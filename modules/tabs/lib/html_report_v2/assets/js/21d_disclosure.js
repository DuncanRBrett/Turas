/**
 * v2 disclosure control (re-identification protection).
 *
 * Composite audience filters can narrow a report onto a handful of people. Fine on a
 * 1,363-student survey, dangerous on a 200-person staff survey where "Finance · female ·
 * 10y+" is one identifiable person. This module is the single source of truth for "is the
 * current view small enough to risk identifying someone?". Every view consults it rather
 * than each re-implementing a threshold.
 *
 * The dial is one configurable minimum base k (project.min_reporting_base; 1 = off). The
 * live audience base is the number of respondents matching the global filter, which is N
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

  /** The largest published Total-column base in the report. The confidentiality ship
   *  (html_report_v2_microdata = FALSE) has no per-respondent records, so it also has no
   *  live filter: the audience is ALWAYS the full sample, and the full sample is a
   *  published figure. Mirrors reader._publishedTotalBase (24a_reader.js); column 0 is
   *  the Total column. Null only when no question publishes a base at all. */
  function publishedTotalBase() {
    var best = null;
    ((TR.AGG && TR.AGG.questions) || []).forEach(function (q) {
      var b = q.bases && q.bases[0] ? q.bases[0].n : null;
      if (b != null && (best === null || b > best)) best = b;
    });
    return best;
  }
  disc._publishedTotalBase = publishedTotalBase;

  /** Respondents matching the live global filter (= the whole sample when unfiltered).
   *
   *  Without microdata this returns the PUBLISHED full sample rather than null. Until
   *  now it returned null, audienceTooSmall() failed closed on that, and a confidential
   *  ship therefore hid every comment, tag and quote in the report. That forced the
   *  operator to clear min_reporting_base to get a readable report, which also switched
   *  off the column suppression in applyDisclosureSuppression() (22_model.js) that reads
   *  the PUBLISHED bases and works perfectly well with no microdata. So the one setting
   *  that protects a three-person department was being turned off to make the comments
   *  visible. Nothing is being assumed safe here: with no microdata there is no filter
   *  bar, so the audience genuinely is the whole sample.
   *
   *  Still returns null when the base cannot be established at all (an island with no
   *  published bases), and the caller MUST keep treating that as "unknown". */
  disc.audienceBase = function () {
    if (!TR.MICRO) return publishedTotalBase();
    var f = TR.d2 && TR.d2.state && TR.d2.state.filters;
    return (f && f.length && TR.stats) ? TR.stats.maskCount(TR.stats.mask(f)) : TR.MICRO.n;
  };

  /** True when the live audience is too small to show identifying detail (tags, quotes).
   *  Fails CLOSED: if disclosure is engaged but the base can't be established at all,
   *  withhold detail rather than assume the audience is safe. */
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
      return TR.txt("disclosure.note_unverified", { k: disc.minBase() });
    }
    return TR.txt("disclosure.note_too_small", { n: base, k: disc.minBase() });
  };
})(typeof window !== "undefined" ? window : globalThis);
