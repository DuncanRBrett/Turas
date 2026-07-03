#!/usr/bin/env node
/**
 * Reader polish gate (READER_EXPERIENCE_PLAN bundle A) — five contracts:
 *
 * A1 Fixed card anatomy: every dashboard gauge renders fixed slots — score
 *    top-left / code top-right as FLEX SIBLINGS (nothing absolutely positioned
 *    over the score), band bar, 2-line-clamped title, ONE meta row holding the
 *    Δ chip + 💬 pill + 📌 pin (pin last).
 * A2 ShortLabel: q.short_label is consumed defensively (fallback to q.title)
 *    on cards, tracking metric names and default pin titles.
 * A3 Audience strip: the shell renders one aria-live strip on EVERY tab —
 *    cut + base n (+ weighted/effective when weighted) + wave; the Patterns
 *    and Tracking tabs state that they read the full published sample.
 * A4 One "How to read this" panel: the legend contains all five explains
 *    (sig letters incl. lowercase 80%, ▲▵ arrows, bands, precision, weighted
 *    bases); the dashboard PE box collapses to the ⓘ once seen (persisted).
 * A5 One number-format rule: fmt.score is THE mean/index display everywhere.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/reader_polish_tests.mjs
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

/* ---------------- sandbox A: views (gauge cards) + tracking format ---------------- */

function viewsSandbox() {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  vm.createContext(sb);
  load(sb, "00_namespace.js");
  load(sb, "01_format.js");
  load(sb, "20_data.js");                     // real d2.shortLabel
  const TR = sb.TR;
  TR.charts = { clip: (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + "…" : String(s)) };
  TR.render = {
    wavePoints: () => null,
    sparkline: () => "",
    deltaChip: (d) => (d ? '<span class="delta up">▲0.2</span>' : ""),
    currentYear: () => null
  };
  TR.qual = {
    affordanceHtml: (code) =>
      '<button class="ql-jumpbtn" data-qual-jump="' + code + '">💬 5 comments</button>'
  };
  TR.conf = {
    labels: () => ({ moe_name: "Precision Estimate", moe_abbrev: "PE",
      precision_term: "precision range", interval_abbrev: "SI", interval_term: "stability interval" }),
    maxMoePct: (n) => 98 / Math.sqrt(n),
    fmtRange: (a, b) => a + "–" + b
  };
  TR.reader = { peCollapsed: () => sb.__peCollapsed === true };
  TR.AGG = { project: {}, questions: [], banner_groups: [] };
  TR.PREV = null;
  load(sb, "25_cards.js");                    // waveLabels used by 27_views' intro
  load(sb, "27_views.js");
  load(sb, "27t_tracking.js");                // trk.fmtVal shares fmt.score
  return sb;
}

const Q_LONG_TITLE = "To what extent do you agree that the registration process provided a good educational experience overall?";
function gaugeFixture(overrides) {
  const q = Object.assign({
    code: "Q8", title: Q_LONG_TITLE, category: "Admin", scale_max: 10,
    rows: [{ kind: "mean", label: "Index" }]
  }, overrides || {});
  const model = {
    rows: [{ kind: "mean", label: "Index",
      cells: [{ mean: 8.2, ci: null }],
      delta: { diff: 0.2, isMean: true, sig: false } }],
    columns: [{ label: "Total", base: 200 }]
  };
  return { q, model };
}

console.log("Reader polish (bundle A) — suite:");

run("A1: gauge card renders the fixed slots in order — ghead(score,code) · bar · title · meta", () => {
  const sb = viewsSandbox();
  const { q, model } = gaugeFixture({ short_label: "Registration experience" });
  const html = sb.TR.views._gaugeCardHtml(q, model);
  const head = at(html, '<span class="ghead">', "head slot");
  const bar = at(html, '<span class="gbar">', "band bar slot");
  const title = at(html, '<span class="gt">', "title slot");
  const meta = at(html, '<span class="gmeta">', "meta row slot");
  assert(head < bar && bar < title && title < meta, "slots out of order");
  // score and code are flex SIBLINGS inside the head — nothing can overlap
  assert(html.indexOf('<span class="ghead"><span class="gv">') !== -1,
    "score is the first child of the head");
  const gv = at(html, '<span class="gv">', "score");
  const gq = at(html, '<span class="gq">', "code");
  assert(gv < gq && gq < bar, "code sits top-right within the head, before the bar");
});

