# ==============================================================================
# WEIGHTING VALIDATION V10.0 - WEIGHT EXTRACTION & VALIDATION MODULE
# ==============================================================================
# Functions for weight vector extraction, validation, and repair
# Part of R Survey Analytics Toolkit
#
# MODULE PURPOSE:
# This module handles the extraction of weight vectors from survey data with
# comprehensive validation and multiple repair policies. It ensures weight
# data quality and provides clear diagnostics for problematic weights.
#
# VERSION HISTORY:
# V10.0 - Modular refactoring (2025-12-27)
#         - EXTRACTED: From weighting.R V9.9.4 (~290 lines)
#         - MAINTAINED: All V9.9.4 validation logic and repair policies
#         - NO CHANGES: Function signatures and behavior identical
# V9.9.4 - Final production release (all validation complete)
# V9.9.2 - Proper weight repair policy (exclude, not coerce)
#
# WEIGHT REPAIR POLICY (V9.9.2):
# - repair="exclude" (default): NA→0, zero→0, negative→error, infinite→0
#   This is CORRECT for survey weights - excludes problematic cases
# - repair="coerce_to_one": Legacy behavior (not recommended)
#   Forces NA/zero/negative to 1, which biases estimates
# - repair="error": Stops on any problematic weights
#
# EXPORTED FUNCTIONS:
# - get_weight_vector(): Extract and validate weight vector from data
#
# INTERNAL FUNCTIONS:
# - apply_error_repair_policy(): Enforce error on invalid weights
# - apply_exclude_repair_policy(): Exclude invalid weights (recommended)
# - apply_coerce_repair_policy(): Coerce to 1 (legacy, not recommended)
# - check_weight_variability(): Warn if weights are highly variable
# ==============================================================================

WEIGHTING_VALIDATION_VERSION <- "10.0"

# ==============================================================================
# WEIGHT REPAIR POLICY HELPERS (INTERNAL)
# ==============================================================================

#' Apply error repair policy to weights
#' @keywords internal
apply_error_repair_policy <- function(weights, weight_variable, n_rows) {
  n_na <- sum(is.na(weights))
  n_zero <- sum(!is.na(weights) & weights == 0)
  n_negative <- sum(!is.na(weights) & weights < 0)
  n_infinite <- sum(!is.na(weights) & is.infinite(weights))

  issues <- character()
  if (n_na > 0) issues <- c(issues, sprintf("%d NA values", n_na))
  if (n_zero > 0) issues <- c(issues, sprintf("%d zero values", n_zero))
  if (n_negative > 0) issues <- c(issues, sprintf("%d negative values", n_negative))
  if (n_infinite > 0) issues <- c(issues, sprintf("%d infinite values", n_infinite))

  if (length(issues) > 0) {
    tabs_refuse(
      code = "DATA_INVALID_WEIGHTS",
      title = "Invalid Weight Values",
      problem = sprintf("Weight column '%s' has problems with repair='error': %s", weight_variable, paste(issues, collapse = ", ")),
      why_it_matters = "Weight repair policy is set to 'error' which requires all weights to be valid.",
      how_to_fix = c(
        "Fix the weight column data to remove NA, zero, negative, or infinite values",
        "Or use repair='exclude' to automatically exclude invalid weights"
      )
    )
  }

  return(weights)
}

