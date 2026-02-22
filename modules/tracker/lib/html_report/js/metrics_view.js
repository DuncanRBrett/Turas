// ==============================================================================
// TurasTracker HTML Report - Metrics by Segment View
// ==============================================================================
// Controls the per-metric view: metric selection, segment chips, wave chips,
// significance toggle, show-chart checkbox, n= count toggle,
// insight box, pin button.
//
// Segment and wave chip selections PERSIST across metric switches —
// stored in global activeSegments / activeWaves objects.
// ==============================================================================

// ---- Global chip state (persists across metric panels) ----
var activeSegments = {};   // { segmentName: true/false }
var activeWaves = {};      // { waveId: true/false }
var chipStateInitialised = false;
var selectedSegment = null; // Segment whose chart labels are shown (only one at a time)

/**
 * Initialise chip state from the first metric panel's default chips.
 * Called once on first metric selection or toggle.
 */
function initChipState() {
  if (chipStateInitialised) return;

  // Read initial segment state from first panel's chips
  var firstPanel = document.querySelector(".tk-metric-panel");
  if (firstPanel) {
    firstPanel.querySelectorAll(".tk-segment-chip").forEach(function(chip) {
      var seg = chip.getAttribute("data-segment");
      if (seg) {
        var isActive = chip.classList.contains("active");
        activeSegments[seg] = isActive;
        // Set first active segment as selected
        if (isActive && selectedSegment === null) {
          selectedSegment = seg;
        }
      }
    });
    firstPanel.querySelectorAll(".tk-wave-chip").forEach(function(chip) {
      var wid = chip.getAttribute("data-wave");
      if (wid) activeWaves[wid] = chip.classList.contains("active");
    });
  }
  chipStateInitialised = true;
}

/**
 * Apply the global chip state to a specific metric panel.
 * Updates chip buttons, table row/column visibility, and chart element visibility.
 * @param {HTMLElement} panel - The metric panel element
 */
function applyChipState(panel) {
  if (!panel) return;

  // ---- Apply segment state ----
  panel.querySelectorAll(".tk-segment-chip").forEach(function(chip) {
    var seg = chip.getAttribute("data-segment");
    if (seg && seg in activeSegments) {
      var isActive = activeSegments[seg];
      var isSelected = (seg === selectedSegment);
      chip.classList.toggle("active", isActive);
      chip.classList.toggle("selected", isActive && isSelected);

      // Table rows
      panel.querySelectorAll("tr[data-segment=\"" + seg + "\"]").forEach(function(el) {
        el.classList.toggle("segment-hidden", !isActive);
      });
      panel.querySelectorAll("td[data-segment=\"" + seg + "\"], th[data-segment=\"" + seg + "\"]").forEach(function(el) {
        el.classList.toggle("segment-hidden", !isActive);
      });

      // Chart elements: lines, points, legend — visible when segment is ACTIVE
      panel.querySelectorAll(".mv-chart-area path[data-segment=\"" + seg + "\"]").forEach(function(el) {
        el.style.display = isActive ? "" : "none";
      });
      panel.querySelectorAll(".mv-chart-area circle[data-segment=\"" + seg + "\"]").forEach(function(el) {
        el.style.display = isActive ? "" : "none";
      });
      panel.querySelectorAll(".mv-chart-area .tk-chart-legend-item[data-segment=\"" + seg + "\"]").forEach(function(el) {
        el.style.display = isActive ? "" : "none";
      });

      // Chart LABELS — visible only when segment is ACTIVE AND SELECTED
      panel.querySelectorAll(".mv-chart-area .tk-chart-label[data-segment=\"" + seg + "\"]").forEach(function(el) {
        el.style.display = (isActive && isSelected) ? "" : "none";
      });
    }
  });

  // ---- Update group header states ----
  if (typeof SEGMENT_GROUPS !== "undefined" && SEGMENT_GROUPS.groups) {
    for (var gName in SEGMENT_GROUPS.groups) {
      var gSegs = SEGMENT_GROUPS.groups[gName];
      var anyActive = false;
      for (var gi = 0; gi < gSegs.length; gi++) {
        if (activeSegments[gSegs[gi]]) { anyActive = true; break; }
      }
      panel.querySelectorAll('.mv-segment-group-header[data-group="' + gName + '"]').forEach(function(h) {
        h.classList.toggle("active", anyActive);
      });
    }
  }

  // ---- Apply wave state ----
  panel.querySelectorAll(".tk-wave-chip").forEach(function(chip) {
    var wid = chip.getAttribute("data-wave");
    if (wid && wid in activeWaves) {
      var isActive = activeWaves[wid];
      chip.classList.toggle("active", isActive);

      // Table columns (th + td)
      panel.querySelectorAll("th[data-wave=\"" + wid + "\"], td[data-wave=\"" + wid + "\"]").forEach(function(el) {
        el.classList.toggle("wave-hidden", !isActive);
      });

      // Chart elements (points and labels for this wave)
      panel.querySelectorAll(".mv-chart-area circle[data-wave=\"" + wid + "\"]").forEach(function(el) {
        // Only hide if wave is hidden; segment visibility is handled above
        if (!isActive) el.style.display = "none";
      });
      panel.querySelectorAll(".mv-chart-area .tk-chart-label[data-wave=\"" + wid + "\"]").forEach(function(el) {
        if (!isActive) el.style.display = "none";
      });
    }
  });

  // Rebuild chart paths based on current visibility
  rebuildChartLines(panel);
}

