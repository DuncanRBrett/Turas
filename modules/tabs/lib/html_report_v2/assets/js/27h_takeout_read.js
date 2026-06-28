/**
 * Executive Takeout — Read view (Patterns). One editable big-picture answer, the
 * headline indices, then the cross-question patterns: the group under strain,
 * the weakest and strongest areas, and what moved. Each takeaway is editable so
 * the message lands in the client's language.
 *
 * Pure HTML builder: takes the patterns object, returns a string. The controller
 * (27k) injects it and wires editing, deep-links and the "how sure" panel.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var fmt = TR.fmt, ui = takeout.ui;
  var read = takeout.readView = {};

  /** The apex band: kicker, the editable answer, the headline indices. */
  function apexHtml(t) {
    var project = (TR.AGG && TR.AGG.project && TR.AGG.project.name) || "This study";
    var answer = takeout.state.getApex(ui.answerSeed(t.patterns));
    var kpis = (t.answer.metrics || []).slice(0, 3).map(function (m) {
      return '<div class="tko-kpi"><div class="tko-kpi-label">' + fmt.escapeHtml(m.label || m.title) +
        '</div><div class="tko-kpi-val">' + ui.fmtVal(true, m.value) + ui.topBox(m) +
        '</div><div class="tko-kpi-foot"><span class="tko-kpi-band tko-band-' + (m.band || "na") +
        '">' + fmt.escapeHtml(m.band || "—") + "</span>" + ui.apexTrend(m) + "</div></div>";
    }).join("");
    return '<div class="tko-apex"><div class="tko-kicker">Executive takeout · patterns · ' +
      fmt.escapeHtml(project) + '</div><div class="tko-apex-main"><div class="tko-apex-answer">' +
      '<div class="tko-eyebrow">The big picture</div>' +
      ui.editable("__apex__", "answer", answer, "tko-answer", "The one-line answer — editable") +
      "</div>" + (kpis ? '<div class="tko-apex-metrics">' + kpis + "</div>" : "") + "</div>" +
      ui.reliabilityRibbon(t.reliability) + "</div>";
  }

  /** Heading line for a pattern card (subject + context). */
  function headHtml(p) {
    if (p.kind === "area") {
      return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) +
        '<span class="tko-pscore"> · ' + Number(p.avg).toFixed(1) + "</span></div>";
    }
    if (p.kind === "group") {
      return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) + "</div>" + ui.bannerChip(p.group);
    }
    return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) + "</div>";
  }

  /** Evidence + note for a pattern card. */
  function bodyHtml(p, cls) {
    if (p.kind === "group") {
      var rows = (p.evidence || []).map(function (e) { return ui.groupRow(e, cls); }).join("");
      var note = p.secondary
        ? '<div class="tko-note">Most positive group: ' + fmt.escapeHtml(p.secondary) + ".</div>" : "";
      return rows + note;
    }
    if (p.kind === "area") {
      var arows = (p.evidence || []).map(function (m) { return ui.areaRow(m, cls); }).join("");
      var an = p.moving < 0 ? '<div class="tko-note">Several items slipping since last wave.</div>' : "";
      return arows + an;
    }
    // movement
    var spark = ui.movementSpark(p.waves);
    var mv = spark
      ? '<div class="tko-mspark">' + spark + "</div>"
      : '<div class="tko-note">' + (p.diff >= 0 ? "Up " : "Down ") + Math.abs(p.diff).toFixed(1) + ".</div>";
    return mv + (p.driver ? '<div class="tko-note">Led by ' + fmt.escapeHtml(p.driver) + ".</div>" : "");
  }

  /** Deep-link target per pattern kind. */
  function footHtml(p) {
    var map = { group: ["findings", "see the breakouts →"], weak: ["dashboard", "see the questions →"],
      strong: ["dashboard", "see the questions →"], moved: ["moved", "see tracking →"] };
    var go = map[p.id] || ["dashboard", "see detail →"];
    return '<div class="tko-pfoot"><button class="linklike" data-goto="' + go[0] + '">' +
      go[1] + "</button></div>";
  }

  /** One pattern as an editable card. */
  function cardHtml(p) {
    var meta = ui.patternMeta(p.id);
    var take = takeout.state.getText(p.id, "takeaway", ui.patternSeed(p));
    return '<article class="tko-pcard tko-edge-' + meta.cls + '">' +
      '<div class="tko-ptag tko-on-' + meta.cls + '">' + fmt.escapeHtml(meta.tag) + "</div>" +
      headHtml(p) +
      ui.editable(p.id, "takeaway", take, "tko-take", "Takeaway — editable") +
      bodyHtml(p, meta.cls) + footHtml(p) + "</article>";
  }

  /** Provenance line — the glass-box audit trail. */
  function provHtml(t) {
    return '<div class="tko-prov" role="note">Built from grouped questions and breakouts the ' +
      "report already computes · no AI · " + t.standoutCount + " differences and " +
      t.themeCount + " tagged areas considered · curated by the researcher.</div>";
  }

  read.html = function (t) {
    var cards = (t.patterns || []).map(cardHtml).join("");
    var body = cards ||
      '<div class="tko-empty">No clear cross-question pattern stands out on this study — ' +
      "and that, honestly, is the headline.</div>";
    return apexHtml(t) + '<div class="tko-pgrid">' + body + "</div>" + provHtml(t);
  };

})(typeof window !== "undefined" ? window : globalThis);
