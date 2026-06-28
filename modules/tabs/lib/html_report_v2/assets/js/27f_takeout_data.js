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

  /** Weighted Pearson between two per-respondent vectors, pairwise-complete.
   *  Returns { r, base } where base is the count of complete pairs. */
  function weightedPearson(x, y, w) {
    var sw = 0, sx = 0, sy = 0, base = 0;
    for (var r = 0; r < x.length; r++) {
      var a = x[r], b = y[r];
      if (a === null || a === undefined || b === null || b === undefined) continue;
      var wr = w ? w[r] : 1;
      sw += wr; sx += wr * a; sy += wr * b; base++;
    }
    if (!sw || base < 2) return { r: 0, base: base };
    var mx = sx / sw, my = sy / sw, cxy = 0, cxx = 0, cyy = 0;
    for (var s = 0; s < x.length; s++) {
      var av = x[s], bv = y[s];
      if (av === null || av === undefined || bv === null || bv === undefined) continue;
      var ws = w ? w[s] : 1, dx = av - mx, dy = bv - my;
      cxy += ws * dx * dy; cxx += ws * dx * dx; cyy += ws * dy * dy;
    }
    var den = Math.sqrt(cxx * cyy);
    return { r: den > 1e-12 ? cxy / den : 0, base: base };
  }

  /**
   * For "questions that move together": from per-respondent index scores
   * (TR.MICRO.scores) build the zero-order weighted correlation matrix across
   * rated questions, each question's correlation with the per-respondent overall
   * mean (the global factor the engine partials out), the complete-pair bases, and
   * the survey's acquiescence floor (mean inter-item raw r). Returns null when
   * microdata is absent or fewer than three rated questions carry scores.
   */
  function gatherComovement(views) {
    var micro = TR.MICRO;
    if (!micro || !micro.scores) return null;
    var weights = micro.weights || null;
    // rated questions that carry per-respondent scores, in questionnaire order
    var qs = views.indexQuestions().filter(function (q) {
      return micro.scores[q.code] && micro.scores[q.code].length;
    }).map(function (q) { return { code: q.code, title: q.title }; });
    var n = qs.length;
    if (n < 3) return null;
    var nResp = micro.n || (micro.scores[qs[0].code] || []).length;
    // per-respondent global factor = mean of that respondent's answered rated scores
    var global = new Array(nResp);
    for (var r = 0; r < nResp; r++) {
      var sum = 0, cnt = 0;
      for (var qi = 0; qi < n; qi++) {
        var v = micro.scores[qs[qi].code][r];
        if (v !== null && v !== undefined) { sum += v; cnt++; }
      }
      global[r] = cnt ? sum / cnt : null;
    }
    // matrices
    var R = [], B = [], rGlobal = [];
    for (var i = 0; i < n; i++) { R.push(new Array(n).fill(0)); B.push(new Array(n).fill(0)); }
    var floorSum = 0, floorCnt = 0;
    for (var a = 0; a < n; a++) {
      var xa = micro.scores[qs[a].code];
      rGlobal[a] = weightedPearson(xa, global, weights).r;
      for (var b = a + 1; b < n; b++) {
        var pr = weightedPearson(xa, micro.scores[qs[b].code], weights);
        R[a][b] = R[b][a] = pr.r; B[a][b] = B[b][a] = pr.base;
        floorSum += pr.r; floorCnt++;
      }
    }
    return { questions: qs, r: R, base: B, rGlobal: rGlobal,
      floor: floorCnt ? floorSum / floorCnt : 0 };
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
    var comove = null;
    try { comove = gatherComovement(views); } catch (e) { comove = null; }
    var reliability = gatherReliability(lv.levels.concat(lv.apex));
    var lowBase = (TR.AGG && TR.AGG.project && TR.AGG.project.low_base_threshold) || 30;
    return { columns: columns, levels: lv.levels, apex: lv.apex, comove: comove,
      reliability: reliability, lowBaseThreshold: lowBase };
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
      var raw = global.localStorage && localStorage.getItem(KEY);
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
    reset: function () { cache = { version: VERSION, text: {}, veto: {}, apex: null }; persist(); }
  };

})(typeof window !== "undefined" ? window : globalThis);
