# ==============================================================================
# RANKING CROSSTABS - V10.1 (Phase 2 Refactoring)
# ==============================================================================
# Crosstab row creation functions for ranking questions
# Extracted from ranking.R for better modularity
#
# VERSION HISTORY:
# V10.1 - Extracted from ranking.R (2025-12-29)
#        - Uses tabs_source() for reliable subdirectory loading
#        - All ranking crosstab row creation functions
#
# DEPENDENCIES (must be loaded before this file):
# - tabs_refuse() from 00_guard.R
# - format_output_value() from shared_functions.R (optional)
# - calculate_percent_ranked_first() from ranking_metrics.R
# - calculate_mean_rank() from ranking_metrics.R
# - calculate_percent_top_n() from ranking_metrics.R
#
# USAGE:
# These functions are sourced by ranking.R using:
#   tabs_source("ranking", "ranking_crosstabs.R")
#
# FUNCTIONS EXPORTED:
# - get_banner_subset_and_weights() - Get subset matrix and weights for banner
# - format_ranking_value() - Format ranking output value
# - calculate_banner_ranking_metrics() - Calculate metrics for one banner column
# - create_ranking_rows_for_item() - Create crosstab rows for ranking item
# ==============================================================================

# ==============================================================================
# RANKING ROW CREATION HELPERS (INTERNAL)
# ==============================================================================

