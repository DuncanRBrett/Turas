"""What if engine: one fit and one set of outputs for any study, driven by a spec.

A study file (study_sacap.py, study_ccpb.py) loads its data, builds a spec, and
calls run(spec). The engine then:

1. fits the ordinal outcome model (Detractor < Passive < Promoter) on the levers,
   with bootstrap refits for ranges and a sign check;
2. fits the additive profile model (who the respondent is) for the
   Economist-style line, with a ridge penalty chosen by cross-validation;
3. works out which groups can be published client-safe: single context groups
   and declared two-way crossings, with secondary suppression and a cross-table
   nesting check, at a minimum of spec["min_group"] respondents;
4. precomputes every published group's results, and writes
   build/whatif_<id>_safe.json (no respondent rows; audited) and
   build/whatif_<id>_open.json (respondent rows, for the open view only).

Lever kinds:
- rating:   a score; x = value - centre.
- nested:   a score that only exists for some respondents (has a service);
            two columns, has and has * (value - centre). Moves touch only those who have it.
- coverage: has the service or not; x = 0 or 1. Moves extend or withdraw it.

Prototype only: Python and scipy here; a Turas build would use R.
"""
import itertools
import json
import pathlib
import warnings

import numpy as np
import pandas as pd
from scipy.optimize import minimize

HERE = pathlib.Path(__file__).parent
warnings.filterwarnings("ignore")  # the optimiser probes extreme values on the way; overflow there is expected
np.seterr(all="ignore")
RATING_MOVES = ["slip2", "slip1", "up1", "up2", "floor"]
COVERAGE_MOVES = ["withdraw", "extend"]
MOVES = RATING_MOVES + COVERAGE_MOVES
MAIN_PENALTY = 1e-4


# ---------------------------------------------------------------- ordinal model
def ord_fit(X, y, w, start=None, penalty=MAIN_PENALTY):
    k = X.shape[1]

    def nll(t):
        b, c1, c2 = t[:k], t[k], t[k] + np.exp(t[k + 1])
        eta = X @ b
        f1, f2 = 1 / (1 + np.exp(-(c1 - eta))), 1 / (1 + np.exp(-(c2 - eta)))
        p = np.column_stack([f1, f2 - f1, 1 - f2])
        return -np.sum(w * np.log(np.clip(p[np.arange(len(y)), y], 1e-12, 1))) + penalty * np.sum(b ** 2)

    t0 = start if start is not None else np.r_[np.zeros(k), -1.0, 0.5]
    t = minimize(nll, t0, method="BFGS", options={"maxiter": 3000}).x
    return {"b": t[:k], "c1": float(t[k]), "c2": float(t[k] + np.exp(t[k + 1])), "_t": t}


def probs(fit, eta):
    f1 = 1 / (1 + np.exp(-(fit["c1"] - eta)))
    f2 = 1 / (1 + np.exp(-(fit["c2"] - eta)))
    return np.column_stack([f1, f2 - f1, 1 - f2])


def npsvec(fit, eta):
    p = probs(fit, eta)
    return 100 * (p[:, 2] - p[:, 0])


def cv_pseudo_r2(X, y, w, penalty, folds=5):
    n = len(y)
    order = np.random.default_rng(7).permutation(n)
    P = np.zeros((n, 3))
    for q in range(folds):
        te = order[q::folds]
        tr = np.setdiff1d(order, te)
        fit = ord_fit(X[tr], y[tr], w[tr], penalty=penalty)
        P[te] = probs(fit, X[te] @ fit["b"])
    base = np.array([np.average(y == c, weights=w) for c in range(3)])
    ll = np.average(np.log(np.clip(P[np.arange(n), y], 1e-12, 1)), weights=w)
    return float(1 - ll / np.average(np.log(base[y]), weights=w))


# ---------------------------------------------------------------- disclosure
def secondary_suppression(tab, k, seed=None):
    """Hide cells under k, then protect them: in every row and column whose hidden
    total is between 1 and k-1, also hide the smallest published cell; repeat."""
    hide = seed.copy() if seed is not None else (tab > 0) & (tab < k)
    changed = True
    while changed:
        changed = False
        for axis in (0, 1):
            for ln in (tab.index if axis == 0 else tab.columns):
                row = tab.loc[ln] if axis == 0 else tab[ln]
                while True:
                    h = hide.loc[ln] if axis == 0 else hide[ln]
                    tot = row[h].sum()
                    if not 0 < tot < k:
                        break
                    cand = row[(~h) & (row > 0)]
                    if cand.empty:
                        break
                    c = cand.idxmin()
                    if axis == 0:
                        hide.loc[ln, c] = True
                    else:
                        hide.loc[c, ln] = True
                    changed = True
    return hide


