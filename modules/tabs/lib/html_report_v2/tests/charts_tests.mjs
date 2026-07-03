#!/usr/bin/env node
/**
 * Chart-geometry gate. render.repel() lays out 1-D label positions without
 * overlap inside [minPos, maxPos]. Its backward (overflow) sweep set
 * pos = next - minGap with no lower clamp, so on a crowded small-slice chart a
 * callout could be pushed off the top of the track (negative position). This
 * checks the sweep now clamps to minPos.
 *
 * Also gates render.pieChart's full-circle case: a slice at 100% of the total
 * makes sweep = 2π, so the SVG arc's endpoints coincide and the whole donut
 * rendered as nothing — it must now draw a visible full ring.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/charts_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
sandbox.TR = { render: { CHART_TYPES: [] },
  charts: { brandOf: () => "#000", accentOf: () => "#111", clip: (s) => s },
  fmt: { escapeHtml: (s) => String(s) } };
vm.createContext(sandbox);
// real SVG builders so pieChart output can be asserted on
vm.runInContext(readFileSync(path.join(JS_DIR, "03_svg.js"), "utf8"), sandbox, { filename: "03_svg.js" });
vm.runInContext(readFileSync(path.join(JS_DIR, "23z_charts.js"), "utf8"), sandbox, { filename: "23z_charts.js" });
const repel = sandbox.TR.render.repel;
const pieChart = sandbox.TR.render.pieChart;

// pieChart deps normally supplied by 23_render.js — minimal stand-ins
sandbox.TR.render.chartRows = (model) => ({ rows: model.rows, axisMax: 100 });
sandbox.TR.render.categoryColours = (rows) =>
  rows.map((r, i) => ["#1b6e53", "#b3372f", "#a8842c"][i % 3]);

function pieModel(pcts) {
  return {
    code: "Q1",
    columns: [{ label: "Total" }],
    rows: pcts.map((p, i) => ({ kind: "category", label: "Opt " + i,
      cells: [{ pct: p }] }))
  };
}

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }

console.log("Chart geometry — suite:");

run("repel never pushes a label below minPos (crowded backward sweep)", () => {
  // 5 labels bunched at the bottom, gap 10 wider than the 12-tall track: the
  // overflow backward sweep would run negative without the clamp.
  const out = repel([{ pos: 2 }, { pos: 3 }, { pos: 4 }, { pos: 5 }, { pos: 6 }], 10, 0, 12);
  assert(out.every((l) => l.pos >= 0), "all positions >= minPos: " + JSON.stringify(out.map((l) => l.pos)));
  assert(out.every((l) => l.pos <= 12), "all positions <= maxPos");
});

run("repel keeps order and the minimum gap where the track allows it", () => {
  const out = repel([{ pos: 0 }, { pos: 1 }, { pos: 2 }], 5, 0, 100);
  assert(out[1].pos - out[0].pos >= 5 && out[2].pos - out[1].pos >= 5, "gaps enforced when there is room");
});

run("pie with one 100% slice draws a visible full ring, not a degenerate arc", () => {
  const svg = pieChart(pieModel([100, 0]), 0);
  // full circle: R=88, r0=46 -> ring radius (88+46)/2 = 67, width 88-46 = 42
  assert(svg.indexOf('<circle cx="170" cy="115" r="67"') !== -1,
    "full ring circle at the donut radius: " + svg.slice(0, 400));
  assert(svg.indexOf('stroke="#1b6e53" stroke-width="42"') !== -1,
    "ring stroked with the slice colour at the donut width");
  assert(svg.indexOf(">100%<") !== -1, "100% value label still shown");
  // no arc whose endpoints coincide (the invisible-donut signature)
  const arc = svg.match(/M ([0-9. -]+) A 88 88 0 1 1 \1/);
  assert(arc === null, "no zero-length outer arc remains");
});

run("pie with a normal split still uses arc slices (no ring)", () => {
  const svg = pieChart(pieModel([60, 40]), 0);
  assert(svg.indexOf("<circle") === -1, "no full-ring circle on a 60/40 split");
  assert((svg.match(/<path /g) || []).length === 2, "one arc path per slice");
  assert(svg.indexOf(">60%<") !== -1 && svg.indexOf(">40%<") !== -1,
    "both slice labels rendered");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
