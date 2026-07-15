/**
 * v2 wave history — matches 2025 questions to the published results of
 * every prior wave (TR.PREV.waves; any number of waves) and serves trend
 * series for the Total column AND for banner segments where the wave
 * workbooks carry them (sparse: e.g. Campus 2020-2022+2024, more in 2024).
 *
 * Matching is by normalised title, occurrence-ordered for duplicate titles,
 * mirroring pipeline/extract_waves.py (which also applies the cross-wave
 * title + segment aliases). History values are always published wave
 * figures — the synthetic microdata never filters prior waves.
 *
 * SIZE-EXCEPTION: one wave-history engine; the Total and per-segment read
 * paths share the NET member-sum / NET POSITIVE / Index-recompute fallback
 * logic and splitting them would duplicate the methodology.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var waves = TR.waves = {};

  var waveIndexes = null;  // [{wave, year, index: {match_key: waveQ}}]
  var aggKeys = null;      // 2025 qcode -> occurrence-ordered match key
  var segCache = null;     // ordered tracked segments

  /** Drop the lazy caches (call if TR.PREV / TR.AGG are swapped at runtime). */
  waves.reset = function () { waveIndexes = null; aggKeys = null; segCache = null; };

  function ensureIndexes() {
    if (waveIndexes) return;
    waveIndexes = (TR.PREV && TR.PREV.waves ? TR.PREV.waves : []).map(function (w) {
      var index = {};
      (w.questions || []).forEach(function (p) {
        index[p.match_key || p.title_norm] = p;
      });
      return { wave: w.wave, year: w.year, current: !!w.current, index: index };
    });
    aggKeys = {};
    // Prefer the current wave's explicit question code -> match_key map (carried
    // when a question mapping links waves by a canonical key, robust to renames);
    // fall back to occurrence-ordered normalised title for unmapped questions, so
    // the title-match path and SACAP (no current/code map) are unaffected.
    var mapped = {};
    waveIndexes.forEach(function (w) {
      if (!w.current) return;
      Object.keys(w.index).forEach(function (key) {
        var p = w.index[key];
        if (p.code) { aggKeys[p.code] = key; mapped[p.code] = true; }
      });
    });
    var seen = {};
    TR.AGG.questions.forEach(function (q) {
      if (mapped[q.code]) return;
      var t = TR.model.norm(q.title);
      var k = seen[t] || 0;
      seen[t] = k + 1;
      aggKeys[q.code] = k === 0 ? t : t + "#" + k;
    });
  }

  /** Matched history for a question: [{wave, year, base, q}], oldest first. */
  waves.history = function (q) {
    ensureIndexes();
    var out = [];
    waveIndexes.forEach(function (w) {
      if (w.current) return;   // the current wave is handled by the live model
      var hit = w.index[aggKeys[q.code]];
      if (hit) out.push({ wave: w.wave, year: w.year, base: hit.base, q: hit });
    });
    return out;
  };

  /** Per-respondent scores for q in the CURRENT wave (the island wave flagged
   *  `current`), or null. Lets the live model derive the current point's SD
   *  from microdata when its published distribution is absent — so wave-on-wave
   *  significance holds without any pre-calculated figure. */
  waves.currentScores = function (q) {
    ensureIndexes();
    for (var i = 0; i < waveIndexes.length; i++) {
      if (!waveIndexes[i].current) continue;
      var hit = waveIndexes[i].index[aggKeys[q.code]];
      if (hit && hit.scores) return hit.scores;
    }
    return null;
  };

  /** Per-respondent weights for q in the CURRENT wave (parallel to
   *  currentScores), or null when the wave is unweighted. */
  waves.currentWeights = function (q) {
    ensureIndexes();
    for (var i = 0; i < waveIndexes.length; i++) {
      if (!waveIndexes[i].current) continue;
      var hit = waveIndexes[i].index[aggKeys[q.code]];
      if (hit && hit.scores) return hit.weights || null;
    }
    return null;
  };

  /** Current-wave point {value, base, sd} recomputed from microdata (Total),
   *  or null. Treating the current wave exactly like history keeps the whole
   *  series internally consistent — full precision, no rounded summary. */
  waves.currentPoint = function (q) {
    var s = waves.currentScores(q);
    if (!s || !s.length) return null;
    var w = waves.currentWeights(q);
    return { value: meanOfScores(s, w), base: s.length, sd: sdOfScores(s, w),
      effBase: effNfromWeights(w, s.length) };
  };

  /**
   * Tracked segments: 2025 banner columns present in at least one wave,
   * in 2025 column order: [{label, norm, group, years: [..]}].
   */
  waves.segments = function () {
    if (segCache) return segCache;
    var byNorm = {};
    ((TR.PREV && TR.PREV.waves) || []).forEach(function (w) {
      (w.segments || []).forEach(function (s) {
        (byNorm[s.norm] = byNorm[s.norm] || []).push(w.year);
      });
    });
    segCache = [];
    TR.AGG.columns.forEach(function (col) {
      var n = TR.model.norm(col.label);
      if (byNorm[n]) {
        segCache.push({ label: col.label, norm: n, group: col.group,
          years: byNorm[n] });
      }
    });
    return segCache;
  };

  /* ---------- per-row published values (seg = null means Total) ---------- */

  function rowValue(waveQ, label, seg) {
    if (!waveQ.rows) return null;   // microdata-only wave: no published distribution
    var hit = waveQ.rows[TR.model.norm(label)];
    if (!hit) return null;
    if (seg) {
      return hit.seg && hit.seg[seg] !== undefined ? hit.seg[seg] : null;
    }
    return hit.pct !== undefined ? hit.pct : null;
  }

  /** NET fallback for waves published without NET rows: sum the members. */
  function netFromMembers(q, ri, waveQ, seg) {
    var members = q.net_members && q.net_members[String(ri)];
    if (!members) return null;
    var sum = 0;
    for (var i = 0; i < members.length; i++) {
      var v = rowValue(waveQ, q.rows[members[i]].label, seg);
      if (v === null) return null;
      sum += v;
    }
    return sum;
  }

  function netValue(q, ri, waveQ, seg) {
    var v = rowValue(waveQ, q.rows[ri].label, seg);
    return v !== null ? v : netFromMembers(q, ri, waveQ, seg);
  }

  /** Index mean recomputed from a wave's published distribution. Requires
   *  EVERY scored category to resolve in the prior wave (same all-or-nothing
   *  rule as netFromMembers): a partial match would re-normalise over a
   *  truncated distribution and fabricate a shifted mean. */
  function indexFromDistribution(q, waveQ, seg) {
    if (!q.index_scores) return null;
    var sum = 0, weight = 0, missing = false;
    Object.keys(q.index_scores).forEach(function (label) {
      var v = rowValue(waveQ, label, seg);
      if (v === null) { missing = true; return; }
      sum += q.index_scores[label] * v; weight += v;
    });
    return (!missing && weight > 0) ? sum / weight : null;
  }

  /* ---------- microdata recompute (per-respondent scores) ----------
   * A wave question may carry `scores`: per-respondent metric values (the
   * rating for means; +100/0/-100 for NPS). When present, the headline value
   * and its SD are recomputed directly from them — the flexible model that
   * needs no published distribution and no pre-baked significance. Absent
   * (e.g. SACAP), every path below falls back to stats/distribution, so
   * existing reports are byte-for-byte unaffected. Total column only for now
   * (per-segment microdata recompute arrives with banner-aware waves). */
  // Per-respondent score reducers. An optional parallel weights array makes the
  // wave mean/SD weighted (so the trend matches a weighted crosstab); absent or
  // all-1 weights reduce to the prior unweighted formulas exactly.
  function meanOfScores(s, w) {
    if (!s || !s.length) return null;
    var sum = 0, wsum = 0;
    for (var i = 0; i < s.length; i++) {
      var wi = w ? w[i] : 1; sum += wi * s[i]; wsum += wi;
    }
    return wsum ? sum / wsum : null;
  }
  function sdOfScores(s, w) {
    if (!s || s.length < 2) return null;
    var m = meanOfScores(s, w);
    if (m === null) return null;
    var v = 0, wsum = 0, sumW2 = 0;
    for (var i = 0; i < s.length; i++) {
      var wi = w ? w[i] : 1, d = s[i] - m;
      v += wi * d * d; wsum += wi; sumW2 += wi * wi;
    }
    var effN = sumW2 > 0 ? (wsum * wsum) / sumW2 : 0;   // Kish effective base
    if (effN <= 1) return null;
    return Math.sqrt((v / wsum) * effN / (effN - 1));    // sample SD (effN df)
  }
  waves.sdFromScores = sdOfScores;
  // exposed for the regression tests (audit_stats_tests.mjs)
  waves._sigPair = sigPair;
  waves._indexFromDistribution = indexFromDistribution;

  function meanValue(q, row, waveQ, seg) {
    if (!seg && waveQ.scores) return meanOfScores(waveQ.scores, waveQ.weights);  // microdata
    var stats = (seg ? (waveQ.seg_stats || {})[seg] : waveQ.stats) || {};
    var label = TR.model.norm(row.label);
    if (label.indexOf("nps") !== -1) {
      return stats.nps !== undefined ? stats.nps : null;
    }
    if (label === "mean") {
      return stats.mean !== undefined ? stats.mean : null;
    }
    return stats.index !== undefined
      ? stats.index : indexFromDistribution(q, waveQ, seg);
  }

  /**
   * Published value of view-model row ri in one wave question, or null.
   * ri indexes q.rows — attachDeltas runs before row ops reorder them.
   */
  waves.valueAt = function (q, row, ri, waveQ, seg) {
    if (row.kind === "mean") return meanValue(q, row, waveQ, seg);
    var diff = q.net_diffs && q.net_diffs[String(ri)];
    if (diff) {
      var v = rowValue(waveQ, row.label, seg);
      if (v !== null) return v;
      var plus = netValue(q, diff.plus, waveQ, seg);
      var minus = netValue(q, diff.minus, waveQ, seg);
      return plus === null || minus === null ? null : plus - minus;
    }
    if (row.kind === "net") return netValue(q, ri, waveQ, seg);
    return rowValue(waveQ, row.label, seg);
  };

  function baseOf(waveQ, seg) {
    if (seg) return (waveQ.bases || {})[seg] || null;
    return waveQ.base || null;
  }

  /* ---------- effective base for weighted wave-on-wave significance ----------
   * A weighted estimate carries the variance of its KISH effective base
   * n_eff = (Σw)²/Σw², not its raw respondent count. Sizing the wave z-test on
   * the raw base (as it did) over-states precision and over-flags movements on a
   * weighted tracker. These size it on n_eff, mirroring the crosstab weighted
   * z-test (22_model.js sigCell) and the R engine (weighting.R). Total path only:
   * segments and computed-totals waves have no per-respondent weights, so they
   * fall back to the plain base — and an unweighted study has n_eff === n, so
   * every path below is byte-identical there. */
  function effNfromWeights(w, n) {
    if (!w || !w.length) return n;
    var wsum = 0, sumW2 = 0;
    for (var i = 0; i < w.length; i++) { wsum += w[i]; sumW2 += w[i] * w[i]; }
    return sumW2 > 0 ? Math.round((wsum * wsum) / sumW2) : n;   // rounded, as R does
  }

  /** Effective base of a HISTORY wave point (Total only): the Kish n_eff when
   *  the wave carries per-respondent weights, else undefined so the point falls
   *  back to its plain base. */
  function effBaseOf(waveQ, seg) {
    if (seg || !waveQ || !waveQ.weights || !waveQ.weights.length) return undefined;
    return effNfromWeights(waveQ.weights, baseOf(waveQ, null));
  }

  /** The base significance is sized on: the effective base when a point carries
   *  one, else its plain base (so unweighted / segment points are unchanged). */
  function effBaseOfPoint(p) {
    return (p.effBase != null && p.effBase > 0) ? p.effBase : p.base;
  }

  /** (count, base) a proportion test runs on. Weighted report: the shown %
   *  carried on the effective base (x = %·n_eff over n_eff) — the weighted
   *  z-test form. Unweighted report: the exact integer count, byte-identical.
   *  Weightedness is the PROJECT flag, never inferred from n_eff === base: a
   *  constant (e.g. expansion) weight has n_eff exactly n while p.x is the
   *  weighted frequency, and pairing that x with the unweighted base feeds the
   *  test a proportion off by the weight factor. */
  function sigPair(p) {
    var eff = effBaseOfPoint(p);
    var weighted = !!(TR.AGG && TR.AGG.project && TR.AGG.project.weighted);
    if (!weighted && eff === p.base && p.x !== null && p.x !== undefined) {
      return { x: p.x, base: p.base };
    }
    return { x: p.value / 100 * eff, base: eff };
  }

  /* ---------- spread of mean-kind metrics (from published distributions) --- */

  /** Per-category respondent scores behind a mean-kind row: {ri: score}.
   *  Index rows use the configured index weights; NPS maps 9-10/7-8/0-6
   *  to +100/0/-100; plain means use the numeric category labels. */
  waves.scoreMap = function (q, row) {
    var label = TR.model.norm(row.label);
    var type = label.indexOf("nps") !== -1 ? "nps"
      : label === "mean" ? "mean" : "index";
    var map = {}, any = false;
    q.rows.forEach(function (r, ri) {
      if (r.kind !== "category") return;
      var score = null;
      if (type === "index") {
        var w = q.index_scores && q.index_scores[r.label];
        if (w !== undefined && w !== null) score = w;
      } else {
        var v = parseFloat(r.label);
        if (isFinite(v)) {
          score = type === "nps" ? (v >= 9 ? 100 : v >= 7 ? 0 : -100) : v;
        }
      }
      if (score !== null) { map[ri] = score; any = true; }
    });
    return any ? map : null;
  };

  function sdFromPairs(pairs) {
    var weight = 0, mean = 0;
    pairs.forEach(function (d) { weight += d.p; mean += d.p * d.s; });
    if (weight <= 0) return null;
    mean /= weight;
    var variance = 0;
    pairs.forEach(function (d) {
      variance += d.p * (d.s - mean) * (d.s - mean);
    });
    return Math.sqrt(variance / weight);
  }
  waves.sdFromPairs = sdFromPairs;

  /** SD of a mean-kind row in one HISTORY wave (per segment), derived
   *  exactly from that wave's published category distribution. */
  waves.sdAtWave = function (q, row, waveQ, seg) {
    if (!seg && waveQ.scores) return sdOfScores(waveQ.scores, waveQ.weights);  // microdata
    // Computed-totals history: a stored SD (Total waveQ.stats.sd or per-segment
    // seg_stats[seg].sd, supplied by the tracker) lets the Welch test run without
    // a published distribution. Absent (e.g. SACAP) -> fall back to the dist.
    var st = seg ? (waveQ.seg_stats || {})[seg] : waveQ.stats;
    if (st && st.sd !== undefined && st.sd !== null) return st.sd;
    var scores = waves.scoreMap(q, row);
    if (!scores) return null;
    var pairs = [];
    Object.keys(scores).forEach(function (ri) {
      var v = waves.valueAt(q, q.rows[ri], parseInt(ri, 10), waveQ, seg || null);
      if (v !== null && v !== undefined) pairs.push({ p: v, s: scores[ri] });
    });
    return sdFromPairs(pairs);
  };

  /** SD of a mean-kind row in the CURRENT wave from a view model's Total
   *  column (rows still aligned with q.rows — pre row-ops). */
  function sdFromModel(q, row, viewModel) {
    var scores = waves.scoreMap(q, row);
    if (!scores) return null;
    var pairs = [];
    Object.keys(scores).forEach(function (ri) {
      var cell = viewModel.rows[ri] && viewModel.rows[ri].cells[0];
      if (cell && cell.pct !== null && cell.pct !== undefined) {
        pairs.push({ p: cell.pct, s: scores[ri] });
      }
    });
    return sdFromPairs(pairs);
  }

  /**
   * Welch significance LEVEL between two mean points carrying sd + base:
   *   2 = significant at 95% · 1 = significant at 80% (not 95%) · 0 = neither.
   * Same low-base exclusion as the proportion path. The 80% band is the
   * report's optional dual-significance level (95% + 80%); callers decide
   * whether to surface it.
   */
  function meanLevel(a, b) {
    if (a.sd === null || a.sd === undefined ||
        b.sd === null || b.sd === undefined) return 0;
    if (!a.base || !b.base) return 0;
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var ea = effBaseOfPoint(a), eb = effBaseOfPoint(b);
    if (ea < threshold || eb < threshold) return 0;      // gate on the effective base
    var z = TR.stats.meanZ(a.value, a.sd, ea, b.value, b.sd, eb);
    if (z === null) return 0;
    var az = Math.abs(z);
    return az > TR.stats.zPrimary(1) ? 2 : az > TR.stats.zSecondary(1) ? 1 : 0;
  }
  /** Strong (95%) Welch test — unchanged semantics for non-dual callers. */
  function meanSigBetween(a, b) { return meanLevel(a, b) === 2; }

  /** Count for sig testing: published n (Total only), else pct-derived. */
  function countOf(waveQ, row, value, seg) {
    if (!seg) {
      var hit = waveQ.rows[TR.model.norm(row.label)];
      if (hit && hit.n !== undefined) return hit.n;
    }
    var base = baseOf(waveQ, seg);
    return base ? Math.round(value / 100 * base) : null;
  }

  /**
   * Pooled-z significance LEVEL between two series points (proportions):
   *   2 = significant at 95% · 1 = significant at 80% (not 95%) · 0 = neither.
   * Bases under the low-base threshold are excluded, mirroring the crosstab
   * convention (weighting.R).
   */
  function propLevel(a, b) {
    if (a.x === null || b.x === null || !a.base || !b.base) return 0;
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var ea = effBaseOfPoint(a), eb = effBaseOfPoint(b);
    if (ea < threshold || eb < threshold) return 0;      // gate on the effective base
    var pa = sigPair(a), pb = sigPair(b);                // % on n_eff (weighted) / exact count
    var z = TR.stats.propZ(pa.x, pa.base, pb.x, pb.base);
    if (z === null) return 0;
    var az = Math.abs(z);
    return az > TR.stats.zPrimary(1) ? 2 : az > TR.stats.zSecondary(1) ? 1 : 0;
  }
  /** Strong (95%) proportion test — unchanged semantics for non-dual callers. */
  function sigBetween(a, b) { return propLevel(a, b) === 2; }

  /**
   * Trend series for a model row, Total (seg null) or one segment:
   * [{wave, year, value, base, x}], oldest first, missing waves skipped.
   */
  waves.series = function (q, row, ri, seg) {
    var isMean = row.kind === "mean";
    // An SD row's "history" would be each wave's MEAN (valueAt resolves
    // mean-kind rows through stats.mean/index) — no published SD series
    // exists, so the row is untracked rather than trended against the mean.
    if (isMean && TR.model.isStdDevRow(row.label)) return [];
    var series = [];
    waves.history(q).forEach(function (h) {
      var value = waves.valueAt(q, row, ri, h.q, seg || null);
      if (value === null || value === undefined) return;
      series.push({ wave: h.wave, year: h.year, value: value,
        base: baseOf(h.q, seg || null),
        effBase: effBaseOf(h.q, seg || null),
        x: isMean || row.diff ? null : countOf(h.q, row, value, seg || null),
        sd: isMean && !row.diff
          ? waves.sdAtWave(q, row, h.q, seg || null) : undefined });
    });
    return series;
  };

  /**
   * Tracker-shaped cells: every point of a series (typically with the
   * current wave appended by the caller) annotated with change vs the
   * PREVIOUS point and vs the FIRST point, significance on both.
   * Proportions (canSig) use the pooled z; points carrying a
   * distribution-derived `sd` (means/indexes/NPS) use a Welch test;
   * NET POSITIVE (score difference) rows stay untested.
   *
   * `mode` is the report's significance setting (TR.d2.state.sigMode):
   *   "off"  → no flags (sig_prev/soft_prev all false)
   *   "95"   → sig_prev/sig_base = strong (95%) booleans; no soft
   *   "dual" → also soft_prev/soft_base: significant at 80% but NOT 95%
   * mode defaults to "on" when omitted, so a bare cellsFor(points, canSig)
   * keeps the strong-only behaviour (and 95%/single output is byte-identical).
   */
  waves.cellsFor = function (points, canSig, mode) {
    var on = mode !== "off";        // significance display master switch
    var dual = mode === "dual";     // also flag the 80% (soft) band
    var level = function (a, b) {
      if (canSig) return propLevel(a, b);
      if (a.sd !== undefined && a.sd !== null) return meanLevel(a, b);
      return 0;
    };
    // Could the test between two waves actually RUN — i.e. did both waves carry the
    // inputs it needs (bases >= the reporting threshold, a count for proportions, a
    // spread for means)? propLevel/meanLevel return 0 both when a test runs and finds
    // nothing AND when it can't run at all, so this separates "flat" from "untestable"
    // (e.g. historical waves loaded as bare aggregates with no base / distribution).
    var testable = function (a, b) {
      var threshold = TR.AGG.project.low_base_threshold || 30;
      if (!a.base || !b.base) return false;
      if (effBaseOfPoint(a) < threshold || effBaseOfPoint(b) < threshold) return false;
      return canSig
        ? (a.x !== null && a.x !== undefined && b.x !== null && b.x !== undefined)
        : (a.sd !== null && a.sd !== undefined && b.sd !== null && b.sd !== undefined);
    };
    return points.map(function (p, i) {
      var prev = i > 0 ? points[i - 1] : null;
      var first = i > 0 ? points[0] : null;
      var lp = prev ? level(p, prev) : 0;
      var lb = first ? level(p, first) : 0;
      return { wave: p.wave, year: p.year, value: p.value, base: p.base,
        x: p.x, sd: p.sd, current: !!p.current,
        change_prev: prev ? p.value - prev.value : null,
        sig_prev: on && lp === 2, soft_prev: dual && lp === 1,
        tested_prev: !!prev && testable(p, prev),   // inputs present for a wave-on-wave test
        change_base: first ? p.value - first.value : null,
        sig_base: on && lb === 2, soft_base: dual && lb === 1 };
    });
  };

  /**
   * Attach row.waves (Total trend series, oldest first), row.delta (vs the
   * latest matched wave) and row.deltaBase (vs the oldest matched wave,
   * when it differs) to a view model, plus prevWave / history metadata.
   */
  waves.attachDeltas = function (q, viewModel) {
    // Prior waves are published full-sample Totals (no microdata to filter), so
    // under an audience filter a wave delta compares filtered-now against
    // unfiltered-prior — misleading. Render the filtered view as untracked; the
    // filter bar explains the trend is hidden.
    if (viewModel.filtered) {
      viewModel.history = [];
      viewModel.prevWave = null;
      return viewModel;
    }
    var history = waves.history(q);
    viewModel.history = history.map(function (h) {
      return { wave: h.wave, year: h.year, base: h.base };
    });
    var latestWave = history[history.length - 1];
    viewModel.prevWave = latestWave
      ? { wave: latestWave.wave, year: latestWave.year, base: latestWave.base }
      : null;
    if (!history.length) return viewModel;
    var curBase = viewModel.columns[0].base || 0;

    viewModel.rows.forEach(function (row, ri) {
      var isMean = row.kind === "mean";
      if (isMean && TR.model.isStdDevRow(row.label)) return;   // untracked (no SD history)
      var series = waves.series(q, row, ri, null);
      if (!series.length) return;
      row.waves = series;

      var cur = isMean ? row.cells[0].mean : row.cells[0].pct;
      if (cur === null || cur === undefined) return;
      var canSig = !isMean && !row.diff;
      var curX = !canSig ? null
        : (row.cells[0].n !== null && row.cells[0].n !== undefined
          ? row.cells[0].n : Math.round(cur / 100 * curBase));
      var col0 = viewModel.columns[0];
      var curEff = (col0.baseEff != null && col0.baseEff > 0) ? col0.baseEff : curBase;
      var curPoint = { value: cur, base: curBase, x: curX, effBase: curEff,
        sd: isMean && !row.diff ? sdFromModel(q, row, viewModel) : undefined };
      var sigVs = function (point) {
        if (canSig) return sigBetween(curPoint, point);
        if (isMean && !row.diff) return meanSigBetween(curPoint, point);
        return false;
      };
      var latest = series[series.length - 1];
      row.delta = { prev: latest.value, wave: latest.wave, year: latest.year,
        diff: cur - latest.value, isMean: isMean, sig: sigVs(latest) };
      var first = series[0];
      if (first.year !== latest.year) {
        row.deltaBase = { prev: first.value, wave: first.wave, year: first.year,
          diff: cur - first.value, isMean: isMean, sig: sigVs(first) };
      }
    });
    return viewModel;
  };

})(typeof window !== "undefined" ? window : globalThis);
