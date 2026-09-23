#!/usr/bin/env node
/**
 * Links from the narrative (stage 3 of STORY_EXPLORE_AND_RETURN_BRIEF.md,
 * item 3). In Word the author selects words, presses Ctrl+K and types
 * turas:Q12; the R reader keeps that as link = "Q12" on the words' runs.
 * Contracts:
 *
 * L1 Every narrative surface (Report tab card, cover, story card, Present)
 *    shows the words as a link, and the page stays self-contained: the href is
 *    the report's own route (#tab=crosstabs&q=Q12), never "turas:" and never
 *    an external address. A code the report does not carry is plain words.
 * L2 A click opens the question in the crosstabs under a return point to
 *    where the reader was, from each surface, and Back restores the view
 *    whole. The reader's own banner and filters are kept for the detour.
 * L3 Both decks show the words as plain text: the slides built from an
 *    island with links are byte-identical to those built without them.
 *
 * The fixture is the R reader's REAL output for narrative_fixture.docx
 * (fixtures/narrative_island.json): "Ratings" links Q1, "reminders" Q2 and
 * "between lists" Q999, a code no report carries.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/narrative_links_tests.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { installText } from "./_text.mjs";

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
  if (String(hay).indexOf(needle) === -1) {
    throw new Error(msg + ": missing " + JSON.stringify(needle));
  }
}
function absent(hay, needle, msg) {
  if (String(hay).indexOf(needle) !== -1) throw new Error(msg + ": " + JSON.stringify(needle));
}
const clone = (o) => JSON.parse(JSON.stringify(o));
const xmlOf = (s) => (typeof s === "string" ? s : s.xml);

const LINK_Q1 = '<a class="nar-link" href="#tab=crosstabs&amp;q=Q1" data-nar-link="Q1">Ratings</a>';
const LINK_Q2 = '<a class="nar-link" href="#tab=crosstabs&amp;q=Q2" data-nar-link="Q2">reminders</a>';

// A turas: address (turas:Q12): the scheme with something after it, so a
// "Turas: " log prefix is not one
const ADDRESS = /turas:(?!\s)/i;

/** The page stays self-contained: no turas: address anywhere, and every
 *  href or src is in-page (#...) or embedded (data:). */
function selfContained(html, where) {
  assert(!ADDRESS.test(html), where + ": a turas: address reached the page");
  const refs = [];
  html.replace(/\b(href|src|action|formaction)\s*=\s*"([^"]*)"/gi, (m, attr, v) => {
    refs.push(attr + "=" + v);
    return m;
  });
  refs.forEach((r) => {
    const v = r.slice(r.indexOf("=") + 1);
    assert(v.charAt(0) === "#" || /^data:/i.test(v), where + ": not in-page: " + r);
  });
  return refs;
}

/** Links a surface draws: data-nar-link values in order. */
const linksIn = (html) => (String(html).match(/data-nar-link="[^"]*"/g) || [])
  .map((s) => s.slice(15, -1));

/* ---------------- sandbox 1: the surfaces ----------------------------------- */

function surfaces(opts) {
  opts = opts || {};
  const store = {};
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
    "14_pptx_parts.js", "21_stats.js", "23_render.js", "23z_charts.js", "23za_trend.js",
    "23y_xlsx.js", "29_export.js"]) load(sb, f);
  installText(sb);
  const TR = sb.TR;
  const project = { name: "SACS 2026", client: "SACS", wave: "2026", cover: true,
    narrative: "narrative" in opts ? opts.narrative : clone(FIX.word) };
  const questions = opts.questions ||
    [{ code: "Q1", title: "Ratings" }, { code: "Q2", title: "Reminders" }];
  TR.AGG = { project, questions, banner_groups: [] };
  TR.userState = null;
  TR.d2 = {
    storeKey: (b) => b + ":proj",
    state: { tab: "report", banner: "", filters: [], sorts: {}, hiddenRows: {},
      hiddenChartRows: {}, sigMode: "95", showIntervals: false, showCounts: false,
      activeQ: null },
    questionByCode: (c) => questions.find((q) => q.code === c) || null,
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
  load(sb, "24a_reader.js");
  load(sb, "24b_narrative.js");
  load(sb, "28_insights.js");
  load(sb, "32_report.js");
  load(sb, "30_story.js");
  sb.overlay = overlay;
  return sb;
}

