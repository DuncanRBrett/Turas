"""Robustness checks for the What if lever model, on each study.

1. Does the hand-built ordinal fit agree with R's ordinal::clm (the standard)?
2. Proportional odds, the ordinal model's key assumption: R's nominal_test per
   lever, and held-out fit of ordinal against multinomial.
3. Linearity: is one straight-line effect per rating point good enough, against
   a separate effect for each band of the scale?
4. Calibration: predict every group's NPS from a model that never saw those
   respondents (5-fold), and compare with the actual NPS, allowing for the
   actual's own sampling error.
5. Overlap between levers (correlations and variance inflation).
6. The client-safe shortcut: adding single-lever results against the exact
   combined result, for random 2 to 4 lever combinations in every single group.

Run: python3 robustness.py   (needs R with the ordinal package)
"""
import json
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression

import study_ccpb
import study_sacap
import whatif_engine as E

HERE = pathlib.Path(__file__).parent
R_SCRIPT = r'''
suppressMessages(library(ordinal))
d <- read.csv(commandArgs(TRUE)[1])
d$y <- factor(d$y, levels = 0:2, ordered = TRUE)
w <- d$w; d$w <- NULL
fit <- clm(y ~ ., data = d, weights = w, link = "logit")
nt <- suppressWarnings(nominal_test(fit))
out <- list(beta = as.list(coef(fit)[names(fit$beta)]), theta = as.list(fit$alpha),
            nominal_p = as.list(setNames(nt[["Pr(>Chi)"]][-1], rownames(nt)[-1])))
cat(jsonlite::toJSON(out, auto_unbox = TRUE, digits = 8))
'''


def r_clm(X, y, w, names):
    with tempfile.TemporaryDirectory() as td:
        csv, rs = pathlib.Path(td) / "d.csv", pathlib.Path(td) / "f.R"
        df = pd.DataFrame(X, columns=names)
        df["y"], df["w"] = y, w
        df.to_csv(csv, index=False)
        rs.write_text(R_SCRIPT)
        res = subprocess.run(["Rscript", str(rs), str(csv)], capture_output=True, text=True, cwd=HERE.parent.parent)
        if res.returncode != 0:
            sys.exit("R failed:\n" + res.stderr[-2000:])
        return json.loads(res.stdout[res.stdout.index("{"):])


def cv_probs(X, y, w, penalty, folds=5):
    order = np.random.default_rng(7).permutation(len(y))
    P = np.zeros((len(y), 3))
    for q in range(folds):
        te = order[q::folds]
        tr = np.setdiff1d(order, te)
        fit = E.ord_fit(X[tr], y[tr], w[tr], penalty=penalty)
        P[te] = E.probs(fit, X[te] @ fit["b"])
    return P


def pseudo_r2(P, y, w):
    base = np.array([np.average(y == c, weights=w) for c in range(3)])
    return 1 - np.average(np.log(np.clip(P[np.arange(len(y)), y], 1e-12, 1)), weights=w) / np.average(np.log(base[y]), weights=w)


