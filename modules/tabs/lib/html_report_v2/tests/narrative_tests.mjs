#!/usr/bin/env node
/**
 * Narrative screens (stage 2 of NARRATIVE_SCREENS_BRIEF.md). project.narrative
 * is the report's Background, Executive summary and any other summary screen,
 * read from a Word document or the Comments sheet by the R build. Contracts:
 *
 * N1 One renderer: TR.narrative.blocksHtml turns every honoured block kind into
 *    HTML, escaped, with run bold/italic kept and Word's flat list levels
 *    nested properly. The fixture is the R reader's REAL output for the stage 1
 *    fixture document, so the two sides cannot drift apart unnoticed.
 * N2 The Report tab shows one pinnable card per screen, in document order, and
 *    the pin is a reference (the screen id), never a frozen copy.
 * N3 A pinned screen is a story item of kind "narrative": it renders the
 *    CURRENT screen on the story card and in Present, and a screen that is gone
 *    shows the authored "unavailable" note everywhere, never a crash.
 * N4 The deck never drops a narrative pin (a plain bridge slide until stage 3
 *    adds a text-and-bullets slide), and the deck cover's summary text comes
 *    from the cover screen (coverScreen) through the same blocks.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/narrative_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { TXT, installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const SHELL_SRC = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
const FIX = JSON.parse(readFileSync(path.join(HERE, "fixtures", "narrative_island.json"), "utf8"));
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
const clone = (o) => JSON.parse(JSON.stringify(o));
const xmlOf = (s) => (typeof s === "string" ? s : s.xml);
const run1 = (text, bold, italic) => ({ text, bold: !!bold, italic: !!italic });
const item = (level, ordered, text) => ({ level, ordered, runs: [run1(text)] });

/* ---------------- sandbox: narrative + report + story over the real deck ---- */

function sandbox(opts) {
  opts = opts || {};
  const store = {};
  // Present wires one delegated click listener on the overlay (the live strip)
  const overlay = { hidden: true, innerHTML: "", addEventListener: () => {},
    querySelector: () => ({ addEventListener: () => {} }) };
  const sb = { console, TextEncoder, atob,
    localStorage: {
      getItem: (k) => (k in store ? store[k] : null),
      setItem: (k, v) => { store[k] = String(v); },
      removeItem: (k) => { delete store[k]; }
    },
    document: {
      getElementById: (id) => (id === "present-overlay" ? overlay : null),
      addEventListener: () => {}, removeEventListener: () => {}
    } };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  for (const f of ["00_namespace.js", "01_format.js", "03_svg.js", "13_zip.js",
    "14_pptx_parts.js", "23_render.js", "23z_charts.js", "23za_trend.js",
    "23y_xlsx.js", "29_export.js"]) load(sb, f);
  installText(sb);
  const TR = sb.TR;
  const project = { name: "SACS 2026", client: "SACS", wave: "2026" };
  if ("narrative" in opts) project.narrative = opts.narrative;
  else project.narrative = clone(FIX.word);
  TR.AGG = { project, questions: [], banner_groups: [] };
  TR.userState = opts.userState || null;
  TR.d2 = {
    storeKey: (b) => b + ":proj",
    state: { tab: "report", banner: "", filters: [], sorts: {}, hiddenRows: {},
      hiddenChartRows: {}, sigMode: "95", showIntervals: false, showCounts: false,
      activeQ: null },
    questionByCode: () => null,
    shortLabel: (q) => q.title || "",
    rowScope: () => "all", hiddenFor: () => [],
    bannerDescription: () => "All respondents",
    categories: () => [],
    tracking: () => ({ enabled: false }),
    qualitative: () => ({ enabled: false })
  };
  TR.shell = { toast: () => {} };
  TR.charts = Object.assign(TR.charts || {},
    { clip: (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + "…" : String(s)) });
  TR.model = { forQuestion: () => null };
  TR.exhibit = { titleFor: () => "EX", models: () => [], panelsHtml: () => "<div>EX</div>" };
  TR.cards2 = { chartState: () => ({ type: "bar", kind: "auto", cols: [0] }) };
  TR.ai = { execSummaryHtml: () => "", methodologyHtml: () => "" };
  load(sb, "24b_narrative.js");
  load(sb, "28_insights.js");
  load(sb, "32_report.js");
  load(sb, "30_story.js");
  sb.overlay = overlay;
  return sb;
}

/** The present-mode HTML for one story item (Present opens on item 0). */
function presentOf(sb, it) {
  sb.TR.story2.items().length = 0;
  sb.TR.story2.items().push(it);
  sb.TR.story2._topAction("present");
  return sb.overlay.innerHTML;
}

console.log("Narrative screens (project.narrative -> report, cover, story, deck): suite:");

/* ---------------- N1: one renderer ------------------------------------------ */

run("N1: the fixture screens resolve by id, in document order", () => {
  const TR = sandbox({}).TR;
  eq(TR.narrative.screens().map((s) => s.id),
    ["background-method", "executive-summary", "executive-summary-2"], "ids");
  eq(TR.narrative.coverScreen().id, "executive-summary",
    "the cover screen is the executive summary, not the first screen");
  eq(TR.narrative.byId("executive-summary-2").blocks.length, 1, "a repeat heading");
  eq(TR.narrative.byId("gone"), null, "an unknown id");
});

run("N1: no narrative on the island (or not an array) is no screens", () => {
  eq(sandbox({ narrative: undefined }).TR.narrative.screens(), [], "absent");
  eq(sandbox({ narrative: "x" }).TR.narrative.screens(), [], "malformed");
  eq(sandbox({ narrative: undefined }).TR.narrative.coverScreen(), null, "no cover screen");
});

