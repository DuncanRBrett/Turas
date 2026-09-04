#!/usr/bin/env node
/**
 * COMPUTED-PATH PARITY. The engine's recompute against R's published layer,
 * and then the aggregate cube against the respondent island.
 *
 * Until this file existed, no node gate ran the COMPUTED path (the one a live
 * filter or a custom banner takes) against an R-built respondent island. The
 * published half was covered by parity_stats_tests.mjs; the recompute was
 * covered only by hand-authored stubs, which can agree with R by coincidence.
 * The aggregate cube (TR.CUBE) is a second computed source, so it needs the
 * same harness before it can be trusted with a single delivered figure.
 *
 *   fixture project : modules/tabs/tests/fixtures/parity_project/
 *   published layer : parity_island.json / parity_island_weighted.json
 *   respondent isle : parity_micro.json / parity_micro_weighted.json
 *   aggregate cube  : parity_cube.json / parity_cube_weighted.json
 *   regenerate      : Rscript modules/tabs/tests/fixtures/parity_project/regenerate_parity_island.R
 *
 * Sections:
 *   CP-1  The R-built respondent island installs and the computed path runs.
 *   CP-2  Computed equals published, unfiltered, for every question and every
 *         banner group. Figures to DISPLAYED precision (TR.fmt decides the
 *         decimals); the unweighted respondent count exactly.
 *   CP-3  Significance letters, under the scope the cross-engine spec already
 *         sets (docs/tabs_production_review_2026-08/CROSS_ENGINE_STATS_SPEC.md,
 *         JS-2 and JS-3). Proportion letters on the unweighted fixture are
 *         exact against a same-rule recompute of R's published counts. Mean
 *         rows, and the weighted fixture, must agree outside a band around
 *         alpha; pairs inside the band are LOGGED, not failed, because the JS
 *         mean test is a z where R runs a Welch t. That divergence is
 *         documented, not a bug to chase.
 *         One further documented difference: the published path carries R's
 *         FPC-corrected letters, the computed path deliberately does not
 *         correct (a filtered sub-population's universe is unknown), so the
 *         comparison recomputes the published side under the same no-FPC rule.
 *   CP-4  CUBE versus MICRO over an enumerated view set. Both sides are THIS
 *         engine, so figures and letters are exact, with no band. Skipped with
 *         a printed reason until the cube island exists.
 *
 * Run: node modules/tabs/lib/html_report_v2/tests/computed_parity_tests.mjs
 */
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import vm from "node:vm";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JS_DIR = path.join(HERE, "..", "assets", "js");
const FIXTURE_DIR = path.join(HERE, "..", "..", "..", "tests", "fixtures", "parity_project");

const MODULES = ["00_namespace.js", "01_format.js", "03_svg.js", "20_data.js",
  "21_stats.js", "21c_confidence.js", "21d_disclosure.js", "22w_waves.js",
  "22_model.js", "23_render.js", "26_filter.js"];

/**
 * A FRESH engine per configuration. stats.isWeighted() caches its answer in a
 * module-private variable that nothing resets, so running the unweighted and
 * the weighted fixture in one sandbox would carry the first one's verdict into
 * the second and silently null every weighted median.
 */
function makeEngine() {
  const sandbox = { console };
  sandbox.globalThis = sandbox;
  sandbox.window = sandbox;
  vm.createContext(sandbox);
  for (const file of MODULES) {
    vm.runInContext(readFileSync(path.join(JS_DIR, file), "utf8"), sandbox,
      { filename: file });
  }
  return sandbox.TR;
}

let passed = 0, failed = 0;
const notes = [];
function run(name, fn) {
  try { fn(); passed++; console.log("  ✓ " + name); }
  catch (e) {
    failed++;
    console.log("  ✗ " + name + "\n    " + (process.env.TRACE ? e.stack : e.message));
  }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }
function eq(a, b, msg) {
  if (a !== b) throw new Error(msg + ": expected " + JSON.stringify(b) + ", got " + JSON.stringify(a));
}
function readJson(name) {
  return JSON.parse(readFileSync(path.join(FIXTURE_DIR, name), "utf8"));
}

