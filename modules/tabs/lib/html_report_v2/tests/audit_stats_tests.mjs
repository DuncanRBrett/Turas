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
 *   7. FPC on the published view: intervals narrow on the FPC-corrected base,
 *      and significance is NOT recomputed here — R applies the correction in
 *      its own tests and the letters are carried. Disclosure-suppressed
 *      columns still neither earn nor grant a letter.
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
import { TXT, installText, blockOf } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
installText(sandbox);
for (const file of ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js", "22_model.js",
  "23_render.js", "26_filter.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + (process.env.TRACE ? e.stack : e.message)); }
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

/* ---------------- 6b. netScoreMeans (NET POSITIVE) ---------------- */

run("netScoreMeans scores +-100 off box membership and means to the printed net", () => {
  setProject({});
  // 6 respondents: 3 in the favourable box (row 1), 2 in the unfavourable box
  // (row 0), 1 answered into NO box. Printed net = (3 - 2)/6 * 100 = 16.6667,
  // and the score mean must equal it — that equality is the whole method
  // (review 2026-08, I5).
  TR.MICRO = {
    n: 6,
    answers: { Q1: [4, 4, 4, 1, 1, 3] },
    boxes: { Q1: [1, 1, 1, 0, 0, null] },
    banner_vars: {}
  };
  const mask = new Uint8Array(6).fill(1);
  const m = TR.stats.netScoreMeans("Q1", 1, 0, [{ member: null }], mask)[0];

  close(m.mean, 100 / 6, 1e-9, "mean IS the printed net");
  eq(m.k, 6, "the no-box respondent stays in the base");
  // Population variance = sum(w s^2)/wbase - mean^2 = 50000/6 - (100/6)^2
  //                     = 8333.333333 - 277.777778 = 8055.555556
  // Sample variance      = 8055.555556 * 6/5 = 9666.666667  ->  sd = 98.319208
  close(m.sd, Math.sqrt(9666.6666667), 1e-6, "sd is the Bessel-scaled score sd");
});

run("netScoreMeans variance equals the correlated-proportions variance", () => {
  setProject({});
  // The identity the decision rests on: for X in {+1,0,-1} with P(+1)=t and
  // P(-1)=b, Var(X) = t + b - (t - b)^2, which is exactly n * Var(p_top -
  // p_bottom) under the multinomial. Here t = 0.5, b = 0.25 (8 respondents):
  //   t + b - (t - b)^2 = 0.75 - 0.0625 = 0.6875  ->  6875 on the +-100 scale.
  TR.MICRO = {
    n: 8,
    answers: { Q1: [4, 4, 4, 4, 1, 1, 3, 3] },
    boxes: { Q1: [1, 1, 1, 1, 0, 0, null, null] },
    banner_vars: {}
  };
  const mask = new Uint8Array(8).fill(1);
  const m = TR.stats.netScoreMeans("Q1", 1, 0, [{ member: null }], mask)[0];
  close(m.mean, 25, 1e-9, "net = 50% - 25% = +25");
  // sd is the SAMPLE sd (population variance scaled by k/(k-1) = 8/7).
  close(m.sd * m.sd * 7 / 8, 6875, 1e-6, "population variance = t + b - (t-b)^2");
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
          // sig[] is what R published. The census column (HQ) carries none and
          // is named by none — R excludes a full census from pairing.
          { kind: "category", label: "Yes", pct: [47, 40, 50, 42], n: [400, 20, 200, 168], sig: ["", "", "D", ""] },
          { kind: "category", label: "No",  pct: [53, 60, 50, 58], n: [450, 30, 200, 232], sig: ["", "", "", "C"] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
}

// The published view USED to re-letter a population report here, from the
// display-rounded %s and each column's FPC ciBase. That overlay is retired: R
// applies the FPC inside its own tests, so the carried letters are already
// corrected — at both alphas, on weighted designs too, and from the unrounded
// counts. This pins that the view now passes them through untouched.
run("FPC: the published view carries R's letters and does not re-letter", () => {
  loadPopulationFixture();
  const model = TR.model.forQuestion("Q1", "Site", [], {});
  const yes = model.rows[0], no = model.rows[1];
  eq(yes.cells[2].sig, "D", "C keeps exactly the letter R published");
  eq(no.cells[3].sig, "C", "and so does D on the No row");
  // The census column neither earns nor grants a letter — R excluded it.
  eq(yes.cells[1].sig, "", "census column has no letters");
  assert(yes.cells[2].sig.indexOf("B") === -1, "no letter references the census column");
});

run("FPC: the census column still gets an infinite ciBase for its interval", () => {
  loadPopulationFixture();
  const model = TR.model.forQuestion("Q1", "Site", [], { intervals: true });
  // HQ: base 50 of a universe of 50 -> nothing left to be uncertain about.
  eq(model.columns[1].ciBase, Infinity, "census ciBase is Infinity");
  // North: 400 of 10000 is 4% coverage — below FPC_MIN_COVERAGE (5%), so the
  // correction does not engage and the interval base is the raw base.
  eq(model.columns[2].ciBase, 400, "a below-floor column keeps its raw base");
});

run("a disclosure-suppressed column neither earns nor grants a letter", () => {
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

run("display precision: value and change use the config's DECIMAL PLACES", () => {
  TR.AGG = { project: { format: { percent_decimals: 0, rating_decimals: 1 } } };
  const pt = (v, cur) => ({ wave: "w", year: 2025, value: v, base: 753, sd: 1.2, current: !!cur });
  // a mean: 9.136 -> 9.160 is +0.024 raw, but the reader sees 9.1 and 9.2
  const m = TR.waves.cellsFor([pt(9.136), pt(9.160, true)], false, "95", 1);
  eq(m[0].value, 9.1, "prior mean shown at 1 decimal");
  eq(m[1].value, 9.2, "current mean shown at 1 decimal");
  eq(m[1].change_prev, 0.1, "change is the difference of the two SHOWN figures");
  // an NPS at 0 places: 78.272 -> 79.42 reads 78 -> 79, change +1
  const n = TR.waves.cellsFor([pt(78.272), pt(79.42, true)], true, "95", 0);
  eq(n[0].value, 78, "prior NPS at 0 decimals");
  eq(n[1].value, 79, "current NPS at 0 decimals");
  eq(n[1].change_prev, 1, "NPS change reconciles with the two shown figures");
});

run("display precision falls back sanely when a report predates project.format", () => {
  TR.AGG = { project: {} };
  eq(TR.fmt.decimalsFor(true), 1, "means default to 1 decimal");
  eq(TR.fmt.decimalsFor(false), 0, "percentages default to 0");
  eq(TR.fmt.score(9.16), "9.2", "fmt.score still rounds to 1 without config");
});

run("SIGNIFICANCE still reads the RAW values, never the rounded ones", () => {
  TR.AGG = { project: { format: { percent_decimals: 0, rating_decimals: 1 } } };
  const pt = (v, cur) => ({ wave: "w", year: 2025, value: v, base: 4000,
    sd: 0.5, effBase: 4000, current: !!cur });
  // 9.14 -> 9.16 rounds to 9.1 -> 9.2, i.e. a SHOWN change of +0.1, while the
  // real move is 0.02. On a large base the raw Welch test must judge the real
  // move — the displayed rounding must not manufacture significance.
  const c = TR.waves.cellsFor([pt(9.14), pt(9.16, true)], false, "95", 1);
  eq(c[1].change_prev, 0.1, "the SHOWN change is 0.1");
  assert(c[1].sig_prev === false,
    "a 0.02 move is not significant, however it displays");
  // and a real move stays significant even though it displays identically
  const d = TR.waves.cellsFor([pt(8.60), pt(9.16, true)], false, "95", 1);
  assert(d[1].sig_prev === true, "a real 0.56 move on n=4000 is significant");
});

run("an NPS takes PERCENT places, not ratings places (it is mean-KIND, 0-100)", () => {
  TR.AGG = { project: { format: { percent_decimals: 0, rating_decimals: 1 } } };
  eq(TR.fmt.decimalsForQ({ type: "scale", scale_max: 10 }, true), 1, "a rating -> 1");
  eq(TR.fmt.decimalsForQ({ type: "nps", scale_max: 100 }, true), 0, "an NPS -> 0");
  eq(TR.fmt.decimalsForQ({ scale_max: 100 }, true), 0, "0-100 scale alone is enough");
  eq(TR.fmt.decimalsForQ(null, true), 1, "no question -> the ratings default");
  eq(TR.fmt.decimalsForQ({ type: "scale", scale_max: 10 }, false), 0, "a proportion row -> 0");
});


run("crosstab tableHtml honours DECIMAL PLACES — no fake NPS decimal (I13)", () => {
  // The island stores what the engine published: NPS 79 (percent places, 0dp),
  // rating mean 4.3 (rating places, 1dp). The crosstab tab hard-coded
  // toFixed(1), re-adding a digit the published table never had ("79.0").
  TR.AGG = { project: { format: { percent_decimals: 0, rating_decimals: 1 } } };
  const npsModel = {
    code: "QN", title: "Recommend", type: "nps", scale_max: 100,
    columns: [{ label: "Total", letter: "A", base: 100 }],
    rows: [{ kind: "mean", label: "NPS Score",
      cells: [{ mean: 79, n: null, pct: null, sig: "" }] }]
  };
  const html = TR.render.tableHtml(npsModel, {});
  assert(html.indexOf(">79<") >= 0, "NPS renders as 79, got: " + html.match(/class="mv">[^<]*/));
  assert(html.indexOf("79.0") < 0, "no fake decimal on an integer-published NPS");

  const ratingModel = {
    code: "QR", title: "Rating", type: "scale", scale_max: 10,
    columns: [{ label: "Total", letter: "A", base: 100 }],
    rows: [{ kind: "mean", label: "Mean",
      cells: [{ mean: 4.3, n: null, pct: null, sig: "" }] }]
  };
  const rhtml = TR.render.tableHtml(ratingModel, {});
  assert(rhtml.indexOf(">4.3<") >= 0, "rating mean keeps its 1dp");
});

run("crosstab tableHtml shows percent_decimals=1 percentages (I13)", () => {
  TR.AGG = { project: { format: { percent_decimals: 1, rating_decimals: 1 } } };
  const m = {
    code: "Q1", title: "Q", type: "single", scale_max: null,
    columns: [{ label: "Total", letter: "A", base: 100 }],
    rows: [{ kind: "category", label: "Yes",
      cells: [{ mean: null, n: 46, pct: 46.3, sig: "" }] }]
  };
  const html = TR.render.tableHtml(m, {});
  assert(html.indexOf("46.3%") >= 0, "1dp percent renders 46.3%, got: " + html.match(/class="v">[^<]*/));
});

run("crosstab export matrix uses the same config precision (I13)", () => {
  TR.AGG = { project: { format: { percent_decimals: 0, rating_decimals: 1 } } };
  const m = {
    code: "QN", title: "Recommend", type: "nps", scale_max: 100,
    columns: [{ label: "Total", letter: "A", base: 100 }],
    rows: [{ kind: "mean", label: "NPS Score",
      cells: [{ mean: 79, n: null, pct: null, sig: "" }] }]
  };
  const mat = TR.render.matrix(m, {});
  const flat = JSON.stringify(mat);
  assert(flat.indexOf("79.0") < 0, "matrix carries 79, not 79.0: " + flat.slice(0, 200));
});


run("attachDeltas tests a mean's RAW current value, not the rounded cell (I3)", () => {
  // Prior wave: mean 8.8, sd 1.0, n 800. Current raw mean 8.86 (published cell
  // rounds to 8.9). Welch criticals at these bases: ~0.098 (95%), ~0.064 (80%).
  //   raw delta 0.06     -> not significant at ANY level (the truth)
  //   rounded delta 0.10 -> "significant at 95%" (the old, wrong input)
  // The chip must agree with the Tracking tab, which tests raw scores.
  const scores = [];
  for (let i = 0; i < 400; i++) scores.push(7.86);
  for (let i = 0; i < 400; i++) scores.push(9.86);   // mean 8.86, sd ~1.0
  setProject({ name: "I3", low_base_threshold: 30, weighted: false });
  TR.AGG.questions = [
    { code: "QM", title: "Overall rating", type: "scale", scale_max: 10, category: "T",
      bases: [{ n: 800, low: false }],
      rows: [
        { kind: "category", label: "7.86", pct: [50], n: [400], sig: [""] },
        { kind: "category", label: "9.86", pct: [50], n: [400], sig: [""] },
        { kind: "mean", label: "Mean", pct: [8.9], n: [null], sig: [""] }
      ] }
  ];
  TR.AGG.columns = [{ label: "Total", letter: "", group: null }];
  TR.AGG.banner_groups = [];
  TR.PREV = { waves: [
    { wave: "2025", year: 2025, current: false, segments: [],
      questions: [{ match_key: "overall rating", title: "Overall rating",
        base: 800, stats: { mean: 8.8, sd: 1.0 } }] },
    { wave: "2026", year: 2026, current: true, segments: [],
      questions: [{ code: "QM", match_key: "overall rating", title: "Overall rating",
        base: 800, score_type: "mean", scores: scores, weights: null }] }
  ] };
  TR.MICRO = null;
  if (TR.d2) TR.d2._qIndex = null;
  if (TR.waves.reset) TR.waves.reset();
  const model = TR.model.forQuestion("QM", null, [], {});
  const row = model.rows[2];
  assert(row.delta, "the mean row carries a wave delta");
  assert(!row.delta.sig,
    "raw delta 0.06 is not significant - the rounded cell's 0.10 must not flip it (got sig=" +
    JSON.stringify(row.delta.sig) + ")");
  // the DISPLAYED delta still reconciles with the published figures (rounded ends)
  eq(row.delta.diff, 0.1, "displayed delta subtracts the rounded ends (8.9 - 8.8)");
});


run("attachDeltas tests a WEIGHTED proportion's raw share, not the rounded cell (I3)", () => {
  // The proportion half of I3. Weighted report, n_eff 600 both waves, prior 50%.
  // The published cell rounds to 56%, but the exact weighted share is 55.5%
  // (5550/10000):
  //   rounded 56.0% -> pooled z ≈ 2.08 -> "significant at 95%" (the old input)
  //   raw     55.5% -> pooled z ≈ 1.91 -> not significant (the truth)
  // A 0dp weighted report hides half a point in every cell; the test must not.
  setProject({ name: "I3p", low_base_threshold: 30, weighted: true });
  TR.AGG.questions = [
    { code: "QP", title: "Uses the service", type: "single", category: "T",
      bases: [{ n: 800, nWeighted: 10000, nEff: 600, low: false }],
      rows: [
        { kind: "category", label: "Yes", pct: [56], n: [5550], sig: [""] },
        { kind: "category", label: "No", pct: [44], n: [4450], sig: [""] }
      ] }
  ];
  TR.AGG.columns = [{ label: "Total", letter: "", group: null }];
  TR.AGG.banner_groups = [];
  TR.PREV = { waves: [
    { wave: "2025", year: 2025, current: false, segments: [],
      questions: [{ match_key: "uses the service", title: "Uses the service",
        base: 600, rows: { yes: { pct: 50 }, no: { pct: 50 } } }] }
  ] };
  TR.MICRO = null;
  if (TR.d2) TR.d2._qIndex = null;
  if (TR.waves.reset) TR.waves.reset();
  const model = TR.model.forQuestion("QP", null, [], {});
  const row = model.rows[0];
  assert(row.delta, "the Yes row carries a wave delta");
  assert(!row.delta.sig,
    "raw 55.5% vs 50% is not significant — the rounded 56% must not flip it (got sig=" +
    JSON.stringify(row.delta.sig) + ")");
  // the DISPLAYED delta still reconciles with the published figures
  eq(row.delta.diff, 6, "displayed delta subtracts the published cells (56 - 50)");
});

/* ---- heatmap_colour: a documented setting that read nothing (I11) ---------
 * The crosstab heat tint took TR.charts.brandOf() unconditionally, so
 * `heatmap_colour` — whitelisted, shipped in the template and documented as
 * "set explicitly to override without changing other colours" — was a silent
 * no-op. The island now carries the field ONLY when the config sets it, so an
 * unset report must tint exactly as before.
 */
run("heatOf falls back to the brand colour when the island carries no override", () => {
  setProject({ brand_colour: "#123456" });
  eq(TR.charts.heatOf(), "#123456", "unset -> brand colour, byte-identical to before");
});

run("heatOf uses heatmap_colour when the config set one", () => {
  setProject({ brand_colour: "#123456", heatmap_colour: "#B02020" });
  eq(TR.charts.heatOf(), "#B02020", "the override wins");
  eq(TR.charts.brandOf(), "#123456", "…without disturbing the brand colour");
});

run("the tint actually renders in the override colour, not the brand colour", () => {
  // brandOf is #123456 = rgb(18,52,86); the override is #B02020 = rgb(176,32,32).
  setProject({ brand_colour: "#123456", heatmap_colour: "#B02020" });
  const model = { columns: [{ label: "Total", letter: "", base: 100 }],
    rows: [{ kind: "category", label: "Yes", stat: "Column %",
             cells: [{ pct: 100, n: 100, sig: "" }] }] };
  const html = TR.render.tableHtml(model, { heatmap: "heat" });
  assert(/176\s*,\s*32\s*,\s*32/.test(html),
    "the override colour reaches the cell background: " + (html.match(/rgba\([^)]*\)/) || [])[0]);
  assert(!/18\s*,\s*52\s*,\s*86/.test(html), "and the brand colour does not");
});

run("with no override the tint is the brand colour, as it always was", () => {
  setProject({ brand_colour: "#123456" });
  const model = { columns: [{ label: "Total", letter: "", base: 100 }],
    rows: [{ kind: "category", label: "Yes", stat: "Column %",
             cells: [{ pct: 100, n: 100, sig: "" }] }] };
  const html = TR.render.tableHtml(model, { heatmap: "heat" });
  assert(/18\s*,\s*52\s*,\s*86/.test(html), "brand colour tints the cell");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