run("N1: the cover screen is the first titled Executive summary, else the first", () => {
  const sc = (title) => ({ id: title, title, blocks: [] });
  const pick = (titles) => {
    const TR = sandbox({ narrative: titles.map(sc) }).TR;
    return TR.narrative.coverScreen().title;
  };
  // the SACS 2026 Word file's Heading 1 titles, in order
  eq(pick(["Background and method", "Executive summary : In a nutshell",
    "Executive summary", "Executive summary: the ratings", "Participation"]),
    "Executive summary : In a nutshell", "the first of several, whatever follows the words");
  eq(pick(["Background & method", "Executive summary"]), "Executive summary",
    "the Comments fallback leads with its executive summary");
  eq(pick(["background", "EXECUTIVE  SUMMARY."]), "EXECUTIVE  SUMMARY.",
    "case, spacing and punctuation are ignored");
  eq(pick(["Background", "Key findings"]), "Background",
    "no executive summary: the first screen, as the brief says");
  eq(pick(["Why an executive summary matters", "Executive summaryish"]),
    "Why an executive summary matters", "the words must lead the title, as whole words");
});

run("N1: paragraphs keep their bold and italic runs", () => {
  const TR = sandbox({}).TR;
  const h = TR.narrative.blocksHtml([FIX.word[0].blocks[0]]);
  eq(h, "<p>This study has <strong>136</strong> responses and <em>two</em> sections.</p>",
    "the first fixture paragraph");
  eq(TR.narrative.blocksHtml([{ type: "paragraph", runs: [run1("both", true, true)] }]),
    "<p><strong><em>both</em></strong></p>", "bold and italic together");
});

run("N1: every block kind from the Word fixture renders", () => {
  const TR = sandbox({}).TR;
  const bg = TR.narrative.blocksHtml(FIX.word[0].blocks);
  at(bg, '<h4 class="nar-sub">How we asked</h4>', "Heading 2 is a sub-heading");
  at(bg, "<ul><li>Online survey<ul><li>Invites by email</li></ul></li>" +
    "<li>Two reminders</li></ul>", "a level-1 item nests inside its parent");
  at(bg, '<ol><li value="1">First step</li><li value="2">Second step</li></ol>',
    "a numbered list, each item with the number Word shows");
  at(bg, '<table class="nar-table"><thead><tr><th>Group</th><th>n</th><th>%</th></tr></thead>' +
    "<tbody><tr><td>Staff</td><td>136</td><td>58% of invites</td></tr></tbody></table>",
    "a simple table, text cells by row, its first row the header row as on the deck");
  const ex = TR.narrative.blocksHtml(FIX.word[1].blocks);
  at(ex, '<blockquote class="nar-callout">&quot;Culture varies by campus.&quot;</blockquote>',
    "the Quote style is a callout band");
  at(ex, '<figure class="nar-fig"><img src="data:image/png;base64,', "the picture is embedded");
  at(ex, 'alt="Response chart" width="40" height="20">', "with its alt text and size");
  assert(at(ex, "<p>Text before.</p>", "text before") <
    ex.indexOf('<figure', ex.indexOf("<p>Text before.</p>")) &&
    ex.indexOf("<p>Text after.</p>") > ex.indexOf("<p>Text before.</p>"),
    "a picture sits where it sits in the text");
});

run("N1: list nesting survives level jumps and a change of list type", () => {
  const TR = sandbox({}).TR;
  eq(TR.narrative.blocksHtml([{ type: "list", items: [
    item(0, false, "a"), item(2, false, "b"), item(0, false, "c")] }]),
    "<ul><li>a<ul><li>b</li></ul></li><li>c</li></ul>",
    "a jump of two levels reads as one");
  eq(TR.narrative.blocksHtml([{ type: "list", items: [
    item(0, false, "a"), item(1, true, "b"), item(1, true, "c"), item(0, false, "d")] }]),
    '<ul><li>a<ol><li value="1">b</li><li value="2">c</li></ol></li><li>d</li></ul>',
    "a numbered list inside a bulleted one");
  eq(TR.narrative.blocksHtml([{ type: "list", items: [
    item(0, false, "a"), item(0, true, "b")] }]),
    '<ul><li>a</li></ul><ol><li value="1">b</li></ol>',
    "a change of type at the same level closes one list and opens the other");
  eq(TR.narrative.blocksHtml([{ type: "list", items: [
    item(0, false, "a"), item(1, false, "b"), item(2, false, "c"), item(0, false, "d")] }]),
    "<ul><li>a<ul><li>b<ul><li>c</li></ul></li></ul></li><li>d</li></ul>",
    "closing two levels at once");
});

run("N1: a numbered list keeps Word's numbers across an interrupting paragraph", () => {
  const TR = sandbox({}).TR;
  const num = (text, n) => Object.assign(item(0, true, text), { number: n });
  const html = TR.narrative.blocksHtml([
    { type: "list", items: [num("One", 1), num("Two", 2)] },
    { type: "paragraph", runs: [run1("An aside.")] },
    { type: "list", items: [num("Three", 3)] }]);
  at(html, '<ol><li value="3">Three</li></ol>', "the third item still reads 3");
  eq(TR.narrative.blocksText([{ type: "list", items: [num("Three", 3)] }]), "3. Three",
    "and so does its plain line");
});

run("N1: without Word's numbers, items are counted as the nested list reads", () => {
  const TR = sandbox({}).TR;
  // known answer: a(1) b(1, a new level) c(2) d(2, back to the outer list)
  // e (a bullet) f(1, the numbered list restarts after the change of type)
  eq(TR.narrative.listNumbers([item(0, true, "a"), item(1, true, "b"), item(1, true, "c"),
    item(0, true, "d"), item(0, false, "e"), item(0, true, "f")]),
    [1, 1, 2, 2, null, 1], "counted per level, restarting under a new parent");
  eq(TR.narrative.listNumbers([Object.assign(item(0, true, "x"), { number: 7 }),
    item(0, true, "y")]), [7, 8], "a given number is carried on from");
});

