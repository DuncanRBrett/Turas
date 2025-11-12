# ==============================================================================
# TURAS SHARED LIBRARY - WEIGHTS
# ==============================================================================
# Shared between: TurasTabs, TurasTracker, and future modules
#
# PURPOSE:
#   Weight calculation and validation utilities for survey data
#
# IMPORTANT: Changes to this file affect multiple modules.
#             Test thoroughly before committing.
#
# VERSION: 1.0.0
# CREATED: Phase 4 - Code Quality Improvements
# ==============================================================================

WEIGHTS_VERSION <- "1.0.0"

# ==============================================================================
# WEIGHT EFFICIENCY CALCULATION
# ==============================================================================

#' Calculate Weight Efficiency
#'
#' Calculates effective sample size given a vector of weights.
#'
#' FORMULA: efficiency = (sum of weights)^2 / sum of squared weights
#'
#' INTERPRETATION:
#' - Equal weights: efficiency = n (no information loss)
#' - Varying weights: efficiency < n (some information loss)
#' - Highly variable weights: efficiency << n (significant loss)
#'
#' DESIGN: Extracted from both TurasTabs and TurasTracker to ensure
#' identical calculation across all modules.
#'
#' @param weights Numeric vector of weight values (must be positive, non-NA)
#' @return Numeric. Effective sample size
#'
#' @export
#' @examples
#' # Equal weights - efficiency equals sample size
#' weights <- rep(1, 100)
#' calculate_weight_efficiency(weights)  # Returns 100
#'
#' # Varying weights - efficiency less than sample size
#' weights <- c(rep(1, 90), rep(5, 10))
#' calculate_weight_efficiency(weights)  # Returns ~71.4
calculate_weight_efficiency <- function(weights) {

  # Remove NA values
  weights <- weights[!is.na(weights)]

  # Handle empty or invalid input
  if (length(weights) == 0) {
    warning("calculate_weight_efficiency: No valid weights provided", call. = FALSE)
    return(0)
  }

  # Check for negative or zero weights
  if (any(weights <= 0)) {
    warning("calculate_weight_efficiency: Some weights are <= 0 (will be excluded)", call. = FALSE)
    weights <- weights[weights > 0]
  }

  if (length(weights) == 0) {
    return(0)
  }

  # Calculate efficiency
  sum_weights <- sum(weights)
  sum_weights_squared <- sum(weights^2)

  if (sum_weights_squared == 0) {
    return(0)
  }

  eff_n <- (sum_weights^2) / sum_weights_squared
  return(eff_n)
}


#' Calculate Design Effect
#'
#' Calculates design effect (deff) for weighted data.
#'
#' FORMULA: deff = n / effective_n = sum(weights^2) / (sum(weights) / n)^2
#'
#' INTERPRETATION:
#' - deff = 1: No design effect (equal weights)
#' - deff > 1: Variance inflation due to weighting
#' - deff = 2: Standard errors are ~1.41x larger than unweighted
#'
#' @param weights Numeric vector of weight values
#' @return Numeric. Design effect
#'
#' @export
#' @examples
#' weights <- rep(1, 100)
#' calculate_design_effect(weights)  # Returns 1.0
#'
#' weights <- c(rep(0.5, 50), rep(2, 50))
#' calculate_design_effect(weights)  # Returns 1.25
calculate_design_effect <- function(weights) {

  # Remove NA and invalid weights
  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) {
    return(NA_real_)
  }

  n <- length(weights)
  eff_n <- calculate_weight_efficiency(weights)

  if (eff_n == 0) {
    return(NA_real_)
  }

  deff <- n / eff_n
  return(deff)
}

# ==============================================================================
# WEIGHT VALIDATION
# ==============================================================================

