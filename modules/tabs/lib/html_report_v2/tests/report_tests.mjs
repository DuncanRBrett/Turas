// Report tab — statistical diagnostics panel (report.diagnosticsHtml) and the
// About card (report.aboutHtml). Loads 32_report.js into a vm sandbox with a
// minimal TR and asserts the diagnostics panel renders from
// project.diagnostics (the interactive twin of the Excel stats pack), is
// omitted when absent, and flags TRS events by level; and that About renders
// analyst + contact from report_meta plus the standard report-construction
// note in place of the old configurable disclaimer field.
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

// A fresh module load with project.diagnostics / project.report_meta set to
// the given objects (either may be undefined, as on a report without them).
// `projectExtra` merges into project (alpha, bonferroni, ...) and `prev` sets
// TR.PREV, so the methodology block can be exercised across configurations.
// The REAL 21_stats.js is loaded alongside: the methodology note reports the
// project's configured significance level and whether Bonferroni is on, and
// re-deriving those in a stub would let the note and the engine drift apart.
function boot(diagnostics, reportMeta, projectExtra, prev) {
  const sandbox = {
    console,
    localStorage: { getItem: () => null, setItem: () => {}, removeItem: () => {} }
  };
  sandbox.globalThis = sandbox;
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  sandbox.TR = {
    fmt: { escapeHtml: (s) => String(s == null ? "" : s) },
    ai: { execSummaryHtml: () => "", methodologyHtml: () => "" },
    AGG: { project: Object.assign(
      { name: "proj", diagnostics: diagnostics, report_meta: reportMeta },
      projectExtra || {}) }
  };
  if (prev) sandbox.TR.PREV = prev;
  for (const f of ["21_stats.js", "32_report.js"]) {
    vm.runInContext(readFileSync(path.join(JS_DIR, f), "utf8"), sandbox, { filename: f });
  }
  return sandbox.TR;
}

// Mirrors the shape emitted by diagnostics_for_island() on the R side.
const diag = {
  generated_by: "TABS", status: "PARTIAL",
  sections: [
    { title: "Declaration", rows: [["Project", "SACAP"], ["Status", "PARTIAL"]] },
    { title: "Data received & used", rows: [["Rows × columns", "1,363 × 240"], ["Questions analysed", "40"]] },
    { title: "Assumptions & parameters", rows: [["Significance Testing", "Enabled"], ["Alpha (p-value threshold)", "0.050"]] },
    { title: "Reproducibility", rows: [["Turas version", "10.2"]] }
  ],
  warnings: { summary: "1 event(s) recorded", events: [
    { level: "PARTIAL", code: "CALC_CHART_SKIP", title: "Chart skipped", message: "Base below threshold" }
  ] }
};

console.log("Report tab — statistical diagnostics panel:");

run("absent diagnostics -> the panel is omitted entirely", () => {
  assert(boot(undefined).report.diagnosticsHtml() === "",
    "diagnosticsHtml is empty when project.diagnostics is absent");
  assert(boot(null).report.diagnosticsHtml() === "", "empty for null too");
});

run("present -> a collapsible card with a status pill", () => {
  const h = boot(diag).report.diagnosticsHtml();
  assert(h.indexOf("<details") >= 0 && h.indexOf("rpt-diag") >= 0, "renders a collapsible diagnostics card");
  assert(h.indexOf("Statistical diagnostics") >= 0, "carries the panel heading");
  assert(h.indexOf("rpt-diag-status partial") >= 0 && h.indexOf(">PARTIAL<") >= 0,
    "the status pill reflects the run status (PARTIAL)");
  assert(h.indexOf("This is the reports diagnostics record") >= 0, "carries the hint line");
});

