#!/usr/bin/env node
/**
 * Chart-geometry gate. render.repel() lays out 1-D label positions without
 * overlap inside [minPos, maxPos]. Its backward (overflow) sweep set
 * pos = next - minGap with no lower clamp, so on a crowded small-slice chart a
 * callout could be pushed off the top of the track (negative position). This
 * checks the sweep now clamps to minPos.
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
sandbox.TR = { svg: { el: () => "" }, render: { CHART_TYPES: [] },
  charts: { brandOf: () => "#000", accentOf: () => "#111", clip: (s) => s },
  fmt: { escapeHtml: (s) => String(s) } };
vm.createContext(sandbox);
vm.runInContext(readFileSync(path.join(JS_DIR, "23z_charts.js"), "utf8"), sandbox, { filename: "23z_charts.js" });
const repel = sandbox.TR.render.repel;

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

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
