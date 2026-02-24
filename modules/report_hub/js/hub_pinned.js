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

    // Update source report's pin button state if applicable
    if (item.type === "pin" && item.source) {
      var ns = item.source === "tracker" ? "TrackerReport" : "TabsReport";
      var key = item.metricId || item.qCode;
      if (key && window[ns] && typeof window[ns].updatePinButton === "function") {
        window[ns].updatePinButton(key, false);
      }
    }

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

        // Restore per-report pin button states
        for (var i = 0; i < data.length; i++) {
          var item = data[i];
          if (item.type === "pin" && item.source) {
            var ns = item.source === "tracker" ? "TrackerReport" : "TabsReport";
            var key = item.metricId || item.qCode;
            if (key && window[ns] && typeof window[ns].updatePinButton === "function") {
              window[ns].updatePinButton(key, true);
            }
          }
        }
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

    // PNG snapshot (if captured)
    if (pin.pngDataUrl) {
      html += '<div class="hub-pin-snapshot"><img src="' + pin.pngDataUrl + '" alt="Pinned view"></div>';
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

  /**
   * Export a single pin card as PNG
   * @param {string} pinId - Pin ID
   */
  ReportHub.exportPinCard = function(pinId) {
    var card = document.querySelector('.hub-pin-card[data-pin-id="' + pinId + '"]');
    if (!card) return;

    var clone = card.cloneNode(true);
    // Remove action buttons from clone
    var actions = clone.querySelector(".hub-pin-actions");
    if (actions) actions.parentNode.removeChild(actions);

    // Inline computed styles for accurate rendering
    inlineStylesRecursive(clone, card);

    var w = card.offsetWidth || 800;
    var h = card.offsetHeight || 600;
    var scale = 3;

    var svgNS = "http://www.w3.org/2000/svg";
    var svgStr = '<svg xmlns="' + svgNS + '" width="' + (w * scale) + '" height="' + (h * scale) + '">';
    svgStr += '<foreignObject width="' + w + '" height="' + h + '" transform="scale(' + scale + ')">';
    svgStr += '<div xmlns="http://www.w3.org/1999/xhtml" style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;font-size:14px;color:#2c2c2c;background:#fff;padding:20px;">';
    svgStr += clone.outerHTML;
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
    };
    img.src = svgUrl;
  };

  /**
   * Export all pinned cards as PNGs (sequential download)
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
      setTimeout(exportNext, 400);
    }
    exportNext();
  };

  /**
   * Recursively inline computed styles from a source element onto a clone
   * (needed for SVG foreignObject rendering)
   */
  function inlineStylesRecursive(clone, source) {
    if (!source || !clone) return;
    try {
      var computed = window.getComputedStyle(source);
      var important = ["font-family", "font-size", "font-weight", "color",
        "background-color", "border", "padding", "margin", "display",
        "text-align", "line-height", "width", "max-width"];
      for (var p = 0; p < important.length; p++) {
        var val = computed.getPropertyValue(important[p]);
        if (val) clone.style.setProperty(important[p], val);
      }
    } catch (e) { /* ignore */ }
    var sourceChildren = source.children;
    var cloneChildren = clone.children;
    for (var c = 0; c < Math.min(sourceChildren.length, cloneChildren.length); c++) {
      inlineStylesRecursive(cloneChildren[c], sourceChildren[c]);
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
