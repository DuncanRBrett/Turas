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
      return { wave: w.wave, year: w.year, index: index };
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
      var hit = w.index[aggKeys[q.code]];
      if (hit) out.push({ wave: w.wave, year: w.year, base: hit.base, q: hit });
    });
    return out;
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

  function meanValue(q, row, waveQ, seg) {
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
        x: isMean || row.diff ? null : countOf(h.q, row, value, seg || null) });
    });
    return series;
  };

  /**
   * Tracker-shaped cells: every point of a series (typically with the
   * current wave appended by the caller) annotated with change vs the
   * PREVIOUS point and vs the FIRST point, pooled-z sig on both.
   * canSig is false for means/indexes and NET POSITIVE (score) rows.
   */
  waves.cellsFor = function (points, canSig) {
    return points.map(function (p, i) {
      var prev = i > 0 ? points[i - 1] : null;
      var first = i > 0 ? points[0] : null;
      return { wave: p.wave, year: p.year, value: p.value, base: p.base,
        x: p.x, current: !!p.current,
        change_prev: prev ? p.value - prev.value : null,
        sig_prev: prev && canSig ? sigBetween(p, prev) : false,
        change_base: first ? p.value - first.value : null,
        sig_base: first && canSig ? sigBetween(p, first) : false };
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
      var curPoint = { value: cur, base: curBase, x: curX };
      var latest = series[series.length - 1];
      row.delta = { prev: latest.value, wave: latest.wave, year: latest.year,
        diff: cur - latest.value, isMean: isMean,
        sig: canSig ? sigBetween(curPoint, latest) : false };
      var first = series[0];
      if (first.year !== latest.year) {
        row.deltaBase = { prev: first.value, wave: first.wave, year: first.year,
          diff: cur - first.value, isMean: isMean,
          sig: canSig ? sigBetween(curPoint, first) : false };
      }
    });
    return viewModel;
  };

})(typeof window !== "undefined" ? window : globalThis);
