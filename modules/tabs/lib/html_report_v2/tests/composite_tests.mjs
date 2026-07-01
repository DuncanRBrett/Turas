#!/usr/bin/env node
/**
 * Verification gate for the COMPOSITE (profile) banner — the one tabs-v2 feature
 * that can introduce a SILENT statistical error, so it is checked by harness,
 * never by reasoning. Loads the real engine into a vm context over a hand-built
 * fixture and asserts:
 *   1. columnsFor("composite:…") builds heterogeneous, possibly OVERLAPPING
 *      member columns, each with NO letter (so pairwise letters cannot appear),
 *      Total member === null.
 *   2. model.forQuestion(...,"composite:…") tags the model composite and emits
 *      vs-THE-REST arrows: ▲ above / ▼ below at 95%, hollow ▵/▿ at 80% (dual),
 *      "" when not different — bidirectional, and a confident "" for an
 *      overlapping column that genuinely matches the rest.
 *   3. NO cell ever carries an alphabetic pairwise letter (the trap), and the
 *      Total column is never tested.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/composite_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;                 // engine IIFEs accept window or globalThis
vm.createContext(sandbox);
// Minimal engine slice model.forQuestion needs (namespace → data → stats →
// confidence → waves → model → composite store).
for (const file of ["00_namespace.js", "01_format.js", "20_data.js", "21_stats.js",
  "21c_confidence.js", "22w_waves.js", "22_model.js", "28c_composite.js"]) {
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

/* ---------------- fixture ---------------- */
// n = 40 respondents. Source vars (each a column the composite can draw on):
//   Q002 dept   : 0–19 Marketing(0), 20–39 Admin(1)          (disjoint pair)
//   Q003 campus : even Cape Town(0), odd Durban(1)            (overlaps dept)
//   Q006 border : a hand-picked group of 10 tuned for an 80%-but-not-95% gap
// Outcomes:
//   Q001 Yes/No : Marketing 90% Yes, Admin 10% Yes (overall 50%)
//   Q007 Index  : a scored scale (Marketing high, Admin low; varied within group
//                 so the within-group SD is non-zero and the t-test is defined)
const N = 40;
const idx = Array.from({ length: N }, (_, i) => i);
const dept = idx.map((i) => (i < 20 ? 0 : 1));
const campus = idx.map((i) => (i % 2 === 0 ? 0 : 1));
// Q001: Yes(0) for Marketing 0–17 and Admin 20–21; No(1) otherwise → 20/40 Yes.
const yesno = idx.map((i) => {
  if (i < 20) return i <= 17 ? 0 : 1;     // Marketing: 18/20 Yes
  return i <= 21 ? 0 : 1;                  // Admin: 2/20 Yes
});
// Border group: {0..6, 22,23,24} → 7 of its 10 are Yes (0–6), rest 13/30 Yes.
const borderMembers = new Set([0, 1, 2, 3, 4, 5, 6, 22, 23, 24]);
const border = idx.map((i) => (borderMembers.has(i) ? 0 : 1));
// Q007 scores: Marketing {7,9}, Admin {3,5} by parity (non-zero within-group SD).
const score = idx.map((i) => (i < 20 ? (i % 2 ? 9 : 7) : (i % 2 ? 5 : 3)));

TR.PREV = null;
TR.AGG = {
  project: { name: "Composite fixture", low_base_threshold: 5, weighted: false },
  banner_groups: [{ id: "Q002", name: "Department" }],
  columns: [{ label: "Total", letter: "", group: null }],
  questions: [
    { code: "Q001", title: "Recommend", type: "single", category: "Test",
      rows: [{ kind: "category", label: "Yes" }, { kind: "category", label: "No" }] },
    { code: "Q007", title: "Satisfaction", type: "scale", category: "Test",
      rows: [{ kind: "mean", label: "Index" }] }
  ]
};
TR.MICRO = {
  n: N,
  answers: { Q001: yesno, Q002: dept, Q003: campus, Q006: border, Q007: score },
  banner_vars: { Q002: dept },
  scores: { Q007: score }
};
TR.userState = null;

// The composite Duncan describes: a profile banner of spotlight groups, some
// from the same variable (disjoint) and some from different ones (overlapping).
const compId = TR.compositeBanners.add({
  name: "Spotlight groups",
  columns: [
    { code: "Q002", label: "Marketing", rows: [0] },      // disjoint from Admin
    { code: "Q002", label: "Admin", rows: [1] },          // disjoint from Marketing
    { code: "Q003", label: "Cape Town", rows: [0] },      // OVERLAPS both depts
    { code: "Q006", label: "Border", rows: [0] }          // overlaps Marketing
  ]
});

