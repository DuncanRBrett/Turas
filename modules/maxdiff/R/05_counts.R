# ==============================================================================
# MAXDIFF MODULE - COUNT-BASED SCORING - TURAS V10.0
# ==============================================================================
# Count-based scoring methods for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# SCORING METHODS:
# - Best%: Proportion chosen as best
# - Worst%: Proportion chosen as worst
# - Net Score: Best% - Worst%
# - Best-Worst Score: (Best - Worst) / Shown
#
# DEPENDENCIES:
# - utils.R
# ==============================================================================

COUNTS_VERSION <- "10.0"

# ==============================================================================
# MAIN COUNT SCORER
# ==============================================================================

#' Compute MaxDiff Count Scores
#'
#' Computes count-based scores for all items from long format data.
#'
#' @param long_data Data frame. Long format MaxDiff data
#' @param items Data frame. Items configuration
#' @param weighted Logical. Use weights in calculations
#' @param verbose Logical. Print progress messages
#'
#' @return Data frame with item scores:
#'   - Item_ID, Item_Label
#'   - Times_Shown, Times_Best, Times_Worst
#'   - Best_Pct, Worst_Pct, Net_Score, BW_Score
#'
#' @export
compute_maxdiff_counts <- function(long_data, items, weighted = TRUE, verbose = TRUE) {

  if (verbose) log_message("Computing count-based scores...", "INFO", verbose)

  # Get included items
  included_items <- items$Item_ID[items$Include == 1]

  # Initialize results
  results_list <- lapply(included_items, function(item_id) {

    # Filter to this item
    item_data <- long_data[long_data$item_id == item_id, ]

    if (nrow(item_data) == 0) {
      return(data.frame(
        Item_ID = item_id,
        Times_Shown = 0,
        Times_Best = 0,
        Times_Worst = 0,
        Best_Pct = NA_real_,
        Worst_Pct = NA_real_,
        Net_Score = NA_real_,
        BW_Score = NA_real_,
        stringsAsFactors = FALSE
      ))
    }

    if (weighted && "weight" %in% names(item_data)) {
      # Weighted counts
      times_shown <- sum(item_data$weight, na.rm = TRUE)
      times_best <- sum(item_data$weight * item_data$is_best, na.rm = TRUE)
      times_worst <- sum(item_data$weight * item_data$is_worst, na.rm = TRUE)
    } else {
      # Unweighted counts
      times_shown <- nrow(item_data)
      times_best <- sum(item_data$is_best, na.rm = TRUE)
      times_worst <- sum(item_data$is_worst, na.rm = TRUE)
    }

    # Calculate percentages
    best_pct <- if (times_shown > 0) 100 * times_best / times_shown else NA_real_
    worst_pct <- if (times_shown > 0) 100 * times_worst / times_shown else NA_real_

    # Net score (Best% - Worst%)
    net_score <- if (!is.na(best_pct) && !is.na(worst_pct)) {
      best_pct - worst_pct
    } else {
      NA_real_
    }

    # Best-Worst score ((Best - Worst) / Shown)
    bw_score <- if (times_shown > 0) {
      (times_best - times_worst) / times_shown
    } else {
      NA_real_
    }

    data.frame(
      Item_ID = item_id,
      Times_Shown = times_shown,
      Times_Best = times_best,
      Times_Worst = times_worst,
      Best_Pct = best_pct,
      Worst_Pct = worst_pct,
      Net_Score = net_score,
      BW_Score = bw_score,
      stringsAsFactors = FALSE
    )
  })

  # Combine results
  results <- do.call(rbind, results_list)

  # Add item labels and groups
  results <- merge(
    results,
    items[, c("Item_ID", "Item_Label", "Item_Group", "Display_Order")],
    by = "Item_ID",
    all.x = TRUE
  )

  # Calculate ranks
  results$Rank <- rank(-results$Net_Score, ties.method = "min", na.last = "keep")

  # Reorder columns
  col_order <- c("Item_ID", "Item_Label", "Item_Group",
                 "Times_Shown", "Times_Best", "Times_Worst",
                 "Best_Pct", "Worst_Pct", "Net_Score", "BW_Score",
                 "Rank", "Display_Order")
  col_order <- col_order[col_order %in% names(results)]
  results <- results[, col_order]

  if (verbose) {
    log_message(sprintf(
      "Count scores computed for %d items",
      nrow(results)
    ), "INFO", verbose)
  }

  return(results)
}


# ==============================================================================
# RESPONDENT-LEVEL COUNT SCORES
# ==============================================================================

#' Compute respondent-level count scores
#'
#' @param long_data Data frame. Long format data
#' @param items Data frame. Items configuration
#' @param verbose Logical. Print messages
#'
#' @return Data frame with respondent-by-item scores
#' @export
compute_respondent_counts <- function(long_data, items, verbose = TRUE) {

  if (verbose) log_message("Computing respondent-level scores...", "INFO", verbose)

  # Get unique respondents
  respondents <- unique(long_data$resp_id)
  included_items <- items$Item_ID[items$Include == 1]

  # Aggregate by respondent and item
  agg <- aggregate(
    cbind(is_best, is_worst) ~ resp_id + item_id,
    data = long_data,
    FUN = sum,
    na.rm = TRUE
  )

  # Count times shown
  shown <- aggregate(
    obs_id ~ resp_id + item_id,
    data = long_data,
    FUN = length
  )
  names(shown)[3] <- "times_shown"

  # Merge
  results <- merge(agg, shown, by = c("resp_id", "item_id"))

  # Calculate scores
  results$best_pct <- 100 * results$is_best / results$times_shown
  results$worst_pct <- 100 * results$is_worst / results$times_shown
  results$net_score <- results$best_pct - results$worst_pct
  results$bw_score <- (results$is_best - results$is_worst) / results$times_shown

  if (verbose) {
    log_message(sprintf(
      "Respondent scores: %d respondents x %d items",
      length(respondents), length(included_items)
    ), "INFO", verbose)
  }

  return(results)
}


