// ---- Pinned Views ----
var pinnedViews = [];

function updatePinBadge() {
  var badge = document.getElementById("pin-count-badge");
  if (badge) {
    badge.textContent = pinnedViews.length;
    badge.style.display = pinnedViews.length > 0 ? "inline" : "none";
  }
  var empty = document.getElementById("pinned-empty-state");
  var cards = document.getElementById("pinned-cards-container");
  if (empty) empty.style.display = pinnedViews.length === 0 ? "block" : "none";
  if (cards) cards.style.display = pinnedViews.length > 0 ? "block" : "none";
}

function savePinnedData() {
  var store = document.getElementById("pinned-views-data");
  if (store) store.textContent = JSON.stringify(pinnedViews);
}

function togglePin(qCode) {
  // Always add a new pin (multi-pin support).
  // Each pin captures the current view state (banner, chart, table).
  // Unpinning is done via the ✕ button on each pinned card.
  var pin = captureCurrentView(qCode);
  if (pin) {
    pinnedViews.push(pin);
    updatePinButton(qCode, true);
  }
  savePinnedData();
  renderPinnedCards();
  updatePinBadge();
}

function updatePinButton(qCode, isPinned) {
  document.querySelectorAll(".pin-btn[data-q-code=\"" + qCode + "\"]").forEach(function(btn) {
    btn.style.color = isPinned ? "#323367" : "#94a3b8";
    btn.style.borderColor = isPinned ? "#323367" : "#e2e8f0";
    btn.title = isPinned ? "Unpin this view" : "Pin this view";
  });
}

function captureCurrentView(qCode) {
  var container = document.querySelector(".question-container .chart-wrapper[data-q-code=\"" + qCode + "\"]");
  if (!container) container = document.querySelector(".chart-wrapper[data-q-code=\"" + qCode + "\"]");
  var qContainer = container ? container.closest(".question-container") : null;
  if (!qContainer) return null;

  var wrapper = qContainer.querySelector(".chart-wrapper");
  var qTitle = wrapper ? wrapper.getAttribute("data-q-title") || "" : "";
  var chartDataStr = wrapper ? wrapper.getAttribute("data-chart-data") : null;

  // Capture selected chart columns
  var selectedCols = [];
  if (chartColumnState[qCode]) {
    selectedCols = Object.keys(chartColumnState[qCode]).filter(function(k) {
      return chartColumnState[qCode][k];
    });
  }

  // Capture excluded rows
  var excludedRows = [];
  if (window._chartExclusions && window._chartExclusions[qCode]) {
    excludedRows = Object.keys(window._chartExclusions[qCode]);
  }

  // Capture insight text
  var insightText = "";
  var editor = qContainer.querySelector(".insight-editor");
  if (editor) insightText = editor.textContent.trim();

  // Capture table sort state
  var table = qContainer.querySelector("table.ct-table");
  var tableSortState = null;
  if (table && sortState[table.id] && sortState[table.id].direction !== "none") {
    tableSortState = { colKey: sortState[table.id].colKey, direction: sortState[table.id].direction };
  }

  // Capture visible table HTML (clone, remove hidden cols and excluded rows)
  var tableClone = table ? table.cloneNode(true) : null;
  if (tableClone) {
    // Remove hidden columns
    tableClone.querySelectorAll("[style*=\"display: none\"], [style*=\"display:none\"]").forEach(function(el) { el.remove(); });
    // Remove excluded rows
    tableClone.querySelectorAll(".ct-row-excluded").forEach(function(el) { el.remove(); });
    // Remove sort indicators, exclude buttons, and frequency/significance annotations
    tableClone.querySelectorAll(".ct-sort-indicator, .row-exclude-btn, .ct-freq, .ct-sig").forEach(function(el) { el.remove(); });
  }

  // Capture chart SVG
  var chartSvg = wrapper ? wrapper.querySelector("svg") : null;
  var chartSvgStr = chartSvg ? new XMLSerializer().serializeToString(chartSvg) : "";

  // Get active banner label
  var bannerLabel = "";
  var activeBannerTab = document.querySelector(".banner-tab.active");
  if (activeBannerTab) bannerLabel = activeBannerTab.textContent.trim();

  // Get base text
  var baseText = "";
  var baseRow = qContainer.querySelector("tr.ct-row-base");
  if (baseRow) {
    var baseCells = baseRow.querySelectorAll("td:not([style*=none])");
    if (baseCells.length > 1) baseText = "n=" + baseCells[1].textContent.trim();
  }

  return {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    qCode: qCode,
    qTitle: qTitle,
    bannerGroup: currentGroup,
    bannerLabel: bannerLabel,
    selectedColumns: selectedCols,
    excludedRows: excludedRows,
    insightText: insightText,
    sortState: tableSortState,
    tableHtml: tableClone ? tableClone.outerHTML : "",
    chartSvg: chartSvgStr,
    baseText: baseText,
    timestamp: Date.now(),
    order: pinnedViews.length
  };
}

