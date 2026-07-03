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

/* ---- XML-1.0-illegal characters are stripped (corrupt-workbook gate) ---- */
const esc = sandbox.TR.xlsx.escape;

run("escape strips C0 controls XML 1.0 forbids (\\x0B verbatim gate)", () => {
  assert(esc("a\x0Bb\x1Ac\x00d") === "abcd",
    "\\x0B \\x1A \\x00 stripped: " + JSON.stringify(esc("a\x0Bb\x1Ac\x00d")));
  assert(esc("l1\nl2\tl3\rl4") === "l1\nl2\tl3\rl4", "\\t \\n \\r survive (legal in XML 1.0)");
  assert(esc(" plain text! ") === " plain text! ", "ordinary text untouched");
});

run("escape strips U+FFFE/U+FFFF and unpaired surrogates, keeps emoji pairs", () => {
  assert(esc("a\uFFFEb\uFFFFc") === "abc", "FFFE/FFFF stripped");
  assert(esc("a\uD800b") === "ab", "lone high surrogate stripped");
  assert(esc("a\uDC00b") === "ab", "lone low surrogate stripped");
  assert(esc("ok 😀 done") === "ok 😀 done", "valid surrogate pair (emoji) survives");
});

run("escape still entity-escapes after stripping", () => {
  assert(esc("a<b\x0B&c") === "a&lt;b&amp;c",
    "entities + strip compose: " + JSON.stringify(esc("a<b\x0B&c")));
});

run("a cell built from a control-char verbatim contains no illegal bytes", () => {
  const xml = cell("Great\x0B course\x1A!", true);
  assert(isText(xml), "verbatim stays a text cell");
  assert(xml.indexOf("Great course!") !== -1, "text preserved minus the control chars");
  assert(!/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/.test(xml), "no illegal control bytes in the cell XML");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
