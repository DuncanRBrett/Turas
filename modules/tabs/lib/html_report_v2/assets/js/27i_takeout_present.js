/**
 * Executive Takeout — Present view (Patterns). The same patterns object as a
 * full-screen sequence: a cover with the headline indices, one screen per
 * pattern (group / weakest area / strongest area / what moved), and an honest
 * fine-print card. Takeaways stay inline-editable.
 *
 * Pure HTML builder; the controller (27k) wires editing and links.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var fmt = TR.fmt, ui = takeout.ui;
  var present = takeout.presentView = {};

  function kicker(idx, total, text) {
    var n = function (v) { return (v < 10 ? "0" : "") + v; };
    return '<div class="tko-slide-kicker">' + n(idx) + " / " + n(total) + " · " +
      fmt.escapeHtml(text) + "</div>";
  }

  function coverCard(t, total) {
    var project = (TR.AGG && TR.AGG.project && TR.AGG.project.name) || "This study";
    var answer = takeout.state.getApex(ui.answerSeed(t.patterns));
    var kpis = (t.answer.metrics || []).slice(0, 3).map(function (m) {
      return '<div class="tko-cover-kpi"><div class="tko-hero">' + ui.fmtVal(true, m.value) +
        '</div><div class="tko-cover-lab">' + fmt.escapeHtml(m.label || m.title) + " " +
        ui.topBox(m) + "</div></div>";
    }).join("");
    return '<section class="tko-slide tko-slide-cover">' + kicker(1, total, "the big picture") +
      ui.editable("__apex__", "answer", answer, "tko-claim tko-claim-lg", "The one-line answer — editable") +
      '<div class="tko-cover-nums">' + kpis + "</div>" +
      '<div class="tko-cover-foot">' + fmt.escapeHtml(project) + "</div></section>";
  }

  function evidence(p, cls) {
    if (p.kind === "group") return (p.evidence || []).map(function (e) { return ui.groupRow(e, cls); }).join("");
    if (p.kind === "area") return (p.evidence || []).map(function (m) { return ui.areaRow(m, cls); }).join("");
    return ui.movementSpark(p.waves);
  }

  function patternSlide(p, idx, total) {
    var meta = ui.patternMeta(p.id);
    var take = takeout.state.getText(p.id, "takeaway", ui.patternSeed(p));
    var sub = p.kind === "area"
      ? fmt.escapeHtml(p.subject) + ' <span class="tko-pscore">· ' + Number(p.avg).toFixed(1) + "</span>"
      : fmt.escapeHtml(p.subject);
    return '<section class="tko-slide tko-slide-finding tko-edge-' + meta.cls + '">' +
      kicker(idx, total, meta.tag) +
      '<div class="tko-slide-sub">' + sub + (p.kind === "group" ? " " + ui.bannerChip(p.group) : "") + "</div>" +
      ui.editable(p.id, "takeaway", take, "tko-claim tko-claim-lg", "Takeaway — editable") +
      '<div class="tko-slide-visual">' + evidence(p, meta.cls) + "</div>" +
      (p.kind === "movement" && p.driver ? '<div class="tko-note">Led by ' + fmt.escapeHtml(p.driver) + ".</div>" : "") +
      "</section>";
  }

  function finePrint(t, total) {
    return '<section class="tko-slide tko-slide-fine">' + kicker(total, total, "how sure we are") +
      ui.reliabilityRibbon(t.reliability) +
      '<div class="tko-prov" role="note">Built from grouped questions and breakouts the report ' +
      "already computes · no AI · curated by the researcher.</div></section>";
  }

  present.html = function (t) {
    var ps = t.patterns || [];
    var total = ps.length + 2;
    var slides = [coverCard(t, total)];
    ps.forEach(function (p, i) { slides.push(patternSlide(p, i + 2, total)); });
    slides.push(finePrint(t, total));
    return '<div class="tko-deck">' + slides.join("") + "</div>";
  };

})(typeof window !== "undefined" ? window : globalThis);
