#!/usr/bin/env node
/**
 * Question provenance gate. The Selection sheet's Source / Formula has to
 * reach the v2 report. A column worked out before the config ever saw it
 * arrives at the engine as a finished column, so a derived figure and an asked
 * one look identical on the page unless the config says which is which.
 *
 * P1 cards2._provenance: a Formula means derived, a Source alone means asked,
 *    neither means the card says nothing, and defensive on reports built
 *    before the fields existed.
 * P2 The badge: DERIVED / ASKED beside the question code, escaped, with the
 *    source and formula in the tooltip. Nothing at all when undeclared.
 * P3 The note: shown only while the Sources toggle is on, and it never
 *    appears on a question that declares nothing.
 * P4 Wiring: the badge and the note sit in the question head, the toggle is
 *    offered ONLY when the report carries provenance, and it round-trips
 *    through the hash so a shared link keeps it.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/provenance_tests.mjs
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

/** Sandbox with 25_cards.js over a question index we control. */
function cardsSandbox(questions, state) {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  const byCode = {};
  (questions || []).forEach((q) => { byCode[q.code] = q; });
  sb.TR = {
    fmt: {
      escapeHtml: (s) => String(s == null ? "" : s)
        .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
    },
    AGG: { questions: questions || [], project: {} },
    d2: { state: state || {}, questionByCode: (c) => byCode[c] || null }
  };
  vm.createContext(sb);
  load(sb, "25_cards.js");
  return sb;
}

const DERIVED = {
  code: "Elec_Spend",
  source: "electricity amount question",
  formula: "mean monthly spend among buyers"
};
const ASKED = { code: "Age", source: "survey question" };
const SILENT = { code: "Gender" };

console.log("Question provenance (Selection Source / Formula): suite:");

/* ---------------- P1: what counts as derived ---------------- */

run("P1: a Formula means derived; a Source alone means asked; neither -> null", () => {
  const { TR } = cardsSandbox([DERIVED, ASKED, SILENT]);
  eq(TR.cards2._provenance("Elec_Spend"),
    { derived: true, source: "electricity amount question",
      formula: "mean monthly spend among buyers" },
    "formula present -> derived");
  eq(TR.cards2._provenance("Age"),
    { derived: false, source: "survey question", formula: "" },
    "source with no formula -> asked");
  eq(TR.cards2._provenance("Gender"), null, "declares nothing -> nothing to say");
});

run("P1: defensive. Unknown code and pre-feature data layers", () => {
  const { TR } = cardsSandbox([SILENT]);
  eq(TR.cards2._provenance("NotAQuestion"), null, "unknown code is null-safe");
  // A report built before the columns existed has no source/formula keys at
  // all; it must read as undeclared, never as asked.
  eq(TR.cards2._provenance("Gender"), null, "absent keys are not an empty declaration");
});

/* ---------------- P2 + P3: badge and note ---------------- */

run("P2: the note is for DERIVED questions only, formula first", () => {
  const on = { showSources: true };
  let TR = cardsSandbox([DERIVED], on).TR;
  eq(TR.cards2._provNoteHtml("Elec_Spend"),
    '<div class="provnote"><b>Derived:</b> mean monthly spend among buyers  ·  ' +
    'electricity amount question</div>',
    "the formula leads. It is the part that changes how the number reads");
  // An asked question gets the badge and nothing else: 87 cards saying
  // "Source: survey question" would bury the lines that matter.
  TR = cardsSandbox([ASKED], on).TR;
  eq(TR.cards2._provNoteHtml("Age"), "", "asked -> badge only, no line");
  TR = cardsSandbox([SILENT], on).TR;
  eq(TR.cards2._provNoteHtml("Gender"), "", "undeclared -> nothing rendered");
});

