/* ===========================================================================
   TURAS PRICING SIMULATOR - Core Engine
   Demand interpolation, revenue/profit calculation, UI updates
   =========================================================================== */

var TurasSimulator = (function() {
  "use strict";

  // State
  var state = {
    currentPrice: 0,
    currentSegment: "total",
    battleMode: false,
    battlePrices: [0, 0]
  };

  var data = null;   // Will be set from PRICING_DATA
  var config = null;  // Will be set from PRICING_CONFIG

  // =========================================================================
  // INITIALIZATION
  // =========================================================================

  function init(pricingData, pricingConfig) {
    data = pricingData;
    config = pricingConfig;

    // Set initial price to optimal
    state.currentPrice = data.optimal_price || data.price_range[Math.floor(data.price_range.length / 2)];

    setupSlider();
    setupScenarios();
    setupSegmentToggle();
    setupBattleMode();
    updateAll();
  }

  // =========================================================================
  // DEMAND INTERPOLATION (Monotone-preserving)
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

    // Clamp to range
    if (price <= prices[0]) return intents[0];
    if (price >= prices[prices.length - 1]) return intents[intents.length - 1];

    // Linear interpolation between adjacent points
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
    return interpolateIntent(price, segment) * 100; // Volume index (base 100)
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

    document.getElementById("sim-range-min").textContent = config.currency + formatNum(minPrice);
    document.getElementById("sim-range-max").textContent = config.currency + formatNum(maxPrice);

    slider.addEventListener("input", function() {
      state.currentPrice = parseFloat(this.value);
      updateAll();
    });
  }

  // =========================================================================
  // UI: METRICS UPDATE
  // =========================================================================

  function updateAll() {
    var price = state.currentPrice;
    var seg = state.currentSegment;

    // Price display
    setHTML("sim-current-price", config.currency + formatNum(price));

    // Metrics
    var intent = interpolateIntent(price, seg);
    var revenue = calcRevenue(price, seg);
    var profit = calcProfit(price, seg);
    var volume = calcVolume(price, seg);

    setHTML("sim-intent-value", (intent * 100).toFixed(1) + "%");
    setHTML("sim-revenue-value", formatNum(revenue));
    setHTML("sim-volume-value", formatNum(volume));

    if (config.unit_cost > 0) {
      setHTML("sim-profit-value", formatNum(profit));
      showEl("sim-profit-card");
    } else {
      hideEl("sim-profit-card");
    }

    // Deltas vs optimal
    if (data.optimal_price) {
      var optRevenue = calcRevenue(data.optimal_price, seg);
      var revDelta = ((revenue - optRevenue) / optRevenue * 100);
      setDelta("sim-revenue-delta", revDelta);
    }

    // Update chart
    updateChart(price, seg);

    // Update battle mode if active
    if (state.battleMode) {
      updateBattle();
    }

    // Deselect scenario cards if price doesn't match
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

    // Revenue curve
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

    // Demand line
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
      html += '<div class="sim-scenario-card" data-price="' + sc.price + '" data-idx="' + i + '">';
      html += '<div class="sim-scenario-name">' + escHTML(sc.name) + '</div>';
      html += '<div class="sim-scenario-price">' + config.currency + formatNum(sc.price) + '</div>';
      if (sc.description) html += '<div class="sim-scenario-desc">' + escHTML(sc.description) + '</div>';
      html += '</div>';
    }
    container.innerHTML = html;

    // Click handlers
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
  // UI: BATTLE MODE
  // =========================================================================

  function setupBattleMode() {
    var btn = document.getElementById("sim-battle-toggle");
    if (!btn) return;

    btn.addEventListener("click", function() {
      state.battleMode = !state.battleMode;
      var battleEl = document.getElementById("sim-battle-section");
      if (battleEl) {
        battleEl.classList.toggle("active", state.battleMode);
      }
      btn.textContent = state.battleMode ? "Exit Battle Mode" : "Battle Mode";
      if (state.battleMode) {
        state.battlePrices[0] = state.currentPrice;
        state.battlePrices[1] = data.optimal_price || state.currentPrice;
        setupBattleSliders();
        updateBattle();
      }
    });
  }

  function setupBattleSliders() {
    var minP = data.price_range[0];
    var maxP = data.price_range[data.price_range.length - 1];
    var step = (maxP - minP) / 200;

    for (var s = 0; s < 2; s++) {
      var slider = document.getElementById("sim-battle-slider-" + s);
      if (slider) {
        slider.min = minP;
        slider.max = maxP;
        slider.step = step;
        slider.value = state.battlePrices[s];
        (function(idx) {
          slider.addEventListener("input", function() {
            state.battlePrices[idx] = parseFloat(this.value);
            updateBattle();
          });
        })(s);
      }
    }
  }

  function updateBattle() {
    var labels = ["A", "B"];
    for (var b = 0; b < 2; b++) {
      var p = state.battlePrices[b];
      var intent = interpolateIntent(p);
      var rev = calcRevenue(p);
      var profit = calcProfit(p);

      setHTML("sim-battle-price-" + b, config.currency + formatNum(p));
      setHTML("sim-battle-intent-" + b, (intent * 100).toFixed(1) + "%");
      setHTML("sim-battle-revenue-" + b, formatNum(rev));
      if (config.unit_cost > 0) {
        setHTML("sim-battle-profit-" + b, formatNum(profit));
      }
    }

    // Highlight winner
    var rev0 = calcRevenue(state.battlePrices[0]);
    var rev1 = calcRevenue(state.battlePrices[1]);
    highlightWinner("sim-battle-revenue-0", "sim-battle-revenue-1", rev0, rev1);
  }

  function highlightWinner(id0, id1, v0, v1) {
    var el0 = document.getElementById(id0);
    var el1 = document.getElementById(id1);
    if (!el0 || !el1) return;
    el0.style.fontWeight = v0 >= v1 ? "700" : "400";
    el1.style.fontWeight = v1 >= v0 ? "700" : "400";
    el0.style.color = v0 >= v1 ? "var(--sim-green)" : "var(--sim-text)";
    el1.style.color = v1 >= v0 ? "var(--sim-green)" : "var(--sim-text)";
  }

  // =========================================================================
  // EXPORT TO PNG
  // =========================================================================

  function exportPNG() {
    // Use the browser's built-in SVG-to-canvas approach
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

      // Add watermark
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
    if (typeof n !== "number" || isNaN(n)) return "—";
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
    init: init,
    exportPNG: exportPNG,
    getState: function() { return state; }
  };

})();
