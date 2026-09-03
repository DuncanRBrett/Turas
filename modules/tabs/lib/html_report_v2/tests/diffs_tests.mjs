#!/usr/bin/env node
/**
 * Differences view. Behavioural gate (production review 2026-08, I12c).
 *
 * `27d_diffs.js` builds the lay reader's "where groups differ" view: which
 * findings appear, what each is measured against, and the sentence each becomes.
 * It shipped with three hooks explicitly exposed "for the differences gate test"
 * (`views._isClassification`, `views._collectFindings`, `views._diffLineHtml`)
 * and no such test, only two incidental checks in stat_label_tests.mjs, both
 * about the C1 stat label. Everything else the view decides was untested: which
 * questions are excluded as tautological cuts, what "the rest" is and when it is
 * unavailable, which rows are suppressed on a scale, the tautological 0%/100%
 * drop, the 95% vs 95%+80% split, the bidirectional mean test and its two base
 * gates, the two-level collapse of reciprocal mean pairs, and the wording of
 * every sentence a client reads.
 *
 * The mean-finding half runs on the REAL statistics module (21_stats.js) over
 * real per-respondent microdata, so it tests the arithmetic the report performs
 * rather than a stub that agrees with it. The categorical half stubs
 * `TR.model.forQuestion`. The model has its own suites, and what is under test
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

/** A fresh sandbox with the view module loaded. 21_stats.js always loads: the
 *  microdata paths need its tabulations, and every view now words its
 *  significance levels through TR.stats.levelPrimary/Secondary rather than a
 *  hard-coded "95%"/"80%". `withStats` is kept for call-site readability. */
