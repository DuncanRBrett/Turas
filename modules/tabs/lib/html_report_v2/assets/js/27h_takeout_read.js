/**
 * Pattern recognition — Read view. One editable big-picture answer, the headline
 * indices, then the cross-question patterns: the group under strain, which split
 * matters most, the weakest and strongest areas, and what moved. Each takeaway is
 * editable so the message lands in the client's language.
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
    var seed = ui.answerSeed(t.patterns);
    var answer = takeout.state.getApex(seed);
    var kpis = (t.answer.metrics || []).slice(0, 3).map(function (m) {
      return '<div class="tko-kpi"><div class="tko-kpi-label">' + fmt.escapeHtml(m.label || m.title) +
        '</div><div class="tko-kpi-val">' + ui.fmtVal(true, m.value) + ui.topBox(m) +
        '</div><div class="tko-kpi-foot"><span class="tko-kpi-band tko-band-' + (m.band || "na") +
        '">' + fmt.escapeHtml(m.band || "—") + "</span>" + ui.apexTrend(m) + "</div></div>";
    }).join("");
    return '<div class="tko-apex"><div class="tko-kicker">Pattern recognition · ' +
      fmt.escapeHtml(project) + '</div><div class="tko-apex-main"><div class="tko-apex-answer">' +
      '<div class="tko-eyebrow">The big picture</div>' +
      ui.editable("__apex__", "answer", answer, "tko-answer", "The one-line answer — editable", seed) +
      "</div>" + (kpis ? '<div class="tko-apex-metrics">' + kpis + "</div>" : "") + "</div>" +
      ui.reliabilityRibbon(t.reliability) + "</div>";
  }

  /** Heading line for a pattern card (subject + context). */
  function headHtml(p) {
    if (p.kind === "portrait") {
      return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) + "</div>" + ui.bannerChip(p.group);
    }
    if (p.kind === "area") {
      // No synthetic cross-question average in the heading — the member rows below
      // carry the real numbers (the "where does 40.8 come from?" fix).
      return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) + "</div>";
    }
    if (p.kind === "group") {
      return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) + "</div>" + ui.bannerChip(p.group);
    }
    if (p.kind === "comove") {
      return '<div class="tko-ph">' + p.bundleCount + (p.bundleCount === 1 ? " set" : " sets") +
        " of co-moving questions</div>";
    }
    if (p.kind === "odd") {
      return '<div class="tko-ph">' + fmt.escapeHtml(p.column) + "</div>" + ui.bannerChip(p.group);
    }
    if (p.kind === "bimodal") {
      return '<div class="tko-ph">' + p.flaggedCount + (p.flaggedCount === 1 ? " question" : " questions") +
        " split into two camps</div>";
    }
    return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) + "</div>";
  }

  /** Evidence + note for a pattern card. */
  function bodyHtml(p, cls) {
    if (p.kind === "portrait") {
      // Balanced by construction: where the group lags AND where it leads, equal
      // billing. One side may be empty (a uniformly strong/weak group).
      var lo = (p.lows || []).map(function (e) { return ui.portraitRow(e, "low"); }).join("");
      var hi = (p.highs || []).map(function (e) { return ui.portraitRow(e, "high"); }).join("");
      var blocks = "";
      if (lo) blocks += '<div class="tko-side"><div class="tko-sidehd tko-sidehd-low">Where it lags</div>' + lo + "</div>";
      if (hi) blocks += '<div class="tko-side"><div class="tko-sidehd tko-sidehd-high">Where it leads</div>' + hi + "</div>";
      return '<div class="tko-portrait">' + blocks + "</div>";
    }
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
    if (p.kind === "split") {
      // Navigation pointer only — no synthetic average-index rows (the "4.4 / 3.7
      // that's nowhere else" fix). Names the cut; the portraits carry the detail.
      return '<div class="tko-note">The widest, most consistent differences run by ' +
        fmt.escapeHtml(p.subject) +
        (p.sigGaps ? " — " + p.sigGaps + " group" + (p.sigGaps === 1 ? "" : "s") +
          " stand clearly apart" : "") + ". Start here, then read the rest through it.</div>";
    }
    if (p.kind === "comove") {
      var bundles = (p.bundles || []).map(function (b, i) { return ui.comoveBundle(b, p.floor, i); }).join("");
      return bundles +
        '<div class="tko-note">Scanned ' + p.pairCount + " question pairs · controlled for the " +
        "survey-wide tendency to agree · only sets that cohere beyond that baseline survive.</div>";
    }
    if (p.kind === "odd") {
      var rows = ui.oddRow(p.flip) + (p.secondary || []).map(function (s) { return ui.oddRow(s); }).join("");
      return rows + '<div class="tko-cap">Out of ' + p.familyCells + " group × question cells, this one " +
        "opposes the group’s own direction and survives multiplicity correction.</div>";
    }
    if (p.kind === "bimodal") {
      var qrows = (p.questions || []).map(function (q) { return ui.bimodalRow(q); }).join("");
      return qrows + '<div class="tko-note">The average sits mid-scale, but the answers pile up at both ' +
        "ends — read the split, not the mean.</div>";
    }
    // movement
    if (p.stable) return '<div class="tko-note">No metric shifted materially since the last wave.</div>';
    var rows = (p.down ? ui.moverRow(p.down, "down") : "") + (p.up ? ui.moverRow(p.up, "up") : "");
    var spark = ui.movementSpark(p.waves);
    return rows + (spark ? '<div class="tko-mspark">' + spark + "</div>" : "");
  }

  /** Deep-link target per pattern kind. */
  function footHtml(p) {
    var map = { group: ["findings", "see the breakouts →"], split: ["findings", "see the breakdown →"],
      comove: ["crosstabs", "see the questions →"], odd: ["findings", "see the breakouts →"],
      bimodal: ["crosstabs", "see the distributions →"],
      weak: ["dashboard", "see the questions →"], strong: ["dashboard", "see the questions →"],
      moved: ["moved", "see tracking →"] };
    var go = (p.kind === "portrait" ? ["findings", "see the breakouts →"] : map[p.id]) ||
      ["dashboard", "see detail →"];
    return '<div class="tko-pfoot"><button class="linklike" data-goto="' + go[0] + '">' +
      go[1] + "</button></div>";
  }

  /** Caption under a confident-null card — the working that shows it was a real
   *  test, not a pattern that simply wasn't computed. */
  function nullCaption(p) {
    if (p.id === "odd") {
      return '<div class="tko-cap">Scanned ' + p.familyCells + " group × question cells · an exception " +
        "must oppose the group’s own direction, clear a real gap, and survive multiplicity correction · 0 survive.</div>";
    }
    return '<div class="tko-cap">Scanned ' + p.scanned + " questions for a two-camp split (peaks at both " +
      "ends, a calm average, real mass in each camp) · none found — not mere spread or skew.</div>";
  }

  /** One pattern as an editable card. The takeaway is keyed by id + subject so a
   *  saved edit can never resurface under a different subject after a re-run.
   *  A confident-null pattern renders a compact, non-editable "we checked, nothing
   *  real" card — the visible proof of the never-cry-wolf discipline. */
  function cardHtml(p) {
    var meta = ui.patternMeta(p.id);
    if (p.nullResult) {
      return '<article class="tko-pcard tko-null tko-edge-' + meta.cls + '">' +
        '<div class="tko-ptag tko-on-' + meta.cls + '">' + fmt.escapeHtml(meta.tag) + "</div>" +
        '<div class="tko-take tko-take-null">' + fmt.escapeHtml(ui.patternSeed(p)) + "</div>" +
        nullCaption(p) + "</article>";
    }
    var seed = ui.patternSeed(p);
    var key = p.id + "|" + (p.subject || "");
    var take = takeout.state.getText(key, "takeaway", seed);
    var pin = '<button class="snap-pin" data-snap-pin data-snap-source="patterns" ' +
      'data-snap-title="' + fmt.escapeHtml(TR.charts.clip(seed, 90)) + '" ' +
      'data-snap-context="' + fmt.escapeHtml("Pattern · " + meta.tag) +
      '" title="Pin this card to the story" aria-label="Pin card to story">📌</button>';
    return '<article class="tko-pcard tko-edge-' + meta.cls + '" data-snap-card>' +
      '<div class="tko-ptag tko-on-' + meta.cls + '">' + fmt.escapeHtml(meta.tag) + "</div>" +
      pin + headHtml(p) +
      ui.editable(key, "takeaway", take, "tko-take", "Takeaway — editable", seed) +
      bodyHtml(p, meta.cls) + footHtml(p) + "</article>";
  }

  /** Provenance line — the glass-box audit trail. When the FDR family is present
   *  it states the multiplicity correction: how many cells were scanned and how
   *  many single-cell differences survive it (the rest being consistency, not
   *  individual cells), or the confident null when nothing stands alone. */
  function provHtml(t) {
    var base = "Built from grouped questions and breakouts the report already computes · no AI · " +
      t.segmentCount + " breakout groups and " + t.themeCount + " tagged areas considered";
    if (t.fdr) {
      var f = t.fdr, scan = "scanned " + f.groupCount + " groups × " + f.questionCount +
        " questions = " + f.K + " cells · corrected for multiplicity (" + f.method + ")";
      base = "no AI · " + scan;
    }
    // Rigor footer: the demoted never-cry-wolf checks (odd-one-out + hidden
    // disagreement) report as one honest line instead of empty cards.
    var rg = t.rigor || {}, checks = [];
    if (rg.odd) checks.push("every group for a true exception");
    if (rg.bimodal) checks.push("every question for a hidden two-camp split");
    if (checks.length) {
      var found = (rg.odd && rg.odd.found) || (rg.bimodal && rg.bimodal.found);
      base += " · also checked " + checks.join(" and ") +
        (found ? " — flagged on the cards above" : " — nothing held up beyond chance");
    }
    return '<div class="tko-prov" role="note">' + fmt.escapeHtml(base) + " · curated by the researcher.</div>";
  }

  read.html = function (t) {
    var cards = (t.patterns || []).map(cardHtml).join("");
    var body = cards ||
      '<div class="tko-empty">No clear cross-question pattern stands out on this study — ' +
      "and that, honestly, is the headline.</div>";
    return apexHtml(t) + '<div class="tko-pgrid">' + body + "</div>" + provHtml(t);
  };

})(typeof window !== "undefined" ? window : globalThis);
