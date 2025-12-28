# ==============================================================================
# STATISTICAL VALIDATORS MODULE
# ==============================================================================
# Module name: statistical_validators
# Purpose: Validation for statistical test preconditions and results
# Extracted from validation.R for better modularity
# VERSION HISTORY: V10.1 - Extracted from validation.R (2025)

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Source shared functions
if (!exists("log_issue")) {
  script_dir <- dirname(sys.frame(1)$ofile)
  if (is.null(script_dir) || is.na(script_dir)) script_dir <- getwd()
  source(file.path(dirname(script_dir), "shared_functions.R"), local = FALSE)
}

# ==============================================================================
# CHI-SQUARE TEST VALIDATION
# ==============================================================================

#' Validate Chi-Square Test Preconditions
#'
#' Checks if chi-square test assumptions are met:
#' - All expected frequencies >= 1
#' - No more than 20% of cells with expected frequency < 5 (Cochran's rule)
#' - Adequate sample size
#'
#' @param observed Matrix or data frame of observed frequencies
#' @param min_expected Numeric. Minimum expected frequency (default: 5)
#' @param max_low_expected_pct Numeric. Maximum % of cells < min_expected (default: 0.20)
#' @param min_total Numeric. Minimum total sample size (default: 30)
#' @param verbose Logical. Print diagnostic messages (default: FALSE)
#' @return List with $valid (logical), $message (character), $diagnostics (list)
#' @export
#'
#' @examples
#' if (!result$valid) warning(result$message)
validate_chi_square_preconditions <- function(observed,
                                               min_expected = 5,
                                               max_low_expected_pct = 0.20,
                                               min_total = 30,
                                               verbose = FALSE) {
  # Input validation
  if (!is.matrix(observed) && !is.data.frame(observed)) {
    return(list(
      valid = FALSE,
      message = "observed must be a matrix or data frame",
      diagnostics = NULL
    ))
  }

  observed <- as.matrix(observed)

  # Check for negative values
  if (any(observed < 0, na.rm = TRUE)) {
    return(list(
      valid = FALSE,
      message = "observed frequencies cannot be negative",
      diagnostics = NULL
    ))
  }

  # Calculate expected frequencies under independence
  row_totals <- rowSums(observed, na.rm = TRUE)
  col_totals <- colSums(observed, na.rm = TRUE)
  grand_total <- sum(observed, na.rm = TRUE)

  # Check minimum sample size
  if (grand_total < min_total) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Total sample size (%d) below minimum (%d) for chi-square test",
        grand_total, min_total
      ),
      diagnostics = list(
        grand_total = grand_total,
        min_required = min_total
      )
    ))
  }

  # Check for zero marginals (would cause division by zero)
  if (any(row_totals == 0) || any(col_totals == 0)) {
    return(list(
      valid = FALSE,
      message = "Chi-square test invalid: one or more rows/columns have zero total",
      diagnostics = list(
        zero_rows = sum(row_totals == 0),
        zero_cols = sum(col_totals == 0)
      )
    ))
  }

  # Calculate expected frequencies
  expected <- outer(row_totals, col_totals) / grand_total

  # Count cells with low expected frequency
  n_cells <- length(expected)
  n_low_expected <- sum(expected < min_expected)
  pct_low_expected <- n_low_expected / n_cells

  # Check if any expected frequency is zero
  if (any(expected == 0)) {
    return(list(
      valid = FALSE,
      message = "Chi-square test invalid: expected frequency is zero for some cells",
      diagnostics = list(
        n_zero_expected = sum(expected == 0)
      )
    ))
  }

  # Check minimum expected frequency rule
  min_exp_value <- min(expected)

  diagnostics <- list(
    grand_total = grand_total,
    n_cells = n_cells,
    n_low_expected = n_low_expected,
    pct_low_expected = pct_low_expected,
    min_expected_value = min_exp_value,
    expected_matrix = expected
  )

  # Cochran's rule: no more than 20% of cells should have expected < 5
  if (pct_low_expected > max_low_expected_pct) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Chi-square test may be unreliable: %.1f%% of cells have expected frequency < %d (max allowed: %.0f%%)",
        pct_low_expected * 100, min_expected, max_low_expected_pct * 100
      ),
      diagnostics = diagnostics
    ))
  }

  # Additional warning for very small expected values
  if (min_exp_value < 1) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Chi-square test unreliable: minimum expected frequency (%.2f) is less than 1",
        min_exp_value
      ),
      diagnostics = diagnostics
    ))
  }

  if (verbose) {
    cat(sprintf("Chi-square preconditions met: n=%d, min_expected=%.2f, low_expected_pct=%.1f%%\n",
                grand_total, min_exp_value, pct_low_expected * 100))
  }

  return(list(
    valid = TRUE,
    message = "Chi-square test preconditions met",
    diagnostics = diagnostics
  ))
}