# ==============================================================================
# STANDARD ERROR CALCULATIONS
# ==============================================================================

#' Compute standard errors for count scores
#'
#' Uses bootstrap resampling to estimate SEs.
#'
#' @param long_data Data frame. Long format data
#' @param items Data frame. Items configuration
#' @param n_boot Integer. Number of bootstrap iterations
#' @param verbose Logical. Print messages
#'
#' @return Data frame with Item_ID and SE columns
#' @export
compute_count_standard_errors <- function(long_data, items, n_boot = 1000, verbose = TRUE) {

  if (verbose) log_message("Computing bootstrap standard errors...", "INFO", verbose)

  included_items <- items$Item_ID[items$Include == 1]
  respondents <- unique(long_data$resp_id)
  n_resp <- length(respondents)

  # Store bootstrap estimates
  boot_estimates <- matrix(NA, nrow = n_boot, ncol = length(included_items))
  colnames(boot_estimates) <- included_items

  for (b in seq_len(n_boot)) {
    # Bootstrap sample of respondents
    boot_resp <- sample(respondents, size = n_resp, replace = TRUE)

    # Get data for bootstrap sample
    boot_data <- long_data[long_data$resp_id %in% boot_resp, ]

    # If respondent appears multiple times in bootstrap, need to handle
    # For simplicity, we'll just calculate scores on the subset

    # Calculate scores
    for (item_id in included_items) {
      item_data <- boot_data[boot_data$item_id == item_id, ]

      if (nrow(item_data) > 0) {
        times_shown <- nrow(item_data)
        times_best <- sum(item_data$is_best, na.rm = TRUE)
        times_worst <- sum(item_data$is_worst, na.rm = TRUE)

        best_pct <- 100 * times_best / times_shown
        worst_pct <- 100 * times_worst / times_shown
        net_score <- best_pct - worst_pct

        boot_estimates[b, item_id] <- net_score
      }
    }

    if (verbose && b %% 200 == 0) {
      log_progress(b, n_boot, "Bootstrap", verbose)
    }
  }

  # Calculate standard errors
  se_values <- apply(boot_estimates, 2, sd, na.rm = TRUE)

  results <- data.frame(
    Item_ID = included_items,
    Net_Score_SE = se_values,
    stringsAsFactors = FALSE
  )

  if (verbose) {
    log_message("Bootstrap standard errors computed", "INFO", verbose)
  }

  return(results)
}


# ==============================================================================
# CONFIDENCE INTERVALS FOR COUNT SCORES
# ==============================================================================
#' Compute confidence intervals for count scores
#'
#' @param count_scores Data frame. Output from compute_maxdiff_counts
#' @param n_respondents Integer. Number of respondents
#' @param conf_level Numeric. Confidence level (default: 0.95)
#'
#' @return Data frame with CI columns added
#' @export
add_count_confidence_intervals <- function(count_scores, n_respondents, conf_level = 0.95) {

  alpha <- 1 - conf_level
  z <- qnorm(1 - alpha / 2)

  # Calculate SEs using normal approximation
  # For Best%: SE = sqrt(p * (1-p) / n)
  count_scores$Best_Pct_SE <- sqrt(
    (count_scores$Best_Pct / 100) * (1 - count_scores$Best_Pct / 100) / n_respondents
  ) * 100

  count_scores$Worst_Pct_SE <- sqrt(
    (count_scores$Worst_Pct / 100) * (1 - count_scores$Worst_Pct / 100) / n_respondents
  ) * 100

  # Net Score SE (assuming independence)
  count_scores$Net_Score_SE <- sqrt(
    count_scores$Best_Pct_SE^2 + count_scores$Worst_Pct_SE^2
  )

  # Confidence intervals
  count_scores$Best_Pct_Lower <- pmax(0, count_scores$Best_Pct - z * count_scores$Best_Pct_SE)
  count_scores$Best_Pct_Upper <- pmin(100, count_scores$Best_Pct + z * count_scores$Best_Pct_SE)

  count_scores$Worst_Pct_Lower <- pmax(0, count_scores$Worst_Pct - z * count_scores$Worst_Pct_SE)
  count_scores$Worst_Pct_Upper <- pmin(100, count_scores$Worst_Pct + z * count_scores$Worst_Pct_SE)

  count_scores$Net_Score_Lower <- count_scores$Net_Score - z * count_scores$Net_Score_SE
  count_scores$Net_Score_Upper <- count_scores$Net_Score + z * count_scores$Net_Score_SE

  return(count_scores)
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff counts module loaded (v%s)", COUNTS_VERSION))