run("A1: ONE meta row carries Δ chip + 💬 pill + 📌 pin, pin last", () => {
  const sb = viewsSandbox();
  const { q, model } = gaugeFixture();
  const html = sb.TR.views._gaugeCardHtml(q, model);
  const metaRow = html.slice(at(html, '<span class="gmeta">', "meta row"));
  const chip = at(metaRow, 'class="delta', "Δ chip in meta row");
  const pill = at(metaRow, "ql-jumpbtn", "💬 pill in meta row");
  const pin = at(metaRow, "snap-pin", "📌 pin in meta row");
  assert(chip < pill && pill < pin, "meta row order must be Δ · 💬 · 📌");
  // the pill/pin must NOT render inside the gauge button (over the score)
  const btnEnd = html.indexOf("</button>");
  assert(html.indexOf("ql-jumpbtn") > btnEnd, "pill is outside the gauge button");
});

run("A1: no absolutely-positioned pill/pin can overlap the score (CSS contract)", () => {
  assert(!/\.gauge-wrap \.ql-jumpbtn\s*\{[^}]*position:\s*absolute/.test(CSS),
    "the old absolute pill-over-score rule must be gone");
  assert(!/\.gauge-wrap \.snap-pin\s*\{[^}]*bottom:/.test(CSS),
    "the old absolute pin rule must be gone");
  const gt = CSS.match(/\.gauge \.gt\s*\{[^}]*\}/);
  assert(gt && gt[0].indexOf("-webkit-line-clamp: 2") !== -1,
    "the title clamps to 2 lines");
  assert(CSS.indexOf(".gmeta {") !== -1, "meta row style present");
});

run("A2: shortLabel fallback chain — analyst label wins, title otherwise", () => {
  const sb = viewsSandbox();
  const d2 = sb.TR.d2;
  eq(d2.shortLabel({ short_label: "Short", title: "Long" }), "Short", "short wins");
  eq(d2.shortLabel({ title: "Long" }), "Long", "falls back to title");
  eq(d2.shortLabel({ short_label: "   ", title: "Long" }), "Long", "blank short ignored");
  eq(d2.shortLabel(null), "", "null-safe");
});

run("A2: gauge card + pin title use short_label, tooltip keeps the full question", () => {
  const sb = viewsSandbox();
  const withShort = gaugeFixture({ short_label: "Registration experience" });
  const html = sb.TR.views._gaugeCardHtml(withShort.q, withShort.model);
  assert(html.indexOf('<span class="gt">Registration experience</span>') !== -1,
    "card title is the short label");
  assert(html.indexOf('data-snap-title="Q8 — Registration experience"') !== -1,
    "default pin title is the short label");
  assert(html.indexOf('title="' + Q_LONG_TITLE) !== -1, "tooltip keeps the full title");
  const noShort = gaugeFixture();
  const html2 = sb.TR.views._gaugeCardHtml(noShort.q, noShort.model);
  assert(html2.indexOf(Q_LONG_TITLE.slice(0, 40)) !== -1, "no short label -> title shown");
});

run("A2: exhibit default pin titles prefer the model's short_label", () => {
  const sb = viewsSandbox();
  load(sb, "30x_exhibit.js");
  const ex = sb.TR.exhibit;
  eq(ex.titleFor({}, [{ code: "Q8", title: "Long", short_label: "Short" }]),
    "Q8 — Short", "short label wins");
  eq(ex.titleFor({}, [{ code: "Q8", title: "Long" }]), "Q8 — Long", "fallback to title");
  eq(ex.titleFor({ title: "Analyst title" }, [{ code: "Q8", title: "Long" }]),
    "Analyst title", "explicit titles always win");
});

