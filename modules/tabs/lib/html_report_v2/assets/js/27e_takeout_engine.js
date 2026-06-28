/**
 * Executive Takeout — Patterns engine (pure; no DOM, no LLM).
 *
 * Answers "what's the big picture?" by stepping back from individual questions:
 *   - GROUP   — the breakout column that is consistently off across the survey
 *               (e.g. one campus behind on most questions). Needs no tagging.
 *   - AREA    — the weakest and strongest THEMES (clusters of tagged questions).
 *   - MOVEMENT — the headline metric or theme that moved most since last wave.
 *
 * Every number is pre-computed upstream; this module only groups, ranks and
 * selects. Generic: it operates on the POSITION of a question (its theme /
 * section) and on banner columns, never on what they are named, so the same
 * code runs on an engagement, brand or CX survey. Degrades gracefully when
 * nothing is tagged (the GROUP pattern still works). Unit-tested in
 * tests/takeout_tests.mjs and the in-browser #selftest.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};

  /* Tunable thresholds — no magic numbers in the logic below. */
  var CONST = takeout.CONST = {
    MIN_GROUP_HITS: 2,        // a column must be off on >=N questions to be "the group"
    MIN_AREA_MEMBERS: 2,      // a theme needs >=N questions to count as an "area"
    EVIDENCE_MAX: 4,          // rows of supporting evidence shown per pattern
    COHEN_H_REFERENCE: 0.8,   // Cohen's "large" effect -> full weight
    MIN_MOVE_FRACTION: 0.03   // a wave change must be >=N of the scale to count as a "move"
  };                          //   (0.03 -> 0.15 on a 5-pt scale, 3pp on a 0-100 metric);
                              //   significance alone is not enough — a tiny change can test
                              //   significant on a large base yet mean nothing.

  /** Cohen's h for two proportions (effect size for a percentage gap). */
  function cohenH(p1, p2) {
    var clamp = function (p) { return Math.min(1, Math.max(0, p)); };
    var phi = function (p) { return 2 * Math.asin(Math.sqrt(clamp(p))); };
    return phi(p1) - phi(p2);
  }
  takeout.cohenH = cohenH;

  /** A standout's effect size on a 0..1 scale, comparable across metrics. */
  function effectSize(f) {
    if (f.isMean) {
      var range = (f.scaleMax - f.scaleMin) || 0;
      return range > 0 ? Math.min(1, Math.abs(f.gap) / range) : 0;
    }
    var baseline = (f.rest === null || f.rest === undefined) ? f.overall : f.rest;
    if (f.value === null || baseline === null || baseline === undefined) return 0;
    return Math.min(1, Math.abs(cohenH(f.value / 100, baseline / 100)) / CONST.COHEN_H_REFERENCE);
  }
  takeout.effectSize = effectSize;

  /** A touchpoint's level on its own 0..1 scale (value as a share of the max). */
  function areaScore(level) {
    var max = level.scaleMax || 0;
    return max > 0 ? Math.min(1, Math.max(0, level.value / max)) : 0;
  }

  /**
   * GROUP pattern: which banner column is most consistently off across the
   * survey. Tally each column's significant standouts (behind / ahead); the
   * column behind on the most questions is "the group under strain". Returns
   * null when no column is off on enough questions. Pure; no tagging needed.
   */
  function groupPattern(standouts) {
    var byCol = {};
    (standouts || []).forEach(function (f) {
      if (f.value === null || f.value === undefined) return;
      var key = f.column;
      var c = byCol[key] || (byCol[key] = { column: f.column, group: f.bannerGroup || "", behind: [], ahead: [] });
      var dir = f.isMean ? (f.direction === "behind" ? "behind" : "ahead") : (f.gap >= 0 ? "ahead" : "behind");
      (dir === "behind" ? c.behind : c.ahead).push(f);
    });
    var cols = Object.keys(byCol).map(function (k) { return byCol[k]; });
    var pick = function (side) {
      var best = null;
      cols.forEach(function (c) {
        var hits = c[side].length;
        if (hits < CONST.MIN_GROUP_HITS) return;
        var eff = c[side].reduce(function (s, f) { return s + effectSize(f); }, 0);
        if (!best || hits > best.hits || (hits === best.hits && eff > best.eff)) {
          best = { col: c, hits: hits, eff: eff };
        }
      });
      return best;
    };
    var strain = pick("behind"), thriving = pick("ahead");
    if (!strain) return null;
    var c = strain.col;
    var evidence = c.behind.slice().sort(function (a, b) { return effectSize(b) - effectSize(a); })
      .slice(0, CONST.EVIDENCE_MAX).map(function (f) {
        return { label: f.title, value: f.value, rest: f.rest, overall: f.overall,
          scaleMax: f.scaleMax, isMean: !!f.isMean, decimals: f.decimals };
      });
    return { id: "group", kind: "group", subject: c.column, group: c.group,
      hits: strain.hits, total: c.behind.length + c.ahead.length, evidence: evidence,
      secondary: thriving ? thriving.col.column : null };
  }

  /** Group levels into themes (theme, else section, else "(untagged)"). */
  function groupByTheme(levels) {
    var map = {}, order = [];
    (levels || []).forEach(function (l) {
      var key = l.theme || l.section || "(untagged)";
      if (!map[key]) { map[key] = { name: key, section: l.section || "", members: [] }; order.push(map[key]); }
      map[key].members.push(l);
    });
    return order.map(function (t) {
      var sum = 0, raw = 0, moving = 0;
      t.members.forEach(function (m) {
        sum += areaScore(m);
        raw += (m.value || 0);
        if (m.delta && m.delta.sig) moving += (m.delta.diff < 0 ? -1 : 1);
      });
      t.score = t.members.length ? sum / t.members.length : 0;        // normalised 0..1, for ranking
      t.avg = t.members.length ? raw / t.members.length : 0;          // raw scale average, for display
      t.scaleMax = (t.members[0] && t.members[0].scaleMax) || 0;
      t.moving = moving;   // net signed count of significant movers
      return t;
    });
  }

  /** Evidence rows for an area, weakest- or strongest-member first. */
  function areaEvidence(theme, weakest) {
    return theme.members.slice().sort(function (a, b) {
      return weakest ? areaScore(a) - areaScore(b) : areaScore(b) - areaScore(a);
    }).slice(0, CONST.EVIDENCE_MAX).map(function (m) {
      return { label: m.title, value: m.value, scaleMax: m.scaleMax,
        delta: m.delta || null, topBox: m.topBox || null };
    });
  }

  /** WEAKEST and STRONGEST area patterns from multi-question themes. */
  function areaPatterns(levels) {
    var themes = groupByTheme(levels).filter(function (t) {
      return t.name !== "(untagged)" && t.members.length >= CONST.MIN_AREA_MEMBERS;
    });
    if (themes.length < 1) return [];
    var ranked = themes.slice().sort(function (a, b) { return a.score - b.score; });
    var weak = ranked[0], strong = ranked[ranked.length - 1];
    var make = function (t, isWeak) {
      return { id: isWeak ? "weak" : "strong", kind: "area", subject: t.name,
        section: t.section, score: t.score, avg: t.avg, scaleMax: t.scaleMax,
        members: t.members.length, moving: t.moving, evidence: areaEvidence(t, isWeak) };
    };
    var out = [make(weak, true)];
    if (strong !== weak) out.push(make(strong, false));   // need >=2 distinct themes for both
    return out;
  }

  /**
   * MOVEMENT pattern: the headline metrics that moved since last wave — biggest
   * riser AND biggest faller (two-sided). A move must be both significant AND
   * material (>= MIN_MOVE_FRACTION of the scale); a significant-but-trivial shift
   * is reported as "broadly stable", not dressed up as a move. Returns null only
   * when there is no significant change at all (e.g. no wave history).
   */
  function movementPattern(apex) {
    var sig = (apex || []).filter(function (m) { return m.delta && m.delta.sig; });
    if (!sig.length) return null;
    var material = sig.filter(function (m) {
      return Math.abs(m.delta.diff) / ((m.scaleMax || 0) || 1) >= CONST.MIN_MOVE_FRACTION;
    }).map(function (m) {
      return { subject: m.label || m.title, diff: m.delta.diff, year: m.delta.year, waves: m.waves || null };
    });
    if (!material.length) {
      return { id: "moved", kind: "movement", stable: true, subject: "Broadly stable",
        year: (sig[0].delta || {}).year || null };
    }
    material.sort(function (a, b) { return Math.abs(b.diff) - Math.abs(a.diff); });
    var up = material.filter(function (x) { return x.diff >= 0; })[0] || null;
    var down = material.filter(function (x) { return x.diff < 0; })[0] || null;
    var top = material[0];
    return { id: "moved", kind: "movement", subject: top.subject, diff: top.diff,
      year: top.year, waves: top.waves, up: up, down: down };
  }
  takeout._movementPattern = movementPattern;

  /**
   * Build the patterns object from gathered inputs. Pure: same inputs always
   * give the same patterns. Assembles GROUP + WEAK/STRONG AREA + MOVEMENT,
   * omitting any pattern that cannot be computed (graceful degradation).
   */
  function buildPatterns(inputs) {
    inputs = inputs || {};
    var patterns = [];
    var group = groupPattern(inputs.standouts);
    if (group) patterns.push(group);
    areaPatterns(inputs.levels || []).forEach(function (p) { patterns.push(p); });
    var moved = movementPattern(inputs.apex || []);
    if (moved) patterns.push(moved);
    return {
      answer: { metrics: inputs.apex || [] },
      reliability: inputs.reliability || null,
      patterns: patterns,
      themeCount: groupByTheme(inputs.levels || []).filter(function (t) {
        return t.name !== "(untagged)" && t.members.length >= CONST.MIN_AREA_MEMBERS;
      }).length,
      standoutCount: (inputs.standouts || []).length
    };
  }
  takeout.buildPatterns = buildPatterns;

  takeout._groupPattern = groupPattern;
  takeout._areaPatterns = areaPatterns;
  takeout._groupByTheme = groupByTheme;

})(typeof window !== "undefined" ? window : globalThis);
