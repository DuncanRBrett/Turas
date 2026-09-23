"""Client-safe prototype fit for the SACAP 2025 student NPS simulator.

The page this feeds must carry NO respondent rows. It gets:
- the model coefficients (main fit plus 200 bootstrap refits), for "build a student";
- precomputed results for published groups only.

Disclosure rules, set below:
- MIN_GROUP: a group publishes only if at least this many people answered.
  Counted on respondents, as tabs does; a population basis was considered and
  dropped (23 Sep 2026) because it fails whenever the client can tell who answered.
- Crossings use secondary suppression (changed 23 Sep 2026 from all or nothing,
  which hid whole crossings for one small cell). Cells under the minimum are
  hidden, then the smallest other cells in the same row or column are hidden too,
  until every row and column has either nothing hidden or a hidden total that
  clears the minimum. Subtraction can then only recover a combined group that is
  at least the minimum. Hidden cells are not marked as small or protecting.
- Counts inside a group (students below Good on a lever) show only if they clear
  the minimum too.
- A differencing check: for any two published groups where one sits inside the
  other, the difference must be zero or clear the minimum.

Model: ordinal (Detractor < Passive < Promoter), weighted, ratings only. Context
did not improve held-out prediction, so it is used only to define groups.
Writes build/model_sacap_safe.json. Hardcoded OneDrive paths: prototype only.
"""
import itertools
import json
import sys
import warnings

import numpy as np
import pandas as pd
from scipy.optimize import minimize

warnings.filterwarnings("ignore")
MIN_GROUP = int(sys.argv[1]) if len(sys.argv) > 1 else 5  # respondents; SACS uses 5
RELIABILITY_FLOOR = 30  # SACAP significance_min_base
N_BOOT = 100  # 100 refits keeps the page size sane with a few hundred groups
CENTRE = 3.0
GOOD = 4
PENALTY = 1e-4
rng = np.random.default_rng(20260923)
ROOT = "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/Projects/SACAP/Student_Annual/03_Waves/Student_Annual-2025/"

# ---------- data ----------
d = pd.read_excel(ROOT + "03_Data/SACAP_Student_Annual-2025_Data_weighted.xlsx", keep_default_na=False, na_values=[""])
d = d[d.Q001.isin(["Complete", "Converted"])].reset_index(drop=True)
N = len(d)
w = d.weight.astype(float).values
s = pd.to_numeric(d.Q017, errors="coerce")
assert s.notna().all()
y = np.where(s >= 9, 2, np.where(s <= 6, 0, 1))

SCALE = {"Terrible": 1, "Not very good": 2, "About average": 3, "Good": 4, "Excellent": 5}
LEVERS = [("Q025", "Educators delivering content"), ("Q026", "Assessment feedback"), ("Q027", "Course content"),
          ("Q021", "Value for money"), ("Q029", "MySACAP usability"), ("Q063", "Staff friendly and approachable"),
          ("Q064", "Student admin"), ("Q065", "Email responsiveness")]
R = d[[c for c, _ in LEVERS]].apply(lambda c: c.map(SCALE)).astype(float)
dont_know = {c: int(R[c].isna().sum()) for c, _ in LEVERS}
R = R.fillna(R.median()).round()
X = R.values - CENTRE
L = len(LEVERS)


def year_band(v):
    v = str(v)
    if "Honours" in v:
        return "Honours"
    if "Masters" in v:
        return "Masters"
    for k in ["1st", "2nd", "3rd"]:
        if v.startswith(k):
            return k + " year"
    return "Other"


course_raw = d.Q005.fillna("Other programmes").astype(str).str.strip()
vc = course_raw.value_counts()
course = course_raw.where(course_raw.map(vc) >= 40, "Other courses")
CTX = {
    "campus": ("Campus", d.Q002.astype(str).str.strip()),
    "course": ("Course", course),
    "year": ("Year of study", d.Q006.map(year_band)),
    "reg": ("New or returning", d.Q009.map(lambda v: "First-time" if "1st" in str(v) else "Returning")),
    "gender": ("Gender", d.Q100.fillna("x").map(lambda v: v if v in ("Female", "Male") else "Other or not said")),
    "age": ("Age", d.Q099.fillna("Not said").replace({"Prefer not to say": "Not said"}).astype(str)),
    "intensity": ("Full or part time", d.Q004.map(lambda v: "Part time" if "Part" in str(v) else "Full time")),
}
# two-way crossings offered, as a banner would declare them
CROSSINGS = [("campus", "course"), ("campus", "year"), ("course", "year"), ("campus", "reg"), ("course", "reg"),
             ("campus", "gender"), ("course", "gender"), ("campus", "age"), ("course", "age"), ("gender", "age")]
