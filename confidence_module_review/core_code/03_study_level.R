# ==============================================================================
# STUDY-LEVEL CALCULATIONS V1.0.0
# ==============================================================================
# Functions for study-level calculations: DEFF, effective sample size
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# V1.0.0 - Initial release (2025-11-12)
#          - Calculate effective sample size (Kish 1965)
#          - Calculate design effect (DEFF)
#          - Weight statistics and quality checks
#          - Adapted from Turas tabs/lib/weighting.R V9.9.4
#
# STATISTICAL METHODOLOGY:
# - Effective sample size: n_eff = (Σw)² / Σw² (Kish 1965)
# - Design effect: DEFF = 1 + CV²  where CV = σ_w / μ_w
# - Alternative DEFF: DEFF = n_actual / n_eff
#
# REFERENCES:
# - Kish, L. (1965). Survey Sampling. Wiley.
#
# DEPENDENCIES:
# - utils.R
# ==============================================================================

STUDY_LEVEL_VERSION <- "1.0.0"

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

source_if_exists <- function(file_path) {
  if (file.exists(file_path)) {
    source(file_path)
  } else if (file.exists(file.path("R", file_path))) {
    source(file.path("R", file_path))
  } else if (file.exists(file.path("..", "R", file_path))) {
    source(file.path("..", "R", file_path))
  }
}

source_if_exists("utils.R")

# ==============================================================================
# EFFECTIVE SAMPLE SIZE
# ==============================================================================

#' Calculate effective sample size
#'
#' Calculates effective sample size using Kish (1965) formula.
#' Effective-n represents the equivalent unweighted sample that would
#' provide the same precision as the weighted sample.
#'
#' FORMULA: n_eff = (Σw)² / Σw²
#'
#' WEIGHT HANDLING:
#' - NA weights: Excluded
#' - Zero weights: Excluded
#' - Negative weights: Should be caught by validation (causes error)
#' - Infinite weights: Excluded
#' - If all weights = 1: returns actual n (no design effect)
#'
#' NUMERIC STABILITY:
#' Uses scale-safe calculation (normalizes by mean weight) to prevent
#' overflow with very large weights. Effective-n is scale-invariant.
#'
#' @param weights Numeric vector. Survey weights (must be non-negative)
#'
#' @return Integer. Effective sample size (rounded)
#'
#' @references
#' Kish, L. (1965). Survey Sampling. Wiley.
#'
#' @examples
#' weights <- c(1.2, 0.8, 1.5, 1.0, 0.9)
#' n_eff <- calculate_effective_n(weights)
#' # Returns: 5 (very light weighting, minimal design effect)
#'
#' @author Adapted from Turas weighting.R V9.9.4
#' @date 2025-11-12
#' @export
calculate_effective_n <- function(weights) {
  # Remove NA/infinite weights and keep only positive (zeros excluded)
  weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(weights) == 0) {
    return(0L)
  }

  # If all weights are 1, effective n = actual n (no design effect)
  if (all(weights == 1)) {
    return(as.integer(length(weights)))
  }

  # Scale-safe calculation for extreme weights
  # Effective-n is scale-invariant, so we can normalize by mean
  # This prevents numeric overflow with very large weights
  mean_weight <- mean(weights)

  if (is.finite(mean_weight) && mean_weight > 0) {
    # Scale by mean for numeric stability
    w <- weights / mean_weight
    n_effective <- (sum(w)^2) / sum(w^2)
  } else {
    # Fallback to direct calculation (shouldn't happen if weights validated)
    sum_weights <- sum(weights)
    sum_weights_squared <- sum(weights^2)

    if (sum_weights_squared == 0) {
      return(0L)
    }

    n_effective <- (sum_weights^2) / sum_weights_squared
  }

  # Return as integer (downstream SE/df use this rounded value)
  return(as.integer(round(n_effective)))
}


# ==============================================================================
# DESIGN EFFECT (DEFF)
# ==============================================================================

