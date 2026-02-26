// ==============================================================================
// TurasTracker HTML Report - Pinned Views
// ==============================================================================
// Pin/unpin metric views, render pinned cards, persist JSON.
// Captures current view state: visible segments, chart, counts, change rows.
// ==============================================================================

var pinnedViews = [];

/**
 * Toggle pin on a metric (add or remove)
 * @param {string} metricId - The metric ID
 */
function togglePin(metricId) {
  // Always add a new pin (multi-pin support).
  // Each pin captures the current view state (visible segments, chart, table).
  // Unpinning is done via the ✕ button on each pinned card.
  var pinObj = captureMetricView(metricId);
  if (pinObj) {
    pinnedViews.push(pinObj);
  }

  renderPinnedCards();
  updatePinBadge();
  savePinnedData();
}

/**
 * Capture current view state for a metric.
 * Filters out hidden segments from the table HTML.
 * Captures chart SVG only if chart is currently visible.
 * Records display state: show-freq (counts), vs-prev/vs-base row visibility.
 * @param {string} metricId - The metric ID
 * @returns {Object|null} Pin object
 */
function captureMetricView(metricId) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return null;

  var titleEl = panel.querySelector(".mv-metric-title");
  var tableArea = panel.querySelector(".mv-table-area");
  var chartArea = panel.querySelector(".mv-chart-area");
  var insightEditor = panel.querySelector(".insight-editor");

  // Get visible segments
  var visibleSegments = [];
  panel.querySelectorAll(".tk-segment-chip.active").forEach(function(chip) {
    visibleSegments.push(chip.getAttribute("data-segment"));
  });

  // ---- Build clean table HTML (only visible segments) ----
  var cleanTableHtml = "";
  if (tableArea) {
    var tableClone = tableArea.cloneNode(true);

    // Remove hidden segment rows
    tableClone.querySelectorAll("tr.segment-hidden").forEach(function(row) {
      row.parentNode.removeChild(row);
    });

    // Remove hidden wave columns
    tableClone.querySelectorAll(".wave-hidden").forEach(function(el) {
      el.parentNode.removeChild(el);
    });

    // Determine display state from panel
    var showFreq = panel.classList.contains("show-freq");
    var vsPrevVisible = false;
    var vsBaseVisible = false;

    // Check if vs-prev / vs-base rows are toggled visible
    var prevRows = panel.querySelectorAll(".tk-change-row.tk-vs-prev.visible");
    var baseRows = panel.querySelectorAll(".tk-change-row.tk-vs-base.visible");
    vsPrevVisible = prevRows.length > 0;
    vsBaseVisible = baseRows.length > 0;

    // In the clone: make freq visible if show-freq is on
    if (showFreq) {
      tableClone.querySelectorAll(".tk-freq").forEach(function(el) {
        el.style.display = "block";
      });
    }

    // In the clone: make vs-prev rows visible if toggled on
    if (vsPrevVisible) {
      tableClone.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) {
        row.style.display = "table-row";
      });
    } else {
      // Remove vs-prev rows from clone if not visible
      tableClone.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) {
        row.parentNode.removeChild(row);
      });
    }

    // In the clone: make vs-base rows visible if toggled on
    if (vsBaseVisible) {
      tableClone.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) {
        row.style.display = "table-row";
      });
    } else {
      // Remove vs-base rows from clone if not visible
      tableClone.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) {
        row.parentNode.removeChild(row);
      });
    }

    cleanTableHtml = tableClone.innerHTML;
  }

  // ---- Chart SVG: only capture if chart is currently displayed ----
  var chartSvg = "";
  var chartVisible = false;
  if (chartArea && chartArea.style.display !== "none") {
    chartVisible = true;
    // Clone chart and remove hidden elements
    var chartClone = chartArea.cloneNode(true);
    chartClone.querySelectorAll("[data-segment]").forEach(function(el) {
      if (el.style.display === "none") {
        el.parentNode.removeChild(el);
      }
    });
    chartClone.querySelectorAll("[data-wave]").forEach(function(el) {
      if (el.style.display === "none") {
        el.parentNode.removeChild(el);
      }
    });
    chartSvg = chartClone.innerHTML;
  }

  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    metricId: metricId,
    metricTitle: titleEl ? titleEl.textContent : metricId,
    visibleSegments: visibleSegments,
    tableHtml: cleanTableHtml,
    chartSvg: chartSvg,
    chartVisible: chartVisible,
    insightText: insightEditor ? insightEditor.innerHTML : "",
    timestamp: Date.now(),
    order: pinnedViews.length
  };

  return pinObj;
}



/**
 * Update pin button visual state
 * @param {string} metricId - The metric ID
 * @param {boolean} isPinned - Whether it's pinned
 */
function updatePinButton(metricId, isPinned) {
  // No-op: multi-pin support means the pin button always shows "Pin this view".
  // Unpinning is done via the ✕ button on each pinned card.
}

/**
 * Render all pinned cards in the pinned tab.
 * Each card shows: header, chart (if captured), table, insight, meta.
 */
