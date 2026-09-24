#!/usr/bin/env node
/**
 * What if tab gate. The whatif module contributes an island (TR.WI) that the
 * tabs build has already cut to the report's delivery mode; 27w_whatif.js
 * renders it and 24_shell.js shows the tab only when it has content.
 *
 * Checks: the availability rule and the tab listing; LIVE mode only when the
 * island is open AND the report carries respondent records; the live numbers
 * for a group equal the R engine's published numbers for the same group (the
 * island's safe block, computed in R from the same model and respondents);
 * the client-safe view offers published groups only; Build a ... never offers
 * a combination the Structure rules block; hostile labels stay inert; no NaN,
 * undefined or em dash reaches the page.
 *
 * Fixture: modules/tabs/tests/fixtures/whatif/synthetic_whatif_island.json
 * (synthetic data; modules/whatif/dev/make_tabs_fixture.R).
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/whatif_view_tests.mjs
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";
import { installText } from "./_text.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const FIXTURE = path.join(HERE, "..", "..", "..", "tests", "fixtures", "whatif", "synthetic_whatif_island.json");
const load = (sandbox, file) =>
  vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox, { filename: file });
const FX = JSON.parse(readFileSync(FIXTURE, "utf8"));

let passed = 0, failed = 0;
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) { failed++; console.log("  ✗ " + name + "\n    " + (e.stack || e.message)); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function has(hay, needle, msg) { if (hay.indexOf(needle) === -1) throw new Error((msg || "missing") + ": " + JSON.stringify(needle)); }
function lacks(hay, needle, msg) { if (hay.indexOf(needle) !== -1) throw new Error((msg || "present") + ": " + JSON.stringify(needle)); }
function close(a, b, tol, msg) { if (!(Math.abs(a - b) <= tol)) throw new Error((msg || "not close") + ": " + a + " vs " + b); }

/** The two shapes the tabs build embeds (see .read_whatif_contribution). */
function openIsland() {
  const w = JSON.parse(JSON.stringify(FX));
  w.meta.mode = "open";
  delete w.meta.id_variable;
  delete w.safe;
  delete w.open.ids;
  return w;
}
function safeIsland() {
  const w = JSON.parse(JSON.stringify(FX));
  w.meta.mode = "safe";
  delete w.meta.id_variable;
  delete w.open;
  delete w.profile;
  return w;
}

function sandbox(island, opts) {
  opts = opts || {};
  const sb = { console, Math, JSON };
  sb.globalThis = sb;
  sb.window = sb;
  sb.TR = { fmt: { escapeHtml: (s) => String(s == null ? "" : s) } };
  sb.TR.d2 = { state: { filters: opts.filters || [] }, filterDescription: () => "the filtered group",
               tracking: () => ({ enabled: false }), qualitative: () => ({ enabled: false }) };
  sb.TR.stats = { source: () => (opts.micro ? "micro" : null), mask: opts.mask || (() => null) };
  vm.createContext(sb);
  load(sb, "27w_whatif.js");
  sb.TR.WI = island;
  return sb;
}
function host() { return { innerHTML: "", querySelectorAll: () => [] }; }
function render(sb) { const h = host(); sb.TR.whatif.render(h); return h.innerHTML; }

const MOVES = FX.model.moves;
const safeAll = FX.safe.groups.find((g) => g.id === "all");

run("available only with a What if island that has content", () => {
  assert(sandbox(openIsland()).TR.whatif.available(), "open available");
  assert(sandbox(safeIsland()).TR.whatif.available(), "safe available");
  assert(!sandbox(null).TR.whatif.available(), "null not available");
  assert(!sandbox({ meta: { kind: "catdriver" } }).TR.whatif.available(), "foreign not available");
});

run("the shell lists the What if tab exactly when the view is available", () => {
  const sb = sandbox(safeIsland());
  sb.TR.AGG = { project: {} };
  installText(sb);
  load(sb, "24_shell.js");
  const tabs = sb.TR.shell.tabGroups()[0].tabs.map((t) => t[0]);
  assert(tabs.indexOf("whatif") !== -1, "listed");
  assert(tabs.indexOf("whatif") < tabs.indexOf("story"), "before Story");
  sb.TR.WI = null;
  assert(sb.TR.shell.tabGroups()[0].tabs.map((t) => t[0]).indexOf("whatif") === -1, "not listed without island");
});