run("A5: one mean/index format — fmt.score shared by dashboard and tracking", () => {
  const sb = viewsSandbox();
  eq(sb.TR.fmt.score(8.2), "8.2", "1 decimal");
  eq(sb.TR.fmt.score(8), "8.0", "whole means keep the decimal");
  eq(sb.TR.fmt.score(null), "–", "null is an en dash");
  eq(sb.TR.trk.fmtVal(8, true), "8.0", "tracking means use the same rule");
  eq(sb.TR.trk.fmtVal(41.6, false), "42%", "percentages unchanged");
  const { q, model } = gaugeFixture();
  assert(sb.TR.views._gaugeCardHtml(q, model).indexOf('<span class="gv">8.2') !== -1,
    "gauge score uses fmt.score");
});

run("A4: dashboard PE box — full sentence first, ⓘ once seen", () => {
  const sb = viewsSandbox();
  const qs = [{ code: "Q8" }];
  const heatModels = { Q8: { columns: [{ label: "Total", base: 400 },
    { label: "Durban", base: 49 }] } };
  sb.__peCollapsed = false;
  const full = sb.TR.views._moeChipHtml(qs, heatModels);
  assert(full.indexOf("stable to about ±") !== -1, "first view shows the full sentence");
  assert(full.indexOf("Durban") !== -1, "names the smallest cut");
  sb.__peCollapsed = true;
  const collapsed = sb.TR.views._moeChipHtml(qs, heatModels);
  assert(collapsed.indexOf("data-legend-open") !== -1, "collapsed to the ⓘ trigger");
  assert(collapsed.indexOf("stable to about") === -1, "long sentence gone once seen");
});

/* ---------------- sandbox B: reader (strip + legend + persistence) ---------------- */

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
  const TR = sb.TR;
  TR.charts = { clip: (s, n) => (String(s).length > n ? String(s).slice(0, n - 1) + "…" : String(s)) };
  TR.AGG = { project: opts.project || { wave: "Wave 2 - Jun 2026" },
    questions: opts.questions || [], banner_groups: [] };
  TR.MICRO = opts.micro !== undefined ? opts.micro : { n: 4, answers: {} };
  TR.d2 = {
    state: { tab: "dashboard", banner: "", filters: opts.filters || [] },
    filterDescription: () => "Q6: Female",
    bannerDescription: () => "Composite banner — Leaders (2 groups vs the rest)",
    hasMicrodata: () => !!(TR.MICRO && TR.MICRO.answers),
    storeKey: (base) => base + ":proj"
  };
  TR.stats = {
    mask: () => opts.mask || [1, 1, 0, 0],
    maskCount: (m) => m.reduce((a, b) => a + b, 0)
  };
  TR.disclosure = { audienceBase: () => (TR.d2.state.filters.length
    ? TR.stats.maskCount(TR.stats.mask()) : (TR.MICRO ? TR.MICRO.n : null)) };
  TR.conf = { labels: () => ({ moe_name: "Precision Estimate", moe_abbrev: "PE" }),
    maxMoePct: (n) => 98 / Math.sqrt(n) };
  load(sb, "26_filter.js");                   // real weightingNote feeds the panel
  load(sb, "24a_reader.js");
  return sb;
}

run("A3: strip under a filter — cut + live n + wave", () => {
  const sb = readerSandbox({ filters: [{ q: "Q6", rows: [1] }] });
  const html = sb.TR.reader.audienceStripHtml("dashboard");
  assert(html.indexOf("Q6: Female") !== -1, "names the cut");
  assert(html.indexOf("n=2") !== -1, "live audience base");
  assert(html.indexOf("Wave 2 - Jun 2026") !== -1, "wave label present");
});

run("A3: strip with no filter — Everyone + full n", () => {
  const html = readerSandbox({}).TR.reader.audienceStripHtml("crosstabs");
  assert(html.indexOf("Everyone") !== -1, "unfiltered cut is Everyone");
  assert(html.indexOf("n=4") !== -1, "full sample base");
});