run("present -> every curated section and its rows render", () => {
  const h = boot(diag).report.diagnosticsHtml();
  ["Declaration", "Data received & used", "Assumptions & parameters", "Reproducibility"].forEach((t) => {
    assert(h.indexOf(">" + t + "<") >= 0, "section renders: " + t);
  });
  assert(h.indexOf(">1,363 × 240<") >= 0, "a data-used row value renders");
  assert(h.indexOf(">0.050<") >= 0, "an assumptions row value renders");
  assert(h.indexOf("Configuration") < 0, "no raw config-echo section (curated panel)");
});

run("present -> TRS events render one row each, flagged by level", () => {
  const h = boot(diag).report.diagnosticsHtml();
  assert(h.indexOf("Warnings &amp; events") >= 0, "the warnings section renders");
  assert(h.indexOf("rpt-diag-lvl partial") >= 0, "the event level is flagged with its class");
  assert(h.indexOf("CALC_CHART_SKIP") >= 0, "the event code renders");
  assert(h.indexOf("Chart skipped — Base below threshold") >= 0, "title + message combine into the detail");
});

run("no events -> a clean-run line, never an empty events table", () => {
  const clean = { status: "PASS",
    sections: [{ title: "Declaration", rows: [["Project", "X"]] }],
    warnings: { summary: "No events — analysis ran cleanly", events: [] } };
  const h = boot(clean).report.diagnosticsHtml();
  assert(h.indexOf("rpt-diag-clean") >= 0 && h.indexOf("No events — analysis ran cleanly") >= 0,
    "the clean-run summary is shown");
  assert(h.indexOf("rpt-diag-events") < 0, "no events table when there are no events");
  assert(h.indexOf("rpt-diag-status pass") >= 0, "PASS status pill");
});

run("a malformed section (missing rows) is skipped, not crashed on", () => {
  const odd = { status: "PASS", sections: [{ title: "Empty" }, { title: "Declaration", rows: [["Project", "Y"]] }],
    warnings: { summary: "clean", events: [] } };
  const h = boot(odd).report.diagnosticsHtml();
  assert(h.indexOf(">Declaration<") >= 0, "the well-formed section still renders");
  assert(h.indexOf(">Empty<") < 0, "the row-less section is dropped rather than throwing");
});

console.log("\nReport tab — About card & report-construction note:");

run("analyst + contact render from the config-fed island meta", () => {
  const h = boot(undefined, {
    analyst: "Duncan Brett", company: "The Research LampPost",
    email: "duncan@researchlamppost.co.za", phone: "+27 82 000 0000"
  }).report.aboutHtml();
  assert(h.indexOf("Analyst / author") >= 0 && h.indexOf("Duncan Brett") >= 0,
    "the analyst field renders with the configured name");
  assert(h.indexOf("Contact details") >= 0, "the contact field renders");
  assert(h.indexOf("The Research LampPost · duncan@researchlamppost.co.za · +27 82 000 0000") >= 0,
    "contact joins company · email · phone");
});

run("the standard report-construction note replaces the old disclaimer field", () => {
  const h = boot(undefined, { analyst: "D", closing: "OLD CLOSING TEXT" }).report.aboutHtml();
  assert(h.indexOf("Report construction") >= 0, "the note's heading renders");
  assert(h.indexOf("produced by code and can be reproduced from the source data") >= 0,
    "the deterministic claim renders");
  assert(h.indexOf("It calculates nothing") >= 0,
    "AI is stated to calculate nothing");
  assert(h.indexOf("labelled and the model named") >= 0, "the AI-disclosure promise renders");
  assert(h.indexOf("reviewed and validated by the report author") >= 0,
    "the author-validation line renders");
  assert(h.indexOf("Disclaimers / confidentiality") < 0, "the old disclaimer field is gone");
  assert(h.indexOf("OLD CLOSING TEXT") < 0, "closing_notes no longer renders in About");
});

run("the producing company interpolates into the note, with a TRL fallback", () => {
  const h = boot(undefined, { company: "Acme Insights" }).report.aboutHtml();
  assert(h.indexOf("produced by Acme Insights using Turas Analytics") >= 0,
    "the configured company_name is used");
  const f = boot(undefined, undefined).report.aboutHtml();
  assert(f.indexOf("produced by The Research LampPost using Turas Analytics") >= 0,
    "falls back to The Research LampPost when report_meta is absent");
});

