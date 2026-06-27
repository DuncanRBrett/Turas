/**
 * Executive Takeout — Read view. A single-screen argument: one editable apex
 * answer, the composite indices, then the findings grouped into four decision
 * postures (Protect / Act / Watch / Decide). Every headline and "so what" is
 * inline-editable so the message can land in the client's own language.
 *
 * Pure HTML builder: takes the takeout object, returns a string. The controller
 * (27k) injects it and wires editing, deep-links and vetoes.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var fmt = TR.fmt, ui = takeout.ui;
  var read = takeout.readView = {};

  /** Signed gap in the finding's own units ("+12pp", "−0.6"), or "". */
  function gapText(f) {
    if (f.gap === null || f.gap === undefined) return "";
    var dir = f.gap >= 0 ? "+" : "−";
    return dir + (f.metric === "mean"
      ? Math.abs(f.gap).toFixed(f.decimals || 1)
      : Math.abs(Math.round(f.gap)) + "pp");
  }

  /** The big number + its label + the signed gap chip. */
  function metricLine(f) {
    return '<div class="tko-metric"><span class="tko-big">' + ui.fmtVal(f, f.value) +
      '</span> <span class="tko-mlabel">' + fmt.escapeHtml(ui.metricLabel(f)) + "</span>" +
      ui.topBox(f) +
      (gapText(f) ? '<span class="tko-gap tko-' + f.posture + '">' + gapText(f) + "</span>" : "") +
      "</div>";
  }

  /** One finding as an editable card. */
  function cardHtml(f, lowThreshold) {
    var claim = takeout.state.getText(f.id, "claim", ui.seedClaim(f));
    var soWhat = takeout.state.getText(f.id, "soWhat", ui.seedSoWhat(f));
    var visual = f.kind === "level" ? ui.gaugeBar(f) : ui.twoBar(f);
    return '<article class="tko-card tko-edge-' + f.posture + '" data-id="' +
      fmt.escapeHtml(f.id) + '">' +
      ui.editable(f.id, "claim", claim, "tko-claim", "Finding headline — editable") +
      ui.questionLine(f) + metricLine(f) + visual +
      '<div class="tko-chips">' + ui.bannerChip(f) + ui.baseChip(f, lowThreshold) +
      ui.softTag(f) + ui.deltaChip(f) + "</div>" +
      ui.editable(f.id, "soWhat", soWhat, "tko-sowhat", "Implication — editable") +
      '<div class="tko-card-foot">' +
      '<button class="linklike" data-goq="' + fmt.escapeHtml(f.code) +
      '">see the table →</button>' +
      '<button class="tko-veto" data-veto="' + fmt.escapeHtml(f.id) +
      '" aria-label="Hide this finding and promote the next">Hide</button></div></article>';
  }

  /** One posture lane: header + its capped cards. Empty lanes are omitted. */
  function laneHtml(posture, lowThreshold) {
    if (!posture.items.length) return "";
    return '<section class="tko-lane" aria-label="' + fmt.escapeHtml(posture.label) + '">' +
      '<header class="tko-lane-head tko-on-' + posture.id + '">' +
      '<span class="tko-lane-dot">' + ui.glyph(posture.id) + "</span>" +
      "<h3>" + fmt.escapeHtml(posture.label) + "</h3>" +
      '<span class="tko-verb">' + fmt.escapeHtml(posture.verb) + "</span>" +
      '<span class="tko-count">' + posture.items.length + "</span></header>" +
      '<div class="tko-lane-grid">' +
      posture.items.map(function (f) { return cardHtml(f, lowThreshold); }).join("") +
      "</div></section>";
  }

  /** The apex band: kicker, the editable answer, the headline indices. */
  function apexHtml(t) {
    var project = (TR.AGG && TR.AGG.project && TR.AGG.project.name) || "This study";
    var apex = takeout.state.getApex(ui.apexSeed(t.answer.metrics));
    var metrics = (t.answer.metrics || []).slice(0, 3).map(function (c) {
      return '<div class="tko-kpi"><div class="tko-kpi-label">' +
        fmt.escapeHtml(c.label || c.title) +
        '</div><div class="tko-kpi-val">' + Number(c.value).toFixed(1) + ui.topBox(c) +
        '</div><div class="tko-kpi-foot"><span class="tko-kpi-band tko-band-' +
        (c.band || "na") + '">' + fmt.escapeHtml(c.band || "—") + "</span>" +
        ui.apexSpark(c) + "</div></div>";
    }).join("");
    return '<div class="tko-apex"><div class="tko-kicker">Executive takeout · ' +
      fmt.escapeHtml(project) + '</div><div class="tko-apex-main"><div class="tko-apex-answer">' +
      '<div class="tko-eyebrow">The answer</div>' +
      ui.editable("__apex__", "answer", apex, "tko-answer", "The one-sentence answer — editable") +
      '</div>' + (metrics ? '<div class="tko-apex-metrics">' + metrics + "</div>" : "") +
      "</div>" + ui.reliabilityRibbon(t.reliability) + "</div>";
  }

  /** Provenance line — the glass-box audit trail. */
  function provHtml(t) {
    return '<div class="tko-prov" role="note">Surfaced from ' + t.candidateCount +
      " candidate findings · " + t.promotedCount + " promoted · ranked by effect size " +
      "(Cohen's h) under base &amp; significance gates · curated by the researcher.</div>";
  }

  /** Build the full Read view for a takeout object. */
  read.html = function (t, opts) {
    opts = opts || {};
    var lanes = t.postures.map(function (p) {
      return laneHtml(p, opts.lowThreshold);
    }).join("");
    var body = lanes ||
      '<div class="tko-empty">No finding clears the significance and base gates ' +
      "on this banner. That is itself the headline — nothing stands out.</div>";
    return apexHtml(t) + '<div class="tko-lanes">' + body + "</div>" + provHtml(t);
  };

})(typeof window !== "undefined" ? window : globalThis);
