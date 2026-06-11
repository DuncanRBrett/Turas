#!/usr/bin/env python3
"""Extract the full data layer from the rendered SACAP 2025 crosstabs HTML.

The live report pre-renders one wide table per question (Total + all banner
columns). This script reverses that into a compact JSON data layer:
banner groups/columns, categories, and per question: rows (category / net /
mean), per-column percentage, count, mean, sig letters, bases and low-base
flags. Counts + bases make the tables exact contingency tables, which the
microdata generator then consumes.

Usage: python3 extract_2025_html.py <report.html> <out.json>
"""

import html as htmllib
import json
import re
import sys

LOW_BASE_MARK = "⚠"  # warning sign in low-base cells
SIG_MARK = "▲"       # ▲ prefix on sig letters


def clean(text):
    return htmllib.unescape(text).replace(" ", " ").strip()


def parse_columns(table_html):
    """Header columns in order: [{key, group, label, letter}]."""
    columns = []
    for m in re.finditer(
            r'<th class="ct-th ct-data-col bg-([^"\s]+)" data-col-key="([^"]+)">\s*'
            r'<div class="ct-header-text">(.*?)</div>\s*(?:<div class="ct-letter">\(([A-Z]+)\)</div>)?',
            table_html, re.S):
        group, key, label, letter = m.groups()
        columns.append({
            "key": clean(key), "group": clean(group),
            "label": clean(re.sub(r"<[^>]+>", "", label)),
            "letter": letter or ""
        })
    return columns


def parse_cells(row_html):
    """All data cells of a row, in column order."""
    cells = []
    for m in re.finditer(
            r'<td class="ct-td ct-data-col[^"]*" data-col-key="([^"]+)"[^>]*>(.*?)</td>',
            row_html, re.S):
        key, body = m.groups()
        cell = {"key": clean(key)}
        val = re.search(r'<span class="ct-val[^"]*">([^<]*)</span>', body)
        mean = re.search(r'<span class="ct-mean-val">([^<]*)</span>', body)
        freq = re.search(r'<div class="ct-freq">n=([\d,]+)</div>', body)
        sig = re.search(r'<span class="ct-sig">([^<]*)</span>', body)
        base = re.search(r'<span class="ct-base-n">([\d,]+)</span>', body)
        low = re.search(r'<span class="ct-low-base">([\d,]+)\s*' + LOW_BASE_MARK, body)
        if val:
            cell["pct"] = float(val.group(1).replace("%", "").strip() or 0)
        if mean:
            cell["mean"] = float(mean.group(1))
        if freq:
            cell["n"] = int(freq.group(1).replace(",", ""))
        if sig:
            cell["sig"] = clean(sig.group(1)).replace(SIG_MARK, "")
        if base:
            cell["base"] = int(base.group(1).replace(",", ""))
        if low:
            cell["base"] = int(low.group(1).replace(",", ""))
            cell["low"] = True
        cells.append(cell)
    return cells


def parse_rows(table_html):
    rows = []
    for m in re.finditer(r'<tr class="ct-row ([^"]+)">(.*?)</tr>', table_html, re.S):
        kind_classes, body = m.groups()
        kind = ("base" if "ct-row-base" in kind_classes
                else "net" if "ct-row-net" in kind_classes
                else "mean" if "ct-row-mean" in kind_classes
                else "category")
        label_m = re.search(
            r'<td class="ct-td ct-label-col">(.*?)</td>', body, re.S)
        label_html = label_m.group(1) if label_m else ""
        index_desc = re.search(r'<div class="ct-index-desc">(.*?)</div>', label_html, re.S)
        label = clean(re.sub(r"<[^>]+>", "",
                             re.sub(r"<div class=\"ct-index-desc\">.*?</div>", "",
                                    label_html, flags=re.S)))
        label = re.sub(r"✕$", "", label).strip()  # row-exclude button glyph
        row = {"kind": kind, "label": label, "cells": parse_cells(body)}
        if index_desc:
            row["index_desc"] = clean(re.sub(r"<[^>]+>", "", index_desc.group(1)))
        rows.append(row)
    return rows