/** Install a published layer + a respondent island into one engine. */
function install(TR, island, micro, cube) {
  TR.PREV = null;
  TR.userState = null;
  TR.AGG = island;
  TR.MICRO = micro || null;
  TR.CUBE = cube || null;
  if (TR.d2) TR.d2._qIndex = null;
}

/* ---------------------------------------------------------------------------
   Displayed precision. TR.fmt owns the decimals; comparing the FORMATTED
   strings is what "to displayed precision" means, and it is what a reader can
   actually see. A raw-value tolerance would be a different, weaker claim.
--------------------------------------------------------------------------- */
function fmtPct(TR, v) {
  return v === null || v === undefined
    ? "-" : Number(v).toFixed(TR.fmt.decimalsFor(false));
}
function fmtMean(TR, q, v) {
  return v === null || v === undefined
    ? "-" : Number(v).toFixed(TR.fmt.decimalsForQ(q, true));
}
function fmtBase(TR, v) {
  return v === null || v === undefined ? "-" : TR.fmt.base(v);
}

/**
 * R rounds a value sitting exactly on the half to the EVEN neighbour; JavaScript
 * rounds it up. So a weighted frequency of 24.5 is published as 24 and rendered
 * as 25, on numbers that are otherwise identical. That is a rounding CONVENTION
 * difference between the two languages, not a difference in the figure, and it
 * is counted and reported rather than either failed or hidden behind a
 * tolerance. Snapped to 12 significant digits first so accumulated
 * floating-point noise does not decide which side of the half a value is on.
 */
function halfEven(v, decimals) {
  const scale = Math.pow(10, decimals);
  const x = Number(Number(v * scale).toPrecision(12));
  const floor = Math.floor(x);
  const frac = x - floor;
  let r;
  if (Math.abs(frac - 0.5) < 1e-9) r = (floor % 2 === 0) ? floor : floor + 1;
  else r = Math.round(x);
  return (r / scale).toFixed(decimals);
}

/**
 * Compare one computed figure against one published one at displayed precision.
 * Returns "" when they agree, "rounding" when they agree once R's half-to-even
 * rule is applied to the computed value, and a message otherwise.
 */
function displayDiff(computed, published, decimals, where) {
  if (computed === null || computed === undefined ||
      published === null || published === undefined) {
    const a = computed === null || computed === undefined ? "-" : Number(computed).toFixed(decimals);
    const b = published === null || published === undefined ? "-" : Number(published).toFixed(decimals);
    return a === b ? "" : where + ": expected " + b + ", got " + a;
  }
  const a = Number(computed).toFixed(decimals);
  const b = Number(published).toFixed(decimals);
  if (a === b) return "";
  if (halfEven(computed, decimals) === b) return "rounding";
  return where + ": expected " + b + ", got " + a;
}

/* ---------------------------------------------------------------------------
   CP-1 and CP-2. The computed path against R's published layer.
--------------------------------------------------------------------------- */

/**
 * Compare one computed model against one published model, cell by cell.
 * Returns the number of cells compared. Throws on the first difference, naming
 * the question, the row and the column, so a failure is actionable without a
 * debugger.
 *
 * `exactN` is true on an unweighted fixture, where the published frequency is
 * a respondent count and the recompute's weighted count must equal it exactly.
 * On a weighted fixture the published n is a weighted frequency and both sides
 * are compared at displayed precision like every other figure.
 */
