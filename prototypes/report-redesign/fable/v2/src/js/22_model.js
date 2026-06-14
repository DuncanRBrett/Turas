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

  /** A standard-deviation summary row (reports spread, not the mean). */
  function isStdDevRow(label) {
    return /^(std\.?\s*dev|standard deviation)/i.test(String(label || ""));
  }

  /** Normalise a label/title for cross-wave matching (mirrors pipeline). */
  model.norm = function (text) {
    return String(text || "").toLowerCase().replace(/\s+/g, " ")
      .replace(/[^a-z0-9 ]/g, "").trim();
  };

  /** Published view: columns restricted to Total + the chosen banner group.
   *  With dual=true, 80%-level lowercase letters are computed from the
   *  published counts and appended to the published 95% letters. */
  function publishedModel(q, bannerId, dual) {
    var cols = [0].concat(TR.d2.groupCols(bannerId));
    var threshold = lowThreshold();
    var columns = cols.map(function (ci) {
      return {
        label: TR.AGG.columns[ci].label,
        letter: ci === 0 ? "" : TR.AGG.columns[ci].letter,
        base: q.bases[ci] ? q.bases[ci].n : null,
        low: q.bases[ci] ? !!q.bases[ci].low : false
      };
    });
    var letters = columns.map(function (c) { return c.letter; });
    var rows = q.rows.map(function (r, qri) {
      var low80 = null;
      if (dual && r.kind === "category") {
        var cells = cols.map(function (ci) {
          return { x: r.n[ci] || 0, base: q.bases[ci] ? q.bases[ci].n : 0 };
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
        diff: !!(q.net_diffs && q.net_diffs[String(qri)]),
        cells: cols.map(function (ci, i) {
          return { pct: r.kind === "mean" ? null : r.pct[ci],
            mean: r.kind === "mean" ? r.pct[ci] : null,
            n: r.n[ci],
            sig: (r.sig[ci] || "") + (low80 ? low80[i] : "") };
        })
      };
    });
    return { source: "published", columns: columns, rows: rows };
  }

  /** Computed view from microdata for any banner/filter combination. */
  function computedModel(q, bannerId, filters, dual) {
    var spec = TR.stats.columnsFor(bannerId);
    var mask = TR.stats.mask(filters);
    var tabs = TR.stats.tabulate(q, spec.columns, mask);
    var letters = spec.columns.map(function (c) { return c.letter; });
    var threshold = lowThreshold();
    var means = stash(q, spec.columns, mask);

    var columns = spec.columns.map(function (col, i) {
      return { label: col.label, letter: col.letter,
        base: tabs[i].base, low: tabs[i].base < threshold };
    });

    var rows = q.rows.map(function (r, ri) {
      if (r.kind === "mean") {
        if (!means) {
          return rowModel(r, spec.columns.map(function () {
            return { mean: null, n: null, pct: null, sig: "" };
          }));
        }
        // A "Standard Deviation" row is a mean-kind row but reports the spread,
        // not the centre — show the recomputed SD (untested) so a filtered view
        // never displays the mean in the SD row.
        var sd = isStdDevRow(r.label);
        var sig = sd ? null : TR.stats.sigLetters(means, letters, threshold, true, dual);
        return rowModel(r, means.map(function (m, i) {
          return { mean: sd ? m.sd : m.mean, n: null, pct: null,
            sig: sd ? "" : sig[i] };
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
      maskCount: TR.stats.maskCount(mask), custom: !!spec.custom,
      customSource: spec.source ? spec.source.code : null };
  }

  function stash(q, columns, mask) {
    return TR.stats.indexMeans(q, columns, mask);
  }

  function rowModel(r, cells) {
    return { kind: r.kind, label: r.label,
      indexDesc: r.index_desc || null, cells: cells };
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
      return diffRow(plusCells.map(function (p, i) {
        var m = minusCells[i];
        var pct = (p.wbase && m.wbase)
          ? (p.n / p.wbase - m.n / m.wbase) * 100 : null;
        return { pct: pct, n: null, mean: null, sig: "" };
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
            var catCell = viewModel.rows[ri] && viewModel.rows[ri].cells[ci];
            if (catCell && catCell.pct !== null && catCell.pct !== undefined) {
              pairs.push({ p: catCell.pct, s: scores[ri] });
            }
          });
          var sd = TR.waves.sdFromPairs(pairs);
          var base = viewModel.columns[ci] ? viewModel.columns[ci].base : null;
          var bounds = sd === null ? null : TR.conf.meanCI(cell.mean, sd, base);
          if (bounds) cell.ci = bounds;
        });
        return;
      }
      row.cells.forEach(function (cell, ci) {
        if (cell.pct === null || cell.pct === undefined) return;
        var base = viewModel.columns[ci] ? viewModel.columns[ci].base : null;
        if (!base) return;
        var p = cell.n !== null && cell.n !== undefined
          ? cell.n / base : cell.pct / 100;
        var w = TR.conf.wilson(Math.min(Math.max(p, 0), 1), base);
        if (w) cell.ci = { lo: w.lower * 100, hi: w.upper * 100 };
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
   * The model the UI renders.
   * @param {object} [opts] - {hiddenCols, hiddenRows, rowScope, sort, dual,
   *   intervals} — intervals=true attaches 95% bounds to every cell.
   */
  model.forQuestion = function (code, bannerId, filters, opts) {
    opts = opts || {};
    var q = TR.d2.questionByCode(code);
    if (!q) return null;
    var custom = bannerId && bannerId.indexOf("custom:") === 0;
    var needCompute = custom || (filters && filters.length > 0);
    var viewModel;
    if (needCompute && TR.d2.hasMicrodata()) {
      viewModel = computedModel(q, bannerId, filters, opts.dual);
    } else {
      viewModel = publishedModel(q,
        custom ? TR.AGG.banner_groups[0].id : bannerId, opts.dual);
    }
    viewModel.code = q.code;
    viewModel.title = q.title;
    viewModel.type = q.type;
    viewModel.category = q.category;
    viewModel.lowBaseThreshold = lowThreshold();
    TR.waves.attachDeltas(q, viewModel);
    if (opts.intervals) attachIntervals(viewModel, q);
    var hidden = opts.hiddenCols !== undefined
      ? opts.hiddenCols : TR.d2.hiddenFor(bannerId);
    applyHiddenColumns(viewModel, hidden);
    return applyRowOps(viewModel, opts);
  };

})(typeof window !== "undefined" ? window : globalThis);
