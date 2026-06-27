#!/usr/bin/env node
/**
 * Verification gate for the Executive Takeout engine. Runs:
 *   1. known-answer tests for the pure engine (Cohen's h, scoring, routing,
 *      battery bonus, build/cap/dedupe) — hand-verifiable expected values.
 *   2. a source structure check (no takeout JS file over 300 active lines).
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
const MAX_ACTIVE_LINES = 300;

/* ---- load the namespace + every takeout module into a sandbox ----
   (loading them all also fails fast on any syntax error or missing export) */
const sandbox = { console };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
const takeoutFiles = readdirSync(JS_DIR).filter((f) => /takeout.*\.js$/.test(f)).sort();
// 01_format defines TR.fmt, which the component layer captures at load time.
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
function close(actual, expected, tol, msg) {
  if (Math.abs(actual - expected) > tol) {
    throw new Error(msg + ": expected ~" + expected + ", got " + actual);
  }
}

console.log("Executive Takeout engine — known-answer suite:");

run("Cohen's h known answers", () => {
  close(takeout.cohenH(0.5, 0.5), 0, 1e-9, "h(.5,.5)=0");
  close(takeout.cohenH(0.86, 0.74), 0.3033, 1e-3, "h(.86,.74)");
  close(takeout.cohenH(0.6, 0.4), 0.4027, 1e-3, "h(.6,.4)");
  assert(takeout.cohenH(0.9, 0.5) > 0, "positive when p1>p2");
  assert(takeout.cohenH(0.5, 0.9) < 0, "negative when p1<p2");
});

run("effect size is comparable across metrics", () => {
  const prop = { metric: "pct", value: 86, rest: 74, overall: 80 };
  close(takeout.effectSize(prop), 0.3033 / 0.8, 1e-3, "proportion effect = |h|/ref");
  const mean = { metric: "mean", gap: 0.6, scaleMin: 0, scaleMax: 10 };
  close(takeout.effectSize(mean), 0.06, 1e-9, "mean effect = |gap|/range");
  const huge = { metric: "pct", value: 95, rest: 5, overall: 50 };
  assert(takeout.effectSize(huge) === 1, "effect clamps to 1");
});

run("score: effect x significance tier", () => {
  const solid = { metric: "pct", value: 86, rest: 74, overall: 80, soft: false };
  close(takeout.scoreFinding(solid), 37.91, 0.1, "solid 95% score");
  const soft = { metric: "pct", value: 86, rest: 74, overall: 80, soft: true };
  close(takeout.scoreFinding(soft), 18.95, 0.1, "soft 80% scores half");
});

run("battery multiplier rewards consistency", () => {
  close(takeout.batteryMultiplier(1), 1.0, 1e-9, "lone finding, no bonus");
  close(takeout.batteryMultiplier(3), 1 + C.BATTERY_BONUS_PER_ITEM * 2, 1e-9, "k=3 bonus");
});

run("routing: levels to one posture each, relative to the median", () => {
  const median = 3.5;
  const lvl = (band, value, delta) => ({ band, value, delta, scaleMin: 0, scaleMax: 5 });
  assert(takeout.routeLevel(lvl("strong", 4.5, { sig: true, diff: -0.6 }), median) === "decide",
    "strong + declining -> decide");
  assert(takeout.routeLevel(lvl("moderate", 3.2, { sig: true, diff: 0.4 }), median) === "watch",
    "any significant mover -> watch");
  assert(takeout.routeLevel(lvl("strong", 4.2, null), median) === "protect",
    "above median, not moving -> protect");
  assert(takeout.routeLevel(lvl("weak", 2.8, null), median) === "act",
    "below median, not moving -> act");
  assert(takeout.medianValue([{ value: 1 }, { value: 3 }, { value: 5 }]) === 3, "median of 1,3,5");
});