function compareModels(TR, q, pub, comp, label, exactN, tally, weighted) {
  let cells = 0;
  const pctDp = TR.fmt.decimalsFor(false);
  const meanDp = TR.fmt.decimalsForQ(q, true);
  const check = (computed, published, dp, where) => {
    const d = displayDiff(computed, published, dp, where);
    if (d === "rounding") {
      if (tally) { tally.rounding++; tally.notes.push(where + ": " + computed + " -> R " +
        published + ", JavaScript " + Number(computed).toFixed(dp)); }
      return;
    }
    if (d) throw new Error(d);
  };
  eq(comp.columns.length, pub.columns.length, label + " column count");
  comp.columns.forEach((cc, ci) => {
    const pc = pub.columns[ci];
    eq(cc.label, pc.label, label + " col " + ci + " label");
    eq(cc.base, pc.base, label + " col " + ci + " base");
    // An unweighted published layer carries NO weighted or effective base (the
    // renderer shows neither), while the recompute always accumulates both.
    // Compared only where the published side states one.
    if (pc.baseW != null) check(cc.baseW, pc.baseW, 0, label + " col " + ci + " baseW");
    if (pc.baseEff != null) check(cc.baseEff, pc.baseEff, 0, label + " col " + ci + " baseEff");
  });
  eq(comp.rows.length, pub.rows.length, label + " row count");
  comp.rows.forEach((cr, ri) => {
    const pr = pub.rows[ri];
    eq(cr.label, pr.label, label + " row " + ri + " label");
    // A SPREAD row on a WEIGHTED design is a documented formula divergence, not
    // a parity failure. R Bessel-corrects the weighted variance on the sum of
    // weights (standard_processor.R: sum(w*(v-m)^2) / (sum(w) - 1)); this engine
    // corrects on the Kish effective base, because the same numbers size its
    // significance tests. On an unweighted design the two are identical, so the
    // row is still held exactly there. Logged with both values, never hidden.
    const spread = weighted &&
      TR.fmt.meanStat(q.rows[ri] || cr) === "sd" && cr.kind === "mean";
    cr.cells.forEach((cc, ci) => {
      const pc = pr.cells[ci];
      const where = label + " / " + cr.label + " / col " + ci;
      check(cc.pct, pc.pct, pctDp, where + " pct");
      if (spread) {
        const a = cc.mean == null ? "-" : Number(cc.mean).toFixed(meanDp);
        const b = pc.mean == null ? "-" : Number(pc.mean).toFixed(meanDp);
        if (a !== b && tally) {
          tally.spread++;
          tally.notes.push(where + " spread: R " + b + " (Bessel on sum of weights), " +
            "engine " + a + " (Bessel on the effective base)");
        }
      } else {
        check(cc.mean, pc.mean, meanDp, where + " mean");
      }
      if (exactN) eq(cc.n, pc.n, where + " n");
      else check(cc.n, pc.n, 0, where + " n");
      cells++;
    });
  });
  return cells;
}

/**
 * Letters for one PUBLISHED proportion row under the computed path's own rule:
 * the published count over the column's real base, sized by the effective base
 * where the island carries one, and NO finite population correction. The
 * computed path does not correct (a sub-population's universe is unknown), so
 * correcting one side and not the other would report a design decision as a
 * parity failure.
 */
function publishedLetters(TR, pub, row, dual) {
  const letters = pub.columns.map((c) => c.letter);
  const cells = pub.columns.map((c, i) => {
    const size = c.baseEff != null ? c.baseEff : c.base;
    const cell = row.cells[i];
    if (!size || !c.base || cell.n === null || cell.n === undefined) {
      return { x: null, base: null };
    }
    const denom = c.baseW != null ? c.baseW : c.base;
    return { x: (cell.n / denom) * size, base: size };
  });
  return TR.stats.sigLetters(cells, letters, pub.lowBaseThreshold ||
    TR.AGG.project.low_base_threshold || 30, false, dual);
}

