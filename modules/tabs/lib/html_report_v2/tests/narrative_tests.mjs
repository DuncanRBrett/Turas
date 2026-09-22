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
  const overlay = { hidden: true, innerHTML: "",
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
  at(bg, "<ol><li>First step</li><li>Second step</li></ol>", "a numbered list");
  at(bg, '<table class="nar-table"><tbody><tr><td>Group</td><td>n</td><td>%</td></tr>' +
    "<tr><td>Staff</td><td>136</td><td>58% of invites</td></tr></tbody></table>",
    "a simple table, text cells by row");
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
    "<ul><li>a<ol><li>b</li><li>c</li></ol></li><li>d</li></ul>",
    "a numbered list inside a bulleted one");
  eq(TR.narrative.blocksHtml([{ type: "list", items: [
    item(0, false, "a"), item(0, true, "b")] }]),
    "<ul><li>a</li></ul><ol><li>b</li></ol>",
    "a change of type at the same level closes one list and opens the other");
  eq(TR.narrative.blocksHtml([{ type: "list", items: [
    item(0, false, "a"), item(1, false, "b"), item(2, false, "c"), item(0, false, "d")] }]),
    "<ul><li>a<ul><li>b<ul><li>c</li></ul></li></ul></li><li>d</li></ul>",
    "closing two levels at once");
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
  assert(t.indexOf("Staff | 136 | 58% of invites") > 0, "a table row is its cells");
  assert(TR.narrative.blocksText(FIX.word[1].blocks).indexOf("data:image") === -1,
    "pictures carry no words");
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
  at(paraOf("First step"), '<a:buAutoNum type="arabicPeriod"/>', "a numbered list numbers");
  at(paraOf("A paragraph between lists."), "<a:buNone/>", "a paragraph has no bullet");
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
  eq(spec.exec, sb.TR.narrative.blocksText(sb.TR.narrative.byId("executive-summary").blocks),
    "the cover text is blocksText of the cover screen");
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
