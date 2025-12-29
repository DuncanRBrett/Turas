# ==============================================================================
# QUESTION PROCESSOR - TURAS V10.1 (Phase 1 Refactoring)
# ==============================================================================
# Common question processing logic extracted from 00_main.R
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Refactoring release (2025-12-29)
#          - Extracted from 00_main.R to reduce duplication
#          - Common validation and data preparation
#          - Shared weight handling logic
#
# EXTRACTED FUNCTIONS:
# - validate_question_in_data() - Check question exists in data
# - get_question_weights() - Get and validate weights for a question
# - prepare_question_data() - Clean and align values with weights
# - calculate_base_stats() - Calculate n, n_eff, and basic statistics
#
# DEPENDENCIES:
# - utils.R (for validation helpers)
# - 03_study_level.R (for calculate_effective_n)
# ==============================================================================

QUESTION_PROCESSOR_VERSION <- "10.1"

# ==============================================================================
# QUESTION VALIDATION
# ==============================================================================

#' Validate that a question exists in survey data
#'
#' Checks if the specified question ID exists as a column in the survey data.
#' Returns validation result without stopping execution.
#'
#' @param q_id Character. Question ID to validate
#' @param survey_data Data frame. Survey data containing responses
#'
#' @return List with:
#'   \describe{
#'     \item{valid}{Logical. TRUE if question exists}
#'     \item{message}{Character. Warning message if not valid, empty if valid}
#'   }
#'
#' @keywords internal
validate_question_in_data <- function(q_id, survey_data) {
  if (!q_id %in% names(survey_data)) {
    return(list(
      valid = FALSE,
      message = sprintf("Question %s: Not found in data", q_id)
    ))
  }

  return(list(valid = TRUE, message = ""))
}


# ==============================================================================
# WEIGHT HANDLING
# ==============================================================================

#' Get weights vector for a question
#'
#' Extracts the weight variable from survey data if specified.
#' Returns NULL for unweighted analysis.
#'
#' @param survey_data Data frame. Survey data
#' @param weight_var Character or NULL. Name of weight variable
#'
#' @return Numeric vector of weights, or NULL if unweighted
#'
#' @keywords internal
get_question_weights <- function(survey_data, weight_var) {
  if (is.null(weight_var) || !nzchar(weight_var)) {
    return(NULL)
  }

  if (!weight_var %in% names(survey_data)) {
    return(NULL)
  }

  return(survey_data[[weight_var]])
}


# ==============================================================================
# DATA PREPARATION
# ==============================================================================

#' Prepare question data by aligning values and weights
#'
#' Cleans and aligns question values with weights, removing NA values
#' and ensuring both vectors have the same length. This is the core
#' data preparation step used by all question processing functions.
#'
#' @param values Vector. Question response values
#' @param weights Numeric vector or NULL. Survey weights
#' @param require_numeric Logical. If TRUE, values must be numeric (default FALSE)
#'
#' @return List with:
#'   \describe{
#'     \item{success}{Logical. TRUE if data preparation succeeded}
#'     \item{values}{Vector. Cleaned values}
#'     \item{weights}{Numeric vector or NULL. Cleaned weights}
#'     \item{n_raw}{Integer. Raw sample size}
#'     \item{message}{Character. Warning message if failed}
#'   }
#'
#' @keywords internal
prepare_question_data <- function(values, weights = NULL, require_numeric = FALSE) {

  # Handle numeric requirement with smart conversion
  if (require_numeric && !is.numeric(values)) {
    values_converted <- suppressWarnings(as.numeric(values))

    n_total <- length(values)
    n_was_na_before <- sum(is.na(values) | trimws(as.character(values)) == "")
    n_valid_after_conversion <- sum(!is.na(values_converted))
    n_non_missing_before <- n_total - n_was_na_before

    # Accept conversion if we have at least 10 valid numbers AND >= 80% success rate
    if (n_valid_after_conversion >= 10 && n_non_missing_before > 0) {
      conversion_success_rate <- n_valid_after_conversion / n_non_missing_before
      if (conversion_success_rate >= 0.80) {
        values <- values_converted
      } else {
        return(list(
          success = FALSE,
          values = NULL,
          weights = NULL,
          n_raw = 0,
          message = sprintf("Non-numeric values (only %d/%d convertible)",
                           n_valid_after_conversion, n_non_missing_before)
        ))
      }
    } else {
      return(list(
        success = FALSE,
        values = NULL,
        weights = NULL,
        n_raw = 0,
        message = sprintf("Insufficient numeric data (only %d valid values)",
                         n_valid_after_conversion)
      ))
    }
  }

  # Determine valid indices based on whether we have weights
  if (!is.null(weights)) {
    # For numeric data, also check for finite values
    if (is.numeric(values)) {
      valid_idx <- !is.na(values) & is.finite(values) & !is.na(weights) & weights > 0
    } else {
      valid_idx <- !is.na(values) & !is.na(weights) & weights > 0
    }

    values_valid <- values[valid_idx]
    weights_valid <- weights[valid_idx]

    if (length(values_valid) == 0) {
      return(list(
        success = FALSE,
        values = NULL,
        weights = NULL,
        n_raw = 0,
        message = "No valid cases after applying weights"
      ))
    }
  } else {
    # Unweighted case
    if (is.numeric(values)) {
      valid_idx <- !is.na(values) & is.finite(values)
    } else {
      valid_idx <- !is.na(values)
    }

    values_valid <- values[valid_idx]
    weights_valid <- NULL

    if (length(values_valid) == 0) {
      return(list(
        success = FALSE,
        values = NULL,
        weights = NULL,
        n_raw = 0,
        message = "No valid (non-missing) responses"
      ))
    }
  }

  return(list(
    success = TRUE,
    values = values_valid,
    weights = weights_valid,
    n_raw = length(values_valid),
    message = ""
  ))
}