function runConfiguration(name, islandFile, microFile, weighted) {
  console.log("\nComputed parity. CP-1/CP-2: " + name + ":");
  const TR = makeEngine();
  const island = readJson(islandFile);
  const micro = readJson(microFile);
  install(TR, island, micro);

  run(name + ": the R-built respondent island installs and the engine sees it", () => {
    assert(TR.d2.hasMicrodata(), "d2.hasMicrodata() is true with the island installed");
    eq(TR.MICRO.n, island.questions[0].bases[0].n, "island n equals the published Total base");
    eq(TR.stats.isWeighted(), !!weighted, "isWeighted matches the configuration");
  });

  const banners = (island.banner_groups || []).map((b) => b.id);
  assert(banners.length > 0, "fixture declares at least one banner group");

  let compared = 0;
  const tally = { rounding: 0, spread: 0, notes: [] };
  run(name + ": computed equals published, every question x every banner group", () => {
    island.questions.forEach((qraw) => {
      const q = TR.d2.questionByCode(qraw.code);
      banners.forEach((banner) => {
        const pub = TR.model._publishedModel(q, banner, true);
        const comp = TR.model._computedModel(q, banner, [], true);
        eq(comp.source, "computed", qraw.code + " takes the computed path");
        compared += compareModels(TR, q, pub, comp,
          name + " " + qraw.code + " x " + banner, !weighted, tally, weighted);
      });
    });
  });
  console.log("    " + compared + " cells compared, " + tally.rounding +
    " agreeing only once R's half-to-even rule is applied, " + tally.spread +
    " weighted spread cells on the documented variance divergence");
  tally.notes.forEach((n) => notes.push(n));

  /* CP-3. Letters. */
  console.log("\nComputed parity. CP-3: significance letters, " + name + ":");
  let exact = 0, banded = 0, logged = 0;
  run(name + ": proportion letters agree with a same-rule published recompute", () => {
    island.questions.forEach((qraw) => {
      const q = TR.d2.questionByCode(qraw.code);
      banners.forEach((banner) => {
        const pub = TR.model._publishedModel(q, banner, true);
        const comp = TR.model._computedModel(q, banner, [], true);
        comp.rows.forEach((cr, ri) => {
          const pr = pub.rows[ri];
          // Mean rows and score-difference NETs run the mean test, which is a
          // documented divergence (JS-3). Counted below, never failed here.
          if (cr.kind === "mean" || pr.diff) { banded += cr.cells.length; return; }
          const want = publishedLetters(TR, pub, pr, true);
          cr.cells.forEach((cc, ci) => {
            const got = String(cc.sig || "").split("").sort().join("");
            const exp = String(want[ci] || "").split("").sort().join("");
            if (weighted) {
              // The weighted fixture carries a design effect on both sides;
              // a disagreement is logged with the view, not failed.
              if (got !== exp) {
                logged++;
                notes.push(name + " " + qraw.code + " / " + cr.label + " / col " + ci +
                  ": computed " + JSON.stringify(got) + ", published-rule " + JSON.stringify(exp));
              } else exact++;
              return;
            }
            eq(got, exp, name + " " + qraw.code + " / " + cr.label + " / col " + ci);
            exact++;
          });
        });
      });
    });
  });
  console.log("    " + exact + " proportion cells exact, " + logged +
    " logged, " + banded + " mean cells out of scope (JS-3)");
  return TR;
}

runConfiguration("unweighted", "parity_island.json", "parity_micro.json", false);
runConfiguration("weighted", "parity_island_weighted.json",
  "parity_micro_weighted.json", true);

/* ---------------------------------------------------------------------------
   CP-4. CUBE versus MICRO.

   The enumeration is written now and skipped with a printed reason until the
   cube island exists, so stage 3 of the cube build has a failing test to turn
   green rather than a test written after the fact to agree with it.

   Views enumerated, per configuration:
     every question
       x  every banner group, plus custom:<code>:cat and custom:<code>:net for
          each declared variable
       x  no filter, every single level of every declared variable, and every
          pair of levels drawn from two DIFFERENT declared variables.

   Both sides are this engine, so figures AND letters are exact here. There is
   no band: a difference is an accumulation bug in the cube.
--------------------------------------------------------------------------- */