run("P3: the formula is never hidden; the toggle governs the source names", () => {
  const src = readFileSync(path.join(JS_DIR, "20_data.js"), "utf8");
  at(src, "showSources: true", "default on. A reader should not have to find a checkbox");

  // Toggle ON: how it was worked out, then what from.
  const on = cardsSandbox([DERIVED], { showSources: true });
  const noteOn = on.TR.cards2._provNoteHtml("Elec_Spend");
  assert(noteOn.indexOf("mean monthly spend among buyers") !== -1, "formula shows");
  assert(noteOn.indexOf("electricity amount question") !== -1, "source shows");

  // Toggle OFF: the formula stays. A DERIVED badge with nothing beside it
  // tells the reader the number was worked out and withholds how, and the
  // control that would answer them is called "Sources", which is not what
  // they would go looking for.
  const { TR } = cardsSandbox([DERIVED], { showSources: false });
  const noteOff = TR.cards2._provNoteHtml("Elec_Spend");
  assert(noteOff.indexOf("mean monthly spend among buyers") !== -1,
    "toggle off -> the formula still shows");
  assert(noteOff.indexOf("electricity amount question") === -1,
    "toggle off -> the source name is gone");
  assert(noteOff.indexOf("·") === -1, "toggle off -> no dangling separator");
  // The badge is not behind the toggle: whether a number was asked or worked
  // out is not something a reader should have to go looking for.
  const cards = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  const b = at(cards, "function provBadgeHtml", "badge builder exists");
  assert(cards.indexOf("TR.d2.state.showSources", b) === -1 ||
         cards.indexOf("TR.d2.state.showSources", b) > cards.indexOf("function provNoteHtml"),
    "the badge does not read the toggle");
});

run("P3: a derived figure carries its derivation into exports", () => {
  const { TR } = cardsSandbox([DERIVED, ASKED, SILENT], { showSources: false });
  // Independent of the toggle: an export is where a derived number is most
  // likely to be misread, with nobody there to explain it.
  eq(TR.cards2._provNoteText("Elec_Spend"),
    "Derived: mean monthly spend among buyers · electricity amount question",
    "one line, for the card SVG meta and the PPTX kicker");
  eq(TR.cards2._provNoteText("Age"), "", "an asked question adds nothing to an export");
  eq(TR.cards2._provNoteText("Gender"), "", "undeclared adds nothing");
  const exp = readFileSync(path.join(JS_DIR, "29_export.js"), "utf8");
  const svg = at(exp, "TR.cards2._provNoteText(model.code)", "card SVG meta carries it");
  assert(exp.indexOf("TR.cards2._provNoteText(model.code)", svg + 1) !== -1,
    "PPTX slide kicker carries it too");
});

run("P2: analyst text is escaped, never injected", () => {
  const { TR } = cardsSandbox([{
    code: "X", source: 'spend & "value"', formula: "<b>a</b> / b"
  }], { showSources: true });
  const note = TR.cards2._provNoteHtml("X");
  assert(note.indexOf("<b>a</b>") === -1, "markup in a config cell must not reach the page");
  assert(note.indexOf("&lt;b&gt;a&lt;/b&gt;") !== -1, "escaped instead");
  assert(note.indexOf("&amp;") !== -1, "ampersand escaped");
});

/* ---------------- P4: wiring ---------------- */

run("P4: badge and note sit in the question head", () => {
  const src = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  at(src, 'provBadgeHtml(model.code) + sourceBadge', "badge beside the question code");
  at(src, "audienceHtml(model) + provNoteHtml(model.code)",
    "note under the audience line, who was asked, then what the figure is");
  assert(/\.badge-prov\s*\{/.test(CSS), ".badge-prov styled");
  assert(/\.badge-prov\.derived\s*\{/.test(CSS), "derived badge is distinguished");
  assert(/\.provnote\s*\{/.test(CSS), ".provnote styled");
});

run("P4: the Sources toggle appears ONLY when the report carries provenance", () => {
  let TR = cardsSandbox([SILENT]).TR;
  eq(TR.cards2._hasProvenance(), false, "no study declares -> no control");
  TR = cardsSandbox([SILENT, DERIVED]).TR;
  eq(TR.cards2._hasProvenance(), true, "one declaration is enough to offer it");
  const src = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  at(src, 'hasProvenance()\n        ? toggle("showSources", "Sources"',
    "the control bar is gated on it");
});

run("P4: the toggle round-trips through the hash", () => {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  load(sb, "00_namespace.js");
  load(sb, "01_format.js");
  load(sb, "20_data.js");
  const { TR } = sb;
  eq(TR.d2.state.showSources, true, "on by default");
  // Only the OFF state travels, so an ordinary link is not lengthened by a
  // setting that is already the default.
  assert(TR.d2.encodeHash().indexOf("src=") === -1, "default state adds nothing to the link");
  TR.d2.state.showSources = false;
  assert(TR.d2.encodeHash().indexOf("src=0") !== -1, "turning it off is encoded");
  TR.d2.decodeHash("#tab=crosstabs&src=0");
  eq(TR.d2.state.showSources, false, "decoded back, so a shared link keeps it off");
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
