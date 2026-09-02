#!/usr/bin/env node
/**
 * MaxDiff tab gate. The maxdiff module contributes a frozen island (TR.MD);
 * 27y_maxdiff.js renders it and 24_shell.js shows the tab only when it has
 * content. This checks the availability rule, that the shell lists the tab
 * exactly when the view says so, that a render carries the estimator's own
 * words (the honesty stamp for the empirical-Bayes fallback), and that a
 * hostile label cannot break out of the markup.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/maxdiff_view_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const load = (sandbox, file) =>
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + e.message); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function has(hay, needle, msg) {
  if (hay.indexOf(needle) === -1) throw new Error((msg || "missing") + ": " + JSON.stringify(needle));
}
function lacks(hay, needle, msg) {
  if (hay.indexOf(needle) !== -1) throw new Error((msg || "present") + ": " + JSON.stringify(needle));
}

function viewSandbox(island) {
  const sb = { console };
  sb.globalThis = sb;
  sb.window = sb;
  sb.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
  vm.createContext(sb);
  load(sb, "27y_maxdiff.js");
  sb.TR.MD = island;
  return sb;
}

function shellSandbox(island) {
  const sb = viewSandbox(island);
  sb.TR.AGG = { project: {} };
  sb.TR.d2 = { tracking: () => ({ enabled: false }), qualitative: () => ({ enabled: false }) };
  installText(sb);
  load(sb, "24_shell.js");
  return sb;
}

const ISLAND = {
  meta: {
    schema: 1, kind: "maxdiff", method: "empirical_bayes",
    methodLabel: "Empirical Bayes fallback (count-based)",
    estimationNote: "cmdstanr was not available, so the utilities are empirical-Bayes shrunken best-minus-worst counts, not Bayesian posterior estimates.",
    nRespondents: 300, nTasks: 8, itemsPerTask: 4, nItems: 3, weighted: false,
    weightingNote: "Unweighted.", frozen: true,
    filterNote: "MaxDiff results do not respond to the audience filter.",
    simulatorFile: "Demo_MaxDiff_Results_simulator.html"
  },
  scores: {
    itemId: ["A", "B", "C"],
    label: ["Free delivery", 'Loyalty <script>alert(1)</script> & "points"', "Gift wrap"],
    group: ["Service", "Reward", "Service"],
    timesShown: [800, 800, 800], timesBest: [400, 200, 40], timesWorst: [40, 200, 500],
    bestPct: [50, 25, 5], worstPct: [5, 25, 62.5], netScore: [45, 0, -57.5],
    hbUtility: [1.2, 0.1, -1.3], hbSpread: [0.4, 0.5, 0.6],
    share: [61.2, 27.4, 11.4], rescaled: [100, 56, 0], rescaleMethod: "0_100"
  },
  turf: { thresholdMethod: "ABOVE_MEAN", nRespondents: 300, maxItems: 3,
          step: [1, 2, 3], itemId: ["A", "B", "C"], label: ["Free delivery", "Loyalty", "Gift wrap"],
          reachPct: [55, 78, 90], incrementalPct: [55, 23, 12], note: "Reach note." },
  anchor: { variable: "MustHave", threshold: 0.5, itemId: ["A", "B", "C"],
            label: ["Free delivery", "Loyalty", "Gift wrap"], rate: [0.7, 0.4, 0.1],
            count: [210, 120, 30], isMustHave: [true, false, false] },
  discrimination: { itemId: ["A", "B", "C"], classification: ["UNIVERSAL_FAVORITE", "POLARIZING", "LOW_PRIORITY"],
                    label: ["Universal Favorite", "Polarizing", "Low Priority"],
                    meanUtility: [1.2, 0.1, -1.3], sdUtility: [0.4, 0.9, 0.6], note: "Class note." }
};

console.log("MaxDiff tab — suite:");

run("availability: null, empty, and a scored island", () => {
  assert(viewSandbox(null).TR.maxdiff.available() === false, "null island is unavailable");
  assert(viewSandbox({}).TR.maxdiff.available() === false, "empty object is unavailable");
  assert(viewSandbox({ meta: {}, scores: { itemId: [] } }).TR.maxdiff.available() === false,
    "no items is unavailable");
  assert(viewSandbox(ISLAND).TR.maxdiff.available() === true, "scored island is available");
});

run("the shell lists the MaxDiff tab exactly when the island has content", () => {
  const without = shellSandbox(null).TR.shell.tabGroups();
  const idsWithout = without[0].tabs.map((t) => t[0]);
  assert(idsWithout.indexOf("maxdiff") === -1, "no island -> no tab: " + idsWithout.join(","));
  const withIsland = shellSandbox(ISLAND).TR.shell.tabGroups();
  const ids = withIsland[0].tabs.map((t) => t[0]);
  assert(ids.indexOf("maxdiff") !== -1, "island -> tab in the READ group: " + ids.join(","));
  assert(ids.indexOf("maxdiff") < ids.indexOf("story"), "before Story, like the other contributions");
  const label = withIsland[0].tabs.filter((t) => t[0] === "maxdiff")[0][1];
  assert(label === "MaxDiff", "tab label");
});

run("a render carries the estimator's words, the stamp, and every panel", () => {
  const sb = viewSandbox(ISLAND);
  const host = { innerHTML: "" };
  sb.TR.maxdiff.render(host);
  const h = host.innerHTML;
  has(h, "Empirical Bayes fallback", "estimator label");
  has(h, 'class="md-stamp"', "the fallback is stamped, not footnoted");
  has(h, "not Bayesian posterior estimates", "estimator note verbatim from the island");
  has(h, "audience filter", "frozen note");
  has(h, "Item scores", "scores panel");
  has(h, "Portfolio reach (TURF)", "turf panel");
  has(h, "Must-haves", "anchor panel");
  has(h, "Where respondents agree and disagree", "discrimination panel");
  has(h, "Spread (SD)", "EB spread is labelled spread, never SE");
  lacks(h, "Posterior SD", "EB is not labelled posterior");
  has(h, 'href="Demo_MaxDiff_Results_simulator.html"', "simulator link");
  has(h, "md-tag-must", "must-have tag");
  // Best-liked item first.
  assert(h.indexOf("Free delivery") < h.indexOf("Gift wrap"), "sorted by share, descending");
});

run("Stan provenance is labelled as posterior, and gets no stamp", () => {
  const isl = JSON.parse(JSON.stringify(ISLAND));
  isl.meta.method = "stan_hb";
  isl.meta.methodLabel = "Stan hierarchical Bayes";
  isl.meta.estimationNote = "Individual utilities are posterior means from the Stan model.";
  const sb = viewSandbox(isl);
  const host = { innerHTML: "" };
  sb.TR.maxdiff.render(host);
  has(host.innerHTML, "Posterior SD", "posterior label");
  lacks(host.innerHTML, 'class="md-stamp"', "no stamp on genuine HB");
});

run("a hostile label is escaped everywhere it appears", () => {
  const sb = viewSandbox(ISLAND);
  const host = { innerHTML: "" };
  sb.TR.maxdiff.render(host);
  lacks(host.innerHTML, "<script>", "raw script tag");
  has(host.innerHTML, "&lt;script&gt;", "escaped label text");
  has(host.innerHTML, "&quot;points&quot;", "escaped quotes");
});

run("a counts-only island renders without utilities, shares or extra panels", () => {
  const isl = {
    meta: { kind: "maxdiff", method: "counts", methodLabel: "Count scores",
            estimationNote: "Best and worst counts only; no model was fitted.", frozen: true },
    scores: { itemId: ["A", "B"], label: ["One", "Two"], bestPct: [40, 10], worstPct: [10, 40],
              netScore: [30, -30] }
  };
  const sb = viewSandbox(isl);
  const host = { innerHTML: "" };
  sb.TR.maxdiff.render(host);
  const h = host.innerHTML;
  has(h, "Count scores", "label");
  lacks(h, "Share</th>", "no share column");
  lacks(h, "Utility</th>", "no utility column");
  lacks(h, "TURF", "no turf panel");
  lacks(h, "Must-haves", "no anchor panel");
  lacks(h, "NaN", "no NaN anywhere");
});

run("an empty island renders a sentence rather than throwing", () => {
  const sb = viewSandbox(null);
  const host = { innerHTML: "" };
  sb.TR.maxdiff.render(host);
  has(host.innerHTML, "no MaxDiff results", "message");
});

run("no em dash reaches the reader from this view", () => {
  const src = readFileSync(path.join(JS_DIR, "27y_maxdiff.js"), "utf8");
  lacks(src, "—", "em dash in the view source");
  lacks(src, "&mdash;", "named em dash");
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
