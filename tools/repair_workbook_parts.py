#!/usr/bin/env python3
"""Drop relationships and content-type overrides that point at parts which are
not in the workbook.

WHY THIS EXISTS

openxlsx seeds every worksheet, at addWorksheet() time, with a relationship to a
drawing part and a vmlDrawing part, plus a [Content_Types].xml override for the
drawing, whether or not the sheet ever gains one. saveWorkbook() then writes
those parts only when the sheet really holds a drawing or a comment. The result
is a relationship pointing at a part that is not in the archive, which is a hard
OPC error: Excel reports unreadable content and offers to repair the file, and
its repair strips every data-validation dropdown. Python readers refuse the file
outright.

modules/shared/lib/turas_save_workbook_atomic.R fixes this at the source, in the
workbook object before the save, which is the right place for anything Turas
writes from now on. See docs/HANDOVER_openxlsx_broken_workbooks.md. This script
is for the files that were already committed before that fix existed and have no
live workbook object to reconcile.

IT IS DELIBERATELY SURGICAL. It rewrites the .rels documents and
[Content_Types].xml and copies every other part through byte for byte, so cells,
styles, data validations, shared strings and each sheet's declared <dimension>
are untouched. An openxlsx loadWorkbook + save round trip would fix the
relationships too, but it collapses every sheet's dimension to A1, which breaks
Python readers for a different reason.

Two traps, both found the hard way when this logic was first written for the VAS
2026 config pour (Electrum/VAS 2026/Reporting, August 2026):

  - Splitting the .rels XML on "<Relationship" also matches the CONTAINER
    element <Relationships ...> and throws its opening tag away, leaving a
    document no parser will read. Rewrite the children inside the container.
  - A relationship element may be self-closing or a pair. Match both.

Usage:
    python3 tools/repair_workbook_parts.py --check  path/to/*.xlsx
    python3 tools/repair_workbook_parts.py --write  path/to/*.xlsx
"""
import argparse
import posixpath
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

REL_ELEMENT = re.compile(r"<Relationship\b[^>]*?(?:/>|>.*?</Relationship>)", re.S)
REL_CONTAINER = re.compile(r"(<Relationships\b[^>]*>)(.*?)(</Relationships>)", re.S)
TARGET = re.compile(r'Target="([^"]+)"')
OVERRIDE = re.compile(r"<Override\b[^>]*?/>")
PART_NAME = re.compile(r'PartName="([^"]+)"')


def read_parts(path):
    """Every part in the archive, in order, as raw bytes."""
    with zipfile.ZipFile(path) as z:
        return [(i, z.read(i.filename)) for i in z.infolist()]


def resolve(rels_name, target):
    """The archive name a relationship target points at.

    Targets are relative to the directory holding the _rels folder. An absolute
    target (a leading slash) is relative to the package root instead; treating
    it as relative is what made an earlier sweep of mine report false
    positives.
    """
    if target.startswith("/"):
        return target.lstrip("/")
    base = posixpath.dirname(posixpath.dirname(rels_name))
    joined = posixpath.join(base, target) if base else target
    return posixpath.normpath(joined)


def is_external(rel):
    return 'TargetMode="External"' in rel or "Target=\"http" in rel


def plan(path):
    """What would be dropped from this workbook. Reads only."""
    parts = read_parts(path)
    names = {info.filename for info, _ in parts}
    dropped_rels = []   # (rels part, target)
    dropped_overrides = []

    for info, data in parts:
        if not info.filename.endswith(".rels"):
            continue
        xml = data.decode("utf-8")
        for rel in REL_ELEMENT.findall(xml):
            if is_external(rel):
                continue
            m = TARGET.search(rel)
            if not m:
                continue
            if resolve(info.filename, m.group(1)) not in names:
                dropped_rels.append((info.filename, m.group(1)))

    ct = next((d for i, d in parts if i.filename == "[Content_Types].xml"), None)
    if ct is not None:
        for ov in OVERRIDE.findall(ct.decode("utf-8")):
            m = PART_NAME.search(ov)
            if m and m.group(1).lstrip("/") not in names:
                dropped_overrides.append(m.group(1))

    return dropped_rels, dropped_overrides


def rewrite(path):
    """Rewrite the workbook in place, dropping only what plan() reports."""
    parts = read_parts(path)
    names = {info.filename for info, _ in parts}
    n_rels = n_over = 0

    def fix_rels(name, data):
        nonlocal n_rels
        xml = data.decode("utf-8")
        container = REL_CONTAINER.search(xml)
        if not container:
            return data
        kept = []
        for rel in REL_ELEMENT.findall(container.group(2)):
            m = TARGET.search(rel)
            if m and not is_external(rel) and resolve(name, m.group(1)) not in names:
                n_rels += 1
                continue
            kept.append(rel)
        # Only the children are replaced. Splitting on "<Relationship" would
        # also match the container and discard its opening tag.
        body = "".join(kept)
        return (xml[:container.start()] + container.group(1) + body +
                container.group(3) + xml[container.end():]).encode("utf-8")

    def fix_content_types(data):
        nonlocal n_over
        xml = data.decode("utf-8")
        out = xml
        for ov in OVERRIDE.findall(xml):
            m = PART_NAME.search(ov)
            if m and m.group(1).lstrip("/") not in names:
                out = out.replace(ov, "", 1)
                n_over += 1
        return out.encode("utf-8")

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".xlsx",
                                      dir=str(Path(path).parent))
    tmp.close()
    with zipfile.ZipFile(tmp.name, "w", zipfile.ZIP_DEFLATED) as out:
        for info, data in parts:
            if info.filename.endswith(".rels"):
                data = fix_rels(info.filename, data)
            elif info.filename == "[Content_Types].xml":
                data = fix_content_types(data)
            # Keep each part's original metadata so only the content differs.
            new_info = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            new_info.compress_type = info.compress_type
            new_info.external_attr = info.external_attr
            new_info.internal_attr = info.internal_attr
            new_info.create_system = info.create_system
            out.writestr(new_info, data)
    shutil.move(tmp.name, path)
    return n_rels, n_over


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true",
                      help="report only, change nothing; exit 1 if any file is affected")
    mode.add_argument("--write", action="store_true", help="repair in place")
    args = ap.parse_args()

    affected = 0
    for f in args.files:
        rels, overrides = plan(f)
        if not rels and not overrides:
            continue
        affected += 1
        print("%s" % f)
        for name, target in rels:
            print("    rel      %s -> %s" % (name, target))
        for pn in overrides:
            print("    override %s" % pn)
        if args.write:
            a, b = rewrite(f)
            print("    repaired: %d relationships, %d content-type overrides" % (a, b))

    print("\n%d of %d workbooks %s" % (
        affected, len(args.files),
        "repaired" if args.write else "carry a dangling reference"))
    return 1 if (affected and args.check) else 0


if __name__ == "__main__":
    sys.exit(main())
