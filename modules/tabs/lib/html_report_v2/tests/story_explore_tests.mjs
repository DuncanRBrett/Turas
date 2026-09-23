#!/usr/bin/env node
/**
 * Explore from a Present question slide (stage 2 of
 * STORY_EXPLORE_AND_RETURN_BRIEF.md, item 1). Item 2, the live strip, was
 * built and then dropped by Duncan on 23 Sep 2026: the pin is his curated
 * view, and Explore already opens the full crosstabs with a way back.
 * Contracts:
 *
 * (1) A question slide carries one Explore button and nothing else new.
 * (2) Explore opens the pin's question, banner and filters in the crosstabs
 *     under a return point to that slide; Back reopens the slide with the
 *     reader's own view restored.
 * (3) Explore never writes the saved pin or storage.
 *
 * The real model and render chain (the disclosure suite's file list) plus the
 * real 20_data.js, 24_shell.js and 30_story.js run over a stubbed DOM.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/story_explore_tests.mjs
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

/* ---------------- sandbox ---------------- */

const CHAIN = ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js",
  "22_model.js", "23_render.js", "23z_charts.js", "23za_trend.js"];

/** Total 200; Dept: Sales 196, Legal 4; Region: North 120, South 80. Weighted,
 *  so all three base rows render. `k` is the reporting threshold (10 here). */
function fixture(TR, k) {
  TR.PREV = null; TR.userState = null; TR.MICRO = null;
  const base = (n) => ({ n, nWeighted: n, nEff: n, low: n < 30 });
  TR.AGG = {
    project: { name: "Live", low_base_threshold: 30, weighted: true,
      min_reporting_base: k, tabs: {} },
    banner_groups: [{ id: "Region", name: "Region" }, { id: "Dept", name: "Dept" }],
    columns: [
      { label: "Total", letter: "", group: null },
      { label: "North", letter: "A", group: "Region" },
      { label: "South", letter: "B", group: "Region" },
      { label: "Sales", letter: "C", group: "Dept" },
      { label: "Legal", letter: "D", group: "Dept" }
    ],
    questions: [{
      code: "Q1", title: "Satisfied?", type: "single", category: "X",
      bases: [base(200), base(120), base(80), base(196), base(4)],
      rows: [
        { kind: "category", label: "Yes", pct: [70, 68, 73, 70, 75],
          n: [140, 82, 58, 137, 3], sig: ["", "", "", "", ""] },
        { kind: "category", label: "No", pct: [30, 32, 27, 30, 25],
          n: [60, 38, 22, 59, 1], sig: ["", "", "", "", ""] }
      ]
    }, {
      code: "Q2", title: "Age", type: "single", category: "X",
      bases: [base(200), base(120), base(80), base(196), base(4)],
      rows: [
        { kind: "category", label: "Under 25", pct: [40, 40, 40, 40, 50],
          n: [80, 48, 32, 78, 2], sig: ["", "", "", "", ""] },
        { kind: "category", label: "25 plus", pct: [60, 60, 60, 60, 50],
          n: [120, 72, 48, 118, 2], sig: ["", "", "", "", ""] }
      ]
    }]
  };
}

const divider = (t) => ({ kind: "divider", title: t, note: "" });
const qpin = (extra) => Object.assign({ kind: "question", title: "", q: "Q1",
  banner: "Region", filters: [{ q: "Q2", box: false, rows: [0] }],
  flags: { chart: false, table: true, insight: true },
  chartType: "bar", chartKind: "detail", chartCols: [0, 1], hiddenChartRows: [],
  rowScope: "all", sort: { col: 1, dir: "desc" }, hiddenRows: [],
  hiddenCols: ["South"], dual: false, intervals: false, counts: false,
  note: "Pinned commentary" }, extra || {});

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
  const calls = [];
  const sb = { console, TextEncoder, atob,
    scrollY: 0, scrollTo: () => {},
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
  fixture(TR, opts.k || 10);
  TR.userState = { story: opts.story || [divider("One"), qpin(), divider("Three")] };
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
  load(sb, "30_story.js");
  // the reader's own view, different from the pin's on every count
  TR.d2.state.banner = "Dept";
  TR.d2.state.activeQ = "Q2";
  TR.d2.state.filters = [];
  TR.d2.state.showIntervals = true;
  return { sb, TR, nodes, store, calls, docListeners };
}

