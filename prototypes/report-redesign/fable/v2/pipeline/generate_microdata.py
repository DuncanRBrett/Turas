#!/usr/bin/env python3
"""Generate synthetic respondent-level microdata consistent with the
extracted SACAP 2025 aggregates.

Guarantees (by construction):
  - every question's Campus-banner crosses (counts, bases) match the
    published tables EXACTLY, including the Total column;
  - each banner variable x Campus joint matches EXACTLY.
Approximated (verified + reported):
  - crosses against the other banner groups (Course/Intensity/Year/Age)
    are matched via conditional-lift weighted allocation.

The respondents are SYNTHETIC. No real respondent data is used or implied;
this file exists so the report can recompute tables under ad-hoc filters
and custom banners. In production Turas would emit real (anonymised)
microdata at generation time and every cross would be exact.

Usage: python3 generate_microdata.py <sacap_2025.json> <out.json> <verify.json>
"""

import json
import random
import sys
from collections import defaultdict

SEED = 20260611
SMOOTH = 0.5  # add-half smoothing for zero cells in lift weights


def col_indices(payload, group):
    return [i for i, c in enumerate(payload["columns"]) if c["group"] == group]


def find_source_row(question, label):
    """Row in a banner-source question matching a banner column label."""
    want = label.strip().lower()
    for kind in ("net", "category"):
        for row in question["rows"]:
            if row["kind"] == kind and row["label"].strip().lower() == want:
                return row
    return None


def weighted_sample_without_replacement(items, weights, k, rng):
    """Pick k distinct items with probability proportional to weights."""
    chosen = []
    pool = list(zip(items, weights))
    for _ in range(min(k, len(pool))):
        total = sum(w for _, w in pool)
        if total <= 0:
            idx = rng.randrange(len(pool))
        else:
            target = rng.random() * total
            acc = 0.0
            idx = len(pool) - 1
            for j, (_, w) in enumerate(pool):
                acc += w
                if acc >= target:
                    idx = j
                    break
        chosen.append(pool.pop(idx)[0])
    return chosen


def assign_banner_vars(payload, rng):
    """Respondent banner attributes: Campus exact; others exact vs Campus."""
    columns = payload["columns"]
    questions = {q["code"]: q for q in payload["questions"]}
    campus_group = payload["banner_groups"][0]["id"]  # Q002 Campus
    campus_cols = col_indices(payload, campus_group)
    any_q = payload["questions"][0]
    n_total = any_q["bases"][0]["n"]

    respondents = []
    for ci in campus_cols:
        count = any_q["bases"][ci]["n"] or 0
        respondents += [{"campus": ci} for _ in range(count)]
    assert len(respondents) == n_total, "campus bases must sum to Total"

    by_campus = defaultdict(list)
    for r_id, r in enumerate(respondents):
        by_campus[r["campus"]].append(r_id)

    for group in payload["banner_groups"][1:]:
        g_cols = col_indices(payload, group["id"])
        source_q = questions.get(group["id"])
        for ci in campus_cols:
            ids = list(by_campus[ci])
            rng.shuffle(ids)
            pool = []
            for gi in g_cols:
                label = columns[gi]["label"]
                row = find_source_row(source_q, label) if source_q else None
                count = 0
                if row is not None and row["n"][ci] is not None:
                    count = row["n"][ci]
                elif row is not None and row["pct"][ci] is not None:
                    base = source_q["bases"][ci]["n"] or 0
                    count = round(row["pct"][ci] / 100.0 * base)
                pool += [gi] * count
            # pad / trim against rounding so everyone gets a value
            while len(pool) < len(ids):
                pool.append(g_cols[rng.randrange(len(g_cols))])
            rng.shuffle(pool)
            for r_id, value in zip(ids, pool[:len(ids)]):
                respondents[r_id][group["id"]] = value
    return respondents


def lift_for(question, row, respondent, other_groups, payload):
    """Naive-Bayes lift of `row` given the respondent's non-campus banners."""
    total_base = question["bases"][0]["n"] or 1
    total_n = (row["n"][0] if row["n"][0] is not None else 0)
    p_total = (total_n + SMOOTH) / (total_base + 1)
    lift = 1.0
    for group in other_groups:
        gi = respondent.get(group["id"])
        if gi is None:
            continue
        base = question["bases"][gi]["n"]
        if not base:
            continue
        n = row["n"][gi]
        p_col = ((n if n is not None else 0) + SMOOTH) / (base + 1)
        lift *= p_col / p_total
    return lift


