#!/usr/bin/env python3
"""Derive the comment-sentiment and comment-vs-rating columns into the survey
data file, from the coded comment appendix.

WHY THIS EXISTS
    A Turas project can report on how people WROTE alongside how they SCORED,
    by carrying the appendix's Overall Sentiment into the data as an ordinary
    question. SACS 2026 has seven such columns and, until this script, no
    record of how they were made. A rebuild of the data file silently blanked
    every one of them.

WHAT IT MAKES
    sentiment columns   one per coded appendix sheet, valued Positive / Mixed /
                        Negative / Did not comment.
    comparison columns  one per declared pair, comparing that sentiment with a
                        rating: "Says what they score", "Writes more critically
                        than they score", "Writes more warmly than they score",
                        or "Did not comment".

    The comparison ranks the sentiment (Negative 1, Mixed 2, Positive 3), bands
    the rating on two cut points, and compares the two ranks. Equal means the
    comment matches the score. A sentiment below its band means the person
    writes more critically than they rate, and above means more warmly.

WHY IT EDITS THE WORKBOOK BY HAND
    Loading and saving an .xlsx with openpyxl drops the shared string table and
    escapes every non-ASCII character as a numeric reference. openxlsx, which R
    uses to read the data, does not decode those, so "don't" comes back as
    "don&#8217;t". This script splices cells into the sheet XML instead and
    leaves every other byte alone.

USAGE
    python3 scripts/build_derived_comment_columns.py \
        --data   "03_Data/SACS-2026_data.xlsx" \
        --appendix "03_Data/2026 SACS Comment Appendix.xlsx" \
        --mapping  "derived_comment_columns.json" [--dry-run]

    --dry-run reports what would change and writes nothing. Run it first.
"""
import argparse
import html
import json
import re
import shutil
import sys
import zipfile
from collections import Counter
from datetime import datetime

SENTIMENT = {1: "Positive", 2: "Mixed", 3: "Negative"}
NO_COMMENT = "Did not comment"
RANK = {"Negative": 1, "Mixed": 2, "Positive": 3}
COMPARISON = {0: "Says what they score",
              -1: "Writes more critically than they score",
              1: "Writes more warmly than they score"}
# The appendix header sits on row 6 and the data starts on row 7, matching
# build_comment_appendix.py. ID is column A, the verbatim column C.
HEADER_ROW = 6
ID_COL = 0


def col_letter(n):
    """1 -> A, 27 -> AA."""
    s = ""
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def col_number(s):
    n = 0
    for ch in s:
        n = n * 26 + (ord(ch) - 64)
    return n


def read_appendix(path, sheet_to_column):
    """{data column code: {respondent id: 'Positive'|'Mixed'|'Negative'}}."""
    import openpyxl
    wb = openpyxl.load_workbook(path, data_only=True, read_only=True)
    out, missing = {}, []
    for sheet, code in sheet_to_column.items():
        if sheet not in wb.sheetnames:
            missing.append(sheet)
            continue
        rows = list(wb[sheet].iter_rows(values_only=True))
        header = rows[HEADER_ROW - 1]
        cols = [j for j, h in enumerate(header)
                if h and "sentiment" in str(h).strip().lower()]
        if not cols:
            missing.append("%s (no Overall Sentiment column)" % sheet)
            continue
        j = cols[0]
        found = {}
        for r in rows[HEADER_ROW:]:
            if r[ID_COL] is None or j >= len(r) or r[j] is None:
                continue
            v = str(r[j]).strip()
            if v in ("1", "2", "3"):
                found[str(r[ID_COL]).strip()] = SENTIMENT[int(v)]
        out[code] = found
    wb.close()
    if missing:
        raise SystemExit("Appendix is missing: %s" % ", ".join(missing))
    return out


def read_data(path):
    import openpyxl
    wb = openpyxl.load_workbook(path, data_only=True, read_only=True)
    ws = wb[wb.sheetnames[0]]
    rows = [list(r) for r in ws.iter_rows(values_only=True)]
    wb.close()
    return rows[0], rows[1:]


