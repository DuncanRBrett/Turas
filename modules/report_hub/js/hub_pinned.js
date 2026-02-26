/**
 * Unified Pinned Views Manager
 *
 * Collects pins from all embedded reports into a single curated view.
 * Supports section dividers for narrative structure.
 */

(function() {
  "use strict";

  // Unified pin store: array of {type, source, id, ...data}
  ReportHub.pinnedItems = [];

  /**
   * Add a pin from a source report
   * @param {string} source - Report key (e.g., "tracker", "tabs")
   * @param {object} pinObj - Pin data from the source report
   */
  ReportHub.addPin = function(source, pinObj) {
    pinObj.source = source;
    pinObj.type = "pin";
    if (!pinObj.id) {
      pinObj.id = "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5);
    }
    pinObj.timestamp = pinObj.timestamp || Date.now();
    ReportHub.pinnedItems.push(pinObj);
    ReportHub.renderPinnedCards();
    ReportHub.updatePinBadge();
    ReportHub.savePinnedData();
  };

  /**
   * Remove a pin by ID
   * @param {string} pinId
   */
  ReportHub.removePin = function(pinId) {
    var idx = -1;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) {
        idx = i;
        break;
      }
    }
    if (idx === -1) return;

    var item = ReportHub.pinnedItems[idx];
    ReportHub.pinnedItems.splice(idx, 1);

    ReportHub.renderPinnedCards();
    ReportHub.updatePinBadge();
    ReportHub.savePinnedData();
  };

  /**
   * Add a section divider
   * @param {string} title - Section title (editable)
   */
  ReportHub.addSection = function(title) {
    title = title || "New Section";
    var section = {
      type: "section",
      title: title,
      id: "sec-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5)
    };
    ReportHub.pinnedItems.push(section);
    ReportHub.renderPinnedCards();
    ReportHub.savePinnedData();
  };

  /**
   * Move an item (pin or section) up or down
   * @param {number} fromIdx
   * @param {number} toIdx
   */
  ReportHub.moveItem = function(fromIdx, toIdx) {
    if (toIdx < 0 || toIdx >= ReportHub.pinnedItems.length) return;
    var item = ReportHub.pinnedItems.splice(fromIdx, 1)[0];
    ReportHub.pinnedItems.splice(toIdx, 0, item);
    ReportHub.renderPinnedCards();
    ReportHub.savePinnedData();
  };

  /**
   * Update the pin count badge
   */
  ReportHub.updatePinBadge = function() {
    var count = 0;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].type === "pin") count++;
    }
    var badge = document.getElementById("hub-pin-count");
    if (badge) {
      badge.textContent = count;
      badge.style.display = count > 0 ? "" : "none";
    }
  };

  /**
   * Save pinned data to the hidden JSON store
   */
  ReportHub.savePinnedData = function() {
    var store = document.getElementById("hub-pinned-data");
    if (store) {
      store.textContent = JSON.stringify(ReportHub.pinnedItems);
    }
  };

  /**
   * Hydrate pinned views from the JSON store on page load
   */
  ReportHub.hydratePinnedViews = function() {
    var store = document.getElementById("hub-pinned-data");
    if (!store) return;
    try {
      var data = JSON.parse(store.textContent);
      if (Array.isArray(data) && data.length > 0) {
        ReportHub.pinnedItems = data;
        ReportHub.renderPinnedCards();
        ReportHub.updatePinBadge();

        // Multi-pin: no need to restore per-report pin button states
      }
    } catch (e) {
      // Silently ignore parse errors
    }
  };

  /**
   * Render all pinned cards and section dividers
   */
  ReportHub.renderPinnedCards = function() {
    var container = document.getElementById("hub-pinned-cards");
    var emptyState = document.getElementById("hub-pinned-empty");
    var toolbar = document.getElementById("hub-pinned-toolbar");

    if (!container) return;

    var pinCount = 0;
    for (var c = 0; c < ReportHub.pinnedItems.length; c++) {
      if (ReportHub.pinnedItems[c].type === "pin") pinCount++;
    }

    if (pinCount === 0) {
      container.innerHTML = "";
      if (emptyState) emptyState.style.display = "";
      if (toolbar) toolbar.style.display = "none";
      return;
    }

    if (emptyState) emptyState.style.display = "none";
    if (toolbar) toolbar.style.display = "";

    var html = "";
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      var item = ReportHub.pinnedItems[i];

      if (item.type === "section") {
        html += buildSectionDividerHTML(item, i);
      } else if (item.type === "pin") {
        html += buildPinCardHTML(item, i);
      }
    }

    container.innerHTML = html;
  };

  /**
   * Build HTML for a section divider
   */
  function buildSectionDividerHTML(section, idx) {
    var total = ReportHub.pinnedItems.length;
    return '<div class="hub-section-divider" data-idx="' + idx + '">' +
      '<div class="hub-section-title" contenteditable="true" ' +
        'onblur="ReportHub.updateSectionTitle(' + idx + ', this.textContent)">' +
        escapeHtml(section.title) + '</div>' +
      '<div class="hub-section-actions">' +
        (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx - 1) + ')" title="Move up">\u25B2</button>' : '') +
        (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx + 1) + ')" title="Move down">\u25BC</button>' : '') +
        '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + section.id + '\')" title="Remove section">\u00D7</button>' +
      '</div>' +
    '</div>';
  }

  /**
   * Build HTML for a pin card
   */
  function buildPinCardHTML(pin, idx) {
    var total = ReportHub.pinnedItems.length;
    var sourceBadge;
    if (pin.source === "tracker") {
      sourceBadge = '<span class="hub-source-badge hub-badge-tracker">Tracker</span>';
    } else if (pin.source === "overview") {
      sourceBadge = '<span class="hub-source-badge hub-badge-overview">Overview</span>';
    } else {
      sourceBadge = '<span class="hub-source-badge hub-badge-tabs">Crosstabs</span>';
    }

    var title = pin.title || pin.metricLabel || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || "";

    var html = '<div class="hub-pin-card" data-pin-id="' + pin.id + '" data-idx="' + idx + '">' +
      '<div class="hub-pin-header">' +
        sourceBadge +
        '<span class="hub-pin-title">' + escapeHtml(title) + '</span>' +
        '<div class="hub-pin-actions">' +
          '<button class="hub-action-btn" onclick="ReportHub.exportPinCard(\'' + pin.id + '\')" title="Export as PNG">\uD83D\uDCF8</button>' +
          (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx - 1) + ')" title="Move up">\u25B2</button>' : '') +
          (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItem(' + idx + ',' + (idx + 1) + ')" title="Move down">\u25BC</button>' : '') +
          '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + pin.id + '\')" title="Remove">\u00D7</button>' +
        '</div>' +
      '</div>';

    if (subtitle) {
      html += '<div class="hub-pin-subtitle">' + escapeHtml(subtitle) + '</div>';
    }

    // Insight area (editable)
    var insightText = pin.insight || "";
    html += '<div class="hub-pin-insight">' +
      '<div class="hub-insight-editor" contenteditable="true" ' +
        'data-placeholder="Add insight..." ' +
        'onblur="ReportHub.syncPinInsight(\'' + pin.id + '\', this.textContent)">' +
        escapeHtml(insightText) +
      '</div>' +
    '</div>';

    // Chart (if captured and was visible when pinned)
    if (pin.chartSvg && pin.chartVisible !== false) {
      html += '<div class="hub-pin-chart">' + pin.chartSvg + '</div>';
    }

    // PNG snapshot (hidden – used only for export, not displayed on screen)
    if (pin.pngDataUrl) {
      html += '<div class="hub-pin-snapshot" style="display:none"><img src="' + pin.pngDataUrl + '" alt="Pinned view"></div>';
    }

    // Table (if captured)
    if (pin.tableHtml) {
      html += '<div class="hub-pin-table">' + pin.tableHtml + '</div>';
    }

    html += '</div>';
    return html;
  }

  /**
   * Update a section's title after editing
   */
  ReportHub.updateSectionTitle = function(idx, newTitle) {
    if (idx >= 0 && idx < ReportHub.pinnedItems.length &&
        ReportHub.pinnedItems[idx].type === "section") {
      ReportHub.pinnedItems[idx].title = newTitle.trim() || "Untitled Section";
      ReportHub.savePinnedData();
    }
  };

  /**
   * Sync a pin's insight text after editing
   */
  ReportHub.syncPinInsight = function(pinId, text) {
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) {
        ReportHub.pinnedItems[i].insight = text.trim();
        ReportHub.savePinnedData();
        break;
      }
    }
  };

  /**
   * Pin an overview summary editor's content
   * @param {string} source - Data source key (e.g., "tracker", "tabs")
   */
  ReportHub.pinOverviewSummary = function(source) {
    var editors = document.querySelectorAll('.hub-summary-editor[data-source="' + source + '"]');
    if (!editors.length) return;
    var editor = editors[0];
    var text = editor.innerText.trim();
    if (!text) { alert("Add summary text before pinning."); return; }
    var section = editor.closest(".hub-summary-section");
    var title = section ? section.querySelector(".hub-summary-label").textContent : "Overview Summary";
    var pinObj = {
      id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
      title: title,
      insight: text,
      timestamp: Date.now()
    };
    ReportHub.addPin("overview", pinObj);
  };

  // ==========================================================================
  // SVG-Native PNG Export Helpers
  // ==========================================================================
  // Builds pure SVG (no foreignObject), clones chart SVG into <g>, renders
  // tables as SVG rect+text elements. Single reliable code path.
  // ==========================================================================

  /** Wrap text into lines that fit within maxWidth (character-based estimate) */
  function hubWrapTextLines(text, maxWidth, charWidth) {
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

  /** Create SVG <text> with <tspan> lines */
  function hubCreateWrappedText(ns, lines, x, startY, lineHeight, attrs) {
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

  /**
   * Extract table data from stored pin HTML.
   * Handles both tracker-style (tk-*) and tabs-style (ct-table) classes.
   */
  function hubExtractPinTableData(tableHtml) {
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
        // Tabs uses .ct-header-text; tracker uses plain text
        var text = th.querySelector(".ct-header-text");
        headerCells.push(text ? text.textContent.trim() : th.textContent.trim().split("\n")[0].trim());
      });
      if (headerCells.length > 0) {
        rows.push({ cells: headerCells, type: "header" });
      }
    }

    // Body rows
    table.querySelectorAll("tbody tr").forEach(function(tr) {
      if (tr.style.display === "none") return;
      if (tr.classList.contains("ct-row-excluded")) return;

      var rowInfo = { cells: [], type: "data" };

      // Tracker-style rows
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
        var dot = tr.querySelector(".tk-seg-dot");
        if (dot) rowInfo.colour = dot.style.background || dot.style.backgroundColor || null;

      // Tabs-style rows
      } else if (tr.classList.contains("ct-row-base")) {
        rowInfo.type = "base";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else if (tr.classList.contains("ct-row-mean")) {
        rowInfo.type = "mean";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else if (tr.classList.contains("ct-row-net")) {
        rowInfo.type = "net";
        tr.querySelectorAll("td").forEach(function(td) {
          if (td.style.display === "none") return;
          var clone = td.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      } else {
        // Generic row (works for both tracker and tabs)
        tr.querySelectorAll("th, td").forEach(function(cell) {
          if (cell.style.display === "none") return;
          var clone = cell.cloneNode(true);
          clone.querySelectorAll(".ct-freq, .ct-sig, .row-exclude-btn, .ct-sort-indicator").forEach(function(el) { el.remove(); });
          rowInfo.cells.push(clone.textContent.trim());
        });
      }

      if (rowInfo.cells.length > 0) {
        rows.push(rowInfo);
      }
    });

    return rows.length > 0 ? rows : null;
  }

  /** Render table as SVG rect+text elements */
  function hubRenderPinTableSVG(ns, svgParent, tableData, x, y, maxWidth) {
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
      } else if (row.type === "mean") {
        bgRect.setAttribute("fill", "#fef9e7");
      } else if (row.type === "net") {
        bgRect.setAttribute("fill", "#f5f0e8");
      } else if (ri % 2 === 0) {
        bgRect.setAttribute("fill", "#ffffff");
      } else {
        bgRect.setAttribute("fill", "#f9fafb");
      }
      svgParent.appendChild(bgRect);

      // Segment colour dot for tracker data/total rows
      if (row.type === "data" || row.type === "total") {
        if (row.colour || tableData.some(function(r) { return r.colour; })) {
          var dotColour = row.colour || COLOURS[colourIdx % COLOURS.length];
          var dot = document.createElementNS(ns, "circle");
          dot.setAttribute("cx", x + 12);
          dot.setAttribute("cy", curY + rH / 2);
          dot.setAttribute("r", "3.5");
          dot.setAttribute("fill", dotColour);
          svgParent.appendChild(dot);
          colourIdx++;
        }
      }

      // Cell text
      row.cells.forEach(function(cellText, ci) {
        var cellW = ci === 0 ? firstColW : dataColW;
        var cellX;
        if (ci === 0) {
          var hasColourDots = tableData.some(function(r) { return r.colour; });
          cellX = (hasColourDots && (row.type === "data" || row.type === "total")) ? x + 22 : x + padX;
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
        } else if (row.type === "total" || row.type === "net") {
          textEl.setAttribute("fill", ci === 0 ? "#1a2744" : "#1e293b");
          textEl.setAttribute("font-weight", "600");
        } else if (row.type === "base") {
          textEl.setAttribute("fill", "#666666");
          textEl.setAttribute("font-weight", "600");
          textEl.setAttribute("font-size", fontSize - 1);
        } else if (row.type === "change") {
          textEl.setAttribute("fill", "#888888");
          textEl.setAttribute("font-size", fontSize - 1);
        } else if (row.type === "mean") {
          textEl.setAttribute("fill", "#5c4a2a");
          textEl.setAttribute("font-style", "italic");
        } else {
          textEl.setAttribute("fill", ci === 0 ? "#374151" : "#1e293b");
        }

        var maxChars = Math.floor((cellW - padX * 2) / (fontSize * 0.55));
        if (maxChars > 0 && cellText.length > maxChars) {
          cellText = cellText.substring(0, Math.max(maxChars - 1, 5)) + "\u2026";
        }

        textEl.textContent = cellText;
        svgParent.appendChild(textEl);
      });

      var borderLine = document.createElementNS(ns, "line");
      borderLine.setAttribute("x1", x); borderLine.setAttribute("x2", x + maxWidth);
      borderLine.setAttribute("y1", curY + rH); borderLine.setAttribute("y2", curY + rH);
      borderLine.setAttribute("stroke", "#e2e8f0"); borderLine.setAttribute("stroke-width", "0.5");
      svgParent.appendChild(borderLine);

      curY += rH;
    });

    return curY - y;
  }

  // ==========================================================================
  // Export Functions
  // ==========================================================================

  /**
   * Export a single pin card as a PowerPoint-quality PNG using SVG-native approach.
   * Builds pure SVG: brand bar → title → meta → insight → chart → table → footer.
   * No foreignObject — single reliable code path.
   * @param {string} pinId - Pin ID
   */
  ReportHub.exportPinCard = function(pinId) {
    // Find pin data in the store
    var pin = null;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) { pin = ReportHub.pinnedItems[i]; break; }
    }
    if (!pin) return;

    var ns = "http://www.w3.org/2000/svg";
    var W = 1280;
    var fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
    var pad = 28;
    var usableW = W - pad * 2;
    var brandColour = "#323367";

    // ---- Resolve fields (handle both tracker and tabs field names) ----
    var titleText = pin.title || pin.metricTitle || pin.qTitle || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || pin.qTitle || "";
    // For tabs: title is qCode, subtitle is qTitle. Combine for the slide.
    if (pin.source === "tabs" && pin.qCode && pin.qTitle) {
      titleText = pin.qCode + " - " + pin.qTitle;
      subtitle = "";
    }
    var insightRaw = pin.insight || pin.insightText || "";
    var insightPlain = "";
    if (insightRaw) {
      var tmpDiv = document.createElement("div");
      tmpDiv.innerHTML = insightRaw;
      insightPlain = tmpDiv.textContent.trim();
    }

    // ---- 1. Title ----
    var titleLines = hubWrapTextLines(titleText, usableW, 9.5);
    var titleLineH = 20;
    var titleStartY = pad + 16;
    var titleBlockH = titleLines.length * titleLineH;

    // ---- 2. Meta line ----
    var metaParts = [];
    // Source badge
    if (pin.source === "tracker") metaParts.push("Tracker");
    else if (pin.source === "tabs") metaParts.push("Crosstabs");
    else if (pin.source === "overview") metaParts.push("Overview");
    // Date
    if (pin.timestamp) metaParts.push(new Date(pin.timestamp).toLocaleDateString());
    // Segments (tracker)
    if (pin.visibleSegments && pin.visibleSegments.length > 0) {
      metaParts.push("Segments: " + pin.visibleSegments.join(", "));
    }
    // Banner (tabs)
    if (pin.bannerLabel) metaParts.push("Banner: " + pin.bannerLabel);
    // Base (tabs)
    if (pin.baseText) metaParts.push("Base: " + pin.baseText);

    var metaText = metaParts.join("  \u00B7  ");
    var metaY = titleStartY + titleBlockH + 4;
    var contentTop = metaY + 18;

    // ---- 3. Insight ----
    var insightLines = hubWrapTextLines(insightPlain, usableW - 16, 7.5);
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
        // Resolve CSS variable references in chart SVG
        chartClone.querySelectorAll("*").forEach(function(el) {
          ["fill", "stroke"].forEach(function(attr) {
            var val = el.getAttribute(attr);
            if (val && val.indexOf("var(") !== -1) {
              var match = val.match(/var\(--[^,)]+,\s*([^)]+)\)/);
              if (match) el.setAttribute(attr, match[1].trim());
            }
          });
        });
        var vb = chartClone.getAttribute("viewBox");
        if (vb) {
          var chartVB = vb.split(" ").map(Number);
          chartScale = usableW / chartVB[2];
          chartDisplayH = chartVB[3] * chartScale;
        }
      }
    }

    // ---- 5. Table dimensions ----
    var tableTopY = chartTopY + chartDisplayH + (chartDisplayH > 0 ? 14 : 0);
    var tableData = null;
    var estimatedTableH = 0;

    if (pin.tableHtml) {
      tableData = hubExtractPinTableData(pin.tableHtml);
      if (tableData && tableData.length > 0) {
        estimatedTableH = 26 + (tableData.length - 1) * 22 + 8;
      }
    }

    // ---- 6. Total height ----
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
    var titleResult = hubCreateWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
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
      var insResult = hubCreateWrappedText(ns, insightLines, pad + 14, insightY + 18, insightLineH,
        { fill: "#1a2744", "font-size": "13", "font-weight": "500" });
      svg.appendChild(insResult.element);
    }

    // Chart — clone SVG content into <g> element
    if (chartClone && chartDisplayH > 0) {
      var chartG = document.createElementNS(ns, "g");
      chartG.setAttribute("transform", "translate(" + pad + "," + chartTopY + ") scale(" + chartScale + ")");
      while (chartClone.firstChild) chartG.appendChild(chartClone.firstChild);
      svg.appendChild(chartG);
    }

    // Table — rendered as SVG rect+text elements
    if (tableData && tableData.length > 0) {
      var actualTableH = hubRenderPinTableSVG(ns, svg, tableData, pad, tableTopY, usableW);
      var newTotalH = tableTopY + actualTableH + pad + 20;
      if (newTotalH > totalH) {
        totalH = newTotalH;
        bg.setAttribute("height", totalH);
        svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
      }
    }

    // Footer line
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
    footerText.textContent = "Combined Report";
    svg.appendChild(footerText);

    // ---- Render SVG to PNG at 3x resolution ----
    var renderScale = 3;
    var svgData = new XMLSerializer().serializeToString(svg);
    var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    var url = URL.createObjectURL(svgBlob);

    var img = new Image();
    img.onerror = function() {
      URL.revokeObjectURL(url);
      console.error("[Hub Pin PNG] SVG render failed for pin: " + pinId);
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
        var slug = titleText.replace(/[^a-zA-Z0-9]/g, "_").substring(0, 40);
        var filename = "pinned_" + slug + ".png";
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
  };

  /**
   * Export all pinned cards as individual PNGs (sequential download)
   */
  ReportHub.exportAllPins = function() {
    var pins = [];
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].type === "pin") {
        pins.push(ReportHub.pinnedItems[i].id);
      }
    }
    if (pins.length === 0) return;

    var idx = 0;
    function exportNext() {
      if (idx >= pins.length) return;
      ReportHub.exportPinCard(pins[idx]);
      idx++;
      setTimeout(exportNext, 600);
    }
    exportNext();
  };

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
      var a2 = document.createElement("a");
      a2.href = dataUrl;
      a2.download = filename;
      document.body.appendChild(a2);
      a2.click();
      document.body.removeChild(a2);
    }
  }

  /**
   * Escape HTML entities
   */
  function escapeHtml(str) {
    if (!str) return "";
    return str.replace(/&/g, "&amp;")
              .replace(/</g, "&lt;")
              .replace(/>/g, "&gt;")
              .replace(/"/g, "&quot;");
  }

})();