# ------------------------------------------------------------------------------
# Z-TEST / PROPORTION TEST VALIDATION
# ------------------------------------------------------------------------------

#' Validate Z-Test for Proportions Preconditions
#'
#' Checks if z-test for proportions assumptions are met:
#' - Normal approximation valid (np >= 10 and n(1-p) >= 10)
#' - Minimum sample size
#' - Valid proportion range (0-1)
#'
#' @param n Integer. Sample size
#' @param p Numeric. Observed proportion (0-1)
#' @param min_np Numeric. Minimum for n*p and n*(1-p) (default: 10)
#' @param min_n Numeric. Minimum sample size (default: 30)
#' @param verbose Logical. Print diagnostic messages (default: FALSE)
#' @return List with $valid (logical), $message (character), $diagnostics (list)
#' @export
#'
#' @examples
#' result <- validate_z_test_preconditions(n = 100, p = 0.25)
#' if (!result$valid) warning(result$message)
validate_z_test_preconditions <- function(n,
                                           p,
                                           min_np = 10,
                                           min_n = 30,
                                           verbose = FALSE) {
  # Input validation
  if (!is.numeric(n) || length(n) != 1 || is.na(n)) {
    return(list(
      valid = FALSE,
      message = "n must be a single numeric value",
      diagnostics = NULL
    ))
  }

  if (!is.numeric(p) || length(p) != 1 || is.na(p)) {
    return(list(
      valid = FALSE,
      message = "p must be a single numeric value",
      diagnostics = NULL
    ))
  }

  # Check proportion range
  if (p < 0 || p > 1) {
    return(list(
      valid = FALSE,
      message = sprintf("Proportion p (%.4f) must be between 0 and 1", p),
      diagnostics = list(n = n, p = p)
    ))
  }

  # Check sample size
  if (n < min_n) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Sample size (%d) below minimum (%d) for z-test",
        n, min_n
      ),
      diagnostics = list(n = n, p = p, min_n = min_n)
    ))
  }

  # Calculate np and n(1-p)
  np <- n * p
  nq <- n * (1 - p)

  diagnostics <- list(
    n = n,
    p = p,
    np = np,
    nq = nq,
    min_np = min_np
  )

  # Check normal approximation conditions
  if (np < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid: n*p = %.1f < %d. Consider exact binomial test.",
        np, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Use exact binomial test instead"
    ))
  }

  if (nq < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid: n*(1-p) = %.1f < %d. Consider exact binomial test.",
        nq, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Use exact binomial test instead"
    ))
  }

  if (verbose) {
    cat(sprintf("Z-test preconditions met: n=%d, p=%.3f, np=%.1f, nq=%.1f\n",
                n, p, np, nq))
  }

  return(list(
    valid = TRUE,
    message = "Z-test preconditions met",
    diagnostics = diagnostics
  ))
}


# ------------------------------------------------------------------------------
# COLUMN PROPORTION COMPARISON VALIDATION
# ------------------------------------------------------------------------------

