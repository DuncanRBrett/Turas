#!/usr/bin/env node
/**
 * Differences view — behavioural gate (production review 2026-08, I12c).
 *
 * `27d_diffs.js` builds the lay reader's "where groups differ" view: which
 * findings appear, what each is measured against, and the sentence each becomes.
 * It shipped with three hooks explicitly exposed "for the differences gate test"
 * (`views._isClassification`, `views._collectFindings`, `views._diffLineHtml`)
 * and no such test — only two incidental checks in stat_label_tests.mjs, both
 * about the C1 stat label. Everything else the view decides was untested: which
 * questions are excluded as tautological cuts, what "the rest" is and when it is
 * unavailable, which rows are suppressed on a scale, the tautological 0%/100%
 * drop, the 95% vs 95%+80% split, the bidirectional mean test and its two base
 * gates, and the wording of every sentence a client reads.
 *
 * The mean-finding half runs on the REAL statistics module (21_stats.js) over
 * real per-respondent microdata, so it tests the arithmetic the report performs
 * rather than a stub that agrees with it. The categorical half stubs
 * `TR.model.forQuestion` — the model has its own suites, and what is under test
 * here is what the view does with a model's letters.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/diffs_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
}
function near(a, b, tol, msg) {
  if (!(Math.abs(a - b) <= tol)) {
    throw new Error(msg + ": expected ~" + b + " (±" + tol + "), got " + a);
  }
}

/** A fresh sandbox with the view module loaded. `withStats` also loads the real
 *  statistics engine, for the microdata paths. */
function sandbox(withStats) {
  const box = { console };
  box.globalThis = box; box.window = box;
  vm.createContext(box);
  const files = ["00_namespace.js", "01_format.js"];
  if (withStats) files.push("21_stats.js");
  files.push("27_views.js", "27d_diffs.js");
  for (const f of files) {
    vm.runInContext(readFileSync(path.join(JS_DIR, f), "utf8"), box, { filename: f });
  }
  box.TR.charts = { clip: (s, n) => String(s).slice(0, n) };
  return box.TR;
}

/* ==========================================================================
   1. Classification questions are cuts, not outcomes
   ========================================================================== */

console.log("Differences — classification exclusion:");

run("1. the built-in classification categories are excluded", () => {
  const D = sandbox();
  D.AGG = { project: {} };
  for (const cat of ["Demographics", "demographic profile", "Firmographics",
                     "Corpographics", "Classification", "CLASSIFYING"]) {
    assert(D.views._isClassification({ category: cat }), cat + " should be a cut");
  }
});

run("2. an ordinary outcome category is not excluded", () => {
  const D = sandbox();
  D.AGG = { project: {} };
  for (const cat of ["Attitudes", "Satisfaction", "Awareness", ""]) {
    assert(!D.views._isClassification({ category: cat }), cat + " should be an outcome");
  }
  assert(!D.views._isClassification({}), "a question with no category is an outcome");
});

run("3. a study extends the list through project.insight_exclude_categories", () => {
  const D = sandbox();
  D.AGG = { project: { insight_exclude_categories: ["Sales Office", "Channel"] } };
  assert(D.views._isClassification({ category: "Sales Office" }), "the configured name");
  assert(D.views._isClassification({ category: "sales OFFICE" }), "case-insensitively");
  assert(!D.views._isClassification({ category: "Attitudes" }), "and nothing else");
});

/* ==========================================================================
   2. Categorical findings — letters, the rest, and what is suppressed
   ========================================================================== */

console.log("\nDifferences — categorical findings:");

/**
 * One question over a Total + three gender columns, with the letters the model
 * would have published. `cells` is [total, A, B, C] as {pct, n, sig}.
 * No microdata, unweighted — so "the rest" comes from the exact count identity.
 */
