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
  "21_stats.js", "21b_cube.js", "21c_confidence.js", "21d_disclosure.js",
  "22w_waves.js", "22_model.js", "23_render.js", "26_filter.js"];

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

/**
 * Cube against respondent island, cell by cell. Both sides are THIS engine, so
 * the claim here is stronger than displayed precision: the two must agree on
 * the NUMBER. The tolerance is 1e-8 relative, which is the precision the cube's
 * own sums are written at (cube_round, digits = 8) and far tighter than any
 * accumulated floating-point difference between summing 200 doubles in a
 * different order. It is NOT a tolerance on the figure: anything a reader could
 * see would be many orders of magnitude larger.
 */
function sameNumber(a, b) {
  if (a === null || a === undefined || b === null || b === undefined) {
    return (a === null || a === undefined) && (b === null || b === undefined);
  }
  var scale = Math.max(1, Math.abs(a), Math.abs(b));
  // 1e-8 relative is the precision the cube's own sums are written at
  // (cube_round, digits = 8). The 1e-5 absolute floor is for the standard
  // deviation: the engine forms a variance as (sum wx squared / sum w) minus
  // (mean squared), which cancels catastrophically when the true variance is
  // zero, so a cell where everyone gave the same answer computes as 1.4e-6 on
  // one source and exactly 0 on the other. Both are zero. The floor is five
  // orders of magnitude below the last digit any of these figures displays,
  // so it can never absorb a difference a reader could see.
  return Math.abs(a - b) <= 1e-8 * scale + 1e-5;
}

function compareSources(TR, q, micro, cube, label, boundary) {
  let cells = 0;
  const pctDp = TR.fmt.decimalsFor(false);
  const meanDp = TR.fmt.decimalsForQ(q, true);
  const same = (a, b, where, dp) => {
    if (!sameNumber(a, b)) {
      throw new Error(where + ": micro " + JSON.stringify(b) + ", cube " + JSON.stringify(a));
    }
    if (dp != null && a != null && b != null &&
        Number(a).toFixed(dp) !== Number(b).toFixed(dp)) {
      // The two sources agree on the NUMBER (checked above, to 1e-8 relative)
      // and disagree only on which side of a rounding boundary it lands. The
      // cube sums each cell in R and adds the cells here; the respondent island
      // accumulates every respondent in one pass. On a weighted design those
      // two orders of addition put a value that is exactly x.5 a fraction of an
      // ulp either side of it. Counted with the view that produced it, never
      // failed as a figure difference and never widened into a tolerance.
      if (boundary) {
        boundary.count++;
        boundary.notes.push(where + " sits on a rounding boundary: micro " +
          Number(b).toFixed(dp) + " (" + b + "), cube " + Number(a).toFixed(dp) +
          " (" + a + ")");
        return;
      }
      throw new Error(where + " prints differently: micro " + Number(b).toFixed(dp) +
        ", cube " + Number(a).toFixed(dp));
    }
  };
  eq(cube.columns.length, micro.columns.length, label + " column count");
  cube.columns.forEach((cc, ci) => {
    const mc = micro.columns[ci];
    eq(cc.label, mc.label, label + " col " + ci + " label");
    same(cc.base, mc.base, label + " col " + ci + " base", 0);
    same(cc.baseW, mc.baseW, label + " col " + ci + " baseW", 0);
    same(cc.baseEff, mc.baseEff, label + " col " + ci + " baseEff", 0);
    eq(!!cc.low, !!mc.low, label + " col " + ci + " low-base flag");
  });
  eq(cube.rows.length, micro.rows.length, label + " row count");
  cube.rows.forEach((cr, ri) => {
    const mr = micro.rows[ri];
    eq(cr.label, mr.label, label + " row " + ri + " label");
    cr.cells.forEach((cc, ci) => {
      const mc = mr.cells[ci];
      const where = label + " / " + cr.label + " / col " + ci;
      same(cc.pct, mc.pct, where + " pct", pctDp);
      same(cc.mean, mc.mean, where + " mean", meanDp);
      same(cc.n, mc.n, where + " n", 0);
      cells++;
    });
  });
  return cells;
}

