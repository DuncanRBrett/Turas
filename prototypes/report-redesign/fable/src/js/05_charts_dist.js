/**
 * Distribution + trend chart builders: 100% stacked scale rows, NPS stacks,
 * wave trend lines, and the per-type dispatcher. Pure string output.
 */
(function (global) {
  "use strict";
  var TR = global.TR, C = TR.CONST, S = TR.svg, fmt = TR.fmt;

  var charts = TR.charts = TR.charts || {};

  var NPS_DETRACTOR = "#C0655B";
  var NPS_PASSIVE = "#CBD2E1";

  /** Shared layout for one 100%-stacked row per banner column. */
  function stackedRows(q, payload, segments) {
    var cols = TR.data.bannerColumns(payload, q);
    var pd = fmt.pctDecimals(payload);
    var plotW = C.CHART_WIDTH - C.CHART_LABEL_WIDTH - C.CHART_VALUE_WIDTH;
    var statRow = (q.stats || [])[0] || null;
    var body = [], y = C.CHART_PAD_TOP + (statRow ? 16 : 0);

    if (statRow) {
      body.push(S.text(C.CHART_WIDTH - 2, y - 6, charts.clip(statRow.label, 20),
        { "text-anchor": "end", "font-size": 10, fill: "#9aa1b1" }));
    }
    cols.forEach(function (col, ci) {
      body.push(S.text(C.CHART_LABEL_WIDTH - 8, y + C.STACK_ROW_HEIGHT * 0.65,
        charts.clip(col, 24),
        { "text-anchor": "end", "font-size": 12, fill: "#3b4252" }));
      var xPos = C.CHART_LABEL_WIDTH;
      segments.forEach(function (seg) {
        var v = seg.row.values && typeof seg.row.values[ci] === "number"
          ? seg.row.values[ci] : 0;
        var w = Math.max((v / 100) * plotW, 0);
        body.push(S.el("rect", { x: xPos, y: y, width: w,
          height: C.STACK_ROW_HEIGHT, fill: seg.colour }));
        if (v >= 8) {
          body.push(S.text(xPos + w / 2, y + C.STACK_ROW_HEIGHT * 0.65,
            fmt.num(v, "pct", pd), { "text-anchor": "middle", "font-size": 11,
              fill: seg.darkText ? "#1c2333" : "#ffffff" }));
        }
        xPos += w;
      });
      if (statRow) {
        var sig = statRow.sig && statRow.sig[ci] ? " " + statRow.sig[ci] : "";
        body.push(S.text(C.CHART_LABEL_WIDTH + plotW + 8,
          y + C.STACK_ROW_HEIGHT * 0.65,
          fmt.num(statRow.values[ci], statRow.format || "dec1", pd) + sig,
          { "font-size": 12, "font-weight": 700, fill: "#1c2333" }));
      }
      y += C.STACK_ROW_HEIGHT + C.STACK_ROW_GAP;
    });

    var legend = S.legend(segments.map(function (seg) {
      return { label: seg.row.label, colour: seg.colour };
    }), C.CHART_LABEL_WIDTH, y + 8, C.CHART_WIDTH - C.CHART_LABEL_WIDTH - 10);
    body.push(legend.body);
    var height = y + 8 + legend.height + 6;
    return S.root(C.CHART_WIDTH, height, q.title + " — distribution", body.join(""));
  }

  /** Scale question: brand-ramp stacked distribution per banner column. */
  charts.stackedScale = function (q, payload) {
    var rows = q.rows || [];
    if (!rows.length) return "";
    var brand = charts.brandOf(payload);
    var segments = rows.map(function (row, i) {
      var strength = 0.16 + 0.84 * (i / Math.max(rows.length - 1, 1));
      return { row: row, colour: S.shade(brand, strength), darkText: strength < 0.55 };
    });
    return stackedRows(q, payload, segments);
  };

  /** NPS question: detractors / passives / promoters stack + NPS column. */
  charts.npsStacked = function (q, payload) {
    var rows = q.rows || [];
    if (!rows.length) return "";
    var brand = charts.brandOf(payload);
    var find = function (re) {
      for (var i = 0; i < rows.length; i++) if (re.test(rows[i].label)) return rows[i];
      return null;
    };
    var det = find(/detract/i), pas = find(/passive/i), pro = find(/promot/i);
    if (!det || !pas || !pro) return charts.stackedScale(q, payload);
    var segments = [
      { row: det, colour: NPS_DETRACTOR, darkText: false },
      { row: pas, colour: NPS_PASSIVE, darkText: true },
      { row: pro, colour: brand, darkText: false }
    ];
    return stackedRows(q, payload, segments);
  };

  /** Wave trend lines. Total emphasised; selected column in accent. */
  charts.trend = function (q, payload, colIndex) {
    var waves = q.meta && q.meta.waves;
    if (!waves || !Array.isArray(waves.series) || !waves.series.length) return "";
    var cols = TR.data.bannerColumns(payload, q);
    var width = C.CHART_WIDTH, height = C.TREND_HEIGHT;
    var padL = 50, padR = 130, padT = 22, padB = 30;
    var all = [];
    waves.series.forEach(function (s) {
      (s.values || []).forEach(function (v) {
        if (typeof v === "number") all.push(v);
      });
    });
    if (!all.length) return "";
    var lo = Math.min.apply(null, all), hi = Math.max.apply(null, all);
    var pad = Math.max((hi - lo) * 0.25, 0.1);
    lo -= pad; hi += pad;
    var nWaves = waves.labels.length;
    var xAt = function (i) { return padL + (i / (nWaves - 1)) * (width - padL - padR); };
    var yAt = function (v) {
      return padT + (1 - (v - lo) / (hi - lo)) * (height - padT - padB);
    };
    var brand = charts.brandOf(payload), accent = charts.accentOf(payload);
    var body = [], endLabels = [];

    waves.labels.forEach(function (label, i) {
      body.push(S.el("line", { x1: xAt(i), y1: padT, x2: xAt(i),
        y2: height - padB, stroke: "#eef0f7" }));
      body.push(S.text(xAt(i), height - 10, charts.clip(label, 14),
        { "text-anchor": "middle", "font-size": 11, fill: "#6b7280" }));
    });
    body.push(S.text(padL, 12, "Trend · " + (waves.stat || "value") + " by wave",
      { "font-size": 10, fill: "#9aa1b1" }));

    waves.series.forEach(function (series) {
      var isTotal = series.column === cols[0];
      var isSelected = colIndex > 0 && series.column === cols[colIndex];
      var emphasised = isTotal || isSelected;
      var colour = isTotal ? brand : (isSelected ? accent : "#c9cedd");
      var pts = series.values.map(function (v, i) {
        return xAt(i) + "," + yAt(v);
      }).join(" ");
      body.push(S.el("polyline", { points: pts, fill: "none", stroke: colour,
        "stroke-width": isTotal ? 3 : 2, "stroke-linecap": "round" }));
      series.values.forEach(function (v, i) {
        body.push(S.el("circle", { cx: xAt(i), cy: yAt(v), r: 3, fill: colour }));
      });
      if (emphasised || waves.series.length <= 4) {
        var last = series.values[series.values.length - 1];
        endLabels.push({ y: yAt(last) + 4, emphasised: emphasised,
          text: charts.clip(series.column, 10) + "  " +
            fmt.num(last, waves.format || "dec1") });
      }
    });
    declutter(endLabels, padT + 8, height - padB).forEach(function (label) {
      body.push(S.text(xAt(nWaves - 1) + 8, label.y, label.text,
        { "font-size": 11, "font-weight": label.emphasised ? 700 : 400,
          fill: label.emphasised ? "#1c2333" : "#9aa1b1" }));
    });
    return S.root(width, height, q.title + " — trend by wave", body.join(""));
  };

  /** Nudge end-of-line labels apart so they never overprint (min 13px gap). */
  function declutter(labels, minY, maxY) {
    var GAP = 13;
    labels.sort(function (a, b) { return a.y - b.y; });
    for (var i = 1; i < labels.length; i++) {
      if (labels[i].y - labels[i - 1].y < GAP) {
        labels[i].y = labels[i - 1].y + GAP;
      }
    }
    var overshoot = labels.length ? labels[labels.length - 1].y - maxY : 0;
    if (overshoot > 0) {
      labels.forEach(function (label) {
        label.y = Math.max(minY, label.y - overshoot);
      });
      for (var j = labels.length - 2; j >= 0; j--) {
        if (labels[j + 1].y - labels[j].y < GAP) {
          labels[j].y = labels[j + 1].y - GAP;
        }
      }
    }
    return labels;
  }

  /** Dispatcher: the right primary chart for a question type. */
  charts.forQuestion = function (q, payload, colIndex) {
    if (q.type === "scale") return charts.stackedScale(q, payload);
    if (q.type === "nps") return charts.npsStacked(q, payload);
    if (q.type === "numeric") {
      return q.rows && q.rows.length
        ? charts.hBars(q, payload, colIndex)
        : charts.columns(q, payload);
    }
    return charts.hBars(q, payload, colIndex);
  };

})(typeof window !== "undefined" ? window : globalThis);
