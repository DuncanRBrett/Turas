#!/usr/bin/env node
/**
 * Gate: the conjoint simulator's "Include No-Purchase" option fails closed.
 *
 * No R code writes a None utility into the simulator's data (the module
 * refuses a None alternative before estimation, 03_estimation.R), yet the
 * checkbox was drawn on every simulator and, when ticked, scored "None" at a
 * utility of 0. On zero-centred utilities that is roughly an average product,
 * so it invented a no-purchase share: 28.5% on the shipped example, which
 * never offered None (review 2026-09-24).
 *
 * Now the option exists only when the data carries a finite noneUtility, the
 * None utility is scaled with the products, and shares without it are the
 * plain product shares.
 *
 * Runs against the SHIPPED simulator JS.
 *
 * Run with:  node modules/conjoint/tests/js/test_simulator_none_option.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const JS = path.join(ROOT, "modules/conjoint/lib/html_simulator/js");

let failures = 0;
function check(label, actual, expected, tol) {
  const ok = tol === undefined ? Object.is(actual, expected)
    : (typeof actual === "number" && Math.abs(actual - expected) <= tol);
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: expected ${expected}, got ${actual}`}`);
}

/** A DOM element stub that records what the simulator writes into it. */
function makeEl(id) {
  return {
    id, _html: "", textContent: "", value: "", style: {}, dataset: {},
    set innerHTML(v) { this._html = v; },
    get innerHTML() { return this._html; },
    classList: { add() {}, remove() {}, toggle() {}, contains() { return false; } },
    addEventListener() {}, removeEventListener() {}, setAttribute() {}, removeAttribute() {},
    appendChild() {}, insertBefore() {}, remove() {},
    getAttribute() { return null; },
    getBoundingClientRect() { return { left: 0, top: 0, width: 600, height: 300 }; },
    querySelector() { return null; }, querySelectorAll() { return []; },
    closest() { return null; },
  };
}

/** Load engine, charts and UI on one data island. */
function loadSimulator(simData) {
  const els = {};
  const byId = (id) => (els[id] = els[id] || makeEl(id));
  const sandbox = {
    console, Math, setTimeout: (fn) => fn(), clearTimeout() {},
    getComputedStyle: () => ({ position: "relative" }),
    document: {
      getElementById: byId, createElement: (t) => makeEl(t),
      createElementNS: (_, t) => makeEl(t), head: makeEl("head"), body: makeEl("body"),
      querySelector() { return null; }, querySelectorAll() { return []; },
      addEventListener() {}, activeElement: null,
    },
  };
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  for (const f of ["simulator_engine.js", "simulator_charts.js", "simulator_ui.js"]) {
    vm.runInContext(readFileSync(path.join(JS, f), "utf8"), sandbox, { filename: f });
  }
  vm.runInContext("this.SimEngine = SimEngine; this.SimUI = SimUI;", sandbox);
  sandbox.SimEngine.init(simData);
  return { engine: sandbox.SimEngine, ui: sandbox.SimUI, byId };
}

// Two products whose total utilities are 1 and 0.
const base = {
  meta: { project_name: "None test", currency_symbol: "R" },
  attributes: [{ name: "Brand", levels: [
    { name: "A", utility: 1 }, { name: "B", utility: 0 }] }],
};
const PRODUCTS = [{ Brand: "A" }, { Brand: "B" }];

// --- a study with a None utility --------------------------------------------
{
  const { engine } = loadSimulator(Object.assign({ noneUtility: -1 }, base));
  // Known answer: e^1, e^0, e^-1 = 2.718, 1, 0.368; sum 4.086 -> 66.5 / 24.5 / 9.0
  const s = engine.predictSharesWithNone(PRODUCTS, engine.getNoneUtility(), "logit");
  check("logit with None: product A share", s[0], 66.52, 0.01);
  check("logit with None: product B share", s[1], 24.47, 0.01);
  check("logit with None: None share", s[2], 9.00, 0.01);

  // The None utility is on the products' scale, so the scale factor moves it too.
  // Scale 2: e^2, e^0, e^-2 = 7.389, 1, 0.135; sum 8.524 -> 86.68 / 11.73 / 1.59
  engine.setScaleFactor(2);
  const s2 = engine.predictSharesWithNone(PRODUCTS, engine.getNoneUtility(), "logit");
  check("scale factor 2 scales the None utility with the products", s2[2], 1.59, 0.01);
}

// --- a study without a None utility -----------------------------------------
{
  const { engine } = loadSimulator(base);
  check("no noneUtility in the data: getNoneUtility() is null, not 0",
    engine.getNoneUtility(), null);
  const plain = engine.predictShares(PRODUCTS, "logit");
  const withNone = engine.predictSharesWithNone(PRODUCTS, engine.getNoneUtility(), "logit");
  check("no None utility: shares are the plain product shares (count)", withNone.length, 2);
  check("no None utility: shares are the plain product shares (A)", withNone[0], plain[0], 1e-9);
}

{
  const { engine } = loadSimulator(Object.assign({ noneUtility: null }, base));
  check("a null noneUtility counts as absent", engine.getNoneUtility(), null);
}

// --- the checkbox ------------------------------------------------------------
function sharesPanelHtml(simData, tickNone) {
  const env = loadSimulator(simData);
  env.ui.init();
  if (tickNone) env.ui.toggleNone(true);
  env.ui.updateResults();
  return env.byId("cj-sim-results").innerHTML + env.byId("cj-sim-share-chart").innerHTML;
}

check("no None utility: the Include No-Purchase checkbox is not drawn",
  sharesPanelHtml(base, false).includes("cj-sim-none-cb"), false);
check("no None utility: ticking None anyway adds no None bar",
  sharesPanelHtml(base, true).includes("No Purchase"), false);
check("with a None utility: the checkbox is drawn",
  sharesPanelHtml(Object.assign({ noneUtility: -1 }, base), false).includes("cj-sim-none-cb"), true);
check("with a None utility: ticking it adds the None bar",
  sharesPanelHtml(Object.assign({ noneUtility: -1 }, base), true).includes("No Purchase"), true);

console.log(failures === 0 ? "\nAll No-Purchase checks passed." : `\n${failures} check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
