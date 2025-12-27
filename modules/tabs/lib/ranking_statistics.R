# ==============================================================================
# RANKING STATISTICS V10.0
# ==============================================================================
# Extracted from ranking.R for improved maintainability
# Contains all ranking statistical comparison functions
#
# Part of R Survey Analytics Toolkit
# Module: Ranking - Statistics
#
# CONTENTS:
# - Mean rank comparison between groups
# - Weighted t-tests for mean ranks
# - Significance testing
# - Statistical helpers
#
# DEPENDENCIES:
# - shared_functions.R (for tabs_refuse error handling)
# - weighting.R (for weighted_t_test_means)
# - ranking_calculations.R (for calculate_mean_rank)
# ==============================================================================

# ==============================================================================
# STATISTICAL FUNCTIONS (V9.9.2: CONFIGURABLE MIN_BASE)
# ==============================================================================

# ==============================================================================
# MEAN RANK COMPARISON HELPERS (INTERNAL)
# ==============================================================================

#' Prepare rank data and weights for comparison
#' @keywords internal
prepare_rank_comparison_data <- function(ranking_matrix1, ranking_matrix2, item_name, weights1, weights2) {
  # Extract ranks
  ranks1 <- ranking_matrix1[, item_name]
  ranks2 <- ranking_matrix2[, item_name]

  # Default weights
  if (is.null(weights1)) weights1 <- rep(1, length(ranks1))
  if (is.null(weights2)) weights2 <- rep(1, length(ranks2))

  return(list(
    ranks1 = ranks1,
    ranks2 = ranks2,
    weights1 = weights1,
    weights2 = weights2
  ))
}

#' Run weighted or basic t-test for mean ranks
#' @keywords internal
run_mean_rank_test <- function(ranks1, ranks2, weights1, weights2, mean1, mean2, min_base, alpha) {
  # Use weighted_t_test_means if available (from weighting.R)
  if (exists("weighted_t_test_means", mode = "function")) {
    test_result <- weighted_t_test_means(
      ranks1, ranks2,
      weights1, weights2,
      min_base = min_base,
      alpha = alpha
    )

    return(list(
      significant = test_result$significant,
      p_value = test_result$p_value,
      mean1 = mean1,
      mean2 = mean2,
      better_group = if (mean1 < mean2) 1 else 2  # Lower mean = better rank
    ))
  } else {
    # Fallback: basic t-test (not weighted)
    test <- tryCatch({
      t.test(ranks1, ranks2, na.rm = TRUE)
    }, error = function(e) {
      # TRS v1.0: Record partial failure instead of silent NULL
      ranking_record_partial_failure(
        section = "Ranking Significance Test",
        stage = "t_test",
        error = conditionMessage(e)
      )
      message(sprintf("[TRS PARTIAL] Ranking significance test failed: %s", conditionMessage(e)))
      return(NULL)
    })

    if (is.null(test)) {
      return(list(
        significant = FALSE,
        p_value = NA_real_,
        mean1 = mean1,
        mean2 = mean2,
        better_group = if (mean1 < mean2) 1 else 2
      ))
    }

    return(list(
      significant = test$p.value < alpha,
      p_value = test$p.value,
      mean1 = mean1,
      mean2 = mean2,
      better_group = if (mean1 < mean2) 1 else 2
    ))
  }
}

#' Compare mean ranks between two groups with significance testing
#'
#' V9.9.2: Configurable min_base (from config)
#'
#' @param ranking_matrix1 Numeric matrix for group 1
#' @param ranking_matrix2 Numeric matrix for group 2
#' @param item_name Character, name of item to compare
#' @param weights1 Numeric vector, weights for group 1
#' @param weights2 Numeric vector, weights for group 2
#' @param alpha Numeric, significance level (default: 0.05)
#' @param min_base Integer, minimum base for testing (default: 10)
#' @return List with significant, p_value, mean1, mean2, better_group
#' @export
compare_mean_ranks <- function(ranking_matrix1, ranking_matrix2, item_name,
                              weights1 = NULL, weights2 = NULL,
                              alpha = 0.05, min_base = 10) {
  # Input validation
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: alpha",
      problem = sprintf("The alpha significance level must be between 0 and 1 (exclusive), got: %s", alpha),
      why_it_matters = "Alpha determines the significance threshold for statistical tests (typically 0.05).",
      how_to_fix = "Provide a value between 0 and 1 for alpha (e.g., 0.05 for 95% confidence)"
    )
  }

  if (!is.numeric(min_base) || length(min_base) != 1 || min_base < 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: min_base",
      problem = sprintf("The min_base must be a positive integer, got: %s",
                       paste(min_base, collapse = ", ")),
      why_it_matters = "Minimum base size ensures sufficient sample for reliable significance testing.",
      how_to_fix = "Provide a positive integer for min_base (e.g., 10 or 30)"
    )
  }

  # Calculate means
  mean1 <- calculate_mean_rank(ranking_matrix1, item_name, weights1)
  mean2 <- calculate_mean_rank(ranking_matrix2, item_name, weights2)

  if (is.na(mean1) || is.na(mean2)) {
    return(list(
      significant = FALSE,
      p_value = NA_real_,
      mean1 = mean1,
      mean2 = mean2,
      better_group = NA_integer_
    ))
  }

  # Prepare rank data and weights (delegated to helper)
  data <- prepare_rank_comparison_data(ranking_matrix1, ranking_matrix2, item_name, weights1, weights2)

  # Run significance test (delegated to helper)
  run_mean_rank_test(data$ranks1, data$ranks2, data$weights1, data$weights2, mean1, mean2, min_base, alpha)
}

# ==============================================================================
# END OF RANKING_STATISTICS.R V10.0
# ==============================================================================
