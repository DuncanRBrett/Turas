#!/usr/bin/env node
/**
 * Gate: the MaxDiff tab carries the classic HTML report's panels.
 *
 * Section 6 of HANDOVER_MAXDIFF_V2_FOLLOWUPS_FOR_OPUS.md brings the tab to
 * parity with the classic report so that report can be retired. The content
 * enumeration is docs/v2_lift/MAXDIFF_PARITY_CHECKLIST.md; this gate is the
 * executable half of it.
 *
 * Panels under test: model diagnostics, head-to-head win rates, per-segment
 * item scores, per-item utility distributions, and the four charts redrawn in
 * the v2 report's own SVG rather than ported from the classic chart builder
 * (Duncan's ruling, 17 Sep 2026).
 *
 * Runs against the SHIPPED module JS (modules/tabs/lib/html_report_v2/assets/js).
 *
 * Run with:  node modules/tabs/tests/js/test_maxdiff_parity_panels.mjs
 */
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/tabs/lib/html_report_v2/assets/js");

function makeTarget() {
  const listeners = {};
  return {
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    removeEventListener() {},
    dispatch(type, ev) { (listeners[type] || []).forEach((f) => f(ev || {})); },
  };
}
const elStub = () => ({
  className: "", style: {}, innerHTML: "", textContent: "", children: [],
  appendChild() {}, remove() {}, closest: () => null, addEventListener() {},
  querySelector: () => null, querySelectorAll: () => [],
});
const documentStub = Object.assign(makeTarget(), {
  body: Object.assign(elStub(), { appendChild() {} }),
  createElement: elStub, getElementById: () => null,
  querySelector: () => null, querySelectorAll: () => [],
});
const sandbox = Object.assign(makeTarget(), {
  console, TextEncoder, URL, document: documentStub,
  getSelection: () => ({ isCollapsed: true, rangeCount: 0 }),
});
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
for (const f of readdirSync(JS).filter((x) => x.endsWith(".js")).sort()) {
  vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
}

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; console.log("  ✓ " + m); } else { fail++; console.log("  ✗ " + m); } };

const ITEMS = ["Fresh", "Cheap", "Local", "Strong"];
const IDS = ITEMS.map((_, i) => "ITEM0" + (i + 1));

/** The upper triangle, the shape .maxdiff_island_head_to_head() writes. */
function h2h() {
  const rowItem = [], colItem = [], prob = [];
  const table = { "0-1": 62.5, "0-2": 71.2, "0-3": 80.4,
                  "1-2": 58.1, "1-3": 66.9, "2-3": 59.3 };
  for (let i = 0; i < IDS.length; i++) {
    for (let j = i + 1; j < IDS.length; j++) {
      rowItem.push(IDS[i]); colItem.push(IDS[j]); prob.push(table[i + "-" + j]);
    }
  }
  return { rowItem, colItem, prob, source: "individual",
           note: "Each win rate is the average, across respondents, of the probability." };
}

/** Long form, the shape .maxdiff_island_segments() writes. */
function segments(opts) {
  const o = opts || {};
  const spec = [
    { variable: "Age", level: "18-34", base: 180 },
    { variable: "Age", level: "35+", base: o.thinLevel ? 12 : 120 },
    { variable: "Region", level: "North", base: 150 },
    { variable: "Region", level: "South", base: 150 },
  ];
  const out = { variable: [], segmentId: [], level: [], base: [], itemId: [],
                netScore: [], bestPct: [], worstPct: [],
                minBase: 50, note: "Segment scores are count-based." };
  spec.forEach(function (g, gi) {
    IDS.forEach(function (id, i) {
      out.variable.push(g.variable);
      out.segmentId.push(g.variable === "Age" ? "S1" : "S2");
      out.level.push(g.level);
      out.base.push(g.base);
      out.itemId.push(id);
      out.netScore.push(46.7 - i * 15 + gi * 3);
      out.bestPct.push(50 - i * 11 + gi);
      out.worstPct.push(3.3 + i * 6);
    });
  });
  return out;
}

