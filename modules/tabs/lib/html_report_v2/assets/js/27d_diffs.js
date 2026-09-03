/**
 * Differences view. Significant banner gaps for LAY readers.
 *
 * Findings are grouped by QUESTION into ranked cards; each line is one group
 * that genuinely stands out, told as a sentence with a two-bar comparison
 * (group vs THE REST, everyone except it) and a plain-English verdict.
 * Percentages surface when a group beats 2+ siblings (the published letters),
 * except on a two-level banner, where the single sibling IS all the siblings,
 * so beating it alone is a finding (DIFFERENCES_RANKING_DESIGN.md, decision E);
 * mean / index / NPS are recomputed from microdata and surface when a group
 * differs from the rest, in either direction, on a two-level banner the rest
 * of one level IS the other, so that pair is one finding told twice and the
 * mirror line is collapsed away. Honours the report's 95% / 95%+80%
 * significance toggle: in dual mode nearly-significant (80%) findings also
 * show, flagged soft and ranked below the solid 95% ones. The shared
 * confidence explainer renders at the foot.
 *
 * SIZE-EXCEPTION: one cohesive lay-reader view (rest recompute + categorical
 * and mean/index/NPS finders + render + scope controls); splitting it would
 * scatter a single deterministic finding contract.
 */
(function (global) {
  "use strict";
  var TR = global.TR, fmt = TR.fmt;

  var views = TR.views;
  var MAX_FINDINGS = 80;        // ranked cut-off, surfaced in the UI note
  var diffBanner = null;        // banner override (default: report banner)
  var diffSort = "standout";    // "standout" (top score) | "question"

  // CLASSIFICATION questions. Demographics, and corpographics / firmographics
  // (sales office, channel, region, etc.): describe WHO or WHAT the groups are.
  // They are the cuts, not the outcomes, so a "difference" on them is tautological
  // (a campus is full of its own city; a sales region is full of its own offices).
  // Excluded as difference TARGETS, detected from the category tag the config
  // already carries. A study whose labels don't match can extend the list via
  // project.insight_exclude_categories (case-insensitive category names).
  var CLASSIFICATION_RE = /demograph|corpograph|firmograph|classif/i;
  function isClassification(q) {
    var cat = String((q && q.category) || "");
    if (!cat) return false;
    if (CLASSIFICATION_RE.test(cat)) return true;
    var extra = (TR.AGG && TR.AGG.project && TR.AGG.project.insight_exclude_categories) || [];
    var lc = cat.toLowerCase();
    return extra.some(function (c) { return String(c).toLowerCase() === lc; });
  }
  views._isClassification = isClassification;   // exposed for the gate test

  /**
   * "The rest", everyone EXCEPT this group, for one question row, as a
   * percentage on the table's own base logic. Recomputed from microdata so it
   * is weighted-safe and reconciles exactly with the published group / overall
   * figures (group hits + rest hits = overall hits, over the matching bases).
   * Falls back to the exact unweighted count identity when a report carries no
   * microdata. Returns null when the row has no single base (score-difference
   * NETs) or the rest is empty.
   */
  function restPct(q, ri, groupMember, mask, groupCell, totalCell, groupBase, totalBase) {
    if (q.net_diffs && q.net_diffs[String(ri)] !== undefined) return null;
    if (groupMember && mask) {
      var n = TR.MICRO.n, rest = new Uint8Array(n);
      for (var r = 0; r < n; r++) rest[r] = groupMember[r] ? 0 : 1;
      var col = [{ member: rest }];
      if (q.rows[ri].kind === "net") {
        // A NET that decomposes into shown categories recomputes from those
        // members over the full answered base (netCounts): correct.
        var members = q.net_members && q.net_members[String(ri)];
        if (members && members.length) {
          var nc = TR.stats.netCounts(q, members, col, mask)[0];
          return nc && nc.wbase ? nc.n / nc.wbase * 100 : null;
        }
        // A box-scored NET (no shown members) takes its NUMERATOR from box
        // membership but its DENOMINATOR from the full answered base (tabulate),
        // NOT the box-only base. Otherwise respondents with no box, e.g. Neutral
        // on a shown satisfaction scale. Are dropped from the denominator and the
        // rest inflates (verified on SACS: the rest read 90% instead of the true
        // 61%, flipping a group from ahead to behind). Hidden-scale box-only
        // questions are unaffected (there every answered respondent has a box, so
        // the two bases are identical).
        var boxes = TR.MICRO.boxes && TR.MICRO.boxes[q.code];
        if (boxes) {
          var hits = TR.stats.boxCounts(q.code, ri, col, mask)[0];
          var full = TR.stats.tabulate(q, col, mask)[0];
          return full && full.wbase ? hits.n / full.wbase * 100 : null;
        }
        return null;
      }
      var tab = TR.stats.tabulate(q, col, mask)[0];
      return tab.wbase ? (tab.counts[ri] || 0) / tab.wbase * 100 : null;
    }
    // No microdata: exact only when unweighted (published n are respondent
    // counts). On a weighted report the published n is the WEIGHTED frequency
    // while the bases are unweighted. The identity breaks, so no rest value
    // (callers fall back to comparing against the overall figure).
    if (TR.AGG && TR.AGG.project && TR.AGG.project.weighted) return null;
    var rb = totalBase - groupBase;
    if (!rb || groupCell.n == null || totalCell.n == null) return null;
    return (totalCell.n - groupCell.n) / rb * 100;
  }

  /* A finding is built on the question's HEADLINE mean. A median, a mode, a
     spread or a ratio of totals is a different statistic, and the weighted
     means this file recomputes are the wrong input for testing any of them,
     so a "difference" on one would be a finding about a number nobody
     computed. This asked the LABEL until 2026-08, which caught only the SD. */

  /* ------------------------------------------------------------------------
     The BALANCED score (DIFFERENCES_RANKING_DESIGN.md). Every finding carries
     a second score, scoreBalanced = strength × effect × 100, both on 0..1:
     strength is bounded evidence (a capped |z| ratio for a mean, the share of
     siblings beaten for a proportion) and effect is size on the measure's own
     scale (|gap|/robust range for a mean, Cohen's h for a proportion). It
     drives the "balanced" sort only; the legacy `score` and the default sort
     are byte-identical to before. */

  /** Bound on the mean strength ratio |z|/zHi: beyond three times the
   *  critical value, more certainty says nothing more about size. */
  var MEAN_Z_CAP = 3;

  /** Cohen's h for two proportions. The same effect currency as the
   *  Executive Takeout (takeout.effectSize, 27e). Duplicated, not imported:
   *  this module and its test sandbox stay self-contained (SIZE-EXCEPTION). */
  var COHEN_H_REFERENCE = 0.8;   // Cohen's "large" effect -> full weight
  function cohenH(p1, p2) {
    var clamp = function (p) { return Math.min(1, Math.max(0, p)); };
    var phi = function (p) { return 2 * Math.asin(Math.sqrt(clamp(p))); };
    return phi(p1) - phi(p2);
  }

  /**
   * Robust scoring range for a question's per-respondent scores. On an
   * unbounded observed scale (rand, counts, more than 12 distinct values,
   * since the widest designed scale is 0–10 and NPS index scores are three
   * values) one big spender stretches the min–max and deflates every
   * finding's effect, so the bounds become the nearest-rank p5/p95 of the
   * non-null values. Computed over the same full unfiltered vector as the
   * min–max, unweighted, deterministic on rebuild. A designed scale (≤ 12
   * distinct values, where outliers are impossible) keeps the full range.
   * Anchored at 0 exactly as the display range is. Fallback chain: robust
   * range → full range (e.g. ≥95% zeros makes p5 = p95 = 0) → 1. Returns the
   * range WIDTH only. F.scaleMin/scaleMax are untouched: they drive the
   * comparison bars and the Takeout's effectSize, and must not move.
   */
  function robustRange(values, fullRange) {
    var seen = {}, distinct = 0, i;
    for (i = 0; i < values.length && distinct <= 12; i++) {
      if (!seen[values[i]]) { seen[values[i]] = true; distinct++; }
    }
    if (distinct <= 12) return fullRange || 1;
    var sorted = values.slice().sort(function (a, b) { return a - b; });
    var rank = function (p) {
      return sorted[Math.min(sorted.length - 1,
        Math.max(0, Math.ceil(p * sorted.length) - 1))];
    };
    var lo = rank(0.05), hi = rank(0.95);
    var range = Math.max(0, hi) - Math.min(0, lo);
    return range || fullRange || 1;
  }
  views._robustRange = robustRange;   // exposed for the differences gate test

  /**
   * Mean / Index / NPS findings for one question. The published tables carry NO
   * significance for these rows, so recompute the per-column weighted means from
   * microdata (the engine a filtered table uses) and test each group against THE
   * REST with a weighted Welch t-test. The natural test for a single-value
   * metric. It is bidirectional: a group significantly ABOVE or BELOW the rest
   * is a finding (a low-NPS segment is often the headline). The gap is in the
   * metric's own units (points, not pp); the score scales it by significance
   * strength and the response-scale range so these rank comparably with the
   * percentage findings. Returns [] for derived / ranking questions with no
   * recomputable score.
   */
  function meanFindings(q, spec, mask, threshold, dual) {
    var out = [], row = null;
    q.rows.forEach(function (r) {
      if (!row && r.kind === "mean" && TR.fmt.isHeadlineMean(r)) row = r;
    });
    if (!row) return out;
    // An ALLOCATION question carries one series per item row, not one score for
    // the question, so there is no single "headline mean" to scan: this would
    // report item 1 as though it were the question. indexMeans already returns
    // null for it (no scores, and no category rows to hang index_scores on), so
    // this is explicit rather than incidental, and stays right if indexMeans
    // ever learns to read series. Row-aware findings are a follow-up.
    if (TR.MICRO.series && TR.MICRO.series[q.code] &&
        !(TR.MICRO.scores && TR.MICRO.scores[q.code])) return out;
    var means = TR.stats.indexMeans(q, spec.columns, mask);
    if (!means) return out;                       // ranking / no-score question
    var scores = TR.MICRO.scores && TR.MICRO.scores[q.code];
    var lo = 0, hi = 0, any = false, vals = [];   // response-scale range
    if (scores) {
      scores.forEach(function (v) {
        if (v === null || v === undefined) return;
        vals.push(v);
        if (!any) { lo = hi = v; any = true; } else { lo = Math.min(lo, v); hi = Math.max(hi, v); }
      });
    } else if (q.index_scores) {
      // indexMeans fell back to q.index_scores, so the scale range must too,
      // a collapsed 0..0 range inflates the finding's score ~10x and breaks
      // the comparison bars (division by zero width).
      Object.keys(q.index_scores).forEach(function (label) {
        var v = q.index_scores[label];
        if (v === null || v === undefined) return;
        if (!any) { lo = hi = v; any = true; } else { lo = Math.min(lo, v); hi = Math.max(hi, v); }
      });
    }
    var scaleMin = Math.min(0, lo), scaleMax = Math.max(0, hi);
    var range = (scaleMax - scaleMin) || 1;
    // Balanced-score denominator only. The q.index_scores fallback path is a
    // designed scale by definition (declared label scores), so it keeps the
    // full range without the distinct-value scan.
    var scoreRange = scores ? robustRange(vals, range) : range;
    var decimals = /nps/i.test(row.label) ? 0 : 1;
    var n = TR.MICRO.n;
    // The disclosure k-gate blanks below-k columns in the crosstab; a recomputed
    // mean must not resurrect them here (means[i].k is the Kish effective base,
    // <= the raw count, so this gate is never looser than the crosstab's).
    var kMin = (TR.disclosure && TR.disclosure.active && TR.disclosure.active())
      ? TR.disclosure.minBase() : 1;
    var floor = Math.max(threshold, kMin);
    spec.columns.forEach(function (col, i) {
      if (i === 0 || means[i].mean === null || !means[i].k || means[i].k < floor) return;
      var rest = new Uint8Array(n);
      for (var r = 0; r < n; r++) rest[r] = col.member[r] ? 0 : 1;
      var rm = TR.stats.indexMeans(q, [{ member: rest }], mask)[0];
      if (!rm || rm.mean === null || !rm.k || rm.k < floor) return;
      var z = TR.stats.meanZ(means[i].mean, means[i].sd, means[i].k, rm.mean, rm.sd, rm.k);
      if (z === null) return;
      var az = Math.abs(z);
      var zHi = TR.stats.zPrimary(1), zLo = TR.stats.zSecondary(1);
      if (az <= zLo) return;                      // not different from the rest at all
      var soft = az <= zHi;                       // secondary but not primary, "nearly significant"
      if (soft && !dual) return;                  // soft findings only when dual-sig is on
      var gap = means[i].mean - rm.mean;
      out.push({ code: q.code, title: q.title, category: q.category,
        label: row.label, column: col.label, isMean: true, kind: "mean", soft: soft,
        direction: gap >= 0 ? "ahead" : "behind",
        value: means[i].mean, rest: rm.mean, overall: means[0].mean,
        gap: gap, decimals: decimals, scaleMin: scaleMin, scaleMax: scaleMax,
        beaten: [], base: means[i].k,   // column base. Carried for the Executive Takeout
        score: (az / TR.stats.Z95) * Math.abs(gap) / range * 100,
        // Balanced: capped evidence (the same configured critical value that
        // gated the finding, not the fixed Z95 the legacy score keeps) times
        // size on the robust range. A just-significant mean scores 1/3.
        scoreBalanced: Math.min(az / zHi, MEAN_Z_CAP) / MEAN_Z_CAP *
          Math.min(1, Math.abs(gap) / scoreRange) * 100 });
    });
    return out;
  }

  /** All findings for a banner: {code,title,category,label,column,value,isMean,
   *  rest,overall,gap,beaten[],score}. Pure given the models + microdata. */
  function collectFindings(banner) {
    var bannerSource = banner.replace("custom:", "").split(":")[0];
    var micro = TR.d2.hasMicrodata();
    // Banner-column memberships (respondent -> column) are question-independent;
    // build them once and reuse to recompute "the rest" for every finding.
    var spec = micro ? TR.stats.columnsFor(banner) : null;
    var mask = micro ? TR.stats.mask(TR.d2.state.filters) : null;
    var threshold = TR.AGG.project.low_base_threshold || 30;
    var dual = TR.stats.dualMode();   // also surface nearly-significant findings
    var findings = [];
    TR.AGG.questions.forEach(function (q) {
      if (q.code === bannerSource) return;   // a banner never "beats" itself
      if (isClassification(q)) return;       // demographics / corpographics: tautological cuts, not outcomes
      // Per-question opt-out (Selection sheet ExcludeFromInsights = Y): the
      // analyst has taken this question out of the FINDINGS while leaving it in
      // the crosstabs. Near-duplicate views of one measure, or a modelled
      // figure that should not lead the page. BY DESIGN this flag is honoured
      // here ONLY: the Patterns / Group-overview KeyShare scan
      // (27fa_takeout_shares.js) deliberately ignores it, because a question
      // can be a duplicate among Differences cards and still be the single
      // declared share that summarises its own question in the group portraits.
      // A study that wants BOTH tabs to skip a question uses the category-level
      // lever (project.insight_exclude_categories), which gates both.
      if (q.exclude_from_insights) return;
      var model = TR.model.forQuestion(q.code, banner, TR.d2.state.filters,
        { hiddenCols: [], dual: dual });
      var labelByLetter = {};
      model.columns.forEach(function (col) {
        if (col.letter) labelByLetter[col.letter] = col.label;
      });
      // Decision E (DIFFERENCES_RANKING_DESIGN.md): a proportion finding
      // normally needs the group ahead of 2+ siblings. One letter is a
      // pairwise result, not a standout. On a TWO-level banner the single
      // sibling IS all the siblings, so beating it is the strongest breadth
      // statement the banner allows, and it matches the mean path's single
      // planned test (the letters' Bonferroni divisor is 1 there). Structural
      // (Total + two columns), so the rule holds without microdata; banners
      // with 3+ levels are unchanged.
      var required = model.columns.length === 3 ? 1 : 2;
      // model.rows is 1:1 with q.rows in this view (no row scope / hide / sort),
      // so the loop index is the question row index used to recompute the rest.
      model.rows.forEach(function (row, ri) {
        if (row.kind === "mean") return;       // means handled below (recomputed)
        // Every proportion finding here is a percentage-POINT gap between
        // column shares. On a counts-only / row-%-only question the same slot
        // holds a headcount or a row percentage, so the row stays out rather
        // than reporting "a 62pp gap" that is really 62 people (2026-08, C1).
        // Mean/index standouts are unaffected. They recompute below.
        if (!TR.fmt.isColPctStat(row.stat)) return;
        // For rating scales the top-box NETs (+ the index) are the meaningful
        // standouts; individual scale points (Neutral, Very Satisfied…) read as
        // wrong sitting next to a top-box that already contains them, so suppress
        // raw category rows for scale / NPS questions. Other types (multi /
        // single choice) keep their categories. There the categories ARE the story.
        if (row.kind === "category" && (q.type === "scale" || q.type === "nps")) return;
        row.cells.forEach(function (cell, i) {
          if (i === 0) return;
          var sig = cell.sig || "";
          var solid = sig.replace(/[a-z]/g, "");              // beaten at 95%
          var soft80 = dual ? sig.replace(/[A-Z]/g, "") : ""; // beaten only at 80%
          var is95 = solid.length >= required;
          var is80 = !is95 && (solid.length + soft80.length) >= required;
          if (!is95 && !is80) return;
          var overall = row.cells[0].pct;
          if (cell.pct === null || overall === null) return;
          var rest = restPct(q, ri, spec ? spec.columns[i].member : null, mask,
            cell, row.cells[0], model.columns[i].base, model.columns[0].base);
          // An answer no one outside the group gives (rest 0%), or that
          // everyone but this group gives (rest 100%): is a defining trait of
          // the group, not a discovered difference (e.g. a plant that exists
          // only in its own region). Drop these tautological standouts.
          if (rest !== null && (Math.round(rest) === 0 || Math.round(rest) === 100)) return;
          var baseline = rest === null ? overall : rest;
          var letters = is95 ? solid : solid + soft80;
          findings.push({ code: q.code, title: q.title, category: q.category,
            label: row.label, column: model.columns[i].label, isMean: false,
            kind: row.kind,
            soft: is80, value: cell.pct, rest: rest, overall: overall,
            gap: cell.pct - baseline,
            beaten: letters.split("").map(function (l) {
              return labelByLetter[l.toUpperCase()] || l;
            }),
            base: model.columns[i].base,   // column base. Carried for the Executive Takeout
            score: letters.length * Math.abs(cell.pct - baseline),
            // Balanced: share of siblings beaten (structural denominator, as
            // the gate. Low-base siblings understate it, conservatively)
            // times Cohen's h against the same baseline the gap uses, in the
            // Takeout's effect currency (h / 0.8, Cohen's "large").
            scoreBalanced:
              Math.min(1, letters.length / Math.max(1, model.columns.length - 2)) *
              Math.min(1, Math.abs(cohenH(cell.pct / 100, baseline / 100)) /
                COHEN_H_REFERENCE) * 100 });
        });
      });
      // Mean / index / NPS standouts. Recomputed from microdata (the published
      // data has no significance for them), arguably the headline differences.
      if (spec) meanFindings(q, spec, mask, threshold, dual)
        .forEach(function (f) { findings.push(f); });
    });
    // solid (95%) findings rank above nearly-significant (80%) ones, then by score
    findings.sort(function (a, b) {
      return (a.soft ? 1 : 0) - (b.soft ? 1 : 0) || b.score - a.score;
    });
    return findings;
  }

  /**
   * Banner LEVELS. Columns excluding Total. 0 without microdata, where no mean
   * findings are recomputed and so nothing can be a reciprocal pair.
   */
  function bannerLevels(banner) {
    if (!TR.d2.hasMicrodata()) return 0;
    var cols = TR.d2.groupCols(banner);
    return cols ? cols.length : 0;
  }

  /**
   * Collapse reciprocal mean / index / NPS pairs on a TWO-LEVEL banner
   * (DIFFERENCES_TAB_SCOPE.md, item 1). Each mean finding is tested against THE
   * REST, and on a two-level cut the rest of one level IS the other level, so
   * Male-vs-rest and Female-vs-rest are one comparison told from both ends, and
   * every card printed exactly double. The kept line already carries both sides
   * (both values, both bars), so dropping the mirror removes nothing.
   *
   * Deliberately narrow. Proportion findings never mirror. A significance
   * letter is directional, so if Male beats Female, Female does not also beat
   * Male. On three-plus levels "A vs the rest" and "B vs the rest" are genuinely
   * different comparisons, not a pair. And where a banner leaves respondents
   * unbannered the rest is NOT the other level, so the two tests really do
   * differ: the direction and significance guards below then leave both lines
   * standing rather than silently discarding a finding.
   *
   * The higher side leads: the kept line names the group that is ahead. Runs
   * before the MAX_FINDINGS cut so the cap counts real findings and the "top N
   * of M" note is honest.
   */
  function collapseReciprocal(findings, levels) {
    if (levels !== 2) return findings;
    var byRow = {}, drop = [];
    findings.forEach(function (f) {
      if (!f.isMean) return;                       // proportions cannot mirror
      var key = f.code + "\u0000" + f.label;       // one headline mean row per question
      (byRow[key] || (byRow[key] = [])).push(f);
    });
    Object.keys(byRow).forEach(function (key) {
      var pair = byRow[key];
      if (pair.length !== 2) return;               // only one side stood out
      if (pair[0].soft !== pair[1].soft) return;   // the two tests disagree, not one finding
      if (pair[0].direction === pair[1].direction) return;  // both above their own rest
      drop.push(pair[0].direction === "ahead" ? pair[1] : pair[0]);
    });
    if (!drop.length) return findings;
    return findings.filter(function (f) { return drop.indexOf(f) === -1; });
  }

  /** The ranked findings a banner renders: collected, then reciprocal
   *  mean pairs collapsed. sortKey "balanced" re-ranks by scoreBalanced under
   *  the same tier rule (solid before soft): the findings SET is identical
   *  under every sort, so the "top N of M" note stays honest when the reader
   *  switches. Any other key keeps collectFindings' default order. */
  function rankedFindings(banner, sortKey) {
    var out = collapseReciprocal(collectFindings(banner), bannerLevels(banner));
    if (sortKey === "balanced") {
      out = out.slice().sort(function (a, b) {
        return (a.soft ? 1 : 0) - (b.soft ? 1 : 0) ||
          b.scoreBalanced - a.scoreBalanced;
      });
    }
    return out;
  }

  /** Group the ranked findings by question, preserving rank order. */
  function groupByQuestion(findings) {
    var byCode = {}, groups = [];
    findings.forEach(function (f) {
      if (!byCode[f.code]) {
        byCode[f.code] = { code: f.code, title: f.title,
          category: f.category, top: f.score, items: [] };
        groups.push(byCode[f.code]);
      }
      byCode[f.code].items.push(f);
    });
    return groups;
  }

  /** Value in its own units: "83%" for proportions, "9.3" / "78" for a
   *  mean / index / NPS (the metric is named in the sentence lead). */
  function fmtMetric(f, v) {
    return f.isMean ? v.toFixed(f.decimals) : Math.round(v) + "%";
  }

  /** Two-bar comparison: the group vs the rest (everyone except the group);
   *  falls back to "Everyone" when the rest is unavailable. Proportions fill a
   *  0–100 track; means/index/NPS scale to the metric's own range so a 9.3 mean
   *  is a near-full bar, not a 9% sliver. */
  function barsHtml(f) {
    var hasRest = f.rest !== null && f.rest !== undefined;
    var bar = function (value, cls, name) {
      var w = f.isMean
        ? (value - f.scaleMin) / (f.scaleMax - f.scaleMin) * 100
        : value;
      return '<div class="dfb-row"><span class="dfb-name">' + name + "</span>" +
        '<div class="dfb-track"><div class="dfb-bar ' + cls + '" style="width:' +
        Math.min(Math.max(w, 0), 100).toFixed(1) + '%"></div></div>' +
        '<span class="dfb-val">' + fmtMetric(f, value) + "</span></div>";
    };
    return '<div class="dfb">' +
      bar(f.value, "dfb-group", fmt.escapeHtml(TR.charts.clip(f.column, 24))) +
      bar(hasRest ? f.rest : f.overall, "dfb-total",
        hasRest ? "The rest" : "Everyone") + "</div>";
  }

  /** Small tag marking whether the standout row is a DEFINED CATEGORY (a NET
   *  grouping such as a top-box) or an individual DETAIL option, so a label like
   *  "Agree" reads unambiguously as one or the other. Mean / index / NPS rows name
   *  their metric in the sentence already, so they carry no tag. */
  function rowKindTag(f) {
    if (f.kind === "net") {
      return ' <span class="df-rowkind net" title="A defined category. A NET grouping of options (e.g. a top-box)">category</span>';
    }
    if (f.kind === "category") {
      return ' <span class="df-rowkind" title="An individual response option (a detail row)">detail</span>';
    }
    return "";
  }

  /** One finding as a plain-English line inside its question card. The headline
   *  compares the group with the REST (everyone except it) and carries the
   *  whole-sample figure in brackets. Proportions read "X% say "label""; a
   *  mean / index / NPS reads "<metric> <value>" with the gap in its own units. */
  function lineHtml(f) {
    var direction = f.gap >= 0 ? "+" : "−";
    var hasRest = f.rest !== null && f.rest !== undefined;
    var gapTxt = f.isMean
      ? Math.abs(f.gap).toFixed(f.decimals)
      : Math.abs(Math.round(f.gap)) + "pp";
    var lead = f.isMean
      ? fmt.escapeHtml(f.label) + " " + fmtMetric(f, f.value)
      : Math.round(f.value) + "% say “" + fmt.escapeHtml(f.label) + "”";
    var baseline = hasRest
      ? fmtMetric(f, f.rest) + " of the rest (" + fmtMetric(f, f.overall) +
        " overall)"
      : fmtMetric(f, f.overall) + (f.isMean ? " overall" : " of everyone");
    var tail = f.isMean
      ? (f.direction === "ahead" ? "ahead of" : "behind") + " the rest"
      : "ahead of " + fmt.escapeHtml(f.beaten.join(" · "));
    var verdict = f.soft
      ? tail + ", nearly significant (" + TR.stats.levelSecondary() + ")"
      : "statistically " + tail;
    return '<div class="df-line' + (f.soft ? " soft" : "") + '">' +
      '<div class="df-sentence"><strong>' + fmt.escapeHtml(f.column) +
      "</strong>: " + lead + rowKindTag(f) + " vs " + baseline + " · " +
      direction + gapTxt +
      "</div>" + barsHtml(f) +
      '<div class="df-beats">' + verdict + "</div></div>";
  }

  /** The sort control's options. "balanced" ranks by scoreBalanced
   *  (DIFFERENCES_RANKING_DESIGN.md): a page-local control like the other
   *  two, deliberately with no config plumbing (decision C: watch it on real
   *  studies before considering the default). */
  function sortOptionsHtml(current) {
    return [["standout", "Biggest differences first"],
            ["balanced", "Biggest differences first (balanced)"],
            ["question", "Question order"]]
      .map(function (o) {
        return '<option value="' + o[0] + '"' +
          (current === o[0] ? " selected" : "") + ">" + o[1] + "</option>";
      }).join("");
  }
  views._diffSortOptions = sortOptionsHtml;   // exposed for the gate test

  /**
   * The Differences significance selector. Its WORDS are the project's own
   * levels; its option VALUES ("95"/"dual") are persisted state and stay put.
   */
  function sigOptionsHtml(dual) {
    // A study with no secondary level has one choice, which is not a choice.
    if (!TR.stats.hasSecondary()) return "";
    return '<select data-diffsig title="Significance level">' +
      '<option value="95"' + (!dual ? " selected" : "") + ">" +
      TR.stats.levelPrimary() + "</option>" +
      '<option value="dual"' + (dual ? " selected" : "") + ">" +
      TR.stats.levelPrimary() + " + " + TR.stats.levelSecondary() + "</option>" +
      "</select>";
  }
  views._diffSigOptions = sigOptionsHtml;   // exposed for the gate test

  /** The tab's intro. The clause describing the significance control is its own
   *  authored entry, spliced in only when there IS a control to describe. */
  function introHtml() {
    var lv = TR.stats.levelVars();
    return TR.txt.block("diffs.intro", Object.assign({}, lv, {
      dual_clause: { html: TR.stats.hasSecondary() ? TR.txt("diffs.intro_dual", lv) : "" }
    }));
  }
  views._diffsIntroHtml = introHtml;   // exposed for the gate test

  /* exposed for the differences gate test */
  views._collectFindings = collectFindings;
  views._collapseReciprocal = collapseReciprocal;
  views._rankedFindings = rankedFindings;
  views._diffLineHtml = lineHtml;

  function cardHtml(group) {
    var search = (group.code + " " + group.title + " " +
      group.items.map(function (f) { return f.label + " " + f.column; })
        .join(" ")).toLowerCase();
    var pin = '<button class="snap-pin" data-snap-pin data-snap-source="differences" ' +
      'data-snap-title="' + fmt.escapeHtml(group.code + ": " + group.title) + '" ' +
      'data-snap-context="' + fmt.escapeHtml("Where groups differ · " + (group.category || "")) +
      '" title="Pin this card to the story" aria-label="Pin card to story">📌</button>';
    // The header leads with the question TEXT, not the variable name. The
    // code is engineering vocabulary in a lay deliverable (DIFFERENCES_TAB_
    // SCOPE.md, item 2). It stays reachable: hover (title attribute) and the
    // search index both carry it, and the pin keeps "code. Title" so a
    // pinned card stays traceable to its crosstab.
    return '<div class="card df-card" data-snap-card data-search="' +
      fmt.escapeHtml(search) + '">' +
      '<div class="df-qhead"><button class="linklike" data-goq="' +
      group.code + '" title="' + fmt.escapeHtml(group.code) + '">' +
      fmt.escapeHtml(group.title) + "</button>" +
      '<span class="kindtag">' + fmt.escapeHtml(group.category) +
      "</span>" + pin + "</div>" +
      group.items.map(lineHtml).join("") + "</div>";
  }
  views._diffCardHtml = cardHtml;   // exposed for the differences gate test

  views.findings = function (host) {
    var banner = diffBanner || TR.d2.state.banner;
    // The Differences view profiles one real banner's groups against the rest; a
    // custom or composite selection has no single source variable, so fall back.
    if (banner.indexOf("custom:") === 0 || banner.indexOf("composite:") === 0) {
      banner = TR.d2.firstBanner();
    }
    var dual = TR.stats.dualMode();
    var all = rankedFindings(banner, diffSort);
    // 95% findings get the full budget; nearly-significant (80%) ones get their
    // own, so turning on dual mode ADDS soft findings without ever crowding out
    // a solid one, even on dense banners that already have 80+ solid findings.
    var shown = all.filter(function (f) { return !f.soft; }).slice(0, MAX_FINDINGS)
      .concat(all.filter(function (f) { return f.soft; }).slice(0, MAX_FINDINGS));
    var groups = groupByQuestion(shown);
    if (diffSort === "question") {
      groups.sort(function (a, b) { return a.code < b.code ? -1 : 1; });
    }
    var groupName = TR.AGG.banner_groups.filter(function (g) {
      return g.id === banner;
    })[0];
    var html = ['<div class="page"><div class="card"><h2>Where groups differ · ' +
      fmt.escapeHtml(groupName ? groupName.name : banner) + "</h2>" +
      // Rewritten 2026-08-11 (Duncan). The old paragraph explained the whole
      // apparatus. Bracketed whole-sample figures, how percentages differ from
      // averages, the wave scope, why classification questions are excluded,
      // on a tab the reader reaches after the Dashboard and the Group overview.
      // What a reader needs here is what a card IS and what the control does.
      introHtml() +
      '<div class="scopebar">' + views._bannerPickerHtml(banner, "diffbanner") +
      '<select data-diffsort>' + sortOptionsHtml(diffSort) + "</select>" +
      sigOptionsHtml(dual) +
      '<input id="diff-search" type="search" placeholder="Search questions, ' +
      'answers or groups…">' +
      (all.length > shown.length
        ? '<span class="trknote">top ' + shown.length + " of " + all.length +
          " differences shown</span>" : "") + "</div></div>"];
    if (!groups.length) {
      html.push('<div class="card"><p>No group stands significantly apart ' +
        "on this banner.</p></div>");
    }
    groups.forEach(function (group) { html.push(cardHtml(group)); });
    html.push(TR.conf.calloutHtml());
    html.push("</div>");
    host.innerHTML = html.join("");

    views._wireLinks(host);
    var picker = host.querySelector('[data-act="diffbanner"]');
    if (picker) {
      picker.addEventListener("change", function () {
        diffBanner = picker.value;
        views.findings(host);
      });
    }
    host.querySelector("[data-diffsort]").addEventListener("change", function (e) {
      diffSort = e.target.value;
      views.findings(host);
    });
    var sigSel = host.querySelector("[data-diffsig]");
    if (sigSel) {
      sigSel.addEventListener("change", function () {
        TR.d2.state.sigMode = sigSel.value;   // shared report-wide setting
        views.findings(host);
      });
    }
    var search = host.querySelector("#diff-search");
    search.addEventListener("input", function () {
      var term = search.value.trim().toLowerCase();
      host.querySelectorAll(".df-card").forEach(function (card) {
        card.classList.toggle("hidden",
          !!term && card.getAttribute("data-search").indexOf(term) === -1);
      });
    });
    var callout = host.querySelector("[data-callout]");
    if (callout) {
      callout.addEventListener("click", function () {
        callout.closest(".callout").classList.toggle("collapsed");
      });
    }
  };

})(typeof window !== "undefined" ? window : globalThis);
