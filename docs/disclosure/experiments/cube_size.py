# Fable 5.1, 4 Sep 2026. Run from the repo root: python3 docs/disclosure/experiments/cube_size.py
# Reads the Karoo integrated demo report and prints the numbers quoted in
# docs/disclosure/DESIGN_aggregate_interactivity_FABLE.md section 1.
import json, re, itertools, collections
p = "examples/integrated_demo/Output/tabs/report/Karoo_Demo_Crosstabs_report.html"
html = open(p, encoding="utf-8").read()
def island(i):
    m = re.search(r'<script[^>]*id="%s"[^>]*>(.*?)</script>' % i, html, re.S); return json.loads(m.group(1))
agg = island("data-agg"); micro = island("data-micro")
n = micro["n"]; bv = micro["banner_vars"]; W = micro["weights"]
ans = micro["answers"]; scores = micro.get("scores", {}); boxes = micro.get("boxes", {}); series = micro.get("series", {})
qs = {q["code"]: q for q in agg["questions"]}
groups = list(bv); k = 5
def r6(x): return round(x, 6)
def block(vs, code):
    q = qs[code]; a = ans.get(code); sc = scores.get(code); bx = boxes.get(code); sr = series.get(code)
    cats = [i for i, r in enumerate(q["rows"]) if r["kind"] == "category"]
    nets = q.get("net_members") or {}
    boxrows = [i for i, r in enumerate(q["rows"]) if r["kind"] == "net" and str(i) not in nets and not (q.get("net_diffs") or {}).get(str(i))] if bx else []
    cells = collections.defaultdict(lambda: {"base": [0,0.0,0.0], "nbase": [0,0.0,0.0], "rows": collections.defaultdict(float),
                                             "nets": collections.defaultdict(float), "boxes": collections.defaultdict(float),
                                             "score": [0,0.0,0.0,0.0,0.0], "series": collections.defaultdict(lambda: [0,0.0,0.0,0.0,0.0])})
    for r in range(n):
        key = tuple(bv[v][r] for v in vs); w = W[r]; c = cells[key]
        av = a[r] if a else None; b = bx[r] if bx else None
        answered = av is not None or (bx is not None and b is not None)
        if answered:
            c["base"][0] += 1; c["base"][1] += w; c["base"][2] += w*w
        if av is not None:
            c["nbase"][0] += 1; c["nbase"][1] += w; c["nbase"][2] += w*w
            vals = av if isinstance(av, list) else [av]
            for x in vals:
                if x in cats: c["rows"][x] += w
            for ni, mem in nets.items():
                if any(x in mem for x in vals): c["nets"][ni] += w
        if bx is not None and b is not None: c["boxes"][b] += w
        if sc and sc[r] is not None:
            s = sc[r]; c["score"][0] += 1; c["score"][1] += w; c["score"][2] += w*w; c["score"][3] += w*s; c["score"][4] += w*s*s
        if sr:
            for ri, vec in sr.items():
                v = vec[r]
                if v is None: continue
                e = c["series"][ri]; e[0] += 1; e[1] += w; e[2] += w*w; e[3] += w*v; e[4] += w*v*v
    # occupancy rule: every occupied cell's answered base >= k
    occ = [c for c in cells.values() if c["base"][0] > 0]
    ok = all(c["base"][0] >= k for c in occ)
    out = {}
    for key, c in cells.items():
        if c["base"][0] == 0: continue
        rec = {"b": [c["base"][0], r6(c["base"][1]), r6(c["base"][2])],
               "r": {str(i): r6(v) for i, v in c["rows"].items()}}
        if c["nbase"] != c["base"]: rec["nb"] = [c["nbase"][0], r6(c["nbase"][1]), r6(c["nbase"][2])]
        if c["nets"]: rec["n"] = {i: r6(v) for i, v in c["nets"].items()}
        if c["boxes"]: rec["x"] = {str(i): r6(v) for i, v in c["boxes"].items()}
        if c["score"][0]: rec["s"] = [c["score"][0]] + [r6(v) for v in c["score"][1:]]
        if c["series"]: rec["sr"] = {i: [e[0]] + [r6(v) for v in e[1:]] for i, e in c["series"].items()}
        out["|".join(map(str, key))] = rec
    return ok, out
for maxorder in (1, 2, 3):
    cube = {}; shipped = 0; refused = 0
    for order in range(1, maxorder + 1):
        for vs in itertools.combinations(groups, order):
            sid = "*".join(vs); cube[sid] = {}
            for code in ans:
                ok, blk = block(vs, code)
                if ok: cube[sid][code] = blk; shipped += 1
                else: cube[sid][code] = None; refused += 1
    js = json.dumps(cube, separators=(",", ":"))
    print(f"orders 1..{maxorder}: blocks shipped {shipped}, refused {refused}, JSON bytes {len(js):,}")
print("micro island bytes", len(json.dumps(micro, separators=(',', ':'))))
print("scores keys", list(scores), "boxes keys", list(boxes), "series keys", list(series))
