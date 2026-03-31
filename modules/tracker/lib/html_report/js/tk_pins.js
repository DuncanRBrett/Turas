/**
 * TURAS Tracker Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles tracker-specific content capture: metric charts, filtered tables
 * (segments, waves, freq/change row visibility), and insights.
 *
 * Pins are always additive — each click captures a new snapshot.
 * Mode is passed directly from the pin button (no popover needed).
 *
 * Depends on: TurasPins shared library (loaded before this file)
 *             escapeHtml from earlier in the JS bundle
 * See also: tk_pins_extras.js for summary pins, sig changes, print, export
 */

/* global TurasPins, escapeHtml */

(function() {
  "use strict";

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Capture current view state for a tracker metric.
   * Filters out hidden segments/waves from the table clone.
   * Captures chart SVG with viewBox/width/height fix (Bug #1).
   * @param {string} metricId - The metric ID
   * @param {string} mode - "all" (chart+table), "chart", or "table"
   * @returns {object|null} Content object or null if panel not found
   */
  function captureMetricView(metricId, mode) {
    mode = mode || "all";
    var panel = document.getElementById("mv-" + metricId);
    if (!panel) return null;

    var titleEl = panel.querySelector(".mv-metric-title");
    var tableArea = panel.querySelector(".mv-table-area");
    var chartArea = panel.querySelector(".mv-chart-area");
    var insightEditor = panel.querySelector(".insight-editor");

    // Visible segments
    var visibleSegments = [];
    panel.querySelectorAll(".tk-segment-chip.active").forEach(function(chip) {
      visibleSegments.push(chip.getAttribute("data-segment"));
    });

    // ── Table HTML (filtered) ──
    var cleanTableHtml = "";
    if (tableArea && mode !== "chart") {
      var tableClone = tableArea.cloneNode(true);
      tableClone.querySelectorAll("tr.segment-hidden").forEach(function(row) { row.remove(); });
      tableClone.querySelectorAll(".wave-hidden").forEach(function(el) { el.remove(); });

      var showFreq = panel.classList.contains("show-freq");
      var vsPrevVisible = panel.querySelectorAll(".tk-change-row.tk-vs-prev.visible").length > 0;
      var vsBaseVisible = panel.querySelectorAll(".tk-change-row.tk-vs-base.visible").length > 0;

      if (showFreq) {
        tableClone.querySelectorAll(".tk-freq").forEach(function(el) { el.style.display = "block"; });
      }
      if (vsPrevVisible) {
        tableClone.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) {
          row.style.display = "table-row";
        });
      } else {
        tableClone.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) { row.remove(); });
      }
      if (vsBaseVisible) {
        tableClone.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) {
          row.style.display = "table-row";
        });
      } else {
        tableClone.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) { row.remove(); });
      }
      cleanTableHtml = tableClone.innerHTML;
    }

    // ── Chart SVG with viewBox fix (Bug #1) ──
    var chartSvg = "";
    var chartVisible = false;
    if (chartArea && chartArea.style.display !== "none" && mode !== "table") {
      chartVisible = true;
      var chartClone = chartArea.cloneNode(true);
      chartClone.querySelectorAll("[data-segment]").forEach(function(el) {
        if (el.style.display === "none") el.remove();
      });
      chartClone.querySelectorAll("[data-wave]").forEach(function(el) {
        if (el.style.display === "none") el.remove();
      });

      // Ensure viewBox/width/height on cloned SVGs
      var svgEls = chartClone.querySelectorAll("svg");
      svgEls.forEach(function(svgClone) {
        var origSvg = chartArea.querySelector("svg");
        if (!origSvg) return;
        if (!svgClone.getAttribute("viewBox") && origSvg.getBoundingClientRect) {
          var rect = origSvg.getBoundingClientRect();
          if (rect.width > 0 && rect.height > 0) {
            svgClone.setAttribute("viewBox", "0 0 " + rect.width + " " + rect.height);
          }
        }
        if (!svgClone.getAttribute("width") && origSvg.getAttribute("width")) {
          svgClone.setAttribute("width", origSvg.getAttribute("width"));
        }
        if (!svgClone.getAttribute("height") && origSvg.getAttribute("height")) {
          svgClone.setAttribute("height", origSvg.getAttribute("height"));
        }
      });

      chartSvg = chartClone.innerHTML;
    }

    return {
      metricId: metricId,
      title: titleEl ? titleEl.textContent : metricId,
      metricTitle: titleEl ? titleEl.textContent : metricId,
      visibleSegments: visibleSegments,
      tableHtml: cleanTableHtml,
      chartSvg: chartSvg,
      chartVisible: chartVisible,
      pinMode: mode,
      insightText: insightEditor ? insightEditor.innerHTML : ""
    };
  }

  // ── Pin Action ────────────────────────────────────────────────────────────

  /**
   * Pin a metric view — always additive (each click captures new snapshot).
   * @param {string} metricId - The metric ID
   * @param {string} mode - "all", "chart", or "table"
   */
  window.togglePin = function(metricId, mode) {
    var content = captureMetricView(metricId, mode || "all");
    if (content) TurasPins.add(content);
  };

  // ── Insight Editing ───────────────────────────────────────────────────────

  /** Show the insight editor on a pinned card. */
  window.showPinnedInsight = function(pinId, btn) {
    var editor = btn.nextElementSibling;
    if (editor) { editor.style.display = "block"; editor.focus(); }
    btn.style.display = "none";
  };

  /** Sync a pinned card's insight text to the pin data. */
  window.syncPinnedInsight = function(pinId, editor) {
    var pins = TurasPins._getPinsRef();
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].id === pinId) {
        pins[i].insightText = editor.innerHTML;
        break;
      }
    }
    TurasPins.save();
  };

  // ── Global Function Delegates ─────────────────────────────────────────────

  window.addSection = function(title) { TurasPins.addSection(title); };

  window.updateSectionTitle = function(idx, newTitle) {
    var all = TurasPins.getAll();
    if (idx >= 0 && idx < all.length && all[idx].type === "section") {
      TurasPins.updateSectionTitle(all[idx].id, newTitle);
    }
  };

  window.togglePinOverflow = function(btn) { TurasPins._toggleOverflow(btn); };

  window.movePinned = function(fromIdx, toIdx) {
    var all = TurasPins.getAll();
    if (fromIdx >= 0 && fromIdx < all.length) {
      TurasPins.move(all[fromIdx].id, toIdx > fromIdx ? 1 : -1);
    }
  };

  window.removePinned = function(pinId) {
    TurasPins.remove(pinId);
  };

  window.exportPinnedCardPNG = function(pinId) { TurasPins.exportCard(pinId); };
  window.copyPinnedCardToClipboard = function(pinId) { TurasPins.copyToClipboard(pinId); };
  window.exportAllPinsPNG = function() { TurasPins.exportAll(); };
  window.savePinnedData = function() { TurasPins.save(); };
  window.updatePinBadge = function() { TurasPins.updateBadge(); };
  window.renderPinnedCards = function() { TurasPins.renderCards(); };

  window.hydratePinnedViews = function() {
    TurasPins.load();
    TurasPins.renderCards();
    TurasPins.updateBadge();
  };

  // ── Initialisation ────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "pinned-views-data",
      cssPrefix: "pinned",
      moduleLabel: "Tracker",
      containerId: "pinned-cards-container",
      emptyStateId: "pinned-empty-state",
      badgeId: "pin-count-badge",
      toolbarId: "pinned-toolbar",
      features: {
        insightEdit: true,
        sections: true,
        dragDrop: true
      }
    });
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
