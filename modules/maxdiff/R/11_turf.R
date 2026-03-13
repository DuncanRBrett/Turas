# ==============================================================================
# MAXDIFF MODULE - TURF ANALYSIS - TURAS V11.0
# ==============================================================================
# Total Unduplicated Reach & Frequency analysis for portfolio optimization
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v11.0 - Initial release (2026-03)
#
# WHAT IS TURF?
# Given individual-level utilities, TURF finds the combination of K items
# that maximizes "reach" -- the % of respondents for whom at least one
# item in the portfolio is appealing.
#
# DEPENDENCIES:
# - utils.R (rescale_utilities, is_missing_value)
# ==============================================================================

TURF_VERSION <- "11.0"

# ==============================================================================
# APPEAL CLASSIFICATION
# ==============================================================================

#' Classify items as appealing per respondent
#'
#' For each respondent, determines which items they find appealing based
#' on the chosen threshold method.
#'
#' @param individual_utils Matrix or data frame. Rows = respondents, cols = items.
#'   Column names should be Item_IDs.
#' @param method Character. Threshold method:
#'   "ABOVE_MEAN" - item utility > respondent's mean utility
#'   "TOP_3" - respondent's top 3 items
#'   "TOP_K" - respondent's top K items (requires k parameter)
#'   "ABOVE_ZERO" - item utility > 0
#' @param k Integer. Number of top items for TOP_K method (default: 3)
#'
#' @return Logical matrix. Same dimensions as individual_utils.
#'   TRUE = respondent finds item appealing.
#'
#' @keywords internal
classify_appeal <- function(individual_utils, method = "ABOVE_MEAN", k = 3) {

  if (is.null(individual_utils) || nrow(individual_utils) == 0) {
    return(matrix(logical(0), nrow = 0, ncol = 0))
  }

  utils_mat <- as.matrix(individual_utils)
  n_resp <- nrow(utils_mat)
  n_items <- ncol(utils_mat)

  method <- toupper(trimws(method))

  appeal <- matrix(FALSE, nrow = n_resp, ncol = n_items)
  colnames(appeal) <- colnames(utils_mat)

  if (method == "ABOVE_MEAN") {
    row_means <- rowMeans(utils_mat, na.rm = TRUE)
    for (i in seq_len(n_resp)) {
      appeal[i, ] <- utils_mat[i, ] > row_means[i]
    }
  } else if (method %in% c("TOP_3", "TOP_K")) {
    top_k <- if (method == "TOP_3") 3L else as.integer(k)
    top_k <- min(top_k, n_items)
    for (i in seq_len(n_resp)) {
      ranks <- rank(-utils_mat[i, ], ties.method = "random", na.last = "keep")
      appeal[i, ] <- !is.na(ranks) & ranks <= top_k
    }
  } else if (method == "ABOVE_ZERO") {
    appeal <- utils_mat > 0
  } else {
    # Default to ABOVE_MEAN
    row_means <- rowMeans(utils_mat, na.rm = TRUE)
    for (i in seq_len(n_resp)) {
      appeal[i, ] <- utils_mat[i, ] > row_means[i]
    }
  }

  return(appeal)
}


# ==============================================================================
# REACH CALCULATION
# ==============================================================================

#' Calculate reach for a portfolio of items
#'
#' Computes the % of respondents for whom at least one item in the
#' portfolio is appealing.
#'
#' @param appeal_matrix Logical matrix from classify_appeal()
#' @param item_indices Integer vector. Column indices of items in portfolio
#' @param weights Numeric vector. Respondent weights (optional)
#'
#' @return Numeric. Reach proportion (0-1)
#'
#' @keywords internal
calculate_reach <- function(appeal_matrix, item_indices, weights = NULL) {

  if (length(item_indices) == 0) return(0)

  n_resp <- nrow(appeal_matrix)
  if (n_resp == 0) return(0)

  # Check if any item in portfolio appeals to each respondent
  if (length(item_indices) == 1) {
    reached <- appeal_matrix[, item_indices]
  } else {
    reached <- rowSums(appeal_matrix[, item_indices, drop = FALSE]) > 0
  }

  if (is.null(weights)) {
    return(mean(reached, na.rm = TRUE))
  } else {
    weights <- weights[!is.na(reached)]
    reached <- reached[!is.na(reached)]
    return(sum(weights * reached) / sum(weights))
  }
}


