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
    if (item.type === "pin" && item.source && item.metricId) {
      var ns = item.source === "tracker" ? "TrackerReport" : "TabsReport";
      if (window[ns] && typeof window[ns].updatePinButton === "function") {
        window[ns].updatePinButton(item.metricId || item.qCode, false);
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
    var sourceBadge = pin.source === "tracker"
      ? '<span class="hub-source-badge hub-badge-tracker">Tracker</span>'
      : '<span class="hub-source-badge hub-badge-tabs">Crosstabs</span>';

    var title = pin.title || pin.metricLabel || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || "";

    var html = '<div class="hub-pin-card" data-pin-id="' + pin.id + '" data-idx="' + idx + '">' +
      '<div class="hub-pin-header">' +
        sourceBadge +
        '<span class="hub-pin-title">' + escapeHtml(title) + '</span>' +
        '<div class="hub-pin-actions">' +
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

    // Chart (if captured)
    if (pin.chartSvg) {
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
