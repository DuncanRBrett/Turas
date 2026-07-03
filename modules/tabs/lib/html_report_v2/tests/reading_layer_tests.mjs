#!/usr/bin/env node
/**
 * Reading layer gate (READER_EXPERIENCE_PLAN bundle B) — three contracts:
 *
 * B1 Read vs Analyse navigation: the tab bar renders two groups — READ
 *    (Dashboard · Patterns · Tracking · Qualitative · Story) then ANALYSE
 *    (Crosstabs · Differences · Report) — with a divider and aria-hidden
 *    group labels; conditional tabs stay conditional; the tab ids (and so
 *    every saved-copy #hash deep link) are unchanged.
 * B2 Plain-language significance: a reader toggle (legend dialog + a compact
 *    control by the sig-mode select) that turns sig letters, composite arrows
 *    and Δ chips into focusable plain sentences built from the model — level
 *    text derives from project.alpha (never hard-coded 95/80). Default ON for
 *    saved copies (user-state island present), OFF analyst-fresh; the
 *    reader's persisted choice owns once set.
 * B3 Insight titles on cards: q.headline (analyst-authored) leads the
 *    dashboard card and crosstab question header; else the first sentence of
 *    a stored analyst insight, clearly marked; else nothing.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/reading_layer_tests.mjs
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
/** indexOf that refuses -1 — asserts presence AND returns the position. */
function at(hay, needle, msg) {
  const i = hay.indexOf(needle);
  if (i === -1) throw new Error(msg + ": missing " + JSON.stringify(needle));
  return i;
}

/* ---------------- sandbox: shell (tab groups) ---------------- */

function shellSandbox(opts) {
  opts = opts || {};
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  sb.TR = {
    fmt: { escapeHtml: (s) => String(s == null ? "" : s) },
    AGG: { project: opts.project || {} },
    d2: {
      tracking: () => ({ enabled: !!opts.tracking }),
      qualitative: () => ({ enabled: !!opts.qual })
    }
  };
  vm.createContext(sb);
  load(sb, "24_shell.js");
  return sb;
}

console.log("Reading layer (bundle B) — suite:");

run("B1: full report — READ group first, ANALYSE after, exact order", () => {
  const sb = shellSandbox({ tracking: true, qual: true });
  eq(sb.TR.shell.tabGroups(), [
    { label: "Read", tabs: [["dashboard", "Dashboard"], ["takeout", "Patterns"],
      ["moved", "Tracking"], ["qualitative", "Qualitative"], ["story", "Story"]] },
    { label: "Analyse", tabs: [["crosstabs", "Crosstabs"],
      ["findings", "Differences"], ["report", "Report"]] }
  ], "grouped tab list");
});

run("B1: conditional tabs stay conditional (tracking/qual/flagged-off)", () => {
  const bare = shellSandbox({}).TR.shell.tabGroups();
  eq(bare[0].tabs.map((t) => t[0]), ["dashboard", "takeout", "story"],
    "no tracking island / no qual island -> tabs absent");
  const flagged = shellSandbox({ tracking: true, qual: true,
    project: { tabs: { patterns: false, dashboard: false, differences: false } } })
    .TR.shell.tabGroups();
  eq(flagged[0].tabs.map((t) => t[0]), ["moved", "qualitative", "story"],
    "flag-gated READ tabs removed");
  eq(flagged[1].tabs.map((t) => t[0]), ["crosstabs", "report"],
    "Differences flag-gated; Crosstabs/Report always present");
});

