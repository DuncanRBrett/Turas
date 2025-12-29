# ==============================================================================
# RANKING METRICS - V10.1 (Phase 2 Refactoring)
# ==============================================================================
# Metric calculation functions for ranking questions
# Extracted from ranking.R for better modularity
#
# VERSION HISTORY:
# V10.1 - Extracted from ranking.R (2025-12-29)
#        - Uses tabs_source() for reliable subdirectory loading
#        - All ranking metric calculation functions
#        - Mean rank comparison functions
#
# DEPENDENCIES (must be loaded before this file):
# - tabs_refuse() from 00_guard.R
# - calculate_effective_n() from weighting.R
# - calculate_weighted_mean() from weighting.R
# - weighted_variance() from weighting.R (optional)
# - weighted_t_test_means() from weighting.R (optional)
# - ranking_record_partial_failure() from ranking.R
#
# USAGE:
# These functions are sourced by ranking.R using:
#   tabs_source("ranking", "ranking_metrics.R")
#
# FUNCTIONS EXPORTED:
# - calculate_percent_ranked_first() - % who ranked item first
# - calculate_percent_top_n() - % who ranked item in top N
# - calculate_mean_rank() - Mean rank for item
# - calculate_rank_variance() - Variance of ranks for item
# - compare_mean_ranks() - Compare mean ranks between groups
# ==============================================================================

# ==============================================================================
# RANKING METRICS (V9.9.2: RETURN SHAPE PARITY & TOP_N GUARD)
# ==============================================================================

#' Calculate percentage who ranked item first
#'
#' V9.9.2: Removed weights from return (shape parity with top_n)
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, name of item (must be in colnames)
#' @param weights Numeric vector, weights (NULL = unweighted)
#' @return List with count, base, percentage, effective_n
#' @export
calculate_percent_ranked_first <- function(ranking_matrix, item_name, weights = NULL) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Calculating percent ranked first requires a matrix structure to identify rank values.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.character(item_name) || length(item_name) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: item_name",
      problem = sprintf("The item_name argument must be a single character string, got: %s",
                       class(item_name)),
      why_it_matters = "Item name is required to identify which ranking column to calculate first place percentage for.",
      how_to_fix = "Provide a single character string for item_name matching a column in ranking_matrix"
    )
  }

  if (!item_name %in% colnames(ranking_matrix)) {
    # TRS v1.0: Ranking item not found is a configuration/data mismatch
    tabs_refuse(
      code = "DATA_RANKING_ITEM_NOT_FOUND",
      title = paste0("Ranking Item Missing: ", item_name),
      problem = paste0("Ranking item '", item_name, "' is not found in the ranking matrix for calculate_percent_ranked_first."),
      why_it_matters = "Cannot calculate 'percent ranked first' for a missing item. Results would be incomplete.",
      how_to_fix = c(
        "Check that the ranking item exists in the data",
        "Verify the item name matches the column name in data exactly"
      ),
      missing = item_name
    )
  }

  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]

  # Default weights
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }

  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Argument Length Mismatch: weights",
      problem = sprintf("The weights length (%d) must match ranking_matrix rows (%d).",
                       length(weights), length(item_ranks)),
      why_it_matters = "Each respondent row requires exactly one weight value for weighted first place calculations.",
      how_to_fix = "Provide a weights vector with the same length as the number of rows in ranking_matrix"
    )
  }

  # Identify respondents who ranked this item first
  ranked_first <- !is.na(item_ranks) & item_ranks == 1

  # Identify respondents who ranked this item at all
  has_rank <- !is.na(item_ranks)

  # Calculate weighted counts
  weighted_count <- sum(weights[ranked_first], na.rm = TRUE)
  weighted_base <- sum(weights[has_rank], na.rm = TRUE)

  # Calculate effective-n (for significance testing)
  effective_n <- calculate_effective_n(weights[has_rank])

  # Calculate percentage
  percentage <- if (weighted_base > 0) {
    (weighted_count / weighted_base) * 100
  } else {
    NA_real_
  }

  # V9.9.2: Removed weights from return (shape parity)
  return(list(
    count = weighted_count,
    base = weighted_base,
    percentage = percentage,
    effective_n = effective_n
  ))
}

