#!/usr/bin/env node
/**
 * Verification gate for the rebuilt Pattern recognition tab (Phase 1 — tension
 * portraits). Loads the pure engine over a hand-built fixture and asserts the
 * three reader contracts hold: traceable (every shown value is a real cell),
 * commensurable (no cross-scale area), balanced + tension-led (lows AND highs,
 * ranked by tension). No DOM; mirrors takeout_tests.mjs.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/portrait_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const sandbox = { console };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "27da_takeout_stats.js",
  "27e_takeout_engine.js", "27g_takeout_components.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, f), "utf8"), sandbox, { filename: f });
}
const takeout = sandbox.TR.takeout;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(c, m) { if (!c) throw new Error(m); }
function eq(a, b, m) { if (a !== b) throw new Error(m + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a)); }
function close(a, b, t, m) { if (Math.abs(a - b) > t) throw new Error(m + ": expected ~" + b + ", got " + a); }

/* ---------------- fixture (scaleMax 5) ----------------
 * Campus: Cape Town strained but spikes high on quality (the tension);
 *         Durban uniformly thriving (no counter-spike); Joburg flat (excluded).
 * Dept:   Marketing low on satisfaction/recognition, high on results (tension). */
const g = (title, value, total) => ({ title, value, total, scaleMax: 5 });
const columns = [
  { column: "Cape Town", group: "Campus", base: 40, gaps: [
    g("Opinions count", 2.9, 3.7), g("Encouraged to develop", 3.5, 4.1),
    g("Integrity", 3.4, 3.9), g("Spoken about progress", 3.2, 3.8),
    g("Co-workers commit to quality", 4.6, 3.9) ] },                 // the counter-spike
  { column: "Durban", group: "Campus", base: 40, gaps: [
    g("Opinions count", 4.5, 3.7), g("Encouraged to develop", 4.4, 4.1),
    g("Integrity", 4.3, 3.9), g("Spoken about progress", 4.2, 3.8),
    g("Co-workers commit to quality", 4.0, 3.9) ] },                 // uniformly above
  { column: "Joburg", group: "Campus", base: 40, gaps: [
    g("Opinions count", 3.7, 3.7), g("Encouraged to develop", 4.1, 4.1),
    g("Integrity", 3.9, 3.9), g("Spoken about progress", 3.8, 3.8),
    g("Co-workers commit to quality", 3.9, 3.9) ] },                 // flat -> excluded
  { column: "Marketing", group: "Dept", base: 30, gaps: [
    g("Satisfaction", 3.0, 3.8), g("Recognition", 3.1, 3.9),
    g("Person-centred", 3.2, 3.9), g("Results oriented", 4.4, 3.7) ] }
];

console.log("Pattern recognition rebuild — portrait engine suite:");

run("portraits: tension groups rank first; flat group excluded", () => {
  const ps = takeout._portraits(columns, null);
  const names = ps.map((p) => p.subject);
  assert(names.indexOf("Joburg") === -1, "flat Joburg is not a portrait");
  assert(["Cape Town", "Marketing"].indexOf(names[0]) !== -1,
    "a tension group leads (got " + names[0] + ")");
  assert(names.indexOf("Durban") > names.indexOf("Cape Town") &&
    names.indexOf("Durban") > names.indexOf("Marketing"),
    "uniform Durban ranks below both tension groups");
});

run("a portrait is balanced — lows AND highs, with a real counter-spike", () => {
  const ct = takeout._portraits(columns, null).find((p) => p.subject === "Cape Town");
  eq(ct.lean, "strained", "Cape Town leans strained");
  eq(ct.lows.length, 4, "four low questions");
  eq(ct.highs.length, 1, "one high question (the spike)");
  eq(ct.highs[0].label, "Co-workers commit to quality", "the spike is the quality question");
  close(ct.counterSpike, (4.6 - 3.9) / 5, 1e-9, "counter-spike magnitude");
  assert(ct.tensionScore > 0, "Cape Town has tension");
});

run("uniform thriving group has no counter-spike, ~zero tension", () => {
  const d = takeout._portraits(columns, null).find((p) => p.subject === "Durban");
  eq(d.lean, "thriving", "Durban leans thriving");
  eq(d.lows.length, 0, "no low questions");
  eq(d.counterSpike, 0, "no counter-spike");
  eq(d.tensionScore, 0, "zero tension");
});

run("traceability — every shown value is a real fixture cell", () => {
  const ct = takeout._portraits(columns, null).find((p) => p.subject === "Cape Town");
  const cell = columns[0].gaps.find((x) => x.title === "Opinions count");
  const row = ct.lows.find((r) => r.label === "Opinions count");
  eq(row.value, cell.value, "row value == cell value");
  eq(row.rest, cell.total, "row baseline == overall cell");          // not a synthetic aggregate
});

run("peer annotation — Cape Town is bottom on lows, top on its spike", () => {
  const ct = takeout._portraits(columns, null).find((p) => p.subject === "Cape Town");
  eq(ct.highs[0].peerTop, true, "top campus on the quality spike (4.6 > 4.0)");
  eq(ct.lows[0].peerBottom, true, "bottom campus on its worst question");
});

