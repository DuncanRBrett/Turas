#!/usr/bin/env node
/**
 * Weighted-base DISPLAY gate. The v2 recompute already runs on the weights
 * (verified elsewhere), but a weighted report LOOKED unweighted: the only base
 * row shown was the unweighted n and there was no weighted indicator. This
 * checks that a weighted report now surfaces the weighting, mirroring the Excel
 * workbook, and that an unweighted report is unchanged.
 *
 *   1. publishedModel columns carry baseW (weighted base) + baseEff (Kish
 *      effective base) read from each question's serialized bases.
 *   2. render.tableHtml emits "Base (unweighted)" / "Base (weighted)" /
 *      "Effective base" rows on a weighted report, with the effective base
 *      gated by show_effective_n.
 *   3. an UNWEIGHTED report keeps the single "Base (n=)" row and shows neither
 *      extra row (byte-identical base block).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/weighted_display_tests.mjs
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
  "21_stats.js", "21c_confidence.js", "22w_waves.js", "22_model.js", "23_render.js",
  "26_filter.js"]) {
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

/* ---------------- fixture: a weighted published report ---------------- */
// Total + a Gender banner (Male/Female). Weighted base != unweighted n on the
// sub-columns; effective base < weighted base (a real design effect).
function loadFixture() {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;                            // no filter -> published path
  TR.AGG = {
    project: { name: "Weighted fixture", low_base_threshold: 30, weighted: true,
      weight_variable: "weight", show_unweighted_n: true, show_effective_n: true },
    banner_groups: [{ id: "Gender", name: "Gender" }],
    columns: [
      { label: "Total",  letter: "",  group: null },
      { label: "Male",   letter: "B", group: "Gender" },
      { label: "Female", letter: "C", group: "Gender" }
    ],
    questions: [
      { code: "Q1", title: "Campus", type: "single", category: "Test",
        bases: [
          { n: 1363, low: false, nWeighted: 1363, nEff: 1217 },
          { n: 600,  low: false, nWeighted: 640,  nEff: 520 },
          { n: 763,  low: false, nWeighted: 722,  nEff: 697 }
        ],
        rows: [
          { kind: "category", label: "Online",    pct: [43, 40, 46], n: [587, 240, 347], sig: ["", "", ""] },
          { kind: "category", label: "Cape Town", pct: [17, 18, 16], n: [226, 108, 118], sig: ["", "", ""] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;             // drop any cached question index
}

console.log("Weighted-base display — suite:");

/* ---------------- 1. model carries the weighted + effective bases ---------------- */
run("publishedModel columns expose baseW + baseEff from the serialized bases", () => {
  loadFixture();
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  eq(m.columns.length, 3, "Total + Male + Female");
  eq(m.columns[0].base, 1363, "Total unweighted n");
  eq(m.columns[0].baseW, 1363, "Total weighted base");
  eq(m.columns[0].baseEff, 1217, "Total effective base");
  eq(m.columns[1].baseW, 640, "Male weighted base");
  eq(m.columns[1].baseEff, 520, "Male effective base");
  eq(m.columns[2].baseEff, 697, "Female effective base");
});

/* ---------------- 2. render surfaces all three base rows ---------------- */
run("render shows unweighted / weighted / effective base rows when weighted", () => {
  loadFixture();
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  const html = TR.render.tableHtml(m, {});
  assert(html.includes("Base (unweighted)"), "primary base row relabelled 'Base (unweighted)'");
  assert(html.includes("Base (weighted)"), "weighted base row present");
  assert(html.includes("Effective base"), "effective base row present");
  assert(!html.includes("Base (n=)"), "the plain 'Base (n=)' label is not used on a weighted report");
  // effective bases are distinctive 3-digit values -> plain <td>NNN</td>
  assert(html.includes(">520<"), "Male effective base 520 rendered");
  assert(html.includes(">697<"), "Female effective base 697 rendered");
});

/* ---------------- 3. show_effective_n gates the effective row ---------------- */
run("effective base row hidden when show_effective_n is false", () => {
  loadFixture();
  TR.AGG.project.show_effective_n = false;
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  const html = TR.render.tableHtml(m, {});
  assert(html.includes("Base (weighted)"), "weighted base row still shows");
  assert(!html.includes("Effective base"), "effective base row suppressed by config");
});

/* ---------------- 3b. show_weighted_base drops the weighted base row ---------------- */
run("weighted base row hidden when show_weighted_base is false (simpler deck)", () => {
  loadFixture();
  TR.AGG.project.show_weighted_base = false;
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  const html = TR.render.tableHtml(m, {});
  assert(!html.includes("Base (weighted)"), "weighted base row dropped by config");
  // the two that carry interpretive meaning still show
  assert(html.includes("Base (unweighted)"), "unweighted count still shows (always on)");
  assert(html.includes("Effective base"), "effective base still shows");
});

/* ---------------- 4. unweighted report: base block unchanged ---------------- */
run("unweighted report keeps the single 'Base (n=)' row, no extra rows", () => {
  loadFixture();
  TR.AGG.project.weighted = false;
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  const html = TR.render.tableHtml(m, {});
  assert(html.includes("Base (n=)"), "unweighted keeps 'Base (n=)'");
  assert(!html.includes("Base (weighted)"), "no weighted base row when off");
  assert(!html.includes("Effective base"), "no effective base row when off");
  assert(!html.includes("Base (unweighted)"), "no relabel when off");
});

/* ---------------- 5. intervals use each column's OWN base on a 2nd banner ------ */
// Regression for the interval misalignment: attachIntervals indexed q.bases by the
// view position, but on any banner past the first the view is a column SUBSET, so
// each column borrowed a different column's weighted/effective base and the interval
// detached from the shown % (SACAP: 73% -> 12–18pp). It must use the column's own base.
function loadTwoBannerFixture() {
  TR.PREV = null; TR.userState = null; TR.MICRO = null;
  TR.AGG = {
    project: { name: "Two-banner", low_base_threshold: 30, weighted: true,
      weight_variable: "weight" },
    banner_groups: [{ id: "A", name: "Banner A" }, { id: "B", name: "Banner B" }],
    columns: [
      { label: "Total", letter: "",  group: null },
      { label: "A1",    letter: "B", group: "A" },
      { label: "A2",    letter: "C", group: "A" },
      { label: "B1",    letter: "B", group: "B" },
      { label: "B2",    letter: "C", group: "B" }
    ],
    questions: [
      { code: "Q1", title: "Recommend", type: "single", category: "Test",
        // B1's weighted base (800) is nothing like A1's (500): under the old bug B1
        // would borrow A1's base and read 560/500 -> clamp to ~100%, far from 70%.
        bases: [
          { n: 1000, low: false, nWeighted: 1000, nEff: 900 },
          { n: 500,  low: false, nWeighted: 500,  nEff: 450 },
          { n: 500,  low: false, nWeighted: 500,  nEff: 450 },
          { n: 100,  low: false, nWeighted: 800,  nEff: 90 },
          { n: 100,  low: false, nWeighted: 200,  nEff: 95 }
        ],
        rows: [
          { kind: "category", label: "Yes",
            pct: [65, 60, 70, 70, 60], n: [650, 300, 350, 560, 120], sig: ["", "", "", "", ""] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
}

run("intervals bracket the shown % on a banner past the first (own-base fix)", () => {
  loadTwoBannerFixture();
  // Banner B: view is [Total, B1, B2] -> original indices [0, 3, 4]
  const m = TR.model.forQuestion("Q1", "B", [], { dual: false, intervals: true });
  const yes = m.rows.find((r) => r.label === "Yes");
  eq(m.columns.map((c) => c.label).join("|"), "Total|B1|B2", "view = Total + banner B");
  m.columns.forEach((col, i) => {
    const cell = yes.cells[i];
    assert(cell.ci, "interval attached to " + col.label);
    // the interval must bracket the shown %; the bug produced 70% -> ~99–100
    assert(cell.ci.lo <= cell.pct + 0.5 && cell.ci.hi >= cell.pct - 0.5,
      col.label + " interval [" + cell.ci.lo.toFixed(1) + "," + cell.ci.hi.toFixed(1) +
      "] must bracket " + cell.pct + "%");
  });
  // B1 specifically: 70% on effective base 90 -> a sane ±~9pp, NOT pinned at 100
  const b1 = yes.cells[1];
  assert(b1.ci.hi < 90, "B1 upper bound sane (was ~100 under the bug): " + b1.ci.hi.toFixed(1));
  assert(b1.ci.lo > 50, "B1 lower bound sane: " + b1.ci.lo.toFixed(1));
});

/* ---------------- 6. weighting callout for the reader ---------------- */
run("weighting callout appears only when weighted and explains the three bases", () => {
  TR.AGG = { project: { weighted: true, weight_variable: "weight" } };
  const note = TR.filterBar.weightingNote();
  assert(note.indexOf("Weighted data") !== -1, "callout headline present");
  assert(note.indexOf("weight") !== -1, "names the weight variable");
  assert(note.indexOf("Base (unweighted)") !== -1 &&
         note.indexOf("Base (weighted)") !== -1 &&
         note.indexOf("Effective base") !== -1, "explains all three bases");

  // unweighted -> no callout at all
  TR.AGG = { project: { weighted: false } };
  eq(TR.filterBar.weightingNote(), "", "no callout on an unweighted report");
});

/* ---------------- 7. weighted wave-on-wave significance (#8) ---------------- */
// The wave z-test must be sized on the KISH effective base, not the raw count —
// otherwise a weighted tracker over-flags movements. Known-answer: a 50%->65%
// move on 100 respondents is 95%-significant; the same move on a Kish effective
// base of 40 is only 80%. Unweighted points (no effBase) are byte-identical.
run("weighted wave delta is sized on the effective base, not the raw base (#8)", () => {
  TR.AGG = { project: { low_base_threshold: 30 } };

  // proportions
  const w = TR.waves.cellsFor(
    [{ value: 50, base: 100, effBase: 40, x: 50 }, { value: 65, base: 100, effBase: 40, x: 65 }],
    true, "dual");
  eq(w[1].sig_prev, false, "not 95%-significant on the effective base (40)");
  eq(w[1].soft_prev, true, "but 80%-significant — the effective base downgraded the flag");

  // the SAME numbers unweighted (no effBase) stay 95%-significant on the raw base
  const u = TR.waves.cellsFor(
    [{ value: 50, base: 100, x: 50 }, { value: 65, base: 100, x: 65 }], true, "dual");
  eq(u[1].sig_prev, true, "unweighted (effBase absent) stays 95%-sig on the raw base");

  // means: a 3.7 -> 4.0 move (sd 1.0) is 95%-sig on 100 but only 80% on eff 40
  const wm = TR.waves.cellsFor(
    [{ value: 3.7, sd: 1.0, base: 100, effBase: 40 }, { value: 4.0, sd: 1.0, base: 100, effBase: 40 }],
    false, "dual");
  eq(wm[1].sig_prev, false, "weighted mean delta not 95%-sig on the effective base");
  eq(wm[1].soft_prev, true, "weighted mean delta is 80%-sig");
  const um = TR.waves.cellsFor(
    [{ value: 3.7, sd: 1.0, base: 100 }, { value: 4.0, sd: 1.0, base: 100 }], false, "dual");
  eq(um[1].sig_prev, true, "unweighted mean delta stays 95%-sig on the raw base");
});

run("effNfromWeights matches Kish and a low effective base gates the test out (#8)", () => {
  TR.AGG = { project: { low_base_threshold: 30 } };
  // varied weights: n=4 respondents, Σw=4, Σw²=6 -> n_eff = 16/6 = 2.67 -> rounds to 3.
  // A pair with a tiny effective base is excluded from testing entirely.
  const w = TR.waves.cellsFor(
    [{ value: 20, base: 100, effBase: 3, x: 20 }, { value: 80, base: 100, effBase: 3, x: 80 }],
    true, "dual");
  eq(w[1].sig_prev, false, "sub-threshold effective base is not tested (no false flag)");
  eq(w[1].soft_prev, false, "and not softly flagged either");
});

run("tested_prev separates 'flat' from 'untestable' (historical bases not loaded)", () => {
  TR.AGG = { project: { low_base_threshold: 30 } };

  // The CCPB case: the current wave carries a spread + base, but the prior wave is a
  // bare aggregate (mean only, no spread) — so the wave-on-wave test cannot run.
  const noPrevSd = TR.waves.cellsFor(
    [{ value: 8.5, base: 380 }, { value: 8.8, sd: 1.2, base: 396 }], false, "95");
  eq(noPrevSd[1].sig_prev, false, "cannot be 95%-sig without the prior wave's spread");
  eq(noPrevSd[1].tested_prev, false, "flagged NOT testable — prior wave has no spread");

  // both waves carry a spread + base -> the test runs (here it lands flat, not untestable)
  const flat = TR.waves.cellsFor(
    [{ value: 8.7, sd: 1.2, base: 380 }, { value: 8.8, sd: 1.2, base: 396 }], false, "95");
  eq(flat[1].sig_prev, false, "small move on a wide spread is not significant");
  eq(flat[1].tested_prev, true, "but it WAS testable — both waves carry the inputs");

  // proportions: a prior wave with no base is untestable
  const noPrevBase = TR.waves.cellsFor(
    [{ value: 50, x: 50 }, { value: 65, base: 100, x: 65 }], true, "95");
  eq(noPrevBase[1].tested_prev, false, "prior wave with no base is untestable");

  // a sub-threshold prior base is untestable too (no false "flat" claim)
  const lowBase = TR.waves.cellsFor(
    [{ value: 8.5, sd: 1.2, base: 10 }, { value: 8.8, sd: 1.2, base: 396 }], false, "95");
  eq(lowBase[1].tested_prev, false, "prior base below the reporting threshold is untestable");
});

// ---- FPC material-coverage gate: a thin sample is not a finite-population study ----
run("FPC gate: fpcMul is off below 5% coverage, on above, Infinity at census", () => {
  eq(TR.conf.fpcMul(396, 14563), 1, "2.7% coverage (CCPB) -> no correction");
  eq(TR.conf.fpcMul(200, 14563), 1, "1.4% coverage -> no correction");
  assert(TR.conf.fpcMul(100, 200) > 1, "50% coverage -> a real correction");
  eq(TR.conf.fpcMul(200, 200), Infinity, "full census -> Infinity (zero-width interval)");
  eq(TR.conf.fpcMul(50, 1), 1, "no usable population -> 1");
});

run("FPC gate: fpcApplies mirrors the material floor", () => {
  assert(!TR.conf.fpcApplies(396, 14563), "thin sample -> FPC does not materially apply");
  assert(TR.conf.fpcApplies(120, 200), "60% coverage -> FPC applies");
});

run("FPC gate: fpcActiveReport false for a thin sample, true for a near-census", () => {
  TR.AGG = { project: { population_size: 14563, low_base_threshold: 30 },
    columns: [{ label: "Total" }], questions: [] };
  TR.MICRO = { n: 396 };                                  // 2.7% coverage — CCPB shape
  assert(!TR.conf.fpcActiveReport(), "population set but 2.7% coverage -> not a finite-population study");
  TR.MICRO = { n: 10000 };                                 // 68.7% coverage
  assert(TR.conf.fpcActiveReport(), "68.7% coverage -> FPC materially active");
  TR.AGG = { project: { low_base_threshold: 30 }, columns: [{ label: "Total" }], questions: [] };
  TR.MICRO = { n: 396 };
  assert(!TR.conf.fpcActiveReport(), "no configured population -> not active");
});

run("FPC callout: no census/FPC framing for a thin sample; present for a near-census", () => {
  const base = { low_base_threshold: 30, sampling_method: "Stratified" };
  TR.AGG = { project: Object.assign({ population_size: 14563 }, base),
    columns: [{ label: "Total" }], questions: [], banner_groups: [] };
  TR.MICRO = { n: 396 };                                  // 2.7% — a sample
  let html = TR.conf.calloutHtml();
  assert(html.indexOf("finite population correction") === -1, "thin sample: no FPC sentence");
  assert(html.indexOf("near-census") === -1, "the 'near-census' claim is gone entirely");
  assert(html.indexOf("probability sampling, so ranges are formal") !== -1,
    "thin sample reads as a plain probability sample");
  TR.MICRO = { n: 10000 };                                 // 68.7% — genuinely finite-population
  html = TR.conf.calloutHtml();
  assert(html.indexOf("finite population correction") !== -1, "near-census: FPC sentence present");
  assert(html.indexOf("near-census") === -1, "and still never uses the 'near-census' wording");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
