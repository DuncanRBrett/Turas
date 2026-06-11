/**
 * v2 view model — ONE interface the whole UI renders from. For the default
 * view (built-in banner, no filter) it returns the PUBLISHED numbers
 * verbatim; with a filter or custom banner it recomputes everything from
 * microdata and marks the model "computed". Wave-on-wave deltas attach to
 * the Total column when the 2024 wave carries a matching question.
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

  /** Normalise a label/title for cross-wave matching (mirrors pipeline). */
  model.norm = function (text) {
    return String(text || "").toLowerCase().replace(/\s+/g, " ")
      .replace(/[^a-z0-9 ]/g, "").trim();
  };

  var prevIndex = null;
  function prevQuestion(q) {
    if (!TR.PREV) return null;
    if (!prevIndex) {
      prevIndex = {};
      TR.PREV.questions.forEach(function (p) { prevIndex[p.title_norm] = p; });
    }
    return prevIndex[model.norm(q.title)] || null;
  }

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
        var sig = TR.stats.sigLetters(means, letters, threshold, true, dual);
        return rowModel(r, means.map(function (m, i) {
          return { mean: m.mean, n: null, pct: null, sig: sig[i] };
        }));
      }
      if (r.kind === "net") {
        return netRow(q, r, ri, spec.columns, mask, tabs, letters, threshold, dual);
      }
      var cells = tabs.map(function (tab) {
        return { x: tab.counts[ri] || 0, base: tab.base };
      });
      var sigs = TR.stats.sigLetters(cells, letters, threshold, false, dual);
      return rowModel(r, cells.map(function (cell, i) {
        return { pct: cell.base ? cell.x / cell.base * 100 : null,
          n: cell.x, mean: null, sig: sigs[i] };
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

  function netRow(q, r, ri, columns, mask, tabs, letters, threshold, dual) {
    var diff = q.net_diffs && q.net_diffs[String(ri)];
    if (diff !== undefined) {
      var diffRow = function (cells) {
        var m = rowModel(r, cells);
        m.diff = true;
        return m;
      };
      var plus = q.rows[diff.plus], minus = q.rows[diff.minus];
      var plusCells = netOrRowCounts(q, plus, diff.plus, columns, mask, tabs);
      var minusCells = netOrRowCounts(q, minus, diff.minus, columns, mask, tabs);
      return diffRow(plusCells.map(function (p, i) {
        var m = minusCells[i];
        var pct = (p.base && m.base)
          ? (p.n / p.base - m.n / m.base) * 100 : null;
        return { pct: pct, n: null, mean: null, sig: "" };
      }));
    }
    var members = q.net_members && q.net_members[String(ri)];
    if (!members) {
      return rowModel(r, columns.map(function () {
        return { pct: null, n: null, mean: null, sig: "" };
      }));
    }
    var counts = TR.stats.netCounts(q, members, columns, mask);
    var sigs = TR.stats.sigLetters(counts.map(function (c) {
      return { x: c.n, base: c.base };
    }), letters, threshold, false, dual);
    return rowModel(r, counts.map(function (c, i) {
      return { pct: c.base ? c.n / c.base * 100 : null,
        n: c.n, mean: null, sig: sigs[i] };
    }));
  }

  function netOrRowCounts(q, row, ri, columns, mask, tabs) {
    if (row.kind === "net") {
      var members = q.net_members && q.net_members[String(ri)];
      if (members) return TR.stats.netCounts(q, members, columns, mask);
    }
    return tabs.map(function (tab) {
      return { base: tab.base, n: tab.counts[ri] || 0 };
    });
  }

  /** Attach 2024 deltas to the Total column of a model (in place). */
  function attachDeltas(q, viewModel) {
    var prev = prevQuestion(q);
    viewModel.prevWave = prev ? { base: prev.base } : null;
    if (!prev) return viewModel;
    viewModel.rows.forEach(function (row) {
      if (row.kind === "mean") {
        var prevMean = prevIndexMean(q, prev);
        if (prevMean !== null && row.cells[0].mean !== null) {
          row.delta = { prev: prevMean, diff: row.cells[0].mean - prevMean,
            sig: false, isMean: true };
        }
        return;
      }
      var hit = prev.rows[model.norm(row.label)];
      if (!hit || hit.pct === undefined) return;
      var cur = row.cells[0].pct;
      if (cur === null || cur === undefined) return;
      var curBase = viewModel.columns[0].base || 0;
      var sig = false;
      if (prev.base && curBase) {
        sig = TR.stats.propHigher(Math.round(cur / 100 * curBase), curBase,
                Math.round(hit.pct / 100 * prev.base), prev.base) ||
              TR.stats.propHigher(Math.round(hit.pct / 100 * prev.base), prev.base,
                Math.round(cur / 100 * curBase), curBase);
      }
      row.delta = { prev: hit.pct, diff: cur - hit.pct, sig: sig, isMean: false };
    });
    return viewModel;
  }

  /** Prior-wave index mean recomputed from the 2024 distribution. */
  function prevIndexMean(q, prev) {
    if (!q.index_scores) return null;
    var sum = 0, weight = 0;
    Object.keys(q.index_scores).forEach(function (label) {
      var hit = prev.rows[model.norm(label)];
      if (hit && hit.pct !== undefined) {
        sum += q.index_scores[label] * hit.pct;
        weight += hit.pct;
      }
    });
    return weight > 0 ? sum / weight : null;
  }

  /**
   * The model the UI renders: published when possible, computed when the
   * state demands it (filter active or custom banner).
   */
  /* exposed for the golden parity tests */
  model._computedModel = computedModel;
  model._publishedModel = publishedModel;

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
   * @param {object} [opts] - {hiddenCols, hiddenRows, rowScope, sort, dual}.
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
    attachDeltas(q, viewModel);
    var hidden = opts.hiddenCols !== undefined
      ? opts.hiddenCols : TR.d2.hiddenFor(bannerId);
    applyHiddenColumns(viewModel, hidden);
    return applyRowOps(viewModel, opts);
  };

})(typeof window !== "undefined" ? window : globalThis);
