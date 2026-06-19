/**
 * Chart-type library — bar (grouped), column, stacked, pie/donut and dot
 * plot, all pure SVG strings over the same view model so any of them can
 * back the crosstab chart, pins and PNG export. PPTX keeps editable
 * shapes for bar/column and falls back to bar for the other types.
 *
 * SIZE-EXCEPTION: five sibling chart builders sharing geometry helpers.
 */
(function (global) {
  "use strict";
  var TR = global.TR, S = TR.svg;

  var render = TR.render;

  render.CHART_TYPES = [
    ["bar", "Bar"], ["column", "Column"], ["stacked", "Stacked"],
    ["pie", "Pie"], ["dot", "Dot plot"]
  ];

  function fmtPct(v) {
    return v === null || v === undefined ? "–" : Math.round(v) + "%";
  }
  function fmtMean(v) {
    return v === null || v === undefined ? "–" : Number(v).toFixed(1);
  }

  /**
   * Repel 1-D label positions so neighbours never overlap: forward sweep
   * enforces a minimum gap, backward sweep pulls overflow back inside
   * [min, max]. Positions keep their input order's identity via objects.
   * @param {Array<{pos: number}>} labels - desired positions (mutated).
   */
  render.repel = function (labels, minGap, minPos, maxPos) {
    labels.sort(function (a, b) { return a.pos - b.pos; });
    for (var i = 1; i < labels.length; i++) {
      if (labels[i].pos - labels[i - 1].pos < minGap) {
        labels[i].pos = labels[i - 1].pos + minGap;
      }
    }
    var overflow = labels.length ? labels[labels.length - 1].pos - maxPos : 0;
    if (overflow > 0) {
      labels.forEach(function (l) { l.pos = Math.max(minPos, l.pos - overflow); });
      for (var j = labels.length - 2; j >= 0; j--) {
        if (labels[j + 1].pos - labels[j].pos < minGap) {
          labels[j].pos = labels[j + 1].pos - minGap;
        }
      }
    }
    return labels;
  };

  /** Dispatcher used by cards, story and exports. */
  render.chartBy = function (type, model, cols) {
    if (!Array.isArray(cols)) cols = [cols || 0];
    // The "Index (mean)" plot is a rating series — only the column chart scales
    // + labels ratings (meanScale); stacked / pie / horizontal bars assume
    // 0–100% shares, so a mean plot always renders as columns.
    if (model.valueKind === "mean") type = "column";
    if (type === "column") return render.columnChart(model, cols);
    if (type === "stacked") return render.stackedChart(model, cols);
    if (type === "pie") return render.pieChart(model, cols[0] || 0);
    if (type === "dot") return render.dotChart(model, cols);
    if (type === "line") return render.trendChart(model);
    return render.barChart(model, cols);
  };

  /** Vertical grouped columns: rows on the x axis, one column per series. */
  render.columnChart = function (model, cols) {
    var data = render.chartRows(model);
    if (!data.rows.length) return "";
    var meanScale = model.valueKind === "mean";   // ratings, not percentages
    var W = 660, plotH = 170, padT = 16, padB = 58, padL = 10;
    var palette = render.palette();
    // Single series: colour columns by category (semantic); multi-column keeps
    // one colour per cut so the series stay distinguishable.
    var catColours = cols.length === 1 ? render.categoryColours(data.rows) : null;
    var slot = (W - padL * 2) / data.rows.length;
    var barW = Math.min((slot - 8) / cols.length, 34);
    var body = [];
    data.rows.forEach(function (r, i) {
      var cx = padL + i * slot + slot / 2;
      var groupW = barW * cols.length;
      cols.forEach(function (ci, k) {
        var v = r.cells[ci] ? r.cells[ci].pct : null;
        // negative values (an NPS headline in a composite exhibit) floor
        // at the axis — a negative height is invalid SVG and the rect
        // would silently vanish; the label still shows the true value
        var h = v === null ? 0 : Math.max(v, 0) / data.axisMax * plotH;
        body.push(S.el("rect", { x: cx - groupW / 2 + k * barW,
          y: padT + plotH - h, width: barW - 2, height: h,
          fill: catColours ? catColours[i] : palette[k % palette.length], rx: 3 }));
        if (cols.length === 1 || v >= data.axisMax * 0.12) {
          body.push(S.text(cx - groupW / 2 + k * barW + (barW - 2) / 2,
            padT + plotH - h - 4, meanScale ? fmtMean(v) : fmtPct(v),
            { "text-anchor": "middle", "font-size": 9.5,
              "font-weight": 600, fill: "#1c2333" }));
        }
      });
      wrapLabel(body, r.label, cx, padT + plotH + 12, slot);
    });
    body.push(S.el("line", { x1: padL, y1: padT + plotH, x2: W - padL,
      y2: padT + plotH, stroke: "#d8dcea" }));
    var y = padT + plotH + padB - 18;
    if (cols.length > 1) {
      var legend = S.legend(cols.map(function (ci, k) {
        return { label: model.columns[ci] ? model.columns[ci].label : "?",
          colour: palette[k % palette.length] };
      }), padL, y + 10, W - padL * 2);
      body.push(legend.body);
      y += legend.height;
    }
    return S.root(W, y + 14, model.code + " — column chart", body.join(""));
  };

  function wrapLabel(body, label, cx, y, slotW) {
    // line length follows the column's slot width so wide slots keep the
    // full text; three 9.5px lines fit inside the fixed x-axis band
    var maxChars = Math.max(14, Math.floor((slotW || 90) / 6));
    S.wrapText(label, maxChars).slice(0, 3).forEach(function (l, i) {
      body.push(S.text(cx, y + i * 11, l,
        { "text-anchor": "middle", "font-size": 9.5, fill: "#6b7280" }));
    });
  }

  /**
   * 100% stacked horizontal bar per selected column (rows = segments).
   * Big segments label inside; SMALL segments (2–3%) label in a repelled
   * row above the bar with leader ticks, so nothing overlaps or is lost.
   */
  render.stackedChart = function (model, cols) {
    var data = render.chartRows(model);
    if (!data.rows.length) return "";
    var W = 660, LABEL = 150, VAL = 10, rowH = 26, gap = 10, callH = 18;
    var plotW = W - LABEL - VAL;
    var ramp = render.categoryColours(data.rows);
    var body = [], y = 10;
    cols.forEach(function (ci) {
      var col = model.columns[ci];
      var total = 0;
      data.rows.forEach(function (r) {
        total += (r.cells[ci] ? r.cells[ci].pct : 0) || 0;
      });
      var small = [];
      data.rows.forEach(function (r, riIdx) {
        var v = (r.cells[ci] ? r.cells[ci].pct : 0) || 0;
        var share = v / Math.max(total, 1);
        if (v >= 0.5 && share < 0.07) small.push(riIdx);
      });
      var barY = y + (small.length ? callH : 0);
      body.push(S.text(LABEL - 8, barY + rowH * 0.68,
        TR.charts.clip(col ? col.label : "?", 22),
        { "text-anchor": "end", "font-size": 11.5, fill: "#3b4252" }));
      var xPos = LABEL, callouts = [];
      data.rows.forEach(function (r, riIdx) {
        var v = (r.cells[ci] ? r.cells[ci].pct : 0) || 0;
        var w = total > 0 ? v / total * plotW : 0;
        body.push(S.el("rect", { x: xPos, y: barY, width: Math.max(w, 0),
          height: rowH, fill: ramp[riIdx] }));
        if (v / Math.max(total, 1) >= 0.07) {
          body.push(S.text(xPos + w / 2, barY + rowH * 0.68, Math.round(v) + "%",
            { "text-anchor": "middle", "font-size": 10,
              fill: riIdx / data.rows.length > 0.5 ? "#fff" : "#1c2333" }));
        } else if (v >= 0.5) {
          callouts.push({ pos: xPos + w / 2, anchor: xPos + w / 2, value: v });
        }
        xPos += w;
      });
      render.repel(callouts, 26, LABEL + 10, LABEL + plotW - 10);
      callouts.forEach(function (c) {
        body.push(S.el("line", { x1: c.anchor, y1: barY,
          x2: c.pos, y2: barY - 4, stroke: "#9aa1b1", "stroke-width": 1 }));
        body.push(S.text(c.pos, barY - 7, Math.round(c.value) + "%",
          { "text-anchor": "middle", "font-size": 9.5, fill: "#4b5263" }));
      });
      y = barY + rowH + gap;
    });
    var legend = S.legend(data.rows.map(function (r, i) {
      return { label: TR.charts.clip(r.label, 80), colour: ramp[i] };
    }), LABEL, y + 6, W - LABEL - 10);
    body.push(legend.body);
    return S.root(W, y + legend.height + 12,
      model.code + " — stacked", body.join(""));
  };

  /** Donut of one column's category rows. */
  render.pieChart = function (model, colIndex) {
    var data = render.chartRows(model);
    if (!data.rows.length) return "";
    var W = 660, H = 230, cx = 170, cy = H / 2, R = 88, r0 = 46;
    // Pie slices are categories — colour them semantically (warm palette).
    var palette = render.categoryColours(data.rows);
    // negative values cannot be a share of a whole — floor at 0 so a
    // negative NPS headline cannot draw a backwards arc
    var sliceOf = function (r) {
      return Math.max((r.cells[colIndex] && r.cells[colIndex].pct) || 0, 0);
    };
    var total = 0;
    data.rows.forEach(function (r) { total += sliceOf(r); });
    if (total <= 0) return "";
    var body = [], angle = -Math.PI / 2;
    var outside = { left: [], right: [] };
    data.rows.forEach(function (r, i) {
      var v = sliceOf(r);
      var sweep = v / total * Math.PI * 2;
      var a2 = angle + sweep;
      var large = sweep > Math.PI ? 1 : 0;
      var p = function (a, rad) {
        return (cx + rad * Math.cos(a)).toFixed(2) + " " +
               (cy + rad * Math.sin(a)).toFixed(2);
      };
      body.push(S.el("path", { d: "M " + p(angle, R) +
        " A " + R + " " + R + " 0 " + large + " 1 " + p(a2, R) +
        " L " + p(a2, r0) +
        " A " + r0 + " " + r0 + " 0 " + large + " 0 " + p(angle, r0) + " Z",
        fill: palette[i % palette.length], stroke: "#fff", "stroke-width": 1.5 }));
      var mid = angle + sweep / 2;
      if (sweep > 0.3) {
        var lr = (R + r0) / 2;
        body.push(S.text(cx + lr * Math.cos(mid), cy + lr * Math.sin(mid) + 3,
          Math.round(v) + "%", { "text-anchor": "middle", "font-size": 10.5,
            "font-weight": 700,
            fill: i / data.rows.length > 0.5 ? "#fff" : "#1c2333" }));
      } else if (v >= 0.5) {
        // small slice (the 2–3% kind): repelled outside label with a leader
        var side = Math.cos(mid) >= 0 ? "right" : "left";
        outside[side].push({ pos: cy + (R + 14) * Math.sin(mid), mid: mid, value: v });
      }
      angle = a2;
    });
    ["left", "right"].forEach(function (side) {
      render.repel(outside[side], 13, 14, H - 8);
      outside[side].forEach(function (o) {
        var ax = cx + R * Math.cos(o.mid), ay = cy + R * Math.sin(o.mid);
        var lx = cx + (side === "right" ? R + 20 : -(R + 20));
        body.push(S.el("line", { x1: ax, y1: ay, x2: lx, y2: o.pos - 3,
          stroke: "#9aa1b1", "stroke-width": 1 }));
        body.push(S.text(lx + (side === "right" ? 3 : -3), o.pos,
          Math.round(o.value) + "%",
          { "text-anchor": side === "right" ? "start" : "end",
            "font-size": 9.5, fill: "#4b5263" }));
      });
    });
    body.push(S.text(cx, cy + 4,
      TR.charts.clip(model.columns[colIndex] ? model.columns[colIndex].label : "", 12),
      { "text-anchor": "middle", "font-size": 11, "font-weight": 700, fill: "#1c2333" }));
    var legend = S.legend(data.rows.map(function (r, i) {
      return { label: TR.charts.clip(r.label, 80), colour: palette[i % palette.length] };
    }), 320, 40, W - 330);
    body.push(legend.body);
    return S.root(W, Math.max(H, 50 + legend.height),
      model.code + " — pie", body.join(""));
  };

  /** Dot plot: rows on y, one dot per selected column on a shared axis. */
  render.dotChart = function (model, cols) {
    var data = render.chartRows(model);
    if (!data.rows.length) return "";
    var W = 660, LABEL = 210, VAL = 30, rowH = 24;
    var plotW = W - LABEL - VAL;
    var x = S.linear(data.axisMax, plotW);
    var palette = render.palette();
    var body = [], y = 12;
    data.rows.forEach(function (r) {
      // full label, wrapped — the row grows to fit (no ellipses)
      var lines = S.wrapText(r.label, 32);
      var thisRowH = Math.max(rowH, lines.length * 12 + 6);
      var labelTop = y + 4 - (lines.length - 1) * 6;
      lines.forEach(function (line, li) {
        body.push(S.text(LABEL - 8, labelTop + li * 12, line,
          { "text-anchor": "end", "font-size": 11.5, fill: "#3b4252" }));
      });
      body.push(S.el("line", { x1: LABEL, y1: y, x2: LABEL + plotW, y2: y,
        stroke: "#eef0f7", "stroke-width": 2 }));
      cols.forEach(function (ci, k) {
        var v = r.cells[ci] ? r.cells[ci].pct : null;
        if (v === null) return;
        // negative values sit on the axis rather than drawing off-plot
        body.push(S.el("circle", { cx: LABEL + Math.max(x(v), 0), cy: y, r: 5.5,
          fill: palette[k % palette.length], stroke: "#fff", "stroke-width": 1.5 }));
      });
      y += thisRowH;
    });
    [0, 0.25, 0.5, 0.75, 1].forEach(function (f) {
      body.push(S.text(LABEL + plotW * f, y + 10,
        Math.round(data.axisMax * f) + "%",
        { "text-anchor": "middle", "font-size": 9.5, fill: "#9aa1b1" }));
    });
    y += 20;
    var legend = S.legend(cols.map(function (ci, k) {
      return { label: model.columns[ci] ? model.columns[ci].label : "?",
        colour: palette[k % palette.length] };
    }), LABEL, y + 6, W - LABEL - 10);
    body.push(legend.body);
    return S.root(W, y + legend.height + 10,
      model.code + " — dot plot", body.join(""));
  };

})(typeof window !== "undefined" ? window : globalThis);
