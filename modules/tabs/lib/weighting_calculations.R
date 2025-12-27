# ==============================================================================
# WEIGHTING CALCULATIONS V10.0 - CORE CALCULATION MODULE
# ==============================================================================
# Functions for basic weighted calculations: effective-n, variance, counts, means
# Part of R Survey Analytics Toolkit
#
# MODULE PURPOSE:
# This module provides the fundamental weighted calculation functions used
# throughout the survey analysis toolkit. These include effective sample size
# (Kish 1965), weighted variance, weighted counts, percentages, and means.
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - EXTRACTED: From weighting.R V9.9.4 (~320 lines)
#         - MAINTAINED: All V9.9.4 calculation logic and numeric stability
#         - NO CHANGES: Function signatures and behavior identical
# V9.9.4 - Documented rounding & zero exclusion in effective-n
# V9.9.3 - Numeric stability in effective-n, fail-fast length checks
# V9.9.2 - Explicit NA handling in weighted counts
#
# STATISTICAL METHODOLOGY:
# - Effective sample size: n_eff = (Σw)² / Σw²  (Kish 1965)
# - Weighted variance: Population estimator Var = Σw(x - x̄)² / Σw
# - Weighted counts: Sum of weights where condition is TRUE
# - Weighted means: Σ(w×x) / Σw
#
# EXPORTED FUNCTIONS:
# - calculate_effective_n(): Calculate effective sample size (Kish formula)
# - weighted_variance(): Calculate weighted population variance
# - calculate_weighted_count(): Sum weights for matching condition
# - calculate_weighted_percentage(): Convert count/base to percentage
# - calculate_weighted_mean(): Calculate weighted mean
# ==============================================================================

WEIGHTING_CALCULATIONS_VERSION <- "10.0"

# ==============================================================================
# EFFECTIVE SAMPLE SIZE (V9.9.4: DOCUMENTED ROUNDING & ZERO EXCLUSION)
# ==============================================================================

#' Calculate effective sample size for weighted data (Kish 1965)
#'
#' METHODOLOGY:
#' Uses Kish's design effect formula: n_eff = (Σw)² / Σw²
#'
#' V9.9.3 NUMERIC STABILITY:
#' For extreme weights, scales by w/mean(w) internally (scale-invariant)
#' This prevents numeric overflow with very large weights
#'
#' V9.9.4 DOCUMENTATION:
#' - Zero weights are excluded (only weights > 0 are used)
#' - Result is rounded to integer (downstream SE/df calculations use rounded value)
#'
#' INTERPRETATION:
#' - n_eff = n when all weights equal (unweighted)
#' - n_eff < n when weights vary (reduced precision)
#' - Lower n_eff means higher design effect (less efficient sampling)
#' - Used in significance testing to account for weighting impact
#'
#' REFERENCE: Kish, L. (1965). Survey Sampling. New York: John Wiley & Sons.
#'
#' @param weights Numeric vector, weights
#' @return Integer, effective sample size (rounded)
#' @export
#' @examples
#' eff_n <- calculate_effective_n(weights)
#'
#' # Check design effect
#' design_effect <- length(weights) / calculate_effective_n(weights)
calculate_effective_n <- function(weights) {
  # Remove NA/infinite weights and keep only positive (zeros excluded)
  weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(weights) == 0) {
    return(0L)
  }

  # If all weights are 1, effective n = actual n (no design effect)
  if (all(weights == 1)) {
    return(as.integer(length(weights)))
  }

  # V9.9.3: Scale-safe calculation for extreme weights
  # Effective-n is scale-invariant, so we can normalize by mean
  # This prevents numeric overflow with very large weights
  mean_weight <- mean(weights)

  if (is.finite(mean_weight) && mean_weight > 0) {
    # Scale by mean for numeric stability
    w <- weights / mean_weight
    n_effective <- (sum(w)^2) / sum(w^2)
  } else {
    # Fallback to direct calculation (shouldn't happen if weights validated)
    sum_weights <- sum(weights)
    sum_weights_squared <- sum(weights^2)

    if (sum_weights_squared == 0) {
      return(0L)
    }

    n_effective <- (sum_weights^2) / sum_weights_squared
  }

  # Return as integer (downstream SE/df use this rounded value)
  return(as.integer(round(n_effective)))
}

# ==============================================================================
# WEIGHTED VARIANCE (V9.9.1)
# ==============================================================================