#' Validate Column Proportion Comparison Preconditions
#'
#' Checks if two-sample proportion test assumptions are met:
#' - Both samples have adequate size
#' - Normal approximation valid for both proportions
#' - Proportions are meaningfully different from 0 or 1
#'
#' @param n1 Integer. Sample size for group 1
#' @param p1 Numeric. Proportion for group 1
#' @param n2 Integer. Sample size for group 2
#' @param p2 Numeric. Proportion for group 2
#' @param min_n Numeric. Minimum sample size per group (default: 30)
#' @param min_np Numeric. Minimum for n*p and n*(1-p) per group (default: 5)
#' @param verbose Logical. Print diagnostic messages (default: FALSE)
#' @return List with $valid (logical), $message (character), $diagnostics (list)
#' @export
#'
#' @examples
#' result <- validate_column_comparison_preconditions(
#'   n1 = 100, p1 = 0.45,
#'   n2 = 120, p2 = 0.35
#' )
validate_column_comparison_preconditions <- function(n1, p1, n2, p2,
                                                      min_n = 30,
                                                      min_np = 5,
                                                      verbose = FALSE) {
  # Input validation
  if (!is.numeric(n1) || !is.numeric(n2) || !is.numeric(p1) || !is.numeric(p2)) {
    return(list(
      valid = FALSE,
      message = "All inputs must be numeric",
      diagnostics = NULL
    ))
  }

  # Check proportion ranges
  if (p1 < 0 || p1 > 1 || p2 < 0 || p2 > 1) {
    return(list(
      valid = FALSE,
      message = "Proportions must be between 0 and 1",
      diagnostics = list(p1 = p1, p2 = p2)
    ))
  }

  # Check sample sizes
  if (n1 < min_n || n2 < min_n) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Sample sizes (n1=%d, n2=%d) below minimum (%d) for reliable comparison",
        n1, n2, min_n
      ),
      diagnostics = list(n1 = n1, n2 = n2, min_n = min_n)
    ))
  }

  # Calculate np and nq for both groups
  np1 <- n1 * p1
  nq1 <- n1 * (1 - p1)
  np2 <- n2 * p2
  nq2 <- n2 * (1 - p2)

  diagnostics <- list(
    n1 = n1, p1 = p1, np1 = np1, nq1 = nq1,
    n2 = n2, p2 = p2, np2 = np2, nq2 = nq2,
    min_np = min_np
  )

  # Check normal approximation for group 1
  if (np1 < min_np || nq1 < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid for group 1: np1=%.1f, nq1=%.1f (min: %d)",
        np1, nq1, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Consider Fisher's exact test or increase sample size"
    ))
  }

  # Check normal approximation for group 2
  if (np2 < min_np || nq2 < min_np) {
    return(list(
      valid = FALSE,
      message = sprintf(
        "Normal approximation invalid for group 2: np2=%.1f, nq2=%.1f (min: %d)",
        np2, nq2, min_np
      ),
      diagnostics = diagnostics,
      recommendation = "Consider Fisher's exact test or increase sample size"
    ))
  }

  # Check for extreme proportions (may cause instability)
  extreme_threshold <- 0.01
  if (p1 < extreme_threshold || p1 > (1 - extreme_threshold) ||
      p2 < extreme_threshold || p2 > (1 - extreme_threshold)) {
    diagnostics$warning <- "One or more proportions are extreme (<1% or >99%)"
  }

  if (verbose) {
    cat(sprintf("Column comparison preconditions met: n1=%d, n2=%d, p1=%.3f, p2=%.3f\n",
                n1, n2, p1, p2))
  }

  return(list(
    valid = TRUE,
    message = "Column comparison preconditions met",
    diagnostics = diagnostics
  ))
}


# ------------------------------------------------------------------------------
# SIGNIFICANCE TEST RESULT VALIDATION
# ------------------------------------------------------------------------------

