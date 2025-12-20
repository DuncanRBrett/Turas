# ==============================================================================
# KEY DRIVER - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the Key Driver module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - keydriver_refuse() - module-specific refusal wrapper
#   - keydriver_guard_init() - initialize guard state with KDA-specific fields
#   - Validation helpers for KDA-specific requirements
#
# Related:
#   - modules/shared/lib/trs_refusal.R - shared TRS infrastructure
#
# Version: 1.0 (TRS Integration)
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# KEYDRIVER-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (KeyDriver)
#'
#' KeyDriver-specific wrapper around turas_refuse() that provides
#' module-specific defaults and code prefix handling.
#'
#' @param code Refusal code (will be prefixed if needed)
#' @param title Short title for the refusal
#' @param problem One-sentence description of what went wrong
#' @param why_it_matters Explanation of analytical risk
#' @param how_to_fix Explicit step-by-step instructions to resolve
#' @param expected Expected entities (for diagnostics)
#' @param observed Observed entities (for diagnostics)
#' @param missing Missing entities (for diagnostics)
#' @param details Additional diagnostic details
#'
#' @keywords internal
keydriver_refuse <- function(code,
                             title,
                             problem,
                             why_it_matters = NULL,
                             how_to_fix,
                             expected = NULL,
                             observed = NULL,
                             missing = NULL,
                             details = NULL) {

  # Ensure code has valid TRS prefix
  if (!grepl("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", code)) {
    code <- paste0("CFG_", code)
  }

  turas_refuse(
    code = code,
    title = title,
    problem = problem,
    why_it_matters = why_it_matters,
    how_to_fix = how_to_fix,
    expected = expected,
    observed = observed,
    missing = missing,
    details = details,
    module = "KEYDRIVER"
  )
}


#' Run Key Driver Analysis with Refusal Handler
#'
#' Wraps KeyDriver execution with TRS refusal handling.
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
keydriver_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "KEYDRIVER")

  # Add KeyDriver-specific class for compatibility
  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("keydriver_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# KEYDRIVER GUARD STATE
# ==============================================================================

#' Initialize KeyDriver Guard State
#'
#' Creates guard state with KeyDriver-specific tracking fields.
#'
#' @return Guard state list
#' @export
keydriver_guard_init <- function() {
  guard <- guard_init(module = "KEYDRIVER")

  # Add KeyDriver-specific fields
  guard$excluded_drivers <- character(0)
  guard$zero_variance_drivers <- character(0)
  guard$collinearity_warnings <- list()
  guard$shap_status <- "not_run"
  guard$quadrant_status <- "not_run"

  guard
}


#' Record Excluded Driver
#'
#' Records when a driver variable was excluded from analysis.
#'
#' @param guard Guard state object
#' @param driver Driver variable name
#' @param reason Reason for exclusion
#' @return Updated guard state
#' @keywords internal
guard_record_excluded_driver <- function(guard, driver, reason) {
  guard$excluded_drivers <- c(guard$excluded_drivers, driver)
  guard <- guard_warn(guard, paste0("Excluded driver: ", driver, " (", reason, ")"), "excluded")
  guard
}


#' Record Collinearity Warning
#'
#' Records when high collinearity is detected between drivers.
#'
#' @param guard Guard state object
#' @param var1 First variable
#' @param var2 Second variable
#' @param correlation Correlation value
#' @return Updated guard state
#' @keywords internal
guard_record_collinearity <- function(guard, var1, var2, correlation) {
  guard$collinearity_warnings[[length(guard$collinearity_warnings) + 1]] <- list(
    var1 = var1,
    var2 = var2,
    correlation = correlation
  )
  guard <- guard_flag_stability(guard, paste0("High collinearity: ", var1, " <-> ", var2))
  guard
}


#' Get KeyDriver Guard Summary
#'
#' Creates comprehensive summary including KeyDriver-specific fields.
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
keydriver_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  # Add KeyDriver-specific fields
  summary$excluded_drivers <- guard$excluded_drivers
  summary$zero_variance_drivers <- guard$zero_variance_drivers
  summary$collinearity_warnings <- guard$collinearity_warnings
  summary$shap_status <- guard$shap_status
  summary$quadrant_status <- guard$quadrant_status

  # Update has_issues
  summary$has_issues <- summary$has_issues ||
                        length(guard$excluded_drivers) > 0 ||
                        length(guard$collinearity_warnings) > 0

  summary
}


# ==============================================================================
# KEYDRIVER VALIDATION GATES
# ==============================================================================

#' Validate KeyDriver Configuration
#'
#' Hard validation gate for KeyDriver config. Refuses if critical issues found.
#'
#' @param config Configuration list
#' @keywords internal
validate_keydriver_config <- function(config) {

  # Check outcome variable is specified
  if (is.null(config$outcome_var) || length(config$outcome_var) == 0) {
    keydriver_refuse(
      code = "CFG_OUTCOME_MISSING",
      title = "No Outcome Variable Defined",
      problem = "The configuration does not specify an outcome (dependent) variable.",
      why_it_matters = "Key driver analysis requires an outcome variable to analyze.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Ensure one variable has Type='Outcome'",
        "The outcome should be the variable you want to explain/predict"
      )
    )
  }

  # Check driver variables are specified
  if (is.null(config$driver_vars) || length(config$driver_vars) == 0) {
    keydriver_refuse(
      code = "CFG_DRIVERS_MISSING",
      title = "No Driver Variables Defined",
      problem = "The configuration does not specify any driver (independent) variables.",
      why_it_matters = "Key driver analysis requires driver variables to determine their importance.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Set Type='Driver' for each independent variable",
        "You need at least 2 driver variables for meaningful analysis"
      )
    )
  }

  # Check minimum drivers
  if (length(config$driver_vars) < 2) {
    keydriver_refuse(
      code = "CFG_INSUFFICIENT_DRIVERS",
      title = "Insufficient Driver Variables",
      problem = paste0("Only ", length(config$driver_vars), " driver variable specified. Need at least 2."),
      why_it_matters = "Key driver analysis compares relative importance across multiple drivers.",
      how_to_fix = "Add more driver variables to the Variables sheet (Type='Driver')."
    )
  }

  invisible(TRUE)
}