#' Calculate percentage who ranked item in top N positions
#'
#' V9.9.2 ENHANCEMENTS:
#' - Guard top_n vs num_positions (auto-clamp with warning)
#' - Consistent return shape (no weights)
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, name of item
#' @param top_n Integer, top N positions to include (default: 3)
#' @param num_positions Integer, total available positions (for validation)
#' @param weights Numeric vector, weights (NULL = unweighted)
#' @return List with count, base, percentage, effective_n
#' @export
calculate_percent_top_n <- function(ranking_matrix, item_name, top_n = 3,
                                   num_positions = NULL, weights = NULL) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Top-N calculations require a matrix structure to identify ranks across respondents.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.character(item_name) || length(item_name) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: item_name",
      problem = sprintf("The item_name argument must be a single character string, got: %s",
                       class(item_name)),
      why_it_matters = "Item name is required to identify which ranking column to analyze for top-N percentage.",
      how_to_fix = "Provide a single character string for item_name matching a column in ranking_matrix"
    )
  }

  if (!is.numeric(top_n) || length(top_n) != 1 || top_n < 1) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Argument Value: top_n",
      problem = sprintf("The top_n argument must be a single positive integer, got: %s",
                       paste(top_n, collapse = ", ")),
      why_it_matters = "Top-N value determines which rank positions count as 'top' (e.g., top 3 box).",
      how_to_fix = "Provide a single positive integer for top_n (e.g., 3 for top 3 box)"
    )
  }

  # V9.9.2: Guard top_n vs available positions
  if (!is.null(num_positions)) {
    if (top_n > num_positions) {
      warning(sprintf(
        "top_n (%d) exceeds available positions (%d), clamping to %d",
        top_n, num_positions, num_positions
      ), call. = FALSE)
      top_n <- num_positions
    }
  }

  if (!item_name %in% colnames(ranking_matrix)) {
    # TRS v1.0: Ranking item not found is a configuration/data mismatch
    tabs_refuse(
      code = "DATA_RANKING_ITEM_NOT_FOUND",
      title = paste0("Ranking Item Missing: ", item_name),
      problem = paste0("Ranking item '", item_name, "' is not found in the ranking matrix for calculate_percent_top_n."),
      why_it_matters = "Cannot calculate 'percent in top N' for a missing item. Results would be incomplete.",
      how_to_fix = c(
        "Check that the ranking item exists in the data",
        "Verify the item name matches the column name in data exactly"
      ),
      missing = item_name
    )
  }

  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]

  # Default weights
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }

  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Argument Length Mismatch: weights",
      problem = sprintf("The weights length (%d) must match ranking_matrix rows (%d).",
                       length(weights), length(item_ranks)),
      why_it_matters = "Each respondent row requires exactly one weight value for weighted top-N calculations.",
      how_to_fix = "Provide a weights vector with the same length as the number of rows in ranking_matrix"
    )
  }

  # Identify respondents who ranked this item in top N
  ranked_top_n <- !is.na(item_ranks) & item_ranks <= top_n

  # Identify respondents who ranked this item at all
  has_rank <- !is.na(item_ranks)

  # Calculate weighted counts
  weighted_count <- sum(weights[ranked_top_n], na.rm = TRUE)
  weighted_base <- sum(weights[has_rank], na.rm = TRUE)

  # Calculate effective-n
  effective_n <- calculate_effective_n(weights[has_rank])

  # Calculate percentage
  percentage <- if (weighted_base > 0) {
    (weighted_count / weighted_base) * 100
  } else {
    NA_real_
  }

  return(list(
    count = weighted_count,
    base = weighted_base,
    percentage = percentage,
    effective_n = effective_n
  ))
}

