#!/usr/bin/env python3
"""
Known-answer tests for scripts/build_comment_appendix.py.

Self-contained (no pytest needed):  python3 scripts/test_build_comment_appendix.py
Covers column detection, the non-destructive incremental update (preservation +
idempotency), id-header handling (ID vs ResponseID), and the empty-column guard.
"""

import importlib.util
import tempfile
from pathlib import Path

import openpyxl
import pandas as pd

_spec = importlib.util.spec_from_file_location(
    "bca", str(Path(__file__).with_name("build_comment_appendix.py")))
bca = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bca)

_passed = _failed = 0


def check(cond, msg):
    global _passed, _failed
    if cond:
        _passed += 1
    else:
        _failed += 1
        print("  FAIL:", msg)


def sample_df():
    # id + two clearly-named comments, one free-text-but-oddly-named (SACS-style),
    # one closed categorical (few distinct values, repeated -> low uniqueness),
    # one metadata column, one empty comment column.
    return pd.DataFrame({
        "Response ID": [8, 11, 32, 40, 55, 61, 70, 88],
        "Q1Comment": ["the delivery service is consistently excellent", "",
                      "they arrive late far too often these days", "",
                      "helpful and professional staff on every visit", "", "", "quick and reliable every time"],
        "xtraNotes": ["they really do help a lot honestly", "no complaints from us at all here",
                      "", "the range could be a little wider", "", "", "", ""],
        "Please share your view": ["prices have climbed a lot recently", "",
                                   "signage in the store is quite limited", "", "",
                                   "everything is working really well for us", "", ""],
        "Q2": ["Very interested", "Not interested", "Interested", "Very interested",
               "Not interested", "Interested", "Very interested", "Not interested"],
        "Status": ["Complete"] * 8,
        "Q9Comment": [""] * 8,
    })


def sheet_rows(ws):
    hr = bca.find_header_row(ws)
    return [(ws.cell(r, 1).value, ws.cell(r, 2).value, ws.cell(r, 3).value)
            for r in range(hr + 1, ws.max_row + 1) if bca.norm(ws.cell(r, 1).value)]


# ---- detection --------------------------------------------------------------

df = sample_df()
_, idc = bca.strip_bom("Response ID"), bca.resolve_id_column(list(df.columns))
check(idc == "Response ID", "resolve_id_column picks the id anchor")
check(bca.resolve_id_column(["ID", "Q1"]) == "ID", "resolve_id_column accepts plain ID")
check(bca.resolve_id_column(["Foo", "Bar"]) == "Foo", "resolve_id_column falls back to first column")

cols, mode = bca.detect_columns(df, idc, columns=["Q1Comment", "xtraNotes"])
check(cols == ["Q1Comment", "xtraNotes"] and mode == "explicit", "explicit columns win, order kept")

cols, mode = bca.detect_columns(df, idc, pattern="comment")
check(cols == ["Q1Comment", "Q9Comment"] and mode == "pattern", "pattern matches *comment* headers")

cols, mode = bca.detect_columns(df, idc)  # default pattern comment|verbatim|feedback
check(cols == ["Q1Comment", "Q9Comment"] and mode == "default-pattern", "default pattern used when nothing given")

cols, mode = bca.detect_columns(df, idc, auto=True)
check(mode == "auto" and "Q1Comment" in cols and "xtraNotes" in cols
      and "Please share your view" in cols, "auto finds free-text incl. oddly-named + question-wording")
check("Q2" not in cols and "Status" not in cols and "Response ID" not in cols,
      "auto excludes categorical, metadata and the id column")

check(bca.comment_pairs(df, idc, "Q1Comment") == [
        (8, "the delivery service is consistently excellent"),
        (32, "they arrive late far too often these days"),
        (55, "helpful and professional staff on every visit"),
        (88, "quick and reliable every time")],
      "comment_pairs keeps only non-blank comments with int ids")


# ---- build + non-destructive incremental update -----------------------------

tmp = Path(tempfile.mkdtemp())
apx = tmp / "apx.xlsx"

s = bca.build_appendix(df, idc, apx, ["Q1Comment", "xtraNotes", "Q9Comment"], "ResponseID")
s["wb"].save(apx)
wb = openpyxl.load_workbook(apx)
check(set(wb.sheetnames) == {"Q1Comment", "xtraNotes", "Q9Comment"}, "one sheet per column")
check(len(sheet_rows(wb["Q1Comment"])) == 4, "Q1Comment got its 4 comments")
check(len(sheet_rows(wb["Q9Comment"])) == 0, "empty column -> empty sheet (header only)")
check(wb["Q1Comment"].cell(bca.find_header_row(wb["Q1Comment"]), 1).value == "ResponseID",
      "new sheet uses the configured id header")

# analyst codes: a theme column + Noteworthy + sentiment on the first Q1Comment row
ws = wb["Q1Comment"]
hr = bca.find_header_row(ws)
ws.cell(hr, 5).value = "Delivery"
ws.cell(hr + 1, 2).value = "p"     # Priority
ws.cell(hr + 1, 4).value = "1"     # sentiment
ws.cell(hr + 1, 5).value = "1"     # theme code
wb.save(apx)

# re-run, same data -> idempotent, coding preserved
wb2 = openpyxl.load_workbook(apx)
s2 = bca.build_appendix(df, idc, apx, ["Q1Comment", "xtraNotes", "Q9Comment"], "ResponseID")
check(s2["added"] == 0, "re-run with same data adds nothing (idempotent)")
ws2 = s2["wb"]["Q1Comment"]
hr2 = bca.find_header_row(ws2)
check(ws2.cell(hr2, 5).value == "Delivery" and ws2.cell(hr2 + 1, 2).value == "p"
      and ws2.cell(hr2 + 1, 4).value == "1" and ws2.cell(hr2 + 1, 5).value == "1",
      "re-run preserves theme column + Priority mark + sentiment")

# new respondent arrives -> appended, coding still intact
df2 = pd.concat([df, pd.DataFrame({"Response ID": [99], "Q1Comment": ["brand new remark"],
                "xtraNotes": [""], "Q9Comment": [""]})], ignore_index=True)
s3 = bca.build_appendix(df2, idc, apx, ["Q1Comment", "xtraNotes", "Q9Comment"], "ResponseID")
ws3 = s3["wb"]["Q1Comment"]
hr3 = bca.find_header_row(ws3)
check(s3["added"] == 1, "a new respondent is appended (added == 1)")
check(ws3.cell(hr3 + 1, 5).value == "1", "the new record does NOT disturb existing coding")
check(any(str(r[0]) == "99" and r[2] == "brand new remark" for r in sheet_rows(ws3)),
      "the new comment lands in the verbatim column")


# ---- SACS-style: id header is 'ID', update finds it -------------------------

apx2 = tmp / "sacs.xlsx"
bca.build_appendix(df, idc, apx2, ["Q1Comment"], "ID")["wb"].save(apx2)
wsS = openpyxl.load_workbook(apx2)["Q1Comment"]
check(wsS.cell(bca.find_header_row(wsS), 1).value == "ID", "id header 'ID' honoured on create")
added, kept = bca.update_sheet(wsS, bca.comment_pairs(df, idc, "Q1Comment"))
check(added == 0 and kept == 4, "update finds the 'ID'-headed sheet and adds nothing")


print("\n" + ("FAILED" if _failed else "OK"), "— %d passed, %d failed" % (_passed, _failed))
raise SystemExit(1 if _failed else 0)
