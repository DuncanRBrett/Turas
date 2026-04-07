# ==============================================================================
# CATEGORICAL KEY DRIVER - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.1 integration for the Categorical Key Driver module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - catdriver_refuse() - module-specific refusal wrapper
#   - catdriver_guard_init() - initialize guard state with CatDriver-specific fields
#   - Validation helpers for CatDriver-specific requirements
#
# Related:
#   - modules/shared/lib/trs_refusal.R - shared TRS infrastructure
#
# Version: 1.1 (TRS Integration)
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# CATDRIVER-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (CatDriver)
#'
#' CatDriver-specific wrapper around turas_refuse() that provides
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
catdriver_refuse <- function(code,
                             title,
                             problem,
                             why_it_matters,
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
    module = "CATDRIVER"
  )
}


#' Run Categorical Key Driver Analysis with Refusal Handler
#'
#' Wraps CatDriver execution with TRS refusal handling.
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
catdriver_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "CATDRIVER")

  # Add CatDriver-specific class for compatibility
  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("catdriver_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# CATDRIVER GUARD STATE
# ==============================================================================

#' Initialize CatDriver Guard State
#'
#' Creates guard state with CatDriver-specific tracking fields.
#'
#' @return Guard state list
#' @export
catdriver_guard_init <- function() {
  guard <- guard_init(module = "CATDRIVER")

  # Add CatDriver-specific fields
  guard$collapsed_levels <- list()
  guard$dropped_predictors <- character(0)
  guard$missing_handled <- list()
  guard$separation_detected <- FALSE
  guard$data_modifications <- list()
  guard$encoding_issues <- list()

  guard
}


#' Record Collapsed Levels
#'
#' Records when rare factor levels have been collapsed into a combined
#' category.
#'
#' @param guard Guard state object
#' @param variable Variable name whose levels were collapsed
#' @param original_levels Character vector of original rare levels
#' @param collapsed_to Name of the level they were collapsed into
#' @return Updated guard state
#' @keywords internal
guard_record_collapse <- function(guard, variable, original_levels, collapsed_to) {
  guard$collapsed_levels[[variable]] <- list(
    original = original_levels,
    collapsed_to = collapsed_to
  )
  guard <- guard_flag_stability(guard, paste0("Rare levels collapsed in ", variable))
  guard
}


#' Record Dropped Predictor
#'
#' Records when a predictor variable was excluded from analysis.
#'
#' @param guard Guard state object
#' @param variable Predictor variable name
#' @param reason Reason for exclusion
#' @return Updated guard state
#' @keywords internal
guard_record_dropped <- function(guard, variable, reason) {
  guard$dropped_predictors <- c(guard$dropped_predictors, variable)
  guard <- guard_warn(guard, paste0("Dropped predictor: ", variable, " (", reason, ")"), "dropped")
  guard
}


#' Record Separation Detection
#'
#' Records when perfect or quasi-complete separation has been detected.
#'
#' @param guard Guard state object
#' @param details Optional description of which variables or levels exhibit separation
#' @return Updated guard state
#' @keywords internal
guard_record_separation <- function(guard, details = NULL) {
  guard$separation_detected <- TRUE
  guard <- guard_flag_stability(guard, "Perfect or quasi-separation detected")
  if (!is.null(details)) {
    guard <- guard_warn(guard, details, "separation")
  }
  guard
}


#' Record Fallback Estimator Usage
#'
#' Records when the primary estimation engine failed and a fallback was used.
#'
#' @param guard Guard state object
#' @param primary_engine Name of the primary engine that failed
#' @param fallback_engine Name of the fallback engine used
#' @param reason Explanation of why the primary engine failed
#' @return Updated guard state
#' @keywords internal
guard_record_fallback <- function(guard, primary_engine, fallback_engine, reason) {
  guard$fallback_used <- TRUE
  guard$fallback_reason <- reason
  guard <- guard_flag_stability(guard, paste0("Fallback estimator used: ", fallback_engine))
  guard <- guard_warn(guard,
    paste0("Primary engine (", primary_engine, ") failed: ", reason, "; used ", fallback_engine),
    "fallback"
  )
  guard
}


#' Record Data Modification
#'
#' Records any modifications made to input data for full transparency.
#'
#' @param guard Guard state object
#' @param type Category of modification (e.g., "level_collapse", "missing_impute")
#' @param details Description of the specific modification
#' @return Updated guard state
#' @keywords internal
guard_record_modification <- function(guard, type, details) {
  guard$data_modifications[[type]] <- c(guard$data_modifications[[type]], list(details))
  guard
}


#' Record Encoding Issue
#'
#' Records when a variable has encoding issues during data preparation.
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param issue Description of the encoding issue
#' @return Updated guard state
#' @keywords internal
guard_record_encoding_issue <- function(guard, variable, issue) {
  if (is.null(guard$encoding_issues)) guard$encoding_issues <- list()
  guard$encoding_issues[[length(guard$encoding_issues) + 1]] <- list(
    variable = variable,
    issue = issue
  )
  guard <- guard_warn(guard, paste0("Encoding issue: ", variable, " - ", issue), "encoding")
  guard
}


#' Get CatDriver Guard Summary
#'
#' Creates comprehensive summary including CatDriver-specific fields.
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
catdriver_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  # Add CatDriver-specific fields
  summary$collapsed_levels <- guard$collapsed_levels
  summary$dropped_predictors <- guard$dropped_predictors
  summary$separation_detected <- isTRUE(guard$separation_detected)
  summary$data_modifications <- guard$data_modifications
  summary$encoding_issues <- guard$encoding_issues

  # Update has_issues
  summary$has_issues <- summary$has_issues ||
                        length(guard$collapsed_levels) > 0 ||
                        length(guard$dropped_predictors) > 0 ||
                        isTRUE(guard$separation_detected) ||
                        length(guard$encoding_issues) > 0

  summary
}