function renderPinnedCards() {
  var container = document.getElementById("pinned-cards-container");
  var emptyState = document.getElementById("pinned-empty-state");
  var toolbar = document.getElementById("pinned-toolbar");
  if (!container) return;

  // Count actual pins (not sections)
  var pinCount = 0;
  for (var c = 0; c < pinnedViews.length; c++) {
    if (pinnedViews[c].type !== "section") pinCount++;
  }

  if (pinCount === 0) {
    container.innerHTML = "";
    if (emptyState) emptyState.style.display = "block";
    if (toolbar) toolbar.style.display = "none";
    return;
  }

  if (emptyState) emptyState.style.display = "none";
  if (toolbar) toolbar.style.display = "flex";

  var html = "";
  var total = pinnedViews.length;
  for (var i = 0; i < total; i++) {
    var item = pinnedViews[i];

    // Section divider
    if (item.type === "section") {
      html += "<div class=\"section-divider\" data-idx=\"" + i + "\">";
      html += "<div class=\"section-divider-title\" contenteditable=\"true\" " +
        "onblur=\"updateSectionTitle(" + i + ", this.textContent)\">" +
        escapeHtml(item.title) + "</div>";
      html += "<div class=\"section-divider-actions\">";
      if (i > 0) html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"movePinned(" + i + "," + (i - 1) + ")\" title=\"Move up\">\u2191</button>";
      if (i < total - 1) html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"movePinned(" + i + "," + (i + 1) + ")\" title=\"Move down\">\u2193</button>";
      html += "<button class=\"tk-btn tk-btn-sm\" style=\"color:#e8614d;\" onclick=\"removePinned('" + item.id + "','')\" title=\"Remove section\">\u00d7</button>";
      html += "</div></div>";
      continue;
    }

    // Pin card
    var pin = item;
    html += "<div class=\"pinned-card\" data-pin-id=\"" + pin.id + "\">";

    // Header
    html += "<div class=\"pinned-card-header\">";
    html += "<h3 class=\"pinned-card-title\">" + escapeHtml(pin.metricTitle) + "</h3>";
    html += "<div class=\"pinned-card-actions\">";
    html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"exportPinnedCardPNG('" + pin.id + "')\" title=\"Export as PNG\">&#x1F4F8;</button>";
    if (i > 0) {
      html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"movePinned(" + i + "," + (i - 1) + ")\" title=\"Move up\">\u2191</button>";
    }
    if (i < total - 1) {
      html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"movePinned(" + i + "," + (i + 1) + ")\" title=\"Move down\">\u2193</button>";
    }
    html += "<button class=\"tk-btn tk-btn-sm\" onclick=\"removePinned('" + pin.id + "','" + pin.metricId + "')\" title=\"Remove pin\">\u00d7</button>";
    html += "</div></div>";

    // Editable insight (each pin has its own independent insight)
    html += "<div class=\"pinned-card-insight-area\">";
    if (pin.insightText) {
      html += "<div class=\"pinned-card-insight-editor insight-editor\" contenteditable=\"true\" data-pin-id=\"" + pin.id + "\" oninput=\"syncPinnedInsight('" + pin.id + "',this)\">" + pin.insightText + "</div>";
    } else {
      html += "<button class=\"insight-toggle pinned-insight-toggle\" onclick=\"showPinnedInsight('" + pin.id + "',this)\">+ Add Insight</button>";
      html += "<div class=\"pinned-card-insight-editor insight-editor\" contenteditable=\"true\" data-pin-id=\"" + pin.id + "\" oninput=\"syncPinnedInsight('" + pin.id + "',this)\" style=\"display:none\" data-placeholder=\"Type insight for this pin...\"></div>";
    }
    html += "</div>";

    // Chart (if captured and was visible)
    if (pin.chartSvg && pin.chartVisible !== false) {
      html += "<div class=\"pinned-card-chart\">" + pin.chartSvg + "</div>";
    }

    // Table
    if (pin.tableHtml) {
      html += "<div class=\"pinned-card-body\">" + pin.tableHtml + "</div>";
    }

    // Meta
    html += "<div class=\"pinned-card-meta\">" + new Date(pin.timestamp).toLocaleString() + "</div>";
    html += "</div>";
  }

  container.innerHTML = html;
}

/**
 * Add a section divider to the pinned views
 * @param {string} title - Section title (editable in the UI)
 */
function addSection(title) {
  title = title || "New Section";
  pinnedViews.push({
    type: "section",
    title: title,
    id: "sec-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5)
  });
  renderPinnedCards();
  savePinnedData();
}

/**
 * Update a section divider's title after inline editing
 * @param {number} idx - Index in pinnedViews array
 * @param {string} newTitle - New title text
 */
function updateSectionTitle(idx, newTitle) {
  if (idx >= 0 && idx < pinnedViews.length && pinnedViews[idx].type === "section") {
    pinnedViews[idx].title = newTitle.trim() || "Untitled Section";
    savePinnedData();
  }
}

/**
 * Move a pinned view from one position to another
 * @param {number} fromIdx - Source index
 * @param {number} toIdx - Destination index
 */
function movePinned(fromIdx, toIdx) {
  if (fromIdx < 0 || toIdx < 0 || fromIdx >= pinnedViews.length || toIdx >= pinnedViews.length) return;
  var item = pinnedViews.splice(fromIdx, 1)[0];
  pinnedViews.splice(toIdx, 0, item);
  renderPinnedCards();
  savePinnedData();
}

/**
 * Remove a pinned view
 * @param {string} pinId - The pin ID
 * @param {string} metricId - The metric ID
 */
function removePinned(pinId, metricId) {
  pinnedViews = pinnedViews.filter(function(p) { return p.id !== pinId; });
  renderPinnedCards();
  updatePinBadge();
  savePinnedData();
}

/**
 * Update the pin count badge on the Pinned Views tab
 */
function updatePinBadge() {
  var badge = document.getElementById("pin-count-badge");
  if (badge) {
    badge.textContent = pinnedViews.length;
    badge.style.display = pinnedViews.length > 0 ? "inline-block" : "none";
  }
}

/**
 * Show the insight editor on a pinned card
 */
function showPinnedInsight(pinId, btn) {
  var editor = btn.nextElementSibling;
  if (editor) {
    editor.style.display = "block";
    editor.focus();
  }
  btn.style.display = "none";
}

/**
 * Sync a pinned card's insight text to the pinnedViews data
 */
