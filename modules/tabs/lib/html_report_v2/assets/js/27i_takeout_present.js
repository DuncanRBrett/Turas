/**
 * Executive Takeout — Present view. The same takeout object as a Wrapped-style
 * sequence: a cover, one full-screen card per promoted finding (in posture
 * reading order), and an honest fine-print card. One big idea per screen, the
 * hero number as the art. Headlines and "so whats" stay inline-editable.
 *
 * Pure HTML builder; the controller (27k) wires editing and deep-links.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var fmt = TR.fmt, ui = takeout.ui;
  var present = takeout.presentView = {};

  function postureMeta(id) {
    var hit = (takeout.POSTURES || []).filter(function (p) { return p.id === id; })[0];
    return hit || { id: id, label: id, verb: "" };
  }

  /** "02 / 07 · Act now" slide kicker. */
  function kicker(idx, total, text) {
    var n = function (v) { return (v < 10 ? "0" : "") + v; };
    return '<div class="tko-slide-kicker">' + n(idx) + " / " + n(total) + " · " +
      fmt.escapeHtml(text) + "</div>";
  }

  /** Cover — the two composite indices in one breath. */
  function coverCard(t, total) {
    var project = (TR.AGG && TR.AGG.project && TR.AGG.project.name) || "This study";
    var nums = (t.answer.metrics || []).slice(0, 3).map(function (c) {
      return '<div class="tko-cover-kpi"><div class="tko-hero">' + Number(c.value).toFixed(1) +
        '</div><div class="tko-cover-lab">' + fmt.escapeHtml(c.label || c.title) + " · " +
        '<span class="tko-band-' + (c.band || "na") + '">' + fmt.escapeHtml(c.band || "—") +
        "</span></div></div>";
    }).join("");
    var rel = t.reliability || {};
    return '<section class="tko-slide tko-slide-cover">' + kicker(1, total, "this study, in one breath") +
      '<div class="tko-cover-nums">' + (nums || '<div class="tko-hero">—</div>') + "</div>" +
      '<div class="tko-cover-foot">' + fmt.escapeHtml(project) +
      (rel.n ? " · " + (rel.census ? "census" : "sample") + " of " + fmt.base(rel.n) : "") +
      "</div></section>";
  }

  /** A two-bar (standout) or a single scale gauge (level) per card. */
  function visual(f) {
    return f.kind === "level" ? ui.gaugeBar(f) : ui.twoBar(f);
  }

  /** One finding as a full-screen slide. */
  function findingCard(f, idx, total, lowThreshold) {
    var meta = postureMeta(f.posture);
    var claim = takeout.state.getText(f.id, "claim", ui.seedClaim(f));
    var soWhat = takeout.state.getText(f.id, "soWhat", ui.seedSoWhat(f));
    return '<section class="tko-slide tko-slide-finding tko-edge-' + f.posture + '">' +
      kicker(idx, total, meta.label) +
      '<div class="tko-slide-pill tko-on-' + f.posture + '">' + ui.glyph(f.posture) +
      "<span>" + fmt.escapeHtml(meta.label) + "</span></div>" +
      '<div class="tko-slide-hero">' + ui.fmtVal(f, f.value) + "</div>" +
      ui.editable(f.id, "claim", claim, "tko-claim tko-claim-lg", "Finding headline — editable") +
      ui.questionLine(f) +
      '<div class="tko-slide-visual">' + visual(f) + "</div>" +
      ui.editable(f.id, "soWhat", soWhat, "tko-sowhat tko-sowhat-lg", "Implication — editable") +
      '<div class="tko-slide-foot">' + ui.baseChip(f, lowThreshold) + ui.softTag(f) +
      ui.deltaChip(f) +
      '<button class="linklike" data-goq="' + fmt.escapeHtml(f.code) + '">see the table →</button>' +
      "</div></section>";
  }

  /** The closing honesty card. */
  function finePrintCard(t, total) {
    return '<section class="tko-slide tko-slide-fine">' + kicker(total, total, "how sure we are") +
      ui.reliabilityRibbon(t.reliability) +
      '<div class="tko-prov" role="note">Auto-selected by the Takeout engine from ' +
      t.candidateCount + " candidate findings · " + t.promotedCount +
      " promoted · curated by the researcher.</div></section>";
  }

  /** Build the full Present sequence for a takeout object. */
  present.html = function (t, opts) {
    opts = opts || {};
    var items = [];
    t.postures.forEach(function (p) {
      p.items.forEach(function (f) { items.push(f); });
    });
    var total = items.length + 2;   // cover + findings + fine print
    var slides = [coverCard(t, total)];
    items.forEach(function (f, i) {
      slides.push(findingCard(f, i + 2, total, opts.lowThreshold));
    });
    slides.push(finePrintCard(t, total));
    return '<div class="tko-deck">' + slides.join("") + "</div>";
  };

})(typeof window !== "undefined" ? window : globalThis);
