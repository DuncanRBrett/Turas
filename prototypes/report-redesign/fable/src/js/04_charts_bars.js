/**
 * Bar-family chart builders: horizontal bars (single/multi/numeric buckets)
 * and column charts (numeric stats). Pure string output from the payload.
 */
(function (global) {
  "use strict";
  var TR = global.TR, C = TR.CONST, S = TR.svg, fmt = TR.fmt;

  var charts = TR.charts = TR.charts || {};

  /** Truncate a label to fit chart margins. */
  charts.clip = function (label, max) {
    var s = String(label == null ? "" : label);
    return s.length > max ? s.slice(0, max - 1) + "…" : s;
  };

  /** Project brand colour with fallback. */
  charts.brandOf = function (payload) {
    return (payload.project && payload.project.brand_colour) || TR.DEFAULT_BRAND;
  };

  /** Project accent colour with fallback. */
  charts.accentOf = function (payload) {
    return (payload.project && payload.project.accent_colour) || TR.DEFAULT_ACCENT;
  };

  function axisNote(height, label) {
    return S.text(C.CHART_LABEL_WIDTH, height - 8, label,
      { "font-size": 10, fill: "#9aa1b1" });
  }

  /**
   * Horizontal bars for one banner column. The axis maximum is computed
   * across ALL banner columns so switching columns keeps a stable scale.
   */
  charts.hBars = function (q, payload, colIndex) {
    var rows = q.rows || [];
    var cols = TR.data.bannerColumns(payload, q);
    var pd = fmt.pctDecimals(payload);
    var axisMax = S.niceMax(TR.data.maxRowValue(q));
    var plotW = C.CHART_WIDTH - C.CHART_LABEL_WIDTH - C.CHART_VALUE_WIDTH;
    var x = S.linear(axisMax, plotW);
    var brand = charts.brandOf(payload);
    var body = [], y = C.CHART_PAD_TOP;

    rows.forEach(function (row) {
      var v = row.values ? row.values[colIndex] : null;
      var w = typeof v === "number" ? Math.max(x(v), 0) : 0;
      body.push(S.text(C.CHART_LABEL_WIDTH - 8, y + C.BAR_HEIGHT * 0.72,
        charts.clip(row.label, 26),
        { "text-anchor": "end", "font-size": 12, fill: "#3b4252" }));
      body.push(S.el("rect", { x: C.CHART_LABEL_WIDTH, y: y, width: plotW,
        height: C.BAR_HEIGHT, fill: "#eef0f7", rx: 4 }));
      body.push(S.el("rect", { x: C.CHART_LABEL_WIDTH, y: y, width: w,
        height: C.BAR_HEIGHT, fill: brand, rx: 4 }));
      var sig = row.sig && row.sig[colIndex] ? " " + row.sig[colIndex] : "";
      body.push(S.text(C.CHART_LABEL_WIDTH + w + 6, y + C.BAR_HEIGHT * 0.72,
        fmt.num(v, row.format || "pct", pd) + sig,
        { "font-size": 12, "font-weight": 600, fill: "#1c2333" }));
      y += C.BAR_HEIGHT + C.BAR_GAP;
    });

    var height = y - C.BAR_GAP + C.CHART_PAD_BOTTOM;
    body.push(axisNote(height,
      "0–" + axisMax + "% scale · " + (cols[colIndex] || "Total")));
    return S.root(C.CHART_WIDTH, height,
      q.title + " — " + (cols[colIndex] || "Total"), body.join(""));
  };

  /**
   * Vertical columns of the first stat row across banner columns —
   * used for numeric questions that carry stats but no bucket rows.
   */
  charts.columns = function (q, payload) {
    var stat = (q.stats || [])[0];
    if (!stat) return "";
    var cols = TR.data.bannerColumns(payload, q);
    var brand = charts.brandOf(payload);
    var numbers = stat.values.filter(function (v) { return typeof v === "number"; });
    if (!numbers.length) return "";
    var axisMax = S.niceMax(Math.max.apply(null, numbers));
    var plotH = 150, padT = 24, padB = 40;
    var slot = (C.CHART_WIDTH - C.CHART_LABEL_WIDTH) / cols.length;
    var body = [];

    cols.forEach(function (col, i) {
      var v = stat.values[i];
      var h = typeof v === "number" ? (v / axisMax) * plotH : 0;
      var cx = C.CHART_LABEL_WIDTH + i * slot + slot / 2;
      var barW = Math.min(slot * 0.55, 56);
      body.push(S.el("rect", { x: cx - barW / 2, y: padT + plotH - h,
        width: barW, height: h, fill: i === 0 ? brand : S.shade(brand, 0.55), rx: 4 }));
      body.push(S.text(cx, padT + plotH - h - 6, fmt.num(v, stat.format || "dec1"),
        { "text-anchor": "middle", "font-size": 12, "font-weight": 600, fill: "#1c2333" }));
      body.push(S.text(cx, padT + plotH + 16, charts.clip(col, 12),
        { "text-anchor": "middle", "font-size": 11, fill: "#6b7280" }));
    });
    body.push(S.text(C.CHART_LABEL_WIDTH, 14, stat.label,
      { "font-size": 11, fill: "#9aa1b1" }));
    var height = padT + plotH + padB;
    return S.root(C.CHART_WIDTH, height, q.title + " — " + stat.label, body.join(""));
  };

})(typeof window !== "undefined" ? window : globalThis);