run("the construction note describes BOTH engines, not just R", () => {
  // "Statistical analysis runs in R" was true of the published figures only.
  // Every COMPUTED view and all wave significance are recalculated in the
  // browser, so a reader told "it runs in R" would be told something untrue.
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("published figures are computed in R") >= 0,
    "R is scoped to the published figures");
  assert(h.indexOf("recalculates it as you click") >= 0,
    "the in-browser recompute is disclosed");
  assert(h.indexOf("works with no internet connection") >= 0,
    "the self-contained claim is stated plainly");
  assert(h.indexOf("Statistical analysis runs in R, and") < 0,
    "the old R-only phrasing is gone");
});

run("a study can state how its own numbers were built, in place of the default", () => {
  // Turas describes a stock Turas report accurately. It cannot see the stages a
  // study puts around it - a derived engine ahead of it, a preparation layer
  // building composite columns, pages that compute in the browser from their
  // own embedded data - so the study declares them and the declaration stands
  // in place of the default sentence. Turas never guesses on a study's behalf.
  const h = boot(undefined, {
    company: "Acme Insights",
    construction: "Figures are computed in R, then a preparation layer adds composite columns."
  }).report.aboutHtml();
  assert(h.indexOf("preparation layer adds composite columns") >= 0,
    "the study's own account of its build is shown");
  assert(h.indexOf("published figures are computed in R.") < 0,
    "the default sentence stands aside rather than contradicting the study");
  assert(h.indexOf("produced by Acme Insights using Turas Analytics") >= 0,
    "the producer line is kept, so a declaration cannot drop the attribution");
  const declaredAt = h.indexOf("preparation layer");
  assert(h.indexOf("Report construction") < declaredAt,
    "it sits under the Report construction heading");
});

run("a declaration replaces the WHOLE stock block, not just its first sentence", () => {
  // Operator decision 2026-08-11: each study owns its Report construction
  // section. The stock reproducibility, AI and author-validation paragraphs used
  // to render underneath a declaration regardless — so a config that restated
  // them printed them twice (CCPB W2026 did exactly that), and a config that
  // deliberately left one out had it reinstated. The study is the authority on
  // how its own numbers were built, and it owns the assurances with it.
  const h = boot(undefined, { construction: "Built by hand, checked twice." }).report.aboutHtml();
  assert(h.indexOf("Built by hand, checked twice.") >= 0, "the study's own words render");
  ["produced by code and can be reproduced from the source data",
    "We use AI as a working tool",
    "reviewed and validated by the report author"].forEach((stock) => {
    assert(h.indexOf(stock) < 0, "a declaration left the stock paragraph in place: " + stock);
  });
  // and nothing renders twice
  const twice = boot(undefined, { company: "Acme Insights",
    construction: "This report was produced by Acme Insights using Turas Analytics, our " +
      "in-house analysis and reporting platform. We use AI as a working tool." }).report.aboutHtml();
  assert(twice.split("We use AI as a working tool").length - 1 === 1,
    "a config that restates a stock paragraph prints it once, not twice");
});

run("a note that writes its own producer line does not get a second one", () => {
  // An author drafting this row opens the way the section reads — "This report
  // was produced by …" — and the prepended copy printed the sentence twice on
  // the client's page (CCPB W2026). Whoever says it, it is said exactly once.
  const own = boot(undefined, { company: "Acme Insights",
    construction: "This report was produced by Acme Insights using Turas Analytics, which " +
      "includes R, Python and JavaScript." }).report.aboutHtml();
  assert(own.split("This report was produced by").length - 1 === 1,
    "the producer sentence renders exactly once when the note writes its own");
  assert(own.indexOf("includes R, Python and JavaScript") >= 0, "in the study's own words");

  // a note that does NOT claim attribution still gets it
  const lent = boot(undefined, { company: "Acme Insights",
    construction: "Figures come out of R, then a preparation layer adds composites." })
    .report.aboutHtml();
  assert(lent.split("This report was produced by").length - 1 === 1,
    "and exactly once when Turas supplies it");
  assert(lent.indexOf("produced by Acme Insights using Turas Analytics") >= 0,
    "attribution is never dropped");
});