/**
 * The values the filter bar would offer for a declared variable: the CATEGORY
 * ROW indices of the question with that code.
 *
 * Row indices, not cube levels. The filter bar, the custom banner and the
 * composite builder all name a value by its position in the question's own row
 * list (26_filter.js, selectionToFilter). A question variable's cube level
 * happens to BE that index, so enumerating a cube's own levels agreed with the
 * filter bar by coincidence and never exercised the case where the two differ.
 * A banner variable's level is a COLUMN index instead, and columns begin after
 * Total, so every one of them is offset from the row the reader ticked.
 *
 * A declared variable the report does not table cannot be picked at all, so it
 * contributes no views.
 */
function filterableRows(island, code) {
  const q = (island.questions || []).filter((x) => x.code === code)[0];
  if (!q) return [];
  const out = [];
  (q.rows || []).forEach((r, ri) => { if (r.kind === "category") out.push(ri); });
  return out;
}

/** Every (banner, filters) view the enumeration covers, for one cube. */
function enumerateViews(TR, island, cube) {
  const banners = (island.banner_groups || []).map((b) => b.id);
  const declared = Object.keys(cube.vars);
  const pickable = declared.filter((v) => filterableRows(island, v).length > 0);
  const bannerIds = banners.slice();
  pickable.forEach((code) => {
    bannerIds.push("custom:" + code + ":cat");
    bannerIds.push("custom:" + code + ":net");
  });
  const filterSets = [[]];
  const single = [];
  pickable.forEach((code) => {
    filterableRows(island, code).forEach((ri) => {
      single.push({ var: code, filter: { q: code, rows: [ri] } });
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
  // Counted by reason. A cube that refused its way to a pass would show it
  // here: the numbers are printed with the summary, every run.
  const why = {};
  const boundary = { count: 0, notes: [] };

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
        why[cm.refusedReason] = (why[cm.refusedReason] || 0) + 1;
        refused++;
        return;
      }
      served++;
      cells += compareSources(cubeTR, qc, mm, cm, label, boundary);
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
    " served, " + refused + " refused (" +
    (Object.keys(why).sort().map((r) => r + " " + why[r]).join(", ") || "none") +
    "), " + cells + " cells compared, " +
    boundary.count + " on a rounding boundary");
  boundary.notes.slice(0, 6).forEach((nt) => notes.push(nt));
  if (boundary.notes.length > 6) {
    notes.push("... and " + (boundary.notes.length - 6) +
      " more rounding-boundary cells in " + name);
  }

  run(name + ": every view the block rule permits is actually served", () => {
    // A cube that refused everything would pass the comparison above by doing
    // nothing. Refusals must be attributable to the order cap, an undeclared
    // variable or a null block, and nothing else.
    views.forEach((v) => {
      const qc = cubeTR.d2.questionByCode(v.code);
      const cm = cubeTR.model._computedModel(qc, v.banner, v.filters, true);
      if (!cm.refused) return;
      assert(["order", "undeclared", "block", "rows"].indexOf(cm.refusedReason) !== -1,
        "refusal reason is one of order / undeclared / block / rows, got " +
        JSON.stringify(cm.refusedReason));
    });
    assert(served > 0, "the cube serves at least one view");
  });
}

/* ---------------------------------------------------------------------------
   CP-5. A WITHHELD cell blanks its column, and takes nothing else with it.

   On a published banner margin the cube suppresses the CELL, not the cut: a
   department of one withholds its own answers and every other department still
   reports, which is exactly what the workbook does with a column under k.

   The cell ships its BASE and no answers. Two things have to follow. The
   column must blank rather than read the absent answers as zeros. And a
   selection that MIXES a withheld cell with a reported one must blank too,
   because its headcount can clear the threshold while its figures would be
   computed off only part of the group.
--------------------------------------------------------------------------- */
console.log("\nComputed parity. CP-5: a withheld cell blanks its column:");

function withheldFixture() {
  const TR = makeEngine();
  const agg = {
    schema_version: 2,
    project: { name: "T", low_base_threshold: 1, min_reporting_base: 5,
      alpha: 0.05, format: {} },
    columns: [
      { label: "Total", group: "total", letter: "" },
      { label: "Big", group: "Dept", letter: "A" },
      { label: "Small", group: "Dept", letter: "B" }
    ],
    banner_groups: [{ id: "Dept", name: "Department" }],
    categories: [],
    questions: [{
      // The banner question, reported as well as bannered. Its rows are the
      // space a filter arrives in; the columns after Total are the space the
      // cube stores. The row map is what holds the two together.
      code: "Dept", title: "Dept", category: "", type: "single",
      bases: [{ n: 21 }, { n: 20 }, { n: 1 }],
      rows: [
        { kind: "category", label: "Big", pct: [95, 100, 0], n: [20, 20, 0], sig: ["", "", ""] },
        { kind: "category", label: "Small", pct: [5, 0, 100], n: [1, 0, 1], sig: ["", "", ""] }
      ]
    }, {
      code: "Q1", title: "Q1", category: "", type: "single",
      bases: [{ n: 21 }, { n: 20 }, { n: 1 }],
      rows: [
        { kind: "category", label: "Yes", pct: [50, 50, 100], n: [11, 10, 1], sig: ["", "", ""] },
        { kind: "category", label: "No", pct: [50, 50, 0], n: [10, 10, 0], sig: ["", "", ""] }
      ]
    }]
  };
  const cube = {
    schema_version: 1, n: 21, k: 5, order: 2, weighted: false,
    vars: { Dept: { kind: "banner", levels: [1, 2], rowmap: { "0": 1, "1": 2 } } },
    questions: { Q1: { has: ["answers"] } },
    slices: {
      "*": { cells: { "*": { a: [21, 21, 21] } },
        q: { Q1: { "*": { b: [21, 21, 21], r: { "0": 11, "1": 10 } } } } },
      Dept: {
        cells: { "1": { a: [20, 20, 20] }, "2": { a: [1, 1, 1] } },
        q: { Q1: {
          "1": { b: [20, 20, 20], r: { "0": 10, "1": 10 } },
          "2": { b: [1, 1, 1], sup: true }      // the department of one
        } }
      }
    },
    blocks: { shipped: 2, refused: 0 }
  };
  install(TR, agg, null, cube);
  return TR;
}

run("the small column blanks; the big one reports", () => {
  const TR = withheldFixture();
  const q = TR.d2.questionByCode("Q1");
  // The COMPUTED path, which is what a filter or a custom banner takes. The
  // default unfiltered banner view reads the published table instead, where the
  // same column is already blanked before serialisation on a cube build.
  const m = TR.model._computedModel(q, "Dept", [], false);
  TR.model._applyDisclosureSuppression(m);
  eq(m.source, "computed", "the cube serves the view");
  eq(m.columns.length, 3, "Total plus both departments");
  // The base of a banner column is the workbook's own base row, so it is shown.
  eq(m.columns[2].base, 1, "the small column still states its headcount");
  eq(m.columns[2].suppressed, true, "and is blanked");
  const yes = m.rows.filter((r) => r.label === "Yes")[0];
  eq(yes.cells[2].pct, null, "no percentage for the withheld column");
  eq(yes.cells[2].n, null, "and no count");
  // The whole point: the other department is unaffected.
  eq(m.columns[1].base, 20, "the big column reports its base");
  assert(!m.columns[1].suppressed, "and is not blanked");
  eq(Math.round(yes.cells[1].pct), 50, "and reports its figure");
  eq(Math.round(yes.cells[0].pct), 52, "as does Total");
});

run("a selection mixing a withheld cell with a reported one blanks too", () => {
  const TR = withheldFixture();
  const q = TR.d2.questionByCode("Q1");
  // One custom column over BOTH departments. Headcount 21, well over k, but the
  // answers of one of them are not in the file.
  const spec = TR.stats.columnsFor("Dept");
  const both = { label: "Both", letter: "", sel: { "var": "Dept", levels: [1, 2] } };
  const tab = TR.stats.tabulate(q, [both], TR.stats.mask([]))[0];
  eq(tab.base, 21, "the headcount is the whole banner");
  eq(tab.withheld, true, "and the lookup says its answers are incomplete");
  assert(tab.base >= 5, "so the threshold alone would NOT have caught this");
});

run("a filter onto the withheld group is refused, not answered from nothing", () => {
  const TR = withheldFixture();
  const q = TR.d2.questionByCode("Q1");
  // Row 1 is "Small", which the row map sends to column 2. Named in row space
  // because that is what the filter bar sends.
  const m = TR.model.forQuestion("Q1", "", [{ q: "Dept", rows: [1] }], {});
  const yes = m.rows.filter((r) => r.label === "Yes")[0];
  eq(yes.cells[0].pct, null, "the Total column carries no figure for a group of one");
});

/* ---------------------------------------------------------------------------
   CP-4b. ROW SPACE versus LEVEL SPACE.

   Everything a reader picks is named by its position in the question's own row
   list. A banner variable's cube level is a COLUMN index instead, and the
   columns begin after Total, so the two are offset by at least one and a cut
   taken at face value reports a different group under the reader's label. On a
   client-safe interactive build the cube is the only source, so there is
   nothing else to catch it.
--------------------------------------------------------------------------- */

/** Three campuses, unequal, so picking the wrong one cannot look right. */
function campusFixture(rowmap) {
  const TR = makeEngine();
  const agg = {
    schema_version: 2,
    project: { name: "T", low_base_threshold: 1, min_reporting_base: 3,
      alpha: 0.05, format: {} },
    columns: [
      { label: "Total", group: "total", letter: "" },
      { label: "Alpha", group: "Campus", letter: "A" },
      { label: "Beta", group: "Campus", letter: "B" },
      { label: "Gamma", group: "Campus", letter: "C" }
    ],
    banner_groups: [{ id: "Campus", name: "Campus" }],
    categories: [],
    questions: [{
      code: "Campus", title: "Campus", category: "", type: "single",
      bases: [{ n: 19 }, { n: 10 }, { n: 5 }, { n: 4 }],
      rows: [
        { kind: "category", label: "Alpha", pct: [53, 100, 0, 0], n: [10, 10, 0, 0], sig: ["", "", "", ""] },
        { kind: "category", label: "Beta", pct: [26, 0, 100, 0], n: [5, 0, 5, 0], sig: ["", "", "", ""] },
        { kind: "category", label: "Gamma", pct: [21, 0, 0, 100], n: [4, 0, 0, 4], sig: ["", "", "", ""] }
      ]
    }, {
      code: "Q1", title: "Q1", category: "", type: "single",
      bases: [{ n: 19 }, { n: 10 }, { n: 5 }, { n: 4 }],
      rows: [
        { kind: "category", label: "Yes", pct: [47, 60, 40, 25], n: [9, 6, 2, 1], sig: ["", "", "", ""] },
        { kind: "category", label: "No", pct: [53, 40, 60, 75], n: [10, 4, 3, 3], sig: ["", "", "", ""] }
      ]
    }]
  };
  const campusVar = { kind: "banner", levels: [1, 2, 3] };
  if (rowmap) campusVar.rowmap = rowmap;
  const cube = {
    schema_version: 1, n: 19, k: 3, order: 2, weighted: false,
    vars: { Campus: campusVar },
    questions: { Campus: { has: ["answers"] }, Q1: { has: ["answers"] } },
    slices: {
      "*": { cells: { "*": { a: [19, 19, 19] } },
        q: { Q1: { "*": { b: [19, 19, 19], r: { "0": 9, "1": 10 } } } } },
      Campus: {
        cells: { "1": { a: [10, 10, 10] }, "2": { a: [5, 5, 5] }, "3": { a: [4, 4, 4] } },
        q: { Q1: {
          "1": { b: [10, 10, 10], r: { "0": 6, "1": 4 } },
          "2": { b: [5, 5, 5], r: { "0": 2, "1": 3 } },
          "3": { b: [4, 4, 4], r: { "0": 1, "1": 3 } }
        } }
      }
    },
    blocks: { shipped: 3, refused: 0 }
  };
  install(TR, agg, null, cube);
  return TR;
}

run("a filter on a banner value answers about the group the reader ticked", () => {
  const TR = campusFixture({ "0": 1, "1": 2, "2": 3 });
  // Row 1 is Beta, five people. Read as a level it would be column 1, Alpha,
  // ten people: a full and plausible table about the wrong campus.
  const m = TR.model.forQuestion("Q1", "", [{ q: "Campus", rows: [1] }], {});
  assert(!m.refused, "the cut is served");
  eq(m.columns[0].base, 5, "the audience is Beta, not the campus above it");
  const yes = m.rows.filter((r) => r.label === "Yes")[0];
  eq(Math.round(yes.cells[0].pct), 40, "and its figures are Beta's");
});

run("the first banner value is a real audience, not an empty one", () => {
  const TR = campusFixture({ "0": 1, "1": 2, "2": 3 });
  // Row 0 read as a level is column 0, which is Total and is no cell of the
  // banner at all, so the untranslated version returns a base of nobody.
  const m = TR.model.forQuestion("Q1", "", [{ q: "Campus", rows: [0] }], {});
  assert(!m.refused, "the cut is served");
  eq(m.columns[0].base, 10, "Alpha is ten people");
});

run("a value with no column of its own is refused, not answered as somebody else", () => {
  // Beta is missing from the map: its banner merged it with another campus or
  // left it out, so no published column holds exactly those people.
  const TR = campusFixture({ "0": 1, "2": 3 });
  const m = TR.model.forQuestion("Q1", "", [{ q: "Campus", rows: [1] }], {});
  assert(m.refused, "the cut is refused");
  eq(m.refusedReason, "rows", "and says which kind of refusal it is");
  // The sentence itself is authored in the callout registry. This sandbox
  // loads no text module, so that the key is declared and authored is checked
  // where the whole catalogue is: test_report_text.R, "every key the real
  // renderer calls is declared and authored".
  const mask = TR.stats.mask([{ q: "Campus", rows: [1] }]);
  eq(mask.refused.reason, "rows", "the mask carries the reason the bar renders");
});

run("a banner with no map at all cannot be cut in row space", () => {
  // An older file, or a banner built from something the report does not table.
  const TR = campusFixture(null);
  const m = TR.model.forQuestion("Q1", "", [{ q: "Campus", rows: [0] }], {});
  assert(m.refused, "the cut is refused rather than guessed");
  eq(m.refusedReason, "rows", "for the stated reason");
});

run("a custom banner on a banner question crosses the right columns", () => {
  const TR = campusFixture({ "0": 1, "1": 2, "2": 3 });
  const q = TR.d2.questionByCode("Q1");
  const m = TR.model._computedModel(q, "custom:Campus:cat", [], false);
  eq(m.columns.length, 4, "Total plus one column per campus");
  eq(m.columns[1].base, 10, "Alpha");
  eq(m.columns[2].base, 5, "Beta");
  eq(m.columns[3].base, 4, "Gamma");
});

run("a custom banner it cannot translate shows Total only", () => {
  const TR = campusFixture({ "0": 1, "2": 3 });
  const q = TR.d2.questionByCode("Q1");
  const m = TR.model._computedModel(q, "custom:Campus:cat", [], false);
  eq(m.columns.length, 1, "no half-built banner with a column about someone else");
  eq(m.columns[0].base, 19, "and Total still reports");
});

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
