/**
 * v2 confidence layer — sampling-method-aware terminology plus Wilson
 * score intervals, ported from the production confidence module so every
 * number in the report can state its reliability honestly.
 *
 * Terminology mirrors modules/confidence/R/sampling_labels.R verbatim:
 * probability designs (Random/Stratified/Cluster/Census) speak standard
 * statistics ("Confidence Interval", "CI", "Margin of Error", "MOE");
 * non-probability designs (Quota/Online_Panel/Self_Selected (Convenience)/
 * Not_Specified) get honest softened language ("Stability Interval", "SI", "Precision
 * Estimate", "PE"). The report's design is project.sampling_method.
 *
 * Intervals: calculate_proportion_ci_wilson() from 04_proportions.R,
 * ported verbatim and known-answer tested against R output. Mean-kind
 * intervals use z·SD/√n on distribution-derived SDs (TR.waves.scoreMap +
 * sdFromPairs — the same single SD source the significance tests use);
 * the R module's t-based mean CI differs by under 1.5% at the bases in
 * this report (n ≥ 70), documented in the README.
 *
 * Everything here is pure given TR.AGG; no DOM access. The callout
 * builder returns an HTML string for the shared footer-explainer pattern.
 */
(function (global) {
  "use strict";
  var TR = global.TR;

  var conf = TR.conf = {};

  // 95% two-sided critical value matching R's qnorm(0.975), so interval
  // known answers agree with the confidence module to 1e-9. DISPLAY
  // intervals only — significance testing keeps the settled
  // TR.stats.Z95 = 1.96 (guardrail: the sig methodology must not fork).
  var Z95_EXACT = 1.959963984540054;
  conf.Z95_EXACT = Z95_EXACT;

  // a worked example needs a base big enough not to look like an outlier
  var EXAMPLE_MIN_BASE = 100;

  /* ---------------- sampling-method-aware labels ---------------- */

  // config value -> spec key (the switch in get_sampling_labels()).
  // Convenience and Self_Selected are synonyms -> the same softened framing.
  var METHOD_KEYS = {
    Random: "random", Stratified: "stratified", Cluster: "cluster",
    Census: "census", Quota: "quota", Online_Panel: "panel",
    Self_Selected: "convenience", Convenience: "convenience",
    Not_Specified: "not_specified"
  };
  var PROBABILITY_KEYS = ["random", "stratified", "cluster", "census"];

  var STANDARD_LABELS = {
    is_probability: true,
    interval_name: "Confidence Interval", interval_abbrev: "CI",
    moe_name: "Margin of Error", moe_abbrev: "MOE",
    halfwidth_name: "Half-Width",
    precision_term: "margin of error", interval_term: "confidence interval"
  };
  var SOFTENED_LABELS = {
    is_probability: false,
    interval_name: "Stability Interval", interval_abbrev: "SI",
    moe_name: "Precision Estimate", moe_abbrev: "PE",
    halfwidth_name: "Precision Estimate",
    precision_term: "precision range", interval_term: "stability interval"
  };

  /**
   * Presentation labels for a sampling method (default: the project's
   * configured sampling_method). NULL / empty / unrecognised values fall
   * back to the cautious non-probability framing, exactly as the R does.
   * @param {string} [method] - Random | Stratified | Cluster | Census |
   *   Quota | Online_Panel | Self_Selected | Convenience | Not_Specified
   * @returns {object} labels — see STANDARD_LABELS/SOFTENED_LABELS keys
   *   plus sampling_method_normalised.
   */
  conf.labels = function (method) {
    if (method === undefined) {
      method = TR.AGG && TR.AGG.project && TR.AGG.project.sampling_method;
    }
    var key = METHOD_KEYS[String(method == null ? "" : method).trim()] ||
      "not_specified";
    var base = PROBABILITY_KEYS.indexOf(key) !== -1
      ? STANDARD_LABELS : SOFTENED_LABELS;
    var out = { sampling_method_normalised: key };
    Object.keys(base).forEach(function (k) { out[k] = base[k]; });
    return out;
  };

  /**
   * Short method tag for meta lines and band notes. The bracket must name
   * what was actually computed: proportions use Wilson, but mean/Index/NPS
   * intervals are z·SD/√n on the distribution-derived SD — calling those
   * "Wilson" would be dishonest on exported artifacts.
   * @param {string} [kind] - "props" (default): "95% SI (Wilson)";
   *   "means": "95% SI (z·SD/√n)"; "mixed": both named.
   */
  conf.methodNote = function (kind) {
    var abbrev = conf.labels().interval_abbrev;
    if (kind === "means") return "95% " + abbrev + " (z·SD/√n)";
    if (kind === "mixed") {
      return "95% " + abbrev + " (Wilson; means z·SD/√n)";
    }
    return "95% " + abbrev + " (Wilson)";
  };

  /** methodNote kind for a crosstab model: "mixed" when any mean row
   *  carries an interval (Index/NPS rows in an interval view), else
   *  "props". Run on models built with {intervals: true}. */
  conf.modelIntervalKind = function (model) {
    var hasMeanCi = !!(model && model.rows && model.rows.some(function (r) {
      return r.kind === "mean" && (r.cells || []).some(function (c) {
        return c && c.ci;
      });
    }));
    return hasMeanCi ? "mixed" : "props";
  };

  /* ---------------- Wilson score interval ---------------- */

  /**
   * Wilson score 95% interval for a proportion — verbatim port of
   * calculate_proportion_ci_wilson() (04_proportions.R). Asymmetric
   * around p; never leaves [0,1]; accurate for small n and extreme p.
   * @param {number} p - observed proportion in [0,1]
   * @param {number} n - base (unweighted; effective n hook for weighted
   *   data lives in the production module's 03_study_level.R)
   * @returns {{lower:number, upper:number, center:number}|null} null on
   *   invalid input (no silent zero-width intervals).
   */
  conf.wilson = function (p, n) {
    if (!(n >= 1) || !(p >= 0 && p <= 1)) return null;
    var z2 = Z95_EXACT * Z95_EXACT;
    var denominator = 1 + z2 / n;
    var center = (p + z2 / (2 * n)) / denominator;
    var margin = Z95_EXACT *
      Math.sqrt((p * (1 - p) + z2 / (4 * n)) / n) / denominator;
    return {
      lower: Math.max(0, center - margin),
      upper: Math.min(1, center + margin),
      center: center
    };
  };

  /** Wilson bounds for a percentage value (0–100): {lo, hi} in points. */
  conf.wilsonPct = function (pct, n) {
    if (pct === null || pct === undefined) return null;
    var w = conf.wilson(Math.min(Math.max(pct / 100, 0), 1), n);
    return w ? { lo: w.lower * 100, hi: w.upper * 100 } : null;
  };

  /**
   * Symmetric 95% interval for a mean on a known SD: mean ± z·SD/√n.
   * The SD must come from the shared distribution-derived source
   * (TR.waves.scoreMap + sdFromPairs / TR.trk.sdAt) — never recompute it.
   */
  conf.meanCI = function (mean, sd, n) {
    if (mean === null || mean === undefined ||
        sd === null || sd === undefined || !(n >= 2)) return null;
    var half = Z95_EXACT * sd / Math.sqrt(n);
    return { lo: mean - half, hi: mean + half };
  };

  /** Worst-case ±pp at a base (p = 0.5): "stable to about ±2.7pp". */
  conf.maxMoePct = function (n) {
    if (!(n >= 1)) return null;
    return Z95_EXACT * Math.sqrt(0.25 / n) * 100;
  };

  /* ---------------- finite population correction (FPC) ---------------- */

  /**
   * Effective-base multiplier for a base of nActual respondents drawn from a
   * known finite population N: (N-1)/(N-nActual). Verbatim port of
   * apply_fpc()/calculate_fpc_factor() in 03_study_level.R.
   *  - >= 1 (narrows the interval / strengthens the test);
   *  - Infinity at full census (nActual >= N) -> zero-width interval;
   *  - 1 when no usable population is known -> unconfigured reports unchanged.
   */
  conf.fpcMul = function (nActual, N) {
    if (!(N > 1) || !(nActual > 0)) return 1;
    if (nActual >= N) return Infinity;
    return (N - 1) / (N - nActual);
  };

  /** FPC-adjusted effective base: feed straight into wilson/meanCI/z-tests.
   *  nEff is the actual count (unweighted) or the Kish n_eff (weighted). */
  conf.fpcBase = function (nEff, nActual, N) {
    var mul = conf.fpcMul(nActual, N);
    return mul === Infinity ? Infinity : nEff * mul;
  };

  /** Sampled fraction of the universe, clamped to [0,1] (null when unknown). */
  conf.coverage = function (nActual, N) {
    if (!(N > 1) || !(nActual > 0)) return null;
    return Math.min(nActual / N, 1);
  };

  /** Does this report carry any configured population (a per-column universe
   *  or the study total)? Gates the whole FPC path; cached on TR.AGG. */
  conf.reportHasPopulation = function () {
    var agg = TR.AGG;
    if (!agg) return false;
    if (agg._hasPop !== undefined) return agg._hasPop;
    var any = !!(agg.project && agg.project.population_size > 1);
    (agg.columns || []).forEach(function (c) {
      if (c && c.population > 1) any = true;
    });
    agg._hasPop = any;
    return any;
  };

  /** Overall response/coverage rate from the study total (TR.MICRO.n / N), or
   *  null when no total universe is configured. Shown in the design note. */
  conf.responseRate = function () {
    var agg = TR.AGG;
    var N = agg && agg.project && agg.project.population_size;
    var n = TR.MICRO && TR.MICRO.n;
    if (!(N > 1) || !(n > 0)) return null;
    return { n: n, N: N, rate: Math.min(n / N, 1) };
  };

  /** Display range: "81–87" for percentages, "7.2–7.6" for means. */
  conf.fmtRange = function (lo, hi, isMean) {
    if (lo === null || lo === undefined || hi === null || hi === undefined) {
      return "";
    }
    return isMean
      ? Number(lo).toFixed(1) + "–" + Number(hi).toFixed(1)
      : Math.round(lo) + "–" + Math.round(hi);
  };

  /* ---------------- lay-reader explainer callout ---------------- */

  /**
   * Data-derived worked example for the explainer: among non-difference
   * NET rows with a solid Total base, the one with the largest base
   * (ties: largest value) — deterministic for any project's data.
   */
  function workedExample() {
    var best = null;
    // When the Total universe is known, the table's Total intervals are
    // FPC-corrected — so the worked example must use the same effective base,
    // otherwise the callout quotes a wider range than the table shows.
    var totalN = TR.AGG.columns && TR.AGG.columns[0] && TR.AGG.columns[0].population;
    (TR.AGG.questions || []).forEach(function (q) {
      var base = q.bases && q.bases[0] && q.bases[0].n;
      if (!base || base < EXAMPLE_MIN_BASE) return;
      q.rows.forEach(function (r, ri) {
        if (r.kind !== "net") return;
        if (q.net_diffs && q.net_diffs[String(ri)]) return;
        var pct = r.pct && r.pct[0];
        if (pct === null || pct === undefined) return;
        if (best && (base < best.n || (base === best.n && pct <= best.pct))) {
          return;
        }
        var ciBase = (totalN > 1) ? conf.fpcBase(base, base, totalN) : base;
        var w = conf.wilsonPct(pct, ciBase);
        if (w) best = { pct: pct, n: base, lo: w.lo, hi: w.hi, fpc: totalN > 1 };
      });
    });
    return best;
  }

  /**
   * Smallest column of the default banner group on the fullest question —
   * the honest "small groups swing more" example (e.g. Durban n=75).
   */
  function smallColumnExample() {
    var groups = TR.AGG.banner_groups || [];
    if (!groups.length) return null;
    var q = null;
    (TR.AGG.questions || []).forEach(function (qq) {
      var b = qq.bases && qq.bases[0] && qq.bases[0].n;
      if (b && (!q || b > q.bases[0].n)) q = qq;
    });
    if (!q) return null;
    var smallest = null;
    TR.d2.groupCols(groups[0].id).forEach(function (ci) {
      var b = q.bases && q.bases[ci] && q.bases[ci].n;
      if (b && (!smallest || b < smallest.n)) {
        smallest = { label: TR.AGG.columns[ci].label, n: b,
          population: TR.AGG.columns[ci].population };
      }
    });
    return smallest;
  }

  /**
   * Census / finite-population caveat appended to the design sentence when a
   * population is configured: name the coverage, say the intervals are FPC'd,
   * and flag non-response as the residual (uncorrectable) uncertainty so a
   * narrow interval never reads as certainty. "" when no population is set.
   */
  function fpcNote() {
    if (!conf.reportHasPopulation()) return "";
    var rr = conf.responseRate();
    var lead = rr
      ? " This was a near-census: about " + Math.round(rr.rate * 100) +
        "% of the " + TR.fmt.base(rr.N) + "-strong universe responded, so "
      : " Known group sizes were supplied, so ";
    return lead + "ranges include a <strong>finite population correction</strong> " +
      "— they narrow as coverage of a group rises, reaching zero for a full " +
      "census. The remaining uncertainty is mainly <strong>non-response</strong>: " +
      "the people who did not answer may differ from those who did, and no " +
      "interval can correct for that.";
  }

  /** One honest sentence about the sampling design (labels port). */
  function designSentence(labels) {
    if (!labels.is_probability) {
      return "Responses were not drawn by formal random sampling, so ranges " +
        "are <strong>stability intervals (" + labels.interval_abbrev +
        ")</strong> — how much a number would wobble — not formal " +
        "confidence intervals." + fpcNote();
    }
    if (labels.sampling_method_normalised === "cluster") {
      // CLUSTER_WARNING_HTML pattern: clustering is not adjusted for
      return "Probability (cluster) sample: ranges are 95% confidence " +
        "intervals, but respondents cluster, so true uncertainty can be " +
        "larger — treat near-" + labels.precision_term +
        " differences with caution." + fpcNote();
    }
    return "This survey used probability sampling, so ranges are formal " +
      "95% <strong>confidence intervals (" + labels.interval_abbrev +
      ")</strong>." + fpcNote();
  }

  /**
   * The shared "How sure can I be of these numbers?" collapsible footer
   * callout (crosstabs + tracking). Pure string; examples computed live
   * from the report's own data so every sentence stays true.
   */
  conf.calloutHtml = function () {
    var labels = conf.labels();
    var ex = workedExample();
    var small = smallColumnExample();
    var fmt = TR.fmt;
    var bullets = [];
    if (ex) {
      // worked example with real numbers, and it NAMES the concept (so the
      // CI/SI/MOE jargon elsewhere has an anchor). Tail matches the inference:
      // FPC ranges describe the whole group; uncorrected ranges describe a re-run.
      var tail = ex.fpc
        ? "% for the group as a whole"
        : "% if we ran the survey again";
      bullets.push("<li><strong>Every number is an estimate, not an exact count.</strong> " +
        "For example, a " + Math.round(ex.pct) + "% based on " +
        fmt.base(ex.n) + " answers would sit between " + Math.round(ex.lo) +
        "% and " + Math.round(ex.hi) + tail + " — that band is the 95% " +
        fmt.escapeHtml(labels.interval_name) + " (" +
        fmt.escapeHtml(labels.interval_abbrev) + ").</li>");
    }
    // what the "95%" actually means — kept honest for non-probability designs,
    // where a wobble band is not a formal coverage guarantee
    bullets.push(labels.is_probability
      ? "<li><strong>What “95%” means:</strong> if we repeated the survey, the true " +
        "figure would fall inside the range about 19 times out of 20.</li>"
      : "<li><strong>Reading the ranges:</strong> they show how far a number would " +
        "likely wobble if you measured again — a wider range means less certainty.</li>");
    if (small) {
      // FPC-consistent ±pp when the group's universe is known (matches the
      // table's corrected margin rather than the raw-base one).
      var sBase = (small.population > 1)
        ? conf.fpcBase(small.n, small.n, small.population) : small.n;
      bullets.push("<li><strong>Small groups swing more.</strong> " +
        fmt.escapeHtml(small.label) + " has only " + fmt.base(small.n) +
        " respondents, so its numbers can move by about ±" +
        conf.maxMoePct(sBase).toFixed(0) +
        "pp — treat them as indicative.</li>");
    }
    bullets.push("<li><strong>Comparing two numbers:</strong> if two groups’ ranges " +
      "overlap, treat the difference as noise rather than a real gap.</li>");
    bullets.push("<li><strong>“Significant”</strong> means a difference too " +
      "large to be explained by sampling wobble alone — not necessarily " +
      "an important one.</li>");
    bullets.push("<li><strong>About this survey:</strong> " +
      designSentence(labels) + "</li>");
    return '<div class="callout collapsed footer-callout">' +
      '<button class="callout-head" data-callout>' +
      '<span class="callout-ico">±</span> How sure can I be of these numbers?' +
      '<span class="callout-chev">▼</span></button>' +
      '<div class="callout-body"><ul>' + bullets.join("") + "</ul></div></div>";
  };

})(typeof window !== "undefined" ? window : globalThis);