function catFixture(D, opts) {
  opts = opts || {};
  const rows = opts.rows || [{ kind: "category", label: "Yes", stat: "Column %",
    cells: [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
            { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }] }];
  const columns = [{ label: "Total", letter: "", base: 200 },
                   { label: "Male", letter: "A", base: 100 },
                   { label: "Female", letter: "B", base: 50 },
                   { label: "Other", letter: "C", base: 50 }];
  D.d2 = { state: { sigMode: opts.sigMode || "95", filters: [] },
           hasMicrodata: () => false, firstBanner: () => "Gender" };
  D.AGG = { project: Object.assign({ low_base_threshold: 30 }, opts.project || {}),
            columns: columns,
            banner_groups: [{ id: "Gender", name: "Gender" }],
            questions: opts.questions || [{ code: "Q1", title: "Are you aware?",
              category: opts.category || "Awareness", type: opts.type || "single",
              rows: rows.map((r) => ({ kind: r.kind, label: r.label })) }] };
  D.model = { forQuestion: () => ({ columns: columns, rows: rows }) };
  return D;
}

run("4. a group ahead of two or more siblings is a finding, told against the rest", () => {
  const D = catFixture(sandbox());
  const found = D.views._collectFindings("Gender");
  eq(found.length, 1, "one finding");
  const f = found[0];
  eq(f.column, "Male", "the standout group");
  eq(f.value, 85, "its own share");
  eq(f.overall, 60, "the whole-sample figure");
  // The rest = everyone except Male: (120 − 85) hits over (200 − 100) people.
  eq(f.rest, 35, "the rest is recomputed, not assumed to be the overall figure");
  eq(f.gap, 50, "and the gap is measured against the rest (85 − 35)");
  eq(f.beaten.join(","), "Female,Other", "the letters resolve to group NAMES for a lay reader");
  eq(f.soft, false, "a 95% finding is not soft");
});

run("5. beating only ONE sibling is not a standout", () => {
  const D = catFixture(sandbox(), { rows: [{ kind: "category", label: "Yes",
    stat: "Column %",
    cells: [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "B" },
            { pct: 40, n: 20, sig: "" }, { pct: 55, n: 27, sig: "" }] }] });
  eq(D.views._collectFindings("Gender").length, 0,
     "one letter is a pairwise result, not a group that stands out");
});

run("6. a banner never beats itself", () => {
  const D = catFixture(sandbox(), { questions: [{ code: "Gender",
    title: "Gender", category: "Awareness", type: "single",
    rows: [{ kind: "category", label: "Yes" }] }] });
  eq(D.views._collectFindings("Gender").length, 0,
     "the banner source question is tautological against its own cut");
});

run("7. a classification question raises no findings even when it has letters", () => {
  const D = catFixture(sandbox(), { category: "Demographics" });
  eq(D.views._collectFindings("Gender").length, 0, "a cut is not an outcome");
});

run("8. an answer nobody outside the group gives is tautological, not a difference", () => {
  // Male 85%, and the rest 0% — a defining trait of the group (their own plant,
  // their own city), not something discovered.
  const D = catFixture(sandbox(), { rows: [{ kind: "category", label: "Our region",
    stat: "Column %",
    cells: [{ pct: 42, n: 85, sig: "" }, { pct: 85, n: 85, sig: "BC" },
            { pct: 0, n: 0, sig: "" }, { pct: 0, n: 0, sig: "" }] }] });
  eq(D.views._collectFindings("Gender").length, 0, "rest = 0% is dropped");
});

run("9. …and so is one that everyone BUT the group gives", () => {
  const D = catFixture(sandbox(), { rows: [{ kind: "category", label: "Everyone else",
    stat: "Column %",
    cells: [{ pct: 100, n: 200, sig: "" }, { pct: 100, n: 100, sig: "BC" },
            { pct: 100, n: 50, sig: "" }, { pct: 100, n: 50, sig: "" }] }] });
  eq(D.views._collectFindings("Gender").length, 0, "rest = 100% is dropped");
});

