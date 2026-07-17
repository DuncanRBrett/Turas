/**
 * Pattern recognition — share questions (the KeyShare mechanism).
 *
 * Rated questions summarise as an index; a closed single/multi question
 * summarises as ONE share — but only the analyst knows which share is the
 * favourable one ("Always" on delivery-day is good; "Shop around" is not).
 * The Selection sheet's KeyShare column declares it (carried here as
 * q.key_share), and this module resolves that declaration into everything the
 * engine needs: the question row it names, a per-respondent 0/100 score vector
 * for the Welch/BH trust-gate, and a reliability stamp for share-only reports.
 *
 * Direction contract: a KeyShare is ALWAYS higher-is-better, by declaration.
 * Nothing here guesses valence — an undeclared question stays out of the scan,
 * which is the honest default (see PATTERNS_KEY_SHARE_GUIDE.md).
 *
 * Pure given (TR.AGG, TR.MICRO); consumed by 27f_takeout_data.js. Unit-tested
 * in tests/takeout_tests.mjs.
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};
  var shares = takeout._shares = {};

  /** Label normalisation for the KeyShare match: NBSP -> space (Alchemer option
   *  text carries U+00A0), trimmed, case-insensitive. Exact match after that — a fuzzy
   *  match could silently bind the wrong row, which is worse than no match. */
  function normLabel(s) {
    return String(s === null || s === undefined ? "" : s)
      .replace(/\u00a0/g, " ").trim().toLowerCase();
  }
  shares._normLabel = normLabel;

  /**
   * Resolve q.key_share to a row index on q.rows: NET rows first (an analyst
   * naming a grouping means the grouping, not a same-named option), then
   * category rows. Score-difference NETs (net_diffs) can never be a share.
   * Returns -1 when nothing matches — the question then stays out of the scan
   * rather than guessing.
   */
  function resolveRow(q) {
    var want = normLabel(q.key_share);
    if (!want) return -1;
    var rows = q.rows || [], i;
    for (i = 0; i < rows.length; i++) {
      if (rows[i].kind !== "net") continue;
      if (q.net_diffs && q.net_diffs[String(i)] !== undefined) continue;
      if (normLabel(rows[i].label) === want) return i;
    }
    for (i = 0; i < rows.length; i++) {
      if (rows[i].kind === "category" && normLabel(rows[i].label) === want) return i;
    }
    return -1;
  }
  shares._resolveRow = resolveRow;

  /**
   * The scannable share questions: KeyShare declared, resolvable to a row, not
   * already a rated touchpoint (its index would double-count), and not a
   * classification question (demographics describe the groups — they are cuts,
   * not outcomes). Returns [{q, ri}].
   */
  shares.list = function (views) {
    var rated = {};
    try {
      views.indexQuestions().forEach(function (q) { rated[q.code] = true; });
    } catch (e) { /* no rated questions — shares can still scan */ }
    var isClass = (TR.views && TR.views._isClassification) ||
      function () { return false; };
    var out = [];
    (((TR.AGG || {}).questions) || []).forEach(function (q) {
      if (!q.key_share || rated[q.code] || isClass(q)) return;
      var ri = resolveRow(q);
      if (ri >= 0) out.push({ q: q, ri: ri });
    });
    return out;
  };

  /**
   * Per-respondent 0/100 score vector for one share question, so the SAME
   * weighted Welch loop that tests rated questions tests shares (a Welch t on a
   * 0/100 encoding is the unpooled two-proportion z-test, in pp units — the
   * variance floor comes out at 10pp via the shared scaleSpan(q) = 100 path).
   * 100 = in the KeyShare row, 0 = answered but outside it, null = no answer.
   * Denominator mirrors the published convention (tabulate/boxCounts): answered
   * = a raw answer OR box membership; an answered-unshown code counts in the
   * base, never the numerator. Returns null when the microdata carries nothing
   * for this question.
   */
  shares.scoreVector = function (share, micro, nResp) {
    var q = share.q, ri = share.ri, row = (q.rows || [])[ri] || {};
    var answers = micro.answers && micro.answers[q.code];
    var boxes = micro.boxes && micro.boxes[q.code];
    var wanted = null;   // category-index set; null = box-scored NET (match boxes[r] === ri)
    if (row.kind === "net") {
      var members = q.net_members && q.net_members[String(ri)];
      if (members && members.length) {
        wanted = {};
        members.forEach(function (m) { wanted[m] = true; });
      } else if (!boxes) {
        return null;               // box-scored NET without box microdata
      }
    } else {
      wanted = {};
      wanted[ri] = true;
    }
    if (!answers && wanted !== null) return null;
    var out = new Array(nResp), hit, a, b, j;
    for (var r = 0; r < nResp; r++) {
      a = answers ? answers[r] : null;
      b = boxes ? boxes[r] : null;
      if ((a === null || a === undefined) && (b === null || b === undefined)) {
        out[r] = null;
        continue;
      }
      if (wanted === null) {
        hit = b === ri;
      } else if (Array.isArray(a)) {
        hit = false;
        for (j = 0; j < a.length; j++) {
          if (wanted[a[j]]) { hit = true; break; }
        }
      } else {
        hit = a !== null && a !== undefined && !!wanted[a];
      }
      out[r] = hit ? 100 : 0;
    }
    return out;
  };

  /**
   * Total-column base/effective-base of each share question's published model,
   * so a report with no rated questions still stamps an honest n and MoE on the
   * reliability ribbon. Same shape gatherReliability() reads from levels.
   */
  shares.reliabilityItems = function (views, list, modelOf) {
    return (list || []).map(function (s) {
      try {
        var model = modelOf(s.q.code);
        return { base: model.columns[0].base, baseEff: model.columns[0].baseEff || null };
      } catch (e) {
        return { base: 0 };
      }
    });
  };

})(typeof window !== "undefined" ? window : globalThis);
