/**
 * v2 Tracking view — tracker-module parity over the wave history: every
 * tracked metric as a row with column-per-wave published values, an
 * inline sparkline, change vs the previous wave AND vs the baseline wave
 * (pooled-z sig flags on both), per-wave bases in tooltips, drill-down,
 * search / section filter / sort, and key-vs-all scope. Renders entirely
 * from view models, so the current-wave column respects live filters.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var views = TR.views;
  var trkSort = null;           // {col, dir}
  var MAX_ROWS = 200;

  function fmtVal(v, isMean) {
    if (v === null || v === undefined) return "–";
    return isMean ? (Math.round(v * 10) / 10).toString() : Math.round(v) + "%";
  }

  function collectMetrics(scope) {
    var metrics = [], newQ = [];
    TR.AGG.questions.forEach(function (q) {
      var model = views._modelFor(q.code);
      if (!model.prevWave) { newQ.push(q.code); return; }
      model.rows.forEach(function (row) {
        if (!row.waves || !row.waves.length) return;
        if (scope === "key" && row.kind === "category") return;
        var byYear = {};
        row.waves.forEach(function (w) { byYear[w.year] = w; });
        metrics.push({ code: q.code, title: q.title, category: q.category,
          label: row.label, kind: row.kind, isMean: row.kind === "mean",
          byYear: byYear, row: row, delta: row.delta || null,
          deltaBase: row.deltaBase || null,
          cur: row.kind === "mean" ? row.cells[0].mean : row.cells[0].pct });
      });
    });
    return { metrics: metrics, newQ: newQ };
  }

  function applySort(metrics, sort) {
    var byDelta = function (a, b, key) {
      var da = a[key], db = b[key];
      if (!da && !db) return 0;
      if (!da) return 1;
      if (!db) return -1;
      if (da.sig !== db.sig) return da.sig ? -1 : 1;
      return Math.abs(db.diff) - Math.abs(da.diff);
    };
    metrics.sort(function (a, b) {
      var v;
      if (sort.col === "question") v = a.code < b.code ? -1 : 1;
      else if (sort.col === "cur") v = (b.cur || 0) - (a.cur || 0);
      else if (sort.col === "base") v = byDelta(a, b, "deltaBase");
      else v = byDelta(a, b, "delta");
      return sort.dir === "asc" ? -v : v;
    });
  }

  function deltaCell(d) {
    if (!d) return '<td class="wv dnone">–</td>';
    var up = d.diff >= 0;
    return '<td class="wv ' + (up ? "up" : "down") + (d.sig ? " dsig" : "") +
      '" title="vs ' + d.year + ": " + fmtVal(d.prev, d.isMean) +
      (d.sig ? " · significant at 95%" : "") + '">' +
      (up ? "▲ +" : "▼ −") + Math.abs(d.diff).toFixed(d.isMean ? 1 : 0) +
      (d.isMean ? "" : "pp") + "</td>";
  }

  function metricRow(m, years) {
    var cells = ['<td><button class="linklike" data-goq="' + m.code + '">' +
      m.code + " · " + fmt.escapeHtml(TR.charts.clip(m.title, 38)) +
      "</button></td>",
      "<td>" + fmt.escapeHtml(TR.charts.clip(m.label, 30)) +
      (m.kind !== "category"
        ? ' <span class="kindtag">' + (m.row.diff ? "net diff" : m.kind) + "</span>"
        : "") + "</td>"];
    var threshold = TR.AGG.project.low_base_threshold || 30;
    years.forEach(function (year) {
      var w = m.byYear[year];
      var low = w && w.base !== null && w.base < threshold;
      cells.push(w
        ? '<td class="wv' + (low ? " lowb" : "") + '" title="' + year +
          " base n=" + fmt.base(w.base) +
          (low ? " — below " + threshold + ", excluded from significance" : "") +
          '">' + fmtVal(w.value, m.isMean) + (low ? " ⚠" : "") + "</td>"
        : '<td class="wv none">–</td>');
    });
    cells.push('<td class="wv cur">' + fmtVal(m.cur, m.isMean) + "</td>");
    cells.push('<td class="sparkcell">' +
      TR.render.sparkline(TR.render.wavePoints(m.row), m.isMean) + "</td>");
    cells.push(deltaCell(m.delta));
    cells.push(deltaCell(m.deltaBase));
    return '<tr data-cat="' + fmt.escapeHtml(m.category) + '" data-search="' +
      fmt.escapeHtml((m.code + " " + m.title + " " + m.label).toLowerCase()) +
      '">' + cells.join("") + "</tr>";
  }

  views.whatMoved = function (host) {
    if (!TR.d2.tracking().enabled) {
      host.innerHTML = '<div class="page"><div class="card"><h2>Tracking</h2>' +
        "<p>No wave history is configured, so there is nothing to track. With " +
        "history supplied (one wave or many), this tab shows every tracked " +
        "metric across waves with sparklines and significance-tested change.</p>" +
        "</div></div>";
      return;
    }
    var years = TR.d2.tracking().waves.map(function (w) { return w.year; });
    var curYear = TR.render.currentYear();
    var scope = TR.d2.state.movedScope || TR.d2.tracking().defaultScope;
    var collected = collectMetrics(scope);
    var sort = trkSort || { col: "change", dir: "desc" };
    applySort(collected.metrics, sort);
    var cats = {};
    TR.AGG.questions.forEach(function (q) { cats[q.category] = true; });
    var th = views._th;

    var html = ['<div class="page"><div class="card trkcard">' +
      "<h2>Tracking · " + years[0] + "–" + curYear + "</h2>" +
      "<p>Published wave Totals for every tracked metric" +
      (TR.d2.filtersActive()
        ? " — <strong>filters apply to the " + curYear + " column only</strong>" +
          " (history has no respondent-level data)"
        : "") +
      ". <strong>Δ prev</strong> compares " + curYear + " with the most " +
      "recent wave carrying the metric, <strong>Δ first</strong> with its " +
      "baseline wave; outlined chips are significant at 95% (pooled z on " +
      "published bases). Hover any wave for its base; click a question to " +
      "drill into the full crosstab with the trend chart.</p>" +
      '<div class="scopebar"><button class="btab' + (scope === "key" ? " on" : "") +
      '" data-scope="key">Key metrics · NPS, indexes &amp; NETs</button>' +
      '<button class="btab' + (scope === "all" ? " on" : "") +
      '" data-scope="all">All tracked rows</button>' +
      '<input id="trk-search" type="search" placeholder="Search metrics…">' +
      '<select id="trk-cat"><option value="">All sections</option>' +
      Object.keys(cats).map(function (c) {
        return '<option value="' + fmt.escapeHtml(c) + '">' +
          fmt.escapeHtml(c) + "</option>";
      }).join("") + "</select></div>" +
      '<div class="trkwrap"><table class="moved trk"><thead><tr>' +
      th("question", "Question", sort) + "<th>Metric</th>" +
      years.map(function (y) { return "<th class='wv'>" + y + "</th>"; }).join("") +
      th("cur", String(curYear), sort) + "<th>Trend</th>" +
      th("change", "Δ prev", sort) + th("base", "Δ first", sort) +
      "</tr></thead><tbody>"];
    collected.metrics.slice(0, MAX_ROWS).forEach(function (m) {
      html.push(metricRow(m, years));
    });
    html.push("</tbody></table></div>");
    var notes = [];
    if (collected.metrics.length > MAX_ROWS) {
      notes.push("Showing the top " + MAX_ROWS + " of " +
        collected.metrics.length + " tracked rows — search or filter to narrow.");
    }
    if (collected.newQ.length) {
      notes.push(collected.newQ.length + " questions are new in " + curYear +
        " with no history; they appear in Crosstabs only.");
    }
    if (notes.length) {
      html.push('<p class="trknote">' + fmt.escapeHtml(notes.join("  ")) + "</p>");
    }
    html.push("</div></div>");
    host.innerHTML = html.join("");

    views._wireLinks(host);
    host.querySelectorAll("[data-scope]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        TR.d2.state.movedScope = btn.getAttribute("data-scope");
        views.whatMoved(host);
      });
    });
    host.querySelectorAll("th[data-sort]").forEach(function (el) {
      el.addEventListener("click", function () {
        var col = el.getAttribute("data-sort");
        trkSort = (trkSort && trkSort.col === col && trkSort.dir === "desc")
          ? { col: col, dir: "asc" } : { col: col, dir: "desc" };
        views.whatMoved(host);
      });
    });
    views._wireRowFilter(host, "trk-search", "trk-cat");
  };

})(typeof window !== "undefined" ? window : globalThis);
