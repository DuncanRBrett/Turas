/**
 * Executive Takeout — shared render atoms for the Patterns view, used by both
 * the Read and Present layouts so a row, a chip or an editable line is defined
 * once. All user-editable text is stored raw and ESCAPED HERE on render
 * (fmt.escapeHtml) — user content is never written as raw HTML.
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

  /** One member row inside an AREA card: question, a scale bar, its value, and a
   *  move chip when it shifted. cls colours the bar by pattern kind. */
  ui.areaRow = function (m, cls) {
    var pct = m.scaleMax ? Math.min(100, Math.max(0, m.value / m.scaleMax * 100)) : 0;
    return '<div class="tko-row"><span class="tko-rl" title="' + fmt.escapeHtml(m.label) +
      '">' + fmt.escapeHtml(TR.charts.clip(m.label, 28)) + "</span>" +
      '<span class="tko-track"><span class="tko-fill tko-' + cls + '" style="width:' +
      pct.toFixed(1) + '%"></span></span>' +
      '<span class="tko-rv">' + Number(m.value).toFixed(1) + ui.moveChip(m.delta) + "</span></div>";
  };

  /** One row inside the GROUP card: the column's standing on a question vs the
   *  rest (its bar in the pattern colour, the rest shown faintly alongside). */
  ui.groupRow = function (e, cls) {
    var max = e.isMean ? (e.scaleMax || 5) : 100;
    var baseline = (e.rest === null || e.rest === undefined) ? e.overall : e.rest;
    var w = Math.min(100, Math.max(0, (e.value || 0) / max * 100)).toFixed(1);
    return '<div class="tko-row"><span class="tko-rl" title="' + fmt.escapeHtml(e.label) +
      '">' + fmt.escapeHtml(TR.charts.clip(e.label, 24)) + "</span>" +
      '<span class="tko-track"><span class="tko-fill tko-' + cls + '" style="width:' +
      w + '%"></span></span><span class="tko-rv">' + ui.fmtVal(e.isMean, e.value, e.decimals) +
      '<span class="tko-rest"> / ' + ui.fmtVal(e.isMean, baseline, e.decimals) + "</span></span></div>";
  };

  /** A small ▲/▼ move chip for a member that shifted significantly, else "". */
  ui.moveChip = function (delta) {
    if (!delta || !delta.sig) return "";
    var up = delta.diff >= 0;
    return '<span class="tko-move ' + (up ? "up" : "down") + '">' +
      (up ? " ▲" : " ▼") + Math.abs(delta.diff).toFixed(1) + "</span>";
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
      return p.subject + " is behind the rest on " + p.hits + " of " + p.total +
        " questions — the group most under strain.";
    }
    if (p.id === "weak") {
      return p.subject + " is the weakest area — its questions cluster low" +
        (p.moving < 0 ? ", and are slipping." : ".");
    }
    if (p.id === "strong") {
      return p.subject + " is the strongest area — what is holding things together.";
    }
    if (p.id === "moved") {
      return p.subject + " moved " + (p.diff >= 0 ? "up " : "down ") +
        Math.abs(p.diff).toFixed(1) + (p.year ? " since " + p.year : "") +
        (p.driver ? ", led by " + p.driver + "." : ".");
    }
    return "";
  };

  /** Draft for the one-line big-picture answer, from the patterns found. */
  ui.answerSeed = function (patterns) {
    var by = {};
    (patterns || []).forEach(function (p) { by[p.id] = p; });
    var bits = [];
    if (by.strong) bits.push(by.strong.subject + " carries the study");
    if (by.weak) bits.push(by.weak.subject + " is the soft spot");
    if (by.group) bits.push(by.group.subject + " is the group under strain");
    return bits.length ? bits.join("; ") + "."
      : "Write the one-sentence answer your client should walk away with.";
  };

  /** An accessible, inline-editable plaintext field. Saved by 27k on focusout. */
  ui.editable = function (id, field, text, cls, label) {
    return '<div class="tko-ed ' + cls + '" data-edit="' + fmt.escapeHtml(id + "::" + field) +
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
