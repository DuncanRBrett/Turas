#!/usr/bin/env node
/**
 * Regression tests for the 2026-07-02 production-audit statistics fixes
 * (docs/PRODUCTION_AUDIT_2026-07-02.md). Each case pins one confirmed bug:
 *
 *   1. zCrit / configured alpha: the recompute engine derives its critical z
 *      from the project's alpha + bonferroni flag (was hard-coded 1.96).
 *   2. sigLetters honours the per-banner Bonferroni divisor choose(k,2).
 *   3. sigPair never treats a weighted point's published (weighted) frequency
 *      as a respondent count just because n_eff === n (constant weights).
 *   4. indexFromDistribution refuses a PARTIAL category match (was silently
 *      re-normalising over a truncated distribution).
 *   5. Standard-deviation rows are untracked (was trending SD against MEANs).
 *   6. boxCounts uses the FULL answered base as denominator (no-box answers
 *      like Neutral stay in the base).
 *   7. FPC re-letter: census columns (ciBase Infinity) are excluded rather
 *      than NaN-erasing every pairing; disclosure-suppressed columns are
 *      excluded rather than tested as phantom 0%.
 *   8. Mean confidence intervals size on the Kish effective base.
 *   9. A saved custom banner whose question no longer exists renders Total
 *      only instead of crashing (missing-spec guard parity with composites).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/audit_stats_tests.mjs
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
vm.createContext(sandbox);
for (const file of ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js", "22_model.js",
  "23_render.js", "26_filter.js"]) {
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
function close(a, b, tol, msg) {
  if (Math.abs(a - b) > tol) throw new Error(msg + ": expected " + b + " ±" + tol + ", got " + a);
}

function setProject(project) {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;
  TR.AGG = { project: project, banner_groups: [], columns: [], questions: [] };
  if (TR.d2) TR.d2._qIndex = null;
}

console.log("Audit stats regressions — suite:");

/* ---------------- 1. critical z from the configured alpha ---------------- */

run("zCrit reproduces the conventional constants and a Bonferroni-adjusted level", () => {
  close(TR.stats.zCrit(0.05), 1.959964, 0.0005, "zCrit(0.05)");
  close(TR.stats.zCrit(0.20), 1.281552, 0.0005, "zCrit(0.20)");
  // 4-column banner, default config: alpha/choose(3,2) = 0.05/3 -> z ≈ 2.394
  close(TR.stats.zCrit(0.05 / 3), 2.39398, 0.001, "zCrit(0.05/3)");
});

run("zPrimary/zSecondary read the project's alpha, with 0.05/0.20 defaults", () => {
  setProject({});
  close(TR.stats.zPrimary(1), 1.959964, 0.0005, "default zPrimary");
  close(TR.stats.zSecondary(1), 1.281552, 0.0005, "default zSecondary");
  setProject({ alpha: 0.01, alpha_secondary: 0.10 });
  close(TR.stats.zPrimary(1), 2.575829, 0.0005, "alpha=0.01 zPrimary");
  close(TR.stats.zSecondary(1), 1.644854, 0.0005, "alpha_secondary=0.10 zSecondary");
});

/* ---------------- 2. sigLetters honours the Bonferroni divisor ---------------- */

// Total + 3 columns: 50% vs 42% on n=400 gives z ≈ 2.270 — significant at the
// plain 95% level (1.96) but NOT at the Bonferroni-adjusted 0.05/3 (z 2.394).
function pairCells() {
  return [
    { x: null, base: null },                 // Total — never tested
    { x: 200, base: 400 },                   // 50%
    { x: 168, base: 400 },                   // 42%
    { x: 168, base: 400 }                    // 42%
  ];
}
const LETTERS = ["", "B", "C", "D"];

run("bonferroni ON (the R default): a z=2.27 pair earns NO letter at 0.05/3", () => {
  setProject({ alpha: 0.05, bonferroni: true });
  const sigs = TR.stats.sigLetters(pairCells(), LETTERS, 30, false, false);
  eq(sigs[1], "", "column B letters under Bonferroni");
});

run("bonferroni OFF: the same pair letters at plain alpha", () => {
  setProject({ alpha: 0.05, bonferroni: false });
  const sigs = TR.stats.sigLetters(pairCells(), LETTERS, 30, false, false);
  eq(sigs[1], "CD", "column B letters without Bonferroni");
  eq(sigs[2], "", "column C letters");
});

