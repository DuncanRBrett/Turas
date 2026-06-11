#!/usr/bin/env python3
"""Structural validation of a generated .pptx (zip integrity, required OOXML
parts present, every XML part well-formed, slide count consistent).
Exit 0 = valid, exit 1 = problems (all accumulated and printed)."""

import sys
import zipfile
import xml.etree.ElementTree as ET

REQUIRED = [
    "[Content_Types].xml",
    "_rels/.rels",
    "ppt/presentation.xml",
    "ppt/_rels/presentation.xml.rels",
    "ppt/theme/theme1.xml",
    "ppt/slideMasters/slideMaster1.xml",
    "ppt/slideMasters/_rels/slideMaster1.xml.rels",
    "ppt/slideLayouts/slideLayout1.xml",
    "ppt/slideLayouts/_rels/slideLayout1.xml.rels",
    "ppt/slides/slide1.xml",
    "ppt/slides/_rels/slide1.xml.rels",
]
P_NS = "{http://schemas.openxmlformats.org/presentationml/2006/main}"
A_NS = "{http://schemas.openxmlformats.org/drawingml/2006/main}"


def validate(path):
    errors = []
    try:
        archive = zipfile.ZipFile(path)
    except Exception as exc:  # noqa: BLE001 - report any zip-open failure
        return [f"IO_ZIP_OPEN: {exc}"]

    bad_entry = archive.testzip()
    if bad_entry:
        errors.append(f"IO_ZIP_CRC: corrupt entry {bad_entry}")

    names = set(archive.namelist())
    for part in REQUIRED:
        if part not in names:
            errors.append(f"PKG_MISSING_PART: {part}")

    for name in sorted(names):
        if name.endswith(".xml") or name.endswith(".rels"):
            try:
                ET.fromstring(archive.read(name))
            except ET.ParseError as exc:
                errors.append(f"XML_PARSE: {name}: {exc}")

    if "ppt/presentation.xml" in names:
        root = ET.fromstring(archive.read("ppt/presentation.xml"))
        slide_ids = root.findall(f"{P_NS}sldIdLst/{P_NS}sldId")
        slide_parts = [n for n in names
                       if n.startswith("ppt/slides/slide") and n.endswith(".xml")]
        if len(slide_ids) != len(slide_parts):
            errors.append(
                f"PKG_SLIDE_COUNT: presentation lists {len(slide_ids)} slides "
                f"but package has {len(slide_parts)} slide parts")
        for i, slide_name in enumerate(sorted(slide_parts), 1):
            slide = ET.fromstring(archive.read(slide_name))
            if slide.find(f"{P_NS}cSld/{P_NS}spTree") is None:
                errors.append(f"PKG_SLIDE_EMPTY: {slide_name} has no shape tree")

        # criterion 6: at least one slide must carry a native (editable) table
        has_table = any(
            ET.fromstring(archive.read(n)).iter(f"{A_NS}tbl") and
            list(ET.fromstring(archive.read(n)).iter(f"{A_NS}tbl"))
            for n in slide_parts)
        if not has_table:
            errors.append("PKG_NO_NATIVE_TABLE: no a:tbl found in any slide")

    return errors


def main():
    if len(sys.argv) != 2:
        print("usage: verify_pptx.py <file.pptx>")
        return 1
    errors = validate(sys.argv[1])
    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1
    print(f"OK   {sys.argv[1]} is a structurally valid PPTX "
          "(zip + parts + XML + native table)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