#' Apply exclude repair policy to weights (RECOMMENDED)
#' @keywords internal
apply_exclude_repair_policy <- function(weights, weight_variable) {
  n_total <- length(weights)
  n_na <- sum(is.na(weights))
  n_zero <- sum(!is.na(weights) & weights == 0)
  n_negative <- sum(!is.na(weights) & weights < 0)
  n_infinite <- sum(!is.na(weights) & is.infinite(weights))

  # Negative weights are a design error - always stop
  if (n_negative > 0) {
    tabs_refuse(
      code = "DATA_NEGATIVE_WEIGHTS",
      title = "Negative Weight Values",
      problem = sprintf("Weight column '%s' contains %d negative values (%.1f%%).", weight_variable, n_negative, 100 * n_negative / n_total),
      why_it_matters = "Design weights cannot be negative - this indicates a data quality issue.",
      how_to_fix = c(
        "Fix the weight column data to remove negative values",
        "Check weight calculation or data import process"
      )
    )
  }

  # NA weights - exclude (set to 0)
  if (n_na > 0) {
    warning(sprintf(
      "Weight column '%s' contains %d NA values (%.1f%%). These will be EXCLUDED (weight=0) from analysis.",
      weight_variable,
      n_na,
      100 * n_na / n_total
    ), call. = FALSE)
    weights[is.na(weights)] <- 0
  }

  # Infinite weights - exclude (set to 0)
  if (n_infinite > 0) {
    warning(sprintf(
      "Weight column '%s' contains %d infinite values (%.1f%%). These will be EXCLUDED (weight=0) from analysis.",
      weight_variable,
      n_infinite,
      100 * n_infinite / n_total
    ), call. = FALSE)
    weights[is.infinite(weights)] <- 0
  }

  # Zero weights - keep as 0, but warn if many
  if (n_zero > 0) {
    pct_zero <- 100 * n_zero / n_total
    if (pct_zero > 5) {
      warning(sprintf(
        "Weight column '%s' contains %d zero values (%.1f%%). These cases are EXCLUDED from weighted analysis.\nHigh proportion may indicate data quality issues.",
        weight_variable,
        n_zero,
        pct_zero
      ), call. = FALSE)
    }
  }

  return(weights)
}

#' Apply coerce_to_one repair policy to weights (LEGACY - NOT RECOMMENDED)
#' @keywords internal
apply_coerce_repair_policy <- function(weights, weight_variable) {
  n_na <- sum(is.na(weights))
  n_zero <- sum(!is.na(weights) & weights == 0)
  n_negative <- sum(!is.na(weights) & weights < 0)
  n_infinite <- sum(!is.na(weights) & is.infinite(weights))

  # Warn about legacy mode
  warning(sprintf(
    "Using legacy repair='coerce_to_one' mode. This is NOT RECOMMENDED as it biases estimates.\nConsider using repair='exclude' (default) instead."
  ), call. = FALSE)

  # Warn about each type of problem
  if (n_na > 0) {
    warning(sprintf(
      "Weight column '%s': Replacing %d NA values with 1 (unweighted). This may bias results.",
      weight_variable, n_na
    ), call. = FALSE)
    weights[is.na(weights)] <- 1
  }

  if (n_negative > 0) {
    warning(sprintf(
      "Weight column '%s': Replacing %d negative values with 1. This may bias results.",
      weight_variable, n_negative
    ), call. = FALSE)
    weights[weights < 0] <- 1
  }

  if (n_zero > 0) {
    warning(sprintf(
      "Weight column '%s': Replacing %d zero values with 1. This may bias results.",
      weight_variable, n_zero
    ), call. = FALSE)
    weights[weights == 0] <- 1
  }

  if (n_infinite > 0) {
    warning(sprintf(
      "Weight column '%s': Replacing %d infinite values with 1. This may bias results.",
      weight_variable, n_infinite
    ), call. = FALSE)
    weights[is.infinite(weights)] <- 1
  }

  return(weights)
}

#' Check weight variability and warn if high
#' @keywords internal
check_weight_variability <- function(weights, weight_variable) {
  valid_weights <- weights[weights > 0 & is.finite(weights)]

  if (length(valid_weights) > 0) {
    weight_cv <- sd(valid_weights) / mean(valid_weights)  # Coefficient of variation

    if (weight_cv > 1.0) {
      warning(sprintf(
        "Weight column '%s' has high variability (CV = %.2f). This may indicate:\n  1. Intentional design (e.g., raking weights)\n  2. Data quality issues\n  3. Very unequal sampling probabilities\nEffective sample size will be substantially reduced.",
        weight_variable,
        weight_cv
      ), call. = FALSE)
    }
  }

  return(invisible(NULL))
}

# ==============================================================================
# WEIGHT EXTRACTION & VALIDATION (V9.9.2)
# ==============================================================================

