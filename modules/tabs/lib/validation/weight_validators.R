# ==============================================================================
# WEIGHT VALIDATORS MODULE
# ==============================================================================
# Module name: weight_validators
# Purpose: Comprehensive validation for weighting configuration and weight columns
# Extracted from validation.R for better modularity
# VERSION HISTORY: V10.1 - Extracted from validation.R (2025)

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Source shared functions
if (!exists("log_issue")) {
  # Use local variable to avoid overwriting global script_dir
  this_script_dir <- tryCatch({
    dirname(sys.frame(1)$ofile)
  }, error = function(e) getwd())
  if (is.null(this_script_dir) || is.na(this_script_dir) || length(this_script_dir) == 0) {
    this_script_dir <- getwd()
  }
  source(file.path(dirname(this_script_dir), "shared_functions.R"), local = FALSE)
}

# ==============================================================================
# WEIGHT VALIDATION HELPERS
# ==============================================================================

#' Check if weighting is enabled
#' @keywords internal
check_weighting_enabled <- function(config, survey_structure, error_log) {
  apply_weighting <- safe_logical(get_config_value(config, "apply_weighting", FALSE))

  if (!apply_weighting) {
    return(list(error_log = error_log, enabled = FALSE))
  }

  # Check if weight column exists flag is set in Survey_Structure
  weight_exists <- safe_logical(
    get_config_value(survey_structure$project, "weight_column_exists", "N")
  )

  if (!weight_exists) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Weighting Configuration Mismatch",
      "apply_weighting=TRUE but weight_column_exists=N in Survey_Structure. Update Survey_Structure or disable weighting.",
      "",
      "Error"
    )
    return(list(error_log = error_log, enabled = FALSE))
  }

  return(list(error_log = error_log, enabled = TRUE))
}

#' Get and validate weight variable name
#' @keywords internal
check_weight_variable <- function(config, survey_structure, error_log) {
  weight_variable <- get_config_value(config, "weight_variable", NULL)

  if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
    # Try to get default weight from Survey_Structure
    weight_variable <- get_config_value(survey_structure$project, "default_weight", NULL)

    if (is.null(weight_variable) || is.na(weight_variable) || weight_variable == "") {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Missing Weight Variable",
        "Weighting enabled but no weight_variable specified in config. Set weight_variable or disable weighting.",
        "",
        "Error"
      )
      return(list(error_log = error_log, weight_variable = NULL))
    }
  }

  return(list(error_log = error_log, weight_variable = weight_variable))
}

#' Check if weight column exists in data
#' @keywords internal
check_weight_column_exists <- function(weight_variable, survey_data, error_log) {
  if (!weight_variable %in% names(survey_data)) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Missing Weight Column",
      sprintf(
        "Weight column '%s' not found in data. Add column or update weight_variable.",
        weight_variable
      ),
      "",
      "Error"
    )
  }
  return(error_log)
}

#' Check weight values are valid
#' @keywords internal
check_weight_values_valid <- function(weight_values, weight_variable, error_log) {
  # Check for non-numeric weights
  if (!is.numeric(weight_values)) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Non-Numeric Weights",
      sprintf("Weight column '%s' is not numeric (type: %s)", weight_variable, class(weight_values)[1]),
      "",
      "Error"
    )
    return(list(error_log = error_log, valid_weights = NULL))
  }

  # Check for all NA
  valid_weights <- weight_values[!is.na(weight_values) & is.finite(weight_values)]

  if (length(valid_weights) == 0) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Empty Weight Column",
      sprintf("Weight column '%s' has no valid (non-NA, finite) values", weight_variable),
      "",
      "Error"
    )
    return(list(error_log = error_log, valid_weights = NULL))
  }

  # Check for negative weights
  if (any(valid_weights < 0)) {
    n_negative <- sum(valid_weights < 0)
    error_log <- log_issue(
      error_log,
      "Validation",
      "Negative Weights",
      sprintf(
        "Weight column '%s' contains %d negative values (%.1f%%). Weights must be non-negative.",
        weight_variable, n_negative, 100 * n_negative / length(valid_weights)
      ),
      "",
      "Error"
    )
  }

  # Check for infinite weights
  if (any(is.infinite(weight_values))) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "Infinite Weights",
      sprintf("Weight column '%s' contains infinite values. Fix data before analysis.", weight_variable),
      "",
      "Error"
    )
  }

  return(list(error_log = error_log, valid_weights = valid_weights))
}