const overlayOf = (w) => w.nodes["present-overlay"];
const barOf = (w) => w.nodes.returnbar;
const go = (w, tab) => { w.TR.d2.state.tab = tab; w.TR.shell.route(); };
const key = (w, k, target) => (w.docListeners.keydown || []).slice()
  .forEach((fn) => fn({ key: k, target: target || null }));
/** Present at the pinned question slide (index 1 in the default story). */
function presentPin(w, i) {
  go(w, "story");
  w.TR.story2.presentFrom(typeof i === "number" ? i : 1);
}
/** The table the crosstabs model path draws for `item`, as Present draws it. */
function expectedTable(w, item) {
  const model = w.TR.story2._modelFor(item);
  return w.TR.render.tableHtml(model, { heatmap: true,
    showDeltas: w.TR.d2.tracking().enabled, intervals: !!item.intervals,
    showCounts: !!item.counts });
}

/* ---------------- text key ---------------- */

run("the Explore key is in the manifest and the shared registry, with no em dash", () => {
  const k = "story.explore";
  assert(MANIFEST[k], k + " declared in text_manifest.json");
  assert(REGISTRY.tabs[k] && REGISTRY.tabs[k].text, k + " authored in callouts.json");
  absent(REGISTRY.tabs[k].text, "\u2014", k + " carries an em dash");
  absent(MANIFEST[k].context, "\u2014", k + " manifest context carries an em dash");
  eq(MANIFEST[k].tokens, [], k + " takes no tokens");
});

run("the dropped live-strip keys are gone from both files", () => {
  ["banner", "total", "chart", "table", "intervals", "reset"].forEach((n) => {
    const k = "story.live." + n;
    assert(!MANIFEST[k], k + " still in text_manifest.json");
    assert(!REGISTRY.tabs[k], k + " still in callouts.json");
  });
});

/* ---------------- (1) the button ---------------- */

run("(1) a question slide carries one Explore button and no other control", () => {
  const w = sandbox();
  presentPin(w);
  const html = overlayOf(w).innerHTML;
  eq((html.match(/data-explore/g) || []).length, 1, "one Explore button");
  at(html, 'data-txt-key="story.explore"', "worded by its key");
  at(html, TXT("story.explore"), "in the author's words");
  absent(html, "data-live", "no live controls");
  absent(html, "pr-live", "no live strip");
  const pin = w.TR.story2.items()[1];
  at(html, expectedTable(w, pin), "the pinned table, exactly as the model path draws it");
});

run("(1) no Explore on a divider slide or a pin whose question has gone", () => {
  const w = sandbox({ story: [divider("One"), qpin({ q: "Q9" })] });
  presentPin(w, 0);
  absent(overlayOf(w).innerHTML, "data-explore", "divider slide");
  w.TR.story2.presentFrom(1);
  absent(overlayOf(w).innerHTML, "data-explore", "stale question slide");
  const before = overlayOf(w).innerHTML;
  w.TR.story2.explore();
  eq(overlayOf(w).innerHTML, before, "Explore does nothing there");
  eq(w.TR.shell.returnPoint.current(), null, "no return point taken");
});

run("(1) Explore does nothing when Present is closed", () => {
  const w = sandbox();
  go(w, "story");
  w.TR.story2.explore();
  eq(w.TR.d2.state.tab, "story", "still on the Story tab");
  eq(w.TR.shell.returnPoint.current(), null, "no return point taken");
});

/* ---------------- (2) Explore and Back ---------------- */

