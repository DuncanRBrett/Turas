/**
 * Exhibit engine — the two-panel trend exhibit (this-wave distribution
 * chart + line-over-waves chart below) and its cross-section composite
 * generalisation: any questions, any mix of distribution / trend / table.
 * One item kind ("exhibit") powers the story card, present mode and the
 * PPTX slide with one NATIVE chart object per panel (rels rId2+k).
 *
 * Single-question exhibits chart the real view model; multi-question
 * exhibits chart each question's HEADLINE tracked metric (Index/NPS mean
 * first, then top NET, then NET POSITIVE) as one series/bar per question.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var exhibit = TR.exhibit = {};

  /** Headline tracked row of a model: mean > NET > NET POSITIVE > category. */
  exhibit.headlineRow = function (model) {
    var priority = function (r) {
      if (r.kind === "mean") return 0;
      if (r.kind === "net" && !r.diff) return 1;
      if (r.diff) return 2;
      return 3;
    };
    var rows = model.rows.filter(function (r) {
      return r.waves && r.waves.length;
    }).sort(function (a, b) { return priority(a) - priority(b); });
    return rows[0] || null;
  };

  exhibit.models = function (item) {
    return (item.qs || []).map(function (code) {
      return TR.model.forQuestion(code, item.banner, item.filters || [],
        { hiddenCols: [] });
    }).filter(Boolean);
  };

  exhibit.titleFor = function (item, models) {
    if (item.title) return item.title;
    if (models.length === 1) return models[0].code + " — " + models[0].title;
    return "Composite — " + models.length + " tracked metrics";
  };

  function curOf(row) {
    return row.kind === "mean" ? row.cells[0].mean : row.cells[0].pct;
  }

  function shortLabel(model, row) {
    return model.code + " · " + TR.charts.clip(model.title, 26);
  }

  /** Distribution panel model: real for one question, headline bars for many. */
  exhibit.distModel = function (item, models) {
    if (models.length === 1) {
      var m = models[0];
      m.chartKind = item.chartKind || m.chartKind || "auto";
      return m;
    }
    var rows = [];
    models.forEach(function (m) {
      var row = exhibit.headlineRow(m);
      if (!row) return;
      rows.push({ kind: "category", label: shortLabel(m, row),
        cells: [{ pct: curOf(row), n: null, mean: null, sig: "" }] });
    });
    return { code: "COMPOSITE", title: "This wave", source: "published",
      chartKind: "detail", lowBaseThreshold: 30,
      columns: [{ label: "Total", letter: "", base: null, low: false }],
      rows: rows };
  };

  /** Trend panel model: real for one question, headline series for many. */
  exhibit.trendModel = function (item, models) {
    if (models.length === 1) {
      var m = models[0];
      m.chartKind = item.chartKind || m.chartKind || "auto";
      return m;
    }
    var rows = [];
    models.forEach(function (m) {
      var row = exhibit.headlineRow(m);
      if (!row) return;
      rows.push({ kind: row.kind, diff: row.diff, label: shortLabel(m, row),
        waves: row.waves, delta: row.delta, cells: [row.cells[0]] });
    });
    return { code: "COMPOSITE", title: "Trend", source: "published",
      chartKind: "summary", lowBaseThreshold: 30,
      columns: [{ label: "Total", letter: "", base: null, low: false }],
      rows: rows };
  };

  function fmtVal(v, isMean) {
    if (v === null || v === undefined) return "–";
    return isMean ? (Math.round(v * 10) / 10).toString() : Math.round(v) + "%";
  }

  function deltaText(d) {
    if (!d) return "–";
    return (d.diff >= 0 ? "▲ +" : "▼ −") +
      Math.abs(d.diff).toFixed(d.isMean ? 1 : 0) + (d.isMean ? "" : "pp") +
      (d.sig ? " •" : "");
  }

  /** Metric × wave matrix (also the PPTX table): one row per question. */
  exhibit.matrix = function (item, models) {
    var years = TR.d2.tracking().waves.map(function (w) { return w.year; });
    var curYear = TR.render.currentYear();
    var head = ["Metric"].concat(years).concat([String(curYear), "Δ prev", "Δ first"]);
    var body = [];
    models.forEach(function (m) {
      var row = exhibit.headlineRow(m);
      if (!row) return;
      var isMean = row.kind === "mean";
      var byYear = {};
      (row.waves || []).forEach(function (w) { byYear[w.year] = w; });
      body.push({ kind: "row", cells:
        [shortLabel(m, row) + " — " + TR.charts.clip(row.label, 20)]
          .concat(years.map(function (y) {
            return byYear[y] ? fmtVal(byYear[y].value, isMean) : "–";
          }))
          .concat([fmtVal(curOf(row), isMean),
            deltaText(row.delta), deltaText(row.deltaBase)]) });
    });
    return { head: head, body: body };
  };

  function tableHtml(matrix) {
    return '<table class="ct"><thead><tr>' + matrix.head.map(function (h, i) {
      return '<th class="' + (i === 0 ? "lab" : "") + '">' +
        fmt.escapeHtml(String(h)) + "</th>";
    }).join("") + "</tr></thead><tbody>" + matrix.body.map(function (row) {
      return "<tr>" + row.cells.map(function (cell, i) {
        return "<td" + (i === 0 ? ' class="lab"' : "") + ">" +
          fmt.escapeHtml(String(cell)) + "</td>";
      }).join("") + "</tr>";
    }).join("") + "</tbody></table>";
  }

  /** Distribution / trend / table panels as HTML (story card + present). */
  exhibit.panelsHtml = function (item) {
    var models = exhibit.models(item);
    if (!models.length) return "";
    var flags = item.flags || {};
    var out = [];
    if (flags.dist) {
      var dist = exhibit.distModel(item, models);
      var type = item.distType === "line" ? "column" : (item.distType || "column");
      out.push('<div class="chart ex-chart">' +
        TR.render.chartBy(type, dist, item.chartCols || [0]) + "</div>");
    }
    if (flags.trend) {
      out.push('<div class="chart ex-chart">' +
        TR.render.trendChart(exhibit.trendModel(item, models)) + "</div>");
    }
    if (flags.table) {
      out.push('<div class="si-table">' +
        tableHtml(exhibit.matrix(item, models)) + "</div>");
    }
    return out.join("");
  };

  exhibit.contextLine = function (item, models) {
    var bits = [TR.d2.bannerDescription(item.banner),
      "history: published wave Totals"];
    if (item.filters && item.filters.length) {
      bits.push("Filtered " + TR.render.currentYear() + " column");
    }
    return bits.join(" · ");
  };

  /** PPTX slide: one native chart object per visible chart panel. */
  exhibit.slide = function (item) {
    var models = exhibit.models(item);
    if (!models.length) return null;
    var flags = item.flags || {};
    var charts = [];
    if (flags.dist) {
      var type = item.distType === "line" ? "column" : (item.distType || "column");
      var chart = TR.exporter.buildChart(exhibit.distModel(item, models),
        type, item.chartCols && item.chartCols.length ? item.chartCols : [0]);
      if (chart) charts.push(chart);
    }
    if (flags.trend) {
      var trend = TR.exporter.buildTrendChart(exhibit.trendModel(item, models));
      if (trend) charts.push(trend);
    }
    return TR.exporter.exhibitSlide({
      title: exhibit.titleFor(item, models),
      meta: exhibit.contextLine(item, models),
      charts: charts,
      matrix: flags.table ? exhibit.matrix(item, models) : null,
      note: (flags.insight !== false && item.note) ? item.note : ""
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
