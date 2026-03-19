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
    if (!products || products.length === 0) return [];
    var utilities = products.map(productUtility);
    var maxU = Math.max.apply(null, utilities);
    var expU = utilities.map(function(u) { return Math.exp(u - maxU); });
    var sumExp = expU.reduce(function(a, b) { return a + b; }, 0);
    return expU.map(function(e) { return (e / sumExp) * 100; });
  }

  // First choice prediction
  function predictSharesFirstChoice(products) {
    if (!products || products.length === 0) return [];
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
  function sourceOfVolume(baselineProducts, newProduct, method, baselineNames, newProductName) {
    var baseShares = predictShares(baselineProducts, method);
    var allProducts = baselineProducts.concat([newProduct]);
    var testShares = predictShares(allProducts, method);

    var result = [];
    for (var i = 0; i < baselineProducts.length; i++) {
      result.push({
        product: (baselineNames && baselineNames[i]) ? baselineNames[i] : "Product " + (i + 1),
        baseline: baseShares[i],
        test: testShares[i],
        change: testShares[i] - baseShares[i]
      });
    }
    result.push({
      product: newProductName || "New Product",
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

  // Predict shares including a None/no-purchase alternative
  function predictSharesWithNone(products, noneUtility, method) {
    if (!products || products.length === 0) return [];
    var noneU = (noneUtility !== undefined && noneUtility !== null) ? noneUtility : 0;
    if (method === "first_choice") {
      var utilities = products.map(productUtility);
      utilities.push(noneU);
      var maxU = Math.max.apply(null, utilities);
      var count = utilities.filter(function(u) { return u === maxU; }).length;
      return utilities.map(function(u) { return u === maxU ? 100 / count : 0; });
    }
    // Logit (MNL) with none
    var utilities = products.map(productUtility);
    utilities.push(noneU);
    var maxU = Math.max.apply(null, utilities);
    var expU = utilities.map(function(u) { return Math.exp(u - maxU); });
    var sumExp = expU.reduce(function(a, b) { return a + b; }, 0);
    return expU.map(function(e) { return (e / sumExp) * 100; });
  }

  // Get the none utility from the simulator data JSON
  function getNoneUtility() {
    return (data && data.noneUtility !== undefined) ? data.noneUtility : 0;
  }

  // Calculate point price elasticity from demand curve data
  // Uses finite differences: elasticity_i = (dQ/dP) * (P_i / Q_i)
  function calculatePriceElasticity(demandData) {
    if (!demandData || demandData.length < 2) return [];
    var results = [];
    for (var i = 0; i < demandData.length; i++) {
      var price = parseFloat(demandData[i].level);
      var share = demandData[i].share;
      var dQ, dP;
      if (i === 0) {
        // Forward difference
        dQ = demandData[i + 1].share - share;
        dP = parseFloat(demandData[i + 1].level) - price;
      } else if (i === demandData.length - 1) {
        // Backward difference
        dQ = share - demandData[i - 1].share;
        dP = price - parseFloat(demandData[i - 1].level);
      } else {
        // Central difference
        dQ = demandData[i + 1].share - demandData[i - 1].share;
        dP = parseFloat(demandData[i + 1].level) - parseFloat(demandData[i - 1].level);
      }
      var elasticity = (dP !== 0 && share !== 0) ? (dQ / dP) * (price / share) : 0;
      results.push({
        level: demandData[i].level,
        price: price,
        share: share,
        elasticity: elasticity
      });
    }
    return results;
  }

  // Find the price level that maximizes revenue (share * price)
  function findOptimalPrice(demandData, priceValues) {
    if (!demandData || demandData.length === 0) return null;
    var bestRevenue = -Infinity;
    var bestIdx = 0;
    for (var i = 0; i < demandData.length; i++) {
      var price = priceValues ? priceValues[i] : parseFloat(demandData[i].level);
      var revenue = (demandData[i].share / 100) * price;
      if (revenue > bestRevenue) {
        bestRevenue = revenue;
        bestIdx = i;
      }
    }
    return {
      level: demandData[bestIdx].level,
      price: priceValues ? priceValues[bestIdx] : parseFloat(demandData[bestIdx].level),
      share: demandData[bestIdx].share,
      revenue: bestRevenue
    };
  }

  return {
    init: init,
    getData: getData,
    productUtility: productUtility,
    predictShares: predictShares,
    predictSharesLogit: predictSharesLogit,
    predictSharesFirstChoice: predictSharesFirstChoice,
    predictSharesWithNone: predictSharesWithNone,
    getNoneUtility: getNoneUtility,
    calculatePriceElasticity: calculatePriceElasticity,
    findOptimalPrice: findOptimalPrice,
    sensitivitySweep: sensitivitySweep,
    sourceOfVolume: sourceOfVolume,
    demandCurve: demandCurve
  };
})();
