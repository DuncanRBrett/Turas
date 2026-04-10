/**
 * TURAS Pricing Report — Pin System (Thin Wrapper)
 *
 * Delegates pin management to the TurasPins shared library.
 * Handles pricing-specific content capture: standard sections,
 * simulator (metrics + chart), and scenario comparison table.
 *
 * Pins are always additive — each click captures a new snapshot.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 */

/* global TurasPins */

(function() {
  "use strict";

  var sectionMeta = {
    summary: "Summary",
    vw: "Van Westendorp",
    gg: "Gabor-Granger",
    monadic: "Monadic",
    segments: "Segments",
    recommendation: "Recommendation",
    simulator: "Simulator",
    comparison: "Scenario Comparison"
  };

  /**
   * Capture a standard section (chart + table + insight from a panel).
   * @param {string} sectionId
   * @returns {object|null}
   */
  function captureStandardSection(sectionId) {
    var panel = document.getElementById("panel-" + sectionId);
    if (!panel) return null;

    var chartSvg = "";
    var svgEl = panel.querySelector("svg");
    if (svgEl) chartSvg = new XMLSerializer().serializeToString(svgEl);

    var tableHtml = "";
    var tableEl = panel.querySelector(".pr-table");
    if (tableEl) tableHtml = tableEl.outerHTML;

    var insightText = _getInsight("panel-" + sectionId);

    return {
      title: sectionMeta[sectionId] || sectionId,
      chartSvg: chartSvg,
      tableHtml: tableHtml,
      insightText: insightText
    };
  }

  /**
   * Capture the simulator: replicates the on-screen metric cards layout
   * plus the demand/revenue chart. Captures the full visual context.
   * @returns {object|null}
   */
  function captureSimulator() {
    var panel = document.getElementById("panel-simulator");
    if (!panel) return null;

    var price = _text(panel, "#sim-current-price");
    var metrics = _buildMetricCards(panel);

    // Capture the demand/revenue chart
    var chartSvg = "";
    var svgEl = panel.querySelector("#sim-chart-svg svg");
    if (svgEl) chartSvg = new XMLSerializer().serializeToString(svgEl);

    var insightText = _getInsight("sim-insight-area");

    return {
      title: "Simulator \u2014 " + price,
      chartSvg: chartSvg,
      tableHtml: metrics,
      insightText: insightText
    };
  }

  /**
   * Build metric cards HTML plus a hidden export table.
   * The cards render on-screen in the pin; the table is used by
   * the PNG export pipeline which needs a <table> for _extractTableData.
   */
  function _buildMetricCards(panel) {
    var metrics = [];
    metrics.push({ label: "Price", value: _text(panel, "#sim-current-price") });
    metrics.push({ label: "Purchase Intent", value: _text(panel, "#sim-intent-value") });

    var revDelta = _text(panel, "#sim-revenue-delta");
    var revValue = _text(panel, "#sim-revenue-value");
    metrics.push({ label: "Revenue Index", value: revValue, delta: revDelta });

    metrics.push({ label: "Volume Index", value: _text(panel, "#sim-volume-value") });

    var profit = _text(panel, "#sim-profit-value");
    if (profit && profit !== "N/A") {
      metrics.push({ label: "Profit Index", value: profit });
    }

    var costInput = document.getElementById("sim-unit-cost-input");
    if (costInput && costInput.value && parseFloat(costInput.value) > 0) {
      metrics.push({ label: "Unit Cost", value: costInput.value });
    }

    // Visual cards for on-screen pin display
    var cards = [];
    for (var i = 0; i < metrics.length; i++) {
      cards.push(_card(metrics[i].value, metrics[i].label, metrics[i].delta || ""));
    }
    var cardsHtml = '<div style="display:grid;grid-template-columns:repeat(auto-fit,' +
      'minmax(120px,1fr));gap:10px;margin-bottom:12px;">' + cards.join("") + '</div>';

    // Hidden table for PNG export (extractTableData needs a <table>)
    var tableRows = "";
    for (var j = 0; j < metrics.length; j++) {
      var val = metrics[j].value;
      if (metrics[j].delta) val += " (" + metrics[j].delta + ")";
      tableRows += "<tr><td>" + _esc(metrics[j].label) +
        "</td><td>" + _esc(val) + "</td></tr>";
    }
    var exportTable = '<table class="pr-table" style="display:none">' +
      "<thead><tr><th>Metric</th><th>Value</th></tr></thead>" +
      "<tbody>" + tableRows + "</tbody></table>";

    return cardsHtml + exportTable;
  }

  /** Build a single metric card matching the simulator screen style */
  function _card(value, label, delta) {
    var deltaHtml = "";
    if (delta) {
      var cls = delta.indexOf("-") === 0 ? "color:#dc2626" : "color:#059669";
      deltaHtml = '<div style="font-size:11px;font-weight:600;margin-top:3px;' +
        cls + '">' + _esc(delta) + '</div>';
    }
    return '<div style="background:#f8fafc;border-radius:8px;padding:14px;text-align:center;">' +
      '<div style="font-size:22px;font-weight:700;color:#323367;' +
        'font-variant-numeric:tabular-nums;">' + _esc(value) + '</div>' +
      '<div style="font-size:11px;color:#64748b;margin-top:2px;">' +
        _esc(label) + '</div>' +
      deltaHtml + '</div>';
  }

  /**
   * Capture the scenario comparison table with inline styles.
   * Styles must be inlined because the pin renders outside #panel-simulator
   * where the CSS selectors no longer match.
   * @returns {object|null}
   */
  function captureComparison() {
    var table = document.getElementById("sim-compare-table");
    if (!table) return null;
    var rows = table.querySelectorAll("tbody tr");
    if (rows.length === 0) return null;

    var tableHtml = _buildStyledComparisonTable(table);
    var insightText = _getInsight("compare-insight-area");

    return {
      title: "Scenario Comparison",
      chartSvg: "",
      tableHtml: tableHtml,
      insightText: insightText
    };
  }

  /**
   * Build a fully styled comparison table with inline styles.
   * Reads computed styles from the live table and bakes them in
   * so the pin looks identical to the on-screen version.
   */
  function _buildStyledComparisonTable(table) {
    var nCols = table.querySelectorAll("thead th").length;
    var html = '<div style="overflow-x:auto;border:1px solid #e5e7eb;' +
      'border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,0.04)">';
    html += '<table style="width:100%;border-collapse:collapse;font-size:13px;">';

    // Header
    var headers = table.querySelectorAll("thead th");
    html += "<thead><tr>";
    headers.forEach(function(th, ci) {
      var text = th.textContent.replace(/\u00d7/g, "").trim();
      var borderLeft = ci > 0 ?
        "border-left:1px solid rgba(255,255,255,0.15);" : "";
      html += '<th style="padding:12px 16px;font-weight:600;font-size:11px;' +
        'letter-spacing:0.5px;color:#e2e8f0;background:#1a2744;' +
        'white-space:nowrap;vertical-align:bottom;' +
        (ci === 0 ? 'text-align:left;' : 'text-align:right;') +
        borderLeft + '">' + _esc(text) + '</th>';
    });
    html += "</tr></thead><tbody>";

    // Body rows
    var bodyRows = table.querySelectorAll("tbody tr");
    bodyRows.forEach(function(tr, ri) {
      html += "<tr" + (ri % 2 === 1 ? ' style="background:#f9fafb"' : "") + ">";
      var cells = tr.querySelectorAll("td");
      cells.forEach(function(td, ci) {
        var cs = getComputedStyle(td);
        var color = cs.color || "#334155";
        var fw = cs.fontWeight || "400";
        var val = td.querySelector("input") ?
          td.querySelector("input").value : td.textContent.trim();
        var borderLeft = ci > 0 ?
          "border-left:1px solid #e5e7eb;" : "";
        var stickyFirst = ci === 0 ?
          "font-weight:500;color:#1e293b;min-width:140px;" +
          "border-right:1px solid #e5e7eb;" : "";
        html += '<td style="padding:10px 16px;border-bottom:1px solid #f0f1f3;' +
          'font-variant-numeric:tabular-nums;' +
          (ci === 0 ? 'text-align:left;' : 'text-align:right;') +
          'color:' + color + ';font-weight:' + fw + ';' +
          borderLeft + stickyFirst + '">' + _esc(val) + '</td>';
      });
      html += "</tr>";
    });

    html += "</tbody></table></div>";
    return html;
  }

  /** Route to the right capture function */
  function captureView(sectionId) {
    if (sectionId === "simulator") return captureSimulator();
    if (sectionId === "comparison") return captureComparison();
    return captureStandardSection(sectionId);
  }

  /** Get text content from a selector within an element */
  function _text(parent, selector) {
    var el = parent.querySelector(selector);
    return el ? el.textContent.trim() : "";
  }

  /** Get insight text from an insight editor area */
  function _getInsight(containerId) {
    var container = document.getElementById(containerId);
    if (!container) return "";
    var editor = container.querySelector(".pr-insight-editor");
    return editor ? editor.textContent.trim() : "";
  }

  /** HTML-escape for table cell content */
  function _esc(s) {
    if (!s) return "";
    var d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  }

  /**
   * Pin a section — shows checkbox popover when multiple content types exist.
   * @param {string} sectionId - Section to pin
   * @param {HTMLElement} [btnEl] - Pin button for popover positioning
   */
  window.pinSection = function(sectionId, btnEl) {
    var captured = captureView(sectionId);
    if (!captured) return;

    var hasChart = !!captured.chartSvg;
    var hasTable = !!captured.tableHtml;
    var hasInsight = !!captured.insightText;

    // Only one content type or no button → pin directly
    if (!btnEl || (!hasChart && !hasTable) ||
        (hasChart && !hasTable) || (!hasChart && hasTable)) {
      captured.pinFlags = {
        chart: hasChart, table: hasTable,
        insight: hasInsight, aiInsight: false
      };
      captured.pinMode = "custom";
      TurasPins.add(captured);
      return;
    }

    var checkboxes = [
      { key: "table",   label: "Table",   available: hasTable,   checked: hasTable },
      { key: "chart",   label: "Chart",   available: hasChart,   checked: hasChart },
      { key: "insight", label: "Insight", available: true,       checked: hasInsight }
    ];

    TurasPins.showCheckboxPopover(btnEl, checkboxes, function(flags) {
      var content = captureView(sectionId);
      if (!content) return;
      if (!flags.chart) content.chartSvg = "";
      if (!flags.table) content.tableHtml = "";
      if (!flags.insight) content.insightText = "";
      content.pinFlags = {
        chart:     !!flags.chart,
        table:     !!flags.table,
        insight:   !!flags.insight,
        aiInsight: !!flags.aiInsight
      };
      content.pinMode = "custom";
      TurasPins.add(content);
    });
  };

  window.removePinned = function(pinId) { TurasPins.remove(pinId); };
  window.movePinned = function(from, to) { TurasPins.moveByIndex(from, to); };
  window.exportAllPinned = function() { TurasPins.exportAll(); };

  function init() {
    TurasPins.init({
      storeId: "pinned-views-data",
      cssPrefix: "pinned",
      moduleLabel: "Pricing",
      containerId: "pinned-cards-container",
      emptyStateId: "pinned-empty-state",
      badgeId: "pin-badge",
      toolbarId: "pinned-bulk-actions",
      features: {
        sections: true,
        dragDrop: true
      }
    });
    // Initialise drag/drop if enabled
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

})();
