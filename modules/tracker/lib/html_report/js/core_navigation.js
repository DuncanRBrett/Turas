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

  // ---- Column Sorting for Segment Overview ----
  var overviewSortState = { col: -1, dir: "desc" };

  window.sortOverviewColumn = function(headerEl) {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    var colIndex = parseInt(headerEl.getAttribute("data-col-index"), 10);
    if (isNaN(colIndex)) return;

    // Toggle direction
    var dir = "desc";
    if (overviewSortState.col === colIndex && overviewSortState.dir === "desc") {
      dir = "asc";
    }
    overviewSortState = { col: colIndex, dir: dir };

    // Update sort indicators
    table.querySelectorAll(".tk-sortable").forEach(function(th) {
      th.classList.remove("sort-asc", "sort-desc");
    });
    headerEl.classList.add(dir === "asc" ? "sort-asc" : "sort-desc");

    var tbody = table.querySelector("tbody");
    var rows = Array.from(tbody.querySelectorAll("tr"));

    // Group metric rows with their change rows
    var groups = [];
    var baseRow = null;
    var i = 0;
    while (i < rows.length) {
      var row = rows[i];
      if (row.classList.contains("tk-base-row")) {
        baseRow = row;
        i++;
      } else if (row.classList.contains("tk-section-row")) {
        i++;  // Skip section rows — they'll be removed during sort
      } else if (row.classList.contains("tk-metric-row")) {
        var group = { metric: row, changes: [], sortVal: 0 };
        var cells = row.querySelectorAll("td");
        if (colIndex < cells.length) {
          group.sortVal = parseFloat(cells[colIndex].getAttribute("data-sort-val")) || 0;
        }
        i++;
        while (i < rows.length && rows[i].classList.contains("tk-change-row")) {
          group.changes.push(rows[i]);
          i++;
        }
        groups.push(group);
      } else {
        i++;
      }
    }

    // Sort groups
    groups.sort(function(a, b) {
      return dir === "desc" ? b.sortVal - a.sortVal : a.sortVal - b.sortVal;
    });

    // Rebuild tbody (no section rows when sorted by column)
    while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
    groups.forEach(function(g) {
      tbody.appendChild(g.metric);
      g.changes.forEach(function(cr) { tbody.appendChild(cr); });
    });
    if (baseRow) tbody.appendChild(baseRow);
  };


  // ---- Metric Type Filter for Segment Overview ----
  var overviewTypeFilter = "all";

  window.filterOverviewByType = function(typeKey) {
    overviewTypeFilter = typeKey;

    // Update chip active state
    document.querySelectorAll(".tk-overview-type-chip").forEach(function(chip) {
      chip.classList.toggle("active", chip.getAttribute("data-type-filter") === typeKey);
    });

    applyOverviewFilters();
  };


  // ---- Row Search Filter for Segment Overview ----
  var overviewSearchQuery = "";

  window.filterOverviewRows = function(query) {
    overviewSearchQuery = (query || "").toLowerCase();
    applyOverviewFilters();
  };


  /**
   * Apply combined type + text filters to Segment Overview table rows.
   * Hides metric rows (+ associated change rows) that don't match.
   * Hides section headers if all their child rows are hidden.
   */
  function applyOverviewFilters() {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    var rows = table.querySelectorAll("tbody tr.tk-metric-row");
    rows.forEach(function(row) {
      var typeAttr = row.getAttribute("data-metric-type") || "other";
      var label = (row.querySelector(".tk-metric-label") || {}).textContent || "";

      var typeMatch = overviewTypeFilter === "all" || typeAttr === overviewTypeFilter;
      var textMatch = overviewSearchQuery === "" || label.toLowerCase().indexOf(overviewSearchQuery) >= 0;
      var visible = typeMatch && textMatch;

      row.classList.toggle("row-filtered", !visible);

      // Also hide/show associated change rows
      var metricId = row.getAttribute("data-metric-id");
      if (metricId) {
        table.querySelectorAll('.tk-change-row[data-metric-id="' + metricId + '"]').forEach(function(cr) {
          cr.classList.toggle("row-filtered", !visible);
        });
      }
    });

    // Hide section headers with no visible children
    table.querySelectorAll("tbody tr.tk-section-row").forEach(function(secRow) {
      var next = secRow.nextElementSibling;
      var hasVisible = false;
      while (next && !next.classList.contains("tk-section-row")) {
        if (next.classList.contains("tk-metric-row") && !next.classList.contains("row-filtered")) {
          hasVisible = true;
          break;
        }
        next = next.nextElementSibling;
      }
      secRow.style.display = hasVisible ? "" : "none";
    });

    // Also update sidebar items
    document.querySelectorAll(".tk-sidebar-item").forEach(function(item) {
      var metricId = item.getAttribute("data-metric-id");
      var label = item.textContent.toLowerCase();
      var textMatch = overviewSearchQuery === "" || label.indexOf(overviewSearchQuery) >= 0;
      item.classList.toggle("hidden", !textMatch);
    });
  }


  // ---- Collapsible Sections ----
  window.toggleOverviewSection = function(sectionCell) {
    var sectionRow = sectionCell.closest("tr");
    if (!sectionRow) return;

    var isCollapsed = sectionRow.classList.toggle("section-collapsed");

    // Toggle all rows until next section row
    var next = sectionRow.nextElementSibling;
    while (next && !next.classList.contains("tk-section-row")) {
      if (isCollapsed) {
        next.classList.add("section-hidden");
      } else {
        next.classList.remove("section-hidden");
      }
      next = next.nextElementSibling;
    }
  };


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