/**
 * Select and display a specific metric panel.
 * Applies persisted segment/wave chip state to the new panel.
 * @param {string} metricId - The metric ID (e.g., "metric_1")
 */
function selectTrackerMetric(metricId) {
  initChipState();

  // Hide all metric panels
  document.querySelectorAll(".tk-metric-panel").forEach(function(panel) {
    panel.classList.remove("active");
  });

  // Show selected panel
  var target = document.getElementById("mv-" + metricId);
  if (target) {
    target.classList.add("active");
    // Apply persisted chip state to the newly visible panel
    applyChipState(target);
    // Sync group expand/collapse state
    syncGroupExpandState(target);
  }

  // Update sidebar active state
  document.querySelectorAll(".tk-metric-nav-item").forEach(function(item) {
    item.classList.toggle("active", item.getAttribute("data-metric-id") === metricId);
  });
}

/**
 * Toggle expand/collapse of a segment group.
 * First click: expands group (shows sub-chips) and activates all segments.
 * Second click: collapses group and deactivates all segments.
 * @param {string} metricId - The metric ID
 * @param {string} groupName - The group name (e.g., "Campus")
 * @param {HTMLElement} headerBtn - The group header button
 */
function toggleSegmentGroupExpand(metricId, groupName, headerBtn) {
  initChipState();

  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var groupSegs = (typeof SEGMENT_GROUPS !== "undefined" && SEGMENT_GROUPS.groups)
    ? SEGMENT_GROUPS.groups[groupName] : null;
  if (!groupSegs) return;

  // Find the group container (parent of header button)
  var groupDiv = headerBtn.closest(".mv-segment-group");
  if (!groupDiv) return;

  var isExpanded = groupDiv.classList.contains("expanded");

  if (isExpanded) {
    // Collapse: hide chips and deactivate all segments
    groupDiv.classList.remove("expanded");
    for (var i = 0; i < groupSegs.length; i++) {
      activeSegments[groupSegs[i]] = false;
    }
    // If selected segment was in this group, find next active
    var found = false;
    for (var j = 0; j < groupSegs.length; j++) {
      if (groupSegs[j] === selectedSegment) { found = true; break; }
    }
    if (found) {
      selectedSegment = null;
      for (var key in activeSegments) {
        if (activeSegments[key]) { selectedSegment = key; break; }
      }
    }
  } else {
    // Expand: show chips and activate all segments
    groupDiv.classList.add("expanded");
    for (var i = 0; i < groupSegs.length; i++) {
      activeSegments[groupSegs[i]] = true;
    }
    // Set first segment of group as selected
    selectedSegment = groupSegs[0];
  }

  // Apply to all panels so state persists across metric switches
  applyChipStateAllPanels();
}

