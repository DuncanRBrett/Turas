#!/usr/bin/env python3
"""
build_comment_appendix.py — reusable builder for the Turas qualitative Comment Appendix
=======================================================================================
Turn a survey's open-end columns into a coded-comment workbook the Turas qualitative
tab reads — INCREMENTALLY and NON-DESTRUCTIVELY, so it is safe to re-run as fieldwork
grows without losing any coding you have done.

WHAT IT PRODUCES
----------------
One worksheet per comment column (sheet name = column name), in the Turas layout:

    col A  <id header>         <- join key (matches the survey's respondent id)
    col B  Noteworthy          <- tier code: n=Noteworthy, m=Must-read, p=Priority
    col C  <verbatim>          <- the comment text (header = the column name)
    col D  Overall Sentiment   <- coded 1/2/3 (see the legend block above the header)
    col E+ (optional)          <- theme columns you add, coded 1/2/3

A sentiment legend (Total Mentions / 1 Positive / 2 Mixed / 3 Negative) sits above the
header row, matching the hand-built SACS / CCPB appendices.

SAFE TO RE-RUN
--------------
For every sheet that already exists it finds the header row (first cell = the id
anchor), reads the ids already listed, and APPENDS only respondents that are new (have
a comment, not yet present). It NEVER edits or reorders existing rows, so all Noteworthy
marks, Overall Sentiment codes and theme columns are preserved. It writes a timestamped
backup before saving, and refuses (touching nothing) if it cannot find the columns.

CHOOSING THE COMMENT COLUMNS (in priority order)
------------------------------------------------
  --columns "a,b,c"      explicit list (most reliable — use when you know the columns)
  --columns-file FILE    same, one column per line (blank lines / #comments ignored)
  --pattern REGEX        headers matching this regex (default: comment|verbatim|feedback)
  --structure FILE.xlsx  the Survey_Structure's Open_End questions (if the survey tags them)
  --auto                 free-text heuristic (for question-wording headers, e.g. SACS);
                         prints its picks and requires --yes before writing
The resolved columns are always printed with per-column counts, so you can confirm.

USAGE
-----
    python3 build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --columns "Q1Comment,Q2Comment"
    python3 build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --pattern "comment|verbatim|xtra"
    python3 build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --auto           # preview
    python3 build_comment_appendix.py --data DATA.xlsx --appendix APX.xlsx --auto --yes      # write
    python3 build_comment_appendix.py ... --dry-run                                          # never write

Docs: scripts/README_comment_appendix.md
"""

import argparse
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

import openpyxl
import pandas as pd

# ---- layout + detection constants -------------------------------------------

COL_ID, COL_NOTEWORTHY, COL_VERBATIM, COL_SENTIMENT = 1, 2, 3, 4
DEFAULT_ID_HEADER = "ResponseID"
NOTEWORTHY_HEADER = "Noteworthy"
SENTIMENT_HEADER = "Overall Sentiment"

# Header anchor for the respondent-id column — matches the Turas qual reader
# (qual_workbook_reader.R QUAL_ID_PATTERN), so "ID" / "Response ID" / "ResponseID" all work.
ID_PATTERN = re.compile(r"^(response\s*)?id$", re.IGNORECASE)

# Default name pattern for --pattern / a fallback when nothing else is given.
DEFAULT_COMMENT_PATTERN = re.compile(r"comment|verbatim|feedback", re.IGNORECASE)

# Names that are never free-text comments (excluded from the --auto heuristic).
METADATA_DENYLIST = re.compile(
    r"^(response\s*id|id|contact\s*id|.*\bemail\b|.*\bphone\b|.*\burl\b|ip(\s*address)?|"
    r"time\s*started|date\s*submitted|status|longitude|latitude|weight.*|language|country|region)$",
    re.IGNORECASE)

# --auto heuristic thresholds: a free-text column's non-blank cells are long and mostly unique.
AUTO_MIN_MEAN_LEN = 20      # average characters across non-blank cells
AUTO_MIN_UNIQUE_RATIO = 0.6  # distinct / non-blank

