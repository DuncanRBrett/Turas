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

    // ── Table HTML (filtered, with portable styles for hub) ──
    var cleanTableHtml = "";
    if (tableArea && mode !== "chart") {
      // Capture portable HTML first (reads computed styles from live DOM)
      var tableClone = tableArea.cloneNode(true);
      var portableHtml = TurasPins.capturePortableHtml(tableArea, tableClone);

      // Re-parse and filter the styled clone
      var tableTemp = document.createElement("div");
      tableTemp.innerHTML = portableHtml;
      tableTemp.querySelectorAll("tr.segment-hidden").forEach(function(row) { row.remove(); });
      tableTemp.querySelectorAll(".wave-hidden").forEach(function(el) { el.remove(); });

      var showFreq = panel.classList.contains("show-freq");
      var vsPrevVisible = panel.querySelectorAll(".tk-change-row.tk-vs-prev.visible").length > 0;
      var vsBaseVisible = panel.querySelectorAll(".tk-change-row.tk-vs-base.visible").length > 0;

      if (showFreq) {
        tableTemp.querySelectorAll(".tk-freq").forEach(function(el) { el.style.display = "block"; });
      }
      if (vsPrevVisible) {
        tableTemp.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) {
          row.style.display = "table-row";
        });
      } else {
        tableTemp.querySelectorAll(".tk-change-row.tk-vs-prev").forEach(function(row) { row.remove(); });
      }
      if (vsBaseVisible) {
        tableTemp.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) {
          row.style.display = "table-row";
        });
      } else {
        tableTemp.querySelectorAll(".tk-change-row.tk-vs-base").forEach(function(row) { row.remove(); });
      }
      cleanTableHtml = tableTemp.innerHTML;
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
   * When mode is provided, pins directly (backward compat).
   * When mode is omitted or "popover", shows checkbox popover.
   * @param {string} metricId - The metric ID
   * @param {string} [mode] - "all", "chart", "table", or omit for popover
   * @param {HTMLElement} [btnEl] - Pin button for popover positioning
   */
  window.togglePin = function(metricId, mode, btnEl) {
    // Legacy direct-mode calls: pin immediately
    if (mode && mode !== "popover") {
      var content = captureMetricView(metricId, mode);
      if (content) TurasPins.add(content);
      return;
    }

    // Detect available content
    var panel = document.getElementById("mv-" + metricId);
    if (!panel) return;
    var hasChart = !!(panel.querySelector(".mv-chart-area") &&
      panel.querySelector(".mv-chart-area").style.display !== "none" &&
      panel.querySelector(".mv-chart-area svg"));
    var hasTable = !!panel.querySelector(".mv-table-area");
    var insightEditor = panel.querySelector(".insight-editor");
    var hasInsight = !!(insightEditor && insightEditor.innerHTML.trim());

    // Only one content type → pin directly
    if (!hasChart && !hasTable) {
      var c = captureMetricView(metricId, "all");
      if (c) TurasPins.add(c);
      return;
    }
    if (hasChart && !hasTable) {
      togglePinWithFlags(metricId, { chart: true, insight: hasInsight });
      return;
    }
    if (!hasChart && hasTable) {
      togglePinWithFlags(metricId, { table: true, insight: hasInsight });
      return;
    }

    // Both exist — show checkbox popover
    if (!btnEl) btnEl = panel.querySelector(".mv-pin-btn, .export-btn");
    if (!btnEl) {
      togglePinWithFlags(metricId, { table: true, chart: true, insight: hasInsight });
      return;
    }

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable,   checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart,   checked: hasChart },
      { key: "insight", label: "Insight", available: true,       checked: hasInsight }
    ];

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      togglePinWithFlags(metricId, flags);
    });
  };

  /**
   * Execute pin with flags — captures content and strips unchecked types.
   */
  function togglePinWithFlags(metricId, flags) {
    var content = captureMetricView(metricId, "all");
    if (!content) return;

    if (!flags.chart) content.chartSvg = "";
    if (!flags.table) content.tableHtml = "";
    if (!flags.insight) content.insightText = "";

    content.pinFlags = {
      chart:     !!flags.chart,
      table:     !!flags.table,
      insight:   !!flags.insight,
      aiInsight: !!flags.aiInsight
    };
    content.pinMode = "custom";
    TurasPins.add(content);
  }

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
    // Backward compat: expose pinnedViews as direct reference to internal array.
    // External files (qualitative_slides.js, explorer_view.js, chart_controls.js,
    // core_navigation.js) push directly to this array.
    window.pinnedViews = TurasPins._getPinsRef();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
