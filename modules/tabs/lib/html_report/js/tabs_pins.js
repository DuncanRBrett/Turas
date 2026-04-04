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

    // AI callout (portable HTML with inline styles)
    var aiInsightHtml = "";
    var aiCallout = qContainer.querySelector('.turas-ai-callout[data-q-code="' + qCode + '"]');
    if (!aiCallout) aiCallout = qContainer.querySelector(".turas-ai-callout");
    if (aiCallout && aiCallout.style.display !== "none" &&
        aiCallout.getAttribute("data-pinned") !== "hidden") {
      // Capture portable HTML first (clone must match live element structure)
      var aiClone = aiCallout.cloneNode(true);
      aiInsightHtml = TurasPins.capturePortableHtml(aiCallout, aiClone);
      // Then strip interactive buttons from the captured HTML
      var aiTemp = document.createElement("div");
      aiTemp.innerHTML = aiInsightHtml;
      aiTemp.querySelectorAll(".ai-callout-pin, .ai-callout-dismiss")
        .forEach(function(b) { b.remove(); });
      aiInsightHtml = aiTemp.innerHTML;
    }

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

    // Capture table with inline styles, then clean up the clone.
    // capturePortableHtml must run BEFORE removing elements from the
    // clone, because it reads from the live element and the element
    // counts must match between live and clone.
    var tableClone = table ? table.cloneNode(true) : null;
    var tablePortableHtml = "";
    if (table && tableClone) {
      // Inline styles first (live element → clone, matched by index)
      tablePortableHtml = TurasPins.capturePortableHtml(table, tableClone);
      // Now re-parse and remove unwanted elements from the styled HTML
      var tableTemp = document.createElement("div");
      tableTemp.innerHTML = tablePortableHtml;
      tableTemp.querySelectorAll('[style*="display: none"], [style*="display:none"]')
        .forEach(function(el) { el.remove(); });
      tableTemp.querySelectorAll(".ct-row-excluded").forEach(function(el) { el.remove(); });
      tableTemp.querySelectorAll(".ct-sort-indicator, .row-exclude-btn, .ct-freq")
        .forEach(function(el) { el.remove(); });
      tablePortableHtml = tableTemp.innerHTML;
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
      aiInsightHtml: aiInsightHtml,
      sortState: tableSortState,
      tableHtml: tablePortableHtml,
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
   * Show checkbox-based pin popover for crosstab pin.
   * User can independently toggle: Chart, Table, Insight, AI Insight.
   * @param {string} qCode - Question code
   */
  window.togglePin = function(qCode) {
    // If popover already open for this question, close it
    var existing = document.querySelector(".pin-mode-popover");
    if (existing) {
      closePopover();
      return;
    }

    var btn = document.querySelector('.pin-btn[data-q-code="' + qCode + '"]');
    if (!btn) return;

    var qContainer = document.querySelector("#q-container-" + getQuestionIndexByCode(qCode));
    if (!qContainer) qContainer = btn.closest(".question-container");
    var hasChart = !!(qContainer && qContainer.querySelector(".chart-wrapper svg"));
    var hasAiCallout = !!(qContainer && qContainer.querySelector(".turas-ai-callout"));
    var hasInsight = false;
    var insightEditor = qContainer ? qContainer.querySelector(".insight-md-editor") : null;
    if (insightEditor && insightEditor.value.trim()) hasInsight = true;

    var popover = document.createElement("div");
    popover.className = "pin-mode-popover";
    // Stop all clicks inside popover from bubbling to the pin button
    popover.onclick = function(e) { e.stopPropagation(); };

    var title = document.createElement("div");
    title.className = "pin-mode-title";
    title.textContent = "PIN TO VIEWS";
    popover.appendChild(title);

    var checkboxes = [
      { key: "table",     label: "Table",      available: true,        checked: true },
      { key: "chart",     label: "Chart",      available: hasChart,    checked: hasChart },
      { key: "insight",   label: "Insight",    available: true,        checked: hasInsight },
      { key: "aiInsight", label: "AI Insight",  available: hasAiCallout, checked: hasAiCallout }
    ];

    var state = {};
    checkboxes.forEach(function(opt) {
      state[opt.key] = opt.available && opt.checked;

      var row = document.createElement("label");
      row.className = "pin-mode-checkbox" + (opt.available ? "" : " pin-mode-disabled");

      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = opt.available && opt.checked;
      cb.disabled = !opt.available;
      cb.onchange = function() { state[opt.key] = this.checked; };

      var span = document.createElement("span");
      span.textContent = opt.label;
      if (!opt.available) span.title = "Not available for this question";

      row.appendChild(cb);
      row.appendChild(span);
      popover.appendChild(row);
    });

    var pinBtn = document.createElement("button");
    pinBtn.className = "pin-mode-action";
    pinBtn.textContent = "Pin";
    pinBtn.onclick = function(e) {
      e.stopPropagation();
      var anyChecked = Object.keys(state).some(function(k) { return state[k]; });
      if (!anyChecked) return;
      closePopover();
      executePinWithFlags(qCode, state);
    };
    popover.appendChild(pinBtn);

    // Append to the question title card (not the button) to avoid re-triggering togglePin
    var titleCard = btn.closest(".question-title-card") || btn.parentElement;
    // Set position:relative BEFORE reading offsetTop — otherwise offsetTop is
    // measured relative to the body (huge value) and the popover lands off-screen
    titleCard.style.position = "relative";
    popover.style.cssText = "position:absolute;top:" +
      (btn.offsetTop + btn.offsetHeight + 4) + "px;right:16px;z-index:1000;";
    titleCard.appendChild(popover);

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

  function executePinWithFlags(qCode, flags) {
    var content = captureCurrentView(qCode);
    if (!content) return;
    content.pinFlags = {
      chart:     !!flags.chart,
      table:     !!flags.table,
      insight:   !!flags.insight,
      aiInsight: !!flags.aiInsight
    };
    content.pinMode = "custom";
    // Clear content the user opted out of so it doesn't bloat storage
    if (!flags.chart) content.chartSvg = "";
    if (!flags.table) content.tableHtml = "";
    if (!flags.insight) content.insightText = "";
    if (!flags.aiInsight) content.aiInsightHtml = "";
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