/** Flat densities with a stride, the shape .maxdiff_island_distributions() writes. */
function distributions(opts) {
  const o = opts || {};
  const K = 16;
  const mean = [1.5, 1.0, 0.5, 0.2];
  const sd = [0.81, 1.42, 0.63, 0.55];
  const out = { itemId: IDS, nPoints: K, mean: [], median: [], sd: [],
                q25: [], q75: [], min: [], max: [], densityX: [], densityY: [],
                note: "Each shape is the spread of one item's utility across respondents." };
  IDS.forEach(function (_, i) {
    // The reference item is fixed at zero, so the island blanks its shape.
    const blank = o.refBlank !== false && i === IDS.length - 1;
    out.mean.push(blank ? null : mean[i]);
    out.median.push(blank ? null : mean[i]);
    out.sd.push(blank ? null : sd[i]);
    out.q25.push(blank ? null : mean[i] - 0.67 * sd[i]);
    out.q75.push(blank ? null : mean[i] + 0.67 * sd[i]);
    out.min.push(blank ? null : mean[i] - 2.5 * sd[i]);
    out.max.push(blank ? null : mean[i] + 2.5 * sd[i]);
    for (let k = 0; k < K; k++) {
      if (blank) { out.densityX.push(null); out.densityY.push(null); continue; }
      const x = mean[i] - 3 * sd[i] + (6 * sd[i] * k) / (K - 1);
      const z = (x - mean[i]) / sd[i];
      out.densityX.push(x);
      out.densityY.push(Math.exp(-0.5 * z * z) / (sd[i] * Math.sqrt(2 * Math.PI)));
    }
  });
  return out;
}

function turf() {
  return {
    thresholdMethod: "ABOVE_MEAN", nRespondents: 300, maxItems: 4,
    step: [1, 2, 3], itemId: IDS.slice(0, 3), label: ITEMS.slice(0, 3),
    reachPct: [62.4, 81.9, 88.2], incrementalPct: [62.4, 19.5, 6.3],
    note: "Reach is the share of respondents for whom at least one item appeals.",
  };
}

function anchor() {
  return {
    variable: "MustHave", threshold: 0.5, itemId: IDS, label: ITEMS,
    rate: [0.78, 0.61, 0.33, 0.12], count: [234, 183, 99, 36],
    isMustHave: [true, true, false, false],
  };
}

function island(opts) {
  const o = opts || {};
  const d = {
    meta: {
      schema: 1, kind: "maxdiff", projectName: "ParityGate",
      method: "stan_hb", methodLabel: "Stan hierarchical Bayes",
      estimationNote: "Individual utilities are posterior means.",
      nRespondents: 300, nTasks: 10, nItems: 4, itemsPerTask: 3,
      nDivergences: 0, maxTreedepthExceeded: 0, meanRhat: 1.0009, minEss: 8675,
      weighted: false, weightingNote: "Unweighted.", frozen: true,
      filterNote: "MaxDiff results are estimated once on the whole sample.",
    },
    scores: {
      itemId: IDS, label: ITEMS,
      bestPct: [50, 33.3, 25, 16.7], worstPct: [3.3, 6.7, 13.3, 20],
      netScore: [46.7, 26.7, 11.7, -3.3],
      hbUtility: [1.5, 1.0, 0.5, 0.2], hbSpread: [0.81, 1.42, 0.63, 0.55],
      share: [40, 28, 19, 13],
    },
  };
  if (o.diagnostics !== null) {
    d.diagnostics = Object.assign({
      nSegments: 2,
      logLikelihood: -1204.7, aic: 2421.4, bic: 2455.9, pseudoR2: 0.312,
      utilityRange: 1.3, meanUtility: 0.55, utilitySd: 0.853,
      discrimination: 0.325,
      meanMaxShare: 44.2, chanceLevel: 25, sharpnessRatio: 1.8,
      entropyRatio: 0.742, heterogeneity: 0.853,
      meanRespondentRange: 2.41, minRespondentRange: 0.62,
      maxRespondentRange: 5.13,
    }, o.diagnostics || {});
  }
  if (o.headToHead !== null) d.headToHead = o.headToHead || h2h();
  if (o.segments !== null) d.segments = o.segments || segments();
  if (o.distributions !== null) d.distributions = o.distributions || distributions();
  if (o.turf !== null) d.turf = o.turf || turf();
  if (o.anchor !== null) d.anchor = o.anchor || anchor();
  return d;
}

