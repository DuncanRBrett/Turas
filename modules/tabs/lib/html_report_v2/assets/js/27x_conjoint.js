/**
 * Conjoint view. Attribute importance, part-worth utilities with honest
 * intervals, model fit, and willingness to pay when the study produced it.
 *
 * FROZEN, NOT LIVE. Every other analysis tab recomputes from microdata when
 * the audience filter changes. Conjoint cannot: the model was fitted once, on
 * the whole sample. So this tab shows what was estimated and the filter bar is
 * hidden while it is open. The same contract as Tracking. The note at the top
 * of the tab says so, rather than leaving the reader to notice the filter has
 * no effect.
 *
 * The data comes from TR.CJ, the conjoint module's contribution island. There
 * are no new row kinds: a part-worth has no banner, no base and no percentage,
 * so it does not belong in the crosstab data layer.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var cj = TR.conjoint = {};

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function num(v, dp) {
    if (v === null || v === undefined || isNaN(v)) return "–";
    return Number(v).toFixed(dp === undefined ? 1 : dp);
  }

  /** Is there a conjoint contribution with anything in it? */
  cj.available = function () {
    var d = TR.CJ;
    return !!(d && d.meta && d.utilities && d.utilities.length);
  };

  cj.data = function () { return TR.CJ; };

  // -------------------------------------------------------------------------
  // Panels
  // -------------------------------------------------------------------------

  function provenanceHtml(meta) {
    var bits = [];
    bits.push("Estimated with <strong>" + esc(meta.methodLabel || meta.method) + "</strong>");
    if (meta.nRespondents) bits.push(esc(meta.nRespondents) + " respondents");
    if (meta.nChoiceSets) bits.push(esc(meta.nChoiceSets) + " choice sets");
    if (meta.converged === false) {
      bits.push('<strong class="cj-warn">the model did not converge</strong>');
    }

    var notes = [];
    if (meta.filterNote) notes.push(esc(meta.filterNote));
    if (meta.unweightedNote) notes.push(esc(meta.unweightedNote));

    // The market simulator is a separate file. A tool rather than report
    // content. Link to it when the study produced one; it sits beside this
    // report, so a relative link is right.
    var sim = "";
    if (meta.simulatorFile) {
      sim = '<p class="cj-note">Market simulator: <a href="' +
        esc(meta.simulatorFile) + '">' + esc(meta.simulatorFile) +
        "</a>. Open it beside this report to test product configurations.</p>";
    }

    return '<div class="cj-provenance">' +
      "<p>" + bits.join(" · ") + "</p>" +
      (notes.length ? '<p class="cj-note">' + notes.join(" ") + "</p>" : "") +
      sim +
      "</div>";
  }

  function importanceHtml(imp) {
    if (!imp || !imp.attribute || !imp.attribute.length) return "";

    var max = 0;
    imp.importance.forEach(function (v) { if (v > max) max = v; });

    // An island whose writer had no SD column may carry sd as {} (a NULL
    // serialised by jsonlite), only a real array counts.
    var sdArr = Array.isArray(imp.sd) ? imp.sd : null;

    // Descending: the attribute that drives choice most is read first.
    var rows = imp.attribute.map(function (a, i) {
      var v = imp.importance[i];
      var w = max > 0 ? (v / max * 100) : 0;
      var sd = sdArr && sdArr[i] != null
        ? '<td class="cj-num">' + num(sdArr[i]) + "</td>" : "";
      return "<tr><td>" + esc(a) + "</td>" +
        '<td class="cj-barcell"><span class="cj-bar" style="width:' + w.toFixed(1) + '%"></span></td>' +
        '<td class="cj-num">' + num(v) + "%</td>" + sd + "</tr>";
    }).join("");

    var sdHead = sdArr ? '<th class="cj-num">SD across respondents</th>' : "";
    var method = imp.method === "individual"
      ? "Each respondent's own importance was computed first, then averaged."
      : "Computed from the averaged utilities. Where respondents disagree about an attribute, that disagreement cancels before the range is taken, so its importance is understated.";

    return '<section class="cj-panel"><h3>Attribute importance</h3>' +
      '<p class="cj-note">' + esc(method) + "</p>" +
      '<table class="cj-table"><thead><tr><th>Attribute</th><th></th>' +
      '<th class="cj-num">Importance</th>' + sdHead + "</tr></thead><tbody>" +
      rows + "</tbody></table></section>";
  }

  function utilitiesHtml(blocks, meta) {
    var anyHet = blocks.some(function (b) {
      // Array.isArray, not truthiness: an older island can carry {} here.
      var het = Array.isArray(b.heterogeneity) ? b.heterogeneity : [];
      return het.some(function (h) { return h != null && h > 0; });
    });

    var tables = blocks.map(function (b) {
      var rows = b.levels.map(function (lv, i) {
        var base = b.isBaseline && b.isBaseline[i];

        // A baseline level is the reference the others are measured against.
        // It carries no standard error and no interval. The utilities table
        // stores its bounds equal to its own value, which would print as a
        // zero-width interval and read like an impossibly precise estimate.
        var se = base ? "–"
          : (b.se && b.se[i] != null ? num(b.se[i], 2) : "–");
        var ci = base ? "–"
          : ((b.ciLower && b.ciLower[i] != null && b.ciUpper[i] != null)
              ? num(b.ciLower[i], 2) + " to " + num(b.ciUpper[i], 2) : "–");
        var het = anyHet
          ? '<td class="cj-num">' +
            (base ? "–" : (Array.isArray(b.heterogeneity) ? num(b.heterogeneity[i], 2) : "–")) + "</td>"
          : "";

        return "<tr>" +
          "<td>" + esc(lv) + (base ? ' <span class="cj-baseline">(baseline)</span>' : "") + "</td>" +
          '<td class="cj-num">' + num(b.utility[i], 2) + "</td>" +
          '<td class="cj-num">' + se + "</td>" +
          '<td class="cj-num">' + ci + "</td>" + het + "</tr>";
      }).join("");

      return '<div class="cj-attr"><h4>' + esc(b.attribute) + "</h4>" +
        '<table class="cj-table"><thead><tr><th>Level</th>' +
        '<th class="cj-num">Utility</th><th class="cj-num">Std. error</th>' +
        '<th class="cj-num">95% CI</th>' +
        (anyHet ? '<th class="cj-num">Heterogeneity (SD)</th>' : "") +
        "</tr></thead><tbody>" + rows + "</tbody></table></div>";
    }).join("");

    var scale = meta.zeroCentred
      ? "Utilities are zero-centred within each attribute: they compare levels to that attribute's average, not to a fixed origin."
      : "Utilities are shown relative to each attribute's baseline level, which is zero.";

    var hetNote = anyHet
      ? " Std. error is the precision of the estimated average. Heterogeneity (SD) is how much respondents differ from each other. A large one with a small standard error means a real split in the sample, not an imprecise estimate."
      : "";

    return '<section class="cj-panel"><h3>Part-worth utilities</h3>' +
      '<p class="cj-note">' + esc(scale) + esc(hetNote) + "</p>" +
      '<div class="cj-attrs">' + tables + "</div></section>";
  }

  function fitHtml(fit) {
    if (!fit) return "";
    // An island written before the writer dropped NULL blocks carries
    // "fit": {}. Truthy, but with nothing to say. No panel for those either.
    var any = [fit.mcFaddenR2, fit.hitRate, fit.chanceRate,
               fit.logLikelihoodFitted, fit.logLikelihoodNull,
               fit.nObservations, fit.nParameters].some(function (v) {
      return v !== null && v !== undefined;
    });
    if (!any) return "";

    var beatsChance = (fit.hitRate != null && fit.chanceRate != null)
      ? " The model picks the chosen alternative " + num(fit.hitRate * 100) +
        "% of the time; guessing would get " + num(fit.chanceRate * 100) + "%."
      : "";

    var rows = [
      ["McFadden R²", num(fit.mcFaddenR2, 3)],
      ["Hit rate", fit.hitRate != null ? num(fit.hitRate * 100) + "%" : "–"],
      ["Chance rate", fit.chanceRate != null ? num(fit.chanceRate * 100) + "%" : "–"],
      ["Log-likelihood (fitted)", num(fit.logLikelihoodFitted, 1)],
      ["Log-likelihood (null)", num(fit.logLikelihoodNull, 1)],
      ["Observations", num(fit.nObservations, 0)],
      ["Parameters", num(fit.nParameters, 0)]
    ].map(function (r) {
      return "<tr><td>" + esc(r[0]) + '</td><td class="cj-num">' + r[1] + "</td></tr>";
    }).join("");

    return '<section class="cj-panel"><h3>Model fit</h3>' +
      '<p class="cj-note">McFadden R² is not the R² of a regression: 0.2 to 0.4 is a good choice model.' +
      esc(beatsChance) + "</p>" +
      '<table class="cj-table"><tbody>' + rows + "</tbody></table></section>";
  }

  function wtpHtml(wtp) {
    if (!wtp || !wtp.level || !wtp.level.length) return "";

    var cur = wtp.currency || "";
    var rows = wtp.level.map(function (lv, i) {
      var base = wtp.isBaseline && wtp.isBaseline[i];
      var ci = (wtp.ciLower && wtp.ciLower[i] != null && wtp.ciUpper[i] != null)
        ? cur + num(wtp.ciLower[i], 2) + " to " + cur + num(wtp.ciUpper[i], 2) : "–";
      return "<tr><td>" + esc(wtp.attribute[i]) + "</td><td>" + esc(lv) +
        (base ? ' <span class="cj-baseline">(baseline)</span>' : "") + "</td>" +
        '<td class="cj-num">' + (base ? cur + "0.00" : cur + num(wtp.wtp[i], 2)) + "</td>" +
        '<td class="cj-num">' + (base ? "–" : ci) + "</td></tr>";
    }).join("");

    return '<section class="cj-panel"><h3>Willingness to pay</h3>' +
      '<p class="cj-note">Against the ' + esc(wtp.priceAttribute || "price") +
      " attribute. Each figure is what the level is worth relative to its own attribute's baseline. " +
      esc(wtp.intervalNote || "") + "</p>" +
      '<table class="cj-table"><thead><tr><th>Attribute</th><th>Level</th>' +
      '<th class="cj-num">WTP</th><th class="cj-num">Interval (approx.)</th>' +
      "</tr></thead><tbody>" + rows + "</tbody></table></section>";
  }

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------

  cj.render = function (host) {
    var d = TR.CJ;

    if (!cj.available()) {
      host.innerHTML = '<div class="cj-panel"><p>This report carries no conjoint results.</p></div>';
      return;
    }

    host.innerHTML =
      '<div class="cj-view">' +
      "<h2>Conjoint</h2>" +
      provenanceHtml(d.meta) +
      importanceHtml(d.importance) +
      utilitiesHtml(d.utilities, d.meta) +
      fitHtml(d.fit) +
      wtpHtml(d.wtp) +
      "</div>";
  };

}(typeof window !== "undefined" ? window : this));
