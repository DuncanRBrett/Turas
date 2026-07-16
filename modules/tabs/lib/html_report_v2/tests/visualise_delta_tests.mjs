#!/usr/bin/env node
/**
 * vs Previous / vs Baseline delta rendering — regression suite for the
 * flat-zero bug: niceMax's 5-floor squashed ±0.3 mean-point changes onto
 * a −5..+5 axis, and the forced kind:"net" pseudo rows rounded every
 * label to a whole percentage ("0%"), so change modes showed a flat line
 * at zero for every mean/index metric (all of CCPB's tracked metrics).
 *
 * Now trendChart takes opts.delta: symmetric zero-centred axis sized by
 * niceDeltaMax, signed labels in the metric's own units ("+0.2" mean
 * points / "+3pp"), exact tick text, and the zero gridline emphasised.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/visualise_delta_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console, TextEncoder };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const file of ["00_namespace.js", "01_format.js", "03_svg.js",
  "23_render.js", "23z_charts.js", "23za_trend.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) { if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a)); }

/* ---------------- fixtures ---------------- */

// Delta pseudo rows exactly as 27v builds them in change modes: kind
// forced to "net", isMean carrying the metric's real mean-ness, cells
// empty (no current-wave append).
function deltaModel(rows) {
  TR.AGG = { project: { name: "Delta fixture", wave: "W2026" } };
  return { code: "Q02", title: "vis", chartKind: "summary",
    columns: [{ label: "Total", base: 452 }], rows: rows };
}
const meanDeltas = (label, vals) => ({ kind: "net", diff: false, label: label,
  isMean: true, cells: [{ pct: null, mean: null }],
  waves: vals.map((v, i) => ({ year: 2013 + i, value: v, base: 400,
    current: i === vals.length - 1 })) });
const pctDeltas = (label, vals) => ({ kind: "net", diff: false, label: label,
  isMean: false, cells: [{ pct: null, mean: null }],
  waves: vals.map((v, i) => ({ year: 2013 + i, value: v, base: 400,
    current: i === vals.length - 1 })) });

function tickTexts(svg) {
  return [...svg.matchAll(/text-anchor="end"[^>]*>([^<]+)</g)].map((m) => m[1]);
}

console.log("Visualise delta rendering — suite:");

/* ---------------- 1. the helpers ---------------- */
run("_niceDeltaMax scales below niceMax's 5-floor (the flat-line cause)", () => {
  eq(TR.render._niceDeltaMax(0.05), 0.1, "0.05");
  eq(TR.render._niceDeltaMax(0.3), 0.5, "0.3 (CCPB mean changes)");
  eq(TR.render._niceDeltaMax(0.8), 1, "0.8");
  eq(TR.render._niceDeltaMax(3), 5, "3");
  eq(TR.render._niceDeltaMax(7), 10, "7 falls through to niceMax");
  eq(TR.render._niceDeltaMax(0), 1, "all-zero changes keep a readable axis");
});

run("_fmtDelta signs values in the metric's own units", () => {
  eq(TR.render._fmtDelta(0.23, true), "+0.2", "mean up, 1dp");
  eq(TR.render._fmtDelta(-0.16, true), "−0.2", "mean down");
  eq(TR.render._fmtDelta(0, true), "0.0", "mean zero unsigned");
  eq(TR.render._fmtDelta(3.4, false), "+3", "pct up, whole pp");
  eq(TR.render._fmtDelta(-2.6, false), "−3", "pct down");
  eq(TR.render._fmtDelta(0, false), "0", "pct zero unsigned");
});

/* ---------------- 2. mean-metric changes (the reported bug) ---------------- */
run("±0.3 mean-point changes fill a ±0.5 axis — no more −5..+5 flat line", () => {
  const svg = TR.render.trendChart(deltaModel([
    meanDeltas("Total", [-0.2, 0.1, -0.1, 0.2, 0, 0.3, 0.2])
  ]), { delta: true, labels: "last" });
  const ticks = tickTexts(svg);
  assert(ticks.indexOf("0.5") !== -1 && ticks.indexOf("-0.5") !== -1,
    "axis spans ±0.5, got ticks: " + ticks.join(", "));
  assert(ticks.indexOf("0.25") !== -1, "quarter ticks exact (no 0.3 rounding lie)");
  assert(svg.indexOf(">5%<") === -1 && ticks.indexOf("5") === -1,
    "old ±5% axis gone");
});

