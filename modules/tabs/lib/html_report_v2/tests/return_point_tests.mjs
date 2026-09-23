#!/usr/bin/env node
/**
 * The return point (stage 1 of STORY_EXPLORE_AND_RETURN_BRIEF.md). One
 * mechanism records where the reader was and how the report looked, lets them
 * wander, and brings them back. Contracts, lettered as in the brief:
 *
 * (a) Every field of TR.d2.state survives a leave and a return unchanged,
 *     filters, hidden rows and columns and the custom banner included, and a
 *     field added during the detour does not survive it.
 * (b) Back from the crosstabs reopens Present at the same slide, and from each
 *     other origin (Story tab, Report tab, cover) reopens that origin.
 * (c) Stay here drops the bar and keeps the view.
 * (d) The slide link (#tab=story&slide=7) opens Present, clamps past the end,
 *     and the address follows the slide while presenting.
 * (e) The story card's open no longer loses the reader's filters.
 * Plus item 5: Present resumes where it stopped, and every card can present
 * from itself.
 *
 * The real 20_data.js, 24_shell.js and 30_story.js run over a stubbed DOM; the
 * tab renderers that are not under test are stubs that record their calls.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/return_point_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { TXT, installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const REGISTRY = JSON.parse(readFileSync(path.join(HERE, "..", "..", "..", "..",
  "shared", "lib", "callouts", "callouts.json"), "utf8"));
const MANIFEST = JSON.parse(readFileSync(path.join(HERE, "..", "assets",
  "text_manifest.json"), "utf8"));
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
    throw new Error(msg + ": missing " + JSON.stringify(needle) + " in " +
      JSON.stringify(String(hay).slice(0, 300)));
  }
}
function absent(hay, needle, msg) {
  if (String(hay).indexOf(needle) !== -1) throw new Error(msg + ": " + JSON.stringify(needle));
}

/** Structural equality that also compares prototypes (null vs Object), so a
 *  null-prototype object copied through JSON would fail it. */
function sameShape(a, b, where) {
  where = where || "state";
  if (Array.isArray(a) || Array.isArray(b)) {
    assert(Array.isArray(a) && Array.isArray(b), where + ": array vs non-array");
    eq(a.length, b.length, where + " length");
    a.forEach((v, i) => sameShape(v, b[i], where + "[" + i + "]"));
    return;
  }
  if (a && typeof a === "object") {
    assert(b && typeof b === "object", where + ": object vs " + JSON.stringify(b));
    assert(Object.getPrototypeOf(a) === Object.getPrototypeOf(b) ||
      (Object.getPrototypeOf(a) !== null && Object.getPrototypeOf(b) !== null),
      where + ": prototype changed (null-prototype lost or gained)");
    eq(Object.keys(a).sort(), Object.keys(b).sort(), where + " keys");
    Object.keys(a).forEach((k) => sameShape(a[k], b[k], where + "." + k));
    return;
  }
  eq(a, b, where);
}

/* ---------------- fake DOM ---------------- */

function el(id) {
  const listeners = {};
  return {
    id, hidden: false, innerHTML: "", style: {}, children: [],
    listeners,
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    removeEventListener(type, fn) {
      listeners[type] = (listeners[type] || []).filter((f) => f !== fn);
    },
    // Present wires its close button; nothing else here needs a real query
    querySelector: (sel) => (sel === "#pr-close" ? { addEventListener: () => {} } : null),
    querySelectorAll: () => [],
    replaceChildren(...c) { this.children = c; },
    setAttribute() {}, getAttribute: () => null
  };
}

/** A click whose target matches the given selectors (sel -> element). */
function clickOn(target, matches) {
  const t = { closest: (sel) => (sel in matches ? matches[sel] : null) };
  (target.listeners.click || []).forEach((fn) => fn({ target: t, preventDefault() {} }));
}

/* ---------------- sandbox: real data + shell + story ---------------- */

const Q1 = { code: "Q1", title: "Region", category: "Profile",
  rows: [{ kind: "category", label: "North" }, { kind: "category", label: "South" },
    { kind: "category", label: "East" }] };
