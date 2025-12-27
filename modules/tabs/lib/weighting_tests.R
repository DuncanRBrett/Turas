# ==============================================================================
# WEIGHTING TESTS V10.0 - SIGNIFICANCE TESTING MODULE
# ==============================================================================
# Functions for statistical significance testing: z-tests and t-tests
# Part of R Survey Analytics Toolkit
#
# MODULE PURPOSE:
# This module provides significance testing functions for weighted survey data.
# Includes z-tests for proportions and t-tests for means, with proper handling
# of effective sample sizes and weighted variance.
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - EXTRACTED: From weighting.R V9.9.4 (~380 lines)
#         - MAINTAINED: All V9.9.4 significance testing logic
#         - NO CHANGES: Function signatures and behavior identical
# V9.9.4 - Parameter validation for alpha and min_base
# V9.9.3 - Sanity checks for count ≤ base, fail-fast errors
# V9.9.2 - Effective-n from analytic sample (after filtering NAs)
# V9.9.1 - Function signatures aligned with run_crosstabs.r V9.9
#
# STATISTICAL METHODOLOGY:
# Z-tests for proportions:
#   - Pooled proportion: p_pooled = (count1 + count2) / (base1 + base2)
#     Uses design-weighted counts and bases (reflects survey design)
#   - Standard error: SE = sqrt(p_pooled * (1-p_pooled) * (1/n_eff1 + 1/n_eff2))
#     Uses effective sample sizes (accounts for weighting impact)
#
# T-tests for means:
#   - Uses weighted_variance() for population variance
#   - Uses effective-n for degrees of freedom and SE
#   - Welch-Satterthwaite approximation for unequal variances
#
# CRITICAL: Function signatures MUST match run_crosstabs.r V9.9 exactly
# Changes here will break the main analysis script
#
# EXPORTED FUNCTIONS:
# - weighted_z_test_proportions(): Z-test for comparing two proportions
# - weighted_t_test_means(): T-test for comparing two means
#
# INTERNAL FUNCTIONS:
# - prepare_analytic_sample(): Filter to valid observations for testing
# - calculate_t_test_stats(): Calculate t-statistic and p-value
# ==============================================================================

WEIGHTING_TESTS_VERSION <- "10.0"

# ==============================================================================
# SIGNIFICANCE TESTING (V9.9.4: PARAMETER VALIDATION ADDED)
# ==============================================================================