# ==============================================================================
# CATDRIVER VALIDATION GATES
# ==============================================================================

#' Validate CatDriver Configuration
#'
#' Hard validation gate for CatDriver config. Refuses if critical issues found.
#'
#' @param config Configuration list
#' @keywords internal
validate_catdriver_config <- function(config) {

  # Check outcome variable is specified
  if (is.null(config$outcome_var) || length(config$outcome_var) == 0) {
    catdriver_refuse(
      code = "CFG_OUTCOME_MISSING",
      title = "No Outcome Variable Defined",
      problem = "The configuration does not specify an outcome (dependent) variable.",
      why_it_matters = "Categorical key driver analysis requires an outcome variable to analyze.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Ensure one variable has Type='Outcome'",
        "The outcome should be a categorical variable"
      )
    )
  }

  # Check outcome type is declared
  if (is.null(config$outcome_type) || config$outcome_type == "auto") {
    catdriver_refuse(
      code = "CFG_OUTCOME_TYPE_MISSING",
      title = "Outcome Type Not Declared",
      problem = "The 'outcome_type' setting is missing or set to 'auto'.",
      why_it_matters = "Auto-detection can select the wrong model type, producing misleading results.",
      how_to_fix = c(
        "Add 'outcome_type' to the Settings sheet",
        "Valid values: binary, ordinal, multinomial"
      )
    )
  }

  # Check outcome type is valid
  valid_types <- c("binary", "ordinal", "multinomial")
  if (!is.null(config$outcome_type) && !config$outcome_type %in% valid_types) {
    catdriver_refuse(
      code = "CFG_OUTCOME_TYPE_INVALID",
      title = "Invalid Outcome Type",
      problem = paste0("outcome_type='", config$outcome_type, "' is not recognized."),
      why_it_matters = "Unknown outcome types cannot be analyzed.",
      how_to_fix = paste0("Change outcome_type to one of: ", paste(valid_types, collapse = ", "))
    )
  }

  # Check driver variables are specified
  if (is.null(config$driver_vars) || length(config$driver_vars) == 0) {
    catdriver_refuse(
      code = "CFG_DRIVERS_MISSING",
      title = "No Driver Variables Defined",
      problem = "The configuration does not specify any driver (independent) variables.",
      why_it_matters = "Categorical key driver analysis requires driver variables to determine their importance.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Set Type='Driver' for each independent variable",
        "You need at least 2 driver variables for meaningful analysis"
      )
    )
  }

  # Check minimum drivers
  if (length(config$driver_vars) < 2) {
    catdriver_refuse(
      code = "CFG_INSUFFICIENT_DRIVERS",
      title = "Insufficient Driver Variables",
      problem = paste0("Only ", length(config$driver_vars), " driver variable specified. Need at least 2."),
      why_it_matters = "Key driver analysis compares relative importance across multiple drivers.",
      how_to_fix = "Add more driver variables to the Variables sheet (Type='Driver')."
    )
  }

  invisible(TRUE)
}