run("B1: nav HTML — one divider, aria-hidden group labels, tab semantics intact", () => {
  const sb = shellSandbox({ tracking: true, qual: true });
  const html = sb.TR.shell._tabsNavHtml();
  assert(html.indexOf('<nav class="tabs" role="tablist">') === 0, "role=tablist preserved");
  const readLbl = at(html, '<span class="tabgrp-label" aria-hidden="true">Read</span>', "Read label");
  const sep = at(html, '<span class="tabsep" aria-hidden="true"></span>', "divider");
  const anaLbl = at(html, '<span class="tabgrp-label" aria-hidden="true">Analyse</span>', "Analyse label");
  assert(readLbl < sep && sep < anaLbl, "divider sits between the groups");
  eq(html.split('class="tabsep"').length - 1, 1, "exactly ONE divider");
  const story = at(html, 'data-tab="story"', "story tab");
  const xtabs = at(html, 'data-tab="crosstabs"', "crosstabs tab");
  assert(story < sep && sep < xtabs, "reading surfaces before the divider, analyse after");
  assert(html.indexOf('<span class="count" id="story-count">0</span>') !== -1,
    "story count badge survives");
  eq(html.split('role="tab"').length - 1, 8, "every button keeps role=tab");
  assert(html.indexOf('aria-selected="false"') !== -1, "aria-selected wiring unchanged");
});

run("B1: hash deep links keep working — ids unchanged, decode round-trips", () => {
  const sb = shellSandbox({ tracking: true, qual: true });
  // every id the grouped bar emits is still routed by shell.route (source-level)
  const shellSrc = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
  const ids = sb.TR.shell.tabGroups().reduce((a, g) => a.concat(g.tabs.map((t) => t[0])), []);
  ids.forEach((id) => {
    assert(id === "report" || shellSrc.indexOf('d2.state.tab === "' + id + '"') !== -1,
      "route() still handles tab id " + id);
  });
  // a saved-copy deep link decodes to the same state as before
  const ds = { console };
  ds.globalThis = ds; ds.window = ds;
  ds.TR = { fmt: { slug: (s) => s } };
  vm.createContext(ds);
  load(ds, "00_namespace.js");
  load(ds, "20_data.js");
  ds.TR.AGG = { questions: [], columns: [] };
  ds.TR.d2.decodeHash("#tab=findings&q=Q8&banner=Q002");
  eq(ds.TR.d2.state.tab, "findings", "tab id resolves");
  eq(ds.TR.d2.state.activeQ, "Q8", "question deep link resolves");
  ds.TR.d2.decodeHash("#tab=qualitative&qq=Q9");
  eq(ds.TR.d2.state.tab, "qualitative", "qual route resolves");
  eq(ds.TR.d2.state.qualQ, "Q9", "qual focus resolves");
});

/* ---------------- sandbox: reader (B2 sentences + B3 titles) ---------------- */

function readerSandbox(opts) {
  opts = opts || {};
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  if (opts.storage) {
    sb.localStorage = {
      getItem: (k) => (k in opts.storage ? opts.storage[k] : null),
      setItem: (k, v) => { opts.storage[k] = String(v); }
    };
  }
  vm.createContext(sb);
  load(sb, "00_namespace.js");
  load(sb, "01_format.js");
  load(sb, "21_stats.js");                       // real alphaPrimary/Secondary
  const TR = sb.TR;
  TR.AGG = { project: opts.project || {}, questions: [], banner_groups: [] };
  TR.userState = opts.userState !== undefined ? opts.userState : null;
  TR.d2 = { storeKey: (b) => b + ":proj", state: { tab: "dashboard", banner: "", filters: [] } };
  TR.conf = { labels: () => ({ moe_name: "Precision Estimate", moe_abbrev: "PE" }),
    maxMoePct: (n) => 98 / Math.sqrt(n) };
  load(sb, "24a_reader.js");
  if (opts.insights) {
    load(sb, "28_insights.js");
    Object.keys(opts.insights).forEach((k) => TR.insights.set(k, opts.insights[k]));
  }
  return sb;
}

// Durban is column A carrying letters BC; values resolve from the SAME row.
const LETTER_MODEL = {
  composite: false, lowBaseThreshold: 30,
  columns: [
    { label: "Total", letter: "", base: 300, low: false },
    { label: "Durban", letter: "A", base: 100, low: false },
    { label: "Male", letter: "B", base: 100, low: false },
    { label: "Cape Town", letter: "C", base: 100, low: false }
  ],
  rows: [{ kind: "category", label: "Satisfied", cells: [
    { pct: 74, n: 222, sig: "" }, { pct: 62, n: 62, sig: "BC" },
    { pct: 44, n: 44, sig: "" }, { pct: 51, n: 51, sig: "" }] }]
};