#' Z-test for weighted proportions (V9.9.4: Parameter validation added)
#'
#' SIGNATURE (V9.9.1):
#' - Accepts: count1, base1, count2, base2, eff_n1, eff_n2, is_weighted
#' - V8.0 accepted: count1, base1, weights1, count2, base2, weights2
#' - This matches run_crosstabs.r V9.9 exactly
#'
#' V9.9.3 SANITY CHECKS:
#' - Validates count ≤ base (catches upstream data errors)
#' - Checks for negative values
#' - Prevents odd p-values from bad numerators
#'
#' V9.9.4 PARAMETER VALIDATION:
#' - alpha must be in (0, 1)
#' - min_base must be ≥ 1
#' - Makes function "hard to misuse" in isolation
#'
#' STATISTICAL METHODOLOGY:
#' - Pooled proportion: p_pooled = (count1 + count2) / (base1 + base2)
#'   Uses design-weighted counts and bases (reflects survey design)
#' - Standard error: SE = sqrt(p_pooled * (1-p_pooled) * (1/n_eff1 + 1/n_eff2))
#'   Uses effective sample sizes (accounts for weighting impact)
#' - This combination is standard practice in weighted survey analysis
#'
#' @param count1 Numeric, weighted count for group 1
#' @param base1 Numeric, weighted base for group 1
#' @param count2 Numeric, weighted count for group 2
#' @param base2 Numeric, weighted base for group 2
#' @param eff_n1 Numeric, effective sample size for group 1 (required if is_weighted=TRUE)
#' @param eff_n2 Numeric, effective sample size for group 2 (required if is_weighted=TRUE)
#' @param is_weighted Logical, whether data is weighted (explicit flag, no heuristics)
#' @param min_base Integer, minimum base size for testing (default: 30)
#' @param alpha Numeric, significance level (e.g., 0.05 for 95% CI, default: 0.05)
#' @return List with $significant (logical), $p_value (numeric), $higher (logical)
#' @export
weighted_z_test_proportions <- function(count1, base1, count2, base2,
                                       eff_n1 = NULL, eff_n2 = NULL,
                                       is_weighted = FALSE,
                                       min_base = 30,
                                       alpha = 0.05) {
  # V9.9.4: Parameter validation (makes function hard to misuse)
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Alpha Parameter",
      problem = "alpha must be a single numeric value between 0 and 1.",
      why_it_matters = "Alpha defines the significance level for statistical tests (e.g., 0.05 for 95% confidence).",
      how_to_fix = "Set alpha to a value between 0 and 1 (typically 0.05 or 0.01)"
    )
  }

  if (!is.numeric(min_base) || length(min_base) != 1 || min_base < 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid min_base Parameter",
      problem = "min_base must be a single numeric value >= 1.",
      why_it_matters = "min_base defines the minimum sample size required for statistical testing.",
      how_to_fix = "Set min_base to a positive integer (typically 30 or more)"
    )
  }

  # Validate inputs
  if (any(is.na(c(count1, base1, count2, base2)))) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }

  # V9.9.3: Sanity check count/base relationship
  if (count1 < 0 || count2 < 0 || base1 < 0 || base2 < 0) {
    warning("Negative count or base values detected; skipping z-test.", call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }

  if (count1 > base1 || count2 > base2) {
    warning(sprintf(
      "Count exceeds base (count1=%.1f, base1=%.1f, count2=%.1f, base2=%.1f); skipping z-test.\nThis may indicate duplicated rows or upstream data errors.",
      count1, base1, count2, base2
    ), call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }

  # Explicit is_weighted flag (V9.9.1: no heuristics)
  if (is_weighted && (is.null(eff_n1) || is.null(eff_n2))) {
    warning(
      "Weighted data requires effective-n for valid significance testing. Test skipped.",
      call. = FALSE
    )
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }

  # Determine sample sizes to use
  n1 <- if (is_weighted && !is.null(eff_n1)) eff_n1 else base1
  n2 <- if (is_weighted && !is.null(eff_n2)) eff_n2 else base2

  # Check minimum base size
  if (n1 < min_base || n2 < min_base) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }

  # Check for zero bases
  if (base1 == 0 || base2 == 0) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }

  # Calculate proportions
  p1 <- count1 / base1
  p2 <- count2 / base2

  # Pooled proportion (uses design-weighted counts)
  p_pooled <- (count1 + count2) / (base1 + base2)

  # Edge cases: degenerate proportions
  if (p_pooled == 0 || p_pooled == 1) {
    # Both groups have 0% or 100% - no difference to test
    return(list(significant = FALSE, p_value = 1, higher = (p1 > p2)))
  }

  # Standard error (uses effective sample sizes)
  se <- sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))

  if (se == 0 || is.na(se)) {
    return(list(significant = FALSE, p_value = 1, higher = (p1 > p2)))
  }

  # Z-statistic and p-value
  z_stat <- (p1 - p2) / se
  p_value <- 2 * pnorm(-abs(z_stat))

  # V9.9.1: Uses alpha comparison
  return(list(
    significant = (!is.na(p_value) && p_value < alpha),
    p_value = p_value,
    higher = (p1 > p2)
  ))
}

# ==============================================================================
# STATISTICAL TEST HELPERS (INTERNAL)
# ==============================================================================

#' Prepare analytic sample for statistical testing
#' @keywords internal
prepare_analytic_sample <- function(values1, values2, weights1, weights2) {
  # Filter to valid observations
  valid1 <- !is.na(values1) & !is.na(weights1) & is.finite(weights1) & weights1 > 0
  valid2 <- !is.na(values2) & !is.na(weights2) & is.finite(weights2) & weights2 > 0

  return(list(
    values1 = values1[valid1],
    weights1 = weights1[valid1],
    values2 = values2[valid2],
    weights2 = weights2[valid2]
  ))
}

#' Calculate t-test statistics
#' @keywords internal
calculate_t_test_stats <- function(mean1, mean2, var1, var2, eff_n1, eff_n2) {
  # Standard error
  se <- sqrt(var1/eff_n1 + var2/eff_n2)

  if (se == 0 || is.na(se)) {
    return(list(
      p_value = 1,
      higher = (mean1 > mean2),
      failed = FALSE
    ))
  }

  # T-statistic
  t_stat <- (mean1 - mean2) / se

  # Degrees of freedom (Welch-Satterthwaite approximation)
  df <- (var1/eff_n1 + var2/eff_n2)^2 /
        ((var1/eff_n1)^2/(eff_n1-1) + (var2/eff_n2)^2/(eff_n2-1))

  if (is.na(df) || df <= 0) {
    return(list(
      p_value = NA_real_,
      higher = (mean1 > mean2),
      failed = TRUE
    ))
  }

  # P-value
  p_value <- 2 * pt(-abs(t_stat), df)

  return(list(
    p_value = p_value,
    higher = (mean1 > mean2),
    failed = FALSE
  ))
}

