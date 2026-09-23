"""Prototype v3 fit for the CCPB CSAT 2026 NPS driver simulator.

Changes from v2 (fit_ccpb.py):
- Ordinal model (Detractor < Passive < Promoter, proportional odds). Shared slopes
  let 17 detractors be modelled, so NPS moves include detractor movement.
- Service coverage levers (has coolers, knows the sales manager, CCPB does the
  merchandising, offered a promotion) alongside service ratings.
- A nested rating: signage condition only exists for outlets with Coke signage.
  Coded as has_signage + has_signage * (rating - 8).
- Outlet size and channel were tested as controls, so coverage effects are not
  just big stores standing in for coolers. They barely moved the coverage effects
  and made held-out prediction worse, so the page model leaves them out; the
  comparison is recorded in the JSON and shown on the page.
- Symptom variables (called CCPB, shops around) are fitted only to show why they
  are excluded as levers.
- A 2025 vs 2026 comparison of the rating levers (Q202 absent in 2025, so the rep
  lever there averages Q27 and Q28 only).

Writes build/model_ccpb_v3.json. Hardcoded OneDrive paths: prototype only.
"""
import json
import warnings

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from sklearn.model_selection import StratifiedKFold

warnings.filterwarnings("ignore")
ROOT = "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/CCPB/CSAT/"
CENTRE = 8.0
PENALTY = 1e-4  # near-unpenalised; the build should use catdriver's unpenalised R fit
N_BOOT = 200
rng = np.random.default_rng(20260923)


# ---------- ordinal model ----------
def ord_fit(X, y, start=None):
    k = X.shape[1]

    def nll(t):
        b, c1, c2 = t[:k], t[k], t[k] + np.exp(t[k + 1])
        eta = X @ b
        f1, f2 = 1 / (1 + np.exp(-(c1 - eta))), 1 / (1 + np.exp(-(c2 - eta)))
        p = np.column_stack([f1, f2 - f1, 1 - f2])
        return -np.sum(np.log(np.clip(p[np.arange(len(y)), y], 1e-12, 1))) + PENALTY * np.sum(b ** 2)

    t0 = start if start is not None else np.r_[np.zeros(k), -3.0, 0.5]
    t = minimize(nll, t0, method="BFGS", options={"maxiter": 2000}).x
    return {"b": t[:k].tolist(), "c1": float(t[k]), "c2": float(t[k] + np.exp(t[k + 1])), "_t": t}


def ord_prob(fit, X):
    eta = X @ np.array(fit["b"])
    f1 = 1 / (1 + np.exp(-(fit["c1"] - eta)))
    f2 = 1 / (1 + np.exp(-(fit["c2"] - eta)))
    return np.column_stack([f1, f2 - f1, 1 - f2])


def nps(p):
    return 100 * (p[:, 2] - p[:, 0]).mean()


# ---------- data ----------
d = pd.read_excel(ROOT + "W2026/02 Data/CCPB_CSAT_2026.xlsx", keep_default_na=False, na_values=[""])
q79 = pd.to_numeric(d.Q79, errors="coerce").astype(int)
y = np.where(q79 >= 9, 2, np.where(q79 <= 6, 0, 1))
num = lambda c: pd.to_numeric(d[c], errors="coerce")

RATING_LEVERS = [
    ("ordering", "Ease of ordering", ["Q02"]),
    ("delivery", "Delivery", ["Q08", "Q09", "Q10"]),
    ("invoicing", "Invoicing", ["Q13"]),
    ("merch", "Merchandising", ["Q22"]),
    ("rep", "Sales rep", ["Q27", "Q28", "Q202"]),
]
ITEM = {"Q02": "ease of placing orders", "Q08": "delivery overall", "Q09": "product condition",
        "Q10": "delivery team", "Q13": "invoicing", "Q22": "merchandising", "Q27": "rep overall",
        "Q28": "rep handles complaints", "Q202": "rep helps with coolers and signage"}
raw = d[[c for _, _, items in RATING_LEVERS for c in items]].apply(pd.to_numeric, errors="coerce")
missing = {c: int(raw[c].isna().sum()) for c in raw}
raw = raw.fillna(raw.median())
rat = pd.DataFrame({k: raw[items].mean(axis=1) for k, _, items in RATING_LEVERS})

sign_r = num("Q42")
has_sign = sign_r.notna().astype(float)
sign_val = sign_r.fillna(CENTRE)

