/* ===========================================================================
   TURAS PRICING REPORT - Simulator Engine
   Demand interpolation, revenue/profit calculation, interactive UI
   Adapted from simulator_core.js for consolidated report
   =========================================================================== */

var PricingSimulator = (function() {
  "use strict";

  // State
  var state = {
    currentPrice: 0,
    currentSegment: "total",
    scenarios: []  // Array of { price: number }
  };

  var MAX_SCENARIOS = 8;

  var data = null;
  var config = null;
  var _initialized = false;

  // =========================================================================
  // LAZY INITIALIZATION (deferred until simulator tab first activated)
  // =========================================================================

  function lazyInit() {
    if (_initialized) return;
    if (typeof PRICING_DATA === "undefined" || typeof PRICING_CONFIG === "undefined") return;

    data = PRICING_DATA;
    config = PRICING_CONFIG;

    if (!data || !data.price_range || data.price_range.length === 0) return;

    state.currentPrice = data.optimal_price || data.price_range[Math.floor(data.price_range.length / 2)];

    setupSlider();
    setupScenarios();
    setupSegmentToggle();
    setupUnitCostInput();
    setupScenarioComparison();
    updateAll();

    _initialized = true;
  }

  // =========================================================================
  // DEMAND INTERPOLATION
  // =========================================================================

  function interpolateIntent(price, segment) {
    var seg = segment || state.currentSegment;
    var prices, intents;

    if (seg === "total" || !data.segments || !data.segments[seg]) {
      prices = data.price_range;
      intents = data.demand_curve;
    } else {
      prices = data.segments[seg].price_range;
      intents = data.segments[seg].demand_curve;
    }

    if (!prices || !intents || prices.length === 0) return 0;

    if (price <= prices[0]) return intents[0];
    if (price >= prices[prices.length - 1]) return intents[intents.length - 1];

    for (var i = 1; i < prices.length; i++) {
      if (price <= prices[i]) {
        var t = (price - prices[i-1]) / (prices[i] - prices[i-1]);
        return intents[i-1] + t * (intents[i] - intents[i-1]);
      }
    }
    return intents[intents.length - 1];
  }

  function calcRevenue(price, segment) {
    return price * interpolateIntent(price, segment);
  }

  function calcProfit(price, segment) {
    var cost = config.unit_cost || 0;
    return (price - cost) * interpolateIntent(price, segment);
  }

  function calcVolume(price, segment) {
    return interpolateIntent(price, segment) * 100;
  }

  // =========================================================================
  // UI: SLIDER
  // =========================================================================

  function setupSlider() {
    var slider = document.getElementById("sim-price-slider");
    if (!slider) return;

    var minPrice = data.price_range[0];
    var maxPrice = data.price_range[data.price_range.length - 1];

    slider.min = minPrice;
    slider.max = maxPrice;
    slider.step = (maxPrice - minPrice) / 200;
    slider.value = state.currentPrice;

    setHTML("sim-range-min", config.currency + formatNum(minPrice));
    setHTML("sim-range-max", config.currency + formatNum(maxPrice));

    slider.addEventListener("input", function() {
      state.currentPrice = parseFloat(this.value);
      updateAll();
    });

    // Price input field
    var priceInput = document.getElementById("sim-price-input");
    if (priceInput) {
      priceInput.value = state.currentPrice.toFixed(2);
      priceInput.addEventListener("change", function() {
        var val = parseFloat(this.value);
        if (!isNaN(val) && val >= parseFloat(slider.min) && val <= parseFloat(slider.max)) {
          state.currentPrice = val;
          slider.value = val;
          updateAll();
        } else {
          this.value = state.currentPrice.toFixed(2);
        }
      });
    }
  }

  // =========================================================================
  // UI: METRICS UPDATE
  // =========================================================================

  function updateAll() {
    var price = state.currentPrice;
    var seg = state.currentSegment;

    setHTML("sim-current-price", config.currency + formatNum(price));

    var intent = interpolateIntent(price, seg);
    var revenue = calcRevenue(price, seg);
    var profit = calcProfit(price, seg);
    var volume = calcVolume(price, seg);

    setHTML("sim-intent-value", (intent * 100).toFixed(1) + "%");
    setHTML("sim-revenue-value", formatNum(revenue));
    setHTML("sim-volume-value", formatNum(volume));

    if (config.unit_cost > 0) {
      setHTML("sim-profit-value", formatNum(profit));
    } else {
      setHTML("sim-profit-value", "N/A");
    }

    if (data.optimal_price) {
      var optRevenue = calcRevenue(data.optimal_price, seg);
      var revDelta = ((revenue - optRevenue) / optRevenue * 100);
      setDelta("sim-revenue-delta", revDelta);
    }

    // Update price input field
    var priceInput = document.getElementById("sim-price-input");
    if (priceInput && document.activeElement !== priceInput) {
      priceInput.value = price.toFixed(2);
    }

    updateChart(price, seg);

    if (state.scenarios.length > 0) {
      renderComparisonTable();
    }

    deselectScenarios(price);
  }

  function setDelta(id, pct) {
    var el = document.getElementById(id);
    if (!el) return;
    if (Math.abs(pct) < 0.1) {
      el.textContent = "at optimum";
      el.className = "sim-metric-delta";
    } else {
      el.textContent = (pct > 0 ? "+" : "") + pct.toFixed(1) + "% vs optimum";
      el.className = "sim-metric-delta " + (pct >= 0 ? "positive" : "negative");
    }
  }

  // =========================================================================
  // UI: SVG CHART
  // =========================================================================

  function updateChart(price, segment) {
    var container = document.getElementById("sim-chart-svg");
    if (!container) return;

    // Check container has dimensions (avoids zero-size SVG when hidden)
    if (container.offsetWidth === 0) return;

    var prices = data.price_range;
    var intents = (segment !== "total" && data.segments && data.segments[segment])
      ? data.segments[segment].demand_curve
      : data.demand_curve;

    if (!prices || !intents) return;

    var w = 640, h = 280;
    var ml = 50, mr = 60, mt = 20, mb = 35;
    var cw = w - ml - mr, ch = h - mt - mb;

    var xMin = prices[0], xMax = prices[prices.length - 1];
    var sx = function(p) { return ml + (p - xMin) / (xMax - xMin) * cw; };
    var sy = function(v) { return mt + (1 - v) * ch; };

    var svg = [];

    // Grid
    for (var g = 0; g <= 1; g += 0.2) {
      var gy = sy(g);
      svg.push('<line x1="'+ml+'" y1="'+gy.toFixed(1)+'" x2="'+(w-mr)+'" y2="'+gy.toFixed(1)+'" stroke="#e2e8f0" stroke-width="1"/>');
      svg.push('<text x="'+(ml-6)+'" y="'+(gy+4).toFixed(1)+'" text-anchor="end" fill="#64748b" font-size="10">'+(g*100).toFixed(0)+'%</text>');
    }

    // Revenue curve (dashed)
    var revPoints = [];
    var revMax = 0;
    for (var r = 0; r < prices.length; r++) {
      var rv = prices[r] * intents[r];
      if (rv > revMax) revMax = rv;
    }
    if (revMax > 0) {
      for (var r2 = 0; r2 < prices.length; r2++) {
        var rv2 = prices[r2] * intents[r2] / revMax;
        revPoints.push(sx(prices[r2]).toFixed(1) + "," + sy(rv2).toFixed(1));
      }
      svg.push('<polyline points="' + revPoints.join(" ") + '" fill="none" stroke="#f39c12" stroke-width="1.5" stroke-dasharray="5,3" opacity="0.6"/>');
    }

    // Demand line (solid)
    var demandPoints = [];
    for (var d = 0; d < prices.length; d++) {
      demandPoints.push(sx(prices[d]).toFixed(1) + "," + sy(intents[d]).toFixed(1));
    }
    svg.push('<polyline points="' + demandPoints.join(" ") + '" fill="none" stroke="' + config.brand_colour + '" stroke-width="2.5"/>');

    // Current price marker
    var cpx = sx(price);
    var cpy = sy(interpolateIntent(price, segment));
    svg.push('<line x1="'+cpx.toFixed(1)+'" y1="'+mt+'" x2="'+cpx.toFixed(1)+'" y2="'+(h-mb)+'" stroke="#e74c3c" stroke-width="1.5" stroke-dasharray="4,3"/>');
    svg.push('<circle cx="'+cpx.toFixed(1)+'" cy="'+cpy.toFixed(1)+'" r="5" fill="#e74c3c" stroke="white" stroke-width="2"/>');

    // X-axis labels
    var ticks = niceScale(xMin, xMax, 6);
    for (var t = 0; t < ticks.length; t++) {
      if (ticks[t] < xMin || ticks[t] > xMax) continue;
      svg.push('<text x="'+sx(ticks[t]).toFixed(1)+'" y="'+(h-mb+16)+'" text-anchor="middle" fill="#64748b" font-size="10">'+config.currency+ticks[t].toFixed(0)+'</text>');
    }

    // Legend
    svg.push('<line x1="'+(w-mr+10)+'" y1="'+mt+'" x2="'+(w-mr+30)+'" y2="'+mt+'" stroke="'+config.brand_colour+'" stroke-width="2.5"/>');
    svg.push('<text x="'+(w-mr+34)+'" y="'+(mt+4)+'" fill="#64748b" font-size="10">Intent</text>');
    svg.push('<line x1="'+(w-mr+10)+'" y1="'+(mt+16)+'" x2="'+(w-mr+30)+'" y2="'+(mt+16)+'" stroke="#f39c12" stroke-width="1.5" stroke-dasharray="5,3"/>');
    svg.push('<text x="'+(w-mr+34)+'" y="'+(mt+20)+'" fill="#64748b" font-size="10">Revenue</text>');

    container.innerHTML = '<svg viewBox="0 0 '+w+' '+h+'" style="width:100%;height:auto;font-family:-apple-system,BlinkMacSystemFont,sans-serif;">' + svg.join("") + '</svg>';
  }

  // =========================================================================
  // UI: SCENARIOS
  // =========================================================================

  function setupScenarios() {
    if (!config.scenarios || config.scenarios.length === 0) {
      hideEl("sim-scenarios-section");
      return;
    }

    var container = document.getElementById("sim-scenario-cards");
    if (!container) return;

    var html = "";
    for (var i = 0; i < config.scenarios.length; i++) {
      var sc = config.scenarios[i];
      html += '<div class="sim-scenario-card" data-price="' + sc.price + '">';
      html += '<div class="sim-scenario-name">' + escHTML(sc.name) + '</div>';
      html += '<div class="sim-scenario-price">' + config.currency + formatNum(sc.price) + '</div>';
      if (sc.description) html += '<div class="sim-scenario-desc">' + escHTML(sc.description) + '</div>';
      html += '</div>';
    }
    container.innerHTML = html;

    var cards = container.querySelectorAll(".sim-scenario-card");
    for (var c = 0; c < cards.length; c++) {
      cards[c].addEventListener("click", function() {
        var p = parseFloat(this.getAttribute("data-price"));
        state.currentPrice = p;
        document.getElementById("sim-price-slider").value = p;
        selectScenarioCard(this);
        updateAll();
      });
    }
  }

  function selectScenarioCard(card) {
    var all = document.querySelectorAll(".sim-scenario-card");
    for (var i = 0; i < all.length; i++) all[i].classList.remove("active");
    card.classList.add("active");
  }

  function deselectScenarios(price) {
    var cards = document.querySelectorAll(".sim-scenario-card");
    for (var i = 0; i < cards.length; i++) {
      var cp = parseFloat(cards[i].getAttribute("data-price"));
      if (Math.abs(cp - price) < 0.01) {
        cards[i].classList.add("active");
      } else {
        cards[i].classList.remove("active");
      }
    }
  }

  // =========================================================================
  // UI: SEGMENTS
  // =========================================================================

  function setupSegmentToggle() {
    if (!data.segments || Object.keys(data.segments).length === 0) {
      hideEl("sim-segment-section");
      return;
    }

    var container = document.getElementById("sim-segment-buttons");
    if (!container) return;

    var html = '<button class="sim-segment-btn active" data-seg="total">Total</button>';
    var segNames = Object.keys(data.segments);
    for (var i = 0; i < segNames.length; i++) {
      html += '<button class="sim-segment-btn" data-seg="' + escHTML(segNames[i]) + '">' + escHTML(segNames[i]) + '</button>';
    }
    container.innerHTML = html;

    var btns = container.querySelectorAll(".sim-segment-btn");
    for (var b = 0; b < btns.length; b++) {
      btns[b].addEventListener("click", function() {
        for (var j = 0; j < btns.length; j++) btns[j].classList.remove("active");
        this.classList.add("active");
        state.currentSegment = this.getAttribute("data-seg");
        updateAll();
      });
    }
  }

  // =========================================================================
  // UI: UNIT COST INPUT
  // =========================================================================

  function setupUnitCostInput() {
    var input = document.getElementById("sim-unit-cost-input");
    if (!input) return;

    input.value = config.unit_cost > 0 ? config.unit_cost.toFixed(2) : "";

    input.addEventListener("change", function() {
      var val = parseFloat(this.value);
      if (isNaN(val) || val < 0) val = 0;
      config.unit_cost = val;
      this.value = val > 0 ? val.toFixed(2) : "";
      updateAll();
      if (state.scenarios.length > 0) renderComparisonTable();
    });
  }

  // =========================================================================
  // UI: SCENARIO COMPARISON TABLE
  // =========================================================================

  function setupScenarioComparison() {
    var addBtn = document.getElementById("sim-compare-add");
    if (!addBtn) return;

    addBtn.addEventListener("click", function() {
      if (state.scenarios.length >= MAX_SCENARIOS) return;
      state.scenarios.push({ price: state.currentPrice });
      renderComparisonTable();
    });
  }

  function removeScenario(idx) {
    state.scenarios.splice(idx, 1);
    renderComparisonTable();
  }

  function onScenarioPriceChange(idx, value) {
    var p = parseFloat(value);
    if (isNaN(p)) return;
    var minP = data.price_range[0];
    var maxP = data.price_range[data.price_range.length - 1];
    if (p < minP) p = minP;
    if (p > maxP) p = maxP;
    state.scenarios[idx].price = p;
    renderComparisonTable();
  }

  function renderComparisonTable() {
    var thead = document.getElementById("sim-compare-thead");
    var tbody = document.getElementById("sim-compare-tbody");
    if (!thead || !tbody) return;

    var scenarios = state.scenarios;
    if (scenarios.length === 0) {
      thead.innerHTML = "";
      tbody.innerHTML = "";
      return;
    }

    var seg = state.currentSegment;
    var optPrice = data.optimal_price || 0;
    var optRevenue = optPrice > 0 ? calcRevenue(optPrice, seg) : 0;
    var hasProfit = config.unit_cost > 0;
    var optProfit = hasProfit && optPrice > 0 ? calcProfit(optPrice, seg) : 0;

    var metrics = [];
    for (var i = 0; i < scenarios.length; i++) {
      var p = scenarios[i].price;
      var intent = interpolateIntent(p, seg);
      var rev = calcRevenue(p, seg);
      var revIdx = optRevenue > 0 ? (rev / optRevenue * 100) : 0;
      var profit = hasProfit ? calcProfit(p, seg) : 0;
      var profIdx = optProfit > 0 ? (profit / optProfit * 100) : 0;
      metrics.push({
        price: p, intent: intent, revenue: rev,
        revenueIndex: revIdx, profit: profit, profitIndex: profIdx
      });
    }

    var bestRev = -Infinity, worstRev = Infinity;
    var bestProf = -Infinity, worstProf = Infinity;
    if (metrics.length > 1) {
      for (var j = 0; j < metrics.length; j++) {
        if (metrics[j].revenueIndex > bestRev) bestRev = metrics[j].revenueIndex;
        if (metrics[j].revenueIndex < worstRev) worstRev = metrics[j].revenueIndex;
        if (hasProfit) {
          if (metrics[j].profitIndex > bestProf) bestProf = metrics[j].profitIndex;
          if (metrics[j].profitIndex < worstProf) worstProf = metrics[j].profitIndex;
        }
      }
    }

    // Header
    var hdr = "<th>Metric</th>";
    for (var h = 0; h < scenarios.length; h++) {
      var removeBtn = '<button class="sim-remove-scenario" onclick="PricingSimulator._removeScenario(' + h + ')">&times;</button>';
      hdr += "<th>Scenario " + (h + 1) + removeBtn + "</th>";
    }
    thead.innerHTML = hdr;

    // Rows
    var rows = "";
    var minP = data.price_range[0];
    var maxP = data.price_range[data.price_range.length - 1];

    // Price (editable)
    rows += "<tr><td>Price (" + escHTML(config.currency) + ")</td>";
    for (var r = 0; r < scenarios.length; r++) {
      rows += '<td><input type="number" value="' + scenarios[r].price.toFixed(2) +
        '" step="0.50" min="' + minP + '" max="' + maxP +
        '" onchange="PricingSimulator._onPriceChange(' + r + ',this.value)"></td>';
    }
    rows += "</tr>";

    // Purchase Intent
    rows += "<tr><td>Purchase Intent</td>";
    for (var a = 0; a < metrics.length; a++) {
      rows += "<td>" + (metrics[a].intent * 100).toFixed(1) + "%</td>";
    }
    rows += "</tr>";

    // Revenue Index
    rows += "<tr><td>Revenue Index</td>";
    for (var b = 0; b < metrics.length; b++) {
      var rCls = "";
      if (metrics.length > 1) {
        if (metrics[b].revenueIndex === bestRev) rCls = ' class="sim-best"';
        else if (metrics[b].revenueIndex === worstRev) rCls = ' class="sim-worst"';
      }
      var rLabel = metrics[b].revenueIndex.toFixed(0);
      if (Math.abs(metrics[b].revenueIndex - 100) < 0.5) rLabel += ' <span class="sim-at-opt">(peak)</span>';
      rows += "<td" + rCls + ">" + rLabel + "</td>";
    }
    rows += "</tr>";

    // Profit Index (N/A if no unit cost)
    rows += "<tr><td>Profit Index</td>";
    if (hasProfit) {
      for (var c = 0; c < metrics.length; c++) {
        var pCls = "";
        if (metrics.length > 1) {
          if (metrics[c].profitIndex === bestProf) pCls = ' class="sim-best"';
          else if (metrics[c].profitIndex === worstProf) pCls = ' class="sim-worst"';
        }
        var pLabel = metrics[c].profitIndex.toFixed(0);
        if (Math.abs(metrics[c].profitIndex - 100) < 0.5) pLabel += ' <span class="sim-at-opt">(peak)</span>';
        rows += "<td" + pCls + ">" + pLabel + "</td>";
      }
    } else {
      for (var c2 = 0; c2 < metrics.length; c2++) {
        rows += '<td style="color:#94a3b8;">N/A</td>';
      }
    }
    rows += "</tr>";

    // vs Optimal
    if (optPrice > 0) {
      rows += "<tr><td>vs Optimal (" + escHTML(config.currency) + formatNum(optPrice) + ")</td>";
      for (var d = 0; d < metrics.length; d++) {
        var revDiff = metrics[d].revenueIndex - 100;
        var label;
        if (Math.abs(revDiff) < 0.5) {
          label = '<span class="sim-best">at optimum</span>';
        } else {
          var sign = revDiff > 0 ? "+" : "";
          label = sign + revDiff.toFixed(0) + "% revenue";
          if (hasProfit) {
            var profDiff = metrics[d].profitIndex - 100;
            label += ", " + (profDiff > 0 ? "+" : "") + profDiff.toFixed(0) + "% profit";
          }
        }
        rows += "<td>" + label + "</td>";
      }
      rows += "</tr>";
    }

    tbody.innerHTML = rows;
  }

  // =========================================================================
  // EXPORT TO PNG
  // =========================================================================

  function exportPNG() {
    var svgEl = document.querySelector("#sim-chart-svg svg");
    if (!svgEl) { alert("No chart to export"); return; }

    var svgData = new XMLSerializer().serializeToString(svgEl);
    var canvas = document.createElement("canvas");
    var ctx = canvas.getContext("2d");

    var img = new Image();
    img.onload = function() {
      canvas.width = img.width * 2;
      canvas.height = img.height * 2;
      ctx.scale(2, 2);
      ctx.fillStyle = "white";
      ctx.fillRect(0, 0, img.width, img.height);
      ctx.drawImage(img, 0, 0);

      ctx.font = "10px sans-serif";
      ctx.fillStyle = "#94a3b8";
      ctx.fillText("TURAS Pricing Simulator", 10, img.height - 10);

      var link = document.createElement("a");
      link.download = "pricing_simulator.png";
      link.href = canvas.toDataURL("image/png");
      link.click();
    };

    img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)));
  }

  // =========================================================================
  // UTILITIES
  // =========================================================================

  function formatNum(n) {
    if (typeof n !== "number" || isNaN(n)) return "\u2014";
    return n.toFixed(2);
  }

  function setHTML(id, html) {
    var el = document.getElementById(id);
    if (el) el.innerHTML = html;
  }

  function showEl(id) {
    var el = document.getElementById(id);
    if (el) el.style.display = "";
  }

  function hideEl(id) {
    var el = document.getElementById(id);
    if (el) el.style.display = "none";
  }

  function escHTML(s) {
    if (!s) return "";
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function niceScale(min, max, n) {
    var range = max - min;
    var step = Math.pow(10, Math.floor(Math.log10(range / n)));
    if (range / step > n * 2) step *= 2;
    if (range / step > n * 2) step *= 2.5;
    var ticks = [];
    var start = Math.ceil(min / step) * step;
    for (var t = start; t <= max; t += step) {
      ticks.push(Math.round(t * 100) / 100);
    }
    return ticks;
  }

  // Public API
  return {
    lazyInit: lazyInit,
    exportPNG: exportPNG,
    getState: function() { return state; },
    _initialized: _initialized,
    _removeScenario: removeScenario,
    _onPriceChange: onScenarioPriceChange
  };

})();
