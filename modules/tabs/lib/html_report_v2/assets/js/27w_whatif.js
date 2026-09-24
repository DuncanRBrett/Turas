/**
 * What if tab (TR.whatif).
 *
 * Renders a What if contribution (modules/whatif), already cut by the tabs
 * build to this report's delivery mode (.read_whatif_contribution):
 *
 *   open  The island carries the model and each respondent's lever values,
 *         lined up with the report's own records. The tab is LIVE: the group is
 *         whatever the filter bar says, and every number is worked out exactly,
 *         respondent by respondent, from the fixed model.
 *   safe  The island carries the model and precomputed results for published
 *         groups only (modules/shared/lib/disclosure_groups.R: minimum group,
 *         secondary suppression, nesting and recoverability checks). The
 *         tab has its own picker, offers only published groups, and adds up
 *         single-area results for combined scenarios, labelled approximate.
 *
 * Panels: the headline, where to direct effort, build a scenario, Build a ...
 * (who the respondent is), Rate as one (how they rate), diagnostics.
 *
 * Association, not cause: nothing here says fixing an area WILL add points.
 * A respondent flagged dk in the open rows gave no rating for that lever: the
 * live view leaves them out of the need count and the moves, as R does. The
 * model block's halo check marks an area whose effect collapses when the other
 * areas are held (shown under the area, never greyed to zero).
 * Literal strings only (no TR.txt keys), no em dashes.
 */
