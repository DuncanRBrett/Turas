# ==============================================================================
# FINITE POPULATION CORRECTION (FPC)
# ==============================================================================
# Part of Turas shared module infrastructure.
#
# The single definition of the FPC for the whole platform. It began life in the
# confidence module (R/03_study_level.R) and moved here unchanged when the tabs
# crosstab engine needed it too — significance letters and confidence intervals
# have to engage the correction on the same terms, or the Excel workbook and the
# interactive report disagree about a census.
#
# The v2 report's JS (assets/js/21c_confidence.js) is a port of these functions;
# FPC_MIN_COVERAGE is mirrored there. Change one, change both.
#
# WHO SOURCES THIS
# - modules/confidence/R/03_study_level.R  (sources it, API unchanged)
# - modules/tabs/lib/weighting.R           (sources it for the pairwise tests)
#
# DEPENDENCIES: none. These are pure functions over numbers, deliberately kernel-
# style: an unusable input returns a neutral value rather than refusing, because
# they sit inside per-cell loops where a refusal would abort a whole report.
# ==============================================================================

# Material-coverage floor. Below this sampling fraction (n / N) the finite
# population correction is negligible and — more to the point — the study is a
# SAMPLE, not a census, so no correction is applied. Mirrors FPC_MIN_COVERAGE in
# the v2 report's JS (21c_confidence.js) so the Excel crosstabs, the stats pack
# and the interactive report always agree on when the FPC engages.
FPC_MIN_COVERAGE <- 0.05

#' Finite population correction factor
#'
#' When a sample of \code{n} respondents is drawn (without replacement) from a
#' \emph{known finite population} of \code{N}, its standard error is smaller than
#' the infinite-population formula implies. This returns the multiplier applied
#' to that standard error:
#'
#' FORMULA: FPC = sqrt( (N - n) / (N - 1) )   ( ≈ sqrt(1 - n/N) for large N )
#'
#' Use this for census / full-invite designs with partial response, and for
#' small subgroups (e.g. a Masters cohort of 27 with 20 responding) where the
#' sample is a large share of its universe. FPC corrects \emph{sampling} error
#' only — it does nothing about non-response bias.
#'
#' EDGE CASES (return a neutral, non-destructive value rather than refusing, to
#' match \code{calculate_effective_n}'s kernel style):
#' - \code{N} missing / NA / non-finite / <= 1: returns 1 (no correction).
#' - \code{n} missing / NA / <= 0: returns 1 (no correction).
#' - Coverage \code{n / N <= FPC_MIN_COVERAGE} (5%): returns 1 — a thin sample is
#'   not a census, and the correction would be negligible, so none is applied.
#' - \code{n >= N} (full census, incl. rounding over-coverage): returns 0 — there
#'   is nothing left to be uncertain about once everyone is measured.
#'
#' @param n Numeric. Number of respondents in the base (unweighted count).
#' @param N Numeric. Known population size for that base.
#'
#' @return Numeric in [0, 1]. The standard-error multiplier.
#'
#' @examples
#' calculate_fpc_factor(20, 27)   # ~0.520 — Masters cohort, near-complete count
#' calculate_fpc_factor(167, 556) # ~0.840 — 30% response, modest correction
#' calculate_fpc_factor(50, NA)   # 1 — no population known, no correction
#' @export
calculate_fpc_factor <- function(n, N) {
  if (is.null(N) || length(N) != 1L || is.na(N) || !is.finite(N) || N <= 1) {
    return(1)
  }
  if (is.null(n) || length(n) != 1L || is.na(n) || !is.finite(n) || n <= 0) {
    return(1)
  }
  if (n / N <= FPC_MIN_COVERAGE) {
    return(1)   # thin sample: correction negligible -> treat as infinite-population
  }
  if (n >= N) {
    return(0)
  }
  sqrt((N - n) / (N - 1))
}


#' Apply finite population correction to an effective base
#'
#' Re-expresses the FPC as an inflated \emph{effective base} so it composes with
#' the rest of the module: feed the result straight into Wilson / mean-CI / z-
#' and t-tests exactly where a Kish effective-n already flows, and every interval
#' and significance test becomes finite-population aware in one consistent step.
#'
#' FORMULA: n_eff_fpc = n_eff * (N - 1) / (N - n_actual)
#'
#' The sampling fraction uses \code{n_actual} (the real respondent count), while
#' the variance base uses \code{n_eff} (which equals \code{n_actual} unweighted,
#' or the Kish effective-n when weighted) — so weighting and FPC stack correctly.
#'
#' EDGE CASES:
#' - No usable population (NA / non-finite / <= 1): returns \code{n_eff} unchanged
#'   ⇒ byte-identical to a report with no population configured.
#' - Coverage \code{n_actual / N <= FPC_MIN_COVERAGE} (5%): returns \code{n_eff}
#'   unchanged — a thin sample is treated as an infinite-population sample.
#' - \code{n_actual >= N} (full census): returns \code{Inf} ⇒ a zero-width
#'   interval downstream (Wilson/mean-CI collapse to the point estimate).
#'
#' @param n_eff Numeric. The effective base to correct (actual n, or Kish n_eff).
#' @param n_actual Numeric. Unweighted respondent count for the base.
#' @param N Numeric. Known population size for the base.
#'
#' @return Numeric. The FPC-adjusted effective base (\code{Inf} for a full census).
#'
#' @examples
#' apply_fpc(20, 20, 27)   # ~74.3 — n_eff inflates, interval roughly halves
#' apply_fpc(20, 20, NA)   # 20 — unchanged, no correction
#' apply_fpc(27, 27, 27)   # Inf — full census, zero-width interval
#' @export
apply_fpc <- function(n_eff, n_actual, N) {
  if (is.null(N) || length(N) != 1L || is.na(N) || !is.finite(N) || N <= 1) {
    return(n_eff)
  }
  if (is.null(n_actual) || length(n_actual) != 1L || is.na(n_actual) ||
      !is.finite(n_actual) || n_actual <= 0) {
    return(n_eff)
  }
  if (n_actual / N <= FPC_MIN_COVERAGE) {
    return(n_eff)   # thin sample: correction negligible -> effective base unchanged
  }
  if (n_actual >= N) {
    return(Inf)
  }
  n_eff * (N - 1) / (N - n_actual)
}

