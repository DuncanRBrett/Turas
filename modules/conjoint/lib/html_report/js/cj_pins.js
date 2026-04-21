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

  // ── Simulator CSS Wrapper ────────────────────────────────────────────────────

  /**
   * Wrap simulator snapshot HTML with embedded CSS so it renders correctly
   * outside the conjoint report's stylesheet context (e.g., in the hub pin reel).
   * Same pattern as MaxDiff's inlineSimStyles().
   * @param {string} html - Raw simulator results innerHTML
   * @returns {string} Wrapped HTML with embedded <style> block
   */
  function _wrapSimulatorStyles(html) {
    var brand = getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim() || "#323367";
    var css = ".cj-sim-results{min-height:100px}" +
      ".cj-sim-share-bar{margin:8px 0}" +
      ".cj-sim-bar-bg{height:28px;background:#f1f5f9;border-radius:4px;overflow:hidden;position:relative}" +
      ".cj-sim-bar-fill{height:100%;border-radius:4px;display:flex;align-items:center;justify-content:flex-end;padding-right:8px;color:#fff;font-size:11px;font-weight:600}" +
      ".cj-sim-mode-btns{display:flex;gap:8px;margin-bottom:16px}" +
      ".cj-sim-mode-btn{padding:6px 14px;font-size:12px;font-weight:500;border:1px solid #e2e8f0;border-radius:6px;background:#fff;color:#64748b}" +
      ".cj-sim-mode-btn.active{background:" + brand + ";color:#fff;border-color:" + brand + "}" +
      ".cj-sim-grid{width:100%;border-collapse:collapse;font-size:13px}" +
      ".cj-sim-grid th,.cj-sim-grid td{padding:6px 10px;text-align:left;vertical-align:middle}" +
      ".cj-sim-grid thead th{border-bottom:2px solid #e2e8f0}" +
      ".cj-sim-grid tbody tr{border-bottom:1px solid #f1f5f9}" +
      ".cj-sim-grid-attr-label{font-size:12px;color:#64748b;font-weight:500;white-space:nowrap;min-width:120px}" +
      ".cj-sim-snapshot svg{display:block;margin:0 auto;width:100%;height:auto}";
    return '<div style="font-family:Inter,system-ui,-apple-system,sans-serif;"><style>' + css + '</style>' + html + '</div>';
  }

  // ── Insight Tab Mapping ────────────────────────────────────────────────────

  /**
   * Map a viewId to the tab_id used for its insight editor element.
   * Returns null for views that have no associated insight area.
   * @param {string} viewId
   * @returns {string|null}
   */
  function _viewInsightTabId(viewId) {
    // Strip "pin-" prefix so both "pin-overview" (from pin button) and
    // "overview" (from export bar) resolve to the same insight editor.
    var bare = viewId.replace(/^pin-/, "");
    if (bare === "overview")                    return "overview";
    if (bare === "simulator")                   return "simulator";
    if (bare.indexOf("diagnostics") === 0)      return "diagnostics";
    if (bare.indexOf("wtp") === 0)              return "wtp";
    if (viewId.indexOf("util-") === 0)          return "utilities";
    return null;
  }

  // ── Simulator Control Staticification ─────────────────────────────────────

  /**
   * Convert interactive form controls in a simulator clone to static readable
   * equivalents so the pin/export captures meaningful content instead of blanks.
   * Selects → label badge, checkboxes → checked indicator, range → value badge,
   * pure control buttons → removed, hidden tooltips → removed.
   */
  function _staticifySimControls(clone) {
    // Remove hidden tooltip text panels (display:none, not useful in snapshot)
    clone.querySelectorAll(".cj-sim-tooltip").forEach(function(el) { el.remove(); });

    // <select> → badge showing selected option text
    clone.querySelectorAll("select").forEach(function(sel) {
      var span = document.createElement("span");
      span.style.cssText = "font-size:12px;font-weight:500;color:#1e293b;padding:2px 8px;" +
        "background:#f1f5f9;border-radius:4px;display:inline-block;";
      var opt = sel.options[sel.selectedIndex];
      span.textContent = opt ? opt.text : sel.value;
      sel.parentNode.replaceChild(span, sel);
    });

    // <input type="checkbox"> → small coloured box with tick if checked
    clone.querySelectorAll("input[type='checkbox']").forEach(function(cb) {
      var span = document.createElement("span");
      var checked = cb.checked;
      span.style.cssText = "display:inline-flex;align-items:center;justify-content:center;" +
        "width:13px;height:13px;border:1.5px solid " + (checked ? "#323367" : "#94a3b8") + ";" +
        "border-radius:2px;background:" + (checked ? "#323367" : "#fff") + ";" +
        "vertical-align:middle;margin-right:3px;font-size:9px;color:#fff;line-height:1;";
      span.textContent = checked ? "\u2713" : "";
      cb.parentNode.replaceChild(span, cb);
    });

    // <input type="range"> → value badge
    clone.querySelectorAll("input[type='range']").forEach(function(inp) {
      var span = document.createElement("span");
      span.style.cssText = "font-size:12px;font-weight:600;color:#1e293b;padding:2px 8px;" +
        "background:#f1f5f9;border-radius:4px;display:inline-block;";
      span.textContent = parseFloat(inp.value).toFixed(1);
      inp.parentNode.replaceChild(span, inp);
    });

    // All remaining <input> → plain value text
    clone.querySelectorAll("input").forEach(function(inp) {
      var span = document.createElement("span");
      span.style.cssText = "font-size:12px;color:#1e293b;";
      span.textContent = inp.value || "";
      inp.parentNode.replaceChild(span, inp);
    });

    // Pure control buttons → remove entirely
    clone.querySelectorAll("button").forEach(function(btn) { btn.remove(); });
  }

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
      _staticifySimControls(resultsClone);
      // Constrain SVGs to their natural size
      resultsClone.querySelectorAll("svg").forEach(function(svg) {
        var w = svg.getAttribute("width");
        if (w) svg.style.maxWidth = w + "px";
        svg.style.width = "100%";
        svg.style.height = "auto";
      });
      var simInsightTabId = _viewInsightTabId(viewId);
      var simInsightText = "";
      if (simInsightTabId) {
        var simInsightEl = document.getElementById("insight-editor-" + simInsightTabId);
        if (simInsightEl && simInsightEl.textContent.trim()) {
          simInsightText = simInsightEl.textContent.trim();
        }
      }
      return {
        title: title,
        chartSvg: "",
        tableHtml: _wrapSimulatorStyles(resultsClone.innerHTML),
        insightText: simInsightText
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
        tableHtml = TurasPins.capturePortableHtml(tableEl);
      }
    }

    // Insight text — look up the editor by its tab-specific ID
    var insightText = "";
    var insightTabId = _viewInsightTabId(viewId);
    if (insightTabId) {
      var insightEl = document.getElementById("insight-editor-" + insightTabId);
      if (insightEl && insightEl.textContent.trim()) {
        insightText = insightEl.textContent.trim();
      }
    }

    return {
      title: title,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      insightText: insightText
    };
  }

  // ── Mode Popover ───────────────────────────────────────────────────────────

  /**
   * Pin a view — always additive. Shows checkbox popover first.
   * @param {string} viewId - View identifier
   * @param {HTMLElement} btnEl - Button that triggered
   */
  window.cjPinSection = function(viewId, btnEl) {
    // Simulator: always pin full snapshot directly (no mode choice)
    if (viewId === "pin-simulator") {
      cjExecutePinWithFlags(viewId, { table: true, chart: true, insight: true });
      return;
    }

    var content = cjCaptureContent(viewId, "all");
    if (!content) return;
    var hasChart = !!content.chartSvg;
    var hasTable = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    // No button or nothing to pin → pin directly with defaults
    if (!btnEl || (!hasChart && !hasTable)) {
      cjExecutePinWithFlags(viewId, {
        table: hasTable,
        chart: hasChart,
        insight: hasInsight
      });
      return;
    }

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable,   checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart,   checked: hasChart },
      { key: "insight", label: "Insight", available: true,       checked: hasInsight }
    ];

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      cjExecutePinWithFlags(viewId, flags);
    });
  };

  // Backward compat: old pin buttons call showPinPopover
  window.showPinPopover = function(viewId, btnEl) {
    window.cjPinSection(viewId, btnEl);
  };

  // ── Export PNG ─────────────────────────────────────────────────────────────

  /**
   * Export current view as PNG — uses the identical checkbox popover and content
   * capture as cjPinSection, but renders via TurasPins.exportContentAsPNG
   * (same visual output as a pinned card) and downloads immediately.
   * @param {string} viewId - View identifier
   * @param {HTMLElement} btnEl - Button that triggered
   */
  window.cjExportPNG = function(viewId, btnEl) {
    // Export bar passes "simulator"; pin button passes "pin-simulator".
    // Normalise so the simulator innerHTML capture path fires correctly.
    if (viewId === "simulator") viewId = "pin-simulator";

    if (viewId === "pin-simulator") {
      var simContent = cjCaptureContent(viewId, "all");
      if (!simContent) return;
      TurasPins.exportContentAsPNG({
        title:       simContent.title,
        sourceLabel: "Conjoint",
        chartSvg:    simContent.chartSvg,
        tableHtml:   simContent.tableHtml,
        insightText: simContent.insightText,
        pinFlags:    { chart: true, table: true, insight: true }
      });
      return;
    }

    var content = cjCaptureContent(viewId, "all");
    if (!content) return;
    var hasChart   = !!content.chartSvg;
    var hasTable   = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    if (!btnEl || (!hasChart && !hasTable)) {
      TurasPins.exportContentAsPNG({
        title:       content.title,
        sourceLabel: "Conjoint",
        chartSvg:    content.chartSvg,
        tableHtml:   content.tableHtml,
        insightText: content.insightText,
        pinFlags:    { chart: hasChart, table: hasTable, insight: hasInsight }
      });
      return;
    }

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable,   checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart,   checked: hasChart },
      { key: "insight", label: "Insight", available: true,       checked: hasInsight }
    ];

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      var c = cjCaptureContent(viewId, "all");
      if (!c) return;
      TurasPins.exportContentAsPNG({
        title:       c.title,
        sourceLabel: "Conjoint",
        chartSvg:    flags.chart   ? c.chartSvg    : "",
        tableHtml:   flags.table   ? c.tableHtml   : "",
        insightText: flags.insight ? c.insightText : "",
        pinFlags:    { chart: !!flags.chart, table: !!flags.table, insight: !!flags.insight }
      });
    }, null, { title: "EXPORT AS PNG", actionLabel: "Export" });
  };

  /**
   * Execute pin with flags — captures content and delegates to TurasPins.
   */
  function cjExecutePinWithFlags(viewId, flags) {
    var content = cjCaptureContent(viewId, "all");
    if (!content) return;

    if (!flags.chart)   content.chartSvg   = "";
    if (!flags.table)   content.tableHtml  = "";
    if (!flags.insight) content.insightText = "";

    TurasPins.add({
      sectionKey: viewId,
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
  }

  // ── Global Function Delegates ──────────────────────────────────────────────
  // Print overlay is in cj_pins_print.js

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