#' T-test for weighted means (V9.9.4: Parameter validation added)
#'
#' SIGNATURE (V9.9.1):
#' - Accepts: values1, values2, weights1, weights2, min_base, alpha
#' - Computes effective-n internally (not passed in)
#'
#' V9.9.2 FIX:
#' - Effective-n now computed on ANALYTIC SAMPLE (after filtering NAs)
#'
#' V9.9.3 FIX:
#' - Length mismatches now error (fail fast)
#'
#' V9.9.4 PARAMETER VALIDATION:
#' - alpha must be in (0, 1)
#' - min_base must be ≥ 1
#'
#' STATISTICAL METHODOLOGY:
#' - Uses weighted_variance() for population variance
#' - Uses effective-n for degrees of freedom and SE
#' - Welch-Satterthwaite approximation for unequal variances
#'
#' @param values1 Numeric vector, values for group 1
#' @param values2 Numeric vector, values for group 2
#' @param weights1 Numeric vector, weights for group 1 (NULL = unweighted)
#' @param weights2 Numeric vector, weights for group 2 (NULL = unweighted)
#' @param min_base Integer, minimum base size for testing (default: 30)
#' @param alpha Numeric, significance level (default: 0.05)
#' @return List with $significant (logical), $p_value (numeric), $higher (logical)
#' @export
weighted_t_test_means <- function(values1, values2,
                                 weights1 = NULL, weights2 = NULL,
                                 min_base = 30,
                                 alpha = 0.05) {
  # V9.9.4: Parameter validation
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Alpha Parameter",
      problem = "alpha must be a single numeric value between 0 and 1.",
      why_it_matters = "Alpha defines the significance level for statistical tests.",
      how_to_fix = "Set alpha to a value between 0 and 1 (typically 0.05 or 0.01)"
    )
  }

  if (!is.numeric(min_base) || length(min_base) != 1 || min_base < 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid min_base Parameter",
      problem = "min_base must be a single numeric value >= 1.",
      why_it_matters = "min_base defines the minimum sample size required for statistical testing.",
      how_to_fix = "Set min_base to a positive integer (typically 30 or more)"
    )
  }

  # Default to unit weights if not provided
  if (is.null(weights1)) weights1 <- rep(1, length(values1))
  if (is.null(weights2)) weights2 <- rep(1, length(values2))

  # V9.9.3: Validate lengths
  if (length(values1) != length(weights1)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Values1 and Weights1 Length Mismatch",
      problem = sprintf("values1 (%d) and weights1 (%d) have different lengths.", length(values1), length(weights1)),
      why_it_matters = "Each value must have a corresponding weight for t-test calculation.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  if (length(values2) != length(weights2)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Values2 and Weights2 Length Mismatch",
      problem = sprintf("values2 (%d) and weights2 (%d) have different lengths.", length(values2), length(weights2)),
      why_it_matters = "Each value must have a corresponding weight for t-test calculation.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  # Prepare analytic sample (delegated to helper)
  sample <- prepare_analytic_sample(values1, values2, weights1, weights2)
  values1 <- sample$values1
  weights1 <- sample$weights1
  values2 <- sample$values2
  weights2 <- sample$weights2

  # Calculate effective sample sizes
  eff_n1 <- calculate_effective_n(weights1)
  eff_n2 <- calculate_effective_n(weights2)

  # Check minimum base size
  if (eff_n1 < min_base || eff_n2 < min_base) {
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  }

  tryCatch({
    # Calculate weighted means and variances
    mean1 <- calculate_weighted_mean(values1, weights1)
    mean2 <- calculate_weighted_mean(values2, weights2)

    if (is.na(mean1) || is.na(mean2)) {
      return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
    }

    var1 <- weighted_variance(values1, weights1)
    var2 <- weighted_variance(values2, weights2)

    # Calculate t-test statistics (delegated to helper)
    test_result <- calculate_t_test_stats(mean1, mean2, var1, var2, eff_n1, eff_n2)

    if (test_result$failed) {
      return(list(significant = FALSE, p_value = test_result$p_value, higher = test_result$higher))
    }

    return(list(
      significant = (!is.na(test_result$p_value) && test_result$p_value < alpha),
      p_value = test_result$p_value,
      higher = test_result$higher
    ))

  }, error = function(e) {
    warning(sprintf("T-test failed: %s", conditionMessage(e)), call. = FALSE)
    return(list(significant = FALSE, p_value = NA_real_, higher = FALSE))
  })
}

# ==============================================================================
# END OF WEIGHTING_TESTS.R V10.0
# ==============================================================================
