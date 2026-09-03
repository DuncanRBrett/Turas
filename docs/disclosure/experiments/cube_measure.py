# Fable 5.1, 4 Sep 2026. Run from the repo root: python3 docs/disclosure/experiments/cube_measure.py
# Reads the Karoo integrated demo report and prints the numbers quoted in
# docs/disclosure/DESIGN_aggregate_interactivity_FABLE.md section 1.
import json, re, itertools, collections, sys
p = "examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html"
html = open(p, encoding="utf-8").read()
def island(i):
    m = re.search(r'<script[^>]*id="%s"[^>]*>(.*?)</script>' % i, html, re.S)
    return json.loads(m.group(1))
agg = island("data-agg"); micro = island("data-micro")
n = micro["n"]; bv = micro["banner_vars"]; W = micro["weights"]
print("n", n, "banner vars", list(bv), "questions", len(micro["answers"]))
print("distinct weights", len(set(W)), "weighted?", any(w != 1 for w in W))
groups = list(bv)
rows_total = sum(len(q["rows"]) for q in agg["questions"])
print("display rows", rows_total)
k = 5
def cells(vs):
    c = collections.Counter(tuple(bv[v][r] for v in vs) for r in range(n))
    return c
for order in range(1, 5):
    occ = sub = 0; combos = 0; failing = 0
    for vs in itertools.combinations(groups, order):
        c = cells(vs); combos += 1
        occ += len(c); s = sum(1 for v in c.values() if v < k); sub += s
        if s: failing += 1
    print(f"order {order}: combos {combos}, occupied {occ}, under k={k}: {sub}, combos with any sub-k cell: {failing}")
# per-question answered base inside 2-way cells: how many (pair, question) blocks have a sub-k answered cell
ans = micro["answers"]
for order in (2, 3):
    blocks = 0; bad = 0
    for vs in itertools.combinations(groups, order):
        for q, a in ans.items():
            blocks += 1
            c = collections.Counter(tuple(bv[v][r] for v in vs) for r in range(n) if a[r] is not None)
            if any(v < k for v in c.values()): bad += 1
    print(f"order {order}: (combo,question) blocks {blocks}, with a sub-k answered cell {bad}")
