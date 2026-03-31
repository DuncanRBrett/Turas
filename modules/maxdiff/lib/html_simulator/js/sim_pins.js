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

  // ── Snapshot Builders ──────────────────────────────────────────────────────

  function buildSharesSnapshot(shares) {
    var max = shares.length > 0 ? shares[0].share : 1;
    if (max <= 0) max = 1;
    var brand = (SimCharts && SimCharts.getBrandColour) ? SimCharts.getBrandColour() : "#1e3a5f";
    var html = '<div class="sim-share-bars">';
    for (var i = 0; i < shares.length; i++) {
      var s = shares[i];
      var w = Math.max(2, (s.share / max) * 100);
      html += '<div class="sim-bar-row">' +
        '<div class="sim-bar-label">' + esc(s.label) + '</div>' +
        '<div class="sim-bar-track"><div class="sim-bar-fill" style="width:' + w + '%;background:' + brand + '"></div></div>' +
        '<div class="sim-bar-value">' + s.share.toFixed(1) + '%</div>' +
      '</div>';
    }
    html += '</div>';
    return html;
  }

  function buildH2HSnapshot(results) {
    var brand = (SimCharts && SimCharts.getBrandColour) ? SimCharts.getBrandColour() : "#1e3a5f";
    var html = '';
    for (var i = 0; i < results.length; i++) {
      var r = results[i];
      html += '<div class="sim-h2h" style="margin-bottom:12px">' +
        '<div class="sim-h2h-bar">' +
          '<div class="sim-h2h-a" style="width:' + r.probA + '%;background:' + brand + '"><span>' + r.probA + '%</span></div>' +
          '<div class="sim-h2h-b" style="width:' + r.probB + '%;background:#e74c3c"><span>' + r.probB + '%</span></div>' +
        '</div>' +
        '<div class="sim-h2h-labels">' +
          '<span>' + esc(r.itemA) + '</span><span>' + esc(r.itemB) + '</span>' +
        '</div>' +
      '</div>';
    }
    return html;
  }

  function buildTurfSnapshot(reach, selectedLabels, segLabel, topK, optHtml) {
    var brand = (SimCharts && SimCharts.getBrandColour) ? SimCharts.getBrandColour() : "#1e3a5f";
    var angle = (reach.reach / 100) * 360;
    var rad = (angle - 90) * Math.PI / 180;
    var large = angle > 180 ? 1 : 0;
    var cx = 60, cy = 60, radius = 50;
    var x = cx + radius * Math.cos(rad);
    var y = cy + radius * Math.sin(rad);

    var pathD = reach.reach >= 99.9
      ? 'M ' + cx + ' ' + (cy - radius) + ' A ' + radius + ' ' + radius + ' 0 1 1 ' + (cx - 0.01) + ' ' + (cy - radius)
      : 'M ' + cx + ' ' + (cy - radius) + ' A ' + radius + ' ' + radius + ' 0 ' + large + ' 1 ' + x.toFixed(1) + ' ' + y.toFixed(1);

    var svg = '<svg viewBox="0 0 120 120" width="120" height="120">' +
      '<circle cx="' + cx + '" cy="' + cy + '" r="' + radius + '" fill="none" stroke="#e2e8f0" stroke-width="8"/>' +
      '<path d="' + pathD + '" fill="none" stroke="' + brand + '" stroke-width="8" stroke-linecap="round"/>' +
      '<text x="' + cx + '" y="' + (cy + 2) + '" text-anchor="middle" font-size="18" font-weight="700" fill="' + brand + '">' + reach.reach + '%</text>' +
      '<text x="' + cx + '" y="' + (cy + 16) + '" text-anchor="middle" font-size="10" fill="#64748b">reach</text>' +
    '</svg>';

    var html = '<div class="sim-turf-gauge">' + svg +
      '<div class="sim-turf-stats">' +
        '<div>' + reach.nReached + ' / ' + reach.nTotal + ' respondents reached</div>' +
        '<div>Avg frequency: ' + reach.frequency + ' items</div>' +
        (segLabel ? '<div class="sim-turf-seg-label">Segment: ' + esc(segLabel) + '</div>' : '') +
        (topK ? '<div>Top-K threshold: ' + topK + '</div>' : '') +
      '</div>' +
    '</div>';

    if (selectedLabels && selectedLabels.length > 0) {
      html += '<div style="margin-top:12px;font-size:13px"><strong>Portfolio (' + selectedLabels.length + ' items):</strong></div>';
      html += '<ul style="margin:4px 0 0 20px;font-size:12px;color:#475569">';
      for (var i = 0; i < selectedLabels.length; i++) {
        html += '<li style="margin-bottom:2px">' + esc(selectedLabels[i]) + '</li>';
      }
      html += '</ul>';
    }

    if (optHtml) {
      html += '<div style="margin-top:12px">' + optHtml + '</div>';
    }
    return html;
  }

  function buildOverviewSnapshot(stats) {
    if (!stats) return '<div>No overview data available.</div>';
    var html = '<div style="font-size:13px"><div class="sim-stat-grid">';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.nItems + '</div><div class="sim-stat-label">Items</div></div></div>';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.nRespondents.toLocaleString() + '</div><div class="sim-stat-label">Respondents</div></div></div>';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.topShare + '%</div><div class="sim-stat-label">Top Share</div><div class="sim-stat-sub">' + esc(stats.topItem) + '</div></div></div>';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.shareRange + 'pp</div><div class="sim-stat-label">Share Range</div></div></div>';
    html += '</div><div style="margin-top:8px;color:#64748b">Method: ' + esc(stats.method) + '</div></div>';
    return html;
  }

  function buildDiagnosticsSnapshot(diag) {
    if (!diag) return '<div>No diagnostic data available.</div>';
    var html = '<div style="font-size:13px">';
    html += '<table class="sim-seg-table" style="font-size:12px"><thead><tr><th style="text-align:left">Metric</th><th>Value</th></tr></thead><tbody>';
    html += '<tr><td class="sim-seg-item">Method</td><td style="text-align:right">' + esc(diag.method) + '</td></tr>';
    html += '<tr><td class="sim-seg-item">Utility Range</td><td style="text-align:right">' + diag.utilityRange + '</td></tr>';
    html += '<tr><td class="sim-seg-item">Utility SD</td><td style="text-align:right">' + diag.utilitySD + '</td></tr>';
    html += '<tr><td class="sim-seg-item">Discrimination Index</td><td style="text-align:right">' + diag.discriminationIndex + '</td></tr>';
    if (diag.hasIndividual) {
      html += '<tr><td class="sim-seg-item">Mean Max Share</td><td style="text-align:right">' + diag.meanMaxShare + '%</td></tr>';
      html += '<tr><td class="sim-seg-item">Sharpness Ratio</td><td style="text-align:right">' + diag.sharpnessRatio + 'x</td></tr>';
      html += '<tr><td class="sim-seg-item">Entropy Ratio</td><td style="text-align:right">' + diag.entropyRatio + '</td></tr>';
      html += '<tr><td class="sim-seg-item">Heterogeneity</td><td style="text-align:right">' + diag.heterogeneity + '</td></tr>';
    }
    html += '</tbody></table></div>';
    return html;
  }

  // ── Content Capture ────────────────────────────────────────────────────────

  /**
   * Capture the current view from a simulator tab.
   * @param {string} tabId - "overview", "shares", "h2h", "portfolio", "diagnostics"
   */
  function captureView(tabId) {
    if (typeof TurasPins === "undefined" || !TurasPins.getConfig()) {
      console.error("[SimPins] TurasPins not initialised. Cannot capture view.");
      return;
    }
    var data = SimEngine.getData();
    if (!data) return;

    var title = "";
    var chartHtml = "";

    if (tabId === "overview") {
      title = "Overview";
      chartHtml = buildOverviewSnapshot(SimEngine.getOverviewStats());

    } else if (tabId === "diagnostics") {
      title = "Diagnostics";
      chartHtml = buildDiagnosticsSnapshot(SimEngine.getDiagnostics());

    } else if (tabId === "shares") {
      title = "Preference Shares";
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-shares") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-shares") : null;
      if (segLabel) title += " \u2014 " + segLabel;

      var shares = SimEngine.computeShares(segFilter);
      var hiddenItems = window.SimUI ? window.SimUI.getHiddenItems() : {};
      if (Object.keys(hiddenItems).length > 0) {
        var visible = shares.filter(function(s) { return !hiddenItems[s.itemId]; });
        var total = visible.reduce(function(sum, s) { return sum + s.share; }, 0);
        if (total > 0) visible.forEach(function(s) { s.share = (s.share / total) * 100; });
        shares = visible;
      }
      shares.sort(function(a, b) { return b.share - a.share; });
      chartHtml = buildSharesSnapshot(shares);

    } else if (tabId === "h2h") {
      title = "Head-to-Head";
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-h2h") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-h2h") : null;
      if (segLabel) title += " \u2014 " + segLabel;

      var slots = window.SimUI ? window.SimUI.getH2HSlots() : [];
      var results = [];
      for (var i = 0; i < slots.length; i++) {
        if (slots[i].idA && slots[i].idB && slots[i].idA !== slots[i].idB) {
          results.push(SimEngine.headToHead(slots[i].idA, slots[i].idB, segFilter));
        }
      }
      chartHtml = buildH2HSnapshot(results);

    } else if (tabId === "portfolio") {
      title = "Portfolio (TURF)";
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-turf") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-turf") : null;
      if (segLabel) title += " \u2014 " + segLabel;

      var checks = document.querySelectorAll(".sim-portfolio-check");
      var selected = [];
      checks.forEach(function(cb) { if (cb.checked) selected.push(cb.value); });
      var topK = window.SimUI ? window.SimUI.getTopK() : 3;
      var reach = SimEngine.turfReach(selected, topK, segFilter);

      var itemLabels = {};
      data.items.forEach(function(it) { itemLabels[it.id] = it.label; });
      var selectedLabels = selected.map(function(id) { return itemLabels[id] || id; });

      var optEl = document.getElementById("turf-opt-result");
      var optHtml = (optEl && optEl.innerHTML) ? optEl.innerHTML : "";

      chartHtml = buildTurfSnapshot(reach, selectedLabels, segLabel, topK, optHtml);
    }

    // Delegate to TurasPins — chartHtml maps to tableHtml via normalise()
    TurasPins.add({
      title: title,
      tabId: tabId,
      chartHtml: chartHtml,
      insight: "",
      pinMode: "all"
    });
  }

  /**
   * Add a custom slide via TurasPins.
   */
  function addCustomSlide() {
    TurasPins.add({
      title: "Custom Slide",
      insightText: "Click to edit...",
      chartSvg: "",
      tableHtml: "",
      pinMode: "all"
    });
  }

  /**
   * Add a section divider via TurasPins.
   */
  function addSection(title) {
    TurasPins.addSection(title || "New Section");
  }

  function getCount() {
    return TurasPins.getPinCount();
  }

  function getPins() {
    return TurasPins.getAll();
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  function init() {
    if (typeof TurasPins === "undefined" || typeof TurasPins.init !== "function") {
      console.error("[SimPins] TurasPins shared library not loaded. Pin functionality unavailable.");
      return;
    }

    TurasPins.init({
      storeId: "pinned-views-data",
      cssPrefix: "sim-pin",
      moduleLabel: "MaxDiff Simulator",
      containerId: "pins-container",
      emptyStateId: "sim-pins-empty",
      badgeId: "pin-badge",
      features: {
        insightEdit: true,
        sections: true,
        dragDrop: true
      }
    });
    if (TurasPins._initDragDrop) TurasPins._initDragDrop();

    // Wire add buttons
    var addSlideBtn = document.getElementById("pins-add-slide");
    if (addSlideBtn) {
      addSlideBtn.addEventListener("click", function() { addCustomSlide(); });
    }
    var addSectionBtn = document.getElementById("pins-add-section");
    if (addSectionBtn) {
      addSectionBtn.addEventListener("click", function() { addSection("New Section"); });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  return {
    captureView: captureView,
    addCustomSlide: addCustomSlide,
    addSection: addSection,
    getCount: getCount,
    getPins: getPins
  };
})();
