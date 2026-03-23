/**
 * Conjoint Simulator UI Controller
 * Handles product configuration, tab switching, and share updates
 */

var SimUI = (function() {
  "use strict";

  var products = [];
  var activeTab = "simulator";
  var method = "logit";

  function init() {
    var data = SimEngine.getData();
    if (!data) return;

    // Initialize with 2 default products
    addProduct();
    addProduct();
    updateShares();

    // Set up method selector
    var methodSel = document.getElementById("sim-method");
    if (methodSel) {
      methodSel.addEventListener("change", function() {
        method = this.value;
        updateShares();
      });
    }

    // Set up add product button
    var addBtn = document.getElementById("sim-add-product");
    if (addBtn) {
      addBtn.addEventListener("click", function() {
        if (products.length < 8) { addProduct(); updateShares(); }
      });
    }
  }

  function addProduct() {
    var data = SimEngine.getData();
    var product = {};
    data.attributes.forEach(function(attr) {
      product[attr.name] = attr.levels[0].name;
    });
    products.push({ name: "Product " + (products.length + 1), config: product });
    renderProductPanels();
  }

  function removeProduct(idx) {
    if (products.length <= 1) return;
    products.splice(idx, 1);
    // Re-number
    products.forEach(function(p, i) { p.name = "Product " + (i + 1); });
    renderProductPanels();
    updateShares();
  }

  function renderProductPanels() {
    var container = document.getElementById("sim-products");
    if (!container) return;
    var data = SimEngine.getData();

    var html = "";
    products.forEach(function(prod, idx) {
      html += '<div class="sim-product-card">';
      html += '<div class="sim-product-header">';
      html += '<strong>' + prod.name + '</strong>';
      if (products.length > 1) {
        html += ' <button class="sim-remove-btn" onclick="SimUI.removeProduct(' + idx + ')">\u00d7</button>';
      }
      html += '</div>';

      data.attributes.forEach(function(attr) {
        html += '<div class="sim-attr-row">';
        html += '<label>' + attr.name + '</label>';
        html += '<select onchange="SimUI.setLevel(' + idx + ',\'' + attr.name + '\',this.value)">';
        attr.levels.forEach(function(lev) {
          var selected = prod.config[attr.name] === lev.name ? " selected" : "";
          html += '<option value="' + lev.name + '"' + selected + '>' + lev.name + '</option>';
        });
        html += '</select>';
        html += '</div>';
      });

      html += '</div>';
    });

    container.innerHTML = html;
  }

  function setLevel(productIdx, attrName, levelName) {
    products[productIdx].config[attrName] = levelName;
    updateShares();
  }

  function updateShares() {
    var configs = products.map(function(p) { return p.config; });
    var shares = SimEngine.predictShares(configs, method);

    SimCharts.renderShareBars("sim-share-chart", products, shares);

    // Update share numbers
    var shareList = document.getElementById("sim-share-numbers");
    if (shareList) {
      var html = "";
      products.forEach(function(p, i) {
        html += '<div class="sim-share-item"><span>' + p.name + '</span><span class="sim-share-value">' + shares[i].toFixed(1) + '%</span></div>';
      });
      shareList.innerHTML = html;
    }
  }

  function switchTab(tabName) {
    activeTab = tabName;
    document.querySelectorAll(".sim-tab").forEach(function(t) { t.classList.remove("active"); });
    document.querySelectorAll(".sim-panel").forEach(function(p) { p.classList.remove("active"); });
    var btn = document.querySelector('.sim-tab[data-tab="' + tabName + '"]');
    if (btn) btn.classList.add("active");
    var panel = document.getElementById("sim-panel-" + tabName);
    if (panel) panel.classList.add("active");

    if (tabName === "sensitivity") renderSensitivity();
  }

  function renderSensitivity() {
    var data = SimEngine.getData();
    if (!data || products.length === 0) return;

    var container = document.getElementById("sim-sensitivity-content");
    if (!container) return;

    // Build attribute selector if not exists
    var attrSel = document.getElementById("sim-sens-attr");
    if (!attrSel) return;

    if (attrSel.options.length === 0) {
      data.attributes.forEach(function(attr) {
        var opt = document.createElement("option");
        opt.value = attr.name;
        opt.textContent = attr.name;
        attrSel.appendChild(opt);
      });
      attrSel.addEventListener("change", function() { doSensitivity(); });
    }
    doSensitivity();
  }

  function doSensitivity() {
    var attrSel = document.getElementById("sim-sens-attr");
    if (!attrSel || !attrSel.value) return;

    var baseProduct = products[0].config;
    var others = products.slice(1).map(function(p) { return p.config; });
    var results = SimEngine.sensitivitySweep(baseProduct, attrSel.value, others, method);
    SimCharts.renderSensitivity("sim-sensitivity-chart", results, attrSel.value);
  }

  return {
    init: init,
    addProduct: addProduct,
    removeProduct: removeProduct,
    setLevel: setLevel,
    switchTab: switchTab,
    updateShares: updateShares
  };
})();

document.addEventListener("DOMContentLoaded", function() {
  var dataEl = document.getElementById("sim-data");
  if (dataEl) {
    var simData = JSON.parse(dataEl.textContent);
    SimEngine.init(simData);
    SimCharts.setBrand(getComputedStyle(document.documentElement).getPropertyValue("--cj-brand").trim() || "#323367");
    SimUI.init();
  }
});
