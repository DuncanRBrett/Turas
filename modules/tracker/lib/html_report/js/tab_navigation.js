// ==============================================================================
// TurasTracker HTML Report - Tab Navigation
// ==============================================================================
// Handles switching between the 4 report tabs:
//   Summary | Metrics by Segment | Segment Overview | Pinned Views
// ==============================================================================

/**
 * Switch between the 4 report tabs
 * @param {string} tabName - Tab identifier: summary, metrics, overview, pinned
 */
function switchReportTab(tabName) {
  // Deactivate all tab buttons
  document.querySelectorAll(".report-tab").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
  });

  // Hide all panels, show target
  document.querySelectorAll(".tab-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });
  var target = document.getElementById("tab-" + tabName);
  if (target) target.classList.add("active");

  // Trigger resize for sticky columns when switching to overview
  if (tabName === "overview") {
    window.dispatchEvent(new Event("resize"));
  }
}

// Initialise tabs on page load
document.addEventListener("DOMContentLoaded", function() {
  // Default to Summary tab
  switchReportTab("summary");
});
