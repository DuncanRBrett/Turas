# ==============================================================================
# PREFLIGHT VALIDATORS - TURAS Catdriver Module
# ==============================================================================
# Cross-referential validation between config, variables, driver settings,
# and actual data. Catches configuration mistakes before analysis begins.
#
# VERSION HISTORY:
# V1.0 - Initial creation (2026-03-08)
#        - 15 cross-referential checks
#        - Integrates into validate_catdriver_preflight() pipeline
#
# DEPENDENCIES:
# - log_issue() from modules/shared/lib/logging_utils.R
#   OR create_error_log() / log_issue() must be available in the session
#
# USAGE:
#   source("modules/shared/lib/logging_utils.R")
#   source("modules/catdriver/lib/validation/preflight_validators.R")
#   error_log <- create_error_log()
#   error_log <- validate_catdriver_preflight(config, data, variables_df,
#                                             driver_settings_df, error_log)
#
# FUNCTIONS EXPORTED:
# - log_preflight_issue()                   - Logging helper
# - check_outcome_variable_in_data()        - Outcome exists in data
# - check_driver_variables_in_data()        - Drivers exist in data
# - check_weight_variable_in_data()         - Weight variable valid
# - check_outcome_type_vs_data()            - Outcome type matches data
# - check_driver_settings_complete()        - Driver_Settings completeness
# - check_ordinal_levels_order()            - Ordinal levels_order specified
# - check_levels_order_vs_data()            - levels_order values match data
# - check_reference_levels_valid()          - Reference levels exist in data
# - check_multinomial_mode_set()            - Multinomial mode required
# - check_target_outcome_level()            - one_vs_all target level valid
# - check_subgroup_variable()               - Subgroup variable valid
# - check_sample_size_adequate()            - Sample size sufficient
# - check_rare_categories()                 - Rare driver categories
# - check_sparse_cells()                    - Sparse outcome x driver cells
# - check_missing_data_rates()              - Per-variable missing rates
# - validate_catdriver_preflight()          - Main orchestrator
# ==============================================================================


# ==============================================================================
# LOGGING HELPER
# ==============================================================================

#' Log a preflight issue to the error log
#'
#' Convenience wrapper around log_issue() that automatically sets the
#' Component to "Preflight" and provides a consistent interface for
#' all catdriver preflight checks.
#'
#' @param error_log Data frame, error log to append to
#' @param issue_type Character, type/category of issue
#' @param description Character, detailed description of the issue
#' @param question_code Character, related variable name (default: "")
#' @param severity Character, "Error", "Warning", or "Info" (default: "Warning")
#' @return Data frame, updated error log
#' @keywords internal
log_preflight_issue <- function(error_log, issue_type, description,
                                question_code = "", severity = "Warning") {
  log_issue(
    error_log = error_log,
    component = "Preflight",
    issue_type = issue_type,
    description = description,
    question_code = question_code,
    severity = severity
  )
}


# ==============================================================================
# CHECK 1: Outcome variable exists in data
# ==============================================================================

