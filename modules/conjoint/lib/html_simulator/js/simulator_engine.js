/**
 * Conjoint Market Simulator Engine
 * Performs MNL share calculation, RFC simulation, sensitivity sweeps
 */

var SimEngine = (function() {
  "use strict";

  var data = null;

  function init(simData) {
    data = simData;
  }

  function getData() { return data; }

  // Calculate total utility for a product configuration
  function productUtility(product) {
    var total = 0;
    data.attributes.forEach(function(attr) {
      var selectedLevel = product[attr.name];
      if (selectedLevel) {
        attr.levels.forEach(function(lev) {
          if (lev.name === selectedLevel) {
            total += lev.utility;
          }
        });
      }
    });
    return total;
  }

  // MNL share prediction
  function predictSharesLogit(products) {
    var utilities = products.map(productUtility);
    var maxU = Math.max.apply(null, utilities);
    var expU = utilities.map(function(u) { return Math.exp(u - maxU); });
    var sumExp = expU.reduce(function(a, b) { return a + b; }, 0);
    return expU.map(function(e) { return (e / sumExp) * 100; });
  }

  // First choice prediction
  function predictSharesFirstChoice(products) {
    var utilities = products.map(productUtility);
    var maxU = Math.max.apply(null, utilities);
    return utilities.map(function(u) { return u === maxU ? 100 : 0; });
  }

  // General predict function
  function predictShares(products, method) {
    method = method || "logit";
    if (method === "first_choice") return predictSharesFirstChoice(products);
    return predictSharesLogit(products);
  }

  // Sensitivity sweep: vary one attribute across all levels
  function sensitivitySweep(baseProduct, attribute, otherProducts, method) {
    var attr = null;
    data.attributes.forEach(function(a) { if (a.name === attribute) attr = a; });
    if (!attr) return [];

    return attr.levels.map(function(lev) {
      var testProduct = {};
      for (var k in baseProduct) testProduct[k] = baseProduct[k];
      testProduct[attribute] = lev.name;
      var allProducts = [testProduct].concat(otherProducts || []);
      var shares = predictShares(allProducts, method);
      return { level: lev.name, share: shares[0] };
    });
  }

  // Source of volume: compare baseline vs test (with new product)
  function sourceOfVolume(baselineProducts, newProduct, method) {
    var baseShares = predictShares(baselineProducts, method);
    var allProducts = baselineProducts.concat([newProduct]);
    var testShares = predictShares(allProducts, method);

    var result = [];
    for (var i = 0; i < baselineProducts.length; i++) {
      result.push({
        product: "Product " + (i + 1),
        baseline: baseShares[i],
        test: testShares[i],
        change: testShares[i] - baseShares[i]
      });
    }
    result.push({
      product: "New Product",
      baseline: 0,
      test: testShares[testShares.length - 1],
      change: testShares[testShares.length - 1]
    });
    return result;
  }

  return {
    init: init,
    getData: getData,
    productUtility: productUtility,
    predictShares: predictShares,
    sensitivitySweep: sensitivitySweep,
    sourceOfVolume: sourceOfVolume
  };
})();
