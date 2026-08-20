/**
 * Pattern recognition — Read view. One editable big-picture answer, the headline
 * indices, then the cross-question patterns: one card per breakout group, the
 * weakest and strongest areas, and what moved. Each takeaway is editable so the
 * message lands in the client's language.
 *
 * Pure HTML builder: takes the patterns object, returns a string. The controller
 * (27k) injects it and wires editing and the "how sure" panel.
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
    return '<div class="tko-apex"><div class="tko-kicker">Group overview · ' +
      fmt.escapeHtml(project) + '</div><div class="tko-apex-main"><div class="tko-apex-answer">' +
      '<div class="tko-eyebrow">Key finding</div>' +
      ui.editable("__apex__", "answer", answer, "tko-answer", "The one-line answer — editable", seed) +
      "</div>" + (kpis ? '<div class="tko-apex-metrics">' + kpis + "</div>" : "") + "</div></div>";
  }

  /** Heading line for a pattern card (subject + context). */
  function headHtml(p) {
    if (p.kind === "portrait" || p.kind === "steady") {
      return '<div class="tko-ph">' + fmt.escapeHtml(p.subject) + "</div>" + ui.bannerChip(p.group);
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
    if (p.kind === "portrait" || p.kind === "steady") {
      // Where it stands, and nothing else. The lags/leads bars used to sit here:
      // engine-picked extremes, a handful out of thirty, that read as though they
      // were the story. The counts say how the group falls across everything it
      // was scored on; the named example belongs in the editable sentence, in the
      // analyst's words rather than the engine's.
      // A steady group gets the SAME card — it is read beside the ones with a
      // lean, so it has to be comparable at a glance, and its flatness is already
      // visible in the counts without quoting the sign test at the reader.
      return ui.synopsis(p);
    }
    if (p.kind === "group") {
      var rows = (p.evidence || []).map(function (e) { return ui.groupRow(e, cls); }).join("");
      var note = p.secondary
        ? TR.txt.block("patterns.group.most_positive", { subject: p.secondary },
                       { tag: "div", cls: "tko-note" }) : "";
      return rows + note;
    }
    if (p.kind === "split") {
      // Navigation pointer only — no synthetic average-index rows (the "4.4 / 3.7
      // that's nowhere else" fix). Names the cut; the portraits carry the detail.
      return TR.txt.block("patterns.split.note", {
        subject: p.subject,
        gaps_clause: { html: p.sigGaps
          ? TR.txt("patterns.split.gaps_clause",
                   { n: p.sigGaps, groups_word: p.sigGaps === 1 ? "group" : "groups" })
          : "" }
      }, { tag: "div", cls: "tko-note" });
    }
    if (p.kind === "comove") {
      var bundles = (p.bundles || []).map(function (b, i) { return ui.comoveBundle(b, p.floor, i); }).join("");
      return bundles + TR.txt.block("patterns.comove.note", { pairs: p.pairCount },
                                    { tag: "div", cls: "tko-note" });
    }
    if (p.kind === "odd") {
      var rows = ui.oddRow(p.flip) + (p.secondary || []).map(function (s) { return ui.oddRow(s); }).join("");
      return rows + TR.txt.block("patterns.odd.caption", { cells: p.familyCells },
                                 { tag: "div", cls: "tko-cap" });
    }
    if (p.kind === "bimodal") {
      var qrows = (p.questions || []).map(function (q) { return ui.bimodalRow(q); }).join("");
      return qrows + TR.txt.block("patterns.bimodal.note", null,
                                  { tag: "div", cls: "tko-note" });
    }
    // movement
    if (p.stable) return TR.txt.block("patterns.movement.stable", null,
                                      { tag: "div", cls: "tko-note" });
    var rows = (p.down ? ui.moverRow(p.down, "down") : "") + (p.up ? ui.moverRow(p.up, "up") : "");
    var spark = ui.movementSpark(p.waves);
    return rows + (spark ? '<div class="tko-mspark">' + spark + "</div>" : "");
  }

  /** Caption under a confident-null card — the working that shows it was a real
   *  test, not a pattern that simply wasn't computed. */
  function nullCaption(p) {
    if (p.id === "odd") {
      return TR.txt.block("patterns.null.odd", { cells: p.familyCells },
                          { tag: "div", cls: "tko-cap" });
    }
    return TR.txt.block("patterns.null.bimodal", { scanned: p.scanned },
                        { tag: "div", cls: "tko-cap" });
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
      bodyHtml(p, meta.cls) + "</article>";
  }

  /** Provenance line — how wide the scan was, and nothing else.
   *
   *  It used to carry the whole audit trail on the reader's face: no-AI, the
   *  multiplicity method, and a sentence naming each never-cry-wolf check and
   *  its outcome. That is the working, not the finding, and it crowded the one
   *  fact a reader needs to size the scan. The checks and the correction are
   *  unchanged — a confident-null card still shows its own working, and the FDR
   *  correction still gates what appears here at all. Only the line is shorter.
   *
   *  A hit from the demoted checks (odd-one-out, hidden two-camp split) is still
   *  stated inline, because those checks deliberately have no card of their own,
   *  and a finding no reader is told about may as well not have been made. */
  function provHtml(t) {
    var base;
    if (t.fdr) {
      var f = t.fdr;
      base = "Scanned " + f.groupCount + " groups × " + f.questionCount +
        " questions = " + f.K + " cells";
    } else {
      base = t.segmentCount + " breakout groups and " + t.themeCount +
        " tagged areas considered";
    }
    var rg = t.rigor || {}, found = [];
    if (rg.odd && rg.odd.found) found.push(rg.odd.note ||
      "one group breaks its own pattern on a single question");
    if (rg.bimodal && rg.bimodal.found) found.push(rg.bimodal.note ||
      "at least one question splits into two camps behind a calm average");
    if (found.length) base += " · also found: " + found.join("; ");
    return '<div class="tko-prov" role="note">' + fmt.escapeHtml(base) + "</div>";
  }

  /** The honest empty state. "Nothing stands out" is a FINDING — it may only be
   *  claimed when something was actually scanned. A study with nothing the
   *  engine can score is told what the scan reads instead; one with questions
   *  but no comparable groups is told that. */
  function emptyHtml(t) {
    var s = t.scope;
    var empty = function (key) {
      return TR.txt.block(key, null, { tag: "div", cls: "tko-empty" });
    };
    if (s && (s.rated + s.shares) === 0) return empty("patterns.empty.nothing_scorable");
    if (!t.segmentCount) return empty("patterns.empty.no_groups");
    return empty("patterns.empty.no_pattern");
  }

  /** The groups a portrayed banner scanned that produced NO portrait — stated
   *  on the page so "where is the 4th centre?" has its answer: middling on
   *  everything is itself a reading, not an omission. */
  function noStoryHtml(t) {
    var list = t.noStory || [];
    if (!list.length) return "";
    var names = list.map(function (g) {
      return g.subject + " (n = " + fmt.base(g.base) + ")";
    }).join(", ");
    // Neutral wording: this list now also carries groups whose gaps did not
    // hold up as a consistent story (incl. polarized ones the steady card
    // refuses to claim) — "close to the overall" would overclaim for them.
    return TR.txt.block("patterns.no_story",
      { names: names, it_them: list.length === 1 ? "it" : "them" },
      { tag: "div", cls: "tko-cap tko-nostory" });
  }

  read.html = function (t) {
    var cards = (t.patterns || []).map(cardHtml).join("");
    if (cards) cards += noStoryHtml(t);
    var body = cards || emptyHtml(t);
    // Footer order: the reliability line (with the "how sure" entry point) sits
    // directly above the provenance line — demoted from the apex, not deleted.
    return apexHtml(t) + '<div class="tko-pgrid">' + body + "</div>" +
      ui.reliabilityRibbon(t.reliability) + provHtml(t);
  };

})(typeof window !== "undefined" ? window : globalThis);
