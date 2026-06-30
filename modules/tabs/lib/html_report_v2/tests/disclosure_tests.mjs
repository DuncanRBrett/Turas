// Disclosure control — re-identification protection threshold. Node, no DOM.
// Stubs TR.AGG.project / TR.MICRO / TR.stats / TR.d2 and checks the threshold logic,
// the live audience base, and the "set k = N to forbid any drill-down" property.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const jsDir = path.join(here, "..", "assets", "js");
globalThis.TR = {};
new Function(fs.readFileSync(path.join(jsDir, "21d_disclosure.js"), "utf8"))();
const disc = globalThis.TR.disclosure;

let passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { passed++; console.log("  ✓ " + msg); }
  else { failed++; console.log("  ✗ " + msg); }
}

console.log("Disclosure control:");

// Off by default (no config / k<=1) — existing reports are unaffected.
TR.AGG = { project: {} };
assert(disc.minBase() === 1 && disc.active() === false, "no config -> k=1, control off");
TR.AGG.project.min_reporting_base = 1;
assert(disc.active() === false, "k=1 is treated as off");
TR.AGG.project.min_reporting_base = 10;
assert(disc.minBase() === 10 && disc.active() === true, "k=10 -> active");

// Audience base: the whole sample when unfiltered, the mask count when filtered.
TR.MICRO = { n: 200 };
TR.d2 = { state: { filters: [] } };
assert(disc.audienceBase() === 200, "unfiltered audience base = N");
TR.stats = { mask: function (f) { return f; }, maskCount: function () { return 3; } };
TR.d2.state.filters = [{ q: "X", rows: [0] }];
assert(disc.audienceBase() === 3, "filtered audience base = maskCount");
assert(disc.audienceTooSmall() === true, "base 3 < k 10 -> too small");

// The k = N property Duncan asked for: only the full-sample view shows detail; any
// sub-group filter trips the gate.
TR.AGG.project.min_reporting_base = 200;   // k = full sample
TR.d2.state.filters = [];
assert(disc.audienceTooSmall() === false, "k=N, unfiltered (base=N) -> shows detail");
TR.d2.state.filters = [{ q: "X", rows: [0] }];
assert(disc.audienceTooSmall() === true, "k=N, any filter (base<N) -> withholds detail");

// Cell-level safety (for the crosstab suppression increment): 0 is fine, 1..k-1 suppressed.
TR.AGG.project.min_reporting_base = 10;
assert(disc.cellOk(0) === true, "cellOk: an empty cell (0) is fine to show");
assert(disc.cellOk(10) === true && disc.cellOk(25) === true, "cellOk: count >= k is fine");
assert(disc.cellOk(1) === false && disc.cellOk(9) === false, "cellOk: 1..k-1 is suppressed");
// off -> everything shows
TR.AGG.project.min_reporting_base = 1;
assert(disc.cellOk(2) === true, "cellOk: control off -> any count shows");

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
