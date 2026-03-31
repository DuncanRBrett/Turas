/**
 * TURAS Conjoint Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles conjoint-specific content capture: overview, utilities, diagnostics,
 * latent class, WTP, and simulator panels.
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
   * Handles: util-* (attribute sidebar), pin-* (panel cards), simulator.
   */
  function cjFindSource(viewId) {
    var source = null;

    if (viewId.indexOf("util-") === 0) {
      source = document.querySelector(".cj-attr-detail.active");
    } else if (viewId.indexOf("pin-") === 0) {
      var panelPart = viewId.replace(/^pin-/, "");

      if (panelPart.indexOf("diagnostics-") === 0) {
        var subPart = panelPart.replace("diagnostics-", "");
        var diagPanel = document.getElementById("panel-diagnostics");
        if (diagPanel) {
          var targetH2 = { fit: "Model Fit", convergence: "HB Convergence", quality: "Respondent Quality" };
          diagPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === targetH2[subPart]) source = card;
          });
        }
      } else if (panelPart.indexOf("lc-") === 0) {
        var lcPart = panelPart.replace("lc-", "");
        var lcPanel = document.getElementById("panel-latentclass");
        if (lcPanel) {
          var lcTarget = { bic: "Model Comparison", sizes: "Class Sizes", importance: "Importance by Class" };
          lcPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === lcTarget[lcPart]) source = card;
          });
        }
      } else if (panelPart.indexOf("wtp-") === 0) {
        var wtpPart = panelPart.replace("wtp-", "");
        var wtpPanel = document.getElementById("panel-wtp");
        if (wtpPanel) {
          var wtpTarget = { main: "Willingness to Pay", demand: "Demand Curve" };
          wtpPanel.querySelectorAll(".cj-card").forEach(function(card) {
            var h2 = card.querySelector("h2");
            if (h2 && h2.textContent === wtpTarget[wtpPart]) source = card;
          });
        }
      } else if (panelPart === "overview") {
        source = document.querySelector("#panel-overview .cj-card");
      } else if (panelPart === "simulator") {
        source = document.getElementById("cj-sim-results");
        if (source) {
          var modeBtn = document.querySelector(".cj-sim-mode-btn.active");
          source._simMode = modeBtn ? modeBtn.textContent : "Simulator";
        }
      }
    }

    if (!source) {
      var panelId = viewId.replace(/^util-/, "").replace(/^panel-/, "");
      source = document.getElementById("panel-" + panelId);
    }

    return source;
  }

  /**
   * Capture content from a conjoint source element.
   * @param {string} viewId - View identifier
   * @param {string} mode - "all", "chart_insight", or "table_insight"
   * @returns {object|null} Captured content or null
   */
  function cjCaptureContent(viewId, mode) {
    var source = cjFindSource(viewId);
    if (!source) return null;

    mode = mode || "all";

    // Title — context-aware labelling
    var titleEl = source.querySelector("h2") || source.querySelector("h3");
    var title = titleEl ? titleEl.textContent : viewId;

    // Utility views: prefix with "Utility —" so it's clear what was pinned
    if (viewId.indexOf("util-") === 0) {
      title = "Utility \u2014 " + title;
    }

    // Simulator views: prefix with "Simulator —" and add mode + timestamp
    if (source._simMode) {
      var now = new Date();
      var timeStr = String(now.getHours()).padStart(2, "0") + ":" +
                    String(now.getMinutes()).padStart(2, "0");
      title = "Simulator \u2014 " + source._simMode + " (" + timeStr + ")";
      delete source._simMode;
    }

    // ── Simulator special case ──
    // The simulator renders a mix of SVG charts, styled div bars, and tables
    // depending on the active mode (shares, revenue, sensitivity, sov).
    // Capture the full results innerHTML as tableHtml to preserve everything.
    if (viewId === "pin-simulator") {
      var resultsClone = source.cloneNode(true);
      // Strip interactive elements from the snapshot
      resultsClone.querySelectorAll("input, select, button, label").forEach(function(el) { el.remove(); });
      return {
        title: title,
        chartSvg: "",
        tableHtml: '<div class="cj-sim-snapshot">' + resultsClone.innerHTML + '</div>'
      };
    }

    // ── Standard chart + table capture ──

    // Chart SVG — find visible SVG (skip display:none containers)
    var chartSvg = "";
    if (mode === "all" || mode === "chart_insight") {
      var svgEls = source.querySelectorAll("svg");
      var svgEl = null;
      for (var si = 0; si < svgEls.length; si++) {
        if (svgEls[si].getBoundingClientRect().height > 0) {
          svgEl = svgEls[si];
          break;
        }
      }
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

    // Table HTML — find visible table
    var tableHtml = "";
    if (mode === "all" || mode === "table_insight") {
      var tableEl = source.querySelector(".cj-table") || source.querySelector("table");
      if (tableEl) {
        var tableClone = tableEl.cloneNode(true);
        tableHtml = tableClone.outerHTML;
      }
    }

    return {
      title: title,
      chartSvg: chartSvg,
      tableHtml: tableHtml
    };
  }

  // ── Mode Popover ───────────────────────────────────────────────────────────

  function cjClosePopover() {
    var p = document.getElementById("cj-pin-popover");
    if (p) p.remove();
    document.removeEventListener("click", cjClosePopoverOnOutside);
  }

  function cjClosePopoverOnOutside(e) {
    var p = document.getElementById("cj-pin-popover");
    if (p && !p.contains(e.target)) cjClosePopover();
  }

  /**
   * Pin a view — always additive. Shows mode popover first.
   * @param {string} viewId - View identifier
   * @param {HTMLElement} btnEl - Button that triggered
   */
  window.cjPinSection = function(viewId, btnEl) {
    if (!btnEl) { cjExecutePin(viewId, "all"); return; }

    // Simulator: always pin full snapshot directly (no mode choice)
    if (viewId === "pin-simulator") { cjExecutePin(viewId, "all"); return; }

    cjClosePopover();
    var content = cjCaptureContent(viewId, "all");
    var hasChart = content && content.chartSvg;
    var hasTable = content && content.tableHtml;

    // Smart skip: only one content type → pin directly
    if (hasChart && !hasTable) { cjExecutePin(viewId, "chart_insight"); return; }
    if (!hasChart && hasTable) { cjExecutePin(viewId, "table_insight"); return; }
    if (!hasChart && !hasTable) { cjExecutePin(viewId, "all"); return; }

    var popover = document.createElement("div");
    popover.className = "cj-pin-popover";
    popover.id = "cj-pin-popover";

    var options = [
      { label: "Table + Chart", mode: "all" },
      { label: "Chart only", mode: "chart_insight" },
      { label: "Table only", mode: "table_insight" }
    ];

    options.forEach(function(opt) {
      var item = document.createElement("button");
      item.className = "cj-pin-popover-item";
      item.textContent = opt.label;
      item.onclick = function(e) {
        e.stopPropagation();
        cjExecutePin(viewId, opt.mode);
        cjClosePopover();
      };
      popover.appendChild(item);
    });

    btnEl.parentElement.style.position = "relative";
    btnEl.parentElement.appendChild(popover);
    setTimeout(function() {
      document.addEventListener("click", cjClosePopoverOnOutside);
    }, 10);
  };

  // Backward compat: old pin buttons call showPinPopover
  window.showPinPopover = function(viewId, btnEl) {
    window.cjPinSection(viewId, btnEl);
  };

  /**
   * Execute pin with selected mode — captures content and delegates to TurasPins.
   */
  function cjExecutePin(viewId, mode) {
    var content = cjCaptureContent(viewId, mode);
    if (!content) return;

    TurasPins.add({
      sectionKey: viewId,
      title: content.title,
      insightText: "",
      chartSvg: content.chartSvg,
      tableHtml: content.tableHtml,
      pinMode: mode
    });
  }

  // ── Print / PDF ────────────────────────────────────────────────────────────

  window.cjPrintPinnedViews = function() {
    var allItems = TurasPins.getAll();
    var pinCount = 0;
    for (var i = 0; i < allItems.length; i++) {
      if (allItems[i].type !== "section") pinCount++;
    }
    if (pinCount === 0) return;

    var overlay = document.createElement("div");
    overlay.id = "cj-pinned-print-overlay";
    overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;" +
      "z-index:99999;background:white;overflow:auto;";

    var printStyle = document.createElement("style");
    printStyle.id = "cj-pinned-print-style";
    printStyle.textContent = [
      "@page{size:A4 landscape;margin:10mm 12mm}",
      "@media print{body>*:not(#cj-pinned-print-overlay){display:none!important}",
      "#cj-pinned-print-overlay{position:static!important;overflow:visible!important}",
      ".cj-print-page{page-break-after:always;padding:12px 0}.cj-print-page:last-child{page-break-after:auto}",
      ".cj-print-insight{margin-bottom:12px;padding:16px 24px;border-left:4px solid #323367;background:#f0f5f5;border-radius:0 6px 6px 0;font-size:15px;font-weight:600;color:#1a2744;line-height:1.5;-webkit-print-color-adjust:exact;print-color-adjust:exact}",
      ".cj-print-chart svg{width:100%;height:auto}.cj-print-table table{width:100%;border-collapse:collapse;font-size:13px}",
      ".cj-print-table th,.cj-print-table td{padding:4px 8px;border:1px solid #ddd}.cj-print-table th{background:#f1f5f9;font-weight:600;-webkit-print-color-adjust:exact;print-color-adjust:exact}",
      ".cj-print-section-strip{padding:16px 0 8px;border-bottom:2px solid #323367;font-size:16px;font-weight:600;color:#323367}}",
      "#cj-pinned-print-overlay{padding:32px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}",
      ".cj-print-page{border:1px solid #e2e8f0;border-radius:8px;padding:24px;margin-bottom:16px}",
      ".cj-print-close-btn{position:fixed;top:16px;right:16px;z-index:100000;padding:8px 20px;background:#323367;color:white;border:none;border-radius:6px;cursor:pointer;font-size:13px;font-weight:600}"
    ].join(" ");
    document.head.appendChild(printStyle);

    var closeBtn = document.createElement("button");
    closeBtn.className = "cj-print-close-btn";
    closeBtn.textContent = "Close Preview";
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    var projTitle = document.querySelector(".cj-header-title");
    var pTitle = projTitle ? projTitle.textContent.trim() : "Conjoint Report";
    var projStrip = document.createElement("div");
    projStrip.style.cssText = "padding:0 0 8px;margin-bottom:12px;border-bottom:2px solid #323367;";
    projStrip.innerHTML =
      '<div style="font-size:14px;font-weight:700;color:#323367;">' + TurasPins._escapeHtml(pTitle) + "</div>" +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Conjoint &bull; ' +
      new Date().toLocaleDateString() + "</div>";
    overlay.appendChild(projStrip);

    var printPinIdx = 0;
    allItems.forEach(function(item) {
      if (item.type === "section") {
        var sEl = document.createElement("div");
        sEl.className = "cj-print-section-strip";
        sEl.textContent = item.title || "Untitled Section";
        overlay.appendChild(sEl);
        return;
      }
      printPinIdx++;
      var page = document.createElement("div");
      page.className = "cj-print-page";
      page.innerHTML =
        '<div style="font-size:16px;font-weight:600;color:#1e293b;margin:2px 0 10px;">' + TurasPins._escapeHtml(item.title || "") + "</div>" +
        (item.insightText ? '<div class="cj-print-insight">' + TurasPins._escapeHtml(item.insightText) + "</div>" : "") +
        (item.chartSvg ? '<div class="cj-print-chart">' + item.chartSvg + "</div>" : "") +
        (item.tableHtml ? '<div class="cj-print-table">' + item.tableHtml + "</div>" : "") +
        '<div style="text-align:right;font-size:9px;color:#94a3b8;margin-top:4px;">' + printPinIdx + " of " + pinCount + "</div>";
      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    function cleanupPrintOverlay() {
      var ov = document.getElementById("cj-pinned-print-overlay");
      if (ov) ov.remove();
      var ps = document.getElementById("cj-pinned-print-style");
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

  // Added slides pin delegate — conjoint_navigation.js calls this
  window._addPinnedEntry = function(entry) {
    TurasPins.add(entry);
  };

  window.cjGetPinnedViews = function() { return TurasPins._getPinsRef(); };
  window.addSection = function(title) { TurasPins.addSection(title); };
  window.removePinned = function(pinId) { TurasPins.remove(pinId); };
  window.cjRemovePinned = function(pinId) { TurasPins.remove(pinId); };
  window.cjMovePinned = function(pinId, direction) { TurasPins.move(pinId, direction); };
  window.cjUpdatePinBadge = function() { TurasPins.updateBadge(); };
  window.cjRenderPinnedCards = function() { TurasPins.renderCards(); };
  window.exportAllPinnedSlides = function() { TurasPins.exportAll(); };
  window.cjExportPinnedCardPNG = function(pinId) { TurasPins.exportCard(pinId); };
  window.cjSavePinnedData = function() { TurasPins.save(); };
  window.hydratePinnedViews = function() {
    TurasPins.load();
    TurasPins.renderCards();
    TurasPins.updateBadge();
  };
  window.printPinnedViews = function() { window.cjPrintPinnedViews(); };

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "cj-pinned-views-data",
      cssPrefix: "cj-pinned",
      moduleLabel: "Conjoint",
      containerId: "cj-pinned-cards-container",
      emptyStateId: "cj-pinned-empty",
      badgeId: "cj-pinned-count",
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