function renderPinnedCards() {
  var container = document.getElementById("pinned-cards-container");
  if (!container) return;
  container.innerHTML = "";

  // Count actual pins (not sections) for empty state
  var pinCount = 0;
  for (var c = 0; c < pinnedViews.length; c++) {
    if (pinnedViews[c].type !== "section") pinCount++;
  }
  var empty = document.getElementById("pinned-empty-state");
  if (empty) empty.style.display = pinCount === 0 ? "block" : "none";

  var total = pinnedViews.length;

  pinnedViews.forEach(function(item, idx) {

    // Section divider
    if (item.type === "section") {
      var divider = document.createElement("div");
      divider.className = "section-divider";
      divider.setAttribute("data-idx", idx);

      var titleEl = document.createElement("div");
      titleEl.className = "section-divider-title";
      titleEl.contentEditable = "true";
      titleEl.textContent = item.title;
      titleEl.onblur = function() { updateSectionTitle(idx, this.textContent); };
      divider.appendChild(titleEl);

      var sActions = document.createElement("div");
      sActions.className = "section-divider-actions";
      if (idx > 0) {
        var sUp = document.createElement("button");
        sUp.className = "export-btn";
        sUp.style.cssText = "padding:3px 8px;font-size:11px;";
        sUp.textContent = "\u25B2"; sUp.title = "Move up";
        sUp.onclick = function() { movePinned(idx, idx - 1); };
        sActions.appendChild(sUp);
      }
      if (idx < total - 1) {
        var sDown = document.createElement("button");
        sDown.className = "export-btn";
        sDown.style.cssText = "padding:3px 8px;font-size:11px;";
        sDown.textContent = "\u25BC"; sDown.title = "Move down";
        sDown.onclick = function() { movePinned(idx, idx + 1); };
        sActions.appendChild(sDown);
      }
      var sDel = document.createElement("button");
      sDel.className = "export-btn";
      sDel.style.cssText = "padding:3px 8px;font-size:11px;color:#e8614d;";
      sDel.textContent = "\u2715"; sDel.title = "Remove section";
      sDel.onclick = function() { removePinned(item.id, null); };
      sActions.appendChild(sDel);
      divider.appendChild(sActions);
      container.appendChild(divider);
      return;
    }

    // Pin card
    var pin = item;
    var card = document.createElement("div");
    card.className = "pinned-card";
    card.setAttribute("data-pin-id", pin.id);
    card.style.cssText = "background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:20px;margin-bottom:16px;";

    // Header with title, banner, base, controls
    var header = document.createElement("div");
    header.style.cssText = "display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:12px;";
    var titleDiv = document.createElement("div");
    if (pin.pinType === "text_box" || pin.pinType === "heatmap" || pin.pinType === "dashboard_section") {
      // Simplified header for dashboard pins (no qCode/banner)
      titleDiv.innerHTML = "<div style=\"font-size:14px;font-weight:600;color:#1e293b;\">" + escapeHtml(pin.qTitle || "") + "</div>";
    } else {
      // Standard crosstab header
      titleDiv.innerHTML = "<div style=\"font-size:11px;color:#323367;font-weight:700;\">" + escapeHtml(pin.qCode || "") + "</div>" +
        "<div style=\"font-size:14px;font-weight:600;color:#1e293b;\">" + escapeHtml(pin.qTitle || "") + "</div>" +
        "<div style=\"font-size:11px;color:#94a3b8;margin-top:2px;\">Banner: " + escapeHtml(pin.bannerLabel || "") +
        (pin.baseText ? " \u00B7 Base: " + escapeHtml(pin.baseText) : "") + "</div>";
    }
    header.appendChild(titleDiv);

    var controls = document.createElement("div");
    controls.style.cssText = "display:flex;gap:4px;flex-shrink:0;";
    if (idx > 0) {
      var upBtn = document.createElement("button");
      upBtn.className = "export-btn";
      upBtn.style.cssText = "padding:3px 8px;font-size:11px;";
      upBtn.textContent = "\u25B2";
      upBtn.title = "Move up";
      upBtn.onclick = function() { movePinned(idx, idx - 1); };
      controls.appendChild(upBtn);
    }
    if (idx < pinnedViews.length - 1) {
      var downBtn = document.createElement("button");
      downBtn.className = "export-btn";
      downBtn.style.cssText = "padding:3px 8px;font-size:11px;";
      downBtn.textContent = "\u25BC";
      downBtn.title = "Move down";
      downBtn.onclick = function() { movePinned(idx, idx + 1); };
      controls.appendChild(downBtn);
    }
    var exportBtn = document.createElement("button");
    exportBtn.className = "export-btn";
    exportBtn.style.cssText = "padding:3px 8px;font-size:11px;";
    exportBtn.innerHTML = "&#128247;";
    exportBtn.title = "Export as PNG";
    exportBtn.onclick = (function(id) { return function() { exportPinnedCardPNG(id); }; })(pin.id);
    controls.appendChild(exportBtn);
    var removeBtn = document.createElement("button");
    removeBtn.className = "export-btn";
    removeBtn.style.cssText = "padding:3px 8px;font-size:11px;color:#e8614d;";
    removeBtn.textContent = "\u2715";
    removeBtn.title = "Remove pin";
    removeBtn.onclick = function() { removePinned(pin.id, pin.qCode); };
    controls.appendChild(removeBtn);
    header.appendChild(controls);
    card.appendChild(header);

    // Content: stacked layout — insight, chart, table
    // Insight first (the "so what")
    if (pin.insightText) {
      var insightDiv = document.createElement("div");
      if (pin.pinType === "text_box") {
        // Text box pins: plain body text, no accent bar
        insightDiv.style.cssText = "margin-bottom:12px;padding:16px 20px;background:#f8fafc;border-radius:8px;font-size:14px;line-height:1.7;color:#1e293b;font-weight:400;white-space:pre-wrap;";
      } else {
        // Standard crosstab insight: prominent callout
        insightDiv.style.cssText = "margin-bottom:12px;padding:16px 24px;border-left:4px solid #323367;background:linear-gradient(135deg,#f0f5f5 0%,#f8fafa 100%);border-radius:0 8px 8px 0;font-size:15px;line-height:1.5;color:#1a2744;font-weight:600;";
      }
      insightDiv.textContent = pin.insightText;
      card.appendChild(insightDiv);
    }

    // Chart (visual pattern)
    if (pin.chartSvg) {
      var chartDiv = document.createElement("div");
      chartDiv.style.cssText = "margin-bottom:12px;";
      chartDiv.innerHTML = pin.chartSvg;
      card.appendChild(chartDiv);
    }

    // Table (detailed reference)
    if (pin.tableHtml) {
      var tableDiv = document.createElement("div");
      tableDiv.style.cssText = "overflow-x:auto;font-size:11px;";
      tableDiv.innerHTML = pin.tableHtml;
      var tbl = tableDiv.querySelector("table");
      if (tbl) tbl.style.cssText = "font-size:10px;width:100%;table-layout:fixed;word-wrap:break-word;overflow-wrap:break-word;";
      card.appendChild(tableDiv);
    }

    container.appendChild(card);
  });
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
  savePinnedData();
  renderPinnedCards();
  updatePinBadge();
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

function movePinned(fromIdx, toIdx) {
  if (toIdx < 0 || toIdx >= pinnedViews.length) return;
  var item = pinnedViews.splice(fromIdx, 1)[0];
  pinnedViews.splice(toIdx, 0, item);
  savePinnedData();
  renderPinnedCards();
}

function removePinned(pinId, qCode) {
  pinnedViews = pinnedViews.filter(function(p) { return p.id !== pinId; });
  if (qCode) updatePinButton(qCode, pinnedViews.some(function(p) { return p.qCode === qCode; }));
  savePinnedData();
  renderPinnedCards();
  updatePinBadge();
}

function hydratePinnedViews() {
  var store = document.getElementById("pinned-views-data");
  if (!store) return;
  try {
    var data = JSON.parse(store.textContent);
    if (Array.isArray(data) && data.length > 0) {
      pinnedViews = data;
      renderPinnedCards();
      updatePinBadge();
    }
  } catch(e) {}
}

/**
 * Export a single pinned card as a PowerPoint-quality PNG slide.
 * Uses the same SVG-native approach as exportAllPinnedSlides.
 * @param {string} pinId - The pin ID
 */
function exportPinnedCardPNG(pinId) {
  var pin = null;
  for (var i = 0; i < pinnedViews.length; i++) {
    if (pinnedViews[i].id === pinId) { pin = pinnedViews[i]; break; }
  }
  if (!pin || pin.type === "section") return;

  var ns = "http://www.w3.org/2000/svg";
  var W = 1280, fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
  var pad = 28;
  var scale = 3;
  var usableW = W - pad * 2;

  var titleFullText = (pin.pinType === "text_box" || pin.pinType === "heatmap")
    ? pin.qTitle
    : pin.qCode + " - " + pin.qTitle;
  var titleLines = wrapTextLines(titleFullText, usableW, 9.5);
  var titleLineH = 20;
  var titleStartY = pad + 16;
  var titleBlockH = titleLines.length * titleLineH;
  var metaText = (pin.pinType === "text_box" || pin.pinType === "heatmap")
    ? ""
    : "Base: " + (pin.baseText || "\u2014") + " \u00B7 Banner: " + (pin.bannerLabel || "");
  var metaY = titleStartY + titleBlockH + 4;
  var contentTop = metaY + 18;

  // 1. Insight dimensions
  var insightLines = wrapTextLines(pin.insightText, usableW - 16, 7);
  var insightLineH = 17;
  var insightBlockH = insightLines.length > 0 ? insightLines.length * insightLineH + 24 : 0;
  var insightY = contentTop;

  // 2. Chart dimensions (full width)
  var chartTopY = contentTop + insightBlockH + (insightBlockH > 0 ? 12 : 0);
  var chartH = 0, hasChart = false;
  var chartTemp = null;
  if (pin.chartSvg) {
    var tempDiv = document.createElement("div");
    tempDiv.innerHTML = pin.chartSvg;
    chartTemp = tempDiv.querySelector("svg");
    if (chartTemp) {
      hasChart = true;
      var vb = chartTemp.getAttribute("viewBox");
      if (vb) {
        var parts = vb.split(" ").map(Number);
        var cScale = usableW / parts[2];
        chartH = parts[3] * cScale;
      }
    }
  }

  // 3. Table dimensions (full width)
  var tableTopY = chartTopY + chartH + (chartH > 0 ? 12 : 0);
  var tableH = 0;
  if (pin.tableHtml) {
    var countRows = (pin.tableHtml.match(/<tr/g) || []).length;
    tableH = countRows * 18 + 4;
  }

  var totalH = tableTopY + tableH + pad + 20;

  var svg = document.createElementNS(ns, "svg");
  svg.setAttribute("xmlns", ns);
  svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
  svg.setAttribute("style", "font-family:" + fontFamily + ";");

  var bg = document.createElementNS(ns, "rect");
  bg.setAttribute("width", W); bg.setAttribute("height", totalH);
  bg.setAttribute("fill", "#ffffff");
  svg.appendChild(bg);

  var titleResult = createWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
    { fill: "#1a2744", "font-size": "16", "font-weight": "700" });
  svg.appendChild(titleResult.element);

  var metaEl = document.createElementNS(ns, "text");
  metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
  metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "11");
  metaEl.textContent = metaText;
  svg.appendChild(metaEl);

  var isTextBox = pin.pinType === "text_box";

  // 1. Insight
  if (insightLines.length > 0) {
    var aH = Math.max(28, insightLines.length * insightLineH + 12);
    var insBg = document.createElementNS(ns, "rect");
    insBg.setAttribute("x", pad); insBg.setAttribute("y", insightY + 2);
    insBg.setAttribute("width", usableW); insBg.setAttribute("height", aH);
    insBg.setAttribute("rx", "4");
    insBg.setAttribute("fill", isTextBox ? "#f8fafc" : "#f0f4ff");
    svg.appendChild(insBg);
    if (!isTextBox) {
      var iB = document.createElementNS(ns, "rect");
      iB.setAttribute("x", pad); iB.setAttribute("y", insightY + 2);
      iB.setAttribute("width", "4"); iB.setAttribute("height", aH);
      iB.setAttribute("fill", "#323367"); iB.setAttribute("rx", "2");
      svg.appendChild(iB);
    }
    var insFontSize = isTextBox ? "14" : "13";
    var insXOffset = isTextBox ? 12 : 14;
    var insRes = createWrappedText(ns, insightLines, pad + insXOffset, insightY + 18, insightLineH,
      { fill: "#1a2744", "font-size": insFontSize, "font-weight": isTextBox ? "400" : "500" });
    svg.appendChild(insRes.element);
  }

  // 2. Chart
  if (hasChart && chartTemp) {
    var chartClone = chartTemp.cloneNode(true);
    var cvb = chartClone.getAttribute("viewBox").split(" ").map(Number);
    var cScale2 = usableW / cvb[2];
    var cG = document.createElementNS(ns, "g");
    cG.setAttribute("transform", "translate(" + pad + "," + chartTopY + ") scale(" + cScale2 + ")");
    while (chartClone.firstChild) cG.appendChild(chartClone.firstChild);
    svg.appendChild(cG);
  }

  // 3. Table
  if (pin.tableHtml) {
    var tDiv = document.createElement("div");
    tDiv.innerHTML = pin.tableHtml;
    var tRows = extractSlideTableData({
      querySelector: function(sel) { return tDiv.querySelector(sel); },
      querySelectorAll: function(sel) { return tDiv.querySelectorAll(sel); }
    });
    if (tRows) {
      renderTableSVG(ns, svg, tRows, pad, tableTopY, usableW);
    }
  }

  // Render SVG to PNG at 3x
  var svgData = new XMLSerializer().serializeToString(svg);
  var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
  var url = URL.createObjectURL(svgBlob);
  var sImg = new Image();
  sImg.onerror = function() {
    URL.revokeObjectURL(url);
    alert("PNG export failed. Try Chrome or Edge.");
  };
  sImg.onload = function() {
    var canvas = document.createElement("canvas");
    canvas.width = W * scale; canvas.height = totalH * scale;
    var ctx = canvas.getContext("2d");
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(sImg, 0, 0, canvas.width, canvas.height);
    URL.revokeObjectURL(url);
    canvas.toBlob(function(blob) {
      var slug = (pin.qCode || "pin").replace(/[^a-zA-Z0-9]/g, "_");
      downloadBlob(blob, "pin_" + slug + "_slide.png");
    }, "image/png");
  };
  sImg.src = url;
}

