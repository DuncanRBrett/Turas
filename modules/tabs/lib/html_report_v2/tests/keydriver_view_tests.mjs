#!/usr/bin/env node
/**
 * Key drivers tab gate. The keydriver module contributes a frozen island
 * (TR.KD); 27k_keydriver.js renders it and 24_shell.js shows the tab only when
 * it has content. This checks the availability rule, that the shell lists the
 * tab exactly when the view says so and hides the filter bar while it is open,
 * that a method without a bootstrap is stamped rather than drawn as an empty
 * whisker, that every segment carries its base, that a negative driver is
 * marked, and that a hostile driver label cannot break out of the markup.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/keydriver_view_tests.mjs
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
  load(sb, "27k_keydriver.js");
  sb.TR.KD = island;
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

/** A host stub whose querySelectorAll returns nothing, so bind() is a no-op. */
function hostStub() {
  return { innerHTML: "", querySelectorAll: () => [] };
}

function render(island) {
  const sb = viewSandbox(island);
  const host = hostStub();
  sb.TR.keydriver.render(host);
  return host.innerHTML;
}

const ISLAND = {
  meta: {
    schema_version: 1, kind: "keydriver",
    analysis_name: "Suiderland Bank customer satisfaction",
    outcome: { var: "overall_satisfaction", label: "Overall satisfaction" },
    run_status: "PASS",
    primary_method: "shapley_r2_decomposition",
    random_seed: 2026,
    base: {
      n: 900, n_excluded: 0, weighted: true, weight_var: "weight",
      n_eff: 695.68, design_effect: 1.29
    },
    n_drivers: 3, has_ci: true, has_quadrant: true, n_segment_vars: 1,
    frozen: true,
    filter_note: "Report filters do not apply here. These figures were estimated once, on the whole sample."
  },
  importance: {
    methods: [
      { key: "shapley", label: "Shapley value", unit: "pct", interval: false,
        note: "no interval available" },
      { key: "relative_weight", label: "Relative weight", unit: "pct", interval: true },
      { key: "correlation", label: "Correlation", unit: "r", interval: true }
    ],
    drivers: [
      { driver: "digital_banking", label: 'Digital <script>alert(1)</script> & "banking"',
        values: { shapley: 45.8, relative_weight: 45.5, correlation: 0.77 },
        ranks: { shapley: 1, relative_weight: 1, correlation: 1 },
        direction: 1, avg_rank: 1 },
      { driver: "fees_clarity", label: "Clarity of fees",
        values: { shapley: 21.1, relative_weight: 21.3, correlation: 0.61 },
        ranks: { shapley: 2, relative_weight: 2, correlation: 2 },
        direction: 1, avg_rank: 2 },
      { driver: "wait_time", label: "Wait time",
        values: { shapley: 8.4, relative_weight: 8.1, correlation: -0.32 },
        ranks: { shapley: 3, relative_weight: 3, correlation: 3 },
        direction: -1, avg_rank: 3 }
    ]
  },
  ci: {
    rows: [
      { driver: "digital_banking", method: "relative_weight", estimate: 45.5, lo: 41.2, hi: 49.9, se: 2.2 },
      { driver: "fees_clarity", method: "relative_weight", estimate: 21.3, lo: 18.0, hi: 24.8, se: 1.7 },
      { driver: "wait_time", method: "relative_weight", estimate: 8.1, lo: 5.9, hi: 10.6, se: 1.2 }
    ],
    methods: ["relative_weight"],
    no_interval: ["shapley"],
    iterations: 1000, level: 0.95,
    note: "Point_Estimate is the mean of the bootstrap distribution and will not equal the headline importance column."
  },
  fit: {
    r2: 0.7426, adj_r2: 0.7411, f: 515.8, df1: 5, df2: 894, p: 1.6e-260, n_model: 900,
    vif: [
      { term: "digital_banking", vif: 1.34 },
      { term: "fees_clarity", vif: 6.2 },
      { term: "wait_time", vif: 12.9 }
    ],
    vif_thresholds: { moderate: 5, high: 10 }
  },
  quadrant: {
    points: [
      { driver: "digital_banking", x: 100, y: 100, quadrant: 2, quadrant_label: "Keep Up Good Work" },
      { driver: "fees_clarity", x: 0, y: 37.5, quadrant: 1, quadrant_label: "Concentrate Here" }
    ],
    thresholds: { x: 24.3, y: 34.2 },
    axes: { x: "Performance", y: "Importance" },
    importance_source: { requested: "shap", used: "auto (shap was requested and is absent)" }
  },
  segments: [
    {
      variable: "age_band",
      segments: [{ name: "Younger", n: 412 }, { name: "Older", n: 488 }],
      min_base: 60,
      rows: [
        { driver: "digital_banking", values: { Younger: 42.1, Older: 44.4 },
          ranks: { Younger: 1, Older: 1 }, mean: 43.3, classification: "Universal",
          description: "digital_banking is a universal driver" }
      ],
      insights: ["digital_banking is the #1 driver across all 2 segments (Universal)"]
    }
  ]
};

console.log("Key drivers view");

run("available() is false without an island", () => {
  const sb = viewSandbox(null);
  assert(sb.TR.keydriver.available() === false, "should be unavailable");
});

