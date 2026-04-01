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

  function mdClosePopovers() {
    $$(".pin-mode-popover").forEach(function(p) { p.style.display = "none"; });
    var dyn = document.getElementById("md-pin-popover");
    if (dyn) dyn.remove();
    document.removeEventListener("click", mdClosePopoverOnOutside);
  }

  function mdClosePopoverOnOutside(e) {
    var dyn = document.getElementById("md-pin-popover");
    if (dyn && !dyn.contains(e.target)) mdClosePopovers();
  }

  /**
   * Smart pin — detects available content and shows only valid options.
   * If only one content type exists, pins directly without popover.
   * @param {string} panelId - Panel identifier
   */
  function mdTogglePin(panelId) {
    mdClosePopovers();

    var content = mdCaptureContent(panelId);
    if (!content) return;
    var hasChart = !!(content.chartSvg);
    var hasTable = !!(content.tableHtml);

    // Smart skip: only one content type → pin directly
    if (hasChart && !hasTable) { mdExecutePin(panelId, "chart_insight"); return; }
    if (!hasChart && hasTable) { mdExecutePin(panelId, "table_insight"); return; }
    if (!hasChart && !hasTable) { mdExecutePin(panelId, "all"); return; }

    // Both chart and table exist — show dynamic popover
    var btn = $(".pin-btn[data-panel='" + panelId + "']");
    if (!btn) { mdExecutePin(panelId, "all"); return; }

    var popover = document.createElement("div");
    popover.className = "pin-mode-popover";
    popover.id = "md-pin-popover";
    popover.style.display = "block";

    var options = [
      { label: "Table + Chart", mode: "all" },
      { label: "Chart only", mode: "chart_insight" },
      { label: "Table only", mode: "table_insight" }
    ];

    options.forEach(function(opt) {
      var item = document.createElement("button");
      item.className = "pin-mode-option";
      item.textContent = opt.label;
      item.onclick = function(e) {
        e.stopPropagation();
        mdExecutePin(panelId, opt.mode);
        mdClosePopovers();
      };
      popover.appendChild(item);
    });

    btn.parentElement.style.position = "relative";
    btn.parentElement.appendChild(popover);
    setTimeout(function() {
      document.addEventListener("click", mdClosePopoverOnOutside);
    }, 10);
  }

  /**
   * Execute pin with selected mode.
   * @param {string} panelId - Panel identifier
   * @param {string} mode - "all", "chart_insight", or "table_insight"
   */
  function mdExecutePin(panelId, mode) {
    mdClosePopovers();
    var content = mdCaptureContent(panelId);
    if (!content) return;

    TurasPins.add({
      sectionKey: panelId,
      title: content.title,
      insightText: content.insightText,
      chartSvg: (mode === "all" || mode === "chart_insight") ? content.chartSvg : "",
      tableHtml: (mode === "all" || mode === "table_insight") ? content.tableHtml : "",
      pinMode: mode
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
