# Fable 5.1, 4 Sep 2026. Run from the repo root: python3 docs/disclosure/experiments/cube_subtract.py
# Reads the Karoo integrated demo report and prints the numbers quoted in
# docs/disclosure/DESIGN_aggregate_interactivity_FABLE.md section 1.
import json, re, collections
p = "examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html"
html = open(p, encoding="utf-8").read()
def island(i):
    m = re.search(r'<script[^>]*id="%s"[^>]*>(.*?)</script>' % i, html, re.S); return json.loads(m.group(1))
agg = island("data-agg"); micro = island("data-micro")
n = micro["n"]; bv = micro["banner_vars"]; ans = micro["answers"]["Q006"]
q = [x for x in agg["questions"] if x["code"] == "Q006"][0]
cats = [i for i, r in enumerate(q["rows"]) if r["kind"] == "category"]
# 3-way slice Region x Age_Group x Segment for Q006: find a sub-k cell
A, B, C = "Region", "Age_Group", "Segment"
cell = collections.defaultdict(lambda: collections.Counter())
for r in range(n):
    if ans[r] is None: continue
    cell[(bv[A][r], bv[B][r], bv[C][r])][ans[r]] += 1
small = [k for k, c in cell.items() if 0 < sum(c.values()) < 5]
k0 = small[0]
print("suppressed cell", k0, "answered", sum(cell[k0].values()), "distribution", dict(cell[k0]))
# recover from the 2-way margin (Region x Age_Group) minus the other Segment cells
margin = collections.Counter()
for r in range(n):
    if ans[r] is None: continue
    if bv[A][r] == k0[0] and bv[B][r] == k0[1]: margin[ans[r]] += 1
rest = collections.Counter()
for k, c in cell.items():
    if k[0] == k0[0] and k[1] == k0[1] and k[2] != k0[2]: rest.update(c)
recovered = {ri: margin[ri] - rest[ri] for ri in set(margin) | set(rest)}
recovered = {k: v for k, v in recovered.items() if v}
print("recovered by subtraction", recovered, "match:", recovered == dict(cell[k0]))
print("cells in that 3-way slice:", len(cell), "sub-k:", len(small))