run("available() is false for an island with no drivers", () => {
  const sb = viewSandbox({ meta: {}, importance: { methods: [], drivers: [] } });
  assert(sb.TR.keydriver.available() === false, "empty drivers should be unavailable");
});

run("available() is true for a real island", () => {
  const sb = viewSandbox(ISLAND);
  assert(sb.TR.keydriver.available() === true, "should be available");
});

run("the shell lists the tab only when the view says so", () => {
  const flat = JSON.stringify(shellSandbox(ISLAND).TR.shell.tabGroups());
  has(flat, "keydriver", "tab should be listed");
  has(flat, "Key drivers", "label should be listed");

  const flatOff = JSON.stringify(shellSandbox(null).TR.shell.tabGroups());
  lacks(flatOff, "keydriver", "tab should be absent without an island");
});

run("the tab is frozen: the shell hides the filter bar while it is open", () => {
  const src = readFileSync(path.join(JS_DIR, "24_shell.js"), "utf8");
  const idx = src.indexOf('d2.state.tab === "keydriver" ||');
  assert(idx !== -1, "keydriver should be in the filter-bar hide list");
});

run("the render names the outcome and the base", () => {
  const html = render(ISLAND);
  has(html, "Overall satisfaction", "outcome label");
  has(html, "n = 900", "base");
  has(html, "effective n = 696", "effective n rounded");
});

run("the frozen notice is on the tab", () => {
  const html = render(ISLAND);
  has(html, "Report filters do not apply here", "frozen note");
});

run("a method without a bootstrap is stamped, not drawn as an empty whisker", () => {
  // Shapley is first, so it is the default method on open.
  const html = render(ISLAND);
  has(html, "no interval available", "the stamp");
  lacks(html, 'class="kd-whisker"', "no whisker should be drawn for Shapley");
});

run("a method with a bootstrap draws its whisker", () => {
  const sb = viewSandbox(ISLAND);
  sb.TR.keydriver.state.method = "relative_weight";
  const host = hostStub();
  sb.TR.keydriver.render(host);
  has(host.innerHTML, "kd-whisker", "whisker should be drawn");
  has(host.innerHTML, "41.2% to 49.9%", "interval text");
  sb.TR.keydriver.state.method = null;
});

run("a driver that moves the outcome down is marked", () => {
  const html = render(ISLAND);
  has(html, "kd-dir", "direction marker for the negative driver");
});

run("a hostile driver label cannot break out of the markup", () => {
  const html = render(ISLAND);
  lacks(html, "<script>alert(1)</script>", "raw script must not survive");
  has(html, "&lt;script&gt;", "it should be escaped instead");
});

run("every segment carries its base, and the threshold is stated", () => {
  const html = render(ISLAND);
  has(html, "n = 412", "Younger base");
  has(html, "n = 488", "Older base");
  has(html, "had to reach n = 60", "the min base rule");
});

run("the quadrant says which importance source actually made it", () => {
  const html = render(ISLAND);
  has(html, "auto (shap was requested and is absent)", "the used source");
  has(html, "shap was requested", "the substitution is visible");
});

run("severe multicollinearity is flagged with its caveat", () => {
  const html = render(ISLAND);
  has(html, "kd-flag-severe", "the severe VIF flag");
  has(html, "read the drivers as a set", "the caveat");
});

run("the diagnostics drawer carries the fit and the seed", () => {
  const html = render(ISLAND);
  has(html, "R&sup2; = 0.743", "r squared");
  has(html, "seed 2026", "the seed");
  has(html, "1000 bootstrap resamples", "the iteration count");
});

run("the interval's level comes from the island, not from the renderer", () => {
  // A study configured at 90% must not be labelled 95% by a view that assumed
  // one. The shared sig-level gate forbids typing a level into a renderer, and
  // it caught exactly this while the tab was being built.
  const ninety = JSON.parse(JSON.stringify(ISLAND));
  ninety.ci.level = 0.9;
  ninety.importance.methods = [ninety.importance.methods[1]];
  const html = render(ninety);
  has(html, "90% interval", "the study's own level");
  lacks(html, "95% interval", "the assumed level must not appear");
});

run("an island with no intervals labels the column generically", () => {
  const none = JSON.parse(JSON.stringify(ISLAND));
  delete none.ci;
  const html = render(none);
  has(html, "<th>Interval</th>", "a generic header when no level is carried");
});

run("no significance letter is borrowed from the proportion engine", () => {
  const src = readFileSync(path.join(JS_DIR, "27k_keydriver.js"), "utf8");
  lacks(src, "sigLetters", "importance must not route through the proportion tests");
});

run("a one-method island does not break the picker", () => {
  const solo = JSON.parse(JSON.stringify(ISLAND));
  solo.importance.methods = [solo.importance.methods[1]];
  solo.ci.methods = ["relative_weight"];
  const html = render(solo);
  has(html, "Relative weight", "the single method still renders");
  lacks(html, "kd-chips", "no picker for a single method");
});

run("an island with no quadrant and no segments still renders", () => {
  const bare = JSON.parse(JSON.stringify(ISLAND));
  delete bare.quadrant;
  delete bare.segments;
  delete bare.ci;
  const html = render(bare);
  has(html, "Key drivers", "the tab still draws");
  lacks(html, "kd-quadrant", "no quadrant panel");
  lacks(html, "By segment", "no segment panel");
});

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed === 0 ? 0 : 1);