for k, (_, v) in CTX.items():
    assert v.notna().all(), k  # every student has a value, so crossings partition their margins

# ---------- ordinal model ----------
def ord_fit(Xm, ym, wm, start=None, penalty=PENALTY):
    k = Xm.shape[1]

    def nll(t):
        b, c1, c2 = t[:k], t[k], t[k] + np.exp(t[k + 1])
        eta = Xm @ b
        f1, f2 = 1 / (1 + np.exp(-(c1 - eta))), 1 / (1 + np.exp(-(c2 - eta)))
        p = np.column_stack([f1, f2 - f1, 1 - f2])
        return -np.sum(wm * np.log(np.clip(p[np.arange(len(ym)), ym], 1e-12, 1))) + penalty * np.sum(b ** 2)

    t0 = start if start is not None else np.r_[np.zeros(k), -1.0, 0.5]
    t = minimize(nll, t0, method="BFGS", options={"maxiter": 3000}).x
    return {"b": t[:k], "c1": float(t[k]), "c2": float(t[k] + np.exp(t[k + 1])), "_t": t}


def npsvec(fit, eta):
    f1 = 1 / (1 + np.exp(-(fit["c1"] - eta)))
    f2 = 1 / (1 + np.exp(-(fit["c2"] - eta)))
    return 100 * ((1 - f2) - f1)


main = ord_fit(X, y, w)
fits = [main]
for _ in range(N_BOOT):
    i = rng.integers(0, N, N)
    fits.append(ord_fit(X[i], y[i], w[i], start=main["_t"]))
sign = {LEVERS[j][0]: round(float(np.mean([f["b"][j] < 0 for f in fits[1:]])), 3) for j in range(L)}
print("share of refits with a negative slope:", sign)

# ---------- profile model: who the student is (the Economist-style line) ----------
# Additive: each characteristic adds its own effect, so any combination gets an
# estimate even where few or no real students have it. A ridge penalty, chosen by
# cross-validation, pulls thinly supported levels toward the overall score.
PROFILE_KEYS = ["campus", "course", "year", "reg", "gender", "age", "intensity"]
prof_levels = {k: list(CTX[k][1].value_counts().index) for k in PROFILE_KEYS}  # first level = reference
prof_cols = [(k, lv) for k in PROFILE_KEYS for lv in prof_levels[k][1:]]
XP = np.column_stack([(CTX[k][1] == lv).values.astype(float) for k, lv in prof_cols])


def cv_pseudo_r2(Xm, pen, folds=5):
    order = np.random.default_rng(7).permutation(N)
    P = np.zeros((N, 3))
    for q in range(folds):
        te = order[q::folds]
        tr = np.setdiff1d(order, te)
        fit = ord_fit(Xm[tr], y[tr], w[tr], penalty=pen)
        eta = Xm[te] @ fit["b"]
        f1 = 1 / (1 + np.exp(-(fit["c1"] - eta)))
        f2 = 1 / (1 + np.exp(-(fit["c2"] - eta)))
        P[te] = np.column_stack([f1, f2 - f1, 1 - f2])
    base = np.array([np.average(y == c, weights=w) for c in range(3)])
    ll = np.average(np.log(np.clip(P[np.arange(N), y], 1e-12, 1)), weights=w)
    return float(1 - ll / np.average(np.log(base[y]), weights=w))


prof_cv = {pen: round(cv_pseudo_r2(XP, pen), 4) for pen in (1.0, 5.0, 20.0, 50.0)}
PROF_PENALTY = max(prof_cv, key=prof_cv.get)
print("profile model cv pseudo-R2 by penalty:", prof_cv, "-> chosen", PROF_PENALTY)
pmain = ord_fit(XP, y, w, penalty=PROF_PENALTY)
pfits = [pmain]
for _ in range(N_BOOT):
    i = rng.integers(0, N, N)
    pfits.append(ord_fit(XP[i], y[i], w[i], start=pmain["_t"], penalty=PROF_PENALTY))


def profile_nps(fit, Xm):
    eta = Xm @ fit["b"]
    return 100 * ((1 - 1 / (1 + np.exp(-(fit["c2"] - eta)))) - 1 / (1 + np.exp(-(fit["c1"] - eta))))


real_profile_nps = profile_nps(pmain, XP)
spread = [round(float(np.percentile(real_profile_nps, q)), 1) for q in (5, 50, 95)]
print("predicted NPS across real students' profiles, 5th/50th/95th:", spread)


def pack_profile_fit(fit):
    b = dict(zip(prof_cols, fit["b"]))
    return {"b": {k: [0.0] + [round(float(b[(k, lv)]), 5) for lv in prof_levels[k][1:]] for k in PROFILE_KEYS},
            "c1": round(fit["c1"], 5), "c2": round(fit["c2"], 5)}


