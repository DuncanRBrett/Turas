# ==============================================================================
# PREFLIGHT VALIDATORS - TURAS Key Driver Analysis Module
# ==============================================================================
# Cross-referential validation between config, variables, and data files.
# Catches configuration mistakes before analysis begins.
#
# VERSION HISTORY:
# V1.0 - Initial creation (2026-03-08)
#        - 14 cross-referential checks
#        - Integrates into validate_keydriver_preflight() pipeline
#
# USAGE:
#   source("modules/keydriver/lib/validation/preflight_validators.R")
#   error_log <- validate_keydriver_preflight(config, data, variables_df,
#                                             segments_df, stated_df)
#
# FUNCTIONS EXPORTED:
# - check_outcome_in_data()          - Outcome variable existence & type
# - check_drivers_in_data()          - Driver variables existence
# - check_weight_in_data()           - Weight variable validity
# - check_driver_type_specified()    - DriverType completeness
# - check_categorical_aggregation()  - Aggregation method for categoricals
# - check_reference_levels_valid()   - Reference levels exist in data
# - check_sample_size_rule()         - Minimum sample size
# - check_zero_variance_drivers()    - Zero-variance detection
# - check_collinearity_warning()     - High inter-driver correlation
# - check_segment_variables()        - Segment variable existence
# - check_stated_importance_drivers()- StatedImportance/Variables alignment
# - check_shap_dependencies()        - SHAP package availability
# - check_quadrant_requirements()    - Quadrant pre-conditions
# - check_feature_policies_valid()   - On-fail policy validation
# - validate_keydriver_preflight()   - Main orchestrator function
# ==============================================================================


# ==============================================================================
# HELPER: log_preflight_issue
# ==============================================================================

#' Log a preflight validation issue
#'
#' Appends a row to the error log data frame with standardised columns.
#'
#' @param error_log Data frame (or NULL) serving as the running issue log.
#' @param check_name Character. Short name of the check that raised the issue.
#' @param message Character. Human-readable description of the problem.
#' @param severity Character. One of "Error", "Warning", or "Info".
#' @param field Character. Optional field or variable name associated with the issue.
#'
#' @return Updated error_log data frame with the new row appended.
#' @keywords internal
log_preflight_issue <- function(error_log, check_name, message,
                                 severity = "Error", field = "") {
  new_row <- data.frame(
    Component  = "Preflight",
    Check      = check_name,
    Field      = field,
    Message    = message,
    Severity   = severity,
    stringsAsFactors = FALSE
  )

  if (is.null(error_log) || nrow(error_log) == 0) {
    return(new_row)
  }

  rbind(error_log, new_row)
}


# ==============================================================================
# INITIALISE EMPTY ERROR LOG
# ==============================================================================

