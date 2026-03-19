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

  function init() {
    if (_initialized) return;
    var data = SimEngine.getData();
    if (!data || !data.attributes) return;

    _initialized = true;

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

    var html = "";
    products.forEach(function(prod, idx) {
      html += '<div class="cj-sim-product">';
      html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">';
      html += '<input type="text" class="cj-sim-product-name" value="' + escAttr(prod.name) + '" oninput="SimUI._debouncedRename(' + idx + ',this.value)" />';
      html += '<div style="display:flex;gap:4px;">';
      html += '<button style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:12px;" onclick="SimUI.copyProduct(' + idx + ')" title="Copy product">&#x2398;</button>';
      if (products.length > 1) {
        html += '<button style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:16px;" onclick="SimUI.removeProduct(' + idx + ')">\u00d7</button>';
      }
      html += '</div>';
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

    html += '<div style="display:flex;gap:8px;align-items:center;">';
    if (products.length >= 12) {
      html += '<button class="cj-sim-add-btn" style="opacity:0.4;pointer-events:none;flex:1;">+ Add Product (Max 12)</button>';
    } else {
      html += '<button class="cj-sim-add-btn" onclick="SimUI.addProduct()" style="flex:1;">+ Add Product</button>';
    }
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
    var displayProducts = products.slice();
    var shares;

    if (includeNone) {
      var noneU = SimEngine.getNoneUtility();
      shares = SimEngine.predictSharesWithNone(configs, noneU, method);
      // Add a "None" entry for display
      displayProducts = displayProducts.concat([{ name: "None (No Purchase)", config: {} }]);
    } else {
      shares = SimEngine.predictShares(configs, method);
    }

    var html = '<h3 style="font-size:14px;font-weight:600;color:#1e293b;margin-bottom:12px;">Predicted Market Shares</h3>';

    // None option toggle
    html += '<div style="margin-bottom:10px;">';
    html += '<label style="font-size:12px;color:#64748b;cursor:pointer;display:inline-flex;align-items:center;gap:6px;">';
    html += '<input type="checkbox" ' + (includeNone ? 'checked' : '') + ' onchange="SimUI.toggleNone(this.checked)" style="accent-color:#323367;" />';
    html += 'Include No-Purchase Option</label></div>';

    // Method selector with info tooltip
    html += '<div style="margin-bottom:12px;display:flex;align-items:center;gap:8px;">';
    html += '<select class="cj-sim-select" style="width:auto;" onchange="SimUI.setMethod(this.value)">';
    html += '<option value="logit"' + (method === "logit" ? " selected" : "") + '>Logit (MNL)</option>';
    html += '<option value="first_choice"' + (method === "first_choice" ? " selected" : "") + '>First Choice</option>';
    html += '</select>';
    html += '<span class="cj-sim-tooltip-wrap" style="position:relative;display:inline-block;">';
    html += '<span style="display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;border-radius:50%;background:#e2e8f0;color:#64748b;font-size:11px;font-weight:600;cursor:help;">?</span>';
    html += '<span class="cj-sim-tooltip" style="display:none;position:absolute;left:24px;top:-8px;z-index:10;background:#1e293b;color:#f8fafc;font-size:11px;padding:10px 12px;border-radius:6px;width:260px;line-height:1.5;pointer-events:none;">';
    html += '<strong>Logit (MNL):</strong> Distributes shares proportionally based on utility differences. Reflects realistic substitution patterns.<br><br>';
    html += '<strong>First Choice:</strong> Awards 100% share to the highest-utility product. Best for winner-takes-all scenarios.';
    html += '</span></span>';
    html += '</div>';

    // Share bars
    html += '<div id="cj-sim-share-chart"></div>';

    container.innerHTML = html;

    // Activate tooltip hover
    var wrap = container.querySelector(".cj-sim-tooltip-wrap");
    if (wrap) {
      var tip = wrap.querySelector(".cj-sim-tooltip");
      wrap.addEventListener("mouseenter", function() { tip.style.display = "block"; });
      wrap.addEventListener("mouseleave", function() { tip.style.display = "none"; });
    }

    // Render SVG bars
    SimCharts.renderShareBars("cj-sim-share-chart", displayProducts, shares);
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
    _initialized: _initialized,
    init: init,
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
