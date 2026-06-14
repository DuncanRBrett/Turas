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
    var seen = {};
    TR.AGG.questions.forEach(function (q) {
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

  /** Current-wave point {value, base, sd} recomputed from microdata (Total),
   *  or null. Treating the current wave exactly like history keeps the whole
   *  series internally consistent — full precision, no rounded summary. */
  waves.currentPoint = function (q) {
    var s = waves.currentScores(q);
    if (!s || !s.length) return null;
    return { value: meanOfScores(s), base: s.length, sd: sdOfScores(s) };
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

  /** Index mean recomputed from a wave's published distribution. */
  function indexFromDistribution(q, waveQ, seg) {
    if (!q.index_scores) return null;
    var sum = 0, weight = 0;
    Object.keys(q.index_scores).forEach(function (label) {
      var v = rowValue(waveQ, label, seg);
      if (v !== null) { sum += q.index_scores[label] * v; weight += v; }
    });
    return weight > 0 ? sum / weight : null;
  }

  /* ---------- microdata recompute (per-respondent scores) ----------
   * A wave question may carry `scores`: per-respondent metric values (the
   * rating for means; +100/0/-100 for NPS). When present, the headline value
   * and its SD are recomputed directly from them — the flexible model that
   * needs no published distribution and no pre-baked significance. Absent
   * (e.g. SACAP), every path below falls back to stats/distribution, so
   * existing reports are byte-for-byte unaffected. Total column only for now
   * (per-segment microdata recompute arrives with banner-aware waves). */
  function meanOfScores(s) {
    if (!s || !s.length) return null;
    var sum = 0;
    for (var i = 0; i < s.length; i++) sum += s[i];
    return sum / s.length;
  }
  function sdOfScores(s) {
    if (!s || s.length < 2) return null;
    var m = meanOfScores(s), v = 0;
    for (var i = 0; i < s.length; i++) { var d = s[i] - m; v += d * d; }
    return Math.sqrt(v / (s.length - 1));   // sample SD
  }
  waves.sdFromScores = sdOfScores;

  function meanValue(q, row, waveQ, seg) {
    if (!seg && waveQ.scores) return meanOfScores(waveQ.scores);   // microdata
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
    if (!seg && waveQ.scores) return sdOfScores(waveQ.scores);   // microdata
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

  /** Two-sided 95% Welch test between two mean points carrying sd + base.
   *  Same low-base exclusion as the proportion path. */
  function meanSigBetween(a, b) {
    if (a.sd === null || a.sd === undefined ||
        b.sd === null || b.sd === undefined) return false;
    if (!a.base || !b.base) return false;
    var threshold = TR.AGG.project.low_base_threshold || 30;
    if (a.base < threshold || b.base < threshold) return false;
    var z = TR.stats.meanZ(a.value, a.sd, a.base, b.value, b.sd, b.base);
    return z !== null && Math.abs(z) > 1.96;
  }

  /** Count for sig testing: published n (Total only), else pct-derived. */
  function countOf(waveQ, row, value, seg) {
    if (!seg) {
      var hit = waveQ.rows[TR.model.norm(row.label)];
      if (hit && hit.n !== undefined) return hit.n;
    }
    var base = baseOf(waveQ, seg);
    return base ? Math.round(value / 100 * base) : null;
  }

  /** Two-sided 95% z-test between two series points (proportions only).
   *  Bases under the low-base threshold are excluded, mirroring the
   *  crosstab convention (weighting.R). */
  function sigBetween(a, b) {
    if (a.x === null || b.x === null || !a.base || !b.base) return false;
    var threshold = TR.AGG.project.low_base_threshold || 30;
    if (a.base < threshold || b.base < threshold) return false;
    return TR.stats.propHigher(a.x, a.base, b.x, b.base) ||
      TR.stats.propHigher(b.x, b.base, a.x, a.base);
  }

  /**
   * Trend series for a model row, Total (seg null) or one segment:
   * [{wave, year, value, base, x}], oldest first, missing waves skipped.
   */
  waves.series = function (q, row, ri, seg) {
    var isMean = row.kind === "mean";
    var series = [];
    waves.history(q).forEach(function (h) {
      var value = waves.valueAt(q, row, ri, h.q, seg || null);
      if (value === null || value === undefined) return;
      series.push({ wave: h.wave, year: h.year, value: value,
        base: baseOf(h.q, seg || null),
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
   */
  waves.cellsFor = function (points, canSig) {
    var sig = function (a, b) {
      if (canSig) return sigBetween(a, b);
      if (a.sd !== undefined && a.sd !== null) return meanSigBetween(a, b);
      return false;
    };
    return points.map(function (p, i) {
      var prev = i > 0 ? points[i - 1] : null;
      var first = i > 0 ? points[0] : null;
      return { wave: p.wave, year: p.year, value: p.value, base: p.base,
        x: p.x, sd: p.sd, current: !!p.current,
        change_prev: prev ? p.value - prev.value : null,
        sig_prev: prev ? sig(p, prev) : false,
        change_base: first ? p.value - first.value : null,
        sig_base: first ? sig(p, first) : false };
    });
  };

  /**
   * Attach row.waves (Total trend series, oldest first), row.delta (vs the
   * latest matched wave) and row.deltaBase (vs the oldest matched wave,
   * when it differs) to a view model, plus prevWave / history metadata.
   */
  waves.attachDeltas = function (q, viewModel) {
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
      var series = waves.series(q, row, ri, null);
      if (!series.length) return;
      row.waves = series;

      var cur = isMean ? row.cells[0].mean : row.cells[0].pct;
      if (cur === null || cur === undefined) return;
      var canSig = !isMean && !row.diff;
      var curX = !canSig ? null
        : (row.cells[0].n !== null && row.cells[0].n !== undefined
          ? row.cells[0].n : Math.round(cur / 100 * curBase));
      var curPoint = { value: cur, base: curBase, x: curX,
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
