/**
 * Pricing view. The Van Westendorp price points with the interval that
 * brackets each one and the four curves they come from, the Gabor-Granger
 * demand and revenue curves with the revenue optimum marked, the monadic
 * cells against the curve fitted through them, and the recommended price.
 *
 * FROZEN, NOT LIVE. Every other analysis tab recomputes from microdata when
 * the audience filter changes. Pricing cannot: the price points were
 * estimated once, on the whole sample. So this tab shows what was estimated
 * and the filter bar is hidden while it is open, the same contract as
 * Conjoint, MaxDiff and Tracking. The note at the top of the tab says so, and
 * points at the crosstab export, which is the filterable cut.
 *
 * The data comes from TR.PR, the pricing module's contribution island
 * (modules/pricing/R/14_v2_island.R). There are no new row kinds: a price
 * point has no banner and no base, and a demand curve runs along a price
 * axis, so neither belongs in the crosstab data layer.
 *
 * Provenance is the point of the first panel. Which estimator ran, what the
 * weights reached, how acceptance was coded, whether the published curve was
 * smoothed: all of it travels in the island so this view cannot forget to
 * say it.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var pr = TR.pricing = {};

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // A missing value shows as an en dash, never as "NaN" or an empty cell.
  function num(v, dp) {
    if (v === null || v === undefined || isNaN(v)) return "–";
    return Number(v).toFixed(dp === undefined ? 1 : dp);
  }

  function arr(v) { return Array.isArray(v) ? v : null; }

  function meta() { return (TR.PR && TR.PR.meta) || {}; }

  /** A price with the study's own currency in front of it. */
  function money(v, dp) {
    if (v === null || v === undefined || isNaN(v)) return "–";
    return (meta().currency || "") + num(v, dp === undefined ? 2 : dp);
  }

  /** Is there a pricing contribution with anything in it? */
  pr.available = function () {
    var d = TR.PR;
    if (!d || !d.meta) return false;
    return !!(d.vw || d.gg || d.monadic);
  };

  pr.data = function () { return TR.PR; };

  // -------------------------------------------------------------------------
  // Chart primitives. Literal colours, no CSS variables, so the same string
  // renders in the page and rasterises to PNG (the rule 03_svg.js sets).
  // -------------------------------------------------------------------------

  var INK = "#333";
  var GRID = "#e3e3e3";
  var AXIS = "#999";
  var SERIES = ["#323367", "#7a9e3f", "#c9847a", "#2f7d95", "#b58b00"];

  var CHART_W = 720, CHART_H = 320;
  var PAD = { top: 14, right: 54, bottom: 40, left: 52 };

  function extent(values) {
    var lo = Infinity, hi = -Infinity;
    values.forEach(function (v) {
      if (v === null || v === undefined || isNaN(v)) return;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    });
    if (!isFinite(lo) || !isFinite(hi)) return null;
    if (lo === hi) { lo -= 1; hi += 1; }
    return [lo, hi];
  }

  function scaler(domain, lo, hi) {
    var span = domain[1] - domain[0];
    return function (v) {
      if (v === null || v === undefined || isNaN(v)) return null;
      return lo + (span === 0 ? 0 : (v - domain[0]) / span * (hi - lo));
    };
  }

  /** Four or five round tick values across a domain. */
  function ticks(domain, count) {
    var out = [], n = count || 4;
    for (var i = 0; i <= n; i++) out.push(domain[0] + (domain[1] - domain[0]) * i / n);
    return out;
  }

  function path(xs, ys, sx, sy) {
    var d = "", pen = false;
    for (var i = 0; i < xs.length; i++) {
      var x = sx(xs[i]), y = sy(ys[i]);
      if (x === null || y === null) { pen = false; continue; }
      d += (pen ? "L" : "M") + x.toFixed(1) + " " + y.toFixed(1) + " ";
      pen = true;
    }
    return d;
  }

  /**
   * One line chart with a price axis along the bottom.
   *
   * @param {object} spec - xValues, yDomain, yLabel, series [{values, colour,
   *   label, dashed}], markers [{x, label}], points [{x, y, colour}],
   *   rightAxis {values, colour, label}, title.
   */
  function lineChart(spec) {
    var xDom = extent(spec.xValues);
    if (!xDom) return "";
    var yDom = spec.yDomain || [0, 100];
    var sx = scaler(xDom, PAD.left, CHART_W - PAD.right);
    var sy = scaler(yDom, CHART_H - PAD.bottom, PAD.top);

    var out = [];
    // Horizontal grid and the left axis labels.
    ticks(yDom, 4).forEach(function (t) {
      var y = sy(t).toFixed(1);
      out.push('<line x1="' + PAD.left + '" y1="' + y + '" x2="' + (CHART_W - PAD.right) +
        '" y2="' + y + '" stroke="' + GRID + '" stroke-width="1"/>');
      out.push('<text x="' + (PAD.left - 6) + '" y="' + (Number(y) + 3.5) +
        '" text-anchor="end" font-size="10" fill="' + AXIS + '">' +
        esc(num(t, yDom[1] > 20 ? 0 : 1)) + (spec.ySuffix || "") + "</text>");
    });
    // Price axis.
    ticks(xDom, 4).forEach(function (t) {
      var x = sx(t).toFixed(1);
      out.push('<text x="' + x + '" y="' + (CHART_H - PAD.bottom + 14) +
        '" text-anchor="middle" font-size="10" fill="' + AXIS + '">' +
        esc(money(t, 0)) + "</text>");
    });
    out.push('<line x1="' + PAD.left + '" y1="' + (CHART_H - PAD.bottom) + '" x2="' +
      (CHART_W - PAD.right) + '" y2="' + (CHART_H - PAD.bottom) +
      '" stroke="' + AXIS + '" stroke-width="1"/>');

    // A second axis on the right, for the revenue index beside demand.
    var sr = null;
    if (spec.rightAxis) {
      var rDom = extent(spec.rightAxis.values);
      if (rDom) {
        rDom = [0, rDom[1]];
        sr = scaler(rDom, CHART_H - PAD.bottom, PAD.top);
        ticks(rDom, 4).forEach(function (t) {
          out.push('<text x="' + (CHART_W - PAD.right + 6) + '" y="' + (sr(t) + 3.5).toFixed(1) +
            '" text-anchor="start" font-size="10" fill="' + spec.rightAxis.colour + '">' +
            esc(num(t, 0)) + "</text>");
        });
      }
    }

    // Vertical markers (the price points, the optimum).
    (spec.markers || []).forEach(function (m) {
      var x = sx(m.x);
      if (x === null) return;
      out.push('<line x1="' + x.toFixed(1) + '" y1="' + PAD.top + '" x2="' + x.toFixed(1) +
        '" y2="' + (CHART_H - PAD.bottom) + '" stroke="' + (m.colour || "#666") +
        '" stroke-width="1" stroke-dasharray="3 3"/>');
      out.push('<text x="' + (x + 3).toFixed(1) + '" y="' + (PAD.top + 10) +
        '" font-size="10" fill="' + (m.colour || "#666") + '">' + esc(m.label) + "</text>");
    });

    (spec.series || []).forEach(function (s) {
      var d = path(spec.xValues, s.values, sx, sy);
      if (!d) return;
      out.push('<path d="' + d.trim() + '" fill="none" stroke="' + s.colour +
        '" stroke-width="2"' + (s.dashed ? ' stroke-dasharray="4 3"' : "") + "/>");
    });

    if (sr && spec.rightAxis) {
      var dr = path(spec.xValues, spec.rightAxis.values, sx, sr);
      if (dr) {
        out.push('<path d="' + dr.trim() + '" fill="none" stroke="' + spec.rightAxis.colour +
          '" stroke-width="2" stroke-dasharray="5 3"/>');
      }
    }

    (spec.points || []).forEach(function (p) {
      var x = sx(p.x), y = sy(p.y);
      if (x === null || y === null) return;
      out.push('<circle cx="' + x.toFixed(1) + '" cy="' + y.toFixed(1) + '" r="4" fill="' +
        (p.colour || SERIES[0]) + '"/>');
    });

    var legend = (spec.series || []).filter(function (s) { return s.label; })
      .concat(spec.rightAxis && spec.rightAxis.label
        ? [{ label: spec.rightAxis.label, colour: spec.rightAxis.colour }] : [])
      .map(function (s) {
        return '<span class="pr-key"><span class="pr-swatch" style="background:' +
          esc(s.colour) + '"></span>' + esc(s.label) + "</span>";
      }).join("");

    return '<div class="pr-chart">' +
      '<svg viewBox="0 0 ' + CHART_W + " " + CHART_H + '" role="img" aria-label="' +
      esc(spec.title || "chart") + '" preserveAspectRatio="xMidYMid meet">' +
      out.join("") + "</svg>" +
      (legend ? '<div class="pr-legend">' + legend + "</div>" : "") +
      "</div>";
  }

  // -------------------------------------------------------------------------
  // Panels
  // -------------------------------------------------------------------------

  function provenanceHtml(m) {
    var bits = [];
    var labels = arr(m.methodLabels) || arr(m.methods) || [];
    if (labels.length) bits.push(labels.map(esc).join(" and "));
    if (m.nRespondents) bits.push(esc(num(m.nRespondents, 0)) + " respondents");
    if (m.nValid && m.nValid !== m.nRespondents) {
      bits.push(esc(num(m.nValid, 0)) + " after validation");
    }
    if (m.weighted && m.effectiveN) {
      bits.push("effective n " + esc(num(m.effectiveN, 1)));
    }

    var notes = [];
    var en = m.estimationNote || {};
    ["vw", "gg", "monadic"].forEach(function (k) {
      if (en[k]) notes.push('<p class="pr-note">' + esc(en[k]) + "</p>");
    });

    var frozen = [];
    if (m.filterNote) frozen.push(esc(m.filterNote));
    if (m.weightingNote) frozen.push(esc(m.weightingNote));

    var sim = "";
    if (m.simulatorFile) {
      sim = '<p class="pr-note">Simulator: <a href="' + esc(m.simulatorFile) + '">' +
        esc(m.simulatorFile) +
        "</a>. Open it beside this report to try prices against the demand curve.</p>";
    }

    return '<div class="pr-provenance">' +
      (bits.length ? "<p>" + bits.join(" · ") + "</p>" : "") +
      notes.join("") +
      (frozen.length ? '<p class="pr-note pr-frozen">' + frozen.join(" ") + "</p>" : "") +
      sim +
      "</div>";
  }

  function vwHtml(v) {
    if (!v || !arr(v.point) || !v.point.length) return "";
    var lo = arr(v.ciLower), hi = arr(v.ciUpper);

    var rows = v.point.map(function (p, i) {
      var interval = (lo && hi && lo[i] != null && hi[i] != null)
        ? money(lo[i]) + " to " + money(hi[i]) : "–";
      return "<tr><td>" + esc(p) + "</td><td>" +
        esc((arr(v.pointLabel) || [])[i] || "") + "</td>" +
        '<td class="pr-num">' + esc(money(v.value[i])) + "</td>" +
        '<td class="pr-num">' + esc(interval) + "</td></tr>";
    }).join("");

    var notes = [];
    if (v.ciLevel && lo) {
      notes.push("The interval is a bootstrap " + num(v.ciLevel * 100, 0) +
        "% interval around the estimate reported here" +
        (v.ciIterations ? ", from " + num(v.ciIterations, 0) + " replicates" : "") + ".");
    }
    if (v.nAnalysed) {
      notes.push("Estimated on " + num(v.nAnalysed, 0) + " respondents" +
        (v.nComplete && v.nComplete !== v.nAnalysed
          ? " of " + num(v.nComplete, 0) + " who answered all four questions" : "") + ".");
    }
    notes.push("The acceptable range runs from the point of marginal cheapness to the point of marginal expensiveness; the optimal range sits between the optimal and indifference price points.");

    var ranges =
      '<p class="pr-ranges">Acceptable range <strong>' + esc(money(v.acceptableLower)) +
      " to " + esc(money(v.acceptableUpper)) + "</strong>" +
      (v.optimalLower != null
        ? " · Optimal range <strong>" + esc(money(v.optimalLower)) + " to " +
          esc(money(v.optimalUpper)) + "</strong>"
        : "") + "</p>";

    var chart = "";
    var c = v.curves;
    if (c && arr(c.price) && c.price.length > 1) {
      var markers = v.point.map(function (p, i) {
        return { x: v.value[i], label: p, colour: "#666" };
      });
      chart = lineChart({
        title: "Van Westendorp price sensitivity curves",
        xValues: c.price,
        yDomain: [0, 100],
        ySuffix: "%",
        markers: markers,
        series: [
          { values: (arr(c.tooCheap) || []).map(function (x) { return x * 100; }),
            colour: SERIES[1], label: "Too cheap" },
          { values: (arr(c.cheap) || []).map(function (x) { return x * 100; }),
            colour: SERIES[3], label: "Cheap" },
          { values: (arr(c.expensive) || []).map(function (x) { return x * 100; }),
            colour: SERIES[4], label: "Expensive" },
          { values: (arr(c.tooExpensive) || []).map(function (x) { return x * 100; }),
            colour: SERIES[2], label: "Too expensive" }
        ]
      });
    }

    return '<section class="pr-panel"><h3>Van Westendorp price points</h3>' +
      ranges +
      '<p class="pr-note">' + esc(notes.join(" ")) + "</p>" +
      chart +
      '<table class="pr-table"><thead><tr><th>Point</th><th>What it is</th>' +
      '<th class="pr-num">Price</th><th class="pr-num">Interval</th></tr></thead><tbody>' +
      rows + "</tbody></table></section>";
  }

  function ggHtml(g) {
    if (!g || !arr(g.price) || !g.price.length) return "";
    var accept = arr(g.acceptancePct) || [];
    var smoothed = arr(g.smoothedPct);
    var rev = arr(g.revenueIndex);
    var lo = arr(g.ciLowerPct), hi = arr(g.ciUpperPct);
    var el = arr(g.arcElasticity);
    var wn = arr(g.weightedN);

    var rows = g.price.map(function (p, i) {
      var interval = (lo && hi && lo[i] != null && hi[i] != null)
        ? num(lo[i]) + " to " + num(hi[i]) : "–";
      return "<tr><td>" + esc(money(p)) + "</td>" +
        '<td class="pr-num">' + esc(num((arr(g.baseN) || [])[i], 0)) + "</td>" +
        (wn ? '<td class="pr-num">' + esc(num(wn[i], 0)) + "</td>" : "") +
        '<td class="pr-num">' + esc(num(accept[i])) + "%</td>" +
        (smoothed ? '<td class="pr-num">' + esc(num(smoothed[i])) + "%</td>" : "") +
        '<td class="pr-num">' + esc(interval) + "</td>" +
        '<td class="pr-num">' + esc(rev ? num(rev[i], 2) : "–") + "</td>" +
        '<td class="pr-num">' + esc(el ? num(el[i], 2) : "–") + "</td></tr>";
    }).join("");

    var head = "<tr><th>Price</th><th class=\"pr-num\">Base</th>" +
      (wn ? '<th class="pr-num">Weighted base</th>' : "") +
      '<th class="pr-num">Would buy</th>' +
      (smoothed ? '<th class="pr-num">Published</th>' : "") +
      '<th class="pr-num">Interval</th><th class="pr-num">Revenue index</th>' +
      '<th class="pr-num">Elasticity</th></tr>';

    var published = smoothed || accept;
    var series = [{ values: published, colour: SERIES[0], label: "Would buy" }];
    if (smoothed) {
      series.push({ values: accept, colour: SERIES[0], label: "As observed", dashed: true });
    }

    var chart = lineChart({
      title: "Gabor-Granger demand and revenue",
      xValues: g.price,
      yDomain: [0, 100],
      ySuffix: "%",
      series: series,
      points: g.price.map(function (p, i) {
        return { x: p, y: published[i], colour: SERIES[0] };
      }),
      rightAxis: rev ? { values: rev, colour: SERIES[1], label: "Revenue index" } : null,
      markers: g.optimalRevenuePrice != null
        ? [{ x: g.optimalRevenuePrice, label: "Revenue optimum", colour: "#7a4b00" }] : []
    });

    var notes = [];
    if (g.optimalRevenuePrice != null) {
      notes.push("Revenue is highest at " + money(g.optimalRevenuePrice) +
        (g.optimalRevenueIntentPct != null
          ? ", where " + num(g.optimalRevenueIntentPct) + "% would buy" : "") + ".");
    }
    if (g.optimalProfitPrice != null) {
      notes.push("With the unit cost in the config, profit is highest at " +
        money(g.optimalProfitPrice) + ".");
    }
    if (smoothed) {
      notes.push("The published curve is smoothed so it never rises with price; the observed acceptance is the dashed line and the Would buy column.");
    }
    notes.push("The revenue index is price times the share who would buy, so it compares prices rather than forecasting revenue.");
    notes.push("Elasticity is the arc elasticity of the step that ends at that rung.");

    return '<section class="pr-panel"><h3>Gabor-Granger demand</h3>' +
      '<p class="pr-note">' + esc(notes.join(" ")) + "</p>" +
      chart +
      '<table class="pr-table"><thead>' + head + "</thead><tbody>" + rows +
      "</tbody></table></section>";
  }

  function monadicHtml(m) {
    if (!m || !arr(m.cellPrice) || !m.cellPrice.length) return "";
    var wn = arr(m.cellWeightedN);
    var rows = m.cellPrice.map(function (p, i) {
      return "<tr><td>" + esc(money(p)) + "</td>" +
        '<td class="pr-num">' + esc(num((arr(m.cellN) || [])[i], 0)) + "</td>" +
        (wn ? '<td class="pr-num">' + esc(num(wn[i], 0)) + "</td>" : "") +
        '<td class="pr-num">' + esc(num((arr(m.cellIntentPct) || [])[i])) + "%</td></tr>";
    }).join("");

    var chart = "";
    var f = m.fitted;
    if (f && arr(f.price) && f.price.length > 1) {
      chart = lineChart({
        title: "Monadic demand curve",
        xValues: f.price,
        yDomain: [0, 100],
        ySuffix: "%",
        series: [{ values: f.intentPct, colour: SERIES[0], label: "Fitted intent" }],
        points: m.cellPrice.map(function (p, i) {
          return { x: p, y: (arr(m.cellIntentPct) || [])[i], colour: SERIES[2] };
        }),
        markers: m.optimalPrice != null
          ? [{ x: m.optimalPrice, label: "Revenue optimum", colour: "#7a4b00" }] : []
      });
    }

    var notes = ["Each respondent saw one price, so the cells are independent samples and the dots are what they said. The line is the model fitted through them."];
    if (m.optimalPrice != null) {
      notes.push("Revenue is highest at " + money(m.optimalPrice) +
        (m.optimalIntentPct != null
          ? ", where the model puts intent at " + num(m.optimalIntentPct) + "%" : "") + ".");
    }
    if (m.pseudoR2 != null) notes.push("Pseudo R2 " + num(m.pseudoR2, 3) + ".");
    if (m.pValue != null) {
      notes.push("The price effect has p " +
        (m.pValue < 0.001 ? "below 0.001" : "= " + num(m.pValue, 3)) + ".");
    }

    var caveat = m.pValueCaveat
      ? '<p class="pr-stamp">' + esc(m.pValueCaveat) + "</p>" : "";

    return '<section class="pr-panel"><h3>Monadic cells</h3>' +
      '<p class="pr-note">' + esc(notes.join(" ")) + "</p>" +
      caveat +
      chart +
      '<table class="pr-table"><thead><tr><th>Price</th><th class="pr-num">Base</th>' +
      (wn ? '<th class="pr-num">Weighted base</th>' : "") +
      '<th class="pr-num">Would buy</th></tr></thead><tbody>' + rows +
      "</tbody></table></section>";
  }

  function recommendationHtml(r) {
    if (!r || r.price == null) return "";
    var bits = [];
    if (r.source) bits.push("Anchored on " + esc(String(r.source)));
    if (r.confidence) {
      bits.push("confidence " + esc(String(r.confidence).toLowerCase()) +
        (r.confidenceScore != null ? " (" + esc(num(r.confidenceScore * 100, 0)) + "%)" : ""));
    }
    if (r.methodSpreadPct != null) {
      bits.push("the methods' own prices spread " + esc(num(r.methodSpreadPct)) + "%" +
        (r.nMethodPrices ? " across " + esc(num(r.nMethodPrices, 0)) + " estimates" : ""));
    }

    var range = "";
    if (r.acceptableLower != null) {
      range = '<p class="pr-note">Acceptable range ' + esc(money(r.acceptableLower)) +
        " to " + esc(money(r.acceptableUpper)) +
        (r.optimalLower != null
          ? ", optimal range " + esc(money(r.optimalLower)) + " to " +
            esc(money(r.optimalUpper)) : "") + ".</p>";
    }

    return '<section class="pr-panel pr-rec"><h3>Recommended price</h3>' +
      '<p class="pr-headline">' + esc(money(r.price)) + "</p>" +
      (bits.length ? '<p class="pr-note">' + bits.join(" · ") + ".</p>" : "") +
      range +
      '<p class="pr-note">The module reads this off the methods above. The reasoning, the risks and the tier structure are in the Excel deliverable; what to actually charge is a judgement this tab does not make.</p>' +
      "</section>";
  }

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  pr.render = function (host) {
    var d = TR.PR;

    if (!pr.available()) {
      host.innerHTML = '<div class="pr-panel"><p>This report carries no pricing results.</p></div>';
      return;
    }

    host.innerHTML =
      '<div class="pr-view">' +
      "<h2>Pricing</h2>" +
      provenanceHtml(d.meta || {}) +
      recommendationHtml(d.recommendation) +
      vwHtml(d.vw) +
      ggHtml(d.gg) +
      monadicHtml(d.monadic) +
      "</div>";
  };

}(typeof window !== "undefined" ? window : this));