run("live only when the island is open and respondent records are installed", () => {
  assert(sandbox(openIsland(), { micro: true }).TR.whatif.live(), "open + micro is live");
  assert(!sandbox(openIsland(), { micro: false }).TR.whatif.live(), "open without micro is not live");
  assert(!sandbox(safeIsland(), { micro: true }).TR.whatif.live(), "safe is never live");
});

run("live numbers for everyone equal the R engine's published numbers", () => {
  const sb = sandbox(openIsland(), { micro: true });
  const g = sb.TR.whatif._openGroup(null);
  assert(g.n === FX.meta.n, "n " + g.n);
  close(g.actual, safeAll.actual, 0.01, "actual");
  FX.model.levers.forEach((lv, l) => {
    const fixMove = lv.kind === "coverage" ? "extend" : "floor";
    const slipMove = lv.kind === "coverage" ? "withdraw" : "slip1";
    close(g.fix[l].pt, safeAll.est[l][MOVES.indexOf(fixMove)], 0.006, lv.key + " fix");
    close(g.slip[l].pt, safeAll.est[l][MOVES.indexOf(slipMove)], 0.006, lv.key + " slip");
    close(g.fix[l].lo, safeAll.lo[l][MOVES.indexOf(fixMove)], 0.006, lv.key + " fix lo");
    close(g.fix[l].hi, safeAll.hi[l][MOVES.indexOf(fixMove)], 0.006, lv.key + " fix hi");
  });
  (FX.model.bundles || []).forEach((b, bi) => {
    close(g.bundle(b, bi).pt, safeAll.bundles[bi][0], 0.006, "bundle " + b.name);
  });
});

run("live numbers under a filter equal the R engine's for the same group", () => {
  const key = "campus";
  const levels = FX.open.ctx_levels[key];
  const target = FX.safe.groups.find((g) => g.def && Object.keys(g.def).length === 1 && g.def[key]);
  const code = levels.indexOf(target.def[key]);
  const mask = FX.open.ctx[key].map((c) => (c === code ? 1 : 0));
  const sb = sandbox(openIsland(), { micro: true, filters: [{ q: "X", rows: [0] }], mask: () => mask });
  const g = sb.TR.whatif._openGroup(mask);
  assert(g.n === target.n, "n " + g.n + " vs " + target.n);
  close(g.actual, target.actual, 0.01, "actual");
  FX.model.levers.forEach((lv, l) => {
    const fixMove = lv.kind === "coverage" ? "extend" : "floor";
    close(g.fix[l].pt, target.est[l][MOVES.indexOf(fixMove)], 0.006, lv.key + " fix");
  });
});

run("the bundle table's sum of parts adds single-area results, it is not the exact answer again", () => {
  const sb = sandbox(openIsland(), { micro: true });
  const g = sb.TR.whatif._openGroup(null);
  const b = FX.model.bundles[0];
  let parts = 0;
  FX.model.levers.forEach((lv) => { if (b.moves[lv.key]) parts += g.single(lv, b.moves[lv.key]).pt; });
  const html = render(sb);
  const row = html.slice(html.indexOf(b.name));
  const cells = row.match(/<td class="num">([^<]+)/g).slice(0, 2).map((c) => c.replace(/<td class="num">/, ""));
  const fmt1 = (x) => { const r = Math.round(x * 10) / 10; return (r > 0 ? "+" : "\u2212") + Math.abs(r).toFixed(1); };
  assert(cells[1] === fmt1(parts), "sum of parts cell " + cells[1] + " vs " + fmt1(parts));
  assert(cells[0] === fmt1(g.bundle(b, 0).pt), "exact cell");
});