# ==============================================================================
# BASE STATISTICS CALCULATION
# ==============================================================================

#' Calculate base statistics for proportion analysis
#'
#' Calculates the observed proportion and effective sample size for
#' categorical data. Handles both weighted and unweighted cases.
#'
#' @param values Vector. Cleaned values
#' @param categories Vector. Categories to count as "success"
#' @param weights Numeric vector or NULL. Cleaned weights
#'
#' @return List with:
#'   \describe{
#'     \item{success}{Logical. TRUE if calculation succeeded}
#'     \item{proportion}{Numeric. Observed proportion}
#'     \item{n_raw}{Integer. Raw sample size}
#'     \item{n_eff}{Numeric. Effective sample size}
#'     \item{message}{Character. Warning message if failed}
#'   }
#'
#' @keywords internal
calculate_proportion_stats <- function(values, categories, weights = NULL) {
  in_category <- values %in% categories

  if (!is.null(weights)) {
    total_w <- sum(weights)

    if (isTRUE(total_w <= 0)) {
      return(list(
        success = FALSE,
        proportion = NA,
        n_raw = length(values),
        n_eff = NA,
        message = "Total weight is zero or negative"
      ))
    }

    success_w <- sum(weights[in_category])
    p <- success_w / total_w
    n_eff <- calculate_effective_n(weights)
    n_raw <- length(values)
  } else {
    p <- mean(in_category)
    n_eff <- length(values)
    n_raw <- length(values)
  }

  if (is.na(p)) {
    return(list(
      success = FALSE,
      proportion = NA,
      n_raw = n_raw,
      n_eff = n_eff,
      message = "Proportion could not be calculated (NA)"
    ))
  }

  return(list(
    success = TRUE,
    proportion = p,
    n_raw = n_raw,
    n_eff = n_eff,
    message = ""
  ))
}


#' Calculate base statistics for mean analysis
#'
#' Calculates the mean, standard deviation, and effective sample size for
#' numeric data. Handles both weighted and unweighted cases.
#'
#' @param values Numeric vector. Cleaned values
#' @param weights Numeric vector or NULL. Cleaned weights
#'
#' @return List with:
#'   \describe{
#'     \item{success}{Logical. TRUE if calculation succeeded}
#'     \item{mean}{Numeric. Observed mean}
#'     \item{sd}{Numeric. Standard deviation}
#'     \item{n_raw}{Integer. Raw sample size}
#'     \item{n_eff}{Numeric. Effective sample size}
#'     \item{message}{Character. Warning message if failed}
#'   }
#'
#' @keywords internal
calculate_mean_stats <- function(values, weights = NULL) {
  if (!is.null(weights) && length(weights) > 0) {
    total_w <- sum(weights)

    if (isTRUE(total_w <= 0)) {
      return(list(
        success = FALSE,
        mean = NA,
        sd = NA,
        n_raw = length(values),
        n_eff = NA,
        message = "Total weight is zero or negative"
      ))
    }

    mean_val <- sum(values * weights) / total_w
    weighted_var <- sum(weights * (values - mean_val)^2) / total_w
    sd_val <- sqrt(weighted_var)
    n_eff <- calculate_effective_n(weights)
    n_raw <- length(values)
  } else {
    mean_val <- mean(values)
    sd_val <- sd(values)
    n_eff <- length(values)
    n_raw <- length(values)
  }

  return(list(
    success = TRUE,
    mean = mean_val,
    sd = sd_val,
    n_raw = n_raw,
    n_eff = n_eff,
    message = ""
  ))
}