SENTIMENT_LEGEND = [
    ("", "", "Total Mentions", ""),
    ("", "1", "Positive skew", ""),
    ("", "2", "Mixed sentiment", ""),
    ("", "3", "Negative skew", ""),
]


# ---- pure helpers (no I/O) --------------------------------------------------

def norm(value):
    """Trimmed string; '' for None/blank."""
    return "" if value is None else str(value).strip()


def strip_bom(name):
    """Drop a leading UTF-8 BOM from a header (a common Alchemer export artifact)."""
    return re.sub("^" + chr(0xFEFF) + "+", "", str(name))


def fmt_id(value):
    """Render a respondent id as the data holds it: integer when whole, else trimmed text."""
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, str):
        s = value.strip()
        return int(s) if re.fullmatch(r"-?\d+", s) else s
    return value


def resolve_id_column(columns):
    """The respondent-id column: the first header matching the id anchor, else the first column."""
    for c in columns:
        if ID_PATTERN.match(strip_bom(c).strip()):
            return c
    return columns[0]


def looks_like_free_text(series):
    """Heuristic: this column's non-blank values read as free-text comments."""
    vals = [norm(v) for v in series if norm(v) != ""]
    if not vals:
        return False
    mean_len = sum(len(v) for v in vals) / len(vals)
    unique_ratio = len(set(vals)) / len(vals)
    return mean_len >= AUTO_MIN_MEAN_LEN and unique_ratio >= AUTO_MIN_UNIQUE_RATIO


def detect_columns(df, id_col, columns=None, pattern=None, structure_codes=None, auto=False):
    """Resolve the comment columns and the mode used. Returns (ordered_columns, mode).

    Priority: explicit list -> name pattern -> structure Open_End codes -> --auto heuristic.
    Order is preserved and de-duplicated; the id column is never included."""
    headers = [c for c in df.columns if c != id_col]

    if columns:
        wanted = [c.strip() for c in columns if c and c.strip()]
        return list(dict.fromkeys(wanted)), "explicit"
    if pattern is not None:
        rx = pattern if hasattr(pattern, "search") else re.compile(pattern, re.IGNORECASE)
        return [c for c in headers if rx.search(str(c))], "pattern"
    if structure_codes:
        codes = set(structure_codes)
        return [c for c in headers if strip_bom(c).strip() in codes], "structure"
    if auto:
        return [c for c in headers if not METADATA_DENYLIST.match(strip_bom(c).strip())
                and looks_like_free_text(df[c])], "auto"
    # No source given -> the default name pattern (comment|verbatim|feedback).
    return [c for c in headers if DEFAULT_COMMENT_PATTERN.search(str(c))], "default-pattern"


def comment_pairs(df, id_col, column):
    """[(id, comment)] for rows with a non-blank id AND a non-blank comment in `column`."""
    pairs = []
    for rid, comment in zip(df[id_col], df[column]):
        if pd.isna(rid) or norm(rid) == "":
            continue
        text = "" if pd.isna(comment) else str(comment).strip()
        if text:
            pairs.append((fmt_id(rid), text))
    return pairs


def find_header_row(ws):
    """Row index (1-based) whose first cell is the id anchor, else None."""
    for r in range(1, ws.max_row + 1):
        if ID_PATTERN.match(norm(ws.cell(r, 1).value)):
            return r
    return None


def existing_ids_and_last_row(ws, header_row):
    """(set of existing ids as strings, last row carrying an id in column A)."""
    ids, last = set(), header_row
    for r in range(header_row + 1, ws.max_row + 1):
        v = norm(ws.cell(r, COL_ID).value)
        if v:
            ids.add(v)
            last = r
    return ids, last


# ---- workbook I/O -----------------------------------------------------------

def load_data(path):
    """(df with BOM-stripped headers, id column name)."""
    df = pd.read_excel(path)
    df.columns = [strip_bom(c) for c in df.columns]
    return df, resolve_id_column(list(df.columns))