function sandbox(withStats) {   // eslint-disable-line no-unused-vars
  const box = { console };
  box.globalThis = box; box.window = box;
  vm.createContext(box);
  const files = ["00_namespace.js", "01_format.js", "21_stats.js"];
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

console.log("Differences. Classification exclusion:");

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
   2. Categorical findings. Letters, the rest, and what is suppressed
   ========================================================================== */

console.log("\nDifferences. Categorical findings:");

/**
 * One question over a Total + three gender columns, with the letters the model
 * would have published. `cells` is [total, A, B, C] as {pct, n, sig}.
 * No microdata, unweighted, so "the rest" comes from the exact count identity.
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
  // Male 85%, and the rest 0%. A defining trait of the group (their own plant,
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

run("11. a choice question keeps its categories. There the categories ARE the story", () => {
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
  // the count identity breaks. The finding falls back to the overall figure
  // rather than printing a rest it cannot stand behind.
  const D = catFixture(sandbox(), { project: { weighted: true } });
  const f = D.views._collectFindings("Gender")[0];
  eq(f.rest, null, "no rest is claimed");
  eq(f.gap, 25, "the gap falls back to the overall figure (85 − 60)");
});

/* ==========================================================================
   3. The 95% / 95%+80% toggle
   ========================================================================== */

console.log("\nDifferences. The significance toggle:");

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
   4. Mean / index / NPS findings. Real stats over real microdata
   ========================================================================== */

console.log("\nDifferences. Mean / index / NPS findings:");

/**
 * 40 respondents, 20 Male + 20 Female, on a 1–10 index question. Male scores
 * 3s and 4s (mean 3.5); Female 7s and 8s (mean 7.5). Male is decisively BELOW
 * the rest, which is exactly the finding a lay reader most wants surfaced and
 * which the published tables carry no significance for.
 */
function meanFixture(D, opts) {
  opts = opts || {};
  const n = 40;
  const males = opts.males === undefined ? 20 : opts.males;
  // A spread of 4/5/6/5 gives sd ≈ 0.82, so a 0.4 gap over 20-a-side lands
  // between the 80% and 95% critical values. A "nearly significant" mean.
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
  // No published letters for a mean row. That is the whole reason this path
  // recomputes. The model contributes only the row list.
  D.model = { forQuestion: () => ({ columns: [{ label: "Total", letter: "", base: 40 }],
    rows: q.rows.map((r) => ({ kind: r.kind, label: r.label, stat: "Column %", cells: [] })) }) };
  if (opts.disclosure) D.disclosure = opts.disclosure;
  return D;
}

run("17. a group significantly BELOW the rest is a finding. Bidirectional by design", () => {
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
  // Dual mode widens the net to 80%. It must not widen it to "any gap at all".
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

run("20. the disclosure gate is honoured. A recomputed mean never resurrects a withheld column", () => {
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
   4b. Reciprocal mean pairs on a two-level banner (SCOPE item 1)
   ========================================================================== */

console.log("\nDifferences. Reciprocal pairs on a two-level banner:");

/** The level count production derives, from the same stub the view reads. */
function levels(D, banner) { return D.d2.groupCols(banner).length; }

run("22b. a two-level banner tells one mean finding twice. The mirror is collapsed", () => {
  const D = meanFixture(sandbox(true));
  const both = D.views._collectFindings("Gender");
  eq(both.length, 2, "collectFindings still emits both ends. Its contract is unchanged");
  eq(levels(D, "Gender"), 2, "Gender is a two-level cut");
  const shown = D.views._collapseReciprocal(both, levels(D, "Gender"));
  eq(shown.length, 1, "the reader sees one line, not the same finding from both ends");
  eq(shown[0].column, "Female", "the higher side leads");
  eq(shown[0].direction, "ahead", "…so the kept line names the group that is ahead");
  near(shown[0].value, 7.5, 1e-9, "its own mean");
  near(shown[0].rest, 3.5, 1e-9, "and the rest, which on a two-level cut is the other level");
});

run("22c. the view renders the collapsed list, not the raw one", () => {
  // The collapse is worthless if nothing calls it: pin the composition the
  // render path actually uses.
  const D = meanFixture(sandbox(true));
  eq(D.views._rankedFindings("Gender").length, 1, "collect + collapse, as views.findings does");
  eq(D.views._rankedFindings("Gender")[0].column, "Female", "and it is the collapsed pair");
});

run("22d. on three or more levels 'A vs the rest' and 'B vs the rest' are different comparisons", () => {
  const D = meanFixture(sandbox(true));
  const both = D.views._collectFindings("Gender");
  eq(D.views._collapseReciprocal(both, 3).length, 2,
     "a three-level banner keeps every finding. Nothing there is a mirror");
  eq(D.views._collapseReciprocal(both, 1).length, 2, "and a single-level cut has no pair either");
});

run("22e. a proportion finding is never collapsed. A significance letter is directional", () => {
  const D = catFixture(sandbox());
  const found = D.views._collectFindings("Gender");
  eq(found.length, 1, "the fixture's one percentage finding");
  eq(D.views._collapseReciprocal(found, 2).length, 1, "and it survives a two-level collapse");
});

run("22f. two findings pointing the SAME way are not a pair, and both stand", () => {
  // Where a banner leaves respondents unbannered, the rest of one level is not
  // the other level, and both groups can sit above their own rest. That is two
  // findings, not one told twice.
  const D = meanFixture(sandbox(true));
  const both = D.views._collectFindings("Gender").map((f) =>
    Object.assign({}, f, { direction: "ahead" }));
  eq(D.views._collapseReciprocal(both, 2).length, 2, "nothing is discarded");
});

run("22g. …nor are two whose tests disagree on significance", () => {
  const D = meanFixture(sandbox(true));
  const both = D.views._collectFindings("Gender");
  const mixed = [both[0], Object.assign({}, both[1], { soft: true })];
  eq(D.views._collapseReciprocal(mixed, 2).length, 2,
     "one solid and one nearly-significant are two different tests");
});

run("22h. a finding with no counterpart is left alone", () => {
  const D = meanFixture(sandbox(true));
  const one = [D.views._collectFindings("Gender")[0]];
  eq(D.views._collapseReciprocal(one, 2).length, 1, "only one side stood out");
});

run("22i. a report with no microdata has no mean findings, so no level count is sought", () => {
  // catFixture's d2 stub carries no groupCols at all. BannerLevels must never
  // reach for it when hasMicrodata() is false.
  const D = catFixture(sandbox());
  assert(!D.d2.groupCols, "the fixture has no groupCols to call");
  eq(D.views._rankedFindings("Gender").length, 1, "and the view still renders its findings");
});

/* ==========================================================================
   5. The sentence a client actually reads
   ========================================================================== */

console.log("\nDifferences. The rendered line:");

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
  assert(!/pp/.test(html), "never 'pp'. This is not a proportion");
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

run("28b. nor can a hostile COLUMN name. It appears in the bars as well as the lead", () => {
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

run("29. the card header leads with the question text; the code stays reachable, not shown", () => {
  // DIFFERENCES_TAB_SCOPE.md item 2: the code prefix is engineering vocabulary
  // in a lay deliverable. It must still be reachable, hover and search, and
  // the pin keeps "code. Title" so a pinned card traces to its crosstab.
  const D = catFixture(sandbox());
  const f = D.views._collectFindings("Gender")[0];
  const html = D.views._diffCardHtml({ code: f.code, title: f.title,
    category: f.category, top: f.score, items: [f] });
  const head = html.match(/<div class="df-qhead">.*?<\/button>/)[0];
  assert(!/Q1 ·/.test(head), "no 'Q1 ·' prefix in the header: " + head);
  assert(/>Are you aware\?</.test(head), "the question text leads");
  assert(/title="Q1"/.test(head), "the code survives as a hover title");
  assert(/data-goq="Q1"/.test(head), "and the jump-to-question link still keys on it");
  assert(/data-search="[^"]*q1/.test(html), "search still finds the code");
  assert(/data-snap-title="Q1: Are you aware\?"/.test(html),
    "the pin keeps code. Title for traceability");
});

run("30. ExcludeFromInsights takes ONE question out of the findings, and nothing else", () => {
  // DIFFERENCES_TAB_SCOPE.md item 4: the per-question opt-out. The flagged
  // question keeps its crosstab (untouched here) but raises no finding; an
  // otherwise identical twin still does, so the flag, not the fixture, is
  // what silenced it.
  const cells = [{ pct: 60, n: 120, sig: "" }, { pct: 85, n: 85, sig: "BC" },
                 { pct: 40, n: 20, sig: "" }, { pct: 30, n: 15, sig: "" }];
  const rows = [{ kind: "category", label: "Yes", stat: "Column %", cells: cells }];
  const twins = [
    { code: "Q1", title: "Are you aware?", category: "Awareness", type: "single",
      exclude_from_insights: true, rows: [{ kind: "category", label: "Yes" }] },
    { code: "Q2", title: "Are you aware?", category: "Awareness", type: "single",
      rows: [{ kind: "category", label: "Yes" }] }
  ];
  const D = catFixture(sandbox(), { rows: rows, questions: twins });
  const found = D.views._collectFindings("Gender");
  eq(found.length, 1, "only the unflagged twin raises a finding");
  eq(found[0].code, "Q2", "and it is the unflagged one");
  // absent / falsy flag must behave exactly as before (no config = no change)
  const D2 = catFixture(sandbox(), { rows: rows, questions: [
    Object.assign({}, twins[0], { exclude_from_insights: false })] });
  eq(D2.views._collectFindings("Gender").length, 1,
     "ExcludeFromInsights = N is the same as not declaring it");
});

run("30b. …including MEAN findings, which are the case the column was built for", () => {
  // The motivating study excludes imputed SPEND measures, which on a two-level
  // banner raise mean findings (and, since decision E, could raise proportion
  // findings too. The flag must silence both). The skip sits above
  // meanFindings() in the same per-question loop; this pins that, rather than
  // inferring it.
  const D = meanFixture(sandbox(true));
  eq(D.views._collectFindings("Gender").length, 2, "unflagged: both sides differ");
  const F = meanFixture(sandbox(true));
  F.AGG.questions[0].exclude_from_insights = true;
  eq(F.views._collectFindings("Gender").length, 0,
     "flagged: the recomputed mean finding is skipped too");
});

/* ==========================================================================
   6. Decision E and the balanced score (DIFFERENCES_RANKING_DESIGN.md)
   ========================================================================== */

console.log("\nDifferences. The two-level gate and the balanced score:");

/**
 * A TWO-level banner (Total + Male/Female), no microdata. Male 75% vs
 * Female 45% on "Yes". The letters carry whatever significance the fixture
 * declares. The rest for Male is the exact count identity:
 * (120 − 75) / (200 − 100) = 45%.
 */
function catFixture2(D, opts) {
  opts = opts || {};
  const rows = opts.rows || [{ kind: "category", label: "Yes", stat: "Column %",
    cells: [{ pct: 60, n: 120, sig: "" }, { pct: 75, n: 75, sig: opts.sig || "B" },
            { pct: 45, n: 45, sig: "" }] }];
  const columns = [{ label: "Total", letter: "", base: 200 },
                   { label: "Male", letter: "A", base: 100 },
                   { label: "Female", letter: "B", base: 100 }];
  D.d2 = { state: { sigMode: opts.sigMode || "95", filters: [] },
           hasMicrodata: () => false, firstBanner: () => "Gender" };
  D.AGG = { project: { low_base_threshold: 30 },
            columns: columns,
            banner_groups: [{ id: "Gender", name: "Gender" }],
            questions: [{ code: "Q1", title: "Do you buy it?",
              category: "Behaviour", type: "single",
              rows: rows.map((r) => ({ kind: r.kind, label: r.label })) }] };
  D.model = { forQuestion: () => ({ columns: columns, rows: rows }) };
  return D;
}

run("31. on a TWO-level banner, beating the single sibling IS a finding (decision E)", () => {
  // Test 5 pins the other half: on three levels one letter stays a pairwise
  // result, not a standout. On two levels the single sibling is ALL the
  // siblings, so one letter is the strongest breadth statement the banner
  // allows, and "who buys what" can finally surface on Gender.
  const D = catFixture2(sandbox());
  const found = D.views._collectFindings("Gender");
  eq(found.length, 1, "one letter carries the finding on a two-level cut");
  const f = found[0];
  eq(f.column, "Male", "the standout group");
  eq(f.beaten.join(","), "Female", "it beat its single sibling by name");
  eq(f.rest, 45, "the rest is the other level, by the count identity");
  eq(f.soft, false, "a 95% letter is a solid finding");
});

run("31b. a lowercase-only letter on two levels is a SOFT finding, dual mode only", () => {
  eq(catFixture2(sandbox(), { sig: "b" }).views._collectFindings("Gender").length, 0,
     "at 95% a lone 80% letter is silent");
  const dual = catFixture2(sandbox(), { sig: "b", sigMode: "dual" })
    .views._collectFindings("Gender");
  eq(dual.length, 1, "in dual mode it appears");
  eq(dual[0].soft, true, "flagged soft so the sentence hedges");
});

run("32. the balanced proportion score is Cohen's h times the share of siblings beaten", () => {
  const D = catFixture2(sandbox());
  const f = D.views._collectFindings("Gender")[0];
  // Independent restatement: h = 2·asin(√.75) − 2·asin(√.45), against Cohen's
  // "large" 0.8 (the Takeout's effect currency); one of one siblings beaten.
  const h = 2 * Math.asin(Math.sqrt(0.75)) - 2 * Math.asin(Math.sqrt(0.45));
  near(f.scoreBalanced, Math.min(1, h / 0.8) * 100, 1e-9,
       "strength 1 (beat them all) × h/0.8");
  // And on the THREE-level fixture: two of two beatable siblings, h capped.
  const T = catFixture(sandbox());
  near(T.views._collectFindings("Gender")[0].scoreBalanced, 100, 1e-9,
       "85% vs 35% is past Cohen's large. Effect caps at 1, strength is 2/2");
});

run("33. the balanced mean score is CAPPED where the legacy score runs away", () => {
  // meanFixture: 3.5 vs 7.5 with sd ≈ 0.5 over 20-a-side, |z| is many times
  // the critical value. The legacy score multiplies by |z|/1.96 unbounded; the
  // balanced score caps evidence at 3× the critical value, so here it is
  // exactly the effect term: |gap| / range × 100 = 4/8 × 100 = 50.
  const D = meanFixture(sandbox(true));
  const f = D.views._collectFindings("Gender")[0];
  assert(f.score > 100, "the legacy score is unbounded (kept for the default sort): " + f.score);
  near(f.scoreBalanced, 50, 1e-9, "capped strength 1 × effect 4/8");
  assert(f.scoreBalanced <= 100, "the balanced score never exceeds 100");
});

run("34. the robust range ignores an outlier on an OBSERVED scale, keeps a DESIGNED one whole", () => {
  const D = sandbox();
  // Designed: ≤ 12 distinct values (a 0–10 scale): outliers are impossible,
  // the full range stands.
  const designed = [];
  for (let i = 0; i < 100; i++) designed.push(i % 11);
  eq(D.views._robustRange(designed, 10), 10, "a rating scale keeps min–max");
  // Observed: 20 distinct values 0..19, five of each. Nearest-rank p5/p95
  // are 0 and 18. One 10,000 spender must not set the denominator.
  const spend = [];
  for (let i = 0; i < 100; i++) spend.push(i % 20);
  eq(D.views._robustRange(spend, 19), 18, "p5..p95 of the clean vector");
  spend.push(10000);
  eq(D.views._robustRange(spend, 10000), 19,
     "one big spender no longer stretches the scoring range");
});

run("34b. …and falls back to the full range when the percentiles collapse", () => {
  // ≥ 95% zeros: p5 = p95 = 0, a zero robust range. The chain falls back to
  // the full min–max rather than dividing by zero.
  const D = sandbox();
  const vals = [];
  for (let i = 0; i < 290; i++) vals.push(0);
  for (let i = 1; i <= 13; i++) vals.push(i * 100);   // 13 distinct positives
  eq(D.views._robustRange(vals, 1300), 1300, "degenerate percentiles → full range");
  eq(D.views._robustRange([], 0), 1, "and an empty/flat vector ends at the 1 guard");
});

run("35. an outlier-carrying spend measure scores on the robust range END TO END", () => {
  // 20 Male around 14.5, 20 Female around 49, one UNBANNERED respondent at
  // 500 (21 distinct values → an observed scale). The outlier sits in "the
  // rest" of every group and in the full range (0–500), but the balanced
  // score must divide by the robust p5–p95 range instead, so it comes out
  // LARGER than the same gap measured against the outlier-stretched range.
  const D = sandbox(true);
  const n = 41, bannerVars = [], scores = [];
  for (let r = 0; r < 40; r++) {
    const male = r < 20;
    bannerVars.push(male ? 0 : 1);
    scores.push(male ? 10 + (r % 10) : 40 + (r % 10) * 2);
  }
  bannerVars.push(2); scores.push(500);
  const q = { code: "Q9", title: "Monthly spend", category: "Spend",
    type: "scale", rows: [{ kind: "mean", label: "Mean" }] };
  D.MICRO = { n: n, answers: {}, scores: { Q9: scores },
              banner_vars: { Gender: bannerVars }, boxes: {}, weights: null };
  D.AGG = { project: { low_base_threshold: 10 },
            columns: [{ label: "Male", letter: "A" }, { label: "Female", letter: "B" }],
            banner_groups: [{ id: "Gender", name: "Gender" }],
            questions: [q] };
  D.d2 = { state: { sigMode: "95", filters: [] }, hasMicrodata: () => true,
           firstBanner: () => "Gender", groupCols: () => [0, 1],
           questionByCode: (c) => (c === "Q9" ? q : null) };
  D.model = { forQuestion: () => ({
    columns: [{ label: "Total", letter: "", base: n }],
    rows: [{ kind: "mean", label: "Mean", stat: "Column %", cells: [] }] }) };
  const found = D.views._collectFindings("Gender");
  assert(found.length >= 1, "the outlier-dragged rest still leaves a finding");
  const f = found[0];
  eq(f.scaleMax, 500, "the DISPLAY range still holds the outlier. Bars and Takeout untouched");
  assert(f.scoreBalanced > Math.abs(f.gap) / (f.scaleMax - f.scaleMin) * 100,
    "the balanced score beats the full-range effect, so the robust range is in the denominator");
  assert(f.scoreBalanced <= 100, "and stays on the 0–100 scale");
});

run("36. the balanced sort reorders where the legacy sort over-ranks certainty", () => {
  // QA: a tiny gap measured with extreme precision. Huge |z|, small effect.
  // QB: a broad gap at ordinary precision. The legacy sort leads with QA
  // (unbounded |z| multiplier); the balanced sort leads with QB (evidence
  // capped, size on its own scale decides).
  const D = sandbox(true);
  const n = 40, bannerVars = [], A = [], B = [];
  for (let r = 0; r < n; r++) {
    const male = r < 20;
    bannerVars.push(male ? 0 : 1);
    A.push((male ? 5.0 : 5.5) + (r % 2 ? 0.01 : 0));
    B.push(male ? (r % 2 ? 1 : 2) : (r % 2 ? 5 : 9));
  }
  const qs = [
    { code: "QA", title: "Tight tiny gap", category: "S", type: "scale",
      rows: [{ kind: "mean", label: "Mean" }] },
    { code: "QB", title: "Broad big gap", category: "S", type: "scale",
      rows: [{ kind: "mean", label: "Mean" }] }];
  D.MICRO = { n: n, answers: {}, scores: { QA: A, QB: B },
              banner_vars: { Gender: bannerVars }, boxes: {}, weights: null };
  D.AGG = { project: { low_base_threshold: 10 },
            columns: [{ label: "Male", letter: "A" }, { label: "Female", letter: "B" }],
            banner_groups: [{ id: "Gender", name: "Gender" }],
            questions: qs };
  D.d2 = { state: { sigMode: "95", filters: [] }, hasMicrodata: () => true,
           firstBanner: () => "Gender", groupCols: () => [0, 1],
           questionByCode: (c) => qs.filter((q) => q.code === c)[0] || null };
  D.model = { forQuestion: () => ({
    columns: [{ label: "Total", letter: "", base: n }],
    rows: [{ kind: "mean", label: "Mean", stat: "Column %", cells: [] }] }) };
  const legacy = D.views._rankedFindings("Gender");
  const balanced = D.views._rankedFindings("Gender", "balanced");
  eq(legacy.length, 2, "one collapsed finding per question");
  eq(legacy[0].code, "QA", "the legacy sort leads with the huge-z sliver");
  eq(balanced[0].code, "QB", "the balanced sort leads with the big difference");
  eq(balanced.length, legacy.length,
     "the findings SET is identical, only the order moves, so 'top N of M' stays honest");
});

run("36b. a soft finding still never outranks a solid one under the balanced sort", () => {
  const D = catFixture(sandbox(), { sigMode: "dual", rows: [{ kind: "category",
    label: "Yes", stat: "Column %",
    cells: [{ pct: 50, n: 100, sig: "" }, { pct: 52, n: 52, sig: "BC" },
            { pct: 95, n: 48, sig: "ac" }, { pct: 20, n: 10, sig: "" }] }] });
  const found = D.views._rankedFindings("Gender", "balanced");
  eq(found.length, 2, "both appear");
  eq(found[0].soft, false, "solid first…");
  assert(found[1].scoreBalanced > found[0].scoreBalanced,
    "…even though the soft one's balanced score is higher");
});

run("37. the sort control offers exactly three orders, balanced in the middle", () => {
  const D = catFixture(sandbox());
  const html = D.views._diffSortOptions("balanced");
  const values = [...html.matchAll(/value="([a-z]+)"/g)].map((m) => m[1]);
  eq(values.join(","), "standout,balanced,question", "the three sort keys, in order");
  assert(/value="balanced" selected/.test(html), "the current key is marked selected");
  assert(/\(balanced\)/.test(html), "and the balanced option says so on its face");
});

/* ---------------------------------------------------------------------------
 * Allocation questions are excluded from Differences (D7).
 * An Allocation carries one series per ITEM row, not one score per question, so
 * a scan built around a single headline mean would report item 1 as though it
 * were the question. Row-aware findings are a follow-up; until then it must
 * raise nothing at all.
 * ------------------------------------------------------------------------- */

function allocFixture(D) {
  const n = 40;
  const bannerVars = [], bank = [], retail = [];
  for (let r = 0; r < n; r++) {
    const male = r < 20;
    bannerVars.push(male ? 0 : 1);
    // A gap far wider than the mean fixture's, so the scan would certainly
    // raise a finding if it read these as a question-level score.
    bank.push(male ? 80 : 20);
    retail.push(male ? 20 : 80);
  }
  const q = { code: "QA", title: "Share of wallet", category: "Wallet",
    type: "single",
    rows: [{ kind: "mean", label: "Bank", mstat: "mean" },
           { kind: "mean", label: "Retailer", mstat: "mean" }] };
  D.MICRO = { n: n, answers: { QA: bannerVars.map(() => -2) },
              series: { QA: { "0": bank, "1": retail } },
              banner_vars: { Gender: bannerVars }, boxes: {}, weights: null };
  D.AGG = { project: { low_base_threshold: 10 },
            columns: [{ label: "Male", letter: "A" }, { label: "Female", letter: "B" }],
            banner_groups: [{ id: "Gender", name: "Gender" }],
            questions: [q] };
  D.d2 = { state: { sigMode: "95", filters: [] },
           hasMicrodata: () => true, firstBanner: () => "Gender",
           groupCols: () => [0, 1],
           catRows: () => [],
           questionByCode: (c) => (c === "QA" ? q : null) };
  D.model = { forQuestion: () => ({ columns: [{ label: "Total", letter: "", base: 40 }],
    rows: q.rows.map((r) => ({ kind: r.kind, label: r.label, stat: "Column %", cells: [] })) }) };
  return D;
}

run("38. an allocation question raises no Differences finding", () => {
  const D = allocFixture(sandbox(true));
  eq(D.views._collectFindings("Gender").length, 0,
     "an allocation's items are not a single headline mean");
});

run("39. …and it is excluded even if indexMeans later learns to read series", () => {
  const D = allocFixture(sandbox(true));
  // The guard is on the question carrying `series` and no `scores`, so it holds
  // independently of what indexMeans does. Prove it by handing indexMeans a
  // working answer: without the guard, this is exactly the shape that would
  // report item 1 as "Share of wallet".
  D.stats.indexMeans = () => ([
    { mean: 80, sd: 1, k: 20 }, { mean: 20, sd: 1, k: 20 }
  ]);
  eq(D.views._collectFindings("Gender").length, 0,
     "the exclusion does not depend on indexMeans returning null");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
