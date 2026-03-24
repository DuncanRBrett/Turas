/**
 * Turas Hub App — Pin Board
 *
 * Central pin curation view. Collects pins from report iframes via
 * the bridge (MutationObserver on pinned-views-data stores), displays
 * them in a scrollable board with source badges, editable insights,
 * section dividers, and drag-and-drop reordering.
 *
 * Adapted from hub_pinned.js for the Hub App context:
 *   - Persistence via HubState (IndexedDB + sidecar) instead of DOM store
 *   - SVG compression identical to report hub
 *   - Markdown insight editing with live preview
 *
 * Public API:
 *   PinBoard.addPin(source, pinObj)  — Add a pin from a report
 *   PinBoard.addSection(title)       — Add a section divider
 *   PinBoard.render()                — Re-render the board
 *   PinBoard.hydrate(items)          — Load items from persistence
 *   PinBoard.getItems()              — Get current ordered items
 *   PinBoard.getPinCount()           — Number of pins (not sections)
 */

var PinBoard = (function() {
  "use strict";

  // ---- Configuration ----
  var SVG_COMPRESS_DIGITS = 3;

  // ---- State ----
  var items = [];          // Ordered array of pin and section objects
  var dragSrcIdx = null;   // Index of item being dragged

  // ===========================================================================
  // Pin Management
  // ===========================================================================

  /**
   * Add a pin from a source report.
   * @param {string} source - Report key (e.g., "tracker", "tabs")
   * @param {object} pinObj - Pin data from the source report
   */
  function addPin(source, pinObj) {
    pinObj.source = source;
    pinObj.type = "pin";

    if (!pinObj.id) {
      pinObj.id = "pin-" + Date.now() + "-" + randomId();
    }
    pinObj.timestamp = pinObj.timestamp || Date.now();

    // Compress SVG to reduce storage
    if (pinObj.chartSvg) {
      pinObj.chartSvg = compressSvg(pinObj.chartSvg);
    }

    // Strip pngDataUrl — hub regenerates PNGs from SVG at export time
    delete pinObj.pngDataUrl;

    items.push(pinObj);
    render();
    updateBadge();
    persist();

    // Toast feedback
    var label = pinObj.sourceLabel || source || "Report";
    var title = pinObj.title || "View";
    HubApp.showToast("Pinned: " + title + " (" + label + ")");

    // Capture table as PNG for full CSS fidelity (async)
    if (pinObj.tableHtml && !pinObj.tablePng) {
      captureTablePng(pinObj.id, pinObj.tableHtml, source);
    }
  }

  /**
   * Add a section divider.
   * @param {string} [title] - Section title
   */
  function addSection(title) {
    title = title || "New Section";
    items.push({
      type: "section",
      title: title,
      id: "sec-" + Date.now() + "-" + randomId()
    });
    render();
    persist();
  }

  /**
   * Remove an item (pin or section) by ID.
   * @param {string} itemId
   */
  function removeItem(itemId) {
    var idx = findIndex(itemId);
    if (idx === -1) return;

    items.splice(idx, 1);
    render();
    updateBadge();
    persist();
  }

  /**
   * Move an item by ID in a given direction.
   * @param {string} itemId
   * @param {number} direction - -1 for up, +1 for down
   */
  function moveItem(itemId, direction) {
    var fromIdx = findIndex(itemId);
    if (fromIdx === -1) return;

    var toIdx = fromIdx + direction;
    if (toIdx < 0 || toIdx >= items.length) return;

    var item = items.splice(fromIdx, 1)[0];
    items.splice(toIdx, 0, item);
    render();
    persist();
  }

  /**
   * Update a section's title.
   * @param {string} sectionId
   * @param {string} newTitle
   */
  function updateSectionTitle(sectionId, newTitle) {
    var idx = findIndex(sectionId);
    if (idx === -1 || items[idx].type !== "section") return;

    items[idx].title = (newTitle || "").trim() || "Untitled Section";
    persist();
  }

  /**
   * Toggle insight into edit mode.
   * @param {string} pinId
   */
  function toggleInsightEdit(pinId) {
    var container = document.querySelector('.pb-insight[data-pin-id="' + pinId + '"]');
    if (!container) return;

    var rendered = container.querySelector(".pb-insight-rendered");
    var editor = container.querySelector(".pb-insight-editor");
    if (!rendered || !editor) return;

    rendered.style.display = "none";
    editor.style.display = "";
    editor.focus();
  }

  /**
   * Finish insight editing: re-render markdown, save.
   * @param {string} pinId
   */
  function finishInsightEdit(pinId) {
    var container = document.querySelector('.pb-insight[data-pin-id="' + pinId + '"]');
    if (!container) return;

    var rendered = container.querySelector(".pb-insight-rendered");
    var editor = container.querySelector(".pb-insight-editor");
    if (!rendered || !editor) return;

    var md = editor.value.trim();
    rendered.innerHTML = md ? renderMarkdown(md) : "";
    rendered.style.display = "";
    editor.style.display = "none";

    // Save markdown source
    var idx = findIndex(pinId);
    if (idx !== -1) {
      items[idx].insight = md;
      persist();
    }
  }

  // ===========================================================================
  // Hydration
  // ===========================================================================

  /**
   * Hydrate the board from loaded data (IndexedDB cache or sidecar).
   * @param {Array} loadedItems - Ordered items array
   */
  function hydrate(loadedItems) {
    if (!Array.isArray(loadedItems)) return;

    // Validate items
    var valid = [];
    for (var i = 0; i < loadedItems.length; i++) {
      var item = loadedItems[i];
      if (!item || typeof item !== "object") continue;
      if (!item.type || !item.id) continue;
      if (item.type !== "pin" && item.type !== "section") continue;
      // Strip legacy pngDataUrl
      if (item.pngDataUrl) delete item.pngDataUrl;
      valid.push(item);
    }

    if (valid.length > 0) {
      items = valid;
      render();
      updateBadge();
    }
  }

  // ===========================================================================
  // Rendering
  // ===========================================================================

  /**
   * Render the full pin board.
   */
  function render() {
    var container = document.getElementById("pb-cards");
    var emptyState = document.getElementById("pb-empty");
    var toolbar = document.getElementById("pb-toolbar");

    if (!container) return;

    var pinCount = getPinCount();

    if (pinCount === 0 && items.length === 0) {
      container.innerHTML = "";
      if (emptyState) emptyState.style.display = "";
      if (toolbar) toolbar.style.display = "none";
      return;
    }

    if (emptyState) emptyState.style.display = "none";
    if (toolbar) toolbar.style.display = "";

    var html = "";
    for (var i = 0; i < items.length; i++) {
      var item = items[i];
      if (item.type === "section") {
        html += buildSectionHTML(item, i);
      } else if (item.type === "pin") {
        html += buildPinCardHTML(item, i);
      }
    }

    container.innerHTML = html;

    // Attach drag-and-drop listeners
    attachDragListeners();
  }

  /**
   * Build HTML for a section divider.
   */
  function buildSectionHTML(section, idx) {
    var total = items.length;
    var sid = escapeAttr(section.id);

    return '<div class="pb-section-divider" draggable="true" data-idx="' + idx + '" data-item-id="' + sid + '">' +
      '<div class="pb-section-title" contenteditable="true" ' +
        'onpaste="event.preventDefault();document.execCommand(\'insertText\',false,event.clipboardData.getData(\'text/plain\'))" ' +
        'onblur="PinBoard.updateSectionTitle(\'' + sid + '\', this.textContent)">' +
        escapeHtml(section.title) + '</div>' +
      '<div class="pb-item-actions">' +
        (idx > 0 ? '<button class="pb-action-btn" onclick="PinBoard.moveItem(\'' + sid + '\',-1)" title="Move up">' + svgArrowUp() + '</button>' : '') +
        (idx < total - 1 ? '<button class="pb-action-btn" onclick="PinBoard.moveItem(\'' + sid + '\',1)" title="Move down">' + svgArrowDown() + '</button>' : '') +
        '<button class="pb-action-btn pb-remove-btn" onclick="PinBoard.removeItem(\'' + sid + '\')" title="Remove section">' + svgClose() + '</button>' +
      '</div>' +
    '</div>';
  }

  /**
   * Build HTML for a pin card.
   */
  function buildPinCardHTML(pin, idx) {
    var total = items.length;
    var pid = escapeAttr(pin.id);

    // Source badge
    var badgeLabel = pin.sourceLabel || "";
    var badgeClass = "pb-badge-default";
    var sourceType = pin.sourceType || pin.source || "";
    var badgeMap = {
      tracker:    { cls: "pb-badge-tracker",    label: "Tracker" },
      tabs:       { cls: "pb-badge-tabs",       label: "Crosstabs" },
      confidence: { cls: "pb-badge-confidence", label: "Confidence" },
      conjoint:   { cls: "pb-badge-conjoint",   label: "Conjoint" },
      maxdiff:    { cls: "pb-badge-maxdiff",    label: "MaxDiff" },
      pricing:    { cls: "pb-badge-pricing",    label: "Pricing" },
      segment:    { cls: "pb-badge-segment",    label: "Segmentation" },
      catdriver:  { cls: "pb-badge-catdriver",  label: "Cat Driver" },
      keydriver:  { cls: "pb-badge-keydriver",  label: "Key Driver" },
      weighting:  { cls: "pb-badge-weighting",  label: "Weighting" }
    };
    if (badgeMap[sourceType]) {
      badgeClass = badgeMap[sourceType].cls;
      if (!badgeLabel) badgeLabel = badgeMap[sourceType].label;
    } else {
      if (!badgeLabel) badgeLabel = sourceType || "Report";
    }

    var title = pin.title || pin.metricLabel || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || "";

    var html = '<div class="pb-pin-card" draggable="true" data-pin-id="' + pid + '" data-idx="' + idx + '" data-item-id="' + pid + '">' +
      '<div class="pb-pin-header">' +
        '<span class="pb-source-badge ' + badgeClass + '">' + escapeHtml(badgeLabel) + '</span>' +
        '<span class="pb-pin-title">' + escapeHtml(title) + '</span>' +
        '<div class="pb-item-actions">' +
          (pin.chartSvg ? '<button class="pb-action-btn" onclick="ExportManager.exportPinAsPng(\'' + pid + '\')" title="Export as PNG">' + svgDownload() + '</button>' : '') +
          (idx > 0 ? '<button class="pb-action-btn" onclick="PinBoard.moveItem(\'' + pid + '\',-1)" title="Move up">' + svgArrowUp() + '</button>' : '') +
          (idx < total - 1 ? '<button class="pb-action-btn" onclick="PinBoard.moveItem(\'' + pid + '\',1)" title="Move down">' + svgArrowDown() + '</button>' : '') +
          '<button class="pb-action-btn pb-remove-btn" onclick="PinBoard.removeItem(\'' + pid + '\')" title="Remove pin">' + svgClose() + '</button>' +
        '</div>' +
      '</div>';

    if (subtitle) {
      html += '<div class="pb-pin-subtitle">' + escapeHtml(subtitle) + '</div>';
    }

    // Insight (markdown editable)
    var insightRaw = pin.insight || pin.insightText || "";
    var renderedHtml = "";
    var editorText = "";
    if (insightRaw) {
      if (containsHtml(insightRaw)) {
        renderedHtml = sanitizeHtml(insightRaw);
        var tmp = document.createElement("div");
        tmp.innerHTML = renderedHtml;
        editorText = tmp.textContent.trim();
      } else {
        editorText = insightRaw;
        renderedHtml = renderMarkdown(insightRaw);
      }
    }

    html += '<div class="pb-insight" data-pin-id="' + pid + '">' +
      '<div class="pb-insight-rendered pb-md-content" ' +
        'ondblclick="PinBoard.toggleInsightEdit(\'' + pid + '\')" ' +
        'data-placeholder="Double-click to add insight...">' +
        (renderedHtml || '') +
      '</div>' +
      '<textarea class="pb-insight-editor" style="display:none" ' +
        'onblur="PinBoard.finishInsightEdit(\'' + pid + '\')">' +
        escapeHtml(editorText) +
      '</textarea>' +
    '</div>';

    // Chart SVG
    var mode = pin.pinMode || "all";
    var showChart = (mode === "all" || mode === "chart_insight");
    var showTable = (mode === "all" || mode === "table_insight");

    if (pin.chartSvg && pin.chartVisible !== false && showChart) {
      html += '<div class="pb-pin-chart">' + sanitizeHtml(pin.chartSvg) + '</div>';
    }

    // Table: prefer CSS-faithful PNG capture, fall back to raw HTML
    if (showTable) {
      if (pin.tablePng) {
        html += '<div class="pb-pin-table pb-pin-table-png">' +
          '<img src="' + escapeAttr(pin.tablePng) + '" alt="Table" ' +
          'style="max-width:100%;height:auto;">' +
          '</div>';
      } else if (pin.tableHtml) {
        html += '<div class="pb-pin-table">' + sanitizeHtml(pin.tableHtml) + '</div>';
      }
    }

    html += '</div>';
    return html;
  }

  // ===========================================================================
  // Drag and Drop
  // ===========================================================================

  /**
   * Attach drag-and-drop listeners to all draggable items.
   */
  function attachDragListeners() {
    var cards = document.querySelectorAll("#pb-cards [draggable=true]");
    for (var i = 0; i < cards.length; i++) {
      cards[i].addEventListener("dragstart", onDragStart);
      cards[i].addEventListener("dragover", onDragOver);
      cards[i].addEventListener("drop", onDrop);
      cards[i].addEventListener("dragend", onDragEnd);
    }
  }

  function onDragStart(e) {
    dragSrcIdx = parseInt(this.getAttribute("data-idx"), 10);
    this.classList.add("pb-dragging");
    e.dataTransfer.effectAllowed = "move";
    // Required for Firefox
    e.dataTransfer.setData("text/plain", "" + dragSrcIdx);
  }

  function onDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
    this.classList.add("pb-drag-over");
  }

  function onDrop(e) {
    e.preventDefault();
    this.classList.remove("pb-drag-over");

    var toIdx = parseInt(this.getAttribute("data-idx"), 10);
    if (isNaN(dragSrcIdx) || isNaN(toIdx) || dragSrcIdx === toIdx) return;

    // Reorder
    var item = items.splice(dragSrcIdx, 1)[0];
    items.splice(toIdx, 0, item);
    render();
    persist();
  }

  function onDragEnd() {
    this.classList.remove("pb-dragging");
    // Clean up any leftover drag-over states
    var overs = document.querySelectorAll(".pb-drag-over");
    for (var i = 0; i < overs.length; i++) {
      overs[i].classList.remove("pb-drag-over");
    }
    dragSrcIdx = null;
  }

  // ===========================================================================
  // Table PNG Capture (F18 — Full CSS Fidelity)
  // ===========================================================================

  var TABLE_CAPTURE_SCALE = 3;   // Canvas resolution multiplier
  var TABLE_CAPTURE_TIMEOUT = 5000; // Max ms to wait for iframe render

  /**
   * Capture a table's HTML as a high-resolution PNG by rendering it inside
   * a hidden iframe that inherits the source report's CSS context.
   *
   * Flow:
   *   1. Create a hidden iframe
   *   2. Write the table HTML + source report CSS into it
   *   3. Wait for rendering
   *   4. Use html2canvas-style approach: render to foreignObject SVG → canvas → PNG
   *   5. Store the data URL on the pin and re-render
   *
   * @param {string} pinId - ID of the pin to update
   * @param {string} tableHtml - Raw HTML table markup
   * @param {string} sourceKey - Report key (for finding the source iframe's CSS)
   */
  function captureTablePng(pinId, tableHtml, sourceKey) {
    // Find the source report's iframe to extract its stylesheets
    var sourceIframe = document.getElementById("report-iframe-" + sourceKey);
    var cssText = "";

    if (sourceIframe) {
      try {
        var sourceDoc = sourceIframe.contentDocument;
        if (sourceDoc) {
          // Extract all <style> blocks and linked stylesheets
          var styles = sourceDoc.querySelectorAll("style");
          for (var s = 0; s < styles.length; s++) {
            cssText += styles[s].textContent + "\n";
          }
          // Also try to get computed styles from stylesheet rules
          try {
            var sheets = sourceDoc.styleSheets;
            for (var sh = 0; sh < sheets.length; sh++) {
              try {
                var rules = sheets[sh].cssRules || sheets[sh].rules;
                if (rules) {
                  for (var r = 0; r < rules.length; r++) {
                    cssText += rules[r].cssText + "\n";
                  }
                }
              } catch (e) {
                // CORS or access error on external sheets — skip
              }
            }
          } catch (e) {
            // stylesheet access error
          }
        }
      } catch (e) {
        console.warn("[Pin Board] Could not access source iframe CSS:", e.message);
      }
    }

    // Create a hidden iframe for rendering
    var captureFrame = document.createElement("iframe");
    captureFrame.style.cssText = "position:fixed;left:-9999px;top:-9999px;" +
      "width:800px;height:1px;border:none;visibility:hidden;";
    document.body.appendChild(captureFrame);

    var cleanup = function() {
      if (captureFrame.parentNode) {
        document.body.removeChild(captureFrame);
      }
    };

    // Safety timeout
    var timer = setTimeout(function() {
      console.warn("[Pin Board] Table capture timed out for pin:", pinId);
      cleanup();
    }, TABLE_CAPTURE_TIMEOUT);

    captureFrame.onload = function() {
      try {
        var doc = captureFrame.contentDocument;
        // Write table HTML with extracted CSS
        doc.open();
        doc.write(
          '<!DOCTYPE html><html><head><style>' +
          'body { margin: 0; padding: 8px; background: #fff; font-family: ' +
          '-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; font-size: 12px; }' +
          'table { border-collapse: collapse; width: auto; }' +
          'th, td { padding: 4px 8px; border: 1px solid #e2e8f0; }' +
          'th { background: #f1f5f9; font-weight: 600; }' +
          cssText +
          '</style></head><body>' +
          tableHtml +
          '</body></html>'
        );
        doc.close();

        // Wait a frame for rendering
        setTimeout(function() {
          try {
            var body = doc.body;
            var tableEl = body.querySelector("table") || body;
            var width = Math.min(tableEl.scrollWidth + 16, 1200);
            var height = Math.min(tableEl.scrollHeight + 16, 2000);

            // Resize iframe to fit table
            captureFrame.style.width = width + "px";
            captureFrame.style.height = height + "px";

            // Use SVG foreignObject → canvas approach
            var svgData = '<svg xmlns="http://www.w3.org/2000/svg" ' +
              'width="' + width + '" height="' + height + '">' +
              '<foreignObject width="100%" height="100%">' +
              '<div xmlns="http://www.w3.org/1999/xhtml">' +
              new XMLSerializer().serializeToString(doc.documentElement) +
              '</div></foreignObject></svg>';

            var img = new Image();
            img.onload = function() {
              var canvas = document.createElement("canvas");
              canvas.width = width * TABLE_CAPTURE_SCALE;
              canvas.height = height * TABLE_CAPTURE_SCALE;
              var ctx = canvas.getContext("2d");
              ctx.scale(TABLE_CAPTURE_SCALE, TABLE_CAPTURE_SCALE);
              ctx.fillStyle = "#ffffff";
              ctx.fillRect(0, 0, width, height);
              ctx.drawImage(img, 0, 0, width, height);

              var dataUrl = canvas.toDataURL("image/png");

              clearTimeout(timer);
              cleanup();

              // Update the pin with the captured PNG
              var idx = findIndex(pinId);
              if (idx !== -1) {
                items[idx].tablePng = dataUrl;
                render();
                persist();
                console.log("[Pin Board] Table PNG captured for pin:", pinId);
              }
            };

            img.onerror = function() {
              clearTimeout(timer);
              cleanup();
              console.warn("[Pin Board] Table PNG image render failed for pin:", pinId);
            };

            var blob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });
            img.src = URL.createObjectURL(blob);

          } catch (e) {
            clearTimeout(timer);
            cleanup();
            console.warn("[Pin Board] Table capture render error:", e.message);
          }
        }, 200);

      } catch (e) {
        clearTimeout(timer);
        cleanup();
        console.warn("[Pin Board] Table capture error:", e.message);
      }
    };

    // Trigger the load
    captureFrame.src = "about:blank";
  }

  // ===========================================================================
  // SVG Compression (identical to hub_pinned.js)
  // ===========================================================================

  function compressSvg(svg) {
    // Collapse whitespace between tags, preserving text/tspan spacing
    svg = svg.replace(/>([\s]+)</g, function(match, ws, offset) {
      var before = svg.substring(Math.max(0, offset - 7), offset + 1);
      var after = svg.substring(offset + match.length - 1, offset + match.length + 7);
      if (/tspan>$/.test(before) || /^<tspan/.test(after) ||
          /text>$/.test(before) || /^<text/.test(after)) {
        return ">" + (ws.indexOf("\n") !== -1 ? " " : ws.substring(0, 1)) + "<";
      }
      return "><";
    });

    // Reduce decimal precision in coordinate attributes
    var coordAttrs = /\b(d|x|y|x1|y1|x2|y2|cx|cy|r|rx|ry|width|height|viewBox|transform|points|offset|dx|dy|style)="([^"]*)"/g;
    svg = svg.replace(coordAttrs, function(full, attr, val) {
      return attr + '="' + val.replace(/(\d+\.\d{3})\d+/g, "$1") + '"';
    });

    // Remove empty style/class attributes
    svg = svg.replace(/\s+(style|class)=""/g, "");
    return svg;
  }

  // ===========================================================================
  // Markdown Renderer (matches hub_pinned.js / tabs module)
  // ===========================================================================

  function renderMarkdown(md) {
    if (!md) return "";
    var html = md
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/^## (.+)$/gm, "<h2>$1</h2>")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/\*(.+?)\*/g, "<em>$1</em>")
      .replace(/^&gt; (.+)$/gm, "<blockquote>$1</blockquote>")
      .replace(/^- (.+)$/gm, "<li>$1</li>");

    html = html.replace(/((?:<li>.*<\/li>\s*)+)/g, function(match) {
      return "<ul>" + match + "</ul>";
    });
    html = html.replace(/<\/blockquote>\s*<blockquote>/g, "<br>");
    html = html.split("\n").map(function(line) {
      var trimmed = line.trim();
      if (!trimmed) return "";
      if (/^<(h2|ul|li|blockquote)/.test(trimmed)) return trimmed;
      return "<p>" + trimmed + "</p>";
    }).join("\n");

    return html;
  }

  // ===========================================================================
  // Utilities
  // ===========================================================================

  function containsHtml(str) {
    return /<[a-z][\s\S]*>/i.test(str);
  }

  /** Basic HTML sanitization — strips script tags and event handlers */
  function sanitizeHtml(html) {
    if (!html) return "";
    return html
      .replace(/<script[\s\S]*?<\/script>/gi, "")
      .replace(/\bon\w+\s*=\s*"[^"]*"/gi, "")
      .replace(/\bon\w+\s*=\s*'[^']*'/gi, "");
  }

  function escapeHtml(str) {
    if (!str) return "";
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function escapeAttr(str) {
    return escapeHtml(str);
  }

  function findIndex(itemId) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].id === itemId) return i;
    }
    return -1;
  }

  function randomId() {
    return Math.random().toString(36).substring(2, 7);
  }

  function getPinCount() {
    var count = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].type === "pin") count++;
    }
    return count;
  }

  function getItems() {
    return items;
  }

  /** Update the pin count badge in the tab bar */
  function updateBadge() {
    var badge = document.getElementById("pb-count-badge");
    var count = getPinCount();
    if (badge) {
      badge.textContent = count;
      badge.style.display = count > 0 ? "" : "none";
    }
  }

  /** Trigger debounced save */
  function persist() {
    HubState.save(items);
  }

  // ---- Inline SVG icons for action buttons ----

  function svgArrowUp() {
    return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"></polyline></svg>';
  }

  function svgArrowDown() {
    return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>';
  }

  function svgClose() {
    return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>';
  }

  function svgDownload() {
    return '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>';
  }

  // --- Public API ---
  return {
    addPin: addPin,
    addSection: addSection,
    removeItem: removeItem,
    moveItem: moveItem,
    updateSectionTitle: updateSectionTitle,
    toggleInsightEdit: toggleInsightEdit,
    finishInsightEdit: finishInsightEdit,
    hydrate: hydrate,
    render: render,
    getItems: getItems,
    getPinCount: getPinCount,
    updateBadge: updateBadge
  };
})();