#' Calculate frequency for a portfolio of items
#'
#' Computes the average number of appealing items per respondent
#' within the portfolio.
#'
#' @param appeal_matrix Logical matrix from classify_appeal()
#' @param item_indices Integer vector. Column indices of items in portfolio
#' @param weights Numeric vector. Respondent weights (optional)
#'
#' @return Numeric. Average frequency
#'
#' @keywords internal
calculate_frequency <- function(appeal_matrix, item_indices, weights = NULL) {

  if (length(item_indices) == 0) return(0)

  n_resp <- nrow(appeal_matrix)
  if (n_resp == 0) return(0)

  freq_per_resp <- rowSums(appeal_matrix[, item_indices, drop = FALSE])

  if (is.null(weights)) {
    return(mean(freq_per_resp, na.rm = TRUE))
  } else {
    return(sum(weights * freq_per_resp) / sum(weights))
  }
}


# ==============================================================================
# GREEDY TURF OPTIMIZATION
# ==============================================================================

#' Run TURF analysis with greedy optimization
#'
#' Finds the optimal portfolio of items that maximizes reach using
#' a greedy forward-selection algorithm.
#'
#' @param individual_utils Matrix or data frame. Rows = respondents, cols = items.
#'   Column names should be Item_IDs.
#' @param items Data frame. Item definitions with Item_ID and Item_Label columns.
#' @param max_items Integer. Maximum portfolio size to evaluate (default: 10)
#' @param threshold_method Character. Appeal threshold method
#'   (default: "ABOVE_MEAN"). See classify_appeal() for options.
#' @param threshold_k Integer. K for TOP_K method (default: 3)
#' @param weights Numeric vector. Respondent weights (optional)
#' @param verbose Logical. Print progress (default: TRUE)
#'
#' @return List with:
#'   \item{incremental_table}{Data frame with columns: Step, Item_ID, Item_Label,
#'     Reach_Pct, Incremental_Pct, Frequency}
#'   \item{reach_curve}{Data frame with portfolio_size and reach for plotting}
#'   \item{appeal_matrix}{The computed appeal matrix}
#'   \item{threshold_method}{Method used}
#'   \item{n_respondents}{Number of respondents}
#'   \item{n_items}{Number of items evaluated}
#'
#' @export
run_turf_analysis <- function(individual_utils, items,
                              max_items = 10,
                              threshold_method = "ABOVE_MEAN",
                              threshold_k = 3,
                              weights = NULL,
                              verbose = TRUE) {

  # --- Validate inputs ---
  if (is.null(individual_utils) || nrow(individual_utils) == 0) {
    if (exists("maxdiff_refuse", mode = "function")) {
      maxdiff_refuse(
        code = "DATA_TURF_NO_UTILS",
        title = "No Individual Utilities for TURF",
        problem = "Individual-level utilities are required for TURF analysis",
        why_it_matters = "TURF needs respondent-level data to compute reach",
        how_to_fix = "Enable HB estimation (Generate_HB_Model = YES) to produce individual utilities"
      )
    }
    return(list(status = "REFUSED", message = "No individual utilities available"))
  }

  # Drop non-numeric columns (e.g., resp_id) before matrix conversion
  if (is.data.frame(individual_utils)) {
    numeric_cols <- sapply(individual_utils, is.numeric)
    utils_mat <- as.matrix(individual_utils[, numeric_cols, drop = FALSE])
  } else {
    utils_mat <- as.matrix(individual_utils)
  }
  n_resp <- nrow(utils_mat)
  n_items <- ncol(utils_mat)
  item_names <- colnames(utils_mat)

  max_items <- min(max_items, n_items)

  if (verbose) {
    cat(sprintf("  TURF Analysis: %d respondents, %d items, max portfolio = %d\n",
                n_resp, n_items, max_items))
    cat(sprintf("  Threshold method: %s\n", threshold_method))
  }

  # --- Classify appeal ---
  appeal <- classify_appeal(utils_mat, method = threshold_method, k = threshold_k)

  # --- Greedy forward selection ---
  selected <- integer(0)
  available <- seq_len(n_items)

  results <- data.frame(
    Step = integer(0),
    Item_ID = character(0),
    Item_Label = character(0),
    Reach_Pct = numeric(0),
    Incremental_Pct = numeric(0),
    Frequency = numeric(0),
    stringsAsFactors = FALSE
  )

  prev_reach <- 0

  for (step in seq_len(max_items)) {
    best_item <- NA_integer_
    best_reach <- -1

    # Find item that adds most incremental reach
    for (candidate in available) {
      trial_portfolio <- c(selected, candidate)
      trial_reach <- calculate_reach(appeal, trial_portfolio, weights)

      if (trial_reach > best_reach) {
        best_reach <- trial_reach
        best_item <- candidate
      }
    }

    if (is.na(best_item)) break

    selected <- c(selected, best_item)
    available <- setdiff(available, best_item)

    incremental <- best_reach - prev_reach
    freq <- calculate_frequency(appeal, selected, weights)

    # Look up label
    item_id <- item_names[best_item]
    item_label <- item_id
    if (!is.null(items) && "Item_ID" %in% names(items) && "Item_Label" %in% names(items)) {
      match_idx <- match(item_id, items$Item_ID)
      if (!is.na(match_idx)) {
        item_label <- items$Item_Label[match_idx]
      }
    }

    results <- rbind(results, data.frame(
      Step = step,
      Item_ID = item_id,
      Item_Label = item_label,
      Reach_Pct = round(best_reach * 100, 1),
      Incremental_Pct = round(incremental * 100, 1),
      Frequency = round(freq, 2),
      stringsAsFactors = FALSE
    ))

    prev_reach <- best_reach

    if (verbose) {
      cat(sprintf("  Step %d: +%s (Reach: %.1f%%, +%.1f%%)\n",
                  step, item_label, best_reach * 100, incremental * 100))
    }

    # Stop if 100% reach
    if (best_reach >= 0.999) break
  }

  # Build reach curve for plotting
  reach_curve <- data.frame(
    Portfolio_Size = c(0, results$Step),
    Reach_Pct = c(0, results$Reach_Pct)
  )

  list(
    status = "PASS",
    incremental_table = results,
    reach_curve = reach_curve,
    appeal_matrix = appeal,
    threshold_method = threshold_method,
    n_respondents = n_resp,
    n_items = n_items,
    max_items_evaluated = max_items
  )
}


