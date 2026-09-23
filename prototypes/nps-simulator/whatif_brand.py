"""Brand What if: fit and data for one category of a brand study (IPK Baking Mixes).

The unit is a person-brand pair. Levers are links between a brand and a category
entry point or an image attribute. Outcome: attitude in three ordered levels,
committed (love it, one of my preferred) > conditional (only if the price is
right, only if nothing else) > avoid; "no opinion" is kept for the mental
availability measures but left out of the model. The lever model has a baseline
per brand and past purchase (12 months) as a baseline, so link effects are the
halo-corrected ones from ipk_feasibility.py. Bootstrap refits resample people.

A shopper model per brand (age, race, region, income, bought the brand) drives
the Economist-style line. The sample is an anonymous panel, so the page runs in
open mode only and carries person-level rows: INTERNAL ONLY.

Writes build/whatif_brand_ipk_bak.json. Run: python3 whatif_brand.py
"""
import json
import pathlib
import re
import warnings

import numpy as np
import pandas as pd

import whatif_engine as E

warnings.filterwarnings("ignore")
HERE = pathlib.Path(__file__).parent
CAT, CAT_LABEL, FOCAL = "BAK", "Baking Mixes", "IPK"
ROOT = "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/"
N_BOOT, LINK_PENALTY, PROFILE_PENALTY = 100, 1.0, 5.0
NEGATIVE = {"ATT10"}  # "Is an expensive brand": a link that should count against a brand
REGION_GROUP = {"Cape Town Metro": "Western Cape", "Stellenbosch & Winelands": "Western Cape",
                "George & Garden Route": "Western Cape", "Gauteng Metro": "Gauteng"}
rng = np.random.default_rng(20260923)

d = pd.read_excel(ROOT + "8844718_data.xlsx", keep_default_na=False, na_values=[""])
d = d[d.hv_focal_cat.eq(CAT)].reset_index(drop=True)
NP = len(d)
x = pd.ExcelFile(ROOT + "8844718_Survey_Structure_Brand.xlsx")


def sheet(name):
    s = pd.read_excel(x, name, header=None, keep_default_na=False, na_values=[""]).dropna(how="all")
    h = s.index[s.iloc[:, 0].astype(str).eq("Category")][0]
    s.columns = s.loc[h]
    return s.loc[h + 1:].iloc[1:]


br = sheet("Brands")
br = br[(br.CategoryCode == CAT) & (br.BrandCode != "NONE")]
brands = [{"code": r.BrandCode, "label": str(r.BrandLabel).strip(), "colour": str(r.Colour)} for r in br.itertuples()]
BC = [b["code"] for b in brands]
ceps = sheet("CEPs")
ceps = ceps[ceps.CategoryCode == CAT]
attrs = sheet("Attributes")
attrs = attrs[attrs.CategoryCode == CAT]

# Column families differ by category (see PLAN.md); this category uses these two.
levers = []
for r in ceps.itertuples():
    n = int(str(r.CEPCode)[3:])
    levers.append({"key": r.CEPCode, "label": str(r.CEPText).strip(), "kind": "cep", "dir": 1,
                   "rx": rf"BRANDCEP_{CAT}{n:02d}_\d+$"})
for r in attrs.itertuples():
    n = int(str(r.AttrCode)[3:])
    levers.append({"key": r.AttrCode, "label": str(r.AttrText).strip(), "kind": "attr",
                   "dir": -1 if r.AttrCode in NEGATIVE else 1, "rx": rf"BRANDATTR_{CAT}_ATT{n:02d}_\d+$"})
for lv in levers:
    lv["cols"] = [c for c in d.columns if re.match(lv["rx"], c)]
    assert lv["cols"], f"no data columns for {lv['key']}"
L = len(levers)


def has(cols, b):
    return d[cols].eq(b).any(axis=1).values


# person-brand rows, all of them (no-opinion kept for mental availability)
rows = []
for bi, b in enumerate(BC):
    att = pd.to_numeric(d[f"BRANDATT1_{CAT}_{b}"], errors="coerce").values
    y = np.where(np.isin(att, [1, 2]), 2, np.where(np.isin(att, [3, 4]), 1, np.where(att == 5, 0, -1)))
    bought = has([c for c in d.columns if re.match(rf"BRANDPEN1_{CAT}_\d+$", c)], b).astype(int)
    links = np.column_stack([has(lv["cols"], b) for lv in levers]).astype(int)
    for i in range(NP):
        rows.append((i, bi, int(y[i]), int(bought[i]), links[i]))
R_resp = np.array([r[0] for r in rows])
R_brand = np.array([r[1] for r in rows])
R_y = np.array([r[2] for r in rows])
R_bought = np.array([r[3] for r in rows])
R_links = np.array([r[4] for r in rows])

# check against the brand report's own mental availability numbers
cep_idx = [j for j, lv in enumerate(levers) if lv["kind"] == "cep"]
for b, expect in [("IPK", (60, 5.42))]:
    m = R_brand == BC.index(b)
    k = R_links[m][:, cep_idx].sum(1)
    got = (round(100 * (k > 0).mean()), round(k[k > 0].mean(), 2))
    print(f"check {b}: mental penetration {got[0]}%, network size {got[1]} (brand report: {expect[0]}%, {expect[1]})")
    assert got == expect, "data reading does not match the brand report"

