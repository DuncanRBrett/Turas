"""CCPB 2026 main study (outlet CSAT): the What if study definition.

Outcome Q79, recommending CCPB as a distributor (0 to 10). Levers follow
fit_ccpb_v3.py: five service ratings on 1 to 10 (overlapping questions averaged),
signage condition nested among outlets with Coke signage, and four coverage
levers. Run: python3 study_ccpb.py, then python3 build.py.
"""
import numpy as np
import pandas as pd

import whatif_engine

# CCPB CSAT reports run unweighted (apply_weighting FALSE in its crosstab config).


def build_spec():
    """Load the data and return the study spec for whatif_engine.run()."""
    ROOT = "/Users/duncan/Library/CloudStorage/OneDrive-Personal/DB Files/TurasProjects/CCPB/CSAT/W2026/"
    d = pd.read_excel(ROOT + "02 Data/CCPB_CSAT_2026.xlsx", keep_default_na=False, na_values=[""])
    q79 = pd.to_numeric(d.Q79, errors="coerce")
    assert q79.notna().all()
    num = lambda c: pd.to_numeric(d[c], errors="coerce")

    RATINGS = [("ordering", "Ease of ordering", ["Q02"], ""),
               ("delivery", "Delivery", ["Q08", "Q09", "Q10"], "average of delivery overall, product condition, delivery team"),
               ("invoicing", "Invoicing", ["Q13"], ""),
               ("merch", "Merchandising", ["Q22"], ""),
               ("rep", "Sales rep", ["Q27", "Q28", "Q202"], "average of rep overall, complaints, help with coolers and signage")]
    levers = []
    for key, label, items, sub in RATINGS:
        raw = d[items].apply(pd.to_numeric, errors="coerce")
        miss = int(raw.isna().sum().sum())
        levers.append({"key": key, "label": label, "kind": "rating", "sub": sub, "missing": miss,
                       "values": raw.fillna(raw.median()).mean(axis=1).values})
    sign_r = num("Q42")
    levers.append({"key": "signage", "label": "Signage condition", "kind": "nested", "has_label": "Has Coke signage",
                   "sub": "only outlets with Coke signage", "has": sign_r.notna().values, "values": sign_r.fillna(8).values})
    COVER = [("coolers", "Has Coca-Cola coolers", d.Q43.eq("Yes")),
             ("mgr", "Knows its CCPB sales manager", d.Q33.eq("Yes")),
             ("ccpbmerch", "CCPB does the merchandising", d.Q16.isin(["CCPB sales person / rep", "CCPB merchandiser"])),
             ("promo", "Offered a promotion in last 3 months", d.Q29.eq("Yes"))]
    for key, label, flag in COVER:
        levers.append({"key": key, "label": label, "kind": "coverage", "values": flag.astype(int).values})

    # context, labelled from the survey structure
    opt = pd.read_excel(ROOT + "CCPB_CSAT_W2026_Survey_Structure short.xlsx", "Options", header=None,
                        keep_default_na=False, na_values=[""])
    h = opt.index[opt.iloc[:, 0].astype(str).eq("QuestionCode")][0]
    opt.columns = opt.iloc[h]
    opt = opt.iloc[h + 1:]
    chan_lab = {int(r.OptionText): str(r.DisplayText).split("-", 1)[1].strip() for r in opt[opt.QuestionCode == "S09"].itertuples()}
    centre_lab = {str(r.OptionText).strip(): str(r.DisplayText).strip() for r in opt[opt.QuestionCode == "S01"].itertuples()}
    channel = d.S09.map(lambda v: chan_lab.get(int(v), str(v)))
    channel = channel.where(channel.map(channel.value_counts()) >= 30, "Other channels")
    office = d.S05.astype(str)
    office = office.where(office.map(office.value_counts()) >= 30, "Other offices")
    context = {
        "centre": ("Centre", d.S01.astype(str).str.strip().map(lambda v: centre_lab.get(v, v))),
        "office": ("Sales office", office),
        "method": ("Sales method", d.S11.astype(str)),
        "size": ("Outlet size", d.S04.astype(str).str.replace(r"^\d\.", "", regex=True)),
        "channel": ("Channel", channel),
        "coolers": ("Coolers", d.Q43.map(lambda v: "Has coolers" if v == "Yes" else "No coolers")),
        "mgr": ("Sales manager", d.Q33.map(lambda v: "Knows the sales manager" if v == "Yes" else "Does not know the sales manager")),
        "merch": ("Merchandising by", d.Q16.map(lambda v: "CCPB" if v in ("CCPB sales person / rep", "CCPB merchandiser")
                                                 else "Own staff" if v == "Yourself / own staff" else "Someone else or nobody")),
    }

    return {
        "id": "ccpb", "unit": "outlet", "units": "outlets", "min_group": 5, "reliability_floor": 30,
        "y": np.where(q79 >= 9, 2, np.where(q79 <= 6, 0, 1)), "weights": None,
        "meta": {"title": "CCPB Main Study 2026", "brand": "CCPB",
                 "outcome": "Would you recommend Coca-Cola Peninsula Beverages as a distributor? (Q79)"},
        "scale": {"min": 1, "max": 10, "centre": 8, "good": 8, "labels": None, "step": "point"},
        "levers": levers, "context": context,
        "profile": {"keys": ["size", "channel", "method", "centre", "office", "coolers", "mgr", "merch"],
                    "sentence": [["", "A "], ["size", "lower"], ["", " "], ["channel", ""], ["", " on "], ["method", ""],
                                 ["", ", in "], ["centre", ""], ["", ", served from "], ["office", ""], ["", ". It "],
                                 ["coolers", "lower"], ["", ", "], ["mgr", "lower"], ["", ", and its merchandising is done by "],
                                 ["merch", "lower"], ["", "."]]},
        "crossings": [("centre", "channel"), ("centre", "size"), ("channel", "size"), ("office", "channel"), ("method", "size"),
                      ("centre", "coolers"), ("channel", "coolers"), ("size", "coolers"), ("channel", "mgr"), ("channel", "merch")],
        "bundles": [("Service basics", "Delivery, sales rep and ease of ordering each one point up",
                     {"delivery": "up1", "rep": "up1", "ordering": "up1"}),
                    ("Coverage push", "Coolers and a known sales manager extended to every outlet without them",
                     {"coolers": "extend", "mgr": "extend"})],
        "symptoms": [("Called CCPB in the last 12 months", ~d.Q35.isin(["Never", "More than 12 months"]),
                      "Outlets call when something has gone wrong, so calling is a sign of a problem, not a cause."),
                     ("Shops around for suppliers", d.Q05.isin(["Sometimes shop around", "Always shop around"]),
                      "Shopping around is itself a measure of loyalty; it moves with the outcome rather than driving it.")],
        "notes": ["Ratings average about 9 out of 10, so most outlets have little room to improve and more room to slip. Each area's effect rests on the minority who scored lower.",
                  "Overlapping questions are averaged into one area: the three rep questions correlate at about 0.8, and entered separately one came out with the wrong sign.",
                  "Coverage effects may partly reflect which outlets CCPB chose to serve. Adding size and channel as controls barely moved them.",
                  "Missing ratings (not asked or not answered) were set to the middle score for that question."],
    }


if __name__ == "__main__":
    whatif_engine.run(build_spec())