#' Calculate weighted variance (POPULATION VARIANCE)
#'
#' METHODOLOGY:
#' Uses population variance estimator: Var = Σw(x - x̄)² / Σw
#' NOT Bessel-corrected (unbiased) estimator
#'
#' RATIONALE:
#' - This is appropriate because effective-n is used in SE calculations
#' - Combining population variance with effective-n gives correct SE
#' - If you need unbiased variance, divide by (Σw - 1) instead
#'
#' USAGE: Called by weighted t-tests for means
#'
#' @param values Numeric vector, values
#' @param weights Numeric vector, weights
#' @return Numeric, weighted population variance
#' @export
#' @examples
#' var_weighted <- weighted_variance(ratings, weights)
weighted_variance <- function(values, weights) {
  # Validate inputs
  if (length(values) != length(weights)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Values and Weights Length Mismatch",
      problem = sprintf("values and weights must have same length (got %d and %d).", length(values), length(weights)),
      why_it_matters = "Each value must have a corresponding weight for variance calculation.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  # Keep only valid observations
  valid_idx <- !is.na(values) & !is.na(weights) & is.finite(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) < 2) {
    return(0)
  }

  sum_weights <- sum(weights)
  if (sum_weights == 0) {
    return(0)
  }

  # Calculate weighted mean
  weighted_mean <- sum(values * weights) / sum_weights

  # Calculate weighted population variance
  weighted_var <- sum(weights * (values - weighted_mean)^2) / sum_weights

  return(weighted_var)
}

# ==============================================================================
# WEIGHTED COUNTS (V9.9.2)
# ==============================================================================

#' Calculate weighted count (V9.9.2: Explicit NA handling)
#'
#' USAGE: Count respondents matching a condition with weights
#' DESIGN: Treats NA in condition as FALSE (explicit, safe)
#' V9.9.2: Length mismatch now stops (not returns 0)
#'
#' @param condition_vector Logical vector, which rows to count
#' @param weights Numeric vector, weight vector
#' @return Numeric, weighted count
#' @export
calculate_weighted_count <- function(condition_vector, weights) {
  # V9.9.2: Stop on length mismatch (not return 0)
  if (length(condition_vector) != length(weights)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Condition Vector and Weights Length Mismatch",
      problem = sprintf("Condition vector (%d) and weights (%d) have different lengths.", length(condition_vector), length(weights)),
      why_it_matters = "Each row's condition must have a corresponding weight value.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  # V9.9.2: Explicit NA handling - treat NA as FALSE
  cond <- as.logical(condition_vector)
  idx <- !is.na(cond) & cond

  # Sum weights where condition is TRUE (na.rm for safety with weights)
  weighted_count <- sum(weights[idx], na.rm = TRUE)

  return(weighted_count)
}

# ==============================================================================
# WEIGHTED PERCENTAGES (V9.9.3: ROUNDING POLICY DOCUMENTED)
# ==============================================================================

#' Calculate weighted percentage
#'
#' USAGE: Convert weighted count and base to percentage
#' DESIGN: Returns NA for 0/0 division (not 0 or error)
#'
#' ROUNDING POLICY (V9.9.3):
#' This function rounds to specified decimal places for quick calculations.
#' Most formatting is deferred to Excel writer in run_crosstabs.r.
#' If calling this for intermediate calculations, be aware of rounding.
#' For maximum precision in intermediate steps, use raw division and
#' round only at final presentation layer.
#'
#' @param weighted_count Numeric, weighted numerator
#' @param weighted_base Numeric, weighted denominator
#' @param decimal_places Integer, decimal places for rounding (default: 0)
#' @return Numeric, weighted percentage (0-100 scale) or NA
#' @export
#' @examples
#' # Quick calculation with rounding
#' pct <- calculate_weighted_percentage(50, 100, decimal_places = 1)  # 50.0
#'
#' # For intermediate calculations, consider raw division
#' pct_precise <- (weighted_count / weighted_base) * 100  # No rounding
calculate_weighted_percentage <- function(weighted_count, weighted_base,
                                         decimal_places = 0) {
  if (is.na(weighted_base) || weighted_base == 0) {
    return(NA_real_)
  }

  return(round((weighted_count / weighted_base) * 100, decimal_places))
}

# ==============================================================================
# WEIGHTED MEANS (V9.9.3: LENGTH MISMATCH NOW ERRORS)
# ==============================================================================

#' Calculate weighted mean (V9.9.3: Fail-fast on length mismatch)
#'
#' USAGE: Calculate mean with weights
#' DESIGN: Returns NA if no valid observations
#' V9.9.3: Length mismatch now stops (catches upstream bugs early)
#'
#' @param values Numeric vector, values
#' @param weights Numeric vector, weights
#' @return Numeric, weighted mean or NA
#' @export
calculate_weighted_mean <- function(values, weights) {
  # V9.9.3: Stop on length mismatch (fail fast)
  if (length(values) != length(weights)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Values and Weights Length Mismatch",
      problem = sprintf("values (%d) and weights (%d) have different lengths.", length(values), length(weights)),
      why_it_matters = "Each value must have a corresponding weight for mean calculation.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  # Remove NAs and keep only positive finite weights
  valid_idx <- !is.na(values) & !is.na(weights) & is.finite(weights) & weights > 0
  values <- values[valid_idx]
  weights <- weights[valid_idx]

  if (length(values) == 0 || sum(weights) == 0) {
    return(NA_real_)
  }

  weighted_mean <- sum(values * weights) / sum(weights)

  return(weighted_mean)
}

# ==============================================================================
# END OF WEIGHTING_CALCULATIONS.R V10.0
# ==============================================================================
