#!/usr/bin/env python3
"""Structural validation of a generated .pptx (zip integrity, required OOXML
parts present, every XML part well-formed, slide count consistent).
Exit 0 = valid, exit 1 = problems (all accumulated and printed)."""

import io
import posixpath
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
C_NS = "{http://schemas.openxmlformats.org/drawingml/2006/chart}"
R_NS = "{http://schemas.openxmlformats.org/package/2006/relationships}"
S_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"


def check_chart_workbooks(archive, names, errors):
    """Every c:f formula in a chart must reference a sheet that exists in
    that chart's embedded workbook. PowerPoint renders happily from the
    cached values either way, but "Edit Data" makes Excel resolve the
    formulas — a missing sheet turns every series into #REF! the moment
    the workbook closes (caught manually by Duncan, 2026-06-12)."""
    charts = [n for n in names
              if n.startswith("ppt/charts/chart") and n.endswith(".xml")]
    for chart_name in charts:
        chart = ET.fromstring(archive.read(chart_name))
        refs = [f.text for f in chart.iter(f"{C_NS}f") if f.text]
        if not refs:
            continue
        ref_sheets = set()
        for ref in refs:
            sheet = ref.split("!")[0].strip("'").replace("''", "'")
            ref_sheets.add(sheet)
        rels_name = ("ppt/charts/_rels/" +
                     chart_name.split("/")[-1] + ".rels")
        if rels_name not in names:
            errors.append(f"CHART_NO_RELS: {chart_name} has formulas "
                          "but no rels part (no embedded workbook)")
            continue
        rels = ET.fromstring(archive.read(rels_name))
        targets = [rel.get("Target") for rel in rels.iter(f"{R_NS}Relationship")
                   if rel.get("Target", "").endswith(".xlsx")]
        if not targets:
            errors.append(f"CHART_NO_WORKBOOK: {chart_name} has formulas "
                          "but no embedded .xlsx relationship")
            continue
        workbook_name = posixpath.normpath(
            posixpath.join("ppt/charts", targets[0]))
        if workbook_name not in names:
            errors.append(f"CHART_WORKBOOK_MISSING: {workbook_name}")
            continue
        embedded = zipfile.ZipFile(io.BytesIO(archive.read(workbook_name)))
        workbook = ET.fromstring(embedded.read("xl/workbook.xml"))
        sheet_names = {s.get("name") for s in workbook.iter(f"{S_NS}sheet")}
        for sheet in sorted(ref_sheets - sheet_names):
            errors.append(
                f"CHART_REF_SHEET: {chart_name} formulas reference "
                f"'{sheet}!…' but {workbook_name} only has sheets "
                f"{sorted(sheet_names)} — Edit Data would #REF! the chart")


def validate(path, require_table=True):
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

        # criterion 6: at least one slide must carry a native (editable) table.
        # Skipped for image decks (--no-table), which are intentionally all PNGs.
        if require_table:
            has_table = any(
                ET.fromstring(archive.read(n)).iter(f"{A_NS}tbl") and
                list(ET.fromstring(archive.read(n)).iter(f"{A_NS}tbl"))
                for n in slide_parts)
            if not has_table:
                errors.append("PKG_NO_NATIVE_TABLE: no a:tbl found in any slide")

    check_chart_workbooks(archive, names, errors)

    return errors


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    require_table = "--no-table" not in sys.argv
    if len(args) != 1:
        print("usage: verify_pptx.py <file.pptx> [--no-table]")
        return 1
    errors = validate(args[0], require_table=require_table)
    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1
    print(f"OK   {sys.argv[1]} is a structurally valid PPTX "
          "(zip + parts + XML + native table)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