function render(opts) {
  sandbox.TR.MD = island(opts);
  const host = { innerHTML: "" };
  sandbox.TR.maxdiff.render(host);
  return host.innerHTML;
}

// --- Diagnostics panel --------------------------------------------------------
let html = render();
ok(/Model diagnostics/i.test(html), "the tab has a model diagnostics panel");
ok(/1\.80|1\.8(?!\d)/.test(html), "the sharpness ratio reaches the panel");
ok(/0\.742/.test(html), "the entropy ratio reaches the panel");
ok(/0\.853/.test(html), "heterogeneity reaches the panel");
ok(/2\.41/.test(html), "the mean respondent utility range reaches the panel");
ok(/44\.2/.test(html), "the mean maximum share reaches the panel");
const diagSection = (html.match(/<section[^>]*>(?:(?!<\/section>)[\s\S])*?Model diagnostics[\s\S]*?<\/section>/i) || [""])[0];
ok(/Chance is 25\.0%/.test(diagSection),
   "the chance level sits beside the top-item share, so the reader can compare them");
ok(/-1204\.7|−1204\.7|1204\.7/.test(html),
   "the log-likelihood reaches the panel: the classic report read a key that never existed");
ok(/2421\.4/.test(html), "AIC reaches the panel");
ok(/0\.312/.test(html), "the pseudo R-squared reaches the panel");

html = render({ diagnostics: null });
ok(!/Model diagnostics/i.test(html),
   "no diagnostics block means no diagnostics panel, not an empty one");

// --- Head-to-head panel -------------------------------------------------------
html = render();
ok(/Head-to-head/i.test(html), "the tab has a head-to-head panel");
const h2hSection = (html.match(/<section[^>]*>(?:(?!<\/section>)[\s\S])*?Head-to-head[\s\S]*?<\/section>/i) || [""])[0];
ok(h2hSection.length > 0, "the head-to-head panel is its own section");
ok(/62\.5/.test(h2hSection), "a carried win rate is printed");
ok(/37\.5/.test(h2hSection),
   "the mirror cell is derived as 100 minus the carried value, so a pair sums to 100");
ok((h2hSection.match(/<tr>/g) || []).length === 5,
   "a header row plus one row per item, four items");
ok(/Fresh/.test(h2hSection) && /Strong/.test(h2hSection),
   "items are named by their labels, not their ids");

html = render({ headToHead: null });
ok(!/Head-to-head/i.test(html), "no head-to-head block means no head-to-head panel");

const aggHtml = render({ headToHead: Object.assign(h2h(), {
  source: "aggregate",
  note: "There are no individual utilities, so each win rate is computed from the population mean utilities as a single notional respondent.",
}) });
ok(/notional respondent/.test(aggHtml),
   "the aggregate fallback says what it is, rather than passing as a per-respondent rate");

// --- Segments panel -----------------------------------------------------------
html = render();
const segSection = (html.match(/<section[^>]*>(?:(?!<\/section>)[\s\S])*?Scores by segment[\s\S]*?<\/section>/i) || [""])[0];
ok(segSection.length > 0, "the tab has a segments panel");
ok(/>Age</.test(segSection) && /Region/.test(segSection),
   "each configured segment variable gets its own heading");
ok(/18-34/.test(segSection) && /35\+/.test(segSection),
   "the levels of a variable appear as columns");
ok(/n\s*=\s*180/.test(segSection), "each level states its base");
ok(!/segment_scores|segment_summary/.test(segSection),
   "the internal list names never reach the reader, as they do in the classic report");
