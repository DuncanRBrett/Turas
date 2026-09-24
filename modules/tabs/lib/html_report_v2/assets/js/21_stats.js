/**
 * v2 stats engine. Recomputes any table from an embedded COMPUTED SOURCE:
 * filter masks, column memberships (built-in or custom banners), weighted
 * column %, NETs (sums, unions, differences), index means, and two-proportion
 * z-tests / Welch t-tests for significance letters.
 *
 * There are two computed sources and this file is the seam between them.
 * TR.MICRO carries one array position per respondent. TR.CUBE carries
 * precomputed sufficient statistics per (variable combination, question, cell)
 * and no respondents at all; its accumulation lives in 21b_cube.js. Every
 * function below that walks respondents delegates to the cube when a cube is
 * installed and a respondent island is not, and RETURNS THE SAME SHAPE either
 * way, so nothing above this seam has to know which source it is reading.
 *
 * Everything here is pure given (TR.AGG, TR.MICRO, TR.CUBE); unit-tested in
 * node including a golden parity test against the published tables and a
 * cube-versus-microdata comparison over an enumerated view set
 * (computed_parity_tests.mjs).
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var stats = TR.stats = {};

  var ANSWERED_UNSHOWN = -2;    // answered, category not displayed

  /** Is the aggregate cube the source? True only when a cube is installed and
   *  no respondent island is. A build carrying both keeps the records. */
  function onCube() { return !!(TR.cube && TR.cube.active()); }

  /** Which computed source is installed: "micro", "cube" or null. */
  stats.source = function () {
    if (TR.MICRO && TR.MICRO.answers) return "micro";
    if (onCube()) return "cube";
    return null;
  };

  /** Respondents in the study, from whichever source is installed. */
  stats.studyN = function () {
    if (TR.MICRO && TR.MICRO.n != null) return TR.MICRO.n;
    if (onCube()) return TR.CUBE.n;
    return null;
  };

  /** Why this cut cannot be served, or null. Only the cube ever refuses: the
   *  respondent island can compute every cut it is asked for. */
  stats.refusalFor = function (code, columns, mask) {
    return onCube() ? TR.cube.refusalFor(code, columns, mask) : null;
  };

  /** Inverse standard-normal CDF (Acklam's rational approximation, |ε|<1.2e-9). */
  function qnorm(p) {
    if (!(p > 0 && p < 1)) return NaN;
    var a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
      1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00];
    var b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
      6.680131188771972e+01, -1.328068155288572e+01];
    var c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
      -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00];
    var d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
      3.754408661907416e+00];
    var pl = 0.02425, q, r;
    if (p < pl) {
      q = Math.sqrt(-2 * Math.log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
    if (p <= 1 - pl) {
      q = p - 0.5; r = q * q;
      return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
        (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    }
    q = Math.sqrt(-2 * Math.log(1 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }

  /** Two-sided critical z for a significance level (zCrit(0.05) ≈ 1.96). */
  stats.zCrit = function (alpha) { return -qnorm(alpha / 2); };

  /** The project's configured primary / secondary (dual-sig) levels, with the
   *  conventional 0.05 / 0.20 defaults. The same defaults the R engine uses,
   *  so a report with no explicit config behaves exactly as before. */
  function projAlpha() {
    var p = TR.AGG && TR.AGG.project;
    var a = p && Number(p.alpha);
    return (a > 0 && a < 1) ? a : 0.05;
  }
  function projAlpha2() {
    var p = TR.AGG && TR.AGG.project;
    var a = p && Number(p.alpha_secondary);
    var lo = projAlpha();
    return (a > lo && a < 1) ? a : 0.20;
  }
  // The configured levels themselves. The reader layer words its plain-language
  // sentences from these ("the report's 95% level"), never a hard-coded 95/80.
  stats.alphaPrimary = projAlpha;
  stats.alphaSecondary = projAlpha2;
  /**
   * How a level is WORDED. Every user-visible "95%" / "80%" in the report. The
   * legends, the mode selectors, the tooltips and the authored prose's
   * {alpha_pct}/{alpha2_pct} tokens. Comes from here, so a project on
   * alpha_secondary = 0.1 reads "90%" everywhere instead of being told 80%
   * while the engine tests at 90 (defect 2026-08-30).
   *
   * Confidence INTERVALS are a separate, deliberately fixed 95% convention
   * (21c_confidence.js, Z95_EXACT): those strings are not level wording and
   * must not be routed through here.
   */
  stats.levelText = function (alpha) { return Math.round((1 - alpha) * 100) + "%"; };
  /** The same level as odds ("one in 20" at 0.05, "one in 5" at 0.20). The
   *  explainer says both, and interpolating only the percentage would leave it
   *  claiming "at 90% it is less than one in 5". */
  stats.levelOdds = function (alpha) { return String(Math.round(1 / alpha)); };
  stats.levelPrimary = function () { return stats.levelText(projAlpha()); };
  stats.levelSecondary = function () { return stats.levelText(projAlpha2()); };
  stats.oddsPrimary = function () { return stats.levelOdds(projAlpha()); };
  stats.oddsSecondary = function () { return stats.levelOdds(projAlpha2()); };
  /** The four level tokens every authored sentence about significance takes.
   *  One object so a call site cannot supply half of them and ship a literal
   *  "{alpha2_pct}" to the reader. */
  stats.levelVars = function () {
    return {
      alpha_pct: stats.levelPrimary(),
      alpha2_pct: stats.levelSecondary(),
      alpha_odds: stats.oddsPrimary(),
      alpha2_odds: stats.oddsSecondary()
    };
  };
  /**
   * Does this study HAVE a secondary level at all?
   *
   * Blank alpha_secondary switches dual significance off: the R engine then
   * emits no Sig.2 row and no sig2 letters. alpha_secondary in the island
   * always carries a number (it falls back to 0.20), so it cannot answer this,
   * the writer sends `dual_significance: false` instead, and only when the
   * feature is off, which keeps every island from a dual study byte-identical.
   * An older island has no flag and behaves exactly as it did before.
   *
   * Everything that offers, enters or computes the secondary level is gated on
   * this. Without it the report offered a "95% + 80%" option on a study that
   * switched the level off, and choosing it made 22_model.js recompute 80%
   * letters from the published counts. Letters the Excel crosstab does not
   * have (2026-08-31).
   */
  stats.hasSecondary = function () {
    var p = TR.AGG && TR.AGG.project;
    return !(p && p.dual_significance === false);
  };
  /** The report's live dual-significance state: the reader asked for it AND the
   *  study has a secondary level. The one place anything should ask. */
  stats.dualMode = function () {
    return stats.hasSecondary() && TR.d2 && TR.d2.state &&
      TR.d2.state.sigMode === "dual";
  };
  /** Bonferroni is the R engine's default; only an explicit false disables it. */
  stats.bonferroni = function () {
    var p = TR.AGG && TR.AGG.project;
    return !(p && p.bonferroni === false);
  };
  /** Critical z at the project's primary / secondary level over m comparisons
   *  (Bonferroni divisor, pass 1, or omit, for a single planned test). With
   *  the default config these reduce to the familiar 1.96 / 1.2816. */
  stats.zPrimary = function (m) { return stats.zCrit(projAlpha() / (m > 1 ? m : 1)); };
  stats.zSecondary = function (m) { return stats.zCrit(projAlpha2() / (m > 1 ? m : 1)); };
  // Fixed conventional constants, for 95% intervals and scale normalisation,
  // NOT for significance tests (those honour the configured alpha above).
  stats.Z95 = 1.96;
  stats.Z80 = 1.2816;

  /**
   * Per-respondent weight. Absent TR.MICRO.weights (e.g. unweighted projects
   * and the SACAP fixture) every respondent weighs 1, so every weighted
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

  /**
   * Is this a weighted report? The island carries a weight per respondent and
   * an unweighted project's are all 1 (microdata_writer.R), so "weighted" is
   * "some weight is not 1", not merely "weights exist". Cached: the vector
   * does not change within a page.
   */
  var weightedFlag = null;
  stats.isWeighted = function () {
    if (weightedFlag !== null) return weightedFlag;
    if (onCube()) {
      // The cube carries the verdict rather than the weights it was built from.
      weightedFlag = !!TR.CUBE.weighted;
      return weightedFlag;
    }
    var w = TR.MICRO && TR.MICRO.weights;
    weightedFlag = false;
    if (w) {
      for (var r = 0; r < w.length; r++) {
        if (w[r] !== 1) { weightedFlag = true; break; }
      }
    }
    return weightedFlag;
  };
  /** Forget the cached verdict. Only a harness that installs a second island
   *  into one engine needs this; a page installs exactly one. */
  stats._resetWeighted = function () { weightedFlag = null; };

  /** Kish effective base from running Σw and Σw². 0 when no weight mass. */
  function effectiveBase(sumW, sumW2) {
    return sumW2 > 0 ? (sumW * sumW) / sumW2 : 0;
  }

  /** Respondent inclusion mask for a filter list. Returns Uint8Array. */
  stats.mask = function (filters) {
    if (onCube()) return TR.cube.mask(filters);
    var n = TR.MICRO.n;
    var mask = new Uint8Array(n);
    mask.fill(1);
    (filters || []).forEach(function (f) {
      var answers = TR.MICRO.answers[f.q];
      var banner = TR.MICRO.banner_vars[f.q];
      var boxes = f.box && TR.MICRO.boxes ? TR.MICRO.boxes[f.q] : null;
      var wanted = {};
      f.rows.forEach(function (ri) { wanted[ri] = true; });
      for (var r = 0; r < n; r++) {
        if (!mask[r]) continue;
        var hit = false;
        if (boxes) {
          // hidden-scale box filter: match per-respondent box membership
          var b = boxes[r];
          hit = b !== null && b !== undefined && !!wanted[b];
        } else if (answers) {
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
    if (mask && mask.cube) return TR.cube.maskCount(mask);
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

  /** Membership array for a box-category row index, from per-respondent boxes.
   *  Box index equals the row index (mirrors stats.boxCounts / d2.boxRows). */
  function boxMemberArray(boxes, n, boxRi) {
    var member = new Uint8Array(n);
    for (var r = 0; r < n; r++) {
      if (boxes[r] === boxRi) member[r] = 1;
    }
    return member;
  }

  stats.columnsFor = function (banner) {
    if (onCube()) return TR.cube.columnsFor(banner);
    var n = TR.MICRO.n;
    var columns = [{ label: "Total", letter: "", member: null }];
    if (banner && banner.indexOf("composite:") === 0) {
      // Profile banner: one spotlight column per stored spec entry, each from a
      // (possibly different) question and each its own membership. The columns
      // may OVERLAP, so they carry NO letter. Composites are never pairwise
      // tested; significance is computed vs THE REST (model.applyComposite-
      // Significance). Unknown token (e.g. a shared hash whose spec never
      // travelled) shows Total only rather than crashing.
      var spec = TR.compositeBanners && TR.compositeBanners.get(banner);
      if (!spec || !spec.columns || !spec.columns.length) {
        return { columns: columns, composite: true, missing: !spec };
      }
      spec.columns.forEach(function (def) {
        var member;
        if (def.box != null && TR.MICRO.boxes && TR.MICRO.boxes[def.code]) {
          member = boxMemberArray(TR.MICRO.boxes[def.code], n, def.box);
        } else {
          member = memberArray(TR.MICRO.answers[def.code] || [], n, def.rows || []);
        }
        columns.push({ label: def.label, letter: "", member: member,
          composite: true });
      });
      return { columns: columns, composite: true, spec: spec };
    }
    if (banner && banner.indexOf("custom:") === 0) {
      var bits = banner.split(":");
      var code = bits[1];
      var mode = bits[2] || "cat";
      var q = TR.d2.questionByCode(code);
      // A saved custom banner (localStorage / shared #hash) can outlive its
      // question across a regen. Show Total only rather than crashing, the
      // same missing-spec behaviour the composite branch has above.
      if (!q) {
        return { columns: columns, custom: true, missing: true };
      }
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
        // hidden-scale questions publish only boxes (no shown categories to
        // decompose into): make each box NET row a column via box membership.
        if (!defs.length) {
          TR.d2.boxRows(q).forEach(function (br) {
            defs.push({ label: br.label, boxRi: br.index });
          });
        }
      }
      if (!defs.length) {
        TR.d2.catRows(q).forEach(function (cat) {
          defs.push({ label: cat.label, members: [cat.index] });
        });
      }
      var boxes = TR.MICRO.boxes && TR.MICRO.boxes[code];
      defs.forEach(function (def) {
        columns.push({ label: def.label,
          letter: String.fromCharCode(65 + (letterAt++ % 26)),
          member: def.boxRi !== undefined
            ? boxMemberArray(boxes, n, def.boxRi)
            : memberArray(answers, n, def.members) });
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
    if (onCube()) return TR.cube.tabulate(q, columns, mask);
    var answers = TR.MICRO.answers[q.code];
    var boxes = TR.MICRO.boxes && TR.MICRO.boxes[q.code];
    var catRows = TR.d2.catRows(q);
    var result = columns.map(function (col) {
      var counts = {}, base = 0, wbase = 0, sumW2 = 0;
      catRows.forEach(function (cat) { counts[cat.index] = 0; });
      for (var r = 0; r < mask.length; r++) {
        if (!mask[r]) continue;
        if (col.member && !col.member[r]) continue;
        var a = answers[r];
        var answered = a !== null && a !== undefined;
        // Hidden-scale box-only questions (CCS/CSAT style) carry no raw answer,
        // only the respondent's box membership records that they answered.
        // Fall back to it so the base / % denominator reflect the real
        // respondent universe (matching the box-category recompute) instead of
        // collapsing to 0. Shown scales have both (answer ⇒ box), so this is a
        // no-op there and the unweighted base stays byte-identical.
        if (!answered && boxes) {
          var b = boxes[r];
          answered = b !== null && b !== undefined;
        }
        if (!answered) continue;
        var w = weightAt(r);
        base++; wbase += w; sumW2 += w * w;
        if (a === null || a === undefined) continue;  // box-only: no row to tally
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
    if (onCube()) return TR.cube.netCounts(q, members, columns, mask);
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
    if (onCube()) return TR.cube.boxCounts(qcode, boxRi, columns, mask);
    var boxes = TR.MICRO.boxes[qcode];
    var answers = TR.MICRO.answers && TR.MICRO.answers[qcode];
    return columns.map(function (col) {
      var hit = 0, base = 0, wbase = 0, sumW2 = 0;
      for (var r = 0; r < mask.length; r++) {
        if (!mask[r]) continue;
        if (col.member && !col.member[r]) continue;
        var b = boxes[r];
        // The denominator is the FULL answered base. The published convention,
        // and the one restPct / the composite vs-the-rest test already use: an
        // answer that belongs to no box (e.g. Neutral under partial BoxCategory
        // coverage) still counts in the base, just never in the numerator. Box
        // presence stands in for "answered" only when the scale is hidden and
        // boxes are all the microdata carries.
        var a = answers ? answers[r] : undefined;
        if ((b === null || b === undefined) && (a === null || a === undefined)) continue;
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
   * scaled by effBase/(effBase-1), sized by the effective base, for sig / CI.
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
   * per-respondent score array (TR.MICRO.scores[code]): robust to hidden
   * categories (rating scales that publish only the mean) and to display-label
   * recodes, and the source the tabs microdata writer emits. Falls back to
   * mapping each respondent's category-row answer through q.index_scores (the
   * SACAP fixture / shown-category path). null when neither is available.
   */
  stats.indexMeans = function (q, columns, mask) {
    if (onCube()) return TR.cube.indexMeans(q, columns, mask);
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

  /**
   * Median per column, from the carried per-respondent scores. Its own
   * recompute, because a median is not a mean: before this, a filtered view
   * showed the recomputed MEAN in the Median row (VAS electricity: R563.68 in
   * a row whose true value for that audience was R300).
   *
   * Weighted runs return null. The R engine prints "N/A (weighted)" in this
   * row for the same reason, and a weighted median needs a definition nobody
   * has chosen here. null renders as no value, never as a wrong one.
   */
  stats.medians = function (q, columns, mask) {
    if (onCube()) return TR.cube.medians(q, columns, mask);
    var scores = TR.MICRO.scores && TR.MICRO.scores[q.code];
    if (!scores) return null;
    if (stats.isWeighted && stats.isWeighted()) {
      return columns.map(function () { return { mean: null, sd: 0, k: 0 }; });
    }
    return columns.map(function (col) {
      var vals = [];
      for (var r = 0; r < mask.length; r++) {
        if (!mask[r]) continue;
        if (col.member && !col.member[r]) continue;
        var s = scores[r];
        if (s === null || s === undefined) continue;
        vals.push(s);
      }
      if (!vals.length) return { mean: null, sd: 0, k: 0 };
      vals.sort(function (a, b) { return a - b; });
      var mid = vals.length >> 1;
      var med = vals.length % 2 ? vals[mid] : (vals[mid - 1] + vals[mid]) / 2;
      return { mean: med, sd: 0, k: vals.length };
    });
  };

  /**
   * Mean + sd + effective base per column for ONE ITEM of an Allocation
   * (constant-sum) question, from TR.MICRO.series[code][rowIndex].
   *
   * An Allocation publishes one mean row per item, so it needs k score series
   * under one question code and TR.MICRO.scores holds exactly one. The series
   * island carries them keyed by the item's zero-based position in the
   * question's rows[], which is the same `ri` the model iterates rows with.
   *
   * Returns the same {mean, sd, k} shape indexMeans returns, so each item row
   * is tested exactly like any other numeric mean. null when this row carries
   * no series, which the model renders as blank cells rather than as a
   * neighbouring item's number.
   */
  stats.seriesMeans = function (q, rowIndex, columns, mask) {
    if (onCube()) return TR.cube.seriesMeans(q, rowIndex, columns, mask);
    var all = TR.MICRO.series;
    if (!all || !Object.prototype.hasOwnProperty.call(all, q.code)) return null;
    var byRow = all[q.code];
    var key = String(rowIndex);
    // hasOwnProperty, not a truthiness test: a question code or a row key of
    // "constructor" would otherwise read back the inherited function (M11).
    if (!byRow || !Object.prototype.hasOwnProperty.call(byRow, key)) return null;
    var series = byRow[key];
    if (!series) return null;
    return columns.map(function (col) {
      return weightedMeanColumn(function (r) { return series[r]; }, mask, col);
    });
  };

  /**
   * Ratio of totals per column: Σw·numerator / Σw·denominator, over everyone in
   * the audience holding both, with a denominator above zero. This is the
   * average of the UNITS (the average transaction), not of the people (the
   * average person's transaction): different numbers off the same respondents,
   * and the row exists precisely to show both.
   *
   * Mirrors calculate_ratio_of_totals() in numeric_processor.R exactly, so the
   * unfiltered recompute reproduces the published figure.
   */
  stats.ratioOfTotals = function (ratio, columns, mask, qcode) {
    if (onCube()) return TR.cube.ratioOfTotals(ratio, columns, mask, qcode);
    var scores = TR.MICRO.scores || {};
    var num = ratio && scores[ratio.num], den = ratio && scores[ratio.den];
    if (!num || !den) return null;
    return columns.map(function (col) {
      var top = 0, bottom = 0, k = 0;
      for (var r = 0; r < mask.length; r++) {
        if (!mask[r]) continue;
        if (col.member && !col.member[r]) continue;
        var a = num[r], b = den[r];
        if (a === null || a === undefined || b === null || b === undefined || !(b > 0)) continue;
        var w = weightAt(r);
        top += w * a; bottom += w * b; k++;
      }
      return { mean: bottom > 0 ? top / bottom : null, sd: 0, k: k };
    });
  };

  /**
   * Mean +-100 NET POSITIVE score per column: +100 in the favourable box, -100
   * in the unfavourable box, 0 for any other response in the base. That mean IS
   * the printed net (top% - bottom%), so a NET POSITIVE row's letters test the
   * number the row shows. The device the NPS Score row already uses, and the
   * one the R engine adopted for this row (review 2026-08, I5; decision in
   * docs/tabs_production_review_2026-08/NET_POSITIVE_SIG_DECISION.md).
   *
   * Testing the printed difference is not a two-independent-proportions z-test:
   * the two boxes are cells of one multinomial and are negatively correlated.
   * The score carries that covariance itself, for X in {+1,0,-1} with
   * P(+1)=t, P(-1)=b, Var(X) = t + b - (t-b)^2, exactly Var(p_top - p_bottom)*n.
   *
   * Base rule mirrors boxCounts(): an answer belonging to no box still counts
   * in the base (and scores 0), so the mean shares the printed row's
   * denominator. Returns the {mean, sd, k} shape sigLetters(isMean) expects.
   */
  stats.netScoreMeans = function (qcode, plusRi, minusRi, columns, mask) {
    if (onCube()) return TR.cube.netScoreMeans(qcode, plusRi, minusRi, columns, mask);
    var boxes = TR.MICRO.boxes[qcode];
    var answers = TR.MICRO.answers && TR.MICRO.answers[qcode];
    return columns.map(function (col) {
      return weightedMeanColumn(function (r) {
        var b = boxes[r];
        var a = answers ? answers[r] : undefined;
        if ((b === null || b === undefined) && (a === null || a === undefined)) return null;
        if (b === plusRi) return 100;
        if (b === minusRi) return -100;
        return 0;
      }, mask, col);
    });
  };

  /**
   * "The rest", everyone in the audience except this column, as a column spec.
   * Nothing outside this file may build one: on the respondent island it is a
   * complement membership array, on the cube it is an exact subtraction, and
   * the two callers that used to build the array themselves would have had to
   * learn both.
   */
  stats.restOf = function (col) {
    if (onCube()) return TR.cube.restOf(col);
    var n = TR.MICRO.n;
    if (!col || !col.member) return { member: null };
    var rest = new Uint8Array(n);
    for (var r = 0; r < n; r++) rest[r] = col.member[r] ? 0 : 1;
    return { member: rest };
  };

  /**
   * Everyone in ANY column of a banner group. NOT the same as Total: a
   * respondent in no column of the group is excluded. That is the arm the
   * Executive Takeout's cell family compares each group against, so its overall
   * mean is the sum of the group's columns rather than the whole sample.
   */
  stats.groupColumn = function (bannerId) {
    if (onCube()) return TR.cube.groupColumn(bannerId);
    var vars = TR.MICRO && TR.MICRO.banner_vars && TR.MICRO.banner_vars[bannerId];
    if (!vars) return null;
    var member = new Uint8Array(TR.MICRO.n);
    for (var r = 0; r < member.length; r++) {
      var cd = vars[r];
      if (cd !== null && cd !== undefined && cd >= 0) member[r] = 1;
    }
    return { label: "All", letter: "", member: member };
  };

  /**
   * {n, sw, sw2, swx, swx2} for one column's per-respondent scores. The Welch
   * test in 27da only ever used these moments of its two arrays, so this is the
   * whole of what the cell family needs and the only shape the cube can serve.
   */
  stats.momentsOf = function (qcode, col, mask) {
    if (onCube()) return TR.cube.momentsOf(qcode, col, mask);
    var scores = TR.MICRO.scores && TR.MICRO.scores[qcode];
    if (!scores) return { n: 0, sw: 0, sw2: 0, swx: 0, swx2: 0 };
    return momentsFromVector(scores, col, mask);
  };

  /** The same moments for a KeyShare row's 0/100 encoding. */
  stats.shareMomentsOf = function (q, ri, col, mask) {
    if (onCube()) return TR.cube.shareMomentsOf(q, ri, col, mask);
    var vec = TR.takeout && TR.takeout._shares
      ? TR.takeout._shares.scoreVector({ q: q, ri: ri }, TR.MICRO, TR.MICRO.n) : null;
    if (!vec) return { n: 0, sw: 0, sw2: 0, swx: 0, swx2: 0 };
    return momentsFromVector(vec, col, mask);
  };

  function momentsFromVector(vec, col, mask) {
    var n = TR.MICRO.n, cnt = 0, sw = 0, sw2 = 0, swx = 0, swx2 = 0;
    for (var r = 0; r < n; r++) {
      if (mask && !mask[r]) continue;
      if (col && col.member && !col.member[r]) continue;
      var v = vec[r];
      if (v === null || v === undefined) continue;
      var w = weightAt(r);
      cnt++; sw += w; sw2 += w * w; swx += w * v; swx2 += w * v * v;
    }
    return { n: cnt, sw: sw, sw2: sw2, swx: swx, swx2: swx2 };
  }

  /**
   * {n, sw, sw2} for the live audience: everyone matching the filters, with no
   * question condition. What the filter bar, the disclosure gate and the
   * Reader's audience strip count. null when no computed source is installed.
   */
  stats.audienceMoments = function (mask) {
    if (onCube()) return TR.cube.audienceMoments(mask, null);
    if (!TR.MICRO) return null;
    var n = TR.MICRO.n, cnt = 0, sw = 0, sw2 = 0;
    for (var r = 0; r < n; r++) {
      if (mask && !mask[r]) continue;
      var w = weightAt(r);
      cnt++; sw += w; sw2 += w * w;
    }
    return { n: cnt, sw: sw, sw2: sw2 };
  };

  /** Does this question carry a per-respondent score in the installed source? */
  stats.hasScores = function (qcode) {
    if (onCube()) return TR.cube.has(qcode, "scores");
    return !!(TR.MICRO && TR.MICRO.scores && TR.MICRO.scores[qcode]);
  };

  /**
   * The observed range of a question's per-respondent scores over the FULL
   * unfiltered sample, or null when the source carries no score for it. The
   * Differences scan uses it as the denominator that scales a mean gap into a
   * comparable finding score.
   */
  stats.scoreRange = function (qcode) {
    if (onCube()) {
      var f = TR.cube.questionFacts(qcode);
      if (!f || f.score_lo === undefined || f.score_lo === null) return null;
      return { lo: f.score_lo, hi: f.score_hi };
    }
    var sc = TR.MICRO && TR.MICRO.scores && TR.MICRO.scores[qcode];
    if (!sc) return null;
    var lo = 0, hi = 0, any = false;
    for (var i = 0; i < sc.length; i++) {
      var v = sc[i];
      if (v === null || v === undefined) continue;
      if (!any) { lo = hi = v; any = true; }
      else { lo = Math.min(lo, v); hi = Math.max(hi, v); }
    }
    return any ? { lo: lo, hi: hi } : null;
  };

  /**
   * The robust scoring range WIDTH: p5 to p95 on an unbounded observed scale,
   * the full range on a designed one. A fact about the full unfiltered vector,
   * so the cube states it and the respondent island computes it, by the same
   * rule (robustRange in 27d_diffs.js, cube_robust_range in cube_writer.R).
   */
  stats.robustRange = function (qcode, fullRange) {
    if (onCube()) {
      var f = TR.cube.questionFacts(qcode);
      return (f && f.robust_range) ? f.robust_range : null;
    }
    var sc = TR.MICRO && TR.MICRO.scores && TR.MICRO.scores[qcode];
    if (!sc) return null;
    var vals = [];
    for (var i = 0; i < sc.length; i++) {
      if (sc[i] === null || sc[i] === undefined) continue;
      vals.push(sc[i]);
    }
    return TR.views && TR.views._robustRange
      ? TR.views._robustRange(vals, fullRange) : null;
  };

  /** Does it carry box-category membership? Decides whether a NET row
   *  recomputes from boxes or from its declared members. */
  stats.hasBoxes = function (qcode) {
    if (onCube()) return TR.cube.has(qcode, "boxes");
    return !!(TR.MICRO && TR.MICRO.boxes && TR.MICRO.boxes[qcode]);
  };

  /** Does it carry raw category answers? */
  stats.hasAnswers = function (qcode) {
    if (onCube()) return TR.cube.has(qcode, "answers");
    var a = TR.MICRO && TR.MICRO.answers && TR.MICRO.answers[qcode];
    if (!a) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] !== null && a[i] !== undefined) return true;
    }
    return false;
  };

  /** The precomputed full-sample score histogram, or null when the source has
   *  none and the caller has to bin the vector itself. */
  stats.scoreHistogram = function (qcode) {
    if (!onCube()) return null;
    var f = TR.cube.questionFacts(qcode);
    return (f && f.histogram) ? f.histogram : null;
  };

  /** Componentwise a minus b on two moment records. The arm a group is
   *  compared against is always "this set minus that set". */
  stats.subtractMoments = function (a, b) {
    return { n: a.n - b.n, sw: a.sw - b.sw, sw2: a.sw2 - b.sw2,
      swx: a.swx - b.swx, swx2: a.swx2 - b.swx2 };
  };

  /** Does it carry an Allocation item series? */
  stats.hasSeries = function (qcode) {
    if (onCube()) return TR.cube.has(qcode, "series");
    return !!(TR.MICRO && TR.MICRO.series && TR.MICRO.series[qcode]);
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
    return z !== null && z > stats.zPrimary(1);
  };

  // --- Student-t tail (moved from 27da_takeout_stats.js, 24 Sep 2026) --------
  /** Natural log of the gamma function (Lanczos g=7), for exact binomial terms
   *  and the incomplete-beta used by the Student-t tail. */
  function logGamma(x) {
    var c = [0.99999999999980993, 676.5203681218851, -1259.1392167224028,
      771.32342877765313, -176.61502916214059, 12.507343278686905,
      -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7];
    var g = 7;
    if (x < 0.5) return Math.log(Math.PI / Math.sin(Math.PI * x)) - logGamma(1 - x);
    x -= 1;
    var a = c[0], tt = x + g + 0.5;
    for (var i = 1; i < g + 2; i++) a += c[i] / (x + i);
    return 0.5 * Math.log(2 * Math.PI) + (x + 0.5) * Math.log(tt) - tt + Math.log(a);
  }
  stats._logGamma = logGamma;

  /** Regularised incomplete beta I_x(a,b) via the Lentz continued fraction
   *  (Numerical Recipes betacf). Underpins the Student-t tail. */
  function betacf(a, b, x) {
    var qab = a + b, qap = a + 1, qam = a - 1, c = 1, d = 1 - qab * x / qap;
    if (Math.abs(d) < 1e-30) d = 1e-30;
    d = 1 / d; var h = d;
    for (var m = 1; m <= 200; m++) {
      var m2 = 2 * m, aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1 + aa * d; if (Math.abs(d) < 1e-30) d = 1e-30;
      c = 1 + aa / c; if (Math.abs(c) < 1e-30) c = 1e-30;
      d = 1 / d; h *= d * c;
      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1 + aa * d; if (Math.abs(d) < 1e-30) d = 1e-30;
      c = 1 + aa / c; if (Math.abs(c) < 1e-30) c = 1e-30;
      d = 1 / d; var del = d * c; h *= del;
      if (Math.abs(del - 1) < 1e-12) break;
    }
    return h;
  }
  function ibeta(x, a, b) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    var lbeta = logGamma(a + b) - logGamma(a) - logGamma(b);
    var front = Math.exp(lbeta + a * Math.log(x) + b * Math.log(1 - x));
    return x < (a + 1) / (a + b + 2) ? front * betacf(a, b, x) / a
      : 1 - front * betacf(b, a, 1 - x) / b;
  }

  /** Two-sided Student-t tail P(|T_df| >= |t|). A degenerate SE (non-finite t)
   *  must read as p=1, never p=0; df<=0 likewise. The t-tail (not just the
   *  variance floor) is load-bearing: it demotes tiny-base cells whose normal-
   *  approx p would otherwise survive multiplicity correction. */
  function studentT(t, df) {
    if (!isFinite(t)) return 1;
    if (df <= 0) return 1;
    var tc = Math.min(1e6, Math.abs(t));
    return ibeta(df / (df + tc * tc), df / 2, 0.5);
  }
  stats.studentT = studentT;

  /**
   * Welch's two-sample t-test from summary statistics: each side keeps its own
   * variance, sized on its (effective) base, with Welch-Satterthwaite degrees
   * of freedom. The test R runs (weighting.R calculate_t_test_stats) and the
   * tracker runs (statistical_core.R t_test_for_means). Returns {t, df, p}
   * with p two-sided, or null when the test is undefined.
   */
  stats.welch = function (m1, sd1, n1, m2, sd2, n2) {
    if (n1 < 2 || n2 < 2 || m1 === null || m2 === null) return null;
    var v1 = sd1 * sd1 / n1, v2 = sd2 * sd2 / n2;
    var se = Math.sqrt(v1 + v2);
    if (!(se > 0)) return null;
    var t = (m1 - m2) / se;
    var df = (v1 + v2) * (v1 + v2) / (v1 * v1 / (n1 - 1) + v2 * v2 / (n2 - 1));
    if (!(df > 0)) return null;
    return { t: t, df: df, p: studentT(t, df) };
  };

  /**
   * The Welch t of mean1 vs mean2 as its NORMAL EQUIVALENT: the z with the same
   * two-sided p-value, signed like the difference. Every caller compares |z|
   * with zCrit(alpha), which is then exactly "Welch p < alpha". It used to
   * return the raw Welch statistic, which those callers judged against the
   * normal curve: a pair at t = 1.98 on 60 df (p = 0.052) was lettered at 95%
   * (review 24 Sep 2026). null when the test is undefined.
   */
  stats.meanZ = function (m1, sd1, n1, m2, sd2, n2) {
    var w = stats.welch(m1, sd1, n1, m2, sd2, n2);
    if (!w) return null;
    // Past double precision the tail underflows to 0; the raw t is then the
    // better (finite, larger) evidence figure and every threshold is passed.
    if (!(w.p > 1e-300)) return w.t;
    var z = w.p >= 1 ? 0 : -qnorm(w.p / 2);
    return w.t < 0 ? -z : z;
  };

  /** Welch t-test; true when mean1 is significantly higher at the primary level. */
  stats.meanHigher = function (m1, sd1, n1, m2, sd2, n2) {
    var z = stats.meanZ(m1, sd1, n1, m2, sd2, n2);
    return z !== null && z > stats.zPrimary(1);
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
    // Bonferroni divisor mirrors R (run_crosstabs.R run_significance_tests_for_row):
    // choose(k, 2) over ALL the group's non-Total columns. Low-base columns still
    // count in the divisor even though their own tests are skipped.
    var k = cells.length - 1;
    var m = stats.bonferroni() ? k * (k - 1) / 2 : 1;
    var zHi = stats.zPrimary(m);
    var zLo = stats.zSecondary(m);
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
        if (z > zHi) out += letters[j] || "";
        else if (dual && z > zLo) out += (letters[j] || "").toLowerCase();
      }
      return out;
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