def line_failures(tab, hide, k):
    bad = 0
    for axis in (0, 1):
        for ln in (tab.index if axis == 0 else tab.columns):
            row = tab.loc[ln] if axis == 0 else tab[ln]
            h = hide.loc[ln] if axis == 0 else hide[ln]
            bad += int(0 < row[h].sum() < k)
    return bad


def longest_list(o):
    if isinstance(o, list):
        return max([len(o)] + [longest_list(v) for v in o])
    if isinstance(o, dict):
        return max([0] + [longest_list(v) for v in o.values()])
    return 0


def build_design(spec):
    """Design matrix for the lever model. Sets lever["col"], the column a move acts on.

    rating: value - centre. nested: has, and has * (value - centre). coverage: 0 or 1.
    """
    C = spec["scale"]["centre"]
    cols, Xparts = [], []
    for lv in spec["levers"]:
        if lv["kind"] == "rating":
            lv["col"] = len(cols)
            cols.append({"lever": lv["key"], "part": "val"})
            Xparts.append(lv["values"] - C)
        elif lv["kind"] == "nested":
            has = lv["has"].astype(float)
            cols.append({"lever": lv["key"], "part": "has"})
            Xparts.append(has)
            lv["col"] = len(cols)
            cols.append({"lever": lv["key"], "part": "val"})
            Xparts.append(has * (np.where(lv["has"], lv["values"], C) - C))
        else:
            lv["col"] = len(cols)
            cols.append({"lever": lv["key"], "part": "val"})
            Xparts.append(lv["values"].astype(float))
    return np.column_stack(Xparts), cols