run("N1: every authored value is escaped and no markup is honoured", () => {
  const TR = sandbox({}).TR;
  const h = TR.narrative.blocksHtml([
    { type: "paragraph", runs: [run1("<b>x</b> & y")] },
    { type: "subheading", text: "<script>" },
    { type: "table", rows: [["<i>c</i>"]] }]);
  assert(h.indexOf("<b>") === -1 && h.indexOf("<script>") === -1 && h.indexOf("<i>") === -1,
    "no authored tag reaches the page");
  at(h, "&lt;b&gt;x&lt;/b&gt; &amp; y", "run text escaped");
});

run("N1: only an embedded picture renders; unknown kinds render nothing", () => {
  const TR = sandbox({}).TR;
  eq(TR.narrative.blocksHtml([{ type: "image", src: "https://example.com/a.png" }]), "",
    "a remote picture is never fetched by a client report");
  eq(TR.narrative.blocksHtml([{ type: "image", src: "data:text/html;base64,PGI+" }]), "",
    "a data URI that is not a picture");
  eq(TR.narrative.blocksHtml([{ type: "chart" }, null, "x"]), "", "unknown and malformed");
  eq(TR.narrative.blocksHtml(undefined), "", "no blocks at all");
});

run("N1: the Comments fallback shape renders as paragraphs and bullets", () => {
  const TR = sandbox({ narrative: clone(FIX.comments) }).TR;
  eq(TR.narrative.blocksHtml(TR.narrative.byId("background-method").blocks),
    "<p>Why we ran it.</p><ul><li>one</li><li>two</li></ul>", "background");
  eq(TR.narrative.blocksHtml(TR.narrative.byId("executive-summary").blocks),
    "<p>First.</p><p>Second.</p>", "one paragraph per line, as before");
});

run("N1: blocksText is the same blocks as plain lines", () => {
  const TR = sandbox({}).TR;
  const t = TR.narrative.blocksText(FIX.word[0].blocks).split("\n");
  eq(t[0], "This study has 136 responses and two sections.", "runs joined, no markup");
  assert(t.indexOf("How we asked") > 0, "the sub-heading is a line");
  assert(t.indexOf("• Invites by email") > 0, "a list item is a bullet line");
  assert(t.indexOf("2. Second step") > 0, "a numbered item keeps its number");
  assert(t.indexOf("Staff | 136 | 58% of invites") > 0, "a table row is its cells");
  assert(TR.narrative.blocksText(FIX.word[1].blocks).indexOf("data:image") === -1,
    "pictures carry no words");
});

run("N6: coloured words take the brand colour and highlighted words the accent tint", () => {
  const TR = sandbox({}).TR;
  const html = TR.narrative.blocksHtml([{ type: "paragraph", runs: [
    run1("Plain "), Object.assign(run1("<red>", true), { colour: true }),
    Object.assign(run1(" marked"), { highlight: true })] }]);
  eq(html, '<p>Plain <span class="nar-em"><strong>&lt;red&gt;</strong></span>' +
    '<mark class="nar-hl"> marked</mark></p>', "classes, never Word's colours, and escaped");
});

run("N6: Heading 3 is a smaller sub-heading", () => {
  const TR = sandbox({}).TR;
  eq(TR.narrative.blocksHtml([{ type: "subheading", text: "Big" },
    { type: "subheading", text: "Small", level: 3 }]),
    '<h4 class="nar-sub">Big</h4><h5 class="nar-sub nar-sub3">Small</h5>', "h4, then h5");
});

run("N6: letter and roman numbering (known answers)", () => {
  const TR = sandbox({}).TR;
  const lab = TR.narrative.numberLabel;
  eq([lab(1, "lowerLetter"), lab(26, "lowerLetter"), lab(27, "lowerLetter"),
    lab(28, "upperLetter")], ["a", "z", "aa", "AB"], "letters run a..z, aa, ab");
  eq([lab(4, "lowerRoman"), lab(9, "upperRoman"), lab(1994, "upperRoman"), lab(3, undefined)],
    ["iv", "IX", "MCMXCIV", "3"], "roman numerals, and digits with no format");
  const items = [Object.assign(item(0, true, "one"), { number: 1 }),
    Object.assign(item(1, true, "sub"), { number: 2, format: "lowerLetter" })];
  at(TR.narrative.blocksHtml([{ type: "list", items }]),
    '<ol type="a"><li value="2">sub</li></ol>', "the HTML list keeps Word's letters");
  eq(TR.narrative.blocksText([{ type: "list", items }]), "1. one\nb. sub", "and its lines");
});

run("N6: a wide picture stays in the words in Present; a small one goes beside", () => {
  const TR = sandbox({}).TR;
  const pic = FIX.word[1].blocks.find((b) => b.type === "image");
  const wide = Object.assign({}, pic, { wide: true });
  const html = TR.narrative.presentHtml({ id: "w", title: "W", blocks: [
    { type: "paragraph", runs: [run1("Before.")] }, wide,
    { type: "paragraph", runs: [run1("After.")] }] });
  at(html, '<div class="pr-narrative">', "no side column for a wide picture alone");
  assert(html.indexOf("Before.") < html.indexOf("nar-fig-wide") &&
    html.indexOf("nar-fig-wide") < html.indexOf("After."), "it sits where it sits in the text");
  const mixed = TR.narrative.presentHtml({ id: "m", title: "M", blocks: [wide, pic] });
  at(mixed, '<div class="pr-narrative has-pic">', "a small picture still gets the side column");
  eq((mixed.split('<div class="nar-pics">')[1].match(/<figure/g) || []).length, 1,
    "and only the small one is in it");
});

