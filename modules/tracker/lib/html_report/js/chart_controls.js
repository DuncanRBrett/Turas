// ==============================================================================
// TurasTracker HTML Report - Chart Controls
// ==============================================================================
// Handles overview chart: additive metric selection builds a SINGLE combined
// multi-line SVG chart. Also handles chart PNG export.
// ==============================================================================

(function() {
  "use strict";

  // ---- Additive Chart Selection ----
  var chartSelection = {};  // { metricId: true }

  // Distinct colour palette for multi-metric chart lines
  var CHART_COLOURS = [
    "#323367", "#CC9900", "#2E8B57", "#CD5C5C", "#4682B4",
    "#9370DB", "#D2691E", "#20B2AA", "#8B4513", "#6A5ACD",
    "#DC143C", "#008080", "#FF6347", "#4169E1", "#32CD32"
  ];

  window.addToChart = function(metricId) {
    if (chartSelection[metricId]) {
      removeFromChart(metricId);
      return;
    }
    chartSelection[metricId] = true;

    // Show chart panel
    var chartPanel = document.getElementById("tk-chart-panel");
    if (chartPanel) chartPanel.style.display = "";

    // Update button state
    var btn = document.querySelector('.tk-add-chart-btn[data-metric-id="' + metricId + '"]');
    if (btn) btn.classList.add("in-chart");

    rebuildCombinedChart();
  };

  window.removeFromChart = function(metricId) {
    delete chartSelection[metricId];

    // Update button state
    var btn = document.querySelector('.tk-add-chart-btn[data-metric-id="' + metricId + '"]');
    if (btn) btn.classList.remove("in-chart");

    // Hide chart panel if no charts selected
    var count = Object.keys(chartSelection).length;
    if (count === 0) {
      var chartPanel = document.getElementById("tk-chart-panel");
      if (chartPanel) chartPanel.style.display = "none";
    }

    rebuildCombinedChart();
  };

  window.getChartSelection = function() {
    return Object.keys(chartSelection).filter(function(k) { return chartSelection[k]; });
  };

  /**
   * Rebuild the single combined multi-line SVG chart from all selected metrics.
   * Shows one line per selected metric for the currently active overview segment.
   */
  function rebuildCombinedChart() {
    var selected = getChartSelection();
    var countEl = document.getElementById("tk-chart-count");
    if (countEl) {
      countEl.textContent = "Charts (" + selected.length + " selected)";
    }

    var chartContainer = document.getElementById("tk-combined-chart");
    if (!chartContainer) return;

    if (selected.length === 0) {
      chartContainer.innerHTML = '<p style="color:#888;text-align:center;padding:40px;">Select metrics from the table to add them to the chart.</p>';
      return;
    }

    // Get current segment via exposed getter (falls back to "Total")
    var segmentName = (typeof getCurrentSegment === "function") ? getCurrentSegment() : "Total";

    // Collect data from data-chart attributes on metric rows
    var seriesData = [];
    var allWaveLabels = null;
    var allWaveIds = null;
    var isPct = false;
    var isNPS = false;

    for (var i = 0; i < selected.length; i++) {
      var metricId = selected[i];
      var row = document.querySelector('.tk-metric-row[data-metric-id="' + metricId + '"]');
      if (!row) continue;

      var chartAttr = row.getAttribute("data-chart");
      if (!chartAttr) continue;

      try {
        var chartData = JSON.parse(chartAttr);
      } catch (e) { continue; }

      if (!chartData || !chartData.series) continue;
      if (!allWaveLabels && chartData.wave_labels) {
        allWaveLabels = chartData.wave_labels;
        allWaveIds = chartData.wave_ids;
      }

      // Find the series for the current segment
      // series is an object keyed by segment name, not an array
      var segSeries = chartData.series[segmentName] || null;
      if (!segSeries) continue;

      // Get metric label from the table row
      var labelEl = row.querySelector(".tk-metric-label");
      var label = labelEl ? labelEl.textContent : metricId;

      if (chartData.is_percentage) isPct = true;
      if (chartData.is_nps) isNPS = true;

      seriesData.push({
        name: label,
        values: segSeries.values,
        metricId: metricId,
        isPct: chartData.is_percentage || false,
        isNPS: chartData.is_nps || false
      });
    }

    if (seriesData.length === 0 || !allWaveLabels) {
      chartContainer.innerHTML = '<p style="color:#888;text-align:center;padding:40px;">No data available for segment: ' + segmentName + '</p>';
      return;
    }

    // Build the SVG
    var svg = buildCombinedSVG(seriesData, allWaveLabels, allWaveIds, segmentName, isPct, isNPS);
    chartContainer.innerHTML = svg;
  }

  /**
   * Build a combined multi-line SVG showing multiple metrics for one segment.
   */
  function buildCombinedSVG(seriesData, waveLabels, waveIds, segmentName, isPct, isNPS) {
    var nWaves = waveLabels.length;
    if (nWaves < 2) return "";

    var width = 960;
    var legendRowH = 30 + Math.ceil(seriesData.length / 3) * 20;
    var height = 380 + legendRowH;
    var margin = { top: 30, right: 20, bottom: 80, left: 60 };
    var plotW = width - margin.left - margin.right;
    var plotH = height - margin.top - margin.bottom - legendRowH;

    // Collect all values for y-axis range
    var allVals = [];
    seriesData.forEach(function(s) {
      s.values.forEach(function(v) { if (v !== null && !isNaN(v)) allVals.push(v); });
    });
    if (allVals.length === 0) return "";

    var yMin, yMax;
    if (isPct) {
      yMin = 0; yMax = 100;
    } else if (isNPS) {
      yMin = -100; yMax = 100;
    } else {
      var dataMin = Math.min.apply(null, allVals);
      var dataMax = Math.max.apply(null, allVals);
      if (dataMax <= 5.5) { yMin = 0; yMax = 5; }
      else if (dataMax <= 10.5) { yMin = 0; yMax = 10; }
      else {
        var range = dataMax - dataMin || 1;
        yMin = Math.max(0, dataMin - range * 0.15);
        yMax = dataMax + range * 0.15;
      }
    }
    var yRange = yMax - yMin || 1;

    function scaleY(v) { return (v - yMin) / yRange * plotH; }
    function formatVal(v) {
      if (isPct) return Math.round(v) + "%";
      if (isNPS) return (v >= 0 ? "+" : "") + v.toFixed(1);
      return v.toFixed(2);
    }

    var parts = [];
    parts.push('<svg class="tk-line-chart" width="' + width + '" height="' + height + '" viewBox="0 0 ' + width + ' ' + height + '" xmlns="http://www.w3.org/2000/svg">');
    parts.push('<rect width="' + width + '" height="' + height + '" fill="#ffffff" rx="6"/>');
    parts.push('<g transform="translate(' + margin.left + ',' + margin.top + ')">');

    // Title
    parts.push('<text x="' + (plotW / 2) + '" y="-10" text-anchor="middle" fill="#1e293b" font-size="14" font-weight="700">Segment: ' + segmentName + '</text>');

    // Gridlines and y-axis labels
    for (var gi = 0; gi <= 4; gi++) {
      var gv = yMin + (yMax - yMin) * gi / 4;
      var gy = plotH - scaleY(gv);
      parts.push('<line x1="0" y1="' + gy.toFixed(1) + '" x2="' + plotW + '" y2="' + gy.toFixed(1) + '" stroke="#e0e0e0" stroke-width="1" stroke-dasharray="4,4"/>');
      parts.push('<text x="-10" y="' + gy.toFixed(1) + '" text-anchor="end" fill="#666" font-size="12" dy="0.35em">' + formatVal(gv) + '</text>');
    }

    // X-axis labels
    for (var xi = 0; xi < nWaves; xi++) {
      var xPos = xi / (nWaves - 1) * plotW;
      parts.push('<text x="' + xPos.toFixed(1) + '" y="' + (plotH + 24) + '" text-anchor="middle" fill="#666" font-size="13" font-weight="600">' + waveLabels[xi] + '</text>');
      parts.push('<line x1="' + xPos.toFixed(1) + '" y1="' + plotH + '" x2="' + xPos.toFixed(1) + '" y2="' + (plotH + 5) + '" stroke="#ccc" stroke-width="1"/>');
    }

    // Draw series
    var allLabelsByWave = [];
    for (var wi = 0; wi < nWaves; wi++) allLabelsByWave.push([]);

    seriesData.forEach(function(series, sIdx) {
      var colour = CHART_COLOURS[sIdx % CHART_COLOURS.length];
      var points = [];

      for (var wi = 0; wi < nWaves; wi++) {
        var val = series.values[wi];
        if (val === null || isNaN(val)) continue;
        var px = wi / (nWaves - 1) * plotW;
        var py = plotH - scaleY(val);
        points.push({ x: px, y: py, val: val, wi: wi });
      }

      if (points.length >= 2) {
        // Smooth path (Catmull-Rom to Bezier) — smoothPathFromPoints expects {x, y} objects
        var pathD = buildSmoothPath(points.map(function(p) { return { x: p.x, y: p.y }; }));
        parts.push('<path d="' + pathD + '" fill="none" stroke="' + colour + '" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>');
      }

      // Points and labels
      points.forEach(function(p) {
        parts.push('<circle cx="' + p.x.toFixed(1) + '" cy="' + p.y.toFixed(1) + '" r="5" fill="' + colour + '" stroke="#fff" stroke-width="2.5"/>');
        allLabelsByWave[p.wi].push({
          x: p.x, y: p.y - 14, text: formatVal(p.val), colour: colour
        });
      });
    });

    // Resolve label collisions per wave
    var minGap = 14;
    allLabelsByWave.forEach(function(labels) {
      if (labels.length === 0) return;
      labels.sort(function(a, b) { return a.y - b.y; });
      for (var j = 1; j < labels.length; j++) {
        if (labels[j].y - labels[j - 1].y < minGap) {
          labels[j].y = labels[j - 1].y + minGap;
        }
      }
      // Clamp
      if (labels.length > 0 && labels[labels.length - 1].y > plotH - 4) {
        var needed = (labels.length - 1) * minGap;
        var startY = Math.max(4, Math.min(labels[0].y, plotH - 4 - needed));
        for (var j = 0; j < labels.length; j++) {
          labels[j].y = Math.max(4, Math.min(startY + j * minGap, plotH - 4));
        }
      }
      labels.forEach(function(lb) {
        parts.push('<text x="' + lb.x.toFixed(1) + '" y="' + lb.y.toFixed(1) + '" text-anchor="middle" fill="' + lb.colour + '" font-size="11" font-weight="700">' + lb.text + '</text>');
      });
    });

    parts.push('</g>');

    // Legend
    var legendY = height - legendRowH + 8;
    var lx = margin.left;
    seriesData.forEach(function(series, sIdx) {
      var colour = CHART_COLOURS[sIdx % CHART_COLOURS.length];
      var itemW = 16 + 6 + series.name.length * 6.5 + 24;
      if (lx + itemW > width - 20) {
        lx = margin.left;
        legendY += 20;
      }
      parts.push('<rect x="' + lx + '" y="' + (legendY + 4) + '" width="16" height="4" rx="2" fill="' + colour + '"/>');
      parts.push('<text x="' + (lx + 22) + '" y="' + (legendY + 5) + '" fill="#555" font-size="11" font-weight="600" dy="0.35em">' + series.name + '</text>');
      lx += itemW;
    });

    parts.push('</svg>');
    return parts.join("\n");
  }

  /**
   * Build smooth SVG path from {x, y} points.
   * Delegates to global smoothPathFromPoints (from metrics_view.js) if available,
   * otherwise falls back to straight line segments.
   */
  function buildSmoothPath(pts) {
    if (typeof smoothPathFromPoints === "function") {
      return smoothPathFromPoints(pts);
    }
    // Fallback: straight line segments
    if (pts.length < 2) return "";
    var d = "M" + pts[0].x.toFixed(1) + "," + pts[0].y.toFixed(1);
    for (var i = 1; i < pts.length; i++) {
      d += " L" + pts[i].x.toFixed(1) + "," + pts[i].y.toFixed(1);
    }
    return d;
  }

  // ---- Chart PNG Export ----
  window.exportChartPNG = function(metricId) {
    var container;
    if (metricId === "combined") {
      container = document.getElementById("tk-combined-chart");
    } else {
      container = document.querySelector('.tk-chart-container[data-metric-id="' + metricId + '"]');
    }
    if (!container) return;

    var svg = container.querySelector(".tk-line-chart");
    if (!svg) return;

    var svgData = new XMLSerializer().serializeToString(svg);
    var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    var svgUrl = URL.createObjectURL(svgBlob);

    var canvas = document.createElement("canvas");
    var ctx = canvas.getContext("2d");
    var img = new Image();

    img.onload = function() {
      var scale = 3;
      canvas.width = img.width * scale;
      canvas.height = img.height * scale;
      ctx.scale(scale, scale);
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, img.width, img.height);
      ctx.drawImage(img, 0, 0);

      canvas.toBlob(function(blob) {
        var url = URL.createObjectURL(blob);
        var a = document.createElement("a");
        a.href = url;
        a.download = "chart_overview.png";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        URL.revokeObjectURL(svgUrl);
      }, "image/png");
    };

    img.src = svgUrl;
  };

  window.exportSelectedChartsSlide = function() {
    var selected = getChartSelection();
    if (selected.length === 0) return;
    exportChartPNG("combined");
  };

  window.pinSelectedCharts = function() {
    var selected = getChartSelection();
    if (selected.length === 0) return;

    var chartContainer = document.getElementById("tk-combined-chart");
    var chartSvg = chartContainer ? chartContainer.innerHTML : "";

    // Capture insight text
    var insightEditor = document.getElementById("overview-insight-editor");
    var insightText = insightEditor ? insightEditor.innerHTML : "";

    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
      metricId: "overview-charts-" + selected.join("-"),
      metricTitle: "Overview: " + selected.length + " metrics (" + ((typeof getCurrentSegment === "function") ? getCurrentSegment() : "Total") + ")",
      visibleSegments: [(typeof getCurrentSegment === "function") ? getCurrentSegment() : "Total"],
      tableHtml: "",
      chartSvg: chartSvg,
      chartVisible: true,
      insightText: insightText,
      timestamp: Date.now(),
      order: typeof pinnedViews !== "undefined" ? pinnedViews.length : 0
    };

    if (typeof pinnedViews !== "undefined") {
      pinnedViews.push(pinObj);
      if (typeof renderPinnedCards === "function") renderPinnedCards();
      if (typeof updatePinBadge === "function") updatePinBadge();
      if (typeof savePinnedData === "function") savePinnedData();
    }
  };

  // Rebuild chart when segment changes
  window.onOverviewSegmentChanged = function() {
    rebuildCombinedChart();
  };

  // ---- Tooltip ----
  document.addEventListener("DOMContentLoaded", function() {
    document.addEventListener("mouseover", function(e) {
      if (e.target.classList && e.target.classList.contains("tk-chart-point")) {
        var segment = e.target.getAttribute("data-segment");
        var wave = e.target.getAttribute("data-wave");
        var value = e.target.getAttribute("data-value");
        e.target.setAttribute("title", segment + " | " + wave + ": " + value);
      }
    });
  });

})();
