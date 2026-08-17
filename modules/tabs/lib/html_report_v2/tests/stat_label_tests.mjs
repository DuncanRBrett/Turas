#!/usr/bin/env node
/**
 * Reported-statistic labelling (production review 2026-08, CRITICAL C1).
 *
 * A crosstab config that turns the column percentage off
 * (show_percent_column = N) puts ROW percentages or raw FREQUENCIES into the
 * island's `pct` slot. Nothing named the quantity, so the v2 renderer labelled
 * every one of them "%": a counts-only run shipped "142%", "80% B", "62%" —
 * headcounts with percent signs and significance letters — into the crosstab,
 * the TSV, the PPTX matrix, the data bars and the Wilson intervals. The same
 * fall-through substitutes per ROW, so a Frequency-only row rendered as "37%"
 * beside a genuine 37.0%.
 *
 * This suite pins the contract:
 *   1. the statistic travels on the model (question-level and per row);
 *   2. a count prints as a count, in the table, the TSV and the export matrix,
 *      with the unit named on the table's face;
 *   3. nothing that assumes a column proportion is built on a non-column-%
 *      value — no Wilson interval, no data bar, no heat tint;
 *   4. a row percentage keeps its "%" but declares its denominator, and gets
 *      no Wilson interval (whose base is the column, not the row);
 *   5. an ordinary column-% report is completely unchanged;
 *   6. a filtered recompute — always a column % — says what the question was
 *      published as, instead of silently swapping units.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/stat_label_tests.mjs
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
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js",
  "22_model.js", "23_render.js", "26_filter.js"]) {
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
}
/** The rendered value cells of a crosstab, in order. */
function cellValues(html) {
  return (html.match(/<span class="v">([^<]*)<\/span>/g) || [])
    .map((s) => s.replace(/<[^>]+>/g, ""));
}

/* ---------------- fixture ---------------- */
// Total + a Gender banner. `stat` is set per test — absent means the ordinary
// column percentage, exactly as every island built before this field existed.
function loadFixture(stat, rowStats) {
  TR.PREV = null;
  TR.userState = null;
  TR.MICRO = null;                             // no filter -> published path
  const q = {
    code: "Q1", title: "Are you aware?", type: "single", category: "Awareness",
    bases: [{ n: 200, low: false }, { n: 100, low: false }, { n: 100, low: false }],
    rows: [
      { kind: "category", label: "Yes", pct: [142, 80, 62], n: [142, 80, 62], sig: ["", "B", ""] },
      { kind: "category", label: "No", pct: [58, 20, 38], n: [58, 20, 38], sig: ["", "", "A"] }
    ]
  };
  if (stat) q.stat = stat;
  if (rowStats) q.rows.forEach((r, i) => { if (rowStats[i]) r.stat = rowStats[i]; });
  TR.AGG = {
    project: { name: "Stat labelling", low_base_threshold: 30 },
    banner_groups: [{ id: "Gender", name: "Gender" }],
    columns: [
      { label: "Total", letter: "", group: null },
      { label: "Male", letter: "A", group: "Gender" },
      { label: "Female", letter: "B", group: "Gender" }
    ],
    questions: [q]
  };
  if (TR.d2) TR.d2._qIndex = null;
  TR.waves.reset();                            // drop any cached wave index
  return q;
}

/** 200 respondents: 142 "Yes" / 58 "No", split evenly across the Gender banner
 *  (column 1 = Male, column 2 = Female in TR.AGG.columns). */
function microdata() {
  const answers = [], gender = [];
  for (let i = 0; i < 200; i++) {
    answers.push(i < 142 ? 0 : 1);
    gender.push(i % 2 === 0 ? 1 : 2);
  }
  return { n: 200, answers: { Q1: answers }, banner_vars: { Gender: gender },
    boxes: {}, scores: {} };
}

/** One prior wave publishing the same two rows as column percentages. */
function priorWave() {
  TR.PREV = { schema_version: 2, waves: [
    { wave: "2025", year: 2025, questions: [
      { code: "Q1", match_key: "are you aware", base: 190,
        rows: { yes: { pct: 70 }, no: { pct: 30 } } }] },
    { wave: "2026", year: 2026, current: true, questions: [
      { code: "Q1", match_key: "are you aware", base: 200,
        rows: { yes: { pct: 71 }, no: { pct: 29 } } }] }
  ] };
  TR.waves.reset();
}

console.log("Reported-statistic labelling (C1) — suite:");

/* ---------------- 1. the statistic travels ---------------- */
run("the island's stat reaches the model, question-level and per row", () => {
  loadFixture("Frequency");
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  eq(m.stat, "Frequency", "model carries the question's statistic");
  eq(m.rows[0].stat, "Frequency", "each row inherits it");
});

