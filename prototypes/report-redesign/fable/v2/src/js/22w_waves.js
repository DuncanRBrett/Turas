/**
 * v2 wave history — matches 2025 questions to the published Totals of every
 * prior wave (TR.PREV.waves, 2018-2024 and beyond: any number of waves) and
 * attaches per-row trend series plus deltas vs the previous wave AND vs the
 * baseline (oldest matched) wave to view models.
 *
 * Matching is by normalised title, occurrence-ordered for duplicate titles,
 * mirroring pipeline/extract_waves.py (which also applies the cross-wave
 * title aliases). History values are always published wave Totals — the
 * synthetic microdata never filters prior waves.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var waves = TR.waves = {};

  var waveIndexes = null;  // [{wave, year, index: {match_key: waveQ}}]
  var aggKeys = null;      // 2025 qcode -> occurrence-ordered match key

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

  /* ---------- per-row published values ---------- */

  function rowByLabel(waveQ, label) {
    var hit = waveQ.rows[TR.model.norm(label)];
    return hit && hit.pct !== undefined ? hit : null;
  }

  /** NET fallback for waves published without NET rows: sum the members. */
  function netFromMembers(q, ri, waveQ) {
    var members = q.net_members && q.net_members[String(ri)];
    if (!members) return null;
    var sum = 0;
    for (var i = 0; i < members.length; i++) {
      var hit = rowByLabel(waveQ, q.rows[members[i]].label);
      if (!hit) return null;
      sum += hit.pct;
    }
    return sum;
  }

  function netValue(q, ri, waveQ) {
    var hit = rowByLabel(waveQ, q.rows[ri].label);
    return hit ? hit.pct : netFromMembers(q, ri, waveQ);
  }

  /** Index mean recomputed from a wave's published distribution. */
  function indexFromDistribution(q, waveQ) {
    if (!q.index_scores) return null;
    var sum = 0, weight = 0;
    Object.keys(q.index_scores).forEach(function (label) {
      var hit = rowByLabel(waveQ, label);
      if (hit) { sum += q.index_scores[label] * hit.pct; weight += hit.pct; }
    });
    return weight > 0 ? sum / weight : null;
  }

  function meanValue(q, row, waveQ) {
    var stats = waveQ.stats || {};
    var label = TR.model.norm(row.label);
    if (label.indexOf("nps") !== -1) {
      return stats.nps !== undefined ? stats.nps : null;
    }
    if (label === "mean") {
      return stats.mean !== undefined ? stats.mean : null;
    }
    return stats.index !== undefined
      ? stats.index : indexFromDistribution(q, waveQ);
  }

  /**
   * Published value of view-model row ri in one wave question, or null.
   * ri indexes q.rows — attachDeltas runs before row ops reorder them.
   */
  waves.valueAt = function (q, row, ri, waveQ) {
    if (row.kind === "mean") return meanValue(q, row, waveQ);
    var diff = q.net_diffs && q.net_diffs[String(ri)];
    if (diff) {
      var hit = rowByLabel(waveQ, row.label);
      if (hit) return hit.pct;
      var plus = netValue(q, diff.plus, waveQ);
      var minus = netValue(q, diff.minus, waveQ);
      return plus === null || minus === null ? null : plus - minus;
    }
    if (row.kind === "net") return netValue(q, ri, waveQ);
    var cat = rowByLabel(waveQ, row.label);
    return cat ? cat.pct : null;
  };

  /** Count for sig testing: published n when present, else pct-derived. */
  function countOf(waveQ, row, value) {
    var hit = waveQ.rows[TR.model.norm(row.label)];
    if (hit && hit.n !== undefined) return hit.n;
    if (!waveQ.base) return null;
    return Math.round(value / 100 * waveQ.base);
  }

  /** Two-sided 95% z-test of current vs a wave point (proportions only). */
  function sigVs(curX, curBase, point) {
    if (point.x === null || !point.base || !curBase) return false;
    return TR.stats.propHigher(curX, curBase, point.x, point.base) ||
      TR.stats.propHigher(point.x, point.base, curX, curBase);
  }

  /**
   * Attach row.waves (trend series, oldest first), row.delta (vs the latest
   * matched wave) and row.deltaBase (vs the oldest matched wave, when it
   * differs) to a view model, plus viewModel.prevWave / viewModel.history.
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
      var series = [];
      history.forEach(function (h) {
        var value = waves.valueAt(q, row, ri, h.q);
        if (value === null || value === undefined) return;
        series.push({ wave: h.wave, year: h.year, value: value, base: h.base,
          x: isMean || row.diff ? null : countOf(h.q, row, value) });
      });
      if (!series.length) return;
      row.waves = series;

      var cur = isMean ? row.cells[0].mean : row.cells[0].pct;
      if (cur === null || cur === undefined) return;
      var canSig = !isMean && !row.diff;
      var curX = !canSig ? null
        : (row.cells[0].n !== null && row.cells[0].n !== undefined
          ? row.cells[0].n : Math.round(cur / 100 * curBase));
      var latest = series[series.length - 1];
      row.delta = { prev: latest.value, wave: latest.wave, year: latest.year,
        diff: cur - latest.value, isMean: isMean,
        sig: canSig ? sigVs(curX, curBase, latest) : false };
      var first = series[0];
      if (first.year !== latest.year) {
        row.deltaBase = { prev: first.value, wave: first.wave, year: first.year,
          diff: cur - first.value, isMean: isMean,
          sig: canSig ? sigVs(curX, curBase, first) : false };
      }
    });
    return viewModel;
  };

})(typeof window !== "undefined" ? window : globalThis);
