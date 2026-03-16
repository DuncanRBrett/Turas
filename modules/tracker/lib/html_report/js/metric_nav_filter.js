/* ===========================================================================
 * TurasTracker - Metric Nav Filter
 * ===========================================================================
 * Handles metric type chip filtering and search filtering in the metric
 * navigation sidebar.
 * =========================================================================== */

// Default to first type — set from active chip on load
var activeMetricTypeFilter = (function() {
  var activeChip = document.querySelector(".mv-type-chip.active");
  return activeChip ? (activeChip.getAttribute("data-type-filter") || "all") : "all";
})();

function filterMetricType(typeKey) {
  activeMetricTypeFilter = typeKey;
  document.querySelectorAll(".mv-type-chip").forEach(function(chip) {
    chip.classList.toggle("active", chip.getAttribute("data-type-filter") === typeKey);
  });
  applyMetricNavFilter();
}

function filterMetricNav(query) {
  window._metricSearchQuery = (query || "").toLowerCase();
  applyMetricNavFilter();
}

// Apply filter on load if not "all"
if (activeMetricTypeFilter !== "all") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function() { applyMetricNavFilter(); });
  } else {
    setTimeout(function() { applyMetricNavFilter(); }, 0);
  }
}

function applyMetricNavFilter() {
  var q = (window._metricSearchQuery || "").toLowerCase();
  var typeFilter = activeMetricTypeFilter || "all";

  document.querySelectorAll(".tk-metric-nav-item").forEach(function(item) {
    var textMatch = q === "" || item.textContent.toLowerCase().indexOf(q) >= 0;
    var typeMatch = typeFilter === "all" || item.getAttribute("data-metric-type") === typeFilter;
    item.style.display = (textMatch && typeMatch) ? "" : "none";
  });

  // Hide section headers with no visible items after them
  document.querySelectorAll(".mv-nav-section").forEach(function(section) {
    var next = section.nextElementSibling;
    var hasVisible = false;
    while (next && !next.classList.contains("mv-nav-section")) {
      if (next.classList.contains("tk-metric-nav-item") && next.style.display !== "none") {
        hasVisible = true;
        break;
      }
      next = next.nextElementSibling;
    }
    section.style.display = hasVisible ? "" : "none";
  });
}