run("10. a scale question suppresses its raw scale points but keeps its NETs", () => {
  const cells = [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
                 { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }];
  const rows = [{ kind: "category", label: "Very satisfied", stat: "Column %", cells: cells },
                { kind: "net", label: "Top 2 Box", stat: "Column %", cells: cells }];
  const D = catFixture(sandbox(), { type: "scale", rows: rows });
  const found = D.views._collectFindings("Gender");
  eq(found.length, 1, "only the NET survives");
  eq(found[0].kind, "net", "a scale point beside a top-box that contains it reads wrong");
});

run("11. a choice question keeps its categories — there the categories ARE the story", () => {
  const cells = [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
                 { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }];
  const D = catFixture(sandbox(), { type: "multi",
    rows: [{ kind: "category", label: "Convenience", stat: "Column %", cells: cells }] });
  eq(D.views._collectFindings("Gender").length, 1, "a multi-choice category is a finding");
});

run("12. a row that is not a column percentage raises no pp gap (C1)", () => {
  const cells = [{ pct: 142, n: 142, sig: "" }, { pct: 80, n: 80, sig: "BC" },
                 { pct: 62, n: 62, sig: "" }, { pct: 30, n: 30, sig: "" }];
  for (const stat of ["Frequency", "Row %", "Average"]) {
    const D = catFixture(sandbox(), {
      rows: [{ kind: "category", label: "Yes", stat: stat, cells: cells }] });
    eq(D.views._collectFindings("Gender").length, 0,
       stat + ": 80 people beating 62 is not an 18pp gap");
  }
});

run("13. a weighted report with no microdata cannot compute the rest, and says so", () => {
  // The published n is a weighted frequency while the bases are unweighted, so
  // the count identity breaks — the finding falls back to the overall figure
  // rather than printing a rest it cannot stand behind.
  const D = catFixture(sandbox(), { project: { weighted: true } });
  const f = D.views._collectFindings("Gender")[0];
  eq(f.rest, null, "no rest is claimed");
  eq(f.gap, 25, "the gap falls back to the overall figure (85 − 60)");
});

/* ==========================================================================
   3. The 95% / 95%+80% toggle
   ========================================================================== */

console.log("\nDifferences — the significance toggle:");

/** Male solidly ahead (BC); Female nearly-significantly ahead (bc, lower case). */
function softFixture(D, sigMode) {
  return catFixture(D, { sigMode: sigMode, rows: [{ kind: "category", label: "Yes",
    stat: "Column %",
    cells: [{ pct: 50, n: 100, sig: "" }, { pct: 85, n: 85, sig: "BC" },
            { pct: 60, n: 30, sig: "ac" }, { pct: 20, n: 10, sig: "" }] }] });
}

run("14. at 95% only solid findings appear", () => {
  const D = softFixture(sandbox(), "95");
  const found = D.views._collectFindings("Gender");
  eq(found.length, 1, "the nearly-significant one is not shown");
  eq(found[0].column, "Male", "only the solid finding");
});

run("15. in dual mode the nearly-significant finding appears, flagged and ranked below", () => {
  const D = softFixture(sandbox(), "dual");
  const found = D.views._collectFindings("Gender");
  eq(found.length, 2, "both appear");
  eq(found[0].column, "Male", "the solid finding ranks first…");
  eq(found[0].soft, false, "…and is not flagged soft");
  eq(found[1].column, "Female", "the 80% finding follows");
  eq(found[1].soft, true, "flagged soft so the sentence can hedge");
});

run("16. a solid finding always outranks a soft one, whatever the scores", () => {
  // Female's soft gap is enormous, Male's solid gap is tiny: rank must still put
  // the statistically solid finding first.
  const D = catFixture(sandbox(), { sigMode: "dual", rows: [{ kind: "category",
    label: "Yes", stat: "Column %",
    cells: [{ pct: 50, n: 100, sig: "" }, { pct: 52, n: 52, sig: "BC" },
            { pct: 95, n: 48, sig: "ac" }, { pct: 20, n: 10, sig: "" }] }] });
  const found = D.views._collectFindings("Gender");
  eq(found.length, 2, "both appear");
  eq(found[0].soft, false, "solid first regardless of size");
  assert(found[1].score > found[0].score, "even though the soft one scores higher");
});

