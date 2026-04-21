/**
 * TURAS MaxDiff Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 *
 * Sub-tab panels (Preferences, Item Analysis): the pin/export popover shows a
 * radio group header so the user can choose which chart to capture, followed by
 * an Insight checkbox. Uses TurasPins.showCheckboxPopover with opts.headerEl so
 * CSS is properly injected and the popup matches the standard visual format.
 *
 * Diagnostics panel: adds a "Cards" checkbox for the hero stat-card grids
 * alongside the existing Table checkbox.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 */

/* global TurasPins */

(function() {
  "use strict";

  // ── Helpers ────────────────────────────────────────────────────────────────

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  /**
   * Find the first element matching selector within root that is NOT inside
   * a [data-segment] ancestor with display:none.
   */
  function _findVisible(root, selector) {
    var els = root.querySelectorAll(selector);
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      var hidden = false;
      var node = el.parentNode;
      while (node && node !== root) {
        if (node.hasAttribute && node.hasAttribute("data-segment") &&
            node.style && node.style.display === "none") {
          hidden = true;
          break;
        }
        node = node.parentNode;
      }
      if (!hidden) return el;
    }
    return null;
  }

  /** Clone an SVG element with explicit viewBox and dimensions. */
  function _cloneSvg(svgEl) {
    var clone = svgEl.cloneNode(true);
    if (!clone.getAttribute("viewBox")) {
      var bbox = svgEl.getBoundingClientRect();
      if (bbox.width > 0 && bbox.height > 0) {
        clone.setAttribute("viewBox", "0 0 " + bbox.width + " " + bbox.height);
      }
    }
    if (!clone.getAttribute("width"))  clone.setAttribute("width",  svgEl.getBoundingClientRect().width);
    if (!clone.getAttribute("height")) clone.setAttribute("height", svgEl.getBoundingClientRect().height);
    return clone;
  }

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Capture chart, table, hero cards, and insight from a DOM scope element.
   * @param {HTMLElement} scope - Root to search within (sub-panel or panel)
   * @param {HTMLElement} panel - Parent panel (fallback for insight-area search)
   * @returns {{chartSvg, tableHtml, heroHtml, insightText}}
   */
  function _captureScope(scope, panel) {
    // Chart SVG — first visible .md-chart-container svg
    var chartSvg = "";
    var svgEl = _findVisible(scope, ".md-chart-container svg");
    if (svgEl) {
      chartSvg = new XMLSerializer().serializeToString(_cloneSvg(svgEl));
    }

    // Table HTML — first visible table (standard or h2h), with portable inline styles
    var tableHtml = "";
    var tableEl = _findVisible(scope, ".md-table, .md-h2h-table");
    if (tableEl) {
      var tableClone = tableEl.cloneNode(true);
      var portableHtml = TurasPins.capturePortableHtml(tableEl, tableClone);
      var tableTemp = document.createElement("div");
      tableTemp.innerHTML = portableHtml;
      tableTemp.querySelectorAll(".sort-arrow").forEach(function(a) { a.remove(); });
      tableHtml = tableTemp.innerHTML;
    }

    // Hero cards — Diagnostics panel stat-card grids (.md-diag-hero wrapper)
    var heroHtml = "";
    var heroEl = scope.querySelector(".md-diag-hero");
    if (heroEl) {
      var heroClone = heroEl.cloneNode(true);
      heroHtml = TurasPins.capturePortableHtml(heroEl, heroClone);
    }

    // Insight text — scope first, then panel fallback
    var insightText = "";
    var area = scope.querySelector(".insight-area") || (panel && panel.querySelector(".insight-area"));
    if (area) {
      var editor = area.querySelector(".insight-md-editor");
      if (editor) insightText = editor.value;
    }

    return { chartSvg: chartSvg, tableHtml: tableHtml, heroHtml: heroHtml, insightText: insightText };
  }

  /**
   * Capture full panel content, scoped to the active sub-panel when present.
   * @param {string} panelId
   * @returns {object|null}
   */
  function mdCaptureContent(panelId) {
    var panel = $("#panel-" + panelId);
    if (!panel) return null;

    var title = "";
    var h2 = panel.querySelector("h2");
    if (h2) title = h2.textContent;

    var scope = panel.querySelector(".md-subpanel.active") || panel;
    var c = _captureScope(scope, panel);

    return {
      panelId:     panelId,
      title:       title,
      chartSvg:    c.chartSvg,
      tableHtml:   c.tableHtml,
      heroHtml:    c.heroHtml,
      insightText: c.insightText
    };
  }

  /**
   * Capture content from a specific named sub-panel.
   * Appends the sub-tab label to the title so pinned cards are self-describing.
   * @param {string} panelId
   * @param {string} subpanelKey - data-subpanel attribute value
   * @returns {object|null}
   */
  function mdCaptureFromKey(panelId, subpanelKey) {
    var panel = $("#panel-" + panelId);
    if (!panel) return null;

    var title = "";
    var h2 = panel.querySelector("h2");
    if (h2) title = h2.textContent;

    var scope;
    if (subpanelKey) {
      scope = panel.querySelector('.md-subpanel[data-subpanel="' + subpanelKey + '"]') || panel;
      var subBtn = panel.querySelector('.md-subtab-btn[data-subtab="' + subpanelKey + '"]');
      if (subBtn) title = title + " \u2014 " + subBtn.textContent.trim();
    } else {
      scope = panel.querySelector(".md-subpanel.active") || panel;
    }

    var c = _captureScope(scope, panel);

    return {
      panelId:     panelId,
      title:       title,
      chartSvg:    c.chartSvg,
      tableHtml:   c.tableHtml,
      heroHtml:    c.heroHtml,
      insightText: c.insightText
    };
  }

  /**
   * Return all sub-panels in a panel as [{key, label, isActive}].
   * Returns [] when the panel has no sub-panels.
   */
  function mdGetSubpanels(panelId) {
    var panel = $("#panel-" + panelId);
    if (!panel) return [];
    var result = [];
    panel.querySelectorAll(".md-subpanel[data-subpanel]").forEach(function(sp) {
      var key = sp.getAttribute("data-subpanel");
      var btn = panel.querySelector('.md-subtab-btn[data-subtab="' + key + '"]');
      result.push({
        key:      key,
        label:    btn ? btn.textContent.trim() : key,
        isActive: sp.classList.contains("active")
      });
    });
    return result;
  }

  // ── Sub-Tab Radio Header ───────────────────────────────────────────────────

  /**
   * Build a DOM element containing radio buttons for sub-tab selection.
   * Uses .pin-mode-checkbox class so it inherits the TurasPins popover styling.
   * The element is passed as opts.headerEl to TurasPins.showCheckboxPopover,
   * which ensures CSS is injected before the element is rendered.
   *
   * @param {Array<{key, label, isActive}>} subpanels
   * @param {{key: string}} selection - Mutable object; .key is updated on radio change
   * @returns {HTMLElement}
   */
  function _buildSubtabRadioGroup(subpanels, selection) {
    var container = document.createElement("div");
    container.style.cssText = "border-bottom:1px solid #f1f5f9;padding-bottom:4px;margin-bottom:2px;";

    var sectionLbl = document.createElement("div");
    sectionLbl.style.cssText =
      "padding:6px 14px 3px;font-size:10px;font-weight:700;color:#94a3b8;" +
      "text-transform:uppercase;letter-spacing:0.5px;";
    sectionLbl.textContent = "CHART";
    container.appendChild(sectionLbl);

    var radioName = "md-sp-" + Date.now();
    subpanels.forEach(function(sp) {
      var row = document.createElement("label");
      row.className = "pin-mode-checkbox";

      var radio = document.createElement("input");
      radio.type = "radio";
      radio.name = radioName;
      radio.value = sp.key;
      radio.checked = sp.key === selection.key;
      radio.onchange = function() { if (this.checked) selection.key = this.value; };

      var span = document.createElement("span");
      span.textContent = sp.label;

      row.appendChild(radio);
      row.appendChild(span);
      container.appendChild(row);
    });

    return container;
  }

  // ── Mode Popover ───────────────────────────────────────────────────────────

  /**
   * Smart pin:
   * - Multi-subpanel panels: shows sub-tab radio header + Insight checkbox.
   * - Diagnostics: shows Cards + Table + Insight checkboxes.
   * - Other single-content panels: pins directly or shows chart/table/insight checkboxes.
   * @param {string} panelId
   */
  function mdTogglePin(panelId) {
    TurasPins.closePopover();

    // ── Multi-subpanel path (Preferences, Item Analysis) ──────────────────
    var subpanels = mdGetSubpanels(panelId);
    if (subpanels.length > 1) {
      var activePanel = subpanels.filter(function(sp) { return sp.isActive; })[0] || subpanels[0];
      var selection = { key: activePanel.key };

      var btn = $(".pin-btn[data-panel='" + panelId + "']");
      if (!btn) {
        var fb = mdCaptureFromKey(panelId, selection.key);
        if (fb) _execPinFromContent(panelId, fb, { chart: true, table: !!fb.tableHtml, insight: false });
        return;
      }

      var headerEl = _buildSubtabRadioGroup(subpanels, selection);
      var initContent = mdCaptureFromKey(panelId, selection.key);
      var initInsight = initContent ? !!initContent.insightText : false;

      TurasPins.showCheckboxPopover(btn,
        [
          { key: "chart",   label: "Chart",   available: true, checked: true },
          { key: "insight", label: "Insight", available: true, checked: initInsight }
        ],
        function(flags) {
          var c = mdCaptureFromKey(panelId, selection.key);
          if (!c) return;
          _execPinFromContent(panelId, c, { chart: !!flags.chart, table: !!c.tableHtml, insight: !!flags.insight });
        },
        null,
        { headerEl: headerEl }
      );
      return;
    }

    // ── Single-panel path ─────────────────────────────────────────────────
    var content = mdCaptureContent(panelId);
    if (!content) return;
    var hasHero    = !!content.heroHtml;
    var hasChart   = !!content.chartSvg;
    var hasTable   = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    // Smart skip when only one meaningful content type and no hero cards
    if (!hasHero) {
      if (hasChart && !hasTable)   { mdExecutePinWithFlags(panelId, { chart: true, insight: hasInsight }); return; }
      if (!hasChart && hasTable)   { mdExecutePinWithFlags(panelId, { table: true, insight: hasInsight }); return; }
      if (!hasChart && !hasTable)  { mdExecutePinWithFlags(panelId, { insight: hasInsight }); return; }
    }

    // Show checkbox popover (includes Cards for diagnostics)
    var pinBtn = $(".pin-btn[data-panel='" + panelId + "']");
    if (!pinBtn) {
      mdExecutePinWithFlags(panelId, { cards: hasHero, chart: hasChart, table: hasTable, insight: hasInsight });
      return;
    }

    var checkboxes = [];
    if (hasHero)  checkboxes.push({ key: "cards",   label: "Cards",   available: true,     checked: true });
    if (hasChart) checkboxes.push({ key: "chart",   label: "Chart",   available: true,     checked: true });
    if (hasTable) checkboxes.push({ key: "table",   label: "Table",   available: true,     checked: true });
    checkboxes.push(              { key: "insight", label: "Insight", available: true,     checked: hasInsight });

    TurasPins.showCheckboxPopover(pinBtn, checkboxes, function(flags) {
      mdExecutePinWithFlags(panelId, flags);
    });
  }

  /**
   * Execute pin from a pre-captured content object with explicit flags.
   * Used by the sub-tab path where content is already captured from a chosen key.
   */
  function _execPinFromContent(panelId, content, flags) {
    var tableOut = "";
    if (flags.cards  && content.heroHtml)  tableOut += content.heroHtml;
    if (flags.table  && content.tableHtml) tableOut += content.tableHtml;

    TurasPins.add({
      sectionKey:  panelId,
      title:       content.title,
      chartSvg:    flags.chart   ? content.chartSvg    : "",
      tableHtml:   tableOut,
      insightText: flags.insight ? content.insightText : "",
      pinFlags: {
        chart:     !!flags.chart,
        table:     !!(flags.cards || flags.table),
        insight:   !!flags.insight,
        aiInsight: false
      },
      pinMode: "custom"
    });

    var btn = $(".pin-btn[data-panel='" + panelId + "']");
    if (btn) {
      btn.classList.add("pin-flash");
      setTimeout(function() { btn.classList.remove("pin-flash"); }, 600);
    }
  }

  /**
   * Execute pin by re-capturing from the panel with content-type flags.
   * @param {string} panelId
   * @param {object} flags - { cards, chart, table, insight }
   */
  function mdExecutePinWithFlags(panelId, flags) {
    var content = mdCaptureContent(panelId);
    if (!content) return;
    _execPinFromContent(panelId, content, flags);
  }

  // ── Pin Individual Chart ───────────────────────────────────────────────────

  function mdPinChart(btnEl, chartTitle) {
    var wrapper = btnEl.closest(".md-chart-wrapper");
    if (!wrapper) return;
    var svg = wrapper.querySelector("svg");
    if (!svg) return;

    TurasPins.add({
      title: chartTitle || "Chart",
      pinMode: "chart_insight",
      chartSvg: new XMLSerializer().serializeToString(_cloneSvg(svg)),
      tableHtml: "",
      insightText: ""
    });
  }

  // ── Added Slides → Pin ─────────────────────────────────────────────────────

  function mdPinSlide(slideId) {
    var card = $('[data-slide-id="' + slideId + '"]');
    if (!card) return;
    var title = card.querySelector(".md-slide-title");
    var editor = card.querySelector(".md-slide-md-editor");
    var imgStore = card.querySelector(".md-slide-img-store");

    TurasPins.add({
      title: title ? title.textContent : "Slide",
      insightText: editor ? editor.value : "",
      chartSvg: "",
      tableHtml: "",
      imageData: imgStore ? imgStore.value : "",
      pinMode: "all"
    });
  }

  // ── Export PNG ─────────────────────────────────────────────────────────────

  /**
   * Export panel as PNG.
   * Multi-subpanel panels: shows sub-tab radio header + Insight checkbox.
   * Diagnostics: Cards + Table + Insight checkboxes.
   * Others: standard chart/table/insight checkboxes.
   * @param {string} panelId
   * @param {HTMLElement} btnEl - Button that triggered
   */
  function mdExportPNG(panelId, btnEl) {
    // ── Multi-subpanel path ───────────────────────────────────────────────
    var subpanels = mdGetSubpanels(panelId);
    if (subpanels.length > 1 && btnEl) {
      var activePanel = subpanels.filter(function(sp) { return sp.isActive; })[0] || subpanels[0];
      var selection = { key: activePanel.key };
      var headerEl = _buildSubtabRadioGroup(subpanels, selection);

      var initContent = mdCaptureFromKey(panelId, selection.key);
      var initInsight = initContent ? !!initContent.insightText : false;

      TurasPins.showCheckboxPopover(btnEl,
        [
          { key: "chart",   label: "Chart",   available: true, checked: true },
          { key: "insight", label: "Insight", available: true, checked: initInsight }
        ],
        function(flags) {
          var c = mdCaptureFromKey(panelId, selection.key);
          if (!c) return;
          TurasPins.exportContentAsPNG({
            title:       c.title,
            sourceLabel: "MaxDiff",
            chartSvg:    flags.chart ? c.chartSvg : "",
            tableHtml:   c.tableHtml,
            insightText: flags.insight ? c.insightText : "",
            pinFlags: { chart: !!flags.chart, table: !!c.tableHtml, insight: !!flags.insight }
          });
        },
        null,
        { title: "EXPORT AS PNG", actionLabel: "Export", headerEl: headerEl }
      );
      return;
    }

    // ── Single-panel path ─────────────────────────────────────────────────
    var content = mdCaptureContent(panelId);
    if (!content) return;
    var hasHero    = !!content.heroHtml;
    var hasChart   = !!content.chartSvg;
    var hasTable   = !!content.tableHtml;
    var hasInsight = !!content.insightText;

    if (!btnEl || (!hasHero && !hasChart && !hasTable)) {
      TurasPins.exportContentAsPNG({
        title:       content.title,
        sourceLabel: "MaxDiff",
        chartSvg:    content.chartSvg,
        tableHtml:   content.heroHtml || content.tableHtml,
        insightText: content.insightText,
        pinFlags:    { chart: hasChart, table: !!(hasHero || hasTable), insight: hasInsight }
      });
      return;
    }

    var checkboxes = [];
    if (hasHero)  checkboxes.push({ key: "cards",   label: "Cards",   available: true, checked: true });
    if (hasChart) checkboxes.push({ key: "chart",   label: "Chart",   available: true, checked: true });
    if (hasTable) checkboxes.push({ key: "table",   label: "Table",   available: true, checked: true });
    checkboxes.push(              { key: "insight", label: "Insight", available: true, checked: hasInsight });

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      var c = mdCaptureContent(panelId);
      if (!c) return;
      var tableOut = "";
      if (flags.cards && c.heroHtml)  tableOut += c.heroHtml;
      if (flags.table && c.tableHtml) tableOut += c.tableHtml;
      TurasPins.exportContentAsPNG({
        title:       c.title,
        sourceLabel: "MaxDiff",
        chartSvg:    flags.chart   ? c.chartSvg    : "",
        tableHtml:   tableOut,
        insightText: flags.insight ? c.insightText : "",
        pinFlags:    { chart: !!flags.chart, table: !!(flags.cards || flags.table), insight: !!flags.insight }
      });
    }, null, { title: "EXPORT AS PNG", actionLabel: "Export" });
  }

  // ── Global Function Delegates ──────────────────────────────────────────────

  window._mdTogglePin = mdTogglePin;
  window._mdExecutePin = mdExecutePinWithFlags;
  window.mdExportPNG = mdExportPNG;
  window._mdRemovePinned = function(pinId) { TurasPins.remove(pinId); };
  window._mdMovePinned = function(fromIdx, toIdx) {
    var pins = TurasPins.getAll();
    if (fromIdx >= 0 && fromIdx < pins.length) {
      TurasPins.move(pins[fromIdx].id, toIdx > fromIdx ? 1 : -1);
    }
  };
  window._mdPinChart = mdPinChart;
  window._mdPinSlide = mdPinSlide;
  window._mdExportPinnedSvg = function(pinId) { TurasPins.exportCard(pinId); };
  window._mdExportAllPinned = function() { TurasPins.exportAll(); };

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    TurasPins.init({
      storeId: "md-pinned-views-data",
      cssPrefix: "md-pinned",
      moduleLabel: "MaxDiff",
      containerId: "md-pinned-cards-container",
      emptyStateId: "md-pinned-empty",
      badgeId: "pin-count-badge",
      features: {
        sections: true,
        dragDrop: true
      }
    });
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();

    document.addEventListener("click", function(e) {
      if (!e.target.closest(".pin-btn-wrapper") && !e.target.closest(".md-export-btn")) {
        TurasPins.closePopover();
      }
    });

    window.addEventListener("message", function(e) {
      if (!e.data || e.data.type !== "turas-sim-pin") return;
      var pin = e.data.pin;
      if (!pin) return;
      TurasPins.add(pin);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
