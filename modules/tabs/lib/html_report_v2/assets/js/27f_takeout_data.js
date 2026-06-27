/**
 * Executive Takeout — data layer. Two responsibilities, kept separate:
 *   GATHER (I/O boundary): assemble the engine's inputs from the already-
 *     computed report objects (views._collectFindings, views.indexQuestions,
 *     wave deltas, TR.conf reliability). Every source is wrapped so a missing
 *     piece (no microdata, no waves) degrades to empty, never crashes the tab.
 *   STATE (curation): the researcher's edits — claim/so-what text per finding,
 *     the apex answer, and vetoes — persisted in localStorage and seeded from
 *     the saved-copy island, exactly like analyst insights (28_insights.js).
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};

  /* ---------------- gather (I/O boundary) ---------------- */

  /** Scale maximum for a touchpoint (configured scale, else index_scores). */
  function touchpointMax(q) {
    if (q.scale_max) return q.scale_max;
    var max = 0;
    if (q.index_scores) {
      Object.keys(q.index_scores).forEach(function (k) {
        if (q.index_scores[k] > max) max = q.index_scores[k];
      });
    }
    return max > 0 ? max : 100;
  }

  /** Band a touchpoint value strong / moderate / weak — the gauge thresholds
   *  when configured, else 75% / 50% of the scale maximum (dashboard parity). */
  function touchpointBand(value, q) {
    if (value === null || value === undefined) return null;
    if (q.gauge_green != null && q.gauge_amber != null) {
      if (value >= q.gauge_green) return "strong";
      if (value >= q.gauge_amber) return "moderate";
      return "weak";
    }
    var pct = value / (touchpointMax(q) || 100) * 100;
    if (pct >= 75) return "strong";
    if (pct >= 50) return "moderate";
    return "weak";
  }
  takeout._touchpointBand = touchpointBand;

  /** A composite index (Q_Engage / Q_Value): rated touchpoint that maps to a
   *  "single" type — it summarises the others, so it leads the apex answer. */
  function isComposite(q) {
    return q.type !== "scale" && q.type !== "nps" &&
      typeof q.scale_max === "number" && q.scale_max > 0;
  }

  /** Touchpoint levels + composites from the dashboard's rated questions. */
  function gatherLevels(views) {
    var levels = [], composites = [];
    views.indexQuestions().forEach(function (q) {
      var model = views._modelFor(q.code);
      var row = views._meanRow(model);
      var value = row ? row.cells[0].mean : null;
      if (value === null || value === undefined) return;
      var max = touchpointMax(q), band = touchpointBand(value, q);
      var level = { code: q.code, title: q.title, category: q.category,
        value: value, band: band, delta: row.delta || null,
        base: model.columns[0].base, scaleMin: 0, scaleMax: max };
      levels.push(level);
      if (isComposite(q)) {
        composites.push({ code: q.code, title: q.title, value: value,
          band: band, scaleMax: max });
      }
    });
    return { levels: levels, composites: composites };
  }

  /** Overall sample size + worst-case precision for the reliability stamp. */
  function gatherReliability(levels) {
    var n = 0;
    levels.forEach(function (l) { if (l.base > n) n = l.base; });
    var conf = TR.conf || {};
    var census = typeof conf.reportHasPopulation === "function"
      ? conf.reportHasPopulation() : false;
    var labels = typeof conf.labels === "function" ? conf.labels() : {};
    return {
      n: n,
      moePct: typeof conf.maxMoePct === "function" && n ? conf.maxMoePct(n) : null,
      census: census,
      sampleNote: census ? "census" : (labels.sampling_method_normalised || "sample"),
      sigNote: labels.is_probability === false ? "stability interval" : "confidence"
    };
  }

  /**
   * Assemble all engine inputs for a banner. Defensive: each source is isolated
   * so a report without microdata (no standouts) or without waves (no movers)
   * still produces a valid, smaller takeout rather than failing.
   */
  takeout.gather = function (banner) {
    var views = TR.views || {};
    var b = banner || (TR.d2 && TR.d2.state.banner) || (TR.d2 && TR.d2.firstBanner());
    if (b && String(b).indexOf("custom:") === 0) b = TR.d2.firstBanner();
    var standouts = [];
    try {
      if (typeof views._collectFindings === "function") standouts = views._collectFindings(b);
    } catch (e) { standouts = []; }
    var lv = { levels: [], composites: [] };
    try { lv = gatherLevels(views); } catch (e) { lv = { levels: [], composites: [] }; }
    var reliability = gatherReliability(lv.levels);
    var lowBase = (TR.AGG && TR.AGG.project && TR.AGG.project.low_base_threshold) || 30;
    return { standouts: standouts, levels: lv.levels, composites: lv.composites,
      reliability: reliability, lowBaseThreshold: lowBase, banner: b };
  };

  /* ---------------- state (curation, persisted) ---------------- */

  var KEY = "turas_v2_takeout";
  var cache = null;

  function store() {
    if (cache) return cache;
    cache = { text: {}, veto: {}, apex: null };
    if (TR.userState && TR.userState.takeout) merge(cache, TR.userState.takeout);
    try {
      var raw = global.localStorage && localStorage.getItem(KEY);
      if (raw) merge(cache, JSON.parse(raw) || {});
    } catch (e) { /* island-only context */ }
    return cache;
  }

  function merge(target, src) {
    if (!src) return;
    if (src.text) Object.keys(src.text).forEach(function (k) { target.text[k] = src.text[k]; });
    if (src.veto) Object.keys(src.veto).forEach(function (k) { target.veto[k] = src.veto[k]; });
    if (src.apex !== undefined && src.apex !== null) target.apex = src.apex;
  }

  function persist() {
    try {
      if (global.localStorage) localStorage.setItem(KEY, JSON.stringify(store()));
    } catch (e) { /* storage full/blocked — curation stays in memory */ }
  }

  /** Curation API. Text is stored raw and escaped on render — never trusted. */
  takeout.state = {
    getText: function (id, field, fallback) {
      var v = store().text[id + "::" + field];
      return (v === undefined || v === null) ? (fallback || "") : v;
    },
    setText: function (id, field, value) {
      var key = id + "::" + field;
      if (value) store().text[key] = value; else delete store().text[key];
      persist();
    },
    isEdited: function (id, field) {
      return store().text[id + "::" + field] !== undefined;
    },
    getApex: function (fallback) {
      var v = store().apex;
      return (v === undefined || v === null) ? (fallback || "") : v;
    },
    setApex: function (value) { store().apex = value || null; persist(); },
    apexEdited: function () { return !!store().apex; },
    isVetoed: function (id) { return !!store().veto[id]; },
    vetoes: function () { return store().veto; },
    setVeto: function (id, on) {
      if (on) store().veto[id] = true; else delete store().veto[id];
      persist();
    },
    hasCuration: function () {
      var s = store();
      return !!s.apex || Object.keys(s.text).length > 0 || Object.keys(s.veto).length > 0;
    },
    reset: function () { cache = { text: {}, veto: {}, apex: null }; persist(); }
  };

})(typeof window !== "undefined" ? window : globalThis);