#' Calculate design effect (DEFF)
#'
#' Calculates design effect using Kish approximation: DEFF = 1 + CV²
#' where CV is the coefficient of variation of weights.
#'
#' INTERPRETATION:
#' - DEFF = 1.00: No loss of precision from weighting
#' - DEFF = 1.05-1.20: Modest loss (5-20%)
#' - DEFF = 1.20-2.00: Moderate loss (20-50%)
#' - DEFF > 2.00: Substantial loss (>50%)
#'
#' RELATIONSHIP TO EFFECTIVE-N:
#' - n_eff = n_actual / DEFF
#' - DEFF = n_actual / n_eff
#'
#' @param weights Numeric vector. Survey weights
#'
#' @return Numeric. Design effect (DEFF)
#'
#' @examples
#' weights <- c(1.2, 0.8, 1.5, 1.0, 0.9, 2.0)
#' deff <- calculate_deff(weights)
#' # Returns: ~1.15 (modest design effect)
#'
#' @references
#' Kish, L. (1965). Survey Sampling. Wiley.
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
calculate_deff <- function(weights) {
  # Remove NA/infinite weights and keep only positive
  weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(weights) == 0) {
    return(NA_real_)
  }

  # If all weights are 1, DEFF = 1 (no design effect)
  if (all(weights == 1)) {
    return(1.0)
  }

  # Calculate CV of weights
  cv_weights <- sd(weights) / mean(weights)

  # Kish approximation: DEFF = 1 + CV²
  deff <- 1 + cv_weights^2

  return(deff)
}


# ==============================================================================
# COMPREHENSIVE STUDY-LEVEL ANALYSIS
# ==============================================================================

#' Calculate study-level weight statistics
#'
#' Calculates comprehensive weight statistics including:
#' - Actual sample size
#' - Sum of weights
#' - Mean weight
#' - Min/max weights
#' - Coefficient of variation (CV)
#' - Design effect (DEFF)
#' - Effective sample size
#' - Warnings for weight issues
#'
#' @param survey_data Data frame. Survey data
#' @param weight_variable Character. Name of weight variable (NULL for unweighted)
#' @param group_variable Character. Optional grouping variable for subgroup analysis
#'
#' @return Data frame with one row per group (or one row for Total if no grouping)
#'   Columns:
#'   - Group: Group name ("Total" if no grouping)
#'   - Actual_n: Actual sample size
#'   - Sum_Weights: Sum of weights
#'   - Mean_Weight: Mean weight
#'   - Min_Weight: Minimum weight
#'   - Max_Weight: Maximum weight
#'   - Weight_CV: Coefficient of variation of weights
#'   - DEFF: Design effect
#'   - Effective_n: Effective sample size
#'   - Warning: Any warnings (empty if none)
#'
#' @examples
#' # Unweighted data
#' stats <- calculate_study_level_stats(data, weight_variable = NULL)
#'
#' # Weighted data
#' stats <- calculate_study_level_stats(data, weight_variable = "weight")
#'
#' # Weighted with subgroups
#' stats <- calculate_study_level_stats(data, weight_variable = "weight",
#'                                       group_variable = "gender")
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
calculate_study_level_stats <- function(survey_data,
                                        weight_variable = NULL,
                                        group_variable = NULL) {
  # Check if weighted
  is_weighted <- !is.null(weight_variable) && weight_variable != ""

  # If no grouping, analyze total sample
  if (is.null(group_variable) || group_variable == "") {
    if (is_weighted) {
      weights <- survey_data[[weight_variable]]
      result <- calculate_weight_stats_single("Total", weights, nrow(survey_data))
    } else {
      result <- calculate_unweighted_stats_single("Total", nrow(survey_data))
    }

    return(as.data.frame(result))
  }

  # Grouped analysis
  groups <- unique(survey_data[[group_variable]])
  groups <- groups[!is.na(groups)]

  results_list <- list()

  for (grp in groups) {
    subset_data <- survey_data[survey_data[[group_variable]] == grp, ]

    if (is_weighted) {
      weights <- subset_data[[weight_variable]]
      result <- calculate_weight_stats_single(as.character(grp), weights, nrow(subset_data))
    } else {
      result <- calculate_unweighted_stats_single(as.character(grp), nrow(subset_data))
    }

    results_list[[length(results_list) + 1]] <- result
  }

  # Combine results
  results_df <- do.call(rbind, lapply(results_list, as.data.frame))

  return(results_df)
}