run("N1: Present lays a screen out as a slide", () => {
  const TR = sandbox({}).TR;
  const withPic = TR.narrative.presentHtml(TR.narrative.byId("executive-summary"));
  at(withPic, '<div class="pr-narrative has-pic">', "a screen with a picture is flagged");
  at(withPic, '<h1 class="nar-title">Executive summary</h1>', "the title");
  at(withPic, '<p class="nar-lead">Ratings are stable.</p>', "the first paragraph leads");
  const pics = at(withPic, '<div class="nar-pics">', "the pictures sit beside the text");
  assert(withPic.indexOf("<figure", 0) > pics, "and every picture is in that column");
  const long = TR.narrative.presentHtml({ id: "x", title: "Findings", blocks: [
    { type: "list", items: [1, 2, 3, 4, 5, 6, 7].map((n) => item(0, false, "f" + n)) }] });
  at(long, '<div class="pr-narrative long-list">', "a long list is flagged for two columns");
  assert(long.indexOf("nar-lead") === -1, "a list is never the lead");
  const short = TR.narrative.presentHtml({ id: "x", title: "T", blocks: [
    { type: "list", items: [item(0, false, "one")] }] });
  at(short, '<div class="pr-narrative">', "a short list stays one column");
});

/* ---------------- N2: the Report tab ---------------------------------------- */

run("N2: one pinnable card per screen, in document order, pinned by id", () => {
  const h = sandbox({}).TR.report.sectionsHtml();
  eq(h.split(" data-snap-card>").length - 1, 3, "three screens, three cards");
  const a = at(h, 'data-snap-narrative="background-method"', "first card pins by id");
  const b = at(h, 'data-snap-narrative="executive-summary"', "second");
  const c = at(h, 'data-snap-narrative="executive-summary-2"', "third");
  assert(a < b && b < c, "document order");
  at(h, 'data-snap-title="Background &amp; method"', "the title rides the pin, escaped");
  assert(h.indexOf("data-snap-source") === -1,
    "no snapshot source: a narrative pin is never a frozen copy");
  at(h, "<p>This study has <strong>136</strong>", "the body is the shared renderer's");
});

run("N2: an unauthored report still shows both config hints", () => {
  const h = sandbox({ narrative: undefined }).TR.report.sectionsHtml();
  eq(h.split('data-txt-key="report.section_unset"').length - 1, 2, "two hints");
  at(h, TXT("report.section_unset", { row: "_BACKGROUND" }), "the background row");
  at(h, TXT("report.section_unset", { row: "_EXECUTIVE_SUMMARY" }), "the exec row");
  assert(h.indexOf("data-snap-pin") === -1, "nothing to pin");
});

run("N2: the shell hands a narrative pin to story2.pinNarrative before any snapshot", () => {
  const ref = at(SHELL_SRC, 'var screenId = pin.getAttribute("data-snap-narrative");',
    "the shell reads the screen id");
  at(SHELL_SRC, "TR.story2.pinNarrative(screenId,", "and pins by reference");
  assert(ref < SHELL_SRC.indexOf("TR.story2.pinSnapshot({"),
    "the reference branch runs before the snapshot fallthrough");
});

/* ---------------- N3: the story item -------------------------------------- */

run("N3: pinNarrative stores the id and heading, never the words", () => {
  const TR = sandbox({}).TR;
  TR.story2.items().length = 0;   // past the screens-first seed
  TR.story2.pinNarrative("executive-summary", "Executive summary");
  const it = TR.story2.items()[0];
  eq(it, { kind: "narrative", screen: "executive-summary",
    heading: "Executive summary", note: "" }, "the stored item");
  TR.story2.pinNarrative("", "x");
  eq(TR.story2.items().length, 1, "an empty id pins nothing");
});

run("N3: the story card shows the CURRENT screen, so a regeneration refreshes it", () => {
  const sb = sandbox({});
  const it = { kind: "narrative", screen: "executive-summary", heading: "Old heading", note: "" };
  sb.TR.story2.items().push(it);
  let h = sb.TR.story2._itemHtml(it, 0);
  at(h, "1. SUMMARY</span><strong>Executive summary</strong>", "the live title leads");
  at(h, "<p>Ratings are stable.</p>", "the live words");
  // the report is rebuilt with new words under the same heading
  sb.TR.AGG.project.narrative[1].blocks = [{ type: "paragraph", runs: [run1("New wording.")] }];
  h = sb.TR.story2._itemHtml(it, 0);
  at(h, "<p>New wording.</p>", "the regenerated words, not a frozen copy");
  assert(h.indexOf("Ratings are stable.") === -1, "the old words are gone");
  at(sb.TR.story2.itemBodyHtml(it), "<p>New wording.</p>", "the body renderer agrees");
});

run("N3: a pinned screen follows its heading when sections are reordered", () => {
  const sb = sandbox({});
  sb.TR.AGG.project.narrative.reverse();
  eq(sb.TR.story2.pinTitle({ kind: "narrative", screen: "background-method" }),
    "Background & method", "resolved by id, not position");
});

run("N3: a screen that is gone shows the authored note everywhere, never a crash", () => {
  const sb = sandbox({});
  const it = { kind: "narrative", screen: "deleted-section", heading: "Old section", note: "n" };
  eq(sb.TR.story2.pinTitle(it), "Old section", "the pin keeps the heading it was pinned as");
  const card = sb.TR.story2._itemHtml(it, 0);
  at(card, 'data-txt-key="story.narrative_gone"', "the story card shows the note");
  at(card, TXT("story.narrative_gone"), "in the author's words");
  at(sb.TR.story2.itemBodyHtml(it), 'data-txt-key="story.narrative_gone"', "the body too");
  const pres = presentOf(sb, it);
  at(pres, "<h1>Old section</h1>", "Present names the missing screen");
  at(pres, 'data-txt-key="story.narrative_gone"', "and shows the note");
  eq(sb.TR.story2.pinTitle({ kind: "narrative", screen: "x" }), "Summary",
    "an old item with no heading still has a title");
});

run("N3: Present lays the pinned screen out as a slide, with its commentary", () => {
  const sb = sandbox({});
  const pres = presentOf(sb, { kind: "narrative", screen: "executive-summary",
    heading: "", note: "Say this <first>" });
  at(pres, '<div class="pr-narrative has-pic">', "the slide layout");
  at(pres, '<p class="nar-lead">Ratings are stable.</p>', "the lead");
  at(pres, '<div class="pr-note">Say this &lt;first&gt;</div>', "the commentary, escaped");
});

