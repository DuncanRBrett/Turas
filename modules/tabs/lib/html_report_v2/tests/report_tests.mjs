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
function boot(diagnostics, reportMeta) {
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
    AGG: { project: { name: "proj", diagnostics: diagnostics, report_meta: reportMeta } }
  };
  vm.runInContext(readFileSync(path.join(JS_DIR, "32_report.js"), "utf8"),
    sandbox, { filename: "32_report.js" });
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
  assert(h.indexOf("conventional statistical software, not an AI system") >= 0,
    "the deterministic-software claim renders");
  assert(h.indexOf("no AI model takes part in any calculation") >= 0,
    "the no-AI-in-calculation claim renders");
  assert(h.indexOf("says so and names the model") >= 0, "the AI-disclosure promise renders");
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

run("no meta -> fields are omitted but the note and methodology still render", () => {
  const h = boot(undefined, undefined).report.aboutHtml();
  assert(h.indexOf("Analyst / author") < 0, "no empty analyst field is rendered");
  assert(h.indexOf("Contact details") < 0, "no empty contact field is rendered");
  assert(h.indexOf("Report construction") >= 0, "the note renders regardless");
  assert(h.indexOf("Methodology (auto-generated)") >= 0,
    "the auto-generated methodology block is kept below the note");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
