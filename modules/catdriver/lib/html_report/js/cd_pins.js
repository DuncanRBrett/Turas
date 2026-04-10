/**
 * TURAS Catdriver Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles catdriver-specific content capture: section charts, tables,
 * insights, exec-summary callouts, and model metadata.
 *
 * Pins are always additive — each click captures a new snapshot.
 * Mode popover lets user choose: Table + Chart / Chart only / Table only.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 */

/* global TurasPins, cdEscapeHtml */

(function() {
  "use strict";

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Capture content from a catdriver section for pinning.
   * @param {string} sectionKey - Section identifier
   * @param {string} prefix - ID prefix for multi-analysis reports
   * @returns {object|null} Captured content or null if section not found
   */
  function cdCaptureSectionContent(sectionKey, prefix) {
    var sectionId = prefix + "cd-" + sectionKey;
    var section = document.getElementById(sectionId);
    if (!section) return null;

    // Panel label (analysis name)
    var panelLabel = "";
    var panel = section.closest(".cd-analysis-panel");
    if (panel) {
      var heading = panel.querySelector(".cd-panel-heading-title");
      panelLabel = heading ? heading.textContent.trim() : "";
      if (!panelLabel && panel.id === "cd-tab-overview") panelLabel = "Overview";
    }
    // For patterns section: use the active factor tab name as panel label
    if (sectionKey === "patterns" && !panelLabel) {
      var activeTab = section.querySelector(".cd-factor-tab.active");
      if (activeTab) panelLabel = activeTab.textContent.trim();
    }

    // Section title
    var titleEl = section.querySelector(".cd-section-title");
    var sectionTitle = titleEl ? titleEl.textContent.trim() : sectionKey;

    // Insight text
    var insightText = "";
    var insightContainer = document.getElementById(prefix + "cd-insight-container-" + sectionKey);
    if (insightContainer) {
      var editor = insightContainer.querySelector(".cd-insight-editor");
      if (editor && editor.textContent.trim()) insightText = editor.textContent.trim();
    }

    // Chart SVG
    var chartSvg = "";
    var svgEl = section.querySelector("svg.cd-chart, svg.cd-forest-plot");
    if (svgEl) chartSvg = new XMLSerializer().serializeToString(svgEl);

    // Table HTML — capture visible rows with portable styles (respects chip filtering)
    var tableHtml = "";
    var tableEl = section.querySelector("table.cd-table, table.cd-comp-table");
    if (tableEl) {
      var tableClone = tableEl.cloneNode(true);
      var portableHtml = TurasPins.capturePortableHtml(tableEl, tableClone);
      var tableTemp = document.createElement("div");
      tableTemp.innerHTML = portableHtml;
      tableTemp.querySelectorAll('tr[style*="display: none"], tr[style*="display:none"]')
        .forEach(function(row) { row.remove(); });
      tableHtml = tableTemp.innerHTML;
    }

    // Overview card grids and insight elements
    if (sectionKey === "summary-cards" && !tableHtml && !chartSvg) {
      var cardGrid = section.querySelector(".cd-comp-cards");
      if (cardGrid) tableHtml = '<div class="cd-pinned-exec-content">' + TurasPins.capturePortableHtml(cardGrid) + "</div>";
    }
    if (sectionKey === "key-insights" && !tableHtml && !chartSvg) {
      var insightEls = section.querySelectorAll(".cd-comp-insight");
      if (insightEls.length > 0) {
        var insHtml = "";
        insightEls.forEach(function(el) { insHtml += TurasPins.capturePortableHtml(el); });
        tableHtml = '<div class="cd-pinned-exec-content">' + insHtml + "</div>";
      }
    }

    // Exec-summary: callouts + key insights + findings
    if (sectionKey === "exec-summary") {
      var execContent = "";
      var confidence = section.querySelector(".cd-model-confidence");
      if (confidence) execContent += TurasPins.capturePortableHtml(confidence);
      var callouts = section.querySelectorAll(".cd-callout");
      callouts.forEach(function(c) { execContent += TurasPins.capturePortableHtml(c); });
      var insightsList = section.querySelector(".cd-key-insights-heading");
      if (insightsList && insightsList.parentElement) execContent += TurasPins.capturePortableHtml(insightsList.parentElement);
      var findingBox = section.querySelector(".cd-finding-box");
      if (findingBox) execContent += TurasPins.capturePortableHtml(findingBox);
      if (execContent) tableHtml = '<div class="cd-pinned-exec-content">' + execContent + "</div>";
    }

    // Diagnostics table
    if (sectionKey === "diagnostics" && !chartSvg) {
      var diagTable = section.querySelector("table.cd-diagnostics-table");
      if (diagTable) tableHtml = TurasPins.capturePortableHtml(diagTable);
    }

    // Model metadata from panel stats or header badges
    var modelType = "", sampleN = "", r2Text = "";
    var statSources = panel ? panel.querySelectorAll(".cd-panel-stat") : [];
    if (statSources.length === 0) statSources = document.querySelectorAll(".cd-header-badge");
    statSources.forEach(function(stat) {
      var t = stat.textContent.trim();
      if (t.match(/logistic/i)) modelType = t;
      else if (t.match(/^n\s*=/i)) sampleN = t;
      else if (t.match(/^R/)) r2Text = t;
    });

    return {
      panelLabel: panelLabel, sectionTitle: sectionTitle,
      insightText: insightText, chartSvg: chartSvg, tableHtml: tableHtml,
      modelType: modelType, sampleN: sampleN, r2Text: r2Text
    };
  }

  // ── Mode Popover ───────────────────────────────────────────────────────────

  /**
   * Pin a section — always additive (each click captures a new snapshot).
   * Shows checkbox popover to select content types.
   * @param {string} sectionKey - Section key
   * @param {string} prefix - ID prefix for multi-analysis
   */
  window.cdPinSection = function(sectionKey, prefix) {
    prefix = prefix || "";

    var btn = document.querySelector('.cd-pin-btn[data-cd-pin-section="' + sectionKey + '"]');
    var content = cdCaptureSectionContent(sectionKey, prefix);
    if (!content) return;
    var hasChart = !!content.chartSvg;
    var hasTable = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    if (!btn) {
      cdExecutePinWithFlags(sectionKey, prefix, { table: hasTable, chart: hasChart, insight: hasInsight });
      return;
    }

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable,   checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart,   checked: hasChart },
      { key: "insight", label: "Insight", available: true,       checked: hasInsight }
    ];

    TurasPins.showCheckboxPopover(btn, checkboxes, function(flags) {
      cdExecutePinWithFlags(sectionKey, prefix, flags);
    });
  };

  /**
   * Execute pin with flags — captures content and delegates to TurasPins.
   */
  function cdExecutePinWithFlags(sectionKey, prefix, flags) {
    var content = cdCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    var title = content.panelLabel
      ? content.panelLabel + " \u2014 " + content.sectionTitle
      : content.sectionTitle;

    if (!flags.chart) content.chartSvg = "";
    if (!flags.table) content.tableHtml = "";
    if (!flags.insight) content.insightText = "";

    TurasPins.add({
      sectionKey: sectionKey,
      prefix: prefix,
      title: title,
      panelLabel: content.panelLabel,
      sectionTitle: content.sectionTitle,
      insightText: content.insightText,
      chartSvg: content.chartSvg,
      tableHtml: content.tableHtml,
      pinFlags: {
        chart:     !!flags.chart,
        table:     !!flags.table,
        insight:   !!flags.insight,
        aiInsight: !!flags.aiInsight
      },
      pinMode: "custom",
      modelType: content.modelType,
      sampleN: content.sampleN,
      r2Text: content.r2Text
    });
    cdUpdatePinButtons();
  }

  // ── Pin Button State ───────────────────────────────────────────────────────

  function cdUpdatePinButtons() {
    var pins = TurasPins.getAll();
    document.querySelectorAll(".cd-pin-btn").forEach(function(btn) {
      var sectionKey = btn.getAttribute("data-cd-pin-section");
      var prefix = btn.getAttribute("data-cd-pin-prefix") || "";
      var isPinned = false;
      for (var i = 0; i < pins.length; i++) {
        if (pins[i].type !== "section" &&
            pins[i].sectionKey === sectionKey &&
            pins[i].prefix === prefix) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle("cd-pin-btn-active", isPinned);
      btn.title = isPinned ? "Unpin this section" : "Pin to Views";
    });
  }

  // ── Print / PDF ────────────────────────────────────────────────────────────

  /**
   * Print pinned views via window.print() overlay.
   * One pin per page, section dividers as heading strips.
   */
  window.cdPrintPinnedViews = function() {
    var allItems = TurasPins.getAll();
    var pinCount = 0;
    for (var i = 0; i < allItems.length; i++) {
      if (allItems[i].type !== "section") pinCount++;
    }
    if (pinCount === 0) return;

    var overlay = document.createElement("div");
    overlay.id = "cd-pinned-print-overlay";
    overlay.style.cssText = "position:fixed;top:0;left:0;width:100%;height:100%;" +
      "z-index:99999;background:white;overflow:auto;";

    var printStyle = document.createElement("style");
    printStyle.id = "cd-pinned-print-style";
    printStyle.textContent =
      "@page { size: A4 landscape; margin: 10mm 12mm; } " +
      "@media print { " +
      "body > *:not(#cd-pinned-print-overlay) { display: none !important; } " +
      "#cd-pinned-print-overlay { position: static !important; overflow: visible !important; } " +
      ".cd-print-page { page-break-after: always; padding: 12px 0; } " +
      ".cd-print-page:last-child { page-break-after: auto; } " +
      ".cd-print-insight { margin-bottom: 12px; padding: 16px 24px; border-left: 4px solid #323367; " +
      "  background: #f0f5f5; border-radius: 0 6px 6px 0; font-size: 15px; font-weight: 600; " +
      "  color: #1a2744; line-height: 1.5; -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".cd-print-chart svg { width: 100%; height: auto; } " +
      ".cd-print-table table { width: 100%; border-collapse: collapse; font-size: 13px; table-layout: fixed; } " +
      ".cd-print-table th, .cd-print-table td { padding: 4px 8px; border: 1px solid #ddd; } " +
      ".cd-print-table th { background: #f1f5f9; font-weight: 600; -webkit-print-color-adjust: exact; print-color-adjust: exact; } " +
      ".cd-print-section-strip { padding: 16px 0 8px; border-bottom: 2px solid #323367; font-size: 16px; font-weight: 600; color: #323367; } " +
      "} " +
      "#cd-pinned-print-overlay { padding: 32px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; } " +
      ".cd-print-page { border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; margin-bottom: 16px; } " +
      ".cd-print-close-btn { position: fixed; top: 16px; right: 16px; z-index: 100000; padding: 8px 20px; " +
      "  background: #323367; color: white; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }";
    document.head.appendChild(printStyle);

    var closeBtn = document.createElement("button");
    closeBtn.className = "cd-print-close-btn";
    closeBtn.textContent = "Close Preview";
    closeBtn.onclick = cleanupPrintOverlay;
    overlay.appendChild(closeBtn);

    var projTitle = document.querySelector(".cd-header-title, .cd-comp-title");
    var pTitle = projTitle ? projTitle.textContent.trim() : "Catdriver Report";
    var projStrip = document.createElement("div");
    projStrip.className = "cd-print-project-strip";
    projStrip.style.cssText = "padding:0 0 8px;margin-bottom:12px;border-bottom:2px solid #323367;";
    projStrip.innerHTML =
      '<div style="font-size:14px;font-weight:700;color:#323367;">' + cdEscapeHtml(pTitle) + "</div>" +
      '<div style="font-size:10px;color:#64748b;margin-top:2px;">Turas Catdriver &bull; ' +
      new Date().toLocaleDateString() + "</div>";
    overlay.appendChild(projStrip);

    var printPinIdx = 0;
    allItems.forEach(function(item) {
      if (item.type === "section") {
        var sEl = document.createElement("div");
        sEl.className = "cd-print-section-strip";
        sEl.textContent = item.title || "Untitled Section";
        overlay.appendChild(sEl);
        return;
      }
      printPinIdx++;
      var page = document.createElement("div");
      page.className = "cd-print-page";
      page.innerHTML =
        (item.panelLabel ? '<div style="font-size:13px;font-weight:700;color:#323367;text-transform:uppercase;">' + cdEscapeHtml(item.panelLabel) + "</div>" : "") +
        '<div style="font-size:16px;font-weight:600;color:#1e293b;margin:2px 0 10px;">' + cdEscapeHtml(item.sectionTitle || item.title || "") + "</div>" +
        (item.insightText ? '<div class="cd-print-insight">' + cdEscapeHtml(item.insightText) + "</div>" : "") +
        (item.chartSvg ? '<div class="cd-print-chart">' + item.chartSvg + "</div>" : "") +
        (item.tableHtml ? '<div class="cd-print-table">' + item.tableHtml + "</div>" : "") +
        '<div style="text-align:right;font-size:9px;color:#94a3b8;margin-top:4px;">' + printPinIdx + " of " + pinCount + "</div>";
      overlay.appendChild(page);
    });

    document.body.appendChild(overlay);

    function cleanupPrintOverlay() {
      var ov = document.getElementById("cd-pinned-print-overlay");
      if (ov) ov.remove();
      var ps = document.getElementById("cd-pinned-print-style");
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

  window.cdGetPinnedViews = function() { return TurasPins._getPinsRef(); };
  window.cdAddSection = function(title) { TurasPins.addSection(title); };
  window.cdUpdateSectionTitle = function(idx, newTitle) {
    var all = TurasPins.getAll();
    if (idx >= 0 && idx < all.length && all[idx].type === "section") {
      TurasPins.updateSectionTitle(all[idx].id, newTitle);
    }
  };
  window.cdRemovePinned = function(pinId) { TurasPins.remove(pinId); cdUpdatePinButtons(); };
  window.cdMovePinned = function(pinId, direction) { TurasPins.move(pinId, direction); };
  window.cdClearAllPinned = function() {
    TurasPins._getPinsRef([]);
    TurasPins.save();
    TurasPins.updateBadge();
    TurasPins.renderCards();
    cdUpdatePinButtons();
  };
  window.cdUpdatePinBadge = function() { TurasPins.updateBadge(); };
  window.cdRenderPinnedCards = function() { TurasPins.renderCards(); };
  window.cdExportAllPinnedPNG = function() { TurasPins.exportAll(); };
  window.cdExportPinnedCardPNG = function(pinId) { TurasPins.exportCard(pinId); };
  window.cdSavePinnedData = function() { TurasPins.save(); };
  window.cdHydratePinnedViews = function() {
    TurasPins.load();
    TurasPins.renderCards();
    TurasPins.updateBadge();
    cdUpdatePinButtons();
  };

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "cd-pinned-views-data",
      cssPrefix: "cd-pinned",
      moduleLabel: "Catdriver",
      containerId: "cd-pinned-cards-container",
      emptyStateId: "cd-pinned-empty",
      badgeId: "cd-pin-count-badge",
      features: {
        sections: true,
        dragDrop: true
      }
    });
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();
    cdUpdatePinButtons();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