function syncPinnedInsight(pinId, editor) {
  for (var i = 0; i < pinnedViews.length; i++) {
    if (pinnedViews[i].id === pinId) {
      pinnedViews[i].insightText = editor.innerHTML;
      break;
    }
  }
  savePinnedData();
}

/**
 * Save pinned data to JSON script tag
 */
function savePinnedData() {
  var store = document.getElementById("pinned-views-data");
  if (store) {
    store.textContent = JSON.stringify(pinnedViews);
  }
}

/**
 * Hydrate pinned views from JSON on page load
 */
function hydratePinnedViews() {
  var store = document.getElementById("pinned-views-data");
  if (store) {
    try {
      pinnedViews = JSON.parse(store.textContent || "[]");
      renderPinnedCards();
      updatePinBadge();
    } catch (e) {
      pinnedViews = [];
    }
  }
}

/**
 * Escape HTML entities
 * @param {string} str
 * @returns {string}
 */
function escapeHtml(str) {
  var div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// ==============================================================================
// Export Functions — SVG-Native Approach
// ==============================================================================
// Builds pure SVG (no foreignObject), clones chart SVG into <g>, renders
// tables as SVG rect+text elements. Single reliable code path.
// Matches the approach used in the Turas Tabs slide_export.js.
// ==============================================================================

// ---- SVG Helper: Wrap text into lines ----
function pinWrapTextLines(text, maxWidth, charWidth) {
  if (!text) return [];
  var maxChars = Math.floor(maxWidth / charWidth);
  if (text.length <= maxChars) return [text];
  var words = text.split(" ");
  var lines = [], current = "";
  for (var i = 0; i < words.length; i++) {
    var test = current ? current + " " + words[i] : words[i];
    if (test.length > maxChars && current) {
      lines.push(current);
      current = words[i];
    } else {
      current = test;
    }
  }
  if (current) lines.push(current);
  return lines;
}

// ---- SVG Helper: Create <text> with <tspan> lines ----
function pinCreateWrappedText(ns, lines, x, startY, lineHeight, attrs) {
  var el = document.createElementNS(ns, "text");
  el.setAttribute("x", x);
  for (var key in attrs) { el.setAttribute(key, attrs[key]); }
  for (var i = 0; i < lines.length; i++) {
    var tspan = document.createElementNS(ns, "tspan");
    tspan.setAttribute("x", x);
    tspan.setAttribute("y", startY + i * lineHeight);
    tspan.textContent = lines[i];
    el.appendChild(tspan);
  }
  return { element: el, height: lines.length * lineHeight };
}

// ---- SVG Helper: Extract table data from stored pin HTML ----
function extractPinTableData(tableHtml) {
  if (!tableHtml) return null;
  var tempDiv = document.createElement("div");
  tempDiv.innerHTML = tableHtml;
  var table = tempDiv.querySelector("table");
  if (!table) return null;

  var rows = [];

  // Header row
  var headerCells = [];
  var headerRow = table.querySelector("thead tr");
  if (headerRow) {
    headerRow.querySelectorAll("th").forEach(function(th) {
      if (th.style.display === "none") return;
      headerCells.push(th.textContent.trim());
    });
    if (headerCells.length > 0) {
      rows.push({ cells: headerCells, type: "header" });
    }
  }

  // Body rows
  table.querySelectorAll("tbody tr").forEach(function(tr) {
    if (tr.style.display === "none") return;

    var rowInfo = { cells: [], type: "data" };

    if (tr.classList.contains("tk-base-row")) {
      rowInfo.type = "base";
      var baseLabel = tr.querySelector(".tk-base-label");
      rowInfo.cells.push(baseLabel ? baseLabel.textContent.trim() : "Base");
      tr.querySelectorAll("td.tk-base-cell").forEach(function(td) {
        if (td.style.display === "none") return;
        rowInfo.cells.push(td.textContent.trim());
      });
    } else if (tr.classList.contains("tk-change-row")) {
      rowInfo.type = "change";
      var changeLabel = tr.querySelector(".tk-change-label");
      rowInfo.cells.push(changeLabel ? changeLabel.textContent.trim() : "Change");
      tr.querySelectorAll("td.tk-change-cell").forEach(function(td) {
        if (td.style.display === "none") return;
        rowInfo.cells.push(td.textContent.trim());
      });
    } else if (tr.classList.contains("tk-metric-row")) {
      var segName = tr.getAttribute("data-segment") || "";
      rowInfo.type = segName === "Total" ? "total" : "data";
      var labelEl = tr.querySelector(".tk-metric-label");
      rowInfo.cells.push(labelEl ? labelEl.textContent.trim() : segName);
      tr.querySelectorAll("td.tk-value-cell").forEach(function(td) {
        if (td.style.display === "none") return;
        var valSpan = td.querySelector(".tk-val");
        rowInfo.cells.push(valSpan ? valSpan.textContent.trim() : td.textContent.trim());
      });
      // Capture segment colour from dot
      var dot = tr.querySelector(".tk-seg-dot");
      if (dot) {
        rowInfo.colour = dot.style.background || dot.style.backgroundColor || null;
      }
    } else {
      // Generic row
      tr.querySelectorAll("th, td").forEach(function(cell) {
        if (cell.style.display === "none") return;
        rowInfo.cells.push(cell.textContent.trim());
      });
    }

    if (rowInfo.cells.length > 0) {
      rows.push(rowInfo);
    }
  });

  return rows.length > 0 ? rows : null;
}

// ---- SVG Helper: Render table as SVG rect+text elements ----
function renderPinTableSVG(ns, svgParent, tableData, x, y, maxWidth) {
  if (!tableData || tableData.length === 0) return 0;
  var nCols = tableData[0].cells.length;
  if (nCols === 0) return 0;

  var COLOURS = [
    "#323367", "#CC9900", "#2E8B57", "#CD5C5C", "#4682B4",
    "#9370DB", "#D2691E", "#20B2AA", "#8B4513", "#6A5ACD"
  ];

  var baseRowH = 22, headerH = 26, fontSize = 10, padX = 6;
  var firstColW = Math.min(Math.max(maxWidth * 0.25, 140), 260);
  var dataColW = nCols > 1 ? (maxWidth - firstColW) / (nCols - 1) : maxWidth;

  var curY = y;
  var colourIdx = 0;

  tableData.forEach(function(row, ri) {
    var isHeader = row.type === "header";
    var rH = isHeader ? headerH : baseRowH;

    // Row background
    var bgRect = document.createElementNS(ns, "rect");
    bgRect.setAttribute("x", x); bgRect.setAttribute("y", curY);
    bgRect.setAttribute("width", maxWidth); bgRect.setAttribute("height", rH);

    if (isHeader) {
      bgRect.setAttribute("fill", "#1a2744");
    } else if (row.type === "base") {
      bgRect.setAttribute("fill", "#f8f9fa");
    } else if (row.type === "change") {
      bgRect.setAttribute("fill", "#fafbfc");
    } else if (row.type === "total") {
      bgRect.setAttribute("fill", "#f0f0f5");
    } else if (ri % 2 === 0) {
      bgRect.setAttribute("fill", "#ffffff");
    } else {
      bgRect.setAttribute("fill", "#f9fafb");
    }
    svgParent.appendChild(bgRect);

    // Segment colour dot for data/total rows
    if (row.type === "data" || row.type === "total") {
      var dotColour = row.colour || COLOURS[colourIdx % COLOURS.length];
      var dot = document.createElementNS(ns, "circle");
      dot.setAttribute("cx", x + 12);
      dot.setAttribute("cy", curY + rH / 2);
      dot.setAttribute("r", "3.5");
      dot.setAttribute("fill", dotColour);
      svgParent.appendChild(dot);
      colourIdx++;
    }

    // Cell text
    row.cells.forEach(function(cellText, ci) {
      var cellW = ci === 0 ? firstColW : dataColW;
      var cellX;
      if (ci === 0) {
        cellX = (row.type === "data" || row.type === "total") ? x + 22 : x + padX;
      } else {
        cellX = x + firstColW + (ci - 1) * dataColW;
      }

      var textEl = document.createElementNS(ns, "text");
      textEl.setAttribute("y", curY + rH / 2 + 1);
      textEl.setAttribute("dominant-baseline", "central");
      textEl.setAttribute("font-size", fontSize);

      if (ci === 0) {
        textEl.setAttribute("x", cellX);
        textEl.setAttribute("text-anchor", "start");
      } else {
        textEl.setAttribute("x", cellX + cellW / 2);
        textEl.setAttribute("text-anchor", "middle");
      }

      if (isHeader) {
        textEl.setAttribute("fill", "#ffffff");
        textEl.setAttribute("font-weight", "600");
      } else if (row.type === "total") {
        textEl.setAttribute("fill", ci === 0 ? "#1a2744" : "#1e293b");
        textEl.setAttribute("font-weight", "600");
      } else if (row.type === "base") {
        textEl.setAttribute("fill", "#666666");
        textEl.setAttribute("font-weight", "600");
        textEl.setAttribute("font-size", fontSize - 1);
      } else if (row.type === "change") {
        textEl.setAttribute("fill", "#888888");
        textEl.setAttribute("font-size", fontSize - 1);
      } else {
        textEl.setAttribute("fill", ci === 0 ? "#374151" : "#1e293b");
      }

      // Truncate long label text
      var maxChars = Math.floor((cellW - padX * 2) / (fontSize * 0.55));
      if (maxChars > 0 && cellText.length > maxChars) {
        cellText = cellText.substring(0, Math.max(maxChars - 1, 5)) + "\u2026";
      }

      textEl.textContent = cellText;
      svgParent.appendChild(textEl);
    });

    // Row border
    var borderLine = document.createElementNS(ns, "line");
    borderLine.setAttribute("x1", x); borderLine.setAttribute("x2", x + maxWidth);
    borderLine.setAttribute("y1", curY + rH); borderLine.setAttribute("y2", curY + rH);
    borderLine.setAttribute("stroke", "#e2e8f0"); borderLine.setAttribute("stroke-width", "0.5");
    svgParent.appendChild(borderLine);

    curY += rH;
  });

  return curY - y;
}

/**
 * Export a single pinned card as PNG using SVG-native approach.
 * Builds pure SVG: title, insight, chart (cloned <g>), table (rect+text).
 * No foreignObject — single reliable code path.
 * @param {string} pinId - The pin ID
 */
function exportPinnedCardPNG(pinId) {
  // Find pin data
  var pin = null;
  for (var i = 0; i < pinnedViews.length; i++) {
    if (pinnedViews[i].id === pinId) { pin = pinnedViews[i]; break; }
  }
  if (!pin) return;

  var ns = "http://www.w3.org/2000/svg";
  var W = 1280;
  var fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
  var pad = 28;
  var usableW = W - pad * 2;
  var brandColour = getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367";

  // ---- 1. Title ----
  var titleText = pin.metricTitle || "Pinned View";
  var titleLines = pinWrapTextLines(titleText, usableW, 9.5);
  var titleLineH = 20;
  var titleStartY = pad + 16;
  var titleBlockH = titleLines.length * titleLineH;

  // ---- 2. Meta line ----
  var metaText = new Date(pin.timestamp).toLocaleDateString();
  if (pin.visibleSegments && pin.visibleSegments.length > 0) {
    metaText += "  \u00B7  Segments: " + pin.visibleSegments.join(", ");
  }
  var metaY = titleStartY + titleBlockH + 4;
  var contentTop = metaY + 18;

  // ---- 3. Insight ----
  var insightPlain = "";
  if (pin.insightText) {
    var tmpDiv = document.createElement("div");
    tmpDiv.innerHTML = pin.insightText;
    insightPlain = tmpDiv.textContent.trim();
  }
  var insightLines = pinWrapTextLines(insightPlain, usableW - 16, 7.5);
  var insightLineH = 17;
  var insightBlockH = insightLines.length > 0 ? insightLines.length * insightLineH + 24 : 0;
  var insightY = contentTop;

  // ---- 4. Chart dimensions ----
  var chartTopY = contentTop + insightBlockH + (insightBlockH > 0 ? 12 : 0);
  var chartDisplayH = 0;
  var chartClone = null;
  var chartScale = 1;

  if (pin.chartSvg && pin.chartVisible !== false) {
    var chartTempDiv = document.createElement("div");
    chartTempDiv.innerHTML = pin.chartSvg;
    var svgEl = chartTempDiv.querySelector("svg");
    if (svgEl) {
      chartClone = svgEl.cloneNode(true);
      // Resolve any CSS variable references in the chart SVG
      chartClone.querySelectorAll("*").forEach(function(el) {
        ["fill", "stroke"].forEach(function(attr) {
          var val = el.getAttribute(attr);
          if (val && val.indexOf("var(") !== -1) {
            // Parse var(--name, fallback)
            var match = val.match(/var\(--[^,)]+,\s*([^)]+)\)/);
            if (match) el.setAttribute(attr, match[1].trim());
          }
        });
      });
      var vb = chartClone.getAttribute("viewBox");
      if (vb) {
        var chartVB = vb.split(" ").map(Number);
        var chartOrigW = chartVB[2];
        var chartOrigH = chartVB[3];
        chartScale = usableW / chartOrigW;
        chartDisplayH = chartOrigH * chartScale;
      }
    }
  }

  // ---- 5. Table dimensions ----
  var tableTopY = chartTopY + chartDisplayH + (chartDisplayH > 0 ? 14 : 0);
  var tableData = null;
  var estimatedTableH = 0;

  if (pin.tableHtml) {
    tableData = extractPinTableData(pin.tableHtml);
    if (tableData && tableData.length > 0) {
      // Estimate: header 26px + data rows 22px each
      estimatedTableH = 26 + (tableData.length - 1) * 22 + 8;
    }
  }

  // ---- 6. Calculate total height ----
  var totalH = tableTopY + estimatedTableH + pad + 20;
  if (totalH < 300) totalH = 300;

  // ---- Build slide SVG ----
  var svg = document.createElementNS(ns, "svg");
  svg.setAttribute("xmlns", ns);
  svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
  svg.setAttribute("style", "font-family:" + fontFamily + ";");

  // White background
  var bg = document.createElementNS(ns, "rect");
  bg.setAttribute("width", W); bg.setAttribute("height", totalH);
  bg.setAttribute("fill", "#ffffff");
  svg.appendChild(bg);

  // Brand accent bar at top
  var accentBar = document.createElementNS(ns, "rect");
  accentBar.setAttribute("x", "0"); accentBar.setAttribute("y", "0");
  accentBar.setAttribute("width", W); accentBar.setAttribute("height", "4");
  accentBar.setAttribute("fill", brandColour);
  svg.appendChild(accentBar);

  // Title
  var titleResult = pinCreateWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
    { fill: "#1a2744", "font-size": "16", "font-weight": "700" });
  svg.appendChild(titleResult.element);

  // Meta line
  var metaEl = document.createElementNS(ns, "text");
  metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
  metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "11");
  metaEl.textContent = metaText;
  svg.appendChild(metaEl);

  // Insight block
  if (insightLines.length > 0) {
    var accentH = Math.max(28, insightLines.length * insightLineH + 12);
    var insBg = document.createElementNS(ns, "rect");
    insBg.setAttribute("x", pad); insBg.setAttribute("y", insightY + 2);
    insBg.setAttribute("width", usableW); insBg.setAttribute("height", accentH);
    insBg.setAttribute("rx", "4"); insBg.setAttribute("fill", "#f0f4ff");
    svg.appendChild(insBg);
    var iBar = document.createElementNS(ns, "rect");
    iBar.setAttribute("x", pad); iBar.setAttribute("y", insightY + 2);
    iBar.setAttribute("width", "4"); iBar.setAttribute("height", accentH);
    iBar.setAttribute("fill", brandColour); iBar.setAttribute("rx", "2");
    svg.appendChild(iBar);
    var insResult = pinCreateWrappedText(ns, insightLines, pad + 14, insightY + 18, insightLineH,
      { fill: "#1a2744", "font-size": "13", "font-weight": "500" });
    svg.appendChild(insResult.element);
  }

  // Chart — clone SVG content into <g> element (no foreignObject!)
  if (chartClone && chartDisplayH > 0) {
    var chartG = document.createElementNS(ns, "g");
    chartG.setAttribute("transform", "translate(" + pad + "," + chartTopY + ") scale(" + chartScale + ")");
    while (chartClone.firstChild) chartG.appendChild(chartClone.firstChild);
    svg.appendChild(chartG);
  }

  // Table — rendered as SVG rect+text elements
  if (tableData && tableData.length > 0) {
    var actualTableH = renderPinTableSVG(ns, svg, tableData, pad, tableTopY, usableW);
    var newTotalH = tableTopY + actualTableH + pad + 20;
    if (newTotalH > totalH) {
      totalH = newTotalH;
      bg.setAttribute("height", totalH);
      svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
    }
  }

  // Subtle footer line
  var footerY = totalH - pad;
  var footerLine = document.createElementNS(ns, "line");
  footerLine.setAttribute("x1", pad); footerLine.setAttribute("x2", W - pad);
  footerLine.setAttribute("y1", footerY); footerLine.setAttribute("y2", footerY);
  footerLine.setAttribute("stroke", "#e2e8f0"); footerLine.setAttribute("stroke-width", "0.5");
  svg.appendChild(footerLine);

  var footerText = document.createElementNS(ns, "text");
  footerText.setAttribute("x", W - pad); footerText.setAttribute("y", footerY + 14);
  footerText.setAttribute("text-anchor", "end");
  footerText.setAttribute("fill", "#cbd5e1"); footerText.setAttribute("font-size", "9");
  footerText.textContent = "Tracking Report";
  svg.appendChild(footerText);

  // ---- Render SVG to PNG at 3x resolution ----
  var renderScale = 3;
  var svgData = new XMLSerializer().serializeToString(svg);
  var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
  var url = URL.createObjectURL(svgBlob);

  var img = new Image();
  img.onerror = function() {
    URL.revokeObjectURL(url);
    console.error("[Pin PNG] SVG render failed for pin: " + pinId);
    alert("PNG export failed. Please try using Chrome or Edge browser.");
  };
  img.onload = function() {
    var canvas = document.createElement("canvas");
    canvas.width = W * renderScale;
    canvas.height = totalH * renderScale;
    var ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    URL.revokeObjectURL(url);
    canvas.toBlob(function(blob) {
      if (!blob) return;
      var filename = "pinned_" + pin.metricTitle.replace(/[^a-zA-Z0-9]/g, "_") + ".png";
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }, "image/png");
  };
  img.src = url;
}

