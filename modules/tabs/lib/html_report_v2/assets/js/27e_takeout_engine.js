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
    MIN_GROUP_HITS: 2,        // a column must be below the overall on >=N questions
    MIN_STRAIN_GAP: 0.02,     // ...and (reliability-weighted) >=2% of the scale below it
    STRAIN_RELIABLE_BASE: 30, // base at which a group's gap is fully trusted; smaller groups'
                              //   gaps are discounted so a sharp gap on n=5 doesn't outrank a solid n=40
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
   * GROUP pattern: which breakout column sits consistently below the overall
   * across the survey, on the INDEX (a bidirectional, valenced measure — a low
   * group reads as low, unlike significance letters which only mark a group being
   * higher). For each column we net the per-question gap to the overall, as a
   * fraction of each scale; the most-negative net is "under strain", the most-
   * positive is "thriving". Returns null unless one column is below on at least
   * MIN_GROUP_HITS questions AND averages MIN_STRAIN_GAP below the overall.
   * Input: [{column, group, gaps:[{title, value, total, scaleMax}]}].
   */
  function groupPattern(columns) {
    if (!columns || !columns.length) return null;
    var scored = columns.map(function (c) {
      var net = 0, behind = [];
      c.gaps.forEach(function (gp) {
        var frac = (gp.value - gp.total) / (gp.scaleMax || 1);
        net += frac;
        if (frac < 0) behind.push(gp);
      });
      // Rank by the AVERAGE gap to the overall (depth, not breadth), discounted
      // by reliability so a sharp gap on a tiny group doesn't outrank a solid one
      // on a large group. A group at >= STRAIN_RELIABLE_BASE counts in full.
      var avg = c.gaps.length ? net / c.gaps.length : 0;
      var weight = Math.min(1, (c.base || 0) / CONST.STRAIN_RELIABLE_BASE);
      return { column: c.column, group: c.group, avg: avg, weighted: avg * weight,
        behind: behind, count: c.gaps.length };
    });
    var strain = null, thrive = null;
    scored.forEach(function (s) {
      if (!strain || s.weighted < strain.weighted) strain = s;
      if (!thrive || s.weighted > thrive.weighted) thrive = s;
    });
    if (!strain || strain.behind.length < CONST.MIN_GROUP_HITS || strain.weighted > -CONST.MIN_STRAIN_GAP) {
      return null;
    }
    var evidence = strain.behind.slice()
      .sort(function (a, b) { return (a.value - a.total) - (b.value - b.total); })  // most-below first
      .slice(0, CONST.EVIDENCE_MAX).map(function (gp) {
        return { label: gp.title, value: gp.value, rest: gp.total, scaleMax: gp.scaleMax, isMean: true };
      });
    return { id: "group", kind: "group", subject: strain.column, group: strain.group,
      hits: strain.behind.length, total: strain.count, evidence: evidence,
      secondary: (thrive && thrive !== strain && thrive.weighted > 0) ? thrive.column : null };
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
    var group = groupPattern(inputs.columns);
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
      segmentCount: (inputs.columns || []).length
    };
  }
  takeout.buildPatterns = buildPatterns;

  takeout._groupPattern = groupPattern;
  takeout._areaPatterns = areaPatterns;
  takeout._groupByTheme = groupByTheme;

})(typeof window !== "undefined" ? window : globalThis);