run("a declared note of several paragraphs renders as several paragraphs", () => {
  const h = boot(undefined, { construction: "First stage.\n\nSecond stage." })
    .report.aboutHtml();
  assert(h.indexOf("First stage.</p>") >= 0 && h.indexOf("<p>Second stage.</p>") >= 0,
    "blank-line-separated paragraphs survive as paragraphs");
});

run("a report that declares nothing renders exactly as it did before", () => {
  // The house rule the provenance feature set: a config without the new field
  // must produce a byte-identical report. Blank, whitespace and absent all mean
  // the same thing - say nothing, change nothing.
  const base = boot(undefined, { company: "Acme Insights" }).report.aboutHtml();
  ["", "   ", undefined].forEach((value) => {
    const h = boot(undefined, { company: "Acme Insights", construction: value })
      .report.aboutHtml();
    assert(h === base, "an empty construction note changed the rendered About");
  });
  assert(base.indexOf("published figures are computed in R") >= 0,
    "and the default sentence is what it falls back to");
});

// Wave fixtures. TR.PREV always carries the current wave, so one entry is not a
// tracker. `scores` on a wave question means that wave holds respondent-level
// data and IS recalculated (22w_waves.js), which changes what the note may claim.
const PUBLISHED_WAVES = { waves: [
  { wave: "2025", questions: { Q1: { code: "Q1", stats: { mean: 8.1 } } } },
  { wave: "W2026", current: true, questions: { Q1: { code: "Q1", scores: [8, 9] } } }
] };
const MICRO_WAVES = { waves: [
  { wave: "2025", questions: { Q1: { code: "Q1", scores: [7, 8] } } },
  { wave: "W2026", current: true, questions: { Q1: { code: "Q1", scores: [8, 9] } } }
] };

run("the reproducibility claim is scoped to what the software computes", () => {
  const h = boot(undefined, undefined, undefined, PUBLISHED_WAVES).report.aboutHtml();
  assert(h.indexOf("produced by code and can be reproduced from the source data") >= 0,
    "the claim is scoped to code-produced figures");
  assert(h.indexOf("carried forward from earlier waves are the numbers published") >= 0,
    "historical figures are called out as not recalculated");
});

run("the note never claims that earlier waves go untested", () => {
  // It used to end "…which is why no significance is claimed against them",
  // while the Tracking tab of the same report counted significant wave-on-wave
  // movements and the auto-methodology block below described the test. The About
  // card contradicted itself on one page (CCPB W2026: 8 up, 1 down).
  const h = boot(undefined, undefined, undefined, PUBLISHED_WAVES).report.aboutHtml();
  assert(h.indexOf("no significance is claimed against them") < 0,
    "the false claim is gone");
  assert(h.indexOf("the comparison is tested on the figures and bases each wave carries") >= 0,
    "and what actually happens is stated instead");
});

run("a wave that carries respondent data is not described as published-only", () => {
  // "Shown as published rather than recalculated" is a claim the note is only
  // entitled to when no earlier wave carries per-respondent scores.
  const h = boot(undefined, undefined, undefined, MICRO_WAVES).report.aboutHtml();
  assert(h.indexOf("are the numbers published at the time") < 0,
    "a recalculated wave is not called a published one");
  assert(h.indexOf("the comparison is tested on the figures and bases each wave carries") >= 0,
    "the comparison sentence still applies");
});

