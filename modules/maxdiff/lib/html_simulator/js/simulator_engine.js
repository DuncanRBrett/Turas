/**
 * TURAS MaxDiff Simulator Engine v2.0
 * Core computation: MNL shares, head-to-head, TURF reach, segment matrix, overview
 */

var SimEngine = (function() {

  var data = null;

  function init(simData) {
    data = simData;
  }

  /**
   * Compute preference shares across all items (MNL softmax)
   * Uses individual-level utilities if available, else aggregate
   * @param {string} segmentFilter - optional segment filter key "Variable:Value"
   * @returns {Object[]} Array of {itemId, label, share}
   */
  function computeShares(segmentFilter) {
    if (!data || !data.items) return [];

    var items = data.items;
    var n = items.length;

    if (data.individual_utils && data.individual_utils.length > 0) {
      var respUtils = data.individual_utils;
      var respondents = segmentFilter ? filterRespondents(respUtils, segmentFilter) : respUtils;
      var nResp = respondents.length;
      if (nResp === 0) return items.map(function(it) { return {itemId: it.id, label: it.label, share: 0}; });

      var sumShares = new Array(n).fill(0);

      for (var r = 0; r < nResp; r++) {
        var utils = respondents[r].utilities;
        var maxU = Math.max.apply(null, utils);
        var expSum = 0;
        var expU = [];
        for (var i = 0; i < n; i++) {
          var e = Math.exp(utils[i] - maxU);
          expU.push(e);
          expSum += e;
        }
        for (var i = 0; i < n; i++) {
          sumShares[i] += expU[i] / expSum;
        }
      }

      return items.map(function(it, idx) {
        return {itemId: it.id, label: it.label, share: (sumShares[idx] / nResp) * 100};
      });
    }

    // Aggregate fallback
    var utils = items.map(function(it) { return it.utility; });
    var maxU = Math.max.apply(null, utils);
    var expSum = 0;
    var expU = utils.map(function(u) { var e = Math.exp(u - maxU); expSum += e; return e; });

    return items.map(function(it, idx) {
      return {itemId: it.id, label: it.label, share: (expU[idx] / expSum) * 100};
    });
  }

  /**
   * Head-to-head comparison between two items
   * @param {string} idA - Item ID A
   * @param {string} idB - Item ID B
   * @param {string} segmentFilter - optional segment filter key
   * @returns {Object} {probA, probB, itemA, itemB}
   */
  function headToHead(idA, idB, segmentFilter) {
    if (!data || !data.items) return {probA: 50, probB: 50};

    var items = data.items;
    var idxA = items.findIndex(function(it) { return it.id === idA; });
    var idxB = items.findIndex(function(it) { return it.id === idB; });

    if (idxA < 0 || idxB < 0) return {probA: 50, probB: 50};

    if (data.individual_utils && data.individual_utils.length > 0) {
      var respUtils = data.individual_utils;
      var respondents = segmentFilter ? filterRespondents(respUtils, segmentFilter) : respUtils;
      var nResp = respondents.length;
      if (nResp === 0) return {probA: 50, probB: 50, itemA: items[idxA].label, itemB: items[idxB].label};

      var sumProbA = 0;
      for (var r = 0; r < nResp; r++) {
        var uA = respondents[r].utilities[idxA];
        var uB = respondents[r].utilities[idxB];
        sumProbA += 1 / (1 + Math.exp(-(uA - uB)));
      }
      var avgA = (sumProbA / nResp) * 100;
      return {
        probA: Math.round(avgA * 10) / 10,
        probB: Math.round((100 - avgA) * 10) / 10,
        itemA: items[idxA].label,
        itemB: items[idxB].label
      };
    }

    // Aggregate fallback
    var uA = items[idxA].utility;
    var uB = items[idxB].utility;
    var pA = 1 / (1 + Math.exp(-(uA - uB)));
    return {
      probA: Math.round(pA * 1000) / 10,
      probB: Math.round((1 - pA) * 1000) / 10,
      itemA: items[idxA].label,
      itemB: items[idxB].label
    };
  }

  /**
   * Batch head-to-head for multiple pairs
   * @param {Array} pairs - Array of {idA, idB}
   * @param {string} segmentFilter - optional segment filter key
   * @returns {Object[]} Array of {probA, probB, itemA, itemB, idA, idB}
   */
  function headToHeadMulti(pairs, segmentFilter) {
    if (!pairs || pairs.length === 0) return [];
    return pairs.map(function(pair) {
      var result = headToHead(pair.idA, pair.idB, segmentFilter);
      result.idA = pair.idA;
      result.idB = pair.idB;
      return result;
    });
  }

  /**
   * TURF reach calculation for a selected portfolio
   * @param {string[]} selectedIds - Array of selected Item IDs
   * @param {number} topK - Number of top items per respondent to consider "appealing"
   * @param {string} segmentFilter - optional segment filter key
   * @returns {Object} {reach, frequency, nReached, nTotal}
   */
  function turfReach(selectedIds, topK, segmentFilter) {
    if (!data || !data.individual_utils || data.individual_utils.length === 0) {
      return {reach: 0, frequency: 0, nReached: 0, nTotal: 0};
    }

    topK = topK || 3;
    var items = data.items;
    var n = items.length;
    var selectedIndices = selectedIds.map(function(id) {
      return items.findIndex(function(it) { return it.id === id; });
    }).filter(function(idx) { return idx >= 0; });

    if (selectedIndices.length === 0) return {reach: 0, frequency: 0, nReached: 0, nTotal: 0};

    var respUtils = data.individual_utils;
    var respondents = segmentFilter ? filterRespondents(respUtils, segmentFilter) : respUtils;
    var nResp = respondents.length;
    if (nResp === 0) return {reach: 0, frequency: 0, nReached: 0, nTotal: 0};

    var nReached = 0;
    var totalFreq = 0;

    for (var r = 0; r < nResp; r++) {
      var utils = respondents[r].utilities;

      // Determine top-K items for this respondent
      var indexed = utils.map(function(u, i) { return {u: u, i: i}; });
      indexed.sort(function(a, b) { return b.u - a.u; });
      var topSet = {};
      for (var k = 0; k < Math.min(topK, n); k++) {
        topSet[indexed[k].i] = true;
      }

      // Count how many selected items are in top-K
      var count = 0;
      for (var s = 0; s < selectedIndices.length; s++) {
        if (topSet[selectedIndices[s]]) count++;
      }

      if (count > 0) nReached++;
      totalFreq += count;
    }

    return {
      reach: Math.round((nReached / nResp) * 1000) / 10,
      frequency: Math.round((totalFreq / nResp) * 100) / 100,
      nReached: nReached,
      nTotal: nResp
    };
  }

  /**
   * Greedy TURF optimization: find best N items
   * @param {number} maxItems - Maximum portfolio size
   * @param {number} topK - Top-K threshold
   * @param {string} segmentFilter - optional segment filter key
   * @returns {Object[]} Array of {itemId, label, reach, incremental}
   */
  function turfOptimize(maxItems, topK, segmentFilter) {
    if (!data || !data.individual_utils || data.individual_utils.length === 0) return [];

    topK = topK || 3;
    maxItems = Math.min(maxItems || 10, data.items.length);

    var selected = [];
    var available = data.items.map(function(it) { return it.id; });
    var results = [];
    var prevReach = 0;

    for (var step = 0; step < maxItems; step++) {
      var bestId = null;
      var bestReach = -1;

      for (var a = 0; a < available.length; a++) {
        var trial = selected.concat([available[a]]);
        var r = turfReach(trial, topK, segmentFilter);
        if (r.reach > bestReach) {
          bestReach = r.reach;
          bestId = available[a];
        }
      }

      if (!bestId) break;

      selected.push(bestId);
      available = available.filter(function(id) { return id !== bestId; });

      var item = data.items.find(function(it) { return it.id === bestId; });
      results.push({
        itemId: bestId,
        label: item ? item.label : bestId,
        reach: bestReach,
        incremental: Math.round((bestReach - prevReach) * 10) / 10
      });

      prevReach = bestReach;
      if (bestReach >= 99.9) break;
    }

    return results;
  }

  /**
   * Compute segment comparison matrix: shares for each item across all segments
   * @returns {Object} {segments: [{key, label}], items: [{id, label, shares: {segKey: share}}]}
   */
  function segmentComparisonMatrix() {
    if (!data || !data.items || !data.segments || data.segments.length === 0) return null;

    var segments = data.segments.map(function(s) {
      return {key: s.variable + ":" + s.value, label: s.label};
    });

    // Add "All" as first column
    segments.unshift({key: null, label: "All"});

    var itemRows = data.items.map(function(it) {
      var row = {id: it.id, label: it.label, shares: {}};

      for (var si = 0; si < segments.length; si++) {
        var segShares = computeShares(segments[si].key);
        var match = segShares.find(function(s) { return s.itemId === it.id; });
        row.shares[segments[si].key || "all"] = match ? Math.round(match.share * 10) / 10 : 0;
      }

      return row;
    });

    return {segments: segments, items: itemRows};
  }

  /**
   * Get overview statistics
   * @returns {Object} {nItems, nRespondents, nSegments, topItem, bottomItem, topShare, bottomShare, shareRange, method}
   */
  function getOverviewStats() {
    if (!data || !data.items) return null;

    var shares = computeShares(null);
    shares.sort(function(a, b) { return b.share - a.share; });

    var topItem = shares[0] || {label: "-", share: 0};
    var bottomItem = shares[shares.length - 1] || {label: "-", share: 0};

    return {
      nItems: data.items.length,
      nRespondents: data.n_respondents || (data.individual_utils ? data.individual_utils.length : 0),
      nSegments: data.segments ? data.segments.length : 0,
      topItem: topItem.label,
      topShare: Math.round(topItem.share * 10) / 10,
      bottomItem: bottomItem.label,
      bottomShare: Math.round(bottomItem.share * 10) / 10,
      shareRange: Math.round((topItem.share - bottomItem.share) * 10) / 10,
      method: (data.individual_utils && data.individual_utils.length > 0) ? "Hierarchical Bayes" : "Aggregate Logit",
      hasIndividual: !!(data.individual_utils && data.individual_utils.length > 0)
    };
  }

  /**
   * Get data reference (for pins to access metadata)
   */
  function getData() {
    return data;
  }

  /**
   * Compute diagnostic statistics for model quality assessment
   * @returns {Object} Diagnostics object with model fit and item-level stats
   */
  function getDiagnostics() {
    if (!data || !data.items) return null;

    var items = data.items;
    var n = items.length;
    var hasIndividual = !!(data.individual_utils && data.individual_utils.length > 0);

    var result = {
      method: hasIndividual ? "Hierarchical Bayes" : "Aggregate Logit",
      nItems: n,
      nRespondents: hasIndividual ? data.individual_utils.length : 0,
      nSegments: data.segments ? data.segments.length : 0,
      hasIndividual: hasIndividual
    };

    // Population utility stats
    var utils = items.map(function(it) { return it.utility; });
    var utilSum = utils.reduce(function(s, u) { return s + u; }, 0);
    var utilMean = utilSum / n;
    var utilVariance = utils.reduce(function(s, u) { return s + (u - utilMean) * (u - utilMean); }, 0) / n;
    result.utilityRange = Math.round((Math.max.apply(null, utils) - Math.min.apply(null, utils)) * 1000) / 1000;
    result.utilityMean = Math.round(utilMean * 1000) / 1000;
    result.utilitySD = Math.round(Math.sqrt(utilVariance) * 1000) / 1000;

    // Discrimination index: utility range per item
    result.discriminationIndex = Math.round((result.utilityRange / n) * 1000) / 1000;

    // Per-item statistics
    result.itemStats = items.map(function(it, idx) {
      var stat = { id: it.id, label: it.label, popUtility: Math.round(it.utility * 1000) / 1000 };

      if (hasIndividual) {
        var vals = data.individual_utils.map(function(r) { return r.utilities[idx]; });
        var nR = vals.length;
        var iMean = vals.reduce(function(s, v) { return s + v; }, 0) / nR;
        var iVar = vals.reduce(function(s, v) { return s + (v - iMean) * (v - iMean); }, 0) / nR;
        stat.indivMean = Math.round(iMean * 1000) / 1000;
        stat.indivSD = Math.round(Math.sqrt(iVar) * 1000) / 1000;
        stat.indivMin = Math.round(Math.min.apply(null, vals) * 1000) / 1000;
        stat.indivMax = Math.round(Math.max.apply(null, vals) * 1000) / 1000;
      }
      return stat;
    });

    // Individual-level diagnostics
    if (hasIndividual) {
      var nResp = data.individual_utils.length;
      var maxShareSum = 0;
      var utilRanges = [];
      var entropySum = 0;

      for (var r = 0; r < nResp; r++) {
        var ru = data.individual_utils[r].utilities;
        var maxU = Math.max.apply(null, ru);
        var minU = Math.min.apply(null, ru);
        utilRanges.push(maxU - minU);

        // Compute MNL shares for this respondent
        var expSum = 0;
        var exps = [];
        for (var i = 0; i < n; i++) {
          var e = Math.exp(ru[i] - maxU);
          exps.push(e);
          expSum += e;
        }
        var maxShare = 0;
        var entropy = 0;
        for (var i = 0; i < n; i++) {
          var p = exps[i] / expSum;
          if (p > maxShare) maxShare = p;
          if (p > 0) entropy -= p * Math.log(p);
        }
        maxShareSum += maxShare;
        entropySum += entropy;
      }

      // Mean max-share: avg probability of top item per respondent
      result.meanMaxShare = Math.round((maxShareSum / nResp) * 1000) / 10;
      result.chanceLevel = Math.round((1 / n) * 1000) / 10;

      // Preference sharpness: ratio of mean max-share to chance
      result.sharpnessRatio = Math.round((result.meanMaxShare / result.chanceLevel) * 10) / 10;

      // Mean entropy (lower = sharper preferences)
      var maxEntropy = Math.log(n);
      result.meanEntropy = Math.round((entropySum / nResp) * 1000) / 1000;
      result.maxEntropy = Math.round(maxEntropy * 1000) / 1000;
      result.entropyRatio = Math.round((result.meanEntropy / maxEntropy) * 1000) / 1000;

      // Utility range distribution across respondents
      var rangeSum = utilRanges.reduce(function(s, v) { return s + v; }, 0);
      result.meanUtilRange = Math.round((rangeSum / nResp) * 100) / 100;
      result.minUtilRange = Math.round(Math.min.apply(null, utilRanges) * 100) / 100;
      result.maxUtilRange = Math.round(Math.max.apply(null, utilRanges) * 100) / 100;

      // Heterogeneity: avg SD of individual utilities from population mean
      var hetSum = 0;
      for (var i = 0; i < n; i++) {
        var popU = items[i].utility;
        var diffs = 0;
        for (var r = 0; r < nResp; r++) {
          var diff = data.individual_utils[r].utilities[i] - popU;
          diffs += diff * diff;
        }
        hetSum += Math.sqrt(diffs / nResp);
      }
      result.heterogeneity = Math.round((hetSum / n) * 1000) / 1000;
    }

    // Pass through any server-side diagnostics
    if (data.diagnostics) {
      result.serverDiagnostics = data.diagnostics;
    }

    return result;
  }

  function filterRespondents(respUtils, segmentKey) {
    if (!segmentKey || !data.segments) return respUtils;
    var parts = segmentKey.split(":");
    if (parts.length !== 2) return respUtils;
    var segVar = parts[0];
    var segVal = parts[1];
    return respUtils.filter(function(r) {
      return r.segments && r.segments[segVar] === segVal;
    });
  }

  return {
    init: init,
    computeShares: computeShares,
    headToHead: headToHead,
    headToHeadMulti: headToHeadMulti,
    turfReach: turfReach,
    turfOptimize: turfOptimize,
    segmentComparisonMatrix: segmentComparisonMatrix,
    getOverviewStats: getOverviewStats,
    getData: getData,
    getDiagnostics: getDiagnostics
  };
})();