#' Validate KeyDriver Data
#'
#' Hard validation gate for data. Refuses if critical issues found.
#'
#' @param data Data frame
#' @param config Configuration list
#' @param guard Guard state for tracking warnings
#' @return Updated guard state
#' @keywords internal
validate_keydriver_data <- function(data, config, guard) {

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars

  # Check outcome exists
  if (!outcome_var %in% names(data)) {
    keydriver_refuse(
      code = "DATA_OUTCOME_NOT_FOUND",
      title = "Outcome Variable Not Found in Data",
      problem = paste0("Outcome variable '", outcome_var, "' is not in the data file."),
      why_it_matters = "Cannot run analysis without the outcome variable.",
      how_to_fix = c(
        "Check that the variable name in config matches the data column name exactly",
        "Variable names are case-sensitive",
        "Check for extra spaces in column names"
      ),
      expected = outcome_var,
      observed = head(names(data), 20)
    )
  }

  # Check drivers exist
  missing_drivers <- setdiff(driver_vars, names(data))
  if (length(missing_drivers) > 0) {
    keydriver_refuse(
      code = "DATA_DRIVERS_NOT_FOUND",
      title = "Driver Variables Not Found in Data",
      problem = paste0(length(missing_drivers), " driver variable(s) not found in data."),
      why_it_matters = "Cannot include missing drivers in the analysis.",
      how_to_fix = c(
        "Check variable names in config match data column names exactly",
        "Variable names are case-sensitive",
        "Review the list of missing variables below"
      ),
      expected = driver_vars,
      observed = names(data),
      missing = missing_drivers
    )
  }

  # Check sample size
  n_complete <- sum(complete.cases(data[, c(outcome_var, driver_vars)]))
  n_drivers <- length(driver_vars)
  min_n <- max(30L, 10L * n_drivers)

  if (n_complete < min_n) {
    keydriver_refuse(
      code = "DATA_INSUFFICIENT_SAMPLE",
      title = "Insufficient Sample Size",
      problem = paste0("Only ", n_complete, " complete cases. Need at least ", min_n, " for ", n_drivers, " drivers."),
      why_it_matters = "Insufficient sample size produces unreliable importance estimates.",
      how_to_fix = c(
        "Increase sample size (collect more data)",
        "Reduce number of drivers",
        "Address missing data issues",
        paste0("Rule: need at least 10 cases per driver, minimum 30")
      ),
      details = paste0("Complete cases: ", n_complete, "\nRequired minimum: ", min_n)
    )
  }

  # Check for zero-variance variables
  all_vars <- c(outcome_var, driver_vars)
  for (var in all_vars) {
    if (is.numeric(data[[var]])) {
      var_sd <- sd(data[[var]], na.rm = TRUE)
      if (!is.na(var_sd) && var_sd == 0) {
        if (var == outcome_var) {
          keydriver_refuse(
            code = "DATA_OUTCOME_ZERO_VARIANCE",
            title = "Outcome Has No Variance",
            problem = paste0("Outcome variable '", var, "' has zero variance (all values identical)."),
            why_it_matters = "Cannot model a constant outcome - there is nothing to explain.",
            how_to_fix = "Check that your outcome variable has variation in its values."
          )
        } else {
          guard$zero_variance_drivers <- c(guard$zero_variance_drivers, var)
          guard <- guard_flag_stability(guard, paste0("Zero variance: ", var))
        }
      }
    }
  }

  # Refuse if any zero-variance drivers
  if (length(guard$zero_variance_drivers) > 0) {
    keydriver_refuse(
      code = "DATA_DRIVERS_ZERO_VARIANCE",
      title = "Driver Variables Have No Variance",
      problem = paste0(length(guard$zero_variance_drivers), " driver variable(s) have zero variance."),
      why_it_matters = "Variables with no variance cannot predict anything and cause model failures.",
      how_to_fix = c(
        "Remove these variables from your driver list",
        "Or check your data for issues",
        "These variables have identical values for all respondents"
      ),
      missing = guard$zero_variance_drivers
    )
  }

  guard
}


# ==============================================================================
# KEYDRIVER MAPPING VALIDATION (for model coefficients)
# ==============================================================================

#' Validate Model Coefficient Mapping
#'
#' Ensures all model coefficients can be mapped back to driver variables.
#'
#' @param model Fitted model
#' @param driver_vars Expected driver variables
#' @param guard Guard state
#' @return Updated guard state
#' @keywords internal
validate_keydriver_mapping <- function(model, driver_vars, guard) {

  # Get model coefficient names
  coef_names <- names(coef(model))

  # Remove intercept
  coef_names <- coef_names[coef_names != "(Intercept)"]

  # Each coefficient should correspond to a driver
  # For continuous drivers, coef name = driver name
  unmapped <- setdiff(coef_names, driver_vars)

  if (length(unmapped) > 0) {
    # This shouldn't happen for continuous key driver, but check anyway
    guard <- guard_warn(guard,
      paste0("Unmapped model terms: ", paste(unmapped, collapse = ", ")),
      "mapping"
    )
    guard <- guard_flag_stability(guard, "Model has unmapped coefficients")
  }

  guard
}
