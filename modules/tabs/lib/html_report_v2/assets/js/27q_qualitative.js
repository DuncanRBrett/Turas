/**
 * v2 Qualitative tab — pre-coded comment themes as quant + a verbatim quote drawer.
 *
 * Reads the DATA_QUAL island (TR.QUAL): per-question records keyed by the anonymous
 * index, carrying the verbatim (or null when hidden), a noteworthy tier, sentiment,
 * per-mention theme valences, and (when the demographic-cuts dial allows) the tagged
 * demographics. Themed questions show a prevalence board (% of commenters who mentioned
 * each theme, bar coloured by sentiment) and a quote drawer; raw questions show the
 * verbatim browser. Audience filtering is the global filter bar's job — composite cuts
 * (e.g. Campus = Cape Town AND Q017 = Promoter AND Year = 1st) flow in via the cut mask,
 * so there is no per-tab demographic facet row. The noteworthy-tier filter, the sentiment
 * filter (only when coded) and the verbatim-text confidentiality are honoured here.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var qual = TR.qual = TR.qual || {};
  var esc = function (s) { return (TR.fmt && TR.fmt.escapeHtml) ? TR.fmt.escapeHtml(s) : String(s == null ? "" : s); };

  var TIER_ORDER = { all: 0, noteworthy: 1, must_read: 2 };
  var SENT = { 1: "pos", 2: "neu", 3: "neg" };

  // ---- pure helpers (node-testable) -----------------------------------------

  /** Keep records at or above the active noteworthy tier. */
  qual.tierFilter = function (records, tier) {
    var min = TIER_ORDER[tier] || 0;
    return (records || []).filter(function (r) { return (r.tier || 0) >= min; });
  };

  /** Per-theme prevalence (% of the given commenters) + the pos/neu/neg valence split. */
  qual.prevalence = function (records, themes) {
    var base = (records || []).length;
    var rows = (themes || []).map(function (th) {
      var pos = 0, neu = 0, neg = 0, n = 0;
      records.forEach(function (r) {
        var v = r.themeVals && r.themeVals[String(th.id)];
        if (v == null) return;
        n++;
        if (v === 1) pos++; else if (v === 2) neu++; else if (v === 3) neg++;
      });
      return { id: th.id, label: th.label, n: n,
               pct: base ? Math.round(n / base * 100) : 0,
               pos: pos, neu: neu, neg: neg,
               net: n ? Math.round((pos - neg) / n * 100) : 0 };
    });
    rows.sort(function (a, b) { return b.n - a.n; });
    return rows;
  };

  /** Records (from a pool) that mentioned a given theme id. */
  qual.recordsForTheme = function (records, themeId) {
    return (records || []).filter(function (r) {
      return r.themeVals && r.themeVals[String(themeId)] != null;
    });
  };

  /**
   * Theme x banner crosstab, computed from comment records + the banner's column
   * membership (TR.stats.columnsFor().columns, each with a per-respondent `member`
   * Uint8Array; member == null is the Total column). The base of each column is its
   * COMMENTERS — records of this question whose idx falls in the column — so every
   * cell is a % of its column, never the grand total. Each cell carries salience
   * (% who raised the theme), the pos/mixed/neg split both ways (of the base, which
   * sums to salience; and of the mentioners, which sums to 100), the net sentiment,
   * and a vs-the-rest significance flag on the active mode's metric (salience, or —
   * in skew mode — positivity among mentioners). Columns below the disclosure
   * threshold are flagged suppressed. Pure given records + columns (+ TR.stats.propZ).
   */
  qual.themeCrosstab = function (records, themes, columns, opts) {
    opts = opts || {};
    var mode = opts.mode === "skew" ? "skew" : "salience";
    var minBase = opts.minBase > 1 ? opts.minBase : 1;
    records = records || []; themes = themes || []; columns = columns || [];
    var inCol = function (col, idx) { return col.member == null || col.member[idx] === 1; };
    var cols = columns.map(function (col) {
      var base = 0;
      for (var r = 0; r < records.length; r++) if (inCol(col, records[r].idx)) base++;
      return { label: col.label, base: base, total: col.member == null,
               suppressed: col.member != null && base > 0 && base < minBase };
    });
    var pc = function (x, b) { return b ? Math.round(x / b * 100) : 0; };
    var rows = themes.map(function (th) {
      var key = String(th.id);
      var cells = columns.map(function (col, ci) {
        var pos = 0, mix = 0, neg = 0;
        for (var r = 0; r < records.length; r++) {
          var rec = records[r];
          if (!inCol(col, rec.idx)) continue;
          var v = rec.themeVals && rec.themeVals[key];
          if (v === 1) pos++; else if (v === 2) mix++; else if (v === 3) neg++;
        }
        var men = pos + mix + neg, base = cols[ci].base;
        return { men: men, pos: pos, mix: mix, neg: neg, base: base,
          salience: pc(men, base), net: men ? Math.round((pos - neg) / men * 100) : 0,
          ofBase: { pos: pc(pos, base), mix: pc(mix, base), neg: pc(neg, base) },
          ofMen: { pos: pc(pos, men), mix: pc(mix, men), neg: pc(neg, men) }, sig: "" };
      });
      return { id: th.id, label: th.label, cells: cells, totalMen: cells[0] ? cells[0].men : 0 };
    });
    rows.sort(function (a, b) { return b.totalMen - a.totalMen; });
    var Zc = 1.96;
    rows.forEach(function (row) {
      var tot = row.cells[0];
      row.cells.forEach(function (cell, ci) {
        if (ci === 0 || cols[ci].suppressed || !TR.stats || !TR.stats.propZ) return;
        var x = mode === "skew" ? cell.pos : cell.men;
        var nn = mode === "skew" ? cell.men : cell.base;
        var X = mode === "skew" ? tot.pos : tot.men;
        var N = mode === "skew" ? tot.men : tot.base;
        if (nn <= 0 || N - nn <= 0) return;
        var z = TR.stats.propZ(x, nn, X - x, N - nn);
        if (z === null) return;
        cell.sig = z > Zc ? "up" : (z < -Zc ? "down" : "");
      });
    });
    return { columns: cols, rows: rows, mode: mode };
  };

  /** Keep records of one overall sentiment (1 pos / 2 mixed / 3 neg); null = all. */
  qual.sentimentFilter = function (records, sentiment) {
    if (sentiment == null) return records || [];
    return (records || []).filter(function (r) { return r.sentiment === sentiment; });
  };

  /** Pos / mixed / neg counts over a record pool (the sentiment chips + filter tallies). */
  qual.sentimentCounts = function (records) {
    var c = { pos: 0, neu: 0, neg: 0 };
    (records || []).forEach(function (r) {
      if (r.sentiment === 1) c.pos++; else if (r.sentiment === 2) c.neu++; else if (r.sentiment === 3) c.neg++;
    });
    return c;
  };

  /** Whether a question carries overall comment-level sentiment coding at all. Only
   *  sentiment-coded questions get the Positive/Mixed/Negative filter — a raw verbatim
   *  question, or a themed one with per-theme valence but no overall comment sentiment,
   *  has none, and would otherwise show a misleading "0 positive / 0 mixed / 0 negative"
   *  (reads as "we measured and found zero" when nothing was coded). */
  qual.hasSentiment = function (q) {
    return !!(q && q.records && q.records.some(function (r) {
      return r.sentiment === 1 || r.sentiment === 2 || r.sentiment === 3;
    }));
  };

  /**
   * Records whose respondent index passes the cut mask. The cut is the live global
   * filter (d2.state.filters): the closed->open jump shows "the comments from the
   * people in the active cut". A no-op when there is no cut or no microdata island.
   */
  qual.maskFilter = function (records, filters) {
    if (!filters || !filters.length || !TR.stats || !TR.MICRO) return records || [];
    var mask = TR.stats.mask(filters);
    return (records || []).filter(function (r) { return mask[r.idx] === 1; });
  };

  /** The closed<->open jump link for a closed/composite code, or null. */
  qual.linkFor = function (code) {
    var links = (TR.AGG && TR.AGG.project && TR.AGG.project.qualLinks) || null;
    return (links && links[code]) ? links[code] : null;
  };

  /** Comment count for a qual question code (within the cut when filters given). */
  qual.commentCount = function (qcode, filters) {
    var island = TR.QUAL;
    if (!island) return 0;
    var q = findQ(island, qcode);
    if (!q || !q.records) return 0;
    if (!filters || !filters.length) return q.records.length;
    return qual.maskFilter(q.records, filters).length;
  };

  /** The "💬 N comments" affordance for a linked closed/composite card ("" if none). */
  qual.affordanceHtml = function (code) {
    var link = qual.linkFor(code);
    if (!link) return "";
    var n = qual.commentCount(link.qcode);
    if (!n) return "";
    return '<button class="ql-jumpbtn" data-qual-jump="' + esc(code) +
      '" title="Read the ' + esc(link.title) + ' open-end comments behind this finding">' +
      "💬 " + n + " comment" + (n === 1 ? "" : "s") + "</button>";
  };

  // ---- shortlist: star a comment; survives "Save copy" -----------------------
  // Mirrors the insights/notes store: seed from the saved-copy island
  // (TR.userState.qualSaved), let the reader's own localStorage edits win, and
  // expose savedAll() so report.saveCopy embeds the set back into the island.

  var SAVED_KEY = "turas_v2_qualsaved";
  var savedCache = null;
  function savedStore() {
    if (savedCache) return savedCache;
    savedCache = {};
    if (TR.userState && TR.userState.qualSaved) {
      Object.keys(TR.userState.qualSaved).forEach(function (k) { savedCache[k] = TR.userState.qualSaved[k]; });
    }
    try {
      var raw = (typeof localStorage !== "undefined") && TR.d2 && localStorage.getItem(TR.d2.storeKey(SAVED_KEY));
      if (raw) { var own = JSON.parse(raw) || {}; Object.keys(own).forEach(function (k) { savedCache[k] = own[k]; }); }
    } catch (e) { /* island-only */ }
    return savedCache;
  }
  function savedPersist() {
    try {
      if (typeof localStorage !== "undefined" && TR.d2) {
        localStorage.setItem(TR.d2.storeKey(SAVED_KEY), JSON.stringify(savedStore()));
      }
    } catch (e) { /* storage blocked — the shortlist stays in memory */ }
  }
  function savedKey(qcode, idx) { return qcode + "#" + idx; }

  qual.isSaved = function (qcode, idx) { return !!savedStore()[savedKey(qcode, idx)]; };
  qual.toggleSave = function (qcode, idx) {
    var s = savedStore(), k = savedKey(qcode, idx);
    if (s[k]) delete s[k]; else s[k] = 1;
    savedPersist();
    return !!s[k];
  };
  qual.savedAll = function () { return savedStore(); };   // report.saveCopy embeds this
  qual.savedCount = function (qcode) {
    var s = savedStore();
    if (!qcode) return Object.keys(s).length;
    var pre = qcode + "#";
    return Object.keys(s).filter(function (k) { return k.indexOf(pre) === 0; }).length;
  };
  qual.savedFilter = function (records, qcode) {
    return (records || []).filter(function (r) { return qual.isSaved(qcode, r.idx); });
  };

  // ---- highlight a passage inside a comment (survives "Save copy") -----------
  // Stores character ranges [start,end] into the comment's exact text, keyed qcode#idx,
  // seeded from the saved-copy island + per-report localStorage (like the shortlist).
  // renderHighlighted() wraps the ranges in <mark>; the selection wiring lives in wire().

  var HL_KEY = "turas_v2_qualhl";
  var hlCache = null;
  function hlStore() {
    if (hlCache) return hlCache;
    hlCache = {};
    if (TR.userState && TR.userState.qualHighlights) {
      Object.keys(TR.userState.qualHighlights).forEach(function (k) { hlCache[k] = TR.userState.qualHighlights[k]; });
    }
    try {
      var raw = (typeof localStorage !== "undefined") && TR.d2 && localStorage.getItem(TR.d2.storeKey(HL_KEY));
      if (raw) { var own = JSON.parse(raw) || {}; Object.keys(own).forEach(function (k) { hlCache[k] = own[k]; }); }
    } catch (e) { /* island-only */ }
    return hlCache;
  }
  function hlPersist() {
    try {
      if (typeof localStorage !== "undefined" && TR.d2) localStorage.setItem(TR.d2.storeKey(HL_KEY), JSON.stringify(hlStore()));
    } catch (e) { /* storage blocked — highlights stay in memory */ }
  }
  function hlMerge(ranges) {
    var sorted = ranges.slice().sort(function (a, b) { return a[0] - b[0]; });
    var out = [];
    sorted.forEach(function (r) {
      var last = out[out.length - 1];
      if (last && r[0] <= last[1]) last[1] = Math.max(last[1], r[1]);
      else out.push([r[0], r[1]]);
    });
    return out;
  }
  qual.getHighlights = function (qcode, idx) { return hlStore()[qcode + "#" + idx] || []; };
  qual.addHighlight = function (qcode, idx, start, end) {
    if (!(end > start)) return;
    var s = hlStore(), k = qcode + "#" + idx;
    s[k] = hlMerge((s[k] || []).concat([[start, end]]));
    hlPersist();
  };
  qual.removeHighlight = function (qcode, idx, start) {
    var s = hlStore(), k = qcode + "#" + idx;
    var arr = (s[k] || []).filter(function (r) { return r[0] !== start; });
    if (arr.length) s[k] = arr; else delete s[k];
    hlPersist();
  };
  qual.highlightsAll = function () { return hlStore(); };   // report.saveCopy embeds this

  /** Wrap the stored ranges in <mark> (escaping each piece) — pure, node-testable. */
  qual.renderHighlighted = function (text, ranges) {
    if (text == null) return "";
    if (!ranges || !ranges.length) return esc(text);
    var sorted = ranges.slice().sort(function (a, b) { return a[0] - b[0]; });
    var out = "", pos = 0;
    sorted.forEach(function (rg) {
      var a = Math.max(pos, rg[0]), b = Math.max(a, Math.min(rg[1], text.length));
      if (a > pos) out += esc(text.slice(pos, a));
      if (b > a) out += '<mark class="ql-hl" data-s="' + rg[0] + '">' + esc(text.slice(a, b)) + "</mark>";
      pos = Math.max(pos, b);
    });
    if (pos < text.length) out += esc(text.slice(pos));
    return out;
  };

  /** The pool a sentiment pick filters: theme -> tier -> shortlist (everything but
   *  the sentiment filter itself), so the sentiment buttons can show "if I click this,
   *  N comments". */
  qual.poolBeforeSentiment = function (q, st, audience) {
    var pool = (q.type === "themed" && st.theme != null) ? qual.recordsForTheme(audience, st.theme) : audience;
    var records = qual.tierFilter(pool, st.tier);
    if (st.savedOnly) records = qual.savedFilter(records, q.code);
    return records;
  };

  /** The records the drawer is currently showing: theme -> tier -> sentiment ->
   *  shortlist, on top of the already cut+facet-filtered audience. Shared by the
   *  drawer + export so the table and the export never drift. */
  qual.visibleRecords = function (q, st, audience) {
    var pool = qual.poolBeforeSentiment(q, st, audience);
    // Ignore a sentiment pick carried over from a coded question (the control is hidden
    // here, so a stale selection must not silently empty an un-coded question's list).
    return qual.hasSentiment(q) ? qual.sentimentFilter(pool, st.sentiment) : pool;
  };

  // ---- export the visible comments to Excel (client-side) --------------------

  var SENT_LABEL = { 1: "Positive", 2: "Mixed", 3: "Negative" };
  var TIER_LABEL = { 2: "Must-read", 1: "Noteworthy" };

  /** Export matrix: ID + demographics + Noteworthy + Sentiment + Themes + Verbatim.
   *  Pure + node-testable. Hidden verbatims export as "[hidden]" (the confidentiality
   *  dial is honoured — no raw text leaks when text was withheld). When safeDemos is
   *  false (the audience is below the disclosure threshold) the demographic columns export
   *  as "[hidden]" too, so a small cut can't be exported with identifying tags attached. */
  qual.exportRows = function (island, q, records, safeDemos) {
    if (safeDemos === undefined) safeDemos = true;
    var dims = ((island && island.demographics) || []).map(function (d) { return d.label; });
    var byId = {};
    (q.themes || []).forEach(function (t) { byId[String(t.id)] = t.label; });
    var header = ["ID"].concat(dims).concat(["Noteworthy", "Sentiment", "Themes", "Verbatim"]);
    var out = [header];
    (records || []).forEach(function (r) {
      var demos = dims.map(function (lbl) {
        if (!safeDemos) return "[hidden]";
        return (r.demos && r.demos[lbl] != null) ? r.demos[lbl] : "";
      });
      var themes = Object.keys(r.themeVals || {}).map(function (id) { return byId[id] || ("#" + id); }).join("; ");
      var text = (r.text == null) ? "[hidden]" : r.text;
      out.push([r.idx].concat(demos).concat([TIER_LABEL[r.tier] || "", SENT_LABEL[r.sentiment] || "", themes, text]));
    });
    return out;
  };

  qual.exportXlsx = function (island, q, records) {
    if (!TR.xlsx || !TR.xlsx.download) return;
    var safeDemos = !(TR.disclosure && TR.disclosure.audienceTooSmall());
    var base = (TR.fmt && TR.fmt.slug) ? TR.fmt.slug(q.title || q.code || "comments") : "comments";
    TR.xlsx.download(base + "_comments", "Comments", qual.exportRows(island, q, records, safeDemos));
  };

  function findQ(island, code) {
    var qs = island.questions || [];
    for (var i = 0; i < qs.length; i++) if (qs[i].code === code) return qs[i];
    return null;
  }

  // ---- render ----------------------------------------------------------------

  // ---- jump (a closed/composite card -> these comments, in the active cut) ----

  /** The jump context when we arrived from a closed/composite card (else null). */
  qual.jumpContext = function () {
    var d2 = TR.d2, from = d2.state.qualFrom;
    if (!from) return null;
    var src = d2.questionByCode ? d2.questionByCode(from) : null;
    return {
      from: from,
      fromTitle: src ? (src.code + " " + src.title) : from,
      filters: (d2.state.filters || []).slice(),                  // the active cut
      desc: (d2.filterDescription && d2.filterDescription()) || ""
    };
  };

  /** Clear the jump breadcrumb context (the cut/global filter is left untouched). */
  qual.clearJump = function () {
    if (!TR.d2) return;
    TR.d2.state.qualFrom = null;
    TR.d2.state.qualFromTab = null;
  };

  /** Jump from a linked closed/composite card to its open-end comments. */
  qual.jumpTo = function (code) {
    var link = qual.linkFor(code);
    if (!link) return;
    var d2 = TR.d2, s = d2.state;
    s.qualQ = link.qcode;                       // focus the linked open-end
    if (qual._state) qual._state.theme = null;
    s.qualFrom = code;                          // breadcrumb + back target
    s.qualFromTab = (s.tab === "dashboard") ? "dashboard" : "crosstabs";
    s.tab = "qualitative";
    // a NEW history entry, so browser-back returns to the closed view's hash
    if (typeof history !== "undefined" && history.pushState) {
      try { history.pushState(null, "", d2.encodeHash()); } catch (e) {}
    }
    TR.shell.route();
  };

  /** Breadcrumb back: return to the closed view we jumped from. */
  qual.back = function () {
    var s = TR.d2.state, fromTab = s.qualFromTab || "crosstabs";
    qual.clearJump();
    if (typeof history !== "undefined" && history.length > 1 && history.back) {
      history.back();                           // pops to the closed view's hash
    } else {
      s.tab = fromTab; TR.shell.route();        // headless / no-history fallback
    }
  };

  // ---- render ----------------------------------------------------------------

  qual.render = function (host) {
    var island = TR.QUAL, d2 = TR.d2;
    if (!island || !island.questions || !island.questions.length) {
      host.innerHTML = '<div class="page"><p class="ql-empty">No qualitative data in this report.</p></div>';
      return;
    }
    if (!qual._state) {
      qual._state = { tier: TIER_ORDER[island.noteworthyDefault] != null ? island.noteworthyDefault : "all",
                      theme: null, sentiment: null, railGroups: {}, railHidden: false, savedOnly: false,
                      themeView: "overview", xmode: "salience", xbanner: null, xexpand: null, xcounts: false };
    }
    var st = qual._state;
    // The focused open-end lives in d2.state so it round-trips through the URL hash
    // (deep links + the closed->open jump). Fall back to the first question.
    if (!d2.state.qualQ || !findQ(island, d2.state.qualQ)) d2.state.qualQ = island.questions[0].code;
    var q = findQ(island, d2.state.qualQ) || island.questions[0];
    d2.state.qualQ = q.code;

    // The cut is the live global filter — the ONE audience control. The filter bar is
    // visible on this tab and re-renders the comments, so the prevalence + drawer always
    // reflect the active filter ("the comments from the people in this cut"). Composite
    // filters (Campus = Cape Town AND Q017 = Promoter AND Year = 1st) all flow here, which
    // is why the qual tab no longer carries its own demographic facet row. A jump
    // additionally pre-sets the filter and shows a breadcrumb back to the closed finding.
    var cutFilters = (d2.state.filters && d2.state.filters.length) ? d2.state.filters : null;
    var jump = qual.jumpContext();

    var audience = qual.maskFilter(q.records, cutFilters);
    qual._view = { island: island, q: q, audience: audience };   // for the export handler
    host.innerHTML =
      '<div class="ql-wrap' + (st.railHidden ? " norail" : "") + '">' + railHtml(island, st) +
        '<div class="ql-main">' +
          '<button class="ql-railtoggle" title="Show/hide the question list">⟨⟩ Questions</button>' +
          breadcrumbHtml(jump) +
          mainHtml(island, q, st, audience) +
        '</div></div>';
    wire(host, island);
  };

  function breadcrumbHtml(jump) {
    if (!jump) return "";
    var cut = jump.desc
      ? '<span class="ql-cut">cut: ' + esc(jump.desc) + "</span>"
      : '<span class="ql-cut all">all respondents</span>';
    return '<div class="ql-crumb"><button class="ql-back" data-qual-back>‹ Back to ' +
      esc(jump.fromTitle) + "</button>" +
      '<span class="ql-crumblbl">comments behind this finding</span>' + cut + "</div>";
  }

  function railHtml(island, st) {
    var groups = [
      { key: "themed", title: "Themed", qs: island.questions.filter(function (q) { return q.type === "themed"; }) },
      { key: "raw", title: "Verbatim-only", qs: island.questions.filter(function (q) { return q.type !== "themed"; }) }
    ].filter(function (g) { return g.qs.length; });
    var html = groups.map(function (g) {
      var items = g.qs.map(function (q) {
        var sel = q.code === TR.d2.state.qualQ ? ' aria-current="true"' : "";
        var glyph = q.type === "themed" ? "▦" : "❝";
        return '<button class="ql-railitem" data-q="' + esc(q.code) + '"' + sel + '>' +
          '<span class="ql-glyph">' + glyph + '</span>' +
          '<span class="ql-railtitle">' + esc(q.title) + '</span>' +
          '<span class="ql-railn">' + (q.base ? q.base.answered : 0) + '</span></button>';
      }).join("");
      // Reuse the Crosstabs sidebar's collapsible-group classes for an identical feel.
      return '<div class="catgrp' + (st.railGroups[g.key] ? " collapsed" : "") + '">' +
        '<button class="cathdr" data-railtoggle="' + g.key + '">' +
        '<span class="catchev">▼</span>' + esc(g.title) +
        ' <span class="catn">(' + g.qs.length + ')</span></button>' +
        '<div class="catitems">' + items + '</div></div>';
    }).join("");
    return '<nav class="ql-rail" aria-label="Open-end questions">' + html + '</nav>';
  }

  function mainHtml(island, q, st, audience) {
    // The chart (overview) sits ABOVE the controls; tier/sentiment/shortlist sit directly
    // above the comment list they filter, so it's clear they narrow the list, not the chart.
    // Demographic filtering is the global audience bar's job (composite filters), so there
    // is no per-tab facet row here. Themed questions get an Overview / Crosstab switch — the
    // crosstab supplements the prevalence board, it does not replace it (Overview is default).
    var chart = "";
    if (q.type === "themed") {
      chart = viewToggleHtml(st) +
        (st.themeView === "crosstab" && hasBanner()
          ? crosstabHtml(island, q, st, audience)
          : prevalenceHtml(q, st, audience));
    }
    return headerHtml(island, q, audience) + chart +
      controlsHtml(q, st, audience) +
      drawerHtml(island, q, st, audience) + footerHtml(island, q);
  }

  function headerHtml(island, q, audience) {
    var asked = q.base ? q.base.answered : 0;
    var shown = audience.length;
    var n = (shown === asked) ? (asked + " answered") : (shown + " of " + asked + " answered");
    var badge = q.type === "themed" ? "THEMED" : "VERBATIM-ONLY";
    var shield = island.textMode === "full" ? "" :
      '<span class="ql-shield" title="Verbatim confidentiality">🛡 ' + esc(island.textMode) + '</span>';
    return '<header class="ql-head"><h2 class="ql-title">' + esc(q.title) + '</h2>' +
      '<div class="ql-meta"><span class="ql-badge">' + badge + '</span>' +
      '<span class="ql-base">' + n + '</span>' + shield + '</div></header>';
  }

  // One controls row: the noteworthy tier, the sentiment filter (with live counts),
  // and — next to them — the shortlist toggle (per question) + Excel export.
  function controlsHtml(q, st, audience) {
    var tierOpts = [["all", "All"], ["noteworthy", "Noteworthy+"], ["must_read", "Must-read"]];
    var tier = '<div class="ql-seg" role="tablist" aria-label="Noteworthy filter">' +
      tierOpts.map(function (o) {
        return '<button class="ql-segbtn' + (st.tier === o[0] ? " on" : "") +
          '" data-tier="' + o[0] + '">' + o[1] + "</button>";
      }).join("") + "</div>";

    // The sentiment filter only appears when the question was actually sentiment-coded;
    // otherwise it would read "0 positive / 0 mixed / 0 negative" as if measured (it wasn't).
    var sent = "";
    if (qual.hasSentiment(q)) {
      var sc = qual.sentimentCounts(qual.poolBeforeSentiment(q, st, audience));
      var total = sc.pos + sc.neu + sc.neg;
      var sentOpts = [["", "All", total, ""], ["1", "Positive", sc.pos, "pos"],
                      ["2", "Mixed", sc.neu, "neu"], ["3", "Negative", sc.neg, "neg"]];
      var cur = st.sentiment == null ? "" : String(st.sentiment);
      sent = '<div class="ql-seg sentseg" role="tablist" aria-label="Sentiment filter">' +
        sentOpts.map(function (o) {
          return '<button class="ql-segbtn ' + o[3] + (cur === o[0] ? " on" : "") +
            '" data-sent="' + o[0] + '">' + o[1] +
            ' <span class="ql-segn">' + o[2] + "</span></button>";
        }).join("") + "</div>";
    }

    var savedN = qual.savedCount(q.code);
    var actions = '<div class="ql-actions">' +
      '<button class="ql-savedonly' + (st.savedOnly ? " on" : "") + '" data-savedonly aria-pressed="' +
        st.savedOnly + '" title="Show only the comments you have shortlisted for this question">' +
        "★ Shortlist" + (savedN ? " (" + savedN + ")" : "") + "</button>" +
      '<button class="ql-export" data-qual-export title="Download the comments shown here as an Excel file">' +
        "⬇ Export</button></div>";
    // Labelled "Filter the comments below" — these narrow the LIST, not the chart above.
    return '<div class="ql-controls"><span class="ql-ctrllbl">Filter the comments below:</span>' +
      tier + sent + actions + "</div>";
  }

  function prevalenceHtml(q, st, audience) {
    var rows = qual.prevalence(audience, q.themes);   // ranked by salience (volume) desc
    if (!rows.length || !audience.length) return '<p class="ql-empty">No coded themes for this selection.</p>';
    // 100% (proportion) diverging sentiment bars: every theme's bar is the SAME width
    // (W% of the track), pivoted so the neutral midpoint sits on a shared zero line. The
    // lean still reads as valence, but because the bar is proportion (not volume) no
    // dominant theme can compress the others — every segment is generous, so the counts
    // fit inside. Salience is the % + the ranking, not the bar length.
    var W = 48;                                       // bar width as % of track (<=50 so extremes never overflow)
    var seg = function (cls, count, tot) {
      if (!count) return "";
      var label = (count / tot * W) >= 4 ? '<span class="ql-bn">' + count + "</span>" : "";  // shows when wide enough
      return '<span class="ql-bseg ' + cls + '" style="flex:' + count + '">' + label + "</span>";
    };
    var body = rows.map(function (r) {
      var sel = r.id === st.theme ? " on" : "";
      var tot = r.pos + r.neu + r.neg || 1;           // sentiment-coded mentions of this theme
      var f = (r.neg + r.neu / 2) / tot;              // fraction of the bar that sits left of zero
      var bar = '<span class="ql-dtrack"><span class="ql-dzero"></span>' +
        '<span class="ql-dbar" style="left:' + (50 - f * W) + "%;width:" + W + '%">' +
          seg("neg", r.neg, tot) + seg("neu", r.neu, tot) + seg("pos", r.pos, tot) + "</span></span>";
      var netCls = r.net > 0 ? "pos" : r.net < 0 ? "neg" : "neu";
      return '<button class="ql-prow' + sel + '" data-theme="' + r.id + '" ' +
          'title="' + esc(r.label) + " — " + r.n + " of " + audience.length +
          " raised it unprompted (" + r.pos + " positive, " + r.neu + " mixed, " + r.neg + ' negative)">' +
        '<span class="ql-plabel">' + esc(r.label) + "</span>" + bar +
        '<span class="ql-ppct">' + r.pct + '%<span class="ql-pn">n=' + r.n + "</span></span>" +
        '<span class="ql-pnet ' + netCls + '">net ' + (r.net > 0 ? "+" : "") + r.net + "%</span>" +
        "</button>";
    }).join("");
    var axis = '<div class="ql-daxis"><span></span>' +
      '<span class="ql-dends"><span>← more negative</span><span>more positive →</span></span></div>';
    return '<div class="ql-board"><div class="ql-boardhd">What people raised' +
      '<span class="ql-hint"> — ranked by salience (% of the ' + audience.length +
      ' who raised each theme <b>unprompted</b>, right). Each bar is the sentiment <i>mix</i> ' +
      'of that theme’s comments, so every theme is equal width and the lean shows the balance: ' +
      '<b class="qc-neg">negative</b> left, <b class="qc-pos">positive</b> right, ' +
      '<b class="qc-neu">mixed</b> centre; net = net sentiment %. ' +
      "Click a theme to read its comments.</span>" +
      "</div>" + axis + '<div class="ql-boardgrid">' + body + "</div></div>";
  }

  // ---- theme x banner crosstab (supplements the prevalence board) ------------
  // An "Overview / Crosstab" switch sits above the chart: Overview is the diverging
  // prevalence board (default, unchanged); Crosstab is the theme x banner table —
  // salience + net sentiment per column, expandable to the pos/mixed/neg split,
  // with an analyst insight that pins to the Story alongside the table.

  function hasBanner() {
    return !!(TR.AGG && TR.AGG.banner_groups && TR.AGG.banner_groups.length &&
      TR.stats && TR.stats.columnsFor);
  }
  function xtabBannerId(st) {
    var groups = (TR.AGG && TR.AGG.banner_groups) || [];
    if (st.xbanner && groups.some(function (g) { return g.id === st.xbanner; })) return st.xbanner;
    var cur = TR.d2 && TR.d2.state && TR.d2.state.banner;
    if (cur && groups.some(function (g) { return g.id === cur; })) return cur;
    return groups.length ? groups[0].id : null;
  }
  function viewToggleHtml(st) {
    if (!hasBanner()) return "";
    var v = st.themeView === "crosstab" ? "crosstab" : "overview";
    var btn = function (k, l) {
      return '<button class="ql-segbtn' + (v === k ? " on" : "") + '" data-themeview="' + k + '">' + l + "</button>";
    };
    return '<div class="ql-seg ql-viewtog" role="tablist" aria-label="Theme view">' +
      btn("overview", "Overview") + btn("crosstab", "Crosstab by banner") + "</div>";
  }
  function xSig(sig) {
    return sig === "up" ? ' <span class="ql-xsig up" title="significantly higher vs the rest">▲</span>'
         : sig === "down" ? ' <span class="ql-xsig down" title="significantly lower vs the rest">▼</span>' : "";
  }
  function xCell(cell, mode, suppressed, counts) {
    if (suppressed) return '<td class="ql-xc supp"><span title="hidden — column below the confidentiality threshold">·</span></td>';
    var netCls = cell.net > 0 ? "pos" : cell.net < 0 ? "neg" : "mix";
    var net = '<span class="ql-xnet ' + netCls + '">net ' + (cell.net > 0 ? "+" : "") + cell.net + "%</span>";
    if (mode === "skew") {
      var raised = counts ? (cell.men + " raised") : (cell.salience + "% raised");
      return '<td class="ql-xc"><span class="ql-xhead ' + netCls + '">' + (cell.net > 0 ? "+" : "") +
        cell.net + "%" + xSig(cell.sig) + '</span><span class="ql-xsub">' + raised + "</span></td>";
    }
    var head = counts ? cell.men : (cell.salience + "%");
    return '<td class="ql-xc"><span class="ql-xhead">' + head + xSig(cell.sig) + "</span>" + net + "</td>";
  }
  function crosstabHtml(island, q, st, audience) {
    var bannerId = xtabBannerId(st);
    if (!bannerId) return "";
    if (TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall()) {
      return '<div class="ql-xtab card"><p class="ql-disclosure">🛡 ' + esc(TR.disclosure.note()) + "</p></div>";
    }
    var spec = TR.stats.columnsFor(bannerId);
    var minBase = (TR.disclosure && TR.disclosure.minBase) ? TR.disclosure.minBase() : 1;
    var mode = st.xmode === "skew" ? "skew" : "salience";
    var counts = !!st.xcounts;
    var xt = qual.themeCrosstab(audience, q.themes, spec.columns, { mode: mode, minBase: minBase });
    var groups = (TR.AGG && TR.AGG.banner_groups) || [];
    var bannerName = (groups.filter(function (g) { return g.id === bannerId; })[0] || {}).name || "banner";
    var clip = function (s) { return (TR.charts && TR.charts.clip) ? TR.charts.clip(s, 16) : s; };
    var bsel = '<select class="ql-xbanner" data-xbanner aria-label="Cross by banner">' + groups.map(function (g) {
      return '<option value="' + esc(g.id) + '"' + (g.id === bannerId ? " selected" : "") + ">" + esc(g.name) + "</option>";
    }).join("") + "</select>";
    var modeSeg = '<div class="ql-seg" role="tablist" aria-label="Crosstab metric">' +
      '<button class="ql-segbtn' + (mode === "salience" ? " on" : "") + '" data-xmode="salience">Salience</button>' +
      '<button class="ql-segbtn' + (mode === "skew" ? " on" : "") + '" data-xmode="skew">Sentiment skew</button></div>';
    var head = '<tr><th class="ql-xhl">Theme<span class="ql-xhb">ranked by salience</span></th>' +
      xt.columns.map(function (c) {
        return "<th>" + esc(clip(c.label)) + '<span class="ql-xhb">' +
          (c.suppressed ? "n&lt;" + minBase : "n=" + c.base) + "</span></th>";
      }).join("") + "</tr>";
    var subRow = function (row, lbl, cls, pick) {
      return '<tr class="ql-xsub2"><td class="ql-xhl"><span class="' + cls + '">' + lbl + "</span></td>" +
        row.cells.map(function (cell, ci) {
          if (xt.columns[ci].suppressed) return '<td class="ql-xc supp"><span>·</span></td>';
          var v = counts ? cell[pick] : ((mode === "skew" ? cell.ofMen[pick] : cell.ofBase[pick]) + "%");
          return '<td class="ql-xc"><span class="ql-xsubv">' + v + "</span></td>";
        }).join("") + "</tr>";
    };
    var body = xt.rows.map(function (row) {
      var expanded = st.xexpand === row.id;
      var main = '<tr class="ql-xrow' + (st.theme === row.id ? " on" : "") + '" data-xtheme="' + row.id + '">' +
        '<td class="ql-xhl"><span class="ql-xchev">' + (expanded ? "▾" : "▸") + "</span> " + esc(row.label) + "</td>" +
        row.cells.map(function (cell, ci) { return xCell(cell, mode, xt.columns[ci].suppressed, counts); }).join("") + "</tr>";
      if (!expanded) return main;
      return main + subRow(row, "positive", "qc-pos", "pos") + subRow(row, "mixed", "qc-neu", "mix") +
        subRow(row, "negative", "qc-neg", "neg");
    }).join("");
    var insKey = q.code + ":xtab";
    var insTxt = (TR.insights && TR.insights.get) ? TR.insights.get(insKey, bannerId) : "";
    var pinCtx = "Themes by " + bannerName + " · " + (mode === "skew" ? "sentiment skew" : "salience");
    var modeLabel = mode === "skew"
      ? "net sentiment of those who raised each theme (of mentioners)"
      : "% of each column who raised each theme";
    var countsBox = '<label class="ql-xcounts"><input type="checkbox" data-xcounts' +
      (counts ? " checked" : "") + "> Counts</label>";
    return '<section class="ql-xtab card" data-snap-card>' +
      '<div class="ql-xtop snap-pin"><span class="ql-xlbl">Cross themes by</span>' + bsel + modeSeg + countsBox +
        '<span class="ql-xspacer"></span><button class="ql-xpin" data-snap-pin ' +
        'data-snap-source="qualitative" data-snap-title="' + esc(q.title + " — themes by " + bannerName) +
        '" data-snap-context="' + esc(pinCtx) + '">📌 Pin to story</button></div>' +
      '<div class="ql-xcap">Themes × ' + esc(bannerName) + " — " + esc(modeLabel) +
        ". Each cell is a % of its column (commenters)" + (counts ? ", shown as counts" : "") +
        "; click a theme for its split + comments.</div>" +
      '<div class="ql-xscroll"><table class="ql-xtable">' + head + body + "</table></div>" +
      '<div class="insight"><div class="insight-head">Analyst insight</div>' +
      '<textarea class="ql-xinsight" data-xinsight="' + esc(insKey) +
      '" placeholder="What does this cut tell you? (pins to the Story with the table)">' + esc(insTxt) +
      "</textarea></div></section>";
  }

  var SENT_WORD = { 1: "Positive", 2: "Mixed", 3: "Negative" };

  function drawerHtml(island, q, st, audience) {
    var records = qual.visibleRecords(q, st, audience);
    // Disclosure control: when a composite filter narrows the audience below the
    // confidentiality threshold, the per-comment demographic tags are withheld (a quote
    // plus a demographic profile identifies a person on a small sample). The threshold is
    // on the respondent audience, so setting it to the full sample size hides tags on any
    // sub-cut — only the full-sample view shows them.
    var safeDemos = !(TR.disclosure && TR.disclosure.audienceTooSmall());
    var notice = safeDemos ? "" :
      '<div class="ql-disclosure" role="note">🛡 ' + esc(TR.disclosure.note()) + "</div>";
    var caption;
    if (st.savedOnly) {
      caption = "Shortlisted comments";
    } else if (q.type === "themed" && st.theme != null) {
      var th = (q.themes || []).filter(function (t) { return t.id === st.theme; })[0];
      caption = 'Comments mentioning “' + esc(th ? th.label : "") + '”';
    } else {
      caption = q.type === "themed" ? "All comments (pick a theme above to filter)" : "Comments";
    }
    if (st.sentiment != null && qual.hasSentiment(q)) caption = (SENT_WORD[st.sentiment] || "") + " · " + caption;
    var cards = records.length
      ? records.map(function (r) { return quoteCard(r, q.code, safeDemos); }).join("")
      : '<p class="ql-empty">' + (st.savedOnly
          ? "No shortlisted comments yet — use ＋ Shortlist on a comment."
          : "No comments for this selection.") + "</p>";
    return '<div class="ql-drawer">' + notice + '<div class="ql-drawerhd">' + caption +
      ' <span class="ql-hint">(' + records.length + ")</span></div>" + cards + "</div>";
  }

  function quoteCard(r, qcode, safeDemos) {
    var sent = SENT[r.sentiment] || "neu";
    var text = (r.text == null)
      ? '<span class="ql-hidden">[quote hidden in this copy]</span>'
      : qual.renderHighlighted(r.text, qual.getHighlights(qcode, r.idx));   // select-to-highlight
    var star = r.tier >= 2 ? '<span class="ql-star must" title="must-read">★</span>'
             : r.tier >= 1 ? '<span class="ql-star" title="noteworthy">★</span>' : '';
    var tags = (safeDemos && r.demos ? Object.keys(r.demos) : []).filter(function (k) { return r.demos[k] != null; })
      .map(function (k) { return '<span class="ql-tag">' + esc(r.demos[k]) + '</span>'; }).join("");
    var saved = qual.isSaved(qcode, r.idx);
    var save = '<button class="ql-save' + (saved ? " on" : "") + '" data-qual-save="' +
      esc(qcode) + "#" + esc(r.idx) + '" aria-pressed="' + saved + '" title="' +
      (saved ? "Remove from your shortlist" : "Add to your shortlist") + '">' +
      (saved ? "✓ Shortlisted" : "＋ Shortlist") + "</button>";
    return '<div class="ql-quote ' + sent + '" data-hl-key="' + esc(qcode) + "#" + esc(r.idx) + '">' + star +
      '<div class="ql-qbody"><span class="ql-qtext">' + text + '</span>' +
      (tags ? '<div class="ql-tags">' + tags + '</div>' : '') + '</div>' +
      '<div class="ql-qfoot">' + save + '<span class="ql-qid">#' + esc(r.idx) + "</span></div></div>";
  }

  function footerHtml(island, q) {
    var dropped = q.meta && q.meta.dropped_codes ? q.meta.dropped_codes : 0;
    var bits = [(q.base ? q.base.answered : 0) + " comments",
                island.textMode !== "hidden" ? "✎ select text in a comment to highlight a passage" : null,
                q.type === "themed" ? "themes are salience (raised unprompted), not prompted incidence" : null,
                island.demographicCuts === "block" ? "demographic cuts blocked" : null,
                dropped ? (dropped + " stray code(s) quarantined") : null,
                "verbatims shown by ID — never model-authored"];
    return '<footer class="ql-foot">' + bits.filter(Boolean).join(" · ") + '</footer>';
  }

  // ---- interaction -----------------------------------------------------------

  function wire(host, island) {
    var st = qual._state;
    host.querySelectorAll(".ql-railitem").forEach(function (b) {
      b.addEventListener("click", function () {
        TR.d2.state.qualQ = b.getAttribute("data-q");
        st.theme = null;
        qual.clearJump();                 // leaving the jumped open-end drops the cut breadcrumb
        qual.render(host);
      });
    });
    var back = host.querySelector("[data-qual-back]");
    if (back) back.addEventListener("click", function () { qual.back(); });
    host.querySelectorAll(".cathdr[data-railtoggle]").forEach(function (b) {
      b.addEventListener("click", function () {
        var k = b.getAttribute("data-railtoggle");
        st.railGroups[k] = !st.railGroups[k];      // collapse/expand this group
        qual.render(host);
      });
    });
    var toggle = host.querySelector(".ql-railtoggle");
    if (toggle) toggle.addEventListener("click", function () { st.railHidden = !st.railHidden; qual.render(host); });
    host.querySelectorAll("[data-tier]").forEach(function (b) {
      b.addEventListener("click", function () { st.tier = b.getAttribute("data-tier"); qual.render(host); });
    });
    host.querySelectorAll("[data-sent]").forEach(function (b) {
      b.addEventListener("click", function () {
        var v = b.getAttribute("data-sent");
        st.sentiment = v === "" ? null : parseInt(v, 10);
        qual.render(host);
      });
    });
    host.querySelectorAll(".ql-prow").forEach(function (b) {
      b.addEventListener("click", function () {
        var id = parseInt(b.getAttribute("data-theme"), 10);
        st.theme = (st.theme === id) ? null : id;   // toggle
        qual.render(host);
      });
    });
    // theme x banner crosstab: view switch, banner + metric, row expand, insight
    host.querySelectorAll("[data-themeview]").forEach(function (b) {
      b.addEventListener("click", function () { st.themeView = b.getAttribute("data-themeview"); qual.render(host); });
    });
    host.querySelectorAll("[data-xbanner]").forEach(function (sel) {
      sel.addEventListener("change", function () { st.xbanner = sel.value; qual.render(host); });
    });
    host.querySelectorAll("[data-xmode]").forEach(function (b) {
      b.addEventListener("click", function () { st.xmode = b.getAttribute("data-xmode"); qual.render(host); });
    });
    host.querySelectorAll("[data-xcounts]").forEach(function (cb) {
      cb.addEventListener("change", function () { st.xcounts = cb.checked; qual.render(host); });
    });
    host.querySelectorAll(".ql-xrow").forEach(function (b) {
      b.addEventListener("click", function () {
        var id = parseInt(b.getAttribute("data-xtheme"), 10);
        st.theme = id;                                   // select the theme (drawer follows)
        st.xexpand = (st.xexpand === id) ? null : id;    // toggle its pos/mixed/neg split
        qual.render(host);
      });
    });
    host.querySelectorAll("[data-xinsight]").forEach(function (ta) {
      ta.addEventListener("input", function () {
        if (TR.insights && TR.insights.set) TR.insights.set(ta.getAttribute("data-xinsight"), ta.value, xtabBannerId(st));
      });
    });
    // shortlist: star a comment / show only the shortlist / export the visible set
    host.querySelectorAll("[data-qual-save]").forEach(function (b) {
      b.addEventListener("click", function () {
        var v = b.getAttribute("data-qual-save"), at = v.lastIndexOf("#");
        qual.toggleSave(v.slice(0, at), parseInt(v.slice(at + 1), 10));
        qual.render(host);
      });
    });
    var so = host.querySelector("[data-savedonly]");
    if (so) so.addEventListener("click", function () { st.savedOnly = !st.savedOnly; qual.render(host); });
    var ex = host.querySelector("[data-qual-export]");
    if (ex) ex.addEventListener("click", function () {
      var v = qual._view;
      if (v) qual.exportXlsx(v.island, v.q, qual.visibleRecords(v.q, st, v.audience));
    });
    wireHighlights(host);
  }

  // ---- highlight selection wiring (select text -> a "Highlight" chip) ---------

  var _hlPop = null;
  function hlRemovePop() { if (_hlPop) { _hlPop.remove(); _hlPop = null; } }

  function closestQtext(node) {
    var el = node && (node.nodeType === 1 ? node : node.parentElement);
    return el && el.closest ? el.closest(".ql-qtext") : null;
  }

  /** Character offset of (node, nodeOffset) within el's visible text (== the record
   *  text, since esc() decodes back on display), so ranges map to r.text offsets. */
  function hlOffset(el, node, nodeOffset) {
    var r = document.createRange();
    r.selectNodeContents(el);
    try { r.setEnd(node, nodeOffset); } catch (e) { return -1; }
    return r.toString().length;
  }

  function hlShowPop(rect, onApply) {
    hlRemovePop();
    if (typeof document === "undefined") return;
    var b = document.createElement("button");
    b.className = "ql-hlpop";
    b.textContent = "✎ Highlight";
    b.style.left = Math.round(rect.left + rect.width / 2) + "px";
    b.style.top = Math.round(rect.top) + "px";
    b.addEventListener("mousedown", function (e) { e.preventDefault(); });   // keep the selection alive
    b.addEventListener("click", function (e) { e.stopPropagation(); onApply(); });
    document.body.appendChild(b);
    _hlPop = b;
  }

  function wireHighlights(host) {
    var drawer = host.querySelector(".ql-drawer");
    if (!drawer || typeof window === "undefined") return;
    // Select a passage -> offer to highlight it (within a single comment's text).
    drawer.addEventListener("mouseup", function () {
      hlRemovePop();
      var sel = window.getSelection && window.getSelection();
      if (!sel || sel.isCollapsed || !sel.rangeCount) return;
      var range = sel.getRangeAt(0);
      var qt = closestQtext(range.startContainer);
      if (!qt || qt !== closestQtext(range.endContainer)) return;     // must stay within one comment
      var card = qt.closest("[data-hl-key]");
      if (!card) return;
      var start = hlOffset(qt, range.startContainer, range.startOffset);
      var end = hlOffset(qt, range.endContainer, range.endOffset);
      if (start < 0 || end <= start) return;
      var key = card.getAttribute("data-hl-key"), at = key.lastIndexOf("#");
      hlShowPop(range.getBoundingClientRect(), function () {
        qual.addHighlight(key.slice(0, at), parseInt(key.slice(at + 1), 10), start, end);
        hlRemovePop();
        qual.render(host);
      });
    });
    // Click an existing highlight to remove it (ignored mid-selection).
    drawer.addEventListener("click", function (e) {
      var m = e.target.closest && e.target.closest("mark.ql-hl");
      if (!m) return;
      var sel = window.getSelection && window.getSelection();
      if (sel && !sel.isCollapsed) return;
      var card = m.closest("[data-hl-key]");
      if (!card) return;
      var key = card.getAttribute("data-hl-key"), at = key.lastIndexOf("#");
      qual.removeHighlight(key.slice(0, at), parseInt(key.slice(at + 1), 10), parseInt(m.getAttribute("data-s"), 10));
      qual.render(host);
    });
  }
})(typeof window !== "undefined" ? window : globalThis);
