// ==============================================================================
// Turas Weighting HTML Report - Navigation
// ==============================================================================
// Handles switching between the 3 report tabs:
//   Summary | Weight Details | Method Notes
// And per-weight navigation within Weight Details.
// ==============================================================================

/**
 * Switch between the 3 report tabs
 * @param {string} tabName - Tab identifier: summary, details, notes
 */
function switchReportTab(tabName) {
  document.querySelectorAll(".report-tab").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-tab") === tabName);
  });

  document.querySelectorAll(".tab-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });
  var target = document.getElementById("tab-" + tabName);
  if (target) target.classList.add("active");
}

/**
 * Switch between weight detail panels within the Details tab
 * @param {string} weightId - Weight identifier (sanitised weight name)
 */
function switchWeightDetail(weightId) {
  document.querySelectorAll(".wt-nav-btn").forEach(function(btn) {
    btn.classList.toggle("active", btn.getAttribute("data-weight") === weightId);
  });

  document.querySelectorAll(".wt-detail-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });
  var target = document.getElementById("wt-detail-" + weightId);
  if (target) target.classList.add("active");
}

/**
 * Save the current report HTML as a downloadable file
 */
function saveReportHTML() {
  var meta = document.querySelector('meta[name="turas-source-filename"]');
  var baseName = meta ? meta.getAttribute("content") : "Weighting_Report";
  var filename = baseName + "_Updated.html";

  var html = document.documentElement.outerHTML;
  var blob = new Blob(["<!DOCTYPE html>\n" + html], { type: "text/html" });
  var url = URL.createObjectURL(blob);
  var a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// Initialise on page load
document.addEventListener("DOMContentLoaded", function() {
  switchReportTab("summary");
});