function exportAllPinnedSlides() {
  if (pinnedViews.length === 0) {
    alert("No pinned views to export.");
    return;
  }
  var ns = "http://www.w3.org/2000/svg";
  var W = 1280, fontFamily = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
  var pad = 28;
  var scale = 3;
  var DOWNLOAD_DELAY_MS = 600;

  // Step 1: Build all SVG blobs upfront (synchronous)
  var slides = [];
  pinnedViews.forEach(function(pin, idx) {
    // Skip section dividers
    if (pin.type === "section") return;
    var usableW = W - pad * 2;
    var titleFullText = (pin.pinType === "text_box" || pin.pinType === "heatmap")
      ? pin.qTitle
      : pin.qCode + " - " + pin.qTitle;
    var titleLines = wrapTextLines(titleFullText, usableW, 9.5);
    var titleLineH = 20;
    var titleStartY = pad + 16;
    var titleBlockH = titleLines.length * titleLineH;
    var metaText = (pin.pinType === "text_box" || pin.pinType === "heatmap")
      ? ""
      : "Base: " + (pin.baseText || "\u2014") + " \u00B7 Banner: " + (pin.bannerLabel || "");
    var metaY = titleStartY + titleBlockH + 4;
    var contentTop = metaY + 18;

    // Stacked layout: insight → chart → table
    // 1. Insight dimensions
    var insightLines = wrapTextLines(pin.insightText, usableW - 16, 7);
    var insightLineH = 17;
    var insightBlockH = insightLines.length > 0 ? insightLines.length * insightLineH + 24 : 0;
    var insightY = contentTop;

    // 2. Chart dimensions (full width)
    var chartTopY = contentTop + insightBlockH + (insightBlockH > 0 ? 12 : 0);
    var chartH = 0, hasChart = false;
    var chartTemp = null;
    if (pin.chartSvg) {
      var tempDiv = document.createElement("div");
      tempDiv.innerHTML = pin.chartSvg;
      chartTemp = tempDiv.querySelector("svg");
      if (chartTemp) {
        hasChart = true;
        var vb = chartTemp.getAttribute("viewBox");
        if (vb) {
          var parts = vb.split(" ").map(Number);
          var cScale = usableW / parts[2];
          chartH = parts[3] * cScale;
        }
      }
    }

    // 3. Table dimensions (full width)
    var tableTopY = chartTopY + chartH + (chartH > 0 ? 12 : 0);
    var tableH = 0;
    if (pin.tableHtml) {
      var countRows = (pin.tableHtml.match(/<tr/g) || []).length;
      tableH = countRows * 18 + 4;
    }

    var totalH = tableTopY + tableH + pad + 20;

    var svg = document.createElementNS(ns, "svg");
    svg.setAttribute("xmlns", ns);
    svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
    svg.setAttribute("style", "font-family:" + fontFamily + ";");

    var bg = document.createElementNS(ns, "rect");
    bg.setAttribute("width", W); bg.setAttribute("height", totalH);
    bg.setAttribute("fill", "#ffffff");
    svg.appendChild(bg);

    var titleResult = createWrappedText(ns, titleLines, pad, titleStartY, titleLineH,
      { fill: "#1a2744", "font-size": "16", "font-weight": "700" });
    svg.appendChild(titleResult.element);

    var metaEl = document.createElementNS(ns, "text");
    metaEl.setAttribute("x", pad); metaEl.setAttribute("y", metaY);
    metaEl.setAttribute("fill", "#94a3b8"); metaEl.setAttribute("font-size", "11");
    metaEl.textContent = metaText;
    svg.appendChild(metaEl);

    // Render stacked: insight → chart → table
    var isTextBox = pin.pinType === "text_box";

    // 1. Insight (first — the editorial takeaway)
    if (insightLines.length > 0) {
      var aH = Math.max(28, insightLines.length * insightLineH + 12);
      // Background fill for insight area
      var insBg = document.createElementNS(ns, "rect");
      insBg.setAttribute("x", pad); insBg.setAttribute("y", insightY + 2);
      insBg.setAttribute("width", usableW); insBg.setAttribute("height", aH);
      insBg.setAttribute("rx", "4");
      insBg.setAttribute("fill", isTextBox ? "#f8fafc" : "#f0f4ff");
      svg.appendChild(insBg);
      if (!isTextBox) {
        // Accent bar (only for standard crosstab insights)
        var iB = document.createElementNS(ns, "rect");
        iB.setAttribute("x", pad); iB.setAttribute("y", insightY + 2);
        iB.setAttribute("width", "4"); iB.setAttribute("height", aH);
        iB.setAttribute("fill", "#323367"); iB.setAttribute("rx", "2");
        svg.appendChild(iB);
      }
      var insFontSize = isTextBox ? "14" : "13";
      var insXOffset = isTextBox ? 12 : 14;
      var insRes = createWrappedText(ns, insightLines, pad + insXOffset, insightY + 18, insightLineH,
        { fill: "#1a2744", "font-size": insFontSize, "font-weight": isTextBox ? "400" : "500" });
      svg.appendChild(insRes.element);
    }

    // 2. Chart (full width — visual pattern)
    if (hasChart && chartTemp) {
      var chartClone = chartTemp.cloneNode(true);
      var cvb = chartClone.getAttribute("viewBox").split(" ").map(Number);
      var cScale2 = usableW / cvb[2];
      var cG = document.createElementNS(ns, "g");
      cG.setAttribute("transform", "translate(" + pad + "," + chartTopY + ") scale(" + cScale2 + ")");
      while (chartClone.firstChild) cG.appendChild(chartClone.firstChild);
      svg.appendChild(cG);
    }

    // 3. Table (full width — detailed reference)
    if (pin.tableHtml) {
      var tDiv = document.createElement("div");
      tDiv.innerHTML = pin.tableHtml;
      var tRows = extractSlideTableData({ querySelector: function(sel) { return tDiv.querySelector(sel); }, querySelectorAll: function(sel) { return tDiv.querySelectorAll(sel); } });
      if (tRows) {
        renderTableSVG(ns, svg, tRows, pad, tableTopY, usableW);
      }
    }

    // Serialise SVG to blob URL
    var svgData = new XMLSerializer().serializeToString(svg);
    var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
    var slideNum = String(idx + 1).padStart(2, "0");

    slides.push({
      url: URL.createObjectURL(svgBlob),
      num: slideNum,
      qCode: pin.qCode,
      height: totalH
    });
  });

  // Step 2: Download slides sequentially with delay to avoid browser blocking
  var downloaded = 0;
  var failed = 0;

  function downloadNext(i) {
    if (i >= slides.length) {
      if (failed > 0) {
        alert("Exported " + downloaded + " of " + slides.length + " slides. " + failed + " failed.");
      }
      return;
    }
    var s = slides[i];
    var sImg = new Image();
    sImg.onerror = function() {
      URL.revokeObjectURL(s.url);
      failed++;
      setTimeout(function() { downloadNext(i + 1); }, DOWNLOAD_DELAY_MS);
    };
    sImg.onload = function() {
      var canvas = document.createElement("canvas");
      canvas.width = W * scale; canvas.height = s.height * scale;
      var ctx = canvas.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(sImg, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(s.url);
      canvas.toBlob(function(blob) {
        downloadBlob(blob, "pin_" + s.num + "_" + s.qCode + "_slide.png");
        downloaded++;
        setTimeout(function() { downloadNext(i + 1); }, DOWNLOAD_DELAY_MS);
      }, "image/png");
    };
    sImg.src = s.url;
  }

  downloadNext(0);
}

// ---- Print Pinned Views to PDF ----
// Builds a temporary print layout with one pinned view per page,
// triggers window.print() (user can save to PDF), then restores DOM.
function printPinnedViews() {
  // Count actual pins (not sections)
  var pinCount = 0;
  for (var pc = 0; pc < pinnedViews.length; pc++) {
    if (pinnedViews[pc].type !== "section") pinCount++;
  }
  if (pinCount === 0) {
    alert("No pinned views to print. Pin questions from the Crosstabs tab first.");
    return;
  }

  // Create a print overlay container
  var overlay = document.createElement("div");
  overlay.id = "pinned-print-overlay";
  overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;background:white;overflow:auto;";

  // Add print-specific styles
  var printStyle = document.createElement("style");
  printStyle.id = "pinned-print-style";
  printStyle.textContent = "@page { size: A4 landscape; margin: 10mm 12mm; } " +
    "@media print { " +
    "body > *:not(#pinned-print-overlay) { display: none !important; } " +
    "#pinned-print-overlay { position: static !important; overflow: visible !important; } " +
    ".pinned-print-page { page-break-after: always; padding: 12px 0; box-sizing: border-box; } " +
    ".pinned-print-page:last-child { page-break-after: auto; } " +
    ".pinned-print-header { margin-bottom: 10px; } " +
    ".pinned-print-qcode { font-size: 13px; font-weight: 700; color: #323367; } " +
    ".pinned-print-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 2px 0; } " +
    ".pinned-print-meta { font-size: 11px; color: #64748b; } " +
    ".pinned-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid #323367; " +
    "  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; " +
    "  color: #1a2744; line-height: 1.5; " +
    "  -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
    ".pinned-print-chart { margin-bottom: 12px; } " +
    ".pinned-print-chart svg { width: 100%; height: auto; max-height: 300px; } " +
    ".pinned-print-table { overflow: visible; } " +
    ".pinned-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } " +
    ".pinned-print-table th, .pinned-print-table td { padding: 4px 8px; border: 1px solid #ddd; text-align: left; word-wrap: break-word; overflow-wrap: break-word; } " +
    ".pinned-print-table th { background: #f1f5f9; font-weight: 600; font-size: 12px; " +
    "  -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
    ".pinned-print-page-num { text-align: right; font-size: 9px; color: #94a3b8; margin-top: 4px; } " +
    ".pinned-print-project-strip { padding: 0 0 8px 0; margin-bottom: 12px; border-bottom: 2px solid #323367; " +
    "  page-break-after: avoid; page-break-inside: avoid; " +
    "  -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
    "} " +
    "@media screen { " +
    "#pinned-print-overlay .pinned-print-page { " +
    "  max-width: 900px; margin: 20px auto; padding: 32px; " +
    "  border: 1px solid #e2e8f0; border-radius: 8px; background: #fff; " +
    "  box-shadow: 0 1px 3px rgba(0,0,0,0.1); } " +
    ".pinned-print-insight { margin-bottom: 12px; padding: 10px 14px; border-left: 3px solid #323367; " +
    "  background: #f8f9fb; font-size: 12px; color: #374151; } " +
    ".pinned-print-chart { margin-bottom: 12px; } " +
    ".pinned-print-chart svg { width: 100%; height: auto; } " +
    ".pinned-print-table { overflow-x: auto; } " +
    ".pinned-print-table table { font-size: 10px; width: 100%; border-collapse: collapse; } " +
    ".pinned-print-table th, .pinned-print-table td { padding: 3px 6px; border: 1px solid #ddd; } " +
    ".pinned-print-table th { background: #f1f5f9; font-weight: 600; font-size: 9px; } " +
    ".pinned-print-project-strip { padding: 12px 32px 8px 32px; margin-bottom: 12px; border-bottom: 2px solid #323367; } " +
    "}";
  document.head.appendChild(printStyle);

  // Gather project header info from the main banner (same as Summary print)
  var projectTitle = document.querySelector(".header-title");
  var pTitle = projectTitle ? projectTitle.textContent : "Report";

  // Read stats badges from the header badge bar (n, Questions, Weighted/Unweighted, date)
  // Badge bar is the parent of #header-date-badge; its direct children alternate
  // between badge spans (with padding) and separator spans (1px wide, height:16px).
  var headerBadges = [];
  var dateBadge = document.getElementById("header-date-badge");
  if (dateBadge && dateBadge.parentNode) {
    var children = dateBadge.parentNode.children;
    for (var bi = 0; bi < children.length; bi++) {
      var sp = children[bi];
      // Skip separators (they have explicit height in inline style)
      if (sp.style.height) continue;
      var txt = sp.textContent.trim();
      if (txt) headerBadges.push(txt);
    }
  }
  var statsLine = headerBadges.join("  \u00B7  ");

  // Project info strip — appears ONCE at the top (matches Summary print header)
  var projStrip = document.createElement("div");
  projStrip.className = "pinned-print-project-strip";
  projStrip.innerHTML = "<div style=\"font-size:14px;font-weight:700;color:#323367;\">" + escapeHtml(pTitle) + "</div>" +
    (statsLine ? "<div style=\"font-size:10px;color:#64748b;margin-top:2px;\">" + escapeHtml(statsLine) + "</div>" : "");
  overlay.appendChild(projStrip);

  // Build one page per pinned view (sections become dividers)
  var printPinIdx = 0;
  pinnedViews.forEach(function(pin, idx) {
    // Render section dividers as heading strips (not full pages)
    if (pin.type === "section") {
      var sectionEl = document.createElement("div");
      sectionEl.style.cssText = "padding:16px 0 8px;margin:8px 0;border-bottom:2px solid #323367;font-size:16px;font-weight:600;color:#323367;";
      sectionEl.textContent = pin.title || "Untitled Section";
      overlay.appendChild(sectionEl);
      return;
    }
    printPinIdx++;

    var page = document.createElement("div");
    page.className = "pinned-print-page";

    // Header — adapt to pin type
    var hdr = document.createElement("div");
    hdr.className = "pinned-print-header";
    if (pin.pinType === "text_box" || pin.pinType === "heatmap") {
      // Simplified header for dashboard pins (no qCode/banner)
      hdr.innerHTML = "<div class=\"pinned-print-title\">" + escapeHtml(pin.qTitle) + "</div>";
    } else {
      hdr.innerHTML = "<div class=\"pinned-print-qcode\">" + escapeHtml(pin.qCode) + "</div>" +
        "<div class=\"pinned-print-title\">" + escapeHtml(pin.qTitle) + "</div>" +
        "<div class=\"pinned-print-meta\">Banner: " + escapeHtml(pin.bannerLabel) +
        (pin.baseText ? " \u00B7 Base: " + escapeHtml(pin.baseText) : "") + "</div>";
    }
    page.appendChild(hdr);

    // Content: stacked — insight, chart, table
    // Insight first (the "so what")
    if (pin.insightText) {
      var insDiv = document.createElement("div");
      insDiv.className = "pinned-print-insight";
      if (pin.pinType === "text_box") {
        insDiv.style.cssText = "font-size:13px;line-height:1.7;font-weight:400;font-style:normal;border-left:none;background:#f8fafc;padding:12px 16px;border-radius:6px;white-space:pre-wrap;";
      }
      insDiv.textContent = pin.insightText;
      page.appendChild(insDiv);
    }

    // Chart (visual pattern)
    if (pin.chartSvg) {
      var chartDiv = document.createElement("div");
      chartDiv.className = "pinned-print-chart";
      chartDiv.innerHTML = pin.chartSvg;
      page.appendChild(chartDiv);
    }

    // Table (detailed reference)
    if (pin.tableHtml) {
      var tableDiv = document.createElement("div");
      tableDiv.className = "pinned-print-table";
      tableDiv.innerHTML = pin.tableHtml;
      page.appendChild(tableDiv);
    }

    // Page number (count only pins, not section dividers)
    var pgNum = document.createElement("div");
    pgNum.className = "pinned-print-page-num";
    pgNum.textContent = printPinIdx + " of " + pinCount;
    page.appendChild(pgNum);

    overlay.appendChild(page);
  });

  document.body.appendChild(overlay);

  // Clean up function
  function cleanupPrintOverlay() {
    var ov = document.getElementById("pinned-print-overlay");
    if (ov) ov.remove();
    var ps = document.getElementById("pinned-print-style");
    if (ps) ps.remove();
  }

  // Listen for afterprint event (reliable in modern browsers)
  var cleaned = false;
  function onAfterPrint() {
    if (cleaned) return;
    cleaned = true;
    window.removeEventListener("afterprint", onAfterPrint);
    cleanupPrintOverlay();
  }
  window.addEventListener("afterprint", onAfterPrint);

  // Small delay to let browser render, then print
  setTimeout(function() {
    window.print();
    // Fallback cleanup if afterprint does not fire (some browsers)
    setTimeout(function() {
      if (!cleaned) {
        cleaned = true;
        cleanupPrintOverlay();
      }
    }, 2000);
  }, 300);
}

// ---- Dashboard Pin Functions (3B) ----

function pinDashboardText(boxId) {
  var editor = document.getElementById("dash-text-" + boxId);
  var text = editor ? editor.innerText.trim() : "";
  if (!text) { alert("Please enter text before pinning."); return; }

  var title = boxId === "background" ? "Background & Method" : "Executive Summary";
  var pin = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    pinType: "text_box",
    qCode: null,
    qTitle: title,
    bannerGroup: null,
    bannerLabel: null,
    selectedColumns: null,
    excludedRows: null,
    insightText: text,
    sortState: null,
    tableHtml: null,
    chartSvg: null,
    baseText: null,
    timestamp: Date.now(),
    order: pinnedViews.length
  };
  pinnedViews.push(pin);
  savePinnedData();
  renderPinnedCards();
  updatePinBadge();
}

