#!/usr/bin/env python3
"""
Known-answer tests for scripts/build_derived_comment_columns.py.

Self-contained (no pytest needed):
    python3 scripts/test_build_derived_comment_columns.py

Covers the banding, the sentiment-vs-rating comparison, the shape of the
derived values, and the two properties that make the writer safe: it leaves
every other cell alone, and it does not destroy the shared string table the
way an openpyxl round trip does.
"""
import importlib.util
import re
import tempfile
import zipfile
from pathlib import Path

import openpyxl

_spec = importlib.util.spec_from_file_location(
    "bdcc", str(Path(__file__).with_name("build_derived_comment_columns.py")))
bdcc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bdcc)

_passed = _failed = 0


def check(cond, msg):
    global _passed, _failed
    if cond:
        _passed += 1
        print("  ok   " + msg)
    else:
        _failed += 1
        print("  FAIL " + msg)


def make_data(path, rows):
    """rows: list of (ResponseID, Q28, Q05, Q06)."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.append(["ResponseID", "Q28", "Q05", "Q06", "Other"])
    for rid, q28, q05, q06 in rows:
        ws.append([rid, q28, q05, q06, "keep me"])
    wb.save(path)


def make_appendix(path, sheet, coded):
    """coded: {id: sentiment code 1/2/3}."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = sheet
    for _ in range(5):
        ws.append([])
    ws.append(["ID", "Noteworthy", "Comment", "Overall Sentiment", "Theme A"])
    for rid, code in coded.items():
        ws.append([rid, None, "text for %s" % rid, code, None])
    wb.save(path)


print("build_derived_comment_columns known-answer tests:\n")

# ---- banding ---------------------------------------------------------------
check(bdcc.band(3.49, [3.5, 4.0]) == 1, "engagement band: 3.49 is low")
check(bdcc.band(3.5, [3.5, 4.0]) == 2, "engagement band: 3.50 is the middle")
check(bdcc.band(3.99, [3.5, 4.0]) == 2, "engagement band: 3.99 is still the middle")
check(bdcc.band(4.0, [3.5, 4.0]) == 3, "engagement band: 4.00 is high")
check([bdcc.band(v, [2.5, 3.5]) for v in (1, 2, 3, 4, 5)] == [1, 1, 2, 3, 3],
      "a 1-5 item bands 1-2 low, 3 middle, 4-5 high")

# ---- the comparison --------------------------------------------------------
with tempfile.TemporaryDirectory() as tmp:
    data = str(Path(tmp) / "data.xlsx")
    appx = str(Path(tmp) / "appx.xlsx")
    # ids 1..6 cover every sentiment against every band
    make_data(data, [(1, 5, 5, 5), (2, 5, 5, 5), (3, 5, 5, 5),
                     (4, 1, 1, 1), (5, 3, 3, 3), (6, None, None, None)])
    make_appendix(appx, "Satisfaction", {1: 1, 2: 2, 3: 3, 4: 3, 5: 2})
    spec = {"sentiment": {"Satisfaction": "Q29S"},
            "comparison": [{"column": "Q29D", "sentiment": "Q29S",
                            "rating": ["Q28"], "bands": [2.5, 3.5]}]}
    sent = bdcc.read_appendix(appx, spec["sentiment"])
    header, body = bdcc.read_data(data)
    v = bdcc.compute(header, body, sent, spec["comparison"])

    check(v["Q29S"] == ["Positive", "Mixed", "Negative", "Negative", "Mixed",
                        "Did not comment"],
          "sentiment carries across, and an uncoded respondent is Did not comment")
    check(v["Q29D"][0] == "Says what they score",
          "positive comment on a 5 says what they score")
    check(v["Q29D"][1] == "Writes more critically than they score",
          "mixed comment on a 5 writes more critically")
    check(v["Q29D"][2] == "Writes more critically than they score",
          "negative comment on a 5 writes more critically")
    check(v["Q29D"][3] == "Says what they score",
          "negative comment on a 1 says what they score")
    check(v["Q29D"][4] == "Says what they score",
          "mixed comment on a 3 says what they score")
    check(v["Q29D"][5] == "Did not comment",
          "no comment and no rating is Did not comment")

    # a positive comment on a low score is the warm case
    make_appendix(appx, "Satisfaction", {4: 1})
    sent2 = bdcc.read_appendix(appx, spec["sentiment"])
    v2 = bdcc.compute(header, body, sent2, spec["comparison"])
    check(v2["Q29D"][3] == "Writes more warmly than they score",
          "positive comment on a 1 writes more warmly")

# ---- the writer ------------------------------------------------------------
with tempfile.TemporaryDirectory() as tmp:
    data = str(Path(tmp) / "data.xlsx")
    appx = str(Path(tmp) / "appx.xlsx")
    # ids chosen so the three written values differ from one another
    make_data(data, [(1, 5, 5, 5), (2, 5, 5, 5), (3, 1, 1, 1)])
    make_appendix(appx, "Satisfaction", {1: 1, 2: 3, 3: 1})
    spec = {"sentiment": {"Satisfaction": "Q29S"},
            "comparison": [{"column": "Q29D", "sentiment": "Q29S",
                            "rating": ["Q28"], "bands": [2.5, 3.5]}]}
    sent = bdcc.read_appendix(appx, spec["sentiment"])
    header, body = bdcc.read_data(data)
    before = [list(r) for r in body]
    values = bdcc.compute(header, body, sent, spec["comparison"])

    reused, appended, added, backup = bdcc.splice(data, values, header, dry_run=True)
    check(appended == ["Q29S", "Q29D"] and reused == [],
          "a dry run reports both columns as new and writes nothing")
    check(len(bdcc.read_data(data)[0]) == 5, "the dry run really did not write")

    bdcc.splice(data, values, header, dry_run=False)
    h2, b2 = bdcc.read_data(data)
    check(h2[-2:] == ["Q29S", "Q29D"], "both columns are appended, in order")
    check([r[:5] for r in b2] == before, "every pre-existing cell is untouched")
    check([r[h2.index("Q29D")] for r in b2] ==
          ["Says what they score",
           "Writes more critically than they score",
           "Writes more warmly than they score"],
          "the written values are the computed ones, and all three differ")

    # This fixture was written by openpyxl, so it stores text inline and has no
    # shared string table. The writer must follow whichever the file already
    # uses; mixing the two in one sheet is what corrupts a workbook. The real
    # SACS data file is Excel-written and takes the shared-string path.
    z = zipfile.ZipFile(data)
    check("xl/sharedStrings.xml" not in z.namelist(),
          "an inline-string workbook is not given a shared string table")
    check(b"inlineStr" in z.read("xl/worksheets/sheet1.xml"),
          "the new cells are written inline, matching the file")
    check(not [n for n in z.namelist() if n.endswith(".xml")
               and re.search(r"&#\d+;", z.read(n).decode("utf8", "replace"))],
          "no numeric character references are introduced")
    check(list(Path(tmp).glob("data (before derived columns *).xlsx")),
          "a dated backup is left beside the file")

    # running twice must not duplicate the columns
    h3, b3 = bdcc.read_data(data)
    v3 = bdcc.compute(h3, b3, sent, spec["comparison"])
    reused3, appended3, _, _ = bdcc.splice(data, v3, h3, dry_run=True)
    check(appended3 == [] and reused3 == ["Q29S", "Q29D"],
          "a second run rewrites the columns rather than adding more")

print("\n%d passed, %d failed" % (_passed, _failed))
raise SystemExit(1 if _failed else 0)