#' Extract weight vector from data with proper repair policy
#'
#' WEIGHT REPAIR POLICY (V9.9.2):
#' - repair="exclude" (default): NA→0, zero→0, negative→error, infinite→0
#'   This is CORRECT for survey weights - excludes problematic cases
#' - repair="coerce_to_one": Legacy behavior (not recommended)
#'   Forces NA/zero/negative to 1, which biases estimates
#' - repair="error": Stops on any problematic weights
#'
#' DESIGN: Returns unit weights (all 1s) if weighting disabled or column missing
#' V9.9.2: No longer silently fixes bad weights - proper exclusion policy
#'
#' @param data Data frame, survey data
#' @param weight_variable Character, name of weight column (NULL = no weighting)
#' @param repair Character, weight repair policy (default: "exclude")
#' @return Numeric vector of weights
#' @export
#' @examples
#' # Recommended (excludes problematic weights)
#' weights <- get_weight_vector(survey_data, "weight", repair = "exclude")
#'
#' # Legacy behavior (not recommended)
#' weights <- get_weight_vector(survey_data, "weight", repair = "coerce_to_one")
#'
#' # Strict (errors on any issues)
#' weights <- get_weight_vector(survey_data, "weight", repair = "error")
get_weight_vector <- function(data, weight_variable, repair = c("exclude", "coerce_to_one", "error")) {
  repair <- match.arg(repair)

  # Validate data
  if (!is.data.frame(data) || nrow(data) == 0) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Data Argument",
      problem = "data must be a non-empty data frame.",
      why_it_matters = "Cannot extract weights from invalid or empty data.",
      how_to_fix = "This is an internal error - check that data is loaded correctly"
    )
  }

  # No weighting requested
  if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
    return(rep(1, nrow(data)))
  }

  # Check column exists
  if (!weight_variable %in% names(data)) {
    warning(sprintf(
      "Weight column '%s' not found in data. Using unweighted analysis.\nAvailable columns: %s",
      weight_variable,
      paste(head(names(data), 10), collapse = ", ")
    ), call. = FALSE)
    return(rep(1, nrow(data)))
  }

  weights <- data[[weight_variable]]

  # Type check
  if (!is.numeric(weights)) {
    tabs_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Weight Column Type",
      problem = sprintf("Weight column '%s' must be numeric, got: %s", weight_variable, class(weights)[1]),
      why_it_matters = "Weights must be numeric for weighted analysis calculations.",
      how_to_fix = c(
        "Convert weight column to numeric type",
        "Check that weight column contains numbers, not text"
      )
    )
  }

  # Length check (should always match, but safety check)
  if (length(weights) != nrow(data)) {
    tabs_refuse(
      code = "DATA_LENGTH_MISMATCH",
      title = "Weight Vector Length Mismatch",
      problem = sprintf("Weight vector length (%d) does not match data rows (%d).", length(weights), nrow(data)),
      why_it_matters = "Every row must have a corresponding weight value.",
      how_to_fix = "This is an internal error - check weight extraction logic"
    )
  }

  # V9.9.2: Comprehensive diagnostics
  n_total <- length(weights)
  n_na <- sum(is.na(weights))
  n_negative <- sum(weights < 0, na.rm = TRUE)
  n_zero <- sum(weights == 0, na.rm = TRUE)
  n_infinite <- sum(is.infinite(weights))
  n_positive_finite <- sum(weights > 0 & is.finite(weights), na.rm = TRUE)

  # Check for fatal issue
  if (n_positive_finite == 0) {
    tabs_refuse(
      code = "DATA_NO_VALID_WEIGHTS",
      title = "No Valid Weight Values",
      problem = sprintf("Weight column '%s' has no positive finite values.", weight_variable),
      why_it_matters = "Cannot perform weighted analysis without at least some valid weight values.",
      how_to_fix = c(
        "Check weight column data quality",
        "Ensure at least some weights are positive finite numbers"
      )
    )
  }

  # V9.9.2: Apply repair policy (delegated to focused helpers)
  if (repair == "error") {
    weights <- apply_error_repair_policy(weights, weight_variable, n_total)
  } else if (repair == "exclude") {
    weights <- apply_exclude_repair_policy(weights, weight_variable)
  } else {
    weights <- apply_coerce_repair_policy(weights, weight_variable)
  }

  # Check weight variability (after repairs)
  check_weight_variability(weights, weight_variable)

  return(as.numeric(weights))
}

# ==============================================================================
# END OF WEIGHTING_VALIDATION.R V10.0
# ==============================================================================
