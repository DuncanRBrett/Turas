#!/usr/bin/env python3
"""Extract prior-wave (2024) Total-column results from the SACAP 2024
crosstabs workbook for year-on-year deltas. Question codes shifted between
waves, so downstream matching is by normalised question title + row label.

Usage: python3 extract_2024_xlsx.py <crosstabs.xlsx> <out.json>
"""

import json
import re
import sys

import openpyxl


def norm(text):
    """Normalise a title/label for cross-wave matching."""
    t = re.sub(r"\s+", " ", str(text or "")).strip().lower()
    t = re.sub(r"[^a-z0-9 ]", "", t)
    return t


def main():
    if len(sys.argv) != 3:
        print("usage: extract_2024_xlsx.py <crosstabs.xlsx> <out.json>")
        return 1
    wb = openpyxl.load_workbook(sys.argv[1], read_only=True)
    ws = wb["Crosstabs"]
    # the workbook ships a broken dimension record (A1:A1); recalculate
    ws.reset_dimensions()

    questions = {}
    current = None
    pending_label = None

    for row in ws.iter_rows(min_col=1, max_col=3, values_only=True):
        a, b = row[0], row[1] if len(row) > 1 else None
        total = row[2] if len(row) > 2 else None
        if a and isinstance(a, str) and re.match(r"Q\d+\s*-\s*", a):
            code, title = re.match(r"(Q\d+)\s*-\s*(.*)", a).groups()
            current = {"code": code, "title": title.strip(), "base": None, "rows": {}}
            questions[norm(title)] = current
            pending_label = None
            continue
        if current is None:
            continue
        if b == "Base (n=)":
            current["base"] = int(total) if total is not None else None
            continue
        if a and b == "Frequency":
            pending_label = str(a).strip()
            current["rows"].setdefault(norm(pending_label), {})["label"] = pending_label
            current["rows"][norm(pending_label)]["n"] = int(total or 0)
            continue
        if b == "Column %" and pending_label:
            current["rows"][norm(pending_label)]["pct"] = float(total or 0)
            pending_label = None
            continue
        # index / mean style rows: label with a non-Frequency numeric type
        if a and b and b not in ("Frequency", "Column %") and total is not None:
            try:
                value = float(total)
            except (TypeError, ValueError):
                continue
            key = norm(f"{a} {b}") if b != "Index" else norm(str(a))
            current["rows"][key] = {"label": f"{a}".strip(), "stat": str(b),
                                    "value": value}

    out = {
        "wave": "Annual 2024",
        "questions": [
            {"code": q["code"], "title": q["title"], "title_norm": k,
             "base": q["base"], "rows": q["rows"]}
            for k, q in questions.items()
        ],
    }
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    n_rows = sum(len(q["rows"]) for q in out["questions"])
    print(f"OK {len(out['questions'])} questions, {n_rows} row entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
