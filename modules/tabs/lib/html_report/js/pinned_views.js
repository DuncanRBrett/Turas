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
  var idx = pinnedViews.findIndex(function(p) { return p.qCode === qCode && p.bannerGroup === currentGroup; });
  if (idx >= 0) {
    pinnedViews.splice(idx, 1);
    updatePinButton(qCode, false);
  } else {
    var pin = captureCurrentView(qCode);
    if (pin) {
      pinnedViews.push(pin);
      updatePinButton(qCode, true);
    }
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

  pinnedViews.forEach(function(pin, idx) {
    var card = document.createElement("div");
    card.className = "pinned-card";
    card.setAttribute("data-pin-id", pin.id);
    card.style.cssText = "background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:20px;margin-bottom:16px;";

    // Header with title, banner, base, controls
    var header = document.createElement("div");
    header.style.cssText = "display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:12px;";
    var titleDiv = document.createElement("div");
    titleDiv.innerHTML = "<div style=\"font-size:11px;color:#323367;font-weight:700;\">" + escapeHtml(pin.qCode) + "</div>" +
      "<div style=\"font-size:14px;font-weight:600;color:#1e293b;\">" + escapeHtml(pin.qTitle) + "</div>" +
      "<div style=\"font-size:11px;color:#94a3b8;margin-top:2px;\">Banner: " + escapeHtml(pin.bannerLabel) +
      (pin.baseText ? " \u00B7 Base: " + escapeHtml(pin.baseText) : "") + "</div>";
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
    var removeBtn = document.createElement("button");
    removeBtn.className = "export-btn";
    removeBtn.style.cssText = "padding:3px 8px;font-size:11px;color:#e8614d;";
    removeBtn.textContent = "\u2715";
    removeBtn.title = "Remove pin";
    removeBtn.onclick = function() { removePinned(pin.id, pin.qCode); };
    controls.appendChild(removeBtn);
    header.appendChild(controls);
    card.appendChild(header);

    // Content: table and chart side by side
    var content = document.createElement("div");
    content.style.cssText = "display:flex;gap:16px;align-items:flex-start;";

    if (pin.tableHtml) {
      var tableDiv = document.createElement("div");
      tableDiv.style.cssText = "flex:1;overflow-x:auto;font-size:11px;";
      tableDiv.innerHTML = pin.tableHtml;
      // Scale down table for compact display
      var tbl = tableDiv.querySelector("table");
      if (tbl) tbl.style.cssText = "font-size:10px;width:100%;";
      content.appendChild(tableDiv);
    }

    if (pin.chartSvg) {
      var chartDiv = document.createElement("div");
      chartDiv.style.cssText = "flex:1;";
      chartDiv.innerHTML = pin.chartSvg;
      content.appendChild(chartDiv);
    }
    card.appendChild(content);

    // Insight
    if (pin.insightText) {
      var insightDiv = document.createElement("div");
      insightDiv.style.cssText = "margin-top:12px;padding:10px 14px;border-left:3px solid #323367;background:#f8f9fb;border-radius:0 6px 6px 0;font-size:12px;color:#374151;font-style:italic;";
      insightDiv.textContent = pin.insightText;
      card.appendChild(insightDiv);
    }

    container.appendChild(card);
  });
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
  updatePinButton(qCode, pinnedViews.some(function(p) { return p.qCode === qCode; }));
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
      // Update pin buttons
      pinnedViews.forEach(function(pin) {
        updatePinButton(pin.qCode, true);
      });
    }
  } catch(e) {}
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
    var usableW = W - pad * 2;
    var titleFullText = pin.qCode + " - " + pin.qTitle;
    var titleLines = wrapTextLines(titleFullText, usableW, 9.5);
    var titleLineH = 20;
    var titleStartY = pad + 16;
    var titleBlockH = titleLines.length * titleLineH;
    var metaText = "Base: " + (pin.baseText || "\u2014") + " \u00B7 Banner: " + (pin.bannerLabel || "");
    var metaY = titleStartY + titleBlockH + 4;
    var contentTop = metaY + 18;

    // Parse chart SVG to get dimensions
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
          var cScale = (usableW * 0.5) / parts[2];
          chartH = parts[3] * cScale;
        }
      }
    }

    // Approximate table height
    var tableH = 0;
    if (pin.tableHtml) {
      var countRows = (pin.tableHtml.match(/<tr/g) || []).length;
      tableH = countRows * 18 + 4;
    }

    var contentH = Math.max(chartH, tableH, 100);

    // Insight
    var insightLines = wrapTextLines(pin.insightText, usableW - 16, 7);
    var insightLineH = 17;
    var insightY = contentTop + contentH + 16;
    var insightBlockH = insightLines.length > 0 ? insightLines.length * insightLineH + 10 : 0;
    var totalH = insightY + insightBlockH + pad;

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

    // Render table from stored HTML
    if (pin.tableHtml) {
      var tDiv = document.createElement("div");
      tDiv.innerHTML = pin.tableHtml;
      var tRows = extractSlideTableData({ querySelector: function(sel) { return tDiv.querySelector(sel); }, querySelectorAll: function(sel) { return tDiv.querySelectorAll(sel); } });
      if (tRows) {
        var tableW = hasChart ? usableW * 0.48 : usableW;
        renderTableSVG(ns, svg, tRows, pad, contentTop, tableW);
      }
    }

    // Embed chart
    if (hasChart && chartTemp) {
      var chartClone = chartTemp.cloneNode(true);
      var cvb = chartClone.getAttribute("viewBox").split(" ").map(Number);
      var chartAreaW = pin.tableHtml ? usableW * 0.5 : usableW;
      var chartX = pin.tableHtml ? pad + usableW * 0.5 + 8 : pad;
      var cScale2 = chartAreaW / cvb[2];
      var cG = document.createElementNS(ns, "g");
      cG.setAttribute("transform", "translate(" + chartX + "," + contentTop + ") scale(" + cScale2 + ")");
      while (chartClone.firstChild) cG.appendChild(chartClone.firstChild);
      svg.appendChild(cG);
    }

    // Insight
    if (insightLines.length > 0) {
      var iL = document.createElementNS(ns, "line");
      iL.setAttribute("x1", pad); iL.setAttribute("x2", W - pad);
      iL.setAttribute("y1", insightY); iL.setAttribute("y2", insightY);
      iL.setAttribute("stroke", "#e2e8f0"); iL.setAttribute("stroke-width", "1");
      svg.appendChild(iL);
      var aH = Math.max(24, insightLines.length * insightLineH);
      var iB = document.createElementNS(ns, "rect");
      iB.setAttribute("x", pad); iB.setAttribute("y", insightY + 4);
      iB.setAttribute("width", "3"); iB.setAttribute("height", aH);
      iB.setAttribute("fill", "#323367"); iB.setAttribute("rx", "1.5");
      svg.appendChild(iB);
      var insRes = createWrappedText(ns, insightLines, pad + 12, insightY + 18, insightLineH,
        { fill: "#374151", "font-size": "12", "font-style": "italic" });
      svg.appendChild(insRes.element);
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
  if (pinnedViews.length === 0) {
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
  printStyle.textContent = "@media print { " +
    "body > *:not(#pinned-print-overlay) { display: none !important; } " +
    "#pinned-print-overlay { position: static !important; overflow: visible !important; } " +
    ".pinned-print-page { page-break-after: always; padding: 20px 32px; box-sizing: border-box; } " +
    ".pinned-print-page:last-child { page-break-after: auto; } " +
    ".pinned-print-header { margin-bottom: 16px; } " +
    ".pinned-print-qcode { font-size: 12px; font-weight: 700; color: #323367; } " +
    ".pinned-print-title { font-size: 16px; font-weight: 600; color: #1e293b; margin: 2px 0; } " +
    ".pinned-print-meta { font-size: 11px; color: #64748b; } " +
    ".pinned-print-content { display: flex; gap: 20px; align-items: flex-start; margin-top: 12px; } " +
    ".pinned-print-table { flex: 1; overflow: visible; font-size: 11px; } " +
    ".pinned-print-table table { width: 100%; border-collapse: collapse; font-size: 10px; } " +
    ".pinned-print-table th, .pinned-print-table td { padding: 3px 6px; border: 1px solid #ddd; text-align: left; } " +
    ".pinned-print-table th { background: #f1f5f9; font-weight: 600; font-size: 9px; } " +
    ".pinned-print-chart { flex: 1; } " +
    ".pinned-print-chart svg { width: 100%; height: auto; } " +
    ".pinned-print-insight { margin-top: 12px; padding: 10px 14px; border-left: 3px solid #323367; " +
    "  background: #f8f9fb; border-radius: 0 6px 6px 0; font-size: 12px; color: #374151; font-style: italic; } " +
    ".pinned-print-page-num { text-align: right; font-size: 9px; color: #94a3b8; margin-top: 8px; } " +
    "} " +
    "@media screen { " +
    "#pinned-print-overlay .pinned-print-page { " +
    "  max-width: 900px; margin: 20px auto; padding: 32px; " +
    "  border: 1px solid #e2e8f0; border-radius: 8px; background: #fff; " +
    "  box-shadow: 0 1px 3px rgba(0,0,0,0.1); } " +
    ".pinned-print-content { display: flex; gap: 20px; } " +
    ".pinned-print-table { flex: 1; overflow-x: auto; } " +
    ".pinned-print-table table { font-size: 10px; width: 100%; border-collapse: collapse; } " +
    ".pinned-print-table th, .pinned-print-table td { padding: 3px 6px; border: 1px solid #ddd; } " +
    ".pinned-print-table th { background: #f1f5f9; font-weight: 600; font-size: 9px; } " +
    ".pinned-print-chart { flex: 1; } " +
    ".pinned-print-chart svg { width: 100%; height: auto; } " +
    ".pinned-print-insight { margin-top: 12px; padding: 10px 14px; border-left: 3px solid #323367; " +
    "  background: #f8f9fb; font-size: 12px; color: #374151; font-style: italic; } " +
    "}";
  document.head.appendChild(printStyle);

  // Get project title for header
  var projectTitle = document.querySelector(".header-title");
  var pTitle = projectTitle ? projectTitle.textContent : "Report";

  // Build one page per pinned view
  pinnedViews.forEach(function(pin, idx) {
    var page = document.createElement("div");
    page.className = "pinned-print-page";

    // Header
    var hdr = document.createElement("div");
    hdr.className = "pinned-print-header";
    hdr.innerHTML = "<div class=\"pinned-print-qcode\">" + escapeHtml(pin.qCode) + "</div>" +
      "<div class=\"pinned-print-title\">" + escapeHtml(pin.qTitle) + "</div>" +
      "<div class=\"pinned-print-meta\">Banner: " + escapeHtml(pin.bannerLabel) +
      (pin.baseText ? " \u00B7 Base: " + escapeHtml(pin.baseText) : "") +
      " \u00B7 " + escapeHtml(pTitle) + "</div>";
    page.appendChild(hdr);

    // Content: table + chart
    var content = document.createElement("div");
    content.className = "pinned-print-content";

    if (pin.tableHtml) {
      var tableDiv = document.createElement("div");
      tableDiv.className = "pinned-print-table";
      tableDiv.innerHTML = pin.tableHtml;
      content.appendChild(tableDiv);
    }

    if (pin.chartSvg) {
      var chartDiv = document.createElement("div");
      chartDiv.className = "pinned-print-chart";
      chartDiv.innerHTML = pin.chartSvg;
      content.appendChild(chartDiv);
    }
    page.appendChild(content);

    // Insight
    if (pin.insightText) {
      var insDiv = document.createElement("div");
      insDiv.className = "pinned-print-insight";
      insDiv.textContent = pin.insightText;
      page.appendChild(insDiv);
    }

    // Page number
    var pgNum = document.createElement("div");
    pgNum.className = "pinned-print-page-num";
    pgNum.textContent = (idx + 1) + " of " + pinnedViews.length;
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
