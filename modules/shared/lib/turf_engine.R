# ==============================================================================
# SHARED TURF ENGINE - TURAS
# ==============================================================================
# Total Unduplicated Reach & Frequency analysis for portfolio optimization.
# Extracted from maxdiff module for reuse across brand (CEP TURF) and
# portfolio (Category TURF) modules.
#
# VERSION HISTORY:
# v1.0 - Extracted from maxdiff 11_turf.R (2026-04)
#
# WHAT IS TURF?
# Given individual-level data (utilities, binary associations, or any
# respondent × item matrix), TURF finds the combination of K items that
# maximises "reach" -- the % of respondents for whom at least one item
# in the portfolio is appealing / relevant.
#
# USAGE CONTEXTS:
# - MaxDiff: find optimal product portfolio from individual utilities
# - Brand (CEP TURF): find CEP combination maximising mental reach
# - Portfolio (Category TURF): find category combination maximising
#   consumer reach
#
# DEPENDENCIES: None (base R only)
# ==============================================================================

TURF_ENGINE_VERSION <- "1.0"


# ==============================================================================
# SECTION 1: APPEAL CLASSIFICATION
# ==============================================================================

#' Classify items as appealing per respondent
#'
#' For each respondent, determines which items they find appealing based
#' on the chosen threshold method. This is the first step in TURF analysis:
#' converting a numeric utility/score matrix into a binary appeal matrix.
#'
#' For brand module CEP TURF, the input is already binary (brand-CEP
#' linkage matrix), so use method = "ABOVE_ZERO" or pass the binary
#' matrix directly via \code{turf_from_binary()}.
#'
#' @param individual_scores Matrix or data frame. Rows = respondents,
#'   cols = items/CEPs/categories. Column names should be item identifiers.
#' @param method Character. Threshold method:
#'   \describe{
#'     \item{"ABOVE_MEAN"}{item score > respondent's mean score (default)}
#'     \item{"TOP_3"}{respondent's top 3 items}
#'     \item{"TOP_K"}{respondent's top K items (requires k parameter)}
#'     \item{"ABOVE_ZERO"}{item score > 0 (use for binary data)}
#'     \item{"BINARY"}{treat input as pre-classified binary (>0 = TRUE)}
#'   }
#' @param k Integer. Number of top items for TOP_K method (default: 3).
#'
#' @return Logical matrix. Same dimensions as input.
#'   TRUE = respondent finds item appealing/relevant.
#'
#' @examples
#' \dontrun{
#'   # From MaxDiff utilities
#'   appeal <- classify_appeal(individual_utils, method = "ABOVE_MEAN")
#'
#'   # From brand CEP linkage (already binary 0/1)
#'   appeal <- classify_appeal(cep_matrix, method = "BINARY")
#' }
#'
#' @export
classify_appeal <- function(individual_scores, method = "ABOVE_MEAN", k = 3) {

  if (is.null(individual_scores) || nrow(individual_scores) == 0) {
    return(matrix(logical(0), nrow = 0, ncol = 0))
  }

  scores_mat <- as.matrix(individual_scores)
  n_resp <- nrow(scores_mat)
  n_items <- ncol(scores_mat)

  method <- toupper(trimws(method))

  appeal <- matrix(FALSE, nrow = n_resp, ncol = n_items)
  colnames(appeal) <- colnames(scores_mat)

  if (method == "ABOVE_MEAN") {
    row_means <- rowMeans(scores_mat, na.rm = TRUE)
    for (i in seq_len(n_resp)) {
      cmp <- scores_mat[i, ] > row_means[i]
      appeal[i, ] <- ifelse(is.na(cmp), FALSE, cmp)
    }
  } else if (method %in% c("TOP_3", "TOP_K")) {
    top_k <- if (method == "TOP_3") 3L else as.integer(k)
    top_k <- min(top_k, n_items)
    for (i in seq_len(n_resp)) {
      ranks <- rank(-scores_mat[i, ], ties.method = "first", na.last = "keep")
      appeal[i, ] <- !is.na(ranks) & ranks <= top_k
    }
  } else if (method %in% c("ABOVE_ZERO", "BINARY")) {
    cmp <- scores_mat > 0
    appeal <- ifelse(is.na(cmp), FALSE, cmp)
    colnames(appeal) <- colnames(scores_mat)
  } else {
    # Default to ABOVE_MEAN with warning
    row_means <- rowMeans(scores_mat, na.rm = TRUE)
    for (i in seq_len(n_resp)) {
      cmp <- scores_mat[i, ] > row_means[i]
      appeal[i, ] <- ifelse(is.na(cmp), FALSE, cmp)
    }
    warning(sprintf("Unknown threshold method '%s', defaulting to ABOVE_MEAN", method))
  }

  return(appeal)
}


# ==============================================================================
# SECTION 2: REACH & FREQUENCY CALCULATION
# ==============================================================================

