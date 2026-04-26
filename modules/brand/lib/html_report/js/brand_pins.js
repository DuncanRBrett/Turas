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

  // --- Strip interactive controls from a captured HTML fragment ---
  // Pinned cards must read like a snapshot, not a live UI: sort buttons,
  // toolbars, info-callouts, hidden inputs, and stray onclick handlers
  // all get removed. Class list is intentionally brand-specific so the
  // generic shared TurasPins library stays unaware of brand DOM details.
  var INTERACTIVE_SELECTORS = [
    'button', 'input', 'select',
    '.ct-sort-indicator', '.row-exclude-btn',
    '.cb-info-callout', '.cb-controls-bar',
    '.fn-controls', '.ma-controls', '.controls-bar',
    '.fn-pin-dropdown-btn', '.fn-pin-dropdown',
    '.br-pin-btn', '.br-png-btn', '.br-export-btn', '.br-insight-toggle',
    '.fn-png-btn', '.ma-png-btn', '.fn-export-btn', '.ma-export-btn',
    '.toggle-label', '.sig-level-switcher',
    '[onclick]', '[ondblclick]'
  ].join(',');

  window.brStripInteractive = function(html) {
    if (!html) return html;
    var d = document.createElement('div');
    d.innerHTML = html;
    d.querySelectorAll(INTERACTIVE_SELECTORS).forEach(function(el) { el.remove(); });
    return d.innerHTML;
  };

  // --- Read the active "Base:" toggle label inside a captured root ---
  // Funnel, Brand Attitude, Brand Attributes and CEPs all expose a
  // `.sig-level-switcher` with a "Base:" prefix label and one
  // `.sig-btn-active` button. Returns the active button's text trimmed,
  // or "" if no Base toggle is present in this root.
  // Only considers VISIBLE switchers (offsetParent !== null) so hidden
  // sub-tabs (e.g. funnel's relationship sub-tab when the user is on
  // the main funnel sub-tab) don't leak the wrong base label.
  window.brReadBaseLabel = function(root) {
    if (!root) return "";
    var switchers = root.querySelectorAll(".sig-level-switcher");
    for (var i = 0; i < switchers.length; i++) {
      if (!isVisible(switchers[i])) continue;
      var lbl = switchers[i].querySelector(".sig-level-label");
      if (!lbl || !/Base\s*:/i.test(lbl.textContent || "")) continue;
      var active = switchers[i].querySelector(".sig-btn-active");
      if (active) return (active.textContent || "").trim();
    }
    return "";
  };

  // --- Extract capture payload from a given root element ---
  function captureFromRoot(root, sectionKey) {
    if (!root) return null;

    var title = root.querySelector(".br-element-title, h2, h3, .pfo-section-title");
    var titleText = title ? title.textContent.trim() : (sectionKey || "");

    // Pick the first *visible* SVG in the subtree — skip SVGs inside <button>
    // elements (e.g. toolbar download icons) which are not chart content.
    // Fallback: any non-button SVG even if not visible (e.g. inactive tab).
    var svg = null;
    var svgs = root.querySelectorAll("svg");
    for (var si = 0; si < svgs.length; si++) {
      if (isVisible(svgs[si]) && !svgs[si].closest("button")) { svg = svgs[si]; break; }
    }
    if (!svg) {
      for (var si2 = 0; si2 < svgs.length; si2++) {
        if (!svgs[si2].closest("button")) { svg = svgs[si2]; break; }
      }
    }

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

    // Card-grid escape hatch: sections with no <table> can opt into pin
    // capture by marking their card container with data-pin-as-table.
    // Used by the Summary panel (KPI cards) and any future card-only views.
    if (!tableHtml) {
      var cardsEl = root.querySelector("[data-pin-as-table]");
      if (cardsEl && typeof TurasPins !== "undefined" && TurasPins.capturePortableHtml) {
        tableHtml = TurasPins.capturePortableHtml(cardsEl);
      } else if (cardsEl) {
        tableHtml = cardsEl.outerHTML;
      }
    }

    // Insight textarea selectors:
    // - .br-insight-editor      generic section toolbar (page_builder)
    // - .fn-insight-textarea    funnel + cat-buying panels
    // - .ma-insight-box-text    MA + WoM panels
    var editor = root.querySelector(".br-insight-editor")
             || root.querySelector(".fn-insight-textarea")
             || root.querySelector(".ma-insight-box-text");
    var insightText = editor ? editor.value.trim() : "";

    // For sections whose chart is HTML (not SVG), capture the chart area HTML
    // so it can be rendered alongside the table in PNG export.
    var chartHtml = "";
    if (!chartSvg) {
      var htmlChartEl = root.querySelector("[data-fn-rel-chart-area]");
      if (htmlChartEl && typeof TurasPins !== "undefined" && TurasPins.capturePortableHtml) {
        chartHtml = TurasPins.capturePortableHtml(htmlChartEl);
      } else if (htmlChartEl) {
        chartHtml = htmlChartEl.outerHTML;
      }
    }

    // Final pass: strip interactive controls from the captured fragments
    // so pinned cards never carry sort buttons, toolbars, or live toggles.
    tableHtml = window.brStripInteractive(tableHtml);
    chartHtml = window.brStripInteractive(chartHtml);

    // Active "Base:" toggle label — read from the LIVE root before
    // controls are stripped from the captured HTML. Stored both as
    // `subtitle` (rendered in the pin card) and `baseText` (rendered
    // by the PNG/PPT exporter as the meta line under the title).
    var baseLabel = window.brReadBaseLabel(root);
    var subtitle  = baseLabel ? "Base: " + baseLabel : "";

    return {
      sectionKey: sectionKey || (root.id || ""),
      title: titleText,
      subtitle: subtitle,
      baseText: baseLabel,
      chartSvg: chartSvg,
      chartHtml: chartHtml,
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

    var section = document.getElementById("section-" + sectionId);
    if (!section && /^pf-/.test(sectionId)) {
      section = document.getElementById(sectionId.replace(/^pf-/, "pf-subtab-"));
    }
    if (!section) {
      var pgCandidates = document.querySelectorAll('[data-section="' + sectionId + '"]');
      for (var pgi = 0; pgi < pgCandidates.length; pgi++) {
        if (pgCandidates[pgi].tagName !== "BUTTON") { section = pgCandidates[pgi]; break; }
      }
    }
    if (!section) return;

    var hasChart = !!section.querySelector("svg");
    // Match captureFromRoot's selector list so smart-skip sees the same tables
    // the actual capture will find (pfo-table, fn-table, ma-table, plain table,
    // and any [data-pin-as-table] card-grid escape hatch used by Summary).
    var hasTable = !!(
      section.querySelector("table.br-table")  ||
      section.querySelector("table.pfo-table") ||
      section.querySelector("table.fn-table")  ||
      section.querySelector("table.ma-table")  ||
      section.querySelector("table.ma-matrix") ||
      section.querySelector("table") ||
      section.querySelector("[data-pin-as-table]")
    );
    var hasInsight = false;
    var editor = section.querySelector(".br-insight-editor");
    if (editor && editor.value.trim()) hasInsight = true;

    // Smart skip: if only one content type available, pin directly (no dialog)
    if (hasChart && !hasTable)  { brExecutePin(sectionId, { chart: true,  table: false, insight: hasInsight }); return; }
    if (!hasChart && hasTable)  { brExecutePin(sectionId, { chart: false, table: true,  insight: hasInsight }); return; }
    if (!hasChart && !hasTable) { brExecutePin(sectionId, { chart: false, table: false, insight: hasInsight }); return; }

    var checkboxes = [
      { key: "chart",   label: "Chart",   available: true, checked: true },
      { key: "table",   label: "Table",   available: true, checked: true },
      { key: "insight", label: "Insight", available: true, checked: hasInsight }
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
  window.brExportPng = function(sectionId, btnEl) {
    if (typeof TurasPins === "undefined") return;
    var content = brCaptureContent(sectionId);
    if (!content) return;
    applyPortfolioTitleFallback(content, sectionId);

    var hasChart   = !!content.chartSvg;
    var hasTable   = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    function doExport(flags) {
      TurasPins.exportContentAsPNG({
        title:       content.title,
        subtitle:    content.subtitle || "",
        baseText:    content.baseText || "",
        chartSvg:    flags.chart   ? content.chartSvg   : "",
        tableHtml:   flags.table   ? content.tableHtml  : "",
        insightText: flags.insight ? content.insightText : "",
        pinFlags:    { chart: !!flags.chart, table: !!flags.table, insight: !!flags.insight },
        pinMode:     "custom"
      });
    }

    // No button element or nothing to choose between → export directly
    if (!btnEl || (!hasChart && !hasTable)) {
      doExport({ chart: hasChart, table: hasTable, insight: hasInsight });
      return;
    }

    var checkboxes = [];
    if (hasChart) checkboxes.push({ key: "chart",   label: "Chart",   available: true, checked: true });
    if (hasTable) checkboxes.push({ key: "table",   label: "Table",   available: true, checked: true });
    checkboxes.push(              { key: "insight", label: "Insight", available: true, checked: hasInsight });

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      doExport(flags);
    }, null, { title: "EXPORT AS PNG", actionLabel: "Export" });
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

    var hasChart   = !!content.chartSvg || !!content.chartHtml;
    var hasTable   = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    function doExportFromEl(flags) {
      // When chart is HTML (not SVG), prepend it to tableHtml for html2canvas rendering
      var exportTableHtml = flags.table ? content.tableHtml : "";
      if (flags.chart && content.chartHtml && !content.chartSvg) {
        exportTableHtml = content.chartHtml + (exportTableHtml ? exportTableHtml : "");
      }
      TurasPins.exportContentAsPNG({
        title:       content.title,
        subtitle:    content.subtitle || "",
        baseText:    content.baseText || "",
        chartSvg:    (flags.chart && content.chartSvg) ? content.chartSvg : "",
        tableHtml:   exportTableHtml,
        insightText: flags.insight ? content.insightText : "",
        pinFlags:    { chart: !!flags.chart, table: !!flags.table, insight: !!flags.insight },
        pinMode:     "custom"
      });
    }

    if (!hasChart && !hasTable) {
      doExportFromEl({ chart: false, table: false, insight: hasInsight });
      return;
    }

    var checkboxes = [];
    if (hasChart) checkboxes.push({ key: "chart",   label: "Chart",   available: true, checked: true });
    if (hasTable) checkboxes.push({ key: "table",   label: "Table",   available: true, checked: true });
    checkboxes.push(              { key: "insight", label: "Insight", available: true, checked: hasInsight });

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      doExportFromEl(flags);
    }, null, { title: "EXPORT AS PNG", actionLabel: "Export" });
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

  // --- Pin state store ---
  // Lightweight key-value store so portfolio/overview JS can record UI state
  // (active subtab, focal brand, centred brand) that future pin-restore hooks
  // can read via brGetPinState().
  var _brPinState = {};

  window.brSetPinState = function(key, value) {
    _brPinState[key] = value;
  };

  window.brGetPinState = function(key) {
    return _brPinState[key];
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

    // Close any open popover when clicking outside, but not when clicking
    // the brand pin/PNG buttons themselves (they open their own popovers).
    document.addEventListener("click", function(e) {
      if (!e.target.closest(".br-pin-btn") &&
          !e.target.closest(".br-png-btn") &&
          !e.target.closest(".ma-png-btn") &&
          !e.target.closest(".fn-png-btn")) {
        TurasPins.closePopover();
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPins);
  } else {
    initPins();
  }
})();
