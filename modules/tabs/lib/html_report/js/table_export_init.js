// Depends on: getLabelText() from core_navigation.js, sortChartBars() from table_export_init.js (self)
// Extract table data as 2D array (shared by CSV and Excel export)
function extractTableData(qCode) {
  var activeContainer = document.querySelector(".question-container.active");
  if (!activeContainer) return null;
  var table = activeContainer.querySelector("table.ct-table");
  if (!table) return null;

  var data = [];
  var rows = table.querySelectorAll("tr");
  rows.forEach(function(row) {
    var cells = row.querySelectorAll("th, td");
    var rowData = [];
    cells.forEach(function(cell) {
      if (cell.style.display === "none") return;
      var clone = cell.cloneNode(true);
      var freqs = clone.querySelectorAll(".ct-freq");
      freqs.forEach(function(f) { f.remove(); });
      var sigs = clone.querySelectorAll(".ct-sig");
      sigs.forEach(function(s) { s.remove(); });
      var btns = clone.querySelectorAll(".row-exclude-btn");
      btns.forEach(function(b) { b.remove(); });
      rowData.push(clone.textContent.trim());
    });
    if (rowData.length > 0) data.push(rowData);
  });
  return data;
}

// CSV export
function exportCSV(qCode) {
  var data = extractTableData(qCode);
  if (!data) return;

  var csv = data.map(function(row) {
    return row.map(function(cell) {
      var text = String(cell);
      if (text.indexOf(",") >= 0 || text.indexOf("\n") >= 0 || text.indexOf("\"") >= 0) {
        text = "\"" + text.replace(/\"/g, "\"\"") + "\"";
      }
      return text;
    }).join(",");
  }).join("\n");

  var blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  downloadBlob(blob, qCode + "_crosstab.csv");
}