run("mean changes label signed in scale points, not '0%'", () => {
  const svg = TR.render.trendChart(deltaModel([
    meanDeltas("Total", [-0.2, 0.1, 0.3, 0.2])
  ]), { delta: true, labels: "all" });
  assert(svg.indexOf(">+0.2<") !== -1, "end label '+0.2' (was '0%')");
  assert(svg.indexOf(">−0.2<") !== -1, "point label '−0.2'");
  assert(!/>[+−]?\d+%</.test(svg),
    "no percentage-rounded text labels anywhere");
});

run("the zero line is the emphasised gridline, mid-axis", () => {
  const svg = TR.render.trendChart(deltaModel([
    meanDeltas("Total", [-0.2, 0.1, 0.3])
  ]), { delta: true });
  const base = [...svg.matchAll(/<line x1="46" y1="([\d.]+)"[^>]*stroke="#d8dcea"/g)];
  eq(base.length, 1, "exactly one emphasised gridline");
  // symmetric axis: zero sits mid-plot (padT 18 + plotH 192 / 2 = 114)
  eq(base[0][1], "114", "and it is the zero line");
});

/* ---------------- 3. percentage metrics + mixes ---------------- */
run("percentage changes keep whole-pp ticks and labels", () => {
  const svg = TR.render.trendChart(deltaModel([
    pctDeltas("Top2 (NET)", [-3, 2, 4, 3])
  ]), { delta: true, labels: "last" });
  const ticks = tickTexts(svg);
  assert(ticks.indexOf("5pp") !== -1 && ticks.indexOf("-5pp") !== -1,
    "±5pp axis for ±4pp changes, got: " + ticks.join(", "));
  assert(svg.indexOf(">+3pp<") !== -1, "end label '+3pp'");
});

run("a mixed mean+pct selection leaves the axis bare (footer names units)", () => {
  const svg = TR.render.trendChart(deltaModel([
    meanDeltas("Mean", [-0.2, 0.1, 0.3]),
    pctDeltas("NET", [-3, 2, 4])
  ]), { delta: true, labels: "last" });
  assert(tickTexts(svg).every((t) => t.indexOf("pp") === -1),
    "no pp suffix on shared-axis ticks");
  assert(svg.indexOf(">+4pp<") !== -1, "the % series still labels itself in pp");
  assert(svg.indexOf(">+0.3<") !== -1, "the mean series labels in points");
});

/* ---------------- 4. overrides + old path unchanged ---------------- */
run("user y-range override still wins in delta mode", () => {
  const svg = TR.render.trendChart(deltaModel([
    meanDeltas("Total", [-0.2, 0.1, 0.3])
  ]), { delta: true, yMin: -1, yMax: 1 });
  const ticks = tickTexts(svg);
  assert(ticks.indexOf("1") !== -1 && ticks.indexOf("-1") !== -1,
    "±1 axis honoured, got: " + ticks.join(", "));
});

run("absolute charts are untouched (no delta flag -> old axis + labels)", () => {
  TR.AGG = { project: { name: "Abs fixture", wave: "Wave 12" } };
  const svg = TR.render.trendChart({
    code: "Q1", title: "abs", chartKind: "summary",
    columns: [{ label: "Total", base: 200 }],
    rows: [{ kind: "net", label: "Top2 (NET)", cells: [{ pct: null }],
      waves: [{ year: 9, value: 50 }, { year: 10, value: 55 },
        { year: 11, value: 60, current: true }] }] }, { labels: "last" });
  const ticks = tickTexts(svg);
  assert(ticks.indexOf("75%") !== -1 || ticks.indexOf("60%") !== -1 ||
    ticks.indexOf("100%") !== -1, "percentage axis intact: " + ticks.join(", "));
  assert(svg.indexOf(">60%<") !== -1, "unsigned absolute end label");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
