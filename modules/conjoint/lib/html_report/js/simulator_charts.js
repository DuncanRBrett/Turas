/**
 * Conjoint Simulator SVG Charts
 * Market share bars, sensitivity, source of volume, demand curve.
 * Follows Turas visual standards: rx=4, muted palette, #64748b labels.
 */

var SimCharts = (function() {
  "use strict";

  var brandColour = "#323367";
  var palette = ["#323367", "#2d8a6e", "#c46a3a", "#8b5e9b", "#3a7bc8", "#c45d5d", "#5ea37a", "#b07d4f"];

  function setBrand(colour) { brandColour = colour || "#323367"; palette[0] = brandColour; }

  function getColour(i) { return palette[i % palette.length]; }


  // === MARKET SHARE BARS ===

  function renderShareBars(containerId, products, shares) {
    var container = document.getElementById(containerId);
    if (!container) return;

    var n = shares.length;
    var w = 500, barH = 28, gap = 10, ml = 120, mr = 70;
    var h = n * (barH + gap) + 20;
    var pw = w - ml - mr;
    var maxShare = Math.max.apply(null, shares.concat([50]));

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';

    for (var i = 0; i < n; i++) {
      var y = i * (barH + gap) + 10;
      var bw = Math.max((shares[i] / maxShare) * pw, 2);
      var label = products[i].name || ("Product " + (i + 1));
      if (label.length > 15) label = label.substring(0, 14) + "\u2026";

      svg += '<text x="' + (ml - 8) + '" y="' + (y + barH / 2) + '" text-anchor="end" fill="#334155" font-size="12" dominant-baseline="central">' + label + '</text>';
      svg += '<rect x="' + ml + '" y="' + y + '" width="' + bw.toFixed(1) + '" height="' + barH + '" rx="4" fill="' + getColour(i) + '" opacity="0.8"/>';
      svg += '<text x="' + (ml + bw + 6).toFixed(1) + '" y="' + (y + barH / 2) + '" fill="#334155" font-size="12" font-weight="500" dominant-baseline="central">' + shares[i].toFixed(1) + '%</text>';
    }

    svg += '</svg>';
    container.innerHTML = svg;
  }


  // === SENSITIVITY LINE CHART ===

  function renderSensitivity(containerId, sweepResults, attrName) {
    var container = document.getElementById(containerId);
    if (!container || !sweepResults || sweepResults.length === 0) return;

    var n = sweepResults.length;
    var w = 500, h = 280, ml = 60, mr = 30, mt = 30, mb = 70;
    var pw = w - ml - mr, ph = h - mt - mb;
    var maxS = Math.max.apply(null, sweepResults.map(function(r) { return r.share; }).concat([50]));
    var minS = Math.min.apply(null, sweepResults.map(function(r) { return r.share; }).concat([0]));
    if (maxS - minS < 1) maxS = minS + 10;

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';
    svg += '<text x="' + (w / 2) + '" y="16" text-anchor="middle" fill="#334155" font-size="13" font-weight="500">' + attrName + ' Sensitivity (Product 1)</text>';

    // Gridlines
    var yStep = niceStep(maxS - minS, 4);
    for (var gy = Math.ceil(minS / yStep) * yStep; gy <= maxS; gy += yStep) {
      var yy = mt + (1 - (gy - minS) / (maxS - minS)) * ph;
      svg += '<line x1="' + ml + '" y1="' + yy.toFixed(1) + '" x2="' + (w - mr) + '" y2="' + yy.toFixed(1) + '" stroke="#e2e8f0" stroke-width="1"/>';
      svg += '<text x="' + (ml - 6) + '" y="' + yy.toFixed(1) + '" text-anchor="end" fill="#64748b" font-size="10" dominant-baseline="central">' + gy.toFixed(0) + '%</text>';
    }

    // Line + points
    var points = [];
    for (var i = 0; i < n; i++) {
      var x = ml + (i / Math.max(n - 1, 1)) * pw;
      var y = mt + (1 - (sweepResults[i].share - minS) / (maxS - minS)) * ph;
      points.push(x.toFixed(1) + "," + y.toFixed(1));

      svg += '<circle cx="' + x.toFixed(1) + '" cy="' + y.toFixed(1) + '" r="5" fill="' + brandColour + '"/>';
      svg += '<text x="' + x.toFixed(1) + '" y="' + (y - 10).toFixed(1) + '" text-anchor="middle" fill="#334155" font-size="10" font-weight="500">' + sweepResults[i].share.toFixed(1) + '%</text>';

      var lbl = sweepResults[i].level;
      if (lbl.length > 12) lbl = lbl.substring(0, 11) + "\u2026";
      svg += '<text x="' + x.toFixed(1) + '" y="' + (h - mb + 16) + '" text-anchor="end" fill="#64748b" font-size="10" transform="rotate(-35,' + x.toFixed(1) + ',' + (h - mb + 16) + ')">' + lbl + '</text>';
    }

    if (points.length > 1) {
      svg += '<polyline points="' + points.join(" ") + '" fill="none" stroke="' + brandColour + '" stroke-width="2.5"/>';
    }

    svg += '</svg>';
    container.innerHTML = svg;
  }


  // === SOURCE OF VOLUME ===

  function renderSourceOfVolume(containerId, sovResults) {
    var container = document.getElementById(containerId);
    if (!container || !sovResults || sovResults.length === 0) return;

    var n = sovResults.length;
    var w = 500, barH = 24, gap = 8, ml = 120, mr = 80;
    var h = n * (barH + gap) * 2 + 60;
    var pw = w - ml - mr;

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';

    var yPos = 20;
    sovResults.forEach(function(item, i) {
      // Baseline bar
      svg += '<text x="' + (ml - 8) + '" y="' + (yPos + barH / 2) + '" text-anchor="end" fill="#334155" font-size="11" dominant-baseline="central">' + item.product + '</text>';

      var bw1 = Math.max((item.baseline / 100) * pw, 0);
      svg += '<rect x="' + ml + '" y="' + yPos + '" width="' + bw1.toFixed(1) + '" height="' + barH + '" rx="4" fill="#94a3b8" opacity="0.5"/>';
      svg += '<text x="' + (ml + bw1 + 4).toFixed(1) + '" y="' + (yPos + barH / 2) + '" fill="#94a3b8" font-size="10" dominant-baseline="central">' + item.baseline.toFixed(1) + '%</text>';
      yPos += barH + 2;

      // Test bar
      var bw2 = Math.max((item.test / 100) * pw, 0);
      svg += '<rect x="' + ml + '" y="' + yPos + '" width="' + bw2.toFixed(1) + '" height="' + barH + '" rx="4" fill="' + getColour(i) + '" opacity="0.8"/>';

      var changeStr = (item.change >= 0 ? "+" : "") + item.change.toFixed(1) + "pp";
      var changeColour = item.change >= 0 ? "#16a34a" : "#dc2626";
      svg += '<text x="' + (ml + bw2 + 4).toFixed(1) + '" y="' + (yPos + barH / 2) + '" fill="' + changeColour + '" font-size="10" font-weight="500" dominant-baseline="central">' + item.test.toFixed(1) + '% (' + changeStr + ')</text>';
      yPos += barH + gap + 6;
    });

    // Legend
    svg += '<text x="' + ml + '" y="' + (yPos + 5) + '" fill="#94a3b8" font-size="10">Grey = Baseline | Colour = With new product</text>';

    svg += '</svg>';
    container.innerHTML = svg;
  }


  // === DEMAND CURVE ===

  function renderDemandCurve(containerId, curveData) {
    var container = document.getElementById(containerId);
    if (!container || !curveData || curveData.length === 0) return;

    var n = curveData.length;
    var w = 400, h = 250, ml = 60, mr = 20, mt = 30, mb = 50;
    var pw = w - ml - mr, ph = h - mt - mb;
    var maxS = Math.max.apply(null, curveData.map(function(d) { return d.share; })) * 1.1;
    if (maxS < 10) maxS = 10;

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';
    svg += '<text x="' + (w / 2) + '" y="16" text-anchor="middle" fill="#334155" font-size="12" font-weight="500">Demand Curve</text>';

    var points = [];
    for (var i = 0; i < n; i++) {
      var x = ml + (i / Math.max(n - 1, 1)) * pw;
      var y = mt + (1 - curveData[i].share / maxS) * ph;
      points.push(x.toFixed(1) + "," + y.toFixed(1));

      svg += '<circle cx="' + x.toFixed(1) + '" cy="' + y.toFixed(1) + '" r="4" fill="' + brandColour + '"/>';
      svg += '<text x="' + x.toFixed(1) + '" y="' + (y - 8).toFixed(1) + '" text-anchor="middle" fill="#334155" font-size="9" font-weight="500">' + curveData[i].share.toFixed(1) + '%</text>';
      svg += '<text x="' + x.toFixed(1) + '" y="' + (h - mb + 16) + '" text-anchor="middle" fill="#64748b" font-size="10">' + curveData[i].level + '</text>';
    }

    if (points.length > 1) {
      svg += '<polyline points="' + points.join(" ") + '" fill="none" stroke="' + brandColour + '" stroke-width="2.5"/>';
    }

    svg += '</svg>';
    container.innerHTML = svg;
  }


  // === UTILITY ===

  function niceStep(range, targetTicks) {
    var rough = range / (targetTicks || 4);
    var mag = Math.pow(10, Math.floor(Math.log10(rough)));
    var candidates = [1, 2, 5, 10];
    var best = mag;
    candidates.forEach(function(c) {
      if (Math.abs(c * mag - rough) < Math.abs(best - rough)) best = c * mag;
    });
    return best || 1;
  }


  return {
    setBrand: setBrand,
    renderShareBars: renderShareBars,
    renderSensitivity: renderSensitivity,
    renderSourceOfVolume: renderSourceOfVolume,
    renderDemandCurve: renderDemandCurve
  };
})();