// Excel export (Excel XML Spreadsheet format - .xls)
function exportExcel(qCode) {
  var data = extractTableData(qCode);
  if (!data) return;

  // Get question title
  var activeContainer = document.querySelector(".question-container.active");
  var qTitle = "";
  if (activeContainer) {
    var titleEl = activeContainer.querySelector(".question-text");
    if (titleEl) qTitle = titleEl.textContent.trim();
  }

  var xml = [];
  xml.push("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
  xml.push("<?mso-application progid=\"Excel.Sheet\"?>");
  xml.push("<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"");
  xml.push(" xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\">");
  xml.push("<Styles>");
  xml.push("<Style ss:ID=\"header\"><Font ss:Bold=\"1\" ss:Size=\"11\"/>");
  xml.push("<Interior ss:Color=\"#F8F9FA\" ss:Pattern=\"Solid\"/></Style>");
  xml.push("<Style ss:ID=\"title\"><Font ss:Bold=\"1\" ss:Size=\"12\"/></Style>");
  xml.push("<Style ss:ID=\"normal\"><Font ss:Size=\"11\"/></Style>");
  xml.push("</Styles>");
  xml.push("<Worksheet ss:Name=\"" + escapeXml(qCode) + "\">");
  xml.push("<Table>");

  // Title row
  if (qTitle) {
    xml.push("<Row>");
    xml.push("<Cell ss:StyleID=\"title\"><Data ss:Type=\"String\">" +
              escapeXml(qCode + " - " + qTitle) + "</Data></Cell>");
    xml.push("</Row>");
    xml.push("<Row></Row>");
  }

  data.forEach(function(row, rowIdx) {
    xml.push("<Row>");
    row.forEach(function(cell) {
      var styleId = rowIdx === 0 ? "header" : "normal";
      // Try to detect numeric values
      var num = parseFloat(cell.replace(/[,%]/g, ""));
      var isNum = !isNaN(num) && cell.match(/^[\d,\.%\s\-]+$/);
      if (isNum && cell.indexOf("%") >= 0) {
        // Percentage - store as number
        xml.push("<Cell ss:StyleID=\"" + styleId + "\"><Data ss:Type=\"Number\">" +
                  num + "</Data></Cell>");
      } else if (isNum && cell.trim() !== "") {
        xml.push("<Cell ss:StyleID=\"" + styleId + "\"><Data ss:Type=\"Number\">" +
                  num + "</Data></Cell>");
      } else {
        xml.push("<Cell ss:StyleID=\"" + styleId + "\"><Data ss:Type=\"String\">" +
                  escapeXml(cell) + "</Data></Cell>");
      }
    });
    xml.push("</Row>");
  });

  xml.push("</Table></Worksheet></Workbook>");

  var blob = new Blob([xml.join("\n")], {
    type: "application/vnd.ms-excel;charset=utf-8"
  });
  downloadBlob(blob, qCode + "_crosstab.xls");
}

function escapeXml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;")
          .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function downloadBlob(blob, filename) {
  var url = URL.createObjectURL(blob);
  var a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// ---- Column Toggle ----

function buildColumnChips(groupCode) {
  var existing = document.getElementById("col-chip-bar");
  if (existing) existing.remove();

  var headers = document.querySelectorAll(
    "th.ct-data-col.bg-" + groupCode + "[data-col-key]"
  );
  var seen = {};
  var columns = [];
  headers.forEach(function(th) {
    var key = th.getAttribute("data-col-key");
    if (!seen[key]) {
      seen[key] = true;
      var label = th.querySelector(".ct-header-text");
      columns.push({ key: key, label: label ? label.textContent.trim() : key });
    }
  });

  if (columns.length <= 1) return;

  if (!hiddenColumns[groupCode]) hiddenColumns[groupCode] = {};

  var bar = document.createElement("div");
  bar.id = "col-chip-bar";
  bar.className = "col-chip-bar";

  var lbl = document.createElement("span");
  lbl.className = "col-chip-label";
  lbl.textContent = "Columns:";
  bar.appendChild(lbl);

  columns.forEach(function(col) {
    var chip = document.createElement("button");
    chip.className = "col-chip";
    chip.setAttribute("data-col-key", col.key);
    chip.textContent = col.label;
    if (hiddenColumns[groupCode][col.key]) chip.classList.add("col-chip-off");
    chip.onclick = function() { toggleColumn(groupCode, col.key, chip); };
    bar.appendChild(chip);
  });

  var bannerTabs = document.querySelector(".banner-tabs");
  if (bannerTabs) {
    bannerTabs.parentNode.insertBefore(bar, bannerTabs.nextSibling);
  }
}

function toggleColumn(groupCode, colKey, chipEl) {
  if (!hiddenColumns[groupCode]) hiddenColumns[groupCode] = {};
  var isHidden = !!hiddenColumns[groupCode][colKey];

  if (isHidden) {
    delete hiddenColumns[groupCode][colKey];
    chipEl.classList.remove("col-chip-off");
    document.querySelectorAll("th[data-col-key=\"" + colKey + "\"], td[data-col-key=\"" + colKey + "\"]").forEach(function(el) {
      el.style.display = "";
    });
  } else {
    hiddenColumns[groupCode][colKey] = true;
    chipEl.classList.add("col-chip-off");
    document.querySelectorAll("th[data-col-key=\"" + colKey + "\"], td[data-col-key=\"" + colKey + "\"]").forEach(function(el) {
      el.style.display = "none";
    });
  }
}

// ---- Column Sort ----

function initSortHeaders() {
  document.querySelectorAll("th.ct-data-col[data-col-key]").forEach(function(th) {
    // Skip if already initialized (e.g., from saved HTML re-open)
    if (th.querySelector(".ct-sort-indicator")) return;

    var indicator = document.createElement("span");
    indicator.className = "ct-sort-indicator";
    indicator.textContent = " \u21C5";
    th.appendChild(indicator);

    th.addEventListener("click", function() {
      var table = th.closest("table.ct-table");
      if (!table) return;
      sortByColumn(table, th.getAttribute("data-col-key"), th);
    });
  });
}

function sortByColumn(table, colKey, clickedTh) {
  var tbody = table.querySelector("tbody");
  if (!tbody) return;
  var tableId = table.id;

  if (!originalRowOrder[tableId]) {
    originalRowOrder[tableId] = Array.from(tbody.querySelectorAll("tr"));
  }

  if (!sortState[tableId]) sortState[tableId] = { colKey: null, direction: "none" };
  var state = sortState[tableId];
  var newDir;
  if (state.colKey !== colKey) {
    newDir = "desc";
  } else if (state.direction === "desc") {
    newDir = "asc";
  } else if (state.direction === "asc") {
    newDir = "none";
  } else {
    newDir = "desc";
  }
  state.colKey = colKey;
  state.direction = newDir;

  // Reset all indicators in this table
  table.querySelectorAll(".ct-sort-indicator").forEach(function(ind) {
    ind.textContent = " \u21C5";
    ind.classList.remove("ct-sort-active");
  });

  var indicator = clickedTh.querySelector(".ct-sort-indicator");
  if (indicator) {
    if (newDir === "desc") {
      indicator.textContent = " \u2193";
      indicator.classList.add("ct-sort-active");
    } else if (newDir === "asc") {
      indicator.textContent = " \u2191";
      indicator.classList.add("ct-sort-active");
    }
  }

  if (newDir === "none") {
    originalRowOrder[tableId].forEach(function(row) { tbody.appendChild(row); });
    sortChartBars(table, null);
    return;
  }

  // Separate sortable (category, not net) vs pinned rows
  var allRows = Array.from(tbody.querySelectorAll("tr"));
  var sortable = [];
  var pinnedPositions = {};

  allRows.forEach(function(row, idx) {
    if (row.classList.contains("ct-row-category") &&
        !row.classList.contains("ct-row-net")) {
      sortable.push({ row: row, origIdx: idx });
    } else {
      pinnedPositions[idx] = row;
    }
  });

  // Get sort values
  sortable.forEach(function(item) {
    var cell = item.row.querySelector("td[data-col-key=\"" + colKey + "\"]");
    var raw = cell ? cell.getAttribute("data-sort-val") : null;
    var val = raw !== null ? parseFloat(raw) : NaN;
    item.sortVal = isNaN(val) ? null : val;
  });

  // Stable sort with null always last
  sortable.sort(function(a, b) {
    if (a.sortVal === null && b.sortVal === null) return a.origIdx - b.origIdx;
    if (a.sortVal === null) return 1;
    if (b.sortVal === null) return -1;
    var diff = (newDir === "desc") ? b.sortVal - a.sortVal : a.sortVal - b.sortVal;
    return diff !== 0 ? diff : a.origIdx - b.origIdx;
  });

  // Rebuild: pinned rows at original positions, sorted rows fill gaps
  var result = new Array(allRows.length);
  var keys = Object.keys(pinnedPositions);
  for (var k = 0; k < keys.length; k++) {
    result[parseInt(keys[k])] = pinnedPositions[keys[k]];
  }
  var si = 0;
  for (var i = 0; i < result.length; i++) {
    if (!result[i]) {
      result[i] = sortable[si].row;
      si++;
    }
  }

  result.forEach(function(row) { tbody.appendChild(row); });

  // Sort chart bars to match table sort order
  var sortedLabels = sortable.map(function(item) {
    var labelCell = item.row.querySelector("td.ct-label-col");
    return labelCell ? getLabelText(labelCell) : "";
  });
  sortChartBars(table, sortedLabels);
}

// Reorder horizontal bar chart to match table sort
function sortChartBars(table, sortedLabels) {
  var container = table.closest(".question-container");
  if (!container) return;
  var svg = container.querySelector(".chart-wrapper svg");
  if (!svg) return;
  var barGroups = svg.querySelectorAll("g.chart-bar-group");
  if (barGroups.length === 0) return;

  // Read bar spacing from first two groups in current DOM order
  // (positions are always recalculated, so DOM-first = visual-first)
  var groups = Array.from(barGroups);
  if (groups.length < 2) return;
  var getY = function(g) {
    var t = g.getAttribute("transform");
    return parseFloat(t.replace(/[^\d.\-]/g, " ").trim().split(/\s+/)[1] || "0");
  };
  var y0 = getY(groups[0]);
  var y1 = getY(groups[1]);
  var barStep = y1 - y0;

  if (sortedLabels === null) {
    // Reset to original order using data-bar-index
    groups.sort(function(a, b) {
      return parseInt(a.getAttribute("data-bar-index")) - parseInt(b.getAttribute("data-bar-index"));
    });
    groups.forEach(function(g, i) {
      g.setAttribute("transform", "translate(0," + (y0 + i * barStep) + ")");
      svg.appendChild(g);
    });
    return;
  }

  // Build label -> group map
  var labelMap = {};
  groups.forEach(function(g) {
    var label = g.getAttribute("data-bar-label");
    if (label) labelMap[label] = g;
  });

  // Reorder: sorted labels first, then any unmatched groups keep position
  var ordered = [];
  sortedLabels.forEach(function(label) {
    if (labelMap[label]) {
      ordered.push(labelMap[label]);
      delete labelMap[label];
    }
  });
  // Append any remaining unmatched groups
  Object.keys(labelMap).forEach(function(key) {
    ordered.push(labelMap[key]);
  });

  // Apply new positions
  ordered.forEach(function(g, i) {
    g.setAttribute("transform", "translate(0," + (y0 + i * barStep) + ")");
    svg.appendChild(g);
  });
}

// Initialize on DOM ready
document.addEventListener("DOMContentLoaded", function() {
  if (bannerGroups.length > 0) {
    switchBannerGroup(bannerGroups[0], null);
  }
  toggleHeatmap(true);
  initSortHeaders();
  initChartColumnPickers();
  // Hydrate insights from hidden textareas (for saved HTML re-open)
  hydrateInsights();
  // Hydrate pinned views from hidden JSON store
  hydratePinnedViews();
  // Auto-show insights that have content (from config or save-as)
  document.querySelectorAll(".insight-editor").forEach(function(editor) {
    if (editor.textContent.trim()) {
      var cont = editor.closest(".insight-container");
      if (cont) cont.style.display = "block";
      var area = editor.closest(".insight-area");
      if (area) {
        var btn = area.querySelector(".insight-toggle");
        if (btn) btn.style.display = "none";
      }
    }
  });
  // Show help overlay on first visit
  try {
    if (!localStorage.getItem("turas-help-seen")) {
      toggleHelpOverlay();
    }
  } catch(e) {}
});
