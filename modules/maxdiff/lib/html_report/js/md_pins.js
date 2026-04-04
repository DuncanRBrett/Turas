/**
 * TURAS MaxDiff Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles maxdiff-specific content capture: panels with charts, tables,
 * insights, and added slides with image support.
 *
 * Pins are always additive — each click captures a new snapshot.
 * Mode popover lets user choose: Table + Chart + Insight / Chart + Insight / Table + Insight.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 */

/* global TurasPins */

(function() {
  "use strict";

  // ── Helpers ────────────────────────────────────────────────────────────────

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Capture content from a maxdiff panel for pinning.
   * @param {string} panelId - Panel identifier (e.g. "overview", "preferences")
   * @returns {object|null} Captured content
   */
  function mdCaptureContent(panelId) {
    var panel = $("#panel-" + panelId);
    if (!panel) return null;

    var title = "";
    var h2 = panel.querySelector("h2");
    if (h2) title = h2.textContent;

    // Chart SVG
    var chartSvg = "";
    var svgEl = panel.querySelector(".md-chart-container svg");
    if (svgEl) {
      var clone = svgEl.cloneNode(true);
      // Bug #7 pattern: explicit viewBox + dimensions
      if (!clone.getAttribute("viewBox")) {
        var bbox = svgEl.getBoundingClientRect();
        if (bbox.width > 0 && bbox.height > 0) {
          clone.setAttribute("viewBox", "0 0 " + bbox.width + " " + bbox.height);
        }
      }
      if (!clone.getAttribute("width")) clone.setAttribute("width", svgEl.getBoundingClientRect().width);
      if (!clone.getAttribute("height")) clone.setAttribute("height", svgEl.getBoundingClientRect().height);
      chartSvg = new XMLSerializer().serializeToString(clone);
    }

    // Table HTML (with portable styles for hub)
    var tableHtml = "";
    var tableEl = panel.querySelector(".md-table");
    if (tableEl) {
      var tableClone = tableEl.cloneNode(true);
      var portableHtml = TurasPins.capturePortableHtml(tableEl, tableClone);
      // Re-parse and remove sort arrows from styled clone
      var tableTemp = document.createElement("div");
      tableTemp.innerHTML = portableHtml;
      tableTemp.querySelectorAll(".sort-arrow").forEach(function(a) { a.remove(); });
      tableHtml = tableTemp.innerHTML;
    }

    // Insight text
    var insightText = "";
    var area = panel.querySelector(".insight-area");
    if (area) {
      var editor = area.querySelector(".insight-md-editor");
      if (editor) insightText = editor.value;
    }

    return {
      panelId: panelId,
      title: title,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      insightText: insightText
    };
  }

  // ── Mode Popover ───────────────────────────────────────────────────────────

  /**
   * Smart pin — detects available content and shows checkbox popover.
   * If only one content type exists, pins directly without popover.
   * @param {string} panelId - Panel identifier
   */
  function mdTogglePin(panelId) {
    TurasPins.closePopover();

    var content = mdCaptureContent(panelId);
    if (!content) return;
    var hasChart = !!content.chartSvg;
    var hasTable = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    // Smart skip: only one content type → pin directly
    if (hasChart && !hasTable) { mdExecutePinWithFlags(panelId, { chart: true, insight: hasInsight }); return; }
    if (!hasChart && hasTable) { mdExecutePinWithFlags(panelId, { table: true, insight: hasInsight }); return; }
    if (!hasChart && !hasTable) { mdExecutePinWithFlags(panelId, { insight: hasInsight }); return; }

    // Both chart and table exist — show checkbox popover
    var btn = $(".pin-btn[data-panel='" + panelId + "']");
    if (!btn) { mdExecutePinWithFlags(panelId, { table: true, chart: true, insight: hasInsight }); return; }

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable,   checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart,   checked: hasChart },
      { key: "insight", label: "Insight", available: true,       checked: hasInsight }
    ];

    TurasPins.showCheckboxPopover(btn, checkboxes, function(flags) {
      mdExecutePinWithFlags(panelId, flags);
    });
  }

  /**
   * Execute pin with flags.
   * @param {string} panelId - Panel identifier
   * @param {object} flags - { table, chart, insight }
   */
  function mdExecutePinWithFlags(panelId, flags) {
    var content = mdCaptureContent(panelId);
    if (!content) return;

    if (!flags.chart) content.chartSvg = "";
    if (!flags.table) content.tableHtml = "";
    if (!flags.insight) content.insightText = "";

    TurasPins.add({
      sectionKey: panelId,
      title: content.title,
      insightText: content.insightText,
      chartSvg: content.chartSvg,
      tableHtml: content.tableHtml,
      pinFlags: {
        chart:     !!flags.chart,
        table:     !!flags.table,
        insight:   !!flags.insight,
        aiInsight: !!flags.aiInsight
      },
      pinMode: "custom"
    });

    // Flash pin button
    var btn = $(".pin-btn[data-panel='" + panelId + "']");
    if (btn) {
      btn.classList.add("pin-flash");
      setTimeout(function() { btn.classList.remove("pin-flash"); }, 600);
    }
  }

  // ── Pin Individual Chart ───────────────────────────────────────────────────

  function mdPinChart(btnEl, chartTitle) {
    var wrapper = btnEl.closest(".md-chart-wrapper");
    if (!wrapper) return;
    var svg = wrapper.querySelector("svg");
    if (!svg) return;

    var clone = svg.cloneNode(true);
    if (!clone.getAttribute("viewBox")) {
      var bbox = svg.getBoundingClientRect();
      if (bbox.width > 0 && bbox.height > 0) {
        clone.setAttribute("viewBox", "0 0 " + bbox.width + " " + bbox.height);
      }
    }
    if (!clone.getAttribute("width")) clone.setAttribute("width", svg.getBoundingClientRect().width);
    if (!clone.getAttribute("height")) clone.setAttribute("height", svg.getBoundingClientRect().height);

    TurasPins.add({
      title: chartTitle || "Chart",
      pinMode: "chart_insight",
      chartSvg: new XMLSerializer().serializeToString(clone),
      tableHtml: "",
      insightText: ""
    });
  }

  // ── Added Slides → Pin ─────────────────────────────────────────────────────

  function mdPinSlide(slideId) {
    var card = $('[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var title = card.querySelector(".md-slide-title");
    var editor = card.querySelector(".md-slide-md-editor");
    var imgStore = card.querySelector(".md-slide-img-store");

    TurasPins.add({
      title: title ? title.textContent : "Slide",
      insightText: editor ? editor.value : "",
      chartSvg: "",
      tableHtml: "",
      imageData: imgStore ? imgStore.value : "",
      pinMode: "all"
    });
  }

  // ── Global Function Delegates ──────────────────────────────────────────────

  window._mdTogglePin = mdTogglePin;
  window._mdExecutePin = mdExecutePin;
  window._mdRemovePinned = function(pinId) { TurasPins.remove(pinId); };
  window._mdMovePinned = function(fromIdx, toIdx) {
    var pins = TurasPins.getAll();
    if (fromIdx >= 0 && fromIdx < pins.length) {
      TurasPins.move(pins[fromIdx].id, toIdx > fromIdx ? 1 : -1);
    }
  };
  window._mdPinChart = mdPinChart;
  window._mdPinSlide = mdPinSlide;
  window._mdExportPinnedSvg = function(pinId) { TurasPins.exportCard(pinId); };
  window._mdExportAllPinned = function() { TurasPins.exportAll(); };

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "md-pinned-views-data",
      cssPrefix: "md-pinned",
      moduleLabel: "MaxDiff",
      containerId: "md-pinned-cards-container",
      emptyStateId: "md-pinned-empty",
      badgeId: "pin-count-badge",
      features: {
        insightEdit: true,
        sections: true,
        dragDrop: true
      }
    });
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();

    // Close popovers on outside click
    document.addEventListener("click", function(e) {
      if (!e.target.closest(".pin-btn-wrapper")) {
        mdClosePopovers();
      }
    });

    // Listen for simulator iframe pin messages
    window.addEventListener("message", function(e) {
      if (!e.data || e.data.type !== "turas-sim-pin") return;
      var pin = e.data.pin;
      if (!pin) return;
      TurasPins.add(pin);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
