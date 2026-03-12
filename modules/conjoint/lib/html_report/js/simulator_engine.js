/**
 * Conjoint Market Simulator Engine
 * Performs MNL share calculation, first choice, sensitivity sweeps,
 * source of volume analysis, and demand curve generation.
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
    if (!data || !data.attributes) return 0;
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

  // MNL logit share prediction
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
    var count = utilities.filter(function(u) { return u === maxU; }).length;
    return utilities.map(function(u) { return u === maxU ? 100 / count : 0; });
  }

  // General predict function
  function predictShares(products, method) {
    method = method || "logit";
    if (method === "first_choice") return predictSharesFirstChoice(products);
    return predictSharesLogit(products);
  }

  // Sensitivity sweep: vary one attribute across all levels for product 1
  function sensitivitySweep(baseProduct, attribute, otherProducts, method) {
    var attr = null;
    if (!data) return [];
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

  // Source of volume: compare baseline market vs market with new product
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

  // Demand curve: sweep a numeric attribute (e.g., Price) and track share
  function demandCurve(baseProduct, priceAttribute, otherProducts, method) {
    return sensitivitySweep(baseProduct, priceAttribute, otherProducts, method);
  }

  return {
    init: init,
    getData: getData,
    productUtility: productUtility,
    predictShares: predictShares,
    predictSharesLogit: predictSharesLogit,
    predictSharesFirstChoice: predictSharesFirstChoice,
    sensitivitySweep: sensitivitySweep,
    sourceOfVolume: sourceOfVolume,
    demandCurve: demandCurve
  };
})();