COVERAGE = [
    ("coolers", "Has Coca-Cola coolers", d.Q43.eq("Yes")),
    ("mgr", "Knows its CCPB sales manager", d.Q33.eq("Yes")),
    ("ccpbmerch", "CCPB does the merchandising", d.Q16.isin(["CCPB sales person / rep", "CCPB merchandiser"])),
    ("promo", "Offered a promotion in last 3 months", d.Q29.eq("Yes")),
]
cov = pd.DataFrame({k: v.astype(float) for k, _, v in COVERAGE})

opt = pd.read_excel(ROOT + "W2026/CCPB_CSAT_W2026_Survey_Structure short.xlsx", "Options", header=None,
                    keep_default_na=False, na_values=[""])
h = opt.index[opt.iloc[:, 0].astype(str).eq("QuestionCode")][0]
opt.columns = opt.iloc[h]
opt = opt.iloc[h + 1:]
chan_lab = {int(r.OptionText): str(r.DisplayText).split("-", 1)[1].strip()
            for r in opt[opt.QuestionCode == "S09"].itertuples()}
centre_lab = {str(r.OptionText).strip(): str(r.DisplayText).strip() for r in opt[opt.QuestionCode == "S01"].itertuples()}
ctx = pd.DataFrame({
    "centre": d.S01.astype(str).str.strip().map(lambda v: centre_lab.get(v, v)),
    "office": d.S05.astype(str),
    "method": d.S11.astype(str),
    "size": d.S04.astype(str).str.replace(r"^\d\.", "", regex=True),
    "channel": d.S09.map(lambda v: chan_lab.get(int(v), str(v))),
}).fillna("Unknown")
vc = ctx.channel.value_counts()
ctx["channel"] = ctx.channel.where(ctx.channel.map(vc) >= 30, "Other channels")
levels = {c: list(ctx[c].value_counts().index) for c in ctx}

# controls: size and channel dummies (reference = most common)
ctrl = pd.get_dummies(ctx[["size", "channel"]], drop_first=False).astype(float)
ctrl = ctrl.drop(columns=["size_" + levels["size"][0], "channel_" + levels["channel"][0]])

# design matrix, column order is the contract with the page
cols = ([("rating", k) for k, _, _ in RATING_LEVERS] + [("nested_has", "signage"), ("nested_val", "signage")]
        + [("coverage", k) for k, _, _ in COVERAGE])
X = np.column_stack([rat.values - CENTRE, has_sign.values, has_sign.values * (sign_val.values - CENTRE),
                     cov.values])
X_ctrl = np.column_stack([X, ctrl.values])

# ---------- fit, bootstrap ----------
main = ord_fit(X, y)
fits = [main]
for _ in range(N_BOOT):
    i = rng.integers(0, len(y), len(y))
    fits.append(ord_fit(X[i], y[i], start=main["_t"]))
for f in fits:
    f.pop("_t")
Bm = np.array([f["b"] for f in fits[1:]])
lever_cols = [j for j, c in enumerate(cols) if c[0] in ("rating", "nested_val", "coverage")]
sign = {cols[j][1]: round(float((Bm[:, j] < 0).mean()), 3) for j in lever_cols}
print("share of refits with a negative slope:", sign)

# cross-validated fit, with and without controls (pseudo R2 on 3 classes)
cv = StratifiedKFold(5, shuffle=True, random_state=1)
base = np.array([(y == k).mean() for k in range(3)])
ll0 = np.mean(np.log(base[y]))


def cv_r2(Xm):
    P = np.zeros((len(y), 3))
    for tr, te in cv.split(Xm, y):
        P[te] = ord_prob(ord_fit(Xm[tr], y[tr]), Xm[te])
    return round(float(1 - np.mean(np.log(np.clip(P[np.arange(len(y)), y], 1e-12, 1))) / ll0), 3)


r2 = {"ratings_only": cv_r2(X[:, :len(RATING_LEVERS)]), "levers": cv_r2(X), "levers_and_controls": cv_r2(X_ctrl)}
print("cv pseudo-R2:", r2)
p = ord_prob(main, X)
print("actual NPS", round(100 * ((y == 2).mean() - (y == 0).mean()), 1), "model", round(nps(p), 1))

# coverage effect with and without the size/channel controls (all outlets switched on vs off)
def cov_effect(fit, Xm, j):
    X1, X0 = Xm.copy(), Xm.copy()
    X1[:, j], X0[:, j] = 1, 0
    return nps(ord_prob(fit, X1)) - nps(ord_prob(fit, X0))


