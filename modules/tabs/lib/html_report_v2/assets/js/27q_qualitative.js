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
                      theme: null, facets: {}, railGroups: {}, railHidden: false };
    }
    var st = qual._state;
    // The focused open-end lives in d2.state so it round-trips through the URL hash
    // (deep links + the closed->open jump). Fall back to the first question.
    if (!d2.state.qualQ || !findQ(island, d2.state.qualQ)) d2.state.qualQ = island.questions[0].code;
    var q = findQ(island, d2.state.qualQ) || island.questions[0];
    d2.state.qualQ = q.code;

    // Jump context: when we arrived from a closed/composite card the active global
    // filter is the cut ("the comments from the people in this cell"). The filter bar
    // is hidden on this tab, so the breadcrumb is where the cut is shown + cleared.
    var jump = qual.jumpContext();
    var cutFilters = jump ? jump.filters : null;

    var audience = qual.maskFilter(qual.facetFilter(q.records, st.facets), cutFilters);
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
    return headerHtml(island, q, audience) + facetHtml(island, st) + tierBarHtml(st) +
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

  function tierBarHtml(st) {
    var opts = [["all", "All"], ["noteworthy", "Noteworthy+"], ["must_read", "Must-read"]];
    return '<div class="ql-tierbar" role="tablist">' + opts.map(function (o) {
      var on = st.tier === o[0] ? ' class="ql-tier on"' : ' class="ql-tier"';
      return '<button' + on + ' data-tier="' + o[0] + '">' + o[1] + '</button>';
    }).join("") + '</div>';
  }

  function prevalenceHtml(q, st, audience) {
    var rows = qual.prevalence(audience, q.themes);
    if (!rows.length || !audience.length) return '<p class="ql-empty">No coded themes for this selection.</p>';
    var body = rows.map(function (r) {
      var sel = r.id === st.theme ? ' on' : '';
      // Bar is a fixed 0–100 track; the fill width IS the % of commenters, split by
      // sentiment of those mentions (green positive / grey mixed / red negative).
      var seg = function (cls, count) {
        return count ? '<span class="ql-seg ' + cls + '" style="flex:' + count + '"></span>' : '';
      };
      var fill = '<span class="ql-pfill" style="width:' + r.pct + '%">' +
        seg("pos", r.pos) + seg("neu", r.neu) + seg("neg", r.neg) + '</span>';
      var netCls = r.net > 0 ? "pos" : r.net < 0 ? "neg" : "neu";
      return '<button class="ql-prow' + sel + '" data-theme="' + r.id + '" ' +
          'title="' + r.n + ' of ' + audience.length + ' commenters mentioned this">' +
        '<span class="ql-plabel">' + esc(r.label) + '</span>' +
        '<span class="ql-ptrack">' + fill + '</span>' +
        '<span class="ql-ppct">' + r.pct + '%</span>' +
        '<span class="ql-pnet ' + netCls + '">net ' + (r.net > 0 ? "+" : "") + r.net + '</span>' +
        '</button>';
    }).join("");
    return '<div class="ql-board"><div class="ql-boardhd">Themes mentioned' +
      '<span class="ql-hint"> — % of the ' + audience.length +
      ' commenters who raised each theme; bar coloured by sentiment ' +
      '(<b class="qc-pos">positive</b> · <b class="qc-neu">mixed</b> · ' +
      '<b class="qc-neg">negative</b>); net = net sentiment, −100…+100. Click a theme to read its comments.</span>' +
      '</div>' + body + '</div>';
  }

  function drawerHtml(island, q, st, audience) {
    var pool = (q.type === "themed" && st.theme != null)
      ? qual.recordsForTheme(audience, st.theme) : audience;
    var records = qual.tierFilter(pool, st.tier);
    var caption;
    if (q.type === "themed" && st.theme != null) {
      var th = (q.themes || []).filter(function (t) { return t.id === st.theme; })[0];
      caption = 'Comments mentioning “' + esc(th ? th.label : "") + '”';
    } else {
      caption = q.type === "themed" ? "All comments (pick a theme above to filter)" : "Comments";
    }
    var cards = records.length
      ? records.map(function (r) { return quoteCard(r); }).join("")
      : '<p class="ql-empty">No comments for this selection.</p>';
    return '<div class="ql-drawer"><div class="ql-drawerhd">' + caption +
      ' <span class="ql-hint">(' + records.length + ')</span></div>' + cards + '</div>';
  }

  function quoteCard(r) {
    var sent = SENT[r.sentiment] || "neu";
    var text = (r.text == null)
      ? '<span class="ql-hidden">[quote hidden in this copy]</span>' : esc(r.text);
    var star = r.tier >= 2 ? '<span class="ql-star must" title="must-read">★</span>'
             : r.tier >= 1 ? '<span class="ql-star" title="noteworthy">★</span>' : '';
    var tags = (r.demos ? Object.keys(r.demos) : []).filter(function (k) { return r.demos[k] != null; })
      .map(function (k) { return '<span class="ql-tag">' + esc(r.demos[k]) + '</span>'; }).join("");
    return '<div class="ql-quote ' + sent + '">' + star +
      '<div class="ql-qbody"><span class="ql-qtext">' + text + '</span>' +
      (tags ? '<div class="ql-tags">' + tags + '</div>' : '') + '</div>' +
      '<span class="ql-qid">#' + esc(r.idx) + '</span></div>';
  }

  function footerHtml(island, q) {
    var dropped = q.meta && q.meta.dropped_codes ? q.meta.dropped_codes : 0;
    var bits = [(q.base ? q.base.answered : 0) + " comments",
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
    host.querySelectorAll(".ql-tier").forEach(function (b) {
      b.addEventListener("click", function () { st.tier = b.getAttribute("data-tier"); qual.render(host); });
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
  }
})(typeof window !== "undefined" ? window : globalThis);
