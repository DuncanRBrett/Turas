#!/usr/bin/env node
/**
 * Trendline toggle — the dashed least-squares fit line on the tracking
 * Visualise chart and its pinned exhibits (Absolute mode only; the
 * checkbox mirrors the 95% CI bands toggle):
 *   - render._olsFit known answers + degenerate inputs;
 *   - render._clipSeg clips the fitted segment to the axis range exactly
 *     (a tight user y-window crops the line, never bends its slope);
 *   - trendChart draws one dashed .trendfit line per eligible series,
 *     names it in the footer note, and skips single-point series;
 *   - a perfectly linear series' fit lands ON its own data points;
 *   - pinTrackingView persists the flag; panelsHtml re-renders with it.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/trendline_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const stored = {};   // localStorage shim — lets the suite read pinned items back
const sandbox = { console, TextEncoder,
  localStorage: { getItem: (k) => stored[k] || null,
    setItem: (k, v) => { stored[k] = v; } } };
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
function near(a, b, tol, msg) {
  if (Math.abs(a - b) > tol) throw new Error(msg + ": expected ~" + b + ", got " + a);
}

/* ---------------- fixtures ---------------- */

// Pseudo-row style model (cells carry no current value, so wavePoints
// plots exactly the waves given — the Visualise path).
function model(rows) {
  TR.AGG = { project: { name: "Trendline fixture", wave: "Wave 12" } };
  return { code: "Q1", title: "KPI over waves", chartKind: "summary",
    columns: [{ label: "Total", base: 200 }], rows: rows };
}
const netRow = (label, waves) => (
  { kind: "net", label: label, waves: waves, cells: [{ pct: null }] });

function trendfitLines(svg) {
  return [...svg.matchAll(
    /<line class="trendfit" x1="([\d.-]+)" y1="([\d.-]+)" x2="([\d.-]+)" y2="([\d.-]+)"/g)]
    .map((m) => ({ x1: +m[1], y1: +m[2], x2: +m[3], y2: +m[4] }));
}
function circles(svg) {
  return [...svg.matchAll(/<circle cx="([\d.-]+)" cy="([\d.-]+)"/g)]
    .map((m) => ({ cx: +m[1], cy: +m[2] }));
}

console.log("Trendline toggle — suite:");

/* ---------------- 1. the fit itself ---------------- */
run("_olsFit known answer: (0,1)(1,3)(2,5) -> slope 2, intercept 1", () => {
  const f = TR.render._olsFit([{ x: 0, y: 1 }, { x: 1, y: 3 }, { x: 2, y: 5 }]);
  near(f.slope, 2, 1e-9, "slope");
  near(f.intercept, 1, 1e-9, "intercept");
});

run("_olsFit noisy known answer: (0,0)(1,2)(2,1) -> slope 0.5, intercept 0.5", () => {
  const f = TR.render._olsFit([{ x: 0, y: 0 }, { x: 1, y: 2 }, { x: 2, y: 1 }]);
  near(f.slope, 0.5, 1e-9, "slope");
  near(f.intercept, 0.5, 1e-9, "intercept");
});

run("_olsFit degenerate inputs -> null (one point; no x spread)", () => {
  eq(TR.render._olsFit([{ x: 0, y: 5 }]), null, "single point");
  eq(TR.render._olsFit([{ x: 1, y: 5 }, { x: 1, y: 9 }]), null, "no x spread");
});

/* ---------------- 2. exact clipping ---------------- */
run("_clipSeg passes a fully-inside segment through unchanged", () => {
  const seg = TR.render._clipSeg(0, 20, 10, 40, 0, 100);
  near(seg[0].x, 0, 1e-9, "x0"); near(seg[0].v, 20, 1e-9, "v0");
  near(seg[1].x, 10, 1e-9, "x1"); near(seg[1].v, 40, 1e-9, "v1");
});

