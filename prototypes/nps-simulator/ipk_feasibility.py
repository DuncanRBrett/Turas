"""IPK 2026 feasibility check for a brand What if: one category (Baking Mixes, BAK).

Questions this answers, before any page is built:
1. How much do a brand's links (category entry points, image attributes) explain
   how people feel about it, on held-out people?
2. How much of that is halo? Buyers link the brands they buy to everything, so
   the link effects are re-estimated with past purchase as a baseline, and again
   among people who have not bought the brand.
3. Which links would move IPK, and by how much, with and without the halo
   correction?

Unit: a person-brand pair. Only the 250 people whose focal category is baking
answered the brand questions for it. Outcome: attitude in three ordered levels,
committed (love it, one of my preferred) > conditional (only if the price is
right, only if nothing else) > avoid; "no opinion" is left out. Every model has a
baseline per brand. Cross-validation and the bootstrap resample PEOPLE, not pairs.

Run: python3 ipk_feasibility.py
"""
import re
import warnings

import numpy as np
import pandas as pd

import whatif_engine as E

warnings.filterwarnings("ignore")

CAT = "BAK"
ROOT = "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/IPK/"
rng = np.random.default_rng(20260923)

d = pd.read_excel(ROOT + "8844718_data.xlsx", keep_default_na=False, na_values=[""])
d = d[d.hv_focal_cat.eq(CAT)].reset_index(drop=True)
x = pd.ExcelFile(ROOT + "8844718_Survey_Structure_Brand.xlsx")


def sheet(name):
    s = pd.read_excel(x, name, header=None, keep_default_na=False, na_values=[""]).dropna(how="all")
    h = s.index[s.iloc[:, 0].astype(str).eq("Category")][0]
    s.columns = s.loc[h]
    return s.loc[h + 1:].iloc[1:]  # skip the [REQUIRED] help row


brands = sheet("Brands")
brands = brands[(brands.CategoryCode == CAT) & (brands.BrandCode != "NONE")]
BRAND = dict(zip(brands.BrandCode, brands.BrandLabel))
ceps = sheet("CEPs")
CEP = {r.CEPCode: str(r.CEPText).strip() for r in ceps[ceps.CategoryCode == CAT].itertuples()}
attrs = sheet("Attributes")
ATTR = {r.AttrCode: str(r.AttrText).strip() for r in attrs[attrs.CategoryCode == CAT].itertuples()}

# data columns: BRANDCEP_BAK01_<slot> ... hold the brand code when linked
cep_nums = sorted({int(m.group(1)) for c in d.columns if (m := re.match(rf"BRANDCEP_{CAT}(\d+)_\d+$", c))})
att_nums = sorted({int(m.group(1)) for c in d.columns if (m := re.match(rf"BRANDATTR_{CAT}_ATT(\d+)_\d+$", c))})
cep_codes = sorted(CEP)  # CEP01..CEP14 without CEP07: the data numbers them 1..13 in display order
assert len(cep_codes) == len(cep_nums), (cep_codes, cep_nums)
cep_label = {n: CEP[c] for n, c in zip(cep_nums, cep_codes)}
att_label = {n: ATTR[f"ATT{n:02d}"] for n in att_nums}


def linked(prefix_regex, brand):
    cols = [c for c in d.columns if re.match(prefix_regex, c)]
    return d[cols].eq(brand).any(axis=1).values.astype(float)


rows = []
for b in BRAND:
    att = pd.to_numeric(d[f"BRANDATT1_{CAT}_{b}"], errors="coerce")
    rec = pd.DataFrame({"resp": np.arange(len(d)), "brand": b, "att": att.values})
    rec["aware"] = linked(rf"BRANDAWARE_{CAT}_\d+$", b)
    rec["bought12"] = linked(rf"BRANDPEN1_{CAT}_\d+$", b)
    rec["bought3"] = linked(rf"BRANDPEN2_{CAT}_\d+$", b)
    for n in cep_nums:
        rec[f"cep{n}"] = linked(rf"BRANDCEP_{CAT}{n:02d}_\d+$", b)
    for n in att_nums:
        rec[f"att{n}"] = linked(rf"BRANDATTR_{CAT}_ATT{n:02d}_\d+$", b)
    rows.append(rec)