/**
 * Apply chip state to all metric panels (for expand/collapse persistence).
 */
function applyChipStateAllPanels() {
  document.querySelectorAll(".tk-metric-panel").forEach(function(panel) {
    applyChipState(panel);
  });
}

/**
 * Sync expanded state of segment groups on a panel based on activeSegments.
 * Called when switching metrics to ensure group expand/collapse matches state.
 * @param {HTMLElement} panel - The metric panel element
 */
function syncGroupExpandState(panel) {
  if (typeof SEGMENT_GROUPS === "undefined" || !SEGMENT_GROUPS.groups) return;

  for (var gName in SEGMENT_GROUPS.groups) {
    var gSegs = SEGMENT_GROUPS.groups[gName];
    var anyActive = false;
    for (var i = 0; i < gSegs.length; i++) {
      if (activeSegments[gSegs[i]]) { anyActive = true; break; }
    }
    panel.querySelectorAll('.mv-segment-group[data-group="' + gName + '"]').forEach(function(groupDiv) {
      groupDiv.classList.toggle("expanded", anyActive);
    });
  }
}


/**
 * Toggle a segment chip on/off for a metric.
 * Updates global state so it persists across metric switches.
 * Controls both table rows AND chart series visibility.
 * @param {string} metricId - The metric ID
 * @param {string} segmentName - The segment name
 * @param {HTMLElement} chip - The chip button element
 */
function toggleSegmentChip(metricId, segmentName, chip) {
  initChipState();

  chip.classList.toggle("active");
  var isActive = chip.classList.contains("active");

  // Store in global state
  activeSegments[segmentName] = isActive;

  // If activating a segment, make it the selected segment (for chart labels)
  if (isActive) {
    selectedSegment = segmentName;
  } else if (segmentName === selectedSegment) {
    // If deactivating the selected segment, find next active segment
    selectedSegment = null;
    for (var key in activeSegments) {
      if (activeSegments[key]) { selectedSegment = key; break; }
    }
  }

  // Apply state to ALL panels (so chip visual state persists across metric switches)
  applyChipStateAllPanels();
}

/**
 * Toggle a wave chip on/off for a metric.
 * Updates global state so it persists across metric switches.
 * Controls both table column visibility AND chart data point visibility.
 * @param {string} metricId - The metric ID
 * @param {string} waveId - The wave ID (e.g., "W1")
 * @param {HTMLElement} chip - The chip button element
 */
function toggleWaveChip(metricId, waveId, chip) {
  initChipState();

  chip.classList.toggle("active");
  var isActive = chip.classList.contains("active");

  // Store in global state
  activeWaves[waveId] = isActive;

  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  // Show/hide table columns for this wave (th and td cells with data-wave)
  panel.querySelectorAll("th[data-wave=\"" + waveId + "\"], td[data-wave=\"" + waveId + "\"]").forEach(function(el) {
    el.classList.toggle("wave-hidden", !isActive);
  });

  // Show/hide chart elements for this wave (points, labels, x-axis)
  panel.querySelectorAll(".mv-chart-area [data-wave=\"" + waveId + "\"]").forEach(function(el) {
    el.style.display = isActive ? "" : "none";
  });

  // Rebuild chart lines: the smooth path needs to be recalculated
  // since hidden wave points should not be connected
  rebuildChartLines(panel);
}

/**
 * Rebuild chart lines for a panel based on currently visible points.
 * When wave chips are toggled, the smooth SVG path must be recalculated
 * to only connect visible data points.
 * @param {HTMLElement} panel - The metric panel element
 */
