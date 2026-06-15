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
    if (item.segments && models.length === 1) {
      // round-5 pins without an explicit title
      return models[0].code + " · " + TR.charts.clip(models[0].title, 56) +
        " — " + TR.charts.clip(item.metricLabel || "", 26) + " · by segment";
    }
    if (models.length === 1) return models[0].code + " — " + models[0].title;
    return "Composite — " + models.length + " tracked metrics";
  };

  /* ---------- series exhibits (pinned tracking Visualise views) ---------- */

  /** Explicit series list of a pinned view: [{code, ri, label, seg}].
   *  Round-5 pins stored {segments, metricRi, metricLabel} — normalise. */
  function seriesList(item, models) {
    if (item.series) return item.series;
    if (item.segments) {
      var model = models[0];
      var ri = item.metricRi || 0;
      return item.segments.map(function (id) {
        var seg = id === "total" ? null : TR.trk.segmentByNorm(id);
        return { code: model.code, ri: ri, seg: id,
          label: seg ? seg.label : "Total" };
      });
    }
    return null;
  }

  function isSeriesItem(item) {
    return !!(item.series || item.segments);
  }

  function seriesMetric(models, entry) {
    var model = models.filter(function (m) { return m.code === entry.code; })[0];
    if (!model) return null;
    var row = model.rows[entry.ri];
    if (!row) return null;
    return { q: TR.d2.questionByCode(entry.code), code: entry.code,
      title: model.title, label: row.label, kind: row.kind,
      isMean: row.kind === "mean", diff: !!row.diff, ri: entry.ri, row: row };
  }

  /** One pseudo trend row per pinned series (current point embedded). */
  function seriesPseudoRows(item, models) {
    return (seriesList(item, models) || []).map(function (entry) {
      var metric = seriesMetric(models, entry);
      if (!metric) return null;
      var points = TR.trk.points(metric,
        entry.seg === "total" ? null : entry.seg);
      if (!points.length) return null;
      return { kind: metric.kind, diff: metric.diff, label: entry.label,
        isMean: metric.isMean, waves: points,
        // runtime-only refs for the interval-band callback (never persisted)
        _metric: metric, _seg: entry.seg,
        cells: [{ pct: null, mean: null, n: null, sig: "" }] };
    }).filter(Boolean);
  }

  /** Interval-band callback for pinned Visualise views (item.ci). The
   *  bounds come from the same ciBounds the live view uses. */
  function seriesCi(item) {
    if (!item.ci) return null;
    return function (row, point) {
      return row._metric
        ? TR.trkVis._ciBounds(row._metric,
            row._seg === "total" ? "total" : row._seg, point)
        : null;
    };
  }

  function curOf(row) {
    return row.kind === "mean" ? row.cells[0].mean : row.cells[0].pct;
  }

  function shortLabel(model, row) {
    // question TEXT first — codes are meaningless on a chart; generous
    // clips only (chart labels and legends wrap, table cells wrap)
    return TR.charts.clip(model.title, 120) + " · " +
      TR.charts.clip(row.label, 40);
  }

  /**
   * Composite metrics share one chart axis only within a scale family:
   * 0–10 means vs everything else (%/Index/NPS on 0–100). The dominant
   * family plots; the rest are named in a note under the chart and stay
   * in the table. The trend chart applies the same rule internally —
   * this keeps the two exhibit panels consistent.
   */
  function dominantScale(entries, maxOf, isMeanOf) {
    var isSmall = function (e) { return isMeanOf(e) && maxOf(e) <= 10; };
    var small = entries.filter(isSmall);
    var large = entries.filter(function (e) { return !isSmall(e); });
    var keep = small.length > large.length ? small : large;
    var dropped = small.length > large.length ? large : small;
    return { keep: keep, dropped: dropped };
  }

  function waveMax(waves, current) {
    var max = current === null || current === undefined ? 0 : Math.abs(current);
    (waves || []).forEach(function (w) {
      if (w.value !== null && Math.abs(w.value) > max) max = Math.abs(w.value);
    });
    return max;
  }

  /** Distribution panel model: real for one question, headline bars for
   *  many — restricted to the dominant scale family (model._dropped names
   *  what the chart cannot carry; the table keeps everything). */
  exhibit.distModel = function (item, models) {
    if (isSeriesItem(item)) {
      var split = dominantScale(seriesPseudoRows(item, models),
        function (r) {
          return waveMax(r.waves, null);
        },
        function (r) { return !!r.isMean; });
      var rows = split.keep.map(function (r) {
        var last = r.waves[r.waves.length - 1];
        return { kind: "category", label: r.label,
          cells: [{ pct: last.value, n: null, mean: null, sig: "" }] };
      });
      return { code: models[0].code, title: "This wave",
        source: "published", chartKind: "detail", lowBaseThreshold: 30,
        columns: [{ label: "Total", letter: "", base: null, low: false }],
        rows: rows,
        _dropped: split.dropped.map(function (r) { return r.label; }) };
    }
    if (models.length === 1) {
      var m = models[0];
      m.chartKind = item.chartKind || m.chartKind || "auto";
      m.hiddenChartRows = item.hiddenChartRows || [];
      return m;
    }
    var entries = [];
    models.forEach(function (m) {
      var row = exhibit.headlineRow(m);
      if (row) entries.push({ m: m, row: row });
    });
    var compSplit = dominantScale(entries,
      function (e) { return waveMax(e.row.waves, curOf(e.row)); },
      function (e) { return e.row.kind === "mean"; });
    return { code: "COMPOSITE", title: "This wave", source: "published",
      chartKind: "detail", lowBaseThreshold: 30,
      columns: [{ label: "Total", letter: "", base: null, low: false }],
      rows: compSplit.keep.map(function (e) {
        return { kind: "category", label: shortLabel(e.m, e.row),
          cells: [{ pct: curOf(e.row), n: null, mean: null, sig: "" }] };
      }),
      _dropped: compSplit.dropped.map(function (e) {
        return shortLabel(e.m, e.row);
      }) };
  };

  /** Trend panel model: real for one question, headline series for many. */
  exhibit.trendModel = function (item, models) {
    if (isSeriesItem(item)) {
      return { code: models[0].code, title: "Trend",
        source: "published", chartKind: "summary", lowBaseThreshold: 30,
        columns: [{ label: "Total", letter: "", base: null, low: false }],
        rows: seriesPseudoRows(item, models) };
    }
    if (models.length === 1) {
      var m = models[0];
      m.chartKind = item.chartKind || m.chartKind || "auto";
      m.hiddenChartRows = item.hiddenChartRows || [];
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

  /** Metric × wave matrix (also the PPTX table): one row per question
   *  (composites) or one row per segment (pinned tracking views). */
  exhibit.matrix = function (item, models) {
    var years = TR.d2.tracking().waves.map(function (w) { return w.year; });
    var curYear = TR.render.currentYear();
    var head = ["Metric"].concat(years).concat([String(curYear), "Δ prev", "Δ first"]);
    var body = [];
    if (isSeriesItem(item)) {
      seriesPseudoRows(item, models).forEach(function (r) {
        var isMean = !!r.isMean;
        var byYear = {};
        r.waves.forEach(function (c) { byYear[c.year] = c; });
        var last = r.waves[r.waves.length - 1];
        body.push({ kind: "row", cells: [r.label]
          .concat(years.map(function (y) {
            return byYear[y] && !byYear[y].current
              ? fmtVal(byYear[y].value, isMean) : "–";
          }))
          .concat([fmtVal(last.value, isMean),
            deltaText(last.change_prev === null ? null
              : { diff: last.change_prev, sig: last.sig_prev, isMean: isMean }),
            deltaText(last.change_base === null ? null
              : { diff: last.change_base, sig: last.sig_base, isMean: isMean })]) });
      });
      return { head: head, body: body };
    }
    models.forEach(function (m) {
      var row = exhibit.headlineRow(m);
      if (!row) return;
      var isMean = row.kind === "mean";
      var byYear = {};
      (row.waves || []).forEach(function (w) { byYear[w.year] = w; });
      body.push({ kind: "row", cells:
        [shortLabel(m, row)]
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
      if (dist._dropped && dist._dropped.length) {
        out.push('<p class="trknote">Different scale — not on this chart, ' +
          "see the table: " +
          fmt.escapeHtml(dist._dropped.join(" · ")) + "</p>");
      }
    }
    if (flags.trend) {
      out.push('<div class="chart ex-chart">' +
        TR.render.trendChart(exhibit.trendModel(item, models),
          { annotations: item.annotations || [],
            ci: seriesCi(item) }) + "</div>");
    }
    if (flags.table) {
      out.push('<div class="si-table">' +
        tableHtml(exhibit.matrix(item, models)) + "</div>");
    }
    return out.join("");
  };

  /** Interval kind of a pinned series list: the bands use Wilson for
   *  proportion metrics but z·SD/√n for mean/Index/NPS — the context
   *  line must name the method that actually drew them. */
  function seriesIntervalKind(item, models) {
    var means = 0, props = 0;
    (seriesList(item, models) || []).forEach(function (entry) {
      var metric = seriesMetric(models, entry);
      if (!metric) return;
      if (metric.isMean) means++; else props++;
    });
    if (means && props) return "mixed";
    return means ? "means" : "props";
  }

  exhibit.contextLine = function (item, models) {
    if (isSeriesItem(item)) {
      var labels = (seriesList(item, models) || []).map(function (e) {
        return e.label;
      });
      return "Series: " + labels.join(" · ") + " · published wave history" +
        (item.ci ? " · " +
          TR.conf.methodNote(seriesIntervalKind(item, models)) + " bands" : "");
    }
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
    var scaleNote = "";
    if (flags.dist) {
      var type = item.distType === "line" ? "column" : (item.distType || "column");
      var dist = exhibit.distModel(item, models);
      var chart = TR.exporter.buildChart(dist,
        type, item.chartCols && item.chartCols.length ? item.chartCols : [0]);
      if (chart) charts.push(chart);
      if (dist._dropped && dist._dropped.length) {
        scaleNote = " · different scale, table only: " +
          dist._dropped.join(" · ");
      }
    }
    if (flags.trend) {
      var trend = TR.exporter.buildTrendChart(exhibit.trendModel(item, models));
      if (trend) charts.push(trend);
    }
    return TR.exporter.exhibitSlide({
      title: exhibit.titleFor(item, models),
      meta: exhibit.contextLine(item, models) + scaleNote,
      charts: charts,
      matrix: flags.table ? exhibit.matrix(item, models) : null,
      note: (flags.insight !== false && item.note) ? item.note : ""
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