profile_out = {
    "keys": [{"key": k, "label": CTX[k][0], "levels": prof_levels[k]} for k in PROFILE_KEYS],
    "fits": [pack_profile_fit(f) for f in pfits], "penalty": PROF_PENALTY,
    "cv_r2": prof_cv[PROF_PENALTY], "spread": spread,
}

# ---------- groups ----------
def members(defn):
    m = np.ones(N, bool)
    for k, lv in defn.items():
        m &= (CTX[k][1] == lv).values
    return m


def secondary_suppression(tab, k=MIN_GROUP, seed=None):
    """Hide cells under k, then protect them: in every row and column whose hidden
    total is between 1 and k-1, also hide the smallest published cell, and repeat
    until every row and column is either untouched or hides at least k."""
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


def line_failures(tab, hide, k=MIN_GROUP):
    bad = 0
    for axis in (0, 1):
        for ln in (tab.index if axis == 0 else tab.columns):
            row = tab.loc[ln] if axis == 0 else tab[ln]
            h = hide.loc[ln] if axis == 0 else hide[ln]
            bad += int(0 < row[h].sum() < k)
    return bad


published = [{"id": "all", "family": "All students", "label": "All students", "def": {}}]
refused = []
for k, (lab, v) in CTX.items():
    for lv in v.value_counts().index:
        n = int((v == lv).sum())
        if n >= MIN_GROUP:
            published.append({"id": f"{k}={lv}", "family": lab, "label": lv, "def": {k: lv}})
        else:
            refused.append({"group": f"{lab}: {lv}", "why": f"under {MIN_GROUP}"})


def build_crossings(forced):
    """Publish crossing cells under secondary suppression. `forced` holds cell ids
    that must be hidden (found by the nesting check below)."""
    pub, hid, summ, fails = [], [], [], 0
    for k1, k2 in CROSSINGS:
        (l1, v1), (l2, v2) = CTX[k1], CTX[k2]
        tab = pd.crosstab(v1, v2)
        hide = (tab > 0) & (tab < MIN_GROUP)
        for a in tab.index:
            for b in tab.columns:
                if f"{k1}={a}|{k2}={b}" in forced:
                    hide.loc[a, b] = True
        hide = secondary_suppression(tab, seed=hide)
        fails += line_failures(tab, hide)
        fam = f"{l1} by {l2.lower()}"
        cells = [(a, b) for a in tab.index for b in tab.columns if tab.loc[a, b] > 0]
        for a, b in cells:
            defn = {k1: a, k2: b}
            if hide.loc[a, b]:
                hid.append({"family": fam, "def": defn})
            else:
                pub.append({"id": f"{k1}={a}|{k2}={b}", "family": fam, "label": f"{a}, {b}", "def": defn})
        small = int(((tab > 0) & (tab < MIN_GROUP)).sum().sum())
        summ.append({"family": fam, "cells": len(cells), "shown": len(cells) - int(hide.sum().sum()), "small": small,
                     "protecting": int(hide.sum().sum()) - small})
    return pub, hid, summ, fails


def nesting_failures(groups):
    """Any published group inside another must differ from it by 0 or at least MIN_GROUP.
    Catches leaks ACROSS tables (e.g. Honours year vs Honours course at one campus)."""
    out = []
    for a, b in itertools.permutations(groups, 2):
        if a["n"] > b["n"] and np.all(a["mask"][b["mask"]]):
            gap = a["n"] - b["n"]
            if 0 < gap < MIN_GROUP:
                out.append((a["id"], b["id"], gap))
    return out


singles = published
forced, rounds = set(), 0
while True:
    rounds += 1
    cross, hidden, crossing_summary, line_fail = build_crossings(forced)
    groups_now = singles + cross
    for g in groups_now:
        g["mask"] = members(g["def"])
        g["n"] = int(g["mask"].sum())
        assert g["n"] >= MIN_GROUP, g["id"]
    diff_fail = nesting_failures(groups_now)
    # hide the inner group of each failing pair (only crossing cells can be hidden this way)
    new = {b for _, b, _ in diff_fail if "|" in b} | {a for a, b, _ in diff_fail if "|" not in b and "|" in a}
    if not diff_fail or not (new - forced):
        break
    forced |= new
published = groups_now
assert not diff_fail, f"nesting leaks remain after {rounds} rounds: {diff_fail}"
print(f"min={MIN_GROUP} respondents: published {len(published)} groups, hidden {len(hidden)} crossing cells "
      f"({len(forced)} hidden by the nesting check, {rounds} rounds), row/column failures {line_fail}, "
      f"nesting failures {len(diff_fail)}")
