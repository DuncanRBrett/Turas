/**
 * Categorical drivers view. Driver importance for a categorical outcome, the
 * odds ratio for every driver level with the interval that was actually
 * computed, the probability lift for a named outcome level, the raw pattern
 * behind each driver, a subgroup comparison where one was run, and a
 * diagnostics drawer carrying model fit, the assumption checks and the base.
 *
 * FROZEN, NOT LIVE. Every other analysis tab recomputes from microdata when
 * the audience filter changes. This one cannot: an odds ratio is a model
 * estimate made once, on the whole sample, and a logistic regression cannot be
 * re-fitted in the browser. So the tab shows what was estimated, the filter bar
 * is hidden while it is open, and the note at the top says so. Same contract as
 * Conjoint, MaxDiff, Pricing, Key drivers and Tracking.
 *
 * The data comes from TR.CD, the catdriver module's contribution island
 * (modules/catdriver/R/13_v2_island.R). There are no new row kinds: a driver
 * level has no banner and no base of its own, an odds ratio has no percentage,
 * and none of this belongs in the crosstab data layer.
 *
 * ODDS ARE NOT LIKELIHOOD. An odds ratio of 5 does not mean five times as
 * likely; how much it moves a probability depends on the base rate. This view
 * says odds wherever it names the quantity, and the probability lift panel is
 * where a reader goes for the probability scale.
 *
 * AN ABSENT INTERVAL IS NOT A ZERO INTERVAL. The bootstrap is optional and
 * never runs for a multinomial outcome. The island says which intervals it
 * carries; this view draws the bootstrap whisker only where one exists and
 * shows the Wald interval otherwise, labelled for what it is.
 *
 * SIGNIFICANCE IS NOT BORROWED. Importance and odds ratios are model estimates,
 * so nothing here routes through the crosstab significance engine, whose
 * letters come from proportion and Welch tests on counts. The interval is the
 * uncertainty statement, and there is no significance letter anywhere on this
 * tab. The gate asserts that by name.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var cd = TR.catdriver = {};

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // A missing value shows as an en dash, never as "NaN" or an empty cell.
  function num(v, dp) {
    if (v === null || v === undefined || v === "" || isNaN(v)) return "–";
    return Number(v).toFixed(dp === undefined ? 1 : dp);
  }

  function arr(v) { return Array.isArray(v) ? v : null; }
  function meta() { return (TR.CD && TR.CD.meta) || {}; }

  /**
   * The interval's confidence level, in the island's own words.
   *
   * Never typed into this file: a study configured at 90% must not be labelled
   * 95% by a renderer that assumed one.
   * @returns {string}
   */
  function ciLabel() {
    var lv = meta().confidence_level;
    if (lv === undefined || lv === null || isNaN(lv)) return "Interval";
    return Math.round(Number(lv) * 100) + "% interval";
  }

  cd.state = { panel: "importance", subgroupView: "importance" };

  /** Whether this report carries a categorical driver contribution at all. */
  cd.available = function () {
    var d = TR.CD;
    return !!(d && d.importance && arr(d.importance.rows) && d.importance.rows.length);
  };

  // ---------------------------------------------------------------- panels

  /** What ran, on what base. The first thing on the tab, deliberately. */
  function provenanceHtml(m) {
    var f = (TR.CD && TR.CD.fit) || {};
    var bits = [];
    if (m.outcome && (m.outcome.label || m.outcome.var)) {
      bits.push("Outcome: <strong>" + esc(m.outcome.label || m.outcome.var) + "</strong>");
    }
    if (m.outcome && m.outcome.type) bits.push(esc(m.outcome.type));
    if (m.n_drivers) bits.push(m.n_drivers + " drivers");
    if (f.n !== undefined) bits.push("n = " + num(f.n, 0));
    if (f.n_excluded) bits.push(num(f.n_excluded, 0) + " excluded");
    if (m.weighted) {
      var w = "weighted";
      if (f.n_eff !== undefined) w += " (effective n = " + num(f.n_eff, 0) + ")";
      bits.push(w);
    } else {
      bits.push("unweighted");
    }

    var degraded = arr(m.degraded_reasons) || [];
    var degradedHtml = degraded.length
      ? '<details class="cd-degraded"><summary>' + degraded.length +
        " qualification" + (degraded.length === 1 ? "" : "s") +
        " on this run</summary><ul>" +
        degraded.map(function (r) { return "<li>" + esc(r) + "</li>"; }).join("") +
        "</ul></details>"
      : "";

    return '<div class="cd-panel cd-provenance">' +
      "<h3>" + esc(m.analysis_name || "Categorical drivers") + "</h3>" +
      "<p>" + bits.join(" &middot; ") + "</p>" +
      '<p class="cd-frozen">' + esc(m.filter_note ||
        "Report filters do not apply here.") +
      " The crosstab export is the filterable cut.</p>" +
      degradedHtml +
      "</div>";
  }

  /** Driver importance, as bars, with the method that produced the numbers. */
  function importanceHtml() {
    var imp = TR.CD.importance;
    var rows = arr(imp.rows) || [];
    if (!rows.length) return "";

    var vals = rows.map(function (r) { return Number(r.pct); })
      .filter(function (v) { return !isNaN(v); });
    var hi = vals.length ? Math.max.apply(null, vals) : 1;
    if (!(hi > 0)) hi = 1;

    var bars = rows.map(function (r) {
      var pct = Number(r.pct);
      var w = isNaN(pct) ? 0 : Math.max(0, (pct / hi) * 100);
      return '<tr><th scope="row">' + esc(r.label || r.driver) + "</th>" +
        '<td class="cd-barcell"><span class="cd-bar" style="width:' + w.toFixed(1) +
        '%"></span></td>' +
        "<td>" + num(r.pct, 1) + "%</td>" +
        "<td>" + num(r.statistic, 1) + "</td>" +
        "<td>" + (r.df === undefined ? "–" : num(r.df, 0)) + "</td>" +
        "<td>" + esc(r.effect || "–") + "</td></tr>";
    }).join("");

    return '<div class="cd-panel">' +
      "<h3>Driver importance</h3>" +
      '<table class="cd-table"><thead><tr>' +
      "<th>Driver</th><th>Share</th><th>%</th><th>Statistic</th><th>df</th><th>Effect</th>" +
      "</tr></thead><tbody>" + bars + "</tbody></table>" +
      (imp.method ? '<p class="cd-method">Computed as: ' + esc(imp.method) + "</p>" : "") +
      "</div>";
  }

  /**
   * Odds ratios per driver level.
   *
   * The interval column says which interval it is. Where a bootstrap ran, both
   * are shown, because they answer slightly different questions and a reader
   * comparing two reports needs to know which one they are looking at.
   */
  function oddsHtml() {
    var or = TR.CD.odds_ratios;
    if (!or || !arr(or.rows) || !or.rows.length) return "";
    var hasBoot = !!or.bootstrap;
    var hasOutcomeLevel = or.rows.some(function (r) { return r.outcome_level; });

    var body = or.rows.map(function (r) {
      var wald = (r.lo === undefined || r.hi === undefined)
        ? "–" : num(r.lo, 2) + " to " + num(r.hi, 2);
      var boot = (!hasBoot || r.boot_lo === undefined || r.boot_hi === undefined)
        ? "–" : num(r.boot_lo, 2) + " to " + num(r.boot_hi, 2);
      var stab = (r.sign_stability === undefined)
        ? "–" : num(Number(r.sign_stability) * 100, 0) + "%";
      return "<tr>" +
        '<th scope="row">' + esc(r.label || r.driver) + "</th>" +
        "<td>" + esc(r.level) + (r.reference ? ' <span class="cd-ref">vs ' +
          esc(r.reference) + "</span>" : "") + "</td>" +
        (hasOutcomeLevel ? "<td>" + esc(r.outcome_level || "–") +
          (r.vs_outcome ? ' <span class="cd-ref">vs ' + esc(r.vs_outcome) + "</span>" : "") +
          "</td>" : "") +
        "<td>" + num(r.or, 2) + "</td>" +
        "<td>" + wald + "</td>" +
        (hasBoot ? "<td>" + boot + "</td><td>" + stab + "</td>" : "") +
        "</tr>";
    }).join("");

    return '<div class="cd-panel">' +
      "<h3>Odds ratios</h3>" +
      '<p class="cd-note">An odds ratio above 1 means higher odds of the outcome than ' +
      "the reference level. It is not a ratio of probabilities: how much it moves the " +
      "chance depends on the base rate. The probability lift panel is the probability scale.</p>" +
      '<table class="cd-table"><thead><tr>' +
      "<th>Driver</th><th>Level</th>" +
      (hasOutcomeLevel ? "<th>Outcome level</th>" : "") +
      "<th>Odds ratio</th><th>" + esc(ciLabel()) + " (Wald)</th>" +
      (hasBoot ? "<th>Bootstrap</th><th>Sign stability</th>" : "") +
      "</tr></thead><tbody>" + body + "</tbody></table>" +
      (hasBoot ? "" : '<p class="cd-note">No bootstrap ran for this study, so the ' +
        "interval shown is the Wald interval from the model.</p>") +
      "</div>";
  }

  /** Probability lifts, which name the outcome level they describe. */
  function liftsHtml() {
    var l = TR.CD.lifts;
    if (!l || !arr(l.rows) || !l.rows.length) return "";

    var body = l.rows.map(function (r) {
      return "<tr>" +
        '<th scope="row">' + esc(r.label || r.driver) + "</th>" +
        "<td>" + esc(r.level) + (r.is_reference ? ' <span class="cd-ref">reference</span>' : "") +
        "</td>" +
        "<td>" + num(Number(r.prob) * 100, 1) + "%</td>" +
        "<td>" + (r.is_reference ? "–" : num(r.lift_pp, 1) + " pp") + "</td>" +
        "</tr>";
    }).join("");

    return '<div class="cd-panel">' +
      "<h3>Probability lift" +
      (l.outcome_level ? ": " + esc(l.outcome_level) : "") + "</h3>" +
      '<p class="cd-note">' + esc(l.basis || "") + "</p>" +
      '<table class="cd-table"><thead><tr>' +
      "<th>Driver</th><th>Level</th><th>Fitted probability</th><th>Difference</th>" +
      "</tr></thead><tbody>" + body + "</tbody></table></div>";
  }

  /** The raw picture behind each driver, before any model touched it. */
  function patternsHtml() {
    var blocks = arr(TR.CD.patterns) || [];
    if (!blocks.length) return "";

    var tables = blocks.map(function (b) {
      var levels = arr(b.outcome_levels) || [];
      var head = "<th>Level</th><th>n</th><th>% of sample</th>" +
        levels.map(function (lv) { return "<th>% " + esc(lv) + "</th>"; }).join("");
      var body = (arr(b.rows) || []).map(function (r) {
        var shares = (arr(r.shares) || []).map(function (s) {
          return "<td>" + num(s.pct, 1) + "%</td>";
        }).join("");
        return "<tr>" +
          '<th scope="row">' + esc(r.level) +
          (r.is_reference ? ' <span class="cd-ref">reference</span>' : "") + "</th>" +
          "<td>" + num(r.n, 0) + "</td>" +
          "<td>" + num(r.pct_of_total, 1) + "%</td>" + shares + "</tr>";
      }).join("");
      return "<h4>" + esc(b.label || b.driver) + "</h4>" +
        '<table class="cd-table"><thead><tr>' + head + "</tr></thead><tbody>" +
        body + "</tbody></table>";
    }).join("");

    return '<div class="cd-panel"><h3>Factor patterns</h3>' +
      '<p class="cd-note">Observed shares, with no model in them. These are the ' +
      "counts the model was fitted to.</p>" + tables + "</div>";
  }

  /** The subgroup comparison, where one was run. */
  function subgroupsHtml() {
    var sg = TR.CD.subgroups;
    if (!sg || !arr(sg.importance) || !sg.importance.length) return "";
    var groups = arr(sg.groups) || [];

    var head = "<th>Driver</th>" +
      groups.map(function (g) { return "<th>" + esc(g) + "</th>"; }).join("") +
      "<th>Pattern</th>";
    var body = sg.importance.map(function (r) {
      var cells = groups.map(function (g) {
        var hit = (arr(r.groups) || []).filter(function (x) { return x.group === g; })[0];
        if (!hit) return "<td>–</td>";
        return "<td>" + (hit.rank === undefined ? "" : "#" + num(hit.rank, 0) + " ") +
          '<span class="cd-muted">' + num(hit.pct, 1) + "%</span></td>";
      }).join("");
      return "<tr>" + '<th scope="row">' + esc(r.label || r.driver) + "</th>" +
        cells + "<td>" + esc(r.classification || "–") + "</td></tr>";
    }).join("");

    var fit = (arr(sg.fit) || []).map(function (f) {
      return "<tr><th scope=\"row\">" + esc(f.group) + "</th>" +
        "<td>" + num(f.n, 0) + "</td>" +
        "<td>" + (f.n_before_missing === undefined ? "–" : num(f.n_before_missing, 0)) + "</td>" +
        "<td>" + num(f.mcfadden_r2, 3) + "</td>" +
        "<td>" + esc(f.status || "–") + "</td></tr>";
    }).join("");

    var insights = (arr(sg.insights) || []).map(function (i) {
      return "<li>" + esc(i) + "</li>";
    }).join("");

    return '<div class="cd-panel">' +
      "<h3>By " + esc(sg.variable || "subgroup") + "</h3>" +
      '<table class="cd-table"><thead><tr>' + head + "</tr></thead><tbody>" +
      body + "</tbody></table>" +
      (insights ? "<ul class=\"cd-insights\">" + insights + "</ul>" : "") +
      (fit ? "<h4>Model fit by group</h4>" +
        '<table class="cd-table"><thead><tr><th>Group</th><th>n analysed</th>' +
        "<th>n before missing</th><th>McFadden R2</th><th>Status</th></tr></thead><tbody>" +
        fit + "</tbody></table>" : "") +
      "</div>";
  }

  /** Model fit, the assumption checks and the weighting statement. */
  function diagnosticsHtml() {
    var f = TR.CD.fit;
    if (!f) return "";
    var rows = [];
    function add(label, value) {
      if (value === undefined || value === null || value === "") return;
      rows.push("<tr><th scope=\"row\">" + esc(label) + "</th><td>" + value + "</td></tr>");
    }
    add("Model", esc(f.model_type || "") + (f.engine ? " (" + esc(f.engine) + ")" : ""));
    add("McFadden R2", num(f.mcfadden_r2, 3));
    add("AIC", num(f.aic, 1));
    add("Likelihood ratio", f.lr === undefined ? null :
      num(f.lr, 1) + (f.lr_df === undefined ? "" : " on " + num(f.lr_df, 0) + " df"));
    add("Classification accuracy", f.accuracy === undefined ? null :
      num(Number(f.accuracy) * 100, 1) + "%");
    add("Converged", f.converged ? "yes" : "no");
    add("Respondents", num(f.n, 0) +
      (f.n_original === undefined ? "" : " of " + num(f.n_original, 0)));
    if (f.proportional_odds) {
      add("Proportional odds", esc(f.proportional_odds.interpretation ||
        f.proportional_odds.status || ""));
    }
    if (f.multicollinearity) {
      add("Multicollinearity", esc(f.multicollinearity.interpretation ||
        f.multicollinearity.status || ""));
    }

    var weighting = f.weighting
      ? '<p class="cd-note">' + esc(f.weighting) + "</p>" : "";

    return '<details class="cd-panel cd-diagnostics"><summary>Diagnostics</summary>' +
      '<table class="cd-table"><tbody>' + rows.join("") + "</tbody></table>" +
      weighting + "</details>";
  }

  // ---------------------------------------------------------------- render

  /**
   * Draw the tab.
   * @param {HTMLElement} host
   */
  cd.render = function (host) {
    if (!cd.available()) {
      host.innerHTML = '<div class="cd-panel"><p>This report carries no categorical ' +
        "driver results.</p></div>";
      return;
    }
    host.innerHTML =
      '<div class="cd-view">' +
      "<h2>Categorical drivers</h2>" +
      provenanceHtml(meta()) +
      importanceHtml() +
      oddsHtml() +
      liftsHtml() +
      subgroupsHtml() +
      patternsHtml() +
      diagnosticsHtml() +
      "</div>";
  };
})(typeof window !== "undefined" ? window : this);