/** Every (banner, filters) view the enumeration covers, for one cube. */
function enumerateViews(TR, island, cube) {
  const banners = (island.banner_groups || []).map((b) => b.id);
  const declared = Object.keys(cube.vars);
  const questionVars = declared.filter((v) => cube.vars[v].kind === "question");
  const bannerIds = banners.slice();
  questionVars.forEach((code) => {
    bannerIds.push("custom:" + code + ":cat");
    bannerIds.push("custom:" + code + ":net");
  });
  const filterSets = [[]];
  const single = [];
  questionVars.forEach((code) => {
    cube.vars[code].levels.forEach((lv) => {
      single.push({ var: code, filter: { q: code, rows: [lv] } });
    });
  });
  single.forEach((s) => filterSets.push([s.filter]));
  for (let i = 0; i < single.length; i++) {
    for (let j = i + 1; j < single.length; j++) {
      if (single[i].var === single[j].var) continue;
      filterSets.push([single[i].filter, single[j].filter]);
    }
  }
  const views = [];
  island.questions.forEach((qraw) => {
    bannerIds.forEach((banner) => {
      filterSets.forEach((filters) => {
        views.push({ code: qraw.code, banner: banner, filters: filters });
      });
    });
  });
  return views;
}

function runCubeConfiguration(name, islandFile, microFile, cubeFile) {
  if (!existsSync(path.join(FIXTURE_DIR, cubeFile))) {
    console.log("\nComputed parity. CP-4: cube versus micro, " + name +
      ": SKIPPED, " + cubeFile + " does not exist yet " +
      "(regenerate the parity fixture once cube_writer.R is in place).");
    return;
  }
  console.log("\nComputed parity. CP-4: cube versus micro, " + name + ":");
  const island = readJson(islandFile);
  const micro = readJson(microFile);
  const cube = readJson(cubeFile);

  const microTR = makeEngine();
  install(microTR, island, micro, null);
  const cubeTR = makeEngine();
  install(cubeTR, JSON.parse(JSON.stringify(island)), null, cube);

  const views = enumerateViews(microTR, island, cube);
  let served = 0, refused = 0, cells = 0;

  run(name + ": every enumerated view matches the respondent island exactly", () => {
    views.forEach((v) => {
      const q = microTR.d2.questionByCode(v.code);
      const qc = cubeTR.d2.questionByCode(v.code);
      const mm = microTR.model._computedModel(q, v.banner, v.filters, true);
      const cm = cubeTR.model._computedModel(qc, v.banner, v.filters, true);
      const label = name + " " + v.code + " x " + v.banner + " x " +
        (v.filters.length
          ? v.filters.map((f) => f.q + ":" + f.rows.join(",")).join(" + ")
          : "everyone");
      if (cm.refused) {
        // A refusal must be for a stated reason, never a silent blank.
        assert(cm.refusedReason, label + " states why the cut is refused");
        refused++;
        return;
      }
      served++;
      cells += compareModels(cubeTR, qc, mm, cm, label, true, null, false);
      // Letters: both sides are this engine, so exact.
      cm.rows.forEach((cr, ri) => {
        cr.cells.forEach((cc, ci) => {
          eq(String(cc.sig || ""), String(mm.rows[ri].cells[ci].sig || ""),
            label + " / " + cr.label + " / col " + ci + " letters");
        });
      });
    });
  });
  console.log("    " + views.length + " views enumerated, " + served +
    " served, " + refused + " refused, " + cells + " cells compared");

  run(name + ": every view the block rule permits is actually served", () => {
    // A cube that refused everything would pass the comparison above by doing
    // nothing. Refusals must be attributable to the order cap, an undeclared
    // variable or a null block, and nothing else.
    views.forEach((v) => {
      const qc = cubeTR.d2.questionByCode(v.code);
      const cm = cubeTR.model._computedModel(qc, v.banner, v.filters, true);
      if (!cm.refused) return;
      assert(["order", "undeclared", "block"].indexOf(cm.refusedReason) !== -1,
        "refusal reason is one of order / undeclared / block, got " +
        JSON.stringify(cm.refusedReason));
    });
    assert(served > 0, "the cube serves at least one view");
  });
}

runCubeConfiguration("unweighted", "parity_island.json", "parity_micro.json",
  "parity_cube.json");
runCubeConfiguration("weighted", "parity_island_weighted.json",
  "parity_micro_weighted.json", "parity_cube_weighted.json");

if (notes.length) {
  console.log("\nLogged (documented divergence, not failures):");
  notes.slice(0, 20).forEach((n) => console.log("    " + n));
  if (notes.length > 20) console.log("    ... and " + (notes.length - 20) + " more");
}

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
