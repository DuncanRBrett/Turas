# ==============================================================================
# WEIGHTING ADVANCED V10.0 - ADVANCED STATISTICAL TESTS MODULE
# ==============================================================================
# Functions for advanced statistical tests: chi-square and net difference tests
# Part of R Survey Analytics Toolkit
#
# MODULE PURPOSE:
# This module provides advanced statistical testing capabilities including
# chi-square tests for independence and net difference tests for Box2 categories.
# These are specialized tests used in specific survey analysis scenarios.
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - EXTRACTED: From weighting.R V9.9.4 (~270 lines)
#         - MAINTAINED: All V9.9.4 advanced testing logic
#         - NO CHANGES: Function signatures and behavior identical
# V9.9.5 - NEW FEATURES: Chi-square test, net difference testing
#
# STATISTICAL METHODOLOGY:
# Chi-square test:
#   - Pearson's chi-square test: χ² = Σ(O - E)² / E
#   - Expected frequencies: E[i,j] = (row_total[i] × col_total[j]) / grand_total
#   - Warnings when >20% of cells have expected frequency <5
#
# Net difference test:
#   - Compares two proportions (nets) across banner columns
#   - Uses z-tests for each net independently
#   - Returns significance letters for both nets
#
# EXPORTED FUNCTIONS:
# - chi_square_test(): Chi-square test for independence
# - run_net_difference_tests(): Net difference significance test
#
# INTERNAL FUNCTIONS:
# - prepare_chi_square_matrix(): Clean and prepare matrix
# - validate_chi_square_matrix(): Validate matrix dimensions and values
# - calculate_expected_frequencies(): Compute expected frequencies
# - check_expected_frequencies(): Check validity and create warnings
# - create_chi_square_failure(): Create failure result object
# ==============================================================================

WEIGHTING_ADVANCED_VERSION <- "10.0"

# ==============================================================================
# CHI-SQUARE TEST (V9.9.5: NEW FEATURE)
# ==============================================================================

# ==============================================================================
# CHI-SQUARE HELPERS (INTERNAL)
# ==============================================================================

#' Prepare and clean observed matrix for chi-square test
#' @keywords internal
prepare_chi_square_matrix <- function(observed_matrix) {
  # Convert to numeric matrix
  if (is.data.frame(observed_matrix)) {
    observed_matrix <- as.matrix(observed_matrix)
  }
  storage.mode(observed_matrix) <- "double"

  # Remove rows/cols that are all zero
  row_sums <- rowSums(observed_matrix, na.rm = TRUE)
  col_sums <- colSums(observed_matrix, na.rm = TRUE)

  observed_matrix <- observed_matrix[row_sums > 0, , drop = FALSE]
  observed_matrix <- observed_matrix[, col_sums > 0, drop = FALSE]

  return(observed_matrix)
}

#' Validate chi-square matrix for testing
#' @keywords internal
validate_chi_square_matrix <- function(observed_matrix) {
  # Check dimensions
  if (nrow(observed_matrix) < 2 || ncol(observed_matrix) < 2) {
    return(list(valid = FALSE, warning = "Insufficient dimensions (need at least 2×2 table)"))
  }

  # Check for NA values
  if (any(is.na(observed_matrix))) {
    return(list(valid = FALSE, warning = "Matrix contains NA values"))
  }

  # Check for negative values
  if (any(observed_matrix < 0)) {
    return(list(valid = FALSE, warning = "Matrix contains negative values"))
  }

  return(list(valid = TRUE))
}

#' Calculate expected frequencies for chi-square test
#' @keywords internal
calculate_expected_frequencies <- function(observed_matrix) {
  row_totals <- rowSums(observed_matrix)
  col_totals <- colSums(observed_matrix)
  grand_total <- sum(observed_matrix)

  if (grand_total == 0) {
    return(NULL)
  }

  expected_matrix <- outer(row_totals, col_totals) / grand_total
  return(expected_matrix)
}

#' Check expected frequencies and create warning message
#' @keywords internal
check_expected_frequencies <- function(expected_matrix, min_expected) {
  min_exp <- min(expected_matrix)
  low_expected_count <- sum(expected_matrix < min_expected)
  low_expected_pct <- 100 * low_expected_count / length(expected_matrix)

  warning_msg <- NULL
  if (min_exp < 1) {
    warning_msg <- "Some expected frequencies <1 (chi-square may be unreliable)"
  } else if (low_expected_pct > 20) {
    warning_msg <- sprintf("%.0f%% of cells have expected frequency <%d (chi-square assumptions violated)",
                          low_expected_pct, min_expected)
  }

  return(warning_msg)
}

