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
function render(userState, reportMeta) {
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
  TR.userState = userState;
  TR.report.renderTab(documentStub.getElementById());
  return lastWrap._html;
}

const META = {
  analyst: "Jess Taylor", email: "jess@researchlamppost.co.za",
  phone: "+27 11 123 4567", company: "The Research Lamppost",
  fieldwork: "May 2026", closing: "Confidential — for CCPB internal use only."
};

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

let h = render(null, META);
ok(h.includes("Jess Taylor"), "About 'analyst' pre-fills analyst_name");
ok(h.includes("The Research Lamppost · jess@researchlamppost.co.za · +27 11 123 4567"),
   "About 'contact' joins company · email · phone");
ok(h.includes("Confidential — for CCPB internal use only."), "About 'disclaimer' pre-fills closing_notes");
ok(h.includes("Fieldwork: May 2026."), "Background section pre-fills fieldwork_dates");

h = render({ report: { sections: {}, about: { analyst: "Someone Else" }, slides: [] } }, META);
ok(h.includes("Someone Else") && !h.includes("Jess Taylor"), "user-typed analyst overrides the config default");

h = render({ report: { sections: {}, about: { analyst: "" }, slides: [] } }, META);
ok(!h.includes("Jess Taylor"), "user-cleared analyst stays empty (empty string wins over default)");

h = render(null, null);
ok(h.includes('data-field="analyst"') && !h.includes("Jess Taylor"),
   "no report_meta → About fields render empty (no crash, no leakage)");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
