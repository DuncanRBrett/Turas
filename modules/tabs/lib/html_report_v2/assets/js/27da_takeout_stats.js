/**
 * Pattern recognition. Statistical primitives (pure; no DOM, no LLM).
 *
 * The number-crunching the pattern engine (27e) stands on, factored out so the
 * engine file stays focused on pattern logic. Everything here is a deterministic
 * function of its arguments and unit-tested in tests/takeout_tests.mjs against
 * published known-answers (Benjamini-Hochberg 1995, Student-t / sign-test tables).
 * Loads before 27e (filename sorts 27da < 27e).
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var takeout = TR.takeout = TR.takeout || {};

  /** Standard normal CDF Φ(x): Zelen & Severo (A&S 26.2.17), |error| < 7.5e-8.
   *  Used to turn a Fisher-z statistic into a p-value for the FDR step. */
  function normalCdf(x) {
    var t = 1 / (1 + 0.2316419 * Math.abs(x));
    var d = 0.3989422804014327 * Math.exp(-x * x / 2);
    var p = d * t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 +
      t * (-1.821255978 + t * 1.330274429))));
    return x > 0 ? 1 - p : p;
  }
  takeout._normalCdf = normalCdf;

  /** Partial correlation of a,b controlling for one variable g, from the three
   *  zero-order correlations. Returns 0 when a controlled variance vanishes. */
  function partialCorr(rab, rag, rbg) {
    var d = Math.sqrt((1 - rag * rag) * (1 - rbg * rbg));
    return d > 1e-12 ? Math.max(-1, Math.min(1, (rab - rag * rbg) / d)) : 0;
  }
  takeout._partialCorr = partialCorr;

  /** Two-sided p-value for a (partial) correlation r on base n, controlling k
   *  covariates, via Fisher's z (se = 1/sqrt(n-k-3)). n too small -> p=1. */
  function corrPValue(r, n, k) {
    var df = n - (k || 0) - 3;
    if (df <= 0) return 1;
    var rc = Math.max(-0.999999, Math.min(0.999999, r));
    var z = Math.abs(0.5 * Math.log((1 + rc) / (1 - rc))) * Math.sqrt(df);  // atanh(rc)*sqrt(df)
    return 2 * normalCdf(-z);
  }
  takeout._corrPValue = corrPValue;

  /** Benjamini-Hochberg FDR. Given p-values, returns the indices that survive at
   *  level alpha: the largest rank k with p(k) <= (k/m)*alpha rejects all p ranked
   *  <= k. Valid under positive dependence (PRDS), which inter-question
   *  correlations on an attitude survey satisfy (all-positive), so BH (not the
   *  far more conservative Benjamini-Yekutieli) is the right correction here. */
  function bhFDR(pvals, alpha) {
    var m = pvals.length;
    if (!m) return [];
    var order = pvals.map(function (p, i) { return { p: p, i: i }; })
      .sort(function (a, b) { return a.p - b.p; });
    var kMax = -1;
    for (var k = 0; k < m; k++) {
      if (order[k].p <= ((k + 1) / m) * alpha) kMax = k;
    }
    var out = [];
    for (var j = 0; j <= kMax; j++) out.push(order[j].i);
    return out;
  }
  takeout._bhFDR = bhFDR;

  // The Student-t tail and its gamma / incomplete-beta machinery moved to
  // 21_stats.js (review 24 Sep 2026), so the crosstab, Tracking, composite and
  // Differences mean tests share it without depending on this file, which a
  // bundle with no Executive Takeout may leave out. Same functions, aliased.
  var logGamma = TR.stats._logGamma;
  var studentT = TR.stats.studentT;
  takeout._logGamma = logGamma;
  takeout._studentT = studentT;

  /** Weighted Welch two-sample mean test of a group arm vs the rest, with a
   *  scale-aware variance floor so a homogeneous census cell cannot collapse the
   *  SE to a spurious giant t. NO finite-population correction (it belongs in the
   *  reliability layer, not the test). Kish n_eff handles weights. */
  /**
   * The same test from SUFFICIENT STATISTICS rather than from the two arrays.
   *
   * welchTest() only ever used the moments of its inputs, so this is not an
   * approximation of it: the centred sum of squares is (sum wx squared) minus
   * (sum wx) squared over (sum w), which is the identity the array loop below
   * computes the long way. Splitting it out is what lets the Executive
   * Takeout's cell family run on a report that carries aggregates and no
   * respondents.
   *
   * @param g {n, sw, sw2, swx, swx2} for the group arm
   * @param r the same for the arm it is compared against
   * @param vfloor scale-aware variance floor
   */
  function welchFromMoments(g, r, vfloor) {
    var shape = function (m) {
      var mean = m.sw ? m.swx / m.sw : 0;
      var ss = m.sw ? m.swx2 - (m.swx * m.swx) / m.sw : 0;
      var neff = m.sw2 ? (m.sw * m.sw) / m.sw2 : 0;
      var variance = (neff > 1 && m.sw) ? (ss / m.sw) * (neff / (neff - 1)) : 0;
      return { mean: mean, variance: Math.max(variance, 0), neff: neff, n: m.n };
    };
    return welchFromShapes(shape(g), shape(r), vfloor);
  }
  takeout._welchFromMoments = welchFromMoments;

  function welchFromShapes(g, r, vfloor) {
    var vg = Math.max(g.variance, vfloor), vr = Math.max(r.variance, vfloor);
    var seg = vg / g.neff, ser = vr / r.neff, se = Math.sqrt(seg + ser);
    var diff = g.mean - r.mean, t = se > 0 ? diff / se : (diff === 0 ? 0 : Infinity);
    var df = (seg + ser) * (seg + ser) /
      ((seg * seg) / (g.neff - 1) + (ser * ser) / (r.neff - 1));
    return { diff: diff, t: t, df: df, p: studentT(t, df), nG: g.n, nR: r.n,
      flooredG: g.variance < vfloor };
  }

  function welchTest(gx, gw, rx, rw, vfloor) {
    function moments(x, w) {
      var sw = 0, sw2 = 0, sx = 0;
      for (var i = 0; i < x.length; i++) { var wi = w ? w[i] : 1; sw += wi; sw2 += wi * wi; sx += wi * x[i]; }
      var mean = sw ? sx / sw : 0, ss = 0;
      for (var j = 0; j < x.length; j++) { var wj = w ? w[j] : 1; var d = x[j] - mean; ss += wj * d * d; }
      var neff = sw2 ? (sw * sw) / sw2 : 0;
      var variance = (neff > 1 && sw) ? (ss / sw) * (neff / (neff - 1)) : 0;
      return { mean: mean, variance: variance, neff: neff, n: x.length };
    }
    return welchFromShapes(moments(gx, gw), moments(rx, rw), vfloor);
  }
  takeout._welchTest = welchTest;

  /** Two-sided exact sign test (binomial at p=0.5) over a group's per-question
   *  below/above counts. The multiplicity-safe test of DIRECTIONAL CONSISTENCY
   *  that gates the group/split patterns. (Treats questions as independent
   *  Bernoulli; positive inter-item r makes it mildly anti-conservative, which is
   *  safe here as it only ranks groups and SACS margins are far from the line.) */
  function signTest(below, above) {
    var n = below + above, k = Math.min(below, above);
    if (n === 0) return { p: 1, k: 0, n: 0, dir: "none" };
    var cum = 0, logHalfN = n * Math.log(0.5);
    for (var i = 0; i <= k; i++) {
      var logC = logGamma(n + 1) - logGamma(i + 1) - logGamma(n - i + 1);
      cum += Math.exp(logC + logHalfN);
    }
    return { p: Math.min(1, 2 * cum), k: k, n: n, dir: below > above ? "below" : "above" };
  }
  takeout._signTest = signTest;

  /**
   * Sarle's bimodality coefficient (SAS bias-corrected G1/G2) on an ordinal
   * category-count vector counts[0..K-1]. b ∈ (0,1]; the moment-form reference for
   * a uniform is 5/9 ≈ 0.5556. Returns the bias-corrected b plus the raw moments
   * and a moment-form b (g1²+1)/(g2+3) for the scan-size-invariant gate. n<4 ⇒ null.
   */
  function bimodalStat(counts, K) {
    var n = 0;
    for (var i = 0; i < K; i++) n += counts[i] || 0;
    if (n < 4) return null;
    var mean = 0;
    for (i = 0; i < K; i++) mean += (counts[i] || 0) * (i + 1) / n;
    var m2 = 0, m3 = 0, m4 = 0;
    for (i = 0; i < K; i++) {
      var d = (i + 1) - mean, c = (counts[i] || 0) / n;
      m2 += c * d * d; m3 += c * d * d * d; m4 += c * d * d * d * d;
    }
    var sd = Math.sqrt(m2);
    if (sd < 1e-9) return { b: 0, bMoment: 0, mean: mean, n: n };   // zero variance -> not bimodal
    var g1 = m3 / (sd * sd * sd), g2 = m4 / (m2 * m2) - 3;
    var bMoment = (g1 * g1 + 1) / (g2 + 3);                          // uniform reference 5/9
    var G1 = g1 * Math.sqrt(n * (n - 1)) / (n - 2);
    var G2 = ((n - 1) / ((n - 2) * (n - 3))) * ((n + 1) * g2 + 6);
    var b = (G1 * G1 + 1) / (G2 + 3 * (n - 1) * (n - 1) / ((n - 2) * (n - 3)));
    return { b: b, bMoment: bMoment, mean: mean, n: n };
  }
  takeout._bimodalStat = bimodalStat;

  /** Full ahead / level / behind counts for one column's gaps, split by kind.
   *
   *  RAW comparison. A gap counts whichever side of the overall it falls, with
   *  no materiality floor. The portrait's hits/gains counts apply that floor and
   *  so understate the misses on a group that is behind everywhere by a little;
   *  this is the honest denominator to show beside them.
   *
   *  Rated indexes and KeyShare rows are counted SEPARATELY: pooling them hides
   *  the case where a group is ordinary on how it is rated and well ahead on what
   *  actually gets done (or the reverse).
   */
  function tallyGaps(gaps) {
    var blank = function () { return { ahead: 0, level: 0, behind: 0, n: 0 }; };
    var out = { rated: blank(), share: blank() };
    (gaps || []).forEach(function (gp) {
      if (gp.value === null || gp.value === undefined ||
          gp.total === null || gp.total === undefined) return;
      var side = gp.isPct ? out.share : out.rated;
      side.n++;
      if (gp.value > gp.total) side.ahead++;
      else if (gp.value < gp.total) side.behind++;
      else side.level++;
    });
    return out;
  }
  takeout._tallyGaps = tallyGaps;

  /** The declared headline questions for one column, in the analyst's order.
   *  Reads the same gaps the card is built from, so every anchor number is a
   *  real cell that appears in the crosstabs. Codes with no gap (below the base
   *  floor for this column, say) are dropped rather than shown empty. */
  function anchorFrom(gaps, codes) {
    if (!codes || !codes.length) return [];
    var byCode = {};
    (gaps || []).forEach(function (gp) {
      if (gp.code && byCode[gp.code] === undefined) byCode[gp.code] = gp;
    });
    return codes.map(function (c) { return byCode[c]; })
      .filter(function (gp) { return !!gp; });
  }
  takeout._anchorFrom = anchorFrom;

})(typeof window !== "undefined" ? window : globalThis);