run("A3: Patterns tab states the full published sample even when a filter is live", () => {
  const sb = readerSandbox({ filters: [{ q: "Q6", rows: [1] }] });
  const html = sb.TR.reader.audienceStripHtml("takeout");
  assert(html.indexOf("full published sample") !== -1, "says full sample");
  assert(html.indexOf("does not apply") !== -1, "says the filter does not apply");
  assert(html.indexOf("Q6: Female") === -1, "never shows the (ignored) cut");
  assert(html.indexOf("n=4") !== -1, "full-sample n, not the filtered n");
  const trk = sb.TR.reader.audienceStripHtml("moved");
  assert(trk.indexOf("full published sample") !== -1, "tracking states it too");
});

run("A3: weighted report — strip adds weighted + effective bases for the cut", () => {
  const sb = readerSandbox({
    project: { weighted: true, wave: "W2" },
    micro: { n: 4, answers: {}, weights: [2, 2, 1, 1] },
    filters: [{ q: "Q6", rows: [1] }], mask: [1, 1, 0, 0]
  });
  const html = sb.TR.reader.audienceStripHtml("dashboard");
  assert(html.indexOf("n=2") !== -1, "unweighted n");
  assert(html.indexOf("weighted 4") !== -1, "Σw of the masked audience");
  assert(html.indexOf("effective 2") !== -1, "Kish n_eff of the masked audience");
  // patterns strip uses the FULL sample weights
  const pat = sb.TR.reader.audienceStripHtml("takeout");
  assert(pat.indexOf("weighted 6") !== -1, "full-sample Σw on Patterns");
});

run("A3: shell renders the strip on every tab, aria-live polite", () => {
  const shellSrc = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
  assert(shellSrc.indexOf('id="audstrip"') !== -1, "strip container in the frame");
  assert(/id="audstrip"[^>]*aria-live="polite"/.test(shellSrc), "aria-live polite");
  assert(shellSrc.indexOf("TR.reader.renderStrip()") !== -1, "route() refreshes the strip");
});

run("A4: legend panel contains all five explains", () => {
  const sb = readerSandbox({ project: { weighted: true, weight_variable: "wt" },
    questions: [{ code: "Q8", bases: [{ n: 400 }] }] });
  const html = sb.TR.reader.legendHtml();
  assert(html.indexOf("lowercase letters = 80%") !== -1, "1: sig letters incl. 80%");
  assert(html.indexOf("▵ / ▿") !== -1 && html.indexOf("▲ / ▼") !== -1, "2: ▲▵ arrows");
  assert(html.indexOf("strong ≥75%") !== -1 && html.indexOf("moderate 50–74%") !== -1 &&
    html.indexOf("weak") !== -1, "3: bands");
  assert(html.indexOf("Precision Estimate") !== -1 &&
    html.indexOf("stable to about ±") !== -1, "4: precision sentence");
  assert(html.indexOf("Weighted data") !== -1 &&
    html.indexOf("Effective base") !== -1, "5: weighted/effective base note");
});

run("A4: PE collapse persists per report — expanded all first session, ⓘ after", () => {
  const storage = {};
  const first = readerSandbox({ storage });
  eq(first.TR.reader.peCollapsed(), false, "first ever view stays expanded");
  eq(first.TR.reader.peCollapsed(), false, "stays expanded for the WHOLE session");
  eq(storage["v2pe_seen:proj"], "1", "seen flag persisted under the report's storeKey");
  const second = readerSandbox({ storage });
  eq(second.TR.reader.peCollapsed(), true, "next session collapses to the ⓘ");
});

run("A4: every ⓘ trigger opens the ONE panel (shell delegate + crosstabs footer)", () => {
  const shellSrc = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
  assert(shellSrc.indexOf("data-legend-open") !== -1, "header ⓘ present");
  assert(shellSrc.indexOf("TR.reader.openLegend()") !== -1, "delegated open handler");
  const cardsSrc = readFileSync(path.join(JS_DIR, "25_cards.js"), "utf8");
  assert(cardsSrc.indexOf("data-legend-open") !== -1, "crosstabs footer links the panel");
  assert(cardsSrc.indexOf("lowercase = 80%") === -1,
    "the duplicated sig-letter legend is gone from the crosstabs footer");
});

console.log("\n" + (failed ? "✗ " + failed + " failed, " : "✓ ") + passed + " passed");
process.exit(failed ? 1 : 0);