def band(value, cuts):
    """1 low, 2 middle, 3 high. cuts is [low_high_boundary, mid_high_boundary]."""
    return 1 if value < cuts[0] else (2 if value < cuts[1] else 3)


def compute(header, body, sentiments, comparisons):
    """{column code: {row index: value}} for every derived column."""
    idx = {name: i for i, name in enumerate(header) if name}
    if "ResponseID" not in idx:
        raise SystemExit("The data file has no ResponseID column.")
    values = {}
    for code, by_id in sentiments.items():
        values[code] = [by_id.get(str(r[idx["ResponseID"]]).strip(), NO_COMMENT)
                        for r in body]
    for spec in comparisons:
        code, scode = spec["column"], spec["sentiment"]
        if scode not in values:
            raise SystemExit("%s compares against %s, which is not being built."
                             % (code, scode))
        for q in spec["rating"]:
            if q not in idx:
                raise SystemExit("%s needs rating column %s, which the data "
                                 "file does not have." % (code, q))
        out = []
        for n, r in enumerate(body):
            s = values[scode][n]
            nums = []
            for q in spec["rating"]:
                try:
                    nums.append(float(r[idx[q]]))
                except (TypeError, ValueError):
                    pass
            if s not in RANK or not nums:
                out.append(NO_COMMENT)
                continue
            mean = sum(nums) / len(nums)
            d = RANK[s] - band(mean, spec["bands"])
            out.append(COMPARISON[0 if d == 0 else (1 if d > 0 else -1)])
        values[code] = out
    return values


