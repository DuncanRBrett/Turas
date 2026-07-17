/**
 * Pattern recognition — shared render atoms for the Read view, so a row, a chip
 * or an editable line is defined once. All user-editable text is stored raw and
 * ESCAPED HERE on render (fmt.escapeHtml) — user content is never written as raw
 * HTML.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var fmt = TR.fmt;
  var ui = takeout.ui = {};

  /* Pattern presentation: tag label + colour class, per pattern kind. Colour is
     always paired with the tag text, so it is never the sole signal. */
  var PATTERN_META = {
    group: { tag: "The group under strain", cls: "strain" },
    split: { tag: "Which split matters most", cls: "split" },
    comove: { tag: "Questions that move together", cls: "comove" },
    odd: { tag: "The odd one out", cls: "odd" },
    bimodal: { tag: "Hidden disagreement", cls: "bimodal" },
    weak: { tag: "Weakest area", cls: "weak" },
    strong: { tag: "Strongest area", cls: "strong" },
    moved: { tag: "What moved", cls: "moved" }
  };
  ui.patternMeta = function (id) {
    // Portraits carry a per-group id ("portrait:Campus::Cape Town"); they share one
    // neutral tag — the lean shows in the card's balanced lows/highs, not the tag,
    // so the tab no longer leads negative.
    if (typeof id === "string" && id.indexOf("portrait:") === 0) {
      return { tag: "In focus", cls: "focus" };
    }
    return PATTERN_META[id] || { tag: "", cls: "" };
  };

  /** A value in its own units: "3.9" for a mean/index, "69%" for a proportion. */
  ui.fmtVal = function (isMean, v, decimals) {
    if (v === null || v === undefined) return "–";
    return isMean ? Number(v).toFixed(decimals || 1) : Math.round(v) + "%";
  };

  /** One member row inside an AREA card: the question label on its own line (full,
   *  always wraps — never truncated), then a scale bar + value beneath, plus a
   *  move chip when it shifted. cls colours the bar by pattern kind. */
  ui.areaRow = function (m, cls) {
    var pct = m.scaleMax ? Math.min(100, Math.max(0, m.value / m.scaleMax * 100)) : 0;
    var tag = m.summary ? ' <span class="tko-peer">overall</span>' : "";
    return '<div class="tko-row"><div class="tko-rl">' + fmt.escapeHtml(m.label) + tag + "</div>" +
      '<div class="tko-rmeter"><span class="tko-track"><span class="tko-fill tko-' + cls +
      '" style="width:' + pct.toFixed(1) + '%"></span></span>' +
      '<span class="tko-rv">' + Number(m.value).toFixed(1) + ui.moveChip(m.delta) + "</span></div></div>";
  };

  /** One row inside the GROUP card: the question label on its own line (full,
   *  always wraps), then the column's standing vs the rest beneath — its bar in
   *  the pattern colour, the rest shown faintly in the value. */
  ui.groupRow = function (e, cls) {
    var max = e.isMean ? (e.scaleMax || 5) : 100;
    var baseline = (e.rest === null || e.rest === undefined) ? e.overall : e.rest;
    var w = Math.min(100, Math.max(0, (e.value || 0) / max * 100)).toFixed(1);
    return '<div class="tko-row"><div class="tko-rl">' + fmt.escapeHtml(e.label) +
      ui.survivesChip(e.survives) + "</div>" +
      '<div class="tko-rmeter"><span class="tko-track"><span class="tko-fill tko-' + cls +
      '" style="width:' + w + '%"></span></span><span class="tko-rv">' +
      ui.fmtVal(e.isMean, e.value, e.decimals) +
      '<span class="tko-rest"> / ' + ui.fmtVal(e.isMean, baseline, e.decimals) + "</span></span></div></div>";
  };

  /** Capitalise the first letter (for a stitched-together sentence). */
  function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

  /** One row inside a PORTRAIT card — a low or a high. Question label on its own
   *  line (full, always wraps), then the group's value vs the overall beneath, the
   *  bar coloured by direction (strain = below, strong = above). A peer note marks
   *  where the group is the highest / lowest of its banner siblings ("highest of 3
   *  campuses"). Both value and baseline are real cells — no synthetic aggregate. */
  /** A portrait cell in its own units: "62%" for a KeyShare row, "4.2" for an
   *  index — the same real-cell values the crosstab shows. */
  function portraitCell(row, v) {
    return row.isPct ? Math.round(v) + "%" : Number(v).toFixed(1);
  }

  ui.portraitRow = function (e, dir) {
    var max = e.scaleMax || 5;
    var w = Math.min(100, Math.max(0, (e.value || 0) / max * 100)).toFixed(1);
    var peer = "";
    if (dir === "high" && e.peerTop && e.peerCount > 1) {
      peer = ' <span class="tko-peer">highest of ' + e.peerCount + "</span>";
    } else if (dir === "low" && e.peerBottom && e.peerCount > 1) {
      peer = ' <span class="tko-peer">lowest of ' + e.peerCount + "</span>";
    }
    return '<div class="tko-row"><div class="tko-rl">' + fmt.escapeHtml(e.label) + peer + "</div>" +
      '<div class="tko-rmeter"><span class="tko-track"><span class="tko-fill tko-' +
      (dir === "high" ? "strong" : "strain") + '" style="width:' + w + '%"></span></span>' +
      '<span class="tko-rv">' + portraitCell(e, e.value) +
      '<span class="tko-rest"> / ' + portraitCell(e, e.rest) + "</span></span></div></div>";
  };

  /** The editable takeaway seed for a portrait — the tension in one sentence:
   *  the group's lean and, against it, its sharpest counter-spike (or its dip when
   *  thriving). Quotes the real question; cites the two real cells. */
  ui.portraitTension = function (p) {
    var strained = p.lean === "strained";
    var hi = p.highs && p.highs[0], lo = p.lows && p.lows[0];
    var majCount = strained ? p.hits : p.gains;
    // "questions scored" = the scan's actual reach (rated indexes + declared
    // key shares), so the count never reads as the whole questionnaire.
    var lead = p.subject + (strained ? " is under strain — below the overall on "
      : " is the strong group — above the overall on ") + majCount + " of the " + p.total +
      " questions scored";
    if (strained && hi) {
      // An index counter-spike reads as a rating; a KeyShare one as a lead on
      // the share. Both quote the two real cells.
      if (hi.isPct) {
        return lead + " — yet " +
          (hi.peerTop && hi.peerCount > 1 ? "leads every " + p.group.toLowerCase() + " on “"
            : "leads on “") + hi.label + "” (" + portraitCell(hi, hi.value) + " vs " +
          portraitCell(hi, hi.rest) + " overall).";
      }
      return lead + " — yet rates “" + hi.label + "” highest" +
        (hi.peerTop && hi.peerCount > 1 ? " of any " + p.group.toLowerCase() : "") +
        " (" + portraitCell(hi, hi.value) + " vs " + portraitCell(hi, hi.rest) +
        " overall).";
    }
    if (!strained && lo) {
      return lead + " — yet dips on “" + lo.label + "” (" + portraitCell(lo, lo.value) +
        " vs " + portraitCell(lo, lo.rest) + " overall). The one to watch.";
    }
    return lead + (strained && lo ? ", most on “" + lo.label + "”." : ".");
  };

  /** A "survives correction" chip on an evidence row whose single-cell difference
   *  clears multiple-comparison correction (text + colour, never colour alone). */
  ui.survivesChip = function (on) {
    return on ? ' <span class="tko-badge tko-survives" title="This single cell survives ' +
      'Benjamini-Hochberg multiple-comparison correction across the whole grid">survives correction</span>' : "";
  };

  /** A small ▲/▼ move chip for a member that shifted significantly, else "". */
  ui.moveChip = function (delta) {
    if (!delta || !delta.sig) return "";
    var up = delta.diff >= 0;
    return '<span class="tko-move ' + (up ? "up" : "down") + '">' +
      (up ? " ▲" : " ▼") + Math.abs(delta.diff).toFixed(1) + "</span>";
  };

  /** One co-movement bundle: the anchor pair, the cohesion vs the survey floor,
   *  then every member question in full (labels always wrap, never clipped). */
  ui.comoveBundle = function (bundle, floor, idx) {
    var heading = '<div class="tko-bundle-head"><span class="tko-bundle-n">' + (idx + 1) +
      '</span><span class="tko-bundle-anchor">' + fmt.escapeHtml(bundle.anchor.a) +
      ' <span class="tko-bundle-tie">↔</span> ' + fmt.escapeHtml(bundle.anchor.b) +
      '</span><span class="tko-bundle-size">' + bundle.size + " move together</span></div>";
    var cohesion = '<div class="tko-cap">Average correlation ' + bundle.meanRaw.toFixed(2) +
      " — above the survey's " + floor.toFixed(2) + " baseline (they cohere beyond the " +
      "general tendency to agree).</div>";
    var members = '<ul class="tko-bundle-list">' + bundle.members.map(function (m) {
      return "<li>" + fmt.escapeHtml(m.title) + "</li>";
    }).join("") + "</ul>";
    return '<div class="tko-bundle">' + heading + members + cohesion + "</div>";
  };

  /** The exception row for the odd-one-out: the question, the group's value vs the
   *  overall, and how far it breaks the group's own usual gap. */
  ui.oddRow = function (f) {
    var max = f.scaleMax || 5, w = Math.min(100, Math.max(0, (f.value || 0) / max * 100)).toFixed(1);
    return '<div class="tko-row"><div class="tko-rl">' + fmt.escapeHtml(f.qtitle) +
      ' <span class="tko-badge tko-survives">survives correction</span></div>' +
      '<div class="tko-rmeter"><span class="tko-track"><span class="tko-fill tko-odd" style="width:' +
      w + '%"></span></span><span class="tko-rv">' + Number(f.value).toFixed(1) +
      '<span class="tko-rest"> / ' + Number(f.total).toFixed(1) + "</span></span></div></div>";
  };

  /** A two-camp distribution bar (low | middle | high) for hidden disagreement. */
  ui.bimodalRow = function (q) {
    var K = q.scaleMax, h = Math.floor(K / 2);
    var low = 0, mid = 0, high = 0;
    q.dist.forEach(function (pct, i) { if (i < h) low += pct; else if (i >= K - h) high += pct; else mid += pct; });
    var seg = function (cls, v) { return v > 0 ? '<span class="tko-seg tko-seg-' + cls +
      '" style="width:' + v + '%">' + (v >= 12 ? v + "%" : "") + "</span>" : ""; };
    return '<div class="tko-row"><div class="tko-rl">' + fmt.escapeHtml(q.title) + "</div>" +
      '<div class="tko-bimobar">' + seg("low", low) + seg("mid", mid) + seg("high", high) + "</div>" +
      '<div class="tko-cap">' + low + "% low · " + high + "% high · mean " + Number(q.mean).toFixed(1) +
      " (looks calm)</div></div>";
  };

  /** A two-sided mover line for the "what moved" card (▲ riser / ▼ faller). */
  ui.moverRow = function (m, dir) {
    return '<div class="tko-mrow tko-mv-' + dir + '">' + (dir === "up" ? "▲ " : "▼ ") +
      fmt.escapeHtml(m.subject) + " " + (m.diff >= 0 ? "+" : "−") + Math.abs(m.diff).toFixed(1) + "</div>";
  };

  /** Movement sparkline (bigger than the KPI one) for the "what moved" card. */
  ui.movementSpark = function (waves) {
    if (waves && TR.render && typeof TR.render.sparkline === "function") {
      try { return TR.render.sparkline(waves, false, { w: 300, h: 56 }); }
      catch (e) { /* no spark */ }
    }
    return "";
  };

  /** The "how many" companion to the index: the favourable top-box %, in its own
   *  words ("· 69% satisfied"). Empty when the metric carries no NET. */
  ui.topBox = function (m) {
    if (!m.topBox || m.topBox.pct === null || m.topBox.pct === undefined) return "";
    return '<span class="tko-tb">· ' + Math.round(m.topBox.pct) + "% " +
      fmt.escapeHtml(String(m.topBox.label || "").toLowerCase()) + "</span>";
  };

  /** Which banner cut the standout group came from (Campus / Department / …). */
  ui.bannerChip = function (group) {
    return group ? '<span class="tko-chip tko-bg">' + fmt.escapeHtml(group) + "</span>" : "";
  };

  /** Apex KPI wave change: a sparkline when history exists, else a ▲/▼ chip. */
  ui.apexTrend = function (m) {
    if (m.waves && TR.render && typeof TR.render.sparkline === "function") {
      try {
        return '<span class="tko-kpi-spark">' +
          TR.render.sparkline(m.waves, false, { w: 60, h: 20 }) + "</span>";
      } catch (e) { /* fall back to delta */ }
    }
    if (!m.delta || m.delta.diff === null || m.delta.diff === undefined) return "";
    var up = m.delta.diff >= 0;
    return '<span class="tko-kpi-delta ' + (up ? "up" : "down") + '">' +
      (up ? "▲" : "▼") + " " + Math.abs(m.delta.diff).toFixed(1) + "</span>";
  };

  /** Templated takeaway for a pattern (the one editable line per card). */
  ui.patternSeed = function (p) {
    if (p.kind === "portrait") return ui.portraitTension(p);
    if (p.id === "group") {
      return p.subject + " scores below the overall on " + p.hits + " of the " + p.total +
        " questions scored — the group most under strain.";
    }
    if (p.id === "split") {
      // Navigation pointer — no synthetic average. (sigGaps = directionally-
      // consistent groups under this cut, when the FDR family is present.)
      return "Differences run most by " + p.subject +
        (p.sigGaps ? " — " + p.sigGaps + " group" + (p.sigGaps === 1 ? "" : "s") +
          " stand clearly apart" : "") + ". Read this study through " +
        p.subject.toLowerCase() + " first.";
    }
    if (p.id === "comove") {
      var b0 = (p.bundles && p.bundles[0]) || null;
      var more = p.bundleCount > 1 ? " (" + p.bundleCount + " such groups found)" : "";
      if (!b0) return "Some questions move together as a set" + more + ".";
      return b0.size + " questions move together as one — " + b0.anchor.a + " and " +
        b0.anchor.b + " anchor them" + more + ". Treat the shared driver once, not " +
        "question by question.";
    }
    if (p.id === "odd") {
      if (p.nullResult) return "No group breaks its own pattern — every exception is too small to matter " +
        "or sits on a base too thin to trust.";
      var f = p.flip, low = p.direction === "low-but-high";
      return p.column + " runs " + (low ? "below" : "above") + " the overall almost everywhere — yet on " +
        "“" + f.qtitle + "” it is unexpectedly " + (low ? "higher" : "lower") + " (" +
        Number(f.value).toFixed(1) + " vs " + Number(f.total).toFixed(1) + ", against its usual " +
        (f.meanGap >= 0 ? "+" : "−") + Math.abs(f.meanGap).toFixed(2) + ").";
    }
    if (p.id === "bimodal") {
      if (p.nullResult) return "No hidden disagreement — every question's average reflects a single camp, not two.";
      return p.flaggedCount + (p.flaggedCount === 1 ? " question splits" : " questions split") +
        " the room into two camps the average hides — read the distribution, not the mean.";
    }
    if (p.id === "weak") {
      // Summary-led area: quote the real overall rating. Flat fallback keeps
      // the qualitative line (its ranking average is not a number anyone rated).
      if (p.summary) {
        return p.subject + " is the weakest area — rated " +
          Number(p.summary.value).toFixed(1) + " overall" +
          (p.moving < 0 ? ", and slipping." : ".");
      }
      return p.subject + " is the weakest area — its questions cluster low" +
        (p.moving < 0 ? ", and are slipping." : ".");
    }
    if (p.id === "strong") {
      if (p.summary) {
        return p.subject + " is the strongest area — rated " +
          Number(p.summary.value).toFixed(1) + " overall.";
      }
      return p.subject + " is the strongest area — what is holding things together.";
    }
    if (p.id === "moved") {
      if (p.stable) return "Broadly stable — nothing shifted materially since the last wave.";
      var ph = function (x) { return x.subject + " " + (x.diff >= 0 ? "up " : "down ") + Math.abs(x.diff).toFixed(1); };
      var when = p.year ? " since " + p.year : "";
      if (p.up && p.down) return ph(p.down) + ", " + ph(p.up) + when + ".";
      return ph(p.up || p.down) + when + ".";
    }
    return "";
  };

  /** Draft for the one-line big-picture answer, from the patterns found. Leads
   *  with the split that matters and the group under strain (the two cross-cutting
   *  reads), then the strongest / weakest areas when a study is tagged. */
  ui.answerSeed = function (patterns) {
    var list = patterns || [];
    var port = list.filter(function (p) { return p.kind === "portrait"; })[0];
    var split = list.filter(function (p) { return p.kind === "split"; })[0];
    var bits = [];
    if (port) {
      var strained = port.lean === "strained";
      var hi = port.highs && port.highs[0], lo = port.lows && port.lows[0];
      if (strained && hi) bits.push(port.subject + " carries a tension — strained overall but strongest on “" + hi.label + "”");
      else if (!strained && lo) bits.push(port.subject + " is strong overall but dips on “" + lo.label + "”");
      else if (strained) bits.push(port.subject + " is under strain almost everywhere — below the overall on " + port.hits + " of " + port.total);
      else bits.push(port.subject + " leads almost everywhere — above the overall on " + port.gains + " of " + port.total);
    }
    if (split) bits.push("differences run most by " + split.subject);
    return bits.length ? cap(bits.join("; ")) + "."
      : "Write the one-sentence answer your client should walk away with.";
  };

  /** An accessible, inline-editable plaintext field. Carries data-seed (the
   *  engine's current wording) so the controller can drop an edit that matches the
   *  seed and never let an unedited line go stale across a re-run. Saved by 27k on
   *  focusout. seed defaults to text when omitted. */
  ui.editable = function (id, field, text, cls, label, seed) {
    var s = (seed === undefined || seed === null) ? text : seed;
    return '<div class="tko-ed ' + cls + '" data-edit="' + fmt.escapeHtml(id + "::" + field) +
      '" data-seed="' + fmt.escapeHtml(s) +
      '" contenteditable="plaintext-only" role="textbox" aria-multiline="false" spellcheck="false" ' +
      'aria-label="' + fmt.escapeHtml(label) + '" title="Click to edit — your wording is saved">' +
      fmt.escapeHtml(text) + "</div>";
  };

  /** Reliability ribbon: how much to trust the page, in one honest line.
   *  Rendered in the read-view footer, above the provenance line (27h). */
  ui.reliabilityRibbon = function (rel) {
    if (!rel || !rel.n) return "";
    var parts = [(rel.census ? "Census" : "Sample"), "n = " + fmt.base(rel.n)];
    if (rel.responseRate) parts.push(rel.responseRate + "% response of " + fmt.base(rel.population));
    if (rel.moePct !== null && rel.moePct !== undefined) {
      parts.push("±" + Number(rel.moePct).toFixed(1) + "pp worst-case");
    }
    parts.push("95% " + (rel.sigNote || "confidence"));
    return '<div class="tko-reliability" role="note"><span>' +
      fmt.escapeHtml(parts.join(" · ")) + "</span>" +
      '<button class="tko-howsure" data-howsure>How sure are these numbers? ›</button></div>';
  };

})(typeof window !== "undefined" ? window : globalThis);