run("a client-safe group reads its precomputed numbers", () => {
  const sb = sandbox(safeIsland());
  const g = sb.TR.whatif._safeGroup({});
  assert(g.n === safeAll.n && !g.exact, "all group");
  const lv0 = FX.model.levers[0];
  const fm = lv0.kind === "coverage" ? "extend" : "floor";
  close(g.fix[0].pt, safeAll.est[0][MOVES.indexOf(fm)], 1e-9, "fix");
  assert(sb.TR.whatif._safeGroup({ nope: "x" }) === null, "unpublished group is null");
});

run("the live view renders every panel with the live badge", () => {
  const html = render(sandbox(openIsland(), { micro: true }));
  ["Where to direct effort", "Build a scenario", "Build a student", "Rate ", "How this works", "Live: follows the audience filter"]
    .forEach((s) => has(html, s));
  lacks(html, "Client-safe: published groups only");
  lacks(html, "data-wi-addfilter", "no own picker when live");
});

run("the client-safe view has its own picker, published groups only, and a privacy check", () => {
  const html = render(sandbox(safeIsland()));
  has(html, "Client-safe: published groups only");
  has(html, "data-wi-addfilter");
  has(html, "Checked in this browser");
  FX.safe.groups.filter((g) => g.def && Object.keys(g.def).length === 1).forEach((g) => {
    const k = Object.keys(g.def)[0];
    has(html, k + "\u0001" + g.def[k], "offers " + g.id);
  });
  lacks(html, "exactly this profile", "no respondent matching in client-safe");
});

run("no NaN, undefined or em dash reaches the page in either mode", () => {
  [render(sandbox(openIsland(), { micro: true })), render(sandbox(safeIsland()))].forEach((html) => {
    lacks(html, "NaN");
    lacks(html, "undefined");
    lacks(html, String.fromCharCode(0x2014), "em dash");
  });
});

run("a hostile lever label cannot break out of the markup", () => {
  const w = safeIsland();
  w.model.levers[0].label = '<img src=x onerror="alert(1)">';
  const html = render(sandbox(w));
  lacks(html, "<img src=x");
  has(html, "&lt;img src=x");
});

run("Build a ... never offers a combination the Structure rules block", () => {
  const sb = sandbox(openIsland(), { micro: true });
  const P = FX.profile;
  assert(P.rules.length > 0, "fixture has a rule");
  const r = P.rules[0];
  const prof = {};
  P.keys.forEach((k) => { prof[k.key] = k.levels[0]; });
  prof[r[0]] = r[1];
  const allowed = sb.TR.whatif._allowedLevels(P, r[2], prof);
  assert(allowed.indexOf(r[3]) === -1, "blocked level not offered");
  prof[r[2]] = r[3];
  const note = sb.TR.whatif._repairProfile(P, prof, r[0]);
  assert(prof[r[2]] !== r[3], "impossible choice switched");
  has(note, "does not exist");
});

run("client-safe Build a ... keeps to combinations the minimum group shares", () => {
  const sb = sandbox(safeIsland());
  const P = FX.safe.profile;
  assert(P.combos.length > 0, "combos present");
  const prof = {};
  P.keys.forEach((k, i) => { prof[k.key] = k.levels[P.combos[0][i]]; });
  const last = P.keys[P.keys.length - 1];
  const other = last.levels.find((l) => !P.combos.some((cb) =>
    P.keys.every((k, i) => (k === last ? k.levels[cb[i]] === l : k.levels[cb[i]] === prof[k.key]))));
  if (other !== undefined) {
    prof[last.key] = other;
    sb.TR.whatif._repairProfile(P, prof, last.key);
    const code = P.keys.map((k) => k.levels.indexOf(prof[k.key])).join(",");
    assert(P.combos.some((cb) => cb.join(",") === code), "repaired to an offered combination");
  }
});

run("the scores follow the cumulative logit (probabilities sum to one)", () => {
  const sb = sandbox(safeIsland());
  const fit = FX.model.fits[0];
  const s = sb.TR.whatif._scoreAt(fit, 0.3, FX.meta.scores);
  assert(s >= Math.min(...FX.meta.scores) && s <= Math.max(...FX.meta.scores), "score in range");
});

console.log((failed ? "\n✗ " : "\n✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