#' Create chi-square test failure result
#' @keywords internal
create_chi_square_failure <- function(warning_msg, chi_sq = NA_real_, df = NA_integer_) {
  return(list(
    significant = FALSE,
    p_value = NA_real_,
    chi_square_stat = chi_sq,
    df = df,
    warning = warning_msg
  ))
}

#' Chi-square test for independence
#'
#' Tests independence between row variable and column variable.
#' Uses Pearson's chi-square test with continuity correction for 2x2 tables.
#'
#' STATISTICAL METHODOLOGY:
#' - Pearson's chi-square test: χ² = Σ(O - E)² / E
#' - Expected frequencies: E[i,j] = (row_total[i] × col_total[j]) / grand_total
#' - Warnings when >20% of cells have expected frequency <5
#'
#' V9.9.5: NEW FEATURE (standard industry expectation)
#'
#' @param observed_matrix Matrix of observed counts (rows × columns)
#' @param min_expected Integer, minimum expected cell count for warning (default: 5)
#' @param alpha Numeric, significance level (default: 0.05)
#' @return List with $significant, $p_value, $chi_square_stat, $df, $warning
#' @export
#' @examples
#' # Test independence between satisfaction and gender
#' obs <- matrix(c(45, 30, 25, 50), nrow=2)
#' result <- chi_square_test(obs)
chi_square_test <- function(observed_matrix, min_expected = 5, alpha = 0.05) {
  # Parameter validation
  if (!is.matrix(observed_matrix) && !is.data.frame(observed_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid observed_matrix Type",
      problem = "observed_matrix must be a matrix or data.frame.",
      why_it_matters = "Chi-square test requires a matrix of observed counts.",
      how_to_fix = "This is an internal error - check function call"
    )
  }

  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Alpha Parameter",
      problem = "alpha must be between 0 and 1.",
      why_it_matters = "Alpha defines the significance level for the chi-square test.",
      how_to_fix = "Set alpha to a value between 0 and 1 (typically 0.05 or 0.01)"
    )
  }

  if (!is.numeric(min_expected) || length(min_expected) != 1 || min_expected < 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid min_expected Parameter",
      problem = "min_expected must be a positive number.",
      why_it_matters = "min_expected defines the threshold for chi-square validity warnings.",
      how_to_fix = "Set min_expected to a positive value (typically 5)"
    )
  }

  # Prepare and clean matrix (delegated to helper)
  observed_matrix <- prepare_chi_square_matrix(observed_matrix)

  # Validate matrix (delegated to helper)
  validation <- validate_chi_square_matrix(observed_matrix)
  if (!validation$valid) {
    return(create_chi_square_failure(validation$warning))
  }

  # Compute chi-square test
  tryCatch({
    # Calculate expected frequencies (delegated to helper)
    expected_matrix <- calculate_expected_frequencies(observed_matrix)

    if (is.null(expected_matrix)) {
      return(create_chi_square_failure("Matrix sum is zero"))
    }

    # Check expected frequencies (delegated to helper)
    warning_msg <- check_expected_frequencies(expected_matrix, min_expected)

    # Compute chi-square statistic
    chi_sq <- sum((observed_matrix - expected_matrix)^2 / expected_matrix)

    # Degrees of freedom
    df <- (nrow(observed_matrix) - 1) * (ncol(observed_matrix) - 1)

    if (df <= 0) {
      return(create_chi_square_failure("Invalid degrees of freedom", chi_sq, df))
    }

    # P-value
    p_value <- pchisq(chi_sq, df, lower.tail = FALSE)

    return(list(
      significant = (!is.na(p_value) && p_value < alpha),
      p_value = p_value,
      chi_square_stat = chi_sq,
      df = df,
      warning = warning_msg
    ))

  }, error = function(e) {
    return(create_chi_square_failure(sprintf("Chi-square test failed: %s", conditionMessage(e))))
  })
}

# ==============================================================================
# NET DIFFERENCE TESTING (V9.9.5: NEW FEATURE)
# ==============================================================================