run("a report with no earlier waves says nothing about waves at all", () => {
  const h = boot(undefined, undefined).report.aboutHtml();
  ["wave comparison", "carried forward from earlier waves", "each wave carries"]
    .forEach((s) => assert(h.indexOf(s) < 0, "a single-wave report mentions waves: " + s));
  assert(h.indexOf("recompute from the respondent-level data held inside the file.") >= 0,
    "and the recompute sentence closes cleanly without the wave clause");
});

run("the recompute sentence does not fold waves in with filters", () => {
  // Filters and custom banners recompute from respondent-level data. A wave
  // loaded from published tables has none in the file to recompute from, so
  // listing all three together was untrue for the third.
  const h = boot(undefined, undefined, undefined, PUBLISHED_WAVES).report.aboutHtml();
  assert(h.indexOf("filters, custom banners and wave comparisons all recompute") < 0,
    "the old conflated list is gone");
  assert(h.indexOf("a wave comparison reads each earlier wave from the figures the file carries") >= 0,
    "waves are named separately and accurately");
});

run("the report is not said to send anything while it is read", () => {
  // Verified against the engine: no fetch, XHR, beacon or socket anywhere in it.
  // AI insights, when used, run in R at BUILD time, so they do not qualify this.
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("Nothing is sent anywhere while you read it") >= 0,
    "the claim is scoped to reading, which is the strong and true version");
});

run("AI is described as a working tool, covering every route it reaches the report by", () => {
  // The old note promised "the report says so and names the model" for any AI
  // report content, but that promise is wired to TR.ai.methodologyHtml(), which
  // fires only when Turas's own insights run. AI-drafted comment marks and
  // config-authored sections arrive by other routes and never triggered it, so
  // the note claimed a completeness it could not deliver.
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("We use AI as a working tool") >= 0,
    "AI in the workflow is acknowledged, not only AI as a product feature");
  assert(h.indexOf("first-pass drafting and sifting") >= 0,
    "the actual first-pass uses are named");
  assert(h.indexOf("accountable for what") >= 0,
    "author accountability carries the assurance — it stays true as AI use grows");
  assert(h.indexOf("not an AI system") < 0,
    "the negative identity claim is gone; it ages badly and protests too much");
});

run("the construction note contains no em dashes", () => {
  // Duncan's house style. Also the tell readers most associate with AI-written
  // prose, which is a poor look on the paragraph explaining our use of AI.
  const h = boot(undefined, undefined).report.aboutHtml();
  const note = h.slice(h.indexOf("Report construction"));
  assert(note.indexOf("—") < 0, "an em dash crept into the report-construction note");
});

run("the auto-generated methodology paragraph is gone from the Report tab", () => {
  // Removed 2026-08-11 (Duncan): it restated in prose what the Statistical
  // diagnostics panel and the How-to-read guide already carry, on the page whose
  // job is the narrative. Nothing was lost — both other surfaces keep it.
  const h = boot(undefined, undefined, undefined,
    { waves: [{ wave: "2025" }, { wave: "W2026", current: true }] }).report.aboutHtml();
  ["Methodology (auto-generated)", "two-proportion pooled z-test", "Welch t-test",
    "Bonferroni correction", "compared at the 95% level", "Wave-on-wave change is tested",
    "are excluded from testing and flagged"]
    .forEach((gone) => assert(h.indexOf(gone) < 0, "still on the Report tab: " + gone));
});

run("a stock unweighted report ends at the construction note", () => {
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("Report construction") >= 0, "the note renders");
  assert(h.indexOf("Notes on this report") < 0,
    "and nothing follows it when no conditional disclosure applies");
});

run("weighting is still disclosed, because it changes how every base reads", () => {
  const h = boot(undefined, undefined,
    { weighted: true, weight_variable: "rim_wt" }).report.aboutHtml();
  assert(h.indexOf("Notes on this report") >= 0, "the surviving notes get a heading");
  assert(h.indexOf("Weighting.") >= 0 && h.indexOf("rim_wt") >= 0,
    "the weight variable is named");
  assert(h.indexOf("effective") >= 0, "and the three bases are explained");
});

