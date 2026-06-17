/**
 * Gate: AI insights rendering (TR.ai, module 28a_ai.js).
 *
 * Loads the renderer in a vm sandbox, injects a TR.AGG.ai fixture and asserts
 * the read-only AI surfaces (per-question callout, exec summary, methodology)
 * render correctly, escape HTML, honour the verified flag, and stay empty when
 * no AI data is present. Run standalone (`node tests/ai_render.mjs`) or spawned
 * by run_tests_v2.mjs.
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const BASE = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const V1_JS = path.join(path.dirname(BASE), "src", "js");
const V2_JS = path.join(BASE, "src", "js");

const sandbox = { console, TextEncoder, URL };
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js", "14_pptx_parts.js"]) {
  vm.runInContext(readFileSync(path.join(V1_JS, f), "utf8"), sandbox, { filename: f });
}
for (const f of readdirSync(V2_JS).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(V2_JS, f), "utf8"), sandbox, { filename: f });
}
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
const assert = (c, m) => { if (!c) throw new Error(m); };

TR.AGG = { ai: {
  model: "Claude Sonnet 4.6 (Anthropic)",
  callouts: {
    Q1: { text: "Two-thirds (68%) reported no lost hours.", confidence: "high" },
    Q2: { text: "Small subgroup signal.", confidence: "low", caveat: "n=12, treat with caution" },
    Q3: { text: "Danger <script>alert(1)</script>", confidence: "high" }
  },
  execSummary: { text: "Para one.\n\nPara two.", verified: false }
} };

run("callout renders narrative + AI label + confidence", () => {
  const h = TR.ai.calloutHtml("Q1");
  assert(h.includes("AI-assisted insight"), "missing AI label");
  assert(h.includes("68%"), "missing narrative");
  assert(h.includes('data-confidence="high"'), "missing confidence attr");
});

run("callout shows a caveat for low-confidence insights", () => {
  const h = TR.ai.calloutHtml("Q2");
  assert(h.includes("ai-callout-caveat"), "missing caveat block");
  assert(h.includes("n=12"), "missing caveat text");
});

run("callout escapes HTML in the narrative", () => {
  const h = TR.ai.calloutHtml("Q3");
  assert(!h.includes("<script>alert"), "raw <script> leaked through");
  assert(h.includes("&lt;script&gt;"), "expected escaped entity");
});

run("callout is empty for an unknown question code", () => {
  assert(TR.ai.calloutHtml("ZZ") === "", "expected empty string");
});

run("exec summary renders paragraphs + unverified flag", () => {
  const h = TR.ai.execSummaryHtml();
  assert(h.includes("AI-assisted key findings"), "missing label");
  assert(h.includes("Para one."), "missing paragraph 1");
  assert(h.includes("Para two."), "missing paragraph 2");
  assert(h.includes("Unverified draft"), "missing unverified flag");
});

run("methodology names the model + carries the disclosure", () => {
  const h = TR.ai.methodologyHtml();
  assert(h.includes("Claude Sonnet 4.6 (Anthropic)"), "missing model name");
  assert(h.includes("always labelled"), "missing AI disclosure");
});

run("verified exec summary omits the unverified flag", () => {
  TR.AGG.ai.execSummary = { text: "Clean summary.", verified: true };
  const h = TR.ai.execSummaryHtml();
  assert(h.includes("Clean summary."), "missing summary text");
  assert(!h.includes("Unverified draft"), "should not flag a verified summary");
});

run("no AI data -> every surface is empty + has() is false", () => {
  TR.AGG = { project: {} };
  assert(TR.ai.calloutHtml("Q1") === "", "callout should be empty");
  assert(TR.ai.execSummaryHtml() === "", "exec summary should be empty");
  assert(TR.ai.methodologyHtml() === "", "methodology should be empty");
  assert(TR.ai.has() === false, "has() should be false");
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
