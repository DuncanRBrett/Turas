#!/usr/bin/env node
/**
 * Pricing tab gate. The pricing module contributes a frozen island (TR.PR);
 * 27z_pricing.js renders it and 24_shell.js shows the tab only when it has
 * content. This checks the availability rule, that the shell lists the tab
 * exactly when the view says so and hides the filter bar while it is open,
 * that a render carries the estimator's own words and the study's own
 * currency, that a method the run did not use adds no panel, and that a
 * hostile project name cannot break out of the markup.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/pricing_view_tests.mjs
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
  load(sb, "27z_pricing.js");
  sb.TR.PR = island;
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

function render(island) {
  const sb = viewSandbox(island);
  const host = { innerHTML: "" };
  sb.TR.pricing.render(host);
  return host.innerHTML;
}

const ISLAND = {
  meta: {
    schema: 1, kind: "pricing", islandVersion: "1.0.0",
    projectName: 'Karoo <script>alert(1)</script> & "Coffee"',
    currency: "R",
    methods: ["van_westendorp", "gabor_granger"],
    methodLabels: ["Van Westendorp price sensitivity meter", "Gabor-Granger"],
    nRespondents: 400, nValid: 356, weighted: true, weightVariable: "Weight",
    effectiveN: 331.8,
    weightingNote: "Weighted by Weight: the Van Westendorp curves are estimated on a survey design built from the weights.",
    estimationNote: {
      vw: "Price points are the curve intersections computed by pricesensitivitymeter (psm_analysis_weighted (survey design)) on 356 respondents.",
      gg: "Acceptance is the share saying they would buy at each rung, coded binary, 1 = would buy, 0 = would not."
    },
    frozen: true,
    filterNote: "Pricing results are estimated once on the whole sample. They do not respond to the audience filter.",
    simulatorFile: "Karoo_Pricing_Results_simulator.html"
  },
  vw: {
    point: ["PMC", "OPP", "IDP", "PME"],
    pointLabel: ["Point of marginal cheapness", "Optimal price point",
                 "Indifference price point", "Point of marginal expensiveness"],
    value: [61.48, 89.74, 93.86, 135.88],
    ciLower: [59.1, 85.5, 89.8, 131.0],
    ciUpper: [63.9, 94.0, 98.0, 141.0],
    ciLevel: 0.95, ciIterations: 300,
    ciPolicy: "Respondents resampled with equal probability carrying their weights.",
    acceptableLower: 61.48, acceptableUpper: 135.88,
    optimalLower: 89.74, optimalUpper: 93.86,
    nAnalysed: 356, nComplete: 356, monotonicityBehavior: "drop",
    curves: {
      price: [40, 60, 80, 100, 120, 140],
      tooCheap: [0.9, 0.6, 0.3, 0.1, 0.03, 0.01],
      cheap: [0.95, 0.75, 0.45, 0.2, 0.08, 0.02],
      expensive: [0.05, 0.15, 0.4, 0.7, 0.9, 0.97],
      tooExpensive: [0.01, 0.05, 0.2, 0.45, 0.75, 0.95],
      nPoints: 6, downsampledFrom: 3201
    }
  },
  gg: {
    price: [60, 80, 100, 120, 140],
    baseN: [400, 400, 400, 400, 400],
    weightedN: [400, 400, 400, 400, 400],
    acceptancePct: [93.9, 85.6, 73.2, 49.1, 32.0],
    revenueIndex: [0.563, 0.685, 0.732, 0.589, 0.448],
    ciLowerPct: [91.5, 82.0, 69.0, 44.5, 27.9],
    ciUpperPct: [96.1, 89.0, 77.3, 53.8, 36.4],
    ciLevel: 0.95,
    arcElasticity: [null, -0.35, -0.68, -1.72, -2.15],
    smoothing: "isotonic",
    optimalRevenuePrice: 100, optimalRevenueIntentPct: 73.2
  },
  recommendation: {
    price: 99.99, source: "Gabor-Granger optimal", confidence: "HIGH",
    confidenceScore: 0.92, acceptableLower: 61.48, acceptableUpper: 135.88,
    optimalLower: 89.74, optimalUpper: 93.86,
    methodSpreadPct: 4.72, nMethodPrices: 4
  }
};

const MONADIC_ISLAND = {
  meta: {
    kind: "pricing", currency: "R", methods: ["monadic"],
    methodLabels: ["Monadic cell test"], nRespondents: 400, nValid: 400,
    weighted: true, effectiveN: 372.3,
    weightingNote: "Weighted by Weight: the monadic model is fitted with the weights normalised to mean 1.",
    estimationNote: {
      monadic: "The fitted curve is a logistic regression of purchase intent on price across 4 price cells. Weighted fit: the p-value overstates significance."
    },
    frozen: true, filterNote: "They do not respond to the audience filter."
  },
  monadic: {
    cellPrice: [70, 80, 90, 100], cellN: [100, 100, 100, 100],
    cellWeightedN: [98, 101, 99, 102],
    cellIntentPct: [72.1, 66.0, 57.4, 48.9],
    fitted: { price: [70, 80, 90, 100], intentPct: [72.5, 65.4, 57.5, 49.2],
              revenueIndex: [50.8, 52.3, 51.8, 49.2] },
    modelType: "logistic", pseudoR2: 0.108, pValue: 4.02e-13,
    pValueCaveat: "Weighted fit: glm treats the weights as frequency weights, so the p-value is not adjusted for the design effect and overstates significance.",
    optimalPrice: 80.3, optimalIntentPct: 65.8
  },
  recommendation: { price: 79.99, source: "Monadic revenue optimal", confidence: "HIGH",
                    confidenceScore: 0.85, methodSpreadPct: 12.19, nMethodPrices: 2 }
};

console.log("Pricing tab: suite");

run("availability: null, empty, meta-only, and a scored island", () => {
  assert(viewSandbox(null).TR.pricing.available() === false, "null island is unavailable");
  assert(viewSandbox({}).TR.pricing.available() === false, "empty object is unavailable");
  assert(viewSandbox({ meta: { kind: "pricing" } }).TR.pricing.available() === false,
    "meta with no method block is unavailable");
  assert(viewSandbox(ISLAND).TR.pricing.available() === true, "scored island is available");
  assert(viewSandbox(MONADIC_ISLAND).TR.pricing.available() === true, "monadic-only is available");
});

run("the shell lists the Pricing tab exactly when the island has content", () => {
  const without = shellSandbox(null).TR.shell.tabGroups();
  const idsWithout = without[0].tabs.map((t) => t[0]);
  assert(idsWithout.indexOf("pricing") === -1, "no island -> no tab: " + idsWithout.join(","));
  const withIsland = shellSandbox(ISLAND).TR.shell.tabGroups();
  const ids = withIsland[0].tabs.map((t) => t[0]);
  assert(ids.indexOf("pricing") !== -1, "island -> tab in the READ group: " + ids.join(","));
  assert(ids.indexOf("pricing") < ids.indexOf("story"), "before Story, like the other contributions");
  const label = withIsland[0].tabs.filter((t) => t[0] === "pricing")[0][1];
  assert(label === "Pricing", "tab label");
});

run("the filter bar is hidden on the Pricing tab, because the results are frozen", () => {
  const shell = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
  has(shell, 'd2.state.tab === "pricing" ||', "pricing in the filter-hidden list");
  has(shell, 'd2.state.tab === "pricing") TR.pricing.render(host)', "render dispatch");
  has(shell, 'TR.PR = parseIsland("data-pr")', "island parsed at boot");
});

run("a both-methods render carries provenance, both panels and the recommendation", () => {
  const h = render(ISLAND);
  has(h, "Van Westendorp price sensitivity meter", "method label");
  has(h, "400 respondents", "sample");
  has(h, "356 after validation", "analysed base");
  has(h, "effective n 331.8", "effective n");
  has(h, "psm_analysis_weighted", "the estimator, verbatim from the island");
  has(h, "audience filter", "frozen note");
  has(h, "Van Westendorp price points", "vw panel");
  has(h, "Gabor-Granger demand", "gg panel");
  has(h, "Recommended price", "recommendation panel");
  lacks(h, "Monadic cells", "no monadic panel on a run without one");
  has(h, 'href="Karoo_Pricing_Results_simulator.html"', "simulator link");
});

run("prices carry the study's own currency, never a dollar sign", () => {
  const h = render(ISLAND);
  has(h, "R89.74", "the OPP in rands");
  has(h, "R99.99", "the recommended price in rands");
  lacks(h, "$", "no hard-coded dollar anywhere in the rendered tab");
});

run("every price point shows its own interval", () => {
  const h = render(ISLAND);
  has(h, "R59.10 to R63.90", "PMC interval");
  has(h, "R85.50 to R94.00", "OPP interval");
  has(h, "bootstrap 95% interval", "the interval is described");
  has(h, "300 replicates", "and how many replicates");
});

run("marker labels that would collide step down a line instead", () => {
  // OPP and IDP sit R4 apart on the Karoo example, which put one label on top
  // of the other. Labels within 34px of the one before step down.
  const h = render(ISLAND);
  const svg = h.slice(h.indexOf("Van Westendorp price sensitivity curves"));
  const ys = [...svg.matchAll(/<text x="([\d.]+)" y="(\d+)" font-size="10"[^>]*>(PMC|OPP|IDP|PME)</g)]
    .map((m) => ({ x: +m[1], y: +m[2], label: m[3] }));
  assert(ys.length === 4, "four marker labels: " + ys.length);
  const opp = ys.find((p) => p.label === "OPP");
  const idp = ys.find((p) => p.label === "IDP");
  assert(idp.x - opp.x < 34, "the two really are close: " + (idp.x - opp.x));
  assert(idp.y > opp.y, "so IDP sits on a lower line: " + opp.y + " vs " + idp.y);
  // PME is far from IDP, so it goes back to the top line.
  const pme = ys.find((p) => p.label === "PME");
  assert(pme.y === ys.find((p) => p.label === "PMC").y, "a distant label starts a new run");
});

run("the VW chart draws four curves and marks the four points", () => {
  const h = render(ISLAND);
  const svg = h.slice(h.indexOf("Van Westendorp price sensitivity curves"));
  assert((svg.match(/<path /g) || []).length >= 4, "four curve paths");
  ["PMC", "OPP", "IDP", "PME"].forEach((p) => {
    assert(svg.indexOf(">" + p + "</text>") !== -1, "marker label " + p);
  });
  has(h, "Too cheap", "legend");
  has(h, "Too expensive", "legend");
});

run("the GG panel shows the rungs, the optimum and the revenue axis", () => {
  const h = render(ISLAND);
  has(h, "R60.00", "first rung");
  has(h, "93.9%", "its acceptance");
  has(h, "Revenue is highest at R100.00", "the optimum in words");
  has(h, "Revenue optimum", "and marked on the chart");
  has(h, "Revenue index", "the second axis is named");
  has(h, "91.5 to 96.1", "the rung interval");
  has(h, "-1.72", "arc elasticity on the rung its step ends at");
});

run("a smoothed curve that equals the observed one is not published twice", () => {
  // The island only carries smoothedPct when it differs from what was
  // observed; the table then has no Published column to mislead the reader.
  const h = render(ISLAND);
  lacks(h, "Published</th>", "no published column when the curve was not moved");
  const isl = JSON.parse(JSON.stringify(ISLAND));
  isl.gg.smoothedPct = [93.9, 85.0, 73.2, 49.1, 32.0];
  const h2 = render(isl);
  has(h2, "Published</th>", "a moved curve gets its own column");
  has(h2, "the observed acceptance is the dashed line", "and the note explains it");
});

run("the monadic panel keeps the cells apart from the fitted curve, with the caveat stamped", () => {
  const h = render(MONADIC_ISLAND);
  has(h, "Monadic cells", "panel");
  has(h, "72.1%", "an observed cell");
  has(h, "the dots are what they said", "the note tells them apart");
  has(h, 'class="pr-stamp"', "the weighted p-value caveat is stamped, not footnoted");
  has(h, "overstates significance", "verbatim from the island");
  has(h, "below 0.001", "a tiny p-value is described, not printed as 0.000");
  lacks(h, "Van Westendorp price points", "no VW panel on a monadic run");
  lacks(h, "Gabor-Granger demand", "no GG panel on a monadic run");
});

run("no generated recommendation prose reaches the tab", () => {
  const h = render(ISLAND);
  // Decision 9: the numbers travel, the sentences do not.
  lacks(h, "Moderate agreement across methods", "the synthesis factor sentences stay in Excel");
  lacks(h, "interpret with caution", "and so does their wording");
  has(h, "spread 4.7%", "the figure travels instead");
});

run("a hostile project name is escaped everywhere it appears", () => {
  const isl = JSON.parse(JSON.stringify(ISLAND));
  isl.meta.estimationNote.vw = 'Estimated <script>alert(2)</script> & "quoted"';
  const h = render(isl);
  lacks(h, "<script>", "raw script tag");
  has(h, "&lt;script&gt;", "escaped note text");
  has(h, "&quot;quoted&quot;", "escaped quotes");
});

run("a missing value renders as an en dash, never NaN", () => {
  const isl = JSON.parse(JSON.stringify(ISLAND));
  isl.vw.ciLower = null;
  isl.vw.ciUpper = null;
  isl.gg.arcElasticity = null;
  isl.gg.revenueIndex = null;
  const h = render(isl);
  lacks(h, "NaN", "no NaN anywhere");
  lacks(h, "undefined", "no undefined anywhere");
  has(h, "–", "en dash for the missing interval");
});

run("an empty island renders a sentence rather than throwing", () => {
  const h = render(null);
  has(h, "no pricing results", "message");
});

run("no em dash reaches the reader from this view", () => {
  const src = readFileSync(path.join(JS_DIR, "27z_pricing.js"), "utf8");
  lacks(src, "—", "em dash in the view source");
  lacks(src, "&mdash;", "named em dash");
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
