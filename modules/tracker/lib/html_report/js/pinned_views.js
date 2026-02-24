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
  var existingIdx = -1;
  for (var i = 0; i < pinnedViews.length; i++) {
    if (pinnedViews[i].metricId === metricId) {
      existingIdx = i;
      break;
    }
  }

  if (existingIdx >= 0) {
    // Unpin
    pinnedViews.splice(existingIdx, 1);
    updatePinButton(metricId, false);
  } else {
    // Pin — capture current view
    var pinObj = captureMetricView(metricId);
    if (pinObj) {
      pinnedViews.push(pinObj);
      updatePinButton(metricId, true);
    }
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
    pngDataUrl: null,
    timestamp: Date.now(),
    order: pinnedViews.length
  };

  // Attempt PNG capture via foreignObject SVG → canvas
  capturePinAsPng(panel, pinObj);

  return pinObj;
}


/**
 * Capture a DOM element as a PNG data URL using foreignObject SVG → canvas.
 * Stores the result in pinObj.pngDataUrl asynchronously. The pinned card
 * will re-render once the PNG is available.
 * @param {HTMLElement} sourceEl - The DOM element to capture
 * @param {Object} pinObj - The pin object to update with pngDataUrl
 */
function capturePinAsPng(sourceEl, pinObj) {
  if (!sourceEl) return;

  var w = sourceEl.offsetWidth || 800;
  var h = sourceEl.offsetHeight || 400;
  var scale = 2;

  // Clone and inline styles
  var clone = sourceEl.cloneNode(true);

  // Remove controls, buttons, etc from the clone
  clone.querySelectorAll(".mv-controls, .mv-segment-chips, .mv-wave-chips, .insight-area, .mv-segment-grouped").forEach(function(el) {
    el.parentNode.removeChild(el);
  });
  clone.querySelectorAll("button").forEach(function(el) {
    el.parentNode.removeChild(el);
  });

  inlineStyles(clone);

  var svgNs = "http://www.w3.org/2000/svg";
  var svg = document.createElementNS(svgNs, "svg");
  svg.setAttribute("width", w);
  svg.setAttribute("height", h);
  svg.setAttribute("xmlns", svgNs);

  var foreignObject = document.createElementNS(svgNs, "foreignObject");
  foreignObject.setAttribute("width", "100%");
  foreignObject.setAttribute("height", "100%");

  var body = document.createElement("div");
  body.setAttribute("xmlns", "http://www.w3.org/1999/xhtml");
  body.style.width = w + "px";
  body.style.fontFamily = "-apple-system, BlinkMacSystemFont, sans-serif";
  body.style.fontSize = "13px";
  body.style.background = "#ffffff";
  body.appendChild(clone);
  foreignObject.appendChild(body);
  svg.appendChild(foreignObject);

  var svgData = new XMLSerializer().serializeToString(svg);
  var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
  var svgUrl = URL.createObjectURL(svgBlob);

  var img = new Image();
  img.onload = function() {
    var canvas = document.createElement("canvas");
    canvas.width = w * scale;
    canvas.height = h * scale;
    var ctx = canvas.getContext("2d");
    ctx.scale(scale, scale);
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, w, h);
    ctx.drawImage(img, 0, 0, w, h);

    try {
      pinObj.pngDataUrl = canvas.toDataURL("image/png");
      // Re-render pinned cards to show PNG
      renderPinnedCards();
    } catch (e) {
      // Security/tainted canvas — fallback to HTML rendering
    }

    URL.revokeObjectURL(svgUrl);
  };
  img.onerror = function() {
    URL.revokeObjectURL(svgUrl);
  };
  img.src = svgUrl;
}

/**
 * Update pin button visual state
 * @param {string} metricId - The metric ID
 * @param {boolean} isPinned - Whether it's pinned
 */