#' Calculate mean rank for item (lower = better ranking)
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, name of item
#' @param weights Numeric vector, weights (NULL = unweighted)
#' @return Numeric, mean rank (or NA if no data)
#' @export
calculate_mean_rank <- function(ranking_matrix, item_name, weights = NULL) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Mean rank calculation requires a matrix structure to compute average ranks.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.character(item_name) || length(item_name) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: item_name",
      problem = sprintf("The item_name argument must be a single character string, got: %s",
                       class(item_name)),
      why_it_matters = "Item name is required to identify which ranking column to compute mean rank for.",
      how_to_fix = "Provide a single character string for item_name matching a column in ranking_matrix"
    )
  }

  if (!item_name %in% colnames(ranking_matrix)) {
    # TRS v1.0: Ranking item not found is a configuration/data mismatch
    tabs_refuse(
      code = "DATA_RANKING_ITEM_NOT_FOUND",
      title = paste0("Ranking Item Missing: ", item_name),
      problem = paste0("Ranking item '", item_name, "' is not found in the ranking matrix for calculate_mean_rank."),
      why_it_matters = "Cannot calculate mean rank for a missing item. Results would be incomplete.",
      how_to_fix = c(
        "Check that the ranking item exists in the data",
        "Verify the item name matches the column name in data exactly"
      ),
      missing = item_name
    )
  }

  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]

  # Default weights
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }

  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Argument Length Mismatch: weights",
      problem = sprintf("The weights length (%d) must match ranking_matrix rows (%d).",
                       length(weights), length(item_ranks)),
      why_it_matters = "Each respondent row requires exactly one weight value for weighted mean rank calculation.",
      how_to_fix = "Provide a weights vector with the same length as the number of rows in ranking_matrix"
    )
  }

  # Filter to valid ranks
  valid_idx <- !is.na(item_ranks)
  valid_ranks <- item_ranks[valid_idx]
  valid_weights <- weights[valid_idx]

  if (length(valid_ranks) == 0) {
    return(NA_real_)
  }

  # Calculate weighted mean
  if (all(valid_weights == 1)) {
    # Unweighted - simple mean
    return(mean(valid_ranks))
  } else {
    # Weighted - use weighting.R function
    return(calculate_weighted_mean(valid_ranks, valid_weights))
  }
}

# ==============================================================================
# STATISTICAL FUNCTIONS (V9.9.2: CONFIGURABLE MIN_BASE)
# ==============================================================================

#' Calculate variance of ranks for an item
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, name of item
#' @param weights Numeric vector, weights (NULL = unweighted)
#' @return Numeric, variance of ranks (or NA if insufficient data)
#' @export
calculate_rank_variance <- function(ranking_matrix, item_name, weights = NULL) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Variance calculation requires a matrix structure to compute rank variance.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.character(item_name) || length(item_name) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: item_name",
      problem = sprintf("The item_name argument must be a single character string, got: %s",
                       class(item_name)),
      why_it_matters = "Item name is required to identify which ranking column to compute variance for.",
      how_to_fix = "Provide a single character string for item_name matching a column in ranking_matrix"
    )
  }

  if (!item_name %in% colnames(ranking_matrix)) {
    return(NA_real_)
  }

  # Extract item ranks
  item_ranks <- ranking_matrix[, item_name]

  # Default weights
  if (is.null(weights)) {
    weights <- rep(1, length(item_ranks))
  }

  # Validate weights length
  if (length(weights) != length(item_ranks)) {
    tabs_refuse(
      code = "ARG_LENGTH_MISMATCH",
      title = "Argument Length Mismatch: weights",
      problem = sprintf("The weights length (%d) must match ranking_matrix rows (%d).",
                       length(weights), length(item_ranks)),
      why_it_matters = "Each respondent row requires exactly one weight value for weighted variance calculation.",
      how_to_fix = "Provide a weights vector with the same length as the number of rows in ranking_matrix"
    )
  }

  # Filter to valid ranks
  valid_idx <- !is.na(item_ranks)
  valid_ranks <- item_ranks[valid_idx]
  valid_weights <- weights[valid_idx]

  if (length(valid_ranks) < 2) {
    return(NA_real_)
  }

  # Calculate variance (uses weighted_variance from weighting.R if available)
  if (all(valid_weights == 1)) {
    # Unweighted - population variance
    mean_rank <- mean(valid_ranks)
    return(mean((valid_ranks - mean_rank)^2))
  } else {
    # Weighted - use weighting.R function if available
    if (exists("weighted_variance", mode = "function")) {
      return(weighted_variance(valid_ranks, valid_weights))
    } else {
      # Fallback: weighted population variance
      mean_rank <- sum(valid_ranks * valid_weights) / sum(valid_weights)
      return(sum(valid_weights * (valid_ranks - mean_rank)^2) / sum(valid_weights))
    }
  }
}

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
