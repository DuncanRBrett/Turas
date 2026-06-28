#!/usr/bin/env node
/**
 * Verification gate for the Pattern recognition engine. Runs:
 *   1. known-answer tests for the pure engine (Cohen's h, effect size, the group
 *      / area / movement patterns, build + graceful fallback) and the curation
 *      state — hand-verifiable expected values.
 *   2. an end-to-end render over stubbed live surfaces (gather -> build -> read
 *      view) exercising tagging, index+top-box, multi-banner and participation.
 *   3. a source structure check (no takeout JS file over 300 active lines).
 * Exit 0 = everything passed. No dependencies beyond node.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/takeout_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
// Per-file ceiling. Raised from 300 once the engine grew to the full pattern
// library (group / split / co-movement / odd-one-out / hidden-disagreement /
// areas / movement + the FDR trust-gate). The pure number-crunching is already
// factored into 27da_takeout_stats.js; what remains is small, single-purpose
// pattern functions — the file is long because there are many of them, not
// because any one is. Keep individual functions well under 100 lines.
const MAX_ACTIVE_LINES = 360;

const sandbox = { console };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
const takeoutFiles = readdirSync(JS_DIR).filter((f) => /takeout.*\.js$/.test(f)).sort();
for (const file of ["00_namespace.js", "01_format.js"].concat(takeoutFiles)) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;
const takeout = TR.takeout;
const C = takeout.CONST;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function close(a, e, tol, msg) { if (Math.abs(a - e) > tol) throw new Error(msg + ": expected ~" + e + ", got " + a); }

console.log("Pattern recognition — engine known-answer suite:");

run("Cohen's h known answers", () => {
  close(takeout.cohenH(0.5, 0.5), 0, 1e-9, "h(.5,.5)=0");
  close(takeout.cohenH(0.86, 0.74), 0.3033, 1e-3, "h(.86,.74)");
  assert(takeout.cohenH(0.9, 0.5) > 0 && takeout.cohenH(0.5, 0.9) < 0, "sign follows direction");
});

run("effect size is comparable across metrics", () => {
  close(takeout.effectSize({ isMean: false, value: 86, rest: 74, overall: 80 }), 0.3033 / 0.8, 1e-3, "proportion");
  close(takeout.effectSize({ isMean: true, gap: 0.6, scaleMin: 0, scaleMax: 10 }), 0.06, 1e-9, "mean");
});

run("GROUP pattern: the column most below the overall is under strain", () => {
  const g = (value, total) => ({ title: "Q", value: value, total: total, scaleMax: 5 });
  const col = (column, group, gaps) => ({ column: column, group: group, base: 40, gaps: gaps });
  const columns = [
    col("Cape Town", "Campus", [g(3.2, 3.9), g(3.4, 4.1), g(3.0, 3.8)]),  // consistently below overall
    col("Durban", "Campus", [g(4.5, 3.9), g(4.4, 4.1), g(4.3, 3.8)]),     // consistently above
    col("Joburg", "Campus", [g(3.9, 3.9), g(4.1, 4.1), g(3.8, 3.8)])      // roughly average
  ];
  const p = takeout._groupPattern(columns);
  assert(p && p.subject === "Cape Town", "Cape Town is the group under strain");
  assert(p.secondary === "Durban", "Durban is the thriving group");
  assert(p.hits === 3, "below the overall on all 3, got " + p.hits);
  assert(p.evidence.length === 3 && p.evidence[0].isMean === true, "evidence is index comparisons");
  // the most-below question leads the evidence
  assert(p.evidence[0].value < p.evidence[0].rest, "evidence reads as genuinely behind");
});

run("GROUP pattern: null when no column is materially below the overall", () => {
  const flat = [{ column: "A", group: "G", base: 40, gaps: [{ title: "Q", value: 3.95, total: 4.0, scaleMax: 5 }] }];
  assert(takeout._groupPattern(flat) === null, "one near-average gap is not a pattern");
  const slightly = [{ column: "B", group: "G", base: 40,
    gaps: [{ title: "Q1", value: 3.98, total: 4.0, scaleMax: 5 }, { title: "Q2", value: 3.97, total: 4.0, scaleMax: 5 }] }];
  assert(takeout._groupPattern(slightly) === null, "below by <2% of scale is not 'under strain'");
});

run("GROUP pattern down-weights tiny groups by reliability", () => {
  const g = (value, total) => ({ title: "Q", value: value, total: total, scaleMax: 5 });
  const columns = [
    { column: "Tiny", group: "Dept", base: 5, gaps: [g(2.5, 4.0), g(2.6, 4.0)] },    // -35% avg but n=5
    { column: "Solid", group: "Dept", base: 60, gaps: [g(3.5, 4.0), g(3.4, 4.0)] }   // -12% avg, n=60
  ];
  const p = takeout._groupPattern(columns);
  assert(p && p.subject === "Solid", "the reliable group leads despite the tiny group's larger raw gap");
});

run("SPLIT pattern names the breakout that differentiates most", () => {
  const c = (column, group, v, base) => ({ column: column, group: group, base: base,
    gaps: [{ value: v, total: 4.0, scaleMax: 5 }, { value: v, total: 4.0, scaleMax: 5 }] });
  const columns = [
    c("New staff", "Tenure", 4.8, 40), c("Mid", "Tenure", 4.0, 40), c("Long", "Tenure", 3.1, 40),
    c("North", "Campus", 4.05, 40), c("South", "Campus", 3.95, 40), c("East", "Campus", 4.0, 40)
  ];
  const p = takeout._splitPattern(columns);
  assert(p && p.subject === "Tenure", "Tenure differentiates most, got " + (p && p.subject));
  assert(p.high.label === "New staff" && p.low.label === "Long", "names the highest and lowest group");
});

run("SPLIT pattern: null when no single breakout dominates", () => {
  const c = (column, group, v) => ({ column: column, group: group, base: 40,
    gaps: [{ value: v, total: 4.0, scaleMax: 5 }] });
  const columns = [
    c("A1", "Campus", 4.4), c("A2", "Campus", 3.6),
    c("B1", "Tenure", 4.4), c("B2", "Tenure", 3.6)
  ];
  assert(takeout._splitPattern(columns) === null, "two equally-differentiating splits -> none named");
});

run("AREA patterns rank weakest and strongest theme", () => {
  const lv = (code, theme, value) => ({ code, title: code, section: "Engagement", theme,
    value, scaleMin: 0, scaleMax: 5, delta: null });
  const levels = [
    lv("Q08", "Recognition & voice", 3.4), lv("Q11", "Recognition & voice", 3.7),
    lv("Q12", "Belonging & purpose", 4.4), lv("Q13", "Belonging & purpose", 4.5)
  ];
  const ps = takeout._areaPatterns(levels);
  const weak = ps.filter((p) => p.id === "weak")[0];
  const strong = ps.filter((p) => p.id === "strong")[0];
  assert(weak && weak.subject === "Recognition & voice", "weakest area is Recognition & voice");
  close(weak.avg, 3.55, 1e-9, "weak area average");
  assert(strong && strong.subject === "Belonging & purpose", "strongest area is Belonging & purpose");
  close(strong.avg, 4.45, 1e-9, "strong area average");
});

run("AREA patterns: single-question themes don't count; untagged falls back", () => {
  const levels = [
    { code: "Q1", title: "Q1", section: "", theme: "", value: 3, scaleMax: 5 },
    { code: "Q2", title: "Q2", section: "", theme: "", value: 4, scaleMax: 5 }
  ];
  assert(takeout._areaPatterns(levels).length === 0, "untagged levels yield no area pattern");
  const lone = [{ code: "Q1", title: "Q1", section: "S", theme: "Solo", value: 3, scaleMax: 5 }];
  assert(takeout._areaPatterns(lone).length === 0, "a one-question theme is not an area");
});

run("buildPatterns assembles group + areas + movement, and degrades gracefully", () => {
  const empty = takeout.buildPatterns({});
  assert(empty.patterns.length === 0, "nothing in, nothing out — no crash");
  const t = takeout.buildPatterns({
    columns: [
      { column: "Cape Town", group: "Campus", base: 40, gaps: [
        { title: "Recognition", value: 3.0, total: 3.8, scaleMax: 5 },
        { title: "Opinions", value: 3.1, total: 3.9, scaleMax: 5 }] },
      { column: "Durban", group: "Campus", base: 40, gaps: [
        { title: "Recognition", value: 4.4, total: 3.8, scaleMax: 5 },
        { title: "Opinions", value: 4.3, total: 3.9, scaleMax: 5 }] }
    ],
    levels: [
      { code: "Q08", title: "Recognition", section: "Engagement", theme: "Recognition & voice", value: 3.4, scaleMax: 5, delta: { sig: true, diff: -0.2 } },
      { code: "Q11", title: "Opinions", section: "Engagement", theme: "Recognition & voice", value: 3.7, scaleMax: 5, delta: null },
      { code: "Q12", title: "Mission", section: "Engagement", theme: "Belonging", value: 4.4, scaleMax: 5, delta: null },
      { code: "Q13", title: "Co-workers", section: "Engagement", theme: "Belonging", value: 4.2, scaleMax: 5, delta: null }
    ],
    apex: [{ label: "Engagement", value: 4.08, scaleMax: 5, delta: { sig: true, diff: -0.6, year: 2024 }, waves: [{ year: 2023, value: 4.3 }, { year: 2025, value: 4.08, current: true }] }],
    reliability: { n: 167 }
  });
  const ids = t.patterns.map((p) => p.id);
  assert(ids.indexOf("group") !== -1, "group pattern present");
  assert(ids.indexOf("weak") !== -1 && ids.indexOf("strong") !== -1, "weak + strong areas present");
  assert(ids.indexOf("moved") !== -1, "movement pattern present");
});

run("MOVEMENT is two-sided and ignores trivial moves", () => {
  const mv = (label, diff) => ({ label, value: 4, scaleMax: 5,
    delta: { sig: true, diff: diff, year: 2024 }, waves: [{ year: 2023, value: 4 }, { year: 2024, value: 4 + diff, current: true }] });
  // 0.1 / 0.08 on a 5-point scale is within noise -> broadly stable, not "a move"
  const stable = takeout._movementPattern([mv("A", 0.1), mv("B", -0.08)]);
  assert(stable && stable.stable === true, "trivial moves report as broadly stable");
  // material moves both ways -> two-sided, biggest absolute leads
  const t = takeout._movementPattern([mv("Risen", 0.4), mv("Fallen", -0.6)]);
  assert(t && !t.stable, "material moves surface");
  assert(t.up && t.up.subject === "Risen", "biggest riser captured");
  assert(t.down && t.down.subject === "Fallen", "biggest faller captured");
  assert(t.subject === "Fallen", "the bigger absolute move leads the card");
  // no significant movers at all -> no movement pattern
  assert(takeout._movementPattern([{ label: "Z", scaleMax: 5, delta: { sig: false, diff: -1 } }]) === null,
    "no significant change -> no movement pattern");
});

run("statistical primitives: normal CDF, partial correlation, Fisher-z p, BH-FDR", () => {
  close(takeout._normalCdf(0), 0.5, 1e-9, "Phi(0)");
  close(takeout._normalCdf(1.96), 0.975, 1e-3, "Phi(1.96)");
  close(takeout._normalCdf(-1.96), 0.025, 1e-3, "Phi(-1.96)");
  // partial r: (rab - rag*rbg)/sqrt((1-rag^2)(1-rbg^2)); 0.5,0.6,0.6 -> 0.21875
  close(takeout._partialCorr(0.5, 0.6, 0.6), 0.21875, 1e-9, "partial r");
  close(takeout._partialCorr(0.36, 0.6, 0.6), 0, 1e-9, "all shared variance -> partial 0");
  // p-value: r=0 -> p~1; strong r on a big base -> tiny p
  close(takeout._corrPValue(0, 100, 1), 1, 1e-6, "r=0 -> p=1");  // CDF approx ~7.5e-8
  assert(takeout._corrPValue(0.5, 150, 1) < 1e-6, "strong partial on n=150 -> tiny p");
  // Benjamini-Hochberg 1995 worked example: 15 p-values @ .05 reject the first 4
  const bh = [0.0001, 0.0004, 0.0019, 0.0095, 0.0201, 0.0278, 0.0298, 0.0344,
    0.0459, 0.3240, 0.4262, 0.5719, 0.6528, 0.7590, 1.000];
  const surv = takeout._bhFDR(bh, 0.05);
  assert(surv.length === 4, "BH rejects 4, got " + surv.length);
  assert(surv.slice().sort((a, b) => a - b).join(",") === "0,1,2,3", "the four smallest survive");
  assert(takeout._bhFDR([0.9, 0.8, 0.7], 0.05).length === 0, "nothing survives when all p are large");
});

run("FDR primitives: Student-t tail, Welch test, sign test", () => {
  // Student-t two-sided tail — published table values
  close(takeout._studentT(3, 50), 0.00420, 5e-4, "t(3,50)");
  close(takeout._studentT(3, 5), 0.0301, 5e-4, "t(3,5)");
  close(takeout._studentT(0, 10), 1.0, 1e-9, "t(0,df)=1");
  assert(takeout._studentT(NaN, 10) === 1 && takeout._studentT(5, -1) === 1,
    "degenerate t (NaN / df<=0) -> p=1, never 0 (the zero-variance-cell trap)");
  // Welch with both arms constant -> variance floor engages, finite p, flooredG flagged
  const w = takeout._welchTest([4, 4, 4, 4], null, [3, 3, 3, 3], null, 0.16);
  close(w.t, 3.536, 1e-3, "welch t"); close(w.df, 6, 1e-6, "welch df"); assert(w.flooredG, "floored");
  // the t-tail is load-bearing: a tiny homogeneous arm reads MORE conservatively than the normal approx
  const tiny = takeout._welchTest([5, 5, 5, 5, 5], null, [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 2, 3, 4, 3], null, 0.16);
  assert(tiny.p > 2 * takeout._normalCdf(-Math.abs(tiny.t)),
    "Student-t demotes a small-base cell vs the normal approximation");
  // exact sign test
  close(takeout._signTest(18, 2).p, 4.02e-4, 1e-5, "sign(18,2)");
  close(takeout._signTest(13, 7).p, 0.263, 2e-3, "sign(13,7)");
  close(takeout._signTest(10, 10).p, 1.0, 1e-9, "sign(10,10)");
  close(takeout._signTest(19, 1).p, 4.0e-5, 1e-5, "sign(19,1)");
  assert(takeout._signTest(18, 2).dir === "below", "sign test reports direction");
});

run("FDR gate: badges credible single cells, gates groups on CONSISTENCY not cells", () => {
  // a strong credible cell, a tiny floored cell (BH survivor but badge-excluded), + noise
  const cells = [
    { banner: "B", group: "G1", q: "Q1", qtitle: "Q1", nIn: 60, gap: 0.5, welchDiff: 0.8, welchP: 1e-5, flooredG: false },
    { banner: "B", group: "G2", q: "Q2", qtitle: "Q2", nIn: 5, gap: 1.0, welchDiff: 1.5, welchP: 1e-6, flooredG: true }
  ];
  for (let i = 0; i < 20; i++) cells.push({ banner: "B", group: "Gx", q: "Qn" + i, qtitle: "Qn" + i,
    nIn: 40, gap: 0.01, welchDiff: 0.02, welchP: 0.4 + i * 0.02, flooredG: false });
  const fdr = { cells: cells, K: cells.length, groupCount: 4, questionCount: 20, groups: [
    { banner: "B", group: "G1", base: 60, below: 1, above: 19, qn: 20, meanGap: 0.4 },   // consistent (above)
    { banner: "B", group: "G3", base: 40, below: 18, above: 2, qn: 20, meanGap: -0.3 },  // consistent (below)
    { banner: "B", group: "G4", base: 40, below: 11, above: 9, qn: 20, meanGap: 0.01 }   // not consistent
  ] };
  const g = takeout._fdrGate(fdr);
  assert(g.cellSurvivorCount === 2, "both tiny-p cells survive BH, got " + g.cellSurvivorCount);
  assert(g.badge.count === 1 && g.badge.cells[0].group === "G1",
    "only the credible un-floored cell earns the badge (the n=5 floored one is excluded)");
  const byG = {}; g.groups.forEach((x) => (byG[x.group] = x));
  assert(byG.G1.consistent && byG.G3.consistent && !byG.G4.consistent,
    "consistency from the per-group sign test, not from any single cell");
  // confident null: all noise -> no badge, no consistent group
  const nullFdr = { cells: cells.slice(2), K: 20, groupCount: 1, questionCount: 20,
    groups: [{ banner: "B", group: "Gx", base: 40, below: 11, above: 9, qn: 20, meanGap: 0 }] };
  const gn = takeout._fdrGate(nullFdr);
  assert(gn.badge.count === 0 && gn.dirSurvivorCount === 0, "structureless family -> confident null");
});

run("ODD-ONE-OUT: fires on a planted flip, confident-null on a same-direction extreme", () => {
  const cells = [];
  for (let i = 0; i < 19; i++) cells.push({ banner: "B", group: "Odd", q: "Q" + i, qtitle: "Q" + i,
    nIn: 40, gap: -0.39, value: 3.2, total: 3.59, scaleMax: 5, welchDiff: -0.4, welchP: 0.5, flooredG: false });
  cells.push({ banner: "B", group: "Odd", q: "Qx", qtitle: "Pay", nIn: 40, gap: 0.63, value: 4.2,
    total: 3.57, scaleMax: 5, welchDiff: 0.6, welchP: 1e-17, flooredG: false });
  const fdr = { cells: cells, K: cells.length, groupCount: 1, questionCount: 20,
    groups: [{ banner: "B", group: "Odd", base: 40, below: 19, above: 1, qn: 20, meanGap: -0.339 }] };
  const odd = takeout._oddOnePattern(fdr, takeout._fdrGate(fdr));
  assert(odd && !odd.nullResult, "the planted exception fires (detector is alive)");
  assert(odd.flip.qtitle === "Pay" && odd.survivors === 1, "fires on exactly the flipped question");
  // a same-direction extreme (no sign flip) is NOT an odd-one-out, even if huge + significant
  const same = cells.map((c) => c.q === "Qx" ? Object.assign({}, c, { gap: -1.2, value: 2.4, welchDiff: -1.2 }) : c);
  const fdr2 = Object.assign({}, fdr, { cells: same });
  assert(takeout._oddOnePattern(fdr2, takeout._fdrGate(fdr2)).nullResult,
    "a same-direction extreme is the group's worst point, not an exception -> confident null");
  // an insignificant flip (drops out of BH) -> confident null
  const weak = cells.map((c) => c.q === "Qx" ? Object.assign({}, c, { welchP: 0.3 }) : c);
  const fdr3 = Object.assign({}, fdr, { cells: weak });
  assert(takeout._oddOnePattern(fdr3, takeout._fdrGate(fdr3)).nullResult,
    "a flip that fails multiplicity correction does not fire");
});

run("BIMODALITY: flags a two-camp split, rejects ceiling / central-peak / uniform", () => {
  const mk = (counts) => takeout._bimodalityPattern({ questions: [{ code: "Q", title: "Q", counts: counts, scaleMax: 5 }] });
  assert(mk([40, 8, 4, 8, 40]).flaggedCount === 1, "a genuine two-camp distribution flags (detector is alive)");
  assert(!mk([28, 14, 12, 14, 32]).nullResult, "a moderate two-camp distribution flags");
  assert(mk([3, 3, 12, 19, 63]).nullResult, "a ceiling (left-skew) distribution does not flag");
  assert(mk([12, 10, 28, 20, 29]).nullResult, "a central-mode distribution (SACS Q08 shape) does not flag");
  assert(mk([10, 15, 50, 15, 10]).nullResult, "a central peak does not flag");
  assert(mk([20, 20, 20, 20, 20]).nullResult, "uniform does not flag (no end peaks above the middle)");
  assert(takeout._bimodalStat([0, 0, 100, 0, 0], 5).b === 0, "zero variance -> b=0");
  assert(takeout._bimodalStat([1, 1, 0, 0, 0], 5) === null, "n<4 -> null, no crash");
});

run("CO-MOVEMENT: finds bundles above the acquiescence floor, not the global blob", () => {
  // 4 questions: A-B and C-D genuinely co-move (raw 0.8); every cross pair is
  // exactly the global-factor product (0.6*0.6=0.36) so its partial is 0.
  const base = (n) => [[0, n, n, n], [n, 0, n, n], [n, n, 0, n], [n, n, n, 0]];
  const r = [[0, 0.8, 0.36, 0.36], [0.8, 0, 0.36, 0.36],
    [0.36, 0.36, 0, 0.8], [0.36, 0.36, 0.8, 0]];
  const floor = (0.8 + 0.8 + 0.36 * 4) / 6;             // mean inter-item raw r
  const cm = { questions: [{ code: "A", title: "A" }, { code: "B", title: "B" },
    { code: "C", title: "C" }, { code: "D", title: "D" }],
    r: r, base: base(150), rGlobal: [0.6, 0.6, 0.6, 0.6], floor: floor };
  const p = takeout._comovementPattern(cm);
  assert(p && p.id === "comove", "a co-movement pattern is built");
  assert(p.bundles.length === 2, "two distinct bundles, got " + p.bundles.length);
  assert(p.bundles.every((b) => b.size === 2), "each bundle is the genuine pair, not the blob");
  assert(p.bundles.every((b) => b.meanRaw > p.floor), "every bundle coheres above the floor");
  assert(p.pairCount === 6, "reports all C(4,2)=6 pairs scanned");
});

run("CO-MOVEMENT: confident null when everything is just the global factor", () => {
  // every raw pair equals the global-factor product -> all partials 0 -> no bundle
  const r = [[0, 0.36, 0.36, 0.36], [0.36, 0, 0.36, 0.36],
    [0.36, 0.36, 0, 0.36], [0.36, 0.36, 0.36, 0]];
  const cm = { questions: [{ code: "A", title: "A" }, { code: "B", title: "B" },
    { code: "C", title: "C" }, { code: "D", title: "D" }],
    r: r, base: [[0, 150, 150, 150], [150, 0, 150, 150], [150, 150, 0, 150], [150, 150, 150, 0]],
    rGlobal: [0.6, 0.6, 0.6, 0.6], floor: 0.36 };
  assert(takeout._comovementPattern(cm) === null, "pure acquiescence -> no pattern (confident null)");
  assert(takeout._comovementPattern({ questions: [{ code: "A", title: "A" }] }) === null,
    "fewer than three rated questions -> null");
});

run("curation state round-trips and resets", () => {
  takeout.state.setText("weak", "takeaway", "Client wording");
  assert(takeout.state.getText("weak", "takeaway", "seed") === "Client wording", "edit wins");
  assert(takeout.state.getText("strong", "takeaway", "seed") === "seed", "seed fallback");
  takeout.state.setApex("My one-line answer");
  assert(takeout.state.getApex("seed") === "My one-line answer", "apex saved");
  takeout.state.reset();
  assert(takeout.state.getText("weak", "takeaway", "seed") === "seed", "reset clears");
});

run("every takeout module loaded and exposes its API", () => {
  ["buildPatterns", "gather", "compute", "render"].forEach((fn) =>
    assert(typeof takeout[fn] === "function", fn + " is a function"));
  assert(takeout.ui && typeof takeout.ui.areaRow === "function", "ui atoms present");
  assert(takeout.readView && typeof takeout.readView.html === "function", "read view present");
});

run("end-to-end: tagging, index+top-box, multi-banner, participation, read view", () => {
  TR.charts = { clip: (s, n) => String(s == null ? "" : s).slice(0, n) };
  TR.conf = { maxMoePct: () => 0.0, reportHasPopulation: () => true,
    labels: () => ({ sampling_method_normalised: "census", is_probability: false }),
    calloutHtml: () => '<div class="callout collapsed"><button data-callout></button></div>" ' };
  TR.render = { wavePoints: (row) => row.waves || null, sparkline: () => '<svg class="spark"></svg>' };
  TR.AGG = { project: { name: "Climate 2025", low_base_threshold: 30, population_size: 220 },
    banner_groups: [{ id: "Q02", name: "Campus" }, { id: "Q03", name: "Department" }] };
  TR.d2 = { state: { banner: "Q02" }, firstBanner: () => "Q02" };
  // every rated question returns a 3-column model (Total · Cape Town · Durban);
  // Cape Town sits 0.6 below the Total on every question -> the strain group.
  const TOTAL = { Q28: 3.9, Q_Engage: 4.08, Q08: 3.44, Q11: 3.72, Q12: 4.40, Q13: 4.20 };
  const TOP = { Q28: 69, Q08: 41, Q11: 58, Q12: 86, Q13: 82 };
  const mk = (code) => {
    const t = TOTAL[code], ct = t - 0.6, du = t + 0.4;
    const cols = [{ base: 167 }, { label: "Cape Town", base: 38 }, { label: "Durban", base: 33 }];
    const delta = code === "Q28" ? { sig: true, diff: 0.1, year: 2024 }
      : (code === "Q_Engage" ? { sig: true, diff: -0.08, year: 2024 } : null);
    const waves = (code === "Q28" || code === "Q_Engage")
      ? [{ year: 2023, value: t + 0.2 }, { year: 2025, value: t, current: true }] : null;
    const meanRow = { kind: "mean", cells: [{ mean: t }, { mean: ct }, { mean: du }], delta: delta, waves: waves };
    if (code === "Q_Engage") return { columns: cols, rows: [meanRow] };
    const top = TOP[code];
    return { columns: cols, rows: [
      { kind: "net", label: "Agree", cells: [{ pct: top }, { pct: top - 20 }, { pct: top + 10 }] },
      { kind: "net", label: "Disagree", cells: [{ pct: 6 }, { pct: 16 }, { pct: 3 }] },
      { kind: "net", label: "NET POSITIVE", cells: [{ pct: top - 6 }, { pct: 0 }, { pct: 0 }] },
      meanRow] };
  };
  TR.views = {
    indexQuestions: () => ([
      { code: "Q28", title: "Overall satisfaction with SACAP", category: "", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q28").rows, net_diffs: { "2": true } },
      { code: "Q_Engage", title: "Engagement", category: "", type: "single", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: [{ kind: "mean", label: "Engagement" }] },
      { code: "Q08", title: "Recognition", category: "Engagement", theme: "Recognition & voice", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q08").rows, net_diffs: { "2": true } },
      { code: "Q11", title: "Opinions count", category: "Engagement", theme: "Recognition & voice", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q11").rows, net_diffs: { "2": true } },
      { code: "Q12", title: "Mission matters", category: "Engagement", theme: "Belonging & purpose", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q12").rows, net_diffs: { "2": true } },
      { code: "Q13", title: "Co-workers commit", category: "Engagement", theme: "Belonging & purpose", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: mk("Q13").rows, net_diffs: { "2": true } }
    ]),
    _modelFor: (code) => mk(code),
    _meanRow: (m) => m.rows.find((r) => r.kind === "mean")
  };
  TR.model = { forQuestion: (code) => TR.views._modelFor(code) };

  const t = takeout.compute();
  assert(t.patterns.some((p) => p.id === "group"), "group pattern built");
  assert(t.patterns.some((p) => p.id === "weak"), "weakest-area pattern built");
  const read = takeout.readView.html(t);
  assert(read.indexOf("Recognition &amp; voice") !== -1, "weakest area named");
  assert(read.indexOf("Belonging &amp; purpose") !== -1, "strongest area named");
  assert(read.indexOf("Cape Town") !== -1, "group under strain named");
  assert(read.indexOf("Satisfaction") !== -1, "satisfaction leads the apex");
  assert(read.indexOf("69% agree") !== -1, "apex shows index + top-box");
  assert(read.indexOf("% response of") !== -1, "participation shown");
  assert(read.indexOf('data-edit="') !== -1, "editable hooks present");
});

console.log("Source structure check (<=" + MAX_ACTIVE_LINES + " active lines/file):");
function activeLines(src) {
  let inBlock = false, count = 0;
  for (const raw of src.split("\n")) {
    const t = raw.trim();
    if (!t) continue;
    if (inBlock) { if (t.includes("*/")) inBlock = false; continue; }
    if (t.startsWith("/*")) { if (!t.includes("*/")) inBlock = true; continue; }
    if (t.startsWith("//") || t.startsWith("*")) continue;
    if (/^[{}()\[\];,]+$/.test(t)) continue;
    count++;
  }
  return count;
}
for (const file of readdirSync(JS_DIR).filter((f) => /takeout.*\.js$/.test(f)).sort()) {
  const n = activeLines(readFileSync(path.join(JS_DIR, file), "utf8"));
  run(file + " (" + n + " active lines)", () =>
    assert(n <= MAX_ACTIVE_LINES, file + " has " + n + " active lines (max " + MAX_ACTIVE_LINES + ")"));
}

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