def check(mod):
    spec = mod.build_spec()
    sid, y = spec["id"], spec["y"]
    w = spec["weights"] if spec.get("weights") is not None else np.ones(len(y))
    X, cols = E.build_design(spec)
    names = [f"{c['lever']}_{c['part']}" for c in cols]
    levers = spec["levers"]
    print(f"\n==================== {sid.upper()}  n={len(y)}  detractors={int((y == 0).sum())}  passives={int((y == 1).sum())}  promoters={int((y == 2).sum())}")

    # 1. agreement with R
    ours = E.ord_fit(X, y, w)
    r = r_clm(X, y, w, names)
    rb = np.array([r["beta"][n] for n in names])
    print(f"1. ordinal::clm agreement: largest coefficient difference {np.max(np.abs(rb - ours['b'])):.4f} "
          f"(largest coefficient {np.max(np.abs(rb)):.3f}); thresholds R {[round(v, 3) for v in r['theta'].values()]} "
          f"vs ours {[round(ours['c1'], 3), round(ours['c2'], 3)]}")

    # 2. proportional odds
    bad = {k: round(v, 4) for k, v in r["nominal_p"].items() if v is not None and v < 0.05}
    print(f"2. proportional odds, nominal_test: {len(bad)} of {len(names)} terms reject at p<0.05: {bad or 'none'}")
    Po = cv_probs(X, y, w, E.MAIN_PENALTY)
    order = np.random.default_rng(7).permutation(len(y))
    Pm = np.zeros((len(y), 3))
    for q in range(5):
        te = order[q::5]
        tr = np.setdiff1d(order, te)
        Pm[te] = LogisticRegression(max_iter=5000, C=1e4).fit(X[tr], y[tr], sample_weight=w[tr]).predict_proba(X[te])
    print(f"   held-out pseudo R2: ordinal {pseudo_r2(Po, y, w):.3f}, multinomial (no ordering, twice the slopes) {pseudo_r2(Pm, y, w):.3f}")

    # 3. linearity: straight line against bands for every rating lever
    sc = spec["scale"]
    if sc["labels"]:
        bands = lambda v: np.clip(np.round(v), 2, 5)            # Terrible and Not very good pooled (sparse)
    else:
        bands = lambda v: np.digitize(v, [7, 8, 9, 10])          # under 7, 7s, 8s, 9s, 10
    parts = []
    for lv in levers:
        if lv["kind"] == "rating":
            bv = bands(lv["values"])
            lv_levels = sorted(set(bv))
            parts += [(bv == b).astype(float) for b in lv_levels[1:]]
        else:
            parts.append(X[:, lv["col"]])
            if lv["kind"] == "nested":
                parts.append(X[:, lv["col"] - 1])
    XB = np.column_stack(parts)
    lin, band = pseudo_r2(cv_probs(X, y, w, 1.0), y, w), pseudo_r2(cv_probs(XB, y, w, 1.0), y, w)
    print(f"3. linearity, held-out pseudo R2 (same light penalty): straight line {lin:.3f}, a separate effect per band {band:.3f}")

    # 4. calibration by group, out of sample
    npsi = 100 * (Po[:, 2] - Po[:, 0])
    rows = []
    for k, (lab, v) in spec["context"].items():
        for lvl in v.value_counts().index:
            m = (v == lvl).values
            if m.sum() < 30:
                continue
            ww = w[m]
            p, d_ = np.average(y[m] == 2, weights=ww), np.average(y[m] == 0, weights=ww)
            neff = ww.sum() ** 2 / (ww ** 2).sum()
            se = 100 * np.sqrt(max(p + d_ - (p - d_) ** 2, 1e-9) / neff)
            pred, act = np.average(npsi[m], weights=ww), 100 * (p - d_)
            rows.append((f"{lab}: {lvl}", int(m.sum()), act, pred, (pred - act) / se))
    cal = pd.DataFrame(rows, columns=["group", "n", "actual", "predicted", "z"])
    print(f"4. calibration, {len(cal)} groups of 30+: median |predicted - actual| {np.median(np.abs(cal.predicted - cal.actual)):.1f} NPS points; "
          f"{(np.abs(cal.z) > 1.96).sum()} of {len(cal)} outside their 95% sampling band (about {0.05 * len(cal):.1f} expected by chance)")
    worst = cal.reindex(cal.z.abs().sort_values(ascending=False).index).head(4)
    for _, rw in worst.iterrows():
        print(f"     {rw.group[:48]:48s} n={rw.n:4d} actual {rw.actual:6.1f} predicted {rw.predicted:6.1f} z={rw.z:+.2f}")

    # 5. overlap
    rat = [lv for lv in levers if lv["kind"] == "rating"]
    R = np.corrcoef(np.column_stack([lv["values"] for lv in rat]).T)
    iu = np.triu_indices(len(rat), 1)
    top = np.argmax(R[iu])
    vif = np.diag(np.linalg.inv(np.corrcoef(X.T)))
    print(f"5. overlap: highest correlation between rating levers {R[iu][top]:.2f} ({rat[iu[0][top]]['label']} and {rat[iu[1][top]]['label']}); "
          f"largest variance inflation {vif.max():.1f} ({names[int(np.argmax(vif))]}); rule of thumb worries above 5")

    # 6. the client-safe additive shortcut
    rng = np.random.default_rng(3)
    base = E.npsvec(ours, X @ ours["b"])
    moves_by_kind = {"rating": ["slip1", "up1", "up2", "floor"], "nested": ["slip1", "up1", "floor"], "coverage": ["extend", "withdraw"]}
    GOOD, LO, HI = sc["good"], sc["min"], sc["max"]

    def dx(lv, mv):
        v = lv["values"]
        if lv["kind"] == "coverage":
            return np.where(v == 1, 0.0, 1.0) if mv == "extend" else np.where(v == 1, -1.0, 0.0)
        vv = np.where(lv["has"], v, sc["centre"]) if lv["kind"] == "nested" else v
        out = np.maximum(vv, GOOD) - vv if mv == "floor" else np.clip(vv + {"slip1": -1, "up1": 1, "up2": 2}[mv], LO, HI) - vv
        return np.where(lv["has"], out, 0.0) if lv["kind"] == "nested" else out

    errs = []
    groups = [np.ones(len(y), bool)] + [(v == lvl).values for _, (_, v) in spec["context"].items() for lvl in v.value_counts().index]
    for m in groups:
        if m.sum() < 5:
            continue
        for _ in range(5):
            pick = rng.choice(len(levers), rng.integers(2, 5), replace=False)
            mv = {int(j): rng.choice(moves_by_kind[levers[j]["kind"]]) for j in pick}
            eta = X @ ours["b"]
            e_all = eta + sum(ours["b"][levers[j]["col"]] * dx(levers[j], mv[j]) for j in mv)
            exact = np.average(E.npsvec(ours, e_all)[m] - base[m], weights=w[m])
            parts_sum = sum(np.average(E.npsvec(ours, eta + ours["b"][levers[j]["col"]] * dx(levers[j], mv[j]))[m] - base[m], weights=w[m]) for j in mv)
            errs.append((abs(exact - parts_sum), abs(exact)))
    e = np.array(errs)
    print(f"6. additive shortcut, {len(e)} random combinations: median error {np.median(e[:, 0]):.1f} NPS points, 90th percentile {np.percentile(e[:, 0], 90):.1f}, "
          f"worst {e[:, 0].max():.1f}; median size of the change itself {np.median(e[:, 1]):.1f}")


if __name__ == "__main__":
    for mod in (study_sacap, study_ccpb):
        check(mod)
