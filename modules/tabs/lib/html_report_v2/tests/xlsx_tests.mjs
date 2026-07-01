#!/usr/bin/env node
/**
 * XLSX cell-coercion gate. The writer turned any numeric-looking string into a
 * native number, mangling verbatims / identifiers in the qual comment export
 * ("50%" -> 50, "007" -> 7, "0821234567" -> a number). This checks:
 *   - a clean number string still coerces (the numeric-matrix export wants that);
 *   - a leading-zero identifier never coerces (globally correct);
 *   - keepText forces a string cell even for clean numbers (text exports).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/xlsx_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.TR = { fmt: { escapeXml: (s) => String(s == null ? "" : s)
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") } };
vm.createContext(sandbox);
vm.runInContext(readFileSync(path.join(JS_DIR, "23y_xlsx.js"), "utf8"), sandbox, { filename: "23y_xlsx.js" });
const cell = sandbox.TR.xlsx._cell;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
const isNum = (xml, v) => xml === "<c><v>" + v + "</v></c>";
const isText = (xml) => xml.indexOf('t="inlineStr"') !== -1;

console.log("XLSX cell coercion — suite:");

run("native numbers and clean number strings stay numeric (matrix export)", () => {
  assert(isNum(cell(42), 42), "native number 42");
  assert(isNum(cell("45%"), 45), "\"45%\" -> 45 (crosstab cell)");
  assert(isNum(cell("0"), 0), "\"0\" -> 0");
  assert(isNum(cell("0.5"), 0.5), "\"0.5\" -> 0.5");
});

run("leading-zero identifiers are never coerced (007, phones, codes)", () => {
  assert(isText(cell("007")) && cell("007").indexOf("007") !== -1, "007 stays text");
  assert(isText(cell("0821234567")) && cell("0821234567").indexOf("0821234567") !== -1, "phone stays text");
  assert(isText(cell("0081")), "postal code stays text");
});

run("text that isn't a clean number stays text", () => {
  assert(isText(cell("45% AB")), "sig-annotated cell stays text");
  assert(isText(cell("Great course!")), "verbatim stays text");
});

run("keepText forces a string cell even for clean numbers (text exports)", () => {
  assert(isText(cell("50%", true)) && cell("50%", true).indexOf("50%") !== -1, "\"50%\" verbatim kept as text");
  assert(isText(cell("45", true)), "\"45\" kept as text when keepText");
  // native numbers are still numeric even under keepText (an actual number field)
  assert(isNum(cell(45, true), 45), "native number unaffected by keepText");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
