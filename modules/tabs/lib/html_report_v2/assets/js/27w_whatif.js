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
 * (who the respondent is), Rate as one (one respondent's chance of each
 * outcome, never the group score), diagnostics. Every panel below the headline
 * folds; wi.state.open keeps the folds through re-renders.
 *
 * Association, not cause: nothing here says fixing an area WILL add points.
 * A respondent flagged dk in the open rows gave no rating for that lever: the
 * live view leaves them out of the need count and the moves, as R does. The
 * model block's halo check marks an area whose effect collapses when the other
 * areas are held (a chip on the area and one note under the effort table,
 * never greyed to zero).
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
  /** "a Detractor, a Passive or a Promoter". */
  function orList(levels) {
    var w = levels.map(function (l) { return an(l) + " " + l; });
    return w.length < 2 ? w.join("") : w.slice(0, -1).join(", ") + " or " + w[w.length - 1];
  }

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
  /** One note under the effort table for every area marked with the halo
   *  chip, so the rows stay one line each. */
  function haloNote(levers) {
    if (!levers.length) return "";
    var items = levers.map(function (lv) {
      var h = halo(lv.key);
      return lv.label + ": " + (haloNum(h) ? f1(h.single) + " on its own, " + f1(h.partial) + " held"
        : "the numbers rest on too few to show");
    });
    return "fixed on its own for everyone, " + (levers.length > 1 ? "each of these areas is" : "this area is") +
      " worth far more than with the other areas held where they are. " + items.join("; ") +
      ". The data cannot separate " + (levers.length > 1 ? "them" : "it") + " from the areas " +
      (levers.length > 1 ? "they move" : "it moves") + " with, so read the number in the table as a floor.";
  }
  /** Whether respondent i gave no rating of their own for the lever. */
  function dkOf(O, key, i) {
    var d = O.dk && O.dk[key];
    return !!(d && d[i]);
  }

  // ---------------------------------------------------------------- mode
  wi.state = { safeFilters: [], scen: {}, prof: null, profNote: "", rate: null, rateHas: {}, open: {} };

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
   *  null for respondents outside the model. Also caches each respondent's
   *  baseline expected score per fit (etaCache.s), which every move needs. */
  function etas() {
    if (etaCache && etaCache.src === TR.WI) return etaCache.e;
    var M = model(), O = W().open, n = O.n, C = scaleOf().centre, out = [], base = [], scores = meta().scores;
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
      var bs = new Float64Array(n);
      for (var k = 0; k < n; k++) bs[k] = e[k] === null ? NaN : scoreAt(fit, e[k], scores);
      out.push(e);
      base.push(bs);
    });
    etaCache = { src: TR.WI, e: out, s: base };
    return out;
  }
  function baseScores() { etas(); return etaCache.s; }

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

  /** Change in the group's expected score under a set of moves, per fit.
   *  A move's change to a respondent's lever column does not depend on the
   *  fit, so it is worked out once; each fit then visits only the respondents
   *  a move touches, against their cached baseline score. The arithmetic and
   *  its order are the same as scoring every respondent in every fit. */
  function openChange(idx, moves) {
    var M = model(), O = W().open, E = etas(), B = baseScores(), scores = meta().scores, out = [];
    var moved = M.levers.filter(function (lv) { return moves[lv.key]; }), nm = moved.length;
    var who = [], dl = [], sw = 0;
    for (var q = 0; q < idx.length; q++) {
      var i = idx[q], any = false, row = new Array(nm);
      for (var l = 0; l < nm; l++) {
        var lv = moved[l];
        row[l] = delta(lv, moves[lv.key], O.val[lv.key][i], dkOf(O, lv.key, i));
        if (row[l] !== 0) any = true;
      }
      if (any) { who.push(i); for (l = 0; l < nm; l++) dl.push(row[l]); }
      sw += O.w[i];
    }
    for (var f = 0; f < M.fits.length; f++) {
      var fit = M.fits[f], e = E[f], bs = B[f], d = 0;
      var b = moved.map(function (lv) { return fit.b[lv.col]; });
      for (var k = 0; k < who.length; k++) {
        var r = who[k], base = e[r], e2 = base;
        for (l = 0; l < nm; l++) e2 += b[l] * dl[k * nm + l];
        if (e2 !== base) d += O.w[r] * (scoreAt(fit, e2, scores) - bs[r]);
      }
      out.push(sw ? d / sw : NaN);
    }
    return out;
  }
  /** A stable key for a set of moves: chosen levers only, in sorted order. */
  function movesKey(moves) {
    return JSON.stringify(Object.keys(moves).filter(function (k) { return moves[k]; }).sort()
      .map(function (k) { return [k, moves[k]]; }));
  }

  /** A live group: actual score, who needs each fix, and the draws. */
  function openGroup(mask) {
    var M = model(), O = W().open, scores = meta().scores, idx = openIdx(mask);
    if (!idx.length) return { n: 0 };
    var sw = 0, sc = 0;
    idx.forEach(function (i) { sw += O.w[i]; sc += O.w[i] * scores[O.y[i] - 1]; });
    // Results for this audience, kept by their moves: a scenario pick or a
    // re-render works out only what it has not seen for this group.
    var memo = {};
    var run = function (moves) {
      var k = movesKey(moves);
      if (!Object.prototype.hasOwnProperty.call(memo, k)) memo[k] = summ(openChange(idx, moves));
      return memo[k];
    };
    var one = function (lv, m) { var mv = {}; mv[lv.key] = m; return run(mv); };
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
      slip: M.levers.map(function (lv) { return one(lv, slipMove(lv)); }),
      fix: M.levers.map(function (lv) { return one(lv, fixMove(lv)); }),
      scenario: function (moves) { return run(moves); },
      bundle: function (b) { return run(b.moves); },
      single: function (lv, m) { return one(lv, m); }
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
  var AUDIENCES_KEPT = 6;
  function currentGroup() {
    if (wi.live()) {
      var filters = (TR.d2 && TR.d2.state && TR.d2.state.filters) || [];
      var mask = filters.length ? TR.stats.mask(filters) : null;
      var who = filters.length && TR.d2.filterDescription ? TR.d2.filterDescription() : "all " + (meta().units || "respondents");
      // The last few audiences are kept, so filtering back to one already seen
      // (everyone, most often) costs nothing.
      var key = JSON.stringify(filters);
      if (!wi._cache || wi._cache.src !== TR.WI) wi._cache = { src: TR.WI, keys: [], groups: {} };
      var C = wi._cache;
      if (!Object.prototype.hasOwnProperty.call(C.groups, key)) {
        C.groups[key] = openGroup(mask);
        C.keys.push(key);
        if (C.keys.length > AUDIENCES_KEPT) delete C.groups[C.keys.shift()];
      }
      var g = C.groups[key];
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

  // ---------------------------------------------------------------- panels that fold
  // Every panel below the headline folds. Which are open lives in wi.state, so
  // a re-render (any dropdown) leaves each panel as the reader left it, and a
  // fold itself only flips the panel's body, with no re-render.
  var PANEL_OPEN = { effort: true, scenario: true, build: true, rate: false, how: false };
  function isOpen(id) {
    var o = wi.state.open[id];
    return o === undefined ? PANEL_OPEN[id] !== false : o === true;
  }
  /** The panel's heading row: fold button, title, a one-line hint, the pin. */
  function panelHead(id, title, hint, pin) {
    return '<div class="wi-cardhead"><div class="wi-titlerow">' +
      '<button type="button" class="wi-toggle snap-skip" data-wi-toggle="' + id + '" aria-expanded="' + isOpen(id) +
      '" aria-label="Show or hide ' + esc(title) + '"></button>' +
      '<h3 data-wi-toggle-title="' + id + '">' + esc(title) + "</h3>" +
      (hint ? '<span class="wi-sumhint">' + esc(hint) + "</span>" : "") + "</div>" + (pin || "") + "</div>";
  }
  /** Opens the panel's body; the caller closes it with "</div>". A pin always
   *  shows the body, folded or not (.snap-show, see shell.snapshotCard). */
  function panelBody(id) {
    return '<div class="wi-body snap-show" data-wi-body="' + id + '"' + (isOpen(id) ? "" : " hidden") + ">";
  }
  function panelClass(id) { return "wi-panel" + (isOpen(id) ? "" : " wi-folded"); }

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
      h += '<div class="wi-kpis"><div class="wi-kpi"><span class="wi-kpi-label">Actual ' + esc(label) + '</span><b class="wi-kpi-value">' +
        r0(G.actual) + "</b></div>" +
        '<div class="wi-kpi"><span class="wi-kpi-label">' + esc(cap(M.units || "respondents")) + ' in the model</span><b class="wi-kpi-value">' +
        esc(G.n) + "</b></div></div>";
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
    var h = '<div class="' + panelClass("effort") + '" data-snap-card>' +
      panelHead("effort", "Where to direct effort", "", pinButton("Where to direct effort", G.who)) + panelBody("effort");
    h += '<p class="wi-lead">What ' + esc(M.score_label || "the score") + " would lose if an area slipped, and gain if it were fixed for the " +
      esc(units) + " who need it, for " + esc(G.who) + ".</p>";
    h += '<div class="wi-tablewrap"><table class="wi-table wi-effort"><thead><tr><th class="wi-areacol">Area</th><th class="num">' + esc(cap(units)) +
      " who need it</th>" + '<th class="num">If it slips</th><th class="num">If fixed</th><th class="wi-gaincol" title="Net gain per 100 ' +
      esc(units) + ' reached">Net gain per 100 reached</th></tr></thead><tbody>';
    var haloed = [], DASH = "–";
    rows.forEach(function (r) {
      var lv = r.lv, hl = !r.unclear && !!halo(lv.key);
      if (hl) haloed.push(lv);
      // One short line under the area: why it is unclear, or the config's note.
      var sub = r.unclear ? "Points the wrong way in " + Math.round(100 * md.sign[lv.key]) + "% of refits" : lv.sub;
      var needTxt = r.cnt === null || r.cnt === undefined ? "not shown" : String(r.cnt);
      h += "<tr" + (r.unclear ? ' class="wi-unclear"' : hl ? ' class="wi-halo"' : "") + '><td class="wi-areacol">' +
        '<span class="wi-area">' + esc(lv.label) + "</span>" +
        '<span class="wi-tag">' + (lv.kind === "coverage" ? "coverage" : "rating") + "</span>" +
        (r.unclear ? '<span class="wi-tag wi-tag-unclear">unclear</span>' : "") +
        (hl ? '<span class="wi-tag wi-tag-halo">caught in the halo</span>' : "") +
        (sub ? "<small>" + esc(sub) + "</small>" : "") + "</td>";
      h += '<td class="num">' + esc(needTxt) + "</td>";
      [r.slip, r.fix].forEach(function (s) {
        h += '<td class="num">' + (r.unclear ? DASH : withheld(s) ? "not shown" :
          f1(s.pt) + '<span class="wi-rng">' + f1(s.lo) + " to " + f1(s.hi) + "</span>") + "</td>";
      });
      var bar = "";
      if (!r.unclear && r.per100 !== null) {
        bar = '<span class="wi-bar"><i style="width:' + Math.max(0, 100 * r.per100 / mx).toFixed(1) + '%"></i></span>';
      }
      h += '<td class="wi-gaincol"><span class="wi-gain"><b>' + (r.unclear ? DASH : r.per100 === null ? "n/a" : f0(r.per100)) +
        "</b>" + bar + "</span></td></tr>";
    });
    h += "</tbody></table></div>";
    if (haloed.length) h += '<p class="wi-note wi-halonote"><b>Caught in the halo:</b> ' + esc(haloNote(haloed)) + "</p>";
    if (rows.some(function (r) { return r.unclear; })) {
      h += '<p class="wi-note"><b>Unclear:</b> the effect points the wrong way in more than ' +
        Math.round(100 * (md.unclear_share || 0.1)) + "% of the refits, so no number is shown. " +
        "The data cannot separate it from the areas it overlaps.</p>";
    }
    var sc = scaleOf(), good = labelOf(sc.good);
    h += '<p class="wi-note">Ratings: slipping is one ' + esc(sc.step || "point") + " lower for everyone; fixing lifts every " +
      esc(unit) + " below " + esc(good) + " up to " + esc(good) + ". Coverage: slipping withdraws it from every " + esc(unit) +
      " who has it; fixing extends it to everyone without it. Points of " + esc(M.score_label || "score") +
      ", with the " + rangeName() + " across the refits underneath. " +
      (G.exact ? "" : "A count or an effect is not shown when it would rest on fewer than " + esc(M.min_group) + " " + esc(units) +
        ", on its own or set against another published group.") + "</p>";
    return h + "</div></div>";
  }

  /** The scenario's levers, grouped under the config's bundles when each lever
   *  sits in one bundle at most (SACAP: Teaching, Service, then the rest).
   *  Otherwise one ungrouped list, in the config's order. */
  function scenarioGroups(md) {
    var bundles = md.bundles || [], seen = {}, overlap = false;
    bundles.forEach(function (b) {
      Object.keys(b.moves || {}).forEach(function (k) { if (seen[k]) overlap = true; seen[k] = true; });
    });
    if (!bundles.length || overlap) return [{ name: "", levers: md.levers }];
    var groups = bundles.map(function (b) {
      return { name: b.name, levers: md.levers.filter(function (lv) { return b.moves[lv.key]; }) };
    }).filter(function (g) { return g.levers.length; });
    if (!groups.length) return [{ name: "", levers: md.levers }];
    var rest = md.levers.filter(function (lv) { return !seen[lv.key]; });
    if (rest.length) groups.push({ name: "Other areas", levers: rest });
    return groups;
  }
  wi._scenarioGroups = scenarioGroups;

  function scenarioHtml(G) {
    var M = meta(), md = model(), st = wi.state, label = M.score_label || "score";
    var h = '<div class="' + panelClass("scenario") + '" data-snap-card>' +
      panelHead("scenario", "Build a scenario", "", pinButton("What if scenario", G.who)) + panelBody("scenario");
    h += '<p class="wi-lead">' + (G.exact
      ? "Combine moves across areas. Worked out exactly, " + esc(M.unit) + " by " + esc(M.unit) + ", for the current group."
      : "Combine moves across areas. Each area's own result is added up, so combined results are approximate; the bundles below show how close that gets.") + "</p>";
    h += '<div class="wi-moves">';
    scenarioGroups(md).forEach(function (g) {
      h += '<div class="wi-movegrp">' + (g.name ? '<div class="wi-grp">' + esc(g.name) + "</div>" : "");
      g.levers.forEach(function (lv) {
        h += '<label class="wi-moverow' + (st.scen[lv.key] ? " wi-on" : "") + '"><span>' + esc(lv.label) +
          "</span><select data-wi-scen=\"" + esc(lv.key) + '" aria-label="' + esc(lv.label) + ' scenario"><option value="">No change</option>';
        movesFor(lv).forEach(function (m) {
          h += '<option value="' + m + '"' + (st.scen[lv.key] === m ? " selected" : "") + ">" + esc(moveLabel(lv, m)) + "</option>";
        });
        h += "</select></label>";
      });
      h += "</div>";
    });
    h += '</div><div class="wi-result">';
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
    h += "</div>";
    if ((md.bundles || []).length) {
      h += '<div class="wi-tablewrap"><table class="wi-table wi-bundles"><thead><tr><th>Bundle</th><th class="num">Worked out together</th>' +
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
      h += "</tbody></table></div>";
    }
    return h + "</div></div>";
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
    var h = '<div class="' + panelClass("build") + '" data-snap-card>' +
      panelHead("build", "Build " + an(unit) + " " + unit, "", pinButton("Build " + an(unit) + " " + unit, "")) + panelBody("build");
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
    h += '<p class="wi-headline">Expected ' + esc(M.score_label || "score") + " for " + esc(units) + " like this: " + r0(main.score) +
      ". Each has a " + Math.round(100 * main.probs[main.probs.length - 1]) + "% chance of ending up " + esc(an(top)) + " " + esc(top) + ".</p>";
    var tq = (1 - rangeLevel()) / 2;
    h += lineHtml(M.actual, "All " + units, main.score, draws.length ? [pct(draws, tq), pct(draws, 1 - tq)] : null);
    // The notes sit together under the line, then the buttons.
    h += '<div class="wi-notes">';
    if (st.profNote) h += '<p class="wi-note">' + esc(st.profNote) + "</p>";
    h += '<p class="wi-note">' + esc(matchNote(P, prof)) + "</p>";
    h += '<p class="wi-note">Who ' + an(unit) + " " + esc(unit) + " is explains little of any one " + esc(unit) +
      "'s answer, but groups do differ: across real " + esc(units) + "' profiles the expected " + esc(M.score_label || "score") +
      " runs from about " + r0(P.spread[0]) + " to " + r0(P.spread[2]) + ".</p></div>";
    h += '<div class="wi-btnrow"><button class="wi-btn" data-wi-random>Show a random ' + esc(unit) + '</button>' +
      '<button class="wi-btn" data-wi-reset>Reset</button></div>';
    return h + "</div></div>";
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
    var M = meta(), md = model(), st = wi.state, sc = scaleOf(), unit = M.unit || "respondent", label = M.score_label;
    var levels = M.outcome_levels || [], top = levels[levels.length - 1] || "";
    if (!st.rate) {
      st.rate = {};
      md.levers.forEach(function (lv) { st.rate[lv.key] = lv.kind === "coverage" ? 1 : goodOf(lv); st.rateHas[lv.key] = 1; });
    }
    var h = '<div class="' + panelClass("rate") + '">' +
      panelHead("rate", "Rate " + (M.brand || "them") + " as one " + unit,
        "One " + unit + "'s chance of each outcome, not " + (label || "a score")) + panelBody("rate");
    // One person's chance of each outcome, which is not the group score: say so,
    // because the effort table and the scenario above are in score points.
    h += '<p class="wi-lead">Set how one ' + esc(unit) + " rates each area. The model gives the chance that this " + esc(unit) +
      " ends up " + esc(orList(levels)) + ". " +
      (label ? "It is a chance for one " + esc(unit) + ", not " + esc(label) + ": " + esc(label) +
        " is a score for a group, as in the panels above. " : "") +
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
    var p = probs(md.fits[0], 0);
    var tops = md.fits.slice(1).map(function (f, i) { var q = probs(f, i + 1); return q[q.length - 1]; });
    h += '<p class="wi-headline">This ' + esc(unit) + " has a " + Math.round(100 * p[p.length - 1]) + "% chance of ending up " +
      esc(an(top)) + " " + esc(top) + " (" + rangeName() + " " + Math.round(100 * pct(tops, (1 - rangeLevel()) / 2)) + "% to " +
      Math.round(100 * pct(tops, 1 - (1 - rangeLevel()) / 2)) + "%).</p>";
    h += '<table class="wi-table wi-chances"><tbody><tr><th>Chance of ending up</th>' + levels.map(function (l, i) {
      return "<td>" + esc(l) + ' <b class="num">' + Math.round(100 * p[i]) + "%</b></td>";
    }).join("") + "</tr></tbody></table>";
    return h + "</div></div>";
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
    var h = '<div class="' + panelClass("how") + '">' +
      panelHead("how", "How this works", "The model, its checks and its limits") + panelBody("how") + '<ul class="wi-list">' +
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
    return h + "</div></div>";
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
    // Fold a panel in place: flip its body and remember it, no re-render.
    var fold = function (id) {
      var open = !isOpen(id), body = host.querySelector('[data-wi-body="' + id + '"]');
      var btn = host.querySelector('[data-wi-toggle="' + id + '"]');
      wi.state.open[id] = open;
      if (body) body.hidden = !open;
      if (btn) {
        btn.setAttribute("aria-expanded", String(open));
        var panel = btn.closest(".wi-panel");
        if (panel) panel.classList.toggle("wi-folded", !open);
      }
    };
    on("[data-wi-toggle]", "click", function (el) { fold(el.getAttribute("data-wi-toggle")); });
    on("[data-wi-toggle-title]", "click", function (el) { fold(el.getAttribute("data-wi-toggle-title")); });
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
