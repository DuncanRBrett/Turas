/**
 * Pattern recognition — data layer. Two responsibilities, kept separate:
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

  /**
   * For the "group under strain" pattern: every breakout column's INDEX on every
   * rated question, compared to the overall. The index is bidirectional (a low
   * group reads as low — unlike significance letters, which only ever mark a
   * group being higher), so this finds the consistently-lowest segment cleanly
   * and reads intuitively in the evidence. Low-base columns are dropped. Returns
   * [{column, group, gaps:[{title, value, total, scaleMax}]}].
   */
  // Minimum responses to report a subgroup in a census (anonymity / meaning),
  // when the n>=30 sample-error floor doesn't apply. Override per study with
  // project.min_report_base.
  var MIN_CENSUS_BASE = 5;

  function gatherColumnStrain(views) {
    var proj = (TR.AGG && TR.AGG.project) || {};
    var conf = TR.conf || {};
    // In a near-census of a small finite population the sample-error floor (30)
    // is the wrong frame — a small subgroup is most of its own population, so the
    // finite-population correction makes it reliable. Use the analyst's reporting
    // floor there; keep the low-base threshold only for true samples.
    var census = typeof conf.reportHasPopulation === "function" && conf.reportHasPopulation();
    var floor = census ? (proj.min_report_base || MIN_CENSUS_BASE) : (proj.low_base_threshold || 30);
    var groups = (TR.AGG && TR.AGG.banner_groups) || [];
    var cols = {};
    var qs = views.indexQuestions();
    groups.forEach(function (g) {
      qs.forEach(function (q) {
        var model;
        try { model = views._modelFor(q.code, g.id); } catch (e) { return; }
        var row = views._meanRow(model);
        if (!row || row.cells[0].mean === null || row.cells[0].mean === undefined) return;
        var total = row.cells[0].mean, max = touchpointMax(q);
        model.columns.forEach(function (col, i) {
          if (i === 0) return;                              // skip the Total column
          var v = row.cells[i] && row.cells[i].mean;
          if (v === null || v === undefined) return;
          if (!col.base || col.base < floor) return;        // below the reporting floor
          var key = g.name + "::" + col.label;
          var c = cols[key] || (cols[key] = { column: col.label, group: g.name, base: 0, gaps: [] });
          if (col.base > c.base) c.base = col.base;   // largest base seen — for reliability weighting
          c.gaps.push({ title: q.title, value: v, total: total, scaleMax: max });
        });
      });
    });
    return Object.keys(cols).map(function (k) { return cols[k]; });
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

  /** Scale span (max − min) for the variance floor. Likert-type scales (max <= 10)
   *  run 1..max so the span is max−1; wider metrics (0..100) run from 0. */
  function scaleSpan(q) {
    var max = touchpointMax(q);
    return max <= 10 ? max - 1 : max;
  }

  /** Weighted mean of a vector (weights default to 1). */
  function wMean(x, w) {
    var sw = 0, sx = 0;
    for (var i = 0; i < x.length; i++) { var wi = w ? w[i] : 1; sw += wi; sx += wi * x[i]; }
    return sw ? sx / sw : 0;
  }

  /**
   * The shared CELL FAMILY for the multiple-comparison trust-gate AND the
   * odd-one-out pattern: ONE weighted variance-floored Welch test of each breakout
   * group vs the rest, on every rated question, from per-respondent scores. No new
   * R, no FPC (that belongs in the reliability layer). Both downstream patterns read
   * this single object so there is exactly one Welch computation and one BH pass.
   *
   * Returns { cells:[{banner,group,q,qtitle,nIn,gap,welchDiff,welchP,flooredG}],
   *   groups:[{banner,group,base,below,above,qn,meanGap,dir}], K, groupCount,
   *   questionCount } or null when microdata is absent.
   */
  function gatherCellFamily(views) {
    var micro = TR.MICRO;
    if (!micro || !micro.scores || !micro.banner_vars) return null;
    var weights = micro.weights || null;
    var proj = (TR.AGG && TR.AGG.project) || {};
    var conf = TR.conf || {};
    var census = typeof conf.reportHasPopulation === "function" && conf.reportHasPopulation();
    // Per-arm floor: in a census a subgroup is most of its own population, so the
    // analyst's reporting floor (default 5) applies; a true sample keeps n>=30.
    var floor = census ? (proj.min_report_base || MIN_CENSUS_BASE) : (proj.low_base_threshold || 30);
    var qs = views.indexQuestions().filter(function (q) {
      return micro.scores[q.code] && micro.scores[q.code].length;
    });
    if (!qs.length) return null;
    var nResp = micro.n || micro.scores[qs[0].code].length;
    var groups = (TR.AGG && TR.AGG.banner_groups) || [];
    var cells = [], groupAgg = {}, order = [];
    groups.forEach(function (g) {
      var bv = micro.banner_vars[g.id];
      if (!bv) return;
      var codeSet = {};
      for (var r = 0; r < nResp; r++) { var cd = bv[r]; if (cd !== null && cd !== undefined && cd >= 0) codeSet[cd] = true; }
      var codes = Object.keys(codeSet).map(Number).sort(function (a, b) { return a - b; });
      var model;
      try { model = views._modelFor(qs[0].code, g.id); } catch (e) { return; }
      var cols = (model.columns || []).slice(1);                 // non-Total columns
      if (codes.length !== cols.length) return;                  // label/order mismatch -> skip banner, never mislabel
      codes.forEach(function (code, ci) {
        var label = cols[ci].label;
        qs.forEach(function (q) {
          var sc = micro.scores[q.code], vfloor = Math.pow(scaleSpan(q) * 0.1, 2);
          var gx = [], gw = [], rx = [], rw = [], all = [], allw = [];
          for (var r = 0; r < nResp; r++) {
            var v = sc[r]; if (v === null || v === undefined) continue;
            var cd = bv[r]; if (cd === null || cd === undefined || cd < 0) continue;
            var w = weights ? weights[r] : 1;
            all.push(v); allw.push(w);
            if (cd === code) { gx.push(v); gw.push(w); } else { rx.push(v); rw.push(w); }
          }
          if (gx.length < floor || rx.length < floor) return;    // both arms must clear the floor
          var wt = takeout._welchTest(gx, gw, rx, rw, vfloor);
          var gMean = wMean(gx, gw), oMean = wMean(all, allw);
          var gap = gMean - oMean;                                // vs the overall (for the strain/flip read)
          var gkey = g.name + "::" + label;
          var ga = groupAgg[gkey] || (groupAgg[gkey] = { banner: g.name, group: label,
            base: 0, below: 0, above: 0, qn: 0, gapSum: 0 });
          if (!ga.qn) order.push(gkey);
          if (gx.length > ga.base) ga.base = gx.length;
          ga.qn++; ga.gapSum += gap;
          if (wt.diff < 0) ga.below++; else if (wt.diff > 0) ga.above++;
          cells.push({ banner: g.name, group: label, q: q.code, qtitle: q.title, nIn: gx.length,
            gap: gap, value: gMean, total: oMean, scaleMax: touchpointMax(q),
            welchDiff: wt.diff, welchP: wt.p, flooredG: wt.flooredG, gkey: gkey });
        });
      });
    });
    if (!cells.length) return null;
    var groupsOut = order.map(function (k) {
      var ga = groupAgg[k];
      ga.meanGap = ga.qn ? ga.gapSum / ga.qn : 0;
      ga.dir = ga.meanGap < 0 ? "below" : "above";
      return ga;
    });
    return { cells: cells, groups: groupsOut, K: cells.length,
      groupCount: groupsOut.length, questionCount: qs.length };
  }

  /**
   * For "hidden disagreement": each rated question's weighted category-count
   * distribution on its own 1..K ordinal scale, from per-respondent scores. The
   * bimodality test runs only on the overall distribution (never subgroup cuts),
   * so the base is the full answered n. Null when microdata is absent.
   */
  function gatherBimodality(views) {
    var micro = TR.MICRO;
    if (!micro || !micro.scores) return null;
    var weights = micro.weights || null;
    var qs = views.indexQuestions().filter(function (q) {
      return micro.scores[q.code] && micro.scores[q.code].length;
    });
    if (!qs.length) return null;
    var nResp = micro.n || micro.scores[qs[0].code].length;
    var out = qs.map(function (q) {
      var K = touchpointMax(q), sc = micro.scores[q.code], counts = new Array(K).fill(0);
      for (var r = 0; r < nResp; r++) {
        var v = sc[r]; if (v === null || v === undefined) continue;
        var idx = Math.round(v) - 1;                      // scores run 1..K
        if (idx >= 0 && idx < K) counts[idx] += weights ? weights[r] : 1;
      }
      return { code: q.code, title: q.title, counts: counts, scaleMax: K };
    });
    return { questions: out };
  }

  /**
   * Assemble all engine inputs. Defensive: each source is isolated so a report
   * without microdata (no standouts) or without waves still produces a valid,
   * smaller takeout rather than failing.
   */
  takeout.gather = function () {
    var views = TR.views || {};
    var columns = [];
    try { columns = gatherColumnStrain(views); } catch (e) { columns = []; }
    var lv = { levels: [], apex: [] };
    try { lv = gatherLevels(views); } catch (e) { lv = { levels: [], apex: [] }; }
    var comove = null;   // co-moving retired (the acquiescence halo, not a pattern)
    var fdr = null;
    try { fdr = gatherCellFamily(views); } catch (e) { fdr = null; }
    var bimodal = null;
    try { bimodal = gatherBimodality(views); } catch (e) { bimodal = null; }
    var reliability = gatherReliability(lv.levels.concat(lv.apex));
    var lowBase = (TR.AGG && TR.AGG.project && TR.AGG.project.low_base_threshold) || 30;
    return { columns: columns, levels: lv.levels, apex: lv.apex, comove: comove, fdr: fdr,
      bimodal: bimodal, reliability: reliability, lowBaseThreshold: lowBase };
  };

  /* ---------------- state (curation, persisted) ---------------- */

  var KEY = "turas_v2_takeout";
  // Curation-state schema version. BUMP this whenever the engine's seeds change
  // shape/meaning so edits saved under an older engine are dropped rather than
  // shown beside a new subject (the "stale curation" bug). v1 = posture lanes;
  // v2 = patterns view (subject-keyed takeaways, seed-aware persistence).
  var VERSION = 2;
  var cache = null;

  function store() {
    if (cache) return cache;
    cache = { version: VERSION, text: {}, veto: {}, apex: null };
    if (TR.userState && TR.userState.takeout) merge(cache, TR.userState.takeout, VERSION);
    try {
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(KEY));
      if (raw) merge(cache, JSON.parse(raw) || {}, VERSION);
    } catch (e) { /* island-only context */ }
    return cache;
  }

  function merge(target, src, expectVersion) {
    if (!src) return;
    // Ignore curation saved under an older engine — its seeds/subjects no longer
    // match, so honouring it is exactly what produced stale, contradictory cards.
    if (src.version !== expectVersion) return;
    if (src.text) Object.keys(src.text).forEach(function (k) { target.text[k] = src.text[k]; });
    if (src.veto) Object.keys(src.veto).forEach(function (k) { target.veto[k] = src.veto[k]; });
    if (src.apex !== undefined && src.apex !== null) target.apex = src.apex;
  }

  function persist() {
    try {
      if (global.localStorage) localStorage.setItem(TR.d2.storeKey(KEY), JSON.stringify(store()));
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
    // The full curation store ({version,text,veto,apex}) so Save-copy can bake the analyst's
    // Patterns edits/vetoes/apex into the portable .html (they hydrate back via userState.takeout).
    snapshot: function () { return store(); },
    reset: function () { cache = { version: VERSION, text: {}, veto: {}, apex: null }; persist(); }
  };

})(typeof window !== "undefined" ? window : globalThis);
