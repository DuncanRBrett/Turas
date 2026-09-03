/**
 * MaxDiff view. Item scores with preference shares and best/worst bars, the
 * estimator named in words, then TURF, must-haves and discrimination classes
 * when the study produced them.
 *
 * FROZEN, NOT LIVE. Every other analysis tab recomputes from microdata when
 * the audience filter changes. MaxDiff cannot: the utilities were estimated
 * once, on the whole sample. So this tab shows what was estimated and the
 * filter bar is hidden while it is open, the same contract as Conjoint and
 * Tracking. The note at the top of the tab says so.
 *
 * The data comes from TR.MD, the maxdiff module's contribution island
 * (modules/maxdiff/R/13_v2_island.R). There are no new row kinds: a MaxDiff
 * utility has no banner and no base, so it does not belong in the crosstab
 * data layer.
 *
 * Honesty about the estimator is the point of the provenance panel. Without
 * cmdstanr the module's "HB" is an empirical-Bayes fallback on count scores;
 * the island says which ran and this view repeats it where the reader looks.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var md = TR.maxdiff = {};

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // A missing value shows as an en dash, never as "NaN" or an empty cell.
  function num(v, dp) {
    if (v === null || v === undefined || isNaN(v)) return "–";
    return Number(v).toFixed(dp === undefined ? 1 : dp);
  }

  function arr(v) { return Array.isArray(v) ? v : null; }

  /** Is there a MaxDiff contribution with anything in it? */
  md.available = function () {
    var d = TR.MD;
    return !!(d && d.meta && d.scores && Array.isArray(d.scores.itemId) &&
      d.scores.itemId.length);
  };

  md.data = function () { return TR.MD; };

  // -------------------------------------------------------------------------
  // Panels
  // -------------------------------------------------------------------------

  function provenanceHtml(meta) {
    var bits = [];
    bits.push("Scored with <strong>" + esc(meta.methodLabel || meta.method) + "</strong>");
    if (meta.nRespondents) bits.push(esc(num(meta.nRespondents, 0)) + " respondents");
    if (meta.nTasks) bits.push(esc(num(meta.nTasks, 0)) + " tasks each");
    if (meta.itemsPerTask) bits.push(esc(num(meta.itemsPerTask, 0)) + " items per task");
    if (meta.nItems) bits.push(esc(num(meta.nItems, 0)) + " items");

    var notes = [];
    if (meta.filterNote) notes.push(esc(meta.filterNote));
    if (meta.weightingNote) notes.push(esc(meta.weightingNote));

    // The estimator's own description travels in the island so the view
    // cannot forget to say it. The fallback gets a visible stamp.
    var stamp = "";
    if (meta.estimationNote) {
      var cls = meta.method === "empirical_bayes" ? "md-stamp" : "md-note";
      stamp = '<p class="' + cls + '">' + esc(meta.estimationNote) + "</p>";
    }

    var sim = "";
    if (meta.simulatorFile) {
      sim = '<p class="md-note">Simulator: <a href="' + esc(meta.simulatorFile) + '">' +
        esc(meta.simulatorFile) +
        "</a>. Open it beside this report to test head-to-head choices and portfolios.</p>";
    }

    return '<div class="md-provenance">' +
      "<p>" + bits.join(" · ") + "</p>" +
      stamp +
      (notes.length ? '<p class="md-note">' + notes.join(" ") + "</p>" : "") +
      sim +
      "</div>";
  }

  /**
   * The column that carries the headline utility, its spread, and where there
   * is a posterior to take one from, the precision of the population mean.
   * The spread is the spread across respondents on BOTH hierarchical paths,
   * so it carries one label; only the mean's standard error tells the paths
   * apart, and under the empirical-Bayes fallback there is not one.
   */
  function utilityColumns(meta, sc) {
    if (arr(sc.hbUtility)) {
      return {
        value: sc.hbUtility,
        spread: arr(sc.hbSpread),
        se: arr(sc.hbMeanSe),
        label: "Utility",
        spreadLabel: "Spread (SD)",
        seLabel: "Mean SE"
      };
    }
    if (arr(sc.logitUtility)) {
      return { value: sc.logitUtility, spread: arr(sc.logitSe),
               label: "Logit utility", spreadLabel: "Std. error" };
    }
    return null;
  }

  function scoresHtml(sc, meta) {
    var n = sc.itemId.length;
    var share = arr(sc.share);
    var best = arr(sc.bestPct), worst = arr(sc.worstPct), net = arr(sc.netScore);
    var rescaled = arr(sc.rescaled);
    var util = utilityColumns(meta, sc);

    // Order: by preference share when there is one, else by rescaled score,
    // else by net score, else as configured. The best-liked item reads first.
    var key = share || rescaled || net || null;
    var order = [];
    for (var i = 0; i < n; i++) order.push(i);
    if (key) {
      order.sort(function (a, b) {
        var ka = key[a] == null ? -Infinity : key[a];
        var kb = key[b] == null ? -Infinity : key[b];
        return kb - ka;
      });
    }

    var maxShare = 0, maxBW = 0;
    if (share) share.forEach(function (v) { if (v > maxShare) maxShare = v; });
    if (best) best.forEach(function (v) { if (v > maxBW) maxBW = v; });
    if (worst) worst.forEach(function (v) { if (v > maxBW) maxBW = v; });

    var head = "<tr><th>Item</th>";
    if (share) head += "<th></th>" + '<th class="md-num">Share</th>';
    if (best && worst) head += '<th class="md-bwcell">Worst ← → Best</th>' +
      '<th class="md-num">Best</th><th class="md-num">Worst</th>';
    if (net) head += '<th class="md-num">Net</th>';
    if (util) head += '<th class="md-num">' + esc(util.label) + "</th>" +
      (util.spread ? '<th class="md-num">' + esc(util.spreadLabel) + "</th>" : "") +
      (util.se ? '<th class="md-num">' + esc(util.seLabel) + "</th>" : "");
    if (rescaled) head += '<th class="md-num">Score</th>';
    head += "</tr>";

    var rows = order.map(function (i) {
      var r = "<tr><td>" + esc(sc.label[i]) +
        (arr(sc.group) && sc.group[i] ? ' <span class="md-tag">' + esc(sc.group[i]) + "</span>" : "") +
        "</td>";
      if (share) {
        var w = maxShare > 0 && share[i] != null ? (share[i] / maxShare * 100) : 0;
        r += '<td class="md-barcell"><span class="md-bar" style="width:' + w.toFixed(1) + '%"></span></td>' +
          '<td class="md-num">' + num(share[i]) + "%</td>";
      }
      if (best && worst) {
        var wb = maxBW > 0 && best[i] != null ? (best[i] / maxBW * 50) : 0;
        var ww = maxBW > 0 && worst[i] != null ? (worst[i] / maxBW * 50) : 0;
        r += '<td class="md-bwcell"><div class="md-bw">' +
          '<span class="md-bw-worst" style="width:' + ww.toFixed(1) + '%"></span>' +
          '<span class="md-bw-best" style="width:' + wb.toFixed(1) + '%"></span>' +
          "</div></td>" +
          '<td class="md-num">' + num(best[i]) + "%</td>" +
          '<td class="md-num">' + num(worst[i]) + "%</td>";
      }
      if (net) r += '<td class="md-num">' + num(net[i]) + "</td>";
      if (util) {
        r += '<td class="md-num">' + num(util.value[i], 2) + "</td>";
        if (util.spread) r += '<td class="md-num">' + num(util.spread[i], 2) + "</td>";
        if (util.se) r += '<td class="md-num">' + num(util.se[i], 3) + "</td>";
      }
      if (rescaled) r += '<td class="md-num">' + num(rescaled[i], 0) + "</td>";
      return r + "</tr>";
    }).join("");

    var notes = [];
    if (share) {
      notes.push("Share is the average probability, across respondents, of each item being chosen from the full set: shares sum to 100.");
    }
    if (best && worst) {
      notes.push("Best and Worst are the share of the times an item was shown that it was picked as best or worst.");
    }
    if (util && util.spread && util.label === "Utility") {
      notes.push(util.se
        ? "Spread (SD) is how much the item's utility varies across respondents, not the precision of the average. Mean SE is that precision: the posterior standard deviation of the population mean."
        : "Spread (SD) is how much the item's utility varies across respondents, not the precision of the average. This run has no posterior, so there is no standard error for the mean.");
    }
    if (rescaled) {
      var rm = sc.rescaleMethod;
      notes.push(rm === "0_100" ? "Score rescales the headline utility so the least-preferred item is 0 and the most-preferred is 100."
        : rm === "PROBABILITY" ? "Score is the share-of-preference scaling of the headline utility."
        : "Score is the headline utility on its raw scale.");
    }

    return '<section class="md-panel"><h3>Item scores</h3>' +
      (notes.length ? '<p class="md-note">' + esc(notes.join(" ")) + "</p>" : "") +
      '<table class="md-table"><thead>' + head + "</thead><tbody>" + rows +
      "</tbody></table></section>";
  }

  function turfHtml(t) {
    if (!t || !arr(t.step) || !t.step.length) return "";
    var maxReach = 0;
    t.reachPct.forEach(function (v) { if (v > maxReach) maxReach = v; });
    var rows = t.step.map(function (s, i) {
      var w = maxReach > 0 ? (t.reachPct[i] / maxReach * 100) : 0;
      return "<tr><td class=\"md-num\">" + esc(num(s, 0)) + "</td><td>" + esc(t.label[i]) + "</td>" +
        '<td class="md-barcell"><span class="md-bar" style="width:' + w.toFixed(1) + '%"></span></td>' +
        '<td class="md-num">' + num(t.reachPct[i]) + "%</td>" +
        '<td class="md-num">+' + num(t.incrementalPct[i]) + "</td></tr>";
    }).join("");
    var how = t.thresholdMethod ? " Appeal threshold: " + esc(String(t.thresholdMethod)).replace(/_/g, " ").toLowerCase() + "." : "";
    return '<section class="md-panel"><h3>Portfolio reach (TURF)</h3>' +
      '<p class="md-note">' + esc(t.note || "") + how + "</p>" +
      '<table class="md-table"><thead><tr><th class="md-num">Step</th><th>Add</th><th></th>' +
      '<th class="md-num">Reach</th><th class="md-num">Gain</th></tr></thead><tbody>' +
      rows + "</tbody></table></section>";
  }

  function anchorHtml(a) {
    if (!a || !arr(a.itemId) || !a.itemId.length) return "";
    var order = a.itemId.map(function (_, i) { return i; });
    order.sort(function (x, y) { return (a.rate[y] || 0) - (a.rate[x] || 0); });
    var rows = order.map(function (i) {
      var must = a.isMustHave && a.isMustHave[i];
      return "<tr><td>" + esc(a.label[i]) + "</td>" +
        '<td class="md-num">' + num(a.rate[i] * 100) + "%</td>" +
        "<td>" + (must ? '<span class="md-tag md-tag-must">Must-have</span>' : "") + "</td></tr>";
    }).join("");
    var thr = a.threshold != null ? " Items chosen by at least " + num(a.threshold * 100, 0) + "% of respondents are marked must-have." : "";
    return '<section class="md-panel"><h3>Must-haves (anchor question)</h3>' +
      '<p class="md-note">' + esc("The share of respondents who said each item is essential, from the anchor question." + thr) + "</p>" +
      '<table class="md-table"><thead><tr><th>Item</th><th class="md-num">Essential</th><th></th></tr></thead><tbody>' +
      rows + "</tbody></table></section>";
  }

  function discriminationHtml(d) {
    if (!d || !arr(d.itemId) || !d.itemId.length) return "";
    var labels = TR.MD.scores.label;
    var ids = TR.MD.scores.itemId;
    var rows = d.itemId.map(function (id, i) {
      var k = ids.indexOf(id);
      var lab = k >= 0 ? labels[k] : id;
      return "<tr><td>" + esc(lab) + "</td><td>" +
        (d.label && d.label[i] ? '<span class="md-tag">' + esc(d.label[i]) + "</span>" : "") + "</td>" +
        '<td class="md-num">' + num(d.meanUtility ? d.meanUtility[i] : null, 2) + "</td>" +
        '<td class="md-num">' + num(d.sdUtility ? d.sdUtility[i] : null, 2) + "</td></tr>";
    }).join("");
    return '<section class="md-panel"><h3>Where respondents agree and disagree</h3>' +
      '<p class="md-note">' + esc(d.note || "") + "</p>" +
      '<table class="md-table"><thead><tr><th>Item</th><th>Class</th>' +
      '<th class="md-num">Mean utility</th><th class="md-num">Spread (SD)</th></tr></thead><tbody>' +
      rows + "</tbody></table></section>";
  }

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  md.render = function (host) {
    var d = TR.MD;

    if (!md.available()) {
      host.innerHTML = '<div class="md-panel"><p>This report carries no MaxDiff results.</p></div>';
      return;
    }

    host.innerHTML =
      '<div class="md-view">' +
      "<h2>MaxDiff</h2>" +
      provenanceHtml(d.meta) +
      scoresHtml(d.scores, d.meta) +
      turfHtml(d.turf) +
      anchorHtml(d.anchor) +
      discriminationHtml(d.discrimination) +
      "</div>";
  };

}(typeof window !== "undefined" ? window : this));