#' Validate Weights
#'
#' Performs comprehensive validation of weight values.
#' Returns list of issues found.
#'
#' @param weights Numeric vector of weight values
#' @param min_weight Minimum acceptable weight (default: 0, exclusive)
#' @param max_weight Maximum acceptable weight (default: Inf)
#' @param allow_na Logical. Allow NA weights (default: FALSE)
#' @return List with validation results:
#'   - valid: Logical. TRUE if all checks pass
#'   - n_total: Total number of weights
#'   - n_na: Number of NA weights
#'   - n_zero: Number of zero weights
#'   - n_negative: Number of negative weights
#'   - n_too_small: Number below min_weight
#'   - n_too_large: Number above max_weight
#'   - issues: Character vector of issue descriptions
#'
#' @export
#' @examples
#' weights <- c(1, 2, 3, NA, -1, 0)
#' result <- validate_weights(weights)
#' print(result$issues)
validate_weights <- function(weights,
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

  # Check for NA
  if (result$n_na > 0) {
    if (!allow_na) {
      result$valid <- FALSE
      result$issues <- c(result$issues, sprintf(
        "%d NA weights found", result$n_na
      ))
    }
  }

  # Check for zero weights
  if (result$n_zero > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf(
      "%d zero weights found", result$n_zero
    ))
  }

  # Check for negative weights
  if (result$n_negative > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf(
      "%d negative weights found", result$n_negative
    ))
  }

  # Check for weights below minimum
  if (result$n_too_small > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf(
      "%d weights below minimum (%s)", result$n_too_small, min_weight
    ))
  }

  # Check for weights above maximum
  if (result$n_too_large > 0) {
    result$valid <- FALSE
    result$issues <- c(result$issues, sprintf(
      "%d weights above maximum (%s)", result$n_too_large, max_weight
    ))
  }

  return(result)
}


#' Get Weight Summary Statistics
#'
#' Returns descriptive statistics for weights.
#'
#' @param weights Numeric vector of weight values
#' @return Data frame with one row containing:
#'   - n: Sample size
#'   - n_valid: Number of valid weights (positive, non-NA)
#'   - min: Minimum weight
#'   - max: Maximum weight
#'   - mean: Mean weight
#'   - median: Median weight
#'   - sum: Sum of weights
#'   - efficiency: Effective sample size
#'   - design_effect: Design effect
#'
#' @export
#' @examples
#' weights <- c(0.5, 1, 1.5, 2, 2.5)
#' get_weight_summary(weights)
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

# ==============================================================================
# WEIGHT APPLICATION
# ==============================================================================

#' Standardize Weight Variable
#'
#' Creates or validates a standardized weight variable in data frame.
#' Ensures consistent weight column naming across modules.
#'
#' @param data_df Data frame containing weight variable
#' @param weight_var Character. Name of weight variable in data
#' @param target_name Character. Name for standardized column (default: "weight_var")
#' @param validate Logical. Perform validation (default: TRUE)
#' @param context_name Character. Context for error messages
#' @return Data frame with standardized weight column added
#'
#' @export
#' @examples
#' df <- data.frame(ID = 1:5, my_weight = c(1, 1.5, 2, 1, 1))
#' df <- standardize_weight_variable(df, "my_weight")
#' # Now df has 'weight_var' column
standardize_weight_variable <- function(data_df,
                                       weight_var,
                                       target_name = "weight_var",
                                       validate = TRUE,
                                       context_name = "Data") {

  # Check weight variable exists
  if (!weight_var %in% names(data_df)) {
    stop(sprintf(
      "%s: Weight variable '%s' not found in data.\nAvailable columns: %s",
      context_name, weight_var, paste(names(data_df), collapse = ", ")
    ), call. = FALSE)
  }

  # Extract weights
  weights <- data_df[[weight_var]]

  # Validate if requested
  if (validate) {
    validation <- validate_weights(weights, allow_na = FALSE)

    if (!validation$valid) {
      stop(sprintf(
        "%s: Invalid weights found:\n  %s",
        context_name,
        paste(validation$issues, collapse = "\n  ")
      ), call. = FALSE)
    }
  }

  # Create standardized column
  data_df[[target_name]] <- weights

  return(data_df)
}

# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Shared weights module loaded (v%s)", WEIGHTS_VERSION))
