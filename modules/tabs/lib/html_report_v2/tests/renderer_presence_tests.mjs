#!/usr/bin/env node
/**
 * RENDERER PRESENCE. An island without its renderer must be loud.
 *
 * A client deliverable ships only the analysis renderers its islands need: a
 * conjoint report carries no maxdiff code, no report carries the self test.
 * That saves the file describing an analysis the client did not buy. The risk
 * is that the inclusion logic is wrong one day, and the symptom would be a tab
 * that renders nothing and says nothing, which an analyst reads as an empty
 * finding rather than a broken file.
 *
 * shell.boot() refuses instead. This gates the decision it makes.
 * The R half is the CFG_REPORT_V2_RENDERER_MISSING check in
 * build_report_v2_html().
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/renderer_presence_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");

const sandbox = { console, atob, TextDecoder };
sandbox.globalThis = sandbox;
sandbox.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
vm.createContext(sandbox);
vm.runInContext(readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8"), sandbox,
  { filename: "24_shell.js" });
const TR = sandbox.TR;

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
  }
}

function withState(state, fn) {
  const keys = ["CJ", "MD", "PR", "QUAL", "WI", "conjoint", "maxdiff", "pricing", "qual", "whatif"];
  const saved = {};
  keys.forEach((k) => { saved[k] = TR[k]; TR[k] = state[k] || null; });
  try { return fn(); } finally { keys.forEach((k) => { TR[k] = saved[k]; }); }
}

run("a report with no contribution islands needs no contribution renderers", () => {
  withState({}, () => eq(TR.shell._missingRenderers(), [], "nothing missing"));
});

run("every island with its renderer is complete", () => {
  withState({ CJ: {}, MD: {}, PR: {}, QUAL: {},
              conjoint: {}, maxdiff: {}, pricing: {}, qual: {} },
    () => eq(TR.shell._missingRenderers(), [], "all four present"));
});

for (const [island, renderer, name] of [["CJ", "conjoint", "conjoint"],
                                        ["MD", "maxdiff", "maxdiff"],
                                        ["PR", "pricing", "pricing"],
                                        ["QUAL", "qual", "qualitative"]]) {
  run("a " + name + " island with no renderer is reported", () => {
    const state = { CJ: {}, MD: {}, PR: {}, QUAL: {},
                    conjoint: {}, maxdiff: {}, pricing: {}, qual: {} };
    state[renderer] = null;
    withState(state, () => eq(TR.shell._missingRenderers(), [name], name));
  });
  run("a missing " + name + " renderer is fine when the island is absent", () => {
    const state = { conjoint: {}, maxdiff: {}, pricing: {}, qual: {} };
    state[renderer] = null;
    withState(state, () => eq(TR.shell._missingRenderers(), [], name));
  });
}

// What if joins the same rule: its island arrives only when a What if study
// was contributed, and then its renderer must travel with it.
run("a What if island with no renderer is reported", () => {
  withState({ WI: {} }, () => eq(TR.shell._missingRenderers(), ["whatif"], "whatif"));
});
run("a What if island with its renderer is complete", () => {
  withState({ WI: {}, whatif: {} }, () => eq(TR.shell._missingRenderers(), [], "whatif present"));
});

run("several missing renderers are all reported, not just the first", () => {
  withState({ CJ: {}, MD: {}, PR: {}, QUAL: {} },
    () => eq(TR.shell._missingRenderers(),
             ["conjoint", "maxdiff", "pricing", "qualitative"], "all four"));
});

console.log((failed ? "\n✗ " : "\n✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
