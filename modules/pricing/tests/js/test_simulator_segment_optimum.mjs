#!/usr/bin/env node
/**
 * Gate: a segment in the pricing simulator is compared with ITS OWN optimum.
 *
 * The simulator used the total sample's revenue-optimal price for the
 * "% vs optimum" delta and for the comparison table's "Revenue, % of optimum"
 * row and its "(peak)" marker, while it took the revenue itself from the
 * selected segment's curve. A segment whose best price differed read "at
 * optimum" at the wrong price and more than 100% of its "optimum" at its real
 * one (review 2026-09-24).
 *
 * A segment's optimum follows the rule R uses for the total
 * (find_optimal_price, modules/pricing/R/04_gabor_granger.R): the tested price
 * with the highest price x intent, the first one on a tie (which.max).
 *
 * Runs against the SHIPPED simulator JS.
 *
 * Run with:  node modules/pricing/tests/js/test_simulator_segment_optimum.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..", "..", "..");
const SIM_JS = path.join(ROOT, "modules/pricing/lib/html_simulator/js/pricing_simulator.js");

let failures = 0;
function check(label, actual, expected) {
  const ok = Object.is(actual, expected) ||
    (typeof actual === "number" && typeof expected === "number" &&
     Math.abs(actual - expected) < 1e-9);
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${label}${ok ? "" : `: expected ${expected}, got ${actual}`}`);
}

/** A DOM element stub that records what the simulator writes into it. */
function makeEl(id) {
  const listeners = {};
  const el = {
    id, _html: "", textContent: "", className: "", value: "",
    style: {}, dataset: {}, clientWidth: 600, clientHeight: 300,
    set innerHTML(v) { this._html = v; },
    get innerHTML() { return this._html; },
    classList: { add() {}, remove() {}, toggle() {} },
    addEventListener(type, fn) { listeners[type] = fn; },
    setAttribute() {}, appendChild() {},
    getAttribute(name) { return name === "data-seg" ? el._seg : null; },
    getBoundingClientRect() { return { left: 0, top: 0, width: 600, height: 300 }; },
    querySelector() { return null; },
    querySelectorAll() {
      // The segment toggle: one button per data-seg in the HTML just written,
      // the same objects on every call so the click handlers stay attached.
      if (this._buttonsFor !== this._html) {
        this._buttonsFor = this._html;
        this._buttons = [...this._html.matchAll(/data-seg="([^"]*)"/g)].map((m) => {
          const btn = makeEl("btn-" + m[1]);
          btn._seg = m[1];
          return btn;
        });
      }
      return this._buttons;
    },
    _listeners: listeners,
  };
  return el;
}

/** Load the simulator on one data island and return its handle and DOM. */
function loadSimulator(pricingData) {
  const els = {};
  const byId = (id) => (els[id] = els[id] || makeEl(id));
  const sandbox = {
    console,
    document: {
      getElementById: byId,
      createElement: (t) => makeEl(t),
      createElementNS: (_, t) => makeEl(t),
      querySelector() { return null; }, querySelectorAll() { return []; },
      addEventListener() {}, activeElement: null,
    },
    PRICING_DATA: pricingData,
    PRICING_CONFIG: { currency: "R", unit_cost: 0 },
  };
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(readFileSync(SIM_JS, "utf8") + "\n;this.PricingSimulator = PricingSimulator;",
    sandbox, { filename: "pricing_simulator.js" });
  const sim = sandbox.PricingSimulator;
  sim.init();
  return { sim, els, byId };
}

/** Select a segment the way a click on its toggle button does. */
function selectSegment(env, seg) {
  const container = env.byId("sim-segment-buttons");
  const buttons = container.querySelectorAll(".sim-segment-btn");
  const target = buttons.find((b) => b.getAttribute("data-seg") === seg);
  target._listeners.click.call(target);
}