# ==============================================================================
# CUSTOM PORTFOLIO REACH
# ==============================================================================

#' Calculate reach for a specific portfolio
#'
#' Given a pre-computed appeal matrix, calculates reach and frequency
#' for a user-specified set of items.
#'
#' @param appeal_matrix Logical matrix from classify_appeal() or run_turf_analysis()
#' @param item_ids Character vector. Item IDs in the portfolio
#' @param all_item_ids Character vector. All item IDs (column names of appeal_matrix)
#' @param weights Numeric vector. Respondent weights (optional)
#'
#' @return List with reach_pct and frequency
#'
#' @export
calculate_portfolio_reach <- function(appeal_matrix, item_ids, all_item_ids = NULL,
                                      weights = NULL) {

  if (is.null(all_item_ids)) {
    all_item_ids <- colnames(appeal_matrix)
  }

  indices <- match(item_ids, all_item_ids)
  indices <- indices[!is.na(indices)]

  if (length(indices) == 0) {
    return(list(reach_pct = 0, frequency = 0, n_items = 0))
  }

  reach <- calculate_reach(appeal_matrix, indices, weights)
  freq <- calculate_frequency(appeal_matrix, indices, weights)

  list(
    reach_pct = round(reach * 100, 1),
    frequency = round(freq, 2),
    n_items = length(indices)
  )
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff TURF module loaded (v%s)", TURF_VERSION))
