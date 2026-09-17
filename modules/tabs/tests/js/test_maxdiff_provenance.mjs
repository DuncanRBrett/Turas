#!/usr/bin/env node
/**
 * Gate: the MaxDiff tab tells the truth about the fit it is showing.
 *
 * Two things the island now carries and the view has to render (maxdiff v2
 * review, F6 and M3):
 *
 *  F6  Sampler diagnostics. The tabs export gate keyed on the estimator alone,
 *      so a divergent or non-converged Stan fit read exactly like a clean one.
 *      The provenance panel states divergences, mean R-hat and min ESS, and
 *      names max treedepth only when it happened. None of it appears on the
 *      empirical-Bayes path, where there is no sampler to diagnose.
 *
 *  M3  The reference item. The Stan model fixes one item at zero, so its
 *      spread across respondents and its Mean SE are structurally 0. The
 *      island nulls them; this view has to show a dash AND say why, or the
 *      dash reads as missing data.
 *
 * Runs against the SHIPPED module JS (modules/tabs/lib/html_report_v2/assets/js).
 *
 * Run with:  node modules/tabs/tests/js/test_maxdiff_provenance.mjs
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

const ITEMS = ["Fresh", "Cheap", "Local", "Strong", "Smooth", "Rewards"];
const IDS = ITEMS.map((_, i) => "ITEM0" + (i + 1));

/** An island the way 13_v2_island.R writes one; the reference item is last. */
function island(opts) {
  const o = opts || {};
  const stan = o.method !== "empirical_bayes";
  const meta = {
    schema: 1, kind: "maxdiff", projectName: "KarooGate",
    method: stan ? "stan_hb" : "empirical_bayes",
    methodLabel: stan ? "Stan hierarchical Bayes" : "Empirical Bayes fallback (count-based)",
    estimationNote: "Individual utilities are posterior means from the Stan model.",
    nRespondents: 300, nTasks: 10, nItems: 6, itemsPerTask: 4,
    weighted: false, weightingNote: "Unweighted.", frozen: true,
    filterNote: "MaxDiff results are estimated once on the whole sample.",
  };
  if (stan) {
    meta.nDivergences = o.nDivergences === undefined ? 0 : o.nDivergences;
    meta.maxTreedepthExceeded = o.maxTreedepth === undefined ? 0 : o.maxTreedepth;
    meta.meanRhat = o.meanRhat === undefined ? 1.0009 : o.meanRhat;
    meta.minEss = o.minEss === undefined ? 8675 : o.minEss;
    meta.referenceItem = IDS[5];
    meta.referenceItemLabel = ITEMS[5];
  }
  const spread = [0.81, 1.42, 0.63, 0.55, 0.34, null];
  const se = [0.11, 0.10, 0.12, 0.09, 0.13, null];
  return {
    meta: meta,
    scores: {
      itemId: IDS, label: ITEMS,
      timesShown: [200, 200, 200, 200, 200, 200],
      bestPct: [50, 33.3, 25, 16.7, 8.3, 5],
      worstPct: [3.3, 6.7, 13.3, 20, 33.3, 50],
      netScore: [46.7, 26.7, 11.7, -3.3, -25, -45],
      hbUtility: [1.5, 1.0, 0.5, 0.2, -0.4, 0],
      hbSpread: stan ? spread : spread.map((v, i) => (i === 5 ? 0 : v)),
      hbMeanSe: stan ? se : null,
      share: [31, 24, 16, 12, 10, 7],
    },
    discrimination: {
      itemId: IDS,
      classification: ["UNIVERSAL", "POLARISING", "NICHE", "NICHE", "LOW_PRIORITY",
                       stan ? null : "LOW_PRIORITY"],
      label: ["Universal favourite", "Polarising", "Niche", "Niche", "Low priority",
              stan ? null : "Low priority"],
      meanUtility: [1.5, 1.0, 0.5, 0.2, -0.4, 0],
      sdUtility: stan ? spread : spread.map((v, i) => (i === 5 ? 0 : v)),
      note: "Classes come from median splits.",
    },
  };
}

function render(opts) {
  sandbox.TR.MD = island(opts);
  const host = { innerHTML: "" };
  sandbox.TR.maxdiff.render(host);
  return host.innerHTML;
}

// --- F6: the sampler sentence -------------------------------------------------
let html = render();
ok(/Sampler:/.test(html), "a Stan fit states its sampler diagnostics");
ok(/0 divergences/.test(html), "divergences are named, and a clean run says zero");
ok(/mean R-hat 1\.001/.test(html), "mean R-hat is stated to three decimals");
ok(/min ESS 8675/.test(html), "min ESS is stated");
ok(!/max treedepth/.test(html), "a clean run does not mention max treedepth");

html = render({ nDivergences: 1, maxTreedepth: 12, meanRhat: 1.0412, minEss: 87 });
ok(/1 divergence[^s]/.test(html), "one divergence is singular, not '1 divergences'");
ok(/mean R-hat 1\.041/.test(html), "a non-converged fit shows its R-hat, it is not hidden");
ok(/max treedepth exceeded 12 times/.test(html),
   "max treedepth is named when it actually happened");

html = render({ method: "empirical_bayes" });
ok(!/Sampler:/.test(html), "the empirical-Bayes path claims no sampler diagnostics");
ok(!/R-hat/.test(html), "and no R-hat, because there is no posterior to take one from");

// --- M3: the reference item ---------------------------------------------------
html = render();
ok(/Rewards is the reference item, fixed at zero/.test(html),
   "the view names the reference item and says it is fixed at zero");
ok(/relative to it/.test(html), "and says the other utilities are relative to it");
ok(/–/.test(html), "a dash appears where the structural zeros were");
const refRow = (html.match(/<tr><td>Rewards[\s\S]*?<\/tr>/) || [""])[0];
ok(refRow.length > 0, "the reference item still has a row of its own");
ok((refRow.match(/\u2013/g) || []).length === 2,
   "exactly two cells in that row are dashed: the spread and the mean SE");
ok(/>0\.00</.test(refRow),
   "its utility still prints as 0.00, which is the true value, not a dash");

html = render({ method: "empirical_bayes" });
ok(!/is the reference item/.test(html),
   "no reference-item note on a path that has no fixed item");

console.log("\n" + pass + " passed, " + fail + " failed");
process.exit(fail === 0 ? 0 : 1);