/* ---------------- 3. sigPair on a weighted report ---------------- */

run("weighted report: sigPair uses %·n_eff even when n_eff === base (constant weights)", () => {
  setProject({ weighted: true });
  // Constant expansion weight 120: published x is the WEIGHTED frequency 6000,
  // base is the unweighted 100, Kish n_eff = 100 exactly.
  const p = { value: 50, base: 100, x: 6000, effBase: 100 };
  const pair = TR.waves._sigPair(p);
  close(pair.x, 50, 1e-9, "x must be %·n_eff, not the weighted frequency");
  eq(pair.base, 100, "base is the effective base");
});

run("unweighted report: sigPair keeps the exact integer count (byte-identical)", () => {
  setProject({});
  const p = { value: 50, base: 100, x: 50, effBase: 100 };
  const pair = TR.waves._sigPair(p);
  eq(pair.x, 50, "exact count");
  eq(pair.base, 100, "plain base");
});

/* ---------------- 4. indexFromDistribution partial match ---------------- */

run("a prior-wave index with a missing scored category returns null, never re-normalises", () => {
  setProject({});
  const q = { index_scores: { "Poor": 1, "Fair": 2, "Good": 3 } };
  const full = { rows: { poor: { pct: 20 }, fair: { pct: 30 }, good: { pct: 50 } } };
  const partial = { rows: { fair: { pct: 30 }, good: { pct: 50 } } };   // Poor renamed away
  close(TR.waves._indexFromDistribution(q, full, null), 2.3, 1e-9, "full match computes");
  eq(TR.waves._indexFromDistribution(q, partial, null), null, "partial match must be null");
});

/* ---------------- 5. SD rows are untracked ---------------- */

run("a Standard Deviation row produces no wave series (no fake decline vs the mean)", () => {
  setProject({});
  assert(TR.model.isStdDevRow("Standard Deviation"), "predicate: long form");
  assert(TR.model.isStdDevRow("Std. Dev."), "predicate: short form");
  assert(!TR.model.isStdDevRow("Mean"), "predicate: mean is not SD");
  const q = { code: "Q1" };
  const sdRow = { kind: "mean", label: "Standard Deviation" };
  const series = TR.waves.series(q, sdRow, 3, null);
  eq(series.length, 0, "SD row series must be empty");
});

/* ---------------- 6. boxCounts full answered base ---------------- */

run("boxCounts keeps no-box answers (Neutral) in the denominator", () => {
  setProject({});
  // 5 respondents, all answered; respondent 2 (Neutral) belongs to NO box.
  TR.MICRO = {
    n: 5,
    answers: { Q1: [0, 0, 2, 4, 4] },
    boxes: { Q1: [0, 0, null, 1, 1] },
    banner_vars: {}
  };
  const mask = new Uint8Array(5).fill(1);
  const c = TR.stats.boxCounts("Q1", 0, [{ member: null }], mask)[0];
  eq(c.base, 5, "answered base keeps the no-box respondent");
  eq(c.wbase, 5, "weighted base too");
  eq(c.n, 2, "box-0 hits");            // 2/5 = 40%, not 2/4 = 50%
});

/* ---------------- 7 + 8 + 9. model-level fixtures ---------------- */

