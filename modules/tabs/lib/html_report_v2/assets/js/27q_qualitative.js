/**
 * v2 Qualitative tab — pre-coded comment themes as quant + a verbatim quote drawer.
 *
 * Reads the DATA_QUAL island (TR.QUAL): per-question records keyed by the anonymous
 * index, carrying the verbatim (or null when hidden), a noteworthy tier, sentiment,
 * per-mention theme valences, and (when the demographic-cuts dial allows) the tagged
 * demographics. Themed questions show a prevalence board (% of commenters who mentioned
 * each theme, bar coloured by sentiment) and a quote drawer; raw questions show the
 * verbatim browser. Demographic facets (e.g. Campus = Cape Town AND NPS = Promoter), the
 * noteworthy-tier filter and the verbatim-text confidentiality are all honoured here.
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

  /** Keep records matching every selected demographic facet (AND across dimensions). */
  qual.facetFilter = function (records, facets) {
    var dims = facets ? Object.keys(facets).filter(function (d) { return facets[d] != null && facets[d] !== ""; }) : [];
    if (!dims.length) return records || [];
    return (records || []).filter(function (r) {
      var d = r.demos || {};
      for (var i = 0; i < dims.length; i++) if (d[dims[i]] !== facets[dims[i]]) return false;
      return true;
    });
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
    return qual.sentimentFilter(qual.poolBeforeSentiment(q, st, audience), st.sentiment);
  };

  // ---- export the visible comments to Excel (client-side) --------------------

  var SENT_LABEL = { 1: "Positive", 2: "Mixed", 3: "Negative" };
  var TIER_LABEL = { 2: "Must-read", 1: "Noteworthy" };

  /** Export matrix: ID + demographics + Noteworthy + Sentiment + Themes + Verbatim.
   *  Pure + node-testable. Hidden verbatims export as "[hidden]" (the confidentiality
   *  dial is honoured — no raw text leaks when text was withheld). */
  qual.exportRows = function (island, q, records) {
    var dims = ((island && island.demographics) || []).map(function (d) { return d.label; });
    var byId = {};
    (q.themes || []).forEach(function (t) { byId[String(t.id)] = t.label; });
    var header = ["ID"].concat(dims).concat(["Noteworthy", "Sentiment", "Themes", "Verbatim"]);
    var out = [header];
    (records || []).forEach(function (r) {
      var demos = dims.map(function (lbl) { return (r.demos && r.demos[lbl] != null) ? r.demos[lbl] : ""; });
      var themes = Object.keys(r.themeVals || {}).map(function (id) { return byId[id] || ("#" + id); }).join("; ");
      var text = (r.text == null) ? "[hidden]" : r.text;
      out.push([r.idx].concat(demos).concat([TIER_LABEL[r.tier] || "", SENT_LABEL[r.sentiment] || "", themes, text]));
    });
    return out;
  };

  qual.exportXlsx = function (island, q, records) {
    if (!TR.xlsx || !TR.xlsx.download) return;
    var base = (TR.fmt && TR.fmt.slug) ? TR.fmt.slug(q.title || q.code || "comments") : "comments";
    TR.xlsx.download(base + "_comments", "Comments", qual.exportRows(island, q, records));
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
                      theme: null, sentiment: null, facets: {}, railGroups: {}, railHidden: false, savedOnly: false };
    }
    var st = qual._state;
    // The focused open-end lives in d2.state so it round-trips through the URL hash
    // (deep links + the closed->open jump). Fall back to the first question.
    if (!d2.state.qualQ || !findQ(island, d2.state.qualQ)) d2.state.qualQ = island.questions[0].code;
    var q = findQ(island, d2.state.qualQ) || island.questions[0];
    d2.state.qualQ = q.code;

    // The cut is the live global filter (the filter bar is visible on this tab and
    // re-renders it), so the prevalence + drawer always reflect the active filter —
    // "the comments from the people in this cut". A jump additionally pre-sets that
    // filter and shows a breadcrumb back to the closed finding it came from.
    var cutFilters = (d2.state.filters && d2.state.filters.length) ? d2.state.filters : null;
    var jump = qual.jumpContext();

    var audience = qual.maskFilter(qual.facetFilter(q.records, st.facets), cutFilters);
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
    return headerHtml(island, q, audience) + facetHtml(island, st) + controlsHtml(q, st, audience) +
      (q.type === "themed" ? prevalenceHtml(q, st, audience) : "") +
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

  function facetHtml(island, st) {
    var dims = island.demographics || [];
    if (!dims.length) return "";
    var sels = dims.map(function (d) {
      var opts = '<option value="">All</option>' + d.values.map(function (v) {
        var on = st.facets[d.label] === v ? " selected" : "";
        return '<option' + on + '>' + esc(v) + '</option>';
      }).join("");
      return '<label class="ql-facet">' + esc(d.label) +
        ' <select data-dim="' + esc(d.label) + '">' + opts + '</select></label>';
    }).join("");
    var active = Object.keys(st.facets).some(function (k) { return st.facets[k]; });
    var clear = active ? ' <button class="ql-facetclear">clear filters</button>' : "";
    return '<div class="ql-facets"><span class="ql-facetlbl">Filter comments:</span>' + sels + clear + '</div>';
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

    var sc = qual.sentimentCounts(qual.poolBeforeSentiment(q, st, audience));
    var total = sc.pos + sc.neu + sc.neg;
    var sentOpts = [["", "All", total, ""], ["1", "Positive", sc.pos, "pos"],
                    ["2", "Mixed", sc.neu, "neu"], ["3", "Negative", sc.neg, "neg"]];
    var cur = st.sentiment == null ? "" : String(st.sentiment);
    var sent = '<div class="ql-seg sentseg" role="tablist" aria-label="Sentiment filter">' +
      sentOpts.map(function (o) {
        return '<button class="ql-segbtn ' + o[3] + (cur === o[0] ? " on" : "") +
          '" data-sent="' + o[0] + '">' + o[1] +
          ' <span class="ql-segn">' + o[2] + "</span></button>";
      }).join("") + "</div>";

    var savedN = qual.savedCount(q.code);
    var actions = '<div class="ql-actions">' +
      '<button class="ql-savedonly' + (st.savedOnly ? " on" : "") + '" data-savedonly aria-pressed="' +
        st.savedOnly + '" title="Show only the comments you have shortlisted for this question">' +
        "★ Shortlist" + (savedN ? " (" + savedN + ")" : "") + "</button>" +
      '<button class="ql-export" data-qual-export title="Download the comments shown here as an Excel file">' +
        "⬇ Export</button></div>";
    return '<div class="ql-controls">' + tier + sent + actions + "</div>";
  }

  function prevalenceHtml(q, st, audience) {
    var rows = qual.prevalence(audience, q.themes);   // ranked by salience (volume) desc
    if (!rows.length || !audience.length) return '<p class="ql-empty">No coded themes for this selection.</p>';
    // Diverging sentiment bars on a SHARED zero line so valence is comparable across
    // themes: negatives run left of centre, positives right, mixed straddles the centre.
    // Each side of the track represents maxExt comment-units; bar length is absolute, so
    // it also reflects volume, while salience stays the % + the ranking.
    var maxExt = rows.reduce(function (m, r) {
      return Math.max(m, r.neg + r.neu / 2, r.pos + r.neu / 2);
    }, 0) || 1;
    var unit = 50 / maxExt;                           // % of track width per comment, per side
    var num = function (n, side) {
      return n >= 3 ? '<span class="ql-bn ' + side + '">' + n + "</span>" : "";   // direct-labelled ends
    };
    var seg = function (cls, count, inner) {
      return count ? '<span class="ql-bseg ' + cls + '" style="flex:' + count + '">' + (inner || "") + "</span>" : "";
    };
    var body = rows.map(function (r) {
      var sel = r.id === st.theme ? " on" : "";
      var leftExt = (r.neg + r.neu / 2) * unit;
      var totalPct = (r.neg + r.neu + r.pos) * unit;
      var bar = '<span class="ql-dtrack"><span class="ql-dzero"></span>' +
        '<span class="ql-dbar" style="left:' + (50 - leftExt) + "%;width:" + totalPct + '%">' +
          seg("neg", r.neg, num(r.neg, "l")) + seg("neu", r.neu, "") +
          seg("pos", r.pos, num(r.pos, "r")) + "</span></span>";
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
      '<span class="ql-dends"><span>← more negative</span><span>more positive →</span></span>' +
      "<span></span><span></span></div>";
    return '<div class="ql-board"><div class="ql-boardhd">What people raised' +
      '<span class="ql-hint"> — ranked by salience (% of the ' + audience.length +
      ' who raised each theme <b>unprompted</b>). Each bar pivots on a shared zero: ' +
      '<b class="qc-neg">negative</b> runs left, <b class="qc-pos">positive</b> right, ' +
      '<b class="qc-neu">mixed</b> straddles the centre; net = net sentiment %. ' +
      "Click a theme to read its comments.</span>" +
      "</div>" + axis + '<div class="ql-boardgrid">' + body + "</div></div>";
  }

  var SENT_WORD = { 1: "Positive", 2: "Mixed", 3: "Negative" };

  function drawerHtml(island, q, st, audience) {
    var records = qual.visibleRecords(q, st, audience);
    var caption;
    if (st.savedOnly) {
      caption = "Shortlisted comments";
    } else if (q.type === "themed" && st.theme != null) {
      var th = (q.themes || []).filter(function (t) { return t.id === st.theme; })[0];
      caption = 'Comments mentioning “' + esc(th ? th.label : "") + '”';
    } else {
      caption = q.type === "themed" ? "All comments (pick a theme above to filter)" : "Comments";
    }
    if (st.sentiment != null) caption = (SENT_WORD[st.sentiment] || "") + " · " + caption;
    var cards = records.length
      ? records.map(function (r) { return quoteCard(r, q.code); }).join("")
      : '<p class="ql-empty">' + (st.savedOnly
          ? "No shortlisted comments yet — use ＋ Shortlist on a comment."
          : "No comments for this selection.") + "</p>";
    return '<div class="ql-drawer"><div class="ql-drawerhd">' + caption +
      ' <span class="ql-hint">(' + records.length + ")</span></div>" + cards + "</div>";
  }

  function quoteCard(r, qcode) {
    var sent = SENT[r.sentiment] || "neu";
    var text = (r.text == null)
      ? '<span class="ql-hidden">[quote hidden in this copy]</span>'
      : qual.renderHighlighted(r.text, qual.getHighlights(qcode, r.idx));   // select-to-highlight
    var star = r.tier >= 2 ? '<span class="ql-star must" title="must-read">★</span>'
             : r.tier >= 1 ? '<span class="ql-star" title="noteworthy">★</span>' : '';
    var tags = (r.demos ? Object.keys(r.demos) : []).filter(function (k) { return r.demos[k] != null; })
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
    host.querySelectorAll(".ql-facet select").forEach(function (sel) {
      sel.addEventListener("change", function () {
        st.facets[sel.getAttribute("data-dim")] = sel.value;
        qual.render(host);
      });
    });
    var clr = host.querySelector(".ql-facetclear");
    if (clr) clr.addEventListener("click", function () { st.facets = {}; qual.render(host); });
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