#' Calculate reach for a portfolio of items
#'
#' Computes the proportion of respondents for whom at least one item in
#' the portfolio is appealing/relevant.
#'
#' @param appeal_matrix Logical matrix from \code{classify_appeal()}.
#' @param item_indices Integer vector. Column indices of items in portfolio.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Numeric. Reach proportion (0-1).
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
#' @param appeal_matrix Logical matrix from \code{classify_appeal()}.
#' @param item_indices Integer vector. Column indices of items in portfolio.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return Numeric. Average frequency.
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
# SECTION 3: GREEDY TURF OPTIMISATION
# ==============================================================================

#' Run TURF analysis with greedy forward-selection optimisation
#'
#' Finds the optimal portfolio of items that maximises unduplicated reach
#' using a greedy forward-selection algorithm. At each step, the item
#' that adds the most incremental reach is selected.
#'
#' @param individual_scores Matrix or data frame. Rows = respondents,
#'   cols = items. Column names should be item identifiers.
#' @param items Data frame. Item definitions with at minimum an
#'   \code{Item_ID} column. An \code{Item_Label} column is used for
#'   display if present.
#' @param max_items Integer. Maximum portfolio size to evaluate (default: 10).
#' @param threshold_method Character. Appeal threshold method
#'   (default: "ABOVE_MEAN"). See \code{classify_appeal()} for options.
#' @param threshold_k Integer. K for TOP_K method (default: 3).
#' @param weights Numeric vector. Respondent weights (optional).
#' @param verbose Logical. Print progress (default: TRUE).
#' @param id_col Character. Column name in \code{items} for item IDs
#'   (default: "Item_ID"). Allows reuse across contexts (e.g., "CEP_Code").
#' @param label_col Character. Column name in \code{items} for item labels
#'   (default: "Item_Label"). Allows reuse across contexts (e.g., "CEP_Text").
#'
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{incremental_table}{Data frame: Step, Item_ID, Item_Label,
#'     Reach_Pct, Incremental_Pct, Frequency}
#'   \item{reach_curve}{Data frame: Portfolio_Size, Reach_Pct (for plotting)}
#'   \item{appeal_matrix}{The computed logical appeal matrix}
#'   \item{threshold_method}{Method used}
#'   \item{n_respondents}{Number of respondents}
#'   \item{n_items}{Number of items evaluated}
#'   \item{max_items_evaluated}{Maximum portfolio size}
#'
#' @examples
#' \dontrun{
#'   # MaxDiff TURF
#'   result <- run_turf_analysis(hb_utils, items_df, max_items = 5)
#'
#'   # CEP TURF (brand module)
#'   result <- run_turf_analysis(
#'     cep_linkage_matrix, cep_df,
#'     threshold_method = "BINARY",
#'     id_col = "CEP_Code", label_col = "CEP_Text"
#'   )
#' }
#'
#' @export
run_turf_analysis <- function(individual_scores, items,
                              max_items = 10,
                              threshold_method = "ABOVE_MEAN",
                              threshold_k = 3,
                              weights = NULL,
                              verbose = TRUE,
                              id_col = "Item_ID",
                              label_col = "Item_Label") {

  # --- Validate inputs ---
  if (is.null(individual_scores) ||
      (is.data.frame(individual_scores) && nrow(individual_scores) == 0) ||
      (is.matrix(individual_scores) && nrow(individual_scores) == 0)) {
    return(list(
      status = "REFUSED",
      code = "DATA_TURF_NO_SCORES",
      message = "No individual-level scores provided for TURF analysis"
    ))
  }

  # Drop non-numeric columns (e.g., resp_id) before matrix conversion
  if (is.data.frame(individual_scores)) {
    numeric_cols <- vapply(individual_scores, is.numeric, logical(1))
    scores_mat <- as.matrix(individual_scores[, numeric_cols, drop = FALSE])
  } else {
    scores_mat <- as.matrix(individual_scores)
  }
  n_resp <- nrow(scores_mat)
  n_items <- ncol(scores_mat)
  item_names <- colnames(scores_mat)

  max_items <- min(max_items, n_items)

  if (verbose) {
    cat(sprintf("  TURF Analysis: %d respondents, %d items, max portfolio = %d\n",
                n_resp, n_items, max_items))
    cat(sprintf("  Threshold method: %s\n", threshold_method))
  }

  # --- Classify appeal ---
  appeal <- classify_appeal(scores_mat, method = threshold_method, k = threshold_k)

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

    # Look up label from items data frame
    item_id <- item_names[best_item]
    item_label <- item_id
    if (!is.null(items) && id_col %in% names(items) && label_col %in% names(items)) {
      match_idx <- match(item_id, items[[id_col]])
      if (!is.na(match_idx)) {
        item_label <- items[[label_col]][match_idx]
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
# SECTION 4: CUSTOM PORTFOLIO REACH
# ==============================================================================

#' Calculate reach for a specific portfolio
#'
#' Given a pre-computed appeal matrix, calculates reach and frequency
#' for a user-specified set of items.
#'
#' @param appeal_matrix Logical matrix from \code{classify_appeal()} or
#'   \code{run_turf_analysis()}.
#' @param item_ids Character vector. Item IDs in the portfolio.
#' @param all_item_ids Character vector. All item IDs (column names of
#'   appeal_matrix). Defaults to \code{colnames(appeal_matrix)}.
#' @param weights Numeric vector. Respondent weights (optional).
#'
#' @return List with:
#'   \item{reach_pct}{Numeric. Reach percentage (0-100).}
#'   \item{frequency}{Numeric. Average number of appealing items.}
#'   \item{n_items}{Integer. Number of items in portfolio.}
#'
#' @export
calculate_portfolio_reach <- function(appeal_matrix, item_ids,
                                      all_item_ids = NULL,
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
# SECTION 5: REACH SENSITIVITY ANALYSIS
# ==============================================================================

#' Compare TURF reach across different threshold methods
#'
#' Runs the TURF greedy selection for multiple threshold methods and
#' returns a comparison table showing how reach varies by method.
#' Useful for sensitivity analysis and method selection.
#'
#' @param individual_scores Matrix or data frame. Rows = respondents,
#'   cols = items.
#' @param items Data frame. Item definitions with ID and label columns.
#' @param portfolio_sizes Integer vector. Portfolio sizes to compare
#'   (default: 1:5).
#' @param methods Character vector. Threshold methods to compare.
#'   Default: c("ABOVE_MEAN", "TOP_3", "ABOVE_ZERO").
#' @param weights Numeric vector. Respondent weights (optional).
#' @param verbose Logical. Print progress (default: FALSE).
#' @param id_col Character. Column name for item IDs (default: "Item_ID").
#' @param label_col Character. Column name for item labels
#'   (default: "Item_Label").
#'
#' @return Data frame with columns: Portfolio_Size, Method, Reach_Pct.
#'
#' @export
compute_reach_sensitivity <- function(individual_scores, items,
                                       portfolio_sizes = 1:5,
                                       methods = c("ABOVE_MEAN", "TOP_3", "ABOVE_ZERO"),
                                       weights = NULL,
                                       verbose = FALSE,
                                       id_col = "Item_ID",
                                       label_col = "Item_Label") {

  if (is.null(individual_scores) || nrow(individual_scores) == 0) {
    return(data.frame(Portfolio_Size = integer(), Method = character(),
                      Reach_Pct = numeric(), stringsAsFactors = FALSE))
  }

  results <- list()

  for (method in methods) {
    turf <- tryCatch(
      run_turf_analysis(
        individual_scores = individual_scores,
        items = items,
        max_items = max(portfolio_sizes),
        threshold_method = method,
        weights = weights,
        verbose = verbose,
        id_col = id_col,
        label_col = label_col
      ),
      error = function(e) NULL
    )

    if (is.null(turf) || is.null(turf$reach_curve)) next

    for (ps in portfolio_sizes) {
      reach <- if (ps <= nrow(turf$incremental_table)) {
        turf$incremental_table$Reach_Pct[ps]
      } else {
        max(turf$incremental_table$Reach_Pct)
      }

      results[[length(results) + 1]] <- data.frame(
        Portfolio_Size = ps,
        Method = method,
        Reach_Pct = reach,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(results) == 0) {
    return(data.frame(Portfolio_Size = integer(), Method = character(),
                      Reach_Pct = numeric(), stringsAsFactors = FALSE))
  }

  do.call(rbind, results)
}


# ==============================================================================
# SECTION 6: CONVENIENCE WRAPPERS FOR SPECIFIC CONTEXTS
# ==============================================================================

#' Run TURF on a binary association matrix
#'
#' Convenience wrapper for TURF analysis on pre-classified binary data,
#' such as brand-CEP linkage matrices where each cell is already 0/1.
#' Skips the appeal classification step.
#'
#' @param binary_matrix Matrix or data frame. Rows = respondents,
#'   cols = items/CEPs. Values should be 0/1 or logical.
#' @param items Data frame. Item definitions.
#' @param max_items Integer. Maximum portfolio size (default: 10).
#' @param weights Numeric vector. Respondent weights (optional).
#' @param verbose Logical. Print progress (default: TRUE).
#' @param id_col Character. Column name for item IDs (default: "Item_ID").
#' @param label_col Character. Column name for labels (default: "Item_Label").
#'
#' @return Same as \code{run_turf_analysis()}.
#'
#' @export
turf_from_binary <- function(binary_matrix, items,
                             max_items = 10,
                             weights = NULL,
                             verbose = TRUE,
                             id_col = "Item_ID",
                             label_col = "Item_Label") {

  run_turf_analysis(
    individual_scores = binary_matrix,
    items = items,
    max_items = max_items,
    threshold_method = "BINARY",
    weights = weights,
    verbose = verbose,
    id_col = id_col,
    label_col = label_col
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

# Only print load message if not in test context
if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Shared TURF engine loaded (v%s)", TURF_ENGINE_VERSION))
}
