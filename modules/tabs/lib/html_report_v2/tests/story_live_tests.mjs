#!/usr/bin/env node
/**
 * Explore and live in place (stage 2 of STORY_EXPLORE_AND_RETURN_BRIEF.md).
 * Contracts:
 *
 * (1) Explore on a question slide opens the pin's question, banner and filters
 *     in the crosstabs under a return point to that slide; Back reopens the
 *     slide with the reader's own view restored.
 * (2) Each live control (banner, chart or table, 95% intervals) redraws the
 *     slide through the crosstabs' model path, and leaves the saved pin,
 *     TR.d2.state and localStorage byte-identical.
 * (3) Reset to pinned view restores the pinned view exactly.
 * (4) A disclosure-gated column stays gated in the live slide.
 *
 * The real model and render chain (the disclosure suite's file list) plus the
 * real 20_data.js, 24_shell.js and 30_story.js run over a stubbed DOM.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/story_live_tests.mjs
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
const attr = (name, value) => ({ getAttribute: (a) => (a === name ? value : null) });

/* ---------------- sandbox ---------------- */

const CHAIN = ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js",
  "22_model.js", "23_render.js", "23z_charts.js", "23za_trend.js"];

/** Total 200; Dept: Sales 196, Legal 4; Region: North 120, South 80. Weighted,
 *  so all three base rows render. `k` is the reporting threshold: at 10 the
 *  4-person Legal column is suppressed, at 1 the control is off. */
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
/** Everything a live control must leave alone, as strings. */
const frozen = (w) => ({
  items: JSON.stringify(w.TR.story2.items()),
  state: JSON.stringify(vm.runInContext("TR.shell._cloneState(TR.d2.state)", w.sb)),
  store: JSON.stringify(w.store)
});
/** The overlay's table and chart blocks. */
const tableBlock = (html) => {
  const i = html.indexOf('<div class="pr-table"><table');
  return i === -1 ? "" : html.slice(i);
};
const chartBlock = (html) => {
  const i = html.indexOf('<div class="pr-table pr-chart">');
  return i === -1 ? "" : html.slice(i, html.indexOf("</svg>", i));
};
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

/* ---------------- text keys ---------------- */

const KEYS = ["story.explore", "story.live.banner", "story.live.total", "story.live.chart",
  "story.live.table", "story.live.intervals", "story.live.reset"];

run("every new text key is in the manifest and the shared registry, with no em dash", () => {
  KEYS.forEach((k) => {
    assert(MANIFEST[k], k + " declared in text_manifest.json");
    assert(REGISTRY.tabs[k] && REGISTRY.tabs[k].text, k + " authored in callouts.json");
    absent(REGISTRY.tabs[k].text, "—", k + " carries an em dash");
    absent(MANIFEST[k].context, "—", k + " manifest context carries an em dash");
    const used = (REGISTRY.tabs[k].text.match(/\{[a-z][a-z0-9_]*\}/g) || [])
      .map((t) => t.slice(1, -1)).sort();
    eq(used, (MANIFEST[k].tokens || []).slice().sort(), k + " tokens match the manifest");
  });
});

/* ---------------- the strip ---------------- */

run("a question slide carries Explore and the live controls, worded by their keys", () => {
  const w = sandbox();
  presentPin(w);
  const html = overlayOf(w).innerHTML;
  at(html, "data-live-explore", "Explore button");
  KEYS.filter((k) => k !== "story.live.total").forEach((k) => {
    at(html, 'data-txt-key="' + k + '"', k + " on the slide");
  });
  at(html, TXT("story.explore"), "in the author's words");
  at(html, 'data-live-banner="Region" aria-pressed="true"', "the pinned banner is pressed");
  at(html, 'data-live-banner="Dept" aria-pressed="false"', "the other banner is offered");
  at(html, 'data-live-view="table" aria-pressed="true"', "table pressed");
  at(html, 'data-live-view="chart" aria-pressed="false"', "chart not pressed");
  at(html, "data-live-intervals aria-pressed=\"false\"", "intervals off, as pinned");
  at(html, "data-live-reset disabled", "Reset is disabled until something changes");
});