run("_clipSeg clips at the crossing point, not the endpoint (slope kept)", () => {
  // 10 -> 90 over x 0..1, window [40, 60]: crossings at t=0.375 and t=0.625
  const seg = TR.render._clipSeg(0, 10, 1, 90, 40, 60);
  near(seg[0].x, 0.375, 1e-9, "x at v=40"); near(seg[0].v, 40, 1e-9, "v lo");
  near(seg[1].x, 0.625, 1e-9, "x at v=60"); near(seg[1].v, 60, 1e-9, "v hi");
});

run("_clipSeg drops segments fully outside; keeps a flat in-range line", () => {
  eq(TR.render._clipSeg(0, 70, 1, 90, 0, 60), null, "fully above");
  eq(TR.render._clipSeg(0, 1, 1, 2, 10, 60), null, "fully below");
  eq(TR.render._clipSeg(0, 200, 1, 200, 0, 100), null, "flat outside");
  const flat = TR.render._clipSeg(0, 50, 1, 50, 0, 100);
  near(flat[0].v, 50, 1e-9, "flat inside kept");
});

/* ---------------- 3. the chart ---------------- */
run("trendChart without the flag draws no trendfit line (byte-identical off-state)", () => {
  const svg = TR.render.trendChart(model([
    netRow("A", [{ year: 9, value: 50 }, { year: 10, value: 55 }])]));
  eq(trendfitLines(svg).length, 0, "no fit lines");
  assert(svg.indexOf("linear trend") === -1, "no note suffix");
});

run("trendChart {trendline: true} draws one dashed fit per series + note", () => {
  const svg = TR.render.trendChart(model([
    netRow("A", [{ year: 9, value: 50 }, { year: 10, value: 55 }, { year: 11, value: 60 }]),
    netRow("B", [{ year: 9, value: 30 }, { year: 10, value: 28 }, { year: 11, value: 33 }])
  ]), { trendline: true });
  eq(trendfitLines(svg).length, 2, "one fit line per series");
  assert(svg.indexOf('stroke-dasharray="6 4"') !== -1, "dashed");
  assert(svg.indexOf("dashed = linear trend (least squares)") !== -1,
    "footer names the fit honestly");
});

run("a perfectly linear series' fit lands on its own first/last points", () => {
  const svg = TR.render.trendChart(model([
    netRow("A", [{ year: 9, value: 50 }, { year: 10, value: 55 }, { year: 11, value: 60 }])
  ]), { trendline: true });
  const fit = trendfitLines(svg)[0];
  const dots = circles(svg);
  near(fit.y1, dots[0].cy, 0.15, "fit start y == first data point y");
  near(fit.y2, dots[dots.length - 1].cy, 0.15, "fit end y == last data point y");
  near(fit.x1, dots[0].cx, 0.15, "fit spans from the first wave");
  near(fit.x2, dots[dots.length - 1].cx, 0.15, "to the last wave");
});

run("a flat series' fit is horizontal", () => {
  const svg = TR.render.trendChart(model([
    netRow("A", [{ year: 9, value: 50 }, { year: 10, value: 50 }, { year: 11, value: 50 }])
  ]), { trendline: true });
  const fit = trendfitLines(svg)[0];
  near(fit.y1, fit.y2, 1e-9, "horizontal");
});

run("single-point series get no fit line (multi-series chart keeps the rest)", () => {
  const svg = TR.render.trendChart(model([
    netRow("A", [{ year: 9, value: 50 }, { year: 10, value: 55 }]),
    netRow("B", [{ year: 9, value: 30 }])
  ]), { trendline: true });
  eq(trendfitLines(svg).length, 1, "only the 2-point series is fitted");
});

run("a chart of only single-point series draws nothing and stays honest (no note)", () => {
  const svg = TR.render.trendChart(model([
    netRow("A", [{ year: 9, value: 50 }])]), { trendline: true });
  eq(trendfitLines(svg).length, 0, "no fit possible");
  assert(svg.indexOf("linear trend") === -1, "no note for a fit that is not there");
});