def parse_index_scores(index_desc, category_labels):
    """Map category row labels to index scores from text like
    'Terrible = 0 ; not very good = 25; about average = 50; ...'."""
    if not index_desc:
        return None
    pairs = re.findall(r"([^;=]+?)\s*=\s*(-?\d+(?:\.\d+)?)", index_desc)
    if not pairs:
        return None
    scores = {}
    for raw_label, score in pairs:
        norm = raw_label.strip().lower()
        exact = [c for c in category_labels if c.strip().lower() == norm]
        if exact:
            scores[exact[0]] = float(score)
            continue
        # unique substring fallback only — ambiguous matches are skipped so a
        # short alias ("good") can never overwrite a longer label's score
        subs = [c for c in category_labels
                if norm in c.strip().lower() or c.strip().lower() in norm]
        if len(subs) == 1:
            scores[subs[0]] = float(score)
    return scores if scores else None


def infer_net_members(rows, bases):
    """For each net row, find a contiguous run of category rows whose summed
    COUNTS reproduce the net's rounded PERCENTAGE in every column (net rows
    carry no counts in the rendered HTML). Returns {net_index: [cat_indices]}
    only for nets that pass everywhere, so filtering can recompute them.
    """
    TOLERANCE = 0.75  # rounded display percent can be off by half a point
    members = {}
    cat_indices = [i for i, r in enumerate(rows) if r["kind"] == "category"]
    for ni, net in enumerate(rows):
        if net["kind"] != "net":
            continue
        net_pcts = [c.get("pct") for c in net["cells"]]
        if all(v is None for v in net_pcts):
            continue
        candidates = []
        for start in range(len(cat_indices)):
            for end in range(start + 1, len(cat_indices) + 1):
                run = cat_indices[start:end]
                error = 0.0
                ok = True
                for col in range(len(net_pcts)):
                    base = bases[col]["n"]
                    if not base or net_pcts[col] is None:
                        continue
                    total = 0
                    for ri in run:
                        n = rows[ri]["cells"][col].get("n")
                        if n is None:
                            ok = False
                            break
                        total += n
                    if not ok:
                        break
                    diff = abs(total / base * 100.0 - net_pcts[col])
                    if diff > TOLERANCE:
                        ok = False
                        break
                    error += diff
                if ok:
                    candidates.append((error, run))
        if candidates:
            candidates.sort(key=lambda c: (c[0], len(c[1])))
            members[ni] = candidates[0][1]
    return members


def infer_net_diffs(rows):
    """Detect 'NET POSITIVE (A - B)' rows: a difference of two sibling rows.
    Returns {net_index: {"plus": idx, "minus": idx}}."""
    diffs = {}
    by_label = {}
    for i, r in enumerate(rows):
        if r["kind"] in ("net", "category"):
            by_label.setdefault(r["label"].strip().lower(), i)
    for ni, net in enumerate(rows):
        if net["kind"] != "net":
            continue
        m = re.match(r"NET POSITIVE \((.+?)\s*-\s*(.+?)\)\s*$", net["label"], re.I)
        if not m:
            continue
        plus = by_label.get(m.group(1).strip().lower())
        minus = by_label.get(m.group(2).strip().lower())
        if plus is not None and minus is not None:
            diffs[ni] = {"plus": plus, "minus": minus}
    return diffs


