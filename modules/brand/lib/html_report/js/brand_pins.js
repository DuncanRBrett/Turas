// ==============================================================================
// BRAND REPORT - TURAS PINS WRAPPER
// ==============================================================================
// Thin wrapper around the shared TurasPins library.
// Handles content capture for brand-specific sections and delegates
// to TurasPins.add() for pinning.
// ==============================================================================

(function() {
  "use strict";

  // --- Is element currently visible? ---
  function isVisible(el) {
    return !!el && el.offsetParent !== null;
  }

  // --- Extract capture payload from a given root element ---
  function captureFromRoot(root, sectionKey) {
    if (!root) return null;

    var title = root.querySelector(".br-element-title, h2, h3, .pfo-section-title");
    var titleText = title ? title.textContent.trim() : (sectionKey || "");

    // Pick the first *visible* SVG in the subtree — handles panels that hold
    // several sibling SVGs where only the active one is displayed.
    var svg = null;
    var svgs = root.querySelectorAll("svg");
    for (var si = 0; si < svgs.length; si++) {
      if (isVisible(svgs[si])) { svg = svgs[si]; break; }
    }
    if (!svg && svgs.length > 0) svg = svgs[0];

    var chartSvg = "";
    if (svg) {
      var clone = svg.cloneNode(true);
      var vb = svg.getAttribute("viewBox");
      if (vb) {
        var parts = vb.split(/\s+/);
        clone.setAttribute("width", parts[2]);
        clone.setAttribute("height", parts[3]);
      }
      chartSvg = clone.outerHTML;
    }

    // Pick first *visible* table matching known classes, then any visible table.
    var tableSelectors = [
      "table.br-table", "table.pfo-table", "table.fn-table",
      "table.ma-table", "table.ma-matrix", "table"
    ];
    var table = null;
    for (var ts = 0; ts < tableSelectors.length && !table; ts++) {
      var candidates = root.querySelectorAll(tableSelectors[ts]);
      for (var ti = 0; ti < candidates.length; ti++) {
        if (isVisible(candidates[ti])) { table = candidates[ti]; break; }
      }
    }
    if (!table) {
      var fallback = root.querySelector("table");
      if (fallback) table = fallback;
    }

    var tableHtml = "";
    if (table && typeof TurasPins !== "undefined" && TurasPins.capturePortableHtml) {
      tableHtml = TurasPins.capturePortableHtml(table);
    } else if (table) {
      tableHtml = table.outerHTML;
    }

    var editor = root.querySelector(".br-insight-editor");
    var insightText = editor ? editor.value.trim() : "";

    return {
      sectionKey: sectionKey || (root.id || ""),
      title: titleText,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      insightText: insightText
    };
  }

  // --- Content capture (by section_id string) ---
  function brCaptureContent(sectionId) {
    var section = document.getElementById("section-" + sectionId);
    // Portfolio subtabs use pf-subtab-<id> wrappers (e.g. pf-subtab-overview).
    // Check this BEFORE the generic [data-section] query, because pin buttons
    // also carry data-section and would otherwise match first.
    if (!section && /^pf-/.test(sectionId)) {
      var subId = sectionId.replace(/^pf-/, "pf-subtab-");
      section = document.getElementById(subId);
    }
    if (!section) {
      // Find a container (not a button) that declares data-section
      var candidates = document.querySelectorAll('[data-section="' + sectionId + '"]');
      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].tagName !== "BUTTON") { section = candidates[i]; break; }
      }
    }
    if (!section) return null;
    return captureFromRoot(section, sectionId);
  }

  // --- Toggle pin (show checkbox popover) ---
  window.brTogglePin = function(sectionId) {
    if (typeof TurasPins === "undefined") return;

    var btn = document.querySelector('.br-pin-btn[data-section="' + sectionId + '"]');
    if (!btn) return;

    var section = document.getElementById("section-" + sectionId) ||
                  document.querySelector('[data-section="' + sectionId + '"]');
    if (!section) return;

    var hasChart = !!section.querySelector("svg");
    var hasTable = !!section.querySelector("table.br-table");
    var hasInsight = false;
    var editor = section.querySelector(".br-insight-editor");
    if (editor && editor.value.trim()) hasInsight = true;

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable, checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart, checked: hasChart },
      { key: "insight", label: "Insight", available: true,     checked: hasInsight }
    ];

    var anchor = btn.closest(".br-section-toolbar") || btn.parentElement;
    TurasPins.showCheckboxPopover(btn, checkboxes, function(flags) {
      brExecutePin(sectionId, flags);
    }, anchor);
  };

  // Portfolio subtabs (footprint/constellation/clutter) lack an H3; map the
  // section id to the user-facing subtab label so pins and PNG exports show a
  // meaningful header instead of "pf-footprint".
  function applyPortfolioTitleFallback(content, sectionId) {
    if (!/^pf-/.test(sectionId)) return;
    if (content.title && content.title !== sectionId) return;
    var pfLabels = {
      "pf-overview":      "Portfolio Overview",
      "pf-footprint":     "Portfolio Footprint",
      "pf-constellation": "Competitive Set",
      "pf-clutter":       "Category Context",
      "pf-extension":     "Portfolio Extension"
    };
    if (pfLabels[sectionId]) content.title = pfLabels[sectionId];
  }

  function brExecutePin(sectionId, flags) {
    var content = brCaptureContent(sectionId);
    if (!content) return;
    applyPortfolioTitleFallback(content, sectionId);

    content.pinFlags = {
      chart:   !!flags.chart,
      table:   !!flags.table,
      insight: !!flags.insight
    };
    content.pinMode = "custom";

    if (!flags.chart)   content.chartSvg = "";
    if (!flags.table)   content.tableHtml = "";
    if (!flags.insight) content.insightText = "";

    TurasPins.add(content);

    // Flash pin button
    var btn = document.querySelector('.br-pin-btn[data-section="' + sectionId + '"]');
    if (btn) {
      btn.classList.add("pin-flash");
      setTimeout(function() { btn.classList.remove("pin-flash"); }, 600);
    }
  }

  // --- Pin individual chart ---
  window.brPinChart = function(btnEl, chartTitle) {
    if (typeof TurasPins === "undefined") return;
    var wrapper = btnEl.closest(".br-chart-wrapper");
    if (!wrapper) return;
    var svg = wrapper.querySelector("svg");
    if (!svg) return;

    var clone = svg.cloneNode(true);
    var vb = svg.getAttribute("viewBox");
    if (vb) {
      var parts = vb.split(/\s+/);
      clone.setAttribute("width", parts[2]);
      clone.setAttribute("height", parts[3]);
    }

    TurasPins.add({
      sectionKey: "chart-" + Date.now(),
      title: chartTitle || "Chart",
      chartSvg: clone.outerHTML,
      tableHtml: "",
      insightText: "",
      pinMode: "chart_insight"
    });
  };

  // --- Export section content as PNG (no pin save) ---
  window.brExportPng = function(sectionId) {
    if (typeof TurasPins === "undefined") return;
    var content = brCaptureContent(sectionId);
    if (!content) return;
    applyPortfolioTitleFallback(content, sectionId);
    // Flag all available parts so export renders chart + table + insight if present
    content.pinFlags = {
      chart:   !!content.chartSvg,
      table:   !!content.tableHtml,
      insight: !!content.insightText
    };
    content.pinMode = "custom";
    if (typeof TurasPins.exportContentAsPNG === "function") {
      TurasPins.exportContentAsPNG(content);
    }
  };

  // --- Export the enclosing sub-view (or element-section) as PNG ---
  // Used by panels (funnel/MA) whose buttons sit inside controls bars. The
  // nearest MA subtab or funnel subtab is preferred over the outer element
  // section, so switching sub-tabs pins only what's currently visible.
  window.brExportPngFromEl = function(btnEl) {
    if (typeof TurasPins === "undefined" || !btnEl) return;
    var scope = btnEl.closest(".ma-section[data-ma-stim]")
             || btnEl.closest(".ma-subtab[data-ma-subtab]")
             || btnEl.closest(".ma-subtab")
             || btnEl.closest(".fn-subtab")
             || btnEl.closest(".br-element-section");
    if (!scope) return;
    var stim = scope.getAttribute("data-ma-stim")
            || scope.getAttribute("data-ma-subtab");
    var sid = scope.getAttribute("data-section")
           || stim
           || (scope.id || "").replace(/^section-/, "")
           || "export-" + Date.now();
    var content = captureFromRoot(scope, sid);
    if (!content) return;

    // Resolve category label from the enclosing category panel.
    var catPanel = btnEl.closest(".br-panel");
    var catLabel = "";
    if (catPanel) {
      var catBtn = document.querySelector('.br-tab-btn[onclick*="' + (catPanel.id || "").replace(/^panel-/, "") + '"]');
      if (catBtn) catLabel = (catBtn.textContent || "").trim();
    }

    // Friendlier titles for MA/funnel scopes that lack a heading element.
    if (stim) {
      var maTitle = (stim === "attributes") ? "Brand Attributes"
                  : (stim === "ceps")       ? "Category Entry Points"
                  : (stim === "metrics")    ? "Headline Metrics"
                  : stim;
      if (!content.title || content.title === sid) {
        content.title = maTitle + (catLabel ? " \u2014 " + catLabel : "");
      }
    } else if (scope.classList && scope.classList.contains("fn-subtab")) {
      if (!content.title || content.title === sid) {
        content.title = "Funnel" + (catLabel ? " \u2014 " + catLabel : "");
      }
    }

    content.pinFlags = {
      chart:   !!content.chartSvg,
      table:   !!content.tableHtml,
      insight: !!content.insightText
    };
    content.pinMode = "custom";
    if (typeof TurasPins.exportContentAsPNG === "function") {
      TurasPins.exportContentAsPNG(content);
    }
  };

  // --- Export all pinned as PNG ---
  window.brExportAllPinned = function() {
    if (typeof TurasPins === "undefined") return;
    if (typeof TurasPins.exportAll === "function") {
      TurasPins.exportAll();
    } else if (typeof TurasPins.exportAllPng === "function") {
      TurasPins.exportAllPng();
    }
  };

  // --- Add section divider ---
  window.brAddSection = function(title) {
    if (typeof TurasPins !== "undefined" && TurasPins.addSection) {
      TurasPins.addSection(title);
    }
  };

  // --- Init TurasPins ---
  function initPins() {
    if (typeof TurasPins === "undefined") return;

    TurasPins.init({
      storeId: "br-pinned-views-data",
      cssPrefix: "br-pinned",
      moduleLabel: "Brand",
      containerId: "br-pinned-cards-container",
      emptyStateId: "br-pinned-empty",
      badgeId: "br-pin-count-badge",
      features: { sections: true, dragDrop: true }
    });

    if (TurasPins._initDragDrop) TurasPins._initDragDrop();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPins);
  } else {
    initPins();
  }
})();
