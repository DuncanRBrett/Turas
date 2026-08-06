#!/usr/bin/env node
/**
 * CROSS-ENGINE STATISTICS PARITY — the JS half.
 *
 * The R engine (Excel workbook, and the letters carried into the island) and
 * this engine (live filters / custom banners, plus what the published view
 * renders) must not disagree on the same deliverable. This suite renders the
 * REAL island that R generated from the committed parity fixture — not a
 * hand-authored stub that could agree with R by coincidence.
 *
 *   fixture project : modules/tabs/tests/fixtures/parity_project/
 *   island          : parity_island.json / parity_island_weighted.json
 *   regenerate      : Rscript modules/tabs/tests/fixtures/parity_project/regenerate_parity_island.R
 *   R half          : modules/tabs/tests/testthat/test_cross_engine_stats.R
 *
 * Spec: docs/tabs_production_review_2026-08/CROSS_ENGINE_STATS_SPEC.md
 *
 * Sections (spec section 3, in the order the stages landed them):
 *   JS-1  Published view renders the CARRIED letters verbatim, both alphas,
 *         including mean rows' new 80% letters.
 *   JS-4  sig2-absent islands still get 80% letters via the count recompute.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/parity_stats_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const FIXTURE_DIR = path.join(HERE, "..", "..", "..", "tests", "fixtures", "parity_project");

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
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + (process.env.TRACE ? e.stack : e.message)); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
}

function readIsland(name) {
  return JSON.parse(readFileSync(path.join(FIXTURE_DIR, name), "utf8"));
}

/** Install an island as the report and reset every cached/derived bit of state. */
function loadIsland(island) {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;                       // published path only — no recompute
  TR.AGG = island;
  if (TR.d2) TR.d2._qIndex = null;
}

function rowByLabel(model, label) {
  const r = model.rows.filter((x) => x.label === label);
  assert(r.length === 1, "exactly one row labelled " + JSON.stringify(label) +
    " (got " + r.length + ")");
  return r[0];
}

/** The island's raw row, before the model touches it. */
function rawRow(island, code, label) {
  const q = island.questions.filter((x) => x.code === code)[0];
  assert(q, "island carries question " + code);
  const r = q.rows.filter((x) => x.label === label);
  assert(r.length === 1, "island carries exactly one row " + JSON.stringify(label));
  return r[0];
}

// ============================================================================
// JS-1. THE PUBLISHED VIEW RENDERS THE CARRIED LETTERS, VERBATIM
// ============================================================================
//
// The default view must show exactly what R computed — the 95% letters from the
// Sig. row and the 80% letters from the Sig.2 row — with no arithmetic of its
// own. Recomputing the 80% letters here (what the model used to do) read the
// published Frequency row, which format_output_value rounds to 0dp, so the
// workbook and the report could letter the same pair differently.
//
// These run on the WEIGHTED island: the published-view FPC overlay is gated off
// for weighted designs, so this isolates carriage from the FPC work in stage 3.

console.log("Cross-engine parity — JS-1: carried letters, both alphas:");

const weightedIsland = readIsland("parity_island_weighted.json");

run("the fixture island loads and the default view is 'published'", () => {
  loadIsland(weightedIsland);
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: true });
  eq(m.source, "published", "default view source");
  eq(m.columns.length, 5, "Total + four cohort columns");
  eq(m.columns.map((c) => c.label).join(","), "Total,Alpha,Beta,Gamma,Delta", "column order");
  eq(m.columns.map((c) => c.letter).join(","), ",A,B,C,D", "column letters");
});

run("every proportion row's 95% letters are the carried sig, character for character", () => {
  loadIsland(weightedIsland);
  ["Q1", "Q2", "Q3"].forEach((code) => {
    const m = TR.model.forQuestion(code, "Cohort", [], { dual: true });
    m.rows.forEach((row) => {
      const raw = rawRow(weightedIsland, code, row.label);
      row.cells.forEach((cell, ci) => {
        const carried = String(raw.sig[ci] || "").replace(/-/g, "");
        // Uppercase letters on the cell are the 95% set; lowercase are 80%-only.
        const shown = (cell.sig || "").split("").filter((ch) => ch === ch.toUpperCase()).join("");
        eq(shown, carried, code + " / " + row.label + " col " + ci + " 95% letters");
      });
    });
  });
});

run("the 80% letters are sig2 MINUS sig, lowercased — not a recompute", () => {
  loadIsland(weightedIsland);
  ["Q1", "Q2", "Q3"].forEach((code) => {
    const m = TR.model.forQuestion(code, "Cohort", [], { dual: true });
    m.rows.forEach((row) => {
      const raw = rawRow(weightedIsland, code, row.label);
      assert(raw.sig2 !== undefined, code + " / " + row.label + " carries sig2");
      row.cells.forEach((cell, ci) => {
        const hi = String(raw.sig[ci] || "");
        const expected = String(raw.sig2[ci] || "").split("")
          .filter((ch) => ch !== "-" && hi.indexOf(ch) === -1).join("").toLowerCase();
        const shown = (cell.sig || "").split("").filter((ch) => ch === ch.toLowerCase()).join("");
        eq(shown, expected, code + " / " + row.label + " col " + ci + " 80% letters");
      });
    });
  });
});

// The fixture's engineered pair, hand-derived in generate_parity_project.R:
// Beta 39/60 vs Gamma 20/50 gives p = 0.008841, which sits between the
// Bonferroni-adjusted 95% threshold (0.05/6 = 0.008333) and the 80% one
// (0.20/6 = 0.033333). So Beta must carry a LOWERCASE c on Q1 "Yes" — 80% only.
run("the engineered marginal pair renders as 80%-only (lowercase c on Beta)", () => {
  loadIsland(weightedIsland);
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: true });
  const yes = rowByLabel(m, "Yes");
  eq(yes.cells[2].sig, "c", "Beta vs Gamma is 80%-significant, not 95%");
  eq(yes.cells[3].sig, "", "Gamma earns nothing on the Yes row");
});