const narPin = (screen) => ({ kind: "narrative", screen, title: "", note: "" });

function presentOf(sb, it) {
  sb.TR.story2.items().length = 0;
  sb.TR.story2.items().push(it);
  sb.TR.story2._topAction("present");
  return sb.overlay.innerHTML;
}

console.log("Narrative links (turas:Q12 in Word -> an in-page link with a way back): suite:");

/* ---------------- L1: every surface, self-contained ------------------------- */

run("L1: a linked run renders as an in-page route to its question, escaped", () => {
  const TR = surfaces({}).TR;
  const html = TR.narrative.blocksHtml(TR.narrative.byId("executive-summary").blocks);
  at(html, "<p>" + LINK_Q1 + " are stable.</p>", "the link wraps only its words");
  const bg = TR.narrative.blocksHtml(TR.narrative.byId("background-method").blocks);
  at(bg, "<li>Two " + LINK_Q2 + "</li>", "a link in a list item");
  eq(linksIn(bg), ["Q2"], "one link on the Background screen");
});

run("L1: a code the report does not carry is plain words (the JS repeats R's check)", () => {
  const TR = surfaces({}).TR;
  const bg = TR.narrative.blocksHtml(TR.narrative.byId("background-method").blocks);
  at(bg, "<p>A paragraph between lists.</p>", "Q999 is not a question: plain text");
  // and a report whose questions no longer include Q1 shows its words plain
  const none = surfaces({ questions: [] }).TR;
  const ex = none.narrative.blocksHtml(none.narrative.byId("executive-summary").blocks);
  at(ex, "<p>Ratings are stable.</p>", "no questions, no links");
  eq(linksIn(ex), [], "no link at all");
});

run("L1: a hostile code is escaped, and a link keeps the run's own marks inside it", () => {
  const code = 'Q"1<x>';
  const sb = surfaces({ questions: [{ code, title: "odd" }], narrative: [{
    id: "s", title: "S", blocks: [{ type: "paragraph", runs: [
      { text: "a<b", bold: true, italic: false, colour: true, link: code }] }] }] });
  const html = sb.TR.narrative.blocksHtml(sb.TR.narrative.byId("s").blocks);
  eq(html, '<p><a class="nar-link" href="#tab=crosstabs&amp;q=Q%221%3Cx%3E" ' +
    'data-nar-link="Q&quot;1&lt;x&gt;"><span class="nar-em"><strong>a&lt;b</strong>' +
    "</span></a></p>", "escaped, and the route URI-encoded");
  selfContained(html, "hostile code");
});

run("L1: nothing the report ships (JS, CSS, template) holds a turas: address", () => {
  const ASSETS = path.join(HERE, "..", "assets");
  const files = readdirSync(JS_DIR).filter((f) => f.endsWith(".js"))
    .map((f) => path.join(JS_DIR, f))
    .concat([path.join(ASSETS, "styles.css"), path.join(ASSETS, "template.html")]);
  assert(files.length > 30, "the asset list was found");
  files.forEach((f) => assert(!ADDRESS.test(readFileSync(f, "utf8")),
    path.basename(f) + " contains a turas: address"));
});

run("L1: the Report tab cards carry the links, self-contained", () => {
  const h = surfaces({}).TR.report.sectionsHtml();
  eq(linksIn(h), ["Q2", "Q1"], "Background then Executive summary");
  at(h, LINK_Q1, "the executive summary link");
  selfContained(h, "Report tab");
});