P = pd.concat(rows, ignore_index=True)
CEPC, ATTC = [f"cep{n}" for n in cep_nums], [f"att{n}" for n in att_nums]
# how many links each person ticked across all brands: their tendency to tick
P["tick_rate"] = P.groupby("resp")[CEPC + ATTC].transform("sum").sum(axis=1) / len(BRAND)
P = P[P.att.between(1, 5)].reset_index(drop=True)          # "no opinion" (6) and blanks out
P["y"] = np.select([P.att.isin([1, 2]), P.att.isin([3, 4])], [2, 1], 0)
print(f"Baking Mixes: {d.shape[0]} people, {len(BRAND)} brands, {len(P)} person-brand pairs with an opinion; "
      f"committed {int((P.y == 2).sum())}, conditional {int((P.y == 1).sum())}, avoid {int((P.y == 0).sum())}")
print(f"links available: {len(CEPC)} entry points, {len(ATTC)} attributes")

bd = pd.get_dummies(P.brand, drop_first=True).astype(float).values
y, w = P.y.values, np.ones(len(P))
resp = P.resp.values


def design(extra):
    return np.column_stack([bd] + [P[c].values for c in extra])


def cv(Xm, pen=1.0, folds=5):
    people = rng.permutation(np.unique(resp))
    Pr = np.zeros((len(y), 3))
    for q in range(folds):
        te = np.isin(resp, people[q::folds])
        fit = E.ord_fit(Xm[~te], y[~te], w[~te], penalty=pen)
        Pr[te] = E.probs(fit, Xm[te] @ fit["b"])
    base = np.array([(y == c).mean() for c in range(3)])
    return 1 - np.mean(np.log(np.clip(Pr[np.arange(len(y)), y], 1e-12, 1))) / np.mean(np.log(base[y]))


print("\n1. Held-out fit (pseudo R squared; people held out, not pairs):")
P["n_cep"], P["n_att"] = P[CEPC].sum(axis=1), P[ATTC].sum(axis=1)
specs = [("brand baselines only", []),
         ("+ number of entry-point links", ["n_cep"]),
         ("+ number of attribute links", ["n_att"]),
         ("+ every entry point and attribute", CEPC + ATTC),
         ("+ every link + bought in 12 months", CEPC + ATTC + ["bought12"]),
         ("bought in 12 months alone (+ brand)", ["bought12"])]
for name, cols in specs:
    print(f"   {name:42s} {cv(design(cols)):.3f}")

print("\n2. Halo: the effect of one more link, with and without past purchase as a baseline")
for cols, lab in [(["n_cep"], "entry-point link"), (["n_att"], "attribute link")]:
    b0 = E.ord_fit(design(cols), y, w, penalty=1.0)["b"][-1]
    b1 = E.ord_fit(design(cols + ["bought12"]), y, w, penalty=1.0)["b"][-2]
    b2 = E.ord_fit(design(cols + ["bought12", "tick_rate"]), y, w, penalty=1.0)["b"][-3]
    print(f"   per {lab:17s}: {b0:.3f} alone -> {b1:.3f} with purchase ({100 * (1 - b1 / b0):.0f}% smaller) "
          f"-> {b2:.3f} also allowing for how much each person ticks")
nb = P.bought12.values == 0
Xnb = design(["n_cep", "n_att"])[nb]
fnb = E.ord_fit(Xnb, y[nb], w[nb], penalty=1.0)
print(f"   among pairs where the person has NOT bought the brand in 12 months ({nb.sum()} pairs): "
      f"entry-point link {fnb['b'][-2]:.3f}, attribute link {fnb['b'][-1]:.3f}")

