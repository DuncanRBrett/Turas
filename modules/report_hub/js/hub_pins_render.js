/**
 * Hub Pinned Views — Card Rendering
 *
 * Builds HTML for pin cards and section dividers in the hub's unified
 * pinned views panel. Handles source badges, insight editing (dual-mode
 * rendered/editor), chart/table display with pinMode filtering.
 *
 * Depends on: TurasPins shared library (loaded before this file)
 *             hub_pins.js (ReportHub.pinnedItems, ReportHub.moveItemById, etc.)
 */

/* global ReportHub, TurasPins */

(function() {
  "use strict";

  // Source badge configuration — maps source type to CSS class and label
  var BADGE_MAP = {
    tracker:    { cls: "hub-badge-tracker",    label: "Tracker" },
    tabs:       { cls: "hub-badge-tabs",       label: "Crosstabs" },
    confidence: { cls: "hub-badge-confidence", label: "Confidence" },
    conjoint:   { cls: "hub-badge-conjoint",   label: "Conjoint" },
    maxdiff:    { cls: "hub-badge-maxdiff",    label: "MaxDiff" },
    pricing:    { cls: "hub-badge-pricing",    label: "Pricing" },
    segment:    { cls: "hub-badge-segment",    label: "Segmentation" },
    catdriver:  { cls: "hub-badge-catdriver",  label: "Cat Driver" },
    keydriver:  { cls: "hub-badge-keydriver",  label: "Key Driver" },
    weighting:  { cls: "hub-badge-weighting",  label: "Weighting" },
    overview:   { cls: "hub-badge-overview",   label: "Overview" }
  };

  /** Render all pinned cards and section dividers. */
  ReportHub.renderPinnedCards = function() {
    var container = document.getElementById("hub-pinned-cards");
    var emptyState = document.getElementById("hub-pinned-empty");
    var toolbar = document.getElementById("hub-pinned-toolbar");
    if (!container) return;

    var pinCount = 0;
    for (var c = 0; c < ReportHub.pinnedItems.length; c++) {
      if (ReportHub.pinnedItems[c].type === "pin") pinCount++;
    }

    if (pinCount === 0) {
      container.innerHTML = "";
      if (emptyState) emptyState.style.display = "";
      if (toolbar) toolbar.style.display = "none";
      return;
    }

    if (emptyState) emptyState.style.display = "none";
    if (toolbar) toolbar.style.display = "";

    var html = "";
    for (var i = 0; i < ReportHub.pinnedItems.length; i++) {
      var item = ReportHub.pinnedItems[i];
      if (item.type === "section") {
        html += buildSectionDividerHTML(item, i);
      } else if (item.type === "pin") {
        html += buildPinCardHTML(item, i);
      }
    }
    container.innerHTML = html;

    // Force dark header theme on all pinned tables
    container.querySelectorAll(".hub-pin-table th").forEach(function(th) {
      th.style.backgroundColor = "#1a2744";
      th.style.color = "#e2e8f0";
      th.style.fontWeight = "600";
      th.style.fontSize = "11px";
      th.style.padding = "12px 16px";
      th.style.textAlign = "center";
      th.style.letterSpacing = "0.5px";
      th.style.verticalAlign = "bottom";
    });
    container.querySelectorAll(".hub-pin-table thead tr").forEach(function(tr) {
      var firstTh = tr.querySelector("th");
      if (firstTh) firstTh.style.textAlign = "left";
    });
  };

  /** Build HTML for a section divider. */
  function buildSectionDividerHTML(section, idx) {
    var total = ReportHub.pinnedItems.length;
    var sid = TurasPins._escapeHtml(section.id);
    return '<div class="hub-section-divider" data-idx="' + idx + '" data-item-id="' + sid + '" draggable="true" data-pin-drag-idx="' + idx + '">' +
      '<div class="hub-section-title" contenteditable="true" ' +
        'onpaste="event.preventDefault();document.execCommand(\'insertText\',false,event.clipboardData.getData(\'text/plain\'))" ' +
        'onblur="ReportHub.updateSectionTitleById(\'' + sid + '\', this.textContent)">' +
        TurasPins._escapeHtml(section.title) + '</div>' +
      '<div class="hub-section-actions">' +
        (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + sid + '\',-1)" title="Move up">\u25B2</button>' : '') +
        (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + sid + '\',1)" title="Move down">\u25BC</button>' : '') +
        '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + sid + '\')" title="Remove section">\u00D7</button>' +
      '</div>' +
    '</div>';
  }

  /** Build HTML for a pin card. */
  function buildPinCardHTML(pin, idx) {
    var total = ReportHub.pinnedItems.length;
    var sourceType = pin.sourceType || pin.source || "";
    var badgeLabel = pin.sourceLabel || "";
    var badgeClass = "hub-badge-default";
    if (BADGE_MAP[sourceType]) {
      badgeClass = BADGE_MAP[sourceType].cls;
      if (!badgeLabel) badgeLabel = BADGE_MAP[sourceType].label;
    } else {
      if (!badgeLabel) badgeLabel = sourceType || "Report";
    }

    var title = pin.title || pin.metricLabel || pin.qCode || "Pinned View";
    var subtitle = pin.subtitle || pin.questionText || "";
    var pid = TurasPins._escapeHtml(pin.id);

    var html = '<div class="hub-pin-card" data-pin-id="' + pid + '" data-idx="' + idx + '" draggable="true" data-pin-drag-idx="' + idx + '">' +
      '<div class="hub-pin-header">' +
        '<span class="hub-source-badge ' + badgeClass + '">' + TurasPins._escapeHtml(badgeLabel) + '</span>' +
        '<span class="hub-pin-title">' + TurasPins._escapeHtml(title) + '</span>' +
        '<div class="hub-pin-actions">' +
          '<button class="hub-action-btn" onclick="ReportHub.exportPinCard(\'' + pid + '\')" title="Export as PNG">\uD83D\uDCF8</button>' +
          (idx > 0 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + pid + '\',-1)" title="Move up">\u25B2</button>' : '') +
          (idx < total - 1 ? '<button class="hub-action-btn" onclick="ReportHub.moveItemById(\'' + pid + '\',1)" title="Move down">\u25BC</button>' : '') +
          '<button class="hub-action-btn hub-remove-btn" onclick="ReportHub.removePin(\'' + pid + '\')" title="Remove">\u00D7</button>' +
        '</div>' +
      '</div>';

    if (subtitle) {
      html += '<div class="hub-pin-subtitle">' + TurasPins._escapeHtml(subtitle) + '</div>';
    }

    html += buildInsightAreaHTML(pin, pid);

    if (pin.imageData) {
      html += '<div style="margin-bottom:4px;text-align:center;">' +
        '<img src="' + pin.imageData + '" style="max-width:100%;max-height:500px;border-radius:6px;border:1px solid #e2e8f0;" />' +
      '</div>';
    }

    var mode = pin.pinMode || "all";
    var showChart = (mode === "all" || mode === "chart_insight");
    var showTable = (mode === "all" || mode === "table_insight");

    if (pin.chartSvg && pin.chartVisible !== false && showChart) {
      html += '<div class="hub-pin-chart">' + TurasPins._sanitizeHtml(pin.chartSvg) + '</div>';
    }
    if (pin.tableHtml && showTable) {
      html += '<div class="hub-pin-table">' + TurasPins._sanitizeHtml(pin.tableHtml) + '</div>';
    }

    html += '</div>';
    return html;
  }

  /** Build insight area HTML with dual-mode rendered view + editor. */
  function buildInsightAreaHTML(pin, pid) {
    var insightRaw = pin.insight || pin.insightText || "";
    var renderedHtml = "";
    var editorText = "";
    if (insightRaw) {
      if (TurasPins._containsHtml(insightRaw)) {
        renderedHtml = TurasPins._sanitizeHtml(insightRaw);
        var tmp = document.createElement("div");
        tmp.innerHTML = renderedHtml;
        editorText = tmp.textContent.trim();
      } else {
        editorText = insightRaw;
        renderedHtml = TurasPins._renderMarkdown(insightRaw);
      }
    }
    return '<div class="hub-pin-insight" data-pin-id="' + pid + '">' +
      '<div class="hub-insight-rendered hub-md-content" ' +
        'ondblclick="ReportHub.toggleInsightEdit(\'' + pid + '\')" ' +
        'data-placeholder="Double-click to add insight...">' +
        (renderedHtml || '') +
      '</div>' +
      '<textarea class="hub-insight-editor" style="display:none" ' +
        'onblur="ReportHub.finishInsightEdit(\'' + pid + '\')">' +
        TurasPins._escapeHtml(editorText) +
      '</textarea>' +
    '</div>';
  }

})();
