#!/usr/bin/env node
/**
 * Gate for COMPOSITE INDEX questions in the v2 report (Q_Engage, Q_Value…).
 *
 * A composite carries per-respondent scores in the microdata island so it can
 * recompute under a live filter and be tracked across waves (microdata_writer.R
 * micro_scores_for_composite). That is a genuine gain — but it also makes the
 * composite look, to any code that scans `TR.MICRO.scores`, exactly like one
 * more rated question. It is not: it is the AVERAGE of rated questions that are
 * themselves in the report.
 *
 * Two things must therefore hold at once, and they pull in opposite directions:
 *   1. `views.indexQuestions()` KEEPS composites — they belong on the dashboard,
 *      in the reader's band legend and in the level gathering, as they always did.
 *   2. The per-respondent score families (odd-one-out cells, two-camps) DROP
 *      them — otherwise a composite competes with its own components, and its
 *      average-of-averages spread reads as a fabricated pattern.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/composite_index_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.createContext(sandbox);
const files = ["00_namespace.js", "01_format.js", "20_data.js", "27_views.js"]
  .concat(readdirSync(JS_DIR).filter((f) => /takeout.*\.js$/.test(f)).sort());
for (const file of files) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }

/* ---------------- fixture ---------------- */
// Two rated items on a 1–5 scale and the composite that averages them, exactly
// the shape SACS ships (twelve items + Q_Engage).
const meanRow = { kind: "mean", label: "Index" };
const item = (code) => ({ code: code, title: code, type: "scale", scale_max: 5,
  rows: [{ kind: "category", label: "1" }, { kind: "category", label: "5" }, meanRow] });
const composite = { code: "Q_IDX", title: "Overall Index", type: "single",
  composite: true, scale_max: 5, rows: [meanRow] };
const nps = { code: "QN", title: "Recommend", type: "nps", scale_max: 100,
  rows: [meanRow] };
// A rated question whose scale is wider than 10 — kept out of the families for
// its own (pre-existing) reason, so the composite rule is not doing this work.
const wide = { code: "Q100", title: "0-100 slider", type: "scale", scale_max: 100,
  rows: [meanRow] };

TR.AGG = { project: {}, columns: [], questions: [item("Q1"), item("Q2"), composite, nps, wide] };
const scoresFor = (codes) => {
  const out = {};
  codes.forEach((c) => { out[c] = [3, 4, 2, 5]; });
  return out;
};
TR.MICRO = { n: 4, scores: scoresFor(["Q1", "Q2", "Q_IDX", "QN", "Q100"]),
  weights: [1, 1, 1, 1], banner_vars: {} };

const eligible = TR.takeout._familyEligible;
const byCode = (c) => TR.AGG.questions.find((q) => q.code === c);

/* ---------------- tests ---------------- */

run("indexQuestions KEEPS the composite (dashboard, legend, levels unchanged)", () => {
  const codes = TR.views.indexQuestions().map((q) => q.code);
  assert(codes.indexOf("Q_IDX") !== -1,
    "composite must stay in indexQuestions — it is a dashboard metric; got " + codes.join(","));
  assert(codes.indexOf("Q1") !== -1, "rated items must stay too");
});

run("the score families DROP the composite", () => {
  assert(eligible(byCode("Q1"), TR.MICRO) === true, "a rated item is eligible");
  assert(eligible(byCode("Q_IDX"), TR.MICRO) === false,
    "a composite must never enter the cell / two-camps families — it would compete with its own components");
});

run("the composite is excluded by its FLAG, not by a side effect of its shape", () => {
  // Same question, same scale, same scores — only the flag differs. If this
  // passes for one and fails for the other, the guard is the flag.
  const twin = Object.assign({}, byCode("Q_IDX"), { composite: false, code: "Q1" });
  assert(eligible(twin, TR.MICRO) === true,
    "an identical question without the composite flag must be eligible");
});

run("the pre-existing exclusions still hold (NPS, wide scales, no scores)", () => {
  assert(eligible(byCode("QN"), TR.MICRO) === false, "NPS stays out (±100 buckets)");
  assert(eligible(byCode("Q100"), TR.MICRO) === false, "a >10 scale stays out");
  assert(eligible(byCode("Q1"), { scores: {} }) === false, "no scores -> not eligible");
  assert(eligible(byCode("Q1"), null) === false, "no microdata -> not eligible");
});

run("a report with no composites behaves exactly as before", () => {
  // The flag is absent (not false) on every question of an ordinary study.
  const plain = { code: "Q9", type: "scale", scale_max: 5, rows: [meanRow] };
  assert(eligible(plain, { scores: { Q9: [1, 2] } }) === true,
    "an unflagged question must be eligible — no behaviour change for studies without composites");
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