def main():
    if len(sys.argv) != 3:
        print("usage: extract_2025_html.py <report.html> <out.json>")
        return 1
    html = open(sys.argv[1], encoding="utf-8", errors="replace").read()

    # banner groups (id -> display name), in tab order
    banner_groups = []
    for m in re.finditer(
            r'data-group="(Q\d+)" data-banner-name="([^"]+)"', html):
        if m.group(1) not in [b["id"] for b in banner_groups]:
            banner_groups.append({"id": m.group(1), "name": clean(m.group(2))})

    # question code/title in container order
    q_heads = re.findall(
        r'<span class="question-code">(Q\d+)</span>\s*'
        r'<span class="question-text"[^>]*>([^<]+)</span>', html)
    # sidebar: data-category in the same order as containers
    categories = re.findall(
        r'<div class="sidebar-category-group" data-category="([^"]+)">(.*?)'
        r'(?=<div class="sidebar-category-group"|<div class="question-list-footer"|$)',
        html, re.S)
    code_to_category = {}
    for cat_name, body in categories:
        for code in re.findall(r'data-search="(q\d+)', body):
            code_to_category[code.upper()] = clean(cat_name)

    # tables
    questions = []
    global_columns = None
    table_iter = list(re.finditer(
        r'<table class="ct-table" id="table-(Q\d+)">(.*?)</table>', html, re.S))
    titles = dict(q_heads)
    for m in table_iter:
        code, table_html = m.group(1), m.group(2)
        columns = parse_columns(table_html)
        if global_columns is None:
            global_columns = columns
        rows = parse_rows(table_html)
        base_row = next((r for r in rows if r["kind"] == "base"), None)
        if base_row is None:
            print(f"WARN {code}: no base row, skipped")
            continue
        bases = [{"n": c.get("base"), "low": c.get("low", False)}
                 for c in base_row["cells"]]
        data_rows = [r for r in rows if r["kind"] != "base"]

        cat_rows = [r for r in data_rows if r["kind"] == "category"]
        total_base = bases[0]["n"] or 0
        cat_total = sum(r["cells"][0].get("n", 0) or 0 for r in cat_rows)
        qtype = "multi" if total_base and cat_total > total_base * 1.02 else "single"
        if any(r["kind"] == "mean" for r in data_rows):
            qtype = "scale" if qtype == "single" else qtype

        index_desc = next((r.get("index_desc") for r in data_rows
                           if r.get("index_desc")), None)
        scores = parse_index_scores(index_desc,
                                    [r["label"] for r in cat_rows])
        nets = infer_net_members(data_rows, bases)
        net_diffs = infer_net_diffs(data_rows)

        questions.append({
            "code": code,
            "title": clean(titles.get(code, code)),
            "category": code_to_category.get(code, "Other"),
            "type": qtype,
            "bases": bases,
            "index_desc": index_desc,
            "index_scores": scores,
            "net_members": {str(k): v for k, v in nets.items()},
            "net_diffs": {str(k): v for k, v in net_diffs.items()},
            "rows": [{
                "kind": r["kind"], "label": r["label"],
                "pct": [c.get("pct", c.get("mean")) for c in r["cells"]],
                "n": [c.get("n") for c in r["cells"]],
                "sig": [c.get("sig", "") for c in r["cells"]],
            } for r in data_rows],
        })

    payload = {
        "schema_version": 2,
        "project": {
            "name": "SACAP 2025 Annual Student Survey",
            "client": "South African College of Applied Psychology",
            "wave": "Annual 2025",
            "brand_colour": "#323367",
            "accent_colour": "#CC9900",
            "low_base_threshold": 30,
            "alpha": 0.05,
            # tracking is per-project config: enabled=False ships an
            # untracked report; default_scope "key" limits the Tracking tab
            # to NPS / index / rating-NET metrics ("all" adds every row)
            "tracking": {"enabled": True, "default_scope": "key"},
            "sig_note": ("▲ letters mark columns significantly higher at 95% "
                         "confidence within the banner group. Total is not tested."),
        },
        "columns": global_columns,
        "banner_groups": banner_groups,
        "categories": [c for c in dict.fromkeys(code_to_category.values())],
        "questions": questions,
    }
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))

    n_rows = sum(len(q["rows"]) for q in questions)
    n_nets_ok = sum(len(q["net_members"]) + len(q["net_diffs"]) for q in questions)
    n_nets = sum(1 for q in questions for r in q["rows"] if r["kind"] == "net")
    n_scored = sum(1 for q in questions if q["index_scores"])
    print(f"OK {len(questions)} questions, {len(global_columns)} columns, "
          f"{n_rows} rows; nets decomposed {n_nets_ok}/{n_nets}; "
          f"index mappings {n_scored}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