def open_end_codes_from_structure(path):
    """Question codes tagged Variable_Type == 'Open_End' in a Survey_Structure workbook."""
    raw = pd.read_excel(path, sheet_name="Questions", header=None)
    hdr = next((i for i in range(len(raw)) if norm(raw.iloc[i, 0]) == "QuestionCode"), 0)
    q = pd.read_excel(path, sheet_name="Questions", header=hdr)
    q.columns = [norm(c) for c in q.columns]
    is_oe = q["Variable_Type"].astype(str).str.strip().str.lower() == "open_end"
    return [norm(c) for c in q.loc[is_oe, "QuestionCode"].tolist() if norm(c)]


def create_sheet(wb, name, id_header, verbatim_header, records):
    """New sheet: legend block + header row + all comment rows. Returns rows written."""
    ws = wb.create_sheet(title=name[:31])          # Excel caps sheet names at 31 chars
    for i, row in enumerate(SENTIMENT_LEGEND, start=1):
        for c, val in enumerate(row, start=1):
            if val:
                ws.cell(i, c).value = val
    hr = len(SENTIMENT_LEGEND) + 1
    ws.cell(hr, COL_ID).value = id_header
    ws.cell(hr, COL_NOTEWORTHY).value = NOTEWORTHY_HEADER
    ws.cell(hr, COL_VERBATIM).value = verbatim_header
    ws.cell(hr, COL_SENTIMENT).value = SENTIMENT_HEADER
    r = hr + 1
    for rid, comment in records:
        ws.cell(r, COL_ID).value = rid
        ws.cell(r, COL_VERBATIM).value = comment
        r += 1
    return len(records)


def update_sheet(ws, records):
    """Append only ids not already present; leave every existing row untouched.

    Returns (n_added, n_kept). Raises ValueError if the sheet has no id header row."""
    header_row = find_header_row(ws)
    if header_row is None:
        raise ValueError("sheet '%s' has no id header row" % ws.title)
    existing, last = existing_ids_and_last_row(ws, header_row)
    r = last + 1
    added = 0
    for rid, comment in records:
        if norm(rid) in existing:
            continue
        ws.cell(r, COL_ID).value = rid
        ws.cell(r, COL_VERBATIM).value = comment
        existing.add(norm(rid))
        r += 1
        added += 1
    return added, len(existing) - added


# ---- orchestration ----------------------------------------------------------

def build_appendix(df, id_col, appendix_path, columns, id_header):
    """Create/update the appendix in place. Returns a summary dict; caller saves the wb.

    Pure w.r.t. the data (df/columns already resolved); the only side effect is the
    returned openpyxl workbook object, which the caller saves once."""
    appendix = Path(appendix_path)
    if appendix.exists():
        wb = openpyxl.load_workbook(appendix)
    else:
        wb = openpyxl.Workbook()
        wb.remove(wb.active)

    summary = {"created": 0, "updated": 0, "empty": 0, "missing": [], "added": 0, "wb": wb}
    for col in dict.fromkeys(columns):
        if col not in df.columns:
            summary["missing"].append(col)
            continue
        records = comment_pairs(df, id_col, col)
        if col in wb.sheetnames:
            added, kept = update_sheet(wb[col], records)
            summary["added"] += added
            summary["updated"] += 1
            print("  [update]  %-20s kept %3d, added %3d  (total %d)" % (col, kept, added, kept + added))
        else:
            n = create_sheet(wb, col, id_header, col, records)
            summary["added"] += n
            summary["created"] += 1
            if n == 0:
                summary["empty"] += 1
            print("  [create]  %-20s %s" % (col, "empty sheet" if n == 0 else "%d rows" % n))
    return summary