run("an island with no stat reads as the column percentage (legacy default)", () => {
  loadFixture(null);
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  eq(m.stat, "Column %", "absent -> Column %");
  assert(TR.fmt.isColPctStat(undefined), "an undefined stat is a column %");
  assert(TR.fmt.isPctStat("Row %") && !TR.fmt.isPctStat("Frequency"),
    "Row % is a percentage; Frequency is not");
  assert(!TR.fmt.isColPctStat("Row %"), "a Row % is NOT a column percentage");
});

/* ---------------- 2. counts print as counts ---------------- */
run("a counts-only table prints headcounts, not '142%'", () => {
  loadFixture("Frequency");
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  const html = TR.render.tableHtml(m, {});
  const vals = cellValues(html);
  eq(vals.join(" "), "142 80 62 58 20 38", "raw counts, no percent signs");
  assert(!/\d%/.test(html.replace(/style="[^"]*"/g, "")),
    "no percent sign anywhere in the rendered counts table");
  assert(html.includes("Counts (n)"), "the corner cell names the unit");
  // the letters still ride along — R tested the proportions behind the counts
  assert(html.includes("▲B"), "significance letters are unaffected");
});

run("the export matrix and TSV carry the counts and the unit", () => {
  loadFixture("Frequency");
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  const tsv = TR.render.tsv(m);
  assert(tsv.split("\n")[0].startsWith("Response — Counts (n)"),
    "the matrix head names the unit, got: " + tsv.split("\n")[0]);
  assert(/\nYes\t142\t80 B\t62/.test(tsv), "counts land unsuffixed in the TSV:\n" + tsv);
  assert(!/142%/.test(tsv), "no '142%' anywhere in the export");
});

/* ---------------- 3. nothing built on a non-column-% value ---------------- */
run("no Wilson interval, data bar or heat tint on a count", () => {
  loadFixture("Frequency");
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false, intervals: true });
  assert(!m.rows[0].cells[1].ci,
    "a count of 80 must not carry an interval, got " + JSON.stringify(m.rows[0].cells[1].ci));
  const bars = TR.render.tableHtml(m, { heatmap: "bars" });
  eq((bars.match(/dbar/g) || []).length, 0, "no magnitude bars under counts");
  const heatHtml = TR.render.tableHtml(m, { heatmap: "heat" });
  assert(!/background:rgba/.test(heatHtml), "no 0–100 heat tint over counts");
});

run("the same table as column percentages DOES get intervals and bars", () => {
  loadFixture(null);
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false, intervals: true });
  assert(m.rows[0].cells[1].ci, "column percentages still carry Wilson bounds");
  assert((TR.render.tableHtml(m, { heatmap: "bars" }).match(/dbar/g) || []).length > 0,
    "column percentages still draw data bars");
});

/* ---------------- 4. row percentages ---------------- */
run("a row-%-only table keeps its '%' but declares the denominator", () => {
  loadFixture("Row %");
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false, intervals: true });
  const html = TR.render.tableHtml(m, {});
  assert(cellValues(html)[0].endsWith("%"), "a row percentage is still a percentage");
  assert(html.includes("Row % (of the row total)"), "the corner cell names the denominator");
  assert(!m.rows[0].cells[1].ci,
    "no Wilson interval — its base is the column, not the row");
});

/* ---------------- 5. a mixed table: per-row substitution ---------------- */
run("a Frequency-only row prints as a count beside real percentages", () => {
  loadFixture(null, [null, "Frequency"]);
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false, intervals: true });
  const vals = cellValues(TR.render.tableHtml(m, {}));
  eq(vals[0], "142%", "the column-% row is unchanged");
  eq(vals[3], "58", "the Frequency-only row prints as a headcount");
  assert(m.rows[0].cells[1].ci, "the column-% row keeps its interval");
  assert(!m.rows[1].cells[1].ci, "the count row does not");
});

/* ---------------- 6. an ordinary report is unchanged ---------------- */
run("an ordinary column-% report renders exactly as before", () => {
  loadFixture(null);
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  const html = TR.render.tableHtml(m, {});
  eq(cellValues(html).join(" "), "142% 80% 62% 58% 20% 38%", "percentages unchanged");
  assert(!html.includes("cunit"), "no unit note on an ordinary table");
  eq(TR.render.tsv(m).split("\n")[0].split("\t")[0], "Response", "matrix head unchanged");
  eq(TR.render.statNote(m), "", "column % has no note");
});

/* ---------------- 7. a filtered recompute names what changed ---------------- */
run("a filtered recompute is a column % and says what was published", () => {
  loadFixture("Frequency");
  // microdata for the same 200 respondents: 142 "Yes", 58 "No"; filter keeps all
  TR.MICRO = microdata();
  TR.d2._qIndex = null;
  const m = TR.model.forQuestion("Q1", "Gender", [{ q: "Q1", rows: [0, 1] }], { dual: false });
  eq(m.source, "computed", "the filter forced a recompute");
  eq(m.stat, "Column %", "every recomputed value is a column percentage");
  eq(m.statWas, "Frequency", "and it remembers what the question published");
  const html = TR.render.tableHtml(m, {});
  assert(html.includes("published as Counts (n)"),
    "the table says the unit changed, rather than swapping it silently");
  assert(cellValues(html)[0].endsWith("%"), "the recomputed value is shown as a %");
});

