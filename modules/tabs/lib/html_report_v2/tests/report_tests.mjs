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
import { TXT, installText } from "./_text.mjs";

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
  // The construction note's words come from the callout registry, exactly as
  // they do in a real build — see _text.mjs.
  installText(sandbox);
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
  assert(h.indexOf(TXT("report.construction.produced",
    { company: "The Research LampPost" })) >= 0, "the attribution renders");
  assert(h.indexOf(TXT("report.construction.ai_and_review")) >= 0,
    "the AI and author-review paragraph renders");
  assert(h.indexOf("Disclaimers / confidentiality") < 0, "the old disclaimer field is gone");
  assert(h.indexOf("OLD CLOSING TEXT") < 0, "closing_notes no longer renders in About");
});

run("the producing company interpolates into the note, with a TRL fallback", () => {
  const h = boot(undefined, { company: "Acme Insights" }).report.aboutHtml();
  assert(h.indexOf(TXT("report.construction.produced", { company: "Acme Insights" })) >= 0,
    "the configured company_name is used");
  const f = boot(undefined, undefined).report.aboutHtml();
  assert(f.indexOf(TXT("report.construction.produced", { company: "The Research LampPost" })) >= 0,
    "falls back to The Research LampPost when report_meta is absent");
});

run("the stock note renders every paragraph the report is entitled to", () => {
  // Asserts the authored blocks are SERVED, not what they say — the wording is
  // the author's and changes in the Callout Editor without touching this file.
  const h = boot(undefined, undefined).report.aboutHtml();
  ["report.construction.computed", "report.construction.self_contained",
   "report.construction.ai_and_review"].forEach((key) => {
    assert(h.indexOf(TXT(key)) >= 0, key + " renders");
  });
  assert(h.indexOf('data-txt-key="report.construction.self_contained"') >= 0,
    "each authored block is tagged with its key, so the author can find it");
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
  assert(h.indexOf(TXT("report.construction.computed")) < 0,
    "the stock sentence stands aside rather than contradicting the study");
  assert(h.indexOf(TXT("report.construction.produced", { company: "Acme Insights" })) >= 0,
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
  ["report.construction.computed", "report.construction.self_contained",
    "report.construction.ai_and_review"].forEach((key) => {
    assert(h.indexOf(TXT(key)) < 0, "a declaration left the stock paragraph in place: " + key);
    assert(h.indexOf('data-txt-key="' + key + '"') < 0, "and left its block behind: " + key);
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
  assert(own.indexOf(TXT("report.construction.produced",
    { company: "Acme Insights" })) < 0,
    "Turas does not add its own attribution on top of the study's");
  assert(own.split("This report was produced by").length - 1 === 1,
    "the producer sentence renders exactly once when the note writes its own");
  assert(own.indexOf("includes R, Python and JavaScript") >= 0, "in the study's own words");

  // a note that does NOT claim attribution still gets it
  const lent = boot(undefined, { company: "Acme Insights",
    construction: "Figures come out of R, then a preparation layer adds composites." })
    .report.aboutHtml();
  const attribution = TXT("report.construction.produced", { company: "Acme Insights" });
  assert(lent.split(attribution).length - 1 === 1,
    "and exactly once when Turas supplies it");
  assert(lent.indexOf(attribution) >= 0, "attribution is never dropped");
});

run("a declared note of several paragraphs renders as several paragraphs", () => {
  const h = boot(undefined, { construction: "First stage.\n\nSecond stage." })
    .report.aboutHtml();
  assert(h.indexOf("First stage.</p>") >= 0 &&
    h.indexOf('<p data-txt-config="_REPORT_CONSTRUCTION">Second stage.</p>') >= 0,
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
  assert(base.indexOf(TXT("report.construction.computed")) >= 0,
    "and the stock note is what it falls back to");
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

run("published-only earlier waves are called previously published", () => {
  const h = boot(undefined, undefined, undefined, PUBLISHED_WAVES).report.aboutHtml();
  assert(h.indexOf(TXT("report.construction.prior_waves_published")) >= 0,
    "historical figures are called out as not recalculated");
});

run("the note never claims that earlier waves go untested", () => {
  // It used to end "…which is why no significance is claimed against them",
  // while the Tracking tab of the same report counted significant wave-on-wave
  // movements. The About card contradicted itself on one page (CCPB W2026).
  const h = boot(undefined, undefined, undefined, PUBLISHED_WAVES).report.aboutHtml();
  assert(h.indexOf("no significance is claimed against them") < 0,
    "the false claim is gone");
});

run("a wave that carries respondent data is not described as published-only", () => {
  // "Shown as previously published rather than recalculated" is a claim the
  // note is only entitled to when no earlier wave carries per-respondent
  // scores — a wave with scores IS recalculated (22w_waves.js).
  const h = boot(undefined, undefined, undefined, MICRO_WAVES).report.aboutHtml();
  assert(h.indexOf('data-txt-key="report.construction.prior_waves_published"') < 0,
    "a recalculated wave is not called a published one");
});

run("a report with no earlier waves says nothing about waves at all", () => {
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf('data-txt-key="report.construction.prior_waves_published"') < 0,
    "a single-wave report says nothing about earlier waves");
  assert(h.indexOf(TXT("report.construction.self_contained")) >= 0,
    "and the recompute paragraph still closes the stock note");
});

run("AI is described as a working tool, and the author owns the report", () => {
  // Author accountability carries the assurance — it stays true as AI use
  // grows — rather than an absolute no-AI claim, which ages badly.
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf(TXT("report.construction.ai_and_review")) >= 0,
    "the AI and accountability paragraph renders in full");
  assert(h.indexOf('data-txt-key="report.construction.ai_and_review"') >= 0,
    "and is tagged, so the author can find it in the Callout Editor");
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