#' Get banner subset matrix and weights
#' @keywords internal
get_banner_subset_and_weights <- function(key, banner_data_list, ranking_matrix, weights_list) {
  subset_data <- banner_data_list[[key]]

  # Check if subset has data
  if (is.null(subset_data) || !is.data.frame(subset_data) || nrow(subset_data) == 0) {
    return(list(valid = FALSE, reason = "no_data"))
  }

  # Get subset indices
  if (".original_row" %in% names(subset_data)) {
    subset_idx <- subset_data$.original_row
  } else {
    subset_idx <- seq_len(nrow(subset_data))
  }

  # Validate indices
  if (any(subset_idx < 1 | subset_idx > nrow(ranking_matrix))) {
    return(list(valid = FALSE, reason = "invalid_indices"))
  }

  subset_matrix <- ranking_matrix[subset_idx, , drop = FALSE]

  # Get weights
  subset_weights <- if (!is.null(weights_list) && key %in% names(weights_list)) {
    weights_list[[key]]
  } else {
    rep(1, length(subset_idx))
  }

  # Validate weights length
  if (length(subset_weights) != length(subset_idx)) {
    subset_weights <- rep(1, length(subset_idx))
  }

  return(list(
    valid = TRUE,
    subset_matrix = subset_matrix,
    subset_weights = subset_weights
  ))
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

#' Calculate all ranking metrics for one banner column
#' @keywords internal
calculate_banner_ranking_metrics <- function(subset_matrix, item_name, subset_weights,
                                             show_top_n, top_n, num_positions,
                                             decimal_places_percent, decimal_places_index) {
  result <- list()

  # % Ranked 1st
  first_result <- calculate_percent_ranked_first(subset_matrix, item_name, subset_weights)
  result$pct_first <- format_ranking_value(
    first_result$percentage, "percent",
    decimal_places_percent, decimal_places_index
  )

  # Mean Rank
  mean_rank <- calculate_mean_rank(subset_matrix, item_name, subset_weights)
  result$mean_rank <- format_ranking_value(
    mean_rank, "index",
    decimal_places_percent, decimal_places_index
  )

  # % Top N
  if (show_top_n) {
    top_n_result <- calculate_percent_top_n(
      subset_matrix, item_name, top_n,
      num_positions = num_positions,
      weights = subset_weights
    )
    result$pct_top_n <- format_ranking_value(
      top_n_result$percentage, "percent",
      decimal_places_percent, decimal_places_index
    )
  }

  return(result)
}

# ==============================================================================
# MAIN CROSSTAB ROW CREATION FUNCTION
# ==============================================================================

#' Create crosstab rows for one ranking item
#'
#' V9.9.2 ENHANCEMENTS:
#' - Named args in format_output_value calls
#' - top_n guard vs num_positions
#' - Legend note for mean rank interpretation
#'
#' @param ranking_matrix Numeric matrix (rows = respondents, cols = items)
#' @param item_name Character, item to create rows for
#' @param banner_data_list List of data subsets by banner column
#' @param banner_info Banner structure metadata
#' @param internal_keys Character vector, internal column keys
#' @param weights_list List of weight vectors by banner column
#' @param show_top_n Logical, whether to show top N percentage (default: TRUE)
#' @param top_n Integer, top N positions (default: 3)
#' @param num_positions Integer, total ranking positions (for validation)
#' @param decimal_places_percent Integer, decimals for percentages (default: 0)
#' @param decimal_places_index Integer, decimals for mean rank (default: 1)
#' @param add_legend Logical, add legend note to mean rank row (default: TRUE)
#' @return List of data frames (one per row)
#' @export
create_ranking_rows_for_item <- function(ranking_matrix, item_name, banner_data_list,
                                        banner_info, internal_keys, weights_list,
                                        show_top_n = TRUE, top_n = 3,
                                        num_positions = NULL,
                                        decimal_places_percent = 0,
                                        decimal_places_index = 1,
                                        add_legend = TRUE) {
  # Input validation
  if (!is.matrix(ranking_matrix) && !is.data.frame(ranking_matrix)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: ranking_matrix",
      problem = "The ranking_matrix argument must be a matrix or data.frame.",
      why_it_matters = "Crosstab row creation requires a matrix structure to calculate metrics across banner columns.",
      how_to_fix = "Provide a matrix or data.frame object for ranking_matrix"
    )
  }

  if (!is.character(item_name) || length(item_name) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: item_name",
      problem = sprintf("The item_name argument must be a single character string, got: %s",
                       class(item_name)),
      why_it_matters = "Item name identifies which ranking item to create crosstab rows for.",
      how_to_fix = "Provide a single character string for item_name matching a column in ranking_matrix"
    )
  }

  if (!is.list(banner_data_list)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: banner_data_list",
      problem = sprintf("The banner_data_list argument must be a list, got: %s", class(banner_data_list)),
      why_it_matters = "Banner data list contains data subsets for each banner column needed for crosstab.",
      how_to_fix = "Provide a list of data frames, one for each banner column"
    )
  }

  if (!is.character(internal_keys)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Argument Type: internal_keys",
      problem = sprintf("The internal_keys argument must be a character vector, got: %s",
                       class(internal_keys)),
      why_it_matters = "Internal keys identify which banner columns to include in the crosstab.",
      how_to_fix = "Provide a character vector of banner column keys"
    )
  }

  # V9.9.2: Guard top_n vs num_positions
  if (!is.null(num_positions) && top_n > num_positions) {
    warning(sprintf(
      "top_n (%d) exceeds available positions (%d), clamping to %d",
      top_n, num_positions, num_positions
    ), call. = FALSE, immediate. = TRUE)
    top_n <- num_positions
  }

  results <- list()

  # Row 1: % Ranked 1st
  pct_first_row <- data.frame(
    RowLabel = paste0(item_name, " - % Ranked 1st"),
    RowType = "Column %",
    stringsAsFactors = FALSE
  )

  # Row 2: Mean Rank (V9.9.2: Add legend note)
  mean_rank_label <- paste0(item_name, " - Mean Rank")
  if (add_legend) {
    mean_rank_label <- paste0(mean_rank_label, " (Lower = Better)")
  }

  mean_rank_row <- data.frame(
    RowLabel = mean_rank_label,
    RowType = "Average",
    stringsAsFactors = FALSE
  )

  # Row 3: % Top N (optional, V9.9.2: Dynamic top_n in label)
  if (show_top_n) {
    top_n_row <- data.frame(
      RowLabel = paste0(item_name, " - % Top ", top_n),
      RowType = "Column %",
      stringsAsFactors = FALSE
    )
  }

  # Calculate for each banner column (delegated to helpers)
  for (key in internal_keys) {
    # Get banner subset and weights (delegated to helper)
    subset_result <- get_banner_subset_and_weights(key, banner_data_list, ranking_matrix, weights_list)

    if (!subset_result$valid) {
      # Handle invalid subset
      if (subset_result$reason == "invalid_indices") {
        warning(sprintf("Invalid row indices for banner %s, skipping", key), call. = FALSE)
      }
      pct_first_row[[key]] <- NA
      mean_rank_row[[key]] <- NA
      if (show_top_n) top_n_row[[key]] <- NA
      next
    }

    # Calculate metrics with error handling (delegated to helper)
    tryCatch({
      metrics <- calculate_banner_ranking_metrics(
        subset_result$subset_matrix, item_name, subset_result$subset_weights,
        show_top_n, top_n, num_positions,
        decimal_places_percent, decimal_places_index
      )

      pct_first_row[[key]] <- metrics$pct_first
      mean_rank_row[[key]] <- metrics$mean_rank
      if (show_top_n) top_n_row[[key]] <- metrics$pct_top_n
    }, error = function(e) {
      warning(sprintf(
        "Error calculating ranking metrics for banner %s: %s",
        key,
        conditionMessage(e)
      ), call. = FALSE)
      pct_first_row[[key]] <- NA
      mean_rank_row[[key]] <- NA
      if (show_top_n) top_n_row[[key]] <- NA
    })
  }

  results[[1]] <- pct_first_row
  results[[2]] <- mean_rank_row
  if (show_top_n) {
    results[[3]] <- top_n_row
  }

  return(results)
}