function rebuildChartLines(panel) {
  var chartArea = panel.querySelector(".mv-chart-area");
  if (!chartArea) return;

  var svg = chartArea.querySelector("svg");
  if (!svg) return;

  // Get all path elements (one per segment)
  var paths = svg.querySelectorAll("path.tk-chart-line");

  paths.forEach(function(pathEl) {
    var segName = pathEl.getAttribute("data-segment");
    if (!segName) return;

    // Check if this segment is visible
    if (pathEl.style.display === "none") return;

    // Find all visible circles for this segment
    var circles = svg.querySelectorAll("circle.tk-chart-point[data-segment=\"" + segName + "\"]");
    var visiblePoints = [];

    circles.forEach(function(circle) {
      if (circle.style.display !== "none") {
        visiblePoints.push({
          x: parseFloat(circle.getAttribute("cx")),
          y: parseFloat(circle.getAttribute("cy"))
        });
      }
    });

    if (visiblePoints.length < 2) {
      pathEl.setAttribute("d", "");
      return;
    }

    // Build smooth path from visible points
    var d = smoothPathFromPoints(visiblePoints);
    pathEl.setAttribute("d", d);
  });
}

/**
 * Build a smooth SVG path from an array of {x, y} points.
 * Uses Catmull-Rom → cubic Bézier conversion (matching R build_smooth_path).
 * @param {Array} points - Array of {x, y} objects
 * @returns {string} SVG path d-attribute
 */
function smoothPathFromPoints(points) {
  var n = points.length;
  if (n < 2) return "";

  var d = "M" + points[0].x.toFixed(1) + "," + points[0].y.toFixed(1);

  if (n === 2) {
    d += " L" + points[1].x.toFixed(1) + "," + points[1].y.toFixed(1);
    return d;
  }

  var alpha = 0.5 / 3; // tension=0.5, same as R

  for (var i = 0; i < n - 1; i++) {
    var p1 = points[i];
    var p2 = points[i + 1];
    var p0, p3;

    if (i === 0) {
      p0 = { x: 2 * p1.x - p2.x, y: 2 * p1.y - p2.y };
    } else {
      p0 = points[i - 1];
    }

    if (i === n - 2) {
      p3 = { x: 2 * p2.x - p1.x, y: 2 * p2.y - p1.y };
    } else {
      p3 = points[i + 2];
    }

    var cp1x = p1.x + alpha * (p2.x - p0.x);
    var cp1y = p1.y + alpha * (p2.y - p0.y);
    var cp2x = p2.x - alpha * (p3.x - p1.x);
    var cp2y = p2.y - alpha * (p3.y - p1.y);

    d += " C" + cp1x.toFixed(1) + "," + cp1y.toFixed(1) +
         " " + cp2x.toFixed(1) + "," + cp2y.toFixed(1) +
         " " + p2.x.toFixed(1) + "," + p2.y.toFixed(1);
  }

  return d;
}

/**
 * Toggle significance indicators on/off
 */
function toggleSignificance() {
  document.body.classList.toggle("hide-significance");
}

/**
 * Toggle n= count display for a metric panel
 * @param {string} metricId - The metric ID
 */
function toggleMetricCounts(metricId) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;
  panel.classList.toggle("show-freq");
}

/**
 * Toggle show/hide chart underneath the table
 * @param {string} metricId - The metric ID
 * @param {boolean} show - Whether to show the chart
 */
function toggleShowChart(metricId, show) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var chartArea = panel.querySelector(".mv-chart-area");
  if (chartArea) {
    chartArea.style.display = show ? "block" : "none";
  }
}

/**
 * Toggle change sub-rows (vs Previous / vs Baseline) for a metric
 * @param {string} metricId - The metric ID
 * @param {string} changeType - "vs-prev" or "vs-base"
 */
function toggleMetricChangeRows(metricId, changeType) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var rows = panel.querySelectorAll(".tk-change-row.tk-" + changeType);
  rows.forEach(function(row) {
    row.classList.toggle("visible");
  });
}

/**
 * Toggle insight editor for a metric
 * @param {string} metricId - The metric ID
 */
