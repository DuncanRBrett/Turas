#!/usr/bin/env node
/**
 * Standalone gate for the Report tab's config pre-fill (project.report_meta →
 * Background / About). Drives the real TR.report.renderTab through a minimal
 * DOM stub. Run in a FRESH VM per case (report's store() memoises a per-page
 * cache) so the override / cleared-field cases are not polluted by an earlier
 * render. Exits non-zero on any failure. Spawned by run_tests_v2.mjs.
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const V1 = path.join(path.dirname(BASE), "src", "js");
const V2 = path.join(BASE, "src", "js");

// minimal DOM stub: just enough for report.renderTab + its wire() pass
let lastWrap = null;
function makeEl() {
  return {
    _html: "", className: "",
    set innerHTML(v) { this._html = v; }, get innerHTML() { return this._html; },
    addEventListener() {}, appendChild() {},
    replaceChildren(w) { lastWrap = w; },
    querySelector() { return null; }, querySelectorAll() { return []; }
  };
}
const documentStub = {
  createElement() { return makeEl(); },
  getElementById() { return makeEl(); },
  addEventListener() {}
};

// fresh sandbox each call → fresh module caches (mirrors one page load)
function render(userState, reportMeta, comments) {
  const sandbox = { console, TextEncoder, URL, document: documentStub };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"]) {
    vm.runInContext(readFileSync(path.join(V1, f), "utf8"), sandbox, { filename: f });
  }
  for (const f of readdirSync(V2).filter((x) => x.endsWith(".js")).sort()) {
    vm.runInContext(readFileSync(path.join(V2, f), "utf8"), sandbox, { filename: f });
  }
  const TR = sandbox.TR;
  TR.AGG = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_2025.json"), "utf8"));
  TR.MICRO = JSON.parse(readFileSync(path.join(BASE, "data", "sacap_microdata.json"), "utf8"));
  TR.VERIFY = {};
  if (reportMeta) TR.AGG.project.report_meta = reportMeta;
  else delete TR.AGG.project.report_meta;
  if (comments) TR.AGG.comments = comments;
  else delete TR.AGG.comments;
  TR.userState = userState;
  TR.report.renderTab(documentStub.getElementById());
  return { html: lastWrap._html, TR: TR };
}

const META = {
  analyst: "Jess Taylor", email: "jess@researchlamppost.co.za",
  phone: "+27 11 123 4567", company: "The Research Lamppost",
  fieldwork: "May 2026", closing: "Confidential — for CCPB internal use only.",
  background: "60 key account stores were interviewed by phone.",
  exec_summary: "Service rated lower this wave; NPS fell 25 points."
};

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

// ---- Background & Executive summary pre-fill (editable sections) ----
let r = render(null, META);
ok(r.html.includes("60 key account stores were interviewed by phone."),
   "Background section pre-fills config _BACKGROUND");
ok(r.html.includes("Service rated lower this wave; NPS fell 25 points."),
   "Executive summary pre-fills config _EXECUTIVE_SUMMARY");

r = render(null, { fieldwork: "May 2026" });
ok(r.html.includes("Fieldwork: May 2026."),
   "Background falls back to fieldwork when no _BACKGROUND configured");

// ---- About is read-only, sourced from config ----
r = render(null, META);
ok(r.html.includes("Jess Taylor"), "About shows analyst (read-only)");
ok(r.html.includes("The Research Lamppost · jess@researchlamppost.co.za · +27 11 123 4567"),
   "About contact joins company · email · phone");
ok(r.html.includes("Confidential — for CCPB internal use only."), "About shows disclaimer (closing_notes)");
ok(!/class="rpt-about"/.test(r.html) && !/<input[^>]*data-field/.test(r.html),
   "About is read-only — no editable input fields");
ok(r.html.includes("Set from the project configuration."), "About shows the read-only hint");

r = render({ report: { sections: {}, about: { analyst: "Someone Else" }, slides: [] } }, META);
ok(r.html.includes("Jess Taylor") && !r.html.includes("Someone Else"),
   "About ignores stored user edits (read-only)");

r = render(null, null);
ok(!r.html.includes("Jess Taylor"), "no report_meta → About empty, no leakage");

// ---- per-question insights pre-fill from AGG.comments ----
r = render(null, META, { Q9: [{ banner: null, text: "Half the stores are very satisfied." }] });
ok(r.TR.insights.get("Q9", "") === "Half the stores are very satisfied.",
   "insight pre-fills from config comment (general)");
ok(r.TR.insights.get("Q9", "Campus") === "Half the stores are very satisfied.",
   "insight falls back to the general comment for any banner");

r = render(null, META, { Q9: [{ banner: null, text: "general" }, { banner: "Campus", text: "campus-only" }] });
ok(r.TR.insights.get("Q9", "Campus") === "campus-only", "banner-specific config comment wins");

r = render({ insights: { Q9: "analyst wrote this" } }, META, { Q9: [{ banner: null, text: "config" }] });
ok(r.TR.insights.get("Q9", "") === "analyst wrote this", "a user insight overrides the config comment");

r = render(null, META, null);
ok(r.TR.insights.get("Q9", "") === "", "no config comment → empty insight");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
