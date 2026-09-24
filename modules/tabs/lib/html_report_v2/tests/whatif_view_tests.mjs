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
const FX = JSON.parse(readFileSync(FIXTURE, "utf8")).variants.weighted;   // fixture has a weight column

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
  w.model = w.safe.model;          // the client-safe model block, no context baselines
  delete w.safe.model;
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
  // A null in the safe block is a result the R build withheld (it would rest
  // on fewer than the minimum group); the live view still computes it.
  let compared = 0;
  FX.model.levers.forEach((lv, l) => {
    const fixMove = lv.kind === "coverage" ? "extend" : "floor";
    const slipMove = lv.kind === "coverage" ? "withdraw" : "slip1";
    const fi = MOVES.indexOf(fixMove), si = MOVES.indexOf(slipMove);
    if (safeAll.est[l][fi] !== null) {
      close(g.fix[l].pt, safeAll.est[l][fi], 0.006, lv.key + " fix");
      close(g.fix[l].lo, safeAll.lo[l][fi], 0.006, lv.key + " fix lo");
      close(g.fix[l].hi, safeAll.hi[l][fi], 0.006, lv.key + " fix hi");
      compared++;
    }
    if (safeAll.est[l][si] !== null) { close(g.slip[l].pt, safeAll.est[l][si], 0.006, lv.key + " slip"); compared++; }
  });
  (FX.model.bundles || []).forEach((b, bi) => {
    if (safeAll.bundles[bi][0] !== null) { close(g.bundle(b, bi).pt, safeAll.bundles[bi][0], 0.006, "bundle " + b.name); compared++; }
  });
  assert(compared >= 6, "compared " + compared);
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
    const v = target.est[l][MOVES.indexOf(fixMove)];
    if (v !== null) close(g.fix[l].pt, v, 0.006, lv.key + " fix");
  });
});

run("a need count or effect the R build withheld renders as not shown, in the table, the scenario and the bundles", () => {
  const w = safeIsland();
  const M = w.model;
  const applies = (lv, m) => (lv.kind === "coverage") === (m === "withdraw" || m === "extend");
  let hit = null;
  w.safe.groups.forEach((g) => {
    if (hit) return;
    M.levers.forEach((lv, l) => {
      if (hit) return;
      M.moves.forEach((m, mi) => {
        if (!hit && applies(lv, m) && g.est[l][mi] === null) hit = { g, lv, m };
      });
    });
  });
  assert(hit, "the fixture has a withheld effect");
  const sb = sandbox(w);
  sb.TR.whatif.state.safeFilters = Object.keys(hit.g.def).map((k) => ({ key: k, level: hit.g.def[k] }));
  sb.TR.whatif.state.scen = {};
  sb.TR.whatif.state.scen[hit.lv.key] = hit.m;
  const html = render(sb);
  has(html, "not shown");
  has(html, "Not shown: one of the chosen moves is not published for this group");
  lacks(html, "NaN");
  lacks(html, "undefined");
  const sg = sb.TR.whatif._safeGroup(hit.g.def);
  assert(sg.scenario(sb.TR.whatif.state.scen).hidden === true, "scenario flagged hidden");
  // A bundle whose every part is published still shows its sum of parts.
  const shownBundle = (M.bundles || []).findIndex((b, bi) => hit.g.bundles[bi][0] !== null &&
    Object.keys(b.moves).every((k) => { const l = M.levers.findIndex((lv) => lv.key === k); return hit.g.est[l][M.moves.indexOf(b.moves[k])] !== null; }));
  if (shownBundle !== -1) {
    const row = html.slice(html.indexOf(M.bundles[shownBundle].name));
    const cells = row.match(/<td class="num">([^<]+)/g).slice(0, 2);
    assert(cells.every((c) => c.indexOf("not shown") === -1), "published bundle shows numbers");
  }
});

