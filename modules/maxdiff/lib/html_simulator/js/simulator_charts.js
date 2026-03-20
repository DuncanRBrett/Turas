/**
 * TURAS MaxDiff Simulator Charts v2.0
 * SVG chart rendering for the interactive simulator
 */

var SimCharts = (function() {

  var brandColour = "#1e3a5f";

  function setBrandColour(colour) {
    brandColour = colour || "#1e3a5f";
  }

  /**
   * Render horizontal share bars with eye toggle icons
   * @param {Object[]} shares - Array of {itemId, label, share} sorted by share desc
   * @param {HTMLElement} container - DOM element to render into
   * @param {Object} hiddenItems - Map of itemId->true for hidden items
   */
  function renderShareBars(shares, container, hiddenItems) {
    if (!container || !shares || shares.length === 0) return;

    hiddenItems = hiddenItems || {};
    var maxShare = 0;
    for (var i = 0; i < shares.length; i++) {
      if (!hiddenItems[shares[i].itemId] && shares[i].share > maxShare) maxShare = shares[i].share;
    }
    if (maxShare <= 0) maxShare = 1;

    var html = '<div class="sim-share-bars">';
    for (var i = 0; i < shares.length; i++) {
      var s = shares[i];
      var isHidden = !!hiddenItems[s.itemId];
      var width = isHidden ? 0 : Math.max(2, (s.share / maxShare) * 100);
      var rowClass = "sim-bar-row" + (isHidden ? " sim-bar-hidden" : "");

      html += '<div class="' + rowClass + '" data-item-id="' + escapeHtml(s.itemId) + '">' +
        '<button class="sim-eye-btn" data-item-id="' + escapeHtml(s.itemId) + '" title="' + (isHidden ? 'Show' : 'Hide') + ' this item">' +
          (isHidden ? eyeOffIcon() : eyeIcon()) +
        '</button>' +
        '<div class="sim-bar-label">' + escapeHtml(s.label) + '</div>' +
        '<div class="sim-bar-track">' +
          '<div class="sim-bar-fill" style="width:' + width + '%;background:' + brandColour + '"></div>' +
        '</div>' +
        '<div class="sim-bar-value">' + (isHidden ? '\u2014' : s.share.toFixed(1) + '%') + '</div>' +
      '</div>';
    }
    html += '</div>';
    container.innerHTML = html;
  }

  /**
   * Render compact mini bars for overview
   */
  function renderMiniShareBars(shares, container, maxBars) {
    if (!container || !shares || shares.length === 0) return;

    maxBars = maxBars || 6;
    var sorted = shares.slice().sort(function(a, b) { return b.share - a.share; });
    var display = sorted.slice(0, maxBars);
    var maxShare = display[0].share || 1;

    var html = '<div class="sim-mini-bars">';
    for (var i = 0; i < display.length; i++) {
      var s = display[i];
      var width = Math.max(3, (s.share / maxShare) * 100);
      html += '<div class="sim-mini-row">' +
        '<div class="sim-mini-label">' + escapeHtml(s.label) + '</div>' +
        '<div class="sim-mini-track">' +
          '<div class="sim-mini-fill" style="width:' + width + '%;background:' + brandColour + '"></div>' +
        '</div>' +
        '<div class="sim-mini-value">' + s.share.toFixed(1) + '%</div>' +
      '</div>';
    }
    if (sorted.length > maxBars) {
      html += '<div class="sim-mini-more">+ ' + (sorted.length - maxBars) + ' more items</div>';
    }
    html += '</div>';
    container.innerHTML = html;
  }

  /**
   * Render overview stat cards
   */
  function renderOverviewStats(stats, container) {
    if (!container || !stats) return;

    var cards = [
      {value: stats.nItems, label: "Items", icon: statIcon("items")},
      {value: stats.nRespondents.toLocaleString(), label: "Respondents", icon: statIcon("respondents")},
      {value: stats.topShare + "%", label: "Top Share", sub: stats.topItem, icon: statIcon("top")},
      {value: stats.shareRange + "pp", label: "Share Range", sub: "Top \u2013 Bottom", icon: statIcon("range")}
    ];

    var html = '<div class="sim-stat-grid">';
    for (var i = 0; i < cards.length; i++) {
      var c = cards[i];
      html += '<div class="sim-stat-card">' +
        '<div class="sim-stat-icon">' + c.icon + '</div>' +
        '<div class="sim-stat-body">' +
          '<div class="sim-stat-value">' + c.value + '</div>' +
          '<div class="sim-stat-label">' + c.label + '</div>' +
          (c.sub ? '<div class="sim-stat-sub">' + escapeHtml(c.sub) + '</div>' : '') +
        '</div>' +
      '</div>';
    }
    html += '</div>';
    container.innerHTML = html;
  }

  /**
   * Render head-to-head comparison
   */
  function renderHeadToHead(result, container) {
    if (!container) return;

    var html = '<div class="sim-h2h">' +
      '<div class="sim-h2h-bar">' +
        '<div class="sim-h2h-a" style="width:' + result.probA + '%;background:' + brandColour + '">' +
          '<span>' + result.probA + '%</span>' +
        '</div>' +
        '<div class="sim-h2h-b" style="width:' + result.probB + '%;background:#e74c3c">' +
          '<span>' + result.probB + '%</span>' +
        '</div>' +
      '</div>' +
      '<div class="sim-h2h-labels">' +
        '<span class="sim-h2h-label-a">' + escapeHtml(result.itemA || "Item A") + '</span>' +
        '<span class="sim-h2h-label-b">' + escapeHtml(result.itemB || "Item B") + '</span>' +
      '</div>' +
    '</div>';
    container.innerHTML = html;
  }

  /**
   * Render multiple H2H comparisons in a stacked layout
   */
  function renderMultiH2H(results, container) {
    if (!container || !results || results.length === 0) return;

    var html = '';
    for (var i = 0; i < results.length; i++) {
      var r = results[i];
      html += '<div class="sim-h2h-slot" data-slot="' + i + '">' +
        '<div class="sim-h2h-slot-header">' +
          '<span class="sim-h2h-slot-num">' + (i + 1) + '</span>' +
          (i > 0 ? '<button class="sim-h2h-remove" data-slot="' + i + '" title="Remove comparison">&times;</button>' : '') +
        '</div>' +
        '<div class="sim-h2h">' +
          '<div class="sim-h2h-bar">' +
            '<div class="sim-h2h-a" style="width:' + r.probA + '%;background:' + brandColour + '">' +
              '<span>' + r.probA + '%</span>' +
            '</div>' +
            '<div class="sim-h2h-b" style="width:' + r.probB + '%;background:#e74c3c">' +
              '<span>' + r.probB + '%</span>' +
            '</div>' +
          '</div>' +
          '<div class="sim-h2h-labels">' +
            '<span class="sim-h2h-label-a">' + escapeHtml(r.itemA) + '</span>' +
            '<span class="sim-h2h-label-b">' + escapeHtml(r.itemB) + '</span>' +
          '</div>' +
        '</div>' +
      '</div>';
    }
    container.innerHTML = html;
  }

  /**
   * Render segment comparison table
   * @param {Object} matrix - from SimEngine.segmentComparisonMatrix()
   * @param {HTMLElement} container
   */
  function renderSegmentTable(matrix, container) {
    if (!container || !matrix) return;

    var segs = matrix.segments;
    var items = matrix.items;

    // Find best/worst per segment column
    var bestPerSeg = {};
    var worstPerSeg = {};
    for (var si = 0; si < segs.length; si++) {
      var key = segs[si].key || "all";
      var best = -1, worst = 999, bestId = null, worstId = null;
      for (var ii = 0; ii < items.length; ii++) {
        var val = items[ii].shares[key] || 0;
        if (val > best) { best = val; bestId = items[ii].id; }
        if (val < worst) { worst = val; worstId = items[ii].id; }
      }
      bestPerSeg[key] = bestId;
      worstPerSeg[key] = worstId;
    }

    var html = '<div class="sim-seg-table-wrap"><table class="sim-seg-table"><thead><tr><th>Item</th>';
    for (var si = 0; si < segs.length; si++) {
      html += '<th>' + escapeHtml(segs[si].label) + '</th>';
    }
    html += '</tr></thead><tbody>';

    for (var ii = 0; ii < items.length; ii++) {
      html += '<tr><td class="sim-seg-item">' + escapeHtml(items[ii].label) + '</td>';
      for (var si = 0; si < segs.length; si++) {
        var key = segs[si].key || "all";
        var val = items[ii].shares[key] || 0;
        var cls = "";
        if (items[ii].id === bestPerSeg[key]) cls = " sim-seg-best";
        else if (items[ii].id === worstPerSeg[key]) cls = " sim-seg-worst";
        html += '<td class="sim-seg-val' + cls + '">' + val.toFixed(1) + '%</td>';
      }
      html += '</tr>';
    }
    html += '</tbody></table></div>';
    container.innerHTML = html;
  }

  /**
   * Render TURF reach indicator
   * @param {Object} reachResult - {reach, frequency, nReached, nTotal}
   * @param {HTMLElement} container
   * @param {string} segLabel - optional segment label to display
   */
  function renderTurfReach(reachResult, container, segLabel) {
    if (!container) return;

    var r = reachResult;
    var angle = (r.reach / 100) * 360;
    var rad = (angle - 90) * Math.PI / 180;
    var large = angle > 180 ? 1 : 0;
    var cx = 60, cy = 60, radius = 50;
    var x = cx + radius * Math.cos(rad);
    var y = cy + radius * Math.sin(rad);

    var pathD = r.reach >= 99.9
      ? 'M ' + cx + ' ' + (cy - radius) + ' A ' + radius + ' ' + radius + ' 0 1 1 ' + (cx - 0.01) + ' ' + (cy - radius)
      : 'M ' + cx + ' ' + (cy - radius) + ' A ' + radius + ' ' + radius + ' 0 ' + large + ' 1 ' + x.toFixed(1) + ' ' + y.toFixed(1);

    var svg = '<svg viewBox="0 0 120 120" width="120" height="120">' +
      '<circle cx="' + cx + '" cy="' + cy + '" r="' + radius + '" fill="none" stroke="#e2e8f0" stroke-width="8"/>' +
      '<path d="' + pathD + '" fill="none" stroke="' + brandColour + '" stroke-width="8" stroke-linecap="round"/>' +
      '<text x="' + cx + '" y="' + (cy + 2) + '" text-anchor="middle" font-size="18" font-weight="700" fill="' + brandColour + '">' + r.reach + '%</text>' +
      '<text x="' + cx + '" y="' + (cy + 16) + '" text-anchor="middle" font-size="10" fill="#64748b">reach</text>' +
    '</svg>';

    var segText = segLabel ? '<div class="sim-turf-seg-label">Segment: ' + escapeHtml(segLabel) + '</div>' : '';

    var html = '<div class="sim-turf-gauge">' + svg +
      '<div class="sim-turf-stats">' +
        '<div>' + r.nReached + ' / ' + r.nTotal + ' respondents reached</div>' +
        '<div>Avg frequency: ' + r.frequency + ' items</div>' +
        segText +
      '</div>' +
    '</div>';
    container.innerHTML = html;
  }

  /**
   * Render a callout box
   */
  function renderCallout(text, container) {
    if (!container) return;
    container.innerHTML = '<div class="sim-callout"><div class="sim-callout-icon">' + infoIcon() + '</div><div class="sim-callout-text">' + text + '</div></div>';
  }

  /**
   * Render diagnostics dashboard
   * @param {Object} diag - from SimEngine.getDiagnostics()
   * @param {HTMLElement} container
   */
  function renderDiagnostics(diag, container) {
    if (!container || !diag) return;

    var html = '';

    // Model Fit Summary cards
    html += '<div class="sim-diag-section"><h3 class="sim-section-title">Model Summary</h3>';
    html += '<div class="sim-stat-grid">';
    html += diagCard(diag.method, "Method", null, statIcon("items"));
    html += diagCard(diag.nRespondents.toLocaleString(), "Respondents", null, statIcon("respondents"));
    html += diagCard(diag.nItems, "Items", null, statIcon("items"));
    html += diagCard(diag.nSegments, "Segments", null, statIcon("range"));
    html += '</div></div>';

    // Utility statistics
    html += '<div class="sim-diag-section"><h3 class="sim-section-title">Population Utility Statistics</h3>';
    html += '<div class="sim-stat-grid">';
    html += diagCard(diag.utilityRange, "Utility Range", "Max \u2013 Min", statIcon("range"));
    html += diagCard(diag.utilityMean, "Mean Utility", null, statIcon("items"));
    html += diagCard(diag.utilitySD, "Utility SD", "Population spread", statIcon("range"));
    html += diagCard(diag.discriminationIndex, "Discrimination", "Range \u00f7 Items", statIcon("top"));
    html += '</div></div>';

    // Individual-level diagnostics
    if (diag.hasIndividual) {
      html += '<div class="sim-diag-section"><h3 class="sim-section-title">Model Quality Indicators</h3>';
      html += '<div class="sim-stat-grid">';
      html += diagCard(diag.meanMaxShare + "%", "Mean Max Share", "Chance = " + diag.chanceLevel + "%", statIcon("top"));
      html += diagCard(diag.sharpnessRatio + "x", "Sharpness Ratio", "vs chance level", statIcon("top"));
      html += diagCard(diag.entropyRatio, "Entropy Ratio", "Lower = sharper (0\u20131)", statIcon("range"));
      html += diagCard(diag.heterogeneity, "Heterogeneity", "Avg SD from population", statIcon("respondents"));
      html += '</div></div>';

      html += '<div class="sim-diag-section"><h3 class="sim-section-title">Respondent Utility Distribution</h3>';
      html += '<div class="sim-stat-grid">';
      html += diagCard(diag.meanUtilRange, "Mean Util Range", "Per respondent", statIcon("range"));
      html += diagCard(diag.minUtilRange, "Min Util Range", "Least discriminating", statIcon("range"));
      html += diagCard(diag.maxUtilRange, "Max Util Range", "Most discriminating", statIcon("range"));
      html += '</div></div>';
    }

    // Item-level diagnostics table
    html += '<div class="sim-diag-section"><h3 class="sim-section-title">Item-Level Diagnostics</h3>';
    html += '<div class="sim-seg-table-wrap"><table class="sim-seg-table"><thead><tr>';
    html += '<th style="text-align:left">Item</th><th>Pop. Utility</th>';
    if (diag.hasIndividual) {
      html += '<th>Indiv. Mean</th><th>Indiv. SD</th><th>Min</th><th>Max</th>';
    }
    html += '</tr></thead><tbody>';

    var sorted = diag.itemStats.slice().sort(function(a, b) { return b.popUtility - a.popUtility; });
    var bestId = sorted.length > 0 ? sorted[0].id : null;
    var worstId = sorted.length > 0 ? sorted[sorted.length - 1].id : null;

    for (var i = 0; i < sorted.length; i++) {
      var s = sorted[i];
      var cls = s.id === bestId ? ' class="sim-seg-best"' : (s.id === worstId ? ' class="sim-seg-worst"' : '');
      html += '<tr><td class="sim-seg-item">' + escapeHtml(s.label) + '</td>';
      html += '<td' + cls + ' style="text-align:right">' + s.popUtility + '</td>';
      if (diag.hasIndividual) {
        html += '<td style="text-align:right">' + s.indivMean + '</td>';
        html += '<td style="text-align:right">' + s.indivSD + '</td>';
        html += '<td style="text-align:right">' + s.indivMin + '</td>';
        html += '<td style="text-align:right">' + s.indivMax + '</td>';
      }
      html += '</tr>';
    }
    html += '</tbody></table></div></div>';

    // Interpretation guide
    html += '<div class="sim-diag-section"><h3 class="sim-section-title">Interpretation Guide</h3>';
    html += '<div class="sim-diag-guide">';
    html += '<div class="sim-diag-guide-item"><strong>Mean Max Share</strong>: Average probability of each respondent\'s top-ranked item. Higher values indicate sharper, more differentiated preferences. Chance level = 1/' + diag.nItems + '.</div>';
    html += '<div class="sim-diag-guide-item"><strong>Sharpness Ratio</strong>: How many times better than chance the model predicts first choices. Values above 2x suggest good model quality.</div>';
    html += '<div class="sim-diag-guide-item"><strong>Entropy Ratio</strong>: Ratio of observed preference entropy to maximum entropy. Values closer to 0 indicate more decisive preferences; values near 1 indicate near-random.</div>';
    html += '<div class="sim-diag-guide-item"><strong>Heterogeneity</strong>: Average standard deviation of individual utilities from the population mean. Higher values indicate greater diversity of preferences across respondents.</div>';
    html += '<div class="sim-diag-guide-item"><strong>Discrimination Index</strong>: Utility range divided by number of items. Larger values indicate the study effectively differentiates items.</div>';
    html += '<div class="sim-diag-guide-item"><strong>Indiv. SD</strong>: Standard deviation of individual-level utilities for each item. High SD indicates disagreement; low SD indicates consensus.</div>';
    html += '</div></div>';

    container.innerHTML = html;
  }

  function diagCard(value, label, sub, icon) {
    return '<div class="sim-stat-card">' +
      '<div class="sim-stat-icon">' + (icon || '') + '</div>' +
      '<div class="sim-stat-body">' +
        '<div class="sim-stat-value">' + value + '</div>' +
        '<div class="sim-stat-label">' + label + '</div>' +
        (sub ? '<div class="sim-stat-sub">' + escapeHtml(sub) + '</div>' : '') +
      '</div>' +
    '</div>';
  }

  // --- SVG Icons ---
  function eyeIcon() {
    return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>';
  }

  function eyeOffIcon() {
    return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>';
  }

  function infoIcon() {
    return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="' + brandColour + '" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>';
  }

  function statIcon(type) {
    var paths = {
      items: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
      respondents: '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
      top: '<polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/>',
      range: '<line x1="17" y1="10" x2="3" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="17" y1="18" x2="3" y2="18"/>'
    };
    return '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' + brandColour + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + (paths[type] || '') + '</svg>';
  }

  function escapeHtml(str) {
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(str || ""));
    return div.innerHTML;
  }

  return {
    setBrandColour: setBrandColour,
    renderShareBars: renderShareBars,
    renderMiniShareBars: renderMiniShareBars,
    renderOverviewStats: renderOverviewStats,
    renderHeadToHead: renderHeadToHead,
    renderMultiH2H: renderMultiH2H,
    renderSegmentTable: renderSegmentTable,
    renderTurfReach: renderTurfReach,
    renderCallout: renderCallout,
    renderDiagnostics: renderDiagnostics,
    eyeIcon: eyeIcon,
    eyeOffIcon: eyeOffIcon,
    escapeHtml: escapeHtml,
    getBrandColour: function() { return brandColour; }
  };
})();
