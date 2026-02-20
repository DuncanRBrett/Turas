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

    var metricRow = document.querySelector('.tk-metric-row[data-metric-id="' + metricId + '"]');
    var title = metricRow ? metricRow.querySelector(".tk-metric-label").textContent : "Metric";

    // Build slide SVG
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
            drawTableOnCanvas(ctx, metricId, 30, 400, slideW - 60, 280);
          }

          downloadCanvas(canvas, "slide_" + metricId + ".png");
          URL.revokeObjectURL(svgUrl);
        };
        img.src = svgUrl;
      }
    } else if (mode === "table") {
      drawTableOnCanvas(ctx, metricId, 30, 80, slideW - 60, 580);
      downloadCanvas(canvas, "slide_" + metricId + "_table.png");
    }
  };

  function drawTableOnCanvas(ctx, metricId, x, y, w, h) {
    // Simple table rendering on canvas
    ctx.fillStyle = "#f8f8f8";
    ctx.fillRect(x, y, w, h);

    ctx.strokeStyle = "#e0e0e0";
    ctx.lineWidth = 1;
    ctx.strokeRect(x, y, w, h);

    ctx.fillStyle = "#333";
    ctx.font = "12px -apple-system, sans-serif";
    ctx.fillText("Table export - see HTML report for interactive table", x + 20, y + 30);
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
