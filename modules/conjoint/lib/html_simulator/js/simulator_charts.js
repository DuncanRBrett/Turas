/**
 * Conjoint Simulator SVG Charts
 * Builds market share bars and sensitivity charts following Turas visual standards
 */

var SimCharts = (function() {
  "use strict";

  var brandColour = "#323367";

  function setBrand(colour) { brandColour = colour || "#323367"; }

  // Horizontal bar chart for market shares
  function renderShareBars(containerId, products, shares) {
    var container = document.getElementById(containerId);
    if (!container) return;

    var n = shares.length;
    var w = 500, barH = 32, gap = 12, ml = 120, mr = 70;
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
      svg += '<rect x="' + ml + '" y="' + y + '" width="' + bw + '" height="' + barH + '" rx="4" fill="' + brandColour + '" opacity="0.8"/>';
      svg += '<text x="' + (ml + bw + 6) + '" y="' + (y + barH / 2) + '" fill="#334155" font-size="12" font-weight="500" dominant-baseline="central">' + shares[i].toFixed(1) + '%</text>';
    }

    svg += '</svg>';
    container.innerHTML = svg;
  }

  // Sensitivity line chart
  function renderSensitivity(containerId, sweepResults, attrName) {
    var container = document.getElementById(containerId);
    if (!container) return;
    if (!sweepResults || sweepResults.length === 0) return;

    var n = sweepResults.length;
    var w = 500, h = 250, ml = 60, mr = 30, mt = 30, mb = 60;
    var pw = w - ml - mr, ph = h - mt - mb;
    var maxS = Math.max.apply(null, sweepResults.map(function(r) { return r.share; }).concat([50]));
    var minS = Math.min.apply(null, sweepResults.map(function(r) { return r.share; }).concat([0]));
    if (maxS - minS < 1) { maxS = minS + 10; }

    var svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '" width="100%" style="max-width:' + w + 'px;font-family:system-ui,sans-serif;">';
    svg += '<text x="' + (w / 2) + '" y="16" text-anchor="middle" fill="#334155" font-size="13" font-weight="500">' + attrName + ' Sensitivity</text>';

    // Points and line
    var points = [];
    for (var i = 0; i < n; i++) {
      var x = ml + (i / Math.max(n - 1, 1)) * pw;
      var y = mt + (1 - (sweepResults[i].share - minS) / (maxS - minS)) * ph;
      points.push(x.toFixed(1) + "," + y.toFixed(1));

      svg += '<circle cx="' + x.toFixed(1) + '" cy="' + y.toFixed(1) + '" r="5" fill="' + brandColour + '"/>';
      svg += '<text x="' + x.toFixed(1) + '" y="' + (y - 10) + '" text-anchor="middle" fill="#334155" font-size="10" font-weight="500">' + sweepResults[i].share.toFixed(1) + '%</text>';

      // X-axis label
      var lbl = sweepResults[i].level;
      if (lbl.length > 12) lbl = lbl.substring(0, 11) + "\u2026";
      svg += '<text x="' + x.toFixed(1) + '" y="' + (h - mb + 16) + '" text-anchor="middle" fill="#64748b" font-size="10" transform="rotate(-30,' + x.toFixed(1) + ',' + (h - mb + 16) + ')">' + lbl + '</text>';
    }

    if (points.length > 1) {
      svg += '<polyline points="' + points.join(" ") + '" fill="none" stroke="' + brandColour + '" stroke-width="2.5"/>';
    }

    svg += '</svg>';
    container.innerHTML = svg;
  }

  return {
    setBrand: setBrand,
    renderShareBars: renderShareBars,
    renderSensitivity: renderSensitivity
  };
})();