ok((segSection.match(/<svg/g) || []).length === 2,
   "one grouped bar chart per segment variable");

const thin = render({ segments: segments({ thinLevel: true }) });
ok(/md-thin|too few|small base/i.test(thin),
   "a level below the configured minimum is flagged, not printed as if it were solid");

html = render({ segments: null });
ok(!/Scores by segment/i.test(html), "no segments block means no segments panel");

// --- Distributions panel ------------------------------------------------------
html = render();
const distSection = (html.match(/<section[^>]*>(?:(?!<\/section>)[\s\S])*?Utility distributions[\s\S]*?<\/section>/i) || [""])[0];
ok(distSection.length > 0, "the tab has a utility distributions panel");
ok(/<svg[^>]*viewBox=/.test(distSection), "it draws an SVG with a viewBox");
ok((distSection.match(/class="md-violin"/g) || []).length === 3,
   "one shape per item that has a density, and none for the blanked reference item");
ok(/Strong/.test(distSection),
   "the reference item is still named, it just has no shape to draw");

html = render({ distributions: null });
ok(!/Utility distributions/.test(html),
   "no distributions block means no distributions panel");

// --- Charts redrawn in the v2 report's own SVG --------------------------------
html = render();
const turfSection = (html.match(/<section[^>]*>(?:(?!<\/section>)[\s\S])*?Portfolio reach[\s\S]*?<\/section>/i) || [""])[0];
ok(/<svg[^>]*viewBox=/.test(turfSection), "TURF draws a reach curve, not only a table");
ok(/88\.2/.test(turfSection), "the curve's last reach value is the one the island carried");

const quadSection = (html.match(/<section[^>]*>(?:(?!<\/section>)[\s\S])*?Item strategy[\s\S]*?<\/section>/i) || [""])[0];
ok(quadSection.length > 0, "the tab has an item strategy quadrant");
ok(/<svg[^>]*viewBox=/.test(quadSection), "the quadrant is drawn as an SVG");
ok((quadSection.match(/<circle/g) || []).length === 4, "one point per item");
ok(/<ol class="md-key">/.test(quadSection),
   "points are numbered against a key, rather than carrying truncated labels");
ok(!/items are not plotted/.test(quadSection),
   "with every item placed, the panel makes no claim about missing ones");

const noSpread = island();
noSpread.scores.hbSpread = [0.81, 1.42, 0.63, null];
sandbox.TR.MD = noSpread;
const hostQ = { innerHTML: "" };
sandbox.TR.maxdiff.render(hostQ);
ok(/1 of 4 items are not plotted/.test(hostQ.innerHTML),
   "an item the model fixed has no spread, and the quadrant says it is missing");

ok(!/Heterogeneity/.test(diagSection),
   "heterogeneity and the utility spread are the same statistic, so it is not printed twice");
const split = island();
split.diagnostics.heterogeneity = 0.611;
sandbox.TR.MD = split;
const hostH = { innerHTML: "" };
sandbox.TR.maxdiff.render(hostH);
ok(/Heterogeneity/.test(hostH.innerHTML) && /0\.611/.test(hostH.innerHTML),
   "but it is printed when it genuinely differs from the spread");

const anchorSection = (html.match(/<section[^>]*>(?:(?!<\/section>)[\s\S])*?Must-haves[\s\S]*?<\/section>/i) || [""])[0];
ok(/md-threshold/.test(anchorSection),
   "the anchor panel marks the must-have threshold against the bars");
ok(/md-barcell/.test(anchorSection),
   "and draws the essential share as a bar, not only as a number");

// Every chart carries literal colours so a rasterised pin matches the page.
ok(!/var\(--/.test(html.replace(/style="background:[^"]*"/g, "")),
   "no chart reaches for a CSS variable, which would not survive rasterising");

console.log("\n" + pass + " passed, " + fail + " failed");
process.exit(fail === 0 ? 0 : 1);
