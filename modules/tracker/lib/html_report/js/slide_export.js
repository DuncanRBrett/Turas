// ==============================================================================
// TurasTracker HTML Report - Slide Export
// ==============================================================================
// PNG export for presentation slides (1280x720 base, 3x render).
// ==============================================================================

(function() {
  "use strict";

  // ---- Slide Export ----
  window.exportSlidePNG = function(metricId, mode) {
    // mode: "chart", "table", or "chart_table"
    mode = mode || "chart";

    var container = document.querySelector('.tk-chart-container[data-metric-id="' + metricId + '"]');
    if (!container && mode !== "table") return;

    // Find the metric row — check overview table first, then metric panels
    var metricRow = document.querySelector('#tk-crosstab-table .tk-metric-row[data-metric-id="' + metricId + '"]');
    if (!metricRow) {
      metricRow = document.querySelector('.tk-metric-row[data-metric-id="' + metricId + '"]');
    }
    var title = metricRow ? metricRow.querySelector(".tk-metric-label").textContent : "Metric";

    // Build slide
    var slideW = 1280;
    var slideH = 720;
    var scale = 3;

    var canvas = document.createElement("canvas");
    canvas.width = slideW * scale;
    canvas.height = slideH * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);

    // Background
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, slideW, slideH);

    // Header bar
    var brandColour = getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367";
    ctx.fillStyle = brandColour;
    ctx.fillRect(0, 0, slideW, 60);

    // Title text
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 22px -apple-system, sans-serif";
    ctx.fillText(title, 30, 40);

    // Subtitle
    ctx.font = "14px -apple-system, sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.8)";
    ctx.fillText("Tracking Report", slideW - 200, 40);

    if (mode === "chart" || mode === "chart_table") {
      // Render chart SVG to canvas
      var svg = container ? container.querySelector(".tk-line-chart") : null;
      if (svg) {
        var svgData = new XMLSerializer().serializeToString(svg);
        var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
        var svgUrl = URL.createObjectURL(svgBlob);
        var img = new Image();

        img.onload = function() {
          var chartY = mode === "chart_table" ? 80 : 80;
          var chartH = mode === "chart_table" ? 300 : 580;
          var aspectRatio = img.width / img.height;
          var drawW = Math.min(slideW - 60, chartH * aspectRatio);
          var drawH = drawW / aspectRatio;
          ctx.drawImage(img, 30, chartY, drawW, drawH);

          if (mode === "chart_table") {
            drawTableOnCanvas(ctx, metricId, metricRow, 30, 400, slideW - 60, 280);
          }

          downloadCanvas(canvas, "slide_" + metricId + ".png");
          URL.revokeObjectURL(svgUrl);
        };
        img.src = svgUrl;
      }
    } else if (mode === "table") {
      drawTableOnCanvas(ctx, metricId, metricRow, 30, 80, slideW - 60, 580);
      downloadCanvas(canvas, "slide_" + metricId + "_table.png");
    }
  };

  /**
   * Render a metric's data table on the canvas.
   * Reads chart data from the metric row's data-chart JSON attribute.
   */
  function drawTableOnCanvas(ctx, metricId, metricRow, x, y, w, h) {
    // Get chart data from the metric row
    var chartAttr = metricRow ? metricRow.getAttribute("data-chart") : null;
    if (!chartAttr) {
      drawPlaceholder(ctx, x, y, w, h, "No data available for this metric");
      return;
    }

    var chartData;
    try { chartData = JSON.parse(chartAttr); } catch (e) {
      drawPlaceholder(ctx, x, y, w, h, "Unable to parse metric data");
      return;
    }

    if (!chartData || !chartData.series || !chartData.wave_labels) {
      drawPlaceholder(ctx, x, y, w, h, "Incomplete metric data");
      return;
    }

    var waveLabels = chartData.wave_labels;
    var nWaves = waveLabels.length;
    var segmentNames = Object.keys(chartData.series);
    var nSegments = segmentNames.length;
    var isPct = chartData.is_percentage;

    // Layout calculations
    var rowH = 26;
    var headerH = 32;
    var labelColW = Math.min(260, w * 0.28);
    var dataColW = (w - labelColW) / nWaves;
    var maxRows = Math.floor((h - headerH) / rowH);
    var visibleSegments = segmentNames.slice(0, maxRows);

    // Background
    ctx.fillStyle = "#fafafa";
    ctx.fillRect(x, y, w, h);

    // Header row background
    ctx.fillStyle = "#f0f0f5";
    ctx.fillRect(x, y, w, headerH);

    // Header text
    ctx.fillStyle = "#555";
    ctx.font = "bold 12px -apple-system, sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("Segment", x + 10, y + 20);
    ctx.textAlign = "center";
    for (var wi = 0; wi < nWaves; wi++) {
      var colX = x + labelColW + wi * dataColW + dataColW / 2;
      ctx.fillText(String(waveLabels[wi]), colX, y + 20);
    }

    // Header bottom border
    ctx.strokeStyle = "#ccc";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, y + headerH);
    ctx.lineTo(x + w, y + headerH);
    ctx.stroke();

    // Segment colour palette (matching chart_controls.js)
    var COLOURS = [
      "#323367", "#CC9900", "#2E8B57", "#CD5C5C", "#4682B4",
      "#9370DB", "#D2691E", "#20B2AA", "#8B4513", "#6A5ACD"
    ];

    // Data rows
    ctx.textAlign = "left";
    for (var si = 0; si < visibleSegments.length; si++) {
      var segName = visibleSegments[si];
      var series = chartData.series[segName];
      if (!series) continue;

      var rowY = y + headerH + si * rowH;

      // Alternating row background
      if (si % 2 === 0) {
        ctx.fillStyle = "#ffffff";
      } else {
        ctx.fillStyle = "#f8f9fa";
      }
      ctx.fillRect(x, rowY, w, rowH);

      // Row border
      ctx.strokeStyle = "#eee";
      ctx.beginPath();
      ctx.moveTo(x, rowY + rowH);
      ctx.lineTo(x + w, rowY + rowH);
      ctx.stroke();

      // Colour dot
      var dotColour = COLOURS[si % COLOURS.length];
      ctx.fillStyle = dotColour;
      ctx.beginPath();
      ctx.arc(x + 14, rowY + rowH / 2, 4, 0, Math.PI * 2);
      ctx.fill();

      // Segment name (strip group prefix for display)
      var displayName = segName;
      var underscoreIdx = segName.indexOf("_");
      if (underscoreIdx > 0 && segName !== "Total") {
        displayName = segName.substring(underscoreIdx + 1);
      }
      ctx.fillStyle = "#333";
      ctx.font = segName === "Total" ? "bold 12px -apple-system, sans-serif" : "12px -apple-system, sans-serif";
      ctx.textAlign = "left";
      ctx.fillText(displayName, x + 24, rowY + rowH / 2 + 4);

      // Values
      ctx.font = "12px -apple-system, sans-serif";
      ctx.textAlign = "center";
      for (var vi = 0; vi < nWaves; vi++) {
        var val = series.values[vi];
        var colCx = x + labelColW + vi * dataColW + dataColW / 2;

        if (val === null || val === undefined || isNaN(val)) {
          ctx.fillStyle = "#bbb";
          ctx.fillText("\u2014", colCx, rowY + rowH / 2 + 4);
        } else {
          ctx.fillStyle = "#222";
          var formatted;
          if (isPct) {
            formatted = Math.round(val) + "%";
          } else if (chartData.is_nps) {
            formatted = (val >= 0 ? "+" : "") + val.toFixed(1);
          } else {
            formatted = val.toFixed(2);
          }
          ctx.fillText(formatted, colCx, rowY + rowH / 2 + 4);
        }
      }

      // Base sizes (small text below values)
      if (series.n) {
        ctx.font = "9px -apple-system, sans-serif";
        ctx.fillStyle = "#999";
        for (var ni = 0; ni < nWaves; ni++) {
          var nVal = series.n[ni];
          if (nVal !== null && nVal !== undefined && !isNaN(nVal)) {
            var nColCx = x + labelColW + ni * dataColW + dataColW / 2;
            ctx.fillText("n=" + nVal, nColCx, rowY + rowH / 2 + 14);
          }
        }
      }
    }

    // Outer border
    ctx.strokeStyle = "#ddd";
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, w, headerH + visibleSegments.length * rowH);

    // Reset text alignment
    ctx.textAlign = "left";
  }

  function drawPlaceholder(ctx, x, y, w, h, message) {
    ctx.fillStyle = "#f8f8f8";
    ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = "#e0e0e0";
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, w, h);
    ctx.fillStyle = "#888";
    ctx.font = "14px -apple-system, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(message, x + w / 2, y + h / 2);
    ctx.textAlign = "left";
  }

  function downloadCanvas(canvas, filename) {
    canvas.toBlob(function(blob) {
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    }, "image/png");
  }

  // ---- Print Report ----
  window.printReport = function() {
    // Show all change rows for print
    var changeRows = document.querySelectorAll(".tk-change-row");
    changeRows.forEach(function(r) { r.classList.add("visible"); });

    window.print();
  };

})();
