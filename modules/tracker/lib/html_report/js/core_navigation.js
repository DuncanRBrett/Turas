// ==============================================================================
// TurasTracker HTML Report - Core Navigation
// ==============================================================================
// Handles metric navigation, banner switching, change row toggles,
// sparkline visibility, and view switching.
// ==============================================================================

(function() {
  "use strict";

  // ---- State ----
  var currentSegment = SEGMENTS[0] || "Total";
  var changeRowState = { "vs-prev": false, "vs-base": false };

  // ---- Metric Navigation ----
  window.selectMetric = function(metricId) {
    // Highlight in sidebar
    var items = document.querySelectorAll(".tk-sidebar-item");
    items.forEach(function(item) {
      item.classList.toggle("active", item.getAttribute("data-metric-id") === metricId);
    });

    // Scroll to metric row in table
    var row = document.querySelector('.tk-metric-row[data-metric-id="' + metricId + '"]');
    if (row) {
      row.scrollIntoView({ behavior: "smooth", block: "center" });
      row.style.transition = "background 0.3s";
      row.style.background = "#fffde7";
      setTimeout(function() { row.style.background = ""; }, 1500);
    }

    // Scroll to chart if in chart view
    var chart = document.querySelector('.tk-chart-container[data-metric-id="' + metricId + '"]');
    if (chart && document.getElementById("tk-chart-panel").style.display !== "none") {
      chart.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  };

  window.filterMetrics = function(term) {
    var lower = term.toLowerCase();
    var items = document.querySelectorAll(".tk-sidebar-item");
    items.forEach(function(item) {
      var label = item.textContent.toLowerCase();
      item.classList.toggle("hidden", lower !== "" && label.indexOf(lower) === -1);
    });
  };

  // ---- Segment / Banner Switching ----
  window.switchSegment = function(segmentName) {
    currentSegment = segmentName;

    // Update tab active state
    var tabs = document.querySelectorAll(".tk-segment-tab");
    tabs.forEach(function(tab) {
      tab.classList.toggle("tk-tab-active", tab.getAttribute("data-segment") === segmentName);
    });

    // Show/hide columns
    if (segmentName === "__ALL__") {
      // Show all columns
      var allCells = document.querySelectorAll("[data-segment]");
      allCells.forEach(function(cell) {
        cell.classList.remove("segment-hidden");
      });
    } else {
      // Show only matching segment columns
      SEGMENTS.forEach(function(seg) {
        var cells = document.querySelectorAll('[data-segment="' + seg + '"]');
        cells.forEach(function(cell) {
          cell.classList.toggle("segment-hidden", seg !== segmentName);
        });
      });
    }

    // Update sparklines for the selected segment
    updateSparklines(segmentName);
  };

  function updateSparklines(segmentName) {
    // Sparklines update handled by the active segment highlighting
    // For now, sparklines always show the first segment's data (baked in from R)
  }

  // ---- Change Row Toggles ----
  window.toggleChangeRows = function(type) {
    changeRowState[type] = !changeRowState[type];
    var rows = document.querySelectorAll(".tk-" + type);
    rows.forEach(function(row) {
      row.classList.toggle("visible", changeRowState[type]);
    });
  };

  // ---- Sparkline Toggle ----
  window.toggleSparklines = function() {
    document.body.classList.toggle("hide-sparklines");
  };

  // ---- View Switching (Table / Charts) ----
  window.switchView = function(view) {
    var tablePanel = document.querySelector(".tk-table-panel");
    var chartPanel = document.getElementById("tk-chart-panel");
    var btnTable = document.getElementById("btn-table-view");
    var btnChart = document.getElementById("btn-chart-view");

    if (view === "table") {
      tablePanel.style.display = "";
      chartPanel.style.display = "none";
      btnTable.classList.add("tk-btn-active");
      btnChart.classList.remove("tk-btn-active");
    } else {
      tablePanel.style.display = "none";
      chartPanel.style.display = "";
      btnTable.classList.remove("tk-btn-active");
      btnChart.classList.add("tk-btn-active");
    }
  };

  // ---- Group By Switching ----
  window.switchGroupBy = function(mode) {
    var tbody = document.querySelector(".tk-table tbody");
    if (!tbody) return;

    var rows = Array.from(tbody.querySelectorAll("tr"));
    // Remove existing section rows
    rows.forEach(function(r) {
      if (r.classList.contains("tk-section-row")) {
        r.parentNode.removeChild(r);
      }
    });

    // Get metric rows and their change rows
    var metricGroups = [];
    var dataRows = Array.from(tbody.querySelectorAll("tr"));
    var i = 0;

    while (i < dataRows.length) {
      var row = dataRows[i];
      if (row.classList.contains("tk-metric-row")) {
        var group = { metric: row, changes: [] };
        i++;
        while (i < dataRows.length && dataRows[i].classList.contains("tk-change-row")) {
          group.changes.push(dataRows[i]);
          i++;
        }
        metricGroups.push(group);
      } else {
        i++;
      }
    }

    // Sort by group-by mode
    if (mode === "section") {
      metricGroups.sort(function(a, b) {
        var sA = (a.metric.querySelector(".tk-metric-label") || {}).textContent || "";
        var sB = (b.metric.querySelector(".tk-metric-label") || {}).textContent || "";
        return sA.localeCompare(sB);
      });
      // Re-insert with section headers (based on data-chart section)
      rebuildTableWithSections(tbody, metricGroups, function(row) {
        var container = document.querySelector('.tk-chart-container[data-metric-id="' + row.getAttribute("data-metric-id") + '"]');
        return container ? container.getAttribute("data-section") : "(Ungrouped)";
      });
    } else if (mode === "metric_type") {
      // Group by metric name (mean, nps, top2_box, etc.)
      rebuildTableWithSections(tbody, metricGroups, function(row) {
        var chartData = row.getAttribute("data-chart");
        if (chartData) {
          try {
            var d = JSON.parse(chartData);
            return formatMetricType(d.metric_name);
          } catch(e) { return "Other"; }
        }
        return "Other";
      });
    } else if (mode === "question") {
      rebuildTableWithSections(tbody, metricGroups, function(row) {
        return row.getAttribute("data-q-code") || "(Unknown)";
      });
    }
  };

  function rebuildTableWithSections(tbody, metricGroups, sectionFn) {
    // Preserve base row
    var baseRow = tbody.querySelector(".tk-base-row");

    // Clear tbody
    while (tbody.firstChild) {
      tbody.removeChild(tbody.firstChild);
    }

    // Group metrics
    var groups = {};
    metricGroups.forEach(function(g) {
      var section = sectionFn(g.metric);
      if (!groups[section]) groups[section] = [];
      groups[section].push(g);
    });

    // Sort sections
    var sectionKeys = Object.keys(groups).sort();

    var totalCols = document.querySelectorAll(".tk-segment-header-row th").length;

    sectionKeys.forEach(function(sec) {
      // Section header row
      var secRow = document.createElement("tr");
      secRow.className = "tk-section-row";
      var secCell = document.createElement("td");
      secCell.className = "tk-section-cell";
      secCell.colSpan = totalCols;
      secCell.textContent = sec;
      secRow.appendChild(secCell);
      tbody.appendChild(secRow);

      groups[sec].forEach(function(g) {
        tbody.appendChild(g.metric);
        g.changes.forEach(function(cr) {
          tbody.appendChild(cr);
        });
      });
    });

    // Re-append base row
    if (baseRow) tbody.appendChild(baseRow);
  }

  function formatMetricType(name) {
    var labels = {
      "mean": "Means & Averages",
      "nps_score": "NPS Scores",
      "nps": "NPS Scores",
      "top_box": "Box Categories",
      "top2_box": "Box Categories",
      "top3_box": "Box Categories",
      "bottom_box": "Box Categories",
      "bottom2_box": "Box Categories",
      "promoters_pct": "NPS Components",
      "passives_pct": "NPS Components",
      "detractors_pct": "NPS Components"
    };
    return labels[name] || "Other Metrics";
  }

  // ---- Help Overlay ----
  window.toggleHelpOverlay = function() {
    var overlay = document.getElementById("tk-help-overlay");
    if (overlay) {
      overlay.style.display = overlay.style.display === "none" ? "flex" : "none";
    }
  };

  // ---- Init ----
  document.addEventListener("DOMContentLoaded", function() {
    // If only one segment, no need to switch
    if (SEGMENTS.length <= 1) {
      // Hide segment tabs
      var tabBar = document.querySelector(".tk-segment-tabs");
      if (tabBar) tabBar.style.display = "none";
    }
  });

})();