wc = ord_fit(X_ctrl, y)
control_check = {}
for k, lab, _ in COVERAGE:
    j = cols.index(("coverage", k))
    control_check[k] = [round(cov_effect(main, X, j), 1), round(cov_effect(wc, X_ctrl, j), 1)]
    print(f"  {lab:40s} NPS effect without controls {control_check[k][0]:+.1f}, with size and channel {control_check[k][1]:+.1f}")

# ---------- symptoms: fitted only to explain their exclusion ----------
SYMPTOMS = [("Called CCPB in the last 12 months", ~d.Q35.isin(["Never", "More than 12 months"]),
             "Outlets call when something has gone wrong, so calling is a sign of a problem, not a cause of low scores."),
            ("Shops around for suppliers", d.Q05.isin(["Sometimes shop around", "Always shop around"]),
             "Shopping around is itself a measure of loyalty. It moves with the outcome rather than driving it.")]
symptoms = []
for lab, v, why in SYMPTOMS:
    Xs = np.column_stack([X, v.astype(float).values])
    fs = ord_fit(Xs, y)
    symptoms.append({"label": lab, "n": int(v.sum()), "effect": float(round(cov_effect(fs, Xs, Xs.shape[1] - 1), 1)), "why": why})
print("symptoms:", symptoms)

# ---------- 2025 vs 2026, rating levers only, same spec both years ----------
def wave(path):
    w = pd.read_excel(path, keep_default_na=False, na_values=[""])
    q = pd.to_numeric(w.Q79, errors="coerce")
    w, q = w[q.notna()], q[q.notna()].astype(int)
    r = w[["Q02", "Q08", "Q09", "Q10", "Q13", "Q22", "Q27", "Q28"]].apply(pd.to_numeric, errors="coerce")
    r = r.fillna(r.median())
    Lw = np.column_stack([r.Q02, r[["Q08", "Q09", "Q10"]].mean(1), r.Q13, r.Q22, r[["Q27", "Q28"]].mean(1)]) - CENTRE
    yw = np.where(q >= 9, 2, np.where(q <= 6, 0, 1))
    fw = ord_fit(Lw, yw)
    bw = [ord_fit(Lw[i], yw[i], start=fw["_t"]) for i in [rng.integers(0, len(yw), len(yw)) for _ in range(N_BOOT)]]
    out = {}
    for j, (k, _, _) in enumerate(RATING_LEVERS):
        def slip(f):
            X2 = Lw.copy()
            X2[:, j] = np.clip(X2[:, j] - 1, 1 - CENTRE, 10 - CENTRE)
            return nps(ord_prob(f, X2)) - nps(ord_prob(f, Lw))
        g = [slip(f) for f in bw]
        out[k] = [float(round(slip(fw), 1)), round(float(np.percentile(g, 5)), 1), round(float(np.percentile(g, 95)), 1)]
    return {"n": int(len(yw)), "nps": float(round(100 * ((yw == 2).mean() - (yw == 0).mean()), 1)), "slip": out}


waves = {"2025": wave(ROOT + "W2025/01_Data/CCPB_CSAT2025_Data.xlsx"),
         "2026": wave(ROOT + "W2026/02 Data/CCPB_CSAT_2026.xlsx")}
print("waves:", waves)

out = {
    "centre": CENTRE, "n": int(len(y)), "n_det": int((y == 0).sum()), "cols": cols, "fits": fits,
    "sign": sign, "r2": r2, "symptoms": symptoms, "waves": waves, "control_check": control_check,
    "ratings": [{"key": k, "label": lab, "items": [ITEM[c] for c in items],
                 "missing": sum(missing[c] for c in items)} for k, lab, items in RATING_LEVERS],
    "nested": [{"key": "signage", "label": "Signage condition", "applies": "outlets with Coke signage",
                "items": ["general condition of Coca-Cola signage"]}],
    "coverage": [{"key": k, "label": lab} for k, lab, _ in COVERAGE],
    "ctx": [{"key": c, "levels": levels[c]} for c in ctx],
    "resp": {
        "ctx": {c: [levels[c].index(v) for v in ctx[c]] for c in ctx},
        "rat": [np.round(rat[k].values, 3).tolist() for k, _, _ in RATING_LEVERS],
        "sign_has": has_sign.astype(int).tolist(), "sign_val": sign_val.round(0).astype(int).tolist(),
        "cov": [cov[k].astype(int).tolist() for k, _, _ in COVERAGE],
        "y": y.tolist(),
    },
}
json.dump(out, open("build/model_ccpb_v3.json", "w"))
print("json kb", round(len(json.dumps(out)) / 1024))