run("a tight user y-window crops the fit to the plot area, never bends it", () => {
  // 10 -> 90 across 5 waves, forced window [40, 60]
  const svg = TR.render.trendChart(model([
    netRow("A", [{ year: 1, value: 10 }, { year: 2, value: 30 },
      { year: 3, value: 50 }, { year: 4, value: 70 }, { year: 5, value: 90 }])
  ]), { trendline: true, yMin: 40, yMax: 60 });
  const fit = trendfitLines(svg)[0];
  const dots = circles(svg);
  // inside the plot band vertically (padT=18 .. padT+plotH=210)
  assert(fit.y1 >= 17.9 && fit.y1 <= 210.1 && fit.y2 >= 17.9 && fit.y2 <= 210.1,
    "fit stays inside the plot area: got y " + fit.y1 + ".." + fit.y2);
  // clipped horizontally: strictly narrower than the data's x extent
  assert(fit.x1 > dots[0].cx + 1, "clipped in from the first wave");
  assert(fit.x2 < dots[dots.length - 1].cx - 1, "clipped in from the last wave");
});

/* ---------------- 4. pins: persist + re-render ---------------- */
// Real story assembler + exhibit engine over minimal stubs (the
// exports_tests deck-spine pattern).
vm.runInContext(readFileSync(path.join(JS_DIR, "30_story.js"), "utf8"), sandbox,
  { filename: "30_story.js" });
vm.runInContext(readFileSync(path.join(JS_DIR, "30x_exhibit.js"), "utf8"), sandbox,
  { filename: "30x_exhibit.js" });

function pinSetup() {
  TR.AGG = { project: { name: "Pin fixture", wave: "Wave 12" },
    questions: [], banner_groups: [] };
  TR.d2 = { storeKey: (b) => b, state: { filters: [] },
    questionByCode: (c) => ({ code: c, title: "KPI" }) };
  TR.shell = { toast: () => {} };
  TR.trk = { points: () => [{ year: 9, value: 50 },
    { year: 10, value: 55 }, { year: 11, value: 61, current: true }] };
  TR.model = { forQuestion: () => ({ code: "Q1", title: "KPI question",
    columns: [{ label: "Total", base: 200 }],
    rows: [{ kind: "net", label: "Top2 (NET)", waves: [], cells: [{ pct: 61 }] }] }) };
}
const pinSpec = (trendline) => ({ title: "Q1 · KPI — Top2 · Total",
  qs: ["Q1"], series: [{ code: "Q1", ri: 0, seg: "total", label: "Total" }],
  annotations: [], ci: false, trendline: trendline, note: "" });

run("pinTrackingView persists trendline exactly as pinned (on and off)", () => {
  pinSetup();
  TR.story2.pinTrackingView(pinSpec(true), { trend: true });
  TR.story2.pinTrackingView(pinSpec(false), { trend: true });
  const state = JSON.parse(stored["turas_v2_story"]);
  const items = state._owns ? state.items : state;
  eq(items.length, 2, "both pins stored");
  eq(items[0].trendline, true, "pinned with the fit on");
  eq(items[1].trendline, false, "pinned with the fit off");
});

run("panelsHtml re-renders a pinned view's trend chart with its fit line", () => {
  pinSetup();
  const item = { kind: "exhibit", qs: ["Q1"], banner: "", filters: [],
    series: [{ code: "Q1", ri: 0, seg: "total", label: "Total" }],
    annotations: [], ci: false, trendline: true,
    flags: { dist: false, trend: true, table: false, insight: true }, note: "" };
  const withFit = TR.exhibit.panelsHtml(item);
  assert(withFit.indexOf("trendfit") !== -1, "pinned chart carries the fit line");
  assert(withFit.indexOf("dashed = linear trend (least squares)") !== -1,
    "pinned chart names the fit in its note");
  const without = TR.exhibit.panelsHtml(
    Object.assign({}, item, { trendline: false }));
  assert(without.indexOf("trendfit") === -1, "no fit when pinned off");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
