/**
 * TURAS Weighting Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles weighting-specific content capture: summary table,
 * per-weight distribution histograms, diagnostics, and margins tables.
 *
 * Pins are always additive — each click captures a new snapshot.
 * Mode popover lets user choose: Table + Chart / Chart only / Table only.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 */

/* global TurasPins */

(function() {
  "use strict";

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Find the source DOM element for a given view ID.
   * Handles: pin-summary, pin-wt-{weightId}, pin-wt-{weightId}-margins
   */
  function wtFindSource(viewId) {
    // Summary card
    if (viewId === "pin-summary") {
      return document.querySelector('[data-pin-id="pin-summary"]');
    }

    // Per-weight detail cards: pin-wt-{weightId} or pin-wt-{weightId}-margins
    var card = document.querySelector('[data-pin-id="' + viewId + '"]');
    if (card) return card;

    return null;
  }

  /**
   * Capture content from a weighting source element.
   * @param {string} viewId - View identifier
   * @param {string} mode - "all", "chart_insight", or "table_insight"
   * @returns {object|null} Captured content or null
   */
  function wtCaptureContent(viewId, mode) {
    var source = wtFindSource(viewId);
    if (!source) return null;

    mode = mode || "all";

    // Title
    var titleEl = source.querySelector("h3") || source.querySelector("h2");
    var title = titleEl ? titleEl.textContent.replace(/\s*Pin$/, "").trim() : viewId;

    // Chart SVG
    var chartSvg = "";
    if (mode === "all" || mode === "chart_insight") {
      var svgEl = source.querySelector("svg");
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
    }

    // Table HTML
    var tableHtml = "";
    if (mode === "all" || mode === "table_insight") {
      var tableEl = source.querySelector(".wt-table") || source.querySelector("table");
      if (tableEl) tableHtml = TurasPins.capturePortableHtml(tableEl);
    }

    return {
      title: title,
      chartSvg: chartSvg,
      tableHtml: tableHtml
    };
  }

  // ── Mode Popover ───────────────────────────────────────────────────────────

  /**
   * Pin a view — always additive. Shows checkbox popover first.
   * @param {string} viewId - View identifier
   * @param {HTMLElement} btnEl - Button that triggered
   */
  window.wtPinSection = function(viewId, btnEl) {
    var content = wtCaptureContent(viewId, "all");
    if (!content) return;
    var hasChart = !!content.chartSvg;
    var hasTable = !!content.tableHtml;

    // No button or only one content type → pin directly
    if (!btnEl || (!hasChart && !hasTable) ||
        (hasChart && !hasTable) || (!hasChart && hasTable)) {
      wtExecutePinWithFlags(viewId, {
        table: hasTable,
        chart: hasChart
      });
      return;
    }

    var checkboxes = [
      { key: "table", label: "Table", available: hasTable, checked: hasTable },
      { key: "chart", label: "Chart", available: hasChart, checked: hasChart }
    ];

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      wtExecutePinWithFlags(viewId, flags);
    });
  };

  /**
   * Execute pin with flags — captures content and delegates to TurasPins.
   */
  function wtExecutePinWithFlags(viewId, flags) {
    var content = wtCaptureContent(viewId, "all");
    if (!content) return;

    if (!flags.chart) content.chartSvg = "";
    if (!flags.table) content.tableHtml = "";

    TurasPins.add({
      sectionKey: viewId,
      title: content.title,
      insightText: "",
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
  }

  // ── Print / PDF ────────────────────────────────────────────────────────────

  window.wtPrintPinnedViews = function() {
    var allItems = TurasPins.getAll();
    var pinCount = 0;
    for (var i = 0; i < allItems.length; i++) {
      if (allItems[i].type !== "section") pinCount++;
    }
    if (pinCount === 0) return;

    var overlay = document.createElement("div");
    overlay.id = "wt-pinned-print-overlay";
    overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;" +
      "z-index:99999;background:white;overflow:auto;";

    var printStyle = document.createElement("style");
    printStyle.id = "wt-pinned-print-style";
    printStyle.textContent =
      "@page { size: A4 landscape; margin: 10mm 12mm; } " +
      "@media print { " +
      "body > *:not(#wt-pinned-print-overlay) { display: none !important; } " +
      "#wt-pinned-print-overlay { position: static !important; overflow: visible !important; } " +
      ".wt-print-page { page-break-after: always; padding: 12px 0; } " +
      ".wt-print-page:last-child { page-break-after: auto; } " +
      ".wt-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid #1e3a5f; " +
      "  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; " +
      "  color: #1a2744; line-height: 1.5; -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".wt-print-chart svg { width: 100%; height: auto; } " +
      ".wt-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } " +
      ".wt-print-table th, .wt-print-table td { padding: 4px 8px; border: 1px solid #ddd; } " +
      ".wt-print-table th { background: #f1f5f9; font-weight: 600; -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".wt-print-section-strip { padding: 16px 0 8px; border-bottom: 2px solid #1e3a5f; font-size: 16px; font-weight: 600; color: #1e3a5f; } " +
      "} " +
      "#wt-pinned-print-overlay { padding: 32px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; } " +
      ".wt-print-page { border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; margin-bottom: 16px; } " +
      ".wt-print-close-btn { position: fixed; top: 16px; right: 16px; z-index: 100000; padding: 8px 20px; " +
      "  background: #1e3a5f; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }";
    document.head.appendChild(printStyle);

    var closeBtn = document.createElement("button");
    closeBtn.className = "wt-print-close-btn";
    closeBtn.textContent = "Close Preview";
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    var projTitle = document.querySelector(".wt-header h1, .wt-header-title");
    var pTitle = projTitle ? projTitle.textContent.trim() : "Weighting Report";
    var projStrip = document.createElement("div");
    projStrip.style.cssText = "padding:0 0 8px;margin-bottom:12px;border-bottom:2px solid #1e3a5f;";
    projStrip.innerHTML =
      '<div style="font-size:14px;font-weight:700;color:#1e3a5f;">' + TurasPins._escapeHtml(pTitle) + "</div>" +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Weighting &bull; ' +
      new Date().toLocaleDateString() + "</div>";
    overlay.appendChild(projStrip);

    var printPinIdx = 0;
    allItems.forEach(function(item) {
      if (item.type === "section") {
        var sEl = document.createElement("div");
        sEl.className = "wt-print-section-strip";
        sEl.textContent = item.title || "Untitled Section";
        overlay.appendChild(sEl);
        return;
      }
      printPinIdx++;
      var page = document.createElement("div");
      page.className = "wt-print-page";
      page.innerHTML =
        '<div style="font-size:16px;font-weight:600;color:#1e293b;margin:2px 0 10px;">' + TurasPins._escapeHtml(item.title || "") + "</div>" +
        (item.insightText ? '<div class="wt-print-insight">' + TurasPins._escapeHtml(item.insightText) + "</div>" : "") +
        (item.chartSvg ? '<div class="wt-print-chart">' + item.chartSvg + "</div>" : "") +
        (item.tableHtml ? '<div class="wt-print-table">' + item.tableHtml + "</div>" : "") +
        '<div style="text-align:right;font-size:9px;color:#94a3b8;margin-top:4px;">' + printPinIdx + " of " + pinCount + "</div>";
      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    function cleanupPrintOverlay() {
      var ov = document.getElementById("wt-pinned-print-overlay");
      if (ov) ov.remove();
      var ps = document.getElementById("wt-pinned-print-style");
      if (ps) ps.remove();
    }

    var cleaned = false;
    window.addEventListener("afterprint", function onAP() {
      if (cleaned) return;
      cleaned = true;
      window.removeEventListener("afterprint", onAP);
      cleanupPrintOverlay();
    });

    setTimeout(function() {
      window.print();
      setTimeout(function() { if (!cleaned) { cleaned = true; cleanupPrintOverlay(); } }, 3000);
    }, 300);
  };

  // ── Global Function Delegates ──────────────────────────────────────────────

  /**
   * Pin an analyst note — text-only pin for commentary and observations.
   */
  window.wtPinAnalystNote = function() {
    TurasPins.add({
      sectionKey: "analyst-note-" + Date.now(),
      title: "Analyst Note",
      insightText: "Double-click to add your note...",
      chartSvg: "",
      tableHtml: "",
      pinMode: "all"
    });
  };

  window.wtGetPinnedViews = function() { return TurasPins._getPinsRef(); };
  window.addSection = function(title) { TurasPins.addSection(title); };
  window.removePinned = function(pinId) { TurasPins.remove(pinId); };
  window.wtRemovePinned = function(pinId) { TurasPins.remove(pinId); };
  window.wtMovePinned = function(pinId, direction) { TurasPins.move(pinId, direction); };
  window.wtUpdatePinBadge = function() { TurasPins.updateBadge(); };
  window.wtRenderPinnedCards = function() { TurasPins.renderCards(); };
  window.exportAllPinnedSlides = function() { TurasPins.exportAll(); };
  window.wtExportPinnedCardPNG = function(pinId) { TurasPins.exportCard(pinId); };
  window.wtSavePinnedData = function() { TurasPins.save(); };
  window.hydratePinnedViews = function() {
    TurasPins.load();
    TurasPins.renderCards();
    TurasPins.updateBadge();
  };
  window.printPinnedViews = function() { window.wtPrintPinnedViews(); };

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "wt-pinned-views-data",
      cssPrefix: "wt-pinned",
      moduleLabel: "Weighting",
      containerId: "wt-pinned-cards-container",
      emptyStateId: "wt-pinned-empty",
      badgeId: "wt-pinned-count",
      toolbarId: "wt-pinned-toolbar",
      features: {
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
