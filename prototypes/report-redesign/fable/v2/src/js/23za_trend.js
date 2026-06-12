/**
 * Trend visuals over wave history — the inline sparkline used by tracking
 * rows and wave strips, and the full "line over waves" chart (chart type
 * "line"). Series points are published wave Totals (row.waves from
 * TR.waves.attachDeltas) plus the current wave's Total cell; banner
 * columns are deliberately ignored — history has no banner cuts.
 */
(function (global) {
  "use strict";
  var TR = global.TR, S = TR.svg;

  var render = TR.render;

  render.CHART_TYPES.push(["line", "Trend · waves"]);

  /** Current-wave year parsed from project.wave ("Annual 2025" -> 2025). */
  render.currentYear = function () {
    var m = /(\d{4})/.exec((TR.AGG.project && TR.AGG.project.wave) || "");
    return m ? parseInt(m[1], 10) : null;
  };

  /** Full point list for a model row: history + the current Total value.
   *  Rows whose .waves already embed the current point (Visualise pseudo
   *  rows) keep it — nothing is appended when the cells carry no value. */
  render.wavePoints = function (row) {
    var points = (row.waves || []).map(function (w) {
      return { year: w.year, value: w.value, base: w.base,
        current: !!w.current };
    });
    var cur = row.kind === "mean" ? row.cells[0].mean : row.cells[0].pct;
    if (cur !== null && cur !== undefined) {
      points.push({ year: render.currentYear(), value: cur,
        base: null, current: true });
    }
    return points;
  };

  function fmtVal(v, isMean) {
    if (v === null || v === undefined) return "–";
    return isMean ? (Math.round(v * 10) / 10).toString() : Math.round(v) + "%";
  }

  /**
   * Inline sparkline for a tracking row. Pure SVG string (default 96x26),
   * scaled to the series' own min-max band; the current point is accented.
   */
  render.sparkline = function (points, isMean, opts) {
    if (!points || !points.length) return "";
    var W = (opts && opts.w) || 96, H = (opts && opts.h) || 26, pad = 4;
    var values = points.map(function (p) { return p.value; });
    var min = Math.min.apply(null, values), max = Math.max.apply(null, values);
    if (max - min < 1e-9) { max += 1; min -= 1; }
    var y0 = points[0].year, y1 = points[points.length - 1].year;
    var xOf = function (p) {
      return y1 === y0 ? W / 2 : pad + (p.year - y0) / (y1 - y0) * (W - pad * 2);
    };
    var yOf = function (p) {
      return H - pad - (p.value - min) / (max - min) * (H - pad * 2);
    };
    var path = points.map(function (p, i) {
      return (i ? "L" : "M") + xOf(p).toFixed(1) + " " + yOf(p).toFixed(1);
    }).join(" ");
    var body = [];
    if (points.length > 1) {
      body.push(S.el("path", { d: path, fill: "none",
        stroke: TR.charts.brandOf(), "stroke-width": 1.6,
        "stroke-linejoin": "round", "stroke-linecap": "round" }));
    }
    points.forEach(function (p) {
      body.push(S.el("circle", { cx: xOf(p).toFixed(1), cy: yOf(p).toFixed(1),
        r: p.current ? 2.6 : 1.6,
        fill: p.current ? TR.charts.accentOf() : TR.charts.brandOf() }));
    });
    var title = points.map(function (p) {
      return p.year + ": " + fmtVal(p.value, isMean);
    }).join(" · ");
    return '<svg class="spark" viewBox="0 0 ' + W + " " + H + '" width="' + W +
      '" height="' + H + '" role="img" aria-label="' +
      TR.fmt.escapeHtml(title) + '"><title>' + TR.fmt.escapeHtml(title) +
      "</title>" + body.join("") + "</svg>";
  };

  /**
   * Wave strip for a question card: per-wave bases + the headline tracked
   * metrics (means first, then NETs, then NET POSITIVE; max 3) with a
   * sparkline each and a jump to the full trend chart. "" when no history.
   */
  render.waveStripHtml = function (model) {
    if (!model.history || !model.history.length) return "";
    var fmt = TR.fmt;
    var years = model.history.map(function (h) { return h.year; });
    var curYear = render.currentYear();
    var priority = function (r) {
      if (r.kind === "mean") return 0;
      if (r.kind === "net" && !r.diff) return 1;
      if (r.diff) return 2;
      return 3;
    };
    var rows = model.rows.filter(function (r) {
      return r.waves && r.waves.length;
    }).sort(function (a, b) { return priority(a) - priority(b); }).slice(0, 3);
    if (!rows.length) return "";
    var threshold = model.lowBaseThreshold || 30;

    var out = ['<div class="wavestrip"><div class="ws-head">' +
      "<strong>Wave history</strong> · published Totals " + years[0] + "–" +
      curYear + '<button class="linklike" data-act="fulltrend" title="Switch ' +
      'the chart to the trend-over-waves type">full trend chart ↗</button></div>' +
      '<table class="ws"><thead><tr><th></th>'];
    years.forEach(function (y) { out.push('<th class="wv">' + y + "</th>"); });
    out.push('<th class="wv cur">' + curYear + "</th><th></th></tr></thead><tbody>");
    out.push('<tr class="ws-base"><td class="lab">Base (n=)</td>');
    model.history.forEach(function (h) {
      var low = h.base !== null && h.base < threshold;
      out.push('<td class="wv' + (low ? " lowb" : "") + '">' +
        fmt.base(h.base) + (low ? " ⚠" : "") + "</td>");
    });
    out.push('<td class="wv cur">' + fmt.base(model.columns[0].base) +
      "</td><td></td></tr>");
    rows.forEach(function (r) {
      var isMean = r.kind === "mean";
      var byYear = {};
      r.waves.forEach(function (w) { byYear[w.year] = w; });
      out.push('<tr><td class="lab">' +
        fmt.escapeHtml(TR.charts.clip(r.label, 36)) + "</td>");
      years.forEach(function (y) {
        var w = byYear[y];
        out.push(w ? '<td class="wv">' + fmtVal(w.value, isMean) + "</td>"
          : '<td class="wv none">–</td>');
      });
      var cur = isMean ? r.cells[0].mean : r.cells[0].pct;
      out.push('<td class="wv cur">' + fmtVal(cur, isMean) +
        (r.delta ? TR.render.deltaChip(r.delta) : "") + "</td>");
      out.push('<td class="sparkcell">' +
        render.sparkline(render.wavePoints(r), isMean, { w: 120, h: 30 }) +
        "</td></tr>");
    });
    out.push("</tbody></table></div>");
    return out.join("");
  };

  /** Rows to trend: summary prefers NET/mean/diff metrics, detail the cats.
   *  Shared with the native PPTX trend chart so both plot the same series. */
  render.trendRows = trendRows;
  function trendRows(model) {
    var withHistory = model.rows.filter(function (r) {
      return r.waves && r.waves.length;
    });
    var kind = model.chartKind === "summary" ? "summary"
      : model.chartKind === "detail" ? "detail" : "auto";
    var summary = withHistory.filter(function (r) { return r.kind !== "category"; });
    var detail = withHistory.filter(function (r) { return r.kind === "category"; });
    if (kind === "summary") return summary.length ? summary : detail;
    if (kind === "detail") return detail.length ? detail : summary;
    return summary.length ? summary : detail;
  }

  /**
   * Wave trend line chart for a question model (chart type "line").
   * One series per row with history; up to 6 series. Mean-scale rows
   * (0-10 means) and percentage/index rows never share an axis — the
   * dominant group wins and the rest are dropped with a note.
   * @param {object} [opts] - Visualise overrides: {yMin, yMax,
   *   labels: "auto"|"all"|"last"|"none", ci: (row, point) => halfwidth,
   *   note: axis note override, annotations: [{year, label}] (dashed
   *   markers), clickable: data-year attrs on points for tagging}.
   */
  render.trendChart = function (model, opts) {
    opts = opts || {};
    var rows = trendRows(model);
    if (!rows.length) return "";
    var small = rows.filter(function (r) {
      return r.kind === "mean" && Math.max.apply(null, r.waves.map(function (w) {
        return w.value;
      })) <= 10;
    });
    var pct = rows.filter(function (r) { return small.indexOf(r) === -1; });
    var meanScale = small.length > pct.length;
    rows = (meanScale ? small : pct).slice(0, 6);
    var dropped = trendRows(model).length - rows.length;

    var series = rows.map(function (r) {
      return { label: r.label, isMean: r.kind === "mean", row: r,
        points: render.wavePoints(r), sigNow: !!(r.delta && r.delta.sig) };
    });
    var years = [];
    series.forEach(function (s) {
      s.points.forEach(function (p) {
        if (p.year !== null && years.indexOf(p.year) === -1) years.push(p.year);
      });
    });
    years.sort();
    var lo = 0, hi = 0;
    series.forEach(function (s) {
      s.points.forEach(function (p) {
        if (p.value < lo) lo = p.value;
        if (p.value > hi) hi = p.value;
      });
    });
    var axisMax = meanScale ? Math.max(S.niceMax(hi), 10) : S.niceMax(hi);
    var axisMin = lo < 0 ? -S.niceMax(-lo) : 0;
    if (opts.yMax !== undefined && opts.yMax !== null) axisMax = opts.yMax;
    if (opts.yMin !== undefined && opts.yMin !== null) axisMin = opts.yMin;
    if (axisMax <= axisMin) axisMax = axisMin + 1;
    // % suffix only when every plotted series is a proportion
    var pctAxis = rows.every(function (r) { return r.kind !== "mean"; });

    var W = 660, H = 240, padL = 46, padR = 110, padT = 18, padB = 30;
    var plotW = W - padL - padR, plotH = H - padT - padB;
    var xOf = function (year) {
      return years.length === 1 ? padL + plotW / 2
        : padL + (years.indexOf(year)) / (years.length - 1) * plotW;
    };
    var yOf = function (v) {
      return padT + plotH - (v - axisMin) / (axisMax - axisMin) * plotH;
    };
    var palette = render.palette();
    var body = [];
    [0, 0.25, 0.5, 0.75, 1].forEach(function (f) {
      var v = axisMin + (axisMax - axisMin) * f;
      body.push(S.el("line", { x1: padL, y1: yOf(v), x2: padL + plotW,
        y2: yOf(v), stroke: f === 0 ? "#d8dcea" : "#eef0f7" }));
      body.push(S.text(padL - 6, yOf(v) + 3,
        meanScale ? (Math.round(v * 10) / 10)
          : Math.round(v) + (pctAxis ? "%" : ""),
        { "text-anchor": "end", "font-size": 9.5, fill: "#9aa1b1" }));
    });
    years.forEach(function (year) {
      body.push(S.text(xOf(year), padT + plotH + 16, String(year),
        { "text-anchor": "middle", "font-size": 10, fill: "#6b7280" }));
    });
    // analyst annotations: dashed marker + label at the tagged wave
    (opts.annotations || []).forEach(function (a) {
      if (years.indexOf(a.year) === -1) return;
      var ax = xOf(a.year);
      body.push(S.el("line", { x1: ax, y1: padT, x2: ax, y2: padT + plotH,
        stroke: "#a8842c", "stroke-width": 1.2, "stroke-dasharray": "4 3" }));
      body.push(S.text(ax + 4, padT + 9, TR.charts.clip(a.label, 26),
        { "font-size": 9, "font-style": "italic", fill: "#a8842c" }));
    });
    var clampY = function (v) {
      return Math.max(padT, Math.min(padT + plotH, yOf(v)));
    };
    var labelMode = opts.labels || "auto";
    var endLabels = [];
    series.forEach(function (s, k) {
      var colour = palette[k % palette.length];
      // optional 95% interval band behind the line (Visualise toggle).
      // opts.ci returns absolute {lo, hi} bounds — Wilson intervals are
      // asymmetric around the value, so the band is NOT value ± half.
      if (opts.ci) {
        var banded = [];
        s.points.forEach(function (p) {
          var bounds = opts.ci(s.row || s, p);
          if (bounds) banded.push({ x: xOf(p.year), bounds: bounds });
        });
        if (banded.length > 1) {
          var upper = banded.map(function (e, i) {
            return (i ? "L" : "M") + e.x.toFixed(1) + " " +
              clampY(e.bounds.hi).toFixed(1);
          }).join(" ");
          var lower = banded.slice().reverse().map(function (e) {
            return "L" + e.x.toFixed(1) + " " +
              clampY(e.bounds.lo).toFixed(1);
          }).join(" ");
          body.push(S.el("path", { d: upper + lower + " Z", fill: colour,
            "fill-opacity": 0.12, stroke: "none" }));
        }
      }
      var d = s.points.map(function (p, i) {
        return (i ? "L" : "M") + xOf(p.year).toFixed(1) + " " +
          yOf(p.value).toFixed(1);
      }).join(" ");
      if (s.points.length > 1) {
        body.push(S.el("path", { d: d, fill: "none", stroke: colour,
          "stroke-width": 2.2, "stroke-linejoin": "round" }));
      }
      var labelAll = labelMode === "all" ||
        (labelMode === "auto" && series.length === 1);
      s.points.forEach(function (p, pi) {
        var dot = { cx: xOf(p.year).toFixed(1), cy: yOf(p.value).toFixed(1),
          r: p.current ? 4 : 2.6, fill: colour,
          stroke: "#fff", "stroke-width": 1 };
        if (opts.clickable) {
          dot["data-year"] = p.year;
          dot["class"] = "trendpt";
          dot.r = p.current ? 5 : 4;   // bigger hit target when taggable
        }
        body.push(S.el("circle", dot));
        // the end-of-line label (right edge) already carries the final
        // value — per-point labels stop one short so the last value never
        // renders twice; "last" mode is the end labels alone
        var labelThis = labelAll && pi < s.points.length - 1;
        if (labelThis && labelMode !== "none") {
          body.push(S.text(xOf(p.year), yOf(p.value) - 8,
            fmtVal(p.value, s.isMean),
            { "text-anchor": "middle", "font-size": 9.5,
              "font-weight": p.current ? 700 : 400, fill: "#1c2333" }));
        }
      });
      var last = s.points[s.points.length - 1];
      // end labels carry the VALUE only — series names live in the
      // bottom legend where there is room for the full question text
      endLabels.push({ pos: yOf(last.value), colour: colour, sig: s.sigNow,
        text: labelMode === "none" ? "" : fmtVal(last.value, s.isMean) });
    });
    render.repel(endLabels, 13, padT + 4, padT + plotH);
    endLabels.forEach(function (l) {
      // trailing dot marks a significant change vs the prior wave
      body.push(S.text(padL + plotW + 8, l.pos + 3,
        l.text + (l.sig ? " •" : ""),
        { "font-size": 10, "font-weight": 700, fill: l.colour }));
    });
    var note = (opts.note || "Published wave Totals · " + years[0] + "–" +
      years[years.length - 1]) + (dropped > 0 ? " · " + dropped +
      " series hidden (mixed scales or >6)" : "");
    body.push(S.text(padL, H - 4, note, { "font-size": 9.5, fill: "#9aa1b1" }));
    var legend = null, height = H;
    if (series.length > 1) {
      legend = S.legend(series.map(function (s, k) {
        // full text — the legend wraps long labels; clip only the extreme
        return { label: TR.charts.clip(s.label, 300),
          colour: palette[k % palette.length] };
      }), padL, H + 4, W - padL - 10);
      body.push(legend.body);
      height = H + legend.height + 8;
    }
    return S.root(W, height, model.code + " — trend over waves", body.join(""));
  };

})(typeof window !== "undefined" ? window : globalThis);