run("B2: letters case — exact sentence, letters resolved to labels + values", () => {
  const reader = readerSandbox({}).TR.reader;
  eq(reader.letterSentence(LETTER_MODEL, LETTER_MODEL.rows[0], 1),
    "Durban (62%) is meaningfully higher than Male (44%) and Cape Town (51%) " +
    "at the report's 95% level.", "letters sentence");
});

run("B2: lowercase-80 case with alpha 0.10 — level text derives from config", () => {
  const sb = readerSandbox({ project: { alpha: 0.10 } });
  const model = JSON.parse(JSON.stringify(LETTER_MODEL));
  model.rows[0].cells[1].sig = "b";
  const s = sb.TR.reader.letterSentence(model, model.rows[0], 1);
  eq(s, "Durban (62%) is higher than Male (44%) at the weaker 80% level " +
    "(directional) — not at the report's 90% level.", "lowercase sentence");
  assert(s.indexOf("95") === -1, "no hard-coded 95 anywhere with alpha 0.10");
  // both levels move with config: secondary 0.30 -> 70%
  const sb2 = readerSandbox({ project: { alpha: 0.10, alpha_secondary: 0.30 } });
  assert(sb2.TR.reader.letterSentence(model, model.rows[0], 1)
    .indexOf("weaker 70% level") !== -1, "secondary level from alpha_secondary");
});

run("B2: mixed upper+lower letters — one sentence per level", () => {
  const reader = readerSandbox({}).TR.reader;
  const model = JSON.parse(JSON.stringify(LETTER_MODEL));
  model.rows[0].cells[1].sig = "Bc";
  eq(reader.letterSentence(model, model.rows[0], 1),
    "Durban (62%) is meaningfully higher than Male (44%) at the report's 95% level. " +
    "It is also higher than Cape Town (51%) at the weaker 80% level (directional).",
    "dual-level sentence");
});

run("B2: arrow case — composite vs-the-rest, solid primary / hollow secondary", () => {
  const reader = readerSandbox({}).TR.reader;
  const model = JSON.parse(JSON.stringify(LETTER_MODEL));
  model.composite = true;
  model.rows[0].cells[1].sig = "▼";
  eq(reader.arrowSentence(model, model.rows[0], 1),
    "Durban (62%) is meaningfully lower than the rest of the sample at the " +
    "report's 95% level.", "solid arrow sentence");
  model.rows[0].cells[1].sig = "▵";
  eq(reader.arrowSentence(model, model.rows[0], 1),
    "Durban (62%) is higher than the rest of the sample at the weaker 80% " +
    "level (directional).", "hollow arrow sentence");
});

run("B2: Δ chip sentence — wave named from the data, sig vs noise wording", () => {
  const reader = readerSandbox({}).TR.reader;
  eq(reader.deltaSentence({ prev: 58, diff: 4, isMean: false, sig: true, wave: "2025 H1" }),
    "This wave (62%) is meaningfully higher than 2025 H1 (58%) at the report's 95% level.",
    "significant change");
  eq(reader.deltaSentence({ prev: 8.4, diff: -0.2, isMean: true, sig: false, wave: "2025" }),
    "This wave (8.2) is lower than 2025 (8.4), but the change is within the " +
    "survey's noise — not significant at the report's 95% level.", "non-sig change");
});

run("B2: default ON for saved copies, OFF analyst-fresh; persisted choice owns", () => {
  eq(readerSandbox({ userState: { insights: {} } }).TR.reader.explainOn(), true,
    "saved copy (user-state island) defaults ON");
  eq(readerSandbox({}).TR.reader.explainOn(), false, "analyst-fresh defaults OFF");
  const storage = {};
  const first = readerSandbox({ userState: { insights: {} }, storage });
  first.TR.reader.setExplain(false);
  eq(first.TR.reader.explainOn(), false, "toggle wins immediately");
  eq(storage["v2explain_sig:proj"], "0", "persisted under the report's storeKey");
  eq(readerSandbox({ userState: { insights: {} }, storage }).TR.reader.explainOn(),
    false, "reader's stored choice OWNS the saved-copy default next session");
  storage["v2explain_sig:proj"] = "1";
  eq(readerSandbox({ storage }).TR.reader.explainOn(), true,
    "stored ON also owns the analyst-fresh default");
});