#' Validate CatDriver Data
#'
#' Hard validation gate for data. Refuses if critical issues found.
#' Note: named guard_validate_data_hard to avoid collision with the soft
#' diagnostics version in 02_validation.R (validate_catdriver_data).
#'
#' @param data Data frame
#' @param config Configuration list
#' @param guard Guard state for tracking warnings
#' @return Updated guard state
#' @keywords internal
guard_validate_data_hard <- function(data, config, guard) {

  outcome_var <- config$outcome_var
  driver_vars <- config$driver_vars

  # Check outcome exists
  if (!outcome_var %in% names(data)) {
    catdriver_refuse(
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
    catdriver_refuse(
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
    catdriver_refuse(
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

  # Check outcome has sufficient levels for declared type
  outcome_levels <- unique(as.character(na.omit(data[[outcome_var]])))
  n_levels <- length(outcome_levels)

  if (n_levels < 2) {
    catdriver_refuse(
      code = "DATA_OUTCOME_INSUFFICIENT_LEVELS",
      title = "Outcome Has Insufficient Levels",
      problem = paste0("Outcome variable '", outcome_var, "' has only ", n_levels, " level(s)."),
      why_it_matters = "Categorical key driver analysis requires at least 2 outcome categories.",
      how_to_fix = "Check that your outcome variable has variation in its values."
    )
  }

  if (!is.null(config$outcome_type) && config$outcome_type == "binary" && n_levels != 2) {
    catdriver_refuse(
      code = "DATA_OUTCOME_NOT_BINARY",
      title = "Outcome Is Not Binary",
      problem = paste0("outcome_type='binary' but outcome has ", n_levels, " levels."),
      why_it_matters = "Binary logistic regression requires exactly 2 outcome categories.",
      how_to_fix = c(
        "Change outcome_type to 'ordinal' or 'multinomial' for multi-level outcomes",
        "Or recode the outcome to 2 categories"
      ),
      observed = outcome_levels
    )
  }

  guard
}


# ==============================================================================
# CATDRIVER MAPPING VALIDATION (for model coefficients)
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
validate_catdriver_mapping <- function(model, driver_vars, guard) {

  # Get model coefficient names
  coef_names <- names(coef(model))

  # Remove intercept(s) - categorical models may have multiple threshold terms
  coef_names <- coef_names[!grepl("^\\(Intercept\\)|^[0-9]+\\|[0-9]+$", coef_names)]

  # Each coefficient should correspond to a driver
  unmapped <- setdiff(coef_names, driver_vars)
  missing <- setdiff(driver_vars, coef_names)

  # TRS: Unmapped or missing terms is a HARD REFUSAL
  if (length(unmapped) > 0 || length(missing) > 0) {
    catdriver_refuse(
      code = "MAPPER_COEFFICIENT_MISMATCH",
      title = "Coefficient Mapping Failed",
      problem = "Model coefficients do not match expected driver variables.",
      why_it_matters = paste0(
        "Unmapped coefficients cannot be attributed to drivers. ",
        "This would produce wrong or incomplete importance scores."
      ),
      how_to_fix = c(
        if (length(unmapped) > 0) paste0("Check why these coefficients are in the model: ", paste(unmapped, collapse = ", ")),
        if (length(missing) > 0) paste0("Check why these drivers are missing: ", paste(missing, collapse = ", ")),
        "Ensure all driver variables have variation and valid factor levels"
      ),
      expected = driver_vars,
      observed = coef_names,
      missing = if (length(missing) > 0) missing else NULL
    )
  }

  guard
}


# ==============================================================================
# CATDRIVER FEATURE PACKAGE CHECKS (TRS v1.1)
# ==============================================================================

#' Check Feature Package Availability
#'
#' Validates that required packages for optional features are available.
#' Should be called during guard phase, not at runtime.
#'
#' @param config Configuration list
#' @param guard Guard state object
#' @return Updated guard state with package status
#' @keywords internal
guard_check_feature_packages <- function(config, guard) {
  # Check ordinal model packages
  if (!is.null(config$outcome_type) && config$outcome_type == "ordinal") {
    for (pkg in c("ordinal", "MASS")) {
      if (!requireNamespace(pkg, quietly = TRUE)) {
        guard <- guard_warn(guard,
          paste0("Ordinal models require package '", pkg, "' which is not installed"), "packages")
      }
    }
  }

  # Check multinomial model packages
  if (!is.null(config$outcome_type) && config$outcome_type == "multinomial") {
    if (!requireNamespace("nnet", quietly = TRUE)) {
      guard <- guard_warn(guard,
        "Multinomial models require 'nnet' which is not installed", "packages")
    }
  }

  guard
}