/**
 * Pin a gauge section (Index, NPS Score, etc.) to Pinned Views.
 * Clones the gauge cards and heatmap grid from the section, strips controls,
 * and stores as a dashboard_section pin.
 * @param {string} sectionId - The section id suffix (e.g., "index", "nps-score")
 */
function pinGaugeSection(sectionId) {
  var section = document.getElementById("dash-sec-" + sectionId);
  if (!section) return;

  var gauges = section.querySelectorAll(".dash-gauge-card:not(.dash-gauge-excluded)");
  if (gauges.length === 0) return;

  // Get the section title
  var titleEl = section.querySelector(".dash-section-title");
  var sectionTitle = titleEl ? titleEl.childNodes[0].textContent.trim() : sectionId;

  // Clone the section content (gauges + heatmap)
  var clone = section.cloneNode(true);
  // Remove action buttons (pin, export, sort) from the clone
  clone.querySelectorAll(".dash-export-btn, .dash-sort-btn, .dash-slide-export-btn").forEach(function(btn) { btn.remove(); });
  // Remove tier badges from clone (already visible in the gauges)
  clone.querySelectorAll(".dash-tier-pill").forEach(function(pill) { pill.remove(); });
  // Remove excluded gauges
  clone.querySelectorAll(".dash-gauge-excluded").forEach(function(g) { g.remove(); });

  var pin = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    pinType: "dashboard_section",
    qCode: null,
    qTitle: sectionTitle,
    bannerGroup: null,
    bannerLabel: null,
    selectedColumns: null,
    excludedRows: null,
    insightText: null,
    sortState: null,
    tableHtml: clone.innerHTML,
    chartSvg: null,
    baseText: null,
    timestamp: Date.now(),
    order: pinnedViews.length
  };
  pinnedViews.push(pin);
  savePinnedData();
  renderPinnedCards();
  updatePinBadge();
}