/**
 * Download a data URL as a PNG file via Blob (reliable for large images).
 */
function downloadDataUrlAsPng(dataUrl, filename) {
  try {
    var parts = dataUrl.split(",");
    var mime = parts[0].match(/:(.*?);/)[1];
    var bstr = atob(parts[1]);
    var n = bstr.length;
    var u8 = new Uint8Array(n);
    for (var i = 0; i < n; i++) u8[i] = bstr.charCodeAt(i);
    var blob = new Blob([u8], { type: mime });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (e) {
    // Fallback: direct data URL download
    var a2 = document.createElement("a");
    a2.href = dataUrl;
    a2.download = filename;
    document.body.appendChild(a2);
    a2.click();
    document.body.removeChild(a2);
  }
}


/**
 * Clean a cloned DOM element for SVG foreignObject export.
 * Strips contenteditable attributes and other interactive attrs
 * that are irrelevant in a static PNG render.
 */
function cleanCloneForExport(clone) {
  // Remove contenteditable attributes (they have no effect in a PNG)
  clone.querySelectorAll("[contenteditable]").forEach(function(el) {
    el.removeAttribute("contenteditable");
  });
  // Remove oninput/onblur/onclick handlers from clone
  clone.querySelectorAll("[oninput],[onblur],[onclick]").forEach(function(el) {
    el.removeAttribute("oninput");
    el.removeAttribute("onblur");
    el.removeAttribute("onclick");
  });
}

/**
 * Sanitize HTML string for SVG foreignObject (XHTML compliance).
 * Converts self-closing tags to XHTML form, fixes bare ampersands.
 * @param {string} html - The HTML string to sanitize
 * @returns {string} XHTML-safe string
 */
function sanitizeForSvg(html) {
  // Fix bare ampersands (not already part of any entity: named, decimal, or hex)
  html = html.replace(/&(?![a-zA-Z]+;|#\d+;|#x[0-9a-fA-F]+;)/g, "&amp;");
  // Self-closing void elements
  html = html.replace(/<br\s*>/gi, "<br/>");
  html = html.replace(/<hr\s*>/gi, "<hr/>");
  html = html.replace(/<img([^>]*?)(?<!\/)>/gi, "<img$1/>");
  html = html.replace(/<input([^>]*?)(?<!\/)>/gi, "<input$1/>");
  html = html.replace(/<col([^>]*?)(?<!\/)>/gi, "<col$1/>");
  html = html.replace(/<wbr\s*>/gi, "<wbr/>");
  html = html.replace(/<source([^>]*?)(?<!\/)>/gi, "<source$1/>");
  html = html.replace(/<meta([^>]*?)(?<!\/)>/gi, "<meta$1/>");
  html = html.replace(/<link([^>]*?)(?<!\/)>/gi, "<link$1/>");
  return html;
}

/**
 * Inline computed styles on an element tree (for SVG foreignObject rendering).
 */
function inlineStyles(el) {
  if (el.nodeType !== 1) return;
  var computed = window.getComputedStyle(el);
  var important = [
    "font-family", "font-size", "font-weight", "color", "background-color",
    "background", "border", "border-radius", "padding", "margin",
    "display", "text-align", "line-height", "white-space",
    "border-bottom", "border-top", "overflow"
  ];
  for (var i = 0; i < important.length; i++) {
    el.style[important[i]] = computed.getPropertyValue(important[i]);
  }
  for (var c = 0; c < el.children.length; c++) {
    inlineStyles(el.children[c]);
  }
}

/**
 * Export all pinned cards as individual PNGs with a 300ms delay between each.
 */
function exportAllPinsPNG() {
  // Collect only actual pins (skip section dividers)
  var pins = [];
  for (var p = 0; p < pinnedViews.length; p++) {
    if (pinnedViews[p].type !== "section") pins.push(pinnedViews[p]);
  }
  if (pins.length === 0) return;

  var idx = 0;
  function exportNext() {
    if (idx >= pins.length) return;
    exportPinnedCardPNG(pins[idx].id);
    idx++;
    setTimeout(exportNext, 300);
  }
  exportNext();
}

/**
 * Print all pinned views as a single document (for Save as PDF).
 * Adds body class to hide everything except the pinned tab.
 */
function printAllPins() {
  // Switch to pinned tab
  if (typeof switchReportTab === "function") {
    switchReportTab("pinned");
  }

  // Add print class
  document.body.classList.add("print-pinned-only");

  // Slight delay for repaint, then print
  setTimeout(function() {
    window.print();
    // Remove class after print dialog
    setTimeout(function() {
      document.body.classList.remove("print-pinned-only");
    }, 500);
  }, 200);
}

/**
 * Save the entire HTML report with all pins and insights.
 * Persists pin data and insight editors to the HTML, then downloads.
 */
function saveReportHTML() {
  // Save current pin data to JSON store
  savePinnedData();

  // Stamp the header date badge with "Last saved" timestamp (like Turas Tabs)
  var dateBadge = document.getElementById("header-date-badge");
  if (dateBadge) {
    var now = new Date();
    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    var d = now.getDate();
    var m = months[now.getMonth()];
    var y = now.getFullYear();
    var hh = String(now.getHours()).padStart(2, "0");
    var mm = String(now.getMinutes()).padStart(2, "0");
    dateBadge.textContent = "Last saved " + d + " " + m + " " + y + " " + hh + ":" + mm;
  }

  // Save insight editor contents to hidden textareas
  document.querySelectorAll(".insight-editor").forEach(function(editor) {
    var store = editor.closest(".insight-area");
    if (store) {
      var textarea = store.querySelector(".insight-store");
      if (textarea) textarea.value = editor.innerHTML;
    }
  });

  // Save summary editor contents
  document.querySelectorAll(".summary-editor").forEach(function(editor) {
    editor.setAttribute("data-saved-content", editor.innerHTML);
  });

  // Capture full document HTML
  var htmlContent = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;

  // Download
  var blob = new Blob([htmlContent], { type: "text/html;charset=utf-8" });
  var a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  var projectTitle = document.querySelector(".tk-header-project");
  var filename = projectTitle ? projectTitle.textContent.trim().replace(/[^a-zA-Z0-9_-]/g, "_") : "tracking_report";
  a.download = filename + "_updated.html";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(a.href);
}


// ==============================================================================
// Summary Section Pin & Export
// ==============================================================================

/**
 * Pin a summary section (background or findings) to Pinned Views.
 * @param {string} sectionType - "background" or "findings"
 */
function pinSummarySection(sectionType) {
  var editorId = sectionType === "background"
    ? "summary-background-editor"
    : "summary-findings-editor";
  var editor = document.getElementById(editorId);
  if (!editor || !editor.innerHTML.trim()) {
    alert("Add content before pinning.");
    return;
  }

  var title = sectionType === "background" ? "Background & Method" : "Summary";
  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    metricId: "summary-" + sectionType,
    metricTitle: title,
    visibleSegments: [],
    tableHtml: "",
    chartSvg: "",
    chartVisible: false,
    insightText: editor.innerHTML,
    timestamp: Date.now(),
    order: pinnedViews.length
  };

  pinnedViews.push(pinObj);
  renderPinnedCards();
  updatePinBadge();
  savePinnedData();
}

/**
 * Pin the Significant Changes section to Pinned Views.
 * Captures the entire sig changes grid as a single pinned card.
 */
function pinSigChanges() {
  var section = document.getElementById("summary-section-sig-changes");
  if (!section) {
    alert("No significant changes section found.");
    return;
  }
  // Check for empty state (no actual cards)
  var cards = section.querySelectorAll(".dash-sig-card");
  if (cards.length === 0) {
    alert("There are no significant changes to pin.");
    return;
  }

  // Clone the section and strip interactive controls
  var clone = section.cloneNode(true);
  var controls = clone.querySelector(".summary-section-controls");
  if (controls) controls.parentNode.removeChild(controls);

  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    metricId: "summary-sig-changes",
    metricTitle: "Significant Changes",
    visibleSegments: [],
    tableHtml: clone.innerHTML,
    chartSvg: "",
    chartVisible: false,
    insightText: "",
    timestamp: Date.now(),
    order: pinnedViews.length
  };

  pinnedViews.push(pinObj);
  renderPinnedCards();
  updatePinBadge();
  savePinnedData();
}

/**
 * Export a summary section as a slide PNG.
 * @param {string} sectionType - "background", "findings", or "sig-changes"
 */
function exportSummarySlide(sectionType) {
  var sectionId;
  if (sectionType === "background") {
    sectionId = "summary-section-background";
  } else if (sectionType === "sig-changes") {
    sectionId = "summary-section-sig-changes";
  } else {
    sectionId = "summary-section-findings";
  }
  var section = document.getElementById(sectionId);
  if (!section) return;

  var clone = section.cloneNode(true);
  var controls = clone.querySelector(".summary-section-controls");
  if (controls) controls.parentNode.removeChild(controls);
  cleanCloneForExport(clone);
  inlineStyles(clone);

  var w = section.offsetWidth || 800;
  var h = Math.max(section.offsetHeight || 300, 200);
  var scale = 3;

  var svgNS = "http://www.w3.org/2000/svg";
  var htmlContent = sanitizeForSvg(clone.outerHTML);
  var svgStr = '<svg xmlns="' + svgNS + '" width="' + (w * scale) + '" height="' + (h * scale) + '">';
  svgStr += '<foreignObject width="' + w + '" height="' + h + '" transform="scale(' + scale + ')">';
  svgStr += '<div xmlns="http://www.w3.org/1999/xhtml" style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;font-size:14px;color:#2c2c2c;background:#fff;">';
  svgStr += htmlContent;
  svgStr += '</div></foreignObject></svg>';

  var svgBlob = new Blob([svgStr], { type: "image/svg+xml;charset=utf-8" });
  var svgUrl = URL.createObjectURL(svgBlob);
  var canvas = document.createElement("canvas");
  canvas.width = w * scale;
  canvas.height = h * scale;
  var ctx = canvas.getContext("2d");

  var img = new Image();
  img.onload = function() {
    ctx.drawImage(img, 0, 0);
    canvas.toBlob(function(blob) {
      if (!blob) return;
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "summary_" + sectionType + ".png";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }, "image/png");
    URL.revokeObjectURL(svgUrl);
  };
  img.onerror = function() {
    URL.revokeObjectURL(svgUrl);
  };
  img.src = svgUrl;
}


// ---- Summary Table Actions ----

/**
 * Export the summary metrics table as Excel XML.
 */
function exportSummaryExcel() {
  var table = document.getElementById("summary-metrics-table");
  if (!table) return;

  var xml = '<?xml version="1.0"?>\n';
  xml += '<?mso-application progid="Excel.Sheet"?>\n';
  xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"\n';
  xml += ' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n';

  xml += '<Styles>\n';
  xml += '<Style ss:ID="Default"><Font ss:FontName="Calibri" ss:Size="11"/></Style>\n';
  xml += '<Style ss:ID="Title"><Font ss:FontName="Calibri" ss:Size="14" ss:Bold="1"/></Style>\n';
  xml += '<Style ss:ID="Header"><Font ss:FontName="Calibri" ss:Size="11" ss:Bold="1"/><Interior ss:Color="#D9E2F3" ss:Pattern="Solid"/></Style>\n';
  xml += '</Styles>\n';

  xml += '<Worksheet ss:Name="Summary"><Table>\n';

  // Title row
  xml += '<Row><Cell ss:StyleID="Title"><Data ss:Type="String">Summary Metrics Overview</Data></Cell></Row>\n';
  xml += '<Row></Row>\n';

  // Headers
  var headerRow = table.querySelector("thead tr");
  if (headerRow) {
    xml += '<Row>\n';
    headerRow.querySelectorAll("th").forEach(function(th) {
      xml += '<Cell ss:StyleID="Header"><Data ss:Type="String">' + xmlEscape(th.textContent.trim()) + '</Data></Cell>\n';
    });
    xml += '</Row>\n';
  }

  // Body rows (skip hidden)
  table.querySelectorAll("tbody tr").forEach(function(tr) {
    if (tr.style.display === "none") return;
    if (tr.classList.contains("tk-base-row")) {
      xml += '<Row>\n';
      tr.querySelectorAll("td").forEach(function(td) {
        xml += '<Cell><Data ss:Type="String">' + xmlEscape(td.textContent.trim()) + '</Data></Cell>\n';
      });
      xml += '</Row>\n';
      return;
    }
    if (tr.classList.contains("tk-section-row")) {
      xml += '<Row><Cell><Data ss:Type="String">' + xmlEscape(tr.textContent.trim()) + '</Data></Cell></Row>\n';
      return;
    }
    xml += '<Row>\n';
    tr.querySelectorAll("td").forEach(function(td) {
      var label = td.querySelector(".tk-metric-label");
      var text = label ? label.textContent.trim() : td.textContent.trim();
      xml += '<Cell><Data ss:Type="String">' + xmlEscape(text) + '</Data></Cell>\n';
    });
    xml += '</Row>\n';
  });

  xml += '</Table>\n</Worksheet>\n</Workbook>';
  downloadBlob(xml, "summary_metrics.xls", "application/vnd.ms-excel");
}

/**
 * Pin the summary metrics table as a view.
 */
function pinSummaryTable() {
  var table = document.getElementById("summary-metrics-table");
  if (!table) return;

  var clone = table.cloneNode(true);
  // Remove hidden rows
  clone.querySelectorAll("tr").forEach(function(tr) {
    if (tr.style.display === "none") tr.parentNode.removeChild(tr);
  });

  var pinObj = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    metricId: "summary-metrics-table",
    metricTitle: "Summary Metrics Overview",
    visibleSegments: [],
    tableHtml: '<div class="tk-table-wrapper">' + clone.outerHTML + '</div>',
    chartSvg: "",
    chartVisible: false,
    insightText: "",
    timestamp: Date.now(),
    order: pinnedViews.length
  };

  pinnedViews.push(pinObj);
  renderPinnedCards();
  updatePinBadge();
  savePinnedData();
}

/**
 * Export summary metrics table as a slide PNG.
 */
function exportSummaryTableSlide() {
  var table = document.getElementById("summary-metrics-table");
  if (!table) return;

  var brandColour = getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367";
  var slideW = 1280, slideH = 720, scale = 3;
  var canvas = document.createElement("canvas");
  canvas.width = slideW * scale;
  canvas.height = slideH * scale;
  var ctx = canvas.getContext("2d");
  ctx.scale(scale, scale);

  // Background
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, slideW, slideH);

  // Header bar
  ctx.fillStyle = brandColour;
  ctx.fillRect(0, 0, slideW, 60);
  ctx.fillStyle = "#fff";
  ctx.font = "bold 22px -apple-system, sans-serif";
  ctx.fillText("Summary Metrics Overview", 30, 40);

  // Table placeholder
  ctx.fillStyle = "#666";
  ctx.font = "13px -apple-system, sans-serif";
  ctx.fillText("See HTML report for full interactive table", 30, 90);

  canvas.toBlob(function(blob) {
    if (!blob) return;
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "summary_metrics_slide.png";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
  }, "image/png");
}


document.addEventListener("DOMContentLoaded", function() {
  hydratePinnedViews();
});