run("N3: a fresh story opens with the screens, which are never cover findings", () => {
  const sb = sandbox({});
  load(sb, "24a_reader.js");
  eq(sb.TR.story2.items().map((it) => it.kind + ":" + it.screen),
    ["narrative:background-method", "narrative:executive-summary",
      "narrative:executive-summary-2"], "one pin per screen, in document order");
  eq(sb.TR.story2.items()[0].heading, "Background & method", "the heading rides along");
  eq(sb.TR.reader.coverEvidence().length, 0, "the seeded screens are not findings");
  eq(sandbox({ narrative: undefined }).TR.story2.items().length, 0, "no screens, no seed");
});

run("N3: a narrative pin is not a leading finding on the cover", () => {
  const sb = sandbox({});
  load(sb, "24a_reader.js");
  sb.TR.story2.items().push({ kind: "narrative", screen: "executive-summary", note: "" });
  assert(sb.TR.reader.isCoverSectionPin(sb.TR.story2.items()[0]), "narrative is a section pin");
  assert(sb.TR.reader.isCoverSectionPin({ kind: "snapshot", source: "report" }),
    "a frozen section card from before still is too");
  assert(!sb.TR.reader.isCoverSectionPin({ kind: "snapshot", source: "patterns" }),
    "no other snapshot is");
  eq(sb.TR.reader.coverEvidence().length, 0, "nothing left as evidence");
});

/* ---------------- N4: the deck ---------------------------------------------- */

run("N4: every narrative pin gets its slides in both decks, gone or not", () => {
  const sb = sandbox({});
  const TR = sb.TR;
  TR.story2.items().length = 0;   // past the screens-first seed
  TR.story2.pinNarrative("background-method", "Background & method");
  TR.story2.pinNarrative("deleted-section", "Old section");
  const slides = TR.story2._slidesFor(TR.story2.items());
  const xmls = slides.map(xmlOf);
  const mine = xmls.slice(1, -1).join("");
  at(mine, "Background &amp; method", "the live title");
  at(mine, "<a:t>Staff</a:t>", "the screen's words, table included");
  const gone = xmls[xmls.length - 1];
  at(gone, "Old section", "a gone screen still gets its slide");
  const note = TXT("story.narrative_gone").replace(/<[^>]*>/g, "");
  at(gone, note.slice(0, 30).replace(/&/g, "&amp;"), "carrying the note");
  const cards = TR.story2._imageCards(TR.story2.items());
  eq(cards.length, 2, "the image deck has a card per pin");
  assert(cards.every((c) => typeof c === "string" && c.length > 0), "both cards render");
});

/* ---------------- N5: the narrative deck slide ------------------------------ */

const slidesOf = (sb, screen, opts) => sb.TR.exporter.narrativeSlides(screen, opts || {});
const allText = (slides) => slides.map(xmlOf).join("")
  .match(/<a:t>[^<]*<\/a:t>/g).map((t) => t.slice(5, -6));
const runWith = (xml, text) => {
  const m = new RegExp('<a:r><a:rPr ([^>]*)>(?:(?!</a:r>).)*<a:t>' + text + "</a:t></a:r>")
    .exec(xml);
  if (!m) throw new Error("no run for " + text);
  return m[1];
};

run("N5: runs keep their own bold and italic; the first paragraph leads", () => {
  const sb = sandbox({});
  const [s] = slidesOf(sb, sb.TR.narrative.byId("background-method"));
  const x = xmlOf(s);
  assert(/ b="1"/.test(runWith(x, "136")), "the bold run is bold");
  assert(/ i="1"/.test(runWith(x, "two")), "the italic run is italic");
  assert(!/ b="1"/.test(runWith(x, "This study has ")), "its neighbours are not");
  const lead = sb.TR.pptx.STYLE.SIZE.lead * 100, body = sb.TR.pptx.STYLE.SIZE.body * 100;
  assert(runWith(x, "136").indexOf('sz="' + lead + '"') >= 0, "the lead paragraph at lead size");
  assert(runWith(x, "See the Turas site for more.").indexOf('sz="' + body + '"') >= 0,
    "later paragraphs at body size");
  at(x, "Background &amp; method", "the screen title leads the slide");
});

run("N5: bullets keep their nesting and numbering; sub-headings are brand", () => {
  const sb = sandbox({});
  sb.TR.AGG.project.brand_colour = "#123ABC";
  const x = xmlOf(slidesOf(sb, sb.TR.narrative.byId("background-method"))[0]);
  const paraOf = (text) => {
    const i = at(x, "<a:t>" + text + "</a:t>", text);
    return x.slice(x.lastIndexOf("<a:p>", i), i);
  };
  at(paraOf("Online survey"), '<a:buChar char="•"/>', "a bullet");
  assert(paraOf("Online survey").indexOf("lvl=") === -1, "top level");
  at(paraOf("Invites by email"), 'lvl="1"', "the sub-bullet is nested");
  at(paraOf("First step"), '<a:buAutoNum type="arabicPeriod" startAt="1"/>',
    "a numbered list numbers, stating each item's number");
  at(paraOf("Second step"), 'startAt="2"', "the second item is 2");
  // the fixture links "between lists" (turas:Q999); the deck keeps the words
  at(paraOf("between lists"), "<a:buNone/>", "a paragraph has no bullet");
  const sub = runWith(x, "How we asked");
  assert(/ b="1"/.test(sub), "the sub-heading is bold");
});

run("N5: the Quote style is a gold band; a table is a native table", () => {
  const sb = sandbox({});
  const S = sb.TR.pptx.STYLE;
  const ex = xmlOf(slidesOf(sb, sb.TR.narrative.byId("executive-summary"))[0]);
  at(ex, 'val="' + S.CALLOUT_BG + '"', "the band fill");
  assert(/ b="1"/.test(runWith(ex, "&quot;Culture varies by campus.&quot;")),
    "the quote reads bold in the band");
  const bg = xmlOf(slidesOf(sb, sb.TR.narrative.byId("background-method"))[0]);
  const tbl = bg.slice(at(bg, "<a:tbl>", "a native table"), bg.indexOf("</a:tbl>"));
  ["Group", "n", "%", "Staff", "136", "58% of invites"].forEach((t) =>
    at(tbl, "<a:t>" + t + "</a:t>", "cell " + t));
});