#' Create an empty preflight error log
#'
#' @return An empty data frame with the standard preflight log columns.
#' @keywords internal
init_preflight_log <- function() {
  data.frame(
    Component  = character(0),
    Check      = character(0),
    Field      = character(0),
    Message    = character(0),
    Severity   = character(0),
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# CHECK 1: Outcome variable exists in data and is numeric
# ==============================================================================

#' Check Outcome Variable in Data
#'
#' Verifies that exactly one Outcome variable is defined, that it exists as a
#' column in the data, and that it is numeric.
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_outcome_in_data <- function(variables_df, data, error_log) {
  outcome_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "OUTCOME", ]

  if (nrow(outcome_rows) == 0) {
    error_log <- log_preflight_issue(
      error_log, "Outcome Variable",
      "No variable with Type='Outcome' found in Variables sheet. Exactly one outcome variable is required.",
      severity = "Error"
    )
    return(error_log)
  }

  if (nrow(outcome_rows) > 1) {
    error_log <- log_preflight_issue(
      error_log, "Outcome Variable",
      sprintf("Multiple Outcome variables defined: %s. Exactly one is required.",
              paste(outcome_rows$VariableName, collapse = ", ")),
      severity = "Error"
    )
    return(error_log)
  }

  outcome_var <- trimws(outcome_rows$VariableName[1])

  # Check existence in data
  if (!outcome_var %in% names(data)) {
    error_log <- log_preflight_issue(
      error_log, "Outcome Variable",
      sprintf("Outcome variable '%s' not found in data columns.", outcome_var),
      severity = "Error",
      field = outcome_var
    )
    return(error_log)
  }

  # Check numeric type
  vals <- data[[outcome_var]]
  numeric_vals <- suppressWarnings(as.numeric(vals))
  n_non_numeric <- sum(is.na(numeric_vals) & !is.na(vals))

  if (n_non_numeric > 0) {
    pct <- round(100 * n_non_numeric / sum(!is.na(vals)), 1)
    error_log <- log_preflight_issue(
      error_log, "Outcome Variable",
      sprintf("Outcome variable '%s' has %d non-numeric values (%.1f%%). The outcome must be numeric.",
              outcome_var, n_non_numeric, pct),
      severity = "Error",
      field = outcome_var
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 2: All Driver variables exist in data
# ==============================================================================

#' Check Driver Variables in Data
#'
#' Verifies that all variables with Type='Driver' exist as columns in the data.
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_drivers_in_data <- function(variables_df, data, error_log) {
  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER", ]

  if (nrow(driver_rows) == 0) {
    error_log <- log_preflight_issue(
      error_log, "Driver Variables",
      "No variables with Type='Driver' found in Variables sheet. At least one driver is required.",
      severity = "Error"
    )
    return(error_log)
  }

  driver_names <- trimws(driver_rows$VariableName)
  data_cols <- names(data)
  missing_drivers <- setdiff(driver_names, data_cols)

  if (length(missing_drivers) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Driver Variables",
      sprintf("%d driver variable(s) not found in data: %s",
              length(missing_drivers),
              paste(missing_drivers, collapse = ", ")),
      severity = "Error",
      field = paste(missing_drivers, collapse = ", ")
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 3: Weight variable exists, is numeric, > 0, no NaN/Inf
# ==============================================================================

#' Check Weight Variable in Data
#'
#' If a Weight variable is specified, verifies it exists in data, is numeric,
#' contains only positive finite values, and has no NaN or Inf entries.
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_weight_in_data <- function(variables_df, data, error_log) {
  weight_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "WEIGHT", ]

  # Weight is optional - if none defined, skip

  if (nrow(weight_rows) == 0) {
    return(error_log)
  }

  if (nrow(weight_rows) > 1) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable",
      sprintf("Multiple Weight variables defined: %s. At most one is allowed.",
              paste(weight_rows$VariableName, collapse = ", ")),
      severity = "Error"
    )
    return(error_log)
  }

  weight_var <- trimws(weight_rows$VariableName[1])

  # Check existence
  if (!weight_var %in% names(data)) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable",
      sprintf("Weight variable '%s' not found in data columns.", weight_var),
      severity = "Error",
      field = weight_var
    )
    return(error_log)
  }

  # Check numeric
  vals <- data[[weight_var]]
  numeric_vals <- suppressWarnings(as.numeric(vals))
  n_non_numeric <- sum(is.na(numeric_vals) & !is.na(vals))

  if (n_non_numeric > 0) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable",
      sprintf("Weight variable '%s' has %d non-numeric values. Weights must be numeric.",
              weight_var, n_non_numeric),
      severity = "Error",
      field = weight_var
    )
    return(error_log)
  }

  # Check for NaN
  valid_vals <- numeric_vals[!is.na(numeric_vals)]
  n_nan <- sum(is.nan(valid_vals))
  if (n_nan > 0) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable",
      sprintf("Weight variable '%s' contains %d NaN value(s). Weights must be finite positive numbers.",
              weight_var, n_nan),
      severity = "Error",
      field = weight_var
    )
  }

  # Check for Inf
  n_inf <- sum(is.infinite(valid_vals))
  if (n_inf > 0) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable",
      sprintf("Weight variable '%s' contains %d Inf value(s). Weights must be finite positive numbers.",
              weight_var, n_inf),
      severity = "Error",
      field = weight_var
    )
  }

  # Check > 0 (exclude NaN and Inf for this check)
  finite_vals <- valid_vals[is.finite(valid_vals)]
  n_non_positive <- sum(finite_vals <= 0)
  if (n_non_positive > 0) {
    error_log <- log_preflight_issue(
      error_log, "Weight Variable",
      sprintf("Weight variable '%s' contains %d value(s) <= 0. All weights must be strictly positive.",
              weight_var, n_non_positive),
      severity = "Error",
      field = weight_var
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 4: DriverType column present; all drivers have valid DriverType
# ==============================================================================

#' Check Driver Type Specified
#'
#' Verifies that the DriverType column exists in the Variables sheet and that
#' every Driver has a valid DriverType value (continuous, ordinal, or categorical).
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_driver_type_specified <- function(variables_df, error_log) {
  # Check DriverType column exists
  if (!"DriverType" %in% names(variables_df)) {
    error_log <- log_preflight_issue(
      error_log, "Driver Type",
      "DriverType column is missing from the Variables sheet. Each driver must specify its scale type.",
      severity = "Error"
    )
    return(error_log)
  }

  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER", ]

  if (nrow(driver_rows) == 0) return(error_log)

  valid_types <- c("continuous", "ordinal", "categorical")

  for (i in seq_len(nrow(driver_rows))) {
    var_name <- trimws(driver_rows$VariableName[i])
    driver_type <- driver_rows$DriverType[i]

    if (is.na(driver_type) || trimws(driver_type) == "") {
      error_log <- log_preflight_issue(
        error_log, "Driver Type",
        sprintf("Driver '%s' has no DriverType specified. Must be one of: %s",
                var_name, paste(valid_types, collapse = ", ")),
        severity = "Error",
        field = var_name
      )
    } else if (!tolower(trimws(driver_type)) %in% valid_types) {
      error_log <- log_preflight_issue(
        error_log, "Driver Type",
        sprintf("Driver '%s' has invalid DriverType '%s'. Must be one of: %s",
                var_name, driver_type, paste(valid_types, collapse = ", ")),
        severity = "Error",
        field = var_name
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 5: Categorical drivers have AggregationMethod specified
# ==============================================================================

#' Check Categorical Aggregation Method
#'
#' Verifies that categorical drivers have an AggregationMethod specified.
#' Defaults to partial_r2 if not provided (warning, not error).
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_categorical_aggregation <- function(variables_df, error_log) {
  if (!"DriverType" %in% names(variables_df)) return(error_log)
  if (!"AggregationMethod" %in% names(variables_df)) return(error_log)

  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER", ]

  cat_drivers <- driver_rows[
    !is.na(driver_rows$DriverType) &
    tolower(trimws(driver_rows$DriverType)) == "categorical", ]

  if (nrow(cat_drivers) == 0) return(error_log)

  valid_methods <- c("partial_r2", "grouped_permutation", "grouped_shapley")

  for (i in seq_len(nrow(cat_drivers))) {
    var_name <- trimws(cat_drivers$VariableName[i])
    agg_method <- cat_drivers$AggregationMethod[i]

    if (is.na(agg_method) || trimws(agg_method) == "") {
      error_log <- log_preflight_issue(
        error_log, "Categorical Aggregation",
        sprintf("Categorical driver '%s' has no AggregationMethod specified. Will default to 'partial_r2'.",
                var_name),
        severity = "Warning",
        field = var_name
      )
    } else if (!tolower(trimws(agg_method)) %in% valid_methods) {
      error_log <- log_preflight_issue(
        error_log, "Categorical Aggregation",
        sprintf("Categorical driver '%s' has invalid AggregationMethod '%s'. Must be one of: %s",
                var_name, agg_method, paste(valid_methods, collapse = ", ")),
        severity = "Error",
        field = var_name
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 6: Reference levels exist in data for categorical/ordinal drivers
# ==============================================================================

#' Check Reference Levels Valid
#'
#' Verifies that ReferenceLevel values (where specified) exist as actual values
#' in the data for categorical or ordinal driver variables.
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_reference_levels_valid <- function(variables_df, data, error_log) {
  if (!"ReferenceLevel" %in% names(variables_df)) return(error_log)
  if (!"DriverType" %in% names(variables_df)) return(error_log)

  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER", ]

  # Only check categorical and ordinal drivers with a ReferenceLevel specified
  ref_drivers <- driver_rows[
    !is.na(driver_rows$ReferenceLevel) &
    trimws(driver_rows$ReferenceLevel) != "" &
    !is.na(driver_rows$DriverType) &
    tolower(trimws(driver_rows$DriverType)) %in% c("categorical", "ordinal"), ]

  if (nrow(ref_drivers) == 0) return(error_log)

  for (i in seq_len(nrow(ref_drivers))) {
    var_name <- trimws(ref_drivers$VariableName[i])
    ref_level <- trimws(ref_drivers$ReferenceLevel[i])

    # Skip if variable not in data (caught by check_drivers_in_data)
    if (!var_name %in% names(data)) next

    actual_values <- as.character(unique(data[[var_name]]))
    actual_values <- actual_values[!is.na(actual_values)]

    if (!ref_level %in% actual_values) {
      error_log <- log_preflight_issue(
        error_log, "Reference Level",
        sprintf("Driver '%s' has ReferenceLevel='%s' which does not exist in the data. Actual values: %s",
                var_name, ref_level,
                paste(utils::head(sort(actual_values), 10), collapse = ", ")),
        severity = "Error",
        field = var_name
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 7: Sample size rule - n >= max(30, 10 * number_of_drivers)
# ==============================================================================

#' Check Sample Size Rule
#'
#' Verifies that the number of complete observations meets the minimum
#' requirement: n >= max(30, 10 * number_of_drivers). Warns if close to minimum.
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_sample_size_rule <- function(variables_df, data, error_log) {
  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER", ]
  outcome_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "OUTCOME", ]

  if (nrow(driver_rows) == 0 || nrow(outcome_rows) == 0) return(error_log)

  n_drivers <- nrow(driver_rows)
  min_required <- max(30, 10 * n_drivers)

  # Count complete cases across outcome + drivers that exist in data
  outcome_var <- trimws(outcome_rows$VariableName[1])
  driver_vars <- trimws(driver_rows$VariableName)
  all_vars <- c(outcome_var, driver_vars)
  vars_in_data <- intersect(all_vars, names(data))

  if (length(vars_in_data) == 0) return(error_log)

  n_complete <- sum(complete.cases(data[, vars_in_data, drop = FALSE]))

  if (n_complete < min_required) {
    error_log <- log_preflight_issue(
      error_log, "Sample Size",
      sprintf("Insufficient sample size: %d complete cases available, minimum required is %d (max(30, 10 * %d drivers)). Results may be unreliable.",
              n_complete, min_required, n_drivers),
      severity = "Error"
    )
  } else if (n_complete < min_required * 1.5) {
    error_log <- log_preflight_issue(
      error_log, "Sample Size",
      sprintf("Sample size is close to minimum: %d complete cases (minimum is %d for %d drivers). Consider reducing driver count or increasing sample.",
              n_complete, min_required, n_drivers),
      severity = "Warning"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 8: Zero-variance continuous/ordinal drivers
# ==============================================================================

#' Check Zero Variance Drivers
#'
#' Flags any continuous or ordinal numeric driver variables that have zero
#' variance (standard deviation = 0), as these cannot contribute to regression.
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_zero_variance_drivers <- function(variables_df, data, error_log) {
  if (!"DriverType" %in% names(variables_df)) return(error_log)

  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER" &
    !is.na(variables_df$DriverType) &
    tolower(trimws(variables_df$DriverType)) %in% c("continuous", "ordinal"), ]

  if (nrow(driver_rows) == 0) return(error_log)

  for (i in seq_len(nrow(driver_rows))) {
    var_name <- trimws(driver_rows$VariableName[i])

    if (!var_name %in% names(data)) next

    vals <- suppressWarnings(as.numeric(data[[var_name]]))
    vals <- vals[!is.na(vals)]

    if (length(vals) < 2) next

    if (sd(vals) == 0) {
      error_log <- log_preflight_issue(
        error_log, "Zero Variance",
        sprintf("Driver '%s' has zero variance (all values are %s). This variable cannot contribute to the analysis and should be removed.",
                var_name, as.character(vals[1])),
        severity = "Error",
        field = var_name
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 9: Collinearity warning (|correlation| > 0.9)
# ==============================================================================

#' Check Collinearity Warning
#'
#' Flags any pairs of continuous/ordinal numeric driver variables with
#' absolute Pearson correlation exceeding 0.9.
#'
#' @param variables_df Data frame from the Variables config sheet.
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_collinearity_warning <- function(variables_df, data, error_log) {
  if (!"DriverType" %in% names(variables_df)) return(error_log)

  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER" &
    !is.na(variables_df$DriverType) &
    tolower(trimws(variables_df$DriverType)) %in% c("continuous", "ordinal"), ]

  if (nrow(driver_rows) < 2) return(error_log)

  driver_vars <- trimws(driver_rows$VariableName)
  vars_in_data <- intersect(driver_vars, names(data))

  if (length(vars_in_data) < 2) return(error_log)

  # Build numeric matrix from available drivers
  numeric_mat <- as.data.frame(lapply(data[, vars_in_data, drop = FALSE], function(col) {
    suppressWarnings(as.numeric(col))
  }))

  # Compute pairwise correlations (complete obs)
  cor_mat <- suppressWarnings(
    cor(numeric_mat, use = "pairwise.complete.obs", method = "pearson")
  )

  if (is.null(cor_mat) || any(is.na(cor_mat))) {
    # If correlation matrix cannot be computed, replace NAs with 0
    cor_mat[is.na(cor_mat)] <- 0
  }

  # Check upper triangle for high correlations
  n_vars <- ncol(cor_mat)
  for (i in seq_len(n_vars - 1)) {
    for (j in (i + 1):n_vars) {
      r_val <- cor_mat[i, j]
      if (!is.na(r_val) && abs(r_val) > 0.9) {
        error_log <- log_preflight_issue(
          error_log, "Collinearity",
          sprintf("High collinearity between '%s' and '%s' (r = %.3f). Consider removing one to avoid multicollinearity issues.",
                  vars_in_data[i], vars_in_data[j], r_val),
          severity = "Warning",
          field = paste(vars_in_data[i], vars_in_data[j], sep = " / ")
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 10: Segment variables exist in data; segment values present
# ==============================================================================

#' Check Segment Variables
#'
#' Verifies that segment variables exist in the data and that the specified
#' segment values are actually present.
#'
#' @param segments_df Data frame from the Segments config sheet (may be NULL).
#' @param data Data frame of survey data.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_segment_variables <- function(segments_df, data, error_log) {
  if (is.null(segments_df) || !is.data.frame(segments_df) || nrow(segments_df) == 0) {
    return(error_log)
  }

  for (i in seq_len(nrow(segments_df))) {
    seg_name <- trimws(segments_df$segment_name[i])
    seg_var <- trimws(segments_df$segment_variable[i])
    seg_values_raw <- trimws(segments_df$segment_values[i])

    if (is.na(seg_var) || seg_var == "") next

    # Check variable exists in data
    if (!seg_var %in% names(data)) {
      error_log <- log_preflight_issue(
        error_log, "Segment Variables",
        sprintf("Segment '%s': variable '%s' not found in data columns.",
                seg_name, seg_var),
        severity = "Error",
        field = seg_var
      )
      next
    }

    # Check segment values are present in data
    if (!is.na(seg_values_raw) && seg_values_raw != "") {
      seg_values <- trimws(unlist(strsplit(seg_values_raw, ",")))
      actual_values <- as.character(unique(data[[seg_var]]))
      actual_values <- actual_values[!is.na(actual_values)]

      missing_values <- setdiff(seg_values, actual_values)
      if (length(missing_values) > 0) {
        error_log <- log_preflight_issue(
          error_log, "Segment Variables",
          sprintf("Segment '%s': value(s) not found in column '%s': %s. Actual values: %s",
                  seg_name, seg_var,
                  paste(missing_values, collapse = ", "),
                  paste(utils::head(sort(actual_values), 10), collapse = ", ")),
          severity = "Warning",
          field = seg_var
        )
      }
    }
  }

  return(error_log)
}


# ==============================================================================
# CHECK 11: StatedImportance drivers match Variables sheet drivers
# ==============================================================================

#' Check Stated Importance Drivers
#'
#' Verifies that driver names in the StatedImportance sheet match driver names
#' in the Variables sheet.
#'
#' @param stated_df Data frame from the StatedImportance config sheet (may be NULL).
#' @param variables_df Data frame from the Variables config sheet.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_stated_importance_drivers <- function(stated_df, variables_df, error_log) {
  if (is.null(stated_df) || !is.data.frame(stated_df) || nrow(stated_df) == 0) {
    return(error_log)
  }

  # Get defined drivers from Variables sheet
  driver_rows <- variables_df[
    !is.na(variables_df$Type) & toupper(trimws(variables_df$Type)) == "DRIVER", ]
  defined_drivers <- trimws(driver_rows$VariableName)

  # Get stated importance drivers
  stated_drivers <- trimws(stated_df$driver)
  stated_drivers <- stated_drivers[!is.na(stated_drivers) & stated_drivers != ""]

  # Stated drivers not in Variables
  missing_in_vars <- setdiff(stated_drivers, defined_drivers)
  if (length(missing_in_vars) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Stated Importance",
      sprintf("StatedImportance sheet references %d driver(s) not found in Variables sheet: %s",
              length(missing_in_vars),
              paste(missing_in_vars, collapse = ", ")),
      severity = "Error",
      field = paste(missing_in_vars, collapse = ", ")
    )
  }

  # Drivers without stated importance (informational)
  missing_stated <- setdiff(defined_drivers, stated_drivers)
  if (length(missing_stated) > 0) {
    error_log <- log_preflight_issue(
      error_log, "Stated Importance",
      sprintf("%d driver(s) in Variables sheet have no stated importance rating: %s",
              length(missing_stated),
              paste(missing_stated, collapse = ", ")),
      severity = "Info",
      field = paste(missing_stated, collapse = ", ")
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 12: SHAP dependencies available
# ==============================================================================

#' Check SHAP Dependencies
#'
#' When enable_shap is TRUE, verifies that the xgboost package is installed
#' and loadable.
#'
#' @param config List, configuration object.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_shap_dependencies <- function(config, error_log) {
  enable_shap <- config$enable_shap
  if (is.null(enable_shap)) return(error_log)

  # Normalise to logical
  if (is.character(enable_shap)) {
    enable_shap <- toupper(trimws(enable_shap)) == "TRUE"
  }

  if (!isTRUE(enable_shap)) return(error_log)

  if (!requireNamespace("xgboost", quietly = TRUE)) {
    error_log <- log_preflight_issue(
      error_log, "SHAP Dependencies",
      "enable_shap is TRUE but the 'xgboost' package is not installed. Install with: renv::install('xgboost')",
      severity = "Error",
      field = "enable_shap"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 13: Quadrant requirements (StatedImportance or importance_source)
# ==============================================================================

#' Check Quadrant Requirements
#'
#' When enable_quadrant is TRUE, verifies that either the StatedImportance
#' sheet is provided or importance_source is set to a derived method (not auto).
#'
#' @param config List, configuration object.
#' @param stated_df Data frame from the StatedImportance config sheet (may be NULL).
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_quadrant_requirements <- function(config, stated_df, error_log) {
  enable_quadrant <- config$enable_quadrant
  if (is.null(enable_quadrant)) return(error_log)

  # Normalise to logical
  if (is.character(enable_quadrant)) {
    enable_quadrant <- toupper(trimws(enable_quadrant)) == "TRUE"
  }

  if (!isTRUE(enable_quadrant)) return(error_log)

  has_stated <- !is.null(stated_df) && is.data.frame(stated_df) && nrow(stated_df) > 0

  importance_source <- config$importance_source
  if (is.null(importance_source) || trimws(importance_source) == "") {
    importance_source <- "auto"
  }

  # When importance_source is "auto", stated importance is needed for the
  # performance axis. Without it, quadrant analysis cannot place drivers.
  if (tolower(trimws(importance_source)) == "auto" && !has_stated) {
    error_log <- log_preflight_issue(
      error_log, "Quadrant Requirements",
      "enable_quadrant is TRUE and importance_source is 'auto', but no StatedImportance data is provided. Provide stated importance ratings or set importance_source to a derived method (shapley, relative, beta, or shap).",
      severity = "Error",
      field = "enable_quadrant"
    )
  }

  return(error_log)
}


# ==============================================================================
# CHECK 14: Feature on-fail policies valid
# ==============================================================================

#' Check Feature Policies Valid
#'
#' Verifies that shap_on_fail and quadrant_on_fail are set to valid values:
#' "refuse" or "continue_with_flag".
#'
#' @param config List, configuration object.
#' @param error_log Data frame, running error log.
#' @return Updated error_log.
#' @keywords internal
check_feature_policies_valid <- function(config, error_log) {
  valid_policies <- c("refuse", "continue_with_flag")

  # Check shap_on_fail
  shap_policy <- config$shap_on_fail
  if (!is.null(shap_policy) && !is.na(shap_policy) && trimws(shap_policy) != "") {
    if (!tolower(trimws(shap_policy)) %in% valid_policies) {
      error_log <- log_preflight_issue(
        error_log, "Feature Policies",
        sprintf("shap_on_fail='%s' is invalid. Must be one of: %s",
                shap_policy, paste(valid_policies, collapse = ", ")),
        severity = "Error",
        field = "shap_on_fail"
      )
    }
  }

  # Check quadrant_on_fail
  quadrant_policy <- config$quadrant_on_fail
  if (!is.null(quadrant_policy) && !is.na(quadrant_policy) && trimws(quadrant_policy) != "") {
    if (!tolower(trimws(quadrant_policy)) %in% valid_policies) {
      error_log <- log_preflight_issue(
        error_log, "Feature Policies",
        sprintf("quadrant_on_fail='%s' is invalid. Must be one of: %s",
                quadrant_policy, paste(valid_policies, collapse = ", ")),
        severity = "Error",
        field = "quadrant_on_fail"
      )
    }
  }

  return(error_log)
}


# ==============================================================================
# PREFLIGHT ORCHESTRATOR
# ==============================================================================

#' Run Key Driver Pre-Flight Validation Checks
#'
#' Cross-references config, variables, and data to catch configuration
#' mistakes before key driver analysis begins.
#'
#' @param config List, configuration object with feature flags and parameters.
#' @param data Data frame of survey data.
#' @param variables_df Data frame from the Variables config sheet.
#' @param segments_df Data frame from the Segments config sheet (NULL to skip).
#' @param stated_df Data frame from the StatedImportance config sheet (NULL to skip).
#' @param error_log Data frame, existing error log to append to (NULL to start fresh).
#' @param verbose Logical, print progress messages (default TRUE).
#'
#' @return Updated error_log data frame with all detected issues.
#'
#' @examples
#' \dontrun{
#'   log <- validate_keydriver_preflight(config, survey_data, variables_df)
#'   errors <- log[log$Severity == "Error", ]
#'   if (nrow(errors) > 0) {
#'     cat("Pre-flight errors found:\n")
#'     print(errors)
#'   }
#' }
#'
#' @export
validate_keydriver_preflight <- function(config, data, variables_df,
                                          segments_df = NULL,
                                          stated_df = NULL,
                                          error_log = NULL,
                                          verbose = TRUE) {
  if (verbose) {
    cat("  Key Driver pre-flight cross-reference checks...\n")
  }

  # Initialise error log if not provided
  if (is.null(error_log)) {
    error_log <- init_preflight_log()
  }

  # --- Core variable checks ---

  # 1. Outcome variable exists and is numeric
  error_log <- check_outcome_in_data(variables_df, data, error_log)

  # 2. All driver variables exist in data
  error_log <- check_drivers_in_data(variables_df, data, error_log)

  # 3. Weight variable validity
  error_log <- check_weight_in_data(variables_df, data, error_log)

  # 4. DriverType completeness
  error_log <- check_driver_type_specified(variables_df, error_log)

  # 5. Categorical aggregation method
  error_log <- check_categorical_aggregation(variables_df, error_log)

  # 6. Reference level validity
  error_log <- check_reference_levels_valid(variables_df, data, error_log)

  # --- Statistical checks ---

  # 7. Sample size rule
  error_log <- check_sample_size_rule(variables_df, data, error_log)

  # 8. Zero-variance drivers
  error_log <- check_zero_variance_drivers(variables_df, data, error_log)

  # 9. Collinearity warning
  error_log <- check_collinearity_warning(variables_df, data, error_log)

  # --- Optional sheet checks ---

  # 10. Segment variables
  error_log <- check_segment_variables(segments_df, data, error_log)

  # 11. Stated importance / Variables alignment
  error_log <- check_stated_importance_drivers(stated_df, variables_df, error_log)

  # --- Feature dependency checks ---

  # 12. SHAP dependencies
  error_log <- check_shap_dependencies(config, error_log)

  # 13. Quadrant requirements
  error_log <- check_quadrant_requirements(config, stated_df, error_log)

  # 14. Feature on-fail policies
  error_log <- check_feature_policies_valid(config, error_log)

  # --- Summary ---
  if (verbose) {
    n_preflight <- nrow(error_log[error_log$Component == "Preflight", ])
    n_errors <- sum(error_log$Component == "Preflight" & error_log$Severity == "Error")
    n_warnings <- sum(error_log$Component == "Preflight" & error_log$Severity == "Warning")
    n_info <- sum(error_log$Component == "Preflight" & error_log$Severity == "Info")

    if (n_preflight == 0) {
      cat("  All 14 pre-flight checks passed\n")
    } else {
      cat(sprintf("  Pre-flight found %d issue(s): %d error(s), %d warning(s), %d info\n",
                  n_preflight, n_errors, n_warnings, n_info))
    }

    # Console output for errors (Shiny visibility)
    if (n_errors > 0) {
      error_rows <- error_log[error_log$Component == "Preflight" &
                                error_log$Severity == "Error", ]
      cat("\n┌─── KEYDRIVER PREFLIGHT ERRORS ─────────────────────────┐\n")
      for (r in seq_len(nrow(error_rows))) {
        cat(sprintf("│ [%s] %s\n", error_rows$Check[r], error_rows$Message[r]))
      }
      cat("└────────────────────────────────────────────────────────┘\n\n")
    }
  }

  return(error_log)
}
