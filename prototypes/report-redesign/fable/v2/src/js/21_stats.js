/**
 * v2 stats engine — recomputes any table from the embedded respondent-level
 * microdata: filter masks, column memberships (built-in or custom banners),
 * weighted column %, NETs (sums, unions, differences), index means, and
 * two-proportion z-tests / Welch t-tests for significance letters.
 *
 * Everything here is pure given (TR.AGG, TR.MICRO); unit-tested in node
 * including a golden parity test against the published tables.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var stats = TR.stats = {};

  var Z_CRITICAL = 1.96;        // alpha = 0.05, two-sided
  var Z_80 = 1.2816;            // alpha = 0.20, two-sided (dual-sig option)
  var ANSWERED_UNSHOWN = -2;    // answered, category not displayed
  stats.Z95 = Z_CRITICAL;
  stats.Z80 = Z_80;

  /**
   * Per-respondent weight. Absent TR.MICRO.weights (e.g. unweighted projects
   * and the SACAP fixture) every respondent weighs 1 — so every weighted
   * accumulation below collapses to the unweighted count and the recompute is
   * byte-identical to the pre-weighting engine. When weights ARE present the
   * tabulations reproduce the published WEIGHTED figures (sum of weights), and
   * significance uses Kish's effective base n_eff = (Σw)² / Σw² to mirror the
   * production tabs test (weighting.R weighted_z_test_proportions).
   */
  function weightAt(r) {
    var w = TR.MICRO && TR.MICRO.weights;
    return w ? w[r] : 1;
  }

  /** Kish effective base from running Σw and Σw². 0 when no weight mass. */
  function effectiveBase(sumW, sumW2) {
    return sumW2 > 0 ? (sumW * sumW) / sumW2 : 0;
  }

  /** Respondent inclusion mask for a filter list. Returns Uint8Array. */
  stats.mask = function (filters) {
    var n = TR.MICRO.n;
    var mask = new Uint8Array(n);
    mask.fill(1);
    (filters || []).forEach(function (f) {
      var answers = TR.MICRO.answers[f.q];
      var banner = TR.MICRO.banner_vars[f.q];
      var wanted = {};
      f.rows.forEach(function (ri) { wanted[ri] = true; });
      for (var r = 0; r < n; r++) {
        if (!mask[r]) continue;
        var hit = false;
        if (answers) {
          var a = answers[r];
          if (Array.isArray(a)) {
            for (var j = 0; j < a.length; j++) {
              if (wanted[a[j]]) { hit = true; break; }
            }
          } else if (a !== null && a !== undefined && wanted[a]) {
            hit = true;
          }
        } else if (banner) {
          hit = !!wanted[banner[r]];
        }
        if (!hit) mask[r] = 0;
      }
    });
    return mask;
  };

  stats.maskCount = function (mask) {
    var c = 0;
    for (var i = 0; i < mask.length; i++) c += mask[i];
    return c;
  };

  /**
   * Column membership arrays for a banner selection.
   * @param {string} banner - banner group id ("Q002") or "custom:<qcode>".
   * @returns {{columns: [{label, letter, member: Uint8Array|null}], note}}
   *   member === null means "all respondents" (the Total column).
   */
  /** Membership array for a set of category row indexes of a question. */
  function memberArray(answers, n, rowIndexes) {
    var wanted = {};
    rowIndexes.forEach(function (ri) { wanted[ri] = true; });
    var member = new Uint8Array(n);
    for (var r = 0; r < n; r++) {
      var a = answers[r];
      if (Array.isArray(a)) {
        for (var j = 0; j < a.length; j++) {
          if (wanted[a[j]]) { member[r] = 1; break; }
        }
      } else if (a !== null && a !== undefined && wanted[a]) {
        member[r] = 1;
      }
    }
    return member;
  }

  stats.columnsFor = function (banner) {
    var n = TR.MICRO.n;
    var columns = [{ label: "Total", letter: "", member: null }];
    if (banner && banner.indexOf("custom:") === 0) {
      var bits = banner.split(":");
      var code = bits[1];
      var mode = bits[2] || "cat";
      var q = TR.d2.questionByCode(code);
      var answers = TR.MICRO.answers[code];
      var letterAt = 0;
      var defs = [];
      if (mode === "net") {
        // summary groupings: decomposable NETs become the columns
        // (e.g. Promoter / Passive / Detractor instead of 0–10)
        Object.keys(q.net_members || {}).map(Number).sort(function (a, b) {
          return a - b;
        }).forEach(function (ri) {
          defs.push({ label: q.rows[ri].label, members: q.net_members[String(ri)] });
        });
      }
      if (!defs.length) {
        TR.d2.catRows(q).forEach(function (cat) {
          defs.push({ label: cat.label, members: [cat.index] });
        });
      }
      defs.forEach(function (def) {
        columns.push({ label: def.label,
          letter: String.fromCharCode(65 + (letterAt++ % 26)),
          member: memberArray(answers, n, def.members) });
      });
      return { columns: columns, custom: true, source: q, mode: mode };
    }
    var groupCols = TR.d2.groupCols(banner);
    var vars = TR.MICRO.banner_vars[banner];
    groupCols.forEach(function (ci) {
      var member = new Uint8Array(n);
      for (var r = 0; r < n; r++) {
        if (vars[r] === ci) member[r] = 1;
      }
      columns.push({ label: TR.AGG.columns[ci].label,
        letter: TR.AGG.columns[ci].letter, member: member, colIndex: ci });
    });
    return { columns: columns, custom: false };
  };

  /**
   * Tabulate a question against columns under a mask.
   * Returns per column: base, counts per row, pct per row, mean per mean-row.
   */
  stats.tabulate = function (q, columns, mask) {
    var answers = TR.MICRO.answers[q.code];
    var catRows = TR.d2.catRows(q);
    var result = columns.map(function (col) {
      var counts = {}, base = 0, wbase = 0, sumW2 = 0;
      catRows.forEach(function (cat) { counts[cat.index] = 0; });
      for (var r = 0; r < mask.length; r++) {
        if (!mask[r]) continue;
        if (col.member && !col.member[r]) continue;
        var a = answers[r];
        if (a === null || a === undefined) continue;
        var w = weightAt(r);
        base++; wbase += w; sumW2 += w * w;
        if (Array.isArray(a)) {
          for (var j = 0; j < a.length; j++) {
            if (counts[a[j]] !== undefined) counts[a[j]] += w;
          }
        } else if (a !== ANSWERED_UNSHOWN && counts[a] !== undefined) {
          counts[a] += w;
        }
      }
      // base = unweighted respondent count (display + low-base, matches the
      // published unweighted base); wbase = Σw (the % denominator); effBase =
      // Kish n_eff (significance sizing). Unweighted: all three equal `base`.
      return { base: base, counts: counts, wbase: wbase,
        effBase: effectiveBase(wbase, sumW2) };
    });
    return result;
  };

  /** Percentage for a category row in a tabulated column (weighted base). */
  stats.pct = function (tab, rowIndex) {
    if (!tab.wbase) return null;
    return (tab.counts[rowIndex] || 0) / tab.wbase * 100;
  };

  /** NET value (sum of members for singles, union for multis), weighted. */
  stats.netCounts = function (q, members, columns, mask) {
    var answers = TR.MICRO.answers[q.code];
    var wanted = {};
    members.forEach(function (ri) { wanted[ri] = true; });
    return columns.map(function (col) {
      var hit = 0, base = 0, wbase = 0, sumW2 = 0;
      for (var r = 0; r < mask.length; r++) {
        if (!mask[r]) continue;
        if (col.member && !col.member[r]) continue;
        var a = answers[r];
        if (a === null || a === undefined) continue;
        var w = weightAt(r);
        base++; wbase += w; sumW2 += w * w;
        if (Array.isArray(a)) {
          for (var j = 0; j < a.length; j++) {
            if (wanted[a[j]]) { hit += w; break; }
          }
        } else if (wanted[a]) {
          hit += w;
        }
      }
      return { base: base, n: hit, wbase: wbase,
        effBase: effectiveBase(wbase, sumW2) };
    });
  };

  /**
   * Weighted count of respondents whose box-category membership equals a given
   * box row index, per column. Reads TR.MICRO.boxes[qcode] (one box row index
   * per respondent) so box-category NET rows recompute under a filter / custom
   * banner even when the underlying scale is hidden (only the boxes are shown).
   * Returns the same {base, n, wbase, effBase} shape as netCounts.
   */
  stats.boxCounts = function (qcode, boxRi, columns, mask) {
    var boxes = TR.MICRO.boxes[qcode];
    return columns.map(function (col) {
      var hit = 0, base = 0, wbase = 0, sumW2 = 0;
      for (var r = 0; r < mask.length; r++) {
        if (!mask[r]) continue;
        if (col.member && !col.member[r]) continue;
        var b = boxes[r];
        if (b === null || b === undefined) continue;
        var w = weightAt(r);
        base++; wbase += w; sumW2 += w * w;
        if (b === boxRi) hit += w;
      }
      return { base: base, n: hit, wbase: wbase,
        effBase: effectiveBase(wbase, sumW2) };
    });
  };

  /**
   * Weighted mean / sd / effective base for one column from a per-respondent
   * score function (null score = excluded). mean = Σws/Σw (the published
   * weighted mean, exact). The SD reduces to the prior unweighted (k-1) sample
   * variance when every weight is 1; weighted it is the population variance
   * scaled by effBase/(effBase-1), sized by the effective base — for sig / CI.
   */
  function weightedMeanColumn(scoreOf, mask, col) {
    var sum = 0, sumSq = 0, wbase = 0, sumW2 = 0;
    for (var r = 0; r < mask.length; r++) {
      if (!mask[r]) continue;
      if (col.member && !col.member[r]) continue;
      var s = scoreOf(r);
      if (s === null || s === undefined) continue;
      var w = weightAt(r);
      sum += w * s; sumSq += w * s * s; wbase += w; sumW2 += w * w;
    }
    if (!wbase) return { mean: null, sd: 0, k: 0 };
    var effBase = effectiveBase(wbase, sumW2);
    var mean = sum / wbase;
    var popVar = sumSq / wbase - mean * mean;
    var variance = effBase > 1 ? popVar * effBase / (effBase - 1) : 0;
    return { mean: mean, sd: Math.sqrt(Math.max(variance, 0)), k: effBase };
  }

  /**
   * Mean + sd per column for a scale/NPS question. Prefers a carried
   * per-respondent score array (TR.MICRO.scores[code]) — robust to hidden
   * categories (rating scales that publish only the mean) and to display-label
   * recodes, and the source the tabs microdata writer emits. Falls back to
   * mapping each respondent's category-row answer through q.index_scores (the
   * SACAP fixture / shown-category path). null when neither is available.
   */
  stats.indexMeans = function (q, columns, mask) {
    var scores = TR.MICRO.scores && TR.MICRO.scores[q.code];
    if (scores) {
      return columns.map(function (col) {
        return weightedMeanColumn(function (r) { return scores[r]; }, mask, col);
      });
    }
    var answers = TR.MICRO.answers[q.code];
    var scoreByRow = {};
    var any = false;
    TR.d2.catRows(q).forEach(function (cat) {
      var s = q.index_scores && q.index_scores[cat.label];
      if (s !== undefined && s !== null) { scoreByRow[cat.index] = s; any = true; }
    });
    if (!any) return null;
    return columns.map(function (col) {
      return weightedMeanColumn(function (r) {
        var a = answers[r];
        if (a === null || a === undefined || Array.isArray(a)) return null;
        var s = scoreByRow[a];
        return s === undefined ? null : s;
      }, mask, col);
    });
  };

  /* ---------- significance ---------- */

  /**
   * Two-proportion pooled z-test; true when p1 is significantly higher.
   * Mirrors the production tabs test (modules/tabs/lib/weighting.R):
   * pooled SE, alpha 0.05, and the normal-approximation precondition
   * n*p̂ >= 5 and n*(1-p̂) >= 5 in BOTH groups.
   */
  /** z statistic of p1 vs p2, or null when preconditions fail. */
  stats.propZ = function (x1, n1, x2, n2) {
    if (n1 < 1 || n2 < 1) return null;
    var pooled = (x1 + x2) / (n1 + n2);
    if (pooled === 0 || pooled === 1) return null;
    var minExpected = Math.min(n1 * pooled, n1 * (1 - pooled),
      n2 * pooled, n2 * (1 - pooled));
    if (minExpected < 5) return null;
    var se = Math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2));
    if (se === 0) return null;
    return (x1 / n1 - x2 / n2) / se;
  };

  stats.propHigher = function (x1, n1, x2, n2) {
    var z = stats.propZ(x1, n1, x2, n2);
    return z !== null && z > Z_CRITICAL;
  };

  /** Welch t statistic of mean1 vs mean2, or null when undefined. */
  stats.meanZ = function (m1, sd1, n1, m2, sd2, n2) {
    if (n1 < 2 || n2 < 2 || m1 === null || m2 === null) return null;
    var se = Math.sqrt(sd1 * sd1 / n1 + sd2 * sd2 / n2);
    if (se === 0) return null;
    return (m1 - m2) / se;
  };

  /** Welch t-test; true when mean1 is significantly higher. */
  stats.meanHigher = function (m1, sd1, n1, m2, sd2, n2) {
    var z = stats.meanZ(m1, sd1, n1, m2, sd2, n2);
    return z !== null && z > Z_CRITICAL;
  };

  /**
   * Sig letters for a value series across columns (index 0 = Total, never
   * tested). values = [{x, n}] for proportions or {mean, sd, k} for means.
   * Columns under the low-base threshold are excluded both ways.
   */
  /**
   * Sig letters per column. With dual=true the tabs dual-level convention
   * applies: UPPERCASE letters at 95% confidence, lowercase at 80%
   * (significant at 80% but not at 95%).
   */
  stats.sigLetters = function (cells, letters, lowBaseThreshold, isMean, dual) {
    var sizeOf = function (cell) { return isMean ? cell.k : cell.base; };
    return cells.map(function (cell, i) {
      if (i === 0) return "";
      var out = "";
      if (!sizeOf(cell) || sizeOf(cell) < lowBaseThreshold) return "";
      for (var j = 1; j < cells.length; j++) {
        if (j === i) continue;
        var other = cells[j];
        if (!sizeOf(other) || sizeOf(other) < lowBaseThreshold) continue;
        var z = isMean
          ? stats.meanZ(cell.mean, cell.sd, cell.k, other.mean, other.sd, other.k)
          : stats.propZ(cell.x, cell.base, other.x, other.base);
        if (z === null) continue;
        if (z > Z_CRITICAL) out += letters[j] || "";
        else if (dual && z > Z_80) out += (letters[j] || "").toLowerCase();
      }
      return out;
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