run("no strip on a divider slide or a pin whose question has gone", () => {
  const w = sandbox({ story: [divider("One"), qpin({ q: "Q9" })] });
  presentPin(w, 0);
  absent(overlayOf(w).innerHTML, "pr-live", "divider slide");
  w.TR.story2.presentFrom(1);
  absent(overlayOf(w).innerHTML, "pr-live", "stale question slide");
  const before = overlayOf(w).innerHTML;
  w.TR.story2.explore();
  w.TR.story2.live({ banner: "Dept" });
  eq(overlayOf(w).innerHTML, before, "Explore and live do nothing there");
  eq(w.TR.shell.returnPoint.current(), null, "no return point taken");
});

/* ---------------- (1) Explore ---------------- */

run("(1) Explore opens the pin's question, banner and filters under a return point", () => {
  const w = sandbox();
  presentPin(w);
  const pin = w.TR.story2.items()[1];
  clickOn(overlayOf(w), { "[data-live-explore]": {} });
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

run("(1) Explore opens the pin's view even after the live strip varied it", () => {
  const w = sandbox();
  presentPin(w);
  w.TR.story2.live({ banner: "Dept" });
  w.TR.story2.live({ intervals: true });
  w.TR.story2.explore();
  eq(w.TR.d2.state.banner, "Region", "the pin's banner, not the live one");
  eq(w.TR.d2.state.filters, [{ q: "Q2", box: false, rows: [0] }], "the pin's filters");
  w.TR.shell.returnPoint.back();
  eq(w.TR.story2._live(), null, "Back shows the slide at its pinned view");
  at(overlayOf(w).innerHTML, "data-live-reset disabled", "nothing varied");
});

run("(1) Explore while a return point is already open keeps the first", () => {
  const w = sandbox();
  go(w, "report");
  w.TR.shell.returnPoint.leave();
  go(w, "story");
  w.TR.story2.presentFrom(1);
  w.TR.story2.explore();
  eq(w.TR.shell.returnPoint.current(), { kind: "report" }, "Back still goes to the Report tab");
  eq(w.TR.d2.state.activeQ, "Q1", "the detour still opened the question");
});

/* ---------------- (2) each live control ---------------- */

run("(2) the banner control redraws the slide by the new banner, and changes nothing else", () => {
  const w = sandbox({ k: 1 });
  presentPin(w);
  const pinned = overlayOf(w).innerHTML;
  const before = frozen(w);
  clickOn(overlayOf(w), { "[data-live-banner]": attr("data-live-banner", "Dept") });
  const html = overlayOf(w).innerHTML;
  eq(frozen(w), before, "pin, TR.d2.state and storage byte-identical");
  const v = w.TR.story2._live().item;
  eq(v.banner, "Dept", "the live copy carries the new banner");
  eq(v.hiddenCols, [], "the pinned banner's hidden columns do not follow it");
  eq(v.sort, null, "nor does its column sort");
  eq(v.chartCols, [0, 1, 2], "the chart takes every column of the new banner");
  assert(html !== pinned, "the slide redrew");
  at(html, 'data-live-banner="Dept" aria-pressed="true"', "Dept pressed");
  at(tableBlock(html), expectedTable(w, v), "the table is the model path's, for Dept");
  at(tableBlock(html), "Sales", "Dept's columns show");
  absent(tableBlock(html), "North", "Region's do not");
  at(html, "data-live-reset>", "Reset is enabled");
  eq(w.TR.story2.items()[1].banner, "Region", "the saved pin still says Region");
});

run("(2) the chart and table controls redraw the slide, and change nothing else", () => {
  const w = sandbox();
  presentPin(w);
  const before = frozen(w);
  clickOn(overlayOf(w), { "[data-live-view]": attr("data-live-view", "chart") });
  let html = overlayOf(w).innerHTML;
  eq(frozen(w), before, "chart: pin, TR.d2.state and storage byte-identical");
  const v = w.TR.story2._live().item;
  at(html, '<div class="pr-table pr-chart">', "a chart shows");
  at(html, w.TR.render.chartBy("bar", w.TR.story2._modelFor(v), [0, 1]),
    "the model path's chart, at the pin's chart columns");
  eq(tableBlock(html), "", "and no table");
  at(html, 'data-live-view="chart" aria-pressed="true"', "chart pressed");
  clickOn(overlayOf(w), { "[data-live-view]": attr("data-live-view", "table") });
  html = overlayOf(w).innerHTML;
  eq(frozen(w), before, "table: pin, TR.d2.state and storage byte-identical");
  eq(chartBlock(html), "", "no chart");
  at(tableBlock(html), expectedTable(w, w.TR.story2._live().item), "the table is back");
  eq(w.TR.story2.items()[1].flags, { chart: false, table: true, insight: true },
    "the saved pin's flags are untouched");
});

run("(2) the intervals control redraws the slide, and changes nothing else", () => {
  const w = sandbox({ k: 1 });
  presentPin(w);
  const before = frozen(w);
  const off = tableBlock(overlayOf(w).innerHTML);
  clickOn(overlayOf(w), { "[data-live-intervals]": {} });
  const html = overlayOf(w).innerHTML;
  eq(frozen(w), before, "pin, TR.d2.state and storage byte-identical");
  const v = w.TR.story2._live().item;
  eq(v.intervals, true, "the live copy shows intervals");
  at(html, "data-live-intervals aria-pressed=\"true\"", "pressed");
  assert(tableBlock(html) !== off, "the table redrew");
  at(tableBlock(html), expectedTable(w, v), "with the model path's intervals");
  at(html, w.TR.conf.methodNote(w.TR.conf.modelIntervalKind(w.TR.story2._modelFor(v))),
    "the context line names the interval method");
  clickOn(overlayOf(w), { "[data-live-intervals]": {} });
  eq(w.TR.story2._live().item.intervals, false, "a second press turns them off");
  eq(w.TR.d2.state.showIntervals, true, "the reader's own intervals setting never moved");
  eq(w.TR.story2.items()[1].intervals, false, "nor did the pin's");
});

run("(2) nothing the live path does reaches the story tab card or the saved copy", () => {
  const w = sandbox();
  go(w, "story");
  const card = w.TR.story2._itemHtml(w.TR.story2.items()[1], 1);
  w.TR.story2.presentFrom(1);
  w.TR.story2.live({ banner: "Dept" });
  w.TR.story2.live({ view: "chart" });
  w.TR.story2.live({ intervals: true });
  eq(w.TR.story2._itemHtml(w.TR.story2.items()[1], 1), card, "the card renders as pinned");
  eq(Object.keys(w.store).filter((k) => /live/.test(w.store[k])).length, 0,
    "no live view in storage");
});

/* ---------------- (3) Reset ---------------- */

run("(3) Reset restores the pinned view exactly", () => {
  const w = sandbox();
  presentPin(w);
  const pinned = overlayOf(w).innerHTML;
  const before = frozen(w);
  w.TR.story2.live({ banner: "Dept" });
  w.TR.story2.live({ view: "chart" });
  w.TR.story2.live({ intervals: true });
  assert(overlayOf(w).innerHTML !== pinned, "the slide was varied");
  clickOn(overlayOf(w), { "[data-live-reset]": {} });
  eq(overlayOf(w).innerHTML, pinned, "byte-identical to the pinned view");
  eq(w.TR.story2._live(), null, "no live view left");
  eq(frozen(w), before, "and nothing else changed");
});

run("(3) leaving the slide drops its live view; returning shows the pinned view", () => {
  const w = sandbox();
  presentPin(w);
  const pinned = overlayOf(w).innerHTML;
  w.TR.story2.live({ banner: "Dept" });
  key(w, "ArrowRight");
  at(overlayOf(w).innerHTML, "3 / 3", "moved on");
  eq(w.TR.story2._live(), null, "the live view went with the slide");
  key(w, "ArrowLeft");
  eq(overlayOf(w).innerHTML, pinned, "back at the pinned view");
  w.TR.story2.live({ intervals: true });
  key(w, "Escape");
  w.TR.story2._topAction("present");
  eq(overlayOf(w).innerHTML, pinned, "closing and reopening Present shows it pinned too");
});

/* ---------------- (4) disclosure ---------------- */

run("(4) a disclosure-gated column stays gated in the live slide", () => {
  const w = sandbox({ k: 10 });
  presentPin(w);
  // the pin is on Region, where nothing is gated; switch the live banner to
  // Dept, whose 4-person Legal column is under k = 10, and add the intervals
  w.TR.story2.live({ banner: "Dept" });
  w.TR.story2.live({ intervals: true });
  const v = w.TR.story2._live().item;
  const model = w.TR.story2._modelFor(v);
  assert(model.columns[2].label === "Legal" && model.columns[2].suppressed === true,
    "the model path suppressed Legal");
  const table = tableBlock(overlayOf(w).innerHTML);
  const bases = table.slice(table.indexOf('<tr class="rb">'), table.indexOf('<tr class="rc">'));
  eq((bases.match(/n&lt;10/g) || []).length, 3, "every base row masks Legal");
  assert(!/>4 ?⚠?</.test(bases), "the headcount 4 appears nowhere in the bases");
  absent(table, "±49.0pp", "nor its margin of error");
  absent(table, ">75", "nor Legal's 75% Yes");
  w.TR.story2.live({ view: "chart" });
  const chart = chartBlock(overlayOf(w).innerHTML);
  assert(chart.length > 0, "the chart drew");
  absent(chart, ">75", "the chart does not show Legal's 75% either");
  absent(chart, ">25", "nor its 25% No");
});

run("(4) the same live path with the control off shows Legal, so the gate is what hides it", () => {
  const w = sandbox({ k: 1 });
  presentPin(w);
  w.TR.story2.live({ banner: "Dept" });
  w.TR.story2.live({ intervals: true });
  const table = tableBlock(overlayOf(w).innerHTML);
  at(table, "±49.0pp", "the small column's margin shows when nothing is gated");
  absent(table, "n&lt;10", "no marker");
  w.TR.story2.live({ view: "chart" });
  at(chartBlock(overlayOf(w).innerHTML), ">75", "and the chart shows Legal's 75%");
});

/* ---------------- keys and wiring ---------------- */

run("a key on a focused live control never moves the slide", () => {
  const w = sandbox();
  presentPin(w);
  const inStrip = { closest: (sel) => (sel === ".pr-live" ? {} : null) };
  key(w, " ", inStrip);
  key(w, "ArrowRight", inStrip);
  at(overlayOf(w).innerHTML, "2 / 3", "still on slide 2");
  key(w, "Escape", inStrip);
  assert(overlayOf(w).hidden, "Escape still closes Present");
});

run("one overlay click listener however often Present redraws", () => {
  const w = sandbox();
  presentPin(w);
  w.TR.story2.live({ banner: "Dept" });
  w.TR.story2.live("reset");
  key(w, "ArrowRight"); key(w, "ArrowLeft");
  key(w, "Escape");
  w.TR.story2.presentFrom(1);
  eq((overlayOf(w).listeners.click || []).length, 1, "one listener");
});

run("a Total-only report offers Total and the pin's own custom banner", () => {
  const w = sandbox({ story: [qpin({ banner: "custom:Q2:detail", hiddenCols: [], sort: null })] });
  w.TR.AGG.banner_groups = [];
  presentPin(w, 0);
  const html = overlayOf(w).innerHTML;
  at(html, 'data-live-banner=""', "a Total button");
  at(html, TXT("story.live.total"), "worded by its key");
  at(html, 'data-live-banner="custom:Q2:detail" aria-pressed="true"', "the pin's own banner");
});

console.log("\n" + (failed ? "✗ " : "✓ ") + passed + " passed, " + failed + " failed");
if (failed) process.exit(1);
