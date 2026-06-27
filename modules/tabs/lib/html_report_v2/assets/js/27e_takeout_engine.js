/**
 * Executive Takeout — deterministic engine (pure; no DOM, no LLM).
 *
 * Selects and ranks the handful of findings that matter from candidates the
 * report already computes, routes them into decision postures, and caps the
 * result at "just enough". Every number is pre-computed upstream; this module
 * only scores, routes, dedupes and caps. Fully unit-tested in
 * tests/takeout_tests.mjs and the in-browser #selftest.
 *
 * Inputs (assembled by 27f_takeout_data.js):
 *   { standouts:[finding], levels:[finding], composites:[level],
 *     reliability:{...}, lowBaseThreshold:int }
 * Output: the takeout object documented in docs/EXECUTIVE_TAKEOUT_PLAN.md.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};

  /* All tunable thresholds in one place — no magic numbers in the logic. */
  var CONST = takeout.CONST = {
    CAP_PROTECT: 2,            // per-posture ceilings — the "just enough" cap
    CAP_ACT: 2,
    CAP_WATCH: 2,
    CAP_DECIDE: 1,
    COHEN_H_REFERENCE: 0.8,   // Cohen's "large" effect -> full interestingness
    WEIGHT_SOLID: 1.0,        // 95%-significant finding
    WEIGHT_SOFT: 0.5,         // 80%-only ("nearly significant") finding
    BATTERY_BONUS_PER_ITEM: 0.15,  // x(1 + bonus*(k-1)) for cross-item consistency
    BATTERY_FORK_MIN: 3       // same column, same direction, >=k items -> a DECIDE fork
  };

  /** Posture metadata — the four decision lanes, in reading order. */
  var POSTURES = takeout.POSTURES = [
    { id: "protect", label: "Protect", verb: "what you're winning on", cap: CONST.CAP_PROTECT },
    { id: "act", label: "Act now", verb: "where you're exposed", cap: CONST.CAP_ACT },
    { id: "watch", label: "Watch", verb: "what's moving since last wave", cap: CONST.CAP_WATCH },
    { id: "decide", label: "Decide", verb: "a genuine fork — the data points two ways", cap: CONST.CAP_DECIDE }
  ];

  /**
   * Cohen's h for two proportions — the effect-size measure for a percentage
   * gap. Down-weights gaps near 0% or 100% (where a few points mean less) and
   * up-weights gaps around 50%. p1, p2 are proportions in [0, 1].
   */
  function cohenH(p1, p2) {
    var clamp = function (p) { return Math.min(1, Math.max(0, p)); };
    var phi = function (p) { return 2 * Math.asin(Math.sqrt(clamp(p))); };
    return phi(p1) - phi(p2);
  }
  takeout.cohenH = cohenH;

  /**
   * Effect size of one finding on a 0..1 scale, comparable across metrics.
   * Proportions use |Cohen's h| / reference; means/index/NPS use the gap as a
   * fraction of the response-scale range. Returns 0 when not computable.
   */
  function effectSize(f) {
    if (f.metric === "mean") {
      var range = (f.scaleMax - f.scaleMin) || 0;
      return range > 0 ? Math.min(1, Math.abs(f.gap) / range) : 0;
    }
    var baseline = (f.rest === null || f.rest === undefined) ? f.overall : f.rest;
    if (f.value === null || baseline === null || baseline === undefined) return 0;
    var h = Math.abs(cohenH(f.value / 100, baseline / 100));
    return Math.min(1, h / CONST.COHEN_H_REFERENCE);
  }
  takeout.effectSize = effectSize;

  /** Significance-tier weight: solid 95% counts full, soft 80% counts half. */
  function tierWeight(soft) {
    return soft ? CONST.WEIGHT_SOFT : CONST.WEIGHT_SOLID;
  }

  /**
   * Base interestingness score (0..100) before the battery bonus:
   * effect size x significance tier. Significance is a GATE applied upstream;
   * ranking is by effect, never by p-value (large samples must not flood the
   * page with trivially-significant findings).
   */
  function scoreFinding(f) {
    return effectSize(f) * tierWeight(f.soft) * 100;
  }
  takeout.scoreFinding = scoreFinding;

  /**
   * Battery-consistency count for a subgroup standout: how many findings share
   * its column, category and direction (the same segment running the same way
   * across a battery of related items). A segment low on 7 of 9 items is a far
   * stronger story than a lone significant cell.
   */
  function batteryCounts(standouts) {
    var tally = {};
    standouts.forEach(function (f) {
      var key = f.column + "" + f.category + "" + f.direction;
      tally[key] = (tally[key] || 0) + 1;
    });
    return tally;
  }

  function batteryKeyFor(f) {
    return f.column + "" + f.category + "" + f.direction;
  }

  /** Score multiplier for a finding given its battery-consistency count k. */
  function batteryMultiplier(k) {
    return 1 + CONST.BATTERY_BONUS_PER_ITEM * Math.max(0, k - 1);
  }
  takeout.batteryMultiplier = batteryMultiplier;

  /**
   * Route one candidate to exactly one posture, or null to drop it. Levels are
   * a touchpoint's Total figure (carrying its wave delta); standouts are a
   * subgroup vs the rest. Rules are disclosed to the reader in the UI.
   */
  function routePosture(c, batteryK) {
    if (c.kind === "level") {
      var declining = !!(c.delta && c.delta.sig && c.delta.diff < 0);
      if (c.band === "strong") return declining ? "decide" : "protect";
      if (c.band === "weak") return "act";
      return (c.delta && c.delta.sig) ? "watch" : null;   // moderate: only if moving
    }
    if (batteryK >= CONST.BATTERY_FORK_MIN) return "decide";  // systemic segment pattern
    return c.gap >= 0 ? "protect" : "act";
  }
  takeout.routePosture = routePosture;

  /** Stable id so a researcher's text edits survive report regeneration. */
  function findingId(f) {
    return f.code + "|" + f.column + "|" + f.metric;
  }
  takeout.findingId = findingId;

  /** A level's distance from its scale midpoint, 0..1 — how extreme a touchpoint
   *  sits (the weakest rank first in Act, the strongest first in Protect). */
  function levelExtremeness(c) {
    var range = (c.scaleMax - c.scaleMin) || 1;
    var mid = (c.scaleMin + c.scaleMax) / 2;
    var v = (c.value === null || c.value === undefined) ? mid : c.value;
    return Math.min(1, Math.abs(v - mid) / (range / 2));
  }

  /** Within-posture rank score for a level (touchpoint). Movement-led for
   *  Watch/Decide (it is the move that matters there), extremeness elsewhere. */
  function rankLevel(c) {
    var range = (c.scaleMax - c.scaleMin) || 1;
    if (c.posture === "watch" || c.posture === "decide") {
      var move = c.delta ? Math.abs(c.delta.diff) / range : 0;
      return Math.max(move, levelExtremeness(c)) * 100;
    }
    return levelExtremeness(c) * 100;
  }

  /** Normalize a _collectFindings standout into the engine's Finding shape. */
  function normalizeStandout(f) {
    var metric = f.isMean ? "mean" : "pct";
    var out = {
      code: f.code, title: f.title, category: f.category, column: f.column,
      kind: "standout", metric: metric, value: f.value, rest: f.rest,
      overall: f.overall, gap: f.gap, soft: !!f.soft,
      direction: f.isMean ? f.direction : (f.gap >= 0 ? "ahead" : "behind"),
      decimals: f.decimals, scaleMin: f.scaleMin, scaleMax: f.scaleMax,
      base: (f.base === undefined ? null : f.base), beaten: f.beaten || [],
      label: f.label, band: null, delta: null, batteryK: 1, score: 0, posture: null
    };
    out.id = findingId(out);
    return out;
  }

  /** Normalize a touchpoint level (Total figure + wave delta) into a Finding. */
  function normalizeLevel(l) {
    var out = {
      code: l.code, title: l.title, category: l.category, column: "Total",
      kind: "level", metric: "mean", value: l.value, rest: null, overall: l.value,
      gap: null, soft: false,
      direction: (l.delta && l.delta.diff < 0) ? "behind" : "ahead",
      decimals: 1, scaleMin: l.scaleMin, scaleMax: l.scaleMax,
      base: (l.base === undefined ? null : l.base), beaten: [], label: l.title,
      band: l.band, delta: l.delta || null, batteryK: 1, score: 0, posture: null
    };
    out.id = findingId(out);
    return out;
  }

  /** Group routed candidates by posture, rank by score, drop vetoed and exact
   *  duplicates, then cap. A veto frees its slot for the next-ranked candidate. */
  function selectByPosture(candidates, vetoes) {
    vetoes = vetoes || {};
    var groups = {};
    POSTURES.forEach(function (p) { groups[p.id] = []; });
    candidates.forEach(function (f) { groups[f.posture].push(f); });
    POSTURES.forEach(function (p) {
      groups[p.id].sort(function (a, b) { return b.score - a.score; });
      var seen = {}, kept = [];
      for (var i = 0; i < groups[p.id].length && kept.length < p.cap; i++) {
        var f = groups[p.id][i];
        if (seen[f.id] || vetoes[f.id]) continue;
        seen[f.id] = true;
        kept.push(f);
      }
      groups[p.id] = kept;
    });
    return groups;
  }

  /**
   * Build the takeout object from gathered candidates. Pure: same inputs always
   * yield the same takeout. Scores standouts by effect x significance-tier x
   * battery bonus, levels by extremeness/movement, routes each to one posture,
   * then ranks, dedupes and caps. See docs/EXECUTIVE_TAKEOUT_PLAN.md.
   */
  function buildTakeout(inputs) {
    inputs = inputs || {};
    var standouts = (inputs.standouts || []).map(normalizeStandout);
    var levels = (inputs.levels || []).map(normalizeLevel);
    var tally = batteryCounts(standouts);
    standouts.forEach(function (f) {
      f.batteryK = tally[batteryKeyFor(f)] || 1;
      f.score = scoreFinding(f) * batteryMultiplier(f.batteryK);
      f.posture = routePosture(f, f.batteryK);
    });
    levels.forEach(function (f) {
      f.posture = routePosture(f, 1);
      f.score = rankLevel(f);
    });
    var routed = standouts.concat(levels).filter(function (f) { return f.posture; });
    var byPosture = selectByPosture(routed, inputs.vetoes || {});
    var postures = POSTURES.map(function (p) {
      return { id: p.id, label: p.label, verb: p.verb, items: byPosture[p.id] || [] };
    });
    var promoted = postures.reduce(function (s, p) { return s + p.items.length; }, 0);
    return {
      answer: { composites: inputs.composites || [] },
      reliability: inputs.reliability || null,
      postures: postures,
      candidateCount: standouts.length + levels.length,
      promotedCount: promoted
    };
  }
  takeout.buildTakeout = buildTakeout;

  takeout._batteryCounts = batteryCounts;
  takeout._batteryKeyFor = batteryKeyFor;
  takeout._normalizeStandout = normalizeStandout;
  takeout._selectByPosture = selectByPosture;

})(typeof window !== "undefined" ? window : globalThis);