run("a filtered recompute of an ordinary question carries no note", () => {
  loadFixture(null);
  TR.MICRO = microdata();
  TR.d2._qIndex = null;
  const m = TR.model.forQuestion("Q1", "Gender", [{ q: "Q1", rows: [0, 1] }], { dual: false });
  eq(m.source, "computed", "recomputed");
  eq(m.statWas, null, "nothing changed unit");
  eq(TR.render.statNote(m), "", "so no note");
});

/* ---------------- 8. wave trending and the confidence example ---------------- */
run("a counts row is not trended — no delta chip, no wave series", () => {
  loadFixture("Frequency");
  priorWave();
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  assert(!m.rows[0].waves, "no wave series on a counts row");
  assert(!m.rows[0].delta, "and no delta — 142 counts vs a 70% prior is not a change");
  const html = TR.render.tableHtml(m, { showDeltas: true });
  assert(!html.includes("delta"), "no wave chip rendered");
});

run("the same rows AS column percentages still trend", () => {
  loadFixture(null);
  priorWave();
  const m = TR.model.forQuestion("Q1", "Gender", [], { dual: false });
  assert(m.rows[0].waves && m.rows[0].waves.length, "wave series still attaches");
  assert(m.rows[0].delta, "and the delta still computes");
});

run("the confidence explainer never quotes a headcount as its worked example", () => {
  loadFixture("Frequency");
  TR.PREV = null;
  // one NET row with a real base, the only candidate the example can pick
  TR.AGG.questions[0].rows.push({ kind: "net", label: "Top 2 Box",
    pct: [142, 80, 62], n: [142, 80, 62], sig: ["", "", ""] });
  TR.d2._qIndex = null;
  const html = TR.conf.calloutHtml();
  assert(blockOf(html, "conf.footer.example").indexOf("142") === -1,
    "the counts-only question must not supply the worked example");
  // control: as column percentages, that same NET IS the worked example
  loadFixture(null);
  TR.AGG.questions[0].rows.push({ kind: "net", label: "Top 2 Box",
    pct: [71, 80, 62], n: [142, 80, 62], sig: ["", "", ""] });
  TR.d2._qIndex = null;
  assert(blockOf(TR.conf.calloutHtml(), "conf.footer.example").indexOf("71") !== -1,
    "a real column percentage still supplies it");
});

/* ---------------- 9. the Differences view ---------------- */
// Its own sandbox: 27d_diffs is a standalone view module with no other harness.
function diffsSandbox() {
  const box = { console };
  box.globalThis = box;
  box.window = box;
  vm.createContext(box);
  installText(box);
  for (const file of ["00_namespace.js", "01_format.js", "27_views.js", "27d_diffs.js"]) {
    vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), box, { filename: file });
  }
  return box.TR;
}

/** One question, one row where "Male" beats both siblings at 95% (letters BC),
 *  reported in `stat`. No microdata, so "the rest" falls back to the counts. */
function diffsFixture(D, stat) {
  D.d2 = { state: { sigMode: "95", filters: [] }, hasMicrodata: () => false };
  D.AGG = { project: { low_base_threshold: 30 },
    questions: [{ code: "Q1", title: "Are you aware?", category: "Awareness",
      type: "single", rows: [{ kind: "category", label: "Yes" }] }] };
  D.model = { forQuestion: () => ({
    stat: stat || "Column %",
    columns: [{ label: "Total", letter: "" }, { label: "Male", letter: "A" },
      { label: "Female", letter: "B" }, { label: "Other", letter: "C" }],
    rows: [{ kind: "category", label: "Yes", stat: stat || "Column %",
      cells: [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
        { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }] }] }) };
  D.AGG.columns = D.model.forQuestion().columns;
}

run("the Differences view reports pp gaps only from column percentages", () => {
  const D = diffsSandbox();
  diffsFixture(D, "Column %");
  const found = D.views._collectFindings("Gender");
  assert(found.length >= 1, "a column-% standout IS a finding, got " + found.length);
  eq(found[0].value, 85, "the finding carries the share");
});

run("a counts-only row raises no 'pp gap' finding", () => {
  const D = diffsSandbox();
  diffsFixture(D, "Frequency");
  eq(D.views._collectFindings("Gender").length, 0,
    "85 people beating 20 is not a 65pp gap");
});

console.log(failed ? "✗ " + failed + " failed, " + passed + " passed"
  : "✓ all " + passed + " passed");
process.exit(failed ? 1 : 0);
