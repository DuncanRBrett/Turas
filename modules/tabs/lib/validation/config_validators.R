# ==============================================================================
# CONFIG VALIDATORS MODULE
# ==============================================================================
# Module name: config_validators
# Purpose: Validation for crosstab configuration parameters
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
# CONFIGURATION VALIDATION HELPERS
# ==============================================================================

#' Validate alpha (significance level)
#' @keywords internal
check_alpha_config <- function(config, error_log) {
  alpha <- get_config_value(config, "alpha", NULL)
  sig_level <- get_config_value(config, "significance_level", NULL)

  if (!is.null(sig_level) && is.null(alpha)) {
    error_log <- log_issue(
      error_log, "Validation", "Deprecated Config Parameter",
      "Using 'significance_level' is deprecated. Use 'alpha' instead (e.g., alpha = 0.05 for 95% CI).",
      "", "Warning"
    )
    sig_level <- safe_numeric(sig_level)
    alpha <- if (sig_level > 0.5) 1 - sig_level else sig_level
  } else if (!is.null(alpha)) {
    alpha <- safe_numeric(alpha)
  } else {
    alpha <- 0.05
  }

  if (alpha <= 0 || alpha >= 1) {
    error_log <- log_issue(
      error_log, "Validation", "Invalid Alpha",
      sprintf("alpha must be between 0 and 1 (typical: 0.05 for 95%% CI, 0.01 for 99%% CI), got: %.4f", alpha),
      "", "Error"
    )
  }

  if (alpha > 0.2) {
    error_log <- log_issue(
      error_log, "Validation", "Unusual Alpha Value",
      sprintf("alpha = %.4f is unusually high (>80%% CI). Typical values: 0.05 (95%% CI) or 0.01 (99%% CI).", alpha),
      "", "Warning"
    )
  }

  return(error_log)
}

#' Validate minimum base
#' @keywords internal
check_min_base <- function(config, error_log) {
  min_base <- safe_numeric(get_config_value(config, "significance_min_base", 30))

  if (min_base < 1) {
    error_log <- log_issue(
      error_log, "Validation", "Invalid Minimum Base",
      sprintf("significance_min_base must be positive, got: %d", min_base),
      "", "Error"
    )
  }

  if (min_base < 10) {
    error_log <- log_issue(
      error_log, "Validation", "Low Minimum Base",
      sprintf("significance_min_base = %d is very low. Values < 30 may give unreliable significance tests.", min_base),
      "", "Warning"
    )
  }

  return(error_log)
}

#' Validate decimal places settings
#' @keywords internal
check_decimal_places <- function(config, error_log) {
  decimal_settings <- c(
    "decimal_places_percent", "decimal_places_ratings",
    "decimal_places_index", "decimal_places_mean", "decimal_places_numeric"
  )

  for (setting in decimal_settings) {
    value <- safe_numeric(get_config_value(config, setting, 0))

    if (value < 0 || value > MAX_DECIMAL_PLACES) {
      error_log <- log_issue(
        error_log, "Validation", "Invalid Decimal Places",
        sprintf("%s out of range: %d (must be 0-%d).", setting, value, MAX_DECIMAL_PLACES),
        "", "Error"
      )
    } else if (value > 5) {
      error_log <- log_issue(
        error_log, "Validation", "High Decimal Places",
        sprintf("%s = %d exceeds recommended range (0-5 is standard). Values 0-2 are typical for survey reporting.", setting, value),
        "", "Warning"
      )
    }
  }

  return(error_log)
}

#' Validate numeric question settings
#' @keywords internal
check_numeric_settings <- function(config, error_log) {
  show_median <- safe_logical(get_config_value(config, "show_numeric_median", FALSE))
  show_mode <- safe_logical(get_config_value(config, "show_numeric_mode", FALSE))
  apply_weighting <- safe_logical(get_config_value(config, "apply_weighting", FALSE))

  if (show_median && apply_weighting) {
    error_log <- log_issue(
      error_log, "Validation", "Unsupported Configuration",
      "show_numeric_median=TRUE with apply_weighting=TRUE: Median is only available for unweighted data. Median will display as 'N/A (weighted)'.",
      "", "Warning"
    )
  }

  if (show_mode && apply_weighting) {
    error_log <- log_issue(
      error_log, "Validation", "Unsupported Configuration",
      "show_numeric_mode=TRUE with apply_weighting=TRUE: Mode is only available for unweighted data. Mode will display as 'N/A (weighted)'.",
      "", "Warning"
    )
  }

  outlier_method <- get_config_value(config, "outlier_method", "IQR")
  valid_outlier_methods <- c("IQR")

  if (!outlier_method %in% valid_outlier_methods) {
    error_log <- log_issue(
      error_log, "Validation", "Invalid Outlier Method",
      sprintf("outlier_method '%s' not supported. Valid methods: %s. Using 'IQR' as default.",
              outlier_method, paste(valid_outlier_methods, collapse = ", ")),
      "", "Warning"
    )
    config$outlier_method <- "IQR"
  }

  return(error_log)
}

#' Validate and normalize output format
#' @keywords internal
check_output_format <- function(config, error_log, verbose) {
  output_format <- get_config_value(config, "output_format", "excel")
  valid_formats <- c("excel", "xlsx", "csv")

  if (!output_format %in% valid_formats) {
    error_log <- log_issue(
      error_log, "Validation", "Invalid Output Format",
      sprintf("output_format '%s' not recognized. Valid formats: %s. Using 'xlsx' as default.",
              output_format, paste(valid_formats, collapse = ", ")),
      "", "Warning"
    )
    config$output_format <- "xlsx"
  } else if (output_format == "excel") {
    config$output_format <- "xlsx"
    if (verbose) cat("  Note: output_format 'excel' normalized to 'xlsx'\n")
  }

  return(error_log)
}

# ------------------------------------------------------------------------------
# MAIN VALIDATION FUNCTION
# ------------------------------------------------------------------------------

#' Validate crosstab configuration parameters
#'
#' CHECKS PERFORMED:
#' - alpha (significance level) is in (0, 1)
#' - significance_min_base is positive
#' - decimal_places are reasonable (0-5, documented standard)
#' - All required config values are present
#' - Output format is valid (normalizes excel → xlsx)
#'
#' V9.9.2 ENHANCEMENTS:
#' - Documents decimal precision policy (0-5 is standard)
#'
#' V9.9.3 ENHANCEMENTS:
#' - Normalizes output_format in config object: "excel" → "xlsx"
#'
#' @param config Configuration list
#' @param survey_structure Survey structure list
#' @param survey_data Survey data frame
#' @param error_log Error log data frame
#' @param verbose Logical, print progress messages (default: TRUE)
#' @return Updated error log data frame
#' @export
validate_crosstab_config <- function(config, survey_structure, survey_data, error_log, verbose = TRUE) {
  # Input validation
  if (!is.list(config)) {
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid config Type",
      problem = "config must be a list but received a non-list object.",
      why_it_matters = "The validation function requires config to be a list containing crosstab configuration settings.",
      how_to_fix = "Ensure config is a valid list with crosstab settings."
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

  if (verbose) cat("Validating crosstab configuration...\n")

  # Run all validation checks
  error_log <- check_alpha_config(config, error_log)
  error_log <- check_min_base(config, error_log)
  error_log <- check_decimal_places(config, error_log)
  error_log <- check_numeric_settings(config, error_log)
  error_log <- check_output_format(config, error_log, verbose)

  if (verbose) cat("✓ Configuration validation complete\n")

  return(error_log)
}