/* ---------------- render integration (23_render.js hooks) ---------------- */

function renderSandbox(opts) {
  const sb = readerSandbox(opts);
  load(sb, "23_render.js");
  return sb;
}

run("B2: explain ON — sig cell becomes a focusable tooltip carrying the sentence", () => {
  const sb = renderSandbox({ userState: {} });
  const html = sb.TR.render.tableHtml(LETTER_MODEL, {});
  const span = at(html, '<span class="sg xpl" tabindex="0" data-explain="', "focusable sig span");
  assert(html.indexOf("Durban (62%) is meaningfully higher than Male (44%) and " +
    "Cape Town (51%) at the report&#39;s 95% level.") !== -1,
    "the sentence rides in the attribute (escaped)");
  const label = at(html, 'aria-label="Durban (62%)', "aria-label for keyboard/AT focus");
  assert(span < label, "attributes on the same span");
  assert(html.indexOf('title="Significantly higher than column(s)') === -1,
    "analyst-speak title replaced while explaining");
});

run("B2: explain OFF — legacy markup byte-identical (letters, arrows, chips)", () => {
  const sb = renderSandbox({});
  const html = sb.TR.render.tableHtml(LETTER_MODEL, {});
  assert(html.indexOf('<span class="sg" title="Significantly higher than column(s) BC">▲BC</span>') !== -1,
    "legacy letters span unchanged");
  assert(html.indexOf("data-explain") === -1, "no tooltip attributes when off");
  const chip = sb.TR.render.deltaChip({ prev: 58, diff: 4, isMean: false, sig: true, year: 2025 });
  assert(chip.indexOf('title="2025: 58% · significant change"') !== -1,
    "legacy Δ chip title unchanged");
});

run("B2: explain ON — composite arrows and Δ chips carry sentences too", () => {
  const sb = renderSandbox({ userState: {} });
  const model = JSON.parse(JSON.stringify(LETTER_MODEL));
  model.composite = true;
  model.rows[0].cells[1].sig = "▼";
  const html = sb.TR.render.tableHtml(model, {});
  assert(html.indexOf('class="sg dn xpl" tabindex="0"') !== -1, "arrow span focusable");
  assert(html.indexOf("meaningfully lower than the rest of the sample") !== -1,
    "arrow sentence present");
  const chip = sb.TR.render.deltaChip({ prev: 58, diff: 4, isMean: false, sig: true, wave: "2025" });
  assert(chip.indexOf('tabindex="0"') !== -1 && chip.indexOf("data-explain=") !== -1,
    "Δ chip focusable with a sentence");
  assert(chip.indexOf("This wave (62%) is meaningfully higher than 2025 (58%)") !== -1,
    "Δ sentence from the delta's own data");
});

run("B2: toggle lives in the legend dialog AND by the sig-mode control; tooltip never blocks clicks", () => {
  const sb = readerSandbox({});
  const legend = sb.TR.reader.legendHtml();
  assert(legend.indexOf("data-explain-toggle") !== -1, "legend checkbox present");
  assert(legend.indexOf("Explain significance in plain language") !== -1, "legend copy");
  const cardsSrc = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  const sig = at(cardsSrc, "data-sigmode>", "sig-mode select");
  const tgl = at(cardsSrc, "data-explain-sig", "compact Explain toggle");
  assert(tgl > sig && tgl - sig < 700, "toggle sits by the sig-mode control");
  assert(cardsSrc.indexOf("TR.reader.setExplain(e.target.checked)") !== -1,
    "toggle wired to the shared store");
  const xpl = CSS.match(/\.xpl:hover::after[^{]*\{[^}]*\}/);
  assert(xpl && xpl[0].indexOf("pointer-events: none") !== -1,
    "tooltip bubble is pointer-events none (click-through)");
  assert(xpl[0].indexOf("content: attr(data-explain)") !== -1, "bubble reads the sentence");
  assert(/\.xpl:hover::after, \.xpl:focus::after/.test(CSS), "shows on keyboard focus too");
});

