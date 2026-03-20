/**
 * TURAS MaxDiff Simulator UI v2.0
 * DOM manipulation, tab switching, interactive controls
 */

(function() {
  document.addEventListener("DOMContentLoaded", function() {

    // Load embedded data
    var dataEl = document.getElementById("sim-data");
    if (!dataEl) { console.error("sim-data element not found"); return; }

    var simData;
    try {
      simData = JSON.parse(dataEl.textContent);
    } catch(e) {
      console.error("Failed to parse sim-data:", e);
      return;
    }

    SimEngine.init(simData);
    SimCharts.setBrandColour(simData.brand_colour || "#1e3a5f");

    // --- State ---
    var hiddenItems = {};
    var h2hSlots = [];
    var MAX_H2H_SLOTS = 10;

    // --- Tab switching with URL hash ---
    var tabs = document.querySelectorAll(".sim-tab-btn");
    var panels = document.querySelectorAll(".sim-panel");

    function switchTab(target) {
      tabs.forEach(function(t) { t.classList.remove("active"); });
      panels.forEach(function(p) { p.classList.remove("active"); });
      tabs.forEach(function(t) {
        if (t.getAttribute("data-tab") === target) t.classList.add("active");
      });
      var panel = document.getElementById("panel-" + target);
      if (panel) panel.classList.add("active");
    }

    tabs.forEach(function(tab) {
      tab.addEventListener("click", function() {
        var target = this.getAttribute("data-tab");
        switchTab(target);
        history.replaceState(null, null, "#" + target);
      });
    });

    // Load tab from hash
    if (window.location.hash) {
      var hashTab = window.location.hash.substring(1);
      var validTabs = [];
      tabs.forEach(function(t) { validTabs.push(t.getAttribute("data-tab")); });
      if (validTabs.indexOf(hashTab) >= 0) switchTab(hashTab);
    }

    // --- Helper: get current segment filter ---
    function getSegFilter(selectId) {
      var sel = document.getElementById(selectId || "seg-filter-shares");
      return sel ? (sel.value || null) : null;
    }

    function getSegLabel(selectId) {
      var sel = document.getElementById(selectId || "seg-filter-shares");
      if (!sel || !sel.value) return null;
      return sel.options[sel.selectedIndex].text;
    }

    // --- Overview Tab ---
    function updateOverview() {
      var stats = SimEngine.getOverviewStats();
      var statsContainer = document.getElementById("overview-stats");
      if (statsContainer && stats) SimCharts.renderOverviewStats(stats, statsContainer);

      var miniContainer = document.getElementById("overview-mini-chart");
      if (miniContainer) {
        var shares = SimEngine.computeShares(null);
        shares.sort(function(a, b) { return b.share - a.share; });
        SimCharts.renderMiniShareBars(shares, miniContainer, 6);
      }

      var callout = document.getElementById("overview-callout");
      if (callout && stats) {
        var method = stats.method || "Hierarchical Bayes";
        var text = "This simulator uses <strong>" + method + "</strong> utility estimates from <strong>" +
          stats.nRespondents.toLocaleString() + " respondents</strong> to model preference. " +
          "Use it to explore shares, compare items head-to-head, and optimise portfolios.";
        SimCharts.renderCallout(text, callout);
      }
    }
    updateOverview();

    // --- Shares Tab ---
    function updateShares() {
      var segFilter = getSegFilter("seg-filter-shares");
      var shares = SimEngine.computeShares(segFilter);

      // Recompute shares excluding hidden items for redistribution
      if (Object.keys(hiddenItems).length > 0) {
        var visibleShares = shares.filter(function(s) { return !hiddenItems[s.itemId]; });
        var totalVisible = visibleShares.reduce(function(sum, s) { return sum + s.share; }, 0);
        if (totalVisible > 0) {
          visibleShares.forEach(function(s) { s.share = (s.share / totalVisible) * 100; });
        }
        // Keep hidden items in list but with redistributed=0
        shares.forEach(function(s) {
          if (hiddenItems[s.itemId]) s.share = 0;
          else {
            var match = visibleShares.find(function(v) { return v.itemId === s.itemId; });
            if (match) s.share = match.share;
          }
        });
      }

      shares.sort(function(a, b) { return b.share - a.share; });

      var container = document.getElementById("shares-chart");
      if (container) {
        SimCharts.renderShareBars(shares, container, hiddenItems);

        // Wire eye buttons
        container.querySelectorAll(".sim-eye-btn").forEach(function(btn) {
          btn.addEventListener("click", function(e) {
            e.stopPropagation();
            var itemId = this.getAttribute("data-item-id");
            if (hiddenItems[itemId]) {
              delete hiddenItems[itemId];
            } else {
              hiddenItems[itemId] = true;
            }
            updateShares();
          });
        });
      }

      // Hidden count
      var hiddenCount = Object.keys(hiddenItems).length;
      var hiddenInfo = document.getElementById("shares-hidden-info");
      if (hiddenInfo) {
        hiddenInfo.textContent = hiddenCount > 0 ? hiddenCount + " item" + (hiddenCount > 1 ? "s" : "") + " hidden \u2014 shares redistributed" : "";
        hiddenInfo.style.display = hiddenCount > 0 ? "block" : "none";
      }

      // Show all button
      var showAllBtn = document.getElementById("shares-show-all");
      if (showAllBtn) {
        showAllBtn.style.display = hiddenCount > 0 ? "inline-block" : "none";
      }

      var callout = document.getElementById("shares-callout");
      if (callout) {
        SimCharts.renderCallout(
          "Each item\u2019s probability of being chosen from the full set, calculated using the multinomial logit (softmax) model. " +
          "All shares sum to 100%. Click the <strong>eye icon</strong> to hide items and see how shares redistribute among the remaining items.",
          callout
        );
      }
    }

    // Segment filter for shares
    var segSelectShares = document.getElementById("seg-filter-shares");
    if (segSelectShares) segSelectShares.addEventListener("change", updateShares);

    // Show all button
    var showAllBtn = document.getElementById("shares-show-all");
    if (showAllBtn) {
      showAllBtn.addEventListener("click", function() {
        hiddenItems = {};
        updateShares();
      });
    }

    // Segment comparison table toggle
    var segTableToggle = document.getElementById("seg-table-toggle");
    var segTableContainer = document.getElementById("seg-table-container");
    if (segTableToggle && segTableContainer) {
      segTableToggle.addEventListener("click", function() {
        var showing = segTableContainer.style.display !== "none";
        segTableContainer.style.display = showing ? "none" : "block";
        this.textContent = showing ? "Show Segment Table" : "Hide Segment Table";
        if (!showing) {
          var matrix = SimEngine.segmentComparisonMatrix();
          if (matrix) SimCharts.renderSegmentTable(matrix, segTableContainer);
        }
      });
    }

    updateShares();

    // --- Head-to-Head Tab ---
    function createH2HSlot(index, idA, idB) {
      return {index: index, idA: idA || "", idB: idB || ""};
    }

    function buildH2HControls() {
      var container = document.getElementById("h2h-slots");
      if (!container) return;

      var html = '';
      for (var i = 0; i < h2hSlots.length; i++) {
        var slot = h2hSlots[i];
        html += '<div class="sim-h2h-slot-controls" data-slot="' + i + '">' +
          '<div class="sim-h2h-slot-header">' +
            '<span class="sim-h2h-slot-num">Comparison ' + (i + 1) + '</span>' +
            (i > 0 ? '<button class="sim-h2h-remove-btn" data-slot="' + i + '">&times;</button>' : '') +
          '</div>' +
          '<div class="sim-h2h-controls">' +
            '<select class="h2h-select-a" data-slot="' + i + '">' + buildItemOptions(slot.idA) + '</select>' +
            '<span class="sim-vs">vs</span>' +
            '<select class="h2h-select-b" data-slot="' + i + '">' + buildItemOptions(slot.idB) + '</select>' +
          '</div>' +
          '<div class="sim-h2h-result" data-slot="' + i + '"></div>' +
        '</div>';
      }

      if (h2hSlots.length < MAX_H2H_SLOTS) {
        html += '<button id="h2h-add-btn" class="sim-btn sim-btn-outline">+ Add Comparison</button>';
      }

      container.innerHTML = html;

      // Wire events
      container.querySelectorAll(".h2h-select-a, .h2h-select-b").forEach(function(sel) {
        sel.addEventListener("change", function() {
          var slot = parseInt(this.getAttribute("data-slot"));
          var isA = this.classList.contains("h2h-select-a");
          if (isA) h2hSlots[slot].idA = this.value;
          else h2hSlots[slot].idB = this.value;
          updateH2HSlot(slot);
        });
      });

      container.querySelectorAll(".sim-h2h-remove-btn").forEach(function(btn) {
        btn.addEventListener("click", function() {
          var slot = parseInt(this.getAttribute("data-slot"));
          h2hSlots.splice(slot, 1);
          buildH2HControls();
          updateAllH2H();
        });
      });

      var addBtn = document.getElementById("h2h-add-btn");
      if (addBtn) {
        addBtn.addEventListener("click", function() {
          if (h2hSlots.length < MAX_H2H_SLOTS && simData.items.length >= 2) {
            var usedPairs = {};
            h2hSlots.forEach(function(s) { usedPairs[s.idA + ":" + s.idB] = true; });
            // Pick next unused pair
            var newA = simData.items[0].id;
            var newB = simData.items[1].id;
            for (var ai = 0; ai < simData.items.length && usedPairs[newA + ":" + newB]; ai++) {
              for (var bi = ai + 1; bi < simData.items.length; bi++) {
                newA = simData.items[ai].id;
                newB = simData.items[bi].id;
                if (!usedPairs[newA + ":" + newB]) break;
              }
            }
            h2hSlots.push(createH2HSlot(h2hSlots.length, newA, newB));
            buildH2HControls();
            updateAllH2H();
          }
        });
      }
    }

    function buildItemOptions(selectedId) {
      var html = '';
      for (var i = 0; i < simData.items.length; i++) {
        var it = simData.items[i];
        var sel = it.id === selectedId ? ' selected' : '';
        html += '<option value="' + SimCharts.escapeHtml(it.id) + '"' + sel + '>' + SimCharts.escapeHtml(it.label) + '</option>';
      }
      return html;
    }

    function updateH2HSlot(slotIndex) {
      var slot = h2hSlots[slotIndex];
      if (!slot || !slot.idA || !slot.idB || slot.idA === slot.idB) return;

      var segFilter = getSegFilter("seg-filter-h2h");
      var result = SimEngine.headToHead(slot.idA, slot.idB, segFilter);
      var container = document.querySelector('.sim-h2h-result[data-slot="' + slotIndex + '"]');
      if (container) SimCharts.renderHeadToHead(result, container);
    }

    function updateAllH2H() {
      for (var i = 0; i < h2hSlots.length; i++) {
        updateH2HSlot(i);
      }

      var callout = document.getElementById("h2h-callout");
      if (callout) {
        SimCharts.renderCallout(
          "Head-to-head shows the probability of choosing one item over another in a forced-choice scenario. " +
          "Based on the logistic function applied to individual-level utility differences. " +
          "Add up to " + MAX_H2H_SLOTS + " comparisons to evaluate multiple matchups simultaneously.",
          callout
        );
      }
    }

    // Initialize H2H with first pair
    if (simData.items.length >= 2) {
      h2hSlots.push(createH2HSlot(0, simData.items[0].id, simData.items[1].id));
      buildH2HControls();
      updateAllH2H();
    }

    // H2H segment filter
    var segSelectH2H = document.getElementById("seg-filter-h2h");
    if (segSelectH2H) segSelectH2H.addEventListener("change", updateAllH2H);

    // --- Portfolio (TURF) Tab ---
    var portfolioChecks = document.querySelectorAll(".sim-portfolio-check");
    var autoOptBtn = document.getElementById("turf-auto-optimize");
    var topKSelect = document.getElementById("turf-top-k");

    function getTopK() {
      return topKSelect ? parseInt(topKSelect.value) || 3 : 3;
    }

    function updateTurfReach() {
      var selected = [];
      portfolioChecks.forEach(function(cb) {
        if (cb.checked) selected.push(cb.value);
      });

      var segFilter = getSegFilter("seg-filter-turf");
      var segLabel = getSegLabel("seg-filter-turf");
      var result = SimEngine.turfReach(selected, getTopK(), segFilter);
      var container = document.getElementById("turf-result");
      if (container) SimCharts.renderTurfReach(result, container, segLabel);

      var countEl = document.getElementById("turf-count");
      if (countEl) countEl.textContent = selected.length + " items selected";

      var callout = document.getElementById("turf-callout");
      if (callout) {
        SimCharts.renderCallout(
          "Total Unduplicated Reach and Frequency (TURF) measures what % of respondents find at least one item in your portfolio " +
          "appealing (in their personal top-K items). Use <strong>Auto-Optimise</strong> to find the best portfolio of a given size.",
          callout
        );
      }
    }

    portfolioChecks.forEach(function(cb) {
      cb.addEventListener("change", updateTurfReach);
    });

    if (topKSelect) topKSelect.addEventListener("change", updateTurfReach);

    // TURF segment filter
    var segSelectTurf = document.getElementById("seg-filter-turf");
    if (segSelectTurf) segSelectTurf.addEventListener("change", updateTurfReach);

    if (autoOptBtn) {
      autoOptBtn.addEventListener("click", function() {
        var maxItems = parseInt(document.getElementById("turf-max-items").value) || 5;
        var segFilter = getSegFilter("seg-filter-turf");
        var results = SimEngine.turfOptimize(maxItems, getTopK(), segFilter);

        // Check the optimal items
        portfolioChecks.forEach(function(cb) { cb.checked = false; });
        results.forEach(function(r) {
          portfolioChecks.forEach(function(cb) {
            if (cb.value === r.itemId) cb.checked = true;
          });
        });

        updateTurfReach();

        // Show optimization result
        var listEl = document.getElementById("turf-opt-result");
        if (listEl && results.length > 0) {
          var html = '<div class="sim-turf-opt-list"><strong>Optimal portfolio:</strong><ol>';
          results.forEach(function(r) {
            html += '<li><strong>' + SimCharts.escapeHtml(r.label) + '</strong> (reach: ' + r.reach + '%, +' + r.incremental + '%)</li>';
          });
          html += '</ol></div>';
          listEl.innerHTML = html;
        }
      });
    }

    updateTurfReach();

    // Auto-run optimization on initial load
    if (autoOptBtn) {
      var defaultMaxItems = parseInt((document.getElementById("turf-max-items") || {}).value) || 5;
      var segFilter = getSegFilter("seg-filter-turf");
      var initResults = SimEngine.turfOptimize(defaultMaxItems, getTopK(), segFilter);

      // Check the optimal items
      portfolioChecks.forEach(function(cb) { cb.checked = false; });
      initResults.forEach(function(r) {
        portfolioChecks.forEach(function(cb) {
          if (cb.value === r.itemId) cb.checked = true;
        });
      });

      updateTurfReach();

      // Show optimization result
      var listEl = document.getElementById("turf-opt-result");
      if (listEl && initResults.length > 0) {
        var html = '<div class="sim-turf-opt-list"><strong>Optimal portfolio:</strong><ol>';
        initResults.forEach(function(r) {
          html += '<li><strong>' + SimCharts.escapeHtml(r.label) + '</strong> (reach: ' + r.reach + '%, +' + r.incremental + '%)</li>';
        });
        html += '</ol></div>';
        listEl.innerHTML = html;
      }
    }

    // --- Diagnostics Tab ---
    function updateDiagnostics() {
      var diag = SimEngine.getDiagnostics();
      var container = document.getElementById("diagnostics-content");
      if (container && diag) SimCharts.renderDiagnostics(diag, container);

      var callout = document.getElementById("diagnostics-callout");
      if (callout) {
        SimCharts.renderCallout(
          "Model diagnostics assess the reliability and validity of the MaxDiff analysis. " +
          "Key indicators include <strong>preference sharpness</strong> (how decisive respondents are), " +
          "<strong>heterogeneity</strong> (how much preferences vary), and <strong>item discrimination</strong> " +
          "(how effectively the study differentiates between items).",
          callout
        );
      }
    }
    updateDiagnostics();

    // --- Pinned Views Tab ---
    function updatePinBadge() {
      var badge = document.getElementById("pin-badge");
      if (!badge) return;
      var count = typeof SimPins !== "undefined" ? SimPins.getCount() : 0;
      badge.textContent = count;
      badge.style.display = count > 0 ? "inline-flex" : "none";
    }

    // Pin buttons
    document.querySelectorAll(".sim-pin-btn").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var tabId = this.getAttribute("data-pin-tab");
        if (typeof SimPins !== "undefined") {
          SimPins.captureView(tabId);
          updatePinBadge();
        }
      });
    });

    // Export buttons
    document.querySelectorAll(".sim-export-png-btn").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var tabId = this.getAttribute("data-export-tab");
        if (typeof SimExport !== "undefined") SimExport.exportPNG(tabId);
      });
    });

    document.querySelectorAll(".sim-export-excel-btn").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var tabId = this.getAttribute("data-export-tab");
        if (typeof SimExport !== "undefined") SimExport.exportExcel(tabId);
      });
    });

    // Make updatePinBadge available globally for SimPins to call
    window.SimUI = {
      updatePinBadge: updatePinBadge,
      getHiddenItems: function() { return hiddenItems; },
      getH2HSlots: function() { return h2hSlots; },
      getSegFilter: getSegFilter,
      getSegLabel: getSegLabel,
      getTopK: getTopK
    };

    // Initial pin badge
    updatePinBadge();

    function escapeHtml(str) {
      var div = document.createElement("div");
      div.appendChild(document.createTextNode(str || ""));
      return div.innerHTML;
    }
  });
})();