console.log("Composite banner — engine suite:");

/* ---------------- 1. columnsFor ---------------- */
run("columnsFor builds heterogeneous, overlapping, letter-free columns", () => {
  const spec = TR.stats.columnsFor(compId);
  assert(spec.composite === true, "spec flagged composite");
  eq(spec.columns.length, 5, "Total + 4 spotlight columns");
  eq(spec.columns[0].label, "Total", "col 0 is Total");
  eq(spec.columns[0].member, null, "Total membership is null (everyone)");
  eq(spec.columns.map((c) => c.label).join("|"),
    "Total|Marketing|Admin|Cape Town|Border", "labels in order");
  // NO column carries a letter — this is what makes pairwise letters impossible.
  spec.columns.forEach((c) => eq(c.letter, "", "no letter on " + c.label));
  const [, mkt, adm, cpt] = spec.columns;
  eq(mkt.member[0], 1, "respondent 0 is Marketing");
  eq(mkt.member[20], 0, "respondent 20 is not Marketing");
  eq(adm.member[20], 1, "respondent 20 is Admin");
  // The trap made concrete: respondent 0 is in TWO columns at once.
  assert(mkt.member[0] === 1 && cpt.member[0] === 1,
    "respondent 0 is BOTH Marketing and Cape Town (columns overlap)");
});

run("unknown composite token degrades to Total only, never throws", () => {
  const spec = TR.stats.columnsFor("composite:does-not-exist");
  assert(spec.composite === true && spec.missing === true, "flagged missing");
  eq(spec.columns.length, 1, "Total only");
});

/* ---------------- 2 & 3. vs-the-rest significance ---------------- */
function sigByLabel(model, rowLabel) {
  const row = model.rows.find((r) => r.label === rowLabel);
  assert(row, "row '" + rowLabel + "' present");
  const out = {};
  model.columns.forEach((c, i) => { out[c.label] = row.cells[i].sig; });
  return out;
}
function everySig(model) {
  return model.rows.flatMap((r) => r.cells.map((c) => c.sig || ""));
}

run("category row: bidirectional ▲/▼ vs the rest, confident '' for the matched overlap", () => {
  const m = TR.model.forQuestion("Q001", compId, [], { dual: false });
  assert(m.composite === true, "model flagged composite");
  const s = sigByLabel(m, "Yes");
  eq(s["Total"], "", "Total never tested");
  eq(s["Marketing"], "▲", "Marketing 90% vs rest 10% → ▲");
  eq(s["Admin"], "▼", "Admin 10% vs rest 90% → ▼");
  eq(s["Cape Town"], "", "Cape Town 50% vs rest 50% → no arrow (overlap, genuine null)");
});

run("mean (Index) row: vs-the-rest Welch test, bidirectional incl. overlap", () => {
  const m = TR.model.forQuestion("Q007", compId, [], { dual: false });
  const s = sigByLabel(m, "Index");
  eq(s["Total"], "", "Total never tested");
  eq(s["Marketing"], "▲", "Marketing mean 8 vs rest 4 → ▲");
  eq(s["Admin"], "▼", "Admin mean 4 vs rest 8 → ▼");
  eq(s["Cape Town"], "▼", "Cape Town mean 5 vs rest 7 → ▼ (valid despite overlap)");
});

run("dual mode surfaces the 80% level as a hollow ▵; 95% mode hides it", () => {
  const solo = TR.model.forQuestion("Q001", compId, [], { dual: false });
  eq(sigByLabel(solo, "Yes")["Border"], "",
    "Border 70% vs rest 43% (z≈1.46) is not significant at 95%");
  const dual = TR.model.forQuestion("Q001", compId, [], { dual: true });
  eq(sigByLabel(dual, "Yes")["Border"], "▵",
    "…but shows as hollow ▵ at the 80% level in dual mode");
});

run("THE TRAP: no cell ever carries an alphabetic pairwise letter", () => {
  ["Q001", "Q007"].forEach((code) => {
    [false, true].forEach((dual) => {
      const m = TR.model.forQuestion(code, compId, [], { dual: dual });
      everySig(m).forEach((sig) => assert(!/[A-Za-z]/.test(sig),
        code + (dual ? " (dual)" : "") + ": pairwise letter leaked — '" + sig + "'"));
    });
  });
});

run("a non-composite (filtered) model is not flagged composite", () => {
  // Filtered Total banner → the same microdata recompute path, but not composite.
  const m = TR.model.forQuestion("Q001", "", [{ q: "Q003", rows: [0] }], { dual: false });
  assert(m && !m.composite, "filtered Total-banner model is not flagged composite");
});

