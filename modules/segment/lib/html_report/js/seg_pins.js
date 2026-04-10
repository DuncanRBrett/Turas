/**
 * TURAS Segment Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles segment-specific content capture: section charts, tables,
 * insights, exec-summary callouts, profile cards, and clustering metadata.
 *
 * Pins are always additive — each click captures a new snapshot.
 * Mode popover lets user choose: Table + Chart / Chart only / Table only.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 *             segEscapeHtml from seg_utils.js
 * See also: seg_pins_extras.js for image upload and print overlay.
 */

/* global TurasPins, segEscapeHtml */

(function() {
  "use strict";

  // ── Content Capture ────────────────────────────────────────────────────────

  /** Capture SVG from section, ensuring viewBox/dimensions transfer. */
  function captureChartSvg(section) {
    var svgEl = section.querySelector(".seg-chart-wrapper svg, svg");
    if (!svgEl) return "";
    var svgClone = svgEl.cloneNode(true);
    if (!svgClone.getAttribute("viewBox") && svgEl.getBoundingClientRect) {
      var rect = svgEl.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        svgClone.setAttribute("viewBox", "0 0 " + rect.width + " " + rect.height);
      }
    }
    if (!svgClone.getAttribute("width") && svgEl.getAttribute("width")) {
      svgClone.setAttribute("width", svgEl.getAttribute("width"));
    }
    if (!svgClone.getAttribute("height") && svgEl.getAttribute("height")) {
      svgClone.setAttribute("height", svgEl.getAttribute("height"));
    }
    return new XMLSerializer().serializeToString(svgClone);
  }

  /** Capture table HTML with portable styles, cloning and removing hidden rows. */
  function captureTableHtml(section) {
    var tableEl = section.querySelector("table.seg-table, table");
    if (!tableEl) return "";
    var tableClone = tableEl.cloneNode(true);
    var portableHtml = TurasPins.capturePortableHtml(tableEl, tableClone);
    var tableTemp = document.createElement("div");
    tableTemp.innerHTML = portableHtml;
    tableTemp.querySelectorAll('tr[style*="display: none"], tr[style*="display:none"]')
      .forEach(function(row) { row.remove(); });
    return tableTemp.innerHTML;
  }

  /** Capture fallback content for special sections with portable styles. */
  function captureSpecialContent(section, sectionKey) {
    if (sectionKey === "exec-summary") {
      var execContent = "";
      var blocks = section.querySelectorAll(
        ".seg-quality-banner, .seg-exec-block, .seg-finding-box, " +
        ".seg-key-insights-heading, .seg-callout"
      );
      blocks.forEach(function(el) { execContent += TurasPins.capturePortableHtml(el); });
      if (execContent) return '<div class="seg-pinned-exec-content">' + execContent + "</div>";
    }
    if (sectionKey === "cards") {
      var cardGrid = section.querySelector(".seg-cards-grid, .seg-profile-cards");
      if (cardGrid) return '<div class="seg-pinned-exec-content">' + TurasPins.capturePortableHtml(cardGrid) + "</div>";
    }
    return "";
  }

  /**
   * Capture content from a segment section for pinning.
   * @param {string} sectionKey - Section identifier (e.g. "overview", "validation")
   * @param {string} prefix - ID prefix (optional, default "")
   * @returns {object|null} Captured content or null if section not found
   */
  function segCaptureSectionContent(sectionKey, prefix) {
    prefix = prefix || "";
    var section = document.querySelector('[data-seg-section="' + sectionKey + '"]');
    if (!section) return null;

    var panelLabel = "";
    var headerTitle = document.querySelector(".seg-header-title");
    if (headerTitle) panelLabel = headerTitle.textContent.trim();

    var titleEl = section.querySelector(".seg-section-title");
    var sectionTitle = titleEl ? titleEl.textContent.trim() : sectionKey;

    var insightText = "";
    var insightContainer = document.getElementById("seg-insight-container-" + sectionKey);
    if (insightContainer) {
      var editor = insightContainer.querySelector(".seg-insight-editor");
      if (editor && editor.textContent.trim()) insightText = editor.textContent.trim();
    }

    var chartSvg = captureChartSvg(section);
    var tableHtml = captureTableHtml(section);

    // Fallback for special sections that use structured blocks instead of charts/tables
    if (!tableHtml && !chartSvg) {
      tableHtml = captureSpecialContent(section, sectionKey);
    }

    // Clustering metadata from header badges
    var methodText = "";
    var sampleN = "";
    document.querySelectorAll(".seg-header-badge").forEach(function(b) {
      var t = b.textContent.trim();
      if (t.match(/k-means|hierarchical|pam|cluster|gmm|mclust/i)) methodText = t;
      else if (t.match(/^n\s*=/i) || t.match(/n\s*&nbsp;\s*=\s*/i)) sampleN = t;
    });

    return {
      panelLabel: panelLabel, sectionTitle: sectionTitle,
      insightText: insightText, chartSvg: chartSvg, tableHtml: tableHtml,
      methodText: methodText, sampleN: sampleN
    };
  }

  // ── Mode Popover ────────────────────────────────────────────────────────────

  /**
   * Pin a section — always additive (each click captures a new snapshot).
   * Shows checkbox popover to select content types.
   * @param {string} sectionKey - Section key
   * @param {string} prefix - ID prefix
   */
  window.segPinSection = function(sectionKey, prefix) {
    prefix = prefix || "";

    var btn = document.querySelector(
      '.seg-pin-btn[data-seg-pin-section="' + sectionKey + '"]'
    );
    var content = segCaptureSectionContent(sectionKey, prefix);
    if (!content) return;
    var hasChart = !!content.chartSvg;
    var hasTable = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    // No button or only one content type → pin directly
    if (!btn || (!hasChart && !hasTable) ||
        (hasChart && !hasTable) || (!hasChart && hasTable)) {
      segExecutePinWithFlags(sectionKey, prefix, {
        table: hasTable, chart: hasChart, insight: hasInsight
      });
      return;
    }

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable,   checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart,   checked: hasChart },
      { key: "insight", label: "Insight", available: true,       checked: hasInsight }
    ];

    TurasPins.showCheckboxPopover(btn, checkboxes, function(flags) {
      segExecutePinWithFlags(sectionKey, prefix, flags);
    });
  };

  /**
   * Pin a specific component (chart or table) — always additive, no popover.
   * @param {string} sectionKey - Section key
   * @param {string} component - "chart" or "table"
   * @param {string} prefix - ID prefix
   */
  window.segPinComponent = function(sectionKey, component, prefix) {
    prefix = prefix || "";
    var content = segCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    var mode = component === "chart" ? "chart_insight" : "table_insight";
    var title = content.panelLabel
      ? content.panelLabel + " \u2014 " + content.sectionTitle + " \u2014 " +
        (component === "chart" ? "Chart" : "Table")
      : content.sectionTitle + " \u2014 " + (component === "chart" ? "Chart" : "Table");

    TurasPins.add({
      sectionKey: sectionKey, prefix: prefix, component: component,
      title: title, panelLabel: content.panelLabel,
      sectionTitle: content.sectionTitle,
      insightText: content.insightText,
      chartSvg: mode === "chart_insight" ? content.chartSvg : "",
      tableHtml: mode === "table_insight" ? content.tableHtml : "",
      pinMode: mode,
      methodText: content.methodText, sampleN: content.sampleN
    });
    segUpdatePinButtons();
  };

  // ── Execute Pin ────────────────────────────────────────────────────────────

  /**
   * Execute pin with flags — captures content and delegates to TurasPins.
   */
  function segExecutePinWithFlags(sectionKey, prefix, flags) {
    var content = segCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    var title = content.panelLabel
      ? content.panelLabel + " \u2014 " + content.sectionTitle
      : content.sectionTitle;

    if (!flags.chart) content.chartSvg = "";
    if (!flags.table) content.tableHtml = "";
    if (!flags.insight) content.insightText = "";

    TurasPins.add({
      sectionKey: sectionKey, prefix: prefix,
      title: title, panelLabel: content.panelLabel,
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
      methodText: content.methodText, sampleN: content.sampleN
    });
    segUpdatePinButtons();
  }

  // ── Pin Button State ───────────────────────────────────────────────────────

  function segUpdatePinButtons() {
    var pins = TurasPins.getAll();

    // Section-level pin buttons
    document.querySelectorAll(".seg-pin-btn").forEach(function(btn) {
      var sectionKey = btn.getAttribute("data-seg-pin-section");
      var prefix = btn.getAttribute("data-seg-pin-prefix") || "";
      var isPinned = false;
      for (var i = 0; i < pins.length; i++) {
        if (pins[i].type !== "section" &&
            pins[i].sectionKey === sectionKey &&
            pins[i].prefix === prefix &&
            !pins[i].component) {
          isPinned = true; break;
        }
      }
      btn.classList.toggle("seg-pin-btn-active", isPinned);
      btn.title = isPinned ? "Pinned \u2014 click to add another" : "Pin to Views";
    });

    // Component-level pin buttons (chart/table)
    document.querySelectorAll(".seg-component-pin").forEach(function(btn) {
      var sectionKey = btn.getAttribute("data-seg-pin-section");
      var prefix = btn.getAttribute("data-seg-pin-prefix") || "";
      var component = btn.getAttribute("data-seg-pin-component") || "";
      var isPinned = false;
      for (var i = 0; i < pins.length; i++) {
        if (pins[i].type !== "section" &&
            pins[i].sectionKey === sectionKey &&
            pins[i].prefix === prefix &&
            pins[i].component === component) {
          isPinned = true; break;
        }
      }
      btn.classList.toggle("seg-pin-btn-active", isPinned);
    });
  }

  // ── Global Function Delegates ──────────────────────────────────────────────

  window.segGetPinnedViews = function() { return TurasPins._getPinsRef(); };
  window.segAddSection = function(title) { TurasPins.addSection(title); };
  window.segUpdateSectionTitle = function(idx, newTitle) {
    var all = TurasPins.getAll();
    if (idx >= 0 && idx < all.length && all[idx].type === "section") {
      TurasPins.updateSectionTitle(all[idx].id, newTitle);
    }
  };
  window.segRemovePinned = function(pinId) { TurasPins.remove(pinId); segUpdatePinButtons(); };
  window.segMovePinned = function(pinId, direction) { TurasPins.move(pinId, direction); };
  window.segClearAllPinned = function() {
    TurasPins._getPinsRef([]);
    TurasPins.save();
    TurasPins.updateBadge();
    TurasPins.renderCards();
    segUpdatePinButtons();
  };
  window.segUpdatePinBadge = function() { TurasPins.updateBadge(); };
  window.segRenderPinnedCards = function() { TurasPins.renderCards(); };
  window.segExportAllPinnedPNG = function() { TurasPins.exportAll(); };
  window.segExportPinnedCardPNG = function(pinId) { TurasPins.exportCard(pinId); };
  window.segSavePinnedData = function() { TurasPins.save(); };
  window.segHydratePinnedViews = function() {
    TurasPins.load();
    TurasPins.renderCards();
    TurasPins.updateBadge();
    segUpdatePinButtons();
  };

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "seg-pinned-views-data",
      cssPrefix: "seg-pinned",
      moduleLabel: "Segment",
      containerId: "seg-pinned-cards-container",
      emptyStateId: "seg-pinned-empty",
      badgeId: "seg-pin-count-badge",
      features: {
        sections: true,
        dragDrop: true
      }
    });
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();
    segUpdatePinButtons();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