#' Validate Significance Test Result
#'
#' Validates the output of a significance test for data quality issues:
#' - P-value in valid range [0, 1]
#' - Test statistic is finite
#' - Degrees of freedom are positive (if applicable)
#' - Effect size is within expected bounds
#'
#' @param p_value Numeric. P-value from the test
#' @param test_statistic Numeric. Test statistic (chi-square, z, t, etc.)
#' @param df Numeric. Degrees of freedom (optional, for chi-square/t tests)
#' @param effect_size Numeric. Effect size (optional, e.g., Cramér's V, Cohen's d)
#' @param test_type Character. Type of test for validation rules
#' @return List with $valid (logical), $message (character), $warnings (character vector)
#' @export
#'
#' @examples
#' result <- validate_significance_result(
#'   p_value = 0.023,
#'   test_statistic = 12.45,
#'   df = 4,
#'   test_type = "chi_square"
#' )
validate_significance_result <- function(p_value,
                                          test_statistic = NULL,
                                          df = NULL,
                                          effect_size = NULL,
                                          test_type = c("chi_square", "z_test", "t_test", "proportion")) {

  test_type <- match.arg(test_type)
  warnings <- character(0)

  # Validate p-value
  if (is.null(p_value) || is.na(p_value)) {
    return(list(
      valid = FALSE,
      message = "P-value is missing (NULL or NA)",
      warnings = warnings
    ))
  }

  if (!is.numeric(p_value)) {
    return(list(
      valid = FALSE,
      message = sprintf("P-value must be numeric, got: %s", class(p_value)[1]),
      warnings = warnings
    ))
  }

  if (p_value < 0 || p_value > 1) {
    return(list(
      valid = FALSE,
      message = sprintf("P-value (%.6f) outside valid range [0, 1]", p_value),
      warnings = warnings
    ))
  }

  # Validate test statistic
  if (!is.null(test_statistic)) {
    if (!is.finite(test_statistic)) {
      return(list(
        valid = FALSE,
        message = sprintf("Test statistic is not finite: %s", test_statistic),
        warnings = warnings
      ))
    }

    # Chi-square and F statistics must be non-negative
    if (test_type %in% c("chi_square") && test_statistic < 0) {
      return(list(
        valid = FALSE,
        message = sprintf("Chi-square statistic (%.4f) cannot be negative", test_statistic),
        warnings = warnings
      ))
    }
  }

  # Validate degrees of freedom
  if (!is.null(df)) {
    if (!is.finite(df) || df <= 0) {
      return(list(
        valid = FALSE,
        message = sprintf("Degrees of freedom (%.2f) must be positive and finite", df),
        warnings = warnings
      ))
    }

    # Check for suspiciously small df
    if (df < 1 && test_type %in% c("chi_square", "t_test")) {
      warnings <- c(warnings, sprintf(
        "Very small degrees of freedom (%.2f) may indicate insufficient data",
        df
      ))
    }
  }

  # Validate effect size
  if (!is.null(effect_size)) {
    if (!is.finite(effect_size)) {
      warnings <- c(warnings, "Effect size is not finite - interpret with caution")
    } else {
      # Cramér's V should be in [0, 1]
      if (test_type == "chi_square" && (effect_size < 0 || effect_size > 1)) {
        warnings <- c(warnings, sprintf(
          "Cramér's V (%.4f) outside expected range [0, 1]",
          effect_size
        ))
      }

      # Cohen's d typically |d| < 5 for realistic effects
      if (test_type == "t_test" && abs(effect_size) > 5) {
        warnings <- c(warnings, sprintf(
          "Unusually large effect size (d = %.2f) - verify data quality",
          effect_size
        ))
      }
    }
  }

  # Check for suspiciously small p-values (potential numerical issues)
  if (p_value < 1e-15) {
    warnings <- c(warnings, sprintf(
      "Extremely small p-value (%.2e) may indicate numerical precision issues",
      p_value
    ))
  }

  # Check for p-value exactly 0 or 1 (usually indicates edge case)
  if (p_value == 0) {
    warnings <- c(warnings, "P-value is exactly 0 - may indicate extreme test statistic or calculation issue")
  }

  if (p_value == 1) {
    warnings <- c(warnings, "P-value is exactly 1 - may indicate no variation or calculation issue")
  }

  return(list(
    valid = TRUE,
    message = "Significance test result is valid",
    warnings = warnings
  ))
}


# ------------------------------------------------------------------------------
# BASE SIZE VALIDATION FOR SIGNIFICANCE TESTING
# ------------------------------------------------------------------------------

