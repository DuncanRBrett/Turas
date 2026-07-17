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
 *
 * Reader bundle C (READER_EXPERIENCE_PLAN.md): quote-first typography with the analyst's
 * curated selection leading (C1); theme cards carrying championed quotes + a closed-stat
 * chip when a closed question links here — declared q.linked_open or the ResponseID join,
 * both directions (C2); unthemed comments as a first-class "Everything else" card + a
 * theme-coverage bar (C3); and a keyboard-driven focus reading mode (C4). All of it is
 * presentation over the SAME gated record pools — no new data paths past the k-gates.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var qual = TR.qual = TR.qual || {};
  var esc = function (s) { return (TR.fmt && TR.fmt.escapeHtml) ? TR.fmt.escapeHtml(s) : String(s == null ? "" : s); };

  var TIER_ORDER = { all: 0, noteworthy: 1, must_read: 2, priority: 3 };
  var SENT = { 1: "pos", 2: "neu", 3: "neg" };

  // ---- pure helpers (node-testable) -----------------------------------------

  /** Keep records at or above the active noteworthy tier. */
  qual.tierFilter = function (records, tier) {
    var min = TIER_ORDER[tier] || 0;
    return (records || []).filter(function (r) { return (r.tier || 0) >= min; });
  };

  /** Stable display/export order: highest noteworthy tier first (Priority ->
   *  Must-read -> Noteworthy -> the rest); within a tier the existing (data)
   *  order is kept — so the comments to lead with are never buried by record id. */
  qual.byTierDesc = function (records) {
    return (records || [])
      .map(function (r, i) { return { r: r, i: i }; })
      .sort(function (a, b) {
        var d = (b.r.tier || 0) - (a.r.tier || 0);
        return d !== 0 ? d : a.i - b.i;
      })
      .map(function (x) { return x.r; });
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

  /** Sentinel theme id: the UNthemed comments as a first-class selection (C3). */
  qual.OTHER_THEME = "__else__";

  /** Records (from a pool) that mentioned a given theme id. The sentinel
   *  qual.OTHER_THEME selects the unthemed records instead — "Everything else"
   *  rides the same theme -> drawer pipeline as a real theme. */
  qual.recordsForTheme = function (records, themeId) {
    if (themeId === qual.OTHER_THEME) return qual.unthemed(records);
    return (records || []).filter(function (r) {
      return r.themeVals && r.themeVals[String(themeId)] != null;
    });
  };

  /** Records carrying no coded theme at all (every themeVals entry null/absent). */
  qual.unthemed = function (records) {
    return (records || []).filter(function (r) {
      var tv = r.themeVals || {};
      return !Object.keys(tv).some(function (k) { return tv[k] != null; });
    });
  };

  /** Share of comments carrying at least one theme — the header coverage bar
   *  ("83% of comments themed"), from the existing assignments only. */
  qual.coverage = function (records) {
    var total = (records || []).length;
    var themed = total - qual.unthemed(records).length;
    return { themed: themed, total: total, pct: total ? Math.round(themed / total * 100) : 0 };
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
    // Split three counts into integer percentages that SUM to the rounded total
    // (largest-remainder), so pos+mix+neg reconciles with the salience / 100
    // instead of drifting a point from independently rounding each part.
    var splitPct = function (parts, denom) {
      if (!denom) return [0, 0, 0];
      var raw = parts.map(function (p) { return p / denom * 100; });
      var flo = raw.map(Math.floor);
      var target = Math.round(parts.reduce(function (a, b) { return a + b; }, 0) / denom * 100);
      var rem = target - flo.reduce(function (a, b) { return a + b; }, 0);
      raw.map(function (v, i) { return { i: i, f: v - flo[i] }; })
        .sort(function (a, b) { return b.f - a.f; })
        .slice(0, Math.max(0, rem)).forEach(function (o) { flo[o.i]++; });
      return flo;
    };
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
        var ob = splitPct([pos, mix, neg], base), om = splitPct([pos, mix, neg], men);
        return { men: men, pos: pos, mix: mix, neg: neg, base: base,
          salience: pc(men, base), net: men ? Math.round((pos - neg) / men * 100) : 0,
          ofBase: { pos: ob[0], mix: ob[1], neg: ob[2] },
          ofMen: { pos: om[0], mix: om[1], neg: om[2] }, sig: "" };
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

  /** The closed<->open jump link for a closed/composite code, or null. The
   *  ResponseID-join links (project.qualLinks) win; a declared LinkedOpenQuestion
   *  (q.linked_open, optional source-format field) is honoured when its target
   *  open-end actually exists in this report's island. */
  qual.linkFor = function (code) {
    var links = (TR.AGG && TR.AGG.project && TR.AGG.project.qualLinks) || null;
    if (links && links[code]) return links[code];
    var closed = aggQuestion(code);
    var lo = closed && closed.linked_open;
    if (lo && TR.QUAL) {
      var open = findQ(TR.QUAL, lo);
      if (open) return { qcode: lo, title: open.title || lo };
    }
    return null;
  };

  /** The closed question in TR.AGG.questions with this code, or null. */
  function aggQuestion(code) {
    var qs = (TR.AGG && TR.AGG.questions) || [];
    for (var i = 0; i < qs.length; i++) if (qs[i].code === code) return qs[i];
    return null;
  }

  /** The closed/composite question a qual question explains (reverse of linkFor):
   *  a declared linked_open pointing here, else a ResponseID-join link. Returns
   *  { code, title, q } (q = the AGG entry when present) or null. */
  qual.closedFor = function (qcode) {
    var qs = (TR.AGG && TR.AGG.questions) || [];
    var hit = null, i;
    for (i = 0; i < qs.length; i++) if (qs[i].linked_open === qcode) { hit = qs[i]; break; }
    if (!hit) {
      var links = (TR.AGG && TR.AGG.project && TR.AGG.project.qualLinks) || {};
      var keys = Object.keys(links);
      for (i = 0; i < keys.length; i++) {
        if (links[keys[i]] && links[keys[i]].qcode === qcode) {
          hit = aggQuestion(keys[i]) || { code: keys[i], title: keys[i] };
          break;
        }
      }
    }
    if (!hit) return null;
    return { code: hit.code, title: hit.short_label || hit.title || hit.code, q: hit.rows ? hit : null };
  };

  /** The closed-stat chip for a qual question header ("📊 Rated 78.3 · n=106 ·
   *  view Q28 ›") — the bidirectional half of the 💬 jump. "" when unlinked;
   *  the stat is omitted (link only) when the closed question has no mean row. */
  qual.closedStatChip = function (qcode) {
    var c = qual.closedFor(qcode);
    if (!c) return "";
    var stat = "";
    if (c.q) {
      var mr = (c.q.rows || []).filter(function (r) { return r.kind === "mean"; })[0];
      var v = mr && mr.pct ? mr.pct[0] : null;
      var b = c.q.bases && c.q.bases[0] ? c.q.bases[0].n : null;
      if (v != null) {
        stat = "Rated " + ((TR.fmt && TR.fmt.score) ? TR.fmt.score(v) : v) +
          (b != null ? " · n=" + ((TR.fmt && TR.fmt.base) ? TR.fmt.base(b) : b) : "");
      }
    }
    return '<button class="ql-statchip" data-qual-return="' + esc(c.code) +
      '" title="Open ' + esc(c.title) + ' — the closed question these comments sit behind">📊 ' +
      (stat ? esc(stat) + " · " : "") + "view " + esc(c.code) + " ›</button>";
  };

  /** The analyst's one-line headline for a question (optional source-format
   *  field) — the island's own field first, else the AGG entry's. "" if none. */
  qual.headlineFor = function (q) {
    if (q && typeof q.headline === "string" && q.headline.trim()) return q.headline.trim();
    var agg = q && aggQuestion(q.code);
    return (agg && typeof agg.headline === "string" && agg.headline.trim()) ? agg.headline.trim() : "";
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
    // Count within the ACTIVE cut, so the number matches what the jump reveals —
    // and below the disclosure threshold even that count would leak, so no number.
    var filters = (TR.d2 && TR.d2.state && TR.d2.state.filters && TR.d2.state.filters.length)
      ? TR.d2.state.filters : null;
    var n = qual.commentCount(link.qcode, filters);
    if (!n) return "";
    var gated = !!(TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall());
    return '<button class="ql-jumpbtn" data-qual-jump="' + esc(code) +
      '" title="Read the ' + esc(link.title) + ' open-end comments behind this finding">' +
      (gated ? "💬 comments" : "💬 " + n + " comment" + (n === 1 ? "" : "s")) + "</button>";
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
    var own = null;
    try {
      var raw = (typeof localStorage !== "undefined") && TR.d2 && localStorage.getItem(TR.d2.storeKey(SAVED_KEY));
      if (raw) own = JSON.parse(raw) || null;
    } catch (e) { /* island-only */ }
    // Ownership marker: once the reader changes anything here, the persisted
    // localStorage state carries _owns:true and is authoritative — the island
    // seed is ignored on load, so deletions stay deleted. State without the
    // marker (legacy / first visit) seeds from the island and merges without
    // claiming ownership; only a reader change through the persist path does.
    if (own && own._owns) {
      Object.keys(own).forEach(function (k) { if (k !== "_owns") savedCache[k] = own[k]; });
      return savedCache;
    }
    if (TR.userState && TR.userState.qualSaved) {
      Object.keys(TR.userState.qualSaved).forEach(function (k) { if (k !== "_owns") savedCache[k] = TR.userState.qualSaved[k]; });
    }
    if (own) Object.keys(own).forEach(function (k) { if (k !== "_owns") savedCache[k] = own[k]; });
    return savedCache;
  }
  function savedPersist() {
    try {
      if (typeof localStorage !== "undefined" && TR.d2) {
        var out = { _owns: true };   // every persist here is a reader change
        Object.keys(savedStore()).forEach(function (k) { out[k] = savedStore()[k]; });
        localStorage.setItem(TR.d2.storeKey(SAVED_KEY), JSON.stringify(out));
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
    var own = null;
    try {
      var raw = (typeof localStorage !== "undefined") && TR.d2 && localStorage.getItem(TR.d2.storeKey(HL_KEY));
      if (raw) own = JSON.parse(raw) || null;
    } catch (e) { /* island-only */ }
    // Ownership marker: once the reader changes anything here, the persisted
    // localStorage state carries _owns:true and is authoritative — the island
    // seed is ignored on load, so deletions stay deleted. State without the
    // marker (legacy / first visit) seeds from the island and merges without
    // claiming ownership; only a reader change through the persist path does.
    if (own && own._owns) {
      Object.keys(own).forEach(function (k) { if (k !== "_owns") hlCache[k] = own[k]; });
      return hlCache;
    }
    if (TR.userState && TR.userState.qualHighlights) {
      Object.keys(TR.userState.qualHighlights).forEach(function (k) { if (k !== "_owns") hlCache[k] = TR.userState.qualHighlights[k]; });
    }
    if (own) Object.keys(own).forEach(function (k) { if (k !== "_owns") hlCache[k] = own[k]; });
    return hlCache;
  }
  function hlPersist() {
    try {
      if (typeof localStorage !== "undefined" && TR.d2) {
        var out = { _owns: true };   // every persist here is a reader change
        Object.keys(hlStore()).forEach(function (k) { out[k] = hlStore()[k]; });
        localStorage.setItem(TR.d2.storeKey(HL_KEY), JSON.stringify(out));
      }
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

  /** Filter to one split band (NPS Detractor/Passive/Promoter etc.). Only bites on a
   *  split-bearing question; a null/"" band (All) passes everything. The band is the
   *  report-level split axis carried on the record, not a demographic tag. */
  qual.bandFilter = function (q, records, band) {
    if (!q || !q.split || band == null || band === "") return records || [];
    return (records || []).filter(function (r) { return r.band === band; });
  };

  /** How many of `records` fall in `band` ("" = every band) — for the segment counts.
   *  Counts only shown comments, so the band buttons match the list they navigate. */
  qual.bandCount = function (q, records, band) {
    return qual.bandFilter(q, qual.shown(records), band).length;
  };

  /** Records whose verbatim ships — i.e. NOT withheld by the build-time verbatim scope
   *  or a "hide" marker (record.suppressed). Withheld comments are counted in every
   *  distribution (prevalence, coverage, crosstab all read the full audience) but never
   *  appear in the readable comment LIST, so this gate is applied only on the list path,
   *  never on the chart. A report built with qual_verbatim_scope = all and no hide marks
   *  has no suppressed records, so this is a no-op for the common case. */
  qual.shown = function (records) {
    return (records || []).filter(function (r) { return !r.suppressed; });
  };

  /** The pool a sentiment pick filters: shown -> band -> theme -> tier -> shortlist
   *  (everything but the sentiment filter itself), so the sentiment buttons can show
   *  "if I click this, N comments". Withheld verbatims drop out first so the list and
   *  its counts reflect only readable comments; the band narrows next so every
   *  downstream count is per-band. */
  qual.poolBeforeSentiment = function (q, st, audience) {
    var base = qual.bandFilter(q, qual.shown(audience), st.band);
    var pool = (q.type === "themed" && st.theme != null) ? qual.recordsForTheme(base, st.theme) : base;
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
    var records = qual.hasSentiment(q) ? qual.sentimentFilter(pool, st.sentiment) : pool;
    // Lead with the highest tier (Priority -> Must-read -> Noteworthy), never by record id.
    return qual.byTierDesc(records);
  };

  /** Split records into the analyst's curated set (shortlisted or carrying a
   *  highlight) and the rest, order preserved — curated-first rendering (C1).
   *  Presentation-only: both halves come from the SAME gated record pool. */
  qual.curatedSplit = function (records, qcode) {
    var curated = [], rest = [];
    (records || []).forEach(function (r) {
      var marked = qual.isSaved(qcode, r.idx) || qual.getHighlights(qcode, r.idx).length > 0;
      (marked ? curated : rest).push(r);
    });
    return { curated: curated, rest: rest };
  };

  /** Up to `cap` championed quotes for a theme (C2). The rule (fix #1) — so the
   *  inline pair is never arbitrary:
   *    1. the analyst's shortlist always leads (explicit editorial picks win);
   *    2. the remaining slots fill as a BALANCED SPREAD — one positive, one
   *       negative — so the reader sees the theme's range, not just its loudest
   *       side. Mixed/uncoded are the fallback, so a one-sided theme simply fills
   *       from the sentiment that exists (its dominant lean), best tier first.
   *  Within any bucket the order is noteworthy tier desc, then comment ID asc —
   *  a stable, deterministic tie-break (never source array order). Hidden-text
   *  records never champion. */
  qual.championQuotes = function (records, themeId, qcode, cap) {
    cap = cap > 0 ? cap : 2;
    var pool = qual.recordsForTheme(records, themeId)
      .filter(function (r) { return r.text != null; });
    if (!pool.length) return [];
    var byTier = function (a, b) {
      if ((b.tier || 0) !== (a.tier || 0)) return (b.tier || 0) - (a.tier || 0);
      return a.idx - b.idx;                          // stable, deterministic tie-break
    };
    // 1. the analyst's shortlist leads, outright — even two same-sentiment picks
    var saved = pool.filter(function (r) { return qual.isSaved(qcode, r.idx); }).sort(byTier);
    var chosen = saved.slice(0, cap);
    if (chosen.length >= cap) return chosen;
    var taken = {}; chosen.forEach(function (r) { taken[r.idx] = 1; });
    // 2. balanced spread over the rest: prefer the polarity not yet on screen
    var rest = pool.filter(function (r) { return !taken[r.idx]; });
    var pos = rest.filter(function (r) { return r.sentiment === 1; }).sort(byTier);
    var neg = rest.filter(function (r) { return r.sentiment === 3; }).sort(byTier);
    var neu = rest.filter(function (r) { return r.sentiment !== 1 && r.sentiment !== 3; }).sort(byTier);
    var hasPos = chosen.some(function (r) { return r.sentiment === 1; });
    var hasNeg = chosen.some(function (r) { return r.sentiment === 3; });
    var queues = (hasPos && !hasNeg) ? [neg, pos, neu]    // already positive -> lead with a negative
               : [pos, neg, neu];                         // default / already-negative -> positive first
    var i = 0;
    while (chosen.length < cap && (pos.length || neg.length || neu.length)) {
      var qq = queues[i % queues.length];
      if (qq.length) chosen.push(qq.shift());
      i++;
    }
    return chosen;
  };

  /** j/k + arrow-key navigation for the focus reading mode (C4). Pure: given
   *  the current position, a key and the list length, the next position and
   *  whether the key closes the view. Positions clamp at both ends. */
  qual.focusNav = function (pos, key, len) {
    if (key === "Escape") return { pos: pos, close: true };
    var next = pos;
    if (key === "j" || key === "J" || key === "ArrowDown" || key === "ArrowRight") {
      next = Math.min(len - 1, pos + 1);
    } else if (key === "k" || key === "K" || key === "ArrowUp" || key === "ArrowLeft") {
      next = Math.max(0, pos - 1);
    }
    return { pos: next, close: false };
  };

  // ---- export the visible comments to Excel (client-side) --------------------

  var SENT_LABEL = { 1: "Positive", 2: "Mixed", 3: "Negative" };
  var TIER_LABEL = { 3: "Priority", 2: "Must-read", 1: "Noteworthy" };

  /** Export matrix: ID + demographics + Noteworthy + Sentiment + Themes + Verbatim.
   *  Pure + node-testable. Hidden verbatims export as "[hidden]" (the confidentiality
   *  dial is honoured — no raw text leaks when text was withheld). When safeDemos is
   *  false (the audience is below the disclosure threshold) the demographic columns AND the
   *  verbatim text export as "[hidden]" too, so a small cut can't be exported with any
   *  identifying detail attached. */
  qual.exportRows = function (island, q, records, safeDemos) {
    if (safeDemos === undefined) safeDemos = true;
    var dims = ((island && island.demographics) || []).map(function (d) { return d.label; });
    var byId = {};
    (q.themes || []).forEach(function (t) { byId[String(t.id)] = t.label; });
    // The split band is a report-level axis (like Noteworthy/Sentiment), so it exports even
    // when demographics are withheld — it never identifies on its own (it mirrors the
    // recommend question already reported).
    var bandCol = (q.split && (q.split.bands || []).length) ? [q.split.dim || "Band"] : [];
    var header = ["ID"].concat(bandCol).concat(dims).concat(["Noteworthy", "Sentiment", "Themes", "Verbatim"]);
    var out = [header];
    (records || []).forEach(function (r) {
      var demos = dims.map(function (lbl) {
        if (!safeDemos) return "[hidden]";
        return (r.demos && r.demos[lbl] != null) ? r.demos[lbl] : "";
      });
      var bandVal = bandCol.length ? [r.band || ""] : [];
      var themes = Object.keys(r.themeVals || {}).map(function (id) { return byId[id] || ("#" + id); }).join("; ");
      var text = (!safeDemos || r.text == null) ? "[hidden]" : r.text;
      out.push([r.idx].concat(bandVal).concat(demos)
        .concat([TIER_LABEL[r.tier] || "", SENT_LABEL[r.sentiment] || "", themes, text]));
    });
    return out;
  };

  qual.exportXlsx = function (island, q, records) {
    if (!TR.xlsx || !TR.xlsx.download) return;
    // Below the disclosure threshold the drawer withholds the whole list (even the
    // count) — the export must keep that promise: a row per comment (ID, tier,
    // sentiment, themes) would reveal exactly what the gate suppresses on screen.
    if (TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall()) return;
    var safeDemos = !(TR.disclosure && TR.disclosure.audienceTooSmall());
    var base = (TR.fmt && TR.fmt.slug) ? TR.fmt.slug(q.title || q.code || "comments") : "comments";
    // keepText: verbatims, IDs and demographic values are prose / identifiers —
    // never coerce them to numbers (a "50%" comment or an 007 code would mangle).
    TR.xlsx.download(base + "_comments", "Comments",
      qual.exportRows(island, q, records, safeDemos), { keepText: true });
  };

  // ---- collection: the pool (all marks) aggregated across questions ----------
  // The "collection" is a VIEW over the durable pool — every shortlisted (★) and
  // every highlighted (✎) comment, gathered across all questions into one place. It
  // reads the existing shortlist + highlight stores and NEVER mutates them, so the
  // marks can't be lost by anything the collection does. Both stores are keyed
  // qcode#idx; a key that no longer resolves to a record (a mark left over from an
  // earlier data run) is counted as an orphan and skipped, so a stale mark degrades
  // to an honest footnote instead of a broken card. Pure + node-testable.

  var NO_THEME = "No theme";

  /** Index every question's records by idx, for O(1) resolution of a qcode#idx key. */
  function recordIndex(island) {
    var map = {};
    ((island && island.questions) || []).forEach(function (q) {
      var byIdx = {};
      (q.records || []).forEach(function (r) { byIdx[r.idx] = r; });
      map[q.code] = { q: q, byIdx: byIdx };
    });
    return map;
  }

  /** Split a "qcode#idx" mark key into {qcode, idx}, or null if malformed. The idx is
   *  the trailing integer after the LAST '#' (a qcode itself never contains '#'). */
  qual.splitMark = function (key) {
    var s = key == null ? "" : String(key), at = s.lastIndexOf("#");
    if (at < 0) return null;
    var qcode = s.slice(0, at), idx = parseInt(s.slice(at + 1), 10);
    if (!qcode || isNaN(idx)) return null;
    return { qcode: qcode, idx: idx };
  };

  /**
   * Aggregate the pool into collected items across all questions.
   *   savedMap : { "qcode#idx": 1 }              (the shortlist store)
   *   hlMap    : { "qcode#idx": [[start,end]..] } (the highlight store)
   *   hubMap   : { "qcode#idx": 1 }              (union of every hub's members)
   * Returns { items: [...], orphans: N }. Each item is
   *   { qcode, idx, record, question, saved, highlighted, hubbed }
   * de-duplicated by qcode#idx. A comment counts as pooled if it is shortlisted,
   * highlighted OR filed in any hub — so "add to a hub" is itself a way to save a
   * comment (shortlist + hub in one), no separate ★ needed. Orphans (keys with no
   * matching record) are counted once over the union. Pure — no DOM, no storage.
   */
  qual.collectPool = function (island, savedMap, hlMap, hubMap) {
    var res = recordIndex(island);
    savedMap = savedMap || {}; hlMap = hlMap || {}; hubMap = hubMap || {};
    var keys = {};
    Object.keys(savedMap).forEach(function (k) { if (savedMap[k]) keys[k] = 1; });
    Object.keys(hlMap).forEach(function (k) { if (hlMap[k] && hlMap[k].length) keys[k] = 1; });
    Object.keys(hubMap).forEach(function (k) { if (hubMap[k]) keys[k] = 1; });
    var items = [], orphans = 0;
    Object.keys(keys).forEach(function (key) {
      var m = qual.splitMark(key);
      var slot = m && res[m.qcode];
      var rec = slot && slot.byIdx[m.idx];
      if (!rec) { orphans++; return; }
      items.push({ qcode: m.qcode, idx: m.idx, record: rec, question: slot.q,
                   saved: !!savedMap[key], highlighted: !!(hlMap[key] && hlMap[key].length),
                   hubbed: !!hubMap[key] });
    });
    return { items: items, orphans: orphans };
  };

  /**
   * Group collected items for display.
   *   mode "question" (default) — by source question, in island order.
   *   mode "theme" — by theme LABEL across questions (affinity grouping): a comment
   *     appears under every theme it carries; comments with no coded theme fall in a
   *     "No theme" group. Theme groups rank by distinct-comment count desc, "No theme"
   *     last. Returns an ordered array of { key, label, items }. Pure + node-testable.
   */
  qual.groupCollection = function (island, items, mode) {
    items = items || [];
    if (mode === "theme") {
      var groups = {}, order = [];
      var push = function (label, it) {
        if (!groups[label]) { groups[label] = { key: label, label: label, items: [] }; order.push(label); }
        groups[label].items.push(it);
      };
      items.forEach(function (it) {
        var byId = {};
        ((it.question && it.question.themes) || []).forEach(function (t) { byId[String(t.id)] = t.label; });
        var vals = it.record.themeVals || {};
        var labels = Object.keys(vals).filter(function (id) { return vals[id] != null && byId[id]; })
          .map(function (id) { return byId[id]; });
        if (labels.length) labels.forEach(function (lbl) { push(lbl, it); });
        else push(NO_THEME, it);
      });
      return order.map(function (l) { return groups[l]; }).sort(function (a, b) {
        if (a.label === NO_THEME) return 1;
        if (b.label === NO_THEME) return -1;
        return b.items.length - a.items.length;
      });
    }
    var byQ = {};
    items.forEach(function (it) { (byQ[it.qcode] || (byQ[it.qcode] = [])).push(it); });
    return ((island && island.questions) || []).filter(function (q) { return byQ[q.code]; })
      .map(function (q) { return { key: q.code, label: q.title, items: byQ[q.code] }; });
  };

  /** Export matrix for the collection: ID + Question + demographics + Noteworthy +
   *  Sentiment + Themes + Shortlisted + Highlighted + Verbatim. Mirrors exportRows'
   *  confidentiality rule — when safeDemos is false the demographic columns AND the
   *  verbatim export as "[hidden]", and a hidden verbatim always exports as "[hidden]".
   *  Pure + node-testable. */
  qual.collectionExportRows = function (island, items, safeDemos) {
    if (safeDemos === undefined) safeDemos = true;
    var dims = ((island && island.demographics) || []).map(function (d) { return d.label; });
    var header = ["ID", "Question"].concat(dims)
      .concat(["Noteworthy", "Sentiment", "Themes", "Shortlisted", "Highlighted", "Verbatim"]);
    var out = [header];
    (items || []).forEach(function (it) {
      var r = it.record, q = it.question, byId = {};
      (q.themes || []).forEach(function (t) { byId[String(t.id)] = t.label; });
      var demos = dims.map(function (lbl) {
        if (!safeDemos) return "[hidden]";
        return (r.demos && r.demos[lbl] != null) ? r.demos[lbl] : "";
      });
      var themes = Object.keys(r.themeVals || {}).filter(function (id) { return r.themeVals[id] != null; })
        .map(function (id) { return byId[id] || ("#" + id); }).join("; ");
      var text = (!safeDemos || r.text == null) ? "[hidden]" : r.text;
      out.push([r.idx, q.title].concat(demos).concat(
        [TIER_LABEL[r.tier] || "", SENT_LABEL[r.sentiment] || "", themes,
         it.saved ? "Yes" : "", it.highlighted ? "Yes" : "", text]));
    });
    return out;
  };

  qual.exportCollectionXlsx = function (island, items, safeDemos) {
    if (!TR.xlsx || !TR.xlsx.download) return;
    // The caller passes the view's gate (hub-specific when a hub is active — set in
    // collectionMain) so the export can never be more revealing than the screen.
    if (safeDemos === undefined) safeDemos = !(TR.disclosure && TR.disclosure.audienceTooSmall());
    TR.xlsx.download("collection_comments", "Collection",
      qual.collectionExportRows(island, items, safeDemos), { keepText: true });
  };

  // ---- named reader hubs: named lenses over the pool -------------------------
  // A hub is a NAMED SET of marks (qcode#idx) — a VIEW over the pool, never a
  // container: adding a comment to a hub, or renaming/deleting a hub, never touches a
  // mark, and the same mark can sit in several hubs. Reader hubs live in per-report
  // localStorage (mirroring the shortlist). qual.hubsAll() is exposed for the step-2
  // authored-hub island bake but is deliberately NOT yet wired into report.saveCopy
  // (that + the privacy-clear-at-save gate is step 2). Ids are monotonic: a deleted
  // hub's id is never reissued, so a stale reference can't resurrect into another hub.

  var HUBS_KEY = "turas_v2_qualhubs";
  var hubsCache = null;
  function normalizeHubs(raw) {
    var s = (raw && typeof raw === "object") ? raw : {};
    var byId = (s.byId && typeof s.byId === "object") ? s.byId : {};
    var order = Array.isArray(s.order) ? s.order.filter(function (id) { return byId[id]; }) : [];
    Object.keys(byId).forEach(function (id) { if (order.indexOf(id) < 0) order.push(id); });   // defensive
    var maxId = order.reduce(function (m, id) { var n = parseInt(id, 10); return isNaN(n) ? m : Math.max(m, n); }, 0);
    var seq = (typeof s.seq === "number" && s.seq > maxId) ? s.seq : maxId;
    order.forEach(function (id) {
      var h = byId[id];
      if (!h.marks || typeof h.marks !== "object") h.marks = {};
      h.id = id;
      h.name = (typeof h.name === "string" && h.name) ? h.name : "Untitled hub";
      if (typeof h.insight !== "string") h.insight = "";
    });
    return { seq: seq, order: order, byId: byId };
  }
  function hubsStore() {
    if (hubsCache) return hubsCache;
    var seed = (TR.userState && TR.userState.qualHubs) || null;   // step-2 authored bake seeds here
    try {
      var raw = (typeof localStorage !== "undefined") && TR.d2 && localStorage.getItem(TR.d2.storeKey(HUBS_KEY));
      if (raw) seed = JSON.parse(raw);                            // the reader's own set wins entirely
    } catch (e) { /* island / empty */ }
    hubsCache = normalizeHubs(seed);
    return hubsCache;
  }
  function hubsPersist() {
    try {
      if (typeof localStorage !== "undefined" && TR.d2) {
        localStorage.setItem(TR.d2.storeKey(HUBS_KEY), JSON.stringify(hubsStore()));
      }
    } catch (e) { /* storage blocked — hubs stay in memory */ }
  }
  function markKey(qcode, idx) { return qcode + "#" + idx; }

  qual.hubsAll = function () { return hubsStore(); };            // report.saveCopy will embed this (step 2)
  qual.hubList = function () {
    var s = hubsStore();
    return s.order.map(function (id) {
      var h = s.byId[id];
      return { id: id, name: h.name, count: Object.keys(h.marks).length };
    });
  };
  qual.hubGet = function (id) { return hubsStore().byId[id] || null; };
  qual.hubCreate = function (name) {
    var s = hubsStore();
    s.seq += 1;
    var id = String(s.seq);
    s.byId[id] = { id: id, name: (name || "").trim() || "Untitled hub", insight: "", marks: {} };
    s.order.push(id);
    hubsPersist();
    return id;
  };
  qual.hubRename = function (id, name) {
    var h = hubsStore().byId[id];
    if (!h) return false;
    h.name = (name || "").trim() || h.name;   // an all-blank rename keeps the old name
    hubsPersist();
    return true;
  };
  qual.hubDelete = function (id) {
    var s = hubsStore();
    if (!s.byId[id]) return false;
    delete s.byId[id];
    s.order = s.order.filter(function (x) { return x !== id; });
    hubsPersist();
    return true;
  };
  qual.hubHasMark = function (id, qcode, idx) {
    var h = hubsStore().byId[id];
    return !!(h && h.marks[markKey(qcode, idx)]);
  };
  qual.hubToggleMark = function (id, qcode, idx) {
    var h = hubsStore().byId[id];
    if (!h) return false;
    var k = markKey(qcode, idx);
    if (h.marks[k]) delete h.marks[k]; else h.marks[k] = 1;
    hubsPersist();
    return !!h.marks[k];
  };
  qual.hubMarks = function (id) {
    var h = hubsStore().byId[id];
    return h ? h.marks : {};
  };
  qual.hubsForMark = function (qcode, idx) {
    var s = hubsStore(), k = markKey(qcode, idx), out = [];
    s.order.forEach(function (id) { if (s.byId[id].marks[k]) out.push({ id: id, name: s.byId[id].name }); });
    return out;
  };
  /** { "qcode#idx": 1 } over every hub's members — the hub contribution to the pool, so
   *  a comment filed only in a hub still shows up in the collection. */
  qual.hubMarksUnion = function () {
    var s = hubsStore(), out = {};
    s.order.forEach(function (id) { Object.keys(s.byId[id].marks).forEach(function (k) { out[k] = 1; }); });
    return out;
  };
  qual.hubSetInsight = function (id, text) {
    var h = hubsStore().byId[id];
    if (!h) return false;
    h.insight = String(text == null ? "" : text);
    hubsPersist();
    return true;
  };
  /** Distinct respondents behind a set of collected items (idx == the respondent). The
   *  privacy unit for the hub k-gate: a named hub that isolates fewer than k distinct
   *  respondents must not be exported to the report. */
  qual.hubDistinctRespondents = function (items) {
    var seen = {};
    (items || []).forEach(function (it) { if (it && it.record) seen[it.record.idx] = 1; });
    return Object.keys(seen).length;
  };

  /**
   * Build a Story exhibit for a hub — its name, its one-line insight (the finding), a
   * coverage line, and up to `cap` illustrative quotes (with a compact demographic code
   * when safeDemos) + a "+N more" note. Returns a pinSnapshot payload
   * { source, title, context, html, lines, quotes, moreN }. Pure + node-testable — the
   * html is what the Story renders, the lines are what the image deck rasterises, and
   * quotes is the structured payload the editable deck's quote slide renders (WP4).
   * Every disclosure rule the exhibit applies travels into the payload: hidden text
   * (record.text == null) is never included; below-k hubs (safeDemos=false) carry no
   * demographic tags.
   */
  qual.hubExhibit = function (hub, items, opts) {
    opts = opts || {};
    var cap = opts.cap > 0 ? opts.cap : 8;
    var name = (hub && hub.name) || "Hub";
    var insight = ((hub && hub.insight) || "").trim();
    var coverage = (opts.coverage || "").trim();
    var safeDemos = opts.safeDemos !== false;
    var shown = (items || []).slice(0, cap);
    var moreN = (items || []).length - shown.length;
    var demoTags = function (r) {
      if (!safeDemos || !r.demos) return [];
      return Object.keys(r.demos).filter(function (k) { return r.demos[k] != null; })
        .map(function (k) { return r.demos[k]; });
    };
    var demoCode = function (r) { return demoTags(r).join(" · "); };
    var qhtml = shown.map(function (it) {
      var r = it.record, sent = SENT[r.sentiment] || "neu";
      var txt = r.text == null ? "[quote hidden]" : r.text;
      var code = demoCode(r), cite = esc(it.question.title) + (code ? " · " + esc(code) : "");
      return '<blockquote class="ql-exq ' + sent + '">' + esc(txt) + "<cite>" + cite + "</cite></blockquote>";
    }).join("");
    var html = '<div class="ql-exhibit" data-exhibit="hub"><div class="ql-exhead">' +
      '<span class="ql-exkicker">Comment hub</span><h3 class="ql-extitle">' + esc(name) + "</h3>" +
      (insight ? '<p class="ql-exins">' + esc(insight) + "</p>" : "") +
      (coverage ? '<p class="ql-excov">' + esc(coverage) + "</p>" : "") + "</div>" +
      qhtml +
      (moreN > 0 ? '<p class="ql-exmore">+ ' + moreN + " more comment" + (moreN === 1 ? "" : "s") + " in this hub</p>" : "") +
      "</div>";
    var lines = [name];
    if (insight) lines.push(insight);
    if (coverage) lines.push(coverage);
    // structured quotes for the editable deck's quote slide (WP4) — built
    // beside lines so the two carry EXACTLY the same disclosure gates
    var quotes = [];
    shown.forEach(function (it) {
      var r = it.record;
      if (r.text == null) return;   // hidden text stays hidden — never pinned
      var code = demoCode(r);
      lines.push("“" + r.text + "” — " + it.question.title + (code ? " (" + code + ")" : ""));
      quotes.push({ text: r.text, q: it.question.title,
        tags: demoTags(r), sentiment: SENT[r.sentiment] || "neu" });
    });
    if (moreN > 0) lines.push("+ " + moreN + " more");
    return { source: "qualitative", title: name, context: insight || coverage,
      html: html, lines: lines, quotes: quotes, moreN: moreN > 0 ? moreN : 0 };
  };

  function findQ(island, code) {
    var qs = island.questions || [];
    for (var i = 0; i < qs.length; i++) if (qs[i].code === code) return qs[i];
    return null;
  }

  // ---- focus reading mode (C4) -----------------------------------------------
  // A full-width single-column reading view over an ALREADY-GATED record list —
  // the same records the drawer / collection is showing, zero new data logic.
  // focusHtml/focusNav are pure (node-testable); openFocus is the DOM shell.

  /** Normalise drawer records into focus entries { record, qcode, qtitle }. */
  qual.focusEntries = function (records, q) {
    return (records || []).map(function (r) {
      return { record: r, qcode: q.code, qtitle: q.title };
    });
  };

  /** The focus view's inner HTML: header (title · position · key hints · close)
   *  + one large quote block per entry, the current one marked .cur. Honours the
   *  hidden-text + highlight rules exactly as the drawer does; opts.dropTags
   *  drops the demographic chips (a below-k hub's rule travels with it). */
  qual.focusHtml = function (entries, pos, opts) {
    opts = opts || {};
    var saveable = opts.saveable !== false;   // every current caller passes real qcode+idx
    var head = '<div class="ql-fhead"><h2 class="ql-ftitle">' + esc(opts.title || "Focus reading") + "</h2>" +
      '<span class="ql-fpos" data-focus-pos>' + (pos + 1) + " of " + entries.length + "</span>" +
      '<span class="ql-fkeys">j / k or arrow keys to move · ' +
      (saveable ? "s to shortlist · " : "") + 'Esc to close</span>' +
      '<button class="ql-fclose" data-focus-close aria-label="Close focus reading">✕</button></div>';
    var qst = qual._state || {};
    var blocks = entries.map(function (e, i) {
      var r = e.record, sent = SENT[r.sentiment] || "neu";
      var text = r.text == null
        ? '<span class="ql-hidden">[quote hidden in this copy]</span>'
        : qual.renderHighlighted(r.text, qual.getHighlights(e.qcode, r.idx));
      var word = SENT_WORD[r.sentiment]
        ? '<span class="ql-sent ' + sent + '">' + SENT_WORD[r.sentiment] + "</span>" : "";
      // Tags honour opts.dropTags (below-k hub rule) AND the reader tag toggle, "Label: value".
      var tags = (opts.dropTags || qst.tagsOff || !r.demos) ? "" : Object.keys(r.demos)
        .filter(function (k) { return r.demos[k] != null && !(qst.tagHide && qst.tagHide[k]); })
        .map(function (k) { return '<span class="ql-tag">' + esc(k) + ": " + esc(r.demos[k]) + "</span>"; }).join("");
      var saved = saveable && qual.isSaved(e.qcode, r.idx);
      var save = saveable
        ? '<button class="ql-fsave' + (saved ? " on" : "") + '" data-focus-save="' +
          esc(e.qcode) + "#" + esc(r.idx) + '" aria-pressed="' + saved +
          '" title="Shortlist this comment (s)">' + (saved ? "✓ Shortlisted" : "＋ Shortlist") + "</button>"
        : "";
      return '<blockquote class="ql-fq ' + sent + (i === pos ? " cur" : "") + '" data-fi="' + i + '" tabindex="0">' +
        '<div class="ql-fqtext">' + text + "</div>" +
        '<div class="ql-fmeta">' + save + word + tags +
        '<span class="ql-fsrc">' + esc(e.qtitle || "") + '</span><span class="ql-qid">#' + esc(r.idx) + "</span></div></blockquote>";
    }).join("");
    return head + '<div class="ql-fbody">' + blocks + "</div>";
  };

  var FOCUS_ID = "qual-focus";

  qual.closeFocus = function () {
    if (typeof document === "undefined") return;
    var open = document.getElementById(FOCUS_ID);
    if (open) open.remove();
  };

  /** Open the focus reading view. opts: title, dropTags, trigger (the element
   *  focus returns to on close). Keyboard: j/k + arrows move, Esc closes. */
  qual.openFocus = function (entries, opts) {
    if (typeof document === "undefined" || !entries || !entries.length) return;
    opts = opts || {};
    var saveable = opts.saveable !== false;
    qual.closeFocus();
    var pos = 0;
    var overlay = document.createElement("div");
    overlay.id = FOCUS_ID;
    overlay.className = "ql-focusov";
    overlay.innerHTML = '<div class="ql-focus" role="dialog" aria-modal="true" ' +
      'aria-label="Focus reading mode">' + qual.focusHtml(entries, pos, opts) + "</div>";
    // lives INSIDE #app so saveCopy (which empties #app in its clone) can never
    // bake an open focus view into a saved copy — mirrors the legend overlay
    var host = document.getElementById("app") || document.body;
    host.appendChild(overlay);
    var panel = overlay.firstChild;
    var restoreFocus = opts.trigger || document.activeElement;
    var posEl = overlay.querySelector("[data-focus-pos]");
    function setPos(p) {
      pos = p;
      overlay.querySelectorAll(".ql-fq").forEach(function (bq, i) {
        bq.classList.toggle("cur", i === pos);
      });
      if (posEl) posEl.textContent = (pos + 1) + " of " + entries.length;
      var cur = overlay.querySelector('.ql-fq[data-fi="' + pos + '"]');
      if (cur && cur.scrollIntoView) cur.scrollIntoView({ block: "center" });
    }
    function close() {
      overlay.remove();
      if (restoreFocus && restoreFocus.focus) { try { restoreFocus.focus(); } catch (e) {} }
      if (opts.onClose) opts.onClose();   // sync the underlying drawer (new shortlists show + no collapse)
    }
    // Toggle the shortlist on a focus card and update its button in place (focus manages
    // its own DOM; the drawer re-syncs on close via opts.onClose).
    function toggleFocusSave(btn) {
      var val = btn.getAttribute("data-focus-save"), at = val.lastIndexOf("#");
      var on = qual.toggleSave(val.slice(0, at), parseInt(val.slice(at + 1), 10));
      btn.classList.toggle("on", on);
      btn.setAttribute("aria-pressed", on);
      btn.textContent = on ? "✓ Shortlisted" : "＋ Shortlist";
      if (opts.onSave) opts.onSave(on);
    }
    overlay.addEventListener("click", function (e) {
      if (e.target === overlay || e.target.closest("[data-focus-close]")) { close(); return; }
      var sv = e.target.closest("[data-focus-save]");
      if (sv) { toggleFocusSave(sv); return; }        // don't also move position
      var bq = e.target.closest(".ql-fq");
      if (bq) setPos(parseInt(bq.getAttribute("data-fi"), 10));
    });
    // j/k + Esc, plus the same Tab trap as the legend panel — listeners die
    // with the overlay node, so nothing stacks across opens
    overlay.addEventListener("keydown", function (e) {
      if (saveable && (e.key === "s" || e.key === "S")) {   // shortlist the comment being read
        var cur = overlay.querySelector('.ql-fq[data-fi="' + pos + '"] [data-focus-save]');
        if (cur) { e.preventDefault(); toggleFocusSave(cur); return; }
      }
      var nav = qual.focusNav(pos, e.key, entries.length);
      if (nav.close) { e.preventDefault(); close(); return; }
      if (nav.pos !== pos) { e.preventDefault(); setPos(nav.pos); return; }
      if (e.key !== "Tab") return;
      var focusables = panel.querySelectorAll("button, [tabindex]:not([tabindex='-1'])");
      if (!focusables.length) return;
      var first = focusables[0], last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    });
    overlay.querySelector("[data-focus-close]").focus();
  };

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
    if (qual._state) { qual._state.theme = null; qual._state.showRest = false; }
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
                      theme: null, sentiment: null, band: null, tagsOff: false, tagHide: {},
                      railGroups: {}, railHidden: false, savedOnly: false,
                      themeView: "overview", xmode: "salience", xbanner: null, xexpand: null, xcounts: false,
                      view: "question", groupBy: "question", hub: null, hubEditing: null, showRest: false,
                      showChampions: false };
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

    // The pool (every shortlisted + highlighted comment) drives both the rail's "Your
    // collection" count and the collection view itself — compute it once per render.
    var collected = qual.collectPool(island, qual.savedAll(), qual.highlightsAll(), qual.hubMarksUnion());

    var body;
    if (st.view === "collection") {
      body = collectionMain(island, st, cutFilters, collected);
    } else {
      var jump = qual.jumpContext();
      var audience = qual.maskFilter(q.records, cutFilters);
      qual._view = { island: island, q: q, audience: audience };   // for the export handler
      body = breadcrumbHtml(jump) + mainHtml(island, q, st, audience);
    }
    host.innerHTML =
      '<div class="ql-wrap' + (st.railHidden ? " norail" : "") + '">' + railHtml(island, st, collected.items.length) +
        '<div class="ql-main">' +
          '<button class="ql-railtoggle" title="Show/hide the question list">⟨⟩ Questions</button>' +
          body +
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

  function railHtml(island, st, markCount) {
    var groups = [
      { key: "themed", title: "Themed", qs: island.questions.filter(function (q) { return q.type === "themed"; }) },
      { key: "raw", title: "Verbatim-only", qs: island.questions.filter(function (q) { return q.type !== "themed"; }) }
    ].filter(function (g) { return g.qs.length; });
    var html = groups.map(function (g) {
      var items = g.qs.map(function (q) {
        var sel = (st.view !== "collection" && q.code === TR.d2.state.qualQ) ? ' aria-current="true"' : "";
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
    // A pinned "Your collection" entry sits above the question groups — the reader's
    // whole pool of marks (shortlisted + highlighted) in one place, across every question.
    var colCur = st.view === "collection" ? ' aria-current="true"' : "";
    var colBtn = '<button class="ql-railcol" data-col-open' + colCur +
      ' title="Every comment you have shortlisted or highlighted, across all questions">' +
      '<span class="ql-glyph">★</span>' +
      '<span class="ql-railtitle">Your collection</span>' +
      '<span class="ql-railn">' + (markCount || 0) + '</span></button>';
    return '<nav class="ql-rail" aria-label="Open-end questions">' + colBtn + html + '</nav>';
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
    // Clear separator + scroll anchor (fix #4): mark where the chart ends and the
    // comments begin, so the section start is unmissable and the header's jump
    // button lands here. Themed only — raw questions show comments immediately.
    var divider = q.type === "themed"
      ? '<div class="ql-secdivider" id="ql-comments-anchor"><span class="ql-seclabel">💬 The comments</span></div>'
      : "";
    return headerHtml(island, q, audience) + chart + divider +
      controlsHtml(q, st, audience, island) +
      drawerHtml(island, q, st, audience) + footerHtml(island, q);
  }

  function headerHtml(island, q, audience) {
    var asked = q.base ? q.base.answered : 0;
    var shown = audience.length;
    // Below the disclosure threshold the cut's commenter count is withheld too —
    // show only the (unfiltered) answered total, matching the gated drawer.
    var gated = !!(TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall());
    var n = (gated || shown === asked) ? (asked + " answered") : (shown + " of " + asked + " answered");
    var badge = q.type === "themed" ? "THEMED" : "VERBATIM-ONLY";
    var shield = island.textMode === "full" ? "" :
      '<span class="ql-shield" title="Verbatim confidentiality">🛡 ' + esc(island.textMode) + '</span>';
    // the analyst's one-line insight for this question (optional headline field)
    var headline = qual.headlineFor(q);
    var headlineHtml = headline ? '<p class="ql-headline">' + esc(headline) + "</p>" : "";
    // C3 coverage bar — how complete the theme frame is. Below k it reads the
    // UNFILTERED records (never cut-derived), matching the gated header count.
    var cov = "";
    if (q.type === "themed" && (q.themes || []).length) {
      var c = qual.coverage(gated ? q.records : audience);
      cov = '<span class="ql-cov" title="' + c.themed + " of " + c.total +
        ' comments carry at least one theme">' +
        '<span class="ql-covtrack"><span class="ql-covfill" style="width:' + c.pct + '%"></span></span>' +
        c.pct + "% of comments themed</span>";
    }
    // Skip-to-comments (fix #4): a themed question pushes the comment list below the
    // chart, so offer a jump straight to it (the section is anchored below the chart).
    var jump = q.type === "themed"
      ? '<button class="ql-jumpcomments" data-jump-comments ' +
        'title="Skip the chart — jump to the comments and their filters">↓ Jump to comments</button>'
      : "";
    return '<header class="ql-head"><h2 class="ql-title">' + esc(q.title) + '</h2>' + headlineHtml +
      '<div class="ql-meta"><span class="ql-badge">' + badge + '</span>' +
      '<span class="ql-base">' + n + '</span>' + cov + qual.closedStatChip(q.code) + shield + jump + '</div></header>';
  }

  // One controls row: the noteworthy tier, the sentiment filter (with live counts),
  // and — next to them — the shortlist toggle (per question) + Excel export.
  function controlsHtml(q, st, audience, island) {
    // Disclosure control: below k the board/crosstab/drawer are all withheld, so this
    // row must not leak the cut either — no live sentiment counts, no export button
    // (it would emit a row per comment); the filters stay visible but disabled, with
    // the standard disclosure note.
    var gated = !!(TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall());
    var dis = gated ? " disabled" : "";
    var tierOpts = [["all", "All"], ["noteworthy", "Noteworthy+"],
                   ["must_read", "Must-read+"], ["priority", "Priority"]];
    var tier = '<div class="ql-seg" role="tablist" aria-label="Noteworthy filter">' +
      tierOpts.map(function (o) {
        return '<button class="ql-segbtn' + (st.tier === o[0] ? " on" : "") +
          '" data-tier="' + o[0] + '"' + dis + '>' + o[1] + "</button>";
      }).join("") + "</div>";

    // The band segment appears only on a split-bearing question (an NPS "why?" reassembled
    // from Detractor/Passive/Promoter sheets): All + one button per band, each with its count.
    // It narrows the LIST like the tier/sentiment segments, and the board recomputes per band.
    var band = "";
    if (q.split && (q.split.bands || []).length) {
      var bandOpts = [["", "All"]].concat((q.split.bands || []).map(function (b) { return [b, b]; }));
      var curB = st.band == null ? "" : st.band;
      band = '<div class="ql-seg bandseg" role="tablist" aria-label="' +
        esc(q.split.dim || "Split") + ' filter">' +
        bandOpts.map(function (o) {
          var cnt = gated ? null : qual.bandCount(q, audience, o[0]);
          return '<button class="ql-segbtn' + (curB === o[0] ? " on" : "") +
            '" data-band="' + esc(o[0]) + '"' + dis + '>' + esc(o[1]) +
            (cnt == null ? "" : ' <span class="ql-segn">' + cnt + "</span>") + "</button>";
        }).join("") + "</div>";
    }

    // The sentiment filter only appears when the question was actually sentiment-coded;
    // otherwise it would read "0 positive / 0 mixed / 0 negative" as if measured (it wasn't).
    var sent = "";
    if (qual.hasSentiment(q)) {
      var sc = gated ? null : qual.sentimentCounts(qual.poolBeforeSentiment(q, st, audience));
      var sentOpts = [["", "All", sc ? sc.pos + sc.neu + sc.neg : null, ""],
                      ["1", "Positive", sc ? sc.pos : null, "pos"],
                      ["2", "Mixed", sc ? sc.neu : null, "neu"],
                      ["3", "Negative", sc ? sc.neg : null, "neg"]];
      var cur = st.sentiment == null ? "" : String(st.sentiment);
      sent = '<div class="ql-seg sentseg" role="tablist" aria-label="Sentiment filter">' +
        sentOpts.map(function (o) {
          return '<button class="ql-segbtn ' + o[3] + (cur === o[0] ? " on" : "") +
            '" data-sent="' + o[0] + '"' + dis + '>' + o[1] +
            (o[2] == null ? "" : ' <span class="ql-segn">' + o[2] + "</span>") + "</button>";
        }).join("") + "</div>";
    }

    // Tag display control (Feature 2): the reader can hide all tags to declutter, or toggle
    // an individual dimension. Purely SUBTRACTIVE — it only hides fields the analyst already
    // cleared into the island (the demographic_cuts / k-anon gate runs in R), so it can never
    // reveal a suppressed value or lower k. Shown only when the island carries tag dimensions.
    var tagctl = "";
    var tagDims = ((island && island.demographics) || []).map(function (d) { return d.label; });
    if (!gated && tagDims.length) {
      var off = !!st.tagsOff;
      var fields = off ? "" : tagDims.map(function (lbl) {
        var shown = !(st.tagHide && st.tagHide[lbl]);
        return '<button class="ql-tagfield' + (shown ? " on" : "") + '" data-tagfield="' +
          esc(lbl) + '" aria-pressed="' + shown + '">' + esc(lbl) + "</button>";
      }).join("");
      tagctl = '<div class="ql-tagctl"><button class="ql-tagall' + (off ? "" : " on") +
        '" data-tagall aria-pressed="' + (!off) +
        '" title="Show or hide the demographic tags on each comment">🏷 Tags</button>' +
        fields + "</div>";
    }

    var savedN = qual.savedCount(q.code);
    var actions = '<div class="ql-actions">' +
      '<button class="ql-savedonly' + (st.savedOnly ? " on" : "") + '" data-savedonly' + dis +
        ' aria-pressed="' + st.savedOnly +
        '" title="Show only the comments you have shortlisted for this question">' +
        "★ Shortlist" + (savedN ? " (" + savedN + ")" : "") + "</button>" +
      (gated ? "" :
        '<button class="ql-export" data-qual-export title="Download the comments shown here as an Excel file">' +
        "⬇ Export</button>") + "</div>";
    // Labelled "Filter the comments below" — these narrow the LIST, not the chart above.
    // On themed questions the section divider above already separates it, so drop the
    // controls' own top rule to avoid a double line (fix #4).
    var undivided = q.type === "themed" ? " undivided" : "";
    return '<div class="ql-controls' + undivided + '"><span class="ql-ctrllbl">Filter the comments below:</span>' +
      band + tier + sent + tagctl + actions +
      (gated ? '<span class="ql-disclosure">🛡 ' + esc(TR.disclosure.note()) + "</span>" : "") + "</div>";
  }

  function prevalenceHtml(q, st, audience) {
    // Disclosure control: the board shows per-theme counts over the live audience, so on a
    // sub-threshold cut it would reveal small-cell detail ("1 of 3 raised it, 1 negative")
    // for a named cut. Withhold the whole board below k, mirroring the crosstab gate.
    if (TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall()) {
      return '<div class="ql-board"><p class="ql-disclosure">🛡 ' + esc(TR.disclosure.note()) + "</p></div>";
    }
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
    var card = function (r, other) {
      var sel = r.id === st.theme ? " on" : "";
      var tot = r.pos + r.neu + r.neg || 1;           // sentiment-coded mentions of this theme
      var f = (r.neg + r.neu / 2) / tot;              // fraction of the bar that sits left of zero
      var bar = '<span class="ql-dtrack"><span class="ql-dzero"></span>' +
        '<span class="ql-dbar" style="left:' + (50 - f * W) + "%;width:" + W + '%">' +
          seg("neg", r.neg, tot) + seg("neu", r.neu, tot) + seg("pos", r.pos, tot) + "</span></span>";
      var netCls = r.net > 0 ? "pos" : r.net < 0 ? "neg" : "neu";
      var title = other
        ? (r.n + " of " + audience.length + " commented without raising a coded theme (" +
           r.pos + " positive, " + r.neu + " mixed, " + r.neg + " negative)")
        : (r.label + " — " + r.n + " of " + audience.length + " raised it unprompted (" +
           r.pos + " positive, " + r.neu + " mixed, " + r.neg + " negative)");
      // 1–2 championed quotes inline (C2), gated behind the inline-comments toggle
      // (fix #3, default off) so the chart overview stays clean until asked for.
      // Selection is the balanced-spread rule (fix #1, see qual.championQuotes);
      // the text is clamped to 3 lines (fix #2, see .ql-champtext) so a long
      // comment can't blow out the card. Reached only ABOVE the disclosure gate.
      var champ = st.showChampions ? qual.championQuotes(audience, r.id, q.code, 2).map(function (c) {
        return '<div class="ql-champq ' + (SENT[c.sentiment] || "neu") + '">' +
          '<span class="ql-champtext">“' + esc(c.text) + '”</span>' +
          '<span class="ql-champid">#' + esc(c.idx) +
          (qual.isSaved(q.code, c.idx) ? " · shortlisted" : "") + "</span></div>";
      }).join("") : "";
      return '<div class="ql-tcard"><div class="ql-trow">' +
        '<button class="ql-prow' + sel + '" data-theme="' + r.id + '" title="' + esc(title) + '">' +
          '<span class="ql-plabel' + (other ? " other" : "") + '">' + esc(r.label) + "</span>" + bar +
          '<span class="ql-ppct">' + r.pct + '%<span class="ql-pn">n=' + r.n + "</span></span>" +
          '<span class="ql-pnet ' + netCls + '">net ' + (r.net > 0 ? "+" : "") + r.net + "%</span>" +
        "</button>" +
        '<button class="ql-tfocus" data-theme-focus="' + r.id +
          '" title="Read these comments in focus mode" aria-label="Read ' + esc(r.label) +
          ' in focus mode">⤢</button></div>' +
        (champ ? '<div class="ql-champ">' + champ + "</div>" : "") + "</div>";
    };
    var body = rows.map(function (r) { return card(r, false); }).join("");
    // C3: the unthemed comments as a first-class card — same treatment, ranked
    // last regardless of volume so the frame's themes always lead.
    var unthemed = qual.unthemed(audience);
    if (unthemed.length) {
      var uc = qual.sentimentCounts(unthemed);
      var un = uc.pos + uc.neu + uc.neg;
      body += card({ id: qual.OTHER_THEME, label: "Everything else", n: unthemed.length,
        pct: Math.round(unthemed.length / audience.length * 100),
        pos: uc.pos, neu: uc.neu, neg: uc.neg,
        net: un ? Math.round((uc.pos - uc.neg) / un * 100) : 0 }, true);
    }
    var axis = '<div class="ql-daxis"><span></span>' +
      '<span class="ql-dends"><span>← more negative</span><span>more positive →</span></span></div>';
    // Inline-comments toggle (fix #3): off by default, so the board opens as a
    // clean overview; ticking it reveals the balanced-spread example comments and
    // a one-line note (fix #1) making the selection rule visible to the reader.
    var champChecked = st.showChampions ? " checked" : "";
    var tools = '<label class="ql-inlinetoggle" title="Show a couple of example comments beneath each theme bar">' +
      '<input type="checkbox" data-champtoggle' + champChecked + "> Show example comments</label>";
    var champRule = st.showChampions
      ? '<span class="ql-hint ql-champrule">Examples show one positive + one negative comment per theme; ' +
        "your ★ shortlisted picks always lead.</span>"
      : "";
    // Honesty note: when the report curates the readable set (qual_verbatim_scope /
    // hide markers), say so on the board's face — the distribution reflects EVERY
    // comment, but only a subset are shown as readable quotes. Keeps a reader from
    // mistaking "few quotes" for "few comments".
    var shownN = qual.shown(audience).length, totalN = audience.length;
    var scopeNote = shownN < totalN
      ? '<span class="ql-hint ql-scopenote">Distribution reflects all ' + totalN +
        " comments; " + shownN + " are shown as readable quotes (the rest are counted, not displayed).</span>"
      : "";
    return '<div class="ql-board"><div class="ql-boardhd">' +
      '<div class="ql-boardhdrow"><span class="ql-boardttl">What people raised</span>' +
      '<div class="ql-boardtools">' + tools + "</div></div>" +
      '<span class="ql-hint">Ranked by salience (% of the ' + audience.length +
      ' who raised each theme <b>unprompted</b>, right). Each bar is the sentiment <i>mix</i> ' +
      'of that theme’s comments, so every theme is equal width and the lean shows the balance: ' +
      '<b class="qc-neg">negative</b> left, <b class="qc-pos">positive</b> right, ' +
      '<b class="qc-neu">mixed</b> centre; net = net sentiment %. ' +
      "Click a theme to read its comments.</span>" + champRule + scopeNote +
      "</div>" + axis + '<div class="ql-boardgrid">' + body + "</div></div>";
  }

  // ---- theme x banner crosstab (supplements the prevalence board) ------------
  // An "Overview / Crosstab" switch sits above the chart: Overview is the diverging
  // prevalence board (default, unchanged); Crosstab is the theme x banner table —
  // salience + net sentiment per column, expandable to the pos/mixed/neg split,
  // with an analyst insight that pins to the Story alongside the table.

  function hasBanner() {
    // The theme×banner crosstab recomputes from per-respondent banner membership
    // (columnsFor reads TR.MICRO.banner_vars), so an aggregates-only ship
    // (html_report_v2_microdata = N ships TR.MICRO = null) cannot offer it —
    // hide the Overview/Crosstab toggle and fall back to the overview board,
    // the same trade that turns off live filters and custom banners.
    return !!(TR.AGG && TR.AGG.banner_groups && TR.AGG.banner_groups.length &&
      TR.stats && TR.stats.columnsFor && TR.MICRO && TR.MICRO.banner_vars);
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
    // Disclosure control: when a composite filter (or a closed<->open jump) narrows the
    // audience below the confidentiality threshold, withhold the WHOLE comment list — the
    // verbatim text, the demographic tags and even the comment count could identify a person
    // on a small named cut. The threshold is on the respondent audience, so k = the full
    // sample hides comments on any sub-cut; only the full-sample view shows them.
    if (TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall()) {
      return '<div class="ql-drawer"><div class="ql-disclosure" role="note">🛡 ' +
        esc(TR.disclosure.note()) + "</div></div>";
    }
    var records = qual.visibleRecords(q, st, audience);
    var caption;
    if (st.savedOnly) {
      caption = "Shortlisted comments";
    } else if (q.type === "themed" && st.theme === qual.OTHER_THEME) {
      caption = "Comments with no coded theme (everything else)";
    } else if (q.type === "themed" && st.theme != null) {
      var th = (q.themes || []).filter(function (t) { return t.id === st.theme; })[0];
      caption = 'Comments mentioning “' + esc(th ? th.label : "") + '”';
    } else {
      caption = q.type === "themed" ? "All comments (pick a theme above to filter)" : "Comments";
    }
    if (st.sentiment != null && qual.hasSentiment(q)) caption = (SENT_WORD[st.sentiment] || "") + " · " + caption;
    if (q.split && st.band != null && st.band !== "") caption = esc(st.band) + " · " + caption;
    var focusBtn = records.length
      ? '<button class="ql-focusbtn" data-qual-focus ' +
        'title="Read these comments one at a time — j/k or arrows to move, Esc to close">⤢ Focus</button>'
      : "";
    return '<div class="ql-drawer"><div class="ql-drawerhd">' + caption +
      ' <span class="ql-hint">(' + records.length + ")</span>" + focusBtn + "</div>" +
      drawerCardsHtml(records, q, st) + "</div>";
  }

  // Curated-first (C1): the analyst's selection (shortlisted / highlighted)
  // leads under its own rubric; "show all N" expands the rest. Presentation
  // only — both halves are the SAME already-gated visible-record list, and the
  // shortlist-only view (already curated by definition) keeps its flat list.
  function drawerCardsHtml(records, q, st) {
    if (!records.length) {
      return '<p class="ql-empty">' + (st.savedOnly
        ? "No shortlisted comments yet — use ＋ Shortlist on a comment."
        : "No comments for this selection.") + "</p>";
    }
    var cardOf = function (r) { return quoteCard(r, q.code); };
    var split = st.savedOnly ? { curated: [], rest: records } : qual.curatedSplit(records, q.code);
    if (!split.curated.length) return records.map(cardOf).join("");
    var html = '<div class="ql-curhd">★ Analyst’s selection <span class="ql-hint">(' +
      split.curated.length + ")</span></div>" + split.curated.map(cardOf).join("");
    if (!split.rest.length) return html;
    if (st.showRest) {
      html += '<div class="ql-curhd rest">All comments</div>' + split.rest.map(cardOf).join("") +
        '<button class="ql-showall" data-qual-showall aria-expanded="true">' +
        "Back to the analyst’s selection</button>";
    } else {
      html += '<button class="ql-showall" data-qual-showall aria-expanded="false">Show all ' +
        records.length + " comments</button>";
    }
    return html;
  }

  // Reached only when the audience is at/above the disclosure threshold (drawerHtml gates
  // the whole list below k), so demographic tags are safe to show here.
  function quoteCard(r, qcode) {
    var sent = SENT[r.sentiment] || "neu";
    var text = (r.text == null)
      ? '<span class="ql-hidden">[quote hidden in this copy]</span>'
      : qual.renderHighlighted(r.text, qual.getHighlights(qcode, r.idx));   // select-to-highlight
    var star = r.tier >= 3 ? '<span class="ql-star priority" title="priority">★</span>'
             : r.tier >= 2 ? '<span class="ql-star must" title="must-read">★</span>'
             : r.tier >= 1 ? '<span class="ql-star" title="noteworthy">★</span>' : '';
    // Tags honour the reader's tag toggle (hide-all / per-field), and read "Label: value"
    // so several dimensions stay legible ("Centre: Worcester DC · Channel: Presell"). The
    // toggle is subtractive only — a field absent from r.demos (gated/k-anon in R) can't appear.
    var qst = qual._state || {};
    var tags = (!qst.tagsOff && r.demos ? Object.keys(r.demos) : [])
      .filter(function (k) { return r.demos[k] != null && !(qst.tagHide && qst.tagHide[k]); })
      .map(function (k) { return '<span class="ql-tag">' + esc(k) + ": " + esc(r.demos[k]) + "</span>"; }).join("");
    var saved = qual.isSaved(qcode, r.idx);
    var save = '<button class="ql-save' + (saved ? " on" : "") + '" data-qual-save="' +
      esc(qcode) + "#" + esc(r.idx) + '" aria-pressed="' + saved + '" title="' +
      (saved ? "Remove from your shortlist" : "Add to your shortlist") + '">' +
      (saved ? "✓ Shortlisted" : "＋ Shortlist") + "</button>";
    // sentiment word beside the edge accent — the coding is never colour-only
    var sentWord = SENT_WORD[r.sentiment]
      ? '<span class="ql-sent ' + sent + '">' + SENT_WORD[r.sentiment] + "</span>" : "";
    return '<div class="ql-quote ' + sent + '" data-hl-key="' + esc(qcode) + "#" + esc(r.idx) + '">' + star +
      '<div class="ql-qbody"><span class="ql-qtext">' + text + '</span>' +
      (tags ? '<div class="ql-tags">' + tags + '</div>' : '') +
      hubControlHtml(qcode + "#" + r.idx) + '</div>' +
      '<div class="ql-qfoot">' + save + sentWord + '<span class="ql-qid">#' + esc(r.idx) + "</span></div></div>";
  }

  function footerHtml(island, q) {
    var dropped = q.meta && q.meta.dropped_codes ? q.meta.dropped_codes : 0;
    var bits = [(q.base ? q.base.answered : 0) + " comments",
                island.textMode !== "hidden" ? "✎ select text in a comment to highlight a passage" : null,
                q.type === "themed" ? "themes are salience (raised unprompted), not prompted incidence" : null,
                island.demographicCuts === "block" ? "demographic cuts blocked" :
                island.demographicCuts === "safe" ? "demographic tags shown only where the group is large enough" : null,
                dropped ? (dropped + " stray code(s) quarantined") : null,
                "verbatims shown by ID — never model-authored"];
    return '<footer class="ql-foot">' + bits.filter(Boolean).join(" · ") + '</footer>';
  }

  // ---- collection view: the whole pool of marks, across questions ------------
  // Reached from the pinned "Your collection" rail entry. Aggregates every shortlisted
  // + highlighted comment (qual.collectPool), applies the SAME global cut as the rest of
  // the tab, groups by question or theme, and gates on the disclosure threshold exactly
  // like the drawer. It reads the pool and never mutates a mark. One .ql-drawer wraps all
  // the cards so the select-to-highlight wiring works here too.

  function filterItems(items, filters) {
    if (!filters || !filters.length || !TR.stats || !TR.MICRO) return items;
    var mask = TR.stats.mask(filters);
    return items.filter(function (it) { return mask[it.record.idx] === 1; });
  }

  // The hub selector bar: "All marks" + a chip per hub (name + pool-resolved count),
  // a "＋ New hub" affordance, and — for the selected hub — inline rename / delete.
  // Only one inline text input is ever open (st.hubEditing is a single value).
  function hubBarHtml(st, total, resolvedCounts) {
    var chip = function (id, label, count, on) {
      return '<button class="ql-hubsel' + (on ? " on" : "") + '" data-hubsel="' + esc(id == null ? "" : id) +
        '">' + esc(label) + ' <span class="ql-hubseln">' + count + "</span></button>";
    };
    var chips = chip(null, "All marks", total, st.hub == null);
    qual.hubList().forEach(function (h) {
      var c = resolvedCounts[h.id] != null ? resolvedCounts[h.id] : h.count;
      chips += chip(h.id, h.name, c, st.hub === h.id);
    });
    var newBit = (st.hubEditing === "new")
      ? '<span class="ql-hubnewrow"><input class="ql-hubinput" data-hubnewinput type="text" ' +
        'placeholder="hub name" maxlength="60"><button class="ql-hubbtn" data-hubnewgo>Add</button>' +
        '<button class="ql-hublink" data-hubnewcancel>Cancel</button></span>'
      : '<button class="ql-hublink" data-hubnew>＋ New hub</button>';
    var manage = "";
    if (st.hub != null && qual.hubGet(st.hub)) {
      manage = (st.hubEditing === st.hub)
        ? '<span class="ql-hubnewrow"><input class="ql-hubinput" data-hubrenameinput type="text" value="' +
          esc(qual.hubGet(st.hub).name) + '" maxlength="60"><button class="ql-hubbtn" data-hubrenamego>Save</button>' +
          '<button class="ql-hublink" data-hubrenamecancel>Cancel</button></span>'
        : '<button class="ql-hublink" data-hubrename title="Rename this hub">✎ Rename</button>' +
          '<button class="ql-hublink danger" data-hubdel ' +
          'title="Delete this hub — its comments stay in the pool">🗑 Delete</button>';
    }
    // The chips scroll horizontally (many hubs never wrap into a wall); New / rename /
    // delete stay pinned to the right, always in reach.
    return '<div class="ql-hubbar"><span class="ql-ctrllbl">Hubs:</span>' +
      '<div class="ql-hubchips">' + chips + "</div>" + newBit + manage + "</div>";
  }

  // The per-card add-to-hub control, on BOTH the question drawer and the collection: the
  // hubs this comment is already in shown as removable chips, plus a compact "Add to hub"
  // dropdown that scales to any number of hubs (a native menu, never a chip wall). Filing a
  // comment in a hub pools it, so this is also how you save a comment straight from the
  // question list — shortlist and hub in one, no separate ★ needed.
  function hubControlHtml(key) {
    var m = qual.splitMark(key);
    if (!m) return "";
    var inIds = {};
    var chips = qual.hubsForMark(m.qcode, m.idx).map(function (h) {
      inIds[h.id] = 1;
      return '<span class="ql-hubchip">' + esc(h.name) +
        '<button class="ql-hubx" data-hubremove="' + esc(h.id) + '" data-hubkey="' + esc(key) +
        '" title="Remove from ' + esc(h.name) + '" aria-label="Remove from this hub">×</button></span>';
    }).join("");
    var opts = '<option value="" disabled selected>＋ Add to hub…</option>';
    qual.hubList().forEach(function (h) {
      if (inIds[h.id]) return;                          // only offer hubs it is NOT already in
      opts += '<option value="hub:' + esc(h.id) + '">' + esc(h.name) + "</option>";
    });
    opts += '<option value="new">＋ New hub…</option>';
    return '<div class="ql-cardhubs">' + chips +
      '<select class="ql-hubaddsel" data-hubadd="' + esc(key) + '" aria-label="Add this comment to a hub">' +
      opts + "</select></div>";
  }

  function collectionCard(it, ctx) {
    ctx = ctx || {};
    var q = it.question, r = it.record, qcode = it.qcode, key = qcode + "#" + r.idx;
    var sent = SENT[r.sentiment] || "neu";
    var text = (r.text == null)
      ? '<span class="ql-hidden">[quote hidden in this copy]</span>'
      : qual.renderHighlighted(r.text, qual.getHighlights(qcode, r.idx));
    var byId = {}; (q.themes || []).forEach(function (t) { byId[String(t.id)] = t.label; });
    var chips = Object.keys(r.themeVals || {}).filter(function (id) { return r.themeVals[id] != null && byId[id]; })
      .map(function (id) { return '<span class="ql-cchip">' + esc(byId[id]) + "</span>"; }).join("");
    var tags = ctx.dropTags ? "" : (r.demos ? Object.keys(r.demos) : []).filter(function (k) { return r.demos[k] != null; })
      .map(function (k) { return '<span class="ql-tag">' + esc(r.demos[k]) + "</span>"; }).join("");
    var flags = (it.saved ? '<span class="ql-cflag" title="shortlisted">★</span>' : "") +
                (it.highlighted ? '<span class="ql-cflag" title="has a highlighted passage">✎</span>' : "");
    return '<div class="ql-quote ' + sent + ' ql-ccard" data-hl-key="' + esc(key) + '">' +
      '<div class="ql-qbody">' +
        '<div class="ql-csrc"><button class="ql-cjump" data-col-jump="' + esc(qcode) +
          '" title="Go to this question">' + esc(q.title) + " ›</button>" + flags + "</div>" +
        '<span class="ql-qtext">' + text + "</span>" +
        (chips ? '<div class="ql-cthemes">' + chips + "</div>" : "") +
        (tags ? '<div class="ql-tags">' + tags + "</div>" : "") +
        hubControlHtml(key) +
      "</div>" +
      '<div class="ql-qfoot">' + (SENT_WORD[r.sentiment]
        ? '<span class="ql-sent ' + sent + '">' + SENT_WORD[r.sentiment] + "</span>" : "") +
      '<span class="ql-qid">#' + esc(r.idx) + "</span></div></div>";
  }

  function collectionMain(island, st, cutFilters, pool) {
    var total = pool.items.length;

    // Resolve the selected hub (drop a stale selection), and count each hub's
    // pool-resolved membership — its marks that are actually in the pool right now.
    if (st.hub != null && !qual.hubGet(st.hub)) st.hub = null;
    var poolKeys = {};
    pool.items.forEach(function (it) { poolKeys[it.qcode + "#" + it.idx] = 1; });
    var resolved = {};
    qual.hubList().forEach(function (h) {
      var marks = qual.hubMarks(h.id), n = 0;
      Object.keys(marks).forEach(function (k) { if (poolKeys[k]) n++; });
      resolved[h.id] = n;
    });
    var activeHub = st.hub != null ? qual.hubGet(st.hub) : null;
    var scopeTotal = activeHub ? resolved[activeHub.id] : total;
    var head = '<header class="ql-head"><h2 class="ql-title">★ Your collection</h2>' +
      '<div class="ql-meta"><span class="ql-badge">' + (activeHub ? esc(activeHub.name) : "ALL MARKS") +
      '</span><span class="ql-base">' + scopeTotal + (scopeTotal === 1 ? " mark" : " marks") + "</span></div></header>";
    var hubBar = hubBarHtml(st, total, resolved);

    if (!total) {
      qual._colview = { island: island, items: [] };
      return head + hubBar + '<div class="ql-drawer"><p class="ql-empty">Nothing collected yet. As you read, ' +
        "★ shortlist a comment or ✎ highlight a passage — they gather here, across every question.</p></div>";
    }
    // A named hub is a hand-picked set — INDEPENDENT of the audience filter (show all its
    // members). "All marks" is the exploratory view: it honours the live cut, and a below-k
    // cut hides it (a small cut-derived view could identify). A selected hub is NOT a cut,
    // so that gate does not apply to it — a hub is shown whatever the filter.
    var cutDesc = (cutFilters && TR.d2 && TR.d2.filterDescription) ? TR.d2.filterDescription() : "";
    var shown;
    if (activeHub) {
      shown = pool.items.filter(function (it) { return activeHub.marks[it.qcode + "#" + it.idx]; });
    } else {
      if (TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall()) {
        qual._colview = { island: island, items: [] };
        return head + hubBar + '<div class="ql-drawer"><div class="ql-disclosure" role="note">🛡 ' +
          esc(TR.disclosure.note()) + "</div></div>";
      }
      shown = cutFilters ? filterItems(pool.items, cutFilters) : pool.items;
    }

    // §4 for a hub: the COMMENTS are never the secret (they live in their questions); what
    // the threshold protects is DEMOGRAPHIC tags on a small named set. So a hub with fewer
    // than k distinct respondents keeps its comments but drops the per-comment tags — on
    // screen AND in the exported exhibit — rather than being blocked from the report.
    var hubBelowK = !!(activeHub && TR.disclosure && TR.disclosure.active && TR.disclosure.active() &&
      qual.hubDistinctRespondents(shown) < TR.disclosure.minBase());
    var safeDemos = activeHub
      ? !hubBelowK
      : !(TR.disclosure && TR.disclosure.audienceTooSmall && TR.disclosure.audienceTooSmall());

    var groupBy = st.groupBy === "theme" ? "theme" : "question";
    var groups = qual.groupCollection(island, shown, groupBy);

    var toggle = '<div class="ql-seg" role="tablist" aria-label="Group the collection by">' +
      '<button class="ql-segbtn' + (groupBy === "question" ? " on" : "") + '" data-colgroup="question">By question</button>' +
      '<button class="ql-segbtn' + (groupBy === "theme" ? " on" : "") + '" data-colgroup="theme">By theme</button></div>';
    var actions = '<div class="ql-actions">' +
      (shown.length ? '<button class="ql-focusbtn" data-col-focus ' +
        'title="Read these comments one at a time — j/k or arrows to move, Esc to close">⤢ Focus</button>' : "") +
      '<button class="ql-export" data-col-export ' +
      'title="Download everything shown here as an Excel file">⬇ Export</button></div>';

    var noun = shown.length === 1 ? " mark" : " marks";
    var cover, coverPlain;
    if (activeHub) {
      cover = "Showing all " + shown.length + noun + " in " + esc(activeHub.name);
      if (cutDesc) cover += ' · <span class="ql-cut">a hub shows all its comments — the filter doesn’t narrow it</span>';
      coverPlain = "Illustrating " + shown.length + noun + " in " + activeHub.name;
    } else {
      cover = shown.length === scopeTotal
        ? ("Showing all " + scopeTotal + noun)
        : ("Showing " + shown.length + " of " + scopeTotal + noun + (cutDesc ? " in this cut" : ""));
      if (cutDesc) cover += ' · <span class="ql-cut">' + esc(cutDesc) + "</span>";
      coverPlain = "Illustrating " + shown.length + " of " + scopeTotal + noun + (cutDesc ? " · " + cutDesc : "");
    }
    if (pool.orphans) cover += ' · <span class="ql-orphan" title="These marks point at comments not present ' +
      'in this data run — re-mark to refresh them">' + pool.orphans +
      " mark" + (pool.orphans === 1 ? "" : "s") + " no longer match this data</span>";
    qual._colview = { island: island, items: shown, hub: activeHub, coverPlain: coverPlain,
                      safeDemos: safeDemos, dropTags: hubBelowK };

    // A selected hub gets an insight field (the one-line finding) + "Add to story". Never
    // blocked: a below-k hub just drops its demographic tags (safeDemos above), with a calm
    // note — the comments themselves are already in the report.
    var insightBlock = "";
    if (activeHub) {
      var promote = shown.length === 0
        ? '<span class="ql-hubsmall">add comments to build this hub’s story</span>'
        : '<button class="ql-hubpromote" data-hub-promote ' +
          'title="Add this hub — its finding + quotes — to the Story tab">📌 Add to story</button>' +
          (hubBelowK ? '<span class="ql-hubsmall" title="Fewer than the confidentiality threshold of ' +
            TR.disclosure.minBase() + ' distinct respondents — demographic tags are hidden in the report">🛡 tags hidden</span>' : "");
      insightBlock = '<div class="insight ql-hubinsight"><div class="insight-head">Hub insight — the one-line finding' +
        '<span class="ql-xspacer"></span>' + promote + "</div>" +
        '<textarea class="ql-hubinstext" data-hub-insight ' +
        'placeholder="What’s the story of this hub? (one line — travels to the report when you add it to the Story)">' +
        esc(activeHub.insight || "") + "</textarea></div>";
    }

    var ctx = { dropTags: hubBelowK };
    var emptyMsg = activeHub
      ? ("“" + esc(activeHub.name) + "” is empty — switch to All marks and use ＋ Hub on a comment to add it.")
      : "No marks fall in this cut — broaden the filter to see them.";
    var cards = groups.length
      ? groups.map(function (g) {
          return '<div class="ql-colhd">' + esc(g.label) +
            ' <span class="ql-hint">(' + g.items.length + ")</span></div>" +
            g.items.map(function (it) { return collectionCard(it, ctx); }).join("");
        }).join("")
      : '<p class="ql-empty">' + emptyMsg + "</p>";

    return head + hubBar + insightBlock +
      '<div class="ql-controls"><span class="ql-ctrllbl">Group your marks:</span>' + toggle + actions + "</div>" +
      '<div class="ql-colcover">' + cover + "</div>" +
      '<div class="ql-drawer ql-coldrawer">' + cards + "</div>";
  }

  // ---- interaction -----------------------------------------------------------

  /** A data-theme attribute back to a theme id (numeric, or the OTHER sentinel). */
  function themeAttr(raw) {
    return raw === qual.OTHER_THEME ? raw : parseInt(raw, 10);
  }

  /** Display label for a theme id (the focus view's title). */
  function focusThemeLabel(q, id) {
    if (id === qual.OTHER_THEME) return "Everything else";
    var th = (q.themes || []).filter(function (t) { return t.id === id; })[0];
    return th ? th.label : "Theme";
  }

  function wire(host, island) {
    var st = qual._state;
    host.querySelectorAll(".ql-railitem").forEach(function (b) {
      b.addEventListener("click", function () {
        TR.d2.state.qualQ = b.getAttribute("data-q");
        st.theme = null;
        st.band = null;                   // a new question resets the split-band segment to All
        st.showRest = false;              // a new question re-collapses to the curated selection
        st.view = "question";             // a question click leaves the collection
        qual.clearJump();                 // leaving the jumped open-end drops the cut breadcrumb
        qual.render(host);
      });
    });
    // collection view: open it, switch its grouping, jump from a card to its question
    var colOpen = host.querySelector("[data-col-open]");
    if (colOpen) colOpen.addEventListener("click", function () {
      st.view = "collection"; st.hubEditing = null; qual.render(host);
    });
    host.querySelectorAll("[data-colgroup]").forEach(function (b) {
      b.addEventListener("click", function () { st.groupBy = b.getAttribute("data-colgroup"); qual.render(host); });
    });
    host.querySelectorAll("[data-col-jump]").forEach(function (b) {
      b.addEventListener("click", function () {
        TR.d2.state.qualQ = b.getAttribute("data-col-jump");
        st.theme = null; st.band = null; st.showRest = false; st.view = "question";
        qual.clearJump();
        qual.render(host);
      });
    });
    wireHubs(host, st);
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
    host.querySelectorAll("[data-band]").forEach(function (b) {
      b.addEventListener("click", function () {
        var v = b.getAttribute("data-band");
        st.band = v === "" ? null : v;   // "" = All
        qual.render(host);
      });
    });
    var tagall = host.querySelector("[data-tagall]");
    if (tagall) tagall.addEventListener("click", function () { st.tagsOff = !st.tagsOff; qual.render(host); });
    host.querySelectorAll("[data-tagfield]").forEach(function (b) {
      b.addEventListener("click", function () {
        var lbl = b.getAttribute("data-tagfield");
        if (!st.tagHide) st.tagHide = {};
        st.tagHide[lbl] = !st.tagHide[lbl];
        qual.render(host);
      });
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
        var id = themeAttr(b.getAttribute("data-theme"));
        st.theme = (st.theme === id) ? null : id;   // toggle
        qual.render(host);
      });
    });
    // C4 focus reading mode: from a theme card, the drawer, or the collection.
    // Every entry reuses the ALREADY-GATED records its surface is showing.
    host.querySelectorAll("[data-theme-focus]").forEach(function (b) {
      b.addEventListener("click", function () {
        var v = qual._view;
        if (!v) return;
        var id = themeAttr(b.getAttribute("data-theme-focus"));
        var stTheme = { tier: st.tier, sentiment: st.sentiment, savedOnly: st.savedOnly, theme: id };
        qual.openFocus(qual.focusEntries(qual.visibleRecords(v.q, stTheme, v.audience), v.q),
          { title: focusThemeLabel(v.q, id) + " — " + v.q.title, trigger: b,
            onSave: function () { st.showRest = true; }, onClose: function () { qual.render(host); } });
      });
    });
    var fb = host.querySelector("[data-qual-focus]");
    if (fb) fb.addEventListener("click", function () {
      var v = qual._view;
      if (v) qual.openFocus(qual.focusEntries(qual.visibleRecords(v.q, st, v.audience), v.q),
        { title: v.q.title, trigger: fb,
          onSave: function () { st.showRest = true; }, onClose: function () { qual.render(host); } });
    });
    var cf = host.querySelector("[data-col-focus]");
    if (cf) cf.addEventListener("click", function () {
      var v = qual._colview;
      if (!v || !v.items.length) return;
      qual.openFocus(v.items.map(function (it) {
        return { record: it.record, qcode: it.qcode, qtitle: it.question.title };
      }), { title: v.hub ? v.hub.name : "Your collection", dropTags: v.dropTags, trigger: cf,
        onClose: function () { qual.render(host); } });
    });
    // curated-first: expand / re-collapse the non-selected comments
    var sa = host.querySelector("[data-qual-showall]");
    if (sa) sa.addEventListener("click", function () { st.showRest = !st.showRest; qual.render(host); });
    // the closed-stat chip: back to the linked closed question's crosstab card
    host.querySelectorAll("[data-qual-return]").forEach(function (b) {
      b.addEventListener("click", function () {
        qual.clearJump();
        if (TR.shell && TR.shell.goQuestion) TR.shell.goQuestion(b.getAttribute("data-qual-return"));
      });
    });
    // inline-comments toggle (fix #3): show/hide the example comments under each bar
    var champT = host.querySelector("[data-champtoggle]");
    if (champT) champT.addEventListener("change", function () { st.showChampions = champT.checked; qual.render(host); });
    // jump-to-comments (fix #4): scroll straight to the comments section anchor
    var jumpC = host.querySelector("[data-jump-comments]");
    if (jumpC) jumpC.addEventListener("click", function () {
      var anchor = host.querySelector("#ql-comments-anchor");
      if (anchor && anchor.scrollIntoView) anchor.scrollIntoView({ behavior: "smooth", block: "start" });
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
        st.showRest = true;   // marking a comment must never collapse the list you're reading
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
    var colEx = host.querySelector("[data-col-export]");
    if (colEx) colEx.addEventListener("click", function () {
      var v = qual._colview;
      if (v) qual.exportCollectionXlsx(v.island, v.items, v.safeDemos);
    });
    wireHighlights(host);
  }

  // ---- hub interactions (selector bar + per-card add-to-hub picker) ----------

  function inputVal(host, sel) { var el = host.querySelector(sel); return el ? String(el.value || "") : ""; }
  function commitNewHub(host, st) {
    var name = inputVal(host, "[data-hubnewinput]").trim();
    if (name) st.hub = qual.hubCreate(name);   // create and select it
    st.hubEditing = null;
    qual.render(host);
  }
  function commitRename(host, st) {
    var name = inputVal(host, "[data-hubrenameinput]").trim();
    if (name && st.hub != null) qual.hubRename(st.hub, name);
    st.hubEditing = null;
    qual.render(host);
  }
  function wireHubs(host, st) {
    host.querySelectorAll("[data-hubsel]").forEach(function (b) {
      b.addEventListener("click", function () {
        var v = b.getAttribute("data-hubsel");
        st.hub = v === "" ? null : v;
        st.hubEditing = null;
        qual.render(host);
      });
    });
    var byId = function (a) { return host.querySelector("[" + a + "]"); };
    var on = function (a, fn) { var el = byId(a); if (el) el.addEventListener("click", fn); };
    on("data-hubnew", function () { st.hubEditing = "new"; qual.render(host); });
    on("data-hubnewgo", function () { commitNewHub(host, st); });
    on("data-hubnewcancel", function () { st.hubEditing = null; qual.render(host); });
    on("data-hubrename", function () { st.hubEditing = st.hub; qual.render(host); });
    on("data-hubrenamego", function () { commitRename(host, st); });
    on("data-hubrenamecancel", function () { st.hubEditing = null; qual.render(host); });
    on("data-hubdel", function () {
      var h = qual.hubGet(st.hub);
      if (!h) return;
      if (typeof confirm !== "undefined" && !confirm('Delete the hub "' + h.name + '"? Its comments stay in your collection.')) return;
      qual.hubDelete(st.hub); st.hub = null; st.hubEditing = null;
      qual.render(host);
    });
    // per-card add-to-hub dropdown (scales to any number of hubs) + remove-from-hub
    // chips — present on BOTH the question drawer and the collection cards.
    host.querySelectorAll("[data-hubadd]").forEach(function (sel) {
      sel.addEventListener("change", function () {
        var m = qual.splitMark(sel.getAttribute("data-hubadd")), val = sel.value;
        if (!m) return;
        if (val === "new") {
          var name = (typeof prompt !== "undefined") ? prompt("New hub name:") : null;
          if (name && name.trim()) qual.hubToggleMark(qual.hubCreate(name), m.qcode, m.idx);
        } else if (val.indexOf("hub:") === 0) {
          qual.hubToggleMark(val.slice(4), m.qcode, m.idx);   // only not-in hubs are offered -> adds
        }
        qual.render(host);
      });
    });
    host.querySelectorAll("[data-hubremove]").forEach(function (b) {
      b.addEventListener("click", function () {
        var m = qual.splitMark(b.getAttribute("data-hubkey"));
        if (m) qual.hubToggleMark(b.getAttribute("data-hubremove"), m.qcode, m.idx);   // in-hub -> removes
        qual.render(host);
      });
    });
    // hub insight (persist on input, NO re-render so the cursor stays put) + promote to story
    var ins = host.querySelector("[data-hub-insight]");
    if (ins) ins.addEventListener("input", function () { if (st.hub != null) qual.hubSetInsight(st.hub, ins.value); });
    var promote = host.querySelector("[data-hub-promote]");
    if (promote) promote.addEventListener("click", function () {
      var v = qual._colview;
      if (!v || !v.hub || !TR.story2 || !TR.story2.pinSnapshot) return;
      // Never blocked — a below-k hub already ships with its demographic tags dropped
      // (v.safeDemos, set in collectionMain); the comments are safe to include.
      TR.story2.pinSnapshot(qual.hubExhibit(v.hub, v.items, { coverage: v.coverPlain, safeDemos: v.safeDemos }));
    });
    // Enter submits / Escape cancels the inline inputs; focus the header edit input.
    var enterKey = function (sel, go, esc) {
      var el = host.querySelector(sel);
      if (!el) return;
      el.addEventListener("keydown", function (e) {
        if (e.key === "Enter") { e.preventDefault(); go(); }
        else if (e.key === "Escape") { e.preventDefault(); esc(); }
      });
    };
    enterKey("[data-hubnewinput]", function () { commitNewHub(host, st); }, function () { st.hubEditing = null; qual.render(host); });
    enterKey("[data-hubrenameinput]", function () { commitRename(host, st); }, function () { st.hubEditing = null; qual.render(host); });
    if (st.hubEditing) {
      var f = host.querySelector("[data-hubnewinput], [data-hubrenameinput]");
      if (f && f.focus) { try { f.focus(); } catch (e) {} }
    }
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
        if (qual._state) qual._state.showRest = true;   // highlighting must not collapse the list either
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