/* ==========================================================================
   4. Mean / index / NPS findings — real stats over real microdata
   ========================================================================== */

console.log("\nDifferences — mean / index / NPS findings:");

/**
 * 40 respondents, 20 Male + 20 Female, on a 1–10 index question. Male scores
 * 3s and 4s (mean 3.5); Female 7s and 8s (mean 7.5). Male is decisively BELOW
 * the rest — which is exactly the finding a lay reader most wants surfaced and
 * which the published tables carry no significance for.
 */
function meanFixture(D, opts) {
  opts = opts || {};
  const n = 40;
  const males = opts.males === undefined ? 20 : opts.males;
  // A spread of 4/5/6/5 gives sd ≈ 0.82, so a 0.4 gap over 20-a-side lands
  // between the 80% and 95% critical values — a "nearly significant" mean.
  const SOFT = [4, 5, 6, 5];
  const bannerVars = [], scores = [];
  for (let r = 0; r < n; r++) {
    const male = r < males;
    bannerVars.push(male ? 0 : 1);
    if (opts.softMean) scores.push(SOFT[r % 4] + (male ? 0 : 0.4));
    else if (opts.flat) scores.push(r % 2 ? 5 : 6);
    else scores.push(male ? (r % 2 ? 3 : 4) : (r % 2 ? 7 : 8));
  }
  const q = { code: "Q2", title: "Overall rating", category: "Satisfaction",
    type: "scale",
    rows: (opts.rows || [{ kind: "mean", label: "Mean" }]) };
  D.MICRO = { n: n, answers: { Q2: bannerVars.map(() => 0) },
              scores: { Q2: scores }, banner_vars: { Gender: bannerVars },
              boxes: {}, weights: null };
  D.AGG = { project: Object.assign({ low_base_threshold: 10 }, opts.project || {}),
            columns: [{ label: "Male", letter: "A" }, { label: "Female", letter: "B" }],
            banner_groups: [{ id: "Gender", name: "Gender" }],
            questions: [q] };
  D.d2 = { state: { sigMode: opts.sigMode || "95", filters: [] },
           hasMicrodata: () => true, firstBanner: () => "Gender",
           groupCols: () => [0, 1],
           catRows: () => [{ label: "Any", index: 0 }],
           questionByCode: (c) => (c === "Q2" ? q : null) };
  // No published letters for a mean row — that is the whole reason this path
  // recomputes. The model contributes only the row list.
  D.model = { forQuestion: () => ({ columns: [{ label: "Total", letter: "", base: 40 }],
    rows: q.rows.map((r) => ({ kind: r.kind, label: r.label, stat: "Column %", cells: [] })) }) };
  if (opts.disclosure) D.disclosure = opts.disclosure;
  return D;
}

run("17. a group significantly BELOW the rest is a finding — bidirectional by design", () => {
  const D = meanFixture(sandbox(true));
  const found = D.views._collectFindings("Gender");
  eq(found.length, 2, "both groups stand out against the other");
  const male = found.filter((f) => f.column === "Male")[0];
  assert(male, "Male is reported");
  eq(male.direction, "behind", "a low-scoring segment is often the headline");
  eq(male.isMean, true, "flagged as a metric, not a percentage");
  near(male.value, 3.5, 1e-9, "its own mean");
  near(male.rest, 7.5, 1e-9, "the rest's mean");
  near(male.gap, -4, 1e-9, "the gap in the metric's own units");
  eq(male.decimals, 1, "a mean prints to one decimal");
});

