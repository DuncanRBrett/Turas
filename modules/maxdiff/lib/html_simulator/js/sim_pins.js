/**
 * TURAS MaxDiff Simulator — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles simulator-specific content capture: snapshot builders for
 * overview, shares, h2h, portfolio, and diagnostics tabs.
 *
 * Bug #3 fix: Writes pins to #pinned-views-data DOM store so
 * hub bridge (MutationObserver) can detect and forward pins.
 *
 * Depends on: TurasPins shared library, SimEngine, SimCharts, SimUI
 */

/* global TurasPins, SimEngine, SimCharts, SimUI */

var SimPins = (function() {
  "use strict";

  // ── Helpers ────────────────────────────────────────────────────────────────

  function esc(str) {
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(str || ""));
    return div.innerHTML;
  }

  // ── DOM-based Content Capture ────────────────────────────────────────────

  /**
   * Clone visible content from a simulator panel, stripping controls.
   * Returns the innerHTML of the cloned panel with interactive elements removed.
   */
  function clonePanelContent(panelId) {
    var panel = document.getElementById(panelId);
    if (!panel) return "";
    var clone = panel.cloneNode(true);
    // Remove interactive controls, toolbars, buttons, selects, inputs, callout boxes
    clone.querySelectorAll(".sim-toolbar, .sim-panel-header, .sim-insight-block, " +
      ".sim-callout, .sim-h2h-remove-btn, .sim-h2h-controls, " +
      ".sim-portfolio-controls, .sim-portfolio-grid, " +
      ".sim-filter, " +
      "select, button, input, .sim-seg-filter, " +
      "[id$='-callout']").forEach(function(el) { el.remove(); });
    // Remove any hidden elements
    clone.querySelectorAll("[style*='display: none'], [style*='display:none']").forEach(function(el) { el.remove(); });
    // Constrain SVGs to their natural size (don't let pin card blow them up)
    clone.querySelectorAll("svg").forEach(function(svg) {
      var w = svg.getAttribute("width");
      if (w) svg.style.maxWidth = w + "px";
      svg.style.height = "auto";
    });
    return clone.innerHTML;
  }

  /**
   * Inline key CSS styles from the simulator stylesheet into cloned HTML
   * so the pin renders correctly in the parent report context.
   */
  function inlineSimStyles(html) {
    var brand = (SimCharts && SimCharts.getBrandColour) ? SimCharts.getBrandColour() : "#1e3a5f";
    // Wrap in a container that carries the essential simulator styles inline
    return '<div style="font-family:Inter,system-ui,-apple-system,sans-serif;">' +
      '<style>' +
      '.sim-h2h{margin:8px 0 16px}' +
      '.sim-h2h-bar{display:flex;height:44px;border-radius:6px;overflow:hidden}' +
      '.sim-h2h-a,.sim-h2h-b{display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:16px;min-width:40px}' +
      '.sim-h2h-labels{display:flex;justify-content:space-between;margin-top:6px;font-size:12px;font-weight:500;color:#475569}' +
      '.sim-h2h-slot-controls{border-bottom:1px solid #f1f5f9;padding-bottom:14px;margin-bottom:14px}' +
      '.sim-h2h-slot-controls:last-of-type{border-bottom:none}' +
      '.sim-h2h-slot-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:6px}' +
      '.sim-h2h-slot-num{font-size:12px;font-weight:600;color:#94a3b8;text-transform:uppercase;letter-spacing:.05em}' +
      '.sim-bar-row{display:flex;align-items:center;margin-bottom:5px}' +
      '.sim-bar-label{width:170px;font-size:12px;font-weight:500;text-align:right;padding-right:10px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#334155}' +
      '.sim-bar-track{flex:1;height:28px;background:#f1f5f9;border-radius:4px;overflow:hidden}' +
      '.sim-bar-fill{height:100%;border-radius:4px}' +
      '.sim-bar-value{width:58px;font-size:12px;font-weight:600;text-align:right;padding-left:8px;color:#334155}' +
      '.sim-turf-gauge{display:flex;align-items:center;gap:24px;margin:16px 0}.sim-turf-gauge svg{max-width:120px!important;width:120px!important;height:120px!important}' +
      '.sim-turf-stats{font-size:13px;color:#64748b}.sim-turf-stats div{margin-bottom:4px}' +
      '.sim-turf-opt-list{margin-top:14px;font-size:13px}.sim-turf-opt-list ol{padding-left:22px}.sim-turf-opt-list li{margin-bottom:4px}' +
      '.sim-stat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px}' +
      '.sim-stat-card{background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:12px 14px}' +
      '.sim-stat-value{font-size:22px;font-weight:700;color:' + brand + '}' +
      '.sim-stat-label{font-size:11px;font-weight:500;color:#64748b;text-transform:uppercase;letter-spacing:.05em}' +
      '.sim-stat-sub{font-size:11px;color:#94a3b8;margin-top:2px}' +
      '.sim-seg-table{width:100%;border-collapse:collapse}.sim-seg-table th{background:#f8fafc;font-weight:600;font-size:11px;padding:8px 12px;border-bottom:2px solid #e2e8f0;text-align:left}' +
      '.sim-seg-table td{padding:8px 12px;border-bottom:1px solid #f1f5f9;font-size:12px}.sim-seg-item{font-weight:500}' +
      '</style>' + html + '</div>';
  }

  /**
   * Get the segment label for a given tab's segment filter.
   */
  function getSegLabel(tabId) {
    var filterIdMap = {
      shares: "seg-filter-shares",
      h2h: "seg-filter-h2h",
      portfolio: "seg-filter-turf"
    };
    var filterId = filterIdMap[tabId];
    return filterId && window.SimUI ? window.SimUI.getSegLabel(filterId) : null;
  }

  /**
   * Get display title for a simulator tab.
   */
  function getTabTitle(tabId) {
    var titles = {
      overview: "Overview",
      shares: "Preference Shares",
      h2h: "Head-to-Head",
      portfolio: "Portfolio (TURF)",
      diagnostics: "Diagnostics"
    };
    var title = titles[tabId] || tabId;
    var segLabel = getSegLabel(tabId);
    if (segLabel) title += " \u2014 " + segLabel;
    return title;
  }

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Capture the current view from a simulator tab by cloning the DOM.
   * @param {string} tabId - "overview", "shares", "h2h", "portfolio", "diagnostics"
   */
  function captureView(tabId) {
    var panelIdMap = {
      overview: "panel-overview",
      shares: "panel-shares",
      h2h: "panel-h2h",
      portfolio: "panel-portfolio",
      diagnostics: "panel-diagnostics"
    };
    var panelId = panelIdMap[tabId];
    if (!panelId) return;

    var titles = {
      overview: "Simulator: Overview",
      shares: "Simulator: Preference Shares",
      h2h: "Simulator: Head-to-Head",
      portfolio: "Simulator: Portfolio (TURF)",
      diagnostics: "Simulator: Diagnostics"
    };
    var title = titles[tabId] || "Simulator: " + tabId;
    var segLabel = getSegLabel(tabId);

    var contentHtml = clonePanelContent(panelId);

    // Capture insight text if present
    var insightEditor = document.getElementById("insight-" + tabId);
    var insightText = insightEditor ? insightEditor.innerHTML.replace(/&nbsp;/g, " ").trim() : "";

    // Wrap with inlined styles so pin renders properly in parent report
    var styledHtml = inlineSimStyles(contentHtml);

    // Build subtitle with segment context — always show which segment was viewed
    var subtitleText = "";
    if (tabId === "h2h" || tabId === "portfolio" || tabId === "shares") {
      subtitleText = segLabel ? "Segment: " + segLabel : "Segment: All respondents";
    }

    var pinData = {
      title: title,
      subtitle: subtitleText,
      tabId: tabId,
      chartHtml: styledHtml,
      insight: insightText,
      pinMode: "all"
    };

    // If embedded in iframe, forward pin to parent report's pinned views
    if (window.parent && window.parent !== window) {
      window.parent.postMessage({
        type: "turas-sim-pin",
        pin: pinData
      }, "*");
      TurasPins._showToast("Pinned to report views");
    } else {
      // Standalone mode — pin locally
      if (typeof TurasPins !== "undefined" && TurasPins.getConfig()) {
        TurasPins.add(pinData);
      }
    }
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  var _initRetries = 0;
  function init() {
    // TurasPins still needed for standalone mode and toast notifications
    if (typeof TurasPins !== "undefined" && typeof TurasPins.init === "function") {
      TurasPins.init({
        storeId: "pinned-views-data",
        cssPrefix: "sim-pin",
        moduleLabel: "MaxDiff Simulator",
        containerId: "pins-container",
        emptyStateId: "sim-pins-empty",
        badgeId: "pin-badge",
        features: { insightEdit: true, sections: false, dragDrop: false }
      });
    } else if (_initRetries < 5) {
      _initRetries++;
      setTimeout(init, 200);
      return;
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  return { captureView: captureView };
})();