run("N5: pictures go in the side column as real pictures, one rel each", () => {
  const sb = sandbox({});
  const slides = slidesOf(sb, sb.TR.narrative.byId("executive-summary"));
  eq(slides[0].images.length, 2, "both pictures on the first slide");
  at(slides[0].xml, 'r:embed="rId2"', "first picture");
  at(slides[0].xml, 'r:embed="rId3"', "second picture, its own rel");
  eq(slides[0].images[0].ext, "png", "the original format");
  assert(slides[0].images[0].bytes.length > 0, "the original bytes");
  const pkg = sb.TR.pptx.package(slides, { project: sb.TR.AGG.project });
  const txt = Buffer.from(pkg).toString("latin1");
  at(txt, "ppt/media/image1.png", "media part one");
  at(txt, "ppt/media/image2.png", "media part two");
  const none = slidesOf(sb, sb.TR.narrative.byId("background-method"));
  eq(none[0].images.length, 0, "no pictures, no media");
});

run("N5: the pin's commentary is the insight band, on the first slide only", () => {
  const sb = sandbox({});
  const slides = slidesOf(sb, longScreen(40), { note: "Say this <first>" });
  at(xmlOf(slides[0]), "Say this &lt;first&gt;", "the note, escaped");
  assert(slides.slice(1).every((s) => xmlOf(s).indexOf("Say this") === -1),
    "not repeated on continuation slides");
});

function longScreen(n) {
  const words = "a considered sentence about the findings that runs long enough to wrap ";
  return { id: "long", title: "Long", blocks: Array.from({ length: n }, (_, i) =>
    ({ type: "paragraph", runs: [run1("P" + i + " " + words.repeat(3))] })) };
}

run("N5: a long screen carries on over continuation slides and loses no words", () => {
  const sb = sandbox({});
  const slides = slidesOf(sb, longScreen(40));
  assert(slides.length > 1, "more than one slide, got " + slides.length);
  at(xmlOf(slides[1]), "Long (continued)", "a continuation slide says so");
  const texts = allText(slides);
  for (let i = 0; i < 40; i++) {
    eq(texts.filter((t) => t.indexOf("P" + i + " ") === 0).length, 1, "paragraph " + i + " once");
  }
  assert(slides.every((s) => xmlOf(s).indexOf(sb.TR.pptx.PAGE_TOKEN) >= 0),
    "every slide carries the footer page token");
});

run("N5: a long table breaks across slides, repeating its header row", () => {
  const sb = sandbox({});
  const rows = [["Group", "n"]].concat(Array.from({ length: 40 }, (_, i) => ["G" + i, String(i)]));
  const slides = slidesOf(sb, { id: "t", title: "T", blocks: [{ type: "table", rows }] });
  assert(slides.length > 1, "the table needed more than one slide");
  slides.forEach((s) => at(xmlOf(s), "<a:t>Group</a:t>", "the header row on every part"));
  const texts = allText(slides);
  for (let i = 0; i < 40; i++) eq(texts.filter((t) => t === "G" + i).length, 1, "row " + i + " once");
  const ragged = slidesOf(sb, { id: "r", title: "R", blocks: [{ type: "table",
    rows: [["a"], ["b", "c", "d"]] }] });
  at(xmlOf(ragged[0]), "<a:t>d</a:t>", "a ragged row keeps every cell");
});

run("N5: a long list reads in two columns, split at a top-level item", () => {
  const sb = sandbox({});
  const items = [item(0, false, "i1"), item(0, false, "i2"), item(0, false, "i3"),
    item(0, false, "i4"), item(1, false, "i4a"), item(1, false, "i4b"), item(0, false, "i5"),
    item(0, false, "i6")];
  const x = xmlOf(slidesOf(sb, { id: "l", title: "L", blocks: [{ type: "list", items }] })[0]);
  const boxes = x.split("<p:txBody>").slice(1).filter((b) => b.indexOf("<a:t>i") >= 0);
  eq(boxes.length, 2, "two column boxes");
  assert(boxes[0].indexOf("<a:t>i4b</a:t>") >= 0 && boxes[1].indexOf("<a:t>i5</a:t>") >= 0,
    "the sub-list stays with its parent in the first column");
  const withPic = sandbox({});
  const px = xmlOf(slidesOf(withPic, { id: "l", title: "L", blocks: [
    { type: "list", items }, FIX.word[1].blocks.find((b) => b.type === "image")] })[0]);
  eq(px.split("<p:txBody>").filter((b) => b.indexOf("<a:t>i") >= 0).length, 1,
    "beside a picture the list stays one column");
});

/** Every numbered paragraph's startAt on a slide, in order. */
const startsOf = (x) => [...x.matchAll(/<a:buAutoNum type="arabicPeriod" startAt="(\d+)"\/>/g)]
  .map((m) => Number(m[1]));

run("N5: a numbered list's second column carries on from the first", () => {
  const sb = sandbox({});
  const items = Array.from({ length: 10 }, (_, i) => item(0, true, "Rec " + (i + 1)));
  const x = xmlOf(slidesOf(sb, { id: "n", title: "N", blocks: [{ type: "list", items }] })[0]);
  const boxes = x.split("<p:txBody>").slice(1).filter((b) => b.indexOf("<a:t>Rec") >= 0);
  eq(boxes.length, 2, "two columns");
  eq(startsOf(boxes[0]), [1, 2, 3, 4, 5], "left column");
  eq(startsOf(boxes[1]), [6, 7, 8, 9, 10], "right column starts at 6, not 1");
});