run("L1: the cover carries the cover screen's link, self-contained", () => {
  const h = surfaces({}).TR.reader.coverHtml();
  at(h, LINK_Q1, "the executive summary link on the cover");
  selfContained(h, "cover");
});

run("L1: the story card carries the links, self-contained", () => {
  const TR = surfaces({}).TR;
  const h = TR.story2.itemBodyHtml(narPin("background-method")) +
    TR.story2.itemBodyHtml(narPin("executive-summary"));
  eq(linksIn(h), ["Q2", "Q1"], "both screens' links");
  selfContained(h, "story card");
});

run("L1: Present carries the links, self-contained", () => {
  const sb = surfaces({});
  const h = presentOf(sb, narPin("executive-summary"));
  at(h, LINK_Q1, "the link on the narrative slide");
  selfContained(h, "Present");
  const bg = presentOf(sb, narPin("background-method"));
  eq(linksIn(bg), ["Q2"], "the Background slide's link");
  selfContained(bg, "Present, Background");
});

/* ---------------- L3: the decks are plain text ------------------------------ */

/** The island with every link removed: what the deck must equal. */
function stripLinks(screens) {
  const s = clone(screens);
  s.forEach((sc) => sc.blocks.forEach((b) => {
    (b.runs || []).forEach((r) => { delete r.link; });
    (b.items || []).forEach((it) => (it.runs || []).forEach((r) => { delete r.link; }));
  }));
  return s;
}

run("L3: the editable deck is byte-identical with and without links", () => {
  const deck = (narrative) => {
    const sb = surfaces({ narrative });
    const TR = sb.TR;
    TR.story2.items().length = 0;
    ["background-method", "executive-summary", "executive-summary-2"].forEach((id) =>
      TR.story2.pinNarrative(id, id));
    TR.story2.items().push({ kind: "divider", title: "Next", note: "" });
    const slides = TR.story2._slidesFor(TR.story2.items());
    return { xml: slides.map(xmlOf), pkg: Buffer.from(TR.pptx.package(slides,
      { project: TR.AGG.project })) };
  };
  const linked = deck(clone(FIX.word)), plain = deck(stripLinks(FIX.word));
  eq(linked.xml.length, plain.xml.length, "the same slides");
  linked.xml.forEach((x, i) => {
    assert(x === plain.xml[i], "slide " + (i + 1) + " differs");
    absent(x, "turas:", "slide " + (i + 1));
    absent(x, "nar-link", "slide " + (i + 1));
  });
  at(linked.xml.join(""), "<a:t>Ratings</a:t>", "the linked words are kept");
  assert(linked.pkg.equals(plain.pkg), "the packaged .pptx is byte-identical");
});

run("L3: the image deck cards and the plain-text projection carry no link", () => {
  const withLinks = surfaces({}).TR, without = surfaces({ narrative: stripLinks(FIX.word) }).TR;
  const items = [narPin("background-method"), narPin("executive-summary")];
  eq(withLinks.story2._imageCards(items), without.story2._imageCards(items), "image cards");
  const ex = withLinks.narrative.byId("executive-summary").blocks;
  eq(withLinks.narrative.blocksText(ex),
    without.narrative.blocksText(without.narrative.byId("executive-summary").blocks),
    "blocksText");
  eq(withLinks.narrative.coverLines(ex, 2)[0], "Ratings are stable.", "the deck cover's line");
});

/* ---------------- sandbox 2: the detour, over the real shell ----------------- */

function el(id) {
  const listeners = {};
  return {
    id, hidden: false, innerHTML: "", style: {}, children: [], listeners,
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    removeEventListener(type, fn) {
      listeners[type] = (listeners[type] || []).filter((f) => f !== fn);
    },
    querySelector: (sel) => (sel === "#pr-close" ? { addEventListener: () => {} } : null),
    querySelectorAll: () => [],
    replaceChildren(...c) { this.children = c; },
    setAttribute() {}, getAttribute: () => null
  };
}

const CHAIN = ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js",
  "22_model.js", "23_render.js", "23z_charts.js", "23za_trend.js"];