// Before sig2 carriage the model gave mean rows NO 80% letters at all: it
// recomputed them from published counts, and a mean row has no count to
// recompute from. R has always tested means, so the letters existed in Excel
// and not in the report.
run("mean rows carry BOTH alphas — the 80% letters they never had", () => {
  loadIsland(weightedIsland);
  const m = TR.model.forQuestion("Q2", "Cohort", [], { dual: true });
  const mean = rowByLabel(m, "Mean");
  eq(mean.kind, "mean", "the Mean row is a mean-kind row");
  // Carried: sig = ["","","C","",""], sig2 = ["","C","C","","C"].
  // Beta is 95%-significant vs Gamma -> uppercase C.
  // Alpha and Delta are 80%-only vs Gamma  -> lowercase c.
  eq(mean.cells[1].sig, "c", "Alpha: 80%-only vs Gamma");
  eq(mean.cells[2].sig, "C", "Beta: 95% vs Gamma (no duplicate lowercase)");
  eq(mean.cells[3].sig, "", "Gamma earns nothing");
  eq(mean.cells[4].sig, "c", "Delta: 80%-only vs Gamma");
});

// The Sig. row of a summary block is appended AFTER the Std Dev row, so the
// label forward-fill labels it "Standard Deviation". If the writer matched on
// label alone, the mean's letters would render on the SD row — which reports
// spread and is never tested.
run("the Standard Deviation row carries no letters at either alpha", () => {
  loadIsland(weightedIsland);
  const m = TR.model.forQuestion("Q2", "Cohort", [], { dual: true });
  const sd = rowByLabel(m, "Standard Deviation");
  sd.cells.forEach((cell, ci) => eq(cell.sig || "", "", "SD row col " + ci + " has no letters"));
});

run("single-alpha rendering (dual off) shows the 95% letters only", () => {
  loadIsland(weightedIsland);
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: false });
  const yes = rowByLabel(m, "Yes");
  yes.cells.forEach((cell, ci) => {
    const raw = rawRow(weightedIsland, "Q1", "Yes");
    eq(cell.sig || "", String(raw.sig[ci] || "").replace(/-/g, ""),
      "col " + ci + " shows the primary letters and nothing else");
  });
});

// ============================================================================
// JS-4. ISLANDS WITHOUT sig2 STILL GET 80% LETTERS
// ============================================================================
//
// Reports built before sig2 carriage have no sig2 key. Those must keep working:
// the model falls back to recomputing the 80% letters from the published counts,
// exactly as it did before. (That path is the one with the rounding trap — which
// is why it is a fallback and not the default.)

console.log("\nCross-engine parity — JS-4: sig2-absent fallback:");

/** A deep copy of an island with every row's sig2 removed. */
function stripSig2(island) {
  const copy = JSON.parse(JSON.stringify(island));
  copy.questions.forEach((q) => q.rows.forEach((r) => { delete r.sig2; }));
  return copy;
}

run("an old-style island renders 80% letters via the count recompute", () => {
  const old = stripSig2(weightedIsland);
  loadIsland(old);
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: true });
  const yes = rowByLabel(m, "Yes");
  // The recompute reaches the same call on this pair: Beta's 65% over Gamma's
  // 40% is 80%-significant and not 95%-significant, so a lowercase c.
  eq(yes.cells[2].sig, "c", "the fallback still letters Beta at 80%");
  // And the 95% letters are still the carried ones — only the 80% set is derived.
  const raw = rawRow(old, "Q1", "Yes");
  yes.cells.forEach((cell, ci) => {
    const shown = (cell.sig || "").split("").filter((ch) => ch === ch.toUpperCase()).join("");
    eq(shown, String(raw.sig[ci] || "").replace(/-/g, ""), "col " + ci + " 95% letters unchanged");
  });
});

run("on the fallback path mean rows get NO 80% letters (the gap sig2 closes)", () => {
  const old = stripSig2(weightedIsland);
  loadIsland(old);
  const m = TR.model.forQuestion("Q2", "Cohort", [], { dual: true });
  const mean = rowByLabel(m, "Mean");
  // Carried 95% letter survives; the 80%-only letters on Alpha and Delta do not.
  eq(mean.cells[1].sig, "", "Alpha loses its 80% letter without sig2");
  eq(mean.cells[2].sig, "C", "Beta keeps its carried 95% letter");
  eq(mean.cells[4].sig, "", "Delta loses its 80% letter without sig2");
});

run("a sig2 of all-empty strings is carriage, not absence", () => {
  // Guard against a truthiness bug: a row where nothing is significant at 80%
  // carries ["","","","",""], which must still take the carried path (and
  // therefore letter nothing) rather than falling through to the recompute.
  const island = JSON.parse(JSON.stringify(weightedIsland));
  const q = island.questions.filter((x) => x.code === "Q1")[0];
  const yes = q.rows.filter((r) => r.label === "Yes")[0];
  yes.sig2 = ["", "", "", "", ""];
  loadIsland(island);
  const m = TR.model.forQuestion("Q1", "Cohort", [], { dual: true });
  eq(rowByLabel(m, "Yes").cells[2].sig, "", "no letters when R found none at 80%");
});

console.log("\n" + (failed === 0 ? "✓ " : "✗ ") + passed + " passed, " + failed + " failed");
process.exit(failed === 0 ? 0 : 1);
