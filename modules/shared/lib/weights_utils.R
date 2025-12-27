# ==============================================================================
# WEIGHTS UTILITIES
# ==============================================================================
# Weight calculation and validation for survey data
# Consolidated from /shared/weights.R - Turas v10.0
# Part of Turas shared module infrastructure
# ==============================================================================

#' Calculate Weight Efficiency (Effective Sample Size)
#'
#' Formula: efficiency = (sum of weights)^2 / sum of squared weights
#'
#' Interpretation:
#' - Equal weights: efficiency = n (no information loss)
#' - Varying weights: efficiency < n (some loss)
#' - Highly variable: efficiency << n (significant loss)
#'
#' @param weights Numeric vector of weight values
#' @return Numeric, effective sample size
#' @export
calculate_weight_efficiency <- function(weights) {
  weights <- weights[!is.na(weights)]

  if (length(weights) == 0) {
    warning("calculate_weight_efficiency: No valid weights provided", call. = FALSE)
    return(0)
  }

  if (any(weights <= 0)) {
    warning("calculate_weight_efficiency: Some weights are <= 0 (will be excluded)", call. = FALSE)
    weights <- weights[weights > 0]
  }

  if (length(weights) == 0) return(0)

  sum_weights <- sum(weights)
  sum_weights_squared <- sum(weights^2)

  if (sum_weights_squared == 0) return(0)

  return((sum_weights^2) / sum_weights_squared)
}

#' Calculate Design Effect
#'
#' Formula: deff = n / effective_n
#'
#' Interpretation:
#' - deff = 1: No design effect (equal weights)
#' - deff > 1: Variance inflation due to weighting
#' - deff = 2: Standard errors ~1.41x larger than unweighted
#'
#' @param weights Numeric vector
#' @return Numeric, design effect
#' @export
calculate_design_effect <- function(weights) {
  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) return(NA_real_)

  n <- length(weights)
  eff_n <- calculate_weight_efficiency(weights)

  if (eff_n == 0) return(NA_real_)

  return(n / eff_n)
}

#' Validate Weights
#'
#' Comprehensive validation of weight values.
#'
#' @param weights Numeric vector
#' @param min_weight Minimum acceptable (default: 0, exclusive)
#' @param max_weight Maximum acceptable (default: Inf)
#' @param allow_na Logical (default: FALSE)
#' @return List with valid, n_total, n_na, n_zero, n_negative, issues
#' @export
validate_weights_comprehensive <- function(weights,
                                           min_weight = 0,
                                           max_weight = Inf,
                                           allow_na = FALSE) {
  result <- list(
    valid = TRUE,
    n_total = length(weights),
    n_na = sum(is.na(weights)),
    n_zero = sum(weights == 0, na.rm = TRUE),
    n_negative = sum(weights < 0, na.rm = TRUE),
    n_too_small = sum(weights <= min_weight & weights > 0, na.rm = TRUE),
    n_too_large = sum(weights > max_weight, na.rm = TRUE),
    issues = character(0)
  )

  if (result$n_na > 0 && !allow_na) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf("%d NA weights found", result$n_na))
  }

  if (result$n_zero > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf("%d zero weights found", result$n_zero))
  }

  if (result$n_negative > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf("%d negative weights found", result$n_negative))
  }

  if (result$n_too_small > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues,
      sprintf("%d weights below minimum (%s)", result$n_too_small, min_weight))
  }

  if (result$n_too_large > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues,
      sprintf("%d weights above maximum (%s)", result$n_too_large, max_weight))
  }

  return(result)
}

#' Get Weight Summary Statistics
#'
#' @param weights Numeric vector
#' @return Data frame with summary statistics
#' @export
get_weight_summary <- function(weights) {
  valid_weights <- weights[!is.na(weights) & weights > 0]
  n_valid <- length(valid_weights)

  if (n_valid == 0) {
    return(data.frame(
      n = length(weights),
      n_valid = 0,
      min = NA_real_,
      max = NA_real_,
      mean = NA_real_,
      median = NA_real_,
      sum = NA_real_,
      efficiency = NA_real_,
      design_effect = NA_real_
    ))
  }

  data.frame(
    n = length(weights),
    n_valid = n_valid,
    min = min(valid_weights),
    max = max(valid_weights),
    mean = mean(valid_weights),
    median = median(valid_weights),
    sum = sum(valid_weights),
    efficiency = calculate_weight_efficiency(valid_weights),
    design_effect = calculate_design_effect(valid_weights)
  )
}

#' Standardize Weight Variable in Data Frame
#'
#' @param data_df Data frame
#' @param weight_var Character, weight column name
#' @param target_name Character, standardized name (default: "weight_var")
#' @param validate Logical (default: TRUE)
#' @param context_name Character for error messages
#' @return Data frame with standardized weight column
#' @export
standardize_weight_variable <- function(data_df,
                                       weight_var,
                                       target_name = "weight_var",
                                       validate = TRUE,
                                       context_name = "Data") {
  if (!weight_var %in% names(data_df)) {
    turas_refuse(
      code = "DATA_WEIGHT_COLUMN_NOT_FOUND",
      title = "Weight Column Not Found",
      problem = sprintf("Weight variable '%s' not found in %s.", weight_var, context_name),
      why_it_matters = "The specified weight variable must exist in the data for weighted analysis.",
      how_to_fix = c(
        "Verify the weight column name is spelled correctly (case-sensitive)",
        sprintf("Looking for: '%s'", weight_var),
        "Check the available column names listed below",
        "Ensure the weight column exists in your data file"
      ),
      missing = weight_var,
      observed = names(data_df)
    )
  }

  weights <- data_df[[weight_var]]

  if (validate) {
    validation <- validate_weights_comprehensive(weights, allow_na = FALSE)
    if (!validation$valid) {
      turas_refuse(
        code = "DATA_INVALID_WEIGHTS",
        title = "Invalid Weight Values",
        problem = sprintf("%s contains invalid weight values.", context_name),
        why_it_matters = "Weight values must be valid for proper weighted analysis.",
        how_to_fix = c(
          "Review the weight calculation or source",
          "Issues found:",
          paste("  -", validation$issues)
        ),
        details = paste(validation$issues, collapse = "; ")
      )
    }
  }

  data_df[[target_name]] <- weights
  return(data_df)
}