# ---------------------------------------------------------------- run
def run(spec):
    sid, K = spec["id"], spec["min_group"]
    n_boot = spec.get("n_boot", 100)
    rng = np.random.default_rng(20260923)
    y = spec["y"]
    N = len(y)
    w = spec["weights"] if spec.get("weights") is not None else np.ones(N)
    sc = spec["scale"]
    C, GOOD, LO, HI = sc["centre"], sc["good"], sc["min"], sc["max"]
    ctx = spec["context"]  # key -> (label, pd.Series of str)
    for k, (_, v) in ctx.items():
        assert v.notna().all(), f"context {k} has missing values; fill them first"

    # ---- lever design
    X, cols = build_design(spec)
    levers = spec["levers"]

    main = ord_fit(X, y, w)
    fits = [main]
    for _ in range(n_boot):
        i = rng.integers(0, N, N)
        fits.append(ord_fit(X[i], y[i], w[i], start=main["_t"]))
    sign = {lv["key"]: round(float(np.mean([f["b"][lv["col"]] < 0 for f in fits[1:]])), 3) for lv in levers}
    lever_r2 = round(cv_pseudo_r2(X, y, w, MAIN_PENALTY), 3)
    print(f"[{sid}] lever model cv pseudo-R2 {lever_r2}; share of refits with a negative slope: {sign}")

    # ---- symptoms: fitted only to explain why they are not levers
    symptoms = []
    for lab, flag, why in spec.get("symptoms", []):
        Xs = np.column_stack([X, flag.astype(float)])
        fs = ord_fit(Xs, y, w)
        X1, X0 = Xs.copy(), Xs.copy()
        X1[:, -1], X0[:, -1] = 1, 0
        eff = np.average(npsvec(fs, X1 @ fs["b"]) - npsvec(fs, X0 @ fs["b"]), weights=w)
        symptoms.append({"label": lab, "n": int(flag.sum()), "effect": round(float(eff), 1), "why": why})

    # ---- profile model (Economist line)
    pkeys = spec["profile"]["keys"]
    plevels = {k: list(ctx[k][1].value_counts().index) for k in pkeys}
    pcols = [(k, lv) for k in pkeys for lv in plevels[k][1:]]
    XP = np.column_stack([(ctx[k][1] == lv).values.astype(float) for k, lv in pcols])
    pcv = {pen: round(cv_pseudo_r2(XP, y, w, pen), 4) for pen in (1.0, 5.0, 20.0, 50.0)}
    ppen = max(pcv, key=pcv.get)
    pmain = ord_fit(XP, y, w, penalty=ppen)
    pfits = [pmain] + [ord_fit(XP[i], y[i], w[i], start=pmain["_t"], penalty=ppen)
                       for i in (rng.integers(0, N, N) for _ in range(n_boot))]
    real = npsvec(pmain, XP @ pmain["b"])
    spread = [round(float(np.percentile(real, q)), 1) for q in (5, 50, 95)]
    print(f"[{sid}] profile model cv pseudo-R2 by penalty {pcv} -> {ppen}; real profiles 5/50/95: {spread}")

    def pack_profile(f):
        b = dict(zip(pcols, f["b"]))
        return {"b": {k: [0.0] + [round(float(b[(k, lv)]), 5) for lv in plevels[k][1:]] for k in pkeys},
                "c1": round(f["c1"], 5), "c2": round(f["c2"], 5)}

    # ---- groups: singles, then declared crossings under secondary suppression + nesting check
    def members(defn):
        m = np.ones(N, bool)
        for k, lv in defn.items():
            m &= (ctx[k][1] == lv).values
        return m

    singles_all = [{"id": "all", "family": "All " + spec["units"], "label": "All " + spec["units"], "def": {}}]
    refused = []
    for k, (lab, v) in ctx.items():
        for lv in v.value_counts().index:
            if (v == lv).sum() >= K:
                singles_all.append({"id": f"{k}={lv}", "family": lab, "label": lv, "def": {k: lv}})
            else:
                refused.append({"group": f"{lab}: {lv}", "why": f"under {K}"})

    def build_crossings(forced):
        pub, hid, summ, fails = [], [], [], 0
        for k1, k2 in spec["crossings"]:
            (l1, v1), (l2, v2) = ctx[k1], ctx[k2]
            tab = pd.crosstab(v1, v2)
            seed = (tab > 0) & (tab < K)
            for a in tab.index:
                for b in tab.columns:
                    if f"{k1}={a}|{k2}={b}" in forced:
                        seed.loc[a, b] = True
            hide = secondary_suppression(tab, K, seed)
            fails += line_failures(tab, hide, K)
            fam = f"{l1} by {l2[0].lower() + l2[1:]}"
            cells = [(a, b) for a in tab.index for b in tab.columns if tab.loc[a, b] > 0]
            for a, b in cells:
                d = {k1: a, k2: b}
                if hide.loc[a, b]:
                    hid.append({"family": fam, "def": d})
                else:
                    pub.append({"id": f"{k1}={a}|{k2}={b}", "family": fam, "label": f"{a}, {b}", "def": d})
            small = int(((tab > 0) & (tab < K)).sum().sum())
            nh = int(hide.sum().sum())
            summ.append({"family": fam, "cells": len(cells), "shown": len(cells) - nh, "small": small, "protecting": nh - small})
        return pub, hid, summ, fails

    forced, rounds = set(), 0
    while True:
        rounds += 1
        singles = [g for g in singles_all if g["id"] not in forced]
        cross, hidden, crossing_summary, line_fail = build_crossings(forced)
        published = singles + cross
        for g in published:
            g["mask"] = members(g["def"])
            g["n"] = int(g["mask"].sum())
        diff_fail = []
        for a, b in itertools.permutations(published, 2):
            if a["n"] > b["n"] and np.all(a["mask"][b["mask"]]) and 0 < a["n"] - b["n"] < K:
                diff_fail.append((a["id"], b["id"], a["n"] - b["n"]))
        new = {b for _, b, _ in diff_fail if b != "all"} - forced
        if not diff_fail or not new:
            break
        forced |= new
    assert not diff_fail, f"nesting leaks remain: {diff_fail}"
    for g in singles_all:
        if g["id"] in forced:
            refused.append({"group": f"{g['family']}: {g['label']}", "why": "hidden so another group cannot be worked out by subtraction"})
    print(f"[{sid}] min={K}: published {len(published)} groups, hidden {len(hidden)} crossing cells "
          f"({len(forced)} by the nesting check, {rounds} rounds); row/column failures {line_fail}")

    # ---- moves and precompute
    def dx(lv, move):
        v = lv["values"]
        if lv["kind"] == "coverage":
            if move == "extend":
                return np.where(v == 1, 0.0, 1.0)
            if move == "withdraw":
                return np.where(v == 1, -1.0, 0.0)
            return None
        if move not in RATING_MOVES:
            return None
        vv = np.where(lv["has"], v, C) if lv["kind"] == "nested" else v
        if move == "floor":
            out = np.maximum(vv, GOOD) - vv
        else:
            s = {"slip2": -2, "slip1": -1, "up1": 1, "up2": 2}[move]
            out = np.clip(vv + s, LO, HI) - vv
        return np.where(lv["has"], out, 0.0) if lv["kind"] == "nested" else out

    DX = [[dx(lv, m) for m in MOVES] for lv in levers]
    lkey = {lv["key"]: j for j, lv in enumerate(levers)}
    Wg = np.array([g["mask"] * w for g in published], float)
    Wg = Wg / Wg.sum(1, keepdims=True)
    G, L, M, F = len(published), len(levers), len(MOVES), len(fits)
    gain = np.full((G, L, M, F), np.nan)
    bundles = spec.get("bundles", [])
    bgain = np.zeros((G, len(bundles), F))
    for f, fit in enumerate(fits):
        eta = X @ fit["b"]
        base = npsvec(fit, eta)
        gb = Wg @ base
        for j, lv in enumerate(levers):
            for m in range(M):
                if DX[j][m] is not None:
                    gain[:, j, m, f] = Wg @ npsvec(fit, eta + fit["b"][lv["col"]] * DX[j][m]) - gb
        for bi, (_, _, bspec) in enumerate(bundles):
            e2 = eta.copy()
            for key, move in bspec.items():
                lv = levers[lkey[key]]
                e2 = e2 + fit["b"][lv["col"]] * DX[lkey[key]][MOVES.index(move)]
            bgain[:, bi, f] = Wg @ npsvec(fit, e2) - gb

    def need(lv, m):
        if lv["kind"] == "coverage":
            return int((lv["values"][m] == 0).sum())
        if lv["kind"] == "nested":
            return int(((lv["values"][m] < GOOD) & lv["has"][m]).sum())
        return int((lv["values"][m] < GOOD).sum())

    out_groups = []
    for gi, g in enumerate(published):
        m = g["mask"]
        act = 100 * (np.average(y[m] == 2, weights=w[m]) - np.average(y[m] == 0, weights=w[m]))
        nd = [need(lv, m) for lv in levers]
        out_groups.append({
            "id": g["id"], "family": g["family"], "label": g["label"], "def": g["def"], "n": g["n"],
            "actual_nps": round(float(act), 1),
            "need": [c if c >= K else None for c in nd],
            "gain": [[None if np.isnan(gain[gi, j, mm, 0]) else np.round(gain[gi, j, mm], 1).tolist() for mm in range(M)] for j in range(L)],
            "bundle": np.round(bgain[gi], 1).tolist(),
        })

    overall = 100 * (np.average(y == 2, weights=w) - np.average(y == 0, weights=w))
    safe = {
        "id": sid, "meta": spec["meta"], "unit": spec["unit"], "units": spec["units"],
        "mode_default": spec.get("mode_default", "open"), "weighted": spec.get("weights") is not None,
        "min_group": K, "reliability_floor": spec["reliability_floor"], "n": N, "n_det": int((y == 0).sum()),
        "overall_nps": round(float(overall), 1), "scale": sc, "moves": MOVES,
        "levers": [{"key": lv["key"], "label": lv["label"], "kind": lv["kind"], "sub": lv.get("sub", ""),
                    "has_label": lv.get("has_label"), "missing": lv.get("missing", 0), "col": lv["col"]} for lv in levers],
        "design": cols, "sign": sign, "lever_r2": lever_r2,
        "fits": [{"b": np.round(f["b"], 5).tolist(), "c1": round(f["c1"], 5), "c2": round(f["c2"], 5)} for f in fits],
        "profile": {"keys": [{"key": k, "label": ctx[k][0], "levels": plevels[k]} for k in pkeys],
                    "sentence": spec["profile"]["sentence"], "order": spec["profile"].get("order", {}),
                    "fits": [pack_profile(f) for f in pfits], "penalty": ppen, "cv_r2": pcv[ppen], "spread": spread},
        "ctx": [{"key": k, "label": lab, "levels": list(v.value_counts().index)} for k, (lab, v) in ctx.items()],
        "groups": out_groups, "refused": refused, "hidden": hidden, "crossings": crossing_summary,
        "bundles": [{"name": a, "text": b, "spec": c} for a, b, c in bundles],
        "symptoms": symptoms, "notes": spec.get("notes", []),
        "audit": {"line_failures": line_fail, "differencing_failures": len(diff_fail), "nesting_hidden": len(forced)},
    }
    longest = longest_list(safe)
    assert longest < N, f"a list of length {longest} looks respondent-level"
    safe["audit"]["longest_list"] = longest
    (HERE / "build").mkdir(exist_ok=True)
    json.dump(safe, open(HERE / "build" / f"whatif_{sid}_safe.json", "w"), separators=(",", ":"))

    # open-mode rows: NOT client-safe, for the open view only
    levels = {k: list(v.value_counts().index) for k, (_, v) in ctx.items()}
    opn = {
        "ctx": {k: [levels[k].index(x) for x in v] for k, (_, v) in ctx.items()},
        "val": [[None if (lv["kind"] == "nested" and not h) else round(float(x), 3)
                 for x, h in zip(lv["values"], lv["has"] if lv["kind"] == "nested" else [True] * N)] for lv in levers],
        "y": y.tolist(), "w": np.round(w, 4).tolist(),
    }
    json.dump(opn, open(HERE / "build" / f"whatif_{sid}_open.json", "w"), separators=(",", ":"))
    kb = round((HERE / "build" / f"whatif_{sid}_safe.json").stat().st_size / 1024)
    print(f"[{sid}] wrote whatif_{sid}_safe.json ({kb} kb, longest list {longest} vs {N} respondents) and whatif_{sid}_open.json")
    return safe