run("(2) Explore opens the pin's question, banner and filters under a return point", () => {
  const w = sandbox();
  presentPin(w);
  const pin = w.TR.story2.items()[1];
  clickOn(overlayOf(w), { "[data-explore]": {} });
  const s = w.TR.d2.state;
  assert(overlayOf(w).hidden, "Present closes for the detour");
  eq(s.tab, "crosstabs", "in the crosstabs");
  eq(s.activeQ, "Q1", "on the pin's question");
  eq(s.banner, "Region", "with the pin's banner");
  eq(s.filters, pin.filters, "and the pin's filters");
  assert(s.filters !== pin.filters, "a copy of them, not the pin's own array");
  eq(w.calls.filter((c) => c === "filterBar").length, 1, "the filter bar redrew");
  eq(w.TR.shell.returnPoint.current(), { kind: "present", at: 1 }, "return point to the slide");
  assert(!barOf(w).hidden, "the bar shows");
  at(barOf(w).innerHTML, TXT("story.return.present", { n: 2, total: 3 }), "slide 2 of 3");

  w.TR.shell.returnPoint.back();
  assert(!overlayOf(w).hidden, "Back reopens Present");
  at(overlayOf(w).innerHTML, "2 / 3", "at the same slide");
  eq(s.banner, "Dept", "the reader's banner is back");
  eq(s.activeQ, "Q2", "and their question");
  eq(s.filters, [], "and their filters");
  eq(s.showIntervals, true, "and their intervals setting");
});

run("(2) Explore opens the slide showing, after moving through the story", () => {
  const w = sandbox({ story: [qpin({ q: "Q2", banner: "Dept", filters: [] }), divider("Two"),
    qpin()] });
  presentPin(w, 0);
  key(w, "ArrowRight"); key(w, "ArrowRight");
  at(overlayOf(w).innerHTML, "3 / 3", "on slide 3");
  w.TR.story2.explore();
  eq(w.TR.d2.state.activeQ, "Q1", "slide 3's question");
  eq(w.TR.d2.state.banner, "Region", "and banner");
  eq(w.TR.shell.returnPoint.current(), { kind: "present", at: 2 }, "a return point to slide 3");
});

// Starting Present is a new context, not a detour: a point left open from
// before closes, so Back from Explore returns to the slide (review finding I1,
// 23 Sep 2026). A detour started while one is open still keeps the first
// (narrative_links_tests L2).
run("(2) Starting Present closes an older return point, so Explore's Back is the slide", () => {
  const w = sandbox();
  go(w, "report");
  w.TR.shell.returnPoint.leave();
  go(w, "story");
  w.TR.story2.presentFrom(1);
  eq(w.TR.shell.returnPoint.current(), null, "the Report tab point closed as Present opened");
  w.TR.story2.explore();
  eq(w.TR.shell.returnPoint.current(), { kind: "present", at: 1 }, "Back goes to the slide");
  eq(w.TR.d2.state.activeQ, "Q1", "the detour still opened the question");
});

/* ---------------- (3) nothing written ---------------- */

run("(3) presenting and exploring never write the saved pin or storage", () => {
  const w = sandbox();
  go(w, "story");
  const items = JSON.stringify(w.TR.story2.items());
  const store = JSON.stringify(w.store);
  w.TR.story2.presentFrom(1);
  w.TR.story2.explore();
  w.TR.d2.state.banner = "Dept";              // wander in the crosstabs
  w.TR.shell.returnPoint.back();
  eq(JSON.stringify(w.TR.story2.items()), items, "the pins are byte-identical");
  eq(JSON.stringify(w.store), store, "and so is storage");
});

/* ---------------- keys and wiring ---------------- */

run("Space on the focused Explore button never moves the slide", () => {
  const w = sandbox();
  presentPin(w);
  const onExplore = { closest: (sel) => (sel === "[data-explore]" ? {} : null) };
  key(w, " ", onExplore);
  key(w, "ArrowRight", onExplore);
  at(overlayOf(w).innerHTML, "2 / 3", "still on slide 2");
  key(w, "ArrowRight");
  at(overlayOf(w).innerHTML, "3 / 3", "an arrow elsewhere still moves it");
  key(w, "Escape", onExplore);
  assert(overlayOf(w).hidden, "Escape still closes Present");
});

run("one overlay click listener however often Present redraws", () => {
  const w = sandbox();
  presentPin(w);
  key(w, "ArrowRight"); key(w, "ArrowLeft");
  key(w, "Escape");
  w.TR.story2.presentFrom(1);
  eq((overlayOf(w).listeners.click || []).length, 1, "one listener");
});

console.log("\n" + (failed ? "\u2717 " : "\u2713 ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