const Q2 = { code: "Q2", title: "Age", category: "Profile",
  rows: [{ kind: "category", label: "Under 25" }, { kind: "category", label: "25 plus" }] };

const divider = (t) => ({ kind: "divider", title: t, note: "" });
const qpin = (extra) => Object.assign({ kind: "question", q: "Q2", banner: "B1",
  filters: [{ q: "Q1", box: false, rows: [0] }], flags: { table: true }, note: "" }, extra || {});

function sandbox(opts) {
  opts = opts || {};
  const store = {};
  const nodes = {};
  ["present-overlay", "returnbar", "tabhost", "filterbar", "story-count"].forEach((id) => {
    nodes[id] = el(id);
  });
  nodes["present-overlay"].hidden = true;
  nodes.returnbar.hidden = true;
  const docListeners = {};
  const hashes = [];
  const calls = [];
  const scrolls = [];
  const sb = { console, TextEncoder, atob,
    scrollY: 0,
    scrollTo: (x, y) => { scrolls.push([x, y]); },
    history: { replaceState: (a, b, h) => { hashes.push(h); } },
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
  for (const f of ["00_namespace.js", "01_format.js"]) load(sb, f);
  installText(sb);
  const TR = sb.TR;
  TR.AGG = { project: { name: "Proj", wave: "2026", tabs: {} },
    questions: [Q1, Q2],
    banner_groups: [{ id: "B1", name: "Region" }, { id: "B2", name: "Age" }],
    columns: [{ group: "B1", label: "North" }] };
  TR.userState = { story: opts.story || [divider("One"), divider("Two"),
    divider("Three"), divider("Four"), divider("Five")] };
  load(sb, "20_data.js");
  load(sb, "24_shell.js");
  const rec = (name) => () => { calls.push(name); };
  TR.filterBar = { render: rec("filterBar") };
  TR.cards2 = { renderTab: rec("crosstabs"),
    chartState: () => ({ type: "bar", kind: "auto", cols: [0] }) };
  TR.views = { dashboard: rec("dashboard") };
  TR.report = { renderTab: rec("report") };
  TR.reader = { renderCover: rec("cover"), renderStrip: () => {},
    coverAvailable: () => true };
  TR.takeout = { render: rec("takeout") };
  TR.model = { forQuestion: () => null };
  TR.stats = { hasSecondary: () => false, dualMode: () => false };
  TR.insights = { get: () => "" };
  load(sb, "30_story.js");
  TR.d2.state.banner = "B1";
  TR.d2.state.activeQ = "Q1";
  return { sb, TR, nodes, store, hashes, calls, scrolls, docListeners };
}

const overlayOf = (w) => w.nodes["present-overlay"];
const barOf = (w) => w.nodes.returnbar;
const lastHash = (w) => w.hashes[w.hashes.length - 1] || "";
/** The story tab's wrapper (the element its delegated click listener is on). */
const storyWrap = (w) => w.nodes.tabhost.children[0];
const card = (i) => ({ getAttribute: (a) => (a === "data-i" ? String(i) : null) });
const keydowns = (w) => (w.docListeners.keydown || []).length;
const key = (w, k) => (w.docListeners.keydown || []).slice().forEach((fn) => fn({ key: k }));
const go = (w, tab) => { w.TR.d2.state.tab = tab; w.TR.shell.route(); };

/* ---------------- text keys ---------------- */

const KEYS = ["story.present_from_here", "story.return.present", "story.return.story",
  "story.return.report", "story.return.cover", "story.return.stay"];

run("every new text key is in the manifest and the shared registry, with no em dash", () => {
  KEYS.forEach((k) => {
    assert(MANIFEST[k], k + " declared in text_manifest.json");
    assert(REGISTRY.tabs[k] && REGISTRY.tabs[k].text, k + " authored in callouts.json");
    absent(REGISTRY.tabs[k].text, "—", k + " carries an em dash");
    const used = (REGISTRY.tabs[k].text.match(/\{[a-z][a-z0-9_]*\}/g) || [])
      .map((t) => t.slice(1, -1)).sort();
    eq(used, (MANIFEST[k].tokens || []).slice().sort(), k + " tokens match the manifest");
  });
});

/* ---------------- (a) state survives ---------------- */

run("(a) every field of TR.d2.state survives a leave and return unchanged", () => {
  const w = sandbox({ story: [divider("One"), qpin()] });
  const s = w.TR.d2.state;
  go(w, "story");
  // the reader's own view, with every awkward kind of value in it
  s.filters = [{ q: "Q2", box: false, rows: [1] }, { q: "Q1", box: false, rows: [0, 2] }];
  s.hiddenRows = { Q1: ["South"], Q2: [] };
  s.hiddenCols = { B1: ["North"], "custom:Q2:net": ["25 plus"] };
  s.hiddenChartRows = { Q1: ["East"] };
  s.customBanner = "custom:Q2:net";
  s.banner = "custom:Q2:net";
  s.sorts = { Q1: { col: 2, dir: "desc" } };
  s.showIntervals = true; s.showCounts = true; s.sigMode = "dual";
  s.chartColLabels = ["Total", "North"];
  s.collapsedCats["constructor"] = true;       // a legal category name
  s.collapsedCats["Profile"] = true;
  s.visSel = { metric: "Q1", segs: ["a", "b"] };  // a field another module adds
  const before = vm.runInContext("TR.shell._cloneState(TR.d2.state)", w.sb);
  const sameObject = s;

  w.TR.story2.openItem(1);                     // leave through the card's open
  eq(s.tab, "crosstabs", "the detour is in the crosstabs");
  // wander: change everything, in place and by replacement, and add a field
  s.filters[0].rows.push(0);
  s.filters.push({ q: "Q1", box: false, rows: [1] });
  s.hiddenRows.Q1.push("North");
  s.hiddenCols.B1 = [];
  s.customBanner = "custom:Q1:detail";
  s.banner = "B2";
  delete s.collapsedCats["constructor"];
  s.sorts.Q1.dir = "asc";
  s.showIntervals = false;
  s.visSel.segs.length = 0;
  s.detourOnly = "should not survive";
  w.TR.shell.goQuestion("Q1", "B1");
  w.TR.shell.returnPoint.back();

  assert(w.TR.d2.state === sameObject, "state is restored in place, not replaced");
  const after = vm.runInContext("TR.shell._cloneState(TR.d2.state)", w.sb);
  sameShape(after, before);
  assert(!("detourOnly" in s), "a field added during the detour is gone");
  assert(Object.getPrototypeOf(s.collapsedCats) === null, "collapsedCats stays null-prototype");
  eq(s.collapsedCats["constructor"], true, "the 'constructor' category is still collapsed");
});

/* ---------------- (b) each origin ---------------- */

run("(b) Back from the crosstabs reopens Present at the same slide", () => {
  const w = sandbox();
  go(w, "story");
  w.TR.story2.presentFrom(3);
  at(overlayOf(w).innerHTML, "4 / 5", "Present at slide 4");
  eq(w.TR.d2.state.slide, 4, "state carries the slide");
  w.TR.story2.leavePresent();
  assert(overlayOf(w).hidden, "Present closes for the detour");
  eq(w.TR.d2.state.slide, null, "no slide while away");
  eq(keydowns(w), 0, "Present's key listener is removed");
  eq(w.TR.shell.returnPoint.current(), { kind: "present", at: 3 }, "origin recorded");
  assert(!barOf(w).hidden, "the bar shows");
  at(barOf(w).innerHTML, 'data-txt-key="story.return.present"', "the Present wording key");
  at(barOf(w).innerHTML, TXT("story.return.present", { n: 4, total: 5 }), "slide 4 of 5");

  w.TR.shell.goQuestion("Q2", "B2");
  eq(w.calls[w.calls.length - 1], "crosstabs", "the crosstabs rendered");
  assert(!barOf(w).hidden, "the bar stays across the route");

  w.TR.shell.returnPoint.back();
  assert(!overlayOf(w).hidden, "Present is open again");
  at(overlayOf(w).innerHTML, "4 / 5", "at the same slide");
  eq(w.TR.d2.state.tab, "story", "on the Story tab");
  eq(w.TR.d2.state.slide, 4, "state carries the slide again");
  at(lastHash(w), "slide=4", "and so does the address");
  assert(barOf(w).hidden, "the bar is gone");
  eq(barOf(w).innerHTML, "", "and empty");
  eq(w.TR.shell.returnPoint.current(), null, "no return point left");
  eq(keydowns(w), 1, "one key listener, not two");
});

run("(b) Back reopens the Story tab, the Report tab and the cover", () => {
  [["story", "story.return.story"], ["report", "story.return.report"],
    ["cover", "story.return.cover"]].forEach(([tab, textKey]) => {
    const w = sandbox();
    go(w, tab);
    w.sb.scrollY = 420;
    assert(w.TR.shell.returnPoint.leave(), tab + ": leave opens a return point");
    eq(w.TR.shell.returnPoint.current().kind, tab, tab + ": origin from where the reader is");
    at(barOf(w).innerHTML, 'data-txt-key="' + textKey + '"', tab + ": its own wording");
    at(barOf(w).innerHTML, TXT(textKey), tab + ": in the author's words");
    at(barOf(w).innerHTML, 'data-txt-key="story.return.stay"', tab + ": Stay here offered");
    w.TR.shell.goQuestion("Q2", "B2");
    go(w, "dashboard");
    w.sb.scrollY = 0;
    w.calls.length = 0;
    w.TR.shell.returnPoint.back();
    eq(w.TR.d2.state.tab, tab, tab + ": back on its tab");
    if (tab !== "story") eq(w.calls.filter((c) => c === tab).length, 1, tab + ": rendered");
    else assert(storyWrap(w), "story: the Story tab rendered");
    eq(w.scrolls[w.scrolls.length - 1], [0, 420], tab + ": scrolled back to where it was");
    assert(overlayOf(w).hidden, tab + ": Present stays closed");
    assert(barOf(w).hidden, tab + ": bar gone");
  });
});

run("(b) one return point at a time: Back goes where the reader first left", () => {
  const w = sandbox();
  go(w, "report");
  assert(w.TR.shell.returnPoint.leave(), "the first detour opens it");
  go(w, "cover");
  assert(!w.TR.shell.returnPoint.leave(), "a second detour keeps the first");
  eq(w.TR.shell.returnPoint.current().kind, "report", "still the Report tab");
  w.TR.shell.goQuestion("Q1", "B1");
  w.TR.shell.returnPoint.back();
  eq(w.TR.d2.state.tab, "report", "Back goes to the first origin");
});

run("(b) no return point where a detour has no origin", () => {
  const w = sandbox();
  go(w, "crosstabs");
  assert(!w.TR.shell.returnPoint.leave(), "the crosstabs are not an origin");
  assert(barOf(w).hidden, "no bar");
  w.TR.shell.returnPoint.back();          // a Back with nothing open is harmless
  eq(w.TR.d2.state.tab, "crosstabs", "nothing moved");
});

run("(b) the bar's own buttons do Back and Stay here", () => {
  const w = sandbox();
  go(w, "report");
  w.TR.shell.returnPoint.leave();
  w.TR.shell.goQuestion("Q1", "B1");
  clickOn(barOf(w), { "[data-return-back]": {} });
  eq(w.TR.d2.state.tab, "report", "Back button returns");
  w.TR.shell.returnPoint.leave();
  w.TR.shell.goQuestion("Q1", "B1");
  clickOn(barOf(w), { "[data-return-stay]": {} });
  eq(w.TR.d2.state.tab, "crosstabs", "Stay here button keeps the view");
  assert(barOf(w).hidden, "and drops the bar");
  eq((barOf(w).listeners.click || []).length, 1, "one click listener however often it renders");
});

/* ---------------- (c) stay here ---------------- */

run("(c) Stay here drops the bar and keeps the view", () => {
  const w = sandbox({ story: [divider("One"), qpin()] });
  const s = w.TR.d2.state;
  go(w, "story");
  s.filters = [{ q: "Q2", box: false, rows: [1] }];
  w.TR.story2.openItem(1);
  s.showIntervals = true;
  w.TR.shell.returnPoint.stay();
  assert(barOf(w).hidden, "bar hidden");
  eq(barOf(w).innerHTML, "", "bar empty");
  eq(w.TR.shell.returnPoint.current(), null, "return point dropped");
  eq(s.tab, "crosstabs", "still in the crosstabs");
  eq(s.activeQ, "Q2", "on the pinned question");
  eq(s.filters, [{ q: "Q1", box: false, rows: [0] }], "with the pin's filters");
  eq(s.showIntervals, true, "and what the reader changed");
  w.TR.shell.returnPoint.back();
  eq(s.tab, "crosstabs", "Back after Stay here does nothing");
  go(w, "report");
  assert(w.TR.shell.returnPoint.leave(), "a new detour can open a fresh one");
});

run("the return point is never written to localStorage", () => {
  const w = sandbox();
  go(w, "report");
  w.TR.shell.returnPoint.leave();
  w.TR.shell.goQuestion("Q1", "B1");
  Object.keys(w.store).forEach((k) => {
    absent(w.store[k], '"origin"', "stored under " + k);
    absent(k, "return", "a store key");
  });
});

/* ---------------- (d) the slide link ---------------- */

run("(d) #tab=story&slide=3 opens Present at slide 3 and the address follows", () => {
  const w = sandbox();
  w.TR.d2.decodeHash("#tab=story&slide=3");
  w.TR.shell.route();
  assert(!overlayOf(w).hidden, "Present is open");
  at(overlayOf(w).innerHTML, "3 / 5", "at slide 3");
  at(lastHash(w), "tab=story", "the address names the Story tab");
  at(lastHash(w), "slide=3", "and the slide");
  key(w, "ArrowRight");
  at(overlayOf(w).innerHTML, "4 / 5", "next slide");
  eq(w.TR.d2.state.slide, 4, "state follows");
  at(lastHash(w), "slide=4", "the address follows");
  key(w, "ArrowLeft");
  at(lastHash(w), "slide=3", "and back");
  key(w, "Escape");
  assert(overlayOf(w).hidden, "Escape closes");
  eq(w.TR.d2.state.slide, null, "no slide");
  absent(lastHash(w), "slide=", "the address drops the slide");
});

run("(d) a slide past the end clamps to the last; nonsense is ignored", () => {
  let w = sandbox();
  w.TR.d2.decodeHash("#tab=story&slide=99");
  w.TR.shell.route();
  at(overlayOf(w).innerHTML, "5 / 5", "the last slide");
  eq(w.TR.d2.state.slide, 5, "state clamped too");
  at(lastHash(w), "slide=5", "and the address");

  w = sandbox();
  w.TR.d2.decodeHash("#tab=story&slide=0");
  w.TR.shell.route();
  at(overlayOf(w).innerHTML, "1 / 5", "0 opens the first slide");

  w = sandbox();
  w.TR.d2.decodeHash("#tab=story&slide=abc");
  eq(w.TR.d2.state.slide, null, "not a number: no slide");
  w.TR.shell.route();
  assert(overlayOf(w).hidden, "Present stays closed");

  w = sandbox();
  w.TR.d2.decodeHash("#tab=crosstabs&slide=3");
  eq(w.TR.d2.state.slide, null, "a slide off the Story tab is dropped");
  w.TR.shell.route();
  go(w, "story");
  assert(overlayOf(w).hidden, "so a later Story click does not open Present");
});

run("(d) a slide link on an empty story neither crashes nor opens Present", () => {
  const w = sandbox({ story: [] });
  w.TR.userState = null;
  w.TR.d2.decodeHash("#tab=story&slide=2");
  w.TR.shell.route();
  assert(overlayOf(w).hidden, "no overlay");
  eq(w.TR.d2.state.slide, null, "slide cleared");
  absent(lastHash(w), "slide=", "no slide in the address");
});

run("(d) routing to an open Present never stacks a second key listener", () => {
  const w = sandbox();
  w.TR.d2.decodeHash("#tab=story&slide=2");
  w.TR.shell.route();
  w.TR.shell.route();
  w.TR.d2.decodeHash("#tab=story&slide=4");
  w.TR.shell.route();
  eq(keydowns(w), 1, "one listener");
  at(overlayOf(w).innerHTML, "4 / 5", "moved to the new slide");
  key(w, "ArrowRight");
  at(overlayOf(w).innerHTML, "5 / 5", "one step per key press");
});

run("(d) the slide is only in the address on the Story tab", () => {
  const w = sandbox();
  w.TR.d2.state.tab = "crosstabs";
  w.TR.d2.state.slide = 3;
  absent(w.TR.d2.encodeHash(), "slide=", "not on the crosstabs");
  w.TR.d2.state.tab = "story";
  at(w.TR.d2.encodeHash(), "slide=3", "on the Story tab");
});

/* ---------------- item 5: resume ---------------- */

run("(5) Present resumes where it stopped, and clamps if the story shrank", () => {
  const w = sandbox();
  go(w, "story");
  w.TR.story2._topAction("present");
  at(overlayOf(w).innerHTML, "1 / 5", "a first Present starts at slide 1");
  key(w, "ArrowRight"); key(w, "ArrowRight"); key(w, "ArrowRight");
  key(w, "Escape");
  w.TR.story2._topAction("present");
  at(overlayOf(w).innerHTML, "4 / 5", "reopens at slide 4");
  key(w, "Escape");
  w.TR.story2.items().splice(2, 3);
  w.TR.story2._topAction("present");
  at(overlayOf(w).innerHTML, "2 / 2", "clamped to the last slide left");
});

run("(5) every story card offers Present from here, and it opens at that card", () => {
  const w = sandbox({ story: [divider("One"), qpin(), divider("Three")] });
  go(w, "story");
  const html = w.TR.story2._itemHtml(divider("X"), 2);
  at(html, "data-present-from", "the button is on the card");
  at(html, 'data-txt-key="story.present_from_here"', "worded by its key");
  at(html, TXT("story.present_from_here"), "in the author's words");
  clickOn(storyWrap(w), { ".story-item": card(2), "[data-present-from]": {} });
  at(overlayOf(w).innerHTML, "3 / 3", "Present opens at card 3");
  key(w, "Escape");
  clickOn(storyWrap(w), { ".story-item": card(0), "[data-present-from]": {} });
  at(overlayOf(w).innerHTML, "1 / 3", "and at card 1");
});

/* ---------------- (e) the card's open ---------------- */

run("(e) the story card's open keeps a way back to the reader's filters", () => {
  const w = sandbox({ story: [divider("One"), qpin()] });
  const s = w.TR.d2.state;
  go(w, "story");
  const mine = [{ q: "Q2", box: false, rows: [1] }];
  s.filters = JSON.parse(JSON.stringify(mine));
  s.banner = "B1";
  s.activeQ = "Q1";
  clickOn(storyWrap(w), { ".story-item": card(1), "[data-open]": {} });
  eq(s.tab, "crosstabs", "opens in the crosstabs");
  eq(s.activeQ, "Q2", "on the pinned question");
  eq(s.banner, "B1", "with the pin's banner");
  eq(s.filters, [{ q: "Q1", box: false, rows: [0] }], "and the pin's filters");
  eq(w.TR.shell.returnPoint.current(), { kind: "story", at: 1 }, "under a return point");
  at(barOf(w).innerHTML, 'data-txt-key="story.return.story"', "the bar says Back to the story");
  w.TR.shell.returnPoint.back();
  eq(s.filters, mine, "the reader's own filters are back");
  eq(s.activeQ, "Q1", "and their question");
  eq(s.tab, "story", "on the Story tab");
});

run("(e) opening a second pin during the detour keeps the first return point", () => {
  const w = sandbox({ story: [qpin(), qpin({ q: "Q1", filters: [] })] });
  const s = w.TR.d2.state;
  go(w, "story");
  s.filters = [{ q: "Q2", box: false, rows: [0] }];
  w.TR.story2.openItem(0);
  go(w, "story");
  w.TR.story2.openItem(1);
  eq(s.activeQ, "Q1", "the second pin opened");
  eq(s.filters, [], "with its own (empty) filters");
  eq(w.TR.shell.returnPoint.current(), { kind: "story", at: 0 }, "the first card is the origin");
  w.TR.shell.returnPoint.back();
  eq(s.filters, [{ q: "Q2", box: false, rows: [0] }], "Back restores the view before the first");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
