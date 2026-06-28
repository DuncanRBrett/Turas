/**
 * Pattern recognition — engine (pure; no DOM, no LLM).
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
    MIN_SPLIT_DIFF: 0.02,     // a breakout must differentiate groups by >=2% of scale to "matter"
    SPLIT_LEAD_RATIO: 1.25,   // ...and lead the next breakout by this much to be THE split (else none dominates)
    EVIDENCE_MAX: 4,          // rows of supporting evidence shown per pattern
    COHEN_H_REFERENCE: 0.8,   // Cohen's "large" effect -> full weight
    MIN_MOVE_FRACTION: 0.03,  // a wave change must be >=N of the scale to count as a "move"
                              //   (0.03 -> 0.15 on a 5-pt scale, 3pp on a 0-100 metric);
                              //   significance alone is not enough — a tiny change can test
                              //   significant on a large base yet mean nothing.
    // "Questions that move together" (co-movement). On a climate/CX survey
    // acquiescence makes EVERY question correlate positively, so a naive r
    // threshold merges the whole survey into one meaningless bundle. We therefore
    // work on PARTIAL correlation (controlling for each respondent's overall mean)
    // and require a bundle to cohere ABOVE the survey's own acquiescence floor.
    COMOVE_MIN_PARTIAL: 0.20, // an edge needs partial r >= this (after removing the global factor)
    COMOVE_MIN_BASE: 30,      // ...on at least this many complete pairwise responses
    COMOVE_ALPHA: 0.05,       // Benjamini-Hochberg FDR level across all question pairs
    COMOVE_MAX_BUNDLES: 3     // bundles shown on the card (largest / most cohesive first)
  };

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

  /* ---------------- statistical primitives (pure) ---------------- */

  /** Standard normal CDF Φ(x) — Zelen & Severo (A&S 26.2.17), |error| < 7.5e-8.
   *  Used to turn a Fisher-z statistic into a p-value for the FDR step. */
  function normalCdf(x) {
    var t = 1 / (1 + 0.2316419 * Math.abs(x));
    var d = 0.3989422804014327 * Math.exp(-x * x / 2);
    var p = d * t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 +
      t * (-1.821255978 + t * 1.330274429))));
    return x > 0 ? 1 - p : p;
  }
  takeout._normalCdf = normalCdf;

  /** Partial correlation of a,b controlling for one variable g, from the three
   *  zero-order correlations. Returns 0 when a controlled variance vanishes. */
  function partialCorr(rab, rag, rbg) {
    var d = Math.sqrt((1 - rag * rag) * (1 - rbg * rbg));
    return d > 1e-12 ? Math.max(-1, Math.min(1, (rab - rag * rbg) / d)) : 0;
  }
  takeout._partialCorr = partialCorr;

  /** Two-sided p-value for a (partial) correlation r on base n, controlling k
   *  covariates, via Fisher's z (se = 1/sqrt(n-k-3)). n too small -> p=1. */
  function corrPValue(r, n, k) {
    var df = n - (k || 0) - 3;
    if (df <= 0) return 1;
    var rc = Math.max(-0.999999, Math.min(0.999999, r));
    var z = Math.abs(0.5 * Math.log((1 + rc) / (1 - rc))) * Math.sqrt(df);  // atanh(rc)*sqrt(df)
    return 2 * normalCdf(-z);
  }
  takeout._corrPValue = corrPValue;

  /** Benjamini-Hochberg FDR. Given p-values, returns the indices that survive at
   *  level alpha: the largest rank k with p(k) <= (k/m)*alpha rejects all p ranked
   *  <= k. Valid under positive dependence (PRDS) — which inter-question
   *  correlations on an attitude survey satisfy (all-positive), so BH (not the
   *  far more conservative Benjamini-Yekutieli) is the right correction here. */
  function bhFDR(pvals, alpha) {
    var m = pvals.length;
    if (!m) return [];
    var order = pvals.map(function (p, i) { return { p: p, i: i }; })
      .sort(function (a, b) { return a.p - b.p; });
    var kMax = -1;
    for (var k = 0; k < m; k++) {
      if (order[k].p <= ((k + 1) / m) * alpha) kMax = k;
    }
    var out = [];
    for (var j = 0; j <= kMax; j++) out.push(order[j].i);
    return out;
  }
  takeout._bhFDR = bhFDR;

  /**
   * CO-MOVEMENT pattern: groups of questions that rise and fall together across
   * PEOPLE — a shared underlying driver you can act on once, not question by
   * question. The hard part is NOT finding correlation (on an attitude survey
   * everything correlates — acquiescence); it is finding structure ABOVE that
   * halo. So we work on the PARTIAL correlation that removes each respondent's
   * overall level, keep only edges that (a) clear COMOVE_MIN_PARTIAL, (b) survive
   * Benjamini-Hochberg FDR across all pairs, on (c) an adequate base; then group
   * the survivors into connected bundles and keep only bundles whose within-bundle
   * RAW correlation sits above the survey's own acquiescence floor. Returns null
   * (a confident null) when no bundle clears the bar.
   *
   * Input (from gather): { questions:[{code,title}], r:[][], base:[][],
   *   rGlobal:[], floor:Number } where r/base are symmetric n x n matrices of the
   *   zero-order weighted correlation and complete-pair base, rGlobal[i] is item
   *   i's correlation with the per-respondent overall mean, floor is the mean
   *   inter-item raw r (the acquiescence baseline).
   */
  function comovementPattern(cm) {
    if (!cm || !cm.questions || cm.questions.length < 3) return null;
    var qs = cm.questions, n = qs.length, floor = cm.floor || 0;
    var totalPairs = n * (n - 1) / 2;
    var edges = [];                                   // candidate pairs with adequate base
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var base = cm.base[i][j];
        if (!base || base < CONST.COMOVE_MIN_BASE) continue;
        var pr = partialCorr(cm.r[i][j], cm.rGlobal[i], cm.rGlobal[j]);
        edges.push({ i: i, j: j, partial: pr, raw: cm.r[i][j], base: base,
          p: corrPValue(pr, base, 1) });
      }
    }
    if (!edges.length) return null;
    // FDR across all candidate pairs, then keep positive partial edges above the floor strength
    var survive = {};
    bhFDR(edges.map(function (e) { return e.p; }), CONST.COMOVE_ALPHA)
      .forEach(function (k) { survive[k] = true; });
    var kept = edges.filter(function (e, k) {
      return survive[k] && e.partial >= CONST.COMOVE_MIN_PARTIAL;
    });
    if (!kept.length) return null;
    // connected components over the surviving edges (union-find)
    var parent = qs.map(function (_, idx) { return idx; });
    function find(x) { while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x]; } return x; }
    kept.forEach(function (e) { parent[find(e.i)] = find(e.j); });
    var comp = {};
    kept.forEach(function (e) {
      var root = find(e.i);
      (comp[root] || (comp[root] = { nodes: {}, edges: [] }));
      comp[root].nodes[e.i] = true; comp[root].nodes[e.j] = true;
      comp[root].edges.push(e);
    });
    var bundles = [];
    Object.keys(comp).forEach(function (root) {
      var members = Object.keys(comp[root].nodes).map(Number);
      if (members.length < 2) return;
      // within-bundle mean RAW r over every internal pair -> must beat the floor
      var sum = 0, cnt = 0;
      for (var a = 0; a < members.length; a++) {
        for (var b = a + 1; b < members.length; b++) {
          var rr = cm.r[members[a]][members[b]];
          if (rr !== null && rr !== undefined) { sum += rr; cnt++; }
        }
      }
      var meanRaw = cnt ? sum / cnt : 0;
      if (meanRaw <= floor) return;                   // cohesion not above the acquiescence baseline
      var anchor = comp[root].edges.slice().sort(function (x, y) { return y.partial - x.partial; })[0];
      bundles.push({
        members: members.map(function (m) { return { code: qs[m].code, title: qs[m].title }; }),
        size: members.length, meanRaw: meanRaw, lift: meanRaw - floor,
        anchor: { a: qs[anchor.i].title, b: qs[anchor.j].title, partial: anchor.partial }
      });
    });
    if (!bundles.length) return null;
    bundles.sort(function (x, y) { return (y.size - x.size) || (y.meanRaw - x.meanRaw); });
    return { id: "comove", kind: "comove", subject: "Questions that move together",
      floor: floor, pairCount: totalPairs, bundleCount: bundles.length,
      bundles: bundles.slice(0, CONST.COMOVE_MAX_BUNDLES) };
  }
  takeout._comovementPattern = comovementPattern;

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

  /**
   * SPLIT pattern: which breakout (campus / department / tenure / …) differentiates
   * groups the most — the lens worth looking through. For each breakout we measure
   * how spread its groups' average gaps-to-overall are (base-weighted), and name
   * the breakout only if it both differentiates meaningfully AND clearly leads the
   * others (else no single split dominates -> omitted). Reuses the column data.
   */
  function splitPattern(columns) {
    var byGroup = {};
    (columns || []).forEach(function (c) {
      if (!c.gaps || !c.gaps.length) return;
      var net = 0, sumV = 0, max = 0;
      c.gaps.forEach(function (gp) {
        net += (gp.value - gp.total) / (gp.scaleMax || 1);
        sumV += gp.value; max = gp.scaleMax || max;
      });
      (byGroup[c.group] || (byGroup[c.group] = [])).push({ column: c.column, base: c.base || 0,
        avgGap: net / c.gaps.length, avgValue: sumV / c.gaps.length, scaleMax: max });
    });
    var scored = Object.keys(byGroup).map(function (gn) {
      var cols = byGroup[gn];
      if (cols.length < 2) return null;
      var sw = 0, mean = 0;
      cols.forEach(function (x) { sw += x.base; mean += x.base * x.avgGap; });
      mean = sw ? mean / sw : 0;
      var ss = 0;
      cols.forEach(function (x) { ss += x.base * Math.pow(x.avgGap - mean, 2); });
      return { group: gn, diff: sw ? Math.sqrt(ss / sw) : 0, cols: cols };
    }).filter(Boolean);
    if (!scored.length) return null;
    scored.sort(function (a, b) { return b.diff - a.diff; });
    var top = scored[0], second = scored[1];
    if (top.diff < CONST.MIN_SPLIT_DIFF) return null;                            // nothing differentiates much
    if (second && top.diff < second.diff * CONST.SPLIT_LEAD_RATIO) return null;  // no single split dominates
    var sorted = top.cols.slice().sort(function (a, b) { return a.avgValue - b.avgValue; });
    var low = sorted[0], high = sorted[sorted.length - 1];
    return { id: "split", kind: "split", subject: top.group,
      high: { label: high.column, value: high.avgValue, scaleMax: high.scaleMax },
      low: { label: low.column, value: low.avgValue, scaleMax: low.scaleMax } };
  }
  takeout._splitPattern = splitPattern;

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
    var split = splitPattern(inputs.columns);
    if (split) patterns.push(split);
    var comove = comovementPattern(inputs.comove);
    if (comove) patterns.push(comove);
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
