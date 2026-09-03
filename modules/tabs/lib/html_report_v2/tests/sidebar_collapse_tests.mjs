#!/usr/bin/env node
/**
 * Crosstabs sidebar. Collapse/expand all question groups.
 *
 * What this gates:
 *  1. Group collapse is STATE, not just a DOM class: the sidebar renders from
 *     TR.d2.state.collapsedCats, so a collapse survives leaving and re-entering
 *     the Crosstabs tab (it used to reset silently on every re-render).
 *  2. The one all-groups button: its label says what the next click does, so a
 *     part-collapsed sidebar collapses the rest rather than guessing.
 *  3. The active question opens its own group. A collapsed group hides its
 *     links outright, so the .on marking and scrollIntoView did nothing when
 *     prev/next stepped into one.
 *  4. Search shows matches inside collapsed groups (CSS override) without
 *     touching the reader's collapse state.
 *  5. Category titles are analyst-typed text: "constructor" / "__proto__" must
 *     not break the map, and quotes must not break the data-cat attribute.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/sidebar_collapse_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const CSS_PATH = path.join(HERE, "..", "assets", "styles.css");
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

/* ---------- sandbox: 20_data.js state + 25_cards.js sidebar ---------- */

function sandbox(questions) {
  const cv = { console };
  cv.globalThis = cv;
  cv.window = cv;
  cv.TR = {
    AGG: { questions: questions, project: {}, banner_groups: [] },
    PREV: null,
    fmt: {},
    charts: { clip: (s) => s }
  };
  vm.createContext(cv);
  load(cv, "01_format.js");     // real escapeHtml. Attribute escaping is under test
  load(cv, "20_data.js");       // real state + categories()
  load(cv, "25_cards.js");
  return cv;
}

const QS = [
  { code: "Q1", title: "Awareness", category: "Usage" },
  { code: "Q2", title: "Frequency", category: "Usage" },
  { code: "Q3", title: "Satisfaction", category: "Experience" }
];

console.log("Sidebar collapse/expand. Suite:");

/* ---------- 1. state-driven rendering ---------- */

run("a fresh report renders every group expanded", () => {
  const cv = sandbox(QS);
  const html = cv.TR.cards2._sidebarHtml();
  eq(html.indexOf("collapsed"), -1, "no group carries the collapsed class");
  assert(html.indexOf('data-cat="Usage"') !== -1, "group carries its title: " + html);
  assert(html.indexOf('data-cat="Experience"') !== -1, "second group carries its title");
});

run("a collapsed group re-renders collapsed (state, not DOM)", () => {
  const cv = sandbox(QS);
  const cards2 = cv.TR.cards2;
  cards2.setCat("Usage", true);
  const html = cards2._sidebarHtml();
  assert(html.indexOf('class="catgrp collapsed" data-cat="Usage"') !== -1,
    "Usage renders collapsed: " + html);
  assert(html.indexOf('class="catgrp" data-cat="Experience"') !== -1,
    "Experience stays expanded: " + html);
  // and a second render (what re-entering the tab does) keeps it
  assert(cards2._sidebarHtml().indexOf('class="catgrp collapsed" data-cat="Usage"') !== -1,
    "collapse survives a re-render");
});

run("setCat(false) expands again and drops the key", () => {
  const cv = sandbox(QS);
  const cards2 = cv.TR.cards2;
  cards2.setCat("Usage", true);
  cards2.setCat("Usage", false);
  assert(!cards2.catCollapsed("Usage"), "expanded");
  eq(Object.keys(cv.TR.d2.state.collapsedCats), [], "no stale key left behind");
});

/* ---------- 2. the all-groups button ---------- */

run("label says what the next click does", () => {
  const cv = sandbox(QS);
  const cards2 = cv.TR.cards2;
  eq(cards2.catsAllLabel(), "Collapse all", "all expanded");
  cards2.setCat("Usage", true);
  eq(cards2.catsAllLabel(), "Collapse all", "mixed state still collapses");
  cards2.setAllCats(true);
  eq(cards2.catsAllLabel(), "Expand all", "all collapsed");
  cards2.setAllCats(false);
  eq(cards2.catsAllLabel(), "Collapse all", "back to expanded");
});

run("the button renders with the label the state calls for", () => {
  const cv = sandbox(QS);
  const cards2 = cv.TR.cards2;
  assert(cards2._catsAllHtml().indexOf(">Collapse all<") !== -1,
    "expanded sidebar offers Collapse all: " + cards2._catsAllHtml());
  cards2.setAllCats(true);
  assert(cards2._catsAllHtml().indexOf(">Expand all<") !== -1,
    "collapsed sidebar offers Expand all: " + cards2._catsAllHtml());
});

