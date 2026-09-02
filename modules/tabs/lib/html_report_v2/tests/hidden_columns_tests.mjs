#!/usr/bin/env node
/**
 * Hidden columns must take their significance letters with them.
 *
 * Production review 2026-08-21, finding I-3: applyHiddenColumns dropped the
 * column and its cells but left every surviving cell's `sig` string untouched,
 * so a cell kept claiming "higher than C" after column C was hidden. The letter
 * is rendered verbatim by render.matrix, so the dangling reference reached the
 * on-screen table, the clipboard/TSV, the per-question XLSX export and the PPTX
 * matrix at once. A client reading "significantly higher than C" against a
 * table that has no column C.
 *
 * applyDisclosureSuppression already stripped letters for suppressed columns
 * ("a shown cell never claims 'higher than B' once B is hidden"); hiding was the
 * path that forgot. These tests pin both halves: letters for hidden columns go,
 * letters for surviving columns stay.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/hidden_columns_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
installText(sandbox);
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

/* A published report with three banner columns (B, C, D) where the first row's
 * cells each claim significance against one of the others. */
function loadFixture() {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;                            // published path, no recompute
  TR.AGG = {
    project: { name: "Hidden columns fixture", low_base_threshold: 30 },
    banner_groups: [{ id: "Cohort", name: "Cohort" }],
    columns: [
      { label: "Total", letter: "",  group: null },
      { label: "Alpha", letter: "B", group: "Cohort" },
      { label: "Beta",  letter: "C", group: "Cohort" },
      { label: "Gamma", letter: "D", group: "Cohort" }
    ],
    questions: [
      { code: "Q1", title: "Preference", type: "single", category: "Test",
        bases: [
          { n: 900, low: false }, { n: 300, low: false },
          { n: 300, low: false }, { n: 300, low: false }
        ],
        rows: [
          // Alpha beats Gamma (D); Beta beats Gamma (D); Gamma beats Alpha (B).
          { kind: "category", label: "Yes", pct: [50, 60, 58, 32],
            n: [450, 180, 174, 96], sig: ["", "D", "D", "B"] },
          { kind: "category", label: "No", pct: [50, 40, 42, 68],
            n: [450, 120, 126, 204], sig: ["", "", "", "BC"] }
        ] }
    ]
  };
  if (TR.d2) TR.d2._qIndex = null;
}

function sigOf(model, rowIdx) {
  return model.rows[rowIdx].cells.map((c) => (c && c.sig) || "");
}

console.log("Hidden columns. Suite:");

run("baseline: with nothing hidden every published letter survives", () => {
  loadFixture();
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: false, hiddenCols: [] });
  eq(m.columns.length, 4, "Total + three cohort columns");
  eq(sigOf(m, 0).join("|"), "|D|D|B", "published letters carried verbatim");
  eq(sigOf(m, 1).join("|"), "|||BC", "second row's letters carried verbatim");
});

run("hiding a column removes it AND every letter pointing at it", () => {
  loadFixture();
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: false, hiddenCols: ["Gamma"] });

  eq(m.columns.length, 3, "Gamma dropped from the columns");
  assert(!m.columns.some((c) => c.label === "Gamma"), "Gamma is gone");
  eq(m.hiddenCount, 1, "hiddenCount reports the drop");

  // The D letters must not survive. No column D remains to point at.
  const row0 = sigOf(m, 0);
  assert(!row0.join("").includes("D"), "no cell still claims significance vs D, got " + JSON.stringify(row0));
  // Row 2's only letters ("BC") lived in Gamma's cell, which left with the
  // column, so the three surviving cells are all blank.
  eq(JSON.stringify(sigOf(m, 1)), JSON.stringify(["", "", ""]),
     "row 2's surviving cells carry no letters once Gamma's cell leaves");
});

run("letters for columns that are still shown are NOT stripped", () => {
  loadFixture();
  // Hide Alpha (letter B). Gamma's "B" reference must go, but Gamma's cells
  // still reference nothing else and Alpha's "D" claim leaves with Alpha.
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: false, hiddenCols: ["Alpha"] });
  eq(m.columns.length, 3, "Alpha dropped");

  const row0 = sigOf(m, 0);
  assert(!row0.join("").includes("B"), "the hidden column's letter B is stripped everywhere");
  // Beta still legitimately beats Gamma, and Gamma is still shown.
  assert(row0.join("").includes("D"), "Beta keeps its still-valid claim vs D, got " + JSON.stringify(row0));

  const row1 = sigOf(m, 1);
  eq(row1[row1.length - 1], "C", "Gamma's 'BC' loses B and keeps the still-shown C");
});

run("hiding two columns strips both their letters", () => {
  loadFixture();
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: false, hiddenCols: ["Alpha", "Gamma"] });
  eq(m.columns.length, 2, "Total + Beta remain");
  const all = sigOf(m, 0).join("") + sigOf(m, 1).join("");
  assert(!all.includes("B"), "letter B stripped");
  assert(!all.includes("D"), "letter D stripped");
});

run("the rendered table carries no dangling letter either", () => {
  // The strip happens at model level precisely so every consumer inherits it,
  // screen, clipboard, XLSX and PPTX all render these same cells.
  loadFixture();
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: false, hiddenCols: ["Gamma"] });
  const html = TR.render.tableHtml(m, {});
  assert(!html.includes("Gamma"), "hidden column absent from the rendered table");
  assert(!/[▲▼]\s*D/.test(html), "no rendered arrow points at the hidden column D");
});

console.log("\n  " + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