run("18. a group that does not differ from the rest raises nothing, in either mode", () => {
  eq(meanFixture(sandbox(true), { flat: true })
       .views._collectFindings("Gender").length, 0,
     "5s and 6s either side of the cut is not a difference at 95%");
  // Dual mode widens the net to 80% — it must not widen it to "any gap at all".
  eq(meanFixture(sandbox(true), { flat: true, sigMode: "dual" })
       .views._collectFindings("Gender").length, 0,
     "…nor at 80%");
});

run("18b. a nearly-significant mean surfaces only in dual mode, flagged soft", () => {
  eq(meanFixture(sandbox(true), { softMean: true })
       .views._collectFindings("Gender").length, 0,
     "an 80%-only mean difference is silent at 95%");
  const dual = meanFixture(sandbox(true), { softMean: true, sigMode: "dual" })
    .views._collectFindings("Gender");
  assert(dual.length > 0, "and appears in dual mode");
  assert(dual.every((f) => f.soft), "flagged soft, so the sentence hedges");
});

run("19. a column below the low-base threshold raises no mean finding", () => {
  const D = meanFixture(sandbox(true), { project: { low_base_threshold: 25 } });
  eq(D.views._collectFindings("Gender").length, 0,
     "20 respondents cannot carry a finding at a threshold of 25");
});

run("19b. a small group is gated on ITS OWN base, not only on the rest's", () => {
  // 5 Male against 35 Female at a threshold of 10. The rest is comfortably
  // large, so only the group-side gate can stop this one.
  const D = meanFixture(sandbox(true), { males: 5, project: { low_base_threshold: 10 } });
  const found = D.views._collectFindings("Gender");
  assert(!found.some((f) => f.column === "Male"),
    "a 5-person group must not carry a finding just because the rest is big");
  eq(found.length, 0, "and the mirror finding is gated by the same 5 people as the rest");
});

run("20. the disclosure gate is honoured — a recomputed mean never resurrects a withheld column", () => {
  // The crosstab blanks columns below min_reporting_base; a mean recomputed from
  // microdata must not report on them either.
  const D = meanFixture(sandbox(true), {
    disclosure: { active: () => true, minBase: () => 25 } });
  eq(D.views._collectFindings("Gender").length, 0, "the k-gate is never looser here");
});

run("21. a Std Dev row is spread, not a centre, and is never a finding", () => {
  const D = meanFixture(sandbox(true), {
    rows: [{ kind: "mean", label: "Std Dev" }] });
  eq(D.views._collectFindings("Gender").length, 0, "spread is not a difference");
});

run("22. an NPS row prints whole numbers, a mean prints one decimal", () => {
  const D = meanFixture(sandbox(true), { rows: [{ kind: "mean", label: "NPS Score" }] });
  const found = D.views._collectFindings("Gender");
  assert(found.length > 0, "the NPS row is a finding");
  eq(found[0].decimals, 0, "an NPS of 41.7 reads as 42");
});

/* ==========================================================================
   5. The sentence a client actually reads
   ========================================================================== */

console.log("\nDifferences — the rendered line:");

run("23. a percentage finding names the groups it beats and the rest it beat them by", () => {
  const D = catFixture(sandbox());
  const html = D.views._diffLineHtml(D.views._collectFindings("Gender")[0]);
  assert(/<strong>Male<\/strong>/.test(html), "the group leads the sentence");
  assert(/85% say “Yes”/.test(html), "its share and the answer");
  assert(/35% of the rest/.test(html), "measured against the rest");
  assert(/\(60% overall\)/.test(html), "with the whole sample in brackets");
  assert(/\+50pp/.test(html), "the gap in percentage points");
  assert(/statistically ahead of Female · Other/.test(html), "and the groups it beats");
});

run("24. a detail row and a defined category are tagged so the label is unambiguous", () => {
  const D = catFixture(sandbox());
  const detail = D.views._diffLineHtml(D.views._collectFindings("Gender")[0]);
  assert(/>detail</.test(detail), "an individual option is tagged 'detail'");
  const cells = [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
                 { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }];
  const N = catFixture(sandbox(), { type: "multi",
    rows: [{ kind: "net", label: "Top 2 Box", stat: "Column %", cells: cells }] });
  const net = N.views._diffLineHtml(N.views._collectFindings("Gender")[0]);
  assert(/>category</.test(net), "a NET grouping is tagged 'category'");
});