for c in crossing_summary:
    print(f"  {c['family']}: {c['shown']} of {c['cells']} shown ({c['small']} small, {c['protecting']} protecting)")

if "--groups-only" in sys.argv:
    sys.exit(0)

# ---------- precompute ----------
MOVES = [("slip2", -2), ("slip1", -1), ("up1", 1), ("up2", 2), ("floor", "good")]


def dx(l, move):
    r = R.values[:, l]
    if move == "good":
        return np.maximum(r, GOOD) - r
    return np.clip(r + move, 1, 5) - r


DX = {(l, m): dx(l, mv) for l in range(L) for m, mv in MOVES}
BUNDLES = [("Teaching", "Educators, assessment feedback and course content each one notch up", {0: 1, 1: 1, 2: 1}),
           ("Service", "Staff, student admin and email responsiveness each one notch up", {5: 1, 6: 1, 7: 1})]
Wg = np.array([g["mask"] * w for g in published], float)
Wg = Wg / Wg.sum(1, keepdims=True)
G, F = len(published), len(fits)
gain = np.zeros((G, L, len(MOVES), F))
bundle = np.zeros((G, len(BUNDLES), F))
base_model = np.zeros(G)
for f, fit in enumerate(fits):
    eta = X @ fit["b"]
    base = npsvec(fit, eta)
    gb = Wg @ base
    if f == 0:
        base_model = gb
    for l in range(L):
        for m, (mk, _) in enumerate(MOVES):
            gain[:, l, m, f] = Wg @ npsvec(fit, eta + fit["b"][l] * DX[(l, mk)]) - gb
    for bi, (_, _, spec) in enumerate(BUNDLES):
        e2 = eta.copy()
        for l, sh in spec.items():
            e2 = e2 + fit["b"][l] * dx(l, sh)
        bundle[:, bi, f] = Wg @ npsvec(fit, e2) - gb

out_groups = []
for gi, g in enumerate(published):
    m = g["mask"]
    act = 100 * (np.average(y[m] == 2, weights=w[m]) - np.average(y[m] == 0, weights=w[m]))
    below = [int((R.values[m, l] < GOOD).sum()) for l in range(L)]
    out_groups.append({
        "id": g["id"], "family": g["family"], "label": g["label"], "def": g["def"], "n": g["n"],
        "actual_nps": round(float(act), 1), "model_nps": round(float(base_model[gi]), 1),
        # counts inside a group publish only if they clear the minimum too
        "below_good": [c if c >= MIN_GROUP else None for c in below],
        "below_good_pct": [round(100 * c / g["n"]) if c >= MIN_GROUP else None for c in below],
        "gain": np.round(gain[gi], 1).tolist(),
        "bundle": np.round(bundle[gi], 1).tolist(),
    })

out = {
    "mode": "client-safe", "basis": "respondents", "min_group": MIN_GROUP, "reliability_floor": RELIABILITY_FLOOR,
    "n": N, "n_det": int((y == 0).sum()), "overall_nps": round(float(100 * (np.average(y == 2, weights=w) - np.average(y == 0, weights=w))), 1),
    "scale": list(SCALE), "centre": CENTRE, "good": GOOD,
    "levers": [{"code": c, "label": lab, "dont_know": dont_know[c]} for c, lab in LEVERS],
    "sign": sign, "moves": [m for m, _ in MOVES],
    "bundles": [{"name": a, "text": b, "spec": {str(k): v for k, v in c.items()}} for a, b, c in BUNDLES],
    "fits": [{"b": np.round(f["b"], 5).tolist(), "c1": round(f["c1"], 5), "c2": round(f["c2"], 5)} for f in fits],
    "groups": out_groups, "refused": refused, "hidden": hidden, "crossings": crossing_summary,
    "profile": profile_out,
    "ctx": [{"key": k, "label": lab, "levels": list(v.value_counts().index)} for k, (lab, v) in CTX.items()],
    "audit": {"differencing_failures": len(diff_fail), "line_failures": line_fail, "nesting_hidden": len(forced)},
}


# self-audit: nothing in the file may be a per-respondent array
def longest_list(o):
    if isinstance(o, list):
        return max([len(o)] + [longest_list(v) for v in o])
    if isinstance(o, dict):
        return max([0] + [longest_list(v) for v in o.values()])
    return 0


longest = longest_list(out)
assert longest < N, f"a list of length {longest} looks respondent-level"
out["audit"]["longest_list"] = longest
json.dump(out, open("build/model_sacap_safe.json", "w"), separators=(",", ":"))
print(f"longest list {longest} (respondents {N}); json kb {round(len(json.dumps(out, separators=(',', ':'))) / 1024)}")
