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
 *   { standouts:[finding], levels:[finding], apex:[metric],
 *     reliability:{...}, vetoes:{id:true} }
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
   * gap. Down-weights gaps near 0% or 100% and up-weights gaps around 50%.
   * p1, p2 are proportions in [0, 1].
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
   * ranking is by effect, never by p-value.
   */
  function scoreFinding(f) {
    return effectSize(f) * tierWeight(f.soft) * 100;
  }
  takeout.scoreFinding = scoreFinding;

  /** Stable battery key. Without a category we cannot tell related items from
   *  unrelated ones, so each finding is its own battery (k=1) — never the whole
   *  survey collapsed into one. "::" cannot occur in the parts. */
  function batteryKeyFor(f) {
    if (!f.category) return "solo::" + f.code + "::" + f.label + "::" + f.column;
    return f.column + "::" + f.category + "::" + f.direction;
  }
  takeout._batteryKeyFor = batteryKeyFor;

  /**
   * Battery-consistency count for a subgroup standout: how many findings share
   * its column, category and direction (the same segment running the same way
   * across a battery of related items).
   */
  function batteryCounts(standouts) {
    var tally = {};
    standouts.forEach(function (f) {
      var key = batteryKeyFor(f);
      tally[key] = (tally[key] || 0) + 1;
    });
    return tally;
  }
  takeout._batteryCounts = batteryCounts;

  /** Score multiplier for a finding given its battery-consistency count k. */
  function batteryMultiplier(k) {
    return 1 + CONST.BATTERY_BONUS_PER_ITEM * Math.max(0, k - 1);
  }
  takeout.batteryMultiplier = batteryMultiplier;

  /** Route a subgroup standout to one posture: a systemic same-direction
   *  pattern across a battery is a fork; otherwise ahead -> Protect, behind ->
   *  Act. (Significance + base are gated upstream.) */
  function routePosture(c, batteryK) {
    if (batteryK >= CONST.BATTERY_FORK_MIN) return "decide";
    return c.gap >= 0 ? "protect" : "act";
  }
  takeout.routePosture = routePosture;

  /** Median touchpoint value — the line between relatively strong and weak, so
   *  Protect/Act surface the genuine top/bottom touchpoints rather than only
   *  those past an absolute band (most items sit mid-band on a tight scale). */
  function medianValue(levels) {
    var v = levels.map(function (l) { return l.value; })
      .filter(function (x) { return x !== null && x !== undefined; })
      .sort(function (a, b) { return a - b; });
    if (!v.length) return 0;
    var m = Math.floor(v.length / 2);
    return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2;
  }
  takeout.medianValue = medianValue;

  /** Route a touchpoint level: strong-but-declining is a fork; a significant
   *  mover is a Watch story; otherwise Protect/Act by rank vs the median. */
  function routeLevel(f, median) {
    var declining = !!(f.delta && f.delta.sig && f.delta.diff < 0);
    if (f.band === "strong" && declining) return "decide";
    if (f.delta && f.delta.sig) return "watch";
    return f.value >= median ? "protect" : "act";
  }
  takeout.routeLevel = routeLevel;

  /** Within-lane rank score for a level, normalised to the same 0..100 footing
   *  as a standout's effect size (so a touchpoint level and a subgroup gap
   *  compete fairly). Distance from the median as a fraction of the scale for
   *  Protect/Act; movement (with a touch of extremeness) for Watch/Decide. */
  function scoreLevel(f, median) {
    var range = (f.scaleMax - f.scaleMin) || 1;
    var extremeness = Math.abs(f.value - median) / range;
    if (f.posture === "watch" || f.posture === "decide") {
      var move = f.delta ? Math.abs(f.delta.diff) / range : 0;
      return (move + extremeness * 0.25) * 100;
    }
    return extremeness * 100;
  }

  /** Prefer the index (mean) standout over a top-box (%) standout for the same
   *  question + column, so the takeout speaks one metric — the index — wherever
   *  a question has one. Categorical standouts with no index are kept. */
  function preferIndexStandouts(standouts) {
    var hasMean = {};
    standouts.forEach(function (f) {
      if (f.metric === "mean") hasMean[f.code + "::" + f.column] = true;
    });
    return standouts.filter(function (f) {
      return f.metric === "mean" || !hasMean[f.code + "::" + f.column];
    });
  }

  /** Stable id so a researcher's text edits survive report regeneration. */
  function findingId(f) {
    return f.code + "|" + f.column + "|" + f.metric;
  }
  takeout.findingId = findingId;

  /** Normalize a _collectFindings standout into the engine's Finding shape. */
  function normalizeStandout(f) {
    var metric = f.isMean ? "mean" : "pct";
    var out = {
      code: f.code, title: f.title, category: f.category || "", column: f.column,
      kind: "standout", metric: metric, value: f.value, rest: f.rest,
      overall: f.overall, gap: f.gap, soft: !!f.soft,
      direction: f.isMean ? f.direction : (f.gap >= 0 ? "ahead" : "behind"),
      decimals: f.decimals, scaleMin: f.scaleMin, scaleMax: f.scaleMax,
      base: (f.base === undefined ? null : f.base), beaten: f.beaten || [],
      label: f.label, band: null, delta: null, batteryK: 1, score: 0, posture: null,
      bannerGroup: f.bannerGroup || "", topBox: null
    };
    out.id = findingId(out);
    return out;
  }

  /** Normalize a touchpoint level (Total figure + wave delta) into a Finding. */
  function normalizeLevel(l) {
    var out = {
      code: l.code, title: l.title, category: l.category || "", column: "Total",
      kind: "level", metric: "mean", value: l.value, rest: null, overall: l.value,
      gap: null, soft: false,
      direction: (l.delta && l.delta.diff < 0) ? "behind" : "ahead",
      decimals: 1, scaleMin: l.scaleMin, scaleMax: l.scaleMax,
      base: (l.base === undefined ? null : l.base), beaten: [], label: l.title,
      band: l.band, delta: l.delta || null, batteryK: 1, score: 0, posture: null,
      bannerGroup: "", topBox: l.topBox || null, waves: l.waves || null
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
  takeout._selectByPosture = selectByPosture;

  /**
   * Build the takeout object from gathered candidates. Pure: same inputs always
   * yield the same takeout. Standouts score by effect x tier x battery and route
   * by direction; levels route by rank relative to the median (with movers ->
   * Watch, strong-decliners -> Decide); then rank, dedupe and cap.
   */
  function buildTakeout(inputs) {
    inputs = inputs || {};
    var standouts = preferIndexStandouts((inputs.standouts || []).map(normalizeStandout));
    var levels = (inputs.levels || []).map(normalizeLevel);
    var tally = batteryCounts(standouts);
    standouts.forEach(function (f) {
      f.batteryK = tally[batteryKeyFor(f)] || 1;
      f.score = scoreFinding(f) * batteryMultiplier(f.batteryK);
      f.posture = routePosture(f, f.batteryK);
    });
    var median = medianValue(levels);
    levels.forEach(function (f) {
      f.posture = routeLevel(f, median);
      f.score = scoreLevel(f, median);
    });
    var routed = standouts.concat(levels).filter(function (f) { return f.posture; });
    var byPosture = selectByPosture(routed, inputs.vetoes || {});
    var postures = POSTURES.map(function (p) {
      return { id: p.id, label: p.label, verb: p.verb, items: byPosture[p.id] || [] };
    });
    var promoted = postures.reduce(function (s, p) { return s + p.items.length; }, 0);
    return {
      answer: { metrics: inputs.apex || [] },
      reliability: inputs.reliability || null,
      postures: postures,
      candidateCount: standouts.length + levels.length,
      promotedCount: promoted
    };
  }
  takeout.buildTakeout = buildTakeout;

  takeout._normalizeStandout = normalizeStandout;
  takeout._preferIndexStandouts = preferIndexStandouts;

})(typeof window !== "undefined" ? window : globalThis);
