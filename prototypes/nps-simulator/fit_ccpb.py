"""Throwaway prototype fit for a CCPB CSAT 2026 NPS driver simulator.

Outcome: promoter (Q79 9-10) versus everyone else. Only 17 of 753 outlets are
detractors, too few to model as their own class. Levers are 1-10 ratings;
overlapping items are averaged into one lever. Context enters the model only if
it improves cross-validated fit. Writes model_ccpb.json for template_ccpb.html.
"""
import json
import warnings

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold, cross_val_predict

warnings.filterwarnings("ignore")
ROOT = "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/CCPB/CSAT/W2026/"
d = pd.read_excel(ROOT + "02 Data/CCPB_CSAT_2026.xlsx", keep_default_na=False, na_values=[""])
q79 = pd.to_numeric(d.Q79, errors="coerce")
assert q79.notna().all(), "Q79 has missing values"
y = (q79 >= 9).astype(int).values

LEVERS = [
    ("ordering", "Ease of ordering", ["Q02"]),
    ("delivery", "Delivery", ["Q08", "Q09", "Q10"]),
    ("invoicing", "Invoicing", ["Q13"]),
    ("merch", "Merchandising", ["Q22"]),
    ("rep", "Sales rep", ["Q27", "Q28", "Q202"]),
]
ITEM_LABEL = {"Q02": "ease of placing orders", "Q08": "delivery overall", "Q09": "product condition",
              "Q10": "delivery team", "Q13": "invoicing", "Q22": "merchandising", "Q27": "rep overall",
              "Q28": "rep handles complaints", "Q202": "rep helps with coolers and signage"}
raw = d[[c for _, _, items in LEVERS for c in items]].apply(pd.to_numeric, errors="coerce")
missing = {c: int(raw[c].isna().sum()) for c in raw}
raw = raw.fillna(raw.median())
L = pd.DataFrame({k: raw[items].mean(axis=1) for k, _, items in LEVERS})
CENTRE = 8.0
Xr = L.values - CENTRE

# context: labelled, sparse levels collapsed
opt = pd.read_excel(ROOT + "CCPB_CSAT_W2026_Survey_Structure short.xlsx", "Options", header=None,
                    keep_default_na=False, na_values=[""])
h = opt.index[opt.iloc[:, 0].astype(str).eq("QuestionCode")][0]
opt.columns = opt.iloc[h]
opt = opt.iloc[h + 1:]
chan_lab = {int(r.OptionText): str(r.DisplayText).split("-", 1)[1].strip()
            for r in opt[opt.QuestionCode == "S09"].itertuples()}
centre_lab = {str(r.OptionText).strip(): str(r.DisplayText).strip() for r in opt[opt.QuestionCode == "S01"].itertuples()}
ctx = pd.DataFrame({
    "channel": d.S09.map(lambda v: chan_lab.get(int(v), str(v))),
    "size": d.S04.astype(str).str.replace(r"^\d\.", "", regex=True),
    "method": d.S11.astype(str),
    "centre": d.S01.astype(str).str.strip().map(lambda v: centre_lab.get(v, v)),
    "office": d.S05.astype(str),
})
print("missing context:", ctx.isna().sum().to_dict())
ctx = ctx.fillna("Unknown")
for c, other in [("channel", "Other channels"), ("office", "Other offices")]:
    vc = ctx[c].value_counts()
    ctx[c] = ctx[c].where(ctx[c].map(vc) >= 30, other)
levels = {c: [v for v in ctx[c].value_counts().index] for c in ctx}

cv = StratifiedKFold(5, shuffle=True, random_state=1)
base = y.mean()
ll0 = np.mean(np.log(np.where(y == 1, base, 1 - base)))


def cv_r2(X):
    p = cross_val_predict(LogisticRegression(max_iter=5000), X, y, cv=cv, method="predict_proba")[:, 1]
    return round(float(1 - np.mean(np.log(np.where(y == 1, p, 1 - p))) / ll0), 3)


Xc = pd.get_dummies(ctx, drop_first=True).astype(float).values
r2 = {"context_only": cv_r2(Xc), "ratings_only": cv_r2(Xr), "hybrid": cv_r2(np.hstack([Xc, Xr]))}
use_context = r2["hybrid"] > r2["ratings_only"]
print("cv pseudo-R2", r2, "-> context in model:", use_context)
assert not use_context, "prototype page assumes a ratings-only model"

m = LogisticRegression(max_iter=5000).fit(Xr, y)
fits = [{"b0": float(m.intercept_[0]), "B": m.coef_[0].tolist()}]
rng = np.random.default_rng(20260923)
for _ in range(200):
    i = rng.integers(0, len(y), len(y))
    mb = LogisticRegression(max_iter=5000).fit(Xr[i], y[i])
    fits.append({"b0": float(mb.intercept_[0]), "B": mb.coef_[0].tolist()})
B = np.array([f["B"] for f in fits[1:]])
sign = [{"lever": k, "coef": round(fits[0]["B"][j], 3), "share_negative": round(float((B[:, j] < 0).mean()), 3)}
        for j, (k, _, _) in enumerate(LEVERS)]
print("sign check", sign)
print("promoter share actual", round(base, 3), "model", round(float(m.predict_proba(Xr)[:, 1].mean()), 3))

out = {
    "levers": [{"key": k, "label": lab, "items": [ITEM_LABEL[c] for c in items],
                "missing": sum(missing[c] for c in items)} for k, lab, items in LEVERS],
    "ctx": [{"key": c, "levels": levels[c]} for c in ctx],
    "centre": CENTRE, "fits": fits, "sign": sign, "r2": r2, "n": int(len(y)),
    "n_det": int((q79 <= 6).sum()),
    "resp": {"ctx": {c: [levels[c].index(v) for v in ctx[c]] for c in ctx},
             "lev": [np.round(L[k].values, 3).tolist() for k, _, _ in LEVERS],
             "q79": q79.astype(int).tolist()},
}
json.dump(out, open("build/model_ccpb.json", "w"))
print("json kb", round(len(json.dumps(out)) / 1024))
