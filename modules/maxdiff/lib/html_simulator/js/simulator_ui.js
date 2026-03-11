/**
 * TURAS MaxDiff Simulator UI v11.0
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

    // --- Tab switching ---
    var tabs = document.querySelectorAll(".sim-tab-btn");
    var panels = document.querySelectorAll(".sim-panel");
    tabs.forEach(function(tab) {
      tab.addEventListener("click", function() {
        var target = this.getAttribute("data-tab");
        tabs.forEach(function(t) { t.classList.remove("active"); });
        panels.forEach(function(p) { p.classList.remove("active"); });
        this.classList.add("active");
        var panel = document.getElementById("panel-" + target);
        if (panel) panel.classList.add("active");
      });
    });

    // --- Shares Tab ---
    function updateShares() {
      var segFilter = null;
      var segSelect = document.getElementById("seg-filter");
      if (segSelect) segFilter = segSelect.value || null;

      var shares = SimEngine.computeShares(segFilter);
      shares.sort(function(a, b) { return b.share - a.share; });

      var container = document.getElementById("shares-chart");
      if (container) SimCharts.renderShareBars(shares, container);
    }

    // Segment filter
    var segSelect = document.getElementById("seg-filter");
    if (segSelect) {
      segSelect.addEventListener("change", updateShares);
    }

    updateShares();

    // --- Head-to-Head Tab ---
    var h2hSelectA = document.getElementById("h2h-item-a");
    var h2hSelectB = document.getElementById("h2h-item-b");

    function updateH2H() {
      if (!h2hSelectA || !h2hSelectB) return;
      var idA = h2hSelectA.value;
      var idB = h2hSelectB.value;
      if (!idA || !idB || idA === idB) return;

      var result = SimEngine.headToHead(idA, idB);
      var container = document.getElementById("h2h-result");
      if (container) SimCharts.renderHeadToHead(result, container);
    }

    if (h2hSelectA) h2hSelectA.addEventListener("change", updateH2H);
    if (h2hSelectB) h2hSelectB.addEventListener("change", updateH2H);

    // Initialize with first two items
    if (h2hSelectA && h2hSelectB && simData.items.length >= 2) {
      h2hSelectA.value = simData.items[0].id;
      h2hSelectB.value = simData.items[1].id;
      updateH2H();
    }

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

      var result = SimEngine.turfReach(selected, getTopK());
      var container = document.getElementById("turf-result");
      if (container) SimCharts.renderTurfReach(result, container);

      // Update count
      var countEl = document.getElementById("turf-count");
      if (countEl) countEl.textContent = selected.length + " items selected";
    }

    portfolioChecks.forEach(function(cb) {
      cb.addEventListener("change", updateTurfReach);
    });

    if (topKSelect) topKSelect.addEventListener("change", updateTurfReach);

    if (autoOptBtn) {
      autoOptBtn.addEventListener("click", function() {
        var maxItems = parseInt(document.getElementById("turf-max-items").value) || 5;
        var results = SimEngine.turfOptimize(maxItems, getTopK());

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
            html += '<li>' + SimCharts.__proto__ ? '' : '';
            html += '<li><strong>' + escapeHtml(r.label) + '</strong> (reach: ' + r.reach + '%, +' + r.incremental + '%)</li>';
          });
          html += '</ol></div>';
          listEl.innerHTML = html;
        }
      });
    }

    updateTurfReach();

    function escapeHtml(str) {
      var div = document.createElement("div");
      div.appendChild(document.createTextNode(str || ""));
      return div.innerHTML;
    }
  });
})();