#' Net difference significance test
#'
#' Tests if difference between two proportions (nets) is significant.
#' Used for testing BoxCategory rollups (e.g., Satisfied vs Dissatisfied).
#'
#' METHODOLOGY:
#' - Compares net1 across banner columns using z-tests
#' - Compares net2 across banner columns using z-tests
#' - Returns significance letters for both nets
#'
#' V9.9.5: NEW FEATURE (net difference testing)
#'
#' @param test_data List with count1, count2, base, eff_n for each column
#' @param banner_info Banner structure metadata
#' @param internal_keys Character vector of column keys
#' @param alpha Numeric, significance level (default: 0.05)
#' @param bonferroni_correction Logical, apply Bonferroni correction
#' @param min_base Integer, minimum base for testing
#' @param is_weighted Logical, whether data is weighted
#' @return List with $net1 and $net2 sig results, or NULL if insufficient data
#' @export
run_net_difference_tests <- function(test_data, banner_info, internal_keys,
                                    alpha = 0.05,
                                    bonferroni_correction = TRUE,
                                    min_base = 30,
                                    is_weighted = FALSE) {
  # Validation
  if (is.null(test_data) || length(test_data) < 2) return(NULL)
  if (is.null(banner_info) || is.null(internal_keys)) return(NULL)

  # Calculate number of comparisons for Bonferroni
  num_comparisons <- choose(length(test_data), 2)
  if (num_comparisons == 0) return(NULL)

  alpha_adj <- alpha
  if (bonferroni_correction && num_comparisons > 0) {
    alpha_adj <- alpha / num_comparisons
  }

  # Initialize results for both nets
  net1_sig <- setNames(rep("", length(internal_keys)), internal_keys)
  net2_sig <- setNames(rep("", length(internal_keys)), internal_keys)

  # Total column gets "-"
  total_key <- paste0("TOTAL::", "Total")
  if (total_key %in% names(net1_sig)) {
    net1_sig[total_key] <- "-"
    net2_sig[total_key] <- "-"
  }

  # Test each banner question separately
  for (banner_code in names(banner_info$banner_info)) {
    banner_cols <- banner_info$banner_info[[banner_code]]$internal_keys
    banner_letters <- banner_info$banner_info[[banner_code]]$letters

    # Test each column against others in same banner
    for (i in seq_along(banner_cols)) {
      col_i <- banner_cols[i]
      data_i <- test_data[[col_i]]

      if (is.null(data_i)) next

      higher_than_letters <- character(0)
      higher_than_letters_net2 <- character(0)

      for (j in seq_along(banner_cols)) {
        if (i == j) next

        col_j <- banner_cols[j]
        data_j <- test_data[[col_j]]

        if (is.null(data_j)) next

        # Test net1: col_i vs col_j
        test_result_net1 <- weighted_z_test_proportions(
          data_i$count1, data_i$base,
          data_j$count1, data_j$base,
          data_i$eff_n, data_j$eff_n,
          is_weighted = is_weighted,
          min_base = min_base,
          alpha = alpha_adj
        )

        if (test_result_net1$significant && test_result_net1$higher) {
          letter <- banner_letters[j]
          if (length(letter) > 0 && letter != "-") {
            higher_than_letters <- c(higher_than_letters, letter)
          }
        }

        # Test net2: col_i vs col_j
        test_result_net2 <- weighted_z_test_proportions(
          data_i$count2, data_i$base,
          data_j$count2, data_j$base,
          data_i$eff_n, data_j$eff_n,
          is_weighted = is_weighted,
          min_base = min_base,
          alpha = alpha_adj
        )

        if (test_result_net2$significant && test_result_net2$higher) {
          letter <- banner_letters[j]
          if (length(letter) > 0 && letter != "-") {
            higher_than_letters_net2 <- c(higher_than_letters_net2, letter)
          }
        }
      }

      # Store results
      net1_sig[col_i] <- paste(higher_than_letters, collapse = "")
      net2_sig[col_i] <- paste(higher_than_letters_net2, collapse = "")
    }
  }

  return(list(
    net1 = net1_sig,
    net2 = net2_sig
  ))
}

# ==============================================================================
# END OF WEIGHTING_ADVANCED.R V10.0
# ==============================================================================
