#!/usr/bin/env node
/**
 * Gate: the audience line must say whether the figures are weighted.
 *
 * Every number in a v2 report is either weighted or it is not, and the answer
 * is the same for all of them. It used to be stated only inside the "How to
 * read this" panel, so a reader who never opened that panel could quote a
 * weighted percentage as a headcount, or the reverse. This asserts the tag is
 * on the audience line in both states of the filter bar - unfiltered and
 * filtered - and that it names the study's own weight label when one exists.
 *
 * Runs against the SHIPPED module JS (modules/tabs/lib/html_report_v2/assets/js).
 *
 * Run with:  node modules/tabs/tests/js/test_filter_audience_weighting.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/tabs/lib/html_report_v2/assets/js");

/** The one element the filter bar writes into, plus the stubs it touches. */
function makeEl() {
  return {
    _html: "",
    hidden: true,
    set innerHTML(v) { this._html = v; },
    get innerHTML() { return this._html; },
    addEventListener() {}, appendChild() {}, replaceChildren() {},
    classList: { toggle() {}, add() {}, remove() {} },
    closest() { return null; },
    getAttribute() { return null; },
    querySelector() { return null; }, querySelectorAll() { return []; },
  };
}

const bar = makeEl();
const documentStub = {
  body: { classList: { toggle() {}, add() {}, remove() {} } },
  createElement: () => makeEl(),
  getElementById: (id) => (id === "filterbar" ? bar : makeEl()),
  addEventListener() {}, removeEventListener() {},
  querySelector() { return null; }, querySelectorAll() { return []; },
};
const sandbox = {
  console, TextEncoder, URL,
  document: documentStub,
  addEventListener() {}, removeEventListener() {},
  getSelection: () => ({ isCollapsed: true, rangeCount: 0 }),
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of readdirSync(JS).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

/** The report state the filter bar reads: microdata present, N respondents. */
function setUp(project, filters) {
  TR.AGG = { project: project, questions: [] };
  TR.MICRO = { n: 1100, weights: null };
  TR.d2.state.filters = filters || [];
  TR.d2.hasMicrodata = function () { return true; };
  TR.d2.tracking = function () { return { enabled: false }; };
  TR.d2.questionByCode = function () { return null; };
  TR.stats.mask = function () { return new Uint8Array(1100).fill(1); };
  TR.stats.maskCount = function () { return 154; };
  TR.disclosure = null;
  TR.filterBar.render();
  return bar.innerHTML;
}

// --- the tag itself, without a DOM -----------------------------------------
TR.AGG = { project: {} };
ok(TR.filterBar.weightingTag() === "unweighted data",
  "an unweighted project says so in as many words");

TR.AGG = { project: { weighted: true } };
ok(TR.filterBar.weightingTag() === "weighted data",
  "a weighted project with no label named still says weighted");

TR.AGG = { project: { weighted: true, weight_label: "Rim weight" } };
ok(TR.filterBar.weightingTag() === "weighted data (Rim weight)",
  "the study's own weight label is named");

TR.AGG = { project: { weighted: true, weight_variable: "wt" } };
ok(TR.filterBar.weightingTag() === "weighted data (wt)",
  "the weight variable stands in when no label is declared");

// A label is authored data, so it must not be able to inject markup.
TR.AGG = { project: { weighted: true, weight_label: "<b>x</b>" } };
ok(TR.filterBar.weightingTag().indexOf("<b>") === -1,
  "a weight label carrying markup is escaped, not rendered");

// --- and on the audience line, in both states -------------------------------
let html = setUp({}, []);
ok(/everyone \(n=1[\s,]?100\)/.test(html), "unfiltered line still names the whole sample");
ok(html.indexOf("unweighted data") > -1,
  "unfiltered audience line carries the weighting tag");
ok(html.indexOf("with with") === -1,
  "the doubled 'with with' is gone from the invitation");

html = setUp({ weighted: true, weight_label: "Population weight" },
             [{ q: "Q1", rows: [0] }]);
ok(html.indexOf("weighted data (Population weight)") > -1,
  "filtered audience line carries the weighting tag too");
ok(html.indexOf("live recompute") > -1, "and keeps the live-recompute promise");

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
