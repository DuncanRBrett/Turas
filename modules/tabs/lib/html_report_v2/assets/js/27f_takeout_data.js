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
      var model = publishedModel(views, q.code);
      var row = views._meanRow(model);
      var value = row ? row.cells[0].mean : null;
      if (value === null || value === undefined) return;
      var item = { code: q.code, title: q.title,
        section: q.category || "",                 // Level 1 (existing Category column)
        theme: q.theme || q.category || "",        // Level 2 (new Theme column; falls back to section)
        value: value, band: touchpointBand(value, q), delta: row.delta || null,
        base: model.columns[0].base, baseEff: model.columns[0].baseEff || null,
        scaleMin: 0, scaleMax: touchpointMax(q),
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
  // when the n>=30 sample-error floor doesn't apply. The analyst's disclosure k
  // (project.min_reporting_base — the SAME key 21d_disclosure.js reads; the data
  // layer emits it only when > 1) overrides; 5 is only the no-config fallback.
  var MIN_CENSUS_BASE = 5;

  function censusFloor(proj) {
    var k = proj.min_reporting_base;
    return (typeof k === "number" && k > 1) ? k : MIN_CENSUS_BASE;
  }

  /** The Patterns tab summarises the PUBLISHED full-sample view (the shell hides
   *  the filter bar on it for exactly that reason), so every model it reads must
   *  ignore the live audience filter — empty filters, never TR.d2.state.filters.
   *  The microdata scans (cell family, bimodality) already run unmasked. */
  function publishedModel(views, code, banner) {
    if (TR.model && typeof TR.model.forQuestion === "function") {
      return TR.model.forQuestion(code, banner || (TR.d2 && TR.d2.state.banner),
        [], { hiddenCols: [], intervals: true });
    }
    return views._modelFor(code, banner);
  }

  function gatherColumnStrain(views) {
    var proj = (TR.AGG && TR.AGG.project) || {};
    var conf = TR.conf || {};
    // In a near-census of a small finite population the sample-error floor (30)
    // is the wrong frame — a small subgroup is most of its own population, so the
    // finite-population correction makes it reliable. Use the analyst's reporting
    // floor there; keep the low-base threshold only for true samples.
    var census = typeof conf.fpcActiveReport === "function" && conf.fpcActiveReport();
    var floor = census ? censusFloor(proj) : (proj.low_base_threshold || 30);
    var groups = (TR.AGG && TR.AGG.banner_groups) || [];
    var cols = {};
    var qs = views.indexQuestions();
    groups.forEach(function (g) {
      qs.forEach(function (q) {
        var model;
        try { model = publishedModel(views, q.code, g.id); } catch (e) { return; }
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
    // KeyShare questions join the same scan as favourable shares: the declared
    // row's % per column vs the overall %, on the 0–100 scale, so a 5pp share
    // gap and a 0.25-point gap on a 1–5 index carry the same fraction-of-scale
    // weight the rated gaps already use. isPct drives % display downstream.
    var shareList = takeout._shares ? takeout._shares.list(views) : [];
    groups.forEach(function (g) {
      shareList.forEach(function (s) {
        var model;
        try { model = publishedModel(views, s.q.code, g.id); } catch (e) { return; }
        var row = model.rows[s.ri];
        if (!row || !row.cells) return;
        var total = row.cells[0] && row.cells[0].pct;
        if (total === null || total === undefined) return;
        model.columns.forEach(function (col, i) {
          if (i === 0) return;
          var v = row.cells[i] && row.cells[i].pct;
          if (v === null || v === undefined) return;
          if (!col.base || col.base < floor) return;
          var key = g.name + "::" + col.label;
          var c = cols[key] || (cols[key] = { column: col.label, group: g.name, base: 0, gaps: [] });
          if (col.base > c.base) c.base = col.base;
          c.gaps.push({ title: s.q.title, value: v, total: total, scaleMax: 100, isPct: true });
        });
      });
    });
    return Object.keys(cols).map(function (k) { return cols[k]; });
  }

  /** Sample size, precision, and response rate for the reliability stamp. */
  function gatherReliability(items) {
    var n = 0, nEff = null;
    items.forEach(function (l) {
      if (l.base > n) { n = l.base; nEff = l.baseEff > 0 ? l.baseEff : null; }
    });
    var conf = TR.conf || {};
    var census = typeof conf.fpcActiveReport === "function"
      ? conf.fpcActiveReport() : false;
    var labels = typeof conf.labels === "function" ? conf.labels() : {};
    var pop = (TR.AGG && TR.AGG.project && TR.AGG.project.population_size) || null;
    return {
      n: n,
      // Weighted studies size precision on the Kish effective base, exactly as
      // every significance test does; the displayed n stays the respondent count.
      moePct: typeof conf.maxMoePct === "function" && n ? conf.maxMoePct(nEff || n) : null,
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
    var census = typeof conf.fpcActiveReport === "function" && conf.fpcActiveReport();
    // Per-arm floor: in a census a subgroup is most of its own population, so the
    // analyst's reporting floor (default 5) applies; a true sample keeps n>=30.
    var floor = census ? censusFloor(proj) : (proj.low_base_threshold || 30);
    // The odd-one-out finder (the only consumer of this family) tests each cell's
    // gap against FIXED scale-point floors AND against the group's mean gap across
    // the family — both only meaningful within one comparable scale band. Restrict
    // the family to small-range rating scales (max ≤ 10): an NPS / score question
    // (±100) would otherwise clear a floor tuned for 1–5 points on a trivial wobble
    // — a fabricated "odd one out" — and its ±100 gaps would swamp the mean-gap
    // baseline. Strain/thrive keep NPS: they normalise each gap by scaleMax; this
    // family does not.
    var qs = views.indexQuestions().filter(function (q) {
      return micro.scores && micro.scores[q.code] && micro.scores[q.code].length &&
        q.type !== "nps" && touchpointMax(q) <= 10;
    });
    var shareList = takeout._shares ? takeout._shares.list(views) : [];
    var nResp = micro.n || (qs.length ? micro.scores[qs[0].code].length : 0);
    if (!nResp) return null;
    // One family, two sources: rated questions test their per-respondent index
    // scores; KeyShare questions test a 0/100 in-the-share encoding (a Welch t
    // on 0/100 IS the unpooled two-proportion z, in pp; touchpointMax(q)=100
    // puts the shared variance floor at 10pp). Share cells are marked isPct —
    // the odd-one-out finder skips them (its gap floors are scale-point tuned)
    // but the per-cell BH pass and the per-group sign test read them in full,
    // so share-heavy studies get the same never-cry-wolf gate as rated ones.
    var famQs = qs.map(function (q) {
      return { q: q, sc: micro.scores[q.code], isPct: false };
    });
    shareList.forEach(function (s) {
      var sc = takeout._shares.scoreVector(s, micro, nResp);
      if (sc) famQs.push({ q: s.q, sc: sc, isPct: true });
    });
    if (!famQs.length) return null;
    var groups = (TR.AGG && TR.AGG.banner_groups) || [];
    var cells = [], groupAgg = {}, order = [];
    groups.forEach(function (g) {
      var bv = micro.banner_vars[g.id];
      if (!bv) return;
      var codeSet = {};
      for (var r = 0; r < nResp; r++) { var cd = bv[r]; if (cd !== null && cd !== undefined && cd >= 0) codeSet[cd] = true; }
      var codes = Object.keys(codeSet).map(Number).sort(function (a, b) { return a - b; });
      var model;
      try { model = publishedModel(views, famQs[0].q.code, g.id); } catch (e) { return; }
      var cols = (model.columns || []).slice(1);                 // non-Total columns
      if (codes.length !== cols.length) return;                  // label/order mismatch -> skip banner, never mislabel
      codes.forEach(function (code, ci) {
        var label = cols[ci].label;
        famQs.forEach(function (f) {
          var q = f.q, sc = f.sc, vfloor = Math.pow(scaleSpan(q) * 0.1, 2);
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
            base: 0, below: 0, above: 0, qn: 0, qnRated: 0, gapSum: 0 });
          if (!ga.qn) order.push(gkey);
          if (gx.length > ga.base) ga.base = gx.length;
          // qn / below / above feed the per-group sign test — every cell counts.
          // gapSum stays RATED-ONLY (scale points): it becomes meanGap, the
          // odd-one-out baseline, and pp gaps would corrupt its units.
          ga.qn++;
          if (!f.isPct) { ga.qnRated++; ga.gapSum += gap; }
          if (wt.diff < 0) ga.below++; else if (wt.diff > 0) ga.above++;
          cells.push({ banner: g.name, group: label, q: q.code, qtitle: q.title, nIn: gx.length,
            gap: gap, value: gMean, total: oMean, scaleMax: touchpointMax(q),
            isPct: f.isPct,
            welchDiff: wt.diff, welchP: wt.p, flooredG: wt.flooredG, gkey: gkey });
        });
      });
    });
    if (!cells.length) return null;
    var groupsOut = order.map(function (k) {
      var ga = groupAgg[k];
      // meanGap = the group's usual gap in SCALE POINTS across rated questions
      // only (the odd-one-out baseline); 0 when the group has no rated cells.
      ga.meanGap = ga.qnRated ? ga.gapSum / ga.qnRated : 0;
      ga.dir = ga.meanGap < 0 ? "below" : "above";
      return ga;
    });
    return { cells: cells, groups: groupsOut, K: cells.length,
      groupCount: groupsOut.length, questionCount: famQs.length };
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
      var K = touchpointMax(q), sc = micro.scores[q.code];
      // Detect a 0-based scale (NPS 0–10 / raw recommend). "round(v) - 1" assumed
      // 1..K, so v=0 mapped to idx -1 and the detractor camp was dropped — a real
      // two-camp 0–10 split then read as unimodal. Keep 1..K exactly as before;
      // for a 0-based scale bin from 0 (K+1 bins) so the bottom camp is counted.
      var lo = Infinity;
      for (var i = 0; i < nResp; i++) {
        var s = sc[i]; if (s === null || s === undefined) continue;
        var sv = Math.round(s); if (sv < lo) lo = sv;
      }
      var zeroBased = isFinite(lo) && lo <= 0;
      var bins = zeroBased ? K + 1 : K, shift = zeroBased ? 0 : 1;
      var counts = new Array(bins).fill(0);
      for (var r = 0; r < nResp; r++) {
        var v = sc[r]; if (v === null || v === undefined) continue;
        var idx = Math.round(v) - shift;
        if (idx >= 0 && idx < bins) counts[idx] += weights ? weights[r] : 1;
      }
      return { code: q.code, title: q.title, counts: counts, scaleMax: bins };
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
    // Scan scope — what the engine could actually read. The read view words its
    // empty state from this, so "we scanned and found nothing" is only ever
    // claimed when something was scanned (rated indexes or KeyShare shares).
    var ratedCount = 0, shareItems = [];
    try { ratedCount = views.indexQuestions().length; } catch (e) { ratedCount = 0; }
    try { shareItems = takeout._shares ? takeout._shares.list(views) : []; } catch (e) { shareItems = []; }
    var relItems = lv.levels.concat(lv.apex);
    try {
      relItems = relItems.concat(takeout._shares.reliabilityItems(views, shareItems,
        function (code) { return publishedModel(views, code); }));
    } catch (e) { /* shares module absent — rated items alone stamp reliability */ }
    var reliability = gatherReliability(relItems);
    var lowBase = (TR.AGG && TR.AGG.project && TR.AGG.project.low_base_threshold) || 30;
    return { columns: columns, levels: lv.levels, apex: lv.apex, comove: comove, fdr: fdr,
      bimodal: bimodal, reliability: reliability, lowBaseThreshold: lowBase,
      scope: { rated: ratedCount, shares: shareItems.length } };
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
    var saved = null;
    try {
      var raw = global.localStorage && localStorage.getItem(TR.d2.storeKey(KEY));
      if (raw) saved = JSON.parse(raw) || null;
    } catch (e) { saved = null; /* island-only context */ }
    // An OWNING localStorage state (_owns — written as the full post-edit state on
    // every persist) replaces the island seed entirely, so reset() and deletions
    // survive a reload instead of the tombstone-less merge resurrecting island-
    // baked edits. A legacy state (no marker) merges over the island as before.
    if (saved && saved._owns === true && saved.version === VERSION) {
      merge(cache, saved, VERSION);
      cache._owns = true;
      return cache;
    }
    if (TR.userState && TR.userState.takeout) merge(cache, TR.userState.takeout, VERSION);
    merge(cache, saved, VERSION);
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
      // From the first edit on, the reader's copy owns the full state (island
      // included, since it was merged into the cache) — see store().
      store()._owns = true;
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