#' Check weight distribution
#' @keywords internal
check_weight_distribution <- function(valid_weights, weight_values, weight_variable, config, error_log) {
  # V9.9.5: Fully configurable thresholds
  na_threshold <- safe_numeric(get_config_value(config, "weight_na_threshold", 10))
  zero_threshold <- safe_numeric(get_config_value(config, "weight_zero_threshold", 5))
  deff_threshold <- safe_numeric(get_config_value(config, "weight_deff_warning", 3))

  # Check NA rate
  pct_na <- 100 * sum(is.na(weight_values)) / length(weight_values)

  if (pct_na > na_threshold) {
    error_log <- log_issue(
      error_log,
      "Validation",
      "High NA Rate in Weights",
      sprintf(
        "Weight column '%s' has %.1f%% NA values (threshold: %.0f%%). Review data quality.",
        weight_variable, pct_na, na_threshold
      ),
      "",
      "Warning"
    )
  }

  # Check zero weights
  n_zero <- sum(valid_weights == 0)
  if (n_zero > 0) {
    pct_zero <- 100 * n_zero / length(valid_weights)
    if (pct_zero > zero_threshold) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "Many Zero Weights",
        sprintf(
          "Weight column '%s' has %d zero values (%.1f%%, threshold: %.0f%%). High proportion may indicate data issues.",
          weight_variable, n_zero, pct_zero, zero_threshold
        ),
        "",
        "Warning"
      )
    }
  }

  # Check for all-equal weights (SD ≈ 0)
  nonzero_weights <- valid_weights[valid_weights > 0]

  if (length(nonzero_weights) > 0) {
    weight_sd <- sd(nonzero_weights)
    weight_mean <- mean(nonzero_weights)

    if (weight_sd < 1e-10 || (weight_mean > 0 && weight_sd / weight_mean < 1e-6)) {
      error_log <- log_issue(
        error_log,
        "Validation",
        "All-Equal Weights",
        sprintf(
          "Weight column '%s' has near-zero variance (SD = %.10f). All weights appear equal - weighting may not be applied.",
          weight_variable, weight_sd
        ),
        "",
        "Warning"
      )
    }

    # Check variability and design effect
    weight_cv <- weight_sd / weight_mean

    if (weight_cv > 1.5) {
      # Calculate and report Kish design effect (deff ≈ 1 + CV²)
      design_effect <- 1 + weight_cv^2

      severity <- if (design_effect > deff_threshold) "Warning" else "Info"

      error_log <- log_issue(
        error_log,
        "Validation",
        "High Weight Variability",
        sprintf(
          "Weight column '%s' has high variability (CV = %.2f, Design Effect ≈ %.2f, threshold: %.1f). %s",
          weight_variable,
          weight_cv,
          design_effect,
          deff_threshold,
          if (design_effect > deff_threshold) "This substantially reduces effective sample size. Verify weights are correct." else "Verify weights are correct."
        ),
        "",
        severity
      )
    }
  }

  return(error_log)
}

# ------------------------------------------------------------------------------
# MAIN VALIDATION FUNCTION
# ------------------------------------------------------------------------------

#' Validate weighting configuration and weight column
#'
#' CHECKS PERFORMED:
#' - Weighting config consistency
#' - Weight variable is specified when weighting enabled
#' - Weight column exists in data
#' - Weight values are valid (not all NA, not negative, not infinite)
#' - Weight distribution is reasonable (CV, design effect)
#' - Weights are not all equal (V9.9.2)
#'
#' V9.9.5 ENHANCEMENTS:
#' - All thresholds now configurable:
#'   * weight_na_threshold (default: 10)
#'   * weight_zero_threshold (default: 5)
#'   * weight_deff_warning (default: 3)
#'
#' V9.9.2 ENHANCEMENTS:
#' - Reports Kish design effect (deff ≈ 1 + CV²)
#' - Checks for all-equal weights (SD ≈ 0)
#'
#' V9.9.3 ENHANCEMENTS:
#' - Configurable NA threshold (weight_na_threshold, default: 10)
#'
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param config Configuration list
#' @param error_log Error log data frame
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame
#' @export
validate_weighting_config <- function(survey_structure, survey_data, config, error_log, verbose = TRUE) {
  # Input validation
  if (!is.list(survey_structure) || !"project" %in% names(survey_structure)) {
    tabs_refuse(
      code = "ARG_MISSING_ELEMENT",
      title = "Missing Project Element",
      problem = "survey_structure must be a list containing a $project element.",
      why_it_matters = "The project metadata is required for weighting configuration validation.",
      how_to_fix = "Ensure survey_structure is a list with a $project element."
    )
  }

  if (!is.data.frame(survey_data)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid survey_data Type",
      problem = "survey_data must be a data frame but received a non-data-frame object.",
      why_it_matters = "The validation function requires survey_data to check weighting variables.",
      how_to_fix = "Ensure survey_data is a valid data frame."
    )
  }

  if (!is.list(config)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid config Type",
      problem = "config must be a list but received a non-list object.",
      why_it_matters = "The validation function requires config to be a list containing configuration settings.",
      how_to_fix = "Ensure config is a valid list with weighting settings."
    )
  }

  if (!is.data.frame(error_log)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid error_log Type",
      problem = "error_log must be a data frame but received a non-data-frame object.",
      why_it_matters = "The validation function requires error_log to track issues during validation.",
      how_to_fix = "Create error_log using create_error_log() before calling this function."
    )
  }

  # Check if weighting is enabled
  result <- check_weighting_enabled(config, survey_structure, error_log)
  error_log <- result$error_log
  if (!result$enabled) return(error_log)

  if (verbose) cat("Validating weighting configuration...\n")

  # Get weight variable
  result <- check_weight_variable(config, survey_structure, error_log)
  error_log <- result$error_log
  if (is.null(result$weight_variable)) return(error_log)
  weight_variable <- result$weight_variable

  # Check column exists
  error_log <- check_weight_column_exists(weight_variable, survey_data, error_log)
  if (!weight_variable %in% names(survey_data)) return(error_log)

  # Check values
  weight_values <- survey_data[[weight_variable]]
  result <- check_weight_values_valid(weight_values, weight_variable, error_log)
  error_log <- result$error_log
  if (is.null(result$valid_weights)) return(error_log)
  valid_weights <- result$valid_weights

  # Check distribution
  error_log <- check_weight_distribution(valid_weights, weight_values, weight_variable, config, error_log)

  if (verbose) cat("✓ Weighting validation complete\n")

  return(error_log)
}
