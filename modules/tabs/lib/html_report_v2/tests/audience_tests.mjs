#!/usr/bin/env node
/**
 * Question audience gate — the Selection sheet's FilterLabel / BaseFilter has
 * to reach the v2 report. A routed question ("asked only of shops that allow
 * signwriting") publishes a base smaller than the sample; without the label
 * the reader sees the shortfall and never the reason.
 *
 * A1 d2.audienceNote: FilterLabel wins, raw BaseFilter is the fallback, ""
 *    when neither is set — and defensive on reports built before the fields
 *    existed.
 * A2 cards2._audienceHtml: renders "Base: <label>", escaped; "" when there
 *    is no audience — and the crosstab card actually calls it, between the
 *    title and the live-filter context strip.
 * A3 The model carries it (viewModel.audience), so every surface reading a
 *    model sees the audience without re-reading the question.
 * A4 Exports state it: the card SVG meta line and the PPTX slide kicker both
 *    carry "Base: <label>", kept distinct from the reader's own filter note.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/audience_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const CSS = readFileSync(path.join(HERE, "..", "assets", "styles.css"), "utf8");
const load = (sandbox, file) =>
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(actual, expected, msg) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(msg + ": expected " + e + ", got " + a);
}
function at(hay, needle, msg) {
  const i = hay.indexOf(needle);
  if (i === -1) throw new Error(msg + ": missing " + JSON.stringify(needle));
  return i;
}

/** Sandbox with the real d2 (20_data.js) and a minimal fmt. */
function dataSandbox() {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  load(sb, "00_namespace.js");
  load(sb, "01_format.js");
  load(sb, "20_data.js");
  return sb;
}

console.log("Question audience (Selection FilterLabel / BaseFilter) — suite:");

/* ---------------- A1: the fallback chain ---------------- */

run("A1: FilterLabel wins; BaseFilter is the fallback; neither -> \"\"", () => {
  const { TR } = dataSandbox();
  eq(TR.d2.audienceNote({
    code: "Q38",
    filter_label: "Filter = Has requested sign writing in the last 12 months",
    base_filter: 'Q37 =="Yes"'
  }), "Filter = Has requested sign writing in the last 12 months",
    "label preferred over the raw expression");
  eq(TR.d2.audienceNote({ code: "Q38", base_filter: 'Q37 =="Yes"' }),
    'Q37 =="Yes"', "no label -> raw filter expression (same rule as Excel)");
  eq(TR.d2.audienceNote({ code: "Q1" }), "",
    "question asked of everyone -> no audience line");
});

run("A1: routing-only questions (label, no BaseFilter) still carry it", () => {
  const { TR } = dataSandbox();
  // Q37 in the CCPB W2026 config: the routing lives in the questionnaire, so
  // the data arrives restricted and there is no filter expression to show.
  eq(TR.d2.audienceNote({ code: "Q37",
    filter_label: "Filter = Allows signwriting in your shop" }),
    "Filter = Allows signwriting in your shop", "label with no BaseFilter");
});

run("A1: defensive — null question, blank strings, pre-feature data layers", () => {
  const { TR } = dataSandbox();
  eq(TR.d2.audienceNote(null), "", "null-safe");
  eq(TR.d2.audienceNote({ code: "Q1", filter_label: "   ", base_filter: "  " }), "",
    "whitespace-only cells are no audience");
  eq(TR.d2.audienceNote({ code: "Q1", filter_label: 7 }), "",
    "non-string never leaks into the report");
});

/* ---------------- A2: the crosstab card ---------------- */

function cardsSandbox() {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  sb.TR = {
    fmt: {
      escapeHtml: (s) => String(s == null ? "" : s)
        .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
    },
    AGG: { questions: [], project: {} },
    d2: { state: {}, questionByCode: () => null }
  };
  vm.createContext(sb);
  load(sb, "25_cards.js");
  return sb;
}

run("A2: the card states \"Base: <label>\", escaped", () => {
  const { TR } = cardsSandbox();
  eq(TR.cards2._audienceHtml({ audience: "Filter = Allows signwriting in your shop" }),
    '<div class="qaudience"><b>Base:</b> Filter = Allows signwriting in your shop</div>',
    "audience line");
  eq(TR.cards2._audienceHtml({ audience: 'Q37 =="Yes" & Q38 =="Yes"' }),
    '<div class="qaudience"><b>Base:</b> Q37 ==&quot;Yes&quot; &amp; Q38 ==&quot;Yes&quot;</div>',
    "a raw filter expression is escaped, never injected");
  eq(TR.cards2._audienceHtml({ code: "Q1" }), "", "no audience -> nothing rendered");
  eq(TR.cards2._audienceHtml(null), "", "null-safe");
});

run("A2: the card renders it between the title and the live-filter strip", () => {
  const src = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  const line = at(src, "titleHtml(model) + audienceHtml(model) + contextStrip",
    "audience sits in the question head");
  assert(line > 0, "wired into renderActive");
  assert(/\.qaudience\s*\{/.test(CSS), ".qaudience styled");
});

/* ---------------- A3: the model carries it ---------------- */

run("A3: viewModel.audience is set from the question (null when none)", () => {
  const src = readFileSync(path.join(JS_DIR, "22_model.js"), "utf8");
  at(src, "viewModel.audience = TR.d2.audienceNote(q) || null;",
    "model carries the audience");
});

/* ---------------- A4: exports say it too ---------------- */

run("A4: card SVG meta and PPTX kicker both carry it, distinct from the reader's filter", () => {
  const src = readFileSync(path.join(JS_DIR, "29_export.js"), "utf8");
  const svgMeta = at(src, 'model.audience ? "Base: " + model.audience : ""',
    "card SVG meta");
  const kicker = src.indexOf('model.audience ? "Base: " + model.audience : ""',
    svgMeta + 1);
  assert(kicker !== -1, "PPTX slide kicker carries it too");
  at(src, "model.filterNote", "the reader's own pinned filter stays a separate note");
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