// Unweighted population report: Total + B (census: base === N) + C + D.
// C 50% vs D 42% on n=400 -> z ≈ 2.270; bonferroni off so plain 1.96 applies.
function loadPopulationFixture(overrides) {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;
  TR.AGG = {
    project: Object.assign({ name: "Pop fixture", low_base_threshold: 30,
      population_size: 20000, bonferroni: false, alpha: 0.05 }, overrides || {}),
    banner_groups: [{ id: "Site", name: "Site" }],
    columns: [
      { label: "Total", letter: "", group: null, population: 20000 },
      { label: "HQ",    letter: "B", group: "Site", population: 50 },
      { label: "North", letter: "C", group: "Site", population: 10000 },
      { label: "South", letter: "D", group: "Site", population: 10000 }
    ],
    questions: [
      { code: "Q1", title: "Agree", type: "single", category: "Test",
        bases: [
          { n: 850, low: false },
          { n: 50,  low: false },     // census: base == N -> ciBase Infinity
          { n: 400, low: false },
          { n: 400, low: false }
        ],
        rows: [
          { kind: "category", label: "Yes", pct: [47, 40, 50, 42], n: [400, 20, 200, 168], sig: ["", "", "", ""] },
          { kind: "category", label: "No",  pct: [53, 60, 50, 58], n: [450, 30, 200, 232], sig: ["", "", "", ""] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
}

run("FPC re-letter: census column excluded (no NaN), others still letter", () => {
  loadPopulationFixture();
  const model = TR.model.forQuestion("Q1", "Site", [], {});
  const yes = model.rows[0];
  // C (50%) vs D (42%): z 2.27 -> C earns D's letter at the FPC-shrunk bases
  assert(yes.cells[2].sig.indexOf("D") !== -1,
    "C must letter vs D (got " + JSON.stringify(yes.cells[2].sig) + ")");
  // The census column neither earns nor grants letters — and never NaNs the row
  eq(yes.cells[1].sig, "", "census column has no letters");
  assert(yes.cells[2].sig.indexOf("B") === -1, "no letter can reference the census column");
});

run("FPC re-letter: a disclosure-suppressed column is never a phantom 0%", () => {
  loadPopulationFixture({ min_reporting_base: 60 });   // HQ base 50 -> suppressed
  const model = TR.model.forQuestion("Q1", "Site", [], {});
  const yes = model.rows[0];
  assert(model.columns[1].suppressed, "HQ column must be suppressed");
  eq(yes.cells[1].pct, null, "suppressed cell stays blank");
  eq(yes.cells[1].sig, "", "suppressed cell has no letters");
  for (const cell of yes.cells) {
    assert((cell.sig || "").toUpperCase().indexOf("B") === -1,
      "no visible column may letter against the suppressed column");
  }
});

run("mean CI sizes on the Kish effective base on a weighted report", () => {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;
  TR.AGG = {
    project: { name: "W", low_base_threshold: 30, weighted: true },
    banner_groups: [{ id: "Gender", name: "Gender" }],
    columns: [
      { label: "Total", letter: "", group: null },
      { label: "Male", letter: "B", group: "Gender" }
    ],
    questions: [
      { code: "Q1", title: "Rating", type: "scale", category: "Test",
        index_scores: { "Low": 1, "High": 5 },
        bases: [
          { n: 600, low: false, nWeighted: 640, nEff: 520 },
          { n: 300, low: false, nWeighted: 320, nEff: 260 }
        ],
        rows: [
          { kind: "category", label: "Low",  pct: [40, 45], n: [256, 144], sig: ["", ""] },
          { kind: "category", label: "High", pct: [60, 55], n: [384, 176], sig: ["", ""] },
          { kind: "mean", label: "Index", pct: [3.4, 3.2], n: [null, null], sig: ["", ""] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
  const model = TR.model.forQuestion("Q1", "Gender", [], { intervals: true });
  const meanRow = model.rows[2];
  const ci = meanRow.cells[0].ci;
  assert(ci, "mean CI attached");
  // Expected half-width on n_eff = 520 (NOT the raw n = 600): the same SD
  // source the renderer uses, so only the base can differ.
  const scores = TR.waves.scoreMap(TR.AGG.questions[0], meanRow);
  const pairs = Object.keys(scores).map(ri => ({
    p: model.rows[ri].cells[0].pct, s: scores[ri]
  }));
  const sd = TR.waves.sdFromPairs(pairs);
  const onEff = TR.conf.meanCI(3.4, sd, 520);
  const onRaw = TR.conf.meanCI(3.4, sd, 600);
  close(ci.hi - ci.lo, onEff.hi - onEff.lo, 1e-9, "CI width must match the effective base");
  assert(Math.abs((ci.hi - ci.lo) - (onRaw.hi - onRaw.lo)) > 1e-6,
    "CI width must NOT match the raw base");
});

run("a custom banner whose question was dropped renders Total only, no crash", () => {
  loadPopulationFixture();
  TR.MICRO = { n: 10, answers: { Q1: [0,0,0,1,1,1,0,1,0,1] }, banner_vars: {}, boxes: {} };
  const spec = TR.stats.columnsFor("custom:GONE:net");
  assert(spec.custom, "custom flag");
  assert(spec.missing, "missing flag set");
  eq(spec.columns.length, 1, "Total only");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
