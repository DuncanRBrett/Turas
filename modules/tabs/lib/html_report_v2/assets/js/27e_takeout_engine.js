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
    PORTRAIT_MAX: 3,          // group portraits shown on the page (ranked by tension)
    COHEN_H_REFERENCE: 0.8,   // Cohen's "large" effect -> full weight
    MIN_MOVE_FRACTION: 0.03,  // a wave change must be >=N of the scale to count as a "move"
                              //   (0.03 -> 0.15 on a 5-pt scale, 3pp on a 0-100 metric);
                              //   significance alone is not enough — a tiny change can test
                              //   significant on a large base yet mean nothing.
    // Multiple-comparison trust-gate. Scanning every breakout group x rated
    // question is hundreds of cells; ~5% look striking by luck, and tiny
    // homogeneous census cells produce absurd t-stats. Two guards: per-cell BH on
    // a variance-floored Welch test (badges single-cell claims, seeds odd-one-out),
    // and a per-group directional sign-test (gates the group/split patterns — a
    // consistent group like Cape Town has NO single significant cell, so gating it
    // on per-cell significance would wrongly delete it).
    VARIANCE_FLOOR_FRACTION: 0.1, // arm sd floored at 10% of the scale SPAN; (span*0.1)^2 (=0.16 on 1..5)
    FDR_ALPHA: 0.05,          // Benjamini-Hochberg level (both the cell and the group families)
    FDR_METHOD: "BH",         // PRDS-justified (inter-item r all-positive); NOT Benjamini-Yekutieli
    BADGE_MIN_BASE: 12,       // a cell earns the "survives correction" chip only on a group arm >= this
    SIGN_ALPHA: 0.05,         // BH level for the per-group sign-test family (gates group/split)
    SPLIT_MIN_CONSISTENT: 2,  // the winning split must contain >= this many sign-test-consistent groups
    // "The odd one out": a group below (above) almost everywhere yet the reverse
    // on one question — a sign-flip against its OWN direction, large and real.
    ODD_MIN_GAP: 0.20,        // |gap to overall| floor, scale points
    ODD_MIN_RESID: 0.30,      // |gap - the group's mean gap| floor — the break from its own pattern
    ODD_MIN_TEST_BASE: 8,     // soft per-cell base floor so a flip can't rest on a thin census cell
    // "Hidden disagreement" (bimodality): a calm-looking average hiding two camps.
    BIMODAL_B: 0.5556,        // moment-form Sarle bimodality coefficient must exceed 5/9 (uniform reference)
    BIMODAL_CALM_FRAC: 0.25,  // |mean - mid| <= this fraction of the half-range (the average looks calm)
    BIMODAL_MIN_CAMP: 0.20,   // each end-camp (top-two / bottom-two cats) carries >= this share
    BIMODAL_MIN_DIP: 0.05,    // the middle sits >= this far below the lower end-peak (a real trough)
    BIMODAL_MIN_BASE: 30      // shape-claim base floor (distinct from the census reporting floor)
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

  /* ---------------- statistical primitives ---------------- */
  // The pure number-crunching lives in 27da_takeout_stats.js (loaded first);
  // alias the few this engine uses so the pattern logic below reads cleanly.
  var bhFDR = takeout._bhFDR, signTest = takeout._signTest, bimodalStat = takeout._bimodalStat;

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
   * Per (banner, question) extremes across every breakout column, so a portrait
   * can say a group is the highest / lowest of its peers (e.g. "the highest of any
   * campus"). Cheap peer-relative annotation, no config — the §9 sharpening.
   */
  function peerExtremes(columns) {
    var by = {};
    (columns || []).forEach(function (c) {
      c.gaps.forEach(function (gp) {
        var key = c.group + "||" + gp.title;
        var e = by[key] || (by[key] = { count: 0, hi: null, lo: null });
        e.count++;
        if (e.hi === null || gp.value > e.hi.value) e.hi = { col: c.column, value: gp.value };
        if (e.lo === null || gp.value < e.lo.value) e.lo = { col: c.column, value: gp.value };
      });
    });
    return by;
  }

  /**
   * GROUP PORTRAITS — the centrepiece (rebuild). For every breakout column, read
   * its INDEX gap to the overall on each rated question and assemble a BALANCED
   * portrait: the questions where it sits LOW and the questions where it sits HIGH
   * in one card. A group is worth calling out for EITHER reason: a sharp TENSION
   * (it leans one way yet breaks its own pattern the other — Cape Town strained on
   * engagement but proudest of co-worker quality), OR sheer uniform extremeness
   * (top, or bottom, on nearly everything — 20 of 21 metrics). So ranking is by
   * storyScore = how much the group stands out overall (character, base-weighted)
   * PLUS a tension boost — a uniformly extreme group is never buried beneath a
   * minor tension, and a genuine tension still rises among equally-extreme groups.
   * Gated on directional consistency when the FDR family is present (never-cry-wolf
   * — a mixed, lean-less group is not a story), else on a materiality floor. Every
   * number shown is a real cell: the group's value and the overall, both visible in
   * the crosstabs (no synthetic aggregate). Returns a ranked array; the caller
   * takes the top few and seeds the GPS line from #1.
   * Input: same columns as groupPattern — [{column, group, base, gaps:[{title,
   * value, total, scaleMax}]}].
   */
  function portraits(columns, gate) {
    if (!columns || !columns.length) return [];
    var cons = {};
    if (gate) gate.groups.forEach(function (g) { cons[g.banner + "::" + g.group] = g; });
    var peers = peerExtremes(columns);
    var made = columns.map(function (c) {
      var lows = [], highs = [];
      c.gaps.forEach(function (gp) {
        var frac = (gp.value - gp.total) / (gp.scaleMax || 1);
        var peer = peers[c.group + "||" + gp.title] || { count: 0 };
        // isPct marks a KeyShare row (a favourable %, not an index mean) so the
        // card and the tension sentence format it as "62% / 71%", never "62.0".
        var row = { label: gp.title, value: gp.value, rest: gp.total, scaleMax: gp.scaleMax,
          frac: frac, isMean: !gp.isPct, isPct: !!gp.isPct, peerCount: peer.count,
          peerTop: !!(peer.hi && peer.hi.col === c.column),
          peerBottom: !!(peer.lo && peer.lo.col === c.column) };
        if (frac <= -CONST.MIN_STRAIN_GAP) lows.push(row);
        else if (frac >= CONST.MIN_STRAIN_GAP) highs.push(row);
      });
      lows.sort(function (a, b) { return a.frac - b.frac; });    // most below first
      highs.sort(function (a, b) { return b.frac - a.frac; });   // most above first
      var sumLow = lows.reduce(function (s, r) { return s - r.frac; }, 0);   // positive magnitude
      var sumHigh = highs.reduce(function (s, r) { return s + r.frac; }, 0);
      var tot = sumLow + sumHigh;
      var leanScore = tot ? Math.abs(sumLow - sumHigh) / tot : 0;
      var strained = sumLow >= sumHigh;
      var minority = strained ? highs : lows;
      var counterSpike = minority.length ? Math.abs(minority[0].frac) : 0;
      var weight = Math.min(1, (c.base || 0) / CONST.STRAIN_RELIABLE_BASE);
      var g = cons[c.group + "::" + c.column];
      // character = how much the group stands out overall (its dominant direction's
      // average gap, base-weighted) — high for a uniformly extreme group AND for a
      // strong-leaning one. tension = the counter-spike against that lean.
      var tensionScore = leanScore * counterSpike * weight;
      var characterScore = Math.max(sumLow, sumHigh) / (c.gaps.length || 1) * weight;
      return { id: "portrait:" + c.group + "::" + c.column, kind: "portrait",
        subject: c.column, group: c.group, base: c.base,
        lean: strained ? "strained" : "thriving",
        lows: lows.slice(0, CONST.EVIDENCE_MAX), highs: highs.slice(0, CONST.EVIDENCE_MAX),
        hits: lows.length, gains: highs.length, total: c.gaps.length,
        counterSpike: counterSpike, tensionScore: tensionScore, characterScore: characterScore,
        storyScore: characterScore + tensionScore,   // notable for tension OR extremeness
        uniform: counterSpike === 0,                  // top/bottom on (nearly) everything
        consistent: g ? g.consistent : null, signP: g ? g.signP : null, dir: g ? g.dir : null };
    });
    var eligible = made.filter(function (p) {
      if ((p.hits + p.gains) < CONST.MIN_GROUP_HITS) return false;     // too few standouts
      if (p.characterScore < CONST.MIN_STRAIN_GAP) return false;       // not materially standing out
      if (p.consistent === false) return false;   // gate present and group not directionally consistent
      return true;
    });
    eligible.sort(function (a, b) {
      return (b.storyScore - a.storyScore) || (b.characterScore - a.characterScore);
    });
    return eligible;
  }
  takeout._portraits = portraits;

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

  /** An area can only be summarised when its questions share a scale family —
   *  otherwise rolling them up (e.g. an NPS 0–100 with a 1–5 index) averages
   *  apples and oranges, the exact fault Duncan flagged. Same scaleMax = same
   *  family. (Later: a config Scale_Family tag overrides this auto-detection.) */
  function commensurable(members) {
    var sm = members[0] && members[0].scaleMax;
    return members.every(function (m) { return m.scaleMax === sm; });
  }

  /** WEAKEST and STRONGEST area patterns from multi-question themes — only themes
   *  whose questions share a scale (commensurable), so no cross-scale average. */
  function areaPatterns(levels) {
    var themes = groupByTheme(levels).filter(function (t) {
      return t.name !== "(untagged)" && t.members.length >= CONST.MIN_AREA_MEMBERS &&
        commensurable(t.members);
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
   * FDR multiple-comparison TRUST-GATE (not a card). Two guards over the shared
   * cell family (gatherCellFamily): per-cell Benjamini-Hochberg badges
   * single-striking-cell claims and seeds the odd-one-out; a per-group directional
   * sign-test (also BH-corrected) decides which groups are genuinely CONSISTENT.
   * The group/split patterns gate on the per-GROUP set (consistency), NEVER on the
   * per-CELL set — a consistent group like Cape Town can have zero individually-
   * significant cells, so gating it on per-cell significance would wrongly delete
   * it. No FPC anywhere (that lives in the reliability layer).
   */
  function fdrGate(fdr) {
    if (!fdr || !fdr.cells || !fdr.cells.length) return null;
    var cells = fdr.cells;
    var bhAll = bhFDR(cells.map(function (c) { return c.welchP; }), CONST.FDR_ALPHA);
    var survivorSet = {}; bhAll.forEach(function (k) { survivorSet[k] = true; });
    var badge = [];
    bhAll.forEach(function (k) {                       // strict: badge only credible bases, never a floored cell
      var c = cells[k];
      if (c.nIn >= CONST.BADGE_MIN_BASE && !c.flooredG) badge.push(c);
    });
    var groups = fdr.groups || [];
    var signSurv = {};
    bhFDR(groups.map(function (g) { return signTest(g.below, g.above).p; }), CONST.SIGN_ALPHA)
      .forEach(function (k) { signSurv[k] = true; });
    var groupsOut = groups.map(function (g, i) {
      var st = signTest(g.below, g.above);
      return { banner: g.banner, group: g.group, base: g.base, below: g.below, above: g.above,
        qn: g.qn, meanGap: g.meanGap, signP: st.p, dir: st.dir, consistent: !!signSurv[i] };
    });
    return { kind: "fdr", K: fdr.K, groupCount: fdr.groupCount, questionCount: fdr.questionCount,
      alpha: CONST.FDR_ALPHA, method: CONST.FDR_METHOD,
      badge: { count: badge.length, cells: badge.map(function (c) {
        return { banner: c.banner, group: c.group, q: c.q, qtitle: c.qtitle, nG: c.nIn, diff: c.welchDiff, p: c.welchP };
      }) },
      survivorSet: survivorSet,                        // index set into fdr.cells (for odd-one-out)
      groups: groupsOut,
      cellSurvivorCount: bhAll.length,
      dirSurvivorCount: groupsOut.filter(function (g) { return g.consistent; }).length };
  }
  takeout._fdrGate = fdrGate;

  /** Does the per-cell badge set contain this (group column, question title)? */
  function badgeHas(gate, group, qtitle) {
    return !!(gate && gate.badge.cells.some(function (c) {
      return c.group === group && c.qtitle === qtitle;
    }));
  }

  /**
   * THE ODD ONE OUT: a group that runs below (above) the overall almost everywhere
   * yet is unexpectedly the reverse on ONE question — a sign-flip against its OWN
   * direction, large and real. Reads the SHARED cell family + the gate's per-cell
   * BH survivor set (no second family). A candidate must (1) flip against the
   * group's mean-gap direction, (2) clear an absolute gap floor AND a residual
   * floor (the break from the group's own pattern), (3) agree in sign with the
   * group-vs-rest Welch difference, (4) survive multiple-comparison correction, and
   * (5) sit on a credible base. Returns a typed confident-null marker when none
   * survive (on real SACS, none do — every striking cell is a same-direction
   * extreme, not an exception).
   */
  function oddOnePattern(fdr, gate) {
    if (!fdr || !fdr.cells || !gate) return null;
    var mg = {};
    gate.groups.forEach(function (g) { mg[g.banner + "::" + g.group] = g.meanGap; });
    var cand = [];
    fdr.cells.forEach(function (c, idx) {
      // KeyShare cells gap in pp on a 0–100 encoding; the fixed floors below
      // (ODD_MIN_GAP / ODD_MIN_RESID) are scale-point tuned, and the meanGap
      // baseline is rated-only — so share cells sit out of this finder, exactly
      // as NPS does (same cross-scale-fabrication guard, F1).
      if (c.isPct) return;
      var meanGap = mg[c.banner + "::" + c.group];
      if (meanGap === undefined) return;
      var dir = meanGap < 0 ? -1 : 1, gapSign = c.gap < 0 ? -1 : 1;
      if (c.gap === 0 || gapSign === dir) return;                       // (1) must flip the group's direction
      if (Math.abs(c.gap) < CONST.ODD_MIN_GAP) return;                  // (2a) absolute materiality
      var resid = c.gap - meanGap;
      if (Math.abs(resid) < CONST.ODD_MIN_RESID) return;                // (2b) breaks the group's OWN pattern
      if ((c.welchDiff < 0 ? -1 : 1) !== gapSign) return;               // (3) Welch agrees in sign (no base-composition reversal)
      if (!gate.survivorSet[idx]) return;                               // (4) survives the shared per-cell BH pass
      if (c.nIn < CONST.ODD_MIN_TEST_BASE) return;                      // (5) credible base
      cand.push({ banner: c.banner, group: c.group, q: c.q, qtitle: c.qtitle, gap: c.gap,
        meanGap: meanGap, resid: resid, value: c.value, total: c.total, scaleMax: c.scaleMax,
        welchDiff: c.welchDiff, welchP: c.welchP, nIn: c.nIn });
    });
    if (!cand.length) return { id: "odd", kind: "odd", nullResult: true, familyCells: fdr.K, survivors: 0 };
    cand.sort(function (a, b) { return Math.abs(b.resid) - Math.abs(a.resid); });
    var top = cand[0];
    return { id: "odd", kind: "odd", subject: top.group, group: top.banner, column: top.group,
      flip: top, direction: top.meanGap < 0 ? "low-but-high" : "high-but-low",
      secondary: cand.slice(1, CONST.EVIDENCE_MAX), familyCells: fdr.K, survivors: cand.length };
  }
  takeout._oddOnePattern = oddOnePattern;

  /**
   * HIDDEN DISAGREEMENT (bimodality): a question whose AVERAGE looks calm yet the
   * distribution splits into two end-camps with a middle trough — a split the mean
   * hides. Each question must clear ALL of: a moment-form Sarle coefficient above
   * the uniform reference (gB); a peak in each end band above the middle (gShape);
   * a real central dip (gDip); a calm mean (gCalm); real mass in each camp (gCamp);
   * an adequate base (gBase). The structural conjunction IS the multiplicity-safe
   * correction here (the false positives are systematic ceiling-skew, not random),
   * so this does NOT route through BH. Confident-null marker when none flag (on
   * real SACS, every distribution is single-peaked — none do).
   */
  function bimodalityPattern(bm) {
    if (!bm || !bm.questions || !bm.questions.length) return null;
    var flagged = [];
    bm.questions.forEach(function (q) {
      var counts = q.counts, K = q.scaleMax, st = bimodalStat(counts, K);
      if (!st) return;
      var n = st.n, h = Math.floor(K / 2), bMax = 0, tMax = 0, mMax = 0;
      for (var c = 0; c < K; c++) {
        var frac = (counts[c] || 0) / n;
        if (c < h) { if (frac > bMax) bMax = frac; }
        else if (c >= K - h) { if (frac > tMax) tMax = frac; }
        else if (frac > mMax) mMax = frac;
      }
      var bottomTwo = ((counts[0] || 0) + (counts[1] || 0)) / n;
      var topTwo = ((counts[K - 1] || 0) + (counts[K - 2] || 0)) / n;
      var minCamp = Math.min(bottomTwo, topTwo);
      var calmFrac = Math.abs(st.mean - (K + 1) / 2) / ((K - 1) / 2);
      var dipFrac = Math.min(bMax, tMax) - mMax;
      if (st.bMoment > CONST.BIMODAL_B && bMax > mMax && tMax > mMax &&
          dipFrac >= CONST.BIMODAL_MIN_DIP && calmFrac <= CONST.BIMODAL_CALM_FRAC &&
          minCamp >= CONST.BIMODAL_MIN_CAMP && n >= CONST.BIMODAL_MIN_BASE) {
        var dist = [];
        for (var d = 0; d < K; d++) dist.push(Math.round((counts[d] || 0) / n * 100));
        flagged.push({ code: q.code, title: q.title, b: st.b, mean: st.mean, scaleMax: K,
          dipFrac: dipFrac, camps: { bottom: bottomTwo, top: topTwo }, dist: dist });
      }
    });
    if (!flagged.length) return { id: "bimodal", kind: "bimodal", nullResult: true, scanned: bm.questions.length };
    flagged.sort(function (a, b) { return b.dipFrac - a.dipFrac; });
    return { id: "bimodal", kind: "bimodal", subject: "Hidden disagreement",
      scanned: bm.questions.length, flaggedCount: flagged.length, questions: flagged };
  }
  takeout._bimodalityPattern = bimodalityPattern;

  /** One-line statements of a rigor-check hit, for the footer (plain text —
   *  the read view escapes them; every number is a real cell). */
  function round1(v) { return Math.round(v * 10) / 10; }
  function oddNote(odd) {
    var f = odd.flip;
    return odd.subject + (odd.direction === "low-but-high"
      ? " runs low overall yet sits above the overall on “"
      : " runs high overall yet sits below the overall on “") +
      f.qtitle + "” (" + round1(f.value) + " vs " + round1(f.total) + ")";
  }
  function bimodalNote(bm) {
    var titles = bm.questions.slice(0, 2).map(function (q) { return "“" + q.title + "”"; });
    var more = bm.flaggedCount - titles.length;
    return titles.join(", ") + (more > 0 ? " and " + more + " more" : "") +
      (bm.flaggedCount === 1 ? " splits" : " split") + " into two camps behind a calm average";
  }

  /**
   * Build the patterns object from gathered inputs. Pure: same inputs always give
   * the same patterns. Assembles GROUP + SPLIT + CO-MOVEMENT + WEAK/STRONG AREA +
   * MOVEMENT, omitting any that cannot be computed (graceful degradation). When the
   * FDR family is present, the group and split patterns are additionally GATED on
   * directional consistency, and their evidence rows are badged where a single cell
   * survives multiplicity correction.
   */
  function buildPatterns(inputs) {
    inputs = inputs || {};
    var patterns = [];
    var gate = fdrGate(inputs.fdr);

    // Centrepiece: ranked group portraits (tension-led). The top few become cards;
    // #1 seeds the GPS line. Replaces the one-group "under strain" card and folds
    // the old "most positive group" line into each portrait's highs.
    var ports = portraits(inputs.columns, gate);
    ports.slice(0, CONST.PORTRAIT_MAX).forEach(function (p) { patterns.push(p); });

    // Which cut divides the data most — a navigation pointer, NO synthetic average.
    var split = splitPattern(inputs.columns);
    if (split) {
      var consistentGroups = gate ? gate.groups.filter(function (x) {
        return x.banner === split.subject && x.consistent;
      }).length : null;
      if (gate) split.consistent = consistentGroups >= CONST.SPLIT_MIN_CONSISTENT;
      if (!gate || split.consistent) { split.sigGaps = consistentGroups; patterns.push(split); }
    }

    // Weakest / strongest AREA — only commensurable themes (same scale family).
    areaPatterns(inputs.levels || []).forEach(function (p) { patterns.push(p); });

    // Movement (trackers) — unchanged.
    var moved = movementPattern(inputs.apex || []);
    if (moved) patterns.push(moved);

    // Co-moving RETIRED (the acquiescence halo, not a pattern). Odd-one-out and
    // hidden disagreement DEMOTED to the rigor footer — still computed (the
    // never-cry-wolf check), no card (the Phase-1 card set is banked). A hit
    // carries a one-line note so the footer states the finding, truthfully.
    var odd = oddOnePattern(inputs.fdr, gate);
    var bimodal = bimodalityPattern(inputs.bimodal);
    var rigor = {
      odd: odd ? { scanned: odd.familyCells || (gate ? gate.K : 0),
        survivors: odd.survivors || 0, found: !odd.nullResult,
        note: odd.nullResult ? null : oddNote(odd) } : null,
      bimodal: bimodal ? { scanned: bimodal.scanned || 0,
        flagged: bimodal.flaggedCount || 0, found: !bimodal.nullResult,
        note: bimodal.nullResult ? null : bimodalNote(bimodal) } : null
    };

    return {
      answer: { metrics: inputs.apex || [] },
      reliability: inputs.reliability || null,
      patterns: patterns,
      portraitCount: ports.length,
      fdr: gate,
      rigor: rigor,
      scope: inputs.scope || null,   // what was scannable — the read view's honest empty state
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