run("setAllCats covers every group", () => {
  const cv = sandbox(QS);
  const cards2 = cv.TR.cards2;
  cards2.setAllCats(true);
  assert(cards2.catCollapsed("Usage") && cards2.catCollapsed("Experience"),
    "both groups collapsed");
  assert(cards2.allCatsCollapsed(), "allCatsCollapsed true");
  const html = cards2._sidebarHtml();
  eq(html.split("catgrp collapsed").length - 1, 2, "both render collapsed");
});

run("a report with no questions does not claim to be collapsed", () => {
  const cv = sandbox([]);
  const cards2 = cv.TR.cards2;
  assert(!cards2.allCatsCollapsed(), "no groups => not all-collapsed");
  eq(cards2.catsAllLabel(), "Collapse all", "label stays sane");
  eq(cards2._sidebarHtml(), "", "empty sidebar");
  eq(cards2._catsAllHtml(), "", "no button over an empty list");
});

/* ---------- 3. syncCats pushes state onto a rendered sidebar ---------- */

function fakeSidebar(cv, titles) {
  const groups = titles.map((t) => {
    const g = {
      cat: t,
      collapsed: false,
      getAttribute: (k) => (k === "data-cat" ? t : null)
    };
    g.classList = { toggle: (cls, on) => { if (cls === "collapsed") g.collapsed = on; } };
    return g;
  });
  const button = { textContent: "" };
  cv.document = {
    querySelectorAll: (sel) => (sel.indexOf(".catgrp") !== -1 ? groups : []),
    querySelector: (sel) => (sel.indexOf("data-catsall") !== -1 ? button : null)
  };
  return { groups, button };
}

run("syncCats applies the state to the rendered groups and the button", () => {
  const cv = sandbox(QS);
  const cards2 = cv.TR.cards2;
  const dom = fakeSidebar(cv, ["Usage", "Experience"]);
  cards2.setAllCats(true);
  cards2._syncCats();
  eq(dom.groups.map((g) => g.collapsed), [true, true], "both groups collapsed in the DOM");
  eq(dom.button.textContent, "Expand all", "button label refreshed");

  cards2.setCat("Usage", false);
  cards2._syncCats();
  eq(dom.groups.map((g) => g.collapsed), [false, true], "only Usage reopened");
  eq(dom.button.textContent, "Collapse all", "mixed state offers collapse");
});

/* ---------- 4. analyst-typed category titles ---------- */

run("a category named constructor / __proto__ collapses like any other", () => {
  const cv = sandbox([
    { code: "Q1", title: "A", category: "constructor" },
    { code: "Q2", title: "B", category: "__proto__" },
    { code: "Q3", title: "C", category: "valueOf" }
  ]);
  const cards2 = cv.TR.cards2;
  assert(!cards2.catCollapsed("constructor"), "starts expanded");
  cards2.setAllCats(true);
  assert(cards2.catCollapsed("constructor"), "constructor collapsed");
  assert(cards2.catCollapsed("__proto__"), "__proto__ collapsed");
  assert(cards2.allCatsCollapsed(), "all collapsed");
  eq(cards2._sidebarHtml().split("catgrp collapsed").length - 1, 3, "all three render collapsed");
});

run("a quote in a category title cannot break out of the data-cat attribute", () => {
  const cv = sandbox([{ code: "Q1", title: "A", category: 'Say "hi" <b>' }]);
  const html = cv.TR.cards2._sidebarHtml();
  assert(html.indexOf('data-cat="Say &quot;hi&quot; &lt;b&gt;"') !== -1,
    "title escaped in the attribute: " + html);
});

/* ---------- 5. source gates for the two DOM-only behaviours ---------- */

run("the active question opens its own group before scrolling to it", () => {
  const src = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  const block = src.slice(src.indexOf('document.querySelectorAll(".qlink")'));
  const scroll = block.indexOf("scrollIntoView");
  const reveal = block.indexOf('cards2.setCat(grp.getAttribute("data-cat"), false)');
  assert(reveal !== -1, "the active branch expands its group");
  assert(reveal < scroll, "it expands BEFORE scrolling (a hidden link cannot scroll)");
});

run("search reveals matches inside collapsed groups, and CSS backs it", () => {
  const src = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  assert(src.indexOf('side.classList.toggle("searching", !!term)') !== -1,
    "the search handler marks the sidebar as searching");
  const css = readFileSync(CSS_PATH, "utf8");
  assert(/\.side\.searching\s+\.catgrp\.collapsed\s+\.catitems\s*\{[^}]*display:\s*block/.test(css),
    "CSS un-hides collapsed items while searching");
  assert(css.indexOf(".catsall") !== -1, "the all-groups button is styled");
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