(function (global) {
  "use strict";
  var TR = global.TR;
  var wi = TR.whatif = {};

  // ---------------------------------------------------------------- helpers
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }
  function f1(x) {
    if (x === null || x === undefined || isNaN(x)) return "n/a";
    var r = Math.round(x * 10) / 10;
    if (r === 0) return "0.0";
    return (r > 0 ? "+" : "−") + Math.abs(r).toFixed(1);
  }
  function f0(x) {
    if (x === null || x === undefined || isNaN(x)) return "n/a";
    var r = Math.round(x);
    return r === 0 ? "0" : (r > 0 ? "+" : "−") + Math.abs(r);
  }
  function r0(x) { return (x === null || x === undefined || isNaN(x)) ? "n/a" : String(Math.round(x)); }
  /** A result the R build withheld (null in a client-safe island): it would
   *  rest on fewer than the minimum group, alone or against another group. */
  function withheld(s) { return !s || s.pt === null || s.pt === undefined || isNaN(s.pt); }
  function pct(a, q) {
    var b = a.filter(function (v) { return v !== null && !isNaN(v); }).sort(function (x, y) { return x - y; });
    if (!b.length) return NaN;
    var k = (b.length - 1) * q, lo = Math.floor(k), hi = Math.ceil(k);
    return b[lo] + (b[hi] - b[lo]) * (k - lo);
  }
  /** The refit range's coverage, from the island (the R engine's
   *  whatif_summarise_draws uses the same), never typed here. */
  function rangeLevel() { var v = Number((meta().range_level)); return v > 0 && v < 1 ? v : 0.9; }
  function rangeName() { return Math.round(100 * rangeLevel()) + "% range"; }
  /** Point from the main fit, range from the refits. */
  function summ(d) {
    var r = d.slice(1), t = (1 - rangeLevel()) / 2;
    return { pt: d[0], lo: r.length ? pct(r, t) : NaN, hi: r.length ? pct(r, 1 - t) : NaN };
  }
  function sig(z) { return 1 / (1 + Math.exp(-z)); }
  function cap(s) { s = String(s || ""); return s.charAt(0).toUpperCase() + s.slice(1); }
  function an(word) { return /^[aeiou]/i.test(word) ? "an" : "a"; }

  function W() { return TR.WI || {}; }
  function meta() { return W().meta || {}; }
  function model() { return W().model || {}; }

  /** Expected score for one respondent: probabilities of each outcome
   *  category from the cumulative logit, times each category's score. */
  function scoreAt(fit, eta, scores) {
    var th = fit.theta, prev = 0, s = 0;
    for (var j = 0; j < th.length; j++) {
      var F = sig(th[j] - eta);
      s += (F - prev) * scores[j];
      prev = F;
    }
    return s + (1 - prev) * scores[th.length];
  }
  function probsAt(fit, eta) {
    var th = fit.theta, prev = 0, out = [];
    for (var j = 0; j < th.length; j++) { var F = sig(th[j] - eta); out.push(F - prev); prev = F; }
    out.push(1 - prev);
    return out;
  }
  wi._scoreAt = scoreAt;

  function scaleOf() { return meta().scale || { min: 1, max: 5, centre: 3, good: 4 }; }
  function goodOf(lv) { var t = lv.target; return (t === null || t === undefined || isNaN(t)) ? scaleOf().good : t; }
  function labelOf(v) {
    var sc = scaleOf(), labs = sc.labels || [];
    var i = Math.round(v) - sc.min;
    return labs.length && labs[i] ? labs[i] : String(v);
  }

  /** Change in a lever's model column for one respondent under a move.
   *  The JavaScript twin of whatif_move_delta() in modules/whatif/R/04_moves.R.
   *  dk: the respondent gave no rating for this lever (the value is a fill),
   *  so no rating move touches them. */
  function delta(lv, move, v, dk) {
    var sc = scaleOf();
    if (lv.kind === "coverage") {
      if (move === "extend") return v ? 0 : 1;
      if (move === "withdraw") return v ? -1 : 0;
      return 0;
    }
    if (v === null || v === undefined || dk) return 0;
    if (move === "floor") return Math.max(v, goodOf(lv)) - v;
    var s = { slip2: -2, slip1: -1, up1: 1, up2: 2 }[move];
    if (s === undefined) return 0;
    return Math.max(sc.min, Math.min(sc.max, v + s)) - v;
  }
  wi._delta = delta;

  function slipMove(lv) { return lv.kind === "coverage" ? "withdraw" : "slip1"; }
  function fixMove(lv) { return lv.kind === "coverage" ? "extend" : "floor"; }
  function movesFor(lv) { return lv.kind === "coverage" ? ["extend", "withdraw"] : ["slip2", "slip1", "up1", "up2", "floor"]; }
  function moveLabel(lv, m) {
    var M = meta(), unit = M.unit || "respondent", sc = scaleOf(), step = sc.step || "point";
    var steps = step === "notch" ? "notches" : "points", good = labelOf(goodOf(lv));
    if (lv.kind === "coverage") return { withdraw: "Withdrawn from every " + unit + " with it", extend: "Extended to every " + unit + " without it" }[m];
    return { slip2: "Slips 2 " + steps, slip1: "Slips 1 " + step, up1: "Improves 1 " + step,
             up2: "Improves 2 " + steps, floor: "Everyone below " + good + " lifted to " + good }[m];
  }
  function unclear(key) {
    var s = (model().sign || {})[key];
    return s !== undefined && s !== null && s > (model().unclear_share || 0.1);
  }
  /** The halo check from the R engine: the lever's fix effect fitted alone
   *  against its partial effect (the other areas held where they are), for
   *  everyone. Flagged when the partial effect is under the ratio. */
  function halo(key) {
    var h = (model().halo || {})[key];
    return h && h.flag === true ? h : null;
  }
  function haloNum(h) { return h && typeof h.single === "number" && typeof h.partial === "number"; }
  function haloText(key) {
    var h = halo(key);
    if (!h) return "";
    return "Caught in the halo: fixed on its own this area " + (haloNum(h)
      ? "is worth " + f1(h.single) + " points for everyone, " + f1(h.partial) + " with the other areas held where they are."
      : "is worth far more than with the other areas held where they are (the numbers rest on too few to show).") +
      " The data cannot separate it from the areas it moves with.";
  }
  /** Whether respondent i gave no rating of their own for the lever. */
  function dkOf(O, key, i) {
    var d = O.dk && O.dk[key];
    return !!(d && d[i]);
  }

  // ---------------------------------------------------------------- mode
  wi.state = { safeFilters: [], scen: {}, prof: null, profNote: "", rate: null, rateHas: {} };

  /** Whether this report carries a What if contribution at all. */
  wi.available = function () {
    var d = TR.WI;
    return !!(d && d.meta && d.meta.kind === "whatif" && d.model && d.model.fits && d.model.fits.length &&
              (d.open || (d.safe && d.safe.groups && d.safe.groups.length)));
  };

  /** Live: open rows are present and the report's respondent records are
   *  installed, so the tab can follow the filter bar exactly. */
  wi.live = function () {
    var d = TR.WI;
    return !!(d && d.meta && d.meta.mode === "open" && d.open && TR.stats &&
              typeof TR.stats.source === "function" && TR.stats.source() === "micro");
  };

  // ---------------------------------------------------------------- open mode
  var etaCache = null;
  /** Linear predictor per respondent for every fit, from the open rows.
   *  null for respondents outside the model. */
  function etas() {
    if (etaCache && etaCache.src === TR.WI) return etaCache.e;
    var M = model(), O = W().open, n = O.n, C = scaleOf().centre, out = [];
    var lvByKey = {};
    M.levers.forEach(function (lv) { lvByKey[lv.key] = lv; });
    var cols = M.design.map(function (c) {
      if (c.context) {
        var levels = (O.ctx_levels || {})[c.lever] || [];
        return { ctx: O.ctx[c.lever], code: levels.indexOf(c.part) };
      }
      var lv = lvByKey[c.lever];
      return { lv: lv, val: O.val[c.lever], part: c.part };
    });
    M.fits.forEach(function (fit) {
      var e = new Array(n);
      for (var i = 0; i < n; i++) {
        if (O.y[i] === null || O.y[i] === undefined) { e[i] = null; continue; }
        var s = 0;
        for (var j = 0; j < cols.length; j++) {
          var c = cols[j], b = fit.b[j];
          if (c.ctx) { if (c.ctx[i] === c.code) s += b; continue; }
          var v = c.val[i];
          if (c.lv.kind === "rating") s += b * (v - C);
          else if (c.lv.kind === "coverage") s += b * v;
          else if (c.part === "has") s += b * (v === null || v === undefined ? 0 : 1);
          else s += b * (v === null || v === undefined ? 0 : v - C);
        }
        e[i] = s;
      }
      out.push(e);
    });
    etaCache = { src: TR.WI, e: out };
    return out;
  }

  /** Respondents in the current audience who are in the model. */
  function openIdx(mask) {
    var O = W().open, idx = [];
    for (var i = 0; i < O.n; i++) {
      if (O.y[i] === null || O.y[i] === undefined) continue;
      if (mask && !mask[i]) continue;
      idx.push(i);
    }
    return idx;
  }

  /** Change in the group's expected score under a set of moves, per fit. */
  function openChange(idx, moves) {
    var M = model(), O = W().open, E = etas(), scores = meta().scores, out = [];
    var levers = M.levers;
    for (var f = 0; f < M.fits.length; f++) {
      var fit = M.fits[f], e = E[f], sw = 0, d = 0;
      for (var q = 0; q < idx.length; q++) {
        var i = idx[q], base = e[i], e2 = base;
        for (var l = 0; l < levers.length; l++) {
          var mv = moves[levers[l].key];
          if (mv) e2 += fit.b[levers[l].col] * delta(levers[l], mv, O.val[levers[l].key][i], dkOf(O, levers[l].key, i));
        }
        if (e2 !== base) d += O.w[i] * (scoreAt(fit, e2, scores) - scoreAt(fit, base, scores));
        sw += O.w[i];
      }
      out.push(sw ? d / sw : NaN);
    }
    return out;
  }

  /** A live group: actual score, who needs each fix, and the draws. */
  function openGroup(mask) {
    var M = model(), O = W().open, scores = meta().scores, idx = openIdx(mask);
    if (!idx.length) return { n: 0 };
    var sw = 0, sc = 0;
    idx.forEach(function (i) { sw += O.w[i]; sc += O.w[i] * scores[O.y[i] - 1]; });
    var one = function (lv, m) { var mv = {}; mv[lv.key] = m; return openChange(idx, mv); };
    return {
      n: idx.length, actual: sc / sw, exact: true,
      need: M.levers.map(function (lv) {
        var c = 0, vals = O.val[lv.key];
        idx.forEach(function (i) {
          var v = vals[i];
          if (lv.kind === "coverage" ? !v : (v !== null && v !== undefined && !dkOf(O, lv.key, i) && v < goodOf(lv))) c++;
        });
        return c;
      }),
      slip: M.levers.map(function (lv) { return summ(one(lv, slipMove(lv))); }),
      fix: M.levers.map(function (lv) { return summ(one(lv, fixMove(lv))); }),
      scenario: function (moves) { return summ(openChange(idx, moves)); },
      bundle: function (b) { return summ(openChange(idx, b.moves)); },
      single: function (lv, m) { return summ(one(lv, m)); }
    };
  }
  wi._openGroup = openGroup;

  // ---------------------------------------------------------------- safe mode
  function defKey(def) {
    return Object.keys(def).sort().map(function (k) { return k + "=" + def[k]; }).join("|");
  }
  function safeIndex() {
    var S = W().safe, idx = {};
    S.groups.forEach(function (g, i) { idx[defKey(g.def || {})] = i; });
    return idx;
  }
  function curSafeDef() {
    var d = {};
    wi.state.safeFilters.forEach(function (f) { d[f.key] = f.level; });
    return d;
  }
  function crossingDeclared(k1, k2) {
    return (W().safe.declared || []).some(function (p) {
      return (p[0] === k1 && p[1] === k2) || (p[0] === k2 && p[1] === k1);
    });
  }
  /** A published group: precomputed point and 90% range per lever and move. */
  function safeGroup(def) {
    var S = W().safe, M = model(), moves = M.moves, i = safeIndex()[defKey(def)];
    if (i === undefined) return null;
    var g = S.groups[i];
    var at = function (l, m) {
      var j = moves.indexOf(m);
      return { pt: g.est[l][j], lo: g.lo[l][j], hi: g.hi[l][j] };
    };
    return {
      n: g.n, actual: g.actual, exact: false, label: g.label, family: g.family,
      need: g.need,
      slip: M.levers.map(function (lv, l) { return at(l, slipMove(lv)); }),
      fix: M.levers.map(function (lv, l) { return at(l, fixMove(lv)); }),
      single: function (lv, m) { return at(M.levers.indexOf(lv), m); },
      // Adding single-area results; the range combines each part's half-width
      // as if independent. Approximate, and labelled so.
      scenario: function (movesByKey) {
        var pt = 0, lo2 = 0, hi2 = 0, any = false, hidden = false;
        M.levers.forEach(function (lv, l) {
          var m = movesByKey[lv.key];
          if (!m) return;
          var s = at(l, m);
          if (withheld(s)) { hidden = true; return; }
          any = true;
          pt += s.pt;
          lo2 += Math.pow(s.pt - s.lo, 2);
          hi2 += Math.pow(s.hi - s.pt, 2);
        });
        if (hidden) return { pt: NaN, lo: NaN, hi: NaN, hidden: true };
        return any ? { pt: pt, lo: pt - Math.sqrt(lo2), hi: pt + Math.sqrt(hi2) } : { pt: NaN, lo: NaN, hi: NaN };
      },
      bundle: function (b, bi) {
        var r = g.bundles && g.bundles[bi];
        return r ? { pt: r[0], lo: r[1], hi: r[2] } : { pt: NaN, lo: NaN, hi: NaN };
      }
    };
  }
  wi._safeGroup = safeGroup;

  // ---------------------------------------------------------------- the group shown now
  function currentGroup() {
    if (wi.live()) {
      var filters = (TR.d2 && TR.d2.state && TR.d2.state.filters) || [];
      var mask = filters.length ? TR.stats.mask(filters) : null;
      var who = filters.length && TR.d2.filterDescription ? TR.d2.filterDescription() : "all " + (meta().units || "respondents");
      var key = JSON.stringify(filters);
      if (!wi._cache || wi._cache.key !== key || wi._cache.src !== TR.WI) {
        wi._cache = { key: key, src: TR.WI, g: openGroup(mask) };
      }
      var g = wi._cache.g;
      g.who = who;
      return g;
    }
    var def = curSafeDef(), sg = safeGroup(def);
    if (sg) sg.who = wi.state.safeFilters.length ? wi.state.safeFilters.map(function (f) { return f.level; }).join(", ") : "all " + (meta().units || "respondents");
    return sg;
  }

  // ---------------------------------------------------------------- the score line
  function scoreRange() {
    var s = meta().scores || [-100, 0, 100];
    return [Math.min.apply(null, s), Math.max.apply(null, s)];
  }
  function lineHtml(hollow, hollowLabel, filled, band) {
    var rg = scoreRange(), span = rg[1] - rg[0] || 1;
    var pos = function (v) { return Math.max(0, Math.min(100, 100 * (v - rg[0]) / span)).toFixed(2) + "%"; };
    var ticks = [0, 0.25, 0.5, 0.75, 1].map(function (t) { return rg[0] + t * span; });
    var h = '<div class="wi-line" aria-hidden="true"><div class="wi-track"></div>';
    if (band && !isNaN(band[0]) && !isNaN(band[1])) {
      h += '<div class="wi-band" style="left:' + pos(Math.min(band[0], band[1])) + ';width:calc(' +
        pos(Math.max(band[0], band[1])) + " - " + pos(Math.min(band[0], band[1])) + ')"></div>';
    }
    ticks.forEach(function (v) { h += '<div class="wi-tick" style="left:' + pos(v) + '">' + Math.round(v) + "</div>"; });
    if (hollow !== null && hollow !== undefined && !isNaN(hollow)) {
      h += '<div class="wi-dot wi-hollow" style="left:' + pos(hollow) + '"></div>' +
        '<div class="wi-cap" style="left:' + pos(hollow) + '">' + esc(hollowLabel) + " " + r0(hollow) + "</div>";
    }
    if (filled !== null && filled !== undefined && !isNaN(filled)) {
      h += '<div class="wi-dot wi-fill" style="left:' + pos(filled) + '">' + r0(filled) + "</div>";
    }
    return h + "</div>";
  }

  function pinButton(title, ctx) {
    return '<button class="snap-pin" data-snap-pin data-snap-source="whatif" data-snap-title="' + esc(title) +
      '" data-snap-context="' + esc(ctx) + '" title="Pin this card to the story" aria-label="Pin card to story">📌</button>';
  }

  // ---------------------------------------------------------------- panels
  function headHtml(G) {
    var M = meta(), live = wi.live(), label = M.score_label || "Score";
    var h = '<div class="wi-panel wi-head">';
    h += "<h2>What if <span class=\"wi-badge " + (live ? "wi-live" : "wi-safe") + "\">" +
      (live ? "Live: follows the audience filter" : "Client-safe: published groups only") + "</span></h2>";
    h += '<p class="wi-prov">Outcome: <b>' + esc(M.outcome_text || "") + "</b>. Ordinal model on " +
      esc((M.outcome_levels || []).join(", ")) + ", estimated once on " + esc(M.n) + " " + esc(M.units || "respondents") +
      (M.weighted ? ", weighted" : ", unweighted") + ". Showing <b>" + esc(G ? G.who : "") + "</b>.</p>";
    h += '<p class="wi-note">' + (live
      ? "The model was estimated once, on every " + esc(M.unit || "respondent") + ". The filter changes who it is applied to, not the model, so this tab recalculates as you filter."
      : "This file carries no individual answers. Results were prepared for groups of at least " + esc(M.min_group) + " " +
        esc(M.units || "respondents") + ", and the picker below offers only those groups.") + "</p>";
    if (!live) h += safePickerHtml();
    if (G && G.n >= (M.min_group || 1)) {
      h += '<div class="wi-kpis"><div class="wi-kpi"><b>' + r0(G.actual) + "</b><span>Actual " + esc(label) + "</span></div>" +
        '<div class="wi-kpi"><b>' + esc(G.n) + "</b><span>" + esc(cap(M.units || "respondents")) + " in the model</span></div></div>";
      if (G.n < (M.reliability_floor || 30)) {
        h += '<p class="wi-warn">Only ' + esc(G.n) + " " + esc(M.units) + " in this group. Results under " +
          esc(M.reliability_floor) + " are thin: a pointer, not a finding.</p>";
      }
    }
    return h + "</div>";
  }

  function safePickerHtml() {
    var S = W().safe, st = wi.state, M = meta(), idx = safeIndex();
    var h = '<div class="wi-picker"><span class="wi-lbl">Group</span>';
    st.safeFilters.forEach(function (f, q) {
      var lab = (S.filters.filter(function (x) { return x.key === f.key; })[0] || {}).label || f.key;
      h += '<span class="wi-chip">' + esc(lab) + ": " + esc(f.level) +
        ' <button data-wi-unfilter="' + q + '" aria-label="Remove">&times;</button></span>';
    });
    if (st.safeFilters.length < 2) {
      h += '<select data-wi-addfilter aria-label="Add a group filter"><option value="">+ Choose a group</option>';
      S.filters.forEach(function (f) {
        if (st.safeFilters.some(function (x) { return x.key === f.key; })) return;
        if (st.safeFilters.length === 1 && !crossingDeclared(st.safeFilters[0].key, f.key)) return;
        var levels = [];
        S.groups.forEach(function (g) {
          var d = g.def || {}, ks = Object.keys(d);
          if (ks.indexOf(f.key) === -1 || ks.length !== st.safeFilters.length + 1) return;
          var ok = st.safeFilters.every(function (x) { return d[x.key] === x.level; });
          if (ok) levels.push({ level: d[f.key], n: g.n });
        });
        if (!levels.length) return;
        h += '<optgroup label="' + esc(f.label) + '">';
        levels.forEach(function (l) {
          h += '<option value="' + esc(f.key + "\u0001" + l.level) + '">' + esc(l.level) + " (n=" + l.n + ")</option>";
        });
        h += "</optgroup>";
      });
      h += "</select>";
    }
    return h + '<span class="wi-lbl-note">' + esc(S.groups.length) + " published groups, each at least " +
      esc(M.min_group) + " " + esc(M.units) + "</span></div>";
  }

  function effortHtml(G) {
    var M = meta(), md = model(), units = M.units || "respondents", unit = M.unit || "respondent";
    var rows = md.levers.map(function (lv, j) {
      var cnt = G.need[j], fix = G.fix[j];
      return { lv: lv, j: j, slip: G.slip[j], fix: fix, cnt: cnt,
               per100: (cnt && !withheld(fix)) ? fix.pt * G.n / cnt : null, unclear: unclear(lv.key) };
    }).sort(function (a, b) { return (a.unclear - b.unclear) || ((withheld(b.fix) ? 0 : b.fix.pt) - (withheld(a.fix) ? 0 : a.fix.pt)); });
    var mx = Math.max.apply(null, rows.filter(function (r) { return !r.unclear && r.per100 !== null; })
      .map(function (r) { return r.per100; }).concat([1]));
    var h = '<div class="wi-panel" data-snap-card><div class="wi-cardhead"><h3>Where to direct effort</h3>' +
      pinButton("Where to direct effort", G.who) + "</div>";
    h += '<p class="wi-lead">What ' + esc(M.score_label || "the score") + " would lose if an area slipped, and gain if it were fixed for the " +
      esc(units) + " who need it, for " + esc(G.who) + ".</p>";
    h += '<table class="wi-table"><thead><tr><th>Area</th><th class="num">' + esc(cap(units)) + " who need it</th>" +
      '<th class="num">If it slips</th><th class="num">If fixed</th><th class="num">Net gain per 100 ' + esc(units) +
      ' reached</th><th class="wi-barcol"></th></tr></thead><tbody>';
    rows.forEach(function (r) {
      var lv = r.lv, sub = r.unclear ? "Effect unclear: points the wrong way in " + Math.round(100 * md.sign[lv.key]) + "% of refits"
        : halo(lv.key) ? haloText(lv.key) + (lv.sub ? " " + lv.sub : "") : lv.sub;
      var needTxt = r.cnt === null || r.cnt === undefined ? "not shown" : String(r.cnt);
      h += "<tr" + (r.unclear ? ' class="wi-unclear"' : halo(lv.key) ? ' class="wi-halo"' : "") + "><td>" + esc(lv.label) +
        '<span class="wi-tag">' + (lv.kind === "coverage" ? "coverage" : "rating") + "</span>" +
        (sub ? "<small>" + esc(sub) + "</small>" : "") + "</td>";
      h += '<td class="num">' + esc(needTxt) + "</td>";
      [r.slip, r.fix].forEach(function (s) {
        h += '<td class="num">' + (r.unclear ? "~0" : withheld(s) ? "not shown" :
          f1(s.pt) + '<span class="wi-rng">' + f1(s.lo) + " to " + f1(s.hi) + "</span>") + "</td>";
      });
      h += '<td class="num">' + (r.unclear ? "~0" : r.per100 === null ? "n/a" : f0(r.per100)) + "</td>";
      var w = r.unclear || r.per100 === null ? 0 : Math.max(0, 100 * r.per100 / mx);
      h += '<td class="wi-barcol"><div class="wi-bar"><i style="width:' + w.toFixed(1) + '%"></i></div></td></tr>';
    });
    h += "</tbody></table>";
    var sc = scaleOf(), good = labelOf(sc.good);
    h += '<p class="wi-note">Ratings: slipping is one ' + esc(sc.step || "point") + " lower for everyone; fixing lifts every " +
      esc(unit) + " below " + esc(good) + " up to " + esc(good) + ". Coverage: slipping withdraws it from every " + esc(unit) +
      " who has it; fixing extends it to everyone without it. Points of " + esc(M.score_label || "score") +
      ", with the " + rangeName() + " across the refits underneath. " +
      (G.exact ? "" : "A count or an effect is not shown when it would rest on fewer than " + esc(M.min_group) + " " + esc(units) +
        ", on its own or set against another published group.") + "</p>";
    return h + "</div>";
  }

  function scenarioHtml(G) {
    var M = meta(), md = model(), st = wi.state, label = M.score_label || "score";
    var h = '<div class="wi-panel" data-snap-card><div class="wi-cardhead"><h3>Build a scenario</h3>' +
      pinButton("What if scenario", G.who) + "</div>";
    h += '<p class="wi-lead">' + (G.exact
      ? "Combine moves across areas. Worked out exactly, " + esc(M.unit) + " by " + esc(M.unit) + ", for the current group."
      : "Combine moves across areas. Each area's own result is added up, so combined results are approximate; the bundles below show how close that gets.") + "</p>";
    h += '<div class="wi-grid">';
    md.levers.forEach(function (lv) {
      h += "<label><span>" + esc(lv.label) + "</span><select data-wi-scen=\"" + esc(lv.key) + '" aria-label="' +
        esc(lv.label) + ' scenario"><option value="">No change</option>';
      movesFor(lv).forEach(function (m) {
        h += '<option value="' + m + '"' + (st.scen[lv.key] === m ? " selected" : "") + ">" + esc(moveLabel(lv, m)) + "</option>";
      });
      h += "</select></label>";
    });
    h += "</div>";
    var chosen = Object.keys(st.scen).filter(function (k) { return st.scen[k]; });
    if (!chosen.length) {
      h += '<p class="wi-scenres">' + esc(cap(label)) + " for " + esc(G.who) + ": <b>" + r0(G.actual) +
        "</b>. Choose at least one move above.</p>" + lineHtml(G.actual, "Now", null, null);
    } else {
      var s = G.scenario(st.scen), to = G.actual + s.pt;
      if (s.hidden) {
        h += '<p class="wi-scenres">' + esc(cap(label)) + " for " + esc(G.who) + ": <b>" + r0(G.actual) +
          "</b>. Not shown: one of the chosen moves is not published for this group, because it would rest on fewer than " +
          esc(M.min_group) + " " + esc(M.units) + ".</p>" + lineHtml(G.actual, "Now", null, null);
      } else {
      h += '<p class="wi-scenres">' + esc(cap(label)) + " for " + esc(G.who) + ": <b>" + r0(G.actual) + "</b> to <b>" + r0(to) +
        "</b> (" + f1(s.pt) + " points" + (G.exact ? "" : ", approximate") + "; " + rangeName() + " " + f1(s.lo) + " to " + f1(s.hi) + ").</p>";
      h += lineHtml(G.actual, "Now", to, [G.actual + s.lo, G.actual + s.hi]);
      }
      var unc = md.levers.filter(function (lv) { return st.scen[lv.key] && unclear(lv.key); }).map(function (lv) { return lv.label; });
      if (unc.length) h += '<p class="wi-note">' + esc(unc.join(" and ")) + (unc.length > 1 ? " have" : " has") + " no reliable effect, so that part is noise.</p>";
    }
    if ((md.bundles || []).length) {
      h += '<table class="wi-table wi-bundles"><thead><tr><th>Bundle</th><th class="num">Worked out together</th>' +
        '<th class="num">Sum of each part</th></tr></thead><tbody>';
      md.bundles.forEach(function (b, bi) {
        // "Sum of each part" adds single-area results, the client-safe
        // shortcut, so the reader sees how far it is from the exact answer.
        var ex = G.bundle(b, bi), parts = { pt: 0, hidden: false };
        md.levers.forEach(function (lv) {
          if (!b.moves[lv.key]) return;
          var s = G.single(lv, b.moves[lv.key]);
          if (withheld(s)) parts.hidden = true; else parts.pt += s.pt;
        });
        h += "<tr><td>" + esc(b.name) + (b.text ? "<small>" + esc(b.text) + "</small>" : "") + "</td>" +
          '<td class="num">' + (withheld(ex) ? "not shown" : f1(ex.pt) + '<span class="wi-rng">' + f1(ex.lo) + " to " + f1(ex.hi) + "</span>") + "</td>" +
          '<td class="num">' + (parts.hidden ? "not shown" : f1(parts.pt)) + "</td></tr>";
      });
      h += "</tbody></table>";
    }
    return h + "</div>";
  }

  // ---------------------------------------------------------------- Build a ...
  function profileModel() { return wi.live() ? W().profile : (W().safe && W().safe.profile); }

  function orderedLevels(k) {
    var lv = k.levels.slice(), ord = k.order;
    if (ord === "numeric") {
      lv.sort(function (a, b) { var x = parseFloat(a), y = parseFloat(b); return (isNaN(x) ? 1e9 : x) - (isNaN(y) ? 1e9 : y); });
    } else if (ord && typeof ord === "string" && ord.indexOf(";") !== -1) {
      var o = ord.split(";").map(function (s) { return s.trim(); });
      lv.sort(function (a, b) { var i = o.indexOf(a), j = o.indexOf(b); return (i < 0 ? 999 : i) - (j < 0 ? 999 : j); });
    }
    return lv;
  }

  /** Levels of a trait that Structure rules allow with the other choices. */
  function allowedLevels(P, key, prof) {
    var rules = P.rules || [];
    return P.keys.filter(function (k) { return k.key === key; })[0].levels.filter(function (lvl) {
      return !rules.some(function (r) {
        return (r[0] === key && r[1] === lvl && prof[r[2]] === r[3]) || (r[2] === key && r[3] === lvl && prof[r[0]] === r[1]);
      });
    });
  }
  wi._allowedLevels = allowedLevels;

  function comboOf(P, prof) {
    return P.keys.map(function (k) { return k.levels.indexOf(prof[k.key]); });
  }
  function comboAllowed(P, prof) {
    if (!P.combos) return true;
    var c = comboOf(P, prof).join(",");
    return P.combos.some(function (cb) { return cb.join(",") === c; });
  }

  /** Make a profile allowed after one trait changed. Open: switch any trait the
   *  Structure rules now block to its allowed level with the most respondents.
   *  Client-safe: switch to the offered combination that keeps the most choices. */
  function repairProfile(P, prof, changed) {
    var note = [];
    if (P.combos) {
      if (!comboAllowed(P, prof)) {
        var best = null, bestKeep = -1;
        var ci = P.keys.map(function (k) { return k.key; }).indexOf(changed);
        P.combos.forEach(function (cb) {
          // Keep the trait the reader just chose; change the others as little as possible.
          if (ci !== -1 && P.keys[ci].levels[cb[ci]] !== prof[changed]) return;
          var keep = 0;
          P.keys.forEach(function (k, i) { if (k.levels[cb[i]] === prof[k.key]) keep++; });
          if (keep > bestKeep) { bestKeep = keep; best = cb; }
        });
        if (best) {
          P.keys.forEach(function (k, i) {
            if (k.levels[best[i]] !== prof[k.key]) { note.push(k.label); prof[k.key] = k.levels[best[i]]; }
          });
        }
      }
      return note.length ? "Changed " + note.join(", ") + " to keep to profiles that at least " + meta().min_group + " " + meta().units + " share." : "";
    }
    P.keys.forEach(function (k) {
      if (k.key === changed || !k.structural) return;
      var ok = allowedLevels(P, k.key, prof);
      if (ok.indexOf(prof[k.key]) === -1 && ok.length) {
        var bestL = ok[0], bestN = -1;
        ok.forEach(function (l) { var n = (k.n || [])[k.levels.indexOf(l)] || 0; if (n > bestN) { bestN = n; bestL = l; } });
        prof[k.key] = bestL;
        note.push(k.label);
      }
    });
    return note.length ? "Changed " + note.join(", ") + ": that combination does not exist." : "";
  }
  wi._repairProfile = repairProfile;

  function defaultProfile(P) {
    var prof = {};
    if (P.combos && P.combos.length) {
      P.keys.forEach(function (k, i) { prof[k.key] = k.levels[P.combos[0][i]]; });
      return prof;
    }
    P.keys.forEach(function (k) { prof[k.key] = k.levels[0]; });
    repairProfile(P, prof, null);
    return prof;
  }

  function profileScore(P, prof, fit) {
    var eta = 0;
    P.keys.forEach(function (k) { eta += fit.b[k.key][k.levels.indexOf(prof[k.key])] || 0; });
    return { score: scoreAt(fit, eta, meta().scores), probs: probsAt(fit, eta) };
  }
  wi._profileScore = profileScore;

  function buildHtml() {
    var P = profileModel(), M = meta(), st = wi.state;
    if (!P || !P.keys || !P.keys.length) return "";
    if (!st.prof || !P.keys.every(function (k) { return st.prof[k.key] !== undefined && k.levels.indexOf(st.prof[k.key]) !== -1; })) {
      st.prof = defaultProfile(P);
    }
    var prof = st.prof, unit = M.unit || "respondent", units = M.units || "respondents";
    var h = '<div class="wi-panel" data-snap-card><div class="wi-cardhead"><h3>Build ' + an(unit) + " " + esc(unit) + "</h3>" +
      pinButton("Build " + an(unit) + " " + unit, "") + "</div>";
    h += '<p class="wi-lead">Choose who the ' + esc(unit) + " is. The model gives the " + esc(M.score_label || "score") +
      " it expects from " + esc(units) + " like this, against all " + esc(units) + ". The group above does not apply here.</p>";
    var keyed = {};
    P.keys.forEach(function (k) { keyed[k.key] = k; });
    var pieces = (P.sentence && P.sentence.length) ? P.sentence : P.keys.map(function (k) { return { key: k.key, text: "", style: "" }; });
    var s = '<div class="wi-sentence">';
    pieces.forEach(function (p) {
      var t = (p.text || "").trim();
      if (t) s += (/^[,.;:)]/.test(t) ? "" : " ") + esc(t);
      var k = p.key && keyed[p.key];
      if (!k) return;
      var offer = P.combos ? orderedLevels(k).filter(function (l) {
        var i = P.keys.indexOf(k);
        return P.combos.some(function (cb) { return k.levels[cb[i]] === l; });
      }) : orderedLevels(k).filter(function (l) { return !k.structural || allowedLevels(P, k.key, prof).indexOf(l) !== -1; });
      s += ' <select data-wi-prof="' + esc(k.key) + '" aria-label="' + esc(k.label) + '">';
      offer.forEach(function (l) {
        var shown = p.style === "lower" ? l.charAt(0).toLowerCase() + l.slice(1) : l;
        s += '<option value="' + esc(l) + '"' + (l === prof[k.key] ? " selected" : "") + ">" + esc(shown) + "</option>";
      });
      s += "</select>";
    });
    h += s + "</div>";
    var main = profileScore(P, prof, P.fits[0]);
    var draws = P.fits.slice(1).map(function (f) { return profileScore(P, prof, f).score; });
    var top = (M.outcome_levels || []).slice(-1)[0] || "top";
    h += '<p class="wi-headline">Expected ' + esc(M.score_label || "score") + " " + r0(main.score) + ": " +
      Math.round(100 * main.probs[main.probs.length - 1]) + "% chance of being " + esc(an(top)) + " " + esc(top) + ".</p>";
    var tq = (1 - rangeLevel()) / 2;
    h += lineHtml(M.actual, "All " + units, main.score, draws.length ? [pct(draws, tq), pct(draws, 1 - tq)] : null);
    if (st.profNote) h += '<p class="wi-note">' + esc(st.profNote) + "</p>";
    h += '<p class="wi-note">' + esc(matchNote(P, prof)) + "</p>";
    h += '<div class="wi-btnrow"><button class="wi-btn" data-wi-random>Show a random ' + esc(unit) + '</button>' +
      '<button class="wi-btn" data-wi-reset>Reset</button></div>';
    h += '<p class="wi-note">Who ' + an(unit) + " " + esc(unit) + " is explains little of any one " + esc(unit) +
      "'s answer, but groups do differ: across real " + esc(units) + "' profiles the expected " + esc(M.score_label || "score") +
      " runs from about " + r0(P.spread[0]) + " to " + r0(P.spread[2]) + ".</p>";
    return h + "</div>";
  }

  function matchNote(P, prof) {
    var M = meta(), units = M.units || "respondents";
    if (!wi.live()) return "An estimate from adding up each characteristic's effect. This file holds no individual answers.";
    var O = W().open, idx = [];
    for (var i = 0; i < O.n; i++) {
      if (O.y[i] === null || O.y[i] === undefined) continue;
      var ok = P.keys.every(function (k) {
        var code = O.ctx[k.key] ? O.ctx[k.key][i] : null;
        return code !== null && (O.ctx_levels[k.key] || [])[code] === prof[k.key];
      });
      if (ok) idx.push(i);
    }
    if (idx.length >= (M.min_group || 5)) {
      var sw = 0, sc = 0;
      idx.forEach(function (i) { sw += O.w[i]; sc += O.w[i] * M.scores[O.y[i] - 1]; });
      return idx.length + " real " + units + " have exactly this profile. Their actual " + (M.score_label || "score") + " is " +
        r0(sc / sw) + (idx.length < (M.reliability_floor || 30) ? ", from too few to lean on." : ".");
    }
    return (idx.length ? "Fewer than " + M.min_group : "No") + " real " + units +
      " have exactly this profile, so the estimate comes from adding up each characteristic's effect.";
  }

  // ---------------------------------------------------------------- Rate as one
  function rateHtml() {
    var M = meta(), md = model(), st = wi.state, sc = scaleOf(), unit = M.unit || "respondent";
    if (!st.rate) {
      st.rate = {};
      md.levers.forEach(function (lv) { st.rate[lv.key] = lv.kind === "coverage" ? 1 : goodOf(lv); st.rateHas[lv.key] = 1; });
    }
    var h = '<details class="wi-panel"><summary>Rate ' + esc(M.brand || "them") + " as one " + esc(unit) + "</summary>";
    h += '<p class="wi-lead">Set how one ' + esc(unit) + " rates each area. The model gives the chance they would be in each outcome group. " +
      "Who they are is set to the average " + esc(unit) + ". This is the model behind the effort table, seen from one " + esc(unit) + "'s side.</p>";
    h += '<div class="wi-grid">';
    var opts = [];
    for (var v = sc.max; v >= sc.min; v--) opts.push([v, labelOf(v)]);
    md.levers.forEach(function (lv) {
      if (lv.kind === "coverage") {
        h += "<label><span>" + esc(lv.label) + '</span><select data-wi-rate="' + esc(lv.key) + '"><option value="1"' +
          (st.rate[lv.key] ? " selected" : "") + '>Yes</option><option value="0"' + (st.rate[lv.key] ? "" : " selected") + ">No</option></select></label>";
        return;
      }
      if (lv.kind === "nested") {
        h += "<label><span>" + esc(lv.has_label || "Has " + lv.label.toLowerCase()) + '</span><select data-wi-ratehas="' + esc(lv.key) +
          '"><option value="1"' + (st.rateHas[lv.key] ? " selected" : "") + '>Yes</option><option value="0"' +
          (st.rateHas[lv.key] ? "" : " selected") + ">No</option></select></label>";
      }
      h += "<label><span>" + esc(lv.label) + '</span><select data-wi-rate="' + esc(lv.key) + '"' +
        (lv.kind === "nested" && !st.rateHas[lv.key] ? " disabled" : "") + ">";
      opts.forEach(function (o) { h += '<option value="' + o[0] + '"' + (Number(st.rate[lv.key]) === o[0] ? " selected" : "") + ">" + esc(o[1]) + "</option>"; });
      h += "</select></label>";
    });
    h += "</div>";
    var probs = function (f, fi) {
      var e = md.ctx_offset ? md.ctx_offset[fi] || 0 : 0, C = sc.centre;
      md.design.forEach(function (c, j) {
        if (c.context) return;
        var lv = md.levers.filter(function (x) { return x.key === c.lever; })[0], v = Number(st.rate[lv.key]);
        if (lv.kind === "rating") e += f.b[j] * (v - C);
        else if (lv.kind === "coverage") e += f.b[j] * v;
        else if (c.part === "has") e += f.b[j] * st.rateHas[lv.key];
        else e += f.b[j] * st.rateHas[lv.key] * (v - C);
      });
      return probsAt(f, e);
    };
    var p = probs(md.fits[0], 0), levels = M.outcome_levels || [];
    var tops = md.fits.slice(1).map(function (f, i) { var q = probs(f, i + 1); return q[q.length - 1]; });
    h += '<p class="wi-headline">' + Math.round(100 * p[p.length - 1]) + "% chance of being " + esc(an(levels[levels.length - 1] || "")) + " " +
      esc(levels[levels.length - 1] || "") + " (" + rangeName() + " " + Math.round(100 * pct(tops, (1 - rangeLevel()) / 2)) + "% to " +
      Math.round(100 * pct(tops, 1 - (1 - rangeLevel()) / 2)) + "%).</p>";
    h += '<table class="wi-table"><tbody><tr>' + levels.map(function (l, i) {
      return "<td>" + esc(l) + ' <b class="num">' + Math.round(100 * p[i]) + "%</b></td>";
    }).join("") + "</tr></tbody></table>";
    return h + "</details>";
  }

  // ---------------------------------------------------------------- diagnostics
  function diagHtml() {
    var M = meta(), md = model(), W0 = W(), units = M.units || "respondents", unit = M.unit || "respondent";
    var items = [];
    items.push("Model: ordinal logistic regression on " + (M.outcome_levels || []).join(" < ") +
      (M.weighted ? ", weighted" : "") + ", estimated once on all " + M.n + " " + units + " with " + (md.fits.length - 1) +
      " bootstrap refits for the ranges. Held-out fit: pseudo R squared " + Number(md.cv_r2).toFixed(3) + ".");
    var cal = md.calibration || {};
    if (cal.model && cal.ratings_only && md.baselines && md.baselines.keys && md.baselines.keys.length) {
      items.push("Who the " + unit + " is enters the model as a shrunk baseline, so each group's level is right. On " + units +
        " the model never saw, " + cal.model.outside + " of " + cal.model.groups + " groups of 30 or more missed their actual " +
        (M.score_label || "score") + " beyond sampling error (" + cal.ratings_only.outside + " with ratings alone).");
    }
    var unc = md.levers.filter(function (lv) { return unclear(lv.key); });
    items.push(unc.length ? "Sign check: " + unc.map(function (lv) { return lv.label + " points the wrong way in " +
      Math.round(100 * md.sign[lv.key]) + "% of refits"; }).join("; ") + ". Shown greyed; the data cannot separate its effect from the areas it overlaps."
      : "Sign check: every area points the expected way.");
    var hl = md.levers.filter(function (lv) { return halo(lv.key); });
    items.push("Every effect holds the other areas where they are, which is right for what is unique to an area and a floor for what fixing it would do, because ratings move together. " +
      (hl.length ? "Caught in the halo (fixed alone worth more than " + Math.round(1 / (md.halo_ratio || (1 / 3))) + " times its own effect): " +
        hl.map(function (lv) { var h = md.halo[lv.key]; return lv.label + (haloNum(h) ? " (" + f1(h.single) + " alone, " + f1(h.partial) + " held)" : "") + "; "; }).join("").replace(/; $/, ".") +
        " The data cannot separate those areas from the areas they move with; read their effect as a floor."
        : "Halo check: no area's effect collapses when the others are held where they are."));
    items.push("This is association, not cause. " + cap(units) + " who like " + (M.brand || "the organisation") +
      " rate everything higher, so real gains are probably smaller than shown.");
    (md.notes || []).forEach(function (t) { items.push(t); });
    var h = '<details class="wi-panel"><summary>How this works</summary><ul class="wi-list">' +
      items.map(function (t) { return "<li>" + esc(t) + "</li>"; }).join("") + "</ul>";
    if ((md.symptoms || []).length) {
      h += "<h4>Looks like a lever, is not one</h4><ul class=\"wi-list\">" + md.symptoms.map(function (s) {
        return "<li>" + esc(s.label) + ": " + f1(s.effect) + " points, " + esc(s.n) + " " + esc(units) + ". " + esc(s.why) + "</li>";
      }).join("") + "</ul>";
    }
    if (!wi.live() && W0.safe) {
      var a = W0.safe.audit || {}, ok = a.recoverable_failures === 0 && a.differencing_failures === 0 &&
        a.exact === true && a.need_checked === true && a.effects_checked === true &&
        W0.safe.groups.every(function (g) { return g.n >= W0.safe.min_group; });
      h += "<h4>Privacy</h4><p class=\"" + (ok ? "wi-ok" : "wi-warn") + "\">" + (ok
        ? "Prepared so that every published group has at least " + W0.safe.min_group + " " + units +
          " and no smaller group, single or crossed, can be worked out by adding or subtracting published ones. " +
          "A count or an effect that would rest on fewer than " + W0.safe.min_group + " is not shown, for the same reason. " +
          "Checked when this file was built; this browser confirms the " + W0.safe.groups.length +
          " groups it holds each have at least " + W0.safe.min_group + ". No individual answers are in the file."
        : "Privacy check failed. Do not send this file.") + "</p>";
    }
    return h + "</details>";
  }

  // ---------------------------------------------------------------- render and events
  wi.render = function (host) {
    if (!wi.available()) { host.innerHTML = '<div class="wi-view"><p>No What if study in this report.</p></div>'; return; }
    var M = meta(), G = currentGroup(), h = '<div class="wi-view">';
    h += headHtml(G);
    if (!G || !G.n || G.n < (M.min_group || 1)) {
      h += '<div class="wi-panel"><p class="wi-warn">' + (wi.live()
        ? "Fewer than " + esc(M.min_group) + " " + esc(M.units) + " of the model in this audience. Widen the filter."
        : "No published result for this group.") + "</p></div>";
    } else {
      h += effortHtml(G) + scenarioHtml(G);
    }
    h += buildHtml() + rateHtml() + diagHtml() + "</div>";
    host.innerHTML = h;
    bind(host);
  };

  function bind(host) {
    if (!host || typeof host.querySelectorAll !== "function") return;
    var rerender = function () { wi.render(host); };
    var on = function (sel, ev, fn) {
      Array.prototype.forEach.call(host.querySelectorAll(sel), function (el) { el.addEventListener(ev, function () { fn(el); }); });
    };
    on("[data-wi-scen]", "change", function (el) { wi.state.scen[el.getAttribute("data-wi-scen")] = el.value || null; rerender(); });
    on("[data-wi-addfilter]", "change", function (el) {
      if (!el.value) return;
      var parts = el.value.split("\u0001");
      wi.state.safeFilters.push({ key: parts[0], level: parts[1] });
      rerender();
    });
    on("[data-wi-unfilter]", "click", function (el) {
      wi.state.safeFilters.splice(Number(el.getAttribute("data-wi-unfilter")), 1);
      if (wi.state.safeFilters.length === 1 && safeIndex()[defKey(curSafeDef())] === undefined) wi.state.safeFilters = [];
      rerender();
    });
    on("[data-wi-prof]", "change", function (el) {
      var P = profileModel(), key = el.getAttribute("data-wi-prof");
      wi.state.prof[key] = el.value;
      wi.state.profNote = repairProfile(P, wi.state.prof, key);
      rerender();
    });
    on("[data-wi-random]", "click", function () {
      var P = profileModel(), prof = {};
      if (wi.live()) {
        var O = W().open, rows = [];
        for (var i = 0; i < O.n; i++) if (O.y[i] !== null && O.y[i] !== undefined) rows.push(i);
        var r = rows[Math.floor(Math.random() * rows.length)];
        P.keys.forEach(function (k) { prof[k.key] = (O.ctx_levels[k.key] || [])[O.ctx[k.key][r]]; });
      } else if (P.combos && P.combos.length) {
        var cb = P.combos[Math.floor(Math.random() * P.combos.length)];
        P.keys.forEach(function (k, i) { prof[k.key] = k.levels[cb[i]]; });
      }
      wi.state.prof = prof;
      wi.state.profNote = "";
      rerender();
    });
    on("[data-wi-reset]", "click", function () { wi.state.prof = null; wi.state.profNote = ""; rerender(); });
    on("[data-wi-rate]", "change", function (el) { wi.state.rate[el.getAttribute("data-wi-rate")] = Number(el.value); rerender(); });
    on("[data-wi-ratehas]", "change", function (el) { wi.state.rateHas[el.getAttribute("data-wi-ratehas")] = Number(el.value); rerender(); });
  }
})(typeof window !== "undefined" ? window : this);
