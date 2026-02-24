// ==============================================================================
// TurasTracker HTML Report - Core Navigation
// ==============================================================================
// Handles metric navigation, segment switching (dropdown + sidebar),
// change row toggles, sparkline visibility, view switching,
// column sorting, metric type filter, row search, sort-by-metric,
// collapsible sections, and row hide/show.
// ==============================================================================

(function() {
  "use strict";

  // ---- State ----
  var currentSegment = SEGMENTS[0] || "Total";
  var changeRowState = { "vs-prev": false, "vs-base": false };
  var originalRowOrder = [];  // Captured on DOMContentLoaded for "Original Order" sort
  var hiddenMetrics = {};     // { metricId: true } — user-hidden rows

  // Expose currentSegment for chart_controls.js
  window.getCurrentSegment = function() { return currentSegment; };

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

    // Update dropdown value (in case called from sidebar click)
    var dropdown = document.getElementById("segment-selector");
    if (dropdown && dropdown.value !== segmentName) {
      dropdown.value = segmentName;
    }

    // Update sidebar active state — deactivate group headers and individual items
    document.querySelectorAll(".tk-seg-sidebar-item").forEach(function(item) {
      item.classList.toggle("active", item.getAttribute("data-segment") === segmentName);
    });
    document.querySelectorAll(".tk-sidebar-section").forEach(function(el) {
      el.classList.remove("active");
    });

    // Show only matching segment columns in the overview table
    // Skip sidebar items — they must always remain visible
    SEGMENTS.forEach(function(seg) {
      var cells = document.querySelectorAll('[data-segment="' + seg + '"]');
      cells.forEach(function(cell) {
        if (cell.classList.contains("tk-seg-sidebar-item")) return;
        // Only toggle cells inside the overview table, not the metrics panels
        if (cell.closest("#tab-overview") || cell.closest(".tk-table-panel")) {
          cell.classList.toggle("segment-hidden", seg !== segmentName);
        }
      });
    });

    // Update "Showing" label
    var showingEl = document.getElementById("tk-segment-showing");
    if (showingEl) {
      showingEl.innerHTML = "Showing: <strong>" + segmentName + "</strong>";
    }

    // Update sparklines for the selected segment
    updateSparklines(segmentName);

    // Rebuild combined overview chart for new segment
    if (typeof onOverviewSegmentChanged === "function") {
      onOverviewSegmentChanged();
    }
  };

  /**
   * Show all segments from a banner group (e.g., all Campus or all Tenure segments).
   * Reads the group's segment list from the data-group-segments attribute on the header.
   * @param {string} groupName - The banner group name (e.g., "Campus")
   * @param {HTMLElement} headerEl - The clicked group header element
   */
  window.showBannerGroup = function(groupName, headerEl) {
    // Read segment names from the header's data attribute
    var segAttr = headerEl ? headerEl.getAttribute("data-group-segments") : "";
    if (!segAttr) return;
    var groupSegs = segAttr.split(",");

    currentSegment = groupName;

    // Deactivate all individual segment items, activate items in this group
    document.querySelectorAll(".tk-seg-sidebar-item").forEach(function(item) {
      var seg = item.getAttribute("data-segment");
      item.classList.toggle("active", groupSegs.indexOf(seg) !== -1);
    });

    // Highlight this group header, deactivate others
    document.querySelectorAll(".tk-sidebar-section").forEach(function(el) {
      el.classList.remove("active");
    });
    if (headerEl) headerEl.classList.add("active");

    // Show only this group's segment columns, hide all others
    SEGMENTS.forEach(function(seg) {
      var show = groupSegs.indexOf(seg) !== -1;
      var cells = document.querySelectorAll('[data-segment="' + seg + '"]');
      cells.forEach(function(cell) {
        if (cell.classList.contains("tk-seg-sidebar-item")) return;
        if (cell.closest("#tab-overview") || cell.closest(".tk-table-panel")) {
          cell.classList.toggle("segment-hidden", !show);
        }
      });
    });

    // Update "Showing" label
    var showingEl = document.getElementById("tk-segment-showing");
    if (showingEl) {
      showingEl.innerHTML = "Showing: <strong>" + groupName + "</strong> (" + groupSegs.length + " segments)";
    }
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
    var tbody = document.querySelector("#tk-crosstab-table tbody");
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
      rebuildTableWithSections(tbody, metricGroups, function(row) {
        return row.getAttribute("data-section") || "(Ungrouped)";
      });
    } else if (mode === "metric_type") {
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

    // Reset sort-by dropdown to original when switching group-by
    var sortSelect = document.getElementById("sort-by-select");
    if (sortSelect) sortSelect.value = "original";
  };

  function rebuildTableWithSections(tbody, metricGroups, sectionFn) {
    var baseRow = tbody.querySelector(".tk-base-row");

    while (tbody.firstChild) {
      tbody.removeChild(tbody.firstChild);
    }

    var groups = {};
    metricGroups.forEach(function(g) {
      var section = sectionFn(g.metric);
      if (!groups[section]) groups[section] = [];
      groups[section].push(g);
    });

    var sectionKeys = Object.keys(groups).sort(function(a, b) {
      // Always push "(Ungrouped)" to the bottom
      if (a === "(Ungrouped)") return 1;
      if (b === "(Ungrouped)") return -1;
      return a.localeCompare(b);
    });
    var totalCols = 1 + SEGMENTS.length * N_WAVES;

    sectionKeys.forEach(function(sec) {
      var secRow = document.createElement("tr");
      secRow.className = "tk-section-row";
      var secCell = document.createElement("td");
      secCell.className = "tk-section-cell";
      secCell.colSpan = totalCols;
      secCell.innerHTML = "<span class=\"section-chevron\">&#x25BC;</span> " + sec;
      secCell.setAttribute("onclick", "toggleOverviewSection(this)");
      secRow.appendChild(secCell);
      tbody.appendChild(secRow);

      groups[sec].forEach(function(g) {
        tbody.appendChild(g.metric);
        g.changes.forEach(function(cr) {
          tbody.appendChild(cr);
        });
      });
    });

    if (baseRow) tbody.insertBefore(baseRow, tbody.firstChild);
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
    if (baseRow) tbody.insertBefore(baseRow, tbody.firstChild);

    // Reset sort-by dropdown when user column-sorts
    var sortSelect = document.getElementById("sort-by-select");
    if (sortSelect) sortSelect.value = "original";
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
  }


  // ---- Sort Overview By (Metric Name / Original Order) ----
  window.sortOverviewBy = function(mode) {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;
    var tbody = table.querySelector("tbody");
    if (!tbody) return;

    // Clear column sort indicators
    table.querySelectorAll(".tk-sortable").forEach(function(th) {
      th.classList.remove("sort-asc", "sort-desc");
    });
    overviewSortState = { col: -1, dir: "desc" };

    if (mode === "original") {
      // Restore original row order
      restoreOriginalOrder(tbody);
      return;
    }

    // Gather metric groups (metric row + change rows)
    var rows = Array.from(tbody.querySelectorAll("tr"));
    var sectionRows = [];
    var metricGroups = [];
    var baseRow = null;
    var i = 0;

    while (i < rows.length) {
      var row = rows[i];
      if (row.classList.contains("tk-base-row")) {
        baseRow = row;
        i++;
      } else if (row.classList.contains("tk-section-row")) {
        i++;
      } else if (row.classList.contains("tk-metric-row")) {
        var label = (row.querySelector(".tk-metric-label") || {}).textContent || "";
        var group = { metric: row, changes: [], label: label };
        i++;
        while (i < rows.length && rows[i].classList.contains("tk-change-row")) {
          group.changes.push(rows[i]);
          i++;
        }
        metricGroups.push(group);
      } else {
        i++;
      }
    }

    // Sort by label
    var descending = mode === "metric_name_desc";
    metricGroups.sort(function(a, b) {
      var cmp = a.label.localeCompare(b.label);
      return descending ? -cmp : cmp;
    });

    // Rebuild tbody (no section headers when sorted alphabetically)
    while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
    metricGroups.forEach(function(g) {
      tbody.appendChild(g.metric);
      g.changes.forEach(function(cr) { tbody.appendChild(cr); });
    });
    if (baseRow) tbody.insertBefore(baseRow, tbody.firstChild);
  };

  /**
   * Restore original row order captured on DOMContentLoaded.
   */
  function restoreOriginalOrder(tbody) {
    if (originalRowOrder.length === 0) return;

    // Detach all rows
    var baseRow = tbody.querySelector(".tk-base-row");
    while (tbody.firstChild) tbody.removeChild(tbody.firstChild);

    // Re-insert in original order
    for (var i = 0; i < originalRowOrder.length; i++) {
      tbody.appendChild(originalRowOrder[i]);
    }
    if (baseRow) tbody.insertBefore(baseRow, tbody.firstChild);
  }


  // ---- Row Hide/Show (grey out, not full hide) ----
  window.toggleRowVisibility = function(metricId) {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    var isHidden = !hiddenMetrics[metricId];
    hiddenMetrics[metricId] = isHidden;

    // Toggle grey-out on metric row and its change rows
    var metricRow = table.querySelector('.tk-metric-row[data-metric-id="' + metricId + '"]');
    if (metricRow) {
      metricRow.classList.toggle("row-hidden-user", isHidden);
      // Toggle eye button visual state
      var btn = metricRow.querySelector(".tk-row-hide-btn");
      if (btn) btn.classList.toggle("row-greyed", isHidden);
    }
    table.querySelectorAll('.tk-change-row[data-metric-id="' + metricId + '"]').forEach(function(cr) {
      cr.classList.toggle("row-hidden-user", isHidden);
    });

    updateHiddenRowsIndicator();
  };

  window.showAllHiddenRows = function() {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    table.querySelectorAll(".row-hidden-user").forEach(function(el) {
      el.classList.remove("row-hidden-user");
    });
    table.querySelectorAll(".tk-row-hide-btn.row-greyed").forEach(function(btn) {
      btn.classList.remove("row-greyed");
    });
    hiddenMetrics = {};
    updateHiddenRowsIndicator();
  };

  function updateHiddenRowsIndicator() {
    var count = Object.keys(hiddenMetrics).filter(function(k) { return hiddenMetrics[k]; }).length;
    var indicator = document.getElementById("hidden-rows-indicator");
    var countEl = document.getElementById("hidden-rows-count");
    if (indicator) indicator.style.display = count > 0 ? "flex" : "none";
    if (countEl) countEl.textContent = count + " greyed out";
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


  // ---- Overview Insight ----
  window.toggleOverviewInsight = function() {
    var area = document.querySelector("#tab-overview .insight-area");
    if (!area) return;
    var toggleBtn = area.querySelector(".insight-toggle");
    var container = area.querySelector(".insight-container");
    if (container.style.display === "none" || container.style.display === "") {
      container.style.display = "block";
      if (toggleBtn) toggleBtn.style.display = "none";
      var editor = container.querySelector(".insight-editor");
      if (editor) editor.focus();
    } else {
      container.style.display = "none";
      if (toggleBtn) toggleBtn.style.display = "";
    }
  };

  window.dismissOverviewInsight = function() {
    var area = document.querySelector("#tab-overview .insight-area");
    if (!area) return;
    var editor = area.querySelector(".insight-editor");
    var container = area.querySelector(".insight-container");
    var toggleBtn = area.querySelector(".insight-toggle");
    if (editor) editor.innerHTML = "";
    if (container) container.style.display = "none";
    if (toggleBtn) toggleBtn.style.display = "";
  };

  // ---- Overview Pin ----
  window.pinOverviewView = function() {
    var tablePanel = document.querySelector("#tab-overview .tk-table-panel");
    var chartPanel = document.getElementById("tk-chart-panel");
    var insightEditor = document.getElementById("overview-insight-editor");

    // Clone table, remove hidden/filtered/collapsed elements — capture only the current view
    var cleanHtml = "";
    if (tablePanel && tablePanel.style.display !== "none") {
      var clone = tablePanel.cloneNode(true);
      clone.querySelectorAll(".segment-hidden").forEach(function(el) { el.parentNode.removeChild(el); });
      clone.querySelectorAll(".row-hidden-user").forEach(function(el) { el.parentNode.removeChild(el); });
      clone.querySelectorAll(".row-filtered").forEach(function(el) { el.parentNode.removeChild(el); });
      clone.querySelectorAll(".section-hidden").forEach(function(el) { el.parentNode.removeChild(el); });
      // Remove hidden change rows (only keep ones with class "visible")
      clone.querySelectorAll(".tk-change-row").forEach(function(el) {
        if (!el.classList.contains("visible")) el.parentNode.removeChild(el);
      });
      // Remove collapsed section headers and their hidden rows
      clone.querySelectorAll(".tk-section-row.section-collapsed").forEach(function(el) {
        el.parentNode.removeChild(el);
      });
      // Remove interactive elements that shouldn't appear in pin
      clone.querySelectorAll(".tk-row-hide-btn, .tk-add-chart-btn, .tk-sortable").forEach(function(el) {
        el.removeAttribute("onclick");
      });
      cleanHtml = clone.innerHTML;
    }

    // Chart SVG
    var chartSvg = "";
    var chartVisible = false;
    if (chartPanel && chartPanel.style.display !== "none") {
      chartVisible = true;
      chartSvg = chartPanel.innerHTML;
    }

    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
      metricId: "overview-" + currentSegment,
      metricTitle: "Segment Overview: " + currentSegment,
      visibleSegments: [currentSegment],
      tableHtml: cleanHtml,
      chartSvg: chartSvg,
      chartVisible: chartVisible,
      insightText: insightEditor ? insightEditor.innerHTML : "",
      timestamp: Date.now(),
      order: pinnedViews.length
    };

    pinnedViews.push(pinObj);
    if (typeof renderPinnedCards === "function") renderPinnedCards();
    if (typeof updatePinBadge === "function") updatePinBadge();
    if (typeof savePinnedData === "function") savePinnedData();

    // Capture a branded PNG snapshot asynchronously for reliable export
    captureOverviewPng(pinObj);
  };

  /**
   * Generate a branded PNG of the currently visible overview table and store
   * it in pinObj.pngDataUrl. Uses the same DOM-reading approach as
   * exportOverviewSlide() so the image reflects exactly what is visible.
   */
  window.captureOverviewPng = function(pinObj) {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    var brandColour = getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367";

    // Extract visible data from the DOM table (same logic as exportOverviewSlide)
    var headers = [];
    var headerRow = table.querySelector("thead tr.tk-wave-header-row");
    if (headerRow) {
      headerRow.querySelectorAll("th").forEach(function(th) {
        if (th.classList.contains("segment-hidden")) return;
        headers.push(th.textContent.trim());
      });
    }

    var dataRows = [];
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      if (tr.classList.contains("section-hidden")) return;
      if (tr.classList.contains("row-hidden-user")) return;
      if (tr.classList.contains("row-filtered")) return;
      if (tr.style.display === "none") return;
      if (tr.classList.contains("tk-change-row") && !tr.classList.contains("visible")) return;

      var cells = [];
      var rowType = "data";
      if (tr.classList.contains("tk-section-row")) rowType = "section";
      else if (tr.classList.contains("tk-base-row")) rowType = "base";
      else if (tr.classList.contains("tk-change-row")) rowType = "change";

      tr.querySelectorAll("td, th").forEach(function(cell) {
        if (cell.classList.contains("segment-hidden")) return;
        var label = cell.querySelector(".tk-metric-label");
        cells.push(label ? label.textContent.trim() : cell.textContent.trim());
      });

      if (cells.length > 0) {
        dataRows.push({ cells: cells, type: rowType });
      }
    });

    if (dataRows.length === 0) return;

    // Canvas setup
    var nCols = headers.length || 4;
    var slideW = Math.max(1280, nCols * 120 + 300);
    var rowH = 24;
    var headerH = 36;
    var titleBarH = 60;
    var pad = 30;
    var slideH = Math.max(720, titleBarH + pad + headerH + dataRows.length * rowH + pad * 2);
    var scale = 3;

    var canvas = document.createElement("canvas");
    canvas.width = slideW * scale;
    canvas.height = slideH * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);

    // White background
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, slideW, slideH);

    // Header bar
    ctx.fillStyle = brandColour;
    ctx.fillRect(0, 0, slideW, titleBarH);
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 22px -apple-system, sans-serif";
    ctx.fillText(pinObj.metricTitle, pad, 40);
    ctx.font = "14px -apple-system, sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.8)";
    ctx.fillText("Tracking Report", slideW - 200, 40);

    // Table layout
    var tableX = pad;
    var tableY = titleBarH + pad;
    var labelColW = Math.min(400, slideW * 0.35);
    var dataColW = (slideW - pad * 2 - labelColW) / Math.max(1, nCols - 1);

    // Column headers
    ctx.fillStyle = "#f0f0f5";
    ctx.fillRect(tableX, tableY, slideW - pad * 2, headerH);
    ctx.fillStyle = "#555";
    ctx.font = "bold 12px -apple-system, sans-serif";
    ctx.textAlign = "left";
    if (headers.length > 0) ctx.fillText(headers[0], tableX + 10, tableY + 22);
    ctx.textAlign = "center";
    for (var hi = 1; hi < headers.length; hi++) {
      var hx = tableX + labelColW + (hi - 1) * dataColW + dataColW / 2;
      ctx.fillText(headers[hi], hx, tableY + 22);
    }

    // Data rows
    var curY = tableY + headerH;
    for (var ri = 0; ri < dataRows.length; ri++) {
      var row = dataRows[ri];

      if (row.type === "section") {
        ctx.fillStyle = "#f4f5f7";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = brandColour;
        ctx.font = "bold 11px -apple-system, sans-serif";
        ctx.textAlign = "left";
        ctx.fillText(row.cells[0] || "", tableX + 10, curY + 16);
        curY += rowH;
        continue;
      }

      if (row.type === "base") {
        ctx.fillStyle = "#fafbfc";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = "#888";
        ctx.font = "11px -apple-system, sans-serif";
      } else if (row.type === "change") {
        ctx.fillStyle = "#fafafa";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = "#888";
        ctx.font = "11px -apple-system, sans-serif";
      } else {
        ctx.fillStyle = ri % 2 === 0 ? "#ffffff" : "#fafbfc";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = "#1e293b";
        ctx.font = "12px -apple-system, sans-serif";
      }

      // Row border
      ctx.strokeStyle = "#eee";
      ctx.lineWidth = 0.5;
      ctx.beginPath();
      ctx.moveTo(tableX, curY + rowH);
      ctx.lineTo(tableX + slideW - pad * 2, curY + rowH);
      ctx.stroke();

      // Label cell
      ctx.textAlign = "left";
      if (row.cells.length > 0) {
        var labelText = row.cells[0];
        if (labelText.length > 50) labelText = labelText.substring(0, 48) + "...";
        ctx.fillText(labelText, tableX + 10, curY + 16);
      }

      // Value cells
      ctx.textAlign = "center";
      for (var ci = 1; ci < row.cells.length; ci++) {
        var cx = tableX + labelColW + (ci - 1) * dataColW + dataColW / 2;
        ctx.fillText(row.cells[ci] || "", cx, curY + 16);
      }

      curY += rowH;
    }

    // Outer border
    ctx.strokeStyle = "#ddd";
    ctx.lineWidth = 1;
    ctx.strokeRect(tableX, tableY, slideW - pad * 2, curY - tableY);

    // Store as data URL
    try {
      pinObj.pngDataUrl = canvas.toDataURL("image/png");
      if (typeof renderPinnedCards === "function") renderPinnedCards();
      if (typeof savePinnedData === "function") savePinnedData();
    } catch (e) {
      // Canvas tainted or too large — fallback to HTML rendering
    }
  }

  // ---- Overview Slide Export ----
  // Renders only the currently visible table rows/columns as a branded PNG slide.
  window.exportOverviewSlide = function() {
    var table = document.getElementById("tk-crosstab-table");
    if (!table) return;

    var brandColour = getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367";

    // Extract visible data from the DOM table
    var headers = [];
    var headerRow = table.querySelector("thead tr.tk-wave-header-row");
    if (headerRow) {
      headerRow.querySelectorAll("th").forEach(function(th) {
        if (th.classList.contains("segment-hidden")) return;
        headers.push(th.textContent.trim());
      });
    }

    var dataRows = [];
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      // Skip hidden rows of all types
      if (tr.classList.contains("section-hidden")) return;
      if (tr.classList.contains("row-hidden-user")) return;
      if (tr.classList.contains("row-filtered")) return;
      if (tr.style.display === "none") return;
      if (tr.classList.contains("tk-change-row") && !tr.classList.contains("visible")) return;

      var cells = [];
      var rowType = "data";
      if (tr.classList.contains("tk-section-row")) rowType = "section";
      else if (tr.classList.contains("tk-base-row")) rowType = "base";
      else if (tr.classList.contains("tk-change-row")) rowType = "change";

      tr.querySelectorAll("td, th").forEach(function(cell) {
        if (cell.classList.contains("segment-hidden")) return;
        var label = cell.querySelector(".tk-metric-label");
        cells.push(label ? label.textContent.trim() : cell.textContent.trim());
      });

      if (cells.length > 0) {
        dataRows.push({ cells: cells, type: rowType });
      }
    });

    // Canvas setup
    var nCols = headers.length || 4;
    var slideW = Math.max(1280, nCols * 120 + 300);
    var rowH = 24;
    var headerH = 36;
    var titleBarH = 60;
    var pad = 30;
    var slideH = Math.max(720, titleBarH + pad + headerH + dataRows.length * rowH + pad * 2);
    var scale = 3;

    var canvas = document.createElement("canvas");
    canvas.width = slideW * scale;
    canvas.height = slideH * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);

    // White background
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, slideW, slideH);

    // Header bar
    ctx.fillStyle = brandColour;
    ctx.fillRect(0, 0, slideW, titleBarH);
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 22px -apple-system, sans-serif";
    ctx.fillText("Segment Overview: " + currentSegment, pad, 40);
    ctx.font = "14px -apple-system, sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.8)";
    ctx.fillText("Tracking Report", slideW - 200, 40);

    // Table layout
    var tableX = pad;
    var tableY = titleBarH + pad;
    var labelColW = Math.min(400, slideW * 0.35);
    var dataColW = (slideW - pad * 2 - labelColW) / Math.max(1, nCols - 1);

    // Column headers
    ctx.fillStyle = "#f0f0f5";
    ctx.fillRect(tableX, tableY, slideW - pad * 2, headerH);
    ctx.fillStyle = "#555";
    ctx.font = "bold 12px -apple-system, sans-serif";
    ctx.textAlign = "left";
    if (headers.length > 0) ctx.fillText(headers[0], tableX + 10, tableY + 22);
    ctx.textAlign = "center";
    for (var hi = 1; hi < headers.length; hi++) {
      var hx = tableX + labelColW + (hi - 1) * dataColW + dataColW / 2;
      ctx.fillText(headers[hi], hx, tableY + 22);
    }

    // Data rows
    var curY = tableY + headerH;
    for (var ri = 0; ri < dataRows.length; ri++) {
      var row = dataRows[ri];

      // Row background
      if (row.type === "section") {
        ctx.fillStyle = "#f4f5f7";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = brandColour;
        ctx.font = "bold 11px -apple-system, sans-serif";
        ctx.textAlign = "left";
        ctx.fillText(row.cells[0] || "", tableX + 10, curY + 16);
        curY += rowH;
        continue;
      }

      if (row.type === "base") {
        ctx.fillStyle = "#fafbfc";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = "#888";
        ctx.font = "11px -apple-system, sans-serif";
      } else if (row.type === "change") {
        ctx.fillStyle = "#fafafa";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = "#888";
        ctx.font = "11px -apple-system, sans-serif";
      } else {
        ctx.fillStyle = ri % 2 === 0 ? "#ffffff" : "#fafbfc";
        ctx.fillRect(tableX, curY, slideW - pad * 2, rowH);
        ctx.fillStyle = "#1e293b";
        ctx.font = "12px -apple-system, sans-serif";
      }

      // Row border
      ctx.strokeStyle = "#eee";
      ctx.lineWidth = 0.5;
      ctx.beginPath();
      ctx.moveTo(tableX, curY + rowH);
      ctx.lineTo(tableX + slideW - pad * 2, curY + rowH);
      ctx.stroke();

      // Label cell
      ctx.textAlign = "left";
      if (row.cells.length > 0) {
        var labelText = row.cells[0];
        if (labelText.length > 50) labelText = labelText.substring(0, 48) + "...";
        ctx.fillText(labelText, tableX + 10, curY + 16);
      }

      // Value cells
      ctx.textAlign = "center";
      for (var ci = 1; ci < row.cells.length; ci++) {
        var cx = tableX + labelColW + (ci - 1) * dataColW + dataColW / 2;
        ctx.fillText(row.cells[ci] || "", cx, curY + 16);
      }

      curY += rowH;
    }

    // Outer border
    ctx.strokeStyle = "#ddd";
    ctx.lineWidth = 1;
    ctx.strokeRect(tableX, tableY, slideW - pad * 2, curY - tableY);

    canvas.toBlob(function(blob) {
      if (!blob) return;
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "overview_" + currentSegment + ".png";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }, "image/png");
  };


  // ---- Help Overlay ----
  window.toggleHelpOverlay = function() {
    var overlay = document.getElementById("tk-help-overlay");
    if (overlay) {
      overlay.style.display = overlay.style.display === "none" ? "flex" : "none";
    }
  };

  // ---- Summary Tab: Metric Type Filter ----
  window.filterSummaryByType = function(typeKey) {
    // Update chip active state
    document.querySelectorAll(".summary-type-chip").forEach(function(chip) {
      chip.classList.toggle("active", chip.getAttribute("data-type-filter") === typeKey);
    });

    // Filter rows in summary metrics table
    var table = document.getElementById("summary-metrics-table");
    if (!table) return;

    var rows = table.querySelectorAll("tbody tr.tk-metric-row");
    rows.forEach(function(row) {
      var rowType = row.getAttribute("data-metric-type") || "other";
      var visible = typeKey === "all" || rowType === typeKey;
      row.style.display = visible ? "" : "none";
    });

    // Hide section headers with no visible children
    table.querySelectorAll("tbody tr.tk-section-row").forEach(function(secRow) {
      var next = secRow.nextElementSibling;
      var hasVisible = false;
      while (next && !next.classList.contains("tk-section-row")) {
        if (next.classList.contains("tk-metric-row") && next.style.display !== "none") {
          hasVisible = true;
          break;
        }
        next = next.nextElementSibling;
      }
      secRow.style.display = hasVisible ? "" : "none";
    });
  };


  // ---- Init ----
  document.addEventListener("DOMContentLoaded", function() {
    // Capture original row order (for "Original Order" sort)
    var tbody = document.querySelector("#tk-crosstab-table tbody");
    if (tbody) {
      var rows = tbody.querySelectorAll("tr:not(.tk-base-row)");
      originalRowOrder = Array.from(rows);
    }

    // If only one segment, hide segment selector
    if (SEGMENTS.length <= 1) {
      var selector = document.querySelector(".tk-segment-selector");
      if (selector) selector.style.display = "none";
    }

    // Switch to first segment to apply initial column visibility
    if (SEGMENTS.length > 0) {
      window.switchSegment(SEGMENTS[0]);
    }

    // Note: R generates sections in correct order (Ungrouped last).
    // switchGroupBy is only called when the user changes the dropdown.
  });

})();