/* ---------------- B3: insight titles ---------------- */

run("B3: fallback chain — headline wins, insight first sentence next, else null", () => {
  const sb = readerSandbox({ insights: { Q8: "Registration drags scores down. Fix the queue first." } });
  const reader = sb.TR.reader;
  eq(reader.insightTitle({ code: "Q8", headline: "Registration is the pain point" }),
    { text: "Registration is the pain point", source: "headline" },
    "headline always wins");
  eq(reader.insightTitle({ code: "Q8" }),
    { text: "Registration drags scores down.", source: "insight" },
    "first sentence of the stored insight, marked as insight");
  eq(reader.insightTitle({ code: "Q9" }), null, "nothing -> null (no auto-sentences)");
  eq(reader.insightTitle(null), null, "null-safe");
});

run("B3: crosstab header — insight leads, question drops to the secondary line", () => {
  const sb = readerSandbox({ insights: { Q7: "Course choice splits the campuses. More detail here." } });
  const TR = sb.TR;
  load(sb, "25_cards.js");
  const qs = {
    Q8: { code: "Q8", headline: "Registration is the pain point", title: "How was registration?" },
    Q7: { code: "Q7", title: "Which course?" },
    Q6: { code: "Q6", title: "Plain question" }
  };
  TR.d2.questionByCode = (c) => qs[c] || null;
  eq(TR.cards2._titleHtml({ code: "Q8", title: "How was registration?" }),
    '<h2 class="qh-insight">Registration is the pain point</h2>' +
    '<div class="qh-question">How was registration?</div>', "headline over title");
  eq(TR.cards2._titleHtml({ code: "Q7", title: "Which course?" }),
    '<h2 class="qh-insight">Course choice splits the campuses.' +
    ' <span class="qh-src">analyst insight</span></h2>' +
    '<div class="qh-question">Which course?</div>', "marked insight fallback");
  eq(TR.cards2._titleHtml({ code: "Q6", title: "Plain question" }),
    "<h2>Plain question</h2>", "no insight -> plain header unchanged");
});

run("B3: dashboard card — insight line above the question line, anatomy intact", () => {
  const sb = readerSandbox({ insights: { Q8: "Strong scores. Detail follows." } });
  const TR = sb.TR;
  TR.charts = { clip: (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + "…" : String(s)) };
  TR.render = { wavePoints: () => null, sparkline: () => "", deltaChip: () => "" };
  TR.qual = { affordanceHtml: () => "" };
  TR.conf = { labels: () => ({ interval_abbrev: "SI" }), fmtRange: (a, b) => a + "–" + b };
  TR.d2.shortLabel = (q) => q.short_label || q.title;
  load(sb, "27_views.js");
  const model = { rows: [{ kind: "mean", label: "Index", cells: [{ mean: 8.2 }] }],
    columns: [{ label: "Total", base: 200 }] };
  const withHeadline = TR.views._gaugeCardHtml(
    { code: "Q9", title: "Long question", headline: "The one-line takeout", scale_max: 10, rows: [] }, model);
  const gi = at(withHeadline, '<span class="gi">The one-line takeout</span>', "insight line");
  const gt = at(withHeadline, '<span class="gt">', "question line");
  const meta = at(withHeadline, '<span class="gmeta">', "meta row");
  assert(gi < gt && gt < meta, "insight ABOVE the question line, meta row last");
  assert(withHeadline.indexOf("gi-src") === -1, "headline is unmarked");
  const fromInsight = TR.views._gaugeCardHtml(
    { code: "Q8", title: "Long question", scale_max: 10, rows: [] }, model);
  assert(fromInsight.indexOf('<span class="gi">Strong scores.' +
    ' <span class="gi-src">analyst insight</span></span>') !== -1,
    "insight fallback is clearly marked");
  const none = TR.views._gaugeCardHtml(
    { code: "Q1", title: "Long question", scale_max: 10, rows: [] }, model);
  assert(none.indexOf('class="gi"') === -1, "no insight -> no line, never auto-generated");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