function toggleMetricInsight(metricId) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var toggleBtn = panel.querySelector(".insight-toggle");
  var container = panel.querySelector(".insight-container");

  if (container.style.display === "none" || container.style.display === "") {
    container.style.display = "block";
    if (toggleBtn) toggleBtn.style.display = "none";
    // Focus the editor
    var editor = container.querySelector(".insight-editor");
    if (editor) editor.focus();
  } else {
    container.style.display = "none";
    if (toggleBtn) toggleBtn.style.display = "";
  }
}

/**
 * Sync insight text to hidden store
 * @param {string} metricId - The metric ID
 */
function syncMetricInsight(metricId) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var editor = panel.querySelector(".insight-editor");
  var store = panel.querySelector(".insight-store");
  if (editor && store) {
    store.value = editor.innerHTML;
  }
}

/**
 * Dismiss (clear) insight for a metric
 * @param {string} metricId - The metric ID
 */
function dismissMetricInsight(metricId) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var editor = panel.querySelector(".insight-editor");
  var store = panel.querySelector(".insight-store");
  var container = panel.querySelector(".insight-container");
  var toggleBtn = panel.querySelector(".insight-toggle");

  if (editor) editor.innerHTML = "";
  if (store) store.value = "";
  if (container) container.style.display = "none";
  if (toggleBtn) toggleBtn.style.display = "";
}

/**
 * Pin current metric view to the Pinned Views tab
 * @param {string} metricId - The metric ID
 */
function pinMetricView(metricId) {
  if (typeof togglePin === "function") {
    togglePin(metricId);
  }
}


// ==============================================================================
// Column Sorting for Per-Metric Tables
// ==============================================================================

// Track current sort state per metric table
var metricSortState = {};  // { metricId: { col: colIndex, dir: "asc"|"desc" } }

/**
 * Sort the per-metric table by a wave column.
 * Toggles ascending/descending on repeated clicks.
 * @param {string} metricId - The metric ID
 * @param {number} colIndex - Column index (1-based, matching data-col-index)
 * @param {HTMLElement} headerEl - The clicked header element
 */