run("index standout is preferred over a top-box standout (same Q + column)", () => {
  const both = takeout._preferIndexStandouts([
    { code: "Q1", column: "Seg", metric: "pct" },
    { code: "Q1", column: "Seg", metric: "mean" },
    { code: "Q2", column: "Seg", metric: "pct" }
  ]);
  assert(both.length === 2, "the duplicate top-box is dropped");
  assert(both.some((f) => f.code === "Q1" && f.metric === "mean"), "index kept for Q1");
  assert(both.some((f) => f.code === "Q2" && f.metric === "pct"), "lone top-box kept for Q2");
});

run("battery grouping is suppressed when category is blank", () => {
  const f = (label) => ({ code: "Q" + label, category: "", label, column: "Seg", direction: "behind" });
  const counts = takeout._batteryCounts([f("a"), f("b"), f("c")]);
  assert(Object.keys(counts).length === 3, "no category -> each finding its own battery");
  Object.values(counts).forEach((k) => assert(k === 1, "k=1 with no category"));
});

run("routing: standouts by direction and battery", () => {
  const so = (gap) => ({ kind: "standout", gap });
  assert(takeout.routePosture(so(12), 1) === "protect", "ahead -> protect");
  assert(takeout.routePosture(so(-12), 1) === "act", "behind -> act");
  assert(takeout.routePosture(so(-12), C.BATTERY_FORK_MIN) === "decide",
    "systemic segment pattern -> decide");
});

run("buildTakeout caps, routes and dedupes", () => {
  const standouts = [
    { code: "Q1", title: "Mission", category: "Belief", column: "All", label: "matters",
      isMean: false, value: 86, rest: 74, overall: 80, gap: 12, soft: false, beaten: ["x"] },
    { code: "Q2", title: "Workload", category: "Day", column: "All", label: "ok",
      isMean: false, value: 47, rest: 63, overall: 55, gap: -16, soft: false, beaten: ["y"] },
    { code: "Q3", title: "I1", category: "Joiners", column: "Under 2yr", label: "a",
      isMean: false, value: 40, rest: 62, overall: 55, gap: -22, soft: false, beaten: [] },
    { code: "Q4", title: "I2", category: "Joiners", column: "Under 2yr", label: "b",
      isMean: false, value: 41, rest: 60, overall: 54, gap: -19, soft: false, beaten: [] },
    { code: "Q5", title: "I3", category: "Joiners", column: "Under 2yr", label: "c",
      isMean: false, value: 38, rest: 61, overall: 53, gap: -23, soft: false, beaten: [] }
  ];
  const levels = [
    { code: "Q6", title: "Pride", category: "Belief", value: 8.6, band: "strong",
      delta: null, base: 220, scaleMin: 0, scaleMax: 10 },
    { code: "Q7", title: "Systems", category: "Day", value: 4.7, band: "weak",
      delta: null, base: 215, scaleMin: 0, scaleMax: 10 },
    { code: "Q8", title: "Engagement", category: "Index", value: 7.4, band: "strong",
      delta: { sig: true, diff: -0.6, year: 2024 }, base: 220, scaleMin: 0, scaleMax: 10 }
  ];
  const t = takeout.buildTakeout({ standouts, levels, composites: [], reliability: { n: 220 } });
  const by = {};
  t.postures.forEach((p) => { by[p.id] = p.items; });
  assert(t.candidateCount === 8, "8 gated candidates counted, got " + t.candidateCount);
  assert(by.protect.length <= C.CAP_PROTECT, "protect within cap");
  assert(by.act.length <= C.CAP_ACT, "act within cap");
  assert(by.decide.length >= 1, "a decide fork surfaced (battery + strong-declining)");
  assert(t.promotedCount <= 7, "page capped at <=7, got " + t.promotedCount);
  // the Under-2yr battery (k=3, all behind) must route to decide, not act
  const joinerInDecide = by.decide.some((f) => f.column === "Under 2yr");
  assert(joinerInDecide, "systemic joiner pattern routed to decide");
  // every promoted finding carries a stable id
  t.postures.forEach((p) => p.items.forEach((f) =>
    assert(f.id && f.id.indexOf("|") > 0, "finding has a stable id")));
});