#' Check Outcome Variable Exists in Data
#'
#' Verifies that the variable marked as Type=Outcome in the Variables sheet
#' exists as a column in the actual data.
#'
#' @param variables_df Data frame, Variables sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_outcome_variable_in_data <- function(variables_df, data, error_log) {
  outcome_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Outcome", ]

  if (nrow(outcome_rows) == 0) {
    error_log <- log_preflight_issue(
      error_log, "Missing Outcome Variable",
      "No variable with Type='Outcome' found in Variables sheet. Exactly one outcome variable is required.",
      severity = "Error"
    )
    return(error_log)
  }

  if (nrow(outcome_rows) > 1) {
    error_log <- log_preflight_issue(
      error_log, "Multiple Outcome Variables",
      sprintf("Found %d variables with Type='Outcome': %s. Exactly one outcome variable is supported.",
              nrow(outcome_rows),
              paste(outcome_rows$VariableName, collapse = ", ")),
      severity = "Error"
    )
  }

  data_cols <- names(data)
  for (i in seq_len(nrow(outcome_rows))) {
    var_name <- trimws(outcome_rows$VariableName[i])
    if (!var_name %in% data_cols) {
      error_log <- log_preflight_issue(
        error_log, "Outcome Not in Data",
        sprintf("Outcome variable '%s' not found as a column in the data file. Check the variable name matches exactly (case-sensitive).",
                var_name),
        question_code = var_name,
        severity = "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 2: Driver variables exist in data
# ==============================================================================

#' Check Driver Variables Exist in Data
#'
#' Verifies that all variables marked as Type=Driver in the Variables sheet
#' exist as columns in the actual data.
#'
#' @param variables_df Data frame, Variables sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_driver_variables_in_data <- function(variables_df, data, error_log) {
  driver_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Driver", ]

  if (nrow(driver_rows) == 0) {
    error_log <- log_preflight_issue(
      error_log, "No Driver Variables",
      "No variables with Type='Driver' found in Variables sheet. At least one driver variable is required.",
      severity = "Error"
    )
    return(error_log)
  }

  data_cols <- names(data)
  missing_drivers <- character(0)

  for (i in seq_len(nrow(driver_rows))) {
    var_name <- trimws(driver_rows$VariableName[i])
    if (!var_name %in% data_cols) {
      missing_drivers <- c(missing_drivers, var_name)
    }
  }

  if (length(missing_drivers) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Drivers Not in Data",
      sprintf("%d driver variable(s) not found in data: %s. Check variable names match exactly (case-sensitive).",
              length(missing_drivers),
              paste(missing_drivers, collapse = ", ")),
      question_code = paste(missing_drivers, collapse = ", "),
      severity = "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 3: Weight variable exists and is valid
# ==============================================================================

#' Check Weight Variable in Data
#'
#' If a weight variable is defined, verifies it exists in the data,
#' is numeric, and has valid (non-negative, non-NA) values.
#'
#' @param variables_df Data frame, Variables sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_weight_variable_in_data <- function(variables_df, data, error_log) {
  weight_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Weight", ]

  # Weight is optional - no error if not present

  if (nrow(weight_rows) == 0) return(error_log)

  if (nrow(weight_rows) > 1) {
    error_log <- log_preflight_issue(
      error_log, "Multiple Weight Variables",
      sprintf("Found %d variables with Type='Weight': %s. Only one weight variable is supported.",
              nrow(weight_rows),
              paste(weight_rows$VariableName, collapse = ", ")),
      severity = "Error"
    )
  }

  weight_name <- trimws(weight_rows$VariableName[1])
  data_cols <- names(data)

  if (!weight_name %in% data_cols) {
    error_log <- log_preflight_issue(
      error_log, "Weight Not in Data",
      sprintf("Weight variable '%s' not found as a column in the data file.", weight_name),
      question_code = weight_name,
      severity = "Error"
    )
    return(error_log)
  }

  # Check weight values are numeric
  weight_vals <- data[[weight_name]]
  numeric_vals <- suppressWarnings(as.numeric(weight_vals))
  n_non_numeric <- sum(is.na(numeric_vals) & !is.na(weight_vals))

  if (n_non_numeric > 0) {
    error_log <- log_preflight_issue(
      error_log, "Non-Numeric Weights",
      sprintf("Weight variable '%s' has %d non-numeric values. Weights must be numeric.",
              weight_name, n_non_numeric),
      question_code = weight_name,
      severity = "Error"
    )
    return(error_log)
  }

  # Check for negative weights
  valid_weights <- numeric_vals[!is.na(numeric_vals)]
  if (length(valid_weights) > 0 && any(valid_weights < 0)) {
    n_negative <- sum(valid_weights < 0)
    error_log <- log_preflight_issue(
      error_log, "Negative Weights",
      sprintf("Weight variable '%s' contains %d negative value(s). Weights must be non-negative.",
              weight_name, n_negative),
      question_code = weight_name,
      severity = "Error"
    )
  }

  # Check for zero weights (warning only)
  if (length(valid_weights) > 0 && any(valid_weights == 0)) {
    n_zero <- sum(valid_weights == 0)
    error_log <- log_preflight_issue(
      error_log, "Zero Weights",
      sprintf("Weight variable '%s' contains %d zero-weight observation(s). These rows will have no influence on the analysis.",
              weight_name, n_zero),
      question_code = weight_name,
      severity = "Warning"
    )
  }

  # Check for all-NA weights
  if (all(is.na(weight_vals))) {
    error_log <- log_preflight_issue(
      error_log, "All Weights Missing",
      sprintf("Weight variable '%s' contains only NA values. Cannot apply weighting.", weight_name),
      question_code = weight_name,
      severity = "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 4: Outcome type matches data values
# ==============================================================================

#' Check Outcome Type vs Data
#'
#' Validates that the configured outcome_type is consistent with the actual
#' unique values found in the outcome variable. Binary requires exactly 2
#' unique non-NA values; ordinal and multinomial require 3 or more.
#'
#' @param config List, configuration object
#' @param variables_df Data frame, Variables sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_outcome_type_vs_data <- function(config, variables_df, data, error_log) {
  outcome_type <- config$outcome_type
  if (is.null(outcome_type) || is.na(outcome_type) || trimws(outcome_type) == "") {
    # outcome_type is required; will be caught by config validation
    return(error_log)
  }
  outcome_type <- trimws(tolower(outcome_type))

  # Get outcome variable name
  outcome_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Outcome", ]
  if (nrow(outcome_rows) == 0) return(error_log)

  outcome_var <- trimws(outcome_rows$VariableName[1])
  if (!outcome_var %in% names(data)) return(error_log)

  outcome_vals <- data[[outcome_var]]
  unique_vals <- unique(outcome_vals[!is.na(outcome_vals)])
  n_unique <- length(unique_vals)

  if (outcome_type == "binary") {
    if (n_unique != 2) {
      error_log <- log_preflight_issue(
        error_log, "Binary Outcome Mismatch",
        sprintf("outcome_type='binary' but outcome variable '%s' has %d unique non-NA values (expected exactly 2). Values found: %s",
                outcome_var, n_unique,
                paste(utils::head(as.character(unique_vals), 10), collapse = ", ")),
        question_code = outcome_var,
        severity = "Error"
      )
    }
  } else if (outcome_type == "ordinal") {
    if (n_unique < 3) {
      error_log <- log_preflight_issue(
        error_log, "Ordinal Outcome Too Few Levels",
        sprintf("outcome_type='ordinal' but outcome variable '%s' has only %d unique non-NA values (expected 3 or more). Consider using 'binary' if only 2 levels.",
                outcome_var, n_unique),
        question_code = outcome_var,
        severity = "Error"
      )
    }
  } else if (outcome_type == "multinomial") {
    if (n_unique < 3) {
      error_log <- log_preflight_issue(
        error_log, "Multinomial Outcome Too Few Levels",
        sprintf("outcome_type='multinomial' but outcome variable '%s' has only %d unique non-NA values (expected 3 or more). Consider using 'binary' if only 2 levels.",
                outcome_var, n_unique),
        question_code = outcome_var,
        severity = "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 5: Driver_Settings completeness
# ==============================================================================

#' Check Driver Settings Complete
#'
#' Verifies that every variable with Type=Driver in the Variables sheet has
#' a corresponding row in the Driver_Settings sheet.
#'
#' @param variables_df Data frame, Variables sheet
#' @param driver_settings_df Data frame, Driver_Settings sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_driver_settings_complete <- function(variables_df, driver_settings_df, error_log) {
  driver_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Driver", ]
  if (nrow(driver_rows) == 0) return(error_log)

  driver_names <- trimws(driver_rows$VariableName)

  if (is.null(driver_settings_df) || nrow(driver_settings_df) == 0) {
    error_log <- log_preflight_issue(
      error_log, "Driver_Settings Empty",
      sprintf("Driver_Settings sheet is empty but %d driver variable(s) are defined: %s. Each driver needs a row in Driver_Settings.",
              length(driver_names),
              paste(driver_names, collapse = ", ")),
      severity = "Error"
    )
    return(error_log)
  }

  settings_drivers <- trimws(driver_settings_df$driver)
  settings_drivers <- settings_drivers[!is.na(settings_drivers) & settings_drivers != ""]

  # Drivers without settings
  missing_settings <- setdiff(driver_names, settings_drivers)
  if (length(missing_settings) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Missing Driver Settings",
      sprintf("%d driver(s) defined in Variables but missing from Driver_Settings: %s. Add a row for each driver.",
              length(missing_settings),
              paste(missing_settings, collapse = ", ")),
      question_code = paste(missing_settings, collapse = ", "),
      severity = "Error"
    )
  }

  # Settings for non-existent drivers (warning)
  extra_settings <- setdiff(settings_drivers, driver_names)
  if (length(extra_settings) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Orphaned Driver Settings",
      sprintf("%d row(s) in Driver_Settings have no matching Driver in Variables: %s. These will be ignored.",
              length(extra_settings),
              paste(extra_settings, collapse = ", ")),
      question_code = paste(extra_settings, collapse = ", "),
      severity = "Warning"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 6: Ordinal levels_order specified
# ==============================================================================

#' Check Ordinal Levels Order
#'
#' Verifies that drivers with type=ordinal in Driver_Settings have a
#' non-empty levels_order specified.
#'
#' @param driver_settings_df Data frame, Driver_Settings sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_ordinal_levels_order <- function(driver_settings_df, error_log) {
  if (is.null(driver_settings_df) || nrow(driver_settings_df) == 0) return(error_log)

  ordinal_rows <- driver_settings_df[
    !is.na(driver_settings_df$type) & trimws(tolower(driver_settings_df$type)) == "ordinal", ]

  if (nrow(ordinal_rows) == 0) return(error_log)

  for (i in seq_len(nrow(ordinal_rows))) {
    driver_name <- trimws(ordinal_rows$driver[i])
    levels_order <- ordinal_rows$levels_order[i]

    if (is.na(levels_order) || trimws(levels_order) == "") {
      error_log <- log_preflight_issue(
        error_log, "Missing Ordinal Levels Order",
        sprintf("Driver '%s' has type='ordinal' but no levels_order specified. Ordinal drivers require semicolon-separated level order (LOW to HIGH).",
                driver_name),
        question_code = driver_name,
        severity = "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 7: levels_order values exist in data
# ==============================================================================

#' Check Levels Order vs Data
#'
#' For drivers with levels_order specified, verifies that all specified
#' levels actually exist in the data values.
#'
#' @param driver_settings_df Data frame, Driver_Settings sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_levels_order_vs_data <- function(driver_settings_df, data, error_log) {
  if (is.null(driver_settings_df) || nrow(driver_settings_df) == 0) return(error_log)

  data_cols <- names(data)

  for (i in seq_len(nrow(driver_settings_df))) {
    driver_name <- trimws(driver_settings_df$driver[i])
    levels_order <- driver_settings_df$levels_order[i]

    # Skip if no levels_order or driver not in data
    if (is.na(levels_order) || trimws(levels_order) == "") next
    if (!driver_name %in% data_cols) next

    specified_levels <- trimws(unlist(strsplit(levels_order, ";")))
    specified_levels <- specified_levels[specified_levels != ""]

    if (length(specified_levels) == 0) next

    actual_values <- unique(as.character(data[[driver_name]]))
    actual_values <- actual_values[!is.na(actual_values) & actual_values != ""]

    # Specified levels not in data
    missing_levels <- setdiff(specified_levels, actual_values)
    if (length(missing_levels) > 0) {
      error_log <- log_preflight_issue(
        error_log, "Levels Order Mismatch",
        sprintf("Driver '%s': levels_order specifies %d value(s) not found in data: %s. Actual data values: %s",
                driver_name, length(missing_levels),
                paste(missing_levels, collapse = ", "),
                paste(utils::head(actual_values, 10), collapse = ", ")),
        question_code = driver_name,
        severity = "Warning"
      )
    }

    # Data values not in specified levels (may indicate uncovered categories)
    unlisted_values <- setdiff(actual_values, specified_levels)
    if (length(unlisted_values) > 0) {
      error_log <- log_preflight_issue(
        error_log, "Unspecified Data Values",
        sprintf("Driver '%s': data contains %d value(s) not listed in levels_order: %s. These will be treated as unordered.",
                driver_name, length(unlisted_values),
                paste(utils::head(unlisted_values, 10), collapse = ", ")),
        question_code = driver_name,
        severity = "Warning"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 8: Reference levels valid
# ==============================================================================

#' Check Reference Levels Valid
#'
#' Verifies that specified reference_level values in Driver_Settings
#' actually exist in the corresponding data column.
#'
#' @param driver_settings_df Data frame, Driver_Settings sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_reference_levels_valid <- function(driver_settings_df, data, error_log) {
  if (is.null(driver_settings_df) || nrow(driver_settings_df) == 0) return(error_log)

  data_cols <- names(data)

  for (i in seq_len(nrow(driver_settings_df))) {
    driver_name <- trimws(driver_settings_df$driver[i])
    ref_level <- driver_settings_df$reference_level[i]

    # Skip if no reference_level specified or driver not in data
    if (is.na(ref_level) || trimws(ref_level) == "") next
    if (!driver_name %in% data_cols) next

    ref_level <- trimws(ref_level)
    actual_values <- unique(as.character(data[[driver_name]]))
    actual_values <- actual_values[!is.na(actual_values) & actual_values != ""]

    if (!ref_level %in% actual_values) {
      error_log <- log_preflight_issue(
        error_log, "Invalid Reference Level",
        sprintf("Driver '%s': reference_level='%s' not found in data values. Available values: %s",
                driver_name, ref_level,
                paste(utils::head(actual_values, 10), collapse = ", ")),
        question_code = driver_name,
        severity = "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 9: Multinomial mode set when required
# ==============================================================================

#' Check Multinomial Mode Set
#'
#' If outcome_type is 'multinomial', verifies that multinomial_mode is
#' specified in the config.
#'
#' @param config List, configuration object
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_multinomial_mode_set <- function(config, error_log) {
  outcome_type <- config$outcome_type
  if (is.null(outcome_type) || is.na(outcome_type)) return(error_log)
  outcome_type <- trimws(tolower(outcome_type))

  if (outcome_type != "multinomial") return(error_log)

  multinomial_mode <- config$multinomial_mode
  if (is.null(multinomial_mode) || is.na(multinomial_mode) || trimws(multinomial_mode) == "") {
    error_log <- log_preflight_issue(
      error_log, "Missing Multinomial Mode",
      "outcome_type='multinomial' but multinomial_mode is not set. Must be one of: baseline_category, all_pairwise, one_vs_all, per_outcome.",
      severity = "Error"
    )
  } else {
    valid_modes <- c("baseline_category", "all_pairwise", "one_vs_all", "per_outcome")
    if (!trimws(tolower(multinomial_mode)) %in% valid_modes) {
      error_log <- log_preflight_issue(
        error_log, "Invalid Multinomial Mode",
        sprintf("multinomial_mode='%s' is not valid. Must be one of: %s",
                multinomial_mode, paste(valid_modes, collapse = ", ")),
        severity = "Error"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 10: Target outcome level for one_vs_all
# ==============================================================================

#' Check Target Outcome Level
#'
#' If multinomial_mode is 'one_vs_all', verifies that target_outcome_level
#' is set and exists in the actual outcome data values.
#'
#' @param config List, configuration object
#' @param variables_df Data frame, Variables sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_target_outcome_level <- function(config, variables_df, data, error_log) {
  multinomial_mode <- config$multinomial_mode
  if (is.null(multinomial_mode) || is.na(multinomial_mode)) return(error_log)
  multinomial_mode <- trimws(tolower(multinomial_mode))

  if (multinomial_mode != "one_vs_all") return(error_log)

  target_level <- config$target_outcome_level
  if (is.null(target_level) || is.na(target_level) || trimws(target_level) == "") {
    error_log <- log_preflight_issue(
      error_log, "Missing Target Outcome Level",
      "multinomial_mode='one_vs_all' but target_outcome_level is not set. Specify which outcome level to compare against all others.",
      severity = "Error"
    )
    return(error_log)
  }

  target_level <- trimws(target_level)

  # Verify target level exists in data
  outcome_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Outcome", ]
  if (nrow(outcome_rows) == 0) return(error_log)

  outcome_var <- trimws(outcome_rows$VariableName[1])
  if (!outcome_var %in% names(data)) return(error_log)

  actual_values <- unique(as.character(data[[outcome_var]]))
  actual_values <- actual_values[!is.na(actual_values) & actual_values != ""]

  if (!target_level %in% actual_values) {
    error_log <- log_preflight_issue(
      error_log, "Invalid Target Outcome Level",
      sprintf("target_outcome_level='%s' not found in outcome variable '%s'. Available values: %s",
              target_level, outcome_var,
              paste(utils::head(actual_values, 10), collapse = ", ")),
      question_code = outcome_var,
      severity = "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 11: Subgroup variable validation
# ==============================================================================

#' Check Subgroup Variable
#'
#' If subgroup_var is specified, verifies it is not the outcome or a driver,
#' exists in the data, and has at least 2 unique non-NA values.
#'
#' @param config List, configuration object
#' @param variables_df Data frame, Variables sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_subgroup_variable <- function(config, variables_df, data, error_log) {
  subgroup_var <- config$subgroup_var
  if (is.null(subgroup_var) || is.na(subgroup_var) || trimws(subgroup_var) == "") {
    return(error_log)
  }
  subgroup_var <- trimws(subgroup_var)

  # Check it exists in data
  if (!subgroup_var %in% names(data)) {
    error_log <- log_preflight_issue(
      error_log, "Subgroup Variable Not in Data",
      sprintf("subgroup_var='%s' not found as a column in the data file.", subgroup_var),
      question_code = subgroup_var,
      severity = "Error"
    )
    return(error_log)
  }

  # Check it is not an outcome or driver variable
  analysis_vars <- trimws(variables_df$VariableName[
    !is.na(variables_df$Type) & trimws(variables_df$Type) %in% c("Outcome", "Driver")])

  if (subgroup_var %in% analysis_vars) {
    var_type <- trimws(variables_df$Type[
      !is.na(variables_df$VariableName) & trimws(variables_df$VariableName) == subgroup_var])[1]
    error_log <- log_preflight_issue(
      error_log, "Subgroup Is Analysis Variable",
      sprintf("subgroup_var='%s' is already defined as a %s variable. The subgroup variable must be separate from outcome and driver variables.",
              subgroup_var, var_type),
      question_code = subgroup_var,
      severity = "Error"
    )
  }

  # Check for at least 2 unique non-NA values
  subgroup_vals <- data[[subgroup_var]]
  unique_vals <- unique(subgroup_vals[!is.na(subgroup_vals)])
  if (length(unique_vals) < 2) {
    error_log <- log_preflight_issue(
      error_log, "Subgroup Insufficient Levels",
      sprintf("subgroup_var='%s' has only %d unique non-NA value(s). At least 2 subgroups are required for comparison.",
              subgroup_var, length(unique_vals)),
      question_code = subgroup_var,
      severity = "Error"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 12: Sample size adequacy
# ==============================================================================

#' Check Sample Size Adequate
#'
#' Verifies that the total sample size (complete cases across all analysis
#' variables) meets the min_sample_size threshold. Also warns if the number
#' of events per parameter is below 10 (rule of thumb for logistic regression).
#'
#' @param config List, configuration object
#' @param data Data frame, survey data
#' @param variables_df Data frame, Variables sheet
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_sample_size_adequate <- function(config, data, variables_df, error_log) {
  min_n <- config$min_sample_size
  if (is.null(min_n) || is.na(min_n)) min_n <- 30
  min_n <- as.numeric(min_n)

  # Get all analysis variable names
  analysis_rows <- variables_df[
    !is.na(variables_df$Type) &
    trimws(variables_df$Type) %in% c("Outcome", "Driver"), ]

  if (nrow(analysis_rows) == 0) return(error_log)

  analysis_vars <- trimws(analysis_rows$VariableName)
  analysis_vars_in_data <- intersect(analysis_vars, names(data))

  if (length(analysis_vars_in_data) == 0) return(error_log)

  # Count complete cases across all analysis variables
  complete_mask <- complete.cases(data[, analysis_vars_in_data, drop = FALSE])
  n_complete <- sum(complete_mask)

  if (n_complete < min_n) {
    error_log <- log_preflight_issue(
      error_log, "Insufficient Sample Size",
      sprintf("Complete cases across all analysis variables: %d (minimum required: %d). Consider reducing the number of drivers or handling missing data.",
              n_complete, min_n),
      severity = "Error"
    )
  }

  # Events-per-parameter check (rule of thumb: EPP >= 10)
  outcome_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Outcome", ]
  if (nrow(outcome_rows) == 0) return(error_log)

  outcome_var <- trimws(outcome_rows$VariableName[1])
  if (!outcome_var %in% names(data)) return(error_log)

  # Count outcome levels (for estimating parameters)
  outcome_vals <- data[[outcome_var]][complete_mask]
  outcome_levels <- unique(outcome_vals[!is.na(outcome_vals)])
  n_outcome_levels <- length(outcome_levels)

  if (n_outcome_levels < 2) return(error_log)

  # Estimate number of parameters: each driver contributes (levels - 1) parameters
  # For the outcome: (outcome_levels - 1) intercepts
  driver_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Driver", ]
  n_params <- 0
  for (j in seq_len(nrow(driver_rows))) {
    d_name <- trimws(driver_rows$VariableName[j])
    if (d_name %in% names(data)) {
      d_vals <- data[[d_name]][complete_mask]
      n_driver_levels <- length(unique(d_vals[!is.na(d_vals)]))
      n_params <- n_params + max(n_driver_levels - 1, 1)
    }
  }

  if (n_params > 0) {
    # Minimum events = smallest outcome category count
    outcome_counts <- table(outcome_vals[!is.na(outcome_vals)])
    min_events <- min(outcome_counts)
    epp <- min_events / n_params

    if (epp < 10) {
      error_log <- log_preflight_issue(
        error_log, "Low Events Per Parameter",
        sprintf("Events-per-parameter ratio = %.1f (smallest outcome category: %d, estimated parameters: %d). Recommended minimum is 10. Model estimates may be unstable.",
                epp, min_events, n_params),
        severity = "Warning"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 13: Rare categories
# ==============================================================================

#' Check Rare Categories
#'
#' Flags driver categories that have fewer observations than the
#' rare_level_threshold.
#'
#' @param config List, configuration object
#' @param driver_settings_df Data frame, Driver_Settings sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_rare_categories <- function(config, driver_settings_df, data, error_log) {
  threshold <- config$rare_level_threshold
  if (is.null(threshold) || is.na(threshold)) threshold <- 10
  threshold <- as.numeric(threshold)

  if (is.null(driver_settings_df) || nrow(driver_settings_df) == 0) return(error_log)

  data_cols <- names(data)

  for (i in seq_len(nrow(driver_settings_df))) {
    driver_name <- trimws(driver_settings_df$driver[i])
    if (is.na(driver_name) || driver_name == "") next
    if (!driver_name %in% data_cols) next

    driver_vals <- data[[driver_name]]
    driver_vals <- driver_vals[!is.na(driver_vals)]

    if (length(driver_vals) == 0) next

    category_counts <- table(driver_vals)
    rare_cats <- names(category_counts)[category_counts < threshold]

    if (length(rare_cats) > 0) {
      rare_detail <- paste(
        sprintf("'%s' (n=%d)", rare_cats, category_counts[rare_cats]),
        collapse = ", "
      )
      error_log <- log_preflight_issue(
        error_log, "Rare Driver Categories",
        sprintf("Driver '%s' has %d category(ies) below rare_level_threshold (%d): %s",
                driver_name, length(rare_cats), threshold, rare_detail),
        question_code = driver_name,
        severity = "Warning"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 14: Sparse outcome x driver cells
# ==============================================================================

#' Check Sparse Cells
#'
#' Checks cross-tabulation cells between the outcome variable and each
#' driver variable for counts below the rare_cell_threshold. Sparse cells
#' can cause model convergence issues.
#'
#' @param config List, configuration object
#' @param variables_df Data frame, Variables sheet
#' @param driver_settings_df Data frame, Driver_Settings sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_sparse_cells <- function(config, variables_df, driver_settings_df, data, error_log) {
  cell_threshold <- config$rare_cell_threshold
  if (is.null(cell_threshold) || is.na(cell_threshold)) cell_threshold <- 5
  cell_threshold <- as.numeric(cell_threshold)

  # Get outcome variable
  outcome_rows <- variables_df[
    !is.na(variables_df$Type) & trimws(variables_df$Type) == "Outcome", ]
  if (nrow(outcome_rows) == 0) return(error_log)

  outcome_var <- trimws(outcome_rows$VariableName[1])
  if (!outcome_var %in% names(data)) return(error_log)

  if (is.null(driver_settings_df) || nrow(driver_settings_df) == 0) return(error_log)

  data_cols <- names(data)

  for (i in seq_len(nrow(driver_settings_df))) {
    driver_name <- trimws(driver_settings_df$driver[i])
    if (is.na(driver_name) || driver_name == "") next
    if (!driver_name %in% data_cols) next

    # Build cross-tabulation (drop NAs)
    complete_idx <- !is.na(data[[outcome_var]]) & !is.na(data[[driver_name]])
    if (sum(complete_idx) == 0) next

    cross_tab <- table(
      outcome = data[[outcome_var]][complete_idx],
      driver = data[[driver_name]][complete_idx]
    )

    # Find cells below threshold
    sparse_cells <- which(cross_tab < cell_threshold & cross_tab > 0, arr.ind = TRUE)
    if (nrow(sparse_cells) > 0) {
      n_sparse <- nrow(sparse_cells)
      # Report up to 5 examples
      examples <- character(0)
      for (j in seq_len(min(n_sparse, 5))) {
        r <- sparse_cells[j, 1]
        c_idx <- sparse_cells[j, 2]
        examples <- c(examples,
                      sprintf("%s x %s (n=%d)",
                              rownames(cross_tab)[r],
                              colnames(cross_tab)[c_idx],
                              cross_tab[r, c_idx]))
      }
      suffix <- if (n_sparse > 5) sprintf(" ... and %d more", n_sparse - 5) else ""

      error_log <- log_preflight_issue(
        error_log, "Sparse Cross-Tab Cells",
        sprintf("Driver '%s': %d outcome x driver cell(s) have count below %d: %s%s. May cause model instability.",
                driver_name, n_sparse, cell_threshold,
                paste(examples, collapse = "; "), suffix),
        question_code = driver_name,
        severity = "Warning"
      )
    }

    # Flag completely empty cells (zero observations)
    zero_cells <- which(cross_tab == 0, arr.ind = TRUE)
    if (nrow(zero_cells) > 0) {
      n_zero <- nrow(zero_cells)
      examples <- character(0)
      for (j in seq_len(min(n_zero, 5))) {
        r <- zero_cells[j, 1]
        c_idx <- zero_cells[j, 2]
        examples <- c(examples,
                      sprintf("%s x %s",
                              rownames(cross_tab)[r],
                              colnames(cross_tab)[c_idx]))
      }
      suffix <- if (n_zero > 5) sprintf(" ... and %d more", n_zero - 5) else ""

      error_log <- log_preflight_issue(
        error_log, "Empty Cross-Tab Cells",
        sprintf("Driver '%s': %d outcome x driver cell(s) have zero observations: %s%s. Complete separation may prevent model convergence.",
                driver_name, n_zero,
                paste(examples, collapse = "; "), suffix),
        question_code = driver_name,
        severity = "Warning"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 15: Missing data rates
# ==============================================================================

#' Check Missing Data Rates
#'
#' Checks per-variable missing data percentage against the missing_threshold.
#' Variables exceeding the threshold are flagged.
#'
#' @param config List, configuration object
#' @param variables_df Data frame, Variables sheet
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_missing_data_rates <- function(config, variables_df, data, error_log) {
  max_missing_pct <- config$missing_threshold
  if (is.null(max_missing_pct) || is.na(max_missing_pct)) max_missing_pct <- 50
  max_missing_pct <- as.numeric(max_missing_pct)

  analysis_rows <- variables_df[
    !is.na(variables_df$Type) &
    trimws(variables_df$Type) %in% c("Outcome", "Driver", "Weight"), ]

  if (nrow(analysis_rows) == 0) return(error_log)

  n_total <- nrow(data)
  if (n_total == 0) return(error_log)

  high_missing_vars <- character(0)

  for (i in seq_len(nrow(analysis_rows))) {
    var_name <- trimws(analysis_rows$VariableName[i])
    var_type <- trimws(analysis_rows$Type[i])

    if (!var_name %in% names(data)) next

    n_missing <- sum(is.na(data[[var_name]]))
    pct_missing <- 100 * n_missing / n_total

    if (pct_missing > max_missing_pct) {
      severity <- if (var_type == "Outcome") "Error" else "Warning"
      error_log <- log_preflight_issue(
        error_log, "High Missing Rate",
        sprintf("Variable '%s' (%s) has %.1f%% missing values (%d of %d). Threshold is %.0f%%.",
                var_name, var_type, pct_missing, n_missing, n_total, max_missing_pct),
        question_code = var_name,
        severity = severity
      )
      high_missing_vars <- c(high_missing_vars, var_name)
    } else if (pct_missing > 0 && pct_missing <= max_missing_pct) {
      # Informational note for any missing data
      if (pct_missing > 10) {
        error_log <- log_preflight_issue(
          error_log, "Notable Missing Rate",
          sprintf("Variable '%s' (%s) has %.1f%% missing values (%d of %d). Within threshold but may affect analysis.",
                  var_name, var_type, pct_missing, n_missing, n_total),
          question_code = var_name,
          severity = "Info"
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# PREFLIGHT ORCHESTRATOR
# ==============================================================================

#' Run Catdriver Pre-Flight Validation Checks
#'
#' Cross-references config, variables, driver settings, and data to catch
#' configuration mistakes before analysis begins. Runs 15 checks covering
#' variable existence, type consistency, reference validity, sample adequacy,
#' rare categories, sparse cells, and missing data.
#'
#' @param config List, configuration object (from Settings sheet)
#' @param data Data frame, survey data
#' @param variables_df Data frame, Variables sheet
#' @param driver_settings_df Data frame, Driver_Settings sheet (can be NULL)
#' @param error_log Data frame, error log. If NULL, creates a new one.
#' @param verbose Logical, print progress messages (default: TRUE)
#'
#' @return Updated error_log data frame
#'
#' @examples
#' \dontrun{
#'   error_log <- create_error_log()
#'   error_log <- validate_catdriver_preflight(config, data, variables_df,
#'                                             driver_settings_df, error_log)
#'   n_errors <- sum(error_log$Severity == "Error")
#'   if (n_errors > 0) {
#'     cat(sprintf("Found %d error(s). Resolve before running analysis.\n", n_errors))
#'   }
#' }
#'
#' @export
validate_catdriver_preflight <- function(config, data, variables_df,
                                          driver_settings_df, error_log = NULL,
                                          verbose = TRUE) {
  # Initialize error log if not provided
  if (is.null(error_log)) {
    error_log <- create_error_log()
  }

  if (verbose) {
    cat("  Catdriver pre-flight cross-reference checks...\n")
  }

  # --- Variable existence checks ---

  # 1. Outcome variable exists in data
  error_log <- check_outcome_variable_in_data(variables_df, data, error_log)

  # 2. Driver variables exist in data
  error_log <- check_driver_variables_in_data(variables_df, data, error_log)

  # 3. Weight variable valid
  error_log <- check_weight_variable_in_data(variables_df, data, error_log)

  # --- Type consistency checks ---

  # 4. Outcome type vs data values
  error_log <- check_outcome_type_vs_data(config, variables_df, data, error_log)

  # --- Driver settings checks ---

  # 5. Driver_Settings completeness
  error_log <- check_driver_settings_complete(variables_df, driver_settings_df, error_log)

  # 6. Ordinal levels_order specified
  error_log <- check_ordinal_levels_order(driver_settings_df, error_log)

  # 7. levels_order values match data
  error_log <- check_levels_order_vs_data(driver_settings_df, data, error_log)

  # 8. Reference levels valid
  error_log <- check_reference_levels_valid(driver_settings_df, data, error_log)

  # --- Multinomial checks ---

  # 9. Multinomial mode set when required
  error_log <- check_multinomial_mode_set(config, error_log)

  # 10. Target outcome level for one_vs_all
  error_log <- check_target_outcome_level(config, variables_df, data, error_log)

  # --- Subgroup checks ---

  # 11. Subgroup variable valid
  error_log <- check_subgroup_variable(config, variables_df, data, error_log)

  # --- Sample quality checks ---

  # 12. Sample size adequate
  error_log <- check_sample_size_adequate(config, data, variables_df, error_log)

  # 13. Rare driver categories
  error_log <- check_rare_categories(config, driver_settings_df, data, error_log)

  # 14. Sparse outcome x driver cells
  error_log <- check_sparse_cells(config, variables_df, driver_settings_df, data, error_log)

  # 15. Missing data rates
  error_log <- check_missing_data_rates(config, variables_df, data, error_log)

  # --- Summary ---
  if (verbose) {
    n_preflight <- sum(error_log$Component == "Preflight")
    n_errors <- sum(error_log$Component == "Preflight" & error_log$Severity == "Error")
    n_warnings <- sum(error_log$Component == "Preflight" & error_log$Severity == "Warning")
    n_info <- sum(error_log$Component == "Preflight" & error_log$Severity == "Info")

    if (n_preflight == 0) {
      cat("  \u2714 All 15 pre-flight checks passed\n")
    } else {
      cat(sprintf("  Pre-flight found %d issue(s): %d error(s), %d warning(s), %d info\n",
                  n_preflight, n_errors, n_warnings, n_info))

      # Print boxed summary for errors (visible in Shiny console)
      if (n_errors > 0) {
        preflight_errors <- error_log[error_log$Component == "Preflight" &
                                       error_log$Severity == "Error", , drop = FALSE]

        cat("\n\u250C\u2500\u2500\u2500 CATDRIVER PRE-FLIGHT CHECK FAILED \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n")
        for (i in seq_len(nrow(preflight_errors))) {
          cat(sprintf("\u2502 [%d] %s\n", i, preflight_errors$IssueType[i]))
          # Wrap long descriptions
          desc <- preflight_errors$Description[i]
          desc_lines <- strwrap(desc, width = 52, prefix = "\u2502     ")
          cat(paste(desc_lines, collapse = "\n"), "\n")
        }
        cat("\u2502\n")
        cat(sprintf("\u2502 %d of 15 checks failed. Fix errors above before\n", n_errors))
        cat("\u2502 running the analysis.\n")
        cat("\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n\n")
      }

      # Print warnings in a lighter format
      if (n_warnings > 0) {
        preflight_warnings <- error_log[error_log$Component == "Preflight" &
                                         error_log$Severity == "Warning", , drop = FALSE]
        cat("  Pre-flight warnings (analysis will proceed):\n")
        for (i in seq_len(nrow(preflight_warnings))) {
          var_str <- if (nzchar(preflight_warnings$QuestionCode[i]))
            sprintf(" [%s]", preflight_warnings$QuestionCode[i]) else ""
          cat(sprintf("    \u26A0 %s%s\n", preflight_warnings$IssueType[i], var_str))
        }
        cat("\n")
      }
    }
  }

  return(error_log)
}
