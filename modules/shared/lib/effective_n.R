# ==============================================================================
# TURAS SHARED — KISH EFFECTIVE SAMPLE SIZE
# ==============================================================================
#
# One definition of Kish's effective sample size for the whole platform.
#
# Before this file, four modules carried their own copy and three of them
# behaved differently:
#
#   modules/tabs/lib/weighting.R        fractional, finite-filtered, scale-safe
#   modules/confidence/R/03_study_level.R  as above but rounded to an integer
#   modules/maxdiff/R/utils.R           fractional, but no finite filter and no
#                                       scale normalisation, so it returned NaN
#                                       on infinite or very large weights
#
# Those differences are not cosmetic: n_eff feeds standard errors, degrees of
# freedom and minimum-base gates, so two modules describing the same weighted
# sample could disagree about how much information it carries.
#
# REFERENCE: Kish, L. (1965). Survey Sampling. New York: John Wiley & Sons.
# ==============================================================================

#' Kish Effective Sample Size
#'
#' The effective sample size of a weighted sample: the size an unweighted
#' sample would need to be to carry the same information.
#'
#' \deqn{n_{eff} = \frac{(\sum w)^2}{\sum w^2}}
#'
#' Weights that are NA, infinite, zero or negative are dropped before the
#' calculation — they describe no respondent. The remaining weights are scaled
#' by their mean before squaring, which changes nothing (the statistic is
#' scale-invariant) but keeps very large weights from overflowing to infinity.
#'
#' **The value is fractional by design.** It feeds standard errors, degrees of
#' freedom and minimum-base gates, all of which want the real number; rounding
#' belongs at the display site. Use [calculate_effective_n_int()] where a whole
#' number is the established contract.
#'
#' @param weights Numeric vector of weights.
#' @return Numeric. Effective sample size; 0 when no usable weight remains.
#'
#' @examples
#' calculate_effective_n(c(1, 1, 1))     # 3 — no weighting, no loss
#' calculate_effective_n(c(1, 1, 3))     # 2.2727... — variable weights cost precision
#'
#' # Design effect: how much precision the weighting cost
#' w <- c(0.5, 1, 1.5, 2)
#' length(w) / calculate_effective_n(w)
#'
#' @export
calculate_effective_n <- function(weights) {

  # Remove NA/infinite weights and keep only positive (zeros excluded)
  weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(weights) == 0) {
    return(0)
  }

  # If all weights are 1, effective n = actual n (no design effect)
  if (all(weights == 1)) {
    return(as.numeric(length(weights)))
  }

  # Scale-safe calculation for extreme weights.
  # Effective-n is scale-invariant, so normalising by the mean is free and
  # prevents numeric overflow with very large weights.
  mean_weight <- mean(weights)

  if (is.finite(mean_weight) && mean_weight > 0) {
    w <- weights / mean_weight
    n_effective <- (sum(w)^2) / sum(w^2)
  } else {
    # Fallback to direct calculation (shouldn't happen if weights validated)
    sum_weights <- sum(weights)
    sum_weights_squared <- sum(weights^2)

    if (sum_weights_squared == 0) {
      return(0)
    }

    n_effective <- (sum_weights^2) / sum_weights_squared
  }

  n_effective
}


#' Kish Effective Sample Size, Rounded
#'
#' [calculate_effective_n()] rounded to a whole number. Some callers — the
#' confidence module's standard-error and degrees-of-freedom paths among them —
#' have always worked from an integer n_eff, and that contract is preserved
#' here rather than changed underneath them.
#'
#' Prefer the fractional [calculate_effective_n()] for new code: rounding
#' before a variance calculation loses precision for no benefit.
#'
#' @param weights Numeric vector of weights.
#' @return Integer. Effective sample size; 0L when no usable weight remains.
#'
#' @examples
#' calculate_effective_n_int(c(1, 1, 3))  # 2
#'
#' @export
calculate_effective_n_int <- function(weights) {
  n_effective <- calculate_effective_n(weights)
  if (n_effective == 0) return(0L)
  as.integer(round(n_effective))
}