/**
 * Pin the Significant Findings section to Pinned Views.
 * Clones the sig finding cards and stores as a dashboard_section pin.
 */
function pinSigFindings() {
  var section = document.getElementById("dash-sec-sig-findings");
  if (!section) return;

  var cards = section.querySelectorAll(".dash-sig-card");
  if (cards.length === 0) return;

  // Clone the section content
  var clone = section.cloneNode(true);
  // Remove action buttons from the clone
  clone.querySelectorAll(".dash-export-btn, .dash-slide-export-btn").forEach(function(btn) { btn.remove(); });

  var pin = {
    id: "pin-" + Date.now() + "-" + Math.random().toString(36).substr(2, 5),
    pinType: "dashboard_section",
    qCode: null,
    qTitle: "Significant Findings",
    bannerGroup: null,
    bannerLabel: null,
    selectedColumns: null,
    excludedRows: null,
    insightText: null,
    sortState: null,
    tableHtml: clone.innerHTML,
    chartSvg: null,
    baseText: null,
    timestamp: Date.now(),
    order: pinnedViews.length
  };
  pinnedViews.push(pin);
  savePinnedData();
  renderPinnedCards();
  updatePinBadge();
}

/**
 * Export the Significant Findings section as a PNG slide.
 * Reuses the exportDashboardSlide infrastructure but adapted for sig cards.
 */