run("N5: a numbered list carried onto a continued slide keeps its numbers", () => {
  const sb = sandbox({});
  const long = "A recommendation long enough to take a couple of lines on the slide, " +
    "so that forty of them cannot fit on one.";
  const items = Array.from({ length: 40 }, (_, i) =>
    Object.assign(item(0, true, "R" + (i + 1) + " " + long), { number: i + 1 }));
  const slides = slidesOf(sb, { id: "n", title: "N", blocks: [{ type: "list", items }] });
  assert(slides.length > 1, "the list needed more than one slide");
  eq(slides.map(xmlOf).flatMap(startsOf), Array.from({ length: 40 }, (_, i) => i + 1),
    "1 to 40 across the slides, never restarting");
  const second = xmlOf(slides[1]);
  const first = Number(/<a:t>R(\d+) /.exec(second)[1]);
  eq(startsOf(second)[0], first, "the continued slide opens on its own item's number");
});

run("N5: table rows are sized by their words (known answer)", () => {
  const rh = sandbox({}).TR.exporter._narTableRowHeights;
  // a short row is the 0.32in minimum
  eq(rh([["a", "b"]], 10, 9.5), [0.32], "a short row");
  // 200 characters in the second column: 10in wide, first column 2.8in, so the
  // column is 7.2in less 0.06in of margins = 7.14in = 514pt; at half of 9.5pt a
  // character that is 108 characters a line, so 2 lines of 9.5 * 1.25 / 72 in
  // plus 0.08in of padding
  const h = rh([["a", "x".repeat(200)]], 10, 9.5)[0];
  assert(Math.abs(h - (2 * 9.5 * 1.25 / 72 + 0.08)) < 1e-9, "two lines, got " + h);
});

run("N5: a table of sentences breaks before the bottom of the slide", () => {
  const sb = sandbox({});
  const BODY = sb.TR.pptx.STYLE.BODY, EMU = 914400;
  const sentence = "Satisfaction among recent graduates fell for the third wave running, " +
    "driven by slow support and repeated document rejections in the app. ";
  const rows = [["Theme", "What they said", "What to do"]].concat(Array.from({ length: 13 },
    (_, i) => ["Theme " + (i + 1), sentence + sentence, sentence + sentence]));
  const slides = slidesOf(sb, { id: "t", title: "T", blocks: [{ type: "table", rows }] });
  assert(slides.length >= 3, "13 rows of sentences need several slides, got " + slides.length);
  slides.map(xmlOf).forEach((x, k) => {
    const m = /<p:graphicFrame>[\s\S]*?<a:off x="\d+" y="(\d+)"\/><a:ext cx="\d+" cy="(\d+)"\/>/.exec(x);
    assert(m, "slide " + k + " has its table part");
    assert((Number(m[1]) + Number(m[2])) / EMU <= BODY.y + BODY.h + 1e-6,
      "slide " + k + ": the table ends inside the body");
  });
  const texts = allText(slides);
  for (let i = 1; i <= 13; i++) {
    eq(texts.filter((t) => t === "Theme " + i).length, 1, "row " + i + " once");
  }
});

run("N4: the deck cover quotes a screen's first words, not a heading or a table", () => {
  const TR = sandbox({}).TR;
  const lines = TR.narrative.coverLines([
    { type: "subheading", text: "In a nutshell" },
    { type: "table", rows: [["a", "b"]] },
    { type: "list", items: [item(0, false, "Stable ratings"),
      Object.assign(item(0, true, "Fix support"), { number: 1 }), item(0, false, "Third")] }], 2);
  eq(lines, ["• Stable ratings", "1. Fix support"], "the first two list lines");
  eq(TR.narrative.coverLines([], 2), [], "an empty screen gives nothing");
});

/** The whole <a:r> run on a slide that carries this text. */
const runXmlOf = (xml, text) => {
  const i = at(xml, "<a:t>" + text + "</a:t>", text);
  return xml.slice(xml.lastIndexOf("<a:r>", i), xml.indexOf("</a:r>", i) + 6);
};

run("N6: on the slide, coloured words are brand and highlighted words sit on the accent tint", () => {
  const sb = sandbox({});
  sb.TR.AGG.project.brand_colour = "#123ABC";
  sb.TR.AGG.project.accent_colour = "#CC9900";
  // known answer: 30% of the way from white to CC9900 is F0 E0 B3
  eq(sb.TR.exporter._narTint("#CC9900", 0.3), "F0E0B3", "the tint");
  const x = xmlOf(slidesOf(sb, { id: "c", title: "C", blocks: [{ type: "paragraph", runs: [
    run1("plain"), Object.assign(run1("brand"), { colour: true }),
    Object.assign(run1("marked"), { highlight: true })] }] })[0]);
  at(runXmlOf(x, "brand"), '<a:srgbClr val="123ABC"/>', "the coloured run is brand");
  assert(runXmlOf(x, "plain").indexOf("123ABC") === -1, "a plain run is not");
  at(runXmlOf(x, "marked"), '</a:solidFill><a:highlight><a:srgbClr val="F0E0B3"/></a:highlight><a:latin',
    "the highlight sits between the fill and the font, as the schema orders them");
});

run("N6: on the slide, Heading 3 is body size and letters are PowerPoint letters", () => {
  const sb = sandbox({});
  const x = xmlOf(slidesOf(sb, { id: "h", title: "H", blocks: [
    { type: "subheading", text: "Big" }, { type: "subheading", text: "Small", level: 3 },
    { type: "list", items: [Object.assign(item(0, true, "Alpha"), { number: 1, format: "upperLetter" }),
      Object.assign(item(0, true, "Beta"), { number: 2, format: "upperLetter" })] }] })[0]);
  at(runWith(x, "Big"), 'sz="' + sb.TR.pptx.STYLE.SIZE.lead * 100 + '"', "Heading 2 at the lead size");
  at(runWith(x, "Small"), 'sz="' + sb.TR.pptx.STYLE.SIZE.body * 100 + '"', "Heading 3 at body size");
  at(x, '<a:buAutoNum type="alphaUcPeriod" startAt="2"/>', "B., not 2.");
});

