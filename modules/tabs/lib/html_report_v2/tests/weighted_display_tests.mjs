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
  "21_stats.js", "21c_confidence.js", "22w_waves.js", "22_model.js", "23_render.js"]) {
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

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
