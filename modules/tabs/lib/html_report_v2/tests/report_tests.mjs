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
  assert(h.indexOf("twin of the Excel stats") >= 0, "explains it is the twin of the Excel pack");
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
  assert(h.indexOf("Every number here is produced by code") >= 0,
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

run("the reproducibility claim is scoped to what the software computes", () => {
  // Waves loaded from published figures have no source data to reproduce them
  // from, which is precisely why no significance is claimed against them.
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("Every number here is produced by code") >= 0,
    "the claim is scoped to code-produced figures");
  assert(h.indexOf("carried forward from earlier waves") >= 0,
    "historical figures are called out as not recalculated");
  assert(h.indexOf("no significance is claimed against them") >= 0,
    "and the consequence is stated");
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

run("methodology names BOTH tests and the Bonferroni correction", () => {
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("two-proportion pooled z-test") >= 0, "the proportion test is named");
  assert(h.indexOf("Welch t-test") >= 0,
    "the Welch test is named — means/indexes/NPS use it and it was omitted before");
  assert(h.indexOf("Bonferroni correction") >= 0,
    "Bonferroni is disclosed; it materially raises the bar for a letter");
});

run("methodology drops Bonferroni from the text when the project disables it", () => {
  const h = boot(undefined, undefined, { bonferroni: false }).report.aboutHtml();
  assert(h.indexOf("Bonferroni") < 0, "no Bonferroni claim when it is switched off");
  assert(h.indexOf("Welch t-test") >= 0, "the rest of the note is unaffected");
});

run("methodology reports the CONFIGURED level, not a hard-coded 95%", () => {
  const dflt = boot(undefined, undefined).report.aboutHtml();
  assert(dflt.indexOf("compared at the 95% level") >= 0, "0.05 default reads as 95%");
  const ninety = boot(undefined, undefined, { alpha: 0.10 }).report.aboutHtml();
  assert(ninety.indexOf("compared at the 90% level") >= 0,
    "alpha 0.10 reads as 90% — a fixed 95% would describe letters the report never shows");
  assert(ninety.indexOf("compared at the 95% level") < 0, "and 95% is not also claimed");
});

run("the wave-test caveat appears only when there IS wave history", () => {
  const none = boot(undefined, undefined).report.aboutHtml();
  assert(none.indexOf("Wave-on-wave change is tested") < 0,
    "no tracking history -> no wave sentence");
  const tracked = boot(undefined, undefined, undefined,
    { waves: [{ wave: "2025" }, { wave: "W2026", current: true }] }).report.aboutHtml();
  assert(tracked.indexOf("Wave-on-wave change is tested") >= 0, "with history it renders");
  assert(tracked.indexOf("single planned comparison") >= 0,
    "and explains why wave tests take no Bonferroni divisor");
});

run("no meta -> fields are omitted but the note and methodology still render", () => {
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("Analyst / author") < 0, "no empty analyst field is rendered");
  assert(h.indexOf("Contact details") < 0, "no empty contact field is rendered");
  assert(h.indexOf("Report construction") >= 0, "the note renders regardless");
  assert(h.indexOf("Methodology (auto-generated)") >= 0,
    "the auto-generated methodology block is kept below the note");
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
