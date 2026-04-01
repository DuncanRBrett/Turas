/**
 * TURAS Tabs Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles tabs-specific content capture: crosstab charts, tables,
 * insights, banner labels, base text, column/row state.
 *
 * Pins are always additive — each click captures a new snapshot.
 * Mode popover lets user choose: Table + Chart / Chart only / Table only.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 *             core_navigation.js (chartColumnState, currentGroup, sortState)
 *             chart_picker.js (_chartExclusions)
 * See also: tabs_pins_dashboard.js for dashboard pin types
 *           tabs_pins_print.js for print overlay and sig export
 */

/* global TurasPins, BRAND_COLOUR, chartColumnState, currentGroup, sortState, escapeHtml */

(function() {
  "use strict";

  // ── Content Capture ────────────────────────────────────────────────────────

  /** Look up question container index from qCode. */
  function getQuestionIndexByCode(qCode) {
    var items = document.querySelectorAll(".question-item");
    for (var i = 0; i < items.length; i++) {
      var search = items[i].getAttribute("data-search") || "";
      if (search.indexOf(qCode.toLowerCase()) === 0) return i;
    }
    var containers = document.querySelectorAll(".question-container");
    for (var j = 0; j < containers.length; j++) {
      var wrapper = containers[j].querySelector('.chart-wrapper[data-q-code="' + qCode + '"]');
      if (wrapper) return j;
    }
    return -1;
  }

  /**
   * Capture current view state for a crosstab question.
   * @param {string} qCode - Question code
   * @returns {object|null} Content object or null if question not found
   */
  function captureCurrentView(qCode) {
    var container = document.querySelector('.question-container .chart-wrapper[data-q-code="' + qCode + '"]');
    if (!container) container = document.querySelector('.chart-wrapper[data-q-code="' + qCode + '"]');
    var qContainer = container ? container.closest(".question-container") : null;
    if (!qContainer) return null;

    var wrapper = qContainer.querySelector(".chart-wrapper");
    var qTitle = wrapper ? wrapper.getAttribute("data-q-title") || "" : "";

    // Selected chart columns (per banner group)
    var selectedCols = [];
    if (typeof chartColumnState !== "undefined" && chartColumnState[currentGroup]) {
      selectedCols = Object.keys(chartColumnState[currentGroup]).filter(function(k) {
        return chartColumnState[currentGroup][k];
      });
    }

    // Excluded rows
    var excludedRows = [];
    if (window._chartExclusions && window._chartExclusions[qCode]) {
      excludedRows = Object.keys(window._chartExclusions[qCode]);
    }

    // Insight text (raw markdown)
    var insightText = "";
    var editor = qContainer.querySelector(".insight-md-editor");
    if (editor) insightText = editor.value.trim();

    // Table sort state
    var table = qContainer.querySelector("table.ct-table");
    var tableSortState = null;
    if (table && typeof sortState !== "undefined" &&
        sortState[table.id] && sortState[table.id].direction !== "none") {
      tableSortState = {
        colKey: sortState[table.id].colKey,
        direction: sortState[table.id].direction
      };
    }

    // Clone table, remove hidden elements
    var tableClone = table ? table.cloneNode(true) : null;
    if (tableClone) {
      tableClone.querySelectorAll('[style*="display: none"], [style*="display:none"]')
        .forEach(function(el) { el.remove(); });
      tableClone.querySelectorAll(".ct-row-excluded").forEach(function(el) { el.remove(); });
      tableClone.querySelectorAll(".ct-sort-indicator, .row-exclude-btn, .ct-freq")
        .forEach(function(el) { el.remove(); });
    }

    // Chart SVG with viewBox fix
    var chartSvg = wrapper ? wrapper.querySelector("svg") : null;
    var chartSvgStr = "";
    if (chartSvg) {
      var svgClone = chartSvg.cloneNode(true);
      if (!svgClone.getAttribute("viewBox") && chartSvg.getBoundingClientRect) {
        var rect = chartSvg.getBoundingClientRect();
        if (rect.width > 0 && rect.height > 0) {
          svgClone.setAttribute("viewBox", "0 0 " + rect.width + " " + rect.height);
        }
      }
      if (!svgClone.getAttribute("width") && chartSvg.getAttribute("width")) {
        svgClone.setAttribute("width", chartSvg.getAttribute("width"));
      }
      if (!svgClone.getAttribute("height") && chartSvg.getAttribute("height")) {
        svgClone.setAttribute("height", chartSvg.getAttribute("height"));
      }
      chartSvgStr = new XMLSerializer().serializeToString(svgClone);
    }

    // Banner label
    var bannerLabel = "";
    var activeBannerTab = document.querySelector(".banner-tab.active");
    if (activeBannerTab) bannerLabel = activeBannerTab.textContent.trim();

    // Base text
    var baseText = "";
    var baseRow = qContainer.querySelector("tr.ct-row-base");
    if (baseRow) {
      var baseCells = baseRow.querySelectorAll("td:not([style*=none])");
      if (baseCells.length > 1) baseText = "n=" + baseCells[1].textContent.trim();
    }

    return {
      qCode: qCode, qTitle: qTitle,
      title: qCode + " - " + qTitle,
      bannerGroup: typeof currentGroup !== "undefined" ? currentGroup : "",
      bannerLabel: bannerLabel,
      subtitle: "Banner: " + bannerLabel + (baseText ? " \u00B7 Base: " + baseText : ""),
      selectedColumns: selectedCols,
      excludedRows: excludedRows,
      insightText: insightText,
      sortState: tableSortState,
      tableHtml: tableClone ? TurasPins.capturePortableHtml(tableClone) : "",
      chartSvg: chartSvgStr,
      baseText: baseText
    };
  }

  // ── Mode Popover ──────────────────────────────────────────────────────────

  function closePopover() {
    var existing = document.querySelector(".pin-mode-popover");
    if (existing) existing.remove();
    document.removeEventListener("click", closePopoverOnOutside, true);
  }

  function closePopoverOnOutside(e) {
    var p = document.querySelector(".pin-mode-popover");
    if (p && !p.contains(e.target) && !e.target.closest(".pin-btn")) closePopover();
  }

  /**
   * Show mode popover for crosstab pin.
   * @param {string} qCode - Question code
   */
  window.togglePin = function(qCode) {
    closePopover();

    var btn = document.querySelector('.pin-btn[data-q-code="' + qCode + '"]');
    if (!btn) return;

    var qContainer = document.querySelector("#q-container-" + getQuestionIndexByCode(qCode));
    if (!qContainer) qContainer = btn.closest(".question-container");
    var hasChart = qContainer && qContainer.querySelector(".chart-wrapper svg");

    var popover = document.createElement("div");
    popover.className = "pin-mode-popover";

    var title = document.createElement("div");
    title.className = "pin-mode-title";
    title.textContent = "Pin to Views";
    popover.appendChild(title);

    var options = [
      { label: "Table + Chart + Insight", mode: "all" },
      { label: "Chart + Insight", mode: "chart_insight", needsChart: true },
      { label: "Table + Insight", mode: "table_insight" }
    ];

    options.forEach(function(opt) {
      var row = document.createElement("button");
      row.className = "pin-mode-option";
      if (opt.needsChart && !hasChart) {
        row.className += " pin-mode-disabled";
        row.title = "No chart available";
      }
      row.textContent = opt.label;
      row.onclick = function(e) {
        e.stopPropagation();
        if (opt.needsChart && !hasChart) return;
        closePopover();
        executePinWithMode(qCode, opt.mode);
      };
      popover.appendChild(row);
    });

    btn.style.position = "relative";
    popover.style.cssText = "position:absolute;top:100%;right:0;z-index:1000;";
    btn.appendChild(popover);

    setTimeout(function() {
      document.addEventListener("click", closePopoverOnOutside, true);
    }, 0);
  };

  // ── Execute Pin ───────────────────────────────────────────────────────────

  function executePinWithMode(qCode, mode) {
    var content = captureCurrentView(qCode);
    if (!content) return;
    content.pinMode = mode;
    TurasPins.add(content);
    tabsUpdatePinButton(qCode, true);
  }

  function tabsUpdatePinButton(qCode, isPinned) {
    document.querySelectorAll('.pin-btn[data-q-code="' + qCode + '"]').forEach(function(btn) {
      btn.style.color = isPinned ? BRAND_COLOUR : "#94a3b8";
      btn.style.borderColor = isPinned ? BRAND_COLOUR : "#e2e8f0";
      btn.title = isPinned ? "Unpin this view" : "Pin this view";
    });
  }

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

  window.removePinned = function(pinId, qCode) {
    TurasPins.remove(pinId);
    if (qCode) {
      var pins = TurasPins.getAll();
      var stillPinned = pins.some(function(p) { return p.qCode === qCode; });
      tabsUpdatePinButton(qCode, stillPinned);
    }
  };

  window.exportPinnedCardPNG = function(pinId) { TurasPins.exportCard(pinId); };
  window.copyPinnedCardToClipboard = function(pinId) { TurasPins.copyToClipboard(pinId); };
  window.exportAllPinnedSlides = function() { TurasPins.exportAll(); };
  window.savePinnedData = function() { TurasPins.save(); };
  window.updatePinBadge = function() { TurasPins.updateBadge(); };
  window.renderPinnedCards = function() { TurasPins.renderCards(); };

  window.hydratePinnedViews = function() {
    TurasPins.load();
    TurasPins.renderCards();
    TurasPins.updateBadge();
  };

  // ── Clipboard check ───────────────────────────────────────────────────────

  window._clipboardAvailable = !!(navigator.clipboard && typeof ClipboardItem !== "undefined");

  // ── Initialisation ────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "pinned-views-data",
      cssPrefix: "pinned",
      moduleLabel: "Tabs",
      containerId: "pinned-cards-container",
      emptyStateId: "pinned-empty-state",
      badgeId: "pin-count-badge",
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
