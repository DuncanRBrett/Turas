/**
 * TURAS Keydriver Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles keydriver-specific content capture: section charts, tables,
 * insights, exec-summary findings, and method metadata.
 *
 * Also manages qualitative slides (image upload, markdown editing,
 * pin-to-views) — a keydriver-specific feature.
 *
 * Pins are always additive — each click captures a new snapshot.
 * Mode popover lets user choose: Table + Chart / Chart only / Table only.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 */

/* global TurasPins, kdEscapeHtml */

(function() {
  "use strict";

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Capture content from a keydriver section for pinning.
   * @param {string} sectionKey - Section identifier
   * @param {string} prefix - ID prefix for multi-analysis reports
   * @returns {object|null} Captured content or null if section not found
   */
  function kdCaptureSectionContent(sectionKey, prefix) {
    var sectionId = prefix + "kd-" + sectionKey;
    var section = document.getElementById(sectionId);
    if (!section) return null;

    // Panel label (analysis name)
    var panelLabel = "";
    var panel = section.closest(".kd-analysis-panel");
    if (panel) {
      var heading = panel.querySelector(".kd-panel-heading-title");
      panelLabel = heading ? heading.textContent.trim() : "";
      if (!panelLabel && panel.id === "kd-tab-overview") panelLabel = "Overview";
    }

    // Section title
    var titleEl = section.querySelector(".kd-section-title");
    var sectionTitle = titleEl ? titleEl.textContent.trim() : sectionKey;

    // Insight text
    var insightText = "";
    var insightContainer = document.getElementById(prefix + "kd-insight-container-" + sectionKey);
    if (insightContainer) {
      var editor = insightContainer.querySelector(".kd-insight-editor");
      if (editor && editor.textContent.trim()) insightText = editor.textContent.trim();
    }

    // Chart SVG — Bug #7 fix: ensure viewBox transfers to clone
    var chartSvg = "";
    var svgEl = section.querySelector(
      ".kd-chart-wrapper svg, .kd-chart-container svg, svg.kd-importance-chart, svg.kd-chart"
    );
    if (svgEl) {
      var svgClone = svgEl.cloneNode(true);
      // Ensure viewBox and explicit dimensions on the clone
      var vb = svgEl.getAttribute("viewBox");
      if (vb) {
        svgClone.setAttribute("viewBox", vb);
        var parts = vb.split(/[\s,]+/);
        if (parts.length >= 4) {
          var vbW = parseFloat(parts[2]);
          var vbH = parseFloat(parts[3]);
          if (vbW > 0 && vbH > 0) {
            svgClone.setAttribute("width", vbW);
            svgClone.setAttribute("height", vbH);
          }
        }
      }
      if (!svgClone.getAttribute("viewBox")) {
        var rect = svgEl.getBoundingClientRect();
        if (rect.width > 0 && rect.height > 0) {
          svgClone.setAttribute("viewBox", "0 0 " + Math.round(rect.width) + " " + Math.round(rect.height));
          svgClone.setAttribute("width", Math.round(rect.width));
          svgClone.setAttribute("height", Math.round(rect.height));
        }
      }
      chartSvg = new XMLSerializer().serializeToString(svgClone);
    }

    // Table HTML
    var tableHtml = "";
    var tableEl = section.querySelector("table.kd-table, table.kd-comp-table, table.kd-quadrant-action-table");
    if (tableEl) {
      var tableClone = tableEl.cloneNode(true);
      var hidden = tableClone.querySelectorAll(
        'tr[style*="display: none"], tr[style*="display:none"]'
      );
      hidden.forEach(function(row) { row.remove(); });
      tableHtml = tableClone.outerHTML;
    }

    // Overview card grids and insight elements
    if (sectionKey === "summary-cards" && !tableHtml && !chartSvg) {
      var cardGrid = section.querySelector(".kd-comp-cards");
      if (cardGrid) tableHtml = '<div class="kd-pinned-exec-content">' + cardGrid.outerHTML + "</div>";
    }
    if (sectionKey === "key-insights" && !tableHtml && !chartSvg) {
      var insightEls = section.querySelectorAll(".kd-comp-insight");
      if (insightEls.length > 0) {
        var insHtml = "";
        insightEls.forEach(function(el) { insHtml += el.outerHTML; });
        tableHtml = '<div class="kd-pinned-exec-content">' + insHtml + "</div>";
      }
    }

    // Exec-summary: key insights + findings
    if (sectionKey === "exec-summary") {
      var execContent = "";
      var insightsList = section.querySelector(".kd-key-insights-heading");
      if (insightsList && insightsList.parentElement) execContent += insightsList.parentElement.outerHTML;
      var findingBox = section.querySelector(".kd-finding-box");
      if (findingBox) execContent += findingBox.outerHTML;
      if (execContent) tableHtml = '<div class="kd-pinned-exec-content">' + execContent + "</div>";
    }

    // Diagnostics table
    if (sectionKey === "diagnostics" && !chartSvg) {
      var diagTable = section.querySelector("table.kd-diagnostics-table");
      if (diagTable) tableHtml = diagTable.outerHTML;
    }

    // Metadata from panel stats or header badges
    var methodText = "", sampleN = "";
    var statSources = panel ? panel.querySelectorAll(".kd-panel-stat") : [];
    if (statSources.length === 0) statSources = document.querySelectorAll(".kd-header-badge");
    statSources.forEach(function(stat) {
      var t = stat.textContent.trim();
      if (t.match(/correlation/i) || t.match(/regression/i)) methodText = t;
      else if (t.match(/^n\s*=/i)) sampleN = t;
    });

    return {
      panelLabel: panelLabel, sectionTitle: sectionTitle,
      insightText: insightText, chartSvg: chartSvg, tableHtml: tableHtml,
      methodText: methodText, sampleN: sampleN
    };
  }

  // ── Mode Popover ───────────────────────────────────────────────────────────

  function kdClosePopover() {
    var p = document.getElementById("kd-pin-popover");
    if (p) p.remove();
    document.removeEventListener("click", kdClosePopoverOnOutside);
  }

  function kdClosePopoverOnOutside(e) {
    var p = document.getElementById("kd-pin-popover");
    if (p && !p.contains(e.target)) kdClosePopover();
  }

  /**
   * Pin a section — always additive (each click captures a new snapshot).
   * Shows mode popover to select chart/table/both.
   */
  window.kdPinSection = function(sectionKey, prefix) {
    prefix = prefix || "";

    var btn = document.querySelector('.kd-pin-btn[data-kd-pin-section="' + sectionKey + '"]');
    if (!btn) { kdExecutePin(sectionKey, prefix, "all"); return; }

    kdClosePopover();
    var content = kdCaptureSectionContent(sectionKey, prefix);
    var hasChart = content && content.chartSvg;
    var hasTable = content && content.tableHtml;

    var popover = document.createElement("div");
    popover.className = "kd-pin-popover";
    popover.id = "kd-pin-popover";

    var options = [
      { label: "Table + Chart", mode: "all", enabled: hasChart && hasTable },
      { label: "Chart only", mode: "chart_insight", enabled: !!hasChart },
      { label: "Table only", mode: "table_insight", enabled: !!hasTable }
    ];

    options.forEach(function(opt) {
      var item = document.createElement("button");
      item.className = "kd-pin-popover-item";
      item.textContent = opt.label;
      if (!opt.enabled) {
        item.disabled = true;
        item.style.opacity = "0.4";
        item.style.cursor = "default";
      } else {
        item.onclick = function(e) {
          e.stopPropagation();
          kdExecutePin(sectionKey, prefix, opt.mode);
          kdClosePopover();
        };
      }
      popover.appendChild(item);
    });

    btn.parentElement.style.position = "relative";
    btn.parentElement.appendChild(popover);
    setTimeout(function() {
      document.addEventListener("click", kdClosePopoverOnOutside);
    }, 10);
  };

  /**
   * Execute pin with selected mode — captures content and delegates to TurasPins.
   */
  function kdExecutePin(sectionKey, prefix, mode) {
    var content = kdCaptureSectionContent(sectionKey, prefix);
    if (!content) return;

    var title = content.panelLabel
      ? content.panelLabel + " \u2014 " + content.sectionTitle
      : content.sectionTitle;

    TurasPins.add({
      sectionKey: sectionKey,
      prefix: prefix,
      title: title,
      panelLabel: content.panelLabel,
      sectionTitle: content.sectionTitle,
      insightText: content.insightText,
      chartSvg: (mode === "all" || mode === "chart_insight") ? content.chartSvg : "",
      tableHtml: (mode === "all" || mode === "table_insight") ? content.tableHtml : "",
      pinMode: mode,
      methodText: content.methodText,
      sampleN: content.sampleN
    });
    kdUpdatePinButtons();
  }

  // ── Pin Button State ───────────────────────────────────────────────────────

  function kdUpdatePinButtons() {
    var pins = TurasPins.getAll();
    document.querySelectorAll(".kd-pin-btn").forEach(function(btn) {
      var sectionKey = btn.getAttribute("data-kd-pin-section");
      var prefix = btn.getAttribute("data-kd-pin-prefix") || "";
      var isPinned = false;
      for (var i = 0; i < pins.length; i++) {
        if (pins[i].type !== "section" &&
            pins[i].sectionKey === sectionKey &&
            pins[i].prefix === prefix) {
          isPinned = true;
          break;
        }
      }
      btn.classList.toggle("kd-pin-btn-active", isPinned);
      btn.title = isPinned ? "Unpin this section" : "Pin to Views";
    });
  }

  // ── Global Function Delegates ──────────────────────────────────────────────

  window.kdGetPinnedViews = function() { return TurasPins._getPinsRef(); };
  window.kdAddSection = function(title) { TurasPins.addSection(title); };
  window.kdUpdateSectionTitle = function(idx, newTitle) {
    var all = TurasPins.getAll();
    if (idx >= 0 && idx < all.length && all[idx].type === "section") {
      TurasPins.updateSectionTitle(all[idx].id, newTitle);
    }
  };
  window.kdRemovePinned = function(pinId) { TurasPins.remove(pinId); kdUpdatePinButtons(); };
  window.kdMovePinned = function(pinId, direction) { TurasPins.move(pinId, direction); };
  window.kdClearAllPinned = function() {
    TurasPins._getPinsRef([]);
    TurasPins.save();
    TurasPins.updateBadge();
    TurasPins.renderCards();
    kdUpdatePinButtons();
  };
  window.kdUpdatePinBadge = function() { TurasPins.updateBadge(); };
  window.kdRenderPinnedCards = function() { TurasPins.renderCards(); };
  window.kdExportAllPinnedPNG = function() { TurasPins.exportAll(); };
  window.kdExportPinnedCardPNG = function(pinId) { TurasPins.exportCard(pinId); };
  window.kdSavePinnedData = function() { TurasPins.save(); };
  window.kdHydratePinnedViews = function() {
    TurasPins.load();
    TurasPins.renderCards();
    TurasPins.updateBadge();
    kdUpdatePinButtons();
  };

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "kd-pinned-views-data",
      cssPrefix: "kd-pinned",
      moduleLabel: "Key Driver",
      containerId: "kd-pinned-cards-container",
      emptyStateId: "kd-pinned-empty",
      badgeId: "kd-pin-count-badge",
      features: {
        insightEdit: true,
        sections: true,
        dragDrop: true
      }
    });
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();
    kdUpdatePinButtons();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
