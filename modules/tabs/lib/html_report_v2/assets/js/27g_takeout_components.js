/**
 * Executive Takeout — shared render atoms used by both the Read and Present
 * views, so a card, a bar or an editable line is defined exactly once.
 *
 * All user-editable text is stored raw by the state layer and ESCAPED HERE on
 * render (fmt.escapeHtml) — user content is never written as raw HTML. Editable
 * fields are contenteditable plaintext, wired (focusout -> save) by 27k.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var fmt = TR.fmt;
  var ui = takeout.ui = {};

  /* Posture glyphs (decorative; the text label always carries the meaning, so
     colour is never the sole signal — WCAG colour-independence). */
  var GLYPH = {
    protect: "M12 2l8 3v6c0 5-3.6 8.4-8 10.5C7.6 19.4 4 16 4 11V5z",
    act: "M12 2l10 18H2z",
    watch: "M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6S2 12 2 12z",
    decide: "M7 4v6a4 4 0 0 0 4 4h2a4 4 0 0 1 4 4v2M7 4l-2 2 2 2M17 22l2-2-2-2"
  };

  /** Inline SVG posture icon (decorative — aria-hidden). */
  ui.glyph = function (postureId) {
    var d = GLYPH[postureId] || "";
    return '<svg class="tko-glyph" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
      '<path d="' + d + '" fill="none" stroke="currentColor" stroke-width="1.8" ' +
      'stroke-linejoin="round" stroke-linecap="round"></path></svg>';
  };

  /** Value in its own units: "86%" for a proportion, "7.4" for a mean/index. */
  function fmtVal(f, v) {
    if (v === null || v === undefined) return "–";
    return f.metric === "mean" ? Number(v).toFixed(f.decimals || 1) : Math.round(v) + "%";
  }
  ui.fmtVal = fmtVal;

  /** Baseline a finding is measured against: the rest, else the whole sample. */
  function baselineOf(f) {
    return (f.rest === null || f.rest === undefined) ? f.overall : f.rest;
  }

  /** Two-bar comparison (group vs the rest), reusing the .dfb visual language.
   *  Means scale to their own range; proportions fill a 0–100 track. */
  ui.twoBar = function (f) {
    var span = (f.scaleMax - f.scaleMin) || 1;
    var width = function (v) {
      var w = f.metric === "mean" ? (v - f.scaleMin) / span * 100 : v;
      return Math.min(Math.max(w, 0), 100).toFixed(1);
    };
    var base = baselineOf(f);
    var groupName = f.kind === "level" ? "This wave" : TR.charts.clip(f.column, 22);
    var restName = f.kind === "level" ? "Scale max"
      : (f.rest === null || f.rest === undefined ? "Everyone" : "The rest");
    var restVal = f.kind === "level" ? f.scaleMax : base;
    var row = function (v, cls, name) {
      return '<div class="dfb-row"><span class="dfb-name">' + fmt.escapeHtml(name) +
        '</span><div class="dfb-track"><div class="dfb-bar ' + cls + '" style="width:' +
        width(v) + '%"></div></div><span class="dfb-val">' + fmtVal(f, v) + "</span></div>";
    };
    return '<div class="dfb tko-bars">' + row(f.value, "dfb-group tko-" + f.posture) +
      row(restVal, "dfb-total", restName) + "</div>";
  };

  /** Base size chip, with a low-base warning so reliability is never hidden. */
  ui.baseChip = function (f, lowThreshold) {
    if (f.base === null || f.base === undefined) return "";
    var low = f.base < (lowThreshold || 30);
    return '<span class="tko-chip' + (low ? " tko-lowbase" : "") + '">n = ' +
      fmt.base(f.base) + (low ? " · low base" : "") + "</span>";
  };

  /** Confidence tier tag — only shown for nearly-significant (80%) findings. */
  ui.softTag = function (f) {
    return f.soft ? '<span class="tko-chip tko-soft" title="Nearly significant (80%)">80%</span>' : "";
  };

  /** Wave-delta chip for a touchpoint level (▲/▼ + magnitude), when significant. */
  ui.deltaChip = function (f) {
    if (!f.delta || !f.delta.sig) return "";
    var up = f.delta.diff >= 0;
    return '<span class="tko-chip tko-delta ' + (up ? "up" : "down") + '">' +
      (up ? "▲" : "▼") + " " + Math.abs(f.delta.diff).toFixed(1) +
      (f.delta.year ? " vs " + f.delta.year : "") + "</span>";
  };

  /** Templated draft headline (conclusion-first). The researcher rewrites it.
   *  The question itself is named on its own line, so a standout headline talks
   *  about the segment, not the metric. */
  ui.seedClaim = function (f) {
    var col = f.column;
    if (f.kind === "level") {
      if (f.posture === "protect") return f.title + " — a genuine strength";
      if (f.posture === "act") return f.title + " — among the weakest";
      if (f.posture === "watch") return f.title + " — on the move";
      return f.title + " — strong but slipping";
    }
    if (f.posture === "decide") return col + " — answers differently across the battery";
    if (f.posture === "protect") return col + " — ahead of the rest";
    if (f.posture === "watch") return col + " — on the move";
    return col + " — behind the rest";
  };

  /** Label for the metric line: the scale for a level, "index" for a mean
   *  standout, the answer category for a top-box standout. */
  ui.metricLabel = function (f) {
    if (f.kind === "level") return "out of " + f.scaleMax;
    if (f.metric === "mean") return "index";
    return f.label || "";
  };

  /** Single gauge bar for a level (value as a share of its scale) — no separate
   *  "scale max" bar, which carried no information. Coloured by posture. */
  ui.gaugeBar = function (f) {
    var pct = f.scaleMax ? Math.min(100, Math.max(0, f.value / f.scaleMax * 100)) : 0;
    return '<div class="tko-gauge" role="img" aria-label="' + ui.fmtVal(f, f.value) +
      " out of " + f.scaleMax + '"><div class="tko-gauge-fill tko-' + f.posture +
      '" style="width:' + pct.toFixed(1) + '%"></div></div>';
  };

  /** A small factual source line that always names the question behind a card,
   *  so an edited headline never loses what was actually asked. */
  ui.questionLine = function (f) {
    return '<div class="tko-qline" title="' + fmt.escapeHtml(f.title) + '">' +
      fmt.escapeHtml(f.code) + " · " + fmt.escapeHtml(TR.charts.clip(f.title, 70)) + "</div>";
  };

  /** Apex KPI wave-delta chip (shown whenever a prior wave is attached). */
  ui.apexDelta = function (m) {
    if (!m.delta || m.delta.diff === null || m.delta.diff === undefined) return "";
    var up = m.delta.diff >= 0;
    return '<span class="tko-kpi-delta ' + (up ? "up" : "down") + '">' +
      (up ? "▲" : "▼") + " " + Math.abs(m.delta.diff).toFixed(1) + "</span>";
  };

  /** The "how many" companion to the index: the favourable top-box %, in its
   *  own words ("· 69% satisfied"). Empty when the question carries no NET. */
  ui.topBox = function (f) {
    if (!f.topBox || f.topBox.pct === null || f.topBox.pct === undefined) return "";
    return '<span class="tko-tb">· ' + Math.round(f.topBox.pct) + "% " +
      fmt.escapeHtml(String(f.topBox.label || "").toLowerCase()) + "</span>";
  };

  /** Which banner cut a standout came from (Campus / Department / Tenure / …). */
  ui.bannerChip = function (f) {
    return f.bannerGroup
      ? '<span class="tko-chip tko-bg">' + fmt.escapeHtml(f.bannerGroup) + "</span>" : "";
  };

  /** Apex trend: a wave sparkline when history exists, else the single delta. */
  ui.apexSpark = function (m) {
    if (m.waves && TR.render && typeof TR.render.sparkline === "function") {
      try {
        return '<span class="tko-kpi-spark">' +
          TR.render.sparkline(m.waves, false, { w: 60, h: 20 }) + "</span>";
      } catch (e) { /* fall back to the delta chip */ }
    }
    return ui.apexDelta(m);
  };

  /** Templated neutral implication (the "so what"). The researcher rewrites it. */
  ui.seedSoWhat = function (f) {
    if (f.posture === "protect") return "Protect what's driving this — lead with it.";
    if (f.posture === "act") return "The weakest point of the experience — worth acting on.";
    if (f.posture === "watch") return "Worth a look before next wave.";
    return "The machine found the pattern; the diagnosis is yours to make.";
  };

  /** Apex answer seed from the composite indices (a draft, always editable). */
  ui.apexSeed = function (composites) {
    if (!composites || !composites.length) {
      return "Write the one-sentence answer your client should walk away with.";
    }
    var bits = composites.slice(0, 2).map(function (c) {
      return (c.label || c.title) + " sits at " + Number(c.value).toFixed(1) +
        " (" + (c.band || "—") + ")";
    });
    return bits.join("; ") + " — but the fault lines below are where the story is.";
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
    if (rel.responseRate) {
      parts.push(rel.responseRate + "% response of " + fmt.base(rel.population));
    }
    if (rel.moePct !== null && rel.moePct !== undefined) {
      parts.push("±" + Number(rel.moePct).toFixed(1) + "pp worst-case");
    }
    parts.push("95% " + (rel.sigNote || "confidence"));
    return '<div class="tko-reliability" role="note">' +
      '<svg class="tko-glyph" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2l8 3v6c0 5-3.6 8.4-8 10.5C7.6 19.4 4 16 4 11V5z" fill="none" stroke="currentColor" stroke-width="1.6"></path><path d="M9 12l2 2 4-4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"></path></svg>' +
      "<span>" + fmt.escapeHtml(parts.join(" · ")) + "</span></div>";
  };

})(typeof window !== "undefined" ? window : globalThis);
