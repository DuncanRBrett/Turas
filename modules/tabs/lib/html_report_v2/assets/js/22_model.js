/**
 * v2 view model — ONE interface the whole UI renders from. For the default
 * view (built-in banner, no filter) it returns the PUBLISHED numbers
 * verbatim; with a filter or custom banner it recomputes everything from
 * microdata and marks the model "computed". Wave history (trend series +
 * deltas vs previous and baseline waves) attaches via TR.waves.
 *
 * SIZE-EXCEPTION: a single coherent assembly flow over published/computed/
 * prior-wave sources; splitting it would scatter the model contract.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var model = TR.model = {};

  function lowThreshold() {
    return TR.AGG.project.low_base_threshold || 30;
  }

  /** A standard-deviation summary row (reports spread, not the mean).
   *  Kept for callers that only have a label; the vocabulary itself lives in
   *  TR.fmt, because the waves engine and Differences need it too. */
  function isStdDevRow(label) {
    return TR.fmt.SPREAD_LABEL.test(String(label || ""));
  }
  model.isStdDevRow = isStdDevRow;
  model.meanStat = function (row) { return TR.fmt.meanStat(row); };
  model.isHeadlineMean = function (row) { return TR.fmt.isHeadlineMean(row); };

  /**
   * One value per column for a mean-kind row, by which statistic it reports.
   *
   * `means` is the recomputed mean/sd/effective-base per column, so "mean" and
   * "sd" read straight off it. A median and a ratio of totals are separate
   * recomputes; when either cannot be computed for this audience the row goes
   * BLANK rather than falling back to the mean, because a plausible wrong
   * number in a labelled row is the failure this whole path is fixing.
   * A mode is not recomputed at all — no recompute exists for it.
   */
  function statValues(stat, q, row, means, columns, mask) {
    var blank = columns.map(function () { return null; });
    if (stat === "sd") return means.map(function (m) { return m.sd; });
    if (stat === "median") {
      var med = TR.stats.medians(q, columns, mask);
      return med ? med.map(function (m) { return m.mean; }) : blank;
    }
    if (stat === "ratio") {
      var rat = q.ratio ? TR.stats.ratioOfTotals(q.ratio, columns, mask) : null;
      return rat ? rat.map(function (m) { return m.mean; }) : blank;
    }
    if (stat === "mode" || stat === "chi") return blank;
    return means.map(function (m) { return m.mean; });
  }
  model._statValues = statValues;

  // What a question's (or one row's) `pct` values ACTUALLY are — the vocabulary
  // lives in TR.fmt (review 2026-08, C1) because every display and scan layer
  // needs it, not just the model.
  var COL_PCT = TR.fmt.COL_PCT;
  function statOf(q) { return TR.fmt.statOf(null, q); }

  /** Normalise a label/title for cross-wave matching (mirrors pipeline). */
  model.norm = function (text) {
    return String(text || "").toLowerCase().replace(/\s+/g, " ")
      .replace(/[^a-z0-9 ]/g, "").trim();
  };

  /**
   * Build a proportion significance cell {x, base} from a published count + column base.
   * Weighted designs: the published count is WEIGHTED but the base row is UNWEIGHTED, so
   * form the proportion on the weighted base and carry the variance on the Kish EFFECTIVE
   * base — passed as x = p*effN over base = effN, which is exactly the weighted z-test the
   * R engine runs (p from weighted counts, SE ~ p(1-p)/effN). Unweighted designs pass the
   * exact counts through unchanged, so those reports are byte-identical.
   */
  function sigCell(count, base) {
    var x = count || 0;
    if (base && base.nWeighted > 0 && base.nEff > 0) {
      var p = x / base.nWeighted;
      return { x: p * base.nEff, base: base.nEff };
    }
    return { x: x, base: base ? base.n : 0 };
  }

  /** Published view: columns restricted to Total + the chosen banner group.
   *  With dual=true, 80%-level lowercase letters are carried from R's Sig.2 row
   *  (sig2 minus sig) and appended to the published 95% letters; islands built
   *  before sig2 carriage fall back to recomputing them from published counts. */
  function publishedModel(q, bannerId, dual) {
    var cols = [0].concat(TR.d2.groupCols(bannerId));
    var threshold = lowThreshold();
    var columns = cols.map(function (ci) {
      var base = q.bases[ci] ? q.bases[ci].n : null;
      var entry = {
        label: TR.AGG.columns[ci].label,
        letter: ci === 0 ? "" : TR.AGG.columns[ci].letter,
        base: base,
        // Weighted designs also carry the weighted base + Kish effective base so
        // the renderer can show them (null on unweighted -> no extra rows).
        baseW: q.bases[ci] ? (q.bases[ci].nWeighted != null ? q.bases[ci].nWeighted : null) : null,
        baseEff: q.bases[ci] ? (q.bases[ci].nEff != null ? q.bases[ci].nEff : null) : null,
        low: q.bases[ci] ? !!q.bases[ci].low : false
      };
      // Finite population correction: when a universe N is known for the column,
      // carry it so intervals narrow (attachIntervals reads ciBase) and the
      // low-base flag becomes coverage-aware. Omitted entirely otherwise, so a
      // report with no population is byte-identical. (The published path keeps
      // R's significance letters; FPC reaches significance via the computed
      // path, which model.forQuestion routes population reports through.)
      var N = TR.AGG.columns[ci].population;
      if (N > 1 && base != null) {
        entry.population = N;
        entry.coverage = TR.conf.coverage(base, N);
        // fpcBase's nEff argument is the Kish effective base on weighted designs
        // (its own contract) — the sampling fraction still uses the raw count.
        entry.ciBase = TR.conf.fpcBase(entry.baseEff != null ? entry.baseEff : base, base, N);
        entry.low = entry.ciBase < threshold;
      }
      return entry;
    });
    var letters = columns.map(function (c) { return c.letter; });
    var rows = q.rows.map(function (r, qri) {
      var low80 = null;
      // 80% letters are CARRIED from R's Sig.2 row, like the 95% letters above them.
      // Excel's Sig.2 is a superset (every 95% letter is also an 80% letter), so the
      // lowercase set is sig2 minus sig. Recomputing them here instead used the
      // published Frequency row, which format_output_value rounds to 0dp — enough to
      // flip a marginal p~=0.20 call, so the workbook and the report disagreed on the
      // same pair. Mean rows carry sig2 too, so they get their 80% letters here for
      // the first time.
      if (dual && r.sig2) {
        low80 = cols.map(function (ci) {
          var hi = String(r.sig[ci] || "");
          return String(r.sig2[ci] || "").split("").filter(function (ch) {
            return ch !== "-" && hi.indexOf(ch) === -1;
          }).join("").toLowerCase();
        });
      } else if (dual && (r.kind === "category" || r.kind === "net")) {
        // Fallback for islands built before sig2 carriage (no sig2 key): recompute
        // from the published counts for proportion rows — categories AND NET/box rows
        // (a NET POSITIVE diff carries a null count, so its cell is 0/0 and earns no
        // letter, matching R). Means are not recomputed here (no per-column SD in the
        // model), which is why they had no 80% letters at all on this path.
        var cells = cols.map(function (ci) {
          return sigCell(r.n[ci], q.bases[ci]);
        });
        low80 = TR.stats.sigLetters(cells, letters, threshold, false, true)
          .map(function (s) {
            return s.split("").filter(function (ch) {
              return ch === ch.toLowerCase();
            }).join("");
          });
      }
      return {
        kind: r.kind, label: r.label, indexDesc: r.index_desc || null,
        // A row that had to substitute another statistic carries its own; the
        // rest inherit the question's (C1).
        stat: r.stat || statOf(q),
        diff: !!(q.net_diffs && q.net_diffs[String(qri)]),
        cells: cols.map(function (ci, i) {
          return { pct: r.kind === "mean" ? null : r.pct[ci],
            mean: r.kind === "mean" ? r.pct[ci] : null,
            n: r.n[ci],
            sig: (r.sig[ci] || "") + (low80 ? low80[i] : "") };
        })
      };
    });
    return { source: "published", columns: columns, rows: rows, stat: statOf(q) };
  }

  /**
   * True when the question carries per-respondent data we can re-tabulate
   * under a filter / custom banner — raw answers, box membership or scores.
   * Ranking and other derived-metric questions carry none (answers all null,
   * no boxes, no scores), so a filtered recompute can only honestly report
   * "not available" — never a base of 0 against real published figures.
   */
  function recomputable(q) {
    if (TR.MICRO.boxes && TR.MICRO.boxes[q.code]) return true;
    if (TR.MICRO.scores && TR.MICRO.scores[q.code]) return true;
    var a = TR.MICRO.answers[q.code];
    if (!a) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] !== null && a[i] !== undefined) return true;
    }
    return false;
  }

  /** Computed view from microdata for any banner/filter combination. */
  function computedModel(q, bannerId, filters, dual) {
    var spec = TR.stats.columnsFor(bannerId);
    var mask = TR.stats.mask(filters);
    var tabs = TR.stats.tabulate(q, spec.columns, mask);
    var letters = spec.columns.map(function (c) { return c.letter; });
    var threshold = lowThreshold();
    var means = stash(q, spec.columns, mask);
    // A derived-metric question (ranking, etc.) has no microdata to re-tabulate:
    // its base would compute to 0 against a real published base, so report it as
    // "not recomputable" (null base -> "–", no false low-base flag) instead.
    var canRecompute = recomputable(q);

    var columns = spec.columns.map(function (col, i) {
      return { label: col.label, letter: col.letter,
        base: canRecompute ? tabs[i].base : null,
        // Weighted base (Σw) + Kish effective base for the base-row display;
        // the renderer only shows them on a weighted report.
        baseW: canRecompute ? tabs[i].wbase : null,
        baseEff: canRecompute ? tabs[i].effBase : null,
        low: canRecompute && tabs[i].base < threshold };
    });

    var rows = q.rows.map(function (r, ri) {
      if (r.kind === "mean") {
        if (!means) {
          return rowModel(r, spec.columns.map(function () {
            return { mean: null, n: null, pct: null, sig: "" };
          }));
        }
        // WHICH statistic this row reports decides what gets recomputed. This
        // used to recognise "Standard Deviation" by its label and treat every
        // other mean-kind row as the mean itself, so a filtered view printed
        // the recomputed MEAN in the Median row — on VAS electricity, R563.68
        // under a Male filter in a row whose real value is R300. mstat comes
        // from the row TYPE in R; the label test stays as the fallback for
        // reports built before mstat existed.
        var stat = model.meanStat(r);
        var vals = statValues(stat, q, r, means, spec.columns, mask);
        // Only the headline mean is tested. A spread, a median and a ratio of
        // totals each need a test nobody has specified, and inventing one is
        // worse than showing none.
        var sig = stat === "mean"
          ? TR.stats.sigLetters(means, letters, threshold, true, dual) : null;
        return rowModel(r, vals.map(function (v, i) {
          return { mean: v, n: null, pct: null, sig: sig ? sig[i] : "" };
        }));
      }
      if (r.kind === "net") {
        return netRow(q, r, ri, spec.columns, mask, tabs, letters, threshold, dual);
      }
      // Weighted: % = Σw(row) / Σw(base); displayed n = weighted count (the
      // published Frequency); significance is sized by the effective base.
      // Unweighted (every weight 1): wbase === base === effBase, so this is
      // numerically identical to the prior count-based path.
      var cells = tabs.map(function (tab) {
        var wcount = tab.counts[ri] || 0;
        return { wcount: wcount, p: tab.wbase ? wcount / tab.wbase : null,
          effBase: tab.effBase };
      });
      var sigCells = cells.map(function (c) {
        return { x: c.p === null ? 0 : c.p * c.effBase, base: c.effBase };
      });
      var sigs = TR.stats.sigLetters(sigCells, letters, threshold, false, dual);
      return rowModel(r, cells.map(function (cell, i) {
        return { pct: cell.p === null ? null : cell.p * 100,
          n: cell.wcount, mean: null, sig: sigs[i] };
      }));
    });
    return { source: "computed", columns: columns, rows: rows,
      stat: COL_PCT,
      // Set when the recompute changed the unit (published counts / row %s ->
      // column %s), so the card can say so instead of silently swapping.
      statWas: statOf(q) === COL_PCT ? null : statOf(q),
      notRecomputable: !canRecompute,
      maskCount: TR.stats.maskCount(mask), custom: !!spec.custom,
      composite: !!spec.composite,
      customSource: spec.source ? spec.source.code : null };
  }

  function stash(q, columns, mask) {
    return TR.stats.indexMeans(q, columns, mask);
  }

  // Every computed value is a COLUMN percentage — TR.stats.tabulate divides each
  // row's (weighted) count by the column's own base. So a question published as
  // row percentages or as raw counts changes units the moment a filter or custom
  // banner is applied; the stat travels with the value and the renderer relabels
  // rather than printing the new number under the old unit (C1).
  function rowModel(r, cells) {
    return { kind: r.kind, label: r.label,
      indexDesc: r.index_desc || null, stat: COL_PCT, cells: cells };
  }

  /** Build a NET row model from a {wbase, n, effBase}[] counts array. */
  function netRowFromCounts(r, counts, letters, threshold, dual) {
    var sigCells = counts.map(function (c) {
      var p = c.wbase ? c.n / c.wbase : null;
      return { x: p === null ? 0 : p * c.effBase, base: c.effBase };
    });
    var sigs = TR.stats.sigLetters(sigCells, letters, threshold, false, dual);
    return rowModel(r, counts.map(function (c, i) {
      return { pct: c.wbase ? c.n / c.wbase * 100 : null,
        n: c.n, mean: null, sig: sigs[i] };
    }));
  }

  function netRow(q, r, ri, columns, mask, tabs, letters, threshold, dual) {
    // Box-category membership (TR.MICRO.boxes) recomputes box NETs directly from
    // each respondent's box — works whether the underlying scale is shown
    // (SACAP) or hidden (CCS shows only the boxes). Falls back to net_members.
    var boxes = TR.MICRO.boxes && TR.MICRO.boxes[q.code];
    var diff = q.net_diffs && q.net_diffs[String(ri)];
    if (diff !== undefined) {
      var diffRow = function (cells) {
        var m = rowModel(r, cells);
        m.diff = true;
        return m;
      };
      var plusCells = boxes ? TR.stats.boxCounts(q.code, diff.plus, columns, mask)
        : netOrRowCounts(q, q.rows[diff.plus], diff.plus, columns, mask, tabs);
      var minusCells = boxes ? TR.stats.boxCounts(q.code, diff.minus, columns, mask)
        : netOrRowCounts(q, q.rows[diff.minus], diff.minus, columns, mask, tabs);
      // Letters on a NET POSITIVE row test the PRINTED net, via the mean of the
      // per-respondent +-100 score (review 2026-08, I5) — matching what the R
      // engine writes into the published view, so a filtered recompute and the
      // published table do not letter the same row differently. Only available
      // when box membership is carried; the net_members fallback has no
      // per-respondent box, so it stays unlettered rather than guessing.
      var netSig = boxes
        ? TR.stats.sigLetters(
          TR.stats.netScoreMeans(q.code, diff.plus, diff.minus, columns, mask),
          letters, threshold, true, dual)
        : null;
      return diffRow(plusCells.map(function (p, i) {
        var m = minusCells[i];
        var pct = (p.wbase && m.wbase)
          ? (p.n / p.wbase - m.n / m.wbase) * 100 : null;
        return { pct: pct, n: null, mean: null, sig: netSig ? netSig[i] : "" };
      }));
    }
    if (boxes) {
      return netRowFromCounts(r, TR.stats.boxCounts(q.code, ri, columns, mask),
        letters, threshold, dual);
    }
    var members = q.net_members && q.net_members[String(ri)];
    if (!members) {
      return rowModel(r, columns.map(function () {
        return { pct: null, n: null, mean: null, sig: "" };
      }));
    }
    // Weighted NET: % = Σw(hit) / Σw(base), significance sized by effBase.
    var counts = TR.stats.netCounts(q, members, columns, mask);
    var sigCells = counts.map(function (c) {
      var p = c.wbase ? c.n / c.wbase : null;
      return { x: p === null ? 0 : p * c.effBase, base: c.effBase };
    });
    var sigs = TR.stats.sigLetters(sigCells, letters, threshold, false, dual);
    return rowModel(r, counts.map(function (c, i) {
      return { pct: c.wbase ? c.n / c.wbase * 100 : null,
        n: c.n, mean: null, sig: sigs[i] };
    }));
  }

  function netOrRowCounts(q, row, ri, columns, mask, tabs) {
    if (row.kind === "net") {
      var members = q.net_members && q.net_members[String(ri)];
      if (members) return TR.stats.netCounts(q, members, columns, mask);
    }
    return tabs.map(function (tab) {
      return { base: tab.base, n: tab.counts[ri] || 0,
        wbase: tab.wbase, effBase: tab.effBase };
    });
  }

  /**
   * The model the UI renders: published when possible, computed when the
   * state demands it (filter active or custom banner).
   */
  /* exposed for the golden parity tests */
  model._computedModel = computedModel;
  model._publishedModel = publishedModel;
  model._sigCell = sigCell;
  model._applyDisclosureSuppression = applyDisclosureSuppression;

  /**
   * Attach 95% interval bounds to every cell (cell.ci = {lo, hi}).
   * ADDITIVE display only — values never change. Proportions: Wilson on
   * the exact count when published, the displayed pct otherwise. Means:
   * z·SD/√n with the SD derived from the column's own category
   * distribution via TR.waves.scoreMap + sdFromPairs — the same single
   * SD source the significance tests use (guardrail: never fork it).
   * Must run BEFORE row ops so mean rows still align with q.rows.
   */
  function attachIntervals(viewModel, q) {
    viewModel.rows.forEach(function (row) {
      if (row.diff) return;      // score differences have no single base
      if (row.kind === "mean") {
        var scores = TR.waves.scoreMap(q, row);
        if (!scores) return;
        row.cells.forEach(function (cell, ci) {
          if (cell.mean === null || cell.mean === undefined) return;
          var pairs = [];
          Object.keys(scores).forEach(function (ri) {
            var catRow = viewModel.rows[ri];
            var catCell = catRow && catRow.cells[ci];
            // The SD is derived from the category distribution, which only means
            // anything as COLUMN percentages. On a counts-only / row-%-only
            // question those cells hold something else, and feeding them here
            // produced an interval around the mean out of the wrong quantity (C1).
            if (catRow && !TR.fmt.isColPctStat(catRow.stat)) return;
            if (catCell && catCell.pct !== null && catCell.pct !== undefined) {
              pairs.push({ p: catCell.pct, s: scores[ri] });
            }
          });
          var sd = TR.waves.sdFromPairs(pairs);
          var col = viewModel.columns[ci];
          // Variance scales with the Kish effective base on weighted designs —
          // the raw n would claim precision the design effect took away.
          var base = col ? (col.baseEff != null ? col.baseEff : col.base) : null;
          // ciBase carries the finite-population-corrected effective base when a
          // universe is known (Infinity for a full census -> zero-width); else
          // it is the effective/plain base, so non-population reports are unchanged.
          var ciBase = (col && col.ciBase != null) ? col.ciBase : base;
          var bounds = sd === null ? null : TR.conf.meanCI(cell.mean, sd, ciBase);
          if (bounds) cell.ci = bounds;
        });
        return;
      }
      // A Wilson interval is an interval around a COLUMN proportion. Attaching
      // one to a raw count or a row percentage (whose denominator is the row,
      // not this column's base) states a precision that was never computed —
      // it printed "80 (71.1–86.7)" beside a count of 80 (C1).
      if (!TR.fmt.isColPctStat(row.stat)) return;
      row.cells.forEach(function (cell, ci) {
        if (cell.pct === null || cell.pct === undefined) return;
        var col = viewModel.columns[ci];
        var base = col ? col.base : null;
        if (!base) return;
        // Use THIS column's own weighted + effective base, already aligned to the
        // column in the model. NOT q.bases[ci]: that is indexed by the full column
        // list, whereas ci is the position within the current banner view — so on
        // any banner past the first, every column would borrow a different column's
        // base and the interval detaches from the shown % (e.g. 73% -> 12–18pp).
        var weighted = !!(col.baseW > 0 && col.baseEff > 0);
        // Weighted: the shown % is weighted, so the proportion is weightedCount/weightedBase
        // and the interval width uses the Kish effective base (variance ~ 1/effN). Unweighted:
        // exact counts. Either way, ciBase (when a universe is known) already carries the
        // FPC-corrected effective base, so population reports narrow consistently here,
        // in the mean branch, and in the base-row MOE.
        var ciBase = (col.ciBase != null) ? col.ciBase : (weighted ? col.baseEff : base);
        var p = weighted
          ? (cell.n != null ? cell.n / col.baseW : cell.pct / 100)
          : (cell.n !== null && cell.n !== undefined ? cell.n / base : cell.pct / 100);
        var w = TR.conf.wilson(Math.min(Math.max(p, 0), 1), ciBase);
        if (w) cell.ci = { lo: w.lower * 100, hi: w.upper * 100 };
      });
    });
  }

  /** Arrow for a z-score vs the rest, at the project's configured primary /
   *  secondary levels (single planned test per column — no Bonferroni). */
  function compositeArrow(z, dual) {
    if (z === null) return "";
    var zHi = TR.stats.zPrimary(1), zLo = TR.stats.zSecondary(1);
    if (z > zHi) return "▲";
    if (z < -zHi) return "▼";
    if (dual && z > zLo) return "▵";
    if (dual && z < -zLo) return "▿";
    return "";
  }

  /**
   * Significance for a COMPOSITE (profile) banner: each spotlight column is
   * tested against THE REST of the sample (everyone NOT in that column).
   *
   * Pairwise column-vs-column letters are deliberately NOT produced. A
   * composite's columns can overlap (a respondent can be in two of them), which
   * breaks the disjoint-samples assumption behind the two-proportion z-test —
   * running it would print plausible-but-wrong letters. Column-vs-rest is
   * disjoint by construction (column and not-column never share a respondent),
   * so it is always valid, and it is the natural read for a profile banner:
   * "does this group stand out from everyone else?". Bidirectional — ▲ above the
   * rest, ▼ below; dual mode adds the 80% level as hollow ▵ / ▿.
   *
   * The "rest" recompute mirrors the Differences view (27d_diffs restPct) so the
   * test and its denominators reconcile with that view — notably a box-scored
   * NET takes its numerator from box membership but its denominator from the
   * full answered base, so a no-box respondent (e.g. Neutral on a shown scale)
   * still counts in the base. Runs on the computed model while rows are still
   * 1:1 with q.rows (before hide / sort) and writes per cell, so it survives both.
   */
  function applyCompositeSignificance(viewModel, q, bannerId, filters, dual) {
    var spec = TR.stats.columnsFor(bannerId);
    if (!spec.composite) return;
    var cols = spec.columns;
    var mask = TR.stats.mask(filters);
    var threshold = viewModel.lowBaseThreshold;
    var n = TR.MICRO.n;
    // Each column's disjoint complement ("the rest"), built once and reused for
    // every row; index 0 (Total) has no complement and is never tested.
    var rests = cols.map(function (c, i) {
      if (i === 0 || !c.member) return null;
      var rest = new Uint8Array(n);
      for (var r = 0; r < n; r++) rest[r] = c.member[r] ? 0 : 1;
      return { member: rest };
    });
    var restCols = cols.map(function (c, i) { return i === 0 ? { member: null } : rests[i]; });
    // One tabulation pass for the columns and one for their complements covers
    // every category row + base; means and NETs recompute per row below.
    var colTab = TR.stats.tabulate(q, cols, mask);
    var restTab = TR.stats.tabulate(q, restCols, mask);
    var colMeans = TR.stats.indexMeans(q, cols, mask);
    var restMeans = colMeans ? TR.stats.indexMeans(q, restCols, mask) : null;
    var boxes = TR.MICRO.boxes && TR.MICRO.boxes[q.code];

    // Two-proportion z of a column vs its rest, gated by the low-base threshold
    // and the test's own preconditions (propZ returns null when either fails).
    var propZrest = function (pCol, effCol, pRest, effRest) {
      if (pCol === null || pRest === null || !effCol || effCol < threshold) return null;
      return TR.stats.propZ(pCol * effCol, effCol, pRest * effRest, effRest);
    };

    viewModel.rows.forEach(function (row, ri) {
      var isMean = row.kind === "mean";
      // Only the headline mean is tested. A median, a mode, a spread or a
      // ratio of totals each need a test nobody has specified, and the means
      // this path recomputes are the wrong input for all four.
      var skip = row.diff || (isMean && !model.isHeadlineMean(row));
      row.cells.forEach(function (cell, ci) {
        cell.sig = "";                       // clears any (empty) pairwise letters
        if (ci === 0 || skip) return;
        // Disclosure suppression (which ran first) blanked this cell — an arrow
        // on a blank would resurrect exactly what was withheld.
        if (cell.suppressed || (viewModel.columns[ci] && viewModel.columns[ci].suppressed)) return;
        var z = null;
        if (isMean) {
          if (!colMeans || !restMeans) return;
          var cm = colMeans[ci], rm = restMeans[ci];
          if (!cm || cm.mean === null || !cm.k || cm.k < threshold) return;
          if (!rm || rm.mean === null || !rm.k) return;
          z = TR.stats.meanZ(cm.mean, cm.sd, cm.k, rm.mean, rm.sd, rm.k);
        } else if (row.kind === "net") {
          var members = q.net_members && q.net_members[String(ri)];
          if (members && members.length) {
            var cc = TR.stats.netCounts(q, members, [cols[ci]], mask)[0];
            var rc = TR.stats.netCounts(q, members, [rests[ci]], mask)[0];
            z = propZrest(cc.wbase ? cc.n / cc.wbase : null, cc.effBase,
              rc.wbase ? rc.n / rc.wbase : null, rc.effBase);
          } else if (boxes) {
            // box-scored NET: numerator from box membership, denominator from the
            // FULL answered base (colTab / restTab) — matches restPct.
            var cb = TR.stats.boxCounts(q.code, ri, [cols[ci]], mask)[0];
            var rb = TR.stats.boxCounts(q.code, ri, [rests[ci]], mask)[0];
            var cFull = colTab[ci], rFull = restTab[ci];
            z = propZrest(cFull.wbase ? cb.n / cFull.wbase : null, cFull.effBase,
              rFull.wbase ? rb.n / rFull.wbase : null, rFull.effBase);
          } else {
            return;
          }
        } else {                             // category row
          var ct = colTab[ci], rt = restTab[ci];
          z = propZrest(ct.wbase ? (ct.counts[ri] || 0) / ct.wbase : null, ct.effBase,
            rt.wbase ? (rt.counts[ri] || 0) / rt.wbase : null, rt.effBase);
        }
        cell.sig = compositeArrow(z, dual);
      });
    });
  }

  /** Drop hidden columns from a model (Total is never hidden). */
  function applyHiddenColumns(viewModel, hiddenLabels) {
    if (!hiddenLabels || !hiddenLabels.length) return viewModel;
    var keep = viewModel.columns.map(function (col, i) {
      return i === 0 || hiddenLabels.indexOf(col.label) === -1;
    });
    viewModel.hiddenCount = keep.filter(function (k) { return !k; }).length;
    viewModel.columns = viewModel.columns.filter(function (_, i) { return keep[i]; });
    viewModel.rows.forEach(function (row) {
      row.cells = row.cells.filter(function (_, i) { return keep[i]; });
    });
    return viewModel;
  }

  /**
   * Row operations: scope (detail categories / summary NETs+means / all),
   * per-question hidden rows, and sorting category rows by a column.
   * Applied at model level so table, chart, pins and every export agree.
   */
  function applyRowOps(viewModel, opts) {
    var scope = opts.rowScope || "all";
    var hidden = opts.hiddenRows || [];
    viewModel.hiddenRowCount = 0;
    viewModel.rows = viewModel.rows.filter(function (row) {
      if (scope === "detail" && row.kind !== "category") return false;
      if (scope === "summary" && row.kind === "category") return false;
      if (hidden.indexOf(row.label) !== -1) {
        viewModel.hiddenRowCount++;
        return false;
      }
      return true;
    });
    var sort = opts.sort;
    if (sort && sort.dir && viewModel.columns[sort.col]) {
      var cats = viewModel.rows.filter(function (r) { return r.kind === "category"; });
      var rest = viewModel.rows.filter(function (r) { return r.kind !== "category"; });
      cats.sort(function (a, b) {
        var av = a.cells[sort.col] ? a.cells[sort.col].pct : null;
        var bv = b.cells[sort.col] ? b.cells[sort.col].pct : null;
        if (av === null) return 1;
        if (bv === null) return -1;
        return sort.dir === "asc" ? av - bv : bv - av;
      });
      viewModel.rows = cats.concat(rest);
      viewModel.sorted = sort;
    }
    return viewModel;
  }

  /**
   * Disclosure control: blank any column whose reporting base is below the confidentiality
   * threshold k (a base of 1..k-1), so a filter narrowed down to a handful of people can't
   * show their exact answers in the crosstab / dashboard / differences / exports. An empty
   * column (base 0) is already "–"; k = 1 (off) is a no-op, so unprotected reports are
   * byte-identical. When the whole filtered audience is < k every column blanks, which is the
   * n=1-cut case. Letters pointing AT a blanked column are stripped from the columns that
   * remain, so a shown cell never claims "higher than B" once B is hidden. (Complementary
   * subtraction suppression across a banner group is the next increment.)
   */
  function applyDisclosureSuppression(viewModel) {
    if (!(TR.disclosure && TR.disclosure.active && TR.disclosure.active())) return;
    var minBase = TR.disclosure.minBase();
    var gone = [];
    viewModel.columns.forEach(function (col, ci) {
      var base = col.base;
      if (base == null || base === 0 || base >= minBase) return;
      col.suppressed = true;
      if (col.letter) gone.push(col.letter);
      viewModel.rows.forEach(function (row) {
        var cell = row.cells[ci];
        if (!cell) return;
        cell.pct = null; cell.mean = null; cell.n = null; cell.sig = ""; cell.ci = null;
        cell.suppressed = true;
      });
    });
    if (gone.length) {
      var re = new RegExp("[" + gone.join("") + "]", "gi");   // strip both 95% + 80% forms
      viewModel.rows.forEach(function (row) {
        row.cells.forEach(function (cell) {
          if (cell && cell.sig && !cell.suppressed) cell.sig = cell.sig.replace(re, "");
        });
      });
    }
  }

  /**
   * The model the UI renders.
   * @param {object} [opts] - {hiddenCols, hiddenRows, rowScope, sort, dual,
   *   intervals} — intervals=true attaches 95% bounds to every cell.
   */
  model.forQuestion = function (code, bannerId, filters, opts) {
    opts = opts || {};
    var q = TR.d2.questionByCode(code);
    if (!q) return null;
    var custom = bannerId && bannerId.indexOf("custom:") === 0;
    var composite = bannerId && bannerId.indexOf("composite:") === 0;
    var filtered = filters && filters.length > 0;
    var needCompute = custom || composite || filtered;
    var viewModel;
    if (needCompute && TR.d2.hasMicrodata()) {
      viewModel = computedModel(q, bannerId, filters, opts.dual);
    } else {
      viewModel = publishedModel(q,
        custom || composite ? TR.d2.firstBanner() : bannerId, opts.dual);
    }
    // Finite population correction applies to the DEFAULT (published) view of a
    // population report — never under a filter / custom banner, where a
    // sub-population's universe is unknown. The published numbers stay verbatim
    // and FPC narrows the intervals (attachIntervals reads each column's
    // ciBase). Significance is not touched here: it arrives already corrected
    // from R.
    viewModel.fpcDefault = !custom && !composite && !filtered && TR.conf.fpcActiveReport();
    viewModel.code = q.code;
    viewModel.title = q.title;
    // analyst ShortLabel for space-tight surfaces (null on older data layers)
    viewModel.short_label = TR.d2.shortLabel(q) !== q.title ? TR.d2.shortLabel(q) : null;
    // Who was asked this question (Selection FilterLabel / BaseFilter) — null
    // when everyone was. Travels on the model so the card AND every export of
    // it state the audience beside the base.
    viewModel.audience = TR.d2.audienceNote(q) || null;
    viewModel.type = q.type;
    // scale_max travels with type so display formatters can resolve the
    // NPS/0-100 percent-precision exception (fmt.decimalsForQ) from the model.
    viewModel.scale_max = q.scale_max;
    viewModel.category = q.category;
    viewModel.lowBaseThreshold = lowThreshold();
    // An audience filter makes the current wave a subgroup, but prior waves are
    // published full-sample Totals with no microdata to filter — so a wave-on-
    // wave delta would compare filtered-now against unfiltered-prior. Flag the
    // model so attachDeltas suppresses the (misleading) trend under a filter.
    viewModel.filtered = !!(filters && filters.length > 0) && TR.d2.hasMicrodata();
    // Blank sub-threshold columns BEFORE deltas/significance/intervals, so none of them
    // compute (or leak) anything for a cut too small to report.
    applyDisclosureSuppression(viewModel);
    TR.waves.attachDeltas(q, viewModel);
    // NO FPC re-lettering here. R applies the finite population correction
    // inside its own tests now, so the published letters this view carries are
    // already FPC-corrected — at both alphas, on weighted designs too, and from
    // the unrounded counts. Recomputing them here from the DISPLAY-rounded %s
    // was a second, worse computation of the same thing, and it was gated off
    // for weighted reports, so a weighted census silently kept uncorrected
    // letters. FPC still reaches this view through ciBase: intervals narrow,
    // the low-base flag is coverage-aware, and the census framing stands.
    // Computed views (filter / custom banner) keep standard significance — a
    // sub-population's universe is unknown.
    // Composite (profile) banners replace pairwise letters with vs-the-rest
    // arrows — only meaningful on the microdata recompute (its columns carry the
    // membership the test needs); a no-microdata fallback rendered the first
    // real banner instead, so guard on the computed source.
    if (composite && viewModel.source === "computed") {
      applyCompositeSignificance(viewModel, q, bannerId, filters, opts.dual);
    }
    if (opts.intervals) attachIntervals(viewModel, q);
    var hidden = opts.hiddenCols !== undefined
      ? opts.hiddenCols : TR.d2.hiddenFor(bannerId);
    applyHiddenColumns(viewModel, hidden);
    return applyRowOps(viewModel, opts);
  };

})(typeof window !== "undefined" ? window : globalThis);
