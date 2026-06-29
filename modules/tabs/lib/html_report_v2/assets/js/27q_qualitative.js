/**
 * v2 Qualitative tab — pre-coded comment themes as quant + a verbatim quote drawer.
 *
 * Reads the DATA_QUAL island (TR.QUAL): per-question records keyed by the anonymous
 * index, carrying the verbatim (or null when the build hid it), a noteworthy tier,
 * sentiment, and per-mention theme valences. Themed questions show a prevalence board
 * (%-of-commenters + a pos/neu/neg split) and a quote drawer; raw questions show the
 * verbatim browser. The noteworthy-tier filter (All / Noteworthy+ / Must-read) and the
 * verbatim-text confidentiality (hidden -> "[hidden]") are honoured here.
 *
 * First cut: rail + prevalence + quotes + tier filter. The theme x banner crosstab
 * (via model.forQuestion) and the faceted browser are follow-ons.
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

  /** Per-theme prevalence (%-of-commenters) + the pos/neu/neg valence split. */
  qual.prevalence = function (question) {
    var base = (question.records || []).length;
    var rows = (question.themes || []).map(function (th) {
      var pos = 0, neu = 0, neg = 0, n = 0;
      question.records.forEach(function (r) {
        var v = r.themeVals && r.themeVals[String(th.id)];
        if (v == null) return;
        n++;
        if (v === 1) pos++; else if (v === 2) neu++; else if (v === 3) neg++;
      });
      return { id: th.id, label: th.label, n: n,
               pct: base ? Math.round(n / base * 100) : 0,
               pos: pos, neu: neu, neg: neg,
               net: n ? Math.round((pos - neg) / n * 100) : 0,
               divisive: n ? Math.round(neu / n * 100) : 0 };
    });
    rows.sort(function (a, b) { return b.n - a.n; });
    return rows;
  };

  /** Records that mentioned a given theme id (after the tier filter). */
  qual.recordsForTheme = function (question, themeId, tier) {
    return qual.tierFilter(question.records, tier).filter(function (r) {
      return r.themeVals && r.themeVals[String(themeId)] != null;
    });
  };

  function findQ(island, code) {
    var qs = island.questions || [];
    for (var i = 0; i < qs.length; i++) if (qs[i].code === code) return qs[i];
    return null;
  }

  // ---- render ----------------------------------------------------------------

  qual.render = function (host) {
    var island = TR.QUAL;
    if (!island || !island.questions || !island.questions.length) {
      host.innerHTML = '<div class="page"><p class="ql-empty">No qualitative data in this report.</p></div>';
      return;
    }
    if (!qual._state) {
      qual._state = { q: island.questions[0].code,
                      tier: TIER_ORDER[island.noteworthyDefault] != null ? island.noteworthyDefault : "all",
                      theme: null };
    }
    var st = qual._state;
    var q = findQ(island, st.q) || island.questions[0];
    st.q = q.code;
    host.innerHTML =
      '<div class="ql-wrap">' +
        railHtml(island, st) +
        '<div class="ql-main">' + mainHtml(island, q, st) + '</div>' +
      '</div>';
    wire(host, island);
  };

  function railHtml(island, st) {
    var items = island.questions.map(function (q) {
      var glyph = q.type === "themed" ? "▦" : "❝";
      var sel = q.code === st.q ? ' aria-current="true"' : "";
      return '<button class="ql-railitem" data-q="' + esc(q.code) + '"' + sel + '>' +
        '<span class="ql-glyph">' + glyph + '</span>' +
        '<span class="ql-railtitle">' + esc(q.title) + '</span>' +
        '<span class="ql-railn">' + (q.base ? q.base.answered : 0) + '</span></button>';
    }).join("");
    return '<nav class="ql-rail" aria-label="Open-end questions">' + items + '</nav>';
  }

  function mainHtml(island, q, st) {
    return headerHtml(island, q) + tierBarHtml(st) +
      (q.type === "themed" ? prevalenceHtml(q, st) : "") +
      drawerHtml(island, q, st) +
      footerHtml(island, q);
  }

  function headerHtml(island, q) {
    var n = q.base ? q.base.answered : 0;
    var badge = q.type === "themed" ? "THEMED" : "VERBATIM-ONLY";
    var shield = island.textMode === "full" ? "" :
      '<span class="ql-shield" title="Confidentiality: ' + esc(island.textMode) + '">🛡 ' + esc(island.textMode) + '</span>';
    return '<header class="ql-head"><h2 class="ql-title">' + esc(q.title) + '</h2>' +
      '<div class="ql-meta"><span class="ql-badge">' + badge + '</span>' +
      '<span class="ql-base">' + n + ' answered</span>' + shield + '</div></header>';
  }

  function tierBarHtml(st) {
    var opts = [["all", "All"], ["noteworthy", "Noteworthy+"], ["must_read", "Must-read"]];
    return '<div class="ql-tierbar" role="tablist">' + opts.map(function (o) {
      var on = st.tier === o[0] ? ' class="ql-tier on"' : ' class="ql-tier"';
      return '<button' + on + ' data-tier="' + o[0] + '">' + o[1] + '</button>';
    }).join("") + '</div>';
  }

  function prevalenceHtml(q, st) {
    var rows = qual.prevalence(q);
    if (!rows.length) return '<p class="ql-empty">No themes coded for this question.</p>';
    var max = rows[0].pct || 1;
    var body = rows.map(function (r) {
      var sel = r.id === st.theme ? ' on' : '';
      var w = Math.max(2, Math.round(r.pct / max * 100));
      // Diverging valence stack within the bar: pos | neu | neg.
      var seg = function (cls, count) {
        return count ? '<span class="ql-seg ' + cls + '" style="flex:' + count + '"></span>' : '';
      };
      return '<button class="ql-prow' + sel + '" data-theme="' + r.id + '">' +
        '<span class="ql-plabel">' + esc(r.label) + '</span>' +
        '<span class="ql-pbar" style="width:' + w + '%">' +
          seg("pos", r.pos) + seg("neu", r.neu) + seg("neg", r.neg) + '</span>' +
        '<span class="ql-ppct">' + r.pct + '%</span>' +
        '<span class="ql-pnet" title="net sentiment">' + (r.net > 0 ? "+" : "") + r.net + '</span>' +
        '</button>';
    }).join("");
    return '<div class="ql-board"><div class="ql-boardhd">Theme prevalence ' +
      '<span class="ql-hint">(% of commenters · bar split pos/neu/neg · net)</span></div>' +
      body + '</div>';
  }

  function drawerHtml(island, q, st) {
    var records;
    var caption;
    if (q.type === "themed" && st.theme != null) {
      records = qual.recordsForTheme(q, st.theme, st.tier);
      var th = (q.themes || []).filter(function (t) { return t.id === st.theme; })[0];
      caption = 'Comments mentioning “' + esc(th ? th.label : "") + '”';
    } else {
      records = qual.tierFilter(q.records, st.tier);
      caption = q.type === "themed" ? "All comments (pick a theme to filter)" : "Comments";
    }
    var cards = records.length
      ? records.map(function (r) { return quoteCard(r, island); }).join("")
      : '<p class="ql-empty">No comments at this tier.</p>';
    return '<div class="ql-drawer"><div class="ql-drawerhd">' + caption +
      ' <span class="ql-hint">(' + records.length + ')</span></div>' + cards + '</div>';
  }

  function quoteCard(r, island) {
    var sent = SENT[r.sentiment] || "neu";
    var text = (r.text == null)
      ? '<span class="ql-hidden">[quote hidden in this copy]</span>'
      : esc(r.text);
    var star = r.tier >= 2 ? '<span class="ql-star must" title="must-read">★</span>'
             : r.tier >= 1 ? '<span class="ql-star" title="noteworthy">★</span>' : '';
    return '<div class="ql-quote ' + sent + '">' + star +
      '<span class="ql-qtext">' + text + '</span>' +
      '<span class="ql-qid">#' + esc(r.idx) + '</span></div>';
  }

  function footerHtml(island, q) {
    var dropped = q.meta && q.meta.dropped_codes ? q.meta.dropped_codes : 0;
    var bits = [(q.base ? q.base.answered : 0) + " comments",
                island.demographicCuts === "block" ? "demographic cuts blocked" : null,
                dropped ? (dropped + " stray code(s) quarantined") : null,
                "verbatims by ID — never model-authored"];
    return '<footer class="ql-foot">' + bits.filter(Boolean).join(" · ") + '</footer>';
  }

  // ---- interaction -----------------------------------------------------------

  function wire(host, island) {
    var st = qual._state;
    host.querySelectorAll(".ql-railitem").forEach(function (b) {
      b.addEventListener("click", function () { st.q = b.getAttribute("data-q"); st.theme = null; qual.render(host); });
    });
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
  }
})(typeof window !== "undefined" ? window : globalThis);