function exportSigFindingsSlide() {
  var section = document.getElementById("dash-sec-sig-findings");
  if (!section) return;
  var cards = section.querySelectorAll(".dash-sig-card");
  if (cards.length === 0) { alert("No significant findings to export."); return; }

  // Read metadata
  var summaryPanel = document.getElementById("tab-summary");
  var projectTitle = summaryPanel ? (summaryPanel.getAttribute("data-project-title") || "") : "";
  var fieldwork = summaryPanel ? (summaryPanel.getAttribute("data-fieldwork") || "") : "";
  var companyName = summaryPanel ? (summaryPanel.getAttribute("data-company") || "") : "";
  var brandColour = summaryPanel ? (summaryPanel.getAttribute("data-brand-colour") || "#323367") : "#323367";

  var ns = "http://www.w3.org/2000/svg";
  var font = "-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif";
  var W = 1000, pad = 30;
  var headerH = 48, titleH = 30, footerH = 30;
  var cardH = 64, cardGap = 6;
  var maxPerSlide = 12;
  var totalCards = cards.length;
  var slideCount = Math.ceil(totalCards / maxPerSlide);

  for (var si = 0; si < slideCount; si++) {
    var startIdx = si * maxPerSlide;
    var endIdx = Math.min(startIdx + maxPerSlide, totalCards);
    var slideCards = Array.from(cards).slice(startIdx, endIdx);
    var gridH = slideCards.length * (cardH + cardGap);
    var totalH = headerH + pad + titleH + gridH + pad + footerH;

    var svg = document.createElementNS(ns, "svg");
    svg.setAttribute("xmlns", ns);
    svg.setAttribute("viewBox", "0 0 " + W + " " + totalH);
    svg.setAttribute("style", "font-family:" + font + ";");

    // White background
    var bg = document.createElementNS(ns, "rect");
    bg.setAttribute("width", W); bg.setAttribute("height", totalH);
    bg.setAttribute("fill", "#ffffff"); svg.appendChild(bg);

    // Brand header
    var hBar = document.createElementNS(ns, "rect");
    hBar.setAttribute("x", "0"); hBar.setAttribute("y", "0");
    hBar.setAttribute("width", W); hBar.setAttribute("height", headerH);
    hBar.setAttribute("fill", brandColour); svg.appendChild(hBar);

    if (projectTitle) {
      var ptEl = document.createElementNS(ns, "text");
      ptEl.setAttribute("x", pad); ptEl.setAttribute("y", headerH / 2 + 6);
      ptEl.setAttribute("fill", "#ffffff"); ptEl.setAttribute("font-size", "16");
      ptEl.setAttribute("font-weight", "700"); ptEl.textContent = projectTitle;
      svg.appendChild(ptEl);
    }
    var rightText = [fieldwork, companyName].filter(function(s) { return s; }).join("  \u00B7  ");
    if (rightText) {
      var rtEl = document.createElementNS(ns, "text");
      rtEl.setAttribute("x", W - pad); rtEl.setAttribute("y", headerH / 2 + 5);
      rtEl.setAttribute("text-anchor", "end"); rtEl.setAttribute("fill", "rgba(255,255,255,0.85)");
      rtEl.setAttribute("font-size", "11"); rtEl.setAttribute("font-weight", "500");
      rtEl.textContent = rightText; svg.appendChild(rtEl);
    }

    // Section title
    var secY = headerH + pad;
    var secTitle = document.createElementNS(ns, "text");
    secTitle.setAttribute("x", pad); secTitle.setAttribute("y", secY + 16);
    secTitle.setAttribute("fill", "#1a2744"); secTitle.setAttribute("font-size", "15");
    secTitle.setAttribute("font-weight", "700");
    secTitle.textContent = "Significant Findings" + (slideCount > 1 ? " (" + (si + 1) + "/" + slideCount + ")" : "");
    svg.appendChild(secTitle);

    // Finding cards
    var cardY = secY + titleH;
    slideCards.forEach(function(card) {
      var sigText = card.querySelector(".dash-sig-text");
      var badges = card.querySelectorAll(".dash-sig-metric-badge, .dash-sig-group-badge, .dash-sig-type-badge");
      var text = sigText ? sigText.textContent.trim() : "";

      // Card background
      var cardBg = document.createElementNS(ns, "rect");
      cardBg.setAttribute("x", pad); cardBg.setAttribute("y", cardY);
      cardBg.setAttribute("width", W - 2 * pad); cardBg.setAttribute("height", cardH);
      cardBg.setAttribute("rx", "6"); cardBg.setAttribute("fill", "#f0fdf4");
      cardBg.setAttribute("stroke", "#bbf7d0"); cardBg.setAttribute("stroke-width", "1");
      svg.appendChild(cardBg);

      // Badges
      var bx = pad + 10;
      badges.forEach(function(badge) {
        var bText = badge.textContent.trim();
        var bEl = document.createElementNS(ns, "text");
        bEl.setAttribute("x", bx); bEl.setAttribute("y", cardY + 18);
        bEl.setAttribute("fill", "#059669"); bEl.setAttribute("font-size", "9");
        bEl.setAttribute("font-weight", "700"); bEl.textContent = bText;
        svg.appendChild(bEl);
        bx += bText.length * 6 + 14;
      });

      // Finding text (truncate if too long)
      var dispText = text.length > 130 ? text.substring(0, 127) + "..." : text;
      var ftEl = document.createElementNS(ns, "text");
      ftEl.setAttribute("x", pad + 10); ftEl.setAttribute("y", cardY + 42);
      ftEl.setAttribute("fill", "#1e293b"); ftEl.setAttribute("font-size", "11");
      ftEl.textContent = dispText;
      svg.appendChild(ftEl);

      cardY += cardH + cardGap;
    });

    // Footer
    var footerY = totalH - footerH + 18;
    var footerEl = document.createElementNS(ns, "text");
    footerEl.setAttribute("x", W / 2); footerEl.setAttribute("y", footerY);
    footerEl.setAttribute("text-anchor", "middle"); footerEl.setAttribute("fill", "#94a3b8");
    footerEl.setAttribute("font-size", "9");
    footerEl.textContent = "Generated by Turas \u00B7 " + new Date().toLocaleDateString();
    svg.appendChild(footerEl);

    // Download
    var svgData = new XMLSerializer().serializeToString(svg);
    var canvas = document.createElement("canvas");
    canvas.width = W * 2; canvas.height = totalH * 2;
    var ctx = canvas.getContext("2d");
    var img = new Image();
    img.onload = function() {
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      var a = document.createElement("a");
      a.download = "sig_findings" + (slideCount > 1 ? "_" + (si + 1) : "") + ".png";
      a.href = canvas.toDataURL("image/png");
      a.click();
    };
    img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
  }
}