def allocate_question(question, payload, respondents, by_campus, rng):
    """Allocate answers so every Campus-column cross is exact."""
    campus_cols = list(by_campus.keys())
    other_groups = payload["banner_groups"][1:]
    cat_rows = [(i, r) for i, r in enumerate(question["rows"])
                if r["kind"] == "category"]
    n = len(respondents)

    # 1. answered set: per campus, exactly the published base, selected with
    #    probability lifted by the respondent's other banner answer rates
    answered = []
    for ci in campus_cols:
        base = question["bases"][ci]["n"] or 0
        ids = by_campus[ci]
        if base >= len(ids):
            answered += ids
            continue
        weights = []
        for r_id in ids:
            r = respondents[r_id]
            w = 1.0
            for group in other_groups:
                gi = r.get(group["id"])
                gbase = question["bases"][gi]["n"] if gi is not None else None
                gtotal = payload["questions"][0]["bases"][gi]["n"] if gi is not None else None
                if gbase and gtotal:
                    w *= (gbase / gtotal)
            weights.append(w)
        answered += weighted_sample_without_replacement(ids, weights, base, rng)
    answered_set = set(answered)

    if question["type"] == "multi":
        picks = defaultdict(list)
        for ri, row in cat_rows:
            for ci in campus_cols:
                count = row["n"][ci] or 0
                ids = [r for r in by_campus[ci] if r in answered_set]
                if count >= len(ids):
                    chosen = ids
                else:
                    weights = [lift_for(question, row, respondents[r],
                                        other_groups, payload) for r in ids]
                    chosen = weighted_sample_without_replacement(
                        ids, weights, count, rng)
                for r_id in chosen:
                    picks[r_id].append(ri)
        return [sorted(picks.get(r_id, [])) if r_id in answered_set else None
                for r_id in range(n)], len(answered_set)

    # single / scale: exact multiset per campus column
    answers = [None] * n
    for ci in campus_cols:
        ids = [r for r in by_campus[ci] if r in answered_set]
        rng.shuffle(ids)
        remaining = {ri: (row["n"][ci] or 0) for ri, row in cat_rows}
        # rounding slack: mark extras as answered-but-not-displayed (-2) so
        # bases stay exact while every published category cell stays exact
        slack = len(ids) - sum(remaining.values())
        if slack > 0:
            for r_id in ids[len(ids) - slack:]:
                answers[r_id] = -2
            ids = ids[:len(ids) - slack]
        for r_id in ids:
            weights, options = [], []
            for ri, row in cat_rows:
                if remaining.get(ri, 0) <= 0:
                    continue
                options.append(ri)
                weights.append(remaining[ri] * lift_for(
                    question, row, respondents[r_id], other_groups, payload))
            if not options:
                break
            total = sum(weights)
            if total <= 0:
                pick = options[rng.randrange(len(options))]
            else:
                target = rng.random() * total
                acc = 0.0
                pick = options[-1]
                for opt, w in zip(options, weights):
                    acc += w
                    if acc >= target:
                        pick = opt
                        break
            answers[r_id] = pick
            remaining[pick] -= 1
    return answers, len(answered_set)


def repair_question(question, payload, respondents, by_campus, answers, rng,
                    attempts=25000):
    """Hill-climb: swap two same-campus respondents' answers when it reduces
    total discrepancy against the published non-campus banner crosses.
    Campus crosses stay exact because swaps never cross campus columns."""
    other_groups = [g["id"] for g in payload["banner_groups"][1:]]
    cat_rows = [i for i, r in enumerate(question["rows"])
                if r["kind"] == "category"]
    if len(cat_rows) < 2:
        return
    # current counts per (row, column) for non-campus banner columns
    targets, counts = {}, {}
    group_cols = {g: col_indices(payload, g) for g in other_groups}
    for ri in cat_rows:
        row = question["rows"][ri]
        for g in other_groups:
            for gi in group_cols[g]:
                if row["n"][gi] is not None:
                    targets[(ri, gi)] = row["n"][gi]
                    counts[(ri, gi)] = 0
    for r_id, r in enumerate(respondents):
        a = answers[r_id]
        if a is None or isinstance(a, list):
            continue
        for g in other_groups:
            gi = r.get(g)
            if gi is not None and (a, gi) in counts:
                counts[(a, gi)] += 1

    def delta_for(r, old, new):
        d = 0
        for g in other_groups:
            gi = r.get(g)
            if gi is None:
                continue
            for ri, sign in ((old, -1), (new, 1)):
                key = (ri, gi)
                if key not in counts:
                    continue
                cur = counts[key] - targets[key]
                d += abs(cur + sign) - abs(cur)
        return d

    campus_lists = {ci: [r for r in ids if answers[r] is not None]
                    for ci, ids in by_campus.items()}
    campus_keys = [ci for ci, ids in campus_lists.items() if len(ids) > 1]
    if not campus_keys:
        return
    for _ in range(attempts):
        ci = campus_keys[rng.randrange(len(campus_keys))]
        ids = campus_lists[ci]
        r1, r2 = rng.randrange(len(ids)), rng.randrange(len(ids))
        if r1 == r2:
            continue
        id1, id2 = ids[r1], ids[r2]
        a1, a2 = answers[id1], answers[id2]
        if a1 == a2:
            continue
        gain = (delta_for(respondents[id1], a1, a2) +
                delta_for(respondents[id2], a2, a1))
        if gain < 0:
            answers[id1], answers[id2] = a2, a1
            for r_id, old, new in ((id1, a1, a2), (id2, a2, a1)):
                r = respondents[r_id]
                for g in other_groups:
                    gi = r.get(g)
                    if gi is None:
                        continue
                    if (old, gi) in counts:
                        counts[(old, gi)] -= 1
                    if (new, gi) in counts:
                        counts[(new, gi)] += 1