#' Calculate base statistics for NPS analysis
#'
#' Calculates NPS score components (promoters, detractors, passives)
#' and effective sample size. Handles both weighted and unweighted cases.
#'
#' @param values Numeric vector. Cleaned values
#' @param promoter_codes Numeric vector. Codes for promoters
#' @param detractor_codes Numeric vector. Codes for detractors
#' @param weights Numeric vector or NULL. Cleaned weights
#'
#' @return List with:
#'   \describe{
#'     \item{success}{Logical. TRUE if calculation succeeded}
#'     \item{nps_score}{Numeric. NPS score (-100 to +100)}
#'     \item{pct_promoters}{Numeric. Percentage of promoters}
#'     \item{pct_detractors}{Numeric. Percentage of detractors}
#'     \item{pct_passives}{Numeric. Percentage of passives}
#'     \item{n_raw}{Integer. Raw sample size}
#'     \item{n_eff}{Numeric. Effective sample size}
#'     \item{message}{Character. Warning message if failed}
#'   }
#'
#' @keywords internal
calculate_nps_stats <- function(values, promoter_codes, detractor_codes, weights = NULL) {
  is_promoter <- values %in% promoter_codes
  is_detractor <- values %in% detractor_codes

  if (!is.null(weights)) {
    total_w <- sum(weights)

    if (isTRUE(total_w <= 0)) {
      return(list(
        success = FALSE,
        nps_score = NA,
        pct_promoters = NA,
        pct_detractors = NA,
        pct_passives = NA,
        n_raw = length(values),
        n_eff = NA,
        message = "Total weight is zero or negative"
      ))
    }

    pct_promoters <- 100 * sum(weights[is_promoter]) / total_w
    pct_detractors <- 100 * sum(weights[is_detractor]) / total_w
    n_eff <- calculate_effective_n(weights)
    n_raw <- length(values)
  } else {
    pct_promoters <- 100 * mean(is_promoter)
    pct_detractors <- 100 * mean(is_detractor)
    n_eff <- length(values)
    n_raw <- length(values)
  }

  nps_score <- pct_promoters - pct_detractors
  pct_passives <- 100 - pct_promoters - pct_detractors

  return(list(
    success = TRUE,
    nps_score = nps_score,
    pct_promoters = pct_promoters,
    pct_detractors = pct_detractors,
    pct_passives = pct_passives,
    n_raw = n_raw,
    n_eff = n_eff,
    message = ""
  ))
}


# ==============================================================================
# UNIFIED QUESTION PROCESSING
# ==============================================================================

#' Process a single question with full validation and data preparation
#'
#' High-level function that validates a question exists, extracts values
#' and weights, cleans data, and prepares it for CI calculation.
#' This consolidates the common preprocessing across all question types.
#'
#' @param q_id Character. Question ID
#' @param survey_data Data frame. Survey data
#' @param weight_var Character or NULL. Weight variable name
#' @param require_numeric Logical. Whether values must be numeric
#'
#' @return List with:
#'   \describe{
#'     \item{success}{Logical. TRUE if processing succeeded}
#'     \item{values}{Vector. Cleaned values (if success)}
#'     \item{weights}{Numeric vector or NULL. Cleaned weights (if success)}
#'     \item{n_raw}{Integer. Raw sample size}
#'     \item{warning}{Character. Warning message if failed}
#'   }
#'
#' @examples
#' # Internal use:
#' # prep <- process_question_data("Q1", survey_data, "weight", require_numeric = FALSE)
#' # if (prep$success) {
#' #   # proceed with CI calculations
#' # }
#'
#' @keywords internal
process_question_data <- function(q_id, survey_data, weight_var, require_numeric = FALSE) {

  # Step 1: Validate question exists
  validation <- validate_question_in_data(q_id, survey_data)
  if (!validation$valid) {
    return(list(
      success = FALSE,
      values = NULL,
      weights = NULL,
      n_raw = 0,
      warning = validation$message
    ))
  }

  # Step 2: Get raw values and weights
  values <- survey_data[[q_id]]
  weights <- get_question_weights(survey_data, weight_var)

  # Step 3: Prepare data (clean, align, validate)
  prep <- prepare_question_data(values, weights, require_numeric = require_numeric)

  if (!prep$success) {
    return(list(
      success = FALSE,
      values = NULL,
      weights = NULL,
      n_raw = 0,
      warning = sprintf("Question %s: %s", q_id, prep$message)
    ))
  }

  return(list(
    success = TRUE,
    values = prep$values,
    weights = prep$weights,
    n_raw = prep$n_raw,
    warning = ""
  ))
}
