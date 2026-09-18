/**
 * MaxDiff view. Item scores with preference shares and best/worst bars, the
 * estimator named in words, then TURF, must-haves, discrimination classes,
 * head-to-head win rates, per-segment scores, utility distributions and model
 * diagnostics, each when the study produced them.
 *
 * The panel set is deliberate: it matches the classic MaxDiff HTML report so
 * that report can be retired. The content enumeration, including what is
 * carried and what is dropped and why, is
 * docs/v2_lift/MAXDIFF_PARITY_CHECKLIST.md.
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

    // Sampler diagnostics, Stan path only. The panel used to name the
    // estimator and say nothing about whether the fit behaved, so a divergent
    // run read exactly like a clean one (review F6). Max treedepth is only
    // worth a reader's attention when it happened.
    var diag = "";
    if (meta.meanRhat !== null && meta.meanRhat !== undefined) {
      var dparts = [];
      if (meta.nDivergences !== null && meta.nDivergences !== undefined) {
        dparts.push(num(meta.nDivergences, 0) + " divergence" +
          (Number(meta.nDivergences) === 1 ? "" : "s"));
      }
      dparts.push("mean R-hat " + num(meta.meanRhat, 3));
      if (meta.minEss !== null && meta.minEss !== undefined) {
        dparts.push("min ESS " + num(meta.minEss, 0));
      }
      if (meta.maxTreedepthExceeded) {
        dparts.push("max treedepth exceeded " + num(meta.maxTreedepthExceeded, 0) +
          " times");
      }
      diag = '<p class="md-note">Sampler: ' + esc(dparts.join(", ")) + ".</p>";
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
      diag +
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
    // The Stan model fixes one item at zero, so its Spread and Mean SE are
    // structurally 0 rather than measured. The island blanks them; say why,
    // or a dash in two cells reads as missing data (review M3).
    if (meta.referenceItem) {
      // No esc() here: the whole notes list is escaped once where it is joined.
      notes.push((meta.referenceItemLabel || meta.referenceItem) +
        " is the reference item, fixed at zero, so the other utilities are " +
        "relative to it. Its spread and standard error are not measured and " +
        "show as a dash.");
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
      turfCurveSvg(t) +
      '<table class="md-table"><thead><tr><th class="md-num">Step</th><th>Add</th><th></th>' +
      '<th class="md-num">Reach</th><th class="md-num">Gain</th></tr></thead><tbody>' +
      rows + "</tbody></table></section>";
  }

  function anchorHtml(a) {
    if (!a || !arr(a.itemId) || !a.itemId.length) return "";
    var order = a.itemId.map(function (_, i) { return i; });
    order.sort(function (x, y) { return (a.rate[y] || 0) - (a.rate[x] || 0); });
    // The bar runs to 100%, not to the highest item, so the threshold marker
    // sits at the same place in every row and the eye can follow it down.
    var thrPct = a.threshold != null ? a.threshold * 100 : null;
    var rows = order.map(function (i) {
      var must = a.isMustHave && a.isMustHave[i];
      var pct = (a.rate[i] || 0) * 100;
      var mark = thrPct === null ? "" :
        '<span class="md-threshold" style="left:' + thrPct.toFixed(1) + '%"></span>';
      return "<tr><td>" + esc(a.label[i]) + "</td>" +
        '<td class="md-num">' + num(pct) + "%</td>" +
        '<td class="md-barcell"><span class="md-barwrap">' +
        '<span class="md-bar" style="width:' + Math.max(0, Math.min(100, pct)).toFixed(1) +
        '%"></span>' + mark + "</span></td>" +
        "<td>" + (must ? '<span class="md-tag md-tag-must">Must-have</span>' : "") + "</td></tr>";
    }).join("");
    var thr = thrPct != null ? " The line across the bars is the " +
      num(thrPct, 0) + "% threshold; items past it are marked must-have." : "";
    return '<section class="md-panel"><h3>Must-haves (anchor question)</h3>' +
      '<p class="md-note">' + esc("The share of respondents who said each item is essential, from the anchor question." + thr) + "</p>" +
      '<table class="md-table"><thead><tr><th>Item</th><th class="md-num">Essential</th><th></th><th></th></tr></thead><tbody>' +
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
        (d.label && d.label[i] ? '<span class="md-tag">' + esc(d.label[i]) + "</span>" : "\u2013") + "</td>" +
        '<td class="md-num">' + num(d.meanUtility ? d.meanUtility[i] : null, 2) + "</td>" +
        '<td class="md-num">' + num(d.sdUtility ? d.sdUtility[i] : null, 2) + "</td></tr>";
    }).join("");
    return '<section class="md-panel"><h3>Where respondents agree and disagree</h3>' +
      '<p class="md-note">' + esc(d.note || "") + "</p>" +
      '<table class="md-table"><thead><tr><th>Item</th><th>Class</th>' +
      '<th class="md-num">Mean utility</th><th class="md-num">Spread (SD)</th></tr></thead><tbody>' +
      rows + "</tbody></table></section>";
  }

  // A label for an item id, from the scores block. Falls back to the id.
  function labelFor(id) {
    var sc = TR.MD && TR.MD.scores;
    if (!sc || !arr(sc.itemId)) return id;
    var k = sc.itemId.indexOf(id);
    return k >= 0 && sc.label ? sc.label[k] : id;
  }

  // One stat card. Value, then what it is, then the qualifier under it.
  function statCard(value, label, sub) {
    return '<div class="md-stat">' +
      '<div class="md-stat-value">' + value + "</div>" +
      '<div class="md-stat-label">' + esc(label) + "</div>" +
      (sub ? '<div class="md-stat-sub">' + esc(sub) + "</div>" : "") +
      "</div>";
  }

  function statGroup(title, cards) {
    var kept = cards.filter(function (c) { return !!c; });
    if (!kept.length) return "";
    return '<h4 class="md-stat-head">' + esc(title) + "</h4>" +
      '<div class="md-stat-grid">' + kept.join("") + "</div>";
  }

  // Present only when the island carried the number. A dash in a stat card
  // reads as a measurement of nothing, which is worse than no card at all.
  function has(v) { return v !== null && v !== undefined && !isNaN(v); }

  /**
   * Model diagnostics. The classic report's panel showed four groups of stat
   * cards, two of which never rendered: it read the aggregate logit fit from
   * results$logit_results$fit_stats, a key the module does not write, and the
   * only builder that would have drawn the fit was called by no panel. The
   * island reads model_fit, so those numbers appear here for the first time.
   */
  function diagnosticsHtml(d) {
    if (!d) return "";

    var model = statGroup("Model", [
      has(d.nSegments) ? statCard(esc(num(d.nSegments, 0)), "Segments analysed") : "",
      has(d.logLikelihood) ? statCard(esc(num(d.logLikelihood, 1)), "Log-likelihood",
        "Aggregate logit fit") : "",
      has(d.aic) ? statCard(esc(num(d.aic, 1)), "AIC", "Lower is better") : "",
      has(d.bic) ? statCard(esc(num(d.bic, 1)), "BIC", "Lower is better") : "",
      has(d.pseudoR2) ? statCard(esc(num(d.pseudoR2, 3)), "Pseudo R-squared",
        "McFadden") : ""
    ]);

    var pop = statGroup("Population utilities", [
      has(d.utilityRange) ? statCard(esc(num(d.utilityRange, 3)), "Utility range",
        "Highest item minus lowest") : "",
      has(d.meanUtility) ? statCard(esc(num(d.meanUtility, 3)), "Mean utility") : "",
      has(d.utilitySd) ? statCard(esc(num(d.utilitySd, 3)), "Utility spread",
        "Average spread across respondents") : "",
      has(d.discrimination) ? statCard(esc(num(d.discrimination, 3)), "Discrimination",
        "Utility range divided by item count") : ""
    ]);

    var sharp = statGroup("How decisive respondents were", [
      has(d.meanMaxShare) ? statCard(esc(num(d.meanMaxShare, 1)) + "%",
        "Mean top-item share",
        has(d.chanceLevel) ? "Chance is " + num(d.chanceLevel, 1) + "%" : "") : "",
      has(d.sharpnessRatio) ? statCard(esc(num(d.sharpnessRatio, 1)) + "x",
        "Sharpness", "Top-item share against chance") : "",
      has(d.entropyRatio) ? statCard(esc(num(d.entropyRatio, 3)), "Entropy ratio",
        "0 is decisive, 1 is indifferent") : "",
      // Heterogeneity and the utility spread above are the same statistic in
      // the module: the mean of the per-item standard deviations. Showing one
      // number twice under two names reads as a mistake, so this card appears
      // only if the two ever diverge.
      has(d.heterogeneity) && num(d.heterogeneity, 3) !== num(d.utilitySd, 3)
        ? statCard(esc(num(d.heterogeneity, 3)), "Heterogeneity",
          "How much respondents differed") : ""
    ]);

    var resp = statGroup("Spread within a respondent", [
      has(d.meanRespondentRange) ? statCard(esc(num(d.meanRespondentRange, 2)),
        "Mean utility range", "Per respondent") : "",
      has(d.minRespondentRange) ? statCard(esc(num(d.minRespondentRange, 2)),
        "Smallest range", "Least decisive respondent") : "",
      has(d.maxRespondentRange) ? statCard(esc(num(d.maxRespondentRange, 2)),
        "Largest range", "Most decisive respondent") : ""
    ]);

    var body = model + pop + sharp + resp;
    if (!body) return "";

    return '<section class="md-panel"><h3>Model diagnostics</h3>' +
      '<p class="md-note">' + esc("How well the study separated the items, and how " +
        "decisive respondents were. A sharp, high-range study discriminates; a flat " +
        "one means the items were too close together to tell apart.") + "</p>" +
      body + "</section>";
  }

  /**
   * Head-to-head win rates. The island carries the UPPER TRIANGLE only,
   * because P(j beats i) is exactly 100 minus P(i beats j); the mirror is
   * derived here so a pair always sums to 100.
   */
  function headToHeadHtml(h) {
    if (!h || !arr(h.rowItem) || !h.rowItem.length) return "";

    // Item order follows the scores table, so the matrix reads down the same
    // ranking the reader has just looked at.
    var sc = TR.MD.scores;
    var ids = arr(sc && sc.itemId) ? sc.itemId.slice() : [];
    var seen = {};
    h.rowItem.forEach(function (id) { seen[id] = true; });
    h.colItem.forEach(function (id) { seen[id] = true; });
    ids = ids.filter(function (id) { return seen[id]; });
    if (ids.length < 2) return "";

    var SEP = "";
    var byPair = {};
    h.rowItem.forEach(function (r, i) { byPair[r + SEP + h.colItem[i]] = h.prob[i]; });

    var lookup = function (a, b) {
      if (a === b) return null;
      var v = byPair[a + SEP + b];
      if (v !== undefined && v !== null) return v;
      var mirror = byPair[b + SEP + a];
      return mirror === undefined || mirror === null ? null : 100 - mirror;
    };

    // Columns are numbered, not labelled. Ten full item labels as headers make
    // the matrix several screens wide and unreadable; the row labels carry the
    // same numbers, so a column is one glance away from its name.
    var head = '<tr><th>Wins over</th>' + ids.map(function (_, i) {
      return '<th class="md-num md-h2h-col">' + String(i + 1) + "</th>";
    }).join("") + "</tr>";

    var rows = ids.map(function (a, ai) {
      var cells = ids.map(function (b) {
        var v = lookup(a, b);
        if (v === null) return '<td class="md-num md-h2h-self"></td>';
        // Above 50 leans to the row item, below 50 to the column item. The
        // tint is proportional, so a near-even pair looks near-even.
        if (!(TR.svg && TR.svg.shade)) {
          return '<td class="md-num">' + num(v, 1) + "</td>";
        }
        var lean = Math.min(1, Math.abs(v - 50) / 50);
        var bg = v >= 50 ? TR.svg.shade("#2e7d4f", lean * 0.55)
                         : TR.svg.shade("#b3564b", lean * 0.55);
        return '<td class="md-num" style="background:' + bg + '">' +
          num(v, 1) + "</td>";
      }).join("");
      return "<tr><th>" + '<span class="md-h2h-n">' + String(ai + 1) + ".</span> " +
        esc(labelFor(a)) + "</th>" + cells + "</tr>";
    }).join("");

    return '<section class="md-panel"><h3>Head-to-head win rates</h3>' +
      '<p class="md-note">' + esc(h.note || "") + " " +
      esc("Read across a row: each cell is the chance the row item is chosen over " +
          "the column item. Above 50 means the row item wins more often than not. " +
          "Columns are numbered to match the rows.") +
      "</p>" +
      '<div class="md-matrix"><table class="md-table md-h2h"><thead>' + head +
      "</thead><tbody>" + rows + "</tbody></table></div></section>";
  }

  // -------------------------------------------------------------------------
  // Charts
  //
  // Redrawn in the v2 report's own SVG primitives (TR.svg), not ported from
  // the classic report's 767-line chart builder. Duncan ruled on that on
  // 17 Sep 2026: one charting system is worth more than the time a port
  // would have saved. Colours are literal, never CSS variables, so a chart
  // rasterises into a pin looking exactly as it does on the page.
  // -------------------------------------------------------------------------

  var BRAND = "#323367";
  var AXIS = "#8a8f9c";
  var GRID = "#e6e8ee";
  var INK = "#4b5263";

  // 03_svg.js is unconditionally in the shipped bundle, so this is normally
  // true. If it ever is not, the charts drop out and the tables stay; an
  // exception here would leave the whole MaxDiff tab blank instead.
  function canDraw() { return !!(TR.svg && TR.svg.el && TR.svg.root); }

  function chartBox(svgStr) {
    return '<div class="md-chart">' + svgStr + "</div>";
  }

  // Shades for a set of series, far enough apart to tell apart in greyscale.
  function seriesColours(n) {
    var out = [];
    for (var i = 0; i < n; i++) {
      out.push(canDraw() ? TR.svg.shade(BRAND, n === 1 ? 1 : 1 - (i / n) * 0.72)
                         : BRAND);
    }
    return out;
  }

  /** TURF reach curve: how much reach each added item buys. */
  function turfCurveSvg(t) {
    if (!canDraw()) return "";
    var steps = arr(t.step);
    if (!steps || steps.length < 2) return "";
    // The bottom margin holds however many label lines the longest item needs.
    var lines = 1;
    steps.forEach(function (_, i) {
      lines = Math.max(lines, TR.svg.wrapText(String(t.label[i] || ""), 18).length);
    });
    var W = 700, ml = 52, mr = 20, mt = 20, mb = 22 + lines * 11;
    var H = mt + 170 + mb;
    var cw = W - ml - mr, ch = H - mt - mb;
    var top = TR.svg.niceMax(Math.max.apply(null, t.reachPct));
    var y = TR.svg.linear(top, ch);
    var xAt = function (i) {
      return ml + (steps.length === 1 ? cw / 2 : (i / (steps.length - 1)) * cw);
    };
    var yAt = function (v) { return mt + ch - y(v); };

    var parts = [];
    [0, 0.25, 0.5, 0.75, 1].forEach(function (f) {
      var v = top * f, gy = yAt(v);
      parts.push(TR.svg.el("line", { x1: ml, y1: gy, x2: W - mr, y2: gy,
        stroke: GRID, "stroke-width": 1 }));
      parts.push(TR.svg.text(ml - 6, gy + 4, Math.round(v) + "%",
        { "font-size": 10, fill: AXIS, "text-anchor": "end" }));
    });

    // Filled area under the curve, then the curve, then the points.
    var line = steps.map(function (_, i) {
      return (i ? "L" : "M") + xAt(i).toFixed(1) + " " + yAt(t.reachPct[i]).toFixed(1);
    }).join(" ");
    parts.push(TR.svg.el("path", {
      d: line + " L" + xAt(steps.length - 1).toFixed(1) + " " + (mt + ch) +
         " L" + xAt(0).toFixed(1) + " " + (mt + ch) + " Z",
      fill: TR.svg.shade(BRAND, 0.14), stroke: "none" }));
    parts.push(TR.svg.el("path", { d: line, fill: "none", stroke: BRAND,
      "stroke-width": 2, "stroke-linejoin": "round" }));

    steps.forEach(function (_, i) {
      // The end points anchor inward, or their labels run off the viewBox and
      // the browser clips them.
      var anchorAt = i === 0 ? "start" : (i === steps.length - 1 ? "end" : "middle");
      parts.push(TR.svg.el("circle", { cx: xAt(i).toFixed(1), cy: yAt(t.reachPct[i]).toFixed(1),
        r: 3.5, fill: BRAND }));
      parts.push(TR.svg.text(xAt(i), yAt(t.reachPct[i]) - 9,
        num(t.reachPct[i], 1) + "%",
        { "font-size": 10, fill: INK, "text-anchor": anchorAt }));
      // The item each step adds, named in full under its point. Truncating an
      // item label makes it read as a different item, so it wraps instead.
      TR.svg.wrapText(String(t.label[i] || ""), 18).forEach(function (ln, li) {
        parts.push(TR.svg.text(xAt(i), mt + ch + 16 + li * 11, ln,
          { "font-size": 9, fill: AXIS, "text-anchor": anchorAt }));
      });
    });
    parts.push(TR.svg.el("line", { x1: ml, y1: mt + ch, x2: W - mr, y2: mt + ch,
      stroke: AXIS, "stroke-width": 1 }));

    return chartBox(TR.svg.root(W, H,
      "Portfolio reach as each item is added", parts.join("")));
  }

  /**
   * Item strategy quadrant: mean utility across, spread up, split at the
   * medians. Top right is an item that scores well but divides people; bottom
   * right is one everybody wants.
   */
  function quadrantSvg(sc) {
    if (!canDraw()) return "";
    var u = arr(sc.hbUtility), sd = arr(sc.hbSpread), lab = arr(sc.label);
    if (!u || !sd || !lab) return "";
    var pts = [];
    for (var i = 0; i < u.length; i++) {
      if (u[i] === null || sd[i] === null || isNaN(u[i]) || isNaN(sd[i])) continue;
      pts.push({ x: u[i], y: sd[i], label: lab[i] });
    }
    if (pts.length < 2) return "";

    var W = 700, H = 380, ml = 52, mr = 24, mt = 18, mb = 44;
    var cw = W - ml - mr, ch = H - mt - mb;
    var xs = pts.map(function (d) { return d.x; });
    var ys = pts.map(function (d) { return d.y; });
    var pad = function (v) { return (v[1] - v[0]) || 1; };
    var xr = [Math.min.apply(null, xs), Math.max.apply(null, xs)];
    var yr = [Math.min.apply(null, ys), Math.max.apply(null, ys)];
    xr = [xr[0] - pad(xr) * 0.12, xr[1] + pad(xr) * 0.12];
    yr = [yr[0] - pad(yr) * 0.12, yr[1] + pad(yr) * 0.12];
    var xAt = function (v) { return ml + ((v - xr[0]) / (xr[1] - xr[0])) * cw; };
    var yAt = function (v) { return mt + ch - ((v - yr[0]) / (yr[1] - yr[0])) * ch; };

    var median = function (a) {
      var b = a.slice().sort(function (p, q) { return p - q; });
      var m = Math.floor(b.length / 2);
      return b.length % 2 ? b[m] : (b[m - 1] + b[m]) / 2;
    };
    var mx = median(xs), my = median(ys);

    var parts = [];
    parts.push(TR.svg.el("rect", { x: ml, y: mt, width: cw, height: ch,
      fill: "#fbfbfc", stroke: GRID }));
    parts.push(TR.svg.el("line", { x1: xAt(mx), y1: mt, x2: xAt(mx), y2: mt + ch,
      stroke: AXIS, "stroke-dasharray": "4 3", "stroke-width": 1 }));
    parts.push(TR.svg.el("line", { x1: ml, y1: yAt(my), x2: ml + cw, y2: yAt(my),
      stroke: AXIS, "stroke-dasharray": "4 3", "stroke-width": 1 }));

    [["Divisive", ml + cw - 6, mt + 14, "end"],
     ["Niche", ml + 6, mt + 14, "start"],
     ["Agreed favourite", ml + cw - 6, mt + ch - 8, "end"],
     ["Agreed reject", ml + 6, mt + ch - 8, "start"]].forEach(function (q) {
      parts.push(TR.svg.text(q[1], q[2], q[0],
        { "font-size": 10, fill: "#aeb3be", "text-anchor": q[3] }));
    });

    // Numbered points with a key underneath, rather than labels beside them.
    // Ten full item labels on a 700-wide plot either overlap each other or get
    // truncated, and a truncated item label reads as a different item.
    pts.forEach(function (d, i) {
      parts.push(TR.svg.el("circle", { cx: xAt(d.x).toFixed(1), cy: yAt(d.y).toFixed(1),
        r: 9, fill: BRAND, "fill-opacity": 0.85 }));
      parts.push(TR.svg.text(xAt(d.x), yAt(d.y) + 3.5, String(i + 1),
        { "font-size": 10, fill: "#ffffff", "text-anchor": "middle",
          "font-weight": "600" }));
    });

    parts.push(TR.svg.text(ml + cw / 2, H - 12, "Mean utility",
      { "font-size": 11, fill: AXIS, "text-anchor": "middle" }));
    parts.push(TR.svg.el("text", {
      x: 14, y: mt + ch / 2, "font-size": 11, fill: AXIS, "text-anchor": "middle",
      transform: "rotate(-90 14 " + (mt + ch / 2) + ")" }, "Spread across respondents"));

    var key = '<ol class="md-key">' + pts.map(function (d) {
      return "<li>" + esc(d.label) + "</li>";
    }).join("") + "</ol>";
    return chartBox(TR.svg.root(W, H, "Item strategy quadrant", parts.join(""))) + key;
  }

  /** Grouped bars: one group per item, one bar per level of a variable. */
  function segmentBarsSvg(variable, levels, items, valueAt) {
    if (!canDraw()) return "";
    var nS = levels.length, nI = items.length;
    if (!nS || !nI) return "";
    var barH = 12, barGap = 2, groupGap = 12;
    var ml = 190, mr = 54, mt = 14, W = 700;
    var groupH = nS * (barH + barGap) - barGap;
    var ch = nI * (groupH + groupGap) - groupGap;
    var cw = W - ml - mr;

    var vals = [];
    items.forEach(function (_, i) {
      levels.forEach(function (_, j) {
        var v = valueAt(i, j);
        if (v !== null && !isNaN(v)) vals.push(v);
      });
    });
    if (!vals.length) return "";
    var lo = Math.min(0, Math.min.apply(null, vals));
    var hi = Math.max(0, Math.max.apply(null, vals));
    if (hi === lo) hi = lo + 1;
    var xAt = function (v) { return ml + ((v - lo) / (hi - lo)) * cw; };
    var zero = xAt(0);

    var colours = seriesColours(nS);
    var parts = [];
    parts.push(TR.svg.el("line", { x1: zero, y1: mt, x2: zero, y2: mt + ch,
      stroke: AXIS, "stroke-width": 1 }));

    items.forEach(function (item, i) {
      var gy = mt + i * (groupH + groupGap);
      TR.svg.wrapText(String(item), 30).slice(0, 2).forEach(function (ln, li) {
        parts.push(TR.svg.text(ml - 8, gy + 10 + li * 11, ln,
          { "font-size": 10, fill: INK, "text-anchor": "end" }));
      });
      levels.forEach(function (_, j) {
        var v = valueAt(i, j);
        if (v === null || isNaN(v)) return;
        var by = gy + j * (barH + barGap);
        var x0 = Math.min(zero, xAt(v)), x1 = Math.max(zero, xAt(v));
        parts.push(TR.svg.el("rect", { x: x0.toFixed(1), y: by, rx: 2,
          width: Math.max(1, x1 - x0).toFixed(1), height: barH, fill: colours[j] }));
        parts.push(TR.svg.text(x1 + 4, by + barH - 2, num(v, 1),
          { "font-size": 9, fill: AXIS }));
      });
    });

    var leg = TR.svg.legend(levels.map(function (l, j) {
      return { label: String(l), colour: colours[j] };
    }), ml, mt + ch + 22, cw);
    parts.push(leg.body);

    return chartBox(TR.svg.root(W, mt + ch + 34 + (leg.height || 0),
      "Scores by " + variable, parts.join("")));
  }

  /**
   * Violin per item, from the island's flat density grid. A wide shape means
   * respondents disagreed about the item; a narrow one means they agreed.
   */
  function violinSvg(dist) {
    if (!canDraw()) return "";
    var ids = arr(dist.itemId);
    var k = dist.nPoints;
    if (!ids || !k || !arr(dist.densityX)) return "";

    var rowH = 34, ml = 190, mr = 70, mt = 16, W = 700;
    var ch = ids.length * rowH;
    var cw = W - ml - mr;

    var lo = null, hi = null, peak = 0;
    dist.densityX.forEach(function (x, i) {
      if (x === null || isNaN(x)) return;
      if (lo === null || x < lo) lo = x;
      if (hi === null || x > hi) hi = x;
      var y = dist.densityY[i];
      if (y !== null && !isNaN(y) && y > peak) peak = y;
    });
    if (lo === null || hi === null || hi === lo || peak <= 0) return "";
    var xAt = function (v) { return ml + ((v - lo) / (hi - lo)) * cw; };
    var half = (rowH - 10) / 2;

    var parts = [];
    [0, 0.25, 0.5, 0.75, 1].forEach(function (f) {
      var v = lo + (hi - lo) * f, gx = xAt(v);
      parts.push(TR.svg.el("line", { x1: gx, y1: mt, x2: gx, y2: mt + ch,
        stroke: GRID, "stroke-width": 1 }));
      parts.push(TR.svg.text(gx, mt + ch + 14, num(v, 1),
        { "font-size": 10, fill: AXIS, "text-anchor": "middle" }));
    });

    ids.forEach(function (id, i) {
      var cy = mt + i * rowH + rowH / 2;
      var label = labelFor(id);
      TR.svg.wrapText(String(label), 30).slice(0, 2).forEach(function (ln, li) {
        parts.push(TR.svg.text(ml - 8, cy + 3 + li * 11, ln,
          { "font-size": 10, fill: INK, "text-anchor": "end" }));
      });

      var span = dist.densityX.slice(i * k, (i + 1) * k);
      if (span.length !== k || span[0] === null || isNaN(span[0])) {
        // The reference item is fixed at zero for every respondent, so it has
        // no distribution to draw. It keeps its row and says why.
        parts.push(TR.svg.text(ml + 6, cy + 3, "fixed at zero, no spread to show",
          { "font-size": 10, fill: "#aeb3be" }));
        return;
      }
      var ys = dist.densityY.slice(i * k, (i + 1) * k);
      var upper = "", lower = "";
      span.forEach(function (x, j) {
        var h = (ys[j] / peak) * half;
        upper += (j ? "L" : "M") + xAt(x).toFixed(1) + " " + (cy - h).toFixed(1);
      });
      for (var j = k - 1; j >= 0; j--) {
        lower += "L" + xAt(span[j]).toFixed(1) + " " + (cy + (ys[j] / peak) * half).toFixed(1);
      }
      parts.push(TR.svg.el("path", { "class": "md-violin", d: upper + lower + " Z",
        fill: TR.svg.shade(BRAND, 0.42), stroke: BRAND, "stroke-width": 1 }));

      // The interquartile range as a solid bar through the middle.
      if (dist.q25 && dist.q25[i] !== null && !isNaN(dist.q25[i])) {
        parts.push(TR.svg.el("line", { x1: xAt(dist.q25[i]).toFixed(1), y1: cy,
          x2: xAt(dist.q75[i]).toFixed(1), y2: cy, stroke: BRAND,
          "stroke-width": 3, "stroke-linecap": "round" }));
      }
      if (dist.median && dist.median[i] !== null && !isNaN(dist.median[i])) {
        parts.push(TR.svg.el("circle", { cx: xAt(dist.median[i]).toFixed(1), cy: cy,
          r: 2.6, fill: "#ffffff", stroke: BRAND, "stroke-width": 1.4 }));
      }
    });

    parts.push(TR.svg.text(ml + cw / 2, mt + ch + 30, "Utility",
      { "font-size": 11, fill: AXIS, "text-anchor": "middle" }));

    return chartBox(TR.svg.root(W, mt + ch + 40,
      "Utility distribution per item", parts.join("")));
  }

  // -------------------------------------------------------------------------
  // Panels built on those charts
  // -------------------------------------------------------------------------

  /**
   * Per-segment item scores, one table and one chart per segment variable.
   *
   * Static, with no dropdown. The tab is frozen and hides the audience
   * filter, so a filter control here would promise a recut the module cannot
   * do. A level whose base is under the configured minimum is marked rather
   * than printed as if it were solid.
   */
  function segmentsHtml(sg) {
    if (!sg || !arr(sg.itemId) || !sg.itemId.length) return "";
    var vars = [];
    sg.variable.forEach(function (v) { if (vars.indexOf(v) < 0) vars.push(v); });
    if (!vars.length) return "";

    var scoreIds = arr(TR.MD.scores && TR.MD.scores.itemId) || [];
    var blocks = vars.map(function (v) {
      var idx = [];
      sg.variable.forEach(function (x, i) { if (x === v) idx.push(i); });
      var levels = [], baseOf = {};
      idx.forEach(function (i) {
        if (levels.indexOf(sg.level[i]) < 0) levels.push(sg.level[i]);
        baseOf[sg.level[i]] = sg.base[i];
      });
      var items = [];
      idx.forEach(function (i) { if (items.indexOf(sg.itemId[i]) < 0) items.push(sg.itemId[i]); });
      items.sort(function (a, b) {
        var ia = scoreIds.indexOf(a), ib = scoreIds.indexOf(b);
        return (ia < 0 ? 1e9 : ia) - (ib < 0 ? 1e9 : ib);
      });

      var cell = {};
      idx.forEach(function (i) { cell[sg.itemId[i] + "|" + sg.level[i]] = sg.netScore[i]; });
      var valueAt = function (ii, jj) {
        var val = cell[items[ii] + "|" + levels[jj]];
        return val === undefined || val === null ? null : val;
      };

      var thin = function (lv) {
        return sg.minBase != null && baseOf[lv] != null && baseOf[lv] < sg.minBase;
      };
      var head = "<tr><th>Item</th>" + levels.map(function (lv) {
        return '<th class="md-num' + (thin(lv) ? " md-thin" : "") + '">' +
          esc(lv) + '<span class="md-base">n = ' + esc(num(baseOf[lv], 0)) + "</span>" +
          (thin(lv) ? '<span class="md-thin-flag">small base</span>' : "") + "</th>";
      }).join("") + "</tr>";

      var rows = items.map(function (id, ii) {
        return "<tr><td>" + esc(labelFor(id)) + "</td>" + levels.map(function (lv, jj) {
          return '<td class="md-num' + (thin(lv) ? " md-thin" : "") + '">' +
            num(valueAt(ii, jj), 1) + "</td>";
        }).join("") + "</tr>";
      }).join("");

      var flagged = levels.filter(thin);
      var warn = flagged.length ? '<p class="md-note md-thin-note">' +
        esc("Fewer than " + num(sg.minBase, 0) + " respondents in " +
            flagged.join(", ") + ". Those columns are marked; read them as " +
            "indicative, not as a measurement.") + "</p>" : "";

      return "<h4>" + esc(v) + "</h4>" + warn +
        '<table class="md-table"><thead>' + head + "</thead><tbody>" + rows +
        "</tbody></table>" +
        segmentBarsSvg(v, levels, items.map(labelFor), valueAt);
    }).join("");

    return '<section class="md-panel"><h3>Scores by segment</h3>' +
      '<p class="md-note">' + esc((sg.note || "") +
        " Net score is best minus worst, as a percentage of the times an item " +
        "was shown. Segments are the ones the run estimated; they do not " +
        "respond to the audience filter.") + "</p>" +
      blocks + "</section>";
  }

  /** Per-item utility distributions, drawn as violins. */
  function distributionsHtml(dist) {
    if (!dist || !arr(dist.itemId) || !dist.itemId.length) return "";
    var body = violinSvg(dist);
    if (!body) return "";
    return '<section class="md-panel"><h3>Utility distributions</h3>' +
      '<p class="md-note">' + esc((dist.note || "") +
        " The bar through each shape is the middle half of respondents and the " +
        "dot is the median.") + "</p>" + body + "</section>";
  }

  /** The item strategy quadrant, when there are individual utilities behind it. */
  function quadrantHtml(sc) {
    var body = quadrantSvg(sc);
    if (!body) return "";
    // An item needs both a utility and a spread to be placed. The Stan
    // reference item has no spread, so it is absent; that is named rather
    // than left for the reader to notice by counting.
    var plotted = (body.match(/<circle/g) || []).length;
    var total = (arr(sc.itemId) || []).length;
    var missing = total > plotted ? " " + (total - plotted) +
      " of " + total + " items are not plotted, because the model fixed them " +
      "and they have no spread to place." : "";
    return '<section class="md-panel"><h3>Item strategy</h3>' +
      '<p class="md-note">' + esc("Each item by how well it scored and how much " +
        "respondents disagreed about it. The dashed lines are the medians, so " +
        "the quadrants are relative to this study, not to an absolute standard." +
        missing) +
      "</p>" + body + "</section>";
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
      quadrantHtml(d.scores) +
      distributionsHtml(d.distributions) +
      headToHeadHtml(d.headToHead) +
      segmentsHtml(d.segments) +
      diagnosticsHtml(d.diagnostics) +
      "</div>";
  };

}(typeof window !== "undefined" ? window : this));