// a picture that "fills" a slide takes at least this share of the body height
const NAR_MIN_FILL = 0.6;
/** Every picture on a slide: its rId and box, in inches. */
const picsOf = (x) => [...x.matchAll(/<a:blip r:embed="(rId\d+)"\/>[\s\S]*?<a:off x="(\d+)" y="(\d+)"\/><a:ext cx="(\d+)" cy="(\d+)"\/>/g)]
  .map((m) => ({ rid: m[1], x: m[2] / 914400, y: m[3] / 914400, w: m[4] / 914400, h: m[5] / 914400 }));

run("N6: on the slide, a wide picture spans the words where it sits", () => {
  const sb = sandbox({});
  const BODY = sb.TR.pptx.STYLE.BODY;
  const pic = FIX.word[1].blocks.find((b) => b.type === "image");
  const line = { type: "paragraph", runs: [run1("One short line.")] };
  // a 4:1 banner: at the body's full width (12.13in) it is 3.03in tall, which
  // fits under one line of words in the 4.62in body
  const banner = Object.assign({}, pic, { wide: true, width: 1600, height: 400 });
  const slides = slidesOf(sb, { id: "w", title: "W", blocks: [line, banner] });
  eq(slides.length, 1, "room for it under one line of words");
  const p = picsOf(xmlOf(slides[0]));
  eq(p.length, 1, "one picture");
  eq(p[0].rid, "rId2", "the slide's first picture rel");
  assert(Math.abs(p[0].w - BODY.w) < 0.01, "full body width, got " + p[0].w);
  assert(Math.abs(p[0].h - BODY.w / 4) < 0.01, "shape kept, got " + p[0].h);
  assert(p[0].y > BODY.y, "below the words");
  eq(slides[0].images.length, 1, "its bytes ride on the slide");
  // a 2:1 picture at full width (6.07in) is taller than the room left, so it
  // takes all of that room, keeps its shape and is centred in the column
  const q = picsOf(xmlOf(slidesOf(sb, { id: "w", title: "W", blocks: [line,
    Object.assign({}, pic, { wide: true })] })[0]))[0];
  assert(Math.abs(q.y + q.h - (BODY.y + BODY.h)) < 0.01, "down to the body's foot");
  assert(Math.abs(q.w - 2 * q.h) < 0.01, "2:1 kept, got " + q.w + " x " + q.h);
  assert(Math.abs(q.x + q.w / 2 - (BODY.x + BODY.w / 2)) < 0.01, "centred");
});

run("N6: a wide picture after a full slide of words fills the next slide", () => {
  const sb = sandbox({});
  const BODY = sb.TR.pptx.STYLE.BODY;
  const pic = Object.assign({}, FIX.word[1].blocks.find((b) => b.type === "image"),
    { wide: true, width: 1600, height: 900 });
  const words = Array.from({ length: 11 }, (_, i) =>
    ({ type: "paragraph", runs: [run1("P" + i + " " + "word ".repeat(30))] }));
  const slides = slidesOf(sb, { id: "w", title: "W", blocks: words.concat([pic]) });
  const last = xmlOf(slides[slides.length - 1]);
  const p = picsOf(last);
  eq(p.length, 1, "the picture is on the last slide");
  assert(last.indexOf("<a:t>P") === -1, "on its own");
  assert(Math.abs(p[0].y - BODY.y) < 0.01, "from the top of the body");
  assert(p[0].h > NAR_MIN_FILL * BODY.h, "filling the body, got " + p[0].h);
  assert(p[0].y + p[0].h <= BODY.y + BODY.h + 1e-6, "and inside it");
  assert(slides.slice(0, -1).every((s) => picsOf(xmlOf(s)).length === 0),
    "no picture on the slides of words");
});

run("N6: a small and a wide picture each get their own rel, and the deck packages", () => {
  const sb = sandbox({});
  const pic = FIX.word[1].blocks.find((b) => b.type === "image");
  const slides = slidesOf(sb, { id: "m", title: "M", blocks: [
    { type: "paragraph", runs: [run1("Words.")] }, pic, Object.assign({}, pic, { wide: true })] });
  const p = picsOf(xmlOf(slides[0]));
  eq(p.map((q) => q.rid), ["rId2", "rId3"], "side picture first, then the wide one");
  eq(slides[0].images.length, 2, "both pictures' bytes");
  const bytes = sb.TR.pptx.package(slides, { project: sb.TR.AGG.project });
  assert(bytes && bytes.length > 0, "the deck packages");
});

run("N5: every run on a narrative slide is Arial", () => {
  const sb = sandbox({});
  const x = sb.TR.narrative.screens().map((sc) => slidesOf(sb, sc).map(xmlOf).join("")).join("");
  const faces = [...x.matchAll(/<a:latin typeface="([^"]*)"/g)].map((m) => m[1]);
  assert(faces.length && faces.every((f) => f === "Arial"), "Arial throughout");
});

run("N4: the deck cover quotes the first screen through the same blocks", () => {
  const sb = sandbox({});
  let spec = null;
  const real = sb.TR.exporter.coverSlide;
  sb.TR.exporter.coverSlide = (s) => { spec = s; return real(s); };
  sb.TR.story2._slidesFor([]);
  eq(spec.exec, sb.TR.narrative.coverLines(
    sb.TR.narrative.byId("executive-summary").blocks, 2).join("\n"),
    "the cover text is the cover screen's first two lines");
  eq(spec.exec, 'Ratings are stable.\n"Culture varies by campus."', "the first two lines");
  eq(spec.exec.split("\n")[0], "Ratings are stable.",
    "the executive summary, not the background");
  const none = sandbox({ narrative: undefined });
  let spec2 = null;
  none.TR.exporter.coverSlide = (s) => { spec2 = s; return ""; };
  none.TR.story2._slidesFor([]);
  eq(spec2.exec, "", "no narrative, no cover text");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
