// Tracking navigation — regression suite for the Summary → Visualise jump.
//
// Reproduces the bug where clicking a "Significant changes" card (or a KPI
// scorecard card) landed on the Visualise view showing a STALE question/cut
// rather than the card you clicked. Root cause: the click handler wrote a
// dead `visSegs` state key and never updated `visSel` — the model the
// Visualise view actually reads — so a prior selection survived the click.
//
// We load the real Summary (cardVisSel) and Visualise (selection / seriesSpecs)
// helpers with a hand-built TR.trk stub, and assert the click resolves to the
// clicked metric AND cut. No DOM: we drive state exactly as the handler does.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const jsDir = path.join(here, "..", "assets", "js");

globalThis.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
function load(file) {
  new Function(fs.readFileSync(path.join(jsDir, file), "utf8"))();
}
load("27u_summary.js");
load("27v_visualise.js");
const summary = globalThis.TR.trkSummary;
const vis = globalThis.TR.trkVis;

// --- minimal data the Visualise resolvers need -------------------------------
const METRICS = {
  "Q05::1": { key: "Q05::1", code: "Q05",
    title: "I know what is expected of me at work.", label: "Index",
    isMean: true, diff: false },
  "Q15::1": { key: "Q15::1", code: "Q15",
    title: "In the last 6 months, I have spoken with someone about my progress.",
    label: "Index", isMean: true, diff: false }
};
const SEGS = {
  tenure_1_3: { norm: "tenure_1_3", label: "Between 1 and 3 years", group: "tenure" }
};
const state = {};
globalThis.TR.trk = {
  state: state,
  metricByKey: (k) => METRICS[k] || null,
  metricList: () => [METRICS["Q05::1"], METRICS["Q15::1"]],
  segmentByNorm: (n) => SEGS[n] || null
};
globalThis.TR.waves = { segments: () => [SEGS.tenure_1_3] };

// Mirror what the Summary card click handler does (DOM-free).
function clickCard(metricKey, segNorm) {
  state.metricKey = metricKey;
  state.visSel = summary.cardVisSel(metricKey, segNorm);
}

let passed = 0, failed = 0;
function assert(cond, msg) {
  if (cond) { passed++; console.log("  ✓ " + msg); }
  else { failed++; console.log("  ✗ " + msg); }
}

console.log("Tracking navigation — Summary → Visualise jump:");

// 1. cardVisSel shape: a sig card carries the clicked metric AND its cut.
let selObj = summary.cardVisSel("Q15::1", "tenure_1_3");
assert(selObj.metrics.length === 1 && selObj.metrics[0] === "Q15::1",
  "cardVisSel: clicked metric is the only metric");
assert(selObj.segs.length === 1 && selObj.segs[0] === "tenure_1_3",
  "cardVisSel: clicked segment cut is carried through");

// 2. KPI cards (no segment) and Total sig cards both resolve to Total.
assert(summary.cardVisSel("Q05::1", null).segs[0] === "total",
  "cardVisSel: KPI card (no segment) → Total");
assert(summary.cardVisSel("Q15::1", "").segs[0] === "total",
  "cardVisSel: empty segNorm (Total sig card) → Total");

// 3. THE REGRESSION: a stale prior selection must not survive the click.
//    Prior: user had Q05 / Between 1 and 3 years open in Visualise.
state.visSel = { metrics: ["Q05::1"], segs: ["tenure_1_3"] };
//    Now they click the Q15 · Between 1 and 3 years sig card.
clickCard("Q15::1", "tenure_1_3");
let sel = vis._selection();
assert(sel.metrics[0] === "Q15::1",
  "after clicking Q15 card, selection metric is Q15 (not the stale Q05)");
assert(sel.segs[0] === "tenure_1_3",
  "after clicking Q15 card, selection cut is the card's segment");
let specs = vis._seriesSpecs(sel);
assert(specs.length === 1 && specs[0].metric.code === "Q15",
  "seriesSpecs resolves to the Q15 metric");
assert(specs[0].segLabel === "Between 1 and 3 years",
  "seriesSpecs resolves to the 'Between 1 and 3 years' cut");

// 4. Clicking a Total KPI card from the same stale state lands on Total.
state.visSel = { metrics: ["Q05::1"], segs: ["tenure_1_3"] };
clickCard("Q15::1", null);
specs = vis._seriesSpecs(vis._selection());
assert(specs[0].metric.code === "Q15" && specs[0].segLabel === "Total",
  "KPI card click → Q15 · Total (segment reset, not inherited)");

// 5. Fallback: with no visSel, selection() builds Total from metricKey
//    (the path used when arriving without an explicit selection).
state.visSel = null;
state.metricKey = "Q15::1";
sel = vis._selection();
assert(sel.metrics[0] === "Q15::1" && sel.segs[0] === "total",
  "no visSel → selection falls back to metricKey · Total");

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