run("storeKey scopes localStorage per report so composites stay discrete", () => {
  const base = "turas_v2_composites";
  TR.AGG.project = { name: "Survey A", wave: "Wave 1" };
  const a = TR.d2.storeKey(base);
  TR.AGG.project = { name: "Survey B", wave: "Wave 1" };
  const b = TR.d2.storeKey(base);
  TR.AGG.project = { name: "Survey A", wave: "Wave 2" };
  const a2 = TR.d2.storeKey(base);
  assert(a !== b, "different surveys get different keys (" + a + " vs " + b + ")");
  assert(a !== a2, "different waves of one survey get different keys");
  assert(a.indexOf(base) === 0, "the base key stays a prefix (" + a + ")");
});

run("weighted published sig uses the weighted base + effective base, not the unweighted base (E1)", () => {
  const stats = TR.stats, sigCell = TR.model._sigCell;
  // A: weighted count 30 on Σw=60 (p=0.50), effN=55.  B: weighted count 42 on Σw=140
  // (p=0.30), effN=130. Unweighted n=100 each. sigCell forms the proportion on the weighted
  // base and carries the variance on the effective base (x = p*effN over effN).
  const A = sigCell(30, { n: 100, nWeighted: 60, nEff: 55 });
  const B = sigCell(42, { n: 100, nWeighted: 140, nEff: 130 });
  assert(Math.abs(A.x - 27.5) < 1e-9 && A.base === 55, "A -> x = p*effN = 27.5 over effN = 55");
  assert(Math.abs(B.x - 39) < 1e-9 && B.base === 130, "B -> x = 39 over effN = 130");
  const zFixed = stats.propZ(A.x, A.base, B.x, B.base);
  const zBuggy = stats.propZ(30, 100, 42, 100);            // weighted counts over the UNWEIGHTED base
  assert(zFixed > 1.96, "weighted: A (0.50) is 95%-significantly higher than B (0.30), z=" + zFixed.toFixed(2));
  assert(zBuggy < 0, "the old unweighted-base path inverts the sign to B>A, z=" + zBuggy.toFixed(2));
  // Unweighted columns (no nWeighted/nEff) pass the exact counts through unchanged.
  const U = sigCell(45, { n: 90 });
  assert(U.x === 45 && U.base === 90, "unweighted design: exact counts unchanged (byte-identical)");
});

run("disclosure blanks sub-threshold crosstab columns at the model level (task #4)", () => {
  const priorDisc = TR.disclosure;
  TR.disclosure = { active: () => true, minBase: () => 10 };
  const vm = {
    columns: [{ base: 167, letter: "" }, { base: 1, letter: "A" }, { base: 5, letter: "B" }, { base: 40, letter: "C" }],
    rows: [{ cells: [{ pct: 60, sig: "" }, { pct: 100, sig: "" }, { pct: 20, sig: "" }, { pct: 55, sig: "AB" }] }]
  };
  TR.model._applyDisclosureSuppression(vm);
  assert(vm.columns[1].suppressed && vm.columns[2].suppressed, "columns with base 1 and 5 (< k=10) are suppressed");
  assert(!vm.columns[0].suppressed && !vm.columns[3].suppressed, "base 167 and 40 columns are shown");
  assert(vm.rows[0].cells[1].pct === null && vm.rows[0].cells[2].pct === null, "sub-k cells blanked to null (render as –)");
  assert(vm.rows[0].cells[0].pct === 60 && vm.rows[0].cells[3].pct === 55, "safe cells untouched");
  assert(vm.rows[0].cells[3].sig === "", "letters pointing at suppressed A,B stripped from the shown cell");

  // n=1 audience: every column is sub-k, so the whole table blanks (Duncan's live case).
  const tiny = { columns: [{ base: 1, letter: "" }, { base: 1, letter: "A" }],
    rows: [{ cells: [{ pct: 100, sig: "" }, { pct: 100, sig: "" }] }] };
  TR.model._applyDisclosureSuppression(tiny);
  assert(tiny.rows[0].cells[0].pct === null && tiny.rows[0].cells[1].pct === null, "n=1 cut: Total + column both blanked");

  // Control off (k=1) is a no-op -> unprotected reports byte-identical.
  TR.disclosure = { active: () => false, minBase: () => 1 };
  const off = { columns: [{ base: 3 }], rows: [{ cells: [{ pct: 33 }] }] };
  TR.model._applyDisclosureSuppression(off);
  assert(off.rows[0].cells[0].pct === 33, "control off -> nothing blanked");
  TR.disclosure = priorDisc;
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
