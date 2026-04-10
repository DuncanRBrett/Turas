/**
 * Hub Pinned Views — Core Pin Management
 *
 * Manages the hub's unified pin store: add/remove/move/save/load/render.
 * Delegates to TurasPins shared utilities for SVG compression, HTML
 * sanitisation, markdown rendering, and toast notifications.
 *
 * The hub is NOT a TurasPins.init() consumer — it IS the aggregation
 * target that modules forward pins to. It maintains its own pinnedItems
 * array on ReportHub and uses its own rendering (source badges, hub
 * layout). Shared utility functions are called directly.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 * See also: hub_pins_overview.js, hub_pins_export.js
 */

/* global ReportHub, TurasPins */

(function() {
  "use strict";

  // Unified pin store: array of {type, source, id, ...data}
  ReportHub.pinnedItems = [];

  // ── Pin Lifecycle ──────────────────────────────────────────────────────────

  /**
   * Add a pin from a source report.
   * @param {string} source - Report key (e.g., "tracker", "tabs")
   * @param {object} pinObj - Pin data from the source report
   */
  ReportHub.addPin = function(source, pinObj) {
    pinObj.source = source;
    pinObj.type = "pin";
    pinObj = TurasPins.normalise(pinObj);

    // Strip pngDataUrl — hub regenerates PNGs from SVG at export time
    delete pinObj.pngDataUrl;

    ReportHub.pinnedItems.push(pinObj);
    ReportHub.renderPinnedCards();
    ReportHub.updatePinBadge();
    ReportHub.savePinnedData();

    var toastLabel = pinObj.sourceLabel || source || "Report";
    var toastTitle = pinObj.title || "View";
    TurasPins._showToast("Pinned: " + toastTitle + " (" + toastLabel + ")");
  };

  /**
   * Remove a pin or section by ID.
   * @param {string} pinId
   */
  ReportHub.removePin = function(pinId) {
    var idx = -1;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === pinId) { idx = i; break; }
    }
    if (idx === -1) return;
    ReportHub.pinnedItems.splice(idx, 1);
    ReportHub.renderPinnedCards();
    ReportHub.updatePinBadge();
    ReportHub.savePinnedData();
  };

  /**
   * Add a section divider.
   * @param {string} title - Section title (editable)
   */
  ReportHub.addSection = function(title) {
    ReportHub.pinnedItems.push({
      type: "section",
      title: title || "New Section",
      id: "sec-" + Date.now() + "-" + Math.random().toString(36).substring(2, 7)
    });
    ReportHub.renderPinnedCards();
    ReportHub.savePinnedData();
  };

  // ── Reordering ─────────────────────────────────────────────────────────────

  /**
   * Move an item by index (used by drag-and-drop).
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
   * Move an item by ID in a given direction.
   * @param {string} itemId - Pin or section ID
   * @param {number} direction - -1 for up, +1 for down
   */
  ReportHub.moveItemById = function(itemId, direction) {
    var fromIdx = -1;
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === itemId) { fromIdx = i; break; }
    }
    if (fromIdx === -1) return;
    var toIdx = fromIdx + direction;
    if (toIdx < 0 || toIdx >= ReportHub.pinnedItems.length) return;
    var item = ReportHub.pinnedItems.splice(fromIdx, 1)[0];
    ReportHub.pinnedItems.splice(toIdx, 0, item);
    ReportHub.renderPinnedCards();
    ReportHub.savePinnedData();
  };

  // ── Badge & Persistence ────────────────────────────────────────────────────

  /** Update the pin count badge in header. */
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

  /** Save pinned data to the hidden JSON store. */
  ReportHub.savePinnedData = function() {
    var store = document.getElementById("hub-pinned-data");
    if (store) store.textContent = JSON.stringify(ReportHub.pinnedItems);
  };

  /** Hydrate pinned views from the JSON store on page load. */
  ReportHub.hydratePinnedViews = function() {
    var store = document.getElementById("hub-pinned-data");
    if (!store) return;
    try {
      var data = JSON.parse(store.textContent);
      if (!Array.isArray(data)) return;
      var valid = [];
      for (var i = 0; i < data.length; i++) {
        var item = data[i];
        if (!item || typeof item !== "object") continue;
        if (!item.type || !item.id) continue;
        if (item.type !== "pin" && item.type !== "section") continue;
        if (item.pngDataUrl) delete item.pngDataUrl;
        valid.push(item);
      }
      if (valid.length > 0) {
        ReportHub.pinnedItems = valid;
        ReportHub.renderPinnedCards();
        ReportHub.updatePinBadge();
      }
    } catch (e) {
      console.warn("[Turas Report Hub] Failed to parse pinned data:", e.message);
    }
  };

  // ── Section Title Editing ──────────────────────────────────────────────────

  /** Update a section's title by index. */
  ReportHub.updateSectionTitle = function(idx, newTitle) {
    if (idx >= 0 && idx < ReportHub.pinnedItems.length &&
        ReportHub.pinnedItems[idx].type === "section") {
      ReportHub.pinnedItems[idx].title = newTitle.trim() || "Untitled Section";
      ReportHub.savePinnedData();
    }
  };

  /** Update a section's title by ID (safer than index-based). */
  ReportHub.updateSectionTitleById = function(sectionId, newTitle) {
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      if (ReportHub.pinnedItems[i].id === sectionId &&
          ReportHub.pinnedItems[i].type === "section") {
        ReportHub.pinnedItems[i].title = newTitle.trim() || "Untitled Section";
        ReportHub.savePinnedData();
        break;
      }
    }
  };

  /** Expose markdown renderer for hub slides. */
  ReportHub.renderMarkdown = TurasPins._renderMarkdown;

  // ── Drag and Drop ──────────────────────────────────────────────────────────

  (function() {
    var dragFromIdx = null;

    document.addEventListener("dragstart", function(e) {
      var draggable = e.target.closest("[data-pin-drag-idx]");
      if (!draggable) return;
      if (e.target.isContentEditable || e.target.tagName === "TEXTAREA" || e.target.tagName === "INPUT") {
        e.preventDefault();
        return;
      }
      dragFromIdx = parseInt(draggable.getAttribute("data-pin-drag-idx"), 10);
      draggable.classList.add("hub-pin-dragging");
      e.dataTransfer.effectAllowed = "move";
      try {
        var title = draggable.querySelector(".hub-pin-title, .hub-section-title");
        var label = title ? title.textContent.substring(0, 30) : "Moving...";
        var ghost = document.createElement("div");
        ghost.style.cssText = "position:absolute;top:-999px;left:-999px;padding:8px 16px;background:#e2e8f0;border-radius:6px;font-size:13px;font-weight:500;color:#374151;white-space:nowrap;";
        ghost.textContent = label;
        document.body.appendChild(ghost);
        e.dataTransfer.setDragImage(ghost, 0, 0);
        setTimeout(function() { document.body.removeChild(ghost); }, 0);
      } catch (err) { /* drag ghost is cosmetic — safe to skip */ }
    });

    document.addEventListener("dragover", function(e) {
      var target = e.target.closest("[data-pin-drag-idx]");
      if (!target || dragFromIdx === null) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
      document.querySelectorAll(".hub-pin-drop-target").forEach(function(el) {
        el.classList.remove("hub-pin-drop-target");
      });
      target.classList.add("hub-pin-drop-target");
    });

    document.addEventListener("dragleave", function(e) {
      var target = e.target.closest("[data-pin-drag-idx]");
      if (target) target.classList.remove("hub-pin-drop-target");
    });

    document.addEventListener("drop", function(e) {
      e.preventDefault();
      document.querySelectorAll(".hub-pin-drop-target, .hub-pin-dragging").forEach(function(el) {
        el.classList.remove("hub-pin-drop-target", "hub-pin-dragging");
      });
      var target = e.target.closest("[data-pin-drag-idx]");
      if (!target || dragFromIdx === null) return;
      var toIdx = parseInt(target.getAttribute("data-pin-drag-idx"), 10);
      if (dragFromIdx !== toIdx) {
        ReportHub.moveItem(dragFromIdx, toIdx);
      }
      dragFromIdx = null;
    });

    document.addEventListener("dragend", function() {
      dragFromIdx = null;
      document.querySelectorAll(".hub-pin-drop-target, .hub-pin-dragging").forEach(function(el) {
        el.classList.remove("hub-pin-drop-target", "hub-pin-dragging");
      });
    });
  })();

})();