run("uniform extremeness is a story too — top on nearly everything is not buried", () => {
  // A group top on every metric (no counter-spike, zero tension) must still
  // out-rank a group with only a faint tension — character carries it.
  const star = { column: "Star", group: "Campus", base: 40, gaps: [
    g("Q1", 4.6, 3.7), g("Q2", 4.5, 3.8), g("Q3", 4.7, 3.9), g("Q4", 4.6, 3.8), g("Q5", 4.5, 3.9) ] };
  const faint = { column: "Faint", group: "Campus", base: 40, gaps: [
    g("Q1", 3.6, 3.7), g("Q2", 3.7, 3.8), g("Q3", 4.2, 3.9) ] };   // tiny lean + tiny spike
  const ps = takeout._portraits([star, faint], null);
  eq(ps[0].subject, "Star", "uniform-extreme group leads the faint tension");
  eq(ps[0].counterSpike, 0, "Star has no tension — it's pure extremeness");
  assert(ps[0].uniform === true, "flagged uniform");
  assert(takeout.ui.portraitTension(ps[0]).indexOf("5 of the 5 questions scored") !== -1,
    "narrative calls out the sweep (5 of the 5 questions scored)");
});

run("commensurable areas only — mixed-scale theme is dropped", () => {
  const levels = [
    { title: "Recognition A", theme: "Recognition", value: 3.1, scaleMax: 5 },
    { title: "Recognition B", theme: "Recognition", value: 3.3, scaleMax: 5 },
    { title: "Recommend", theme: "Perceptions", value: 45, scaleMax: 100 },
    { title: "Trust", theme: "Perceptions", value: 3.2, scaleMax: 5 }     // different scale
  ];
  const areas = takeout._areaPatterns(levels).map((a) => a.subject);
  assert(areas.indexOf("Recognition") !== -1, "commensurable Recognition kept");
  assert(areas.indexOf("Perceptions") === -1, "mixed-scale Perceptions dropped (no cross-scale average)");
});

run("buildPatterns: portraits + split pointer; co-moving/odd/bimodal not cards", () => {
  const t = takeout.buildPatterns({ columns: columns });
  const kinds = t.patterns.map((p) => p.kind);
  assert(kinds.indexOf("portrait") !== -1, "portraits present");
  assert(kinds.indexOf("comove") === -1, "co-moving retired");
  assert(kinds.indexOf("odd") === -1 && kinds.indexOf("bimodal") === -1, "odd/bimodal not cards");
  const split = t.patterns.find((p) => p.kind === "split");
  assert(split && split.subject === "Campus", "split pointer = Campus");
  assert(t.rigor !== undefined, "rigor summary present for the footer");
  assert(t.patterns.filter((p) => p.kind === "portrait").length <= takeout.CONST.PORTRAIT_MAX,
    "portrait cap respected");
});

run("rigor notes: a hit carries a one-line statement for the footer (audit #3)", () => {
  const cells = [];
  for (let i = 0; i < 19; i++) cells.push({ banner: "Campus", group: "Odd", q: "Q" + i, qtitle: "Q" + i,
    nIn: 40, gap: -0.39, value: 3.2, total: 3.59, scaleMax: 5, welchDiff: -0.4, welchP: 0.5, flooredG: false });
  cells.push({ banner: "Campus", group: "Odd", q: "Qx", qtitle: "Pay", nIn: 40, gap: 0.63, value: 4.24,
    total: 3.57, scaleMax: 5, welchDiff: 0.6, welchP: 1e-17, flooredG: false });
  const fdr = { cells, K: cells.length, groupCount: 1, questionCount: 20,
    groups: [{ banner: "Campus", group: "Odd", base: 40, below: 19, above: 1, qn: 20, meanGap: -0.339 }] };
  const bimodal = { questions: [{ code: "QB", title: "Return to office", counts: [40, 8, 4, 8, 40], scaleMax: 5 }] };
  const t = takeout.buildPatterns({ fdr, bimodal });
  assert(t.rigor.odd.found === true, "odd hit recorded");
  eq(t.rigor.odd.note, "Odd runs low overall yet sits above the overall on “Pay” (4.2 vs 3.6)",
    "odd note names the group, the question and the real cells");
  assert(t.rigor.bimodal.found === true, "bimodal hit recorded");
  eq(t.rigor.bimodal.note, "“Return to office” splits into two camps behind a calm average",
    "bimodal note names the question");
  assert(t.patterns.every((p) => p.kind !== "odd" && p.kind !== "bimodal"), "still no odd/bimodal cards");
  // a confident null carries no note
  const t0 = takeout.buildPatterns({
    fdr: { cells: cells.slice(0, 19), K: 19, groupCount: 1, questionCount: 19,
      groups: [{ banner: "Campus", group: "Odd", base: 40, below: 19, above: 0, qn: 19, meanGap: -0.39 }] },
    bimodal: { questions: [{ code: "QB", title: "Calm", counts: [3, 3, 12, 19, 63], scaleMax: 5 }] } });
  assert(t0.rigor.odd.found === false && t0.rigor.odd.note === null, "null odd -> no note");
  assert(t0.rigor.bimodal.found === false && t0.rigor.bimodal.note === null, "null bimodal -> no note");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
