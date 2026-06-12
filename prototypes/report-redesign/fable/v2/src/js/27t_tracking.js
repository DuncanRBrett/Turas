/**
 * v2 Tracking workspace — tracker-module parity over the wave history.
 * This file: the sub-tab shell (Summary | Metrics | Segments | Visualise),
 * the shared tracking helpers (TR.trk) and the Metrics view (every tracked
 * metric, column-per-wave, for Total OR any tracked banner segment).
 * Summary lives in 27u_summary.js; Segments + Visualise in 27v_visualise.js.
 *
 * Tracking views always show PUBLISHED figures — current wave included —
 * so segment columns and history stay comparable; report-level filters
 * deliberately do not apply here (noted in the UI when active).
 *
 * SIZE-EXCEPTION: one tracking workspace shell + its shared data helpers;
 * the metric list, segment lookups and formatting are used by all three
 * view files and splitting them would scatter the contract.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var views = TR.views;
  var trk = TR.trk = {};

  /** Workspace state — survives tab switches (module scope, not DOM). */
  trk.state = {
    sub: "summary",
    scope: null,            // "key" | "all" (Metrics view)
    segment: null,          // segment norm, null = Total (Metrics view)
    metricKey: null,        // Segments/Visualise context metric
    visSegs: null,          // [segNorm|"total"] selected for Visualise
    visMode: "absolute",    // absolute | prev | base
    visCI: false, visLabels: "last", visWaves: null,
    yMin: null, yMax: null
  };
  var sort = null;
  var MAX_ROWS = 200;

  /* ---------------- shared helpers (used by 27u/27v) ---------------- */

  trk.fmtVal = function (v, isMean) {
    if (v === null || v === undefined) return "–";
    return isMean ? (Math.round(v * 10) / 10).toString() : Math.round(v) + "%";
  };

  trk.years = function () {
    return TR.d2.tracking().waves.map(function (w) { return w.year; });
  };

  var pubCache = {};
  /** Published, unfiltered model for a question under a banner group. */
  trk.publishedModel = function (code, group) {
    var key = code + "::" + (group || "total");
    if (!pubCache[key]) {
      pubCache[key] = TR.model.forQuestion(code,
        group || TR.AGG.banner_groups[0].id, [], { hiddenCols: [] });
    }
    return pubCache[key];
  };

  var metricCache = {};
  /**
   * Every tracked metric row: [{key, code, title, category, label, kind,
   * isMean, diff, ri, q, row}] — ri indexes the unfiltered model's rows
   * (same order as q.rows). scope "key" = non-category rows only.
   */
  trk.metricList = function (scope) {
    if (metricCache[scope]) return metricCache[scope];
    var out = [];
    TR.AGG.questions.forEach(function (q) {
      var model = trk.publishedModel(q.code, null);
      if (!model || !model.prevWave) return;
      model.rows.forEach(function (row, ri) {
        if (!row.waves || !row.waves.length) return;
        if (scope === "key" && row.kind === "category") return;
        out.push({ key: q.code + "::" + ri, code: q.code, title: q.title,
          category: q.category, label: row.label, kind: row.kind,
          isMean: row.kind === "mean", diff: !!row.diff, ri: ri,
          q: TR.d2.questionByCode(q.code), row: row });
      });
    });
    metricCache[scope] = out;
    return out;
  };

  trk.metricByKey = function (key) {
    return trk.metricList("all").filter(function (m) {
      return m.key === key;
    })[0] || null;
  };

  trk.newQuestions = function () {
    return TR.AGG.questions.filter(function (q) {
      var m = trk.publishedModel(q.code, null);
      return !m || !m.prevWave;
    });
  };

  trk.segmentByNorm = function (norm) {
    return TR.waves.segments().filter(function (s) {
      return s.norm === norm;
    })[0] || null;
  };

  /** Published CURRENT value of a metric for Total or a segment. */
  trk.currentFor = function (metric, segNorm) {
    if (!segNorm) {
      var cell = metric.row.cells[0];
      var v = metric.isMean ? cell.mean : cell.pct;
      if (v === null || v === undefined) return null;
      return { value: v, base: trk.publishedModel(metric.code, null).columns[0].base,
        x: cell.n !== null && cell.n !== undefined ? cell.n : null };
    }
    var seg = trk.segmentByNorm(segNorm);
    if (!seg) return null;
    var model = trk.publishedModel(metric.code, seg.group);
    if (!model) return null;
    var ci = -1;
    model.columns.forEach(function (col, i) {
      if (col.label === seg.label) ci = i;
    });
    if (ci < 0) return null;
    var segCell = model.rows[metric.ri] && model.rows[metric.ri].cells[ci];
    if (!segCell) return null;
    var value = metric.isMean ? segCell.mean : segCell.pct;
    if (value === null || value === undefined) return null;
    return { value: value, base: model.columns[ci].base,
      x: segCell.n !== null && segCell.n !== undefined ? segCell.n : null };
  };

  /**
   * Full tracker-shaped point list for a metric in a segment (or Total):
   * history series + the current wave, each with change/sig vs previous
   * point and vs the first point. [] when no history for that segment.
   */
  trk.points = function (metric, segNorm) {
    var series = TR.waves.series(metric.q, metric.row, metric.ri, segNorm || null);
    if (!series.length) return [];
    var canSig = !metric.isMean && !metric.diff;
    var cur = trk.currentFor(metric, segNorm);
    var points = series.slice();
    if (cur) {
      points.push({ wave: TR.AGG.project.wave, year: TR.render.currentYear(),
        value: cur.value, base: cur.base,
        x: canSig ? (cur.x !== null ? cur.x
          : Math.round(cur.value / 100 * (cur.base || 0))) : null,
        current: true });
    }
    return TR.waves.cellsFor(points, canSig);
  };

  /* ---- KPI thresholds (tracker defaults, project-overridable) ---- */

  var THRESHOLDS = { pct: { green: 70, amber: 50 },
    index: { green: 70, amber: 50 }, mean: { green: 7, amber: 5 },
    nps: { green: 30, amber: 0 } };

  trk.kpiType = function (metric) {
    if (!metric.isMean) return "pct";
    var label = TR.model.norm(metric.label);
    if (label.indexOf("nps") !== -1) return "nps";
    if (label === "mean") return "mean";
    return "index";
  };

  trk.band = function (type, value) {
    var cfg = (TR.AGG.project.tracking || {}).thresholds || {};
    var t = cfg[type] || THRESHOLDS[type] || THRESHOLDS.pct;
    if (value === null || value === undefined) return "";
    return value >= t.green ? "g" : value >= t.amber ? "a" : "r";
  };

  trk.dirArrow = function (cell) {
    if (!cell || cell.change_prev === null) return "";
    if (cell.sig_prev) return cell.change_prev >= 0 ? "↑" : "↓";
    return "→";
  };

  /* ---------------- shell ---------------- */

  var SUBS = [["summary", "Summary"], ["metrics", "Metrics"],
    ["segments", "Segments"], ["visualise", "Visualise"]];

  views.whatMoved = function (host) {
    if (!TR.d2.tracking().enabled) {
      host.innerHTML = '<div class="page"><div class="card"><h2>Tracking</h2>' +
        "<p>No wave history is configured, so there is nothing to track. With " +
        "history supplied (one wave or many), this workspace provides the " +
        "summary, per-metric, per-segment and visualise tracking views.</p></div></div>";
      return;
    }
    var wrap = document.createElement("div");
    var years = trk.years();
    wrap.innerHTML = '<div class="page"><div class="trkbar">' +
      "<h2>Tracking · " + years[0] + "–" + TR.render.currentYear() + "</h2>" +
      '<nav class="trksubs">' + SUBS.map(function (s) {
        return '<button class="btab' + (trk.state.sub === s[0] ? " on" : "") +
          '" data-sub="' + s[0] + '">' + s[1] + "</button>";
      }).join("") + "</nav>" +
      (TR.d2.filtersActive()
        ? '<span class="trkfilternote">⚠ report filters do not apply here — ' +
          "tracking always compares published figures</span>" : "") +
      "</div><div id='trkhost'></div></div>";
    host.replaceChildren(wrap);
    wrap.querySelectorAll("[data-sub]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk.state.sub = btn.getAttribute("data-sub");
        views.whatMoved(host);
      });
    });
    var sub = document.getElementById("trkhost");
    if (trk.state.sub === "metrics") renderMetrics(sub);
    else if (trk.state.sub === "segments") TR.trkVis.renderSegments(sub);
    else if (trk.state.sub === "visualise") TR.trkVis.renderVisualise(sub);
    else TR.trkSummary.render(sub);
  };

  /** Re-render the active sub-view in place (state already updated). */
  trk.rerender = function () {
    views.whatMoved(document.getElementById("tabhost"));
  };

  /* ---------------- Metrics view ---------------- */

  function applySort(list, sortSpec) {
    var byDelta = function (a, b) {
      var da = a.last, db = b.last;
      if (!da && !db) return 0;
      if (!da) return 1;
      if (!db) return -1;
      if (da.sig_prev !== db.sig_prev) return da.sig_prev ? -1 : 1;
      return Math.abs(db.change_prev || 0) - Math.abs(da.change_prev || 0);
    };
    list.sort(function (a, b) {
      var v;
      if (sortSpec.col === "question") v = a.code < b.code ? -1 : 1;
      else if (sortSpec.col === "cur") {
        v = ((b.last && b.last.value) || -1e9) - ((a.last && a.last.value) || -1e9);
      } else v = byDelta(a, b);
      return sortSpec.dir === "asc" ? -v : v;
    });
  }

  function changeCell(cell, isMean, vsBase) {
    var change = vsBase ? cell.change_base : cell.change_prev;
    var sig = vsBase ? cell.sig_base : cell.sig_prev;
    if (change === null || change === undefined) return '<td class="wv dnone">–</td>';
    var up = change >= 0;
    return '<td class="wv ' + (up ? "up" : "down") + (sig ? " dsig" : "") +
      '" title="' + (vsBase ? "vs baseline wave" : "vs previous wave") +
      (sig ? " · significant at 95%" : "") + '">' +
      (up ? "▲ +" : "▼ −") + Math.abs(change).toFixed(isMean ? 1 : 0) +
      (isMean ? "" : "pp") + "</td>";
  }

  function renderMetrics(host) {
    var s = trk.state;
    var years = trk.years();
    var scope = s.scope || TR.d2.tracking().defaultScope;
    var segments = TR.waves.segments();
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var entries = trk.metricList(scope).map(function (metric) {
      var cells = trk.points(metric, s.segment);
      var byYear = {};
      cells.forEach(function (c) { if (!c.current) byYear[c.year] = c; });
      return { code: metric.code, title: metric.title, category: metric.category,
        label: metric.label, kind: metric.kind, diff: metric.diff,
        isMean: metric.isMean, key: metric.key, metric: metric,
        byYear: byYear, cells: cells,
        last: cells.length && cells[cells.length - 1].current
          ? cells[cells.length - 1] : null };
    }).filter(function (e) { return e.cells.length; });
    applySort(entries, sort || { col: "change", dir: "desc" });
    var cats = {};
    TR.AGG.questions.forEach(function (q) { cats[q.category] = true; });
    var th = views._th;
    var segPicker = '<select data-trkseg><option value="">Total</option>' +
      segments.map(function (seg) {
        return '<option value="' + seg.norm + '"' +
          (s.segment === seg.norm ? " selected" : "") + ">" +
          fmt.escapeHtml(seg.label) + " (" + seg.years[0] + "–" +
          seg.years[seg.years.length - 1] + ")</option>";
      }).join("") + "</select>";

    var html = ['<div class="card trkcard"><p>Published values per wave for ' +
      "<strong>" + (s.segment ? fmt.escapeHtml(trk.segmentByNorm(s.segment).label)
        : "Total") + "</strong>. <strong>Δ prev</strong> = latest vs the most " +
      "recent wave carrying the metric, <strong>Δ first</strong> = vs its " +
      "baseline; outlined = significant at 95% (pooled z, bases under " + threshold +
      " excluded). Hover wave cells for bases; click a question to drill down.</p>" +
      '<div class="scopebar"><button class="btab' + (scope === "key" ? " on" : "") +
      '" data-scope="key">Key metrics</button>' +
      '<button class="btab' + (scope === "all" ? " on" : "") +
      '" data-scope="all">All tracked rows</button>' + segPicker +
      '<input id="trk-search" type="search" placeholder="Search metrics…">' +
      '<select id="trk-cat"><option value="">All sections</option>' +
      Object.keys(cats).map(function (c) {
        return '<option value="' + fmt.escapeHtml(c) + '">' + fmt.escapeHtml(c) +
          "</option>";
      }).join("") + "</select></div>" +
      '<div class="trkwrap"><table class="moved trk"><thead><tr>' +
      th("question", "Question", sort) + "<th>Metric</th>" +
      years.map(function (y) { return "<th class='wv'>" + y + "</th>"; }).join("") +
      th("cur", String(TR.render.currentYear()), sort) + "<th>Trend</th>" +
      th("change", "Δ prev", sort) + "<th>Δ first</th>" +
      "</tr></thead><tbody>"];
    entries.slice(0, MAX_ROWS).forEach(function (e) {
      var cells = ['<td><button class="linklike" data-goq="' + e.code + '">' +
        e.code + " · " + fmt.escapeHtml(TR.charts.clip(e.title, 38)) +
        "</button></td>",
        '<td><button class="linklike" data-seg-metric="' + e.key + '">' +
        fmt.escapeHtml(TR.charts.clip(e.label, 30)) + "</button>" +
        (e.kind !== "category"
          ? ' <span class="kindtag">' + (e.diff ? "net diff" : e.kind) + "</span>"
          : "") + "</td>"];
      years.forEach(function (y) {
        var c = e.byYear[y];
        var low = c && c.base !== null && c.base < threshold;
        cells.push(c
          ? '<td class="wv' + (low ? " lowb" : "") + '" title="' + y +
            " base n=" + fmt.base(c.base) +
            (low ? " — below " + threshold + ", excluded from significance" : "") +
            '">' + trk.fmtVal(c.value, e.isMean) + (low ? " ⚠" : "") + "</td>"
          : '<td class="wv none">–</td>');
      });
      cells.push('<td class="wv cur">' +
        (e.last ? trk.fmtVal(e.last.value, e.isMean) : "–") + "</td>");
      cells.push('<td class="sparkcell">' + TR.render.sparkline(
        e.cells.map(function (c) {
          return { year: c.year, value: c.value, current: c.current };
        }), e.isMean) + "</td>");
      cells.push(e.last ? changeCell(e.last, e.isMean, false)
        : '<td class="wv dnone">–</td>');
      cells.push(e.last ? changeCell(e.last, e.isMean, true)
        : '<td class="wv dnone">–</td>');
      html.push('<tr data-cat="' + fmt.escapeHtml(e.category) + '" data-search="' +
        fmt.escapeHtml((e.code + " " + e.title + " " + e.label).toLowerCase()) +
        '">' + cells.join("") + "</tr>");
    });
    html.push("</tbody></table></div>");
    var notes = [];
    if (entries.length > MAX_ROWS) {
      notes.push("Showing the top " + MAX_ROWS + " of " + entries.length +
        " tracked rows — search or filter to narrow.");
    }
    if (s.segment) {
      var seg = trk.segmentByNorm(s.segment);
      notes.push(seg.label + " history exists for " + seg.years.join(", ") +
        "; other waves were published without this segment.");
    }
    var newQ = trk.newQuestions();
    if (newQ.length) {
      notes.push(newQ.length + " questions are new in " + TR.render.currentYear() +
        " with no history; they appear in Crosstabs only.");
    }
    if (notes.length) {
      html.push('<p class="trknote">' + fmt.escapeHtml(notes.join("  ")) + "</p>");
    }
    html.push("</div>");
    host.innerHTML = html.join("");

    views._wireLinks(host);
    host.querySelectorAll("[data-seg-metric]").forEach(function (el) {
      el.addEventListener("click", function () {
        trk.state.metricKey = el.getAttribute("data-seg-metric");
        trk.state.sub = "segments";
        trk.rerender();
      });
    });
    host.querySelectorAll("[data-scope]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        trk.state.scope = btn.getAttribute("data-scope");
        trk.rerender();
      });
    });
    var segSel = host.querySelector("[data-trkseg]");
    if (segSel) {
      segSel.addEventListener("change", function () {
        trk.state.segment = segSel.value || null;
        trk.rerender();
      });
    }
    host.querySelectorAll("th[data-sort]").forEach(function (el) {
      el.addEventListener("click", function () {
        var col = el.getAttribute("data-sort");
        sort = (sort && sort.col === col && sort.dir === "desc")
          ? { col: col, dir: "asc" } : { col: col, dir: "desc" };
        trk.rerender();
      });
    });
    views._wireRowFilter(host, "trk-search", "trk-cat");
  }

})(typeof window !== "undefined" ? window : globalThis);