function detour(opts) {
  opts = opts || {};
  const store = {};
  const nodes = {};
  ["present-overlay", "returnbar", "tabhost", "filterbar", "story-count"].forEach((id) => {
    nodes[id] = el(id);
  });
  nodes["present-overlay"].hidden = true;
  nodes.returnbar.hidden = true;
  const docListeners = {};
  const calls = [];
  const sb = { console, TextEncoder, atob, scrollY: 0, scrollTo: () => {},
    history: { replaceState: () => {} },
    localStorage: {
      getItem: (k) => (k in store ? store[k] : null),
      setItem: (k, v) => { store[k] = String(v); },
      removeItem: (k) => { delete store[k]; }
    },
    document: {
      getElementById: (id) => nodes[id] || null,
      createElement: () => el(null),
      querySelectorAll: () => [],
      addEventListener: (type, fn) => {
        (docListeners[type] = docListeners[type] || []).push(fn);
      },
      removeEventListener: (type, fn) => {
        docListeners[type] = (docListeners[type] || []).filter((f) => f !== fn);
      }
    } };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  installText(sb);
  for (const f of CHAIN) load(sb, f);
  const TR = sb.TR;
  const base = (n) => ({ n, nWeighted: n, nEff: n, low: false });
  const q = (code, title) => ({ code, title, type: "single", category: "X",
    bases: [base(200), base(120), base(80)],
    rows: [{ kind: "category", label: "Yes", pct: [70, 68, 73], n: [140, 82, 58],
      sig: ["", "", ""] }, { kind: "category", label: "No", pct: [30, 32, 27],
      n: [60, 38, 22], sig: ["", "", ""] }] });
  TR.PREV = null; TR.userState = null; TR.MICRO = null;
  TR.AGG = {
    project: { name: "Links", low_base_threshold: 30, min_reporting_base: 10, tabs: {},
      narrative: clone(FIX.word) },
    banner_groups: [{ id: "Region", name: "Region" }],
    columns: [{ label: "Total", letter: "", group: null },
      { label: "North", letter: "A", group: "Region" },
      { label: "South", letter: "B", group: "Region" }],
    questions: [q("Q1", "Ratings"), q("Q2", "Reminders")]
  };
  TR.userState = { story: [{ kind: "divider", title: "One", note: "" },
    narPin("executive-summary"), { kind: "divider", title: "Three", note: "" }] };
  TR.d2._qIndex = null;
  TR.waves.reset();
  load(sb, "24_shell.js");
  const rec = (name) => () => { calls.push(name); };
  TR.filterBar = { render: rec("filterBar") };
  TR.cards2 = { renderTab: rec("crosstabs"),
    chartState: () => ({ type: "bar", kind: "detail", cols: [0] }) };
  TR.views = { dashboard: rec("dashboard") };
  TR.report = { renderTab: rec("report") };
  TR.reader = { renderCover: rec("cover"), renderStrip: () => {},
    coverAvailable: () => true };
  TR.insights = { get: () => "" };
  load(sb, "24b_narrative.js");
  load(sb, "30_story.js");
  TR.narrative.wireLinks(sb.document);
  // the reader's own view
  TR.d2.state.banner = "Region";
  TR.d2.state.activeQ = "Q2";
  TR.d2.state.filters = [{ q: "Q2", box: false, rows: [0] }];
  TR.d2.state.showIntervals = true;
  return { sb, TR, nodes, calls, docListeners };
}

const go = (w, tab) => { w.TR.d2.state.tab = tab; w.TR.shell.route(); };
/** A click on a rendered link to `code`, as the browser delivers it. */
function clickLink(w, code, mods) {
  const target = { closest: (sel) => (sel === "[data-nar-link]"
    ? { getAttribute: (a) => (a === "data-nar-link" ? code : null) } : null) };
  let prevented = false;
  const e = Object.assign({ target, button: 0, preventDefault() { prevented = true; } },
    mods || {});
  (w.docListeners.click || []).forEach((fn) => fn(e));
  return prevented;
}
const stateOf = (w) => clone(w.TR.d2.state);

