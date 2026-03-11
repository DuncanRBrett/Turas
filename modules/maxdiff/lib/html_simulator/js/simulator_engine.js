/**
 * TURAS MaxDiff Simulator Engine v11.0
 * Core computation: MNL shares, head-to-head, TURF reach
 */

var SimEngine = (function() {

  var data = null;

  function init(simData) {
    data = simData;
  }

  /**
   * Compute preference shares across all items (MNL softmax)
   * Uses individual-level utilities if available, else aggregate
   * @param {string} segmentFilter - optional segment filter key
   * @returns {Object[]} Array of {itemId, label, share}
   */
  function computeShares(segmentFilter) {
    if (!data || !data.items) return [];

    var items = data.items;
    var n = items.length;

    if (data.individual_utils && data.individual_utils.length > 0) {
      // Individual-level: compute per-respondent shares, then average
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
   * @returns {Object} {probA, probB, itemA, itemB}
   */
  function headToHead(idA, idB) {
    if (!data || !data.items) return {probA: 50, probB: 50};

    var items = data.items;
    var idxA = items.findIndex(function(it) { return it.id === idA; });
    var idxB = items.findIndex(function(it) { return it.id === idB; });

    if (idxA < 0 || idxB < 0) return {probA: 50, probB: 50};

    if (data.individual_utils && data.individual_utils.length > 0) {
      var sumProbA = 0;
      var nResp = data.individual_utils.length;
      for (var r = 0; r < nResp; r++) {
        var uA = data.individual_utils[r].utilities[idxA];
        var uB = data.individual_utils[r].utilities[idxB];
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
   * TURF reach calculation for a selected portfolio
   * @param {string[]} selectedIds - Array of selected Item IDs
   * @param {number} topK - Number of top items per respondent to consider "appealing"
   * @returns {Object} {reach, frequency, nReached, nTotal}
   */
  function turfReach(selectedIds, topK) {
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

    var nResp = data.individual_utils.length;
    var nReached = 0;
    var totalFreq = 0;

    for (var r = 0; r < nResp; r++) {
      var utils = data.individual_utils[r].utilities;

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
   * @returns {Object[]} Array of {itemId, label, reach, incremental}
   */
  function turfOptimize(maxItems, topK) {
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
        var r = turfReach(trial, topK);
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
    turfReach: turfReach,
    turfOptimize: turfOptimize
  };
})();
