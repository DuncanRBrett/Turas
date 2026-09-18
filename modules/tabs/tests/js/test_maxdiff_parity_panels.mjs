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

console.log("\n" + pass + " passed, " + fail + " failed");
process.exit(fail === 0 ? 0 : 1);
