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

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
