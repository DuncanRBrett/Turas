/* ============================================================================
 * TurasTracker - Chart Tooltip & Legend Interaction
 * ============================================================================
 * Hover tooltips for chart data points and interactive legend toggle.
 * VERSION: 1.0.0
 * ============================================================================ */

(function() {
  "use strict";

  // ---- Tooltip ----
  var tooltip = null;

  function createTooltip() {
    if (tooltip) return tooltip;
    tooltip = document.createElement("div");
    tooltip.className = "tk-chart-tooltip";
    tooltip.style.display = "none";
    document.body.appendChild(tooltip);
    return tooltip;
  }

  function showTooltip(e) {
    var el = e.target;
    if (!el.classList.contains("tk-chart-point")) return;
    // Skip points inside the Visualise chart — they have their own rich hover callout
    if (el.closest("#vis-chart")) return;

    var tip = createTooltip();
    var segment = el.getAttribute("data-segment") || "";
    var waveLabel = el.getAttribute("data-wave-label") || el.getAttribute("data-wave") || "";
    var value = el.getAttribute("data-value") || "";
    var change = el.getAttribute("data-change") || "";

    var html = '<div class="tk-tooltip-label">' + segment + ' \u2014 ' + waveLabel + '</div>';
    html += '<div class="tk-tooltip-value">' + value + '</div>';
    if (change) {
      var changeNum = parseFloat(change);
      var arrow = changeNum > 0 ? "\u2191" : (changeNum < 0 ? "\u2193" : "\u2192");
      html += '<div class="tk-tooltip-change">' + arrow + ' ' + change + ' vs previous</div>';
    }

    tip.innerHTML = html;
    tip.style.display = "block";

    // Position tooltip above the point
    var rect = el.getBoundingClientRect();
    var tipRect = tip.getBoundingClientRect();
    var left = rect.left + rect.width / 2 - tipRect.width / 2;
    var top = rect.top - tipRect.height - 10 + window.scrollY;

    // Keep within viewport
    if (left < 4) left = 4;
    if (left + tipRect.width > window.innerWidth - 4) {
      left = window.innerWidth - tipRect.width - 4;
    }
    if (top < window.scrollY + 4) {
      top = rect.bottom + 10 + window.scrollY;
    }

    tip.style.left = left + "px";
    tip.style.top = top + "px";
  }

  function hideTooltip() {
    if (tooltip) tooltip.style.display = "none";
  }

  // Delegate hover events on chart points
  document.addEventListener("mouseover", function(e) {
    if (e.target.classList && e.target.classList.contains("tk-chart-point")) {
      showTooltip(e);
      // Store original radius and enlarge point on hover
      e.target.dataset.origRadius = e.target.getAttribute("r");
      e.target.setAttribute("r", "8");
    }
  });

  document.addEventListener("mouseout", function(e) {
    if (e.target.classList && e.target.classList.contains("tk-chart-point")) {
      hideTooltip();
      e.target.setAttribute("r", e.target.dataset.origRadius || "6");
    }
  });

  // ---- Interactive Legend: Toggle Series Visibility ----
  window.toggleChartSeries = function(segmentName, legendEl) {
    // Find the parent SVG
    var svg = legendEl.closest("svg");
    if (!svg) return;

    // Toggle active state on legend pill
    var rect = legendEl.querySelector("rect");
    var isHidden = legendEl.getAttribute("data-hidden") === "true";

    if (isHidden) {
      // Show series
      legendEl.setAttribute("data-hidden", "false");
      if (rect) {
        rect.setAttribute("fill", "#f0fafa");
        rect.setAttribute("stroke", "#e2e8f0");
      }
      legendEl.style.opacity = "1";
    } else {
      // Hide series
      legendEl.setAttribute("data-hidden", "true");
      if (rect) {
        rect.setAttribute("fill", "#f1f5f9");
        rect.setAttribute("stroke", "#cbd5e1");
      }
      legendEl.style.opacity = "0.4";
    }

    // Toggle visibility of lines, points, labels, area fills for this segment
    var elements = svg.querySelectorAll(
      '[data-segment="' + segmentName + '"]'
    );
    for (var i = 0; i < elements.length; i++) {
      var el = elements[i];
      // Skip legend items themselves
      if (el.closest(".tk-chart-legend-item")) continue;
      el.style.display = isHidden ? "" : "none";
    }
  };

})();