# ---- lever model: brand baselines (first brand is the reference) + links + bought
fitm = R_y >= 0
BD = np.column_stack([(R_brand == bi).astype(float) for bi in range(1, len(BC))])
X = np.column_stack([BD, R_links, R_bought]).astype(float)
Xf, yf, rf = X[fitm], R_y[fitm], R_resp[fitm]
w1 = np.ones(len(yf))
main = E.ord_fit(Xf, yf, w1, penalty=LINK_PENALTY)
fits = [main]
people = np.arange(NP)
for _ in range(N_BOOT):
    pick = rng.choice(people, NP)
    idx = np.concatenate([np.where(rf == p)[0] for p in pick])
    fits.append(E.ord_fit(Xf[idx], yf[idx], w1[idx], penalty=LINK_PENALTY, start=main["_t"]))
nbd = BD.shape[1]
sign = {}
for j, lv in enumerate(levers):
    col = nbd + j
    wrong = np.mean([(f["b"][col] * lv["dir"]) < 0 for f in fits[1:]])
    sign[lv["key"]] = round(float(wrong), 3)
print("share of refits pointing the wrong way:", {k: v for k, v in sign.items() if v > 0.10})

# ---- shopper model per brand: who the person is -> attitude to that brand
d["region3"] = d.Region.map(lambda v: REGION_GROUP.get(v, "Rest of SA"))
PROF = [("age", "Age", d.AGE.astype(str)), ("race", "Race", d.RACE.astype(str)),
        ("region", "Region", d.region3), ("income", "Household income", d.Income.astype(str))]
plevels = {k: list(v.value_counts().index) for k, _, v in PROF}
PX = np.column_stack([(v == lvl).values.astype(float) for k, _, v in PROF for lvl in plevels[k][1:]])
pcols = [(k, lvl) for k, _, v in PROF for lvl in plevels[k][1:]]
profile = {}
for bi, b in enumerate(BC):
    m = (R_brand == bi) & fitm
    rr = R_resp[m]
    Xp = np.column_stack([PX[rr], R_bought[m]])
    yb = R_y[m]
    fb = [E.ord_fit(Xp, yb, np.ones(len(yb)), penalty=PROFILE_PENALTY)]
    for _ in range(N_BOOT):
        i = rng.integers(0, len(yb), len(yb))
        fb.append(E.ord_fit(Xp[i], yb[i], np.ones(len(yb)), penalty=PROFILE_PENALTY, start=fb[0]["_t"]))

    def pack(f):
        bb = dict(zip(pcols + [("bought", "yes")], f["b"]))
        out = {k: [0.0] + [round(float(bb[(k, lv)]), 5) for lv in plevels[k][1:]] for k, _, _ in PROF}
        out["bought"] = [0.0, round(float(bb[("bought", "yes")]), 5)]
        return {"b": out, "c1": round(f["c1"], 5), "c2": round(f["c2"], 5)}

    profile[b] = {"n": int(m.sum()), "fits": [pack(f) for f in fb]}

out = {
    "meta": {"title": "IPK Brand Health · Wave 1", "category": CAT_LABEL, "cat": CAT, "focal": FOCAL,
             "client": "ipk", "unit": "baker", "units": "category buyers", "n_people": NP,
             "outcome": "How people feel about each brand: committed (love it, one of my preferred), conditional (only if the price is right, only if nothing else), avoid"},
    "brands": brands,
    "levers": [{"key": lv["key"], "label": lv["label"], "kind": lv["kind"], "dir": lv["dir"]} for lv in levers],
    "rows": {"r": R_resp.tolist(), "b": R_brand.tolist(), "y": R_y.tolist(), "bought": R_bought.tolist(),
             "links": [int("".join(str(v) for v in lk[::-1]), 2) for lk in R_links]},
    "people": {k: [plevels[k].index(x_) for x_ in v] for k, _, v in PROF},
    "profile_keys": [{"key": k, "label": lab, "levels": plevels[k]} for k, lab, _ in PROF],
    "profile": profile, "profile_penalty": PROFILE_PENALTY,
    "fits": [{"b": np.round(f["b"], 5).tolist(), "c1": round(f["c1"], 5), "c2": round(f["c2"], 5)} for f in fits],
    "n_brand_cols": nbd, "sign": sign,
    "evidence": {"cv": [["brand baselines only", 0.081], ["+ number of entry-point links", 0.183],
                        ["+ number of attribute links", 0.177], ["+ every link separately", 0.188],
                        ["+ every link + bought in 12 months", 0.195], ["bought in 12 months alone", 0.141]],
                 "halo": "Allowing for past purchase shrinks a link's effect by about a fifth (entry point 0.276 to 0.225, attribute 0.370 to 0.296). Among people who have not bought a brand, links still predict how they feel about it.",
                 "source": "ipk_feasibility.py, 23 Sep 2026"},
}
(HERE / "build").mkdir(exist_ok=True)
p = HERE / "build" / "whatif_brand_ipk_bak.json"
json.dump(out, open(p, "w"), separators=(",", ":"))
print(f"wrote {p.name}: {len(rows)} person-brand rows, {int(fitm.sum())} with an opinion, {round(p.stat().st_size / 1024)} kb")