#' Validate Base Sizes for Significance Testing
#'
#' Checks if base sizes are adequate for reliable significance testing:
#' - Minimum base size per column
#' - Effective base size for weighted data
#' - Warning for highly variable base sizes
#'
#' @param base_sizes Numeric vector. Base sizes for each column
#' @param effective_bases Numeric vector. Effective base sizes (optional, for weighted data)
#' @param min_base Numeric. Minimum base size for testing (default: 30)
#' @param warn_ratio Numeric. Warn if max/min base ratio exceeds this (default: 10)
#' @param column_names Character vector. Column names for reporting (optional)
#' @return List with $valid (logical), $message (character), $details (list)
#' @export
validate_base_sizes_for_testing <- function(base_sizes,
                                             effective_bases = NULL,
                                             min_base = 30,
                                             warn_ratio = 10,
                                             column_names = NULL) {
  # Input validation
  if (!is.numeric(base_sizes) || length(base_sizes) == 0) {
    return(list(
      valid = FALSE,
      message = "base_sizes must be a non-empty numeric vector",
      details = NULL
    ))
  }

  # Check for non-positive base sizes
  if (any(base_sizes <= 0, na.rm = TRUE)) {
    zero_cols <- which(base_sizes <= 0)
    col_labels <- if (!is.null(column_names) && length(column_names) >= max(zero_cols)) {
      column_names[zero_cols]
    } else {
      paste("Column", zero_cols)
    }

    return(list(
      valid = FALSE,
      message = sprintf(
        "Zero or negative base sizes found in: %s",
        paste(col_labels, collapse = ", ")
      ),
      details = list(
        zero_base_columns = zero_cols,
        zero_base_labels = col_labels
      )
    ))
  }

  details <- list(
    base_sizes = base_sizes,
    n_columns = length(base_sizes),
    min_base_size = min(base_sizes, na.rm = TRUE),
    max_base_size = max(base_sizes, na.rm = TRUE)
  )

  # Check minimum base size
  below_min <- base_sizes < min_base
  if (any(below_min, na.rm = TRUE)) {
    low_cols <- which(below_min)
    col_labels <- if (!is.null(column_names) && length(column_names) >= max(low_cols)) {
      column_names[low_cols]
    } else {
      paste("Column", low_cols)
    }

    details$low_base_columns <- low_cols
    details$low_base_labels <- col_labels

    return(list(
      valid = FALSE,
      message = sprintf(
        "%d column(s) below minimum base size (%d): %s. Significance tests suppressed for these columns.",
        sum(below_min),
        min_base,
        paste(col_labels, collapse = ", ")
      ),
      details = details
    ))
  }

  # Check base size ratio
  base_ratio <- details$max_base_size / details$min_base_size
  details$base_ratio <- base_ratio

  warnings <- character(0)

  if (base_ratio > warn_ratio) {
    warnings <- c(warnings, sprintf(
      "Large base size variation (ratio %.1f:1). Comparison power may vary significantly.",
      base_ratio
    ))
  }

  # Check effective bases if provided
  if (!is.null(effective_bases)) {
    if (length(effective_bases) != length(base_sizes)) {
      warnings <- c(warnings, "effective_bases length doesn't match base_sizes - ignoring")
    } else {
      details$effective_bases <- effective_bases
      details$min_effective <- min(effective_bases, na.rm = TRUE)

      # Design effect warning
      deff <- base_sizes / effective_bases
      deff <- deff[is.finite(deff)]
      if (length(deff) > 0 && max(deff) > 2) {
        warnings <- c(warnings, sprintf(
          "High design effect detected (max deff = %.2f). Significance tests may be anti-conservative.",
          max(deff)
        ))
      }

      # Check effective base below minimum
      if (details$min_effective < min_base) {
        warnings <- c(warnings, sprintf(
          "Minimum effective base (%.1f) below threshold (%d) due to weighting.",
          details$min_effective, min_base
        ))
      }
    }
  }

  details$warnings <- warnings

  return(list(
    valid = TRUE,
    message = if (length(warnings) > 0) {
      paste("Base sizes adequate with warnings:", paste(warnings, collapse = "; "))
    } else {
      "Base sizes adequate for significance testing"
    },
    details = details
  ))
}