run("25. a mean finding reads in its own units, not in percentage points", () => {
  const D = meanFixture(sandbox(true));
  const male = D.views._collectFindings("Gender").filter((f) => f.column === "Male")[0];
  const html = D.views._diffLineHtml(male);
  assert(/Mean 3\.5/.test(html), "the metric and its value");
  assert(/7\.5 of the rest/.test(html), "against the rest's value");
  assert(/·\s*−4\.0/.test(html), "the gap in points, signed");
  assert(!/pp/.test(html), "never 'pp' — this is not a proportion");
  assert(/statistically behind the rest/.test(html), "and the direction is stated");
});

run("26. a nearly-significant finding hedges instead of claiming significance", () => {
  const D = softFixture(sandbox(), "dual");
  const soft = D.views._collectFindings("Gender").filter((f) => f.soft)[0];
  const html = D.views._diffLineHtml(soft);
  assert(/nearly significant \(80%\)/.test(html), "the verdict is hedged");
  assert(!/statistically/.test(html), "and never claims significance");
  assert(/df-line soft/.test(html), "the line carries the soft class for styling");
});

run("27. with no rest available the sentence compares against everyone, honestly", () => {
  const D = catFixture(sandbox(), { project: { weighted: true } });
  const html = D.views._diffLineHtml(D.views._collectFindings("Gender")[0]);
  assert(/60% of everyone/.test(html), "it says 'of everyone', not a rest it cannot compute");
  assert(/Everyone/.test(html), "and the comparison bar is labelled Everyone");
  assert(!/The rest/.test(html), "no 'The rest' bar");
});

run("28. a hostile row label cannot inject markup into the sentence", () => {
  const D = catFixture(sandbox(), { rows: [{ kind: "category",
    label: '<img src=x onerror=alert(1)>', stat: "Column %",
    cells: [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
            { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }] }] });
  const html = D.views._diffLineHtml(D.views._collectFindings("Gender")[0]);
  assert(!/<img/.test(html), "the tag is escaped, not rendered: " + html.slice(0, 200));
  assert(/&lt;img/.test(html), "and survives as text");
});

run("28b. nor can a hostile COLUMN name — it appears in the bars as well as the lead", () => {
  // The column label is rendered twice by two different paths (the sentence lead
  // and the comparison bar), so both need escaping.
  const D = sandbox();
  catFixture(D);
  const evil = '<script>alert(1)</script>';
  D.AGG.columns[1].label = evil;
  D.model = { forQuestion: () => ({ columns: D.AGG.columns,
    rows: [{ kind: "category", label: "Yes", stat: "Column %",
      cells: [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
              { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }] }] }) };
  const html = D.views._diffLineHtml(D.views._collectFindings("Gender")[0]);
  assert(!/<script/.test(html), "no live script tag anywhere: " + html.slice(0, 240));
  eq((html.match(/&lt;script/g) || []).length, 2,
     "escaped in BOTH the sentence lead and the comparison bar");
});

run("28c. a hostile group NAME in the beaten list is escaped too", () => {
  const D = sandbox();
  catFixture(D);
  D.AGG.columns[2].label = '<b>Female</b>';
  D.model = { forQuestion: () => ({ columns: D.AGG.columns,
    rows: [{ kind: "category", label: "Yes", stat: "Column %",
      cells: [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
              { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }] }] }) };
  const html = D.views._diffLineHtml(D.views._collectFindings("Gender")[0]);
  assert(!/<b>Female/.test(html), "the beaten-group list is escaped: " + html.slice(0, 240));
  assert(/&lt;b&gt;Female/.test(html), "and survives as text");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