function sortMetricTable(metricId, colIndex, headerEl) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var table = panel.querySelector(".mv-metric-table");
  if (!table) return;
  var tbody = table.querySelector("tbody");
  if (!tbody) return;

  // Determine sort direction
  var state = metricSortState[metricId] || {};
  var dir = "desc";
  if (state.col === colIndex && state.dir === "desc") {
    dir = "asc";
  }
  metricSortState[metricId] = { col: colIndex, dir: dir };

  // Clear sort indicators from all headers in this table
  table.querySelectorAll(".tk-sortable").forEach(function(th) {
    th.classList.remove("sort-asc", "sort-desc");
  });
  headerEl.classList.add(dir === "asc" ? "sort-asc" : "sort-desc");

  // Group rows: each segment row + its change rows
  var rows = Array.from(tbody.querySelectorAll("tr"));
  var groups = [];
  var i = 0;
  while (i < rows.length) {
    var row = rows[i];
    if (row.classList.contains("tk-metric-row")) {
      var group = { metric: row, changes: [], sortVal: 0 };
      // Find the value cell at colIndex (skip the label cell at index 0)
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

  // Rebuild tbody
  while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
  groups.forEach(function(g) {
    tbody.appendChild(g.metric);
    g.changes.forEach(function(cr) { tbody.appendChild(cr); });
  });
}


// ==============================================================================
// Excel Export for Per-Metric Tables
// ==============================================================================

/**
 * Export the current per-metric table to Excel (XML Spreadsheet format).
 * Respects current visibility: hidden segments, hidden waves, counts, change rows.
 * @param {string} metricId - The metric ID
 */
function exportMetricExcel(metricId) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var table = panel.querySelector(".mv-metric-table");
  if (!table) return;

  var titleEl = panel.querySelector(".mv-metric-title");
  var title = titleEl ? titleEl.textContent.trim() : metricId;
  var showFreq = panel.classList.contains("show-freq");

  var xml = '<?xml version="1.0"?>\n';
  xml += '<?mso-application progid="Excel.Sheet"?>\n';
  xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
  xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';

  // Styles
  xml += '<Styles>\n';
  xml += '<Style ss:ID="Default"><Font ss:FontName="Calibri" ss:Size="11"/></Style>\n';
  xml += '<Style ss:ID="Title"><Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/></Style>\n';
  xml += '<Style ss:ID="Header"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/><Interior ss:Color="#D9E2F3" ss:Pattern="Solid"/></Style>\n';
  xml += '<Style ss:ID="Change"><Font ss:FontName="Calibri" ss:Size="10" ss:Color="#666666"/><Interior ss:Color="#F5F5F5" ss:Pattern="Solid"/></Style>\n';
  xml += '<Style ss:ID="SigUp"><Font ss:FontName="Calibri" ss:Size="10" ss:Color="#008000" ss:Bold="1"/><Interior ss:Color="#F5F5F5" ss:Pattern="Solid"/></Style>\n';
  xml += '<Style ss:ID="SigDown"><Font ss:FontName="Calibri" ss:Size="10" ss:Color="#C00000" ss:Bold="1"/><Interior ss:Color="#F5F5F5" ss:Pattern="Solid"/></Style>\n';
  xml += '<Style ss:ID="Freq"><Font ss:FontName="Calibri" ss:Size="9" ss:Color="#94A3B8"/></Style>\n';
  xml += '</Styles>\n';

  xml += '<Worksheet ss:Name="' + xmlEscape(title.substring(0, 31)) + '">\n<Table>\n';

  // Title row
  xml += '<Row><Cell ss:StyleID="Title"><Data ss:Type="String">' + xmlEscape(title) + '</Data></Cell></Row>\n';
  xml += '<Row></Row>\n';

  // Headers
  var headerRow = table.querySelector("thead tr");
  if (headerRow) {
    xml += '<Row>\n';
    headerRow.querySelectorAll("th").forEach(function(th) {
      if (th.classList.contains("wave-hidden")) return;
      xml += '<Cell ss:StyleID="Header"><Data ss:Type="String">' + xmlEscape(th.textContent.trim()) + '</Data></Cell>\n';
    });
    xml += '</Row>\n';
  }

  // Body rows
  var bodyRows = table.querySelectorAll("tbody tr");
  bodyRows.forEach(function(tr) {
    // Skip hidden segments
    if (tr.classList.contains("segment-hidden")) return;
    // Skip hidden change rows
    if (tr.classList.contains("tk-change-row") && !tr.classList.contains("visible")) return;

    var isChange = tr.classList.contains("tk-change-row");

    xml += '<Row>\n';
    tr.querySelectorAll("td").forEach(function(td) {
      if (td.classList.contains("wave-hidden")) return;

      var text = "";
      var label = td.querySelector(".tk-metric-label");
      if (label) {
        text = label.textContent.trim();
      } else {
        // Get main value text (excluding n= count)
        var valSpan = td.querySelector(".tk-val");
        if (valSpan) {
          text = valSpan.textContent.trim();
          // Append n= if counts are shown
          if (showFreq) {
            var freqEl = td.querySelector(".tk-freq");
            if (freqEl) text += " (" + freqEl.textContent.trim() + ")";
          }
        } else {
          text = td.textContent.trim();
        }
      }

      var style = "Default";
      if (isChange) {
        var sigUp = td.querySelector(".sig-up");
        var sigDown = td.querySelector(".sig-down");
        if (sigUp) style = "SigUp";
        else if (sigDown) style = "SigDown";
        else style = "Change";
      }

      xml += '<Cell ss:StyleID="' + style + '"><Data ss:Type="String">' + xmlEscape(text) + '</Data></Cell>\n';
    });
    xml += '</Row>\n';
  });

  xml += '</Table>\n</Worksheet>\n</Workbook>';

  var filename = "metric_" + metricId.replace(/[^a-zA-Z0-9_-]/g, "_") + ".xls";
  downloadBlob(xml, filename, "application/vnd.ms-excel");
}