def reorder_sheets(wb, columns):
    """Order sheets to match `columns`; any extras keep their place at the end."""
    wanted = [c[:31] for c in dict.fromkeys(columns) if c[:31] in wb.sheetnames]
    extras = [s for s in wb.sheetnames if s not in wanted]
    wb._sheets = [wb[name] for name in wanted + extras]


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description="Reusable Turas Comment Appendix builder (incremental, non-destructive).")
    ap.add_argument("--data", required=True, help="survey data workbook (.xlsx)")
    ap.add_argument("--appendix", required=True, help="comment appendix workbook to create/update (.xlsx)")
    src = ap.add_mutually_exclusive_group()
    src.add_argument("--columns", help="explicit comma-separated comment columns")
    src.add_argument("--columns-file", help="file with one comment column per line (# and blanks ignored)")
    src.add_argument("--pattern", help="regex; data headers matching it are comment columns")
    src.add_argument("--structure", help="Survey_Structure.xlsx; use its Open_End questions")
    src.add_argument("--auto", action="store_true", help="free-text heuristic (prints picks; needs --yes to write)")
    ap.add_argument("--id-header", default=DEFAULT_ID_HEADER, help="id header for NEW sheets (default: ResponseID)")
    ap.add_argument("--dry-run", action="store_true", help="report only; never write")
    ap.add_argument("--yes", action="store_true", help="confirm writing when columns came from --auto")
    ap.add_argument("--no-backup", action="store_true", help="skip the timestamped backup")
    return ap.parse_args(argv)


def read_columns_file(path):
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    return [ln.strip() for ln in lines if ln.strip() and not ln.strip().startswith("#")]


def main(argv=None):
    args = parse_args(argv)
    df, id_col = load_data(args.data)
    print("Data:     %s" % args.data)
    print("Appendix: %s" % args.appendix)
    print("ID column in data: '%s'\n" % id_col)

    explicit = None
    if args.columns:
        explicit = [c for c in args.columns.split(",")]
    elif args.columns_file:
        explicit = read_columns_file(args.columns_file)
    structure_codes = open_end_codes_from_structure(args.structure) if args.structure else None
    pattern = args.pattern if args.pattern else None

    columns, mode = detect_columns(df, id_col, columns=explicit, pattern=pattern,
                                   structure_codes=structure_codes, auto=args.auto)
    if not columns:
        print("ERROR: no comment columns resolved (mode: %s). The data may be a raw/unmapped\n"
              "  export, or the pattern/list did not match. Nothing was written." % mode)
        return 2

    print("Comment columns (%d, via %s):" % (len(columns), mode))
    for c in columns:
        n = len(comment_pairs(df, id_col, c)) if c in df.columns else "MISSING"
        print("   %-24s %s" % (c, ("%s comments" % n) if c in df.columns else "NOT IN DATA"))
    print()

    # Safety: an --auto heuristic guess must be eyeballed before it writes.
    if mode == "auto" and not args.yes and not args.dry_run:
        print("Auto-detected columns above — re-run with --yes to write them (or --columns to be explicit).")
        return 0

    summary = build_appendix(df, id_col, args.appendix, columns, args.id_header)
    for m in summary["missing"]:
        print("  [skip]    %-20s — NOT FOUND in the data file" % m)
    print("\nSummary: %d created (%d empty), %d updated, %d missing; %d comment rows added." % (
        summary["created"], summary["empty"], summary["updated"], len(summary["missing"]), summary["added"]))

    if args.dry_run:
        print("\n--dry-run: no file written.")
        return 0
    if summary["created"] == 0 and summary["added"] == 0:
        print("\nNo new sheets or rows — appendix left untouched (not re-saved).")
        return 0

    reorder_sheets(summary["wb"], columns)
    appendix = Path(args.appendix)
    if appendix.exists() and not args.no_backup:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = appendix.with_name("%s (backup %s)%s" % (appendix.stem, stamp, appendix.suffix))
        shutil.copy2(appendix, backup)
        print("Backup:  %s" % backup.name)
    summary["wb"].save(appendix)
    print("Saved:   %s" % appendix.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
