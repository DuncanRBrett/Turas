#!/usr/bin/env node
/**
 * Gate: a segment's history point is sized on its effective base.
 *
 * Segment and computed-totals history waves carry no per-respondent weights,
 * so the renderer sized a weighted segment's wave-on-wave test on the raw
 * respondent count and over-stated its precision (review 2026-09-24). The
 * tracker now writes each segment's Kish n_eff as eff_bases[seg], and the
 * Total's as eff_base (tracking_segment_bridge.R). This asserts the history
 * series picks them up, and that a wave without them (an older sidecar) keeps
 * falling back to the plain base exactly as before.
 *
 * Runs against the SHIPPED module JS (modules/tabs/lib/html_report_v2/assets/js).
 *
 * Run with:  node modules/tabs/tests/js/test_segment_wave_effective_base.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/tabs/lib/html_report_v2/assets/js");
const TESTS = path.join(ROOT, "modules/tabs/lib/html_report_v2/tests");

const { installText } = await import(path.join(TESTS, "_text.mjs"));
const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
installText(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js", "22_model.js"]) {
  vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;

let failures = 0;
function check(label, actual, expected) {
  const ok = Object.is(actual, expected);
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: expected ${expected}, got ${actual}`}`);
}

/** One rating question in the live report and one prior wave of history. */
function seed(priorQuestion) {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;
  TR.AGG = {
    project: { name: "Weighted segments", low_base_threshold: 30, weighted: true },
    banner_groups: [],
    columns: [{ label: "Total", letter: "", group: null }],
    questions: [
      { code: "QM", title: "Overall satisfaction", type: "scale", scale_max: 10, category: "T",
        bases: [{ n: 600, low: false }],
        rows: [
          { kind: "category", label: "5", pct: [50], n: [300], sig: [""] },
          { kind: "category", label: "8", pct: [50], n: [300], sig: [""] },
          { kind: "mean", label: "Mean", pct: [6.8], n: [null], sig: [""] }
        ] }
    ]
  };
  TR.PREV = { waves: [
    Object.assign({ match_key: "overall satisfaction", title: "Overall satisfaction" }, priorQuestion)
  ].map((q) => ({ wave: "2025", year: 2025, current: false,
    segments: [{ norm: "north", label: "North", group: "Region" }], questions: [q] })) };
  if (TR.d2) TR.d2._qIndex = null;
  if (TR.waves.reset) TR.waves.reset();
  const q = TR.AGG.questions[0];
  const row = TR.model.forQuestion("QM", null, [], {}).rows[2];
  return { q, row };
}

const weightedPrior = {
  base: 600, eff_base: 320.5, stats: { mean: 6.6, index: 6.6, sd: 2.1 },
  seg_stats: { north: { mean: 6.58, index: 6.58, sd: 2.09 } },
  bases: { north: 291 }, eff_bases: { north: 155.1 }
};

{
  const { q, row } = seed(weightedPrior);
  const seg = TR.waves.series(q, row, 2, "north");
  check("the segment history point keeps its respondent base", seg[0].base, 291);
  check("the segment history point is sized on its effective base", seg[0].effBase, 155.1);
  const tot = TR.waves.series(q, row, 2, null);
  check("a computed Total history point is sized on its carried effective base",
    tot[0].effBase, 320.5);
}

{
  const older = Object.assign({}, weightedPrior);
  delete older.eff_base;
  delete older.eff_bases;
  const { q, row } = seed(older);
  const seg = TR.waves.series(q, row, 2, "north");
  check("an older sidecar without eff_bases falls back to the plain base",
    seg[0].effBase, undefined);
  check("and still carries that plain base", seg[0].base, 291);
}

console.log(failures === 0 ? "\nAll segment effective-base checks passed." : `\n${failures} check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
