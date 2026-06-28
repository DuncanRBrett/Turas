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
    weak: { tag: "Weakest area", cls: "weak" },
    strong: { tag: "Strongest area", cls: "strong" },
    moved: { tag: "What moved", cls: "moved" }
  };
  ui.patternMeta = function (id) { return PATTERN_META[id] || { tag: "", cls: "" }; };

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
    return '<div class="tko-row"><div class="tko-rl">' + fmt.escapeHtml(m.label) + "</div>" +
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
    return '<div class="tko-row"><div class="tko-rl">' + fmt.escapeHtml(e.label) + "</div>" +
      '<div class="tko-rmeter"><span class="tko-track"><span class="tko-fill tko-' + cls +
      '" style="width:' + w + '%"></span></span><span class="tko-rv">' +
      ui.fmtVal(e.isMean, e.value, e.decimals) +
      '<span class="tko-rest"> / ' + ui.fmtVal(e.isMean, baseline, e.decimals) + "</span></span></div></div>";
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
    if (p.id === "group") {
      return p.subject + " scores below the overall on " + p.hits + " of " + p.total +
        " rated questions — the group most under strain.";
    }
    if (p.id === "split") {
      return "Differences run most by " + p.subject + " — " + p.high.label +
        " sits highest, " + p.low.label + " lowest. Read this study through " +
        p.subject.toLowerCase() + ".";
    }
    if (p.id === "comove") {
      var b0 = (p.bundles && p.bundles[0]) || null;
      var more = p.bundleCount > 1 ? " (" + p.bundleCount + " such groups found)" : "";
      if (!b0) return "Some questions move together as a set" + more + ".";
      return b0.size + " questions move together as one — " + b0.anchor.a + " and " +
        b0.anchor.b + " anchor them" + more + ". Treat the shared driver once, not " +
        "question by question.";
    }
    if (p.id === "weak") {
      return p.subject + " is the weakest area — its questions cluster low" +
        (p.moving < 0 ? ", and are slipping." : ".");
    }
    if (p.id === "strong") {
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
    var by = {};
    (patterns || []).forEach(function (p) { by[p.id] = p; });
    var bits = [];
    if (by.split) bits.push("Differences run most by " + by.split.subject);
    if (by.group) bits.push(by.group.subject + " is the group under strain");
    if (by.strong) bits.push(by.strong.subject + " carries the study");
    if (by.weak) bits.push(by.weak.subject + " is the soft spot");
    return bits.length ? bits.join("; ") + "."
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

  /** Reliability ribbon: how much to trust the page, in one honest line. */
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
