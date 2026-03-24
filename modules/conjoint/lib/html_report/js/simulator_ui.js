/**
 * Conjoint Simulator UI Controller (Combined Report Context)
 * Product configuration, mode switching, share display.
 * Uses cj-sim-* CSS classes; init called from navigation (not DOMContentLoaded).
 */

var SimUI = (function() {
  "use strict";

  var products = [];
  var productCounter = 0;
  var method = "logit";
  var currentMode = "shares";
  var includeNone = false;
  var _renameTimer = null;

  var _initialized = false;
  var _currencySymbol = "$";

  function init() {
    if (_initialized) return;
    var data = SimEngine.getData();
    if (!data || !data.attributes) return;

    _initialized = true;
    _currencySymbol = (data.meta && data.meta.currency_symbol) || "$";

    // Check for pre-defined products from config
    if (data.defaultProducts && Array.isArray(data.defaultProducts) && data.defaultProducts.length > 0) {
      data.defaultProducts.forEach(function(defProd) {
        productCounter++;
        var config = {};
        // Start with first level of each attribute as default
        data.attributes.forEach(function(attr) {
          config[attr.name] = attr.levels[0].name;
        });
        // Override with levels from the config product
        if (defProd.levels) {
          for (var attrName in defProd.levels) {
            if (defProd.levels.hasOwnProperty(attrName)) {
              config[attrName] = defProd.levels[attrName];
            }
          }
        }
        products.push({ name: defProd.name || ("Product " + productCounter), config: config });
      });
      renderProductPanels();
      updateResults();
    } else {
      // Start with 2 default products
      addProduct();
      addProduct();
      updateResults();
    }
  }

  function addProduct() {
    var data = SimEngine.getData();
    if (!data) return;
    if (products.length >= 12) {
      showSimToast("Maximum of 12 products reached");
      return;
    }

    productCounter++;
    var product = {};
    data.attributes.forEach(function(attr) {
      product[attr.name] = attr.levels[0].name;
    });
    products.push({ name: "Product " + productCounter, config: product });
    renderProductPanels();
    updateResults();
  }

  function removeProduct(idx) {
    if (products.length <= 1) return;
    products.splice(idx, 1);
    renderProductPanels();
    updateResults();
  }

  function copyProduct(idx) {
    if (products.length >= 12) {
      showSimToast("Maximum of 12 products reached");
      return;
    }
    var source = products[idx];
    if (!source) return;
    productCounter++;
    var configCopy = {};
    for (var k in source.config) configCopy[k] = source.config[k];
    products.splice(idx + 1, 0, { name: source.name + " (copy)", config: configCopy });
    renderProductPanels();
    updateResults();
  }

  function resetAll() {
    var data = SimEngine.getData();
    if (!data) return;
    products = [];
    productCounter = 0;
    addProduct();
    addProduct();
  }

  function toggleNone(checked) {
    includeNone = checked;
    updateResults();
  }

  function renderProductPanels() {
    var container = document.getElementById("cj-sim-products");
    if (!container) return;
    var data = SimEngine.getData();
    if (!data) return;

    // Table grid: rows = attributes, columns = products
    var html = '<table class="cj-sim-grid">';

    // Header row: attribute label + product names + add button
    html += '<thead><tr>';
    html += '<th class="cj-sim-grid-attr"></th>';
    products.forEach(function(prod, idx) {
      html += '<th class="cj-sim-grid-prod-header">';
      html += '<input type="text" class="cj-sim-product-name" value="' + escAttr(prod.name) + '" oninput="SimUI._debouncedRename(' + idx + ',this.value)" />';
      html += '<div class="cj-sim-grid-actions">';
      html += '<button class="cj-sim-grid-action" onclick="SimUI.copyProduct(' + idx + ')" title="Copy">\u2398</button>';
      if (products.length > 1) {
        html += '<button class="cj-sim-grid-action" onclick="SimUI.removeProduct(' + idx + ')" title="Remove">\u00d7</button>';
      }
      html += '</div>';
      html += '</th>';
    });
    // Add product column
    html += '<th class="cj-sim-grid-add">';
    if (products.length < 12) {
      html += '<button class="cj-sim-add-col-btn" onclick="SimUI.addProduct()" title="Add product">+</button>';
    }
    html += '</th>';
    html += '</tr></thead>';

    // Body rows: one per attribute
    html += '<tbody>';
    data.attributes.forEach(function(attr) {
      html += '<tr>';
      html += '<td class="cj-sim-grid-attr-label">' + escHtml(attr.name) + '</td>';
      products.forEach(function(prod, idx) {
        html += '<td class="cj-sim-grid-cell">';
        html += '<select class="cj-sim-select" onchange="SimUI.setLevel(' + idx + ',\'' + escAttr(attr.name) + '\',this.value)">';
        attr.levels.forEach(function(lev) {
          var selected = prod.config[attr.name] === lev.name ? " selected" : "";
          html += '<option value="' + escAttr(lev.name) + '"' + selected + '>' + escHtml(lev.name) + '</option>';
        });
        html += '</select></td>';
      });
      html += '<td></td>';  // empty cell under add column
      html += '</tr>';
    });
    html += '</tbody>';

    html += '</table>';

    // Controls row below grid
    html += '<div style="display:flex;gap:8px;align-items:center;margin-top:10px;">';
    html += '<button class="cj-sim-add-btn" style="background:#f1f5f9;color:#64748b;flex:0 0 auto;" onclick="SimUI.resetAll()">Reset All</button>';
    html += '</div>';

    container.innerHTML = html;
  }

  function renameProduct(idx, name) {
    if (products[idx]) {
      products[idx].name = name;
      // Update results without re-rendering panels (avoids losing input focus)
      updateResults();
    }
  }

  // Debounced rename: waits 300ms after last keystroke before updating results
  function _debouncedRename(idx, name) {
    if (products[idx]) {
      products[idx].name = name;
    }
    if (_renameTimer) clearTimeout(_renameTimer);
    _renameTimer = setTimeout(function() {
      updateResults();
    }, 300);
  }

  function setLevel(productIdx, attrName, levelName) {
    if (products[productIdx]) {
      products[productIdx].config[attrName] = levelName;
      updateResults();
    }
  }

  function setScaleFactor(val) {
    SimEngine.setScaleFactor(val);
    updateResults();
  }

  function switchMode(mode) {
    currentMode = mode;
    _sharesControlsRendered = false;  // Force controls rebuild when switching modes
    updateResults();
  }

  function updateResults() {
    if (products.length === 0) return;
    var resultsEl = document.getElementById("cj-sim-results");
    if (!resultsEl) return;

    if (currentMode === "shares") {
      renderShares(resultsEl);
    } else if (currentMode === "revenue") {
      renderRevenueMode(resultsEl);
    } else if (currentMode === "sensitivity") {
      renderSensitivityMode(resultsEl);
    } else if (currentMode === "sov") {
      renderSovMode(resultsEl);
    }
  }

  var _sharesControlsRendered = false;

  function renderSharesControls(container) {
    // Only render controls once — they persist across updates
    if (_sharesControlsRendered && document.getElementById("cj-sim-share-chart")) return;

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px;">Predicted Market Shares</h3>';

    // None option toggle
    html += '<div style="margin-bottom:10px;">';
    html += '<label style="font-size:12px;color:#64748b;cursor:pointer;display:inline-flex;align-items:center;gap:6px;">';
    html += '<input type="checkbox" id="cj-sim-none-cb" ' + (includeNone ? 'checked' : '') + ' onchange="SimUI.toggleNone(this.checked)" style="accent-color:#323367;" />';
    html += 'Include No-Purchase Option</label></div>';

    // Method selector with info tooltip
    html += '<div style="margin-bottom:12px;display:flex;align-items:center;gap:8px;">';
    html += '<select id="cj-sim-method-sel" class="cj-sim-select" style="width:auto;" onchange="SimUI.setMethod(this.value)">';
    html += '<option value="logit"' + (method === "logit" ? " selected" : "") + '>Logit (MNL)</option>';
    html += '<option value="rfc"' + (method === "rfc" ? " selected" : "") + '>RFC (Approximate)</option>';
    html += '<option value="purchase_likelihood"' + (method === "purchase_likelihood" ? " selected" : "") + '>Purchase Likelihood</option>';
    html += '<option value="first_choice"' + (method === "first_choice" ? " selected" : "") + '>First Choice</option>';
    html += '</select>';
    html += '<span class="cj-sim-tooltip-wrap" style="position:relative;display:inline-block;">';
    html += '<span style="display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;border-radius:50%;background:#e2e8f0;color:#64748b;font-size:11px;font-weight:600;cursor:help;">?</span>';
    html += '<span class="cj-sim-tooltip" style="display:none;position:absolute;left:24px;top:-8px;z-index:10;background:#1e293b;color:#f8fafc;font-size:11px;padding:10px 12px;border-radius:6px;width:280px;line-height:1.5;pointer-events:none;">';
    html += '<strong>Logit (MNL):</strong> Distributes shares proportionally based on utility differences.<br><br>';
    html += '<strong>RFC (Approximate):</strong> Adds Gumbel noise to aggregate utilities, counts first-choices across draws.<br><br>';
    html += '<strong>Purchase Likelihood:</strong> Independent purchase probability per product (values don\'t sum to 100%).<br><br>';
    html += '<strong>First Choice:</strong> 100% share to highest-utility product.';
    html += '</span></span>';
    html += '</div>';

    // Chart container (updated separately; revenue index merged into product grid table)
    html += '<div id="cj-sim-share-chart"></div>';

    // Scale factor in collapsible Advanced section
    var sf = SimEngine.getScaleFactor();
    html += '<details style="margin-top:16px;border-top:1px solid #f1f5f9;padding-top:12px;">';
    html += '<summary style="cursor:pointer;font-size:12px;font-weight:600;color:#64748b;user-select:none;">Advanced</summary>';
    html += '<div style="margin-top:10px;display:flex;align-items:center;gap:8px;">';
    html += '<label style="font-size:11px;color:#64748b;white-space:nowrap;">Scale factor:</label>';
    html += '<input type="range" id="cj-sim-scale-slider" min="0.1" max="3.0" step="0.1" value="' + sf.toFixed(1) + '" ';
    html += 'style="width:120px;accent-color:#323367;" ';
    html += 'oninput="SimUI.setScaleFactor(parseFloat(this.value));document.getElementById(\'cj-sim-scale-val\').textContent=parseFloat(this.value).toFixed(1)" />';
    html += '<span id="cj-sim-scale-val" style="font-size:12px;font-weight:600;color:#1e293b;min-width:24px;">' + sf.toFixed(1) + '</span>';
    html += '<span class="cj-sim-tooltip-wrap" style="position:relative;display:inline-block;">';
    html += '<span style="display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;border-radius:50%;background:#e2e8f0;color:#64748b;font-size:11px;font-weight:600;cursor:help;">?</span>';
    html += '<span class="cj-sim-tooltip" style="display:none;position:absolute;left:24px;top:-8px;z-index:10;background:#1e293b;color:#f8fafc;font-size:11px;padding:10px 12px;border-radius:6px;width:240px;line-height:1.5;pointer-events:none;">';
    html += 'Multiplies utilities before share computation. <strong>1.0</strong> = no adjustment. <strong>&gt;1</strong> = more differentiated shares. <strong>&lt;1</strong> = more equal shares.';
    html += '</span></span>';
    html += '</div>';
    html += '</details>';

    container.innerHTML = html;

    // Activate all tooltip hovers
    container.querySelectorAll(".cj-sim-tooltip-wrap").forEach(function(wrap) {
      var tip = wrap.querySelector(".cj-sim-tooltip");
      if (tip) {
        wrap.addEventListener("mouseenter", function() { tip.style.display = "block"; });
        wrap.addEventListener("mouseleave", function() { tip.style.display = "none"; });
      }
    });

    _sharesControlsRendered = true;
  }

  function renderShares(container) {
    // Render controls once, then only update chart area
    renderSharesControls(container);

    var configs = products.map(function(p) { return p.config; });
    var displayProducts = products.slice();
    var shares;

    if (includeNone) {
      var noneU = SimEngine.getNoneUtility();
      shares = SimEngine.predictSharesWithNone(configs, noneU, method);
      displayProducts = displayProducts.concat([{ name: "None (No Purchase)", config: {} }]);
    } else {
      shares = SimEngine.predictShares(configs, method);
    }

    // Only update the chart — controls stay intact; revenue index is in the product grid table
    SimCharts.renderShareBars("cj-sim-share-chart", displayProducts, shares);
  }

  function detectPriceAttribute() {
    var data = SimEngine.getData();
    if (!data || !data.attributes) return null;
    for (var i = 0; i < data.attributes.length; i++) {
      var name = data.attributes[i].name.toLowerCase();
      if (name.indexOf("price") >= 0 || name.indexOf("cost") >= 0 || name.indexOf("fee") >= 0) {
        return data.attributes[i].name;
      }
    }
    return null;
  }

  function extractPrice(product, priceAttr) {
    var val = product.config ? product.config[priceAttr] : product[priceAttr];
    if (!val) return 0;
    // Strip currency symbols and parse
    var num = parseFloat(String(val).replace(/[^0-9.\-]/g, ""));
    return isNaN(num) ? 0 : num;
  }

  function renderRevenueSummary(displayProducts, shares) {
    var revEl = document.getElementById("cj-sim-revenue");
    if (!revEl) return;
    var priceAttr = detectPriceAttribute();
    if (!priceAttr) { revEl.innerHTML = ""; return; }

    // Only show for actual products (not "None")
    var realProducts = products.length;
    var rows = "";
    var bestRevIdx = 0, bestRev = -Infinity;

    for (var i = 0; i < realProducts && i < shares.length; i++) {
      var price = extractPrice(products[i], priceAttr);
      var share = shares[i];
      var revenue = (share / 100) * price;
      if (revenue > bestRev) { bestRev = revenue; bestRevIdx = i; }
      rows += '<tr>';
      rows += '<td style="padding:4px 8px;font-size:12px;color:#334155;">' + escHtml(displayProducts[i].name) + '</td>';
      rows += '<td style="padding:4px 8px;font-size:12px;text-align:right;">' + share.toFixed(1) + '%</td>';
      rows += '<td style="padding:4px 8px;font-size:12px;text-align:right;">' + price.toFixed(0) + '</td>';
      rows += '<td style="padding:4px 8px;font-size:12px;text-align:right;font-weight:600;">' + revenue.toFixed(2) + '</td>';
      rows += '</tr>';
    }

    revEl.innerHTML =
      '<div style="margin-top:12px;border-top:1px solid #f1f5f9;padding-top:10px;">' +
      '<div style="display:flex;align-items:center;gap:6px;margin-bottom:6px;">' +
      '<span style="font-size:12px;font-weight:600;color:#1e293b;">Revenue Index</span>' +
      '<span style="font-size:11px;color:#64748b;">(share \u00d7 price)</span></div>' +
      '<table style="width:100%;border-collapse:collapse;">' +
      '<thead><tr style="border-bottom:1px solid #e2e8f0;">' +
      '<th style="padding:4px 8px;font-size:11px;color:#64748b;text-align:left;font-weight:500;">Product</th>' +
      '<th style="padding:4px 8px;font-size:11px;color:#64748b;text-align:right;font-weight:500;">Share</th>' +
      '<th style="padding:4px 8px;font-size:11px;color:#64748b;text-align:right;font-weight:500;">Price</th>' +
      '<th style="padding:4px 8px;font-size:11px;color:#64748b;text-align:right;font-weight:500;">Revenue</th>' +
      '</tr></thead><tbody>' + rows + '</tbody></table></div>';
  }

  // === REVENUE SIMULATOR MODE ===
  var revenueCustomers = 1000;
  var showShareBars = true;

  function toggleShareBars(checked) {
    showShareBars = checked;
    updateResults();
  }

  function setRevenueCustomers(val) {
    var n = parseInt(val, 10);
    if (!isNaN(n) && n > 0) {
      revenueCustomers = n;
      updateResults();
    }
  }

  function renderRevenueMode(container) {
    var priceAttr = detectPriceAttribute();
    if (!priceAttr) {
      container.innerHTML = '<div style="text-align:center;padding:40px;color:#94a3b8;">' +
        '<div style="font-size:18px;margin-bottom:8px;">Revenue Simulator Not Available</div>' +
        '<p style="font-size:13px;">No price attribute detected in the conjoint design. Revenue simulation requires a price attribute.</p></div>';
      return;
    }

    var configs = products.map(function(p) { return p.config; });
    var shares = SimEngine.predictShares(configs, method);
    var n_products = products.length;

    // Compute revenue per product
    var revenueData = [];
    var maxRevenue = 0;
    for (var i = 0; i < n_products; i++) {
      var price = extractPrice(products[i], priceAttr);
      var share = shares[i];
      var revenue = price * (share / 100) * revenueCustomers;
      revenueData.push({ name: products[i].name, share: share, price: price, revenue: revenue });
      if (revenue > maxRevenue) maxRevenue = revenue;
    }
    var totalRevenue = revenueData.reduce(function(s, d) { return s + d.revenue; }, 0);

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:4px;">Revenue Simulator</h3>';

    // Customer count input
    html += '<div style="display:flex;align-items:center;gap:8px;margin-bottom:16px;">';
    html += '<label style="font-size:12px;color:#64748b;">Hypothetical customers:</label>';
    html += '<input type="number" value="' + revenueCustomers + '" min="1" step="100" ';
    html += 'style="width:100px;padding:4px 8px;border:1px solid #e2e8f0;border-radius:4px;font-size:12px;text-align:right;" ';
    html += 'onchange="SimUI.setRevenueCustomers(this.value)" />';
    html += '<span style="font-size:11px;color:#94a3b8;">(Revenue = Price \u00d7 Share% \u00d7 Customers)</span>';
    html += '</div>';

    // Toggle for market share bars
    html += '<div style="margin-bottom:12px;">';
    html += '<label style="font-size:12px;color:#64748b;cursor:pointer;display:inline-flex;align-items:center;gap:6px;">';
    html += '<input type="checkbox" ' + (showShareBars ? 'checked' : '') + ' onchange="SimUI.toggleShareBars(this.checked)" style="accent-color:#323367;" />';
    html += 'Show market share bars</label></div>';

    // Stacked horizontal bars — Market Share row + Revenue row (OpinionX style)
    var barHeight = 36;
    var barGap = 8;
    var chartW = 600;
    var rowHeight = barHeight * 2 + barGap + 24;

    html += '<div style="overflow-x:auto;">';

    for (var p = 0; p < n_products; p++) {
      var d = revenueData[p];
      var shareW = Math.max(d.share, 2);
      var revW = maxRevenue > 0 ? (d.revenue / totalRevenue) * 100 : 0;
      var colours = ["#323367", "#c0695c", "#5b8c5a", "#d4a843", "#7c6fb0", "#4a90a4"];
      var colour = colours[p % colours.length];
      var lightColour = colour + "22";

      html += '<div style="margin-bottom:16px;">';
      html += '<div style="font-size:12px;font-weight:600;color:#1e293b;margin-bottom:4px;">' + escHtml(d.name) + '</div>';

      // Market Share bar (togglable)
      if (showShareBars) {
        html += '<div style="display:flex;align-items:center;gap:8px;margin-bottom:4px;">';
        html += '<span style="font-size:11px;color:#64748b;min-width:80px;text-align:right;">Market Share</span>';
        html += '<div style="flex:1;background:#f1f5f9;border-radius:4px;height:' + barHeight + 'px;position:relative;overflow:hidden;">';
        html += '<div style="width:' + shareW + '%;height:100%;background:' + colour + ';border-radius:4px;display:flex;align-items:center;justify-content:center;min-width:40px;transition:width 0.3s ease;">';
        html += '<span style="font-size:12px;font-weight:600;color:#fff;">' + d.share.toFixed(1) + '%</span>';
        html += '</div></div></div>';
      }

      // Revenue bar
      html += '<div style="display:flex;align-items:center;gap:8px;">';
      html += '<span style="font-size:11px;color:#64748b;min-width:80px;text-align:right;">Revenue</span>';
      html += '<div style="flex:1;background:#fef3c7;border-radius:4px;height:' + barHeight + 'px;position:relative;overflow:hidden;">';
      html += '<div style="width:' + Math.max(revW, 2) + '%;height:100%;background:#d4a843;border-radius:4px;display:flex;align-items:center;padding:0 10px;min-width:60px;transition:width 0.3s ease;">';
      html += '<span style="font-size:12px;font-weight:600;color:#fff;">' + _currencySymbol + d.revenue.toLocaleString(undefined, {minimumFractionDigits: 0, maximumFractionDigits: 0}) + '</span>';
      html += '</div></div></div>';

      html += '</div>';
    }

    html += '</div>';

    // Summary table
    html += '<div style="margin-top:12px;border-top:1px solid #f1f5f9;padding-top:10px;">';
    html += '<table style="width:100%;border-collapse:collapse;">';
    html += '<thead><tr style="border-bottom:1px solid #e2e8f0;">';
    html += '<th style="padding:6px 8px;font-size:11px;color:#64748b;text-align:left;font-weight:500;">Product</th>';
    html += '<th style="padding:6px 8px;font-size:11px;color:#64748b;text-align:right;font-weight:500;">Price</th>';
    html += '<th style="padding:6px 8px;font-size:11px;color:#64748b;text-align:right;font-weight:500;">Share</th>';
    html += '<th style="padding:6px 8px;font-size:11px;color:#64748b;text-align:right;font-weight:500;">Customers</th>';
    html += '<th style="padding:6px 8px;font-size:11px;color:#64748b;text-align:right;font-weight:600;">Revenue</th>';
    html += '</tr></thead><tbody>';
    for (var t = 0; t < revenueData.length; t++) {
      var rd = revenueData[t];
      var custCount = Math.round(revenueCustomers * rd.share / 100);
      html += '<tr' + (t === revenueData.length - 1 ? ' style="border-top:1px solid #e2e8f0;font-weight:600;"' : '') + '>';
      html += '<td style="padding:6px 8px;font-size:12px;">' + escHtml(rd.name) + '</td>';
      html += '<td style="padding:6px 8px;font-size:12px;text-align:right;">' + _currencySymbol + rd.price.toFixed(0) + '</td>';
      html += '<td style="padding:6px 8px;font-size:12px;text-align:right;">' + rd.share.toFixed(1) + '%</td>';
      html += '<td style="padding:6px 8px;font-size:12px;text-align:right;">' + custCount.toLocaleString() + '</td>';
      html += '<td style="padding:6px 8px;font-size:12px;text-align:right;font-weight:600;">' + _currencySymbol + rd.revenue.toLocaleString(undefined, {minimumFractionDigits: 0, maximumFractionDigits: 0}) + '</td>';
      html += '</tr>';
    }
    // Total row
    html += '<tr style="border-top:2px solid #1e293b;font-weight:600;">';
    html += '<td style="padding:6px 8px;font-size:12px;">Total</td>';
    html += '<td style="padding:6px 8px;"></td>';
    html += '<td style="padding:6px 8px;font-size:12px;text-align:right;">100%</td>';
    html += '<td style="padding:6px 8px;font-size:12px;text-align:right;">' + revenueCustomers.toLocaleString() + '</td>';
    html += '<td style="padding:6px 8px;font-size:12px;text-align:right;">' + _currencySymbol + totalRevenue.toLocaleString(undefined, {minimumFractionDigits: 0, maximumFractionDigits: 0}) + '</td>';
    html += '</tr></tbody></table></div>';

    container.innerHTML = html;
  }

  function renderSensitivityMode(container) {
    var data = SimEngine.getData();
    if (!data || products.length === 0) return;

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px;">Sensitivity Analysis</h3>';
    html += '<p style="font-size:12px;color:#64748b;margin-bottom:12px;">Sweep one attribute for a chosen product while holding others constant.</p>';
    html += '<div style="display:flex;gap:8px;margin-bottom:12px;">';

    // Product selector
    html += '<select id="cj-sens-product" class="cj-sim-select" style="width:auto;" onchange="SimUI.doSensitivity()">';
    products.forEach(function(prod, idx) {
      html += '<option value="' + idx + '">' + escHtml(prod.name) + '</option>';
    });
    html += '</select>';

    // Attribute selector
    html += '<select id="cj-sens-attr" class="cj-sim-select" style="width:auto;" onchange="SimUI.doSensitivity()">';
    data.attributes.forEach(function(attr) {
      html += '<option value="' + escAttr(attr.name) + '">' + escHtml(attr.name) + '</option>';
    });
    html += '</select>';
    html += '</div>';
    html += '<div id="cj-sens-chart"></div>';

    container.innerHTML = html;
    doSensitivity();
  }

  function doSensitivity() {
    var sel = document.getElementById("cj-sens-attr");
    var prodSel = document.getElementById("cj-sens-product");
    if (!sel || !sel.value) return;
    var prodIdx = prodSel ? parseInt(prodSel.value, 10) : 0;
    if (isNaN(prodIdx) || !products[prodIdx]) prodIdx = 0;
    var base = products[prodIdx].config;
    var others = products.filter(function(p, i) { return i !== prodIdx; }).map(function(p) { return p.config; });
    var results = SimEngine.sensitivitySweep(base, sel.value, others, method);
    SimCharts.renderSensitivity("cj-sens-chart", results, sel.value, products[prodIdx].name);
  }

  function renderSovMode(container) {
    if (products.length < 2) {
      container.innerHTML = '<p style="color:#94a3b8;text-align:center;padding:40px;">Add at least 2 products. The last product is treated as the new entrant.</p>';
      return;
    }

    var baselineProds = products.slice(0, -1);
    var baseline = baselineProds.map(function(p) { return p.config; });
    var newProd = products[products.length - 1].config;
    var baselineNames = baselineProds.map(function(p) { return p.name; });
    var newProdName = products[products.length - 1].name;
    var results = SimEngine.sourceOfVolume(baseline, newProd, method, baselineNames, newProdName);

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px;">Source of Volume</h3>';
    html += '<p style="font-size:12px;color:#64748b;margin-bottom:12px;">Shows where <strong>' + escHtml(newProdName) + '</strong> gains its share from existing products.</p>';
    html += '<div id="cj-sov-chart"></div>';

    container.innerHTML = html;
    SimCharts.renderSourceOfVolume("cj-sov-chart", results, products);
  }

  function setMethod(m) {
    method = m;
    updateResults();
  }

  function showSimToast(message) {
    var toast = document.createElement("div");
    toast.className = "cj-toast";
    toast.textContent = message;
    document.body.appendChild(toast);
    toast.offsetHeight;
    toast.classList.add("visible");
    setTimeout(function() {
      toast.classList.remove("visible");
      setTimeout(function() { toast.remove(); }, 350);
    }, 2000);
  }

  function getProducts() { return products; }

  function escHtml(s) {
    var d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  }

  function escAttr(s) {
    return s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/'/g, "&#39;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  return {
    init: init,
    setScaleFactor: setScaleFactor,
    setRevenueCustomers: setRevenueCustomers,
    toggleShareBars: toggleShareBars,
    addProduct: addProduct,
    removeProduct: removeProduct,
    copyProduct: copyProduct,
    resetAll: resetAll,
    toggleNone: toggleNone,
    renameProduct: renameProduct,
    _debouncedRename: _debouncedRename,
    setLevel: setLevel,
    setMethod: setMethod,
    switchMode: switchMode,
    updateResults: updateResults,
    doSensitivity: doSensitivity,
    getProducts: getProducts,
    get _initialized() { return _initialized; }
  };
})();
