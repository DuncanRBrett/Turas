/**
 * Conjoint Simulator UI Controller (Combined Report Context)
 * Product configuration, mode switching, share display.
 * Uses cj-sim-* CSS classes; init called from navigation (not DOMContentLoaded).
 */

var SimUI = (function() {
  "use strict";

  var products = [];
  var method = "logit";
  var currentMode = "shares";

  var _initialized = false;

  function init() {
    if (_initialized) return;
    var data = SimEngine.getData();
    if (!data || !data.attributes) return;

    _initialized = true;

    // Start with 2 default products
    addProduct();
    addProduct();
    updateResults();
  }

  function addProduct() {
    var data = SimEngine.getData();
    if (!data) return;
    if (products.length >= 8) return;

    var product = {};
    data.attributes.forEach(function(attr) {
      product[attr.name] = attr.levels[0].name;
    });
    products.push({ name: "Product " + (products.length + 1), config: product });
    renderProductPanels();
    updateResults();
  }

  function removeProduct(idx) {
    if (products.length <= 1) return;
    products.splice(idx, 1);
    products.forEach(function(p, i) { p.name = "Product " + (i + 1); });
    renderProductPanels();
    updateResults();
  }

  function renderProductPanels() {
    var container = document.getElementById("cj-sim-products");
    if (!container) return;
    var data = SimEngine.getData();
    if (!data) return;

    var html = "";
    products.forEach(function(prod, idx) {
      html += '<div class="cj-sim-product">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">';
      html += '<h4 style="margin:0;">' + escHtml(prod.name) + '</h4>';
      if (products.length > 1) {
        html += '<button style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:16px;" onclick="SimUI.removeProduct(' + idx + ')">\u00d7</button>';
      }
      html += '</div>';

      data.attributes.forEach(function(attr) {
        html += '<div style="margin-bottom:4px;">';
        html += '<label style="font-size:11px;color:#64748b;display:block;">' + escHtml(attr.name) + '</label>';
        html += '<select class="cj-sim-select" onchange="SimUI.setLevel(' + idx + ',\'' + escAttr(attr.name) + '\',this.value)">';
        attr.levels.forEach(function(lev) {
          var selected = prod.config[attr.name] === lev.name ? " selected" : "";
          html += '<option value="' + escAttr(lev.name) + '"' + selected + '>' + escHtml(lev.name) + '</option>';
        });
        html += '</select></div>';
      });

      html += '</div>';
    });

    html += '<button class="cj-sim-add-btn" onclick="SimUI.addProduct()">+ Add Product</button>';
    container.innerHTML = html;
  }

  function setLevel(productIdx, attrName, levelName) {
    if (products[productIdx]) {
      products[productIdx].config[attrName] = levelName;
      updateResults();
    }
  }

  function switchMode(mode) {
    currentMode = mode;
    updateResults();
  }

  function updateResults() {
    if (products.length === 0) return;
    var resultsEl = document.getElementById("cj-sim-results");
    if (!resultsEl) return;

    if (currentMode === "shares") {
      renderShares(resultsEl);
    } else if (currentMode === "sensitivity") {
      renderSensitivityMode(resultsEl);
    } else if (currentMode === "sov") {
      renderSovMode(resultsEl);
    }
  }

  function renderShares(container) {
    var configs = products.map(function(p) { return p.config; });
    var shares = SimEngine.predictShares(configs, method);

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px;">Predicted Market Shares</h3>';

    // Method selector
    html += '<div style="margin-bottom:12px;">';
    html += '<select class="cj-sim-select" style="width:auto;" onchange="SimUI.setMethod(this.value)">';
    html += '<option value="logit"' + (method === "logit" ? " selected" : "") + '>Logit (MNL)</option>';
    html += '<option value="first_choice"' + (method === "first_choice" ? " selected" : "") + '>First Choice</option>';
    html += '</select></div>';

    // Share bars
    html += '<div id="cj-sim-share-chart"></div>';

    container.innerHTML = html;

    // Render SVG bars
    SimCharts.renderShareBars("cj-sim-share-chart", products, shares);
  }

  function renderSensitivityMode(container) {
    var data = SimEngine.getData();
    if (!data || products.length === 0) return;

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px;">Sensitivity Analysis</h3>';
    html += '<p style="font-size:12px;color:#64748b;margin-bottom:12px;">Sweep one attribute for Product 1 while holding others constant.</p>';
    html += '<select id="cj-sens-attr" class="cj-sim-select" style="width:auto;margin-bottom:12px;" onchange="SimUI.doSensitivity()">';
    data.attributes.forEach(function(attr) {
      html += '<option value="' + escAttr(attr.name) + '">' + escHtml(attr.name) + '</option>';
    });
    html += '</select>';
    html += '<div id="cj-sens-chart"></div>';

    container.innerHTML = html;
    doSensitivity();
  }

  function doSensitivity() {
    var sel = document.getElementById("cj-sens-attr");
    if (!sel || !sel.value) return;
    var base = products[0].config;
    var others = products.slice(1).map(function(p) { return p.config; });
    var results = SimEngine.sensitivitySweep(base, sel.value, others, method);
    SimCharts.renderSensitivity("cj-sens-chart", results, sel.value);
  }

  function renderSovMode(container) {
    if (products.length < 2) {
      container.innerHTML = '<p style="color:#94a3b8;text-align:center;padding:40px;">Add at least 2 products. The last product is treated as the new entrant.</p>';
      return;
    }

    var baseline = products.slice(0, -1).map(function(p) { return p.config; });
    var newProd = products[products.length - 1].config;
    var results = SimEngine.sourceOfVolume(baseline, newProd, method);

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px;">Source of Volume</h3>';
    html += '<p style="font-size:12px;color:#64748b;margin-bottom:12px;">Shows where the last product gains its share from existing products.</p>';
    html += '<div id="cj-sov-chart"></div>';

    container.innerHTML = html;
    SimCharts.renderSourceOfVolume("cj-sov-chart", results);
  }

  function setMethod(m) {
    method = m;
    updateResults();
  }

  function escHtml(s) {
    var d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  }

  function escAttr(s) {
    return s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/'/g, "&#39;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  return {
    _initialized: _initialized,
    init: init,
    addProduct: addProduct,
    removeProduct: removeProduct,
    setLevel: setLevel,
    setMethod: setMethod,
    switchMode: switchMode,
    updateResults: updateResults,
    doSensitivity: doSensitivity,
    get _initialized() { return _initialized; }
  };
})();