run("buildTakeout is graceful on empty input", () => {
  const t = takeout.buildTakeout({});
  assert(t.postures.length === 4, "four posture lanes always present");
  assert(t.promotedCount === 0 && t.candidateCount === 0, "nothing promoted, nothing crashes");
});

run("a veto frees its slot for the next-ranked candidate", () => {
  // distinct categories so they don't form a battery (which would route to Decide);
  // each is a lone positive standout -> Protect, ranked by effect size
  const mk = (code, gap, cat) => ({ code, title: code, category: cat, column: "Seg", label: "x",
    isMean: false, value: 60 + gap, rest: 60, overall: 60, gap, soft: false, beaten: ["a"] });
  const standouts = [mk("Q1", 25, "A"), mk("Q2", 18, "B"), mk("Q3", 10, "C")];
  const base = takeout.buildTakeout({ standouts });
  const ids = base.postures.find((p) => p.id === "protect").items.map((f) => f.id);
  assert(ids.length === 2 && ids.indexOf("Q1|Seg|pct") !== -1, "top two by effect shown");
  // veto the leader -> the third-ranked is promoted into the freed slot
  const vetoed = takeout.buildTakeout({ standouts, vetoes: { "Q1|Seg|pct": true } });
  const ids2 = vetoed.postures.find((p) => p.id === "protect").items.map((f) => f.id);
  assert(ids2.indexOf("Q1|Seg|pct") === -1, "vetoed finding gone");
  assert(ids2.indexOf("Q3|Seg|pct") !== -1, "next candidate promoted into the slot");
});

run("every takeout module loaded and exposes its API", () => {
  ["buildTakeout", "gather", "compute", "render"].forEach((fn) =>
    assert(typeof takeout[fn] === "function", fn + " is a function"));
  assert(takeout.state && typeof takeout.state.setText === "function", "state API present");
  assert(takeout.ui && typeof takeout.ui.twoBar === "function", "ui atoms present");
  assert(takeout.readView && typeof takeout.readView.html === "function", "read view present");
  assert(takeout.presentView && typeof takeout.presentView.html === "function", "present view present");
});

run("curation state round-trips and resets", () => {
  takeout.state.setText("Q1|All|pct", "claim", "Client wording");
  assert(takeout.state.getText("Q1|All|pct", "claim", "seed") === "Client wording", "edit wins over seed");
  assert(takeout.state.getText("Q9|x|pct", "claim", "seed") === "seed", "seed is the fallback");
  takeout.state.setApex("My one-line answer");
  assert(takeout.state.getApex("seed") === "My one-line answer", "apex saved");
  takeout.state.setVeto("Q1|All|pct", true);
  assert(takeout.state.isVetoed("Q1|All|pct") === true, "veto recorded");
  assert(takeout.state.hasCuration() === true, "curation detected");
  takeout.state.reset();
  assert(takeout.state.getText("Q1|All|pct", "claim", "seed") === "seed", "reset clears text");
  assert(takeout.state.isVetoed("Q1|All|pct") === false, "reset clears vetoes");
});