/** The comparison table cell text for one row label, scenario index i. */
function tableCell(env, rowLabel, i) {
  const html = env.byId("sim-compare-tbody").innerHTML;
  const row = html.split("<tr>").find((r) => r.includes(`<td>${rowLabel}`));
  if (!row) return null;
  const cells = [...row.matchAll(/<td[^>]*>(.*?)<\/td>/g)].map((m) => m[1]);
  return cells[i + 1].replace(/<[^>]+>/g, "").trim();
}

// Total: revenue 10 x .9 = 9, 20 x .5 = 10, 30 x .2 = 6. R's optimum is 20,
// but R reports 10 here so a segment can be told apart from the total.
const DATA = {
  price_range: [10, 20, 30], demand_curve: [0.9, 0.5, 0.2], revenue_curve: [9, 10, 6],
  optimal_price: 10,
  segments: {
    // Worked example from the brief: revenue 9 / 12 / 6, so the optimum is 20.
    Young: { price_range: [10, 20, 30], demand_curve: [0.9, 0.6, 0.2], revenue_curve: [9, 12, 6] },
    // A tie: 10 x .6 = 6 and 20 x .3 = 6. The first tested price wins.
    Tied: { price_range: [10, 20, 30], demand_curve: [0.6, 0.3, 0.1], revenue_curve: [6, 6, 3] },
    // No usable curve.
    Empty: { price_range: [], demand_curve: [], revenue_curve: [] },
  },
};

// --- optimalPriceFor: the rule itself ---------------------------------------
{
  const env = loadSimulator(DATA);
  // Reported as a failure, not a crash, if the hook is missing, so the page
  // checks below still run against an older simulator.
  const optimalPriceFor = env.sim._optimalPriceFor || (() => undefined);
  check("total view uses R's optimum, unchanged", optimalPriceFor("total"), 10);
  check("segment optimum is the tested price with the highest revenue",
    optimalPriceFor("Young"), 20);
  check("a tie takes the first tested price, as which.max does",
    optimalPriceFor("Tied"), 10);
  check("a segment with no curve has no optimum", optimalPriceFor("Empty"), null);
  check("an unknown segment has no optimum", optimalPriceFor("Nobody"), null);
}

// --- the comparison table in a segment view ---------------------------------
{
  const env = loadSimulator(DATA);
  selectSegment(env, "Young");
  env.sim.getState().scenarios.push({ price: 20 }, { price: 10 });
  env.sim._onPriceChange(0, "20");
  check("at the segment's optimum the table reads 100% (peak), not 133%",
    tableCell(env, "Revenue, % of optimum", 0), "100% (peak)");
  check("a scenario at the total's optimum reads 75% of the segment's",
    tableCell(env, "Revenue, % of optimum", 1), "75%");
  check("the vs Optimal row names the segment's optimum",
    env.byId("sim-compare-tbody").innerHTML.includes("vs Optimal (R20"), true);
}

// --- the metric card delta in a segment view --------------------------------
{
  const env = loadSimulator(DATA);
  env.sim.getState().currentPrice = 20;
  selectSegment(env, "Young");
  check("the delta at the segment's optimum says at optimum",
    env.byId("sim-revenue-delta").textContent, "at optimum");
}

// --- a segment without a curve shows no comparison ---------------------------
{
  const env = loadSimulator(DATA);
  env.sim.getState().currentPrice = 20;
  selectSegment(env, "Young");
  selectSegment(env, "Empty");
  check("no optimum clears the delta rather than keeping the last one",
    env.byId("sim-revenue-delta").textContent, "");
  env.sim.getState().scenarios.push({ price: 20 });
  env.sim._onPriceChange(0, "20");
  check("no optimum drops the % of optimum row", tableCell(env, "Revenue, % of optimum", 0), null);
}

// --- the total view is unchanged --------------------------------------------
{
  const env = loadSimulator(DATA);
  env.sim.getState().scenarios.push({ price: 10 });
  env.sim._onPriceChange(0, "10");
  check("total view: the total's optimum still reads 100% (peak)",
    tableCell(env, "Revenue, % of optimum", 0), "100% (peak)");
}

console.log(failures === 0 ? "\nAll segment optimum checks passed." : `\n${failures} check(s) FAILED.`);
process.exit(failures === 0 ? 0 : 1);
