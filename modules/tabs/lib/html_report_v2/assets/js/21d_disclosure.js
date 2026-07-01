/**
 * v2 disclosure control (re-identification protection).
 *
 * Composite audience filters can narrow a report onto a handful of people — fine on a
 * 1,363-student survey, dangerous on a 200-person staff survey where "Finance · female ·
 * 10y+" is one identifiable person. This module is the single source of truth for "is the
 * current view small enough to risk identifying someone?". Every view consults it rather
 * than each re-implementing a threshold.
 *
 * The dial is one configurable minimum base k (project.min_reporting_base; 1 = off). The
 * live audience base is the number of respondents matching the global filter — which is N
 * when unfiltered, so setting k = N forbids any sub-group drill-down (only the full-sample
 * view ever shows identifying detail). Below k the renderer withholds the comment
 * demographic tags (and, next, small crosstab cells).
 */
(function (global) {
  "use strict";
  var TR = global.TR = global.TR || {};
  var disc = TR.disclosure = TR.disclosure || {};

  /** The configured minimum reporting base k (>=1; 1 means disclosure control is off). */
  disc.minBase = function () {
    var p = TR.AGG && TR.AGG.project;
    var k = p && p.min_reporting_base;
    return (typeof k === "number" && k > 1) ? k : 1;
  };

  /** Whether disclosure control is engaged for this report at all. */
  disc.active = function () { return disc.minBase() > 1; };

  /** Respondents matching the live global filter (= the whole sample when unfiltered).
   *  Returns null when the base cannot be computed (no microdata island) — the caller
   *  MUST treat that as "unknown", never as "large" (see audienceTooSmall: fail closed). */
  disc.audienceBase = function () {
    if (!TR.MICRO) return null;
    var f = TR.d2 && TR.d2.state && TR.d2.state.filters;
    return (f && f.length && TR.stats) ? TR.stats.maskCount(TR.stats.mask(f)) : TR.MICRO.n;
  };

  /** True when the live audience is too small to show identifying detail (tags, quotes).
   *  Fails CLOSED: if disclosure is engaged but the base can't be verified (microdata
   *  absent — e.g. the build degraded to published-only), withhold detail rather than
   *  assume the audience is safe. */
  disc.audienceTooSmall = function () {
    if (!disc.active()) return false;
    var base = disc.audienceBase();
    return base === null || base < disc.minBase();
  };

  /** Whether a single count (a crosstab cell, a sub-base) is safe to show in full. A
   *  genuinely empty cell (0) is fine; 1..k-1 is the disclosure risk and is suppressed. */
  disc.cellOk = function (count) {
    return !disc.active() || count === 0 || count >= disc.minBase();
  };

  /** Standard one-liner for the UI when the audience is below the threshold. */
  disc.note = function () {
    var base = disc.audienceBase();
    if (base === null) {
      return "Confidentiality threshold (k=" + disc.minBase() + ") is on but the audience size " +
        "can't be verified in this view — demographic detail is hidden to protect individual identities.";
    }
    return "Audience too small (n=" + base + ", below the confidentiality threshold of " +
      disc.minBase() + ") — demographic detail is hidden to protect individual identities. " +
      "Broaden the filter to see it.";
  };
})(typeof window !== "undefined" ? window : globalThis);