print("\n3. Which links would move IPK: '10 more people in every 100 link IPK to this', change in IPK's committed share")
cols = CEPC + ATTC
X_h, X_c = design(cols), design(cols + ["bought12"])
fits_h = [E.ord_fit(X_h, y, w, penalty=1.0)]
fits_c = [E.ord_fit(X_c, y, w, penalty=1.0)]
people = np.unique(resp)
for _ in range(100):
    pick = rng.choice(people, len(people))
    idx = np.concatenate([np.where(resp == p)[0] for p in pick])
    fits_h.append(E.ord_fit(X_h[idx], y[idx], w[idx], penalty=1.0, start=fits_h[0]["_t"]))
    fits_c.append(E.ord_fit(X_c[idx], y[idx], w[idx], penalty=1.0, start=fits_c[0]["_t"]))
ipk = (P.brand == "IPK").values
nb_ = bd.shape[1]


def lift(fits, Xm, j):
    """Points added to IPK's committed share if 10 more IPK raters in every 100 gained link j.

    The link goes to people who do not have it now; if fewer than 10 in 100 lack it,
    everyone who lacks it gets it.
    """
    X0 = Xm[ipk]
    off = X0[:, nb_ + j] == 0
    reach = min(0.10, off.mean())
    X1 = X0.copy()
    X1[:, nb_ + j] = 1
    out = np.array([100 * reach * np.mean((E.probs(f, X1 @ f["b"])[:, 2] - E.probs(f, X0 @ f["b"])[:, 2])[off])
                    if off.any() else 0.0 for f in fits])
    return out[0], np.percentile(out[1:], 5), np.percentile(out[1:], 95)


labels = [f"Entry point: {cep_label[n]}" for n in cep_nums] + [f"Attribute: {att_label[n]}" for n in att_nums]
share = [P.loc[ipk, c].mean() for c in cols]
cat_share = [P.groupby("brand")[c].mean().mean() for c in cols]
res = []
for j, lab in enumerate(labels):
    h = lift(fits_h, X_h, j)
    c = lift(fits_c, X_c, j)
    res.append((lab, share[j], cat_share[j], h, c))
res.sort(key=lambda r: -r[4][0])
print(f"   {'link':72s} {'IPK has':>7s} {'avg brand':>9s} {'no correction':>21s} {'purchase as baseline':>24s}")
for lab, s, cs, h, c in res:
    print(f"   {lab[:72]:72s} {100 * s:6.0f}% {100 * cs:8.0f}% {h[0]:+6.1f} ({h[1]:+.1f},{h[2]:+.1f}) {c[0]:+9.1f} ({c[1]:+.1f},{c[2]:+.1f})")
print(f"\n   IPK: {int(ipk.sum())} people with an opinion; committed now {100 * (P.y[ipk] == 2).mean():.0f}%; bought in 12 months {100 * P.bought12[ipk].mean():.0f}%")

print("\n4. Mental availability as the lever: what if every IPK rater linked IPK to one more entry point (or attribute)?")
Xk = design(["n_cep", "n_att", "bought12"])
fk = [E.ord_fit(Xk, y, w, penalty=1.0)]
for _ in range(100):
    pick = rng.choice(people, len(people))
    idx = np.concatenate([np.where(resp == p)[0] for p in pick])
    fk.append(E.ord_fit(Xk[idx], y[idx], w[idx], penalty=1.0, start=fk[0]["_t"]))
for j, lab, cap in [(0, "entry point", len(CEPC)), (1, "attribute", len(ATTC))]:
    X0 = Xk[ipk]
    X1 = X0.copy()
    X1[:, nb_ + j] = np.minimum(X1[:, nb_ + j] + 1, cap)
    g = np.array([100 * np.mean(E.probs(f, X1 @ f["b"])[:, 2] - E.probs(f, X0 @ f["b"])[:, 2]) for f in fk])
    print(f"   one more {lab:11s} link each: IPK committed share {g[0]:+.1f} points (90% range {np.percentile(g[1:], 5):+.1f} to {np.percentile(g[1:], 95):+.1f}), with purchase as a baseline")
print(f"   IPK now averages {P.loc[ipk, 'n_cep'].mean():.1f} entry-point and {P.loc[ipk, 'n_att'].mean():.1f} attribute links per rater; "
      f"the average brand {P.groupby('brand').n_cep.mean().mean():.1f} and {P.groupby('brand').n_att.mean().mean():.1f}")
