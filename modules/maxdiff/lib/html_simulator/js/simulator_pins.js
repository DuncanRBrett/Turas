/**
 * TURAS MaxDiff Simulator Pins v2.0
 * Pin capture, insight editor, custom slides, sections
 */

var SimPins = (function() {

  var pins = [];
  var nextId = 1;

  /**
   * Capture the current view from a tab and add as a pinned card
   * @param {string} tabId - "overview", "shares", "h2h", "portfolio", "diagnostics"
   */
  function captureView(tabId) {
    var data = SimEngine.getData();
    if (!data) return;

    var pin = {
      id: "pin-" + (nextId++),
      type: "view",
      tabId: tabId,
      timestamp: new Date().toISOString(),
      insight: "",
      title: "",
      chartHtml: "",
      meta: {}
    };

    if (tabId === "overview") {
      pin.title = "Overview";
      var stats = SimEngine.getOverviewStats();
      pin.meta.stats = stats;
      pin.chartHtml = buildOverviewSnapshot(stats);

    } else if (tabId === "diagnostics") {
      pin.title = "Diagnostics";
      var diag = SimEngine.getDiagnostics();
      pin.meta.diagnostics = diag;
      pin.chartHtml = buildDiagnosticsSnapshot(diag);

    } else if (tabId === "shares") {
      pin.title = "Preference Shares";
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-shares") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-shares") : null;
      if (segLabel) pin.title += " \u2014 " + segLabel;

      var shares = SimEngine.computeShares(segFilter);
      var hiddenItems = window.SimUI ? window.SimUI.getHiddenItems() : {};
      if (Object.keys(hiddenItems).length > 0) {
        var visible = shares.filter(function(s) { return !hiddenItems[s.itemId]; });
        var total = visible.reduce(function(sum, s) { return sum + s.share; }, 0);
        if (total > 0) visible.forEach(function(s) { s.share = (s.share / total) * 100; });
        shares = visible;
        pin.meta.hiddenCount = Object.keys(hiddenItems).length;
      }
      shares.sort(function(a, b) { return b.share - a.share; });
      pin.meta.shares = shares;
      pin.chartHtml = buildSharesSnapshot(shares);

    } else if (tabId === "h2h") {
      pin.title = "Head-to-Head";
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-h2h") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-h2h") : null;
      if (segLabel) pin.title += " \u2014 " + segLabel;

      var slots = window.SimUI ? window.SimUI.getH2HSlots() : [];
      var results = [];
      for (var i = 0; i < slots.length; i++) {
        if (slots[i].idA && slots[i].idB && slots[i].idA !== slots[i].idB) {
          var r = SimEngine.headToHead(slots[i].idA, slots[i].idB, segFilter);
          results.push(r);
        }
      }
      pin.meta.comparisons = results;
      pin.chartHtml = buildH2HSnapshot(results);

    } else if (tabId === "portfolio") {
      pin.title = "Portfolio (TURF)";
      var segFilter = window.SimUI ? window.SimUI.getSegFilter("seg-filter-turf") : null;
      var segLabel = window.SimUI ? window.SimUI.getSegLabel("seg-filter-turf") : null;
      if (segLabel) pin.title += " \u2014 " + segLabel;

      var checks = document.querySelectorAll(".sim-portfolio-check");
      var selected = [];
      checks.forEach(function(cb) { if (cb.checked) selected.push(cb.value); });
      var topK = window.SimUI ? window.SimUI.getTopK() : 3;
      var reach = SimEngine.turfReach(selected, topK, segFilter);

      pin.meta.reach = reach;
      pin.meta.selectedIds = selected;
      pin.meta.topK = topK;
      pin.meta.segLabel = segLabel;

      // Get item labels
      var itemLabels = {};
      data.items.forEach(function(it) { itemLabels[it.id] = it.label; });
      pin.meta.selectedLabels = selected.map(function(id) { return itemLabels[id] || id; });

      // Capture optimization results if present
      var optEl = document.getElementById("turf-opt-result");
      pin.meta.optHtml = (optEl && optEl.innerHTML) ? optEl.innerHTML : "";

      pin.chartHtml = buildTurfSnapshot(reach, pin.meta.selectedLabels, segLabel, topK, pin.meta.optHtml);
    }

    pins.push(pin);
    renderPins();
  }

  /**
   * Add a custom slide
   */
  function addCustomSlide() {
    pins.push({
      id: "pin-" + (nextId++),
      type: "custom",
      title: "Custom Slide",
      body: "",
      timestamp: new Date().toISOString()
    });
    renderPins();
  }

  /**
   * Add a section divider
   */
  function addSection(title) {
    pins.push({
      id: "pin-" + (nextId++),
      type: "section",
      title: title || "Section",
      timestamp: new Date().toISOString()
    });
    renderPins();
  }

  function getCount() {
    return pins.length;
  }

  function getPins() {
    return pins;
  }

  // --- Rendering ---

  function renderPins() {
    var container = document.getElementById("pins-container");
    if (!container) return;

    if (pins.length === 0) {
      container.innerHTML = '<div class="sim-pins-empty">No pinned views yet. Pin views from other tabs to save them here.</div>';
      updateCallout();
      return;
    }

    var html = '';
    for (var i = 0; i < pins.length; i++) {
      var p = pins[i];

      if (p.type === "section") {
        html += '<div class="sim-pin-section" data-pin-id="' + p.id + '">' +
          '<input class="sim-pin-section-title" value="' + esc(p.title) + '" data-pin-id="' + p.id + '" placeholder="Section title">' +
          '<div class="sim-pin-card-actions">' +
            moveButtons(i) +
            '<button class="sim-pin-delete" data-pin-id="' + p.id + '" title="Remove">&times;</button>' +
          '</div>' +
        '</div>';

      } else if (p.type === "custom") {
        html += '<div class="sim-custom-slide" data-pin-id="' + p.id + '">' +
          '<div class="sim-pin-card-header">' +
            '<input class="sim-custom-slide-title" value="' + esc(p.title) + '" data-pin-id="' + p.id + '" placeholder="Slide title">' +
            '<div class="sim-pin-card-actions">' +
              moveButtons(i) +
              '<button class="sim-pin-delete" data-pin-id="' + p.id + '" title="Remove">&times;</button>' +
            '</div>' +
          '</div>' +
          '<div class="sim-custom-slide-body" contenteditable="true" data-pin-id="' + p.id + '">' + renderMarkdown(p.body || '') + '</div>' +
        '</div>';

      } else {
        // View pin
        html += '<div class="sim-pin-card" data-pin-id="' + p.id + '">' +
          '<div class="sim-pin-card-header">' +
            '<span class="sim-pin-card-title">' + esc(p.title) + '</span>' +
            '<div class="sim-pin-card-actions">' +
              moveButtons(i) +
              '<button class="sim-pin-export-png sim-btn sim-btn-small" data-pin-id="' + p.id + '">PNG</button>' +
              '<button class="sim-pin-delete" data-pin-id="' + p.id + '" title="Remove">&times;</button>' +
            '</div>' +
          '</div>' +
          '<div class="sim-pin-card-body">' +
            p.chartHtml +
            '<div class="sim-pin-card-insight">' +
              '<div class="sim-pin-insight-editor" contenteditable="true" data-pin-id="' + p.id + '">' + renderMarkdown(p.insight || '') + '</div>' +
            '</div>' +
          '</div>' +
        '</div>';
      }
    }

    container.innerHTML = html;
    wireEvents(container);
    updateCallout();

    // Update badge
    if (window.SimUI) window.SimUI.updatePinBadge();
  }

  function wireEvents(container) {
    // Delete buttons
    container.querySelectorAll(".sim-pin-delete").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var id = this.getAttribute("data-pin-id");
        pins = pins.filter(function(p) { return p.id !== id; });
        renderPins();
      });
    });

    // Move buttons
    container.querySelectorAll(".sim-pin-move-up").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var id = this.getAttribute("data-pin-id");
        var idx = findIndex(id);
        if (idx > 0) { swap(idx, idx - 1); renderPins(); }
      });
    });

    container.querySelectorAll(".sim-pin-move-down").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var id = this.getAttribute("data-pin-id");
        var idx = findIndex(id);
        if (idx < pins.length - 1) { swap(idx, idx + 1); renderPins(); }
      });
    });

    // Insight editors
    container.querySelectorAll(".sim-pin-insight-editor").forEach(function(el) {
      el.addEventListener("blur", function() {
        var id = this.getAttribute("data-pin-id");
        var pin = findPin(id);
        if (pin) pin.insight = this.innerHTML;
      });
    });

    // Custom slide body editors
    container.querySelectorAll(".sim-custom-slide-body").forEach(function(el) {
      el.addEventListener("blur", function() {
        var id = this.getAttribute("data-pin-id");
        var pin = findPin(id);
        if (pin) pin.body = this.innerHTML;
      });
    });

    // Title editors (section + custom)
    container.querySelectorAll(".sim-pin-section-title, .sim-custom-slide-title").forEach(function(el) {
      el.addEventListener("input", function() {
        var id = this.getAttribute("data-pin-id");
        var pin = findPin(id);
        if (pin) pin.title = this.value;
      });
    });

    // PNG export for individual pins
    container.querySelectorAll(".sim-pin-export-png").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var id = this.getAttribute("data-pin-id");
        if (typeof SimExport !== "undefined") SimExport.exportPinPNG(id);
      });
    });
  }

  function updateCallout() {
    var callout = document.getElementById("pins-callout");
    if (callout) {
      SimCharts.renderCallout(
        "Pin any view to save it here. Add insights and commentary, create custom slides, and organise your findings. " +
        "Use the <strong>move arrows</strong> to reorder, and <strong>section dividers</strong> to structure your story.",
        callout
      );
    }
  }

  // --- Snapshot builders ---

  function buildSharesSnapshot(shares) {
    var max = shares.length > 0 ? shares[0].share : 1;
    if (max <= 0) max = 1;
    var html = '<div class="sim-share-bars">';
    for (var i = 0; i < shares.length; i++) {
      var s = shares[i];
      var w = Math.max(2, (s.share / max) * 100);
      html += '<div class="sim-bar-row">' +
        '<div class="sim-bar-label">' + esc(s.label) + '</div>' +
        '<div class="sim-bar-track"><div class="sim-bar-fill" style="width:' + w + '%;background:' + ((SimCharts.getBrandColour ? SimCharts.getBrandColour() : '#1e3a5f')) + '"></div></div>' +
        '<div class="sim-bar-value">' + s.share.toFixed(1) + '%</div>' +
      '</div>';
    }
    html += '</div>';
    return html;
  }

  function buildH2HSnapshot(results) {
    var brand = (SimCharts.getBrandColour ? SimCharts.getBrandColour() : '#1e3a5f');
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
    var brand = (SimCharts.getBrandColour ? SimCharts.getBrandColour() : '#1e3a5f');

    // Build SVG gauge (same as SimCharts.renderTurfReach)
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

    // Portfolio item list
    if (selectedLabels && selectedLabels.length > 0) {
      html += '<div style="margin-top:12px;font-size:13px"><strong>Portfolio (' + selectedLabels.length + ' items):</strong></div>';
      html += '<ul style="margin:4px 0 0 20px;font-size:12px;color:#475569">';
      for (var i = 0; i < selectedLabels.length; i++) {
        html += '<li style="margin-bottom:2px">' + esc(selectedLabels[i]) + '</li>';
      }
      html += '</ul>';
    }

    // Include optimization results if captured
    if (optHtml) {
      html += '<div style="margin-top:12px">' + optHtml + '</div>';
    }

    return html;
  }

  function buildOverviewSnapshot(stats) {
    if (!stats) return '<div>No overview data available.</div>';
    var html = '<div style="font-size:13px">';
    html += '<div class="sim-stat-grid">';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.nItems + '</div><div class="sim-stat-label">Items</div></div></div>';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.nRespondents.toLocaleString() + '</div><div class="sim-stat-label">Respondents</div></div></div>';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.topShare + '%</div><div class="sim-stat-label">Top Share</div><div class="sim-stat-sub">' + esc(stats.topItem) + '</div></div></div>';
    html += '<div class="sim-stat-card"><div class="sim-stat-body"><div class="sim-stat-value">' + stats.shareRange + 'pp</div><div class="sim-stat-label">Share Range</div></div></div>';
    html += '</div>';
    html += '<div style="margin-top:8px;color:#64748b">Method: ' + esc(stats.method) + '</div>';
    html += '</div>';
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

  // --- Helpers ---

  function moveButtons(index) {
    var id = pins[index].id;
    var up = index > 0 ? '<button class="sim-pin-move-up sim-btn sim-btn-small" data-pin-id="' + id + '">\u2191</button>' : '';
    var down = index < pins.length - 1 ? '<button class="sim-pin-move-down sim-btn sim-btn-small" data-pin-id="' + id + '">\u2193</button>' : '';
    return up + down;
  }

  function findPin(id) {
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].id === id) return pins[i];
    }
    return null;
  }

  function findIndex(id) {
    for (var i = 0; i < pins.length; i++) {
      if (pins[i].id === id) return i;
    }
    return -1;
  }

  function swap(a, b) {
    var tmp = pins[a];
    pins[a] = pins[b];
    pins[b] = tmp;
  }

  function renderMarkdown(text) {
    if (!text) return '';
    // Basic markdown: bold, italic, bullets
    text = text.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    text = text.replace(/\*(.+?)\*/g, '<em>$1</em>');
    return text;
  }

  function esc(str) {
    var div = document.createElement("div");
    div.appendChild(document.createTextNode(str || ""));
    return div.innerHTML;
  }

  // --- Wire add buttons on DOMContentLoaded ---
  document.addEventListener("DOMContentLoaded", function() {
    var addSlideBtn = document.getElementById("pins-add-slide");
    if (addSlideBtn) {
      addSlideBtn.addEventListener("click", function() {
        addCustomSlide();
      });
    }

    var addSectionBtn = document.getElementById("pins-add-section");
    if (addSectionBtn) {
      addSectionBtn.addEventListener("click", function() {
        addSection("New Section");
      });
    }
  });

  return {
    captureView: captureView,
    addCustomSlide: addCustomSlide,
    addSection: addSection,
    getCount: getCount,
    getPins: getPins,
    renderPins: renderPins
  };
})();