function updatePinButton(metricId, isPinned) {
  var panel = document.getElementById("mv-" + metricId);
  if (!panel) return;

  var btn = panel.querySelector(".mv-pin-btn");
  if (btn) {
    btn.classList.toggle("pinned", isPinned);
    btn.title = isPinned ? "Unpin this view" : "Pin this view";
  }
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

    // PNG snapshot (hidden – kept for export only, not displayed on screen)
    if (pin.pngDataUrl) {
      html += "<div class=\"pinned-card-png-store\" style=\"display:none\"><img class=\"pinned-card-png\" src=\"" + pin.pngDataUrl + "\" alt=\"" + escapeHtml(pin.metricTitle) + "\"></div>";
    }

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
  updatePinButton(metricId, false);
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
      // Update pin buttons
      for (var i = 0; i < pinnedViews.length; i++) {
        updatePinButton(pinnedViews[i].metricId, true);
      }
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
// Export Functions
// ==============================================================================

/**
 * Export a single pinned card as PNG using SVG foreignObject approach.
 * @param {string} pinId - The pin ID
 */
function exportPinnedCardPNG(pinId) {
  // Shortcut: if the pin has a pre-captured PNG data URL, download it directly
  for (var p = 0; p < pinnedViews.length; p++) {
    if (pinnedViews[p].id === pinId && pinnedViews[p].pngDataUrl) {
      downloadDataUrlAsPng(pinnedViews[p].pngDataUrl, "pinned_" + pinId + ".png");
      return;
    }
  }

  var card = document.querySelector('.pinned-card[data-pin-id="' + pinId + '"]');
  if (!card) return;

  // Also check for a PNG image in the card itself
  var pngImg = card.querySelector(".pinned-card-png");
  if (pngImg && pngImg.src && pngImg.src.indexOf("data:") === 0) {
    downloadDataUrlAsPng(pngImg.src, "pinned_" + pinId + ".png");
    return;
  }

  var clone = card.cloneNode(true);

  // Remove action buttons from clone
  var actions = clone.querySelector(".pinned-card-actions");
  if (actions) actions.parentNode.removeChild(actions);

  // Strip contenteditable attrs and clean for SVG export
  cleanCloneForExport(clone);

  // Convert embedded SVGs to data URL images — foreignObject cannot
  // reliably render nested SVGs due to XML namespace conflicts
  clone.querySelectorAll("svg").forEach(function(svg) {
    try {
      var svgStr = new XMLSerializer().serializeToString(svg);
      var encoded = "data:image/svg+xml;base64," +
        btoa(unescape(encodeURIComponent(svgStr)));
      var imgEl = document.createElement("img");
      imgEl.src = encoded;
      imgEl.style.cssText = "width:100%;height:auto;display:block;";
      svg.parentNode.replaceChild(imgEl, svg);
    } catch (e) {
      if (svg.parentNode) svg.parentNode.removeChild(svg);
    }
  });

  // Inline critical styles
  inlineStyles(clone);

  var cardWidth = card.offsetWidth || 800;
  var cardHeight = card.offsetHeight || 600;
  var scale = 3;

  // Build SVG with foreignObject (sanitize HTML for XHTML compliance)
  var svgNS = "http://www.w3.org/2000/svg";
  var htmlContent = sanitizeForSvg(clone.outerHTML);
  var svgStr = '<svg xmlns="' + svgNS + '" width="' + (cardWidth * scale) + '" height="' + (cardHeight * scale) + '">';
  svgStr += '<foreignObject width="' + cardWidth + '" height="' + cardHeight + '" transform="scale(' + scale + ')">';
  svgStr += '<div xmlns="http://www.w3.org/1999/xhtml" style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;font-size:14px;color:#2c2c2c;background:#fff;">';
  svgStr += htmlContent;
  svgStr += '</div></foreignObject></svg>';

  var svgBlob = new Blob([svgStr], { type: "image/svg+xml;charset=utf-8" });
  var svgUrl = URL.createObjectURL(svgBlob);

  var canvas = document.createElement("canvas");
  canvas.width = cardWidth * scale;
  canvas.height = cardHeight * scale;
  var ctx = canvas.getContext("2d");

  var img = new Image();
  img.onload = function() {
    ctx.drawImage(img, 0, 0);
    canvas.toBlob(function(blob) {
      if (!blob) return;
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "pinned_" + pinId + ".png";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }, "image/png");
    URL.revokeObjectURL(svgUrl);
  };
  img.onerror = function() {
    URL.revokeObjectURL(svgUrl);
    exportPinnedCardFallback(card, pinId);
  };
  img.src = svgUrl;
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
 * Fallback PNG export — renders card content on a canvas.
 * Extracts real data (title, insight, table rows) for a useful export.
 */
function exportPinnedCardFallback(card, pinId) {
  var titleEl = card.querySelector(".pinned-card-title");
  var titleText = titleEl ? titleEl.textContent : "Pinned View";
  var insightEl = card.querySelector(".pinned-card-insight-editor, .insight-editor");
  var insightText = insightEl ? insightEl.textContent.trim() : "";

  // Extract table data from the card
  var tableRows = extractTableFromCard(card);

  var scale = 3;
  var w = 800;
  var brandColour = getComputedStyle(document.documentElement).getPropertyValue("--brand").trim() || "#323367";
  var headerH = 56;
  var insightH = insightText ? Math.ceil(insightText.length / 90) * 18 + 28 : 0;
  var tableH = tableRows ? (tableRows.length * 22 + 12) : 0;
  var h = Math.max(headerH + insightH + tableH + 40, 200);

  var canvas = document.createElement("canvas");
  canvas.width = w * scale;
  canvas.height = h * scale;
  var ctx = canvas.getContext("2d");
  ctx.scale(scale, scale);

  // Background
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, w, h);

  // Header bar
  ctx.fillStyle = brandColour;
  ctx.fillRect(0, 0, w, 50);
  ctx.fillStyle = "#fff";
  ctx.font = "bold 18px -apple-system, sans-serif";
  ctx.textAlign = "left";
  ctx.fillText(titleText, 16, 34);

  var y = headerH;

  // Insight
  if (insightText) {
    ctx.fillStyle = "#f0f4ff";
    ctx.fillRect(16, y, w - 32, insightH - 4);
    ctx.fillStyle = brandColour;
    ctx.fillRect(16, y, 4, insightH - 4);
    ctx.fillStyle = "#1a2744";
    ctx.font = "13px -apple-system, sans-serif";
    y = wrapCanvasTextTracker(ctx, insightText, 28, y + 16, w - 60, 18);
    y += 12;
  }

  // Table data
  if (tableRows && tableRows.length > 0) {
    y = renderCanvasTableTracker(ctx, tableRows, 16, y, w - 32);
  }

  canvas.toBlob(function(blob) {
    if (!blob) return;
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "pinned_" + pinId + ".png";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
  }, "image/png");
}

/**
 * Extract table rows from a card DOM element for canvas rendering.
 */
function extractTableFromCard(card) {
  var table = card.querySelector("table");
  if (!table) return null;
  var rows = [];
  table.querySelectorAll("tr").forEach(function(tr) {
    if (tr.style.display === "none") return;
    if (tr.classList.contains("segment-hidden")) return;
    var cells = [];
    tr.querySelectorAll("th, td").forEach(function(cell) {
      if (cell.style.display === "none") return;
      if (cell.classList.contains("segment-hidden")) return;
      cells.push(cell.textContent.trim());
    });
    if (cells.length > 0) rows.push(cells);
  });
  return rows.length > 0 ? rows : null;
}

/**
 * Wrap text on a canvas, returning the final Y position.
 */
function wrapCanvasTextTracker(ctx, text, x, y, maxW, lineH) {
  var words = text.split(" ");
  var line = "";
  var curY = y;
  for (var i = 0; i < words.length; i++) {
    var test = line + words[i] + " ";
    if (ctx.measureText(test).width > maxW && line !== "") {
      ctx.fillText(line.trim(), x, curY);
      line = words[i] + " ";
      curY += lineH;
    } else {
      line = test;
    }
  }
  if (line.trim()) {
    ctx.fillText(line.trim(), x, curY);
    curY += lineH;
  }
  return curY;
}

/**
 * Render table rows on a canvas at the given position.
 */
function renderCanvasTableTracker(ctx, rows, x, y, maxW) {
  if (!rows || rows.length === 0) return y;
  var colCount = 1;
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].length > colCount) colCount = rows[i].length;
  }
  var colW = maxW / colCount;
  var rowH = 22;

  for (var r = 0; r < rows.length; r++) {
    var rowY = y + r * rowH;
    if (r === 0) {
      ctx.fillStyle = "#f1f5f9";
      ctx.fillRect(x, rowY, maxW, rowH);
      ctx.fillStyle = "#1e293b";
      ctx.font = "bold 11px -apple-system, sans-serif";
    } else {
      if (r % 2 === 0) {
        ctx.fillStyle = "#f8fafc";
        ctx.fillRect(x, rowY, maxW, rowH);
      }
      ctx.fillStyle = "#1e293b";
      ctx.font = "12px -apple-system, sans-serif";
    }

    for (var c = 0; c < rows[r].length; c++) {
      var cellX = x + c * colW;
      var text = rows[r][c];
      if (text.length > 25) text = text.substring(0, 23) + "\u2026";
      if (c === 0) {
        ctx.textAlign = "left";
        ctx.fillText(text, cellX + 4, rowY + 15);
      } else {
        ctx.textAlign = "center";
        ctx.fillText(text, cellX + colW / 2, rowY + 15);
      }
    }

    ctx.strokeStyle = "#e2e8f0";
    ctx.lineWidth = 0.5;
    ctx.beginPath();
    ctx.moveTo(x, rowY + rowH);
    ctx.lineTo(x + maxW, rowY + rowH);
    ctx.stroke();
  }
  ctx.textAlign = "left";
  return y + rows.length * rowH;
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
 * Export a summary section as a slide PNG.
 * @param {string} sectionType - "background" or "findings"
 */
function exportSummarySlide(sectionType) {
  var sectionId = sectionType === "background"
    ? "summary-section-background"
    : "summary-section-findings";
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