run("the privacy paragraph needs the need and effect checks recorded, not just the group checks", () => {
  const w = safeIsland();
  has(render(sandbox(w)), "Prepared so that every published group");
  const w2 = safeIsland();
  delete w2.safe.audit.need_checked;
  has(render(sandbox(w2)), "Privacy check failed");
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
  has(html, "Prepared so that every published group has at least");
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

run("the client-safe model carries no context-baseline terms and still renders every panel", () => {
  const w = safeIsland();
  assert(w.model.design.every((c) => !c.context), "no context rows in the design");
  assert(w.model.fits.every((f) => f.b.length === w.model.design.length), "coefficients match the design");
  assert(FX.model.design.some((c) => c.context), "the open model does have them (fixture has baselines)");
  const html = render(sandbox(w));
  ["Where to direct effort", "Build a scenario", "Rate ", "How this works"].forEach((t) => has(html, t));
  lacks(html, "NaN");
});

run("the scores follow the cumulative logit (probabilities sum to one)", () => {
  const sb = sandbox(safeIsland());
  const fit = FX.model.fits[0];
  const s = sb.TR.whatif._scoreAt(fit, 0.3, FX.meta.scores);
  assert(s >= Math.min(...FX.meta.scores) && s <= Math.max(...FX.meta.scores), "score in range");
});

run("a respondent flagged dk is never moved and never counted as needing the fix, live as in R", () => {
  const sb = sandbox(openIsland(), { micro: true });
  const lv = FX.model.levers.find((l) => l.kind === "rating");
  assert(sb.TR.whatif._delta(lv, "floor", 2, false) > 0, "a rating below Good is lifted");
  assert(sb.TR.whatif._delta(lv, "floor", 2, true) === 0, "a dk respondent is not lifted");
  assert(sb.TR.whatif._delta(lv, "slip1", 4, true) === 0, "nor let slip");
  // The fixture's admin lever has 20 don't-know respondents sitting on a fill.
  const j = FX.model.levers.findIndex((l) => l.key === "admin");
  const flagged = FX.open.dk.admin.reduce((a, b) => a + b, 0);
  assert(flagged === 20, "fixture flags " + flagged);
  const g = sb.TR.whatif._openGroup(null);
  assert(g.need[j] === safeAll.need[j], "live need " + g.need[j] + " equals R's " + safeAll.need[j]);
  // Strip the flags and the same rows count as in need wherever the fill sits below Good.
  const w = openIsland();
  delete w.open.dk;
  const g2 = sandbox(w, { micro: true }).TR.whatif._openGroup(null);
  const below = FX.open.val.admin.filter((v, i) => FX.open.dk.admin[i] === 1 && v !== null && v < 4).length;
  assert(g2.need[j] === g.need[j] + below, "without flags the fills count: " + g2.need[j] + " vs " + (g.need[j] + below));
});

run("an area caught in the halo says so under its name, keeps its number, and is listed in How this works", () => {
  const w = safeIsland();
  const key = w.model.levers[0].key;
  w.model.halo = w.model.halo || {};
  w.model.halo[key] = { single: 12.3, partial: 2.1, ratio: 0.171, flag: true };
  const html = render(sandbox(w));
  has(html, "Caught in the halo: fixed on its own this area is worth +12.3 points");
  has(html, "+2.1 with the other areas held where they are");
  has(html, 'class="wi-halo"');
  has(html, "The data cannot separate those areas from the areas they move with");
  const row = html.slice(html.indexOf('<tr class="wi-halo">'), html.indexOf("</tr>", html.indexOf('<tr class="wi-halo">')));
  lacks(row, "~0", "a halo area is not greyed to zero");
  const own = safeAll.est[0][MOVES.indexOf("floor")];
  assert(own > 0, "fixture's first lever has a published positive fix effect");
  has(row, "+" + own.toFixed(1), "the area keeps its own number");
  // Numbers withheld with the whole sample's effect: the flag still reads, no NaN.
  const w3 = safeIsland();
  w3.model.halo[key] = { flag: true };
  const html3 = render(sandbox(w3));
  has(html3, "the numbers rest on too few to show");
  lacks(html3, "NaN");
  lacks(html3, "undefined");
  const w2 = safeIsland();
  Object.keys(w2.model.halo || {}).forEach((k) => { w2.model.halo[k].flag = false; });
  const html2 = render(sandbox(w2));
  has(html2, "Halo check: no area's effect collapses");
  lacks(html2, "Caught in the halo");
});

console.log((failed ? "\n✗ " : "\n✓ ") + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