run("L2: the shell wires the one delegated listener", () => {
  at(SHELL_SRC, "TR.narrative.wireLinks(document)", "wireTopLevel installs it");
});

for (const origin of ["report", "cover", "story"]) {
  run("L2: from the " + origin + " tab, a link opens the question and Back restores the view", () => {
    const w = detour();
    go(w, origin);
    const before = stateOf(w);
    assert(clickLink(w, "Q1"), "the click is taken over, so the href never navigates");
    const s = w.TR.d2.state;
    eq([s.tab, s.activeQ], ["crosstabs", "Q1"], "the question in the crosstabs");
    eq([s.banner, s.filters, s.showIntervals], [before.banner, before.filters, true],
      "the reader's own banner, filters and toggles");
    eq(w.TR.shell.returnPoint.current(),
      origin === "story" ? { kind: "story", at: null } : { kind: origin }, "the origin");
    assert(!w.nodes.returnbar.hidden, "the bar shows");
    // wander, then come back
    w.TR.d2.state.banner = "";
    w.TR.d2.state.filters = [];
    w.TR.shell.returnPoint.back();
    eq(stateOf(w), before, "Back restores the whole state");
    eq(w.TR.shell.returnPoint.current(), null, "the return point is spent");
  });
}

run("L2: from Present, a link leaves the slide under a return point; Back reopens it", () => {
  const w = detour();
  go(w, "story");
  w.TR.story2.presentFrom(1);
  const overlay = w.nodes["present-overlay"];
  assert(!overlay.hidden, "Present is open");
  at(overlay.innerHTML, LINK_Q1, "the slide shows the link");
  eq(w.TR.d2.state.slide, 2, "at slide 2");
  const before = stateOf(w);
  assert(clickLink(w, "Q1"), "taken over");
  assert(overlay.hidden, "Present closed for the detour");
  eq([w.TR.d2.state.tab, w.TR.d2.state.activeQ], ["crosstabs", "Q1"], "the question");
  eq(w.TR.shell.returnPoint.current(), { kind: "present", at: 1 }, "back to slide 2");
  w.TR.shell.returnPoint.back();
  assert(!overlay.hidden, "Present reopens");
  eq(w.TR.d2.state.slide, 2, "at the same slide");
  eq([w.TR.d2.state.banner, w.TR.d2.state.filters, w.TR.d2.state.activeQ],
    [before.banner, before.filters, before.activeQ], "the reader's view restored");
});

run("L2: a second link while a return point is open keeps the first origin", () => {
  const w = detour();
  go(w, "cover");
  clickLink(w, "Q1");
  go(w, "report");            // wandering, with the bar up
  clickLink(w, "Q2");
  eq(w.TR.d2.state.activeQ, "Q2", "the second link still opens its question");
  eq(w.TR.shell.returnPoint.current(), { kind: "cover" }, "Back still goes to the cover");
});

run("L2: an unknown code, a modifier click or a click elsewhere does nothing", () => {
  const w = detour();
  go(w, "report");
  const before = stateOf(w);
  // never rendered as a link; a crafted one is taken over and goes nowhere
  clickLink(w, "Q999");
  eq(stateOf(w), before, "an unknown code changes nothing");
  eq(w.TR.shell.returnPoint.current(), null, "and opens no return point");
  assert(!clickLink(w, "Q1", { metaKey: true }), "a cmd-click is the browser's");
  assert(!clickLink(w, "Q1", { button: 1 }), "a middle click is the browser's");
  eq(stateOf(w), before, "nothing changed");
  const plain = { closest: () => null };
  (w.docListeners.click || []).forEach((fn) => fn({ target: plain, button: 0,
    preventDefault() { throw new Error("a click off a link was taken over"); } }));
  eq(w.TR.narrative.follow("Q999"), false, "follow refuses an unknown code");
});

console.log((failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