run("synthetic respondent data is still disclosed", () => {
  // A reader must never mistake a fitted prototype for real fieldwork.
  const sandbox = boot(undefined, undefined);
  sandbox.MICRO = { synthetic: true };
  const h = sandbox.report.aboutHtml();
  assert(h.indexOf("SYNTHETIC") >= 0, "the prototype warning survives");
});

run("the AI attribution is still rendered, keeping the construction note's promise", () => {
  // The note promises AI-generated report text is labelled and its model named.
  // TR.ai.methodologyHtml() is the only thing that keeps it, so it outlived the
  // methodology block it used to sit inside.
  const sandbox = boot(undefined, undefined);
  sandbox.ai.methodologyHtml = () => "<p>Drafted with claude-opus-5.</p>";
  const h = sandbox.report.aboutHtml();
  assert(h.indexOf("claude-opus-5") >= 0, "the model is still named on the Report tab");
});

run("no meta -> fields are omitted but the note still renders", () => {
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("Analyst / author") < 0, "no empty analyst field is rendered");
  assert(h.indexOf("Contact details") < 0, "no empty contact field is rendered");
  assert(h.indexOf("Report construction") >= 0, "the note renders regardless");
});

console.log("\nReport tab — read-only authored sections (config-sourced):");

run("background + exec render read-only from the config, one paragraph per line", () => {
  const TR = boot(undefined, {
    background: "Why we ran it.",
    exec_summary: "First finding.\nSecond finding."
  });
  const h = TR.report.sectionsHtml();
  assert(h.indexOf("<textarea") < 0, "no editable textarea remains");
  assert(h.indexOf("<h3>Background & method</h3>") >= 0, "background card renders");
  assert(h.indexOf("<p>Why we ran it.</p>") >= 0, "background text as a paragraph");
  assert(h.indexOf("<p>First finding.</p><p>Second finding.</p>") >= 0,
    "multi-line exec splits into paragraphs");
});

run("populated sections are pinnable to the story (declarative snap markup)", () => {
  const h = boot(undefined, { exec_summary: "Only exec." }).report.sectionsHtml();
  assert(h.split("data-snap-pin").length - 1 === 1, "exactly one pin (the populated card)");
  assert(h.indexOf('data-snap-source="report"') >= 0, "pin is tagged source=report");
  assert(h.indexOf('data-snap-title="Executive summary"') >= 0, "pin carries the section title");
  assert(h.split(" data-snap-card").length - 1 === 1, "only the populated card is snapshottable");
});

run("an unset section shows the config hint instead of an editor", () => {
  const h = boot(undefined, { exec_summary: "Only exec." }).report.sectionsHtml();
  assert(h.indexOf("_BACKGROUND") >= 0, "the hint names the Comments-sheet row");
  const none = boot(undefined, undefined).report.sectionsHtml();
  assert(none.indexOf("_BACKGROUND") >= 0 && none.indexOf("_EXECUTIVE_SUMMARY") >= 0,
    "both hints when nothing is authored");
  assert(none.indexOf("data-snap-pin") < 0, "nothing to pin on an unauthored report");
});

run("the fieldwork fallback still supplies Background & method", () => {
  const h = boot(undefined, { fieldwork: "May 2026" }).report.sectionsHtml();
  assert(h.indexOf("<p>Fieldwork: May 2026.</p>") >= 0, "the fieldwork line renders");
});

run("sectionText is config-only — legacy stored edits are ignored", () => {
  const TR = boot(undefined, { exec_summary: "CFG TEXT" });
  TR.userState = { report: { sections: { exec: "OLD LOCAL EDIT" }, about: {}, slides: [] } };
  assert(TR.report.sectionText("exec") === "CFG TEXT",
    "the config value wins over stored analyst edits");
  assert(boot(undefined, undefined).report.sectionText("exec") === "",
    "empty when the config authors nothing");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