run("end-to-end: generic apex, index+top-box, multi-banner, trend spark, participation", () => {
  TR.charts = { clip: (s, n) => String(s == null ? "" : s).slice(0, n) };
  TR.conf = { maxMoePct: () => 0.0, reportHasPopulation: () => true,
    labels: () => ({ sampling_method_normalised: "census", is_probability: false }) };
  TR.render = { wavePoints: (row) => row.waves || null, sparkline: () => '<svg class="spark"></svg>' };
  TR.AGG = { project: { name: "Climate 2025", low_base_threshold: 30, population_size: 220 },
    banner_groups: [{ id: "Q02", name: "Campus" }, { id: "Q03", name: "Department" }, { id: "Q04", name: "Tenure" }] };
  TR.d2 = { state: { banner: "Q02" }, firstBanner: () => "Q02" };
  // a scale question carries favourable NET, unfavourable NET, NET POSITIVE (diff), then the mean
  const netRows = [{ kind: "net", label: "Agree" }, { kind: "net", label: "Disagree" },
    { kind: "net", label: "NET POSITIVE" }, { kind: "mean", label: "Index" }];
  const qmodel = (mean, top, delta, waves) => ({ columns: [{ base: 167 }], rows: [
    { kind: "net", cells: [{ pct: top }] }, { kind: "net", cells: [{ pct: 6 }] },
    { kind: "net", cells: [{ pct: top - 6 }] },
    { kind: "mean", cells: [{ mean: mean }], delta: delta || null, waves: waves || null }] });
  const meanOnly = (mean, delta) => ({ columns: [{ base: 167 }],
    rows: [{ kind: "mean", cells: [{ mean: mean }], delta: delta || null }] });
  const Q = {
    Q28: { mean: 3.9, top: 69, delta: { sig: true, diff: 0.1, year: 2024 },
      waves: [{ year: 2023, value: 4.08 }, { year: 2024, value: 3.83 }, { year: 2025, value: 3.9, current: true }] },
    Q08: { mean: 3.44, top: 41, delta: null },
    Q12: { mean: 4.51, top: 88, delta: null }
  };
  const seg = (col, val, rest, gap, dir, base) => ({ code: "Q28",
    title: "Overall satisfaction with SACAP", category: "", column: col, label: "Index",
    isMean: true, soft: false, value: val, rest: rest, overall: 3.9, gap: gap,
    direction: dir, decimals: 1, scaleMin: 0, scaleMax: 5, beaten: [], base: base });
  TR.views = {
    _collectFindings: (g) => {
      if (g === "Q02") return [seg("Cape Town", 3.38, 3.98, -0.6, "behind", 38),
        seg("Durban", 4.5, 3.82, 0.68, "ahead", 33)];
      if (g === "Q03") return [seg("Marketing", 3.43, 3.95, -0.52, "behind", 31)];
      if (g === "Q04") return [seg("New staff (<1yr)", 4.3, 3.8, 0.5, "ahead", 30)];
      return [];
    },
    indexQuestions: () => ([
      { code: "Q28", title: "Overall satisfaction with SACAP as a place to work", category: "", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } },
      { code: "Q_Engage", title: "Engagement", category: "", type: "single", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: [{ kind: "mean", label: "Engagement" }] },
      { code: "Q08", title: "Recognition for good work", category: "", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } },
      { code: "Q12", title: "Mission makes work feel important", category: "", type: "scale", scale_max: 5, gauge_green: 4, gauge_amber: 3, rows: netRows, net_diffs: { "2": true } }
    ]),
    _modelFor: (code) => code === "Q_Engage"
      ? meanOnly(4.08, { sig: true, diff: -0.08, year: 2024 })
      : qmodel(Q[code].mean, Q[code].top, Q[code].delta, Q[code].waves),
    _meanRow: (m) => m.rows.find((r) => r.kind === "mean")
  };
  TR.model = { forQuestion: (code) => TR.views._modelFor(code) };

  const t = takeout.compute();
  assert(t.candidateCount >= 5, "standouts gathered across all banner groups, got " + t.candidateCount);
  const read = takeout.readView.html(t, { lowThreshold: 30 });
  const present = takeout.presentView.html(t, { lowThreshold: 30 });
  assert(read.indexOf("Satisfaction") !== -1, "satisfaction leads the apex (generic detection)");
  assert(read.indexOf("69% agree") !== -1, "apex shows index + top-box together");
  assert(read.indexOf("tko-kpi-spark") !== -1, "apex shows the wave sparkline when history exists");
  assert(read.indexOf("Campus") !== -1, "standouts tagged with their banner cut");
  assert(read.indexOf("% response of") !== -1, "participation/response rate shown");
  assert(read.indexOf("tko-gauge") !== -1, "driver level cards use a gauge bar");
  assert(read.indexOf("tko-qline") !== -1, "every card names its question");
  assert(present.indexOf("tko-slide-hero") !== -1, "present renders");
});

/* ---- source structure check ---- */
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