#' Calculate weight statistics for single group (internal)
#' @keywords internal
calculate_weight_stats_single <- function(group_name, weights, actual_n) {
  # Remove NA weights for statistics
  valid_weights <- weights[!is.na(weights) & is.finite(weights) & weights > 0]

  if (length(valid_weights) == 0) {
    return(list(
      Group = group_name,
      Actual_n = actual_n,
      Sum_Weights = NA,
      Mean_Weight = NA,
      Min_Weight = NA,
      Max_Weight = NA,
      Weight_CV = NA,
      DEFF = NA,
      Effective_n = NA,
      Warning = "No valid weights"
    ))
  }

  # Calculate statistics
  sum_weights <- sum(valid_weights)
  mean_weight <- mean(valid_weights)
  min_weight <- min(valid_weights)
  max_weight <- max(valid_weights)
  cv_weights <- sd(valid_weights) / mean_weight
  deff <- calculate_deff(weights)
  n_eff <- calculate_effective_n(weights)

  # Generate warnings
  warning_msgs <- character()

  if (deff > 2.0) {
    warning_msgs <- c(warning_msgs, sprintf("High DEFF (%.2f) - substantial precision loss", deff))
  }

  if (max_weight / min_weight > 10) {
    warning_msgs <- c(warning_msgs, sprintf(
      "Extreme weight range (%.1f:1)",
      max_weight / min_weight
    ))
  }

  if (cv_weights > 0.30) {
    warning_msgs <- c(warning_msgs, sprintf("High weight CV (%.3f)", cv_weights))
  }

  warning_text <- if (length(warning_msgs) > 0) {
    paste(warning_msgs, collapse = "; ")
  } else {
    ""
  }

  return(list(
    Group = group_name,
    Actual_n = actual_n,
    Sum_Weights = round(sum_weights, 1),
    Mean_Weight = round(mean_weight, 3),
    Min_Weight = round(min_weight, 3),
    Max_Weight = round(max_weight, 3),
    Weight_CV = round(cv_weights, 3),
    DEFF = round(deff, 2),
    Effective_n = n_eff,
    Warning = warning_text
  ))
}


#' Calculate unweighted statistics for single group (internal)
#' @keywords internal
calculate_unweighted_stats_single <- function(group_name, actual_n) {
  return(list(
    Group = group_name,
    Actual_n = actual_n,
    Sum_Weights = actual_n,
    Mean_Weight = 1.000,
    Min_Weight = 1.000,
    Max_Weight = 1.000,
    Weight_CV = 0.000,
    DEFF = 1.00,
    Effective_n = actual_n,
    Warning = ""
  ))
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Print study-level statistics summary
#'
#' @param study_stats Data frame. Output from calculate_study_level_stats()
#'
#' @export
print_study_level_stats <- function(study_stats) {
  cat("\n=== STUDY-LEVEL WEIGHT STATISTICS ===\n\n")

  print(study_stats, row.names = FALSE)

  # Print interpretation notes
  cat("\nINTERPRETATION:\n")
  cat("  DEFF = 1.00: No loss of precision from weighting\n")
  cat("  DEFF = 1.05-1.20: Modest loss (5-20%)\n")
  cat("  DEFF = 1.20-2.00: Moderate loss (20-50%)\n")
  cat("  DEFF > 2.00: Substantial loss (>50%)\n")
  cat("\n")
  cat("  Weight CV < 0.20: Modest variation\n")
  cat("  Weight CV = 0.20-0.30: Moderate variation\n")
  cat("  Weight CV > 0.30: High variation\n")
  cat("\n")

  # Highlight warnings
  warnings <- study_stats$Warning[study_stats$Warning != ""]
  if (length(warnings) > 0) {
    cat("⚠ WARNINGS:\n")
    for (i in seq_along(warnings)) {
      cat(sprintf("  %s: %s\n", study_stats$Group[study_stats$Warning != ""][i], warnings[i]))
    }
  } else {
    cat("✓ No weight quality issues detected\n")
  }
}
