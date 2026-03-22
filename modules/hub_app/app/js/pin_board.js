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

    // Table HTML
    if (pin.tableHtml && showTable) {
      html += '<div class="pb-pin-table">' + sanitizeHtml(pin.tableHtml) + '</div>';
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
