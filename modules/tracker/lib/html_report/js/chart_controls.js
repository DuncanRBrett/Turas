// ==============================================================================
// TurasTracker HTML Report - Chart Controls
// ==============================================================================
// Handles line chart interactivity: segment toggling, hover tooltips,
// chart rebuilding, and PNG export.
// ==============================================================================

(function() {
  "use strict";

  // ---- Chart PNG Export ----
  window.exportChartPNG = function(metricId) {
    var container = document.querySelector('.tk-chart-container[data-metric-id="' + metricId + '"]');
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
        a.download = "chart_" + metricId + ".png";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        URL.revokeObjectURL(svgUrl);
      }, "image/png");
    };

    img.src = svgUrl;
  };

  // ---- Tooltip (future enhancement) ----
  // Hover tooltips on chart data points
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
