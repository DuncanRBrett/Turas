#!/usr/bin/env node
/**
 * Categorical drivers tab gate. The catdriver module contributes a frozen
 * island (TR.CD); 27j_catdriver.js renders it and 24_shell.js shows the tab
 * only when it has content. This checks the availability rule, that the shell
 * lists the tab exactly when the view says so and hides the filter bar while it
 * is open, that odds are never narrated as likelihood, that an absent bootstrap
 * is said rather than drawn, that no significance letter appears anywhere, and
 * that a hostile driver label cannot break out of the markup.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/catdriver_view_tests.mjs
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
  load(sb, "27j_catdriver.js");
  sb.TR.CD = island;
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

function hostStub() {
  return { innerHTML: "", querySelectorAll: () => [] };
}

function render(island) {
  const sb = viewSandbox(island);
  const host = hostStub();
  sb.TR.catdriver.render(host);
  return host.innerHTML;
}

const ISLAND = {
  meta: {
    schema_version: 1, kind: "catdriver",
    analysis_name: "Demo: Customer Churn Analysis",
    outcome: { var: "churn", label: "Customer Churn", type: "binary",
               levels: ["Retained", "Churned"] },
    run_status: "PARTIAL",
    degraded_reasons: ["Sparse cells in service_quality (min cell: 1)"],
    weighted: true, weight_var: "survey_weight",
    n_drivers: 2, has_odds_ratios: true, has_lifts: true, has_subgroups: true,
    frozen: true,
    filter_note: "Report filters do not apply here. These figures were estimated once, on the whole sample.",
    confidence_level: 0.9
  },
  importance: {
    method: "LR chi-square share (car::Anova type II on glm)",
    rows: [
      { driver: "service_quality", label: "Service Quality", pct: 58.2,
        statistic: 91.4, df: 3, p: 0.0000001, rank: 1, effect: "Very Large" },
      { driver: "price_perception", label: "Price Perception", pct: 41.8,
        statistic: 65.6, df: 2, p: 0.00002, rank: 2, effect: "Large" }
    ]
  },
  odds_ratios: {
    interval_kind: "wald", bootstrap: false,
    rows: [
      { driver: "service_quality", label: "Service Quality", level: "Excellent",
        reference: "Poor", or: 11.36, lo: 5.2, hi: 24.8, p: 0.0000035 },
      { driver: "price_perception", label: "Price Perception", level: "Good Value",
        reference: "Too Expensive", or: 0.42, lo: 0.21, hi: 0.83, p: 0.012 }
    ]
  },
  lifts: {
    outcome_level: "Churned",
    basis: "Difference in mean fitted probability between a category's respondents and the reference category's. Not an average marginal effect: the groups differ in other ways too.",
    rows: [
      { driver: "service_quality", label: "Service Quality", level: "Poor",
        is_reference: true, prob: 0.69, ref_prob: 0.69, lift: 0, lift_pp: 0 },
      { driver: "service_quality", label: "Service Quality", level: "Excellent",
        is_reference: false, prob: 0.19, ref_prob: 0.69, lift: -0.5, lift_pp: -50.1 }
    ]
  },
  patterns: [
    { driver: "service_quality", label: "Service Quality", reference: "Poor",
      outcome_levels: ["Retained", "Churned"],
      rows: [
        { level: "Poor", n: 55, pct_of_total: 12.1, is_reference: true,
          shares: [{ level: "Retained", pct: 30.9 }, { level: "Churned", pct: 69.1 }] },
        { level: "Excellent", n: 100, pct_of_total: 21.9, is_reference: false,
          shares: [{ level: "Retained", pct: 81.0 }, { level: "Churned", pct: 19.0 }] }
      ] }
  ],
  fit: {
    engine: "glm", model_type: "binary_logistic", outcome_type: "binary",
    mcfadden_r2: 0.1326, aic: 552.1, lr: 84.9, lr_df: 5, lr_p: 0.0000001,
    accuracy: 0.72, converged: true, n: 456, n_original: 500, n_excluded: 44,
    n_eff: 409.3, design_effect: 1.11,
    weighting: "Weighted by 'survey_weight', applied as frequency weights normalised to mean 1 across the respondents with a positive weight. Kish effective n = 409 of 456 (design effect 1.11). Inference is a frequency-weight approximation: the design effect is reported but NOT applied to standard errors, confidence intervals or p-values.",
    proportional_odds: null,
    multicollinearity: { checked: true, status: "PASS",
      method: "GVIF on an auxiliary linear model of the design matrix",
      interpretation: "No multicollinearity concerns (all adjusted GVIF below threshold)" }
  },
  subgroups: {
    variable: "age_group", groups: ["Total", "18-30"], n_groups: 2,
    importance: [
      { driver: "service_quality", label: "Service Quality", classification: "Universal",
        groups: [{ group: "Total", rank: 1, pct: 58.2 }, { group: "18-30", rank: 1, pct: 61.0 }] }
    ],
    fit: [
      { group: "Total", n: 456, n_before_missing: 500, mcfadden_r2: 0.133, status: "PARTIAL" },
      { group: "18-30", n: 133, n_before_missing: 147, mcfadden_r2: 0.181, status: "PARTIAL" }
    ],
    odds_ratios: [],
    insights: ["Service Quality is a universal driver across all subgroups."]
  }
};

run("the tab appears only when the island has importance rows", () => {
  const sb = viewSandbox(ISLAND);
  assert(sb.TR.catdriver.available() === true, "available with rows");
  assert(viewSandbox(null).TR.catdriver.available() === false, "not available without an island");
  const empty = JSON.parse(JSON.stringify(ISLAND));
  empty.importance.rows = [];
  assert(viewSandbox(empty).TR.catdriver.available() === false, "not available with no rows");
});

run("the shell lists the tab exactly when the view says so", () => {
  const on = JSON.stringify(shellSandbox(ISLAND).TR.shell.tabGroups());
  has(on, "Categorical drivers", "the tab is listed when the island has content");
  const off = JSON.stringify(shellSandbox(null).TR.shell.tabGroups());
  lacks(off, "Categorical drivers", "no tab without an island");
});

run("an island without its renderer is reported, not shown empty", () => {
  const sb = shellSandbox(ISLAND);
  assert(sb.TR.shell._missingRenderers().indexOf("catdriver") === -1,
         "nothing missing when the renderer is loaded");
  sb.TR.catdriver = undefined;
  assert(sb.TR.shell._missingRenderers().indexOf("catdriver") !== -1,
         "a missing renderer is named");
});

run("the frozen note is on the face of the tab", () => {
  const html = render(ISLAND);
  has(html, "Report filters do not apply here", "the frozen note shows");
  has(html, "cd-frozen", "and is styled as such");
});

run("odds are never narrated as likelihood", () => {
  const html = render(ISLAND).toLowerCase();
  lacks(html, "more likely", "no likelihood narration");
  lacks(html, "less likely", "no likelihood narration");
  lacks(html, "times as likely", "no likelihood narration");
  has(html, "odds ratio", "the quantity is named for what it is");
});

run("no significance letter appears anywhere on the tab", () => {
  const html = render(ISLAND);
  lacks(html, "sig-letter", "no significance letters");
  lacks(html, "significantly higher", "no borrowed significance language");
  lacks(html, "significantly lower", "no borrowed significance language");
});

run("an absent bootstrap is said, not drawn", () => {
  const html = render(ISLAND);
  has(html, "No bootstrap ran for this study", "the absence is stated");
  lacks(html, "Sign stability", "no column for a statistic that does not exist");

  const withBoot = JSON.parse(JSON.stringify(ISLAND));
  withBoot.odds_ratios.bootstrap = true;
  withBoot.odds_ratios.interval_kind = "wald_and_bootstrap";
  withBoot.odds_ratios.rows[0].boot_lo = 4.9;
  withBoot.odds_ratios.rows[0].boot_hi = 27.1;
  withBoot.odds_ratios.rows[0].sign_stability = 1;
  const html2 = render(withBoot);
  has(html2, "Sign stability", "the column appears when the bootstrap ran");
  has(html2, "100%", "sign stability renders as a percentage");
  lacks(html2, "No bootstrap ran", "and the absence note goes away");
});

run("the interval is labelled at the level the study used", () => {
  const html = render(ISLAND);
  has(html, "90% interval", "the island's own confidence level");
  lacks(html, "95% interval", "not a level the renderer assumed");

  const noLevel = JSON.parse(JSON.stringify(ISLAND));
  delete noLevel.meta.confidence_level;
  has(render(noLevel), "Interval (Wald)", "falls back to an unlabelled interval");
});

run("the probability lift names the outcome level and its basis", () => {
  const html = render(ISLAND);
  has(html, "Probability lift: Churned", "the level is named in the heading");
  has(html, "Not an average marginal effect", "the basis is stated");
});

run("the importance table carries the method that produced it", () => {
  has(render(ISLAND), "LR chi-square share", "the method stamp travels to the reader");
});

run("the weighting statement reaches the diagnostics drawer", () => {
  const html = render(ISLAND);
  has(html, "effective n = 409", "the effective base shows in the provenance line");
  has(html, "NOT applied", "the inference caveat reaches the reader");
});

run("a qualified run shows its qualifications", () => {
  const html = render(ISLAND);
  has(html, "1 qualification on this run", "the count shows");
  has(html, "Sparse cells in service_quality", "and the reason itself");
});

run("subgroup groups keep their own bases", () => {
  const html = render(ISLAND);
  has(html, "n before missing", "the pre-deletion count is shown beside the analysed one");
  has(html, "133", "a group's analysed base");
  has(html, "147", "and what it started with");
});

run("a hostile label cannot break out of the markup", () => {
  const nasty = JSON.parse(JSON.stringify(ISLAND));
  nasty.importance.rows[0].label = '<img src=x onerror="alert(1)">';
  nasty.odds_ratios.rows[0].level = "Response <24h";
  const html = render(nasty);
  lacks(html, "<img src=x", "the tag is escaped");
  has(html, "&lt;img src=x", "and shown as text");
  has(html, "Response &lt;24h", "a level with an angle bracket is escaped too");
});

run("an island with only importance still renders", () => {
  const bare = JSON.parse(JSON.stringify(ISLAND));
  delete bare.odds_ratios;
  delete bare.lifts;
  delete bare.patterns;
  delete bare.subgroups;
  delete bare.fit;
  const html = render(bare);
  has(html, "Categorical drivers", "the tab still draws");
  has(html, "Driver importance", "with what it has");
  lacks(html, "Odds ratios", "and no empty panels");
  lacks(html, "Probability lift", "and no empty panels");
});

run("the audience strip does not print a base that belongs to another study", () => {
  // The strip's n is the crosstab project's. These figures come from the
  // catdriver study's own sample, so printing "n=200" above a panel that says
  // "n=456" invites a reader to take one for the other.
  const sb = shellSandbox(ISLAND);
  sb.TR.d2.state = { tab: "catdriver", filters: [], banner: null };
  sb.TR.d2.filterDescription = () => "Everyone";
  sb.TR.d2.hasComputedSource = () => false;
  sb.TR.d2.studyN = () => 200;
  sb.TR.charts = { clip: (s) => s };
  sb.TR.AGG.project = {};
  load(sb, "24a_reader.js");

  const strip = sb.TR.reader.audienceStripHtml("catdriver");
  has(strip, "does not apply on this tab", "the strip says the filter does not apply");
  lacks(strip, "n=", "and prints no base of its own");

  // the siblings behave the same way, because the reason is the same
  ["conjoint", "maxdiff", "pricing", "keydriver"].forEach(function (t) {
    has(sb.TR.reader.audienceStripHtml(t), "does not apply on this tab", t);
  });
  // and an ordinary tab is untouched
  has(sb.TR.reader.audienceStripHtml("crosstabs"), "Everyone", "crosstabs still shows the cut");
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed === 0 ? 0 : 1);