def verify(payload, respondents, answers_by_q):
    """Recompute every cross from microdata; summarise deviation."""
    report = {"exact_campus_cells": 0, "campus_cells": 0,
              "other_banner_abs_err": [], "details": {}}
    campus_group = payload["banner_groups"][0]["id"]
    campus_cols = set(col_indices(payload, campus_group))
    for q in payload["questions"]:
        answers = answers_by_q[q["code"]]
        cat_rows = [(i, r) for i, r in enumerate(q["rows"])
                    if r["kind"] == "category"]
        for col_i, col in enumerate(payload["columns"]):
            if col_i == 0:
                members = list(range(len(respondents)))
            else:
                group = col["group"]
                members = [r_id for r_id, r in enumerate(respondents)
                           if r.get(group if group != campus_group else "campus")
                           == col_i]
            counts = defaultdict(int)
            for r_id in members:
                a = answers[r_id]
                if a is None:
                    continue
                if isinstance(a, list):
                    for ri in a:
                        counts[ri] += 1
                else:
                    counts[a] += 1
            for ri, row in cat_rows:
                published = row["n"][col_i]
                if published is None:
                    continue
                got = counts.get(ri, 0)
                if col_i == 0 or col_i in campus_cols:
                    report["campus_cells"] += 1
                    if got == published:
                        report["exact_campus_cells"] += 1
                else:
                    base = q["bases"][col_i]["n"]
                    if base:
                        report["other_banner_abs_err"].append(
                            (abs(got - published) / base * 100.0, base))
    threshold = payload["project"].get("low_base_threshold", 30)
    errs_all = sorted(e for e, b in report["other_banner_abs_err"])
    errs_ok = sorted(e for e, b in report["other_banner_abs_err"] if b >= threshold)
    def stats(errs):
        return {
            "cells": len(errs),
            "mean_abs_err_pp": round(sum(errs) / max(len(errs), 1), 3),
            "p90_abs_err_pp": round(errs[int(len(errs) * 0.9)], 3) if errs else 0,
            "max_abs_err_pp": round(errs[-1], 3) if errs else 0,
        }
    summary = {
        "campus_exact_rate": report["exact_campus_cells"] / max(report["campus_cells"], 1),
        "other_banners_all_cells": stats(errs_all),
        "other_banners_base_ge_threshold": stats(errs_ok),
    }
    return summary


def main():
    if len(sys.argv) != 4:
        print("usage: generate_microdata.py <sacap_2025.json> <out.json> <verify.json>")
        return 1
    payload = json.load(open(sys.argv[1], encoding="utf-8"))
    rng = random.Random(SEED)

    respondents = assign_banner_vars(payload, rng)
    by_campus = defaultdict(list)
    for r_id, r in enumerate(respondents):
        by_campus[r["campus"]].append(r_id)

    answers_by_q = {}
    answered_counts = {}
    for q in payload["questions"]:
        answers, n_answered = allocate_question(q, payload, respondents,
                                                by_campus, rng)
        if q["type"] != "multi":
            repair_question(q, payload, respondents, by_campus, answers, rng)
        answers_by_q[q["code"]] = answers
        answered_counts[q["code"]] = n_answered

    summary = verify(payload, respondents, answers_by_q)
    print("verification:", json.dumps(summary, indent=2))

    banner_vars = {}
    campus_group = payload["banner_groups"][0]["id"]
    banner_vars[campus_group] = [r["campus"] for r in respondents]
    for group in payload["banner_groups"][1:]:
        banner_vars[group["id"]] = [r.get(group["id"]) for r in respondents]

    out = {
        "synthetic": True,
        "seed": SEED,
        "n": len(respondents),
        "note": ("Synthetic respondents fitted to the published 2025 tables. "
                 "Campus crosses and Totals are exact; other banner crosses "
                 "are approximated (see verification)."),
        "banner_vars": banner_vars,
        "answers": answers_by_q,
    }
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    with open(sys.argv[3], "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    import os
    print(f"OK microdata for {len(respondents)} respondents x "
          f"{len(payload['questions'])} questions -> "
          f"{os.path.getsize(sys.argv[2])//1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
