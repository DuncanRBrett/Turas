#!/usr/bin/env python3
"""Extract Total-column results from SACAP crosstabs workbooks (2018-2024)
into one multi-wave payload for the v2 report's tracking data layer.

Question codes shift between waves, so downstream matching is by normalised
question title (occurrence-ordered for duplicate titles) + row label.

Row taxonomy per question (all read from the Total column only):
  - "Base (n=)"                      -> question base
  - label + Frequency / Column %     -> category row {label, n, pct}
  - label + Column % (no Frequency)  -> NET-style summary row {label, pct}
    (the old single-wave extractor dropped these -- NETs, NET POSITIVE and
    Detractor/Passive/Promoter rows live here)
  - Index / Average / Score rows     -> stats {index | mean | nps}

Question titles were reworded over the years; wave_title_aliases.json maps
historical normalised titles onto their 2025 equivalents (the tracker
module's question-mapper pattern, kept reviewable as data).

Usage:
  extract_waves.py [--aliases <aliases.json>] <agg_2025.json> <out.json> \
      <year>=<crosstabs.xlsx> ...
"""

import json
import re
import sys

import openpyxl


def norm(text):
    """Normalise a title/label for cross-wave matching (mirrors TR.model.norm)."""
    t = re.sub(r"\s+", " ", str(text or "")).strip().lower()
    t = re.sub(r"[^a-z0-9 ]", "", t)
    return t


STAT_KEYS = {"Index": "index", "Average": "mean", "Score": "nps"}


def parse_workbook(path):
    """Parse one crosstabs workbook into an ordered question list."""
    wb = openpyxl.load_workbook(path, read_only=True)
    ws = wb["Crosstabs"]
    # the workbooks ship broken dimension records (A1:A1); recalculate
    ws.reset_dimensions()

    questions = []
    current = None
    pending_label = None

    for row in ws.iter_rows(min_col=1, max_col=3, values_only=True):
        a = row[0]
        b = row[1] if len(row) > 1 else None
        total = row[2] if len(row) > 2 else None
        if a and isinstance(a, str) and re.match(r"Q\d+\s*-\s*", a):
            code, title = re.match(r"(Q\d+)\s*-\s*(.*)", a).groups()
            current = {"code": code, "title": title.strip(),
                       "base": None, "rows": {}, "stats": {}}
            questions.append(current)
            pending_label = None
            continue
        if current is None:
            continue
        if b == "Base (n=)":
            current["base"] = int(float(total)) if total is not None else None
            continue
        if a and b == "Frequency":
            pending_label = str(a).strip()
            entry = current["rows"].setdefault(norm(pending_label), {})
            entry["label"] = pending_label
            entry["n"] = int(float(total or 0))
            continue
        if b == "Column %":
            if pending_label:
                # second half of a category row
                current["rows"][norm(pending_label)]["pct"] = float(total or 0)
                pending_label = None
            elif a:
                # NET-style summary row: percentage only, no frequency
                label = str(a).strip()
                current["rows"][norm(label)] = {"label": label,
                                                "pct": float(total or 0)}
            continue
        stat = STAT_KEYS.get(str(b).strip()) if b else None
        if stat and total is not None:
            try:
                current["stats"][stat] = float(total)
            except (TypeError, ValueError):
                pass

    return questions


def with_match_keys(questions, aliases):
    """Attach occurrence-ordered match keys (duplicate titles pair k-th to k-th).
    title_norm is the CANONICAL (alias-resolved) norm the JS engine matches on."""
    seen = {}
    for q in questions:
        t = norm(q["title"])
        t = aliases.get(t, t)
        k = seen.get(t, 0)
        seen[t] = k + 1
        q["title_norm"] = t
        q["match_key"] = t if k == 0 else t + "#" + str(k)
    return questions


def match_report(agg_questions, wave_questions):
    """How many 2025 questions find a matching question in this wave."""
    wave_keys = {q["match_key"] for q in wave_questions}
    matched = sum(1 for q in agg_questions if q["match_key"] in wave_keys)
    return {"matched": matched, "of": len(agg_questions),
            "rate": round(matched / len(agg_questions), 3) if agg_questions else 0}


def main():
    args = sys.argv[1:]
    aliases = {}
    if args and args[0] == "--aliases":
        with open(args[1], encoding="utf-8") as f:
            aliases = json.load(f)["aliases"]
        args = args[2:]
    if len(args) < 3:
        print(__doc__)
        return 1
    with open(args[0], encoding="utf-8") as f:
        agg = json.load(f)
    # 2025 titles are canonical: never alias-resolved themselves
    agg_questions = with_match_keys(
        [{"title": q["title"]} for q in agg["questions"]], {})
    unused = set(aliases) - {norm(a) for a in aliases}
    if unused:
        print(f"REFUSED: alias keys not normalised: {sorted(unused)[:3]}")
        return 1
    bad_targets = {v for v in aliases.values()} - \
        {q["title_norm"] for q in agg_questions}
    if bad_targets:
        print(f"REFUSED: alias targets missing from 2025: {sorted(bad_targets)[:3]}")
        return 1

    waves, report = [], {}
    for arg in args[2:]:
        year, _, path = arg.partition("=")
        if not year.isdigit() or not path:
            print(f"REFUSED: bad wave argument {arg!r} (want <year>=<xlsx>)")
            return 1
        questions = with_match_keys(parse_workbook(path), aliases)
        waves.append({"wave": f"Annual {year}", "year": int(year),
                      "questions": questions})
        report[year] = match_report(agg_questions, questions)
        print(f"  {year}: {len(questions)} questions, "
              f"{sum(len(q['rows']) for q in questions)} rows, "
              f"matched {report[year]['matched']}/{report[year]['of']} "
              f"({report[year]['rate']:.0%}) of 2025 questions")

    waves.sort(key=lambda w: w["year"])
    out = {"schema_version": 2, "waves": waves, "match_report": report}
    with open(args[1], "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"OK {len(waves)} waves -> {args[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