def splice(path, values, header, dry_run):
    """Write the columns into the sheet XML, replacing or appending as needed."""
    zin = zipfile.ZipFile(path)
    parts = {n: zin.read(n) for n in zin.namelist()}
    zin.close()
    sheet = "xl/worksheets/sheet1.xml"
    ss_part = "xl/sharedStrings.xml"
    # A workbook Excel wrote keeps a shared string table and new cells join it.
    # One openpyxl wrote has none and stores text inline, so new cells are
    # written inline too. Mixing the two in one sheet is what corrupts a file.
    shared = ss_part in parts
    index, added = {}, 0
    if shared:
        ss = parts[ss_part].decode("utf8")
        for i, si in enumerate(re.findall(r"<si>(.*?)</si>", ss, re.S)):
            index.setdefault(
                html.unescape("".join(re.findall(r"<t[^>]*>(.*?)</t>", si, re.S))), i)
        m = re.search(r"<sst([^>]*)>", ss)
        count = int(re.search(r'count="(\d+)"', m.group(1)).group(1))
        unique = int(re.search(r'uniqueCount="(\d+)"', m.group(1)).group(1))

        # every distinct string this run needs, added once
        wanted = set(values) | {v for col in values.values() for v in col}
        extra = ""
        for text in sorted(wanted):
            if text not in index:
                index[text] = unique + added
                extra += "<si><t>%s</t></si>" % (
                    text.replace("&", "&amp;").replace("<", "&lt;"))
                added += 1

    # where each column goes: reuse its column if it already exists, else append
    existing = {name: i + 1 for i, name in enumerate(header) if name}
    next_col = len(header) + 1
    placement, reused, appended = {}, [], []
    for code in values:
        if code in existing:
            placement[code] = existing[code]
            reused.append(code)
        else:
            placement[code] = next_col
            appended.append(code)
            next_col += 1

    if dry_run:
        return reused, appended, added, None

    if shared:
        ss = ss.replace('count="%d"' % count,
                        'count="%d"' % (count + sum(len(v) + 1 for v in values.values())), 1)
        if added:
            ss = ss.replace('uniqueCount="%d"' % unique,
                            'uniqueCount="%d"' % (unique + added), 1)
            ss = ss.replace("</sst>", extra + "</sst>")
        parts[ss_part] = ss.encode("utf8")

    xml = parts[sheet].decode("utf8")
    last_letter = col_letter(next_col - 1)
    xml = re.sub(r'<dimension ref="A1:[A-Z]+(\d+)"/>',
                 lambda mt: '<dimension ref="A1:%s%s"/>' % (last_letter, mt.group(1)),
                 xml, count=1)
    style = {}
    for code, col in placement.items():
        letter = col_letter(col)
        mt = re.search(r'<c r="%s2"([^>]*?)(?:/>|>)' % letter, xml)
        style[code] = mt.group(1).strip() if mt else ""

    def rewrite(row_match):
        row = row_match.group(0)
        n = int(re.match(r'<row r="(\d+)"', row).group(1))
        cells = {}
        for cm in re.finditer(r'<c r="([A-Z]+)%d"[^>]*(?:/>|>.*?</c>)' % n, row):
            cells[cm.group(1)] = cm.group(0)
        for code, col in placement.items():
            letter = col_letter(col)
            text = code if n == 1 else values[code][n - 2]
            attrs = style.get(code, "")
            attrs = (" " + attrs) if attrs else ""
            if shared:
                cells[letter] = '<c r="%s%d"%s t="s"><v>%d</v></c>' % (
                    letter, n, attrs, index[text])
            else:
                cells[letter] = '<c r="%s%d"%s t="inlineStr"><is><t>%s</t></is></c>' % (
                    letter, n, attrs,
                    text.replace("&", "&amp;").replace("<", "&lt;"))
        body = "".join(cells[c] for c in sorted(cells, key=col_number))
        open_tag = re.match(r'<row [^>]*>', row).group(0)
        open_tag = re.sub(r'spans="1:\d+"', 'spans="1:%d"' % (next_col - 1), open_tag)
        return open_tag + body + "</row>"

    xml, n_rows = re.subn(r'<row r="\d+".*?</row>', rewrite, xml, flags=re.S)
    if n_rows != len(values[list(values)[0]]) + 1:
        raise SystemExit("Patched %d rows, expected %d." %
                         (n_rows, len(values[list(values)[0]]) + 1))
    parts[sheet] = xml.encode("utf8")

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = re.sub(r"\.xlsx$", " (before derived columns %s).xlsx" % stamp, path)
    shutil.copy2(path, backup)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zout:
        with zipfile.ZipFile(backup) as zorig:
            for info in zorig.infolist():
                zout.writestr(info.filename, parts[info.filename])
    return reused, appended, added, backup


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", required=True, help="the survey data .xlsx")
    ap.add_argument("--appendix", required=True, help="the coded comment appendix .xlsx")
    ap.add_argument("--mapping", required=True, help="the .json describing the columns")
    ap.add_argument("--dry-run", action="store_true",
                    help="report what would change and write nothing")
    a = ap.parse_args()

    with open(a.mapping) as fh:
        spec = json.load(fh)
    sheet_to_column = spec.get("sentiment", {})
    comparisons = spec.get("comparison", [])
    if not sheet_to_column:
        raise SystemExit("The mapping declares no sentiment columns.")

    sentiments = read_appendix(a.appendix, sheet_to_column)
    header, body = read_data(a.data)
    values = compute(header, body, sentiments, comparisons)

    print("Respondents in the data file: %d" % len(body))
    for code in values:
        counts = Counter(values[code])
        was = header.index(code) if code in header else None
        note = ""
        if was is not None:
            before = [r[was] for r in body]
            changed = sum(1 for x, y in zip(before, values[code]) if x != y)
            note = "  (column exists; %d of %d values would change)" % (changed, len(body))
        print("  %-8s %s%s" % (code, dict(counts.most_common()), note))

    reused, appended, added, backup = splice(a.data, values, header, a.dry_run)
    print()
    if a.dry_run:
        print("DRY RUN, nothing written.")
        print("  would rewrite columns : %s" % (", ".join(reused) or "none"))
        print("  would add columns     : %s" % (", ".join(appended) or "none"))
        return
    print("Written to %s" % a.data)
    print("  rewrote  : %s" % (", ".join(reused) or "none"))
    print("  added    : %s" % (", ".join(appended) or "none"))
    print("  backup   : %s" % backup)


if __name__ == "__main__":
    main()
