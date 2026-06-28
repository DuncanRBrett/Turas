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

  /** A composite index (e.g. Q_Engage / Q_Value): rated touchpoint that maps to
   *  a "single" type — it summarises the others, so it belongs in the apex. */
  function isComposite(q) {
    return q.type !== "scale" && q.type !== "nps" &&
      typeof q.scale_max === "number" && q.scale_max > 0;
  }

  /** Headline-metric keywords (generic across studies — satisfaction, overall
   *  opinion, recommendation/NPS). A study can override this entirely by listing
   *  question codes in project.takeout_headline. */
  var HEADLINE_RE = /satisf|overall|recommend|\bnps\b|csat|net promoter/i;

  function headlineOverride() {
    var h = TR.AGG && TR.AGG.project && TR.AGG.project.takeout_headline;
    return (h && h.length) ? h : null;
  }

  /** A tidy short label for a headline question (long question text -> a noun). */
  function shortLabel(q) {
    var t = q.title || "";
    if (t.length <= 22) return t;                       // composites, short titles
    if (/satisf/i.test(t)) return "Satisfaction";
    if (/recommend|net promoter|\bnps\b/i.test(t)) return "Recommendation";
    if (/overall/i.test(t)) return "Overall";
    return t.slice(0, 20) + "…";
  }

  /** The favourable top-box: the first NET row that is not a computed difference
   *  (Turas builds NETs favourable-first). Returns {pct,label} or null when the
   *  question carries no NET (pure mean / NPS / numeric) — then the index shows
   *  alone. Generic: keys off row.kind + net_diffs, never off labels. */
  function topBoxOf(q, model) {
    var rows = q.rows || [];
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind !== "net") continue;
      if (q.net_diffs && q.net_diffs[String(i)] !== undefined) continue;  // skip NET POSITIVE
      var cell = model.rows[i] && model.rows[i].cells[0];
      if (cell && cell.pct !== null && cell.pct !== undefined) {
        return { pct: cell.pct, label: rows[i].label };
      }
      return null;
    }
    return null;
  }

  /** Wave trajectory points for the apex sparkline, or null (no/short history). */
  function safeWaves(row) {
    try {
      if (TR.render && typeof TR.render.wavePoints === "function") {
        var pts = TR.render.wavePoints(row);
        return (pts && pts.length > 1) ? pts : null;
      }
    } catch (e) { /* no wave history */ }
    return null;
  }

  /**
   * Split rated questions into driver LEVELS (which feed the lanes) and APEX
   * metrics (the study's headlines: overall/satisfaction-type questions first,
   * then composite indices). Apex metrics are pulled OUT of the lanes so the
   * headlines lead; their subgroup standouts still surface in the lanes.
   * Each item carries its index, top-box and (for apex) its wave trajectory.
   */
  function gatherLevels(views) {
    var override = headlineOverride();
    var levels = [], headline = [], composite = [];
    views.indexQuestions().forEach(function (q) {
      var model = views._modelFor(q.code);
      var row = views._meanRow(model);
      var value = row ? row.cells[0].mean : null;
      if (value === null || value === undefined) return;
      var item = { code: q.code, title: q.title,
        section: q.category || "",                 // Level 1 (existing Category column)
        theme: q.theme || q.category || "",        // Level 2 (new Theme column; falls back to section)
        value: value, band: touchpointBand(value, q), delta: row.delta || null,
        base: model.columns[0].base, scaleMin: 0, scaleMax: touchpointMax(q),
        topBox: topBoxOf(q, model) };
      // A composite is always a headline. A keyword match (satisfaction / overall
      // / NPS) is a headline ONLY when the question is untagged — if the analyst
      // grouped it into a section/theme, they meant it as a driver, not a headline.
      var tagged = !!(q.category || q.theme);
      var isApex = override ? (override.indexOf(q.code) !== -1)
        : (isComposite(q) || (!tagged && HEADLINE_RE.test(q.title || "")));
      if (!isApex) { levels.push(item); return; }
      item.label = shortLabel(q);
      item.waves = safeWaves(row);
      if (isComposite(q)) composite.push(item); else headline.push(item);
    });
    var apex = headline.concat(composite);
    if (override) {
      apex.sort(function (a, b) { return override.indexOf(a.code) - override.indexOf(b.code); });
    }
    return { levels: levels, apex: apex };
  }

  /** Subgroup standouts across EVERY banner group (campus + department + tenure
   *  + whatever a study defines), each tagged with the cut it came from, so the
   *  sharpest difference surfaces wherever it lives. */
  function gatherStandouts(views) {
    if (typeof views._collectFindings !== "function") return [];
    var groups = (TR.AGG && TR.AGG.banner_groups) || [];
    if (!groups.length) {
      try { return views._collectFindings(TR.d2 ? TR.d2.firstBanner() : ""); }
      catch (e) { return []; }
    }
    var all = [];
    groups.forEach(function (g) {
      try {
        views._collectFindings(g.id).forEach(function (f) {
          f.bannerGroup = g.name;
          all.push(f);
        });
      } catch (e) { /* skip a banner group that fails to compute */ }
    });
    return all;
  }

  /** Sample size, precision, and response rate for the reliability stamp. */
  function gatherReliability(items) {
    var n = 0;
    items.forEach(function (l) { if (l.base > n) n = l.base; });
    var conf = TR.conf || {};
    var census = typeof conf.reportHasPopulation === "function"
      ? conf.reportHasPopulation() : false;
    var labels = typeof conf.labels === "function" ? conf.labels() : {};
    var pop = (TR.AGG && TR.AGG.project && TR.AGG.project.population_size) || null;
    return {
      n: n,
      moePct: typeof conf.maxMoePct === "function" && n ? conf.maxMoePct(n) : null,
      census: census,
      population: pop,
      responseRate: (pop && n) ? Math.round(n / pop * 100) : null,
      sampleNote: census ? "census" : (labels.sampling_method_normalised || "sample"),
      sigNote: labels.is_probability === false ? "stability interval" : "confidence"
    };
  }

  /**
   * Assemble all engine inputs. Defensive: each source is isolated so a report
   * without microdata (no standouts) or without waves still produces a valid,
   * smaller takeout rather than failing.
   */
  takeout.gather = function () {
    var views = TR.views || {};
    var standouts = [];
    try { standouts = gatherStandouts(views); } catch (e) { standouts = []; }
    var lv = { levels: [], apex: [] };
    try { lv = gatherLevels(views); } catch (e) { lv = { levels: [], apex: [] }; }
    var reliability = gatherReliability(lv.levels.concat(lv.apex));
    var lowBase = (TR.AGG && TR.AGG.project && TR.AGG.project.low_base_threshold) || 30;
    return { standouts: standouts, levels: lv.levels, apex: lv.apex,
      reliability: reliability, lowBaseThreshold: lowBase };
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
