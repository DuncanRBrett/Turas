# ==============================================================================
# RANKING CALCULATIONS V10.0
# ==============================================================================
# Extracted from ranking.R for improved maintainability
# Contains all ranking calculation and metric functions
#
# Part of R Survey Analytics Toolkit
# Module: Ranking - Calculations
#
# CONTENTS:
# - Percent ranked first calculations
# - Top-N percentage calculations
# - Mean rank calculations
# - Rank variance calculations
# - Value formatting helpers
#
# DEPENDENCIES:
# - shared_functions.R (for tabs_refuse error handling)
# - weighting.R (for weighted calculations)
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

#' Format ranking output value
#' @keywords internal
format_ranking_value <- function(value, value_type, decimal_places_percent, decimal_places_index) {
  if (exists("format_output_value", mode = "function")) {
    if (value_type == "percent") {
      format_output_value(
        value,
        "percent",
        decimal_places_percent = decimal_places_percent,
        decimal_places_ratings = NULL,
        decimal_places_index = NULL
      )
    } else {  # "index"
      format_output_value(
        value,
        "index",
        decimal_places_percent = NULL,
        decimal_places_ratings = NULL,
        decimal_places_index = decimal_places_index
      )
    }
  } else {
    # Fallback if format_output_value not available
    if (is.na(value)) {
      NA
    } else if (value_type == "percent") {
      round(value, decimal_places_percent)
    } else {
      round(value, decimal_places_index)
    }
  }
}

# ==============================================================================
# END OF RANKING_CALCULATIONS.R V10.0
# ==============================================================================
