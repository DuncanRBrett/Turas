# ==============================================================================
# KEY DRIVER CONFIG LOADER
# ==============================================================================
#
# Version: Turas v10.2 (TRS Integration)
# Date: 2025-12
#
# NEW IN v10.2:
#   - TRS v1.0 integration: Refusal framework for config errors
#
# NEW IN v10.1:
#   - Support for Segments sheet
#   - Support for StatedImportance sheet
#   - Extended Settings for SHAP and Quadrant configuration
#
# ==============================================================================

#' Load Key Driver Configuration
#'
#' Loads and validates key driver analysis configuration.
#'
#' @param config_file Path to configuration Excel file
#' @param project_root Optional project root directory (defaults to config file directory)
#' @return List with validated configuration
#' @keywords internal
load_keydriver_config <- function(config_file, project_root = NULL) {

  if (!file.exists(config_file)) {
    keydriver_refuse(
      code = "IO_CONFIG_NOT_FOUND",
      title = "Configuration File Not Found",
      problem = paste0("Configuration file does not exist: ", config_file),
      why_it_matters = "Key driver analysis requires a configuration file to define variables and settings.",
      how_to_fix = c(
        "Check that the file path is correct",
        "Ensure the file exists at the specified location"
      )
    )
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }

  # Get available sheets
  available_sheets <- openxlsx::getSheetNames(config_file)

  # Load settings (required)
  if (!"Settings" %in% available_sheets) {
    keydriver_refuse(
      code = "CFG_SETTINGS_SHEET_MISSING",
      title = "Settings Sheet Missing",
      problem = "Required 'Settings' sheet not found in configuration file.",
      why_it_matters = "The Settings sheet defines essential analysis parameters.",
      how_to_fix = c(
        "Add a 'Settings' sheet to your config Excel file",
        "The sheet should have columns: Setting, Value"
      ),
      expected = "Settings",
      observed = available_sheets
    )
  }
  settings <- openxlsx::read.xlsx(config_file, sheet = "Settings")
  settings_list <- setNames(as.list(settings$Value), settings$Setting)

  # Extract and resolve file paths from settings
  data_file <- settings_list$data_file
  output_file <- settings_list$output_file

  # Resolve relative paths
  if (!is.null(data_file) && !is.na(data_file)) {
    if (!grepl("^(/|[A-Za-z]:)", data_file)) {
      # Relative path - resolve from project root
      data_file <- file.path(project_root, data_file)
    }
    data_file <- normalizePath(data_file, winslash = "/", mustWork = FALSE)
  }

  if (!is.null(output_file) && !is.na(output_file)) {
    if (!grepl("^(/|[A-Za-z]:)", output_file)) {
      # Relative path - resolve from project root
      output_file <- file.path(project_root, output_file)
    }
    output_file <- normalizePath(output_file, winslash = "/", mustWork = FALSE)
  }

  # Load variables definition (required)
  if (!"Variables" %in% available_sheets) {
    keydriver_refuse(
      code = "CFG_VARIABLES_SHEET_MISSING",
      title = "Variables Sheet Missing",
      problem = "Required 'Variables' sheet not found in configuration file.",
      why_it_matters = "The Variables sheet defines which variables are outcomes and drivers.",
      how_to_fix = c(
        "Add a 'Variables' sheet to your config Excel file",
        "The sheet must have columns: VariableName, Type, Label",
        "Set Type='Outcome' for your dependent variable",
        "Set Type='Driver' for independent variables"
      ),
      expected = "Variables",
      observed = available_sheets
    )
  }
  variables <- openxlsx::read.xlsx(config_file, sheet = "Variables")

  # Validate variables sheet
  required_cols <- c("VariableName", "Type", "Label")
  missing_cols <- setdiff(required_cols, names(variables))
  if (length(missing_cols) > 0) {
    keydriver_refuse(
      code = "CFG_VARIABLES_COLUMNS_MISSING",
      title = "Variables Sheet Missing Required Columns",
      problem = paste0("Variables sheet is missing required columns: ", paste(missing_cols, collapse = ", ")),
      why_it_matters = "These columns are needed to identify variables and their roles.",
      how_to_fix = "Add the missing columns to your Variables sheet.",
      expected = required_cols,
      observed = names(variables),
      missing = missing_cols
    )
  }

  # Extract outcome and driver variables
  outcome_vars <- variables$VariableName[variables$Type == "Outcome"]
  driver_vars <- variables$VariableName[variables$Type == "Driver"]

  if (length(outcome_vars) == 0) {
    keydriver_refuse(
      code = "CFG_OUTCOME_MISSING",
      title = "No Outcome Variable Defined",
      problem = "No variable has Type='Outcome' in the Variables sheet.",
      why_it_matters = "Key driver analysis requires an outcome (dependent) variable to analyze.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Set Type='Outcome' for your dependent variable",
        "This should be the variable you want to explain/predict"
      )
    )
  }

  if (length(outcome_vars) > 1) {
    # Warn but don't refuse - use first
    cat(sprintf("   [WARN] Multiple outcome variables found. Using first: %s\n", outcome_vars[1]))
    outcome_vars <- outcome_vars[1]
  }

  if (length(driver_vars) == 0) {
    keydriver_refuse(
      code = "CFG_DRIVERS_MISSING",
      title = "No Driver Variables Defined",
      problem = "No variables have Type='Driver' in the Variables sheet.",
      why_it_matters = "Key driver analysis requires driver (independent) variables to determine importance.",
      how_to_fix = c(
        "Open the Variables sheet in your config file",
        "Set Type='Driver' for each independent variable",
        "You need at least 2 driver variables for meaningful analysis"
      )
    )
  }

  # Extract optional weight variable
  weight_vars <- variables$VariableName[variables$Type == "Weight"]
  weight_var <- if (length(weight_vars) == 0) {
    NULL
  } else {
    if (length(weight_vars) > 1) {
      warning("Multiple weight variables found. Using first: ", weight_vars[1])
    }
    weight_vars[1]
  }

  # -----------------------------------------------------------------
  # NEW v10.1: Load optional Segments sheet
  # -----------------------------------------------------------------
  segments <- NULL
  if ("Segments" %in% available_sheets) {
    segments <- tryCatch({
      seg_df <- openxlsx::read.xlsx(config_file, sheet = "Segments")
      validate_segments_sheet(seg_df)
      seg_df
    }, error = function(e) {
      warning(sprintf("Could not load Segments sheet: %s", e$message))
      NULL
    })
  }

  # -----------------------------------------------------------------
  # NEW v10.1: Load optional StatedImportance sheet
  # -----------------------------------------------------------------
  stated_importance <- NULL
  if ("StatedImportance" %in% available_sheets) {
    stated_importance <- tryCatch({
      si_df <- openxlsx::read.xlsx(config_file, sheet = "StatedImportance")
      validate_stated_importance_sheet(si_df)
      si_df
    }, error = function(e) {
      warning(sprintf("Could not load StatedImportance sheet: %s", e$message))
      NULL
    })
  }

  # -----------------------------------------------------------------
  # Build configuration list
  # -----------------------------------------------------------------
  list(
    settings = settings_list,
    outcome_var = outcome_vars,
    driver_vars = driver_vars,
    weight_var = weight_var,
    variables = variables,
    data_file = data_file,
    output_file = output_file,
    project_root = project_root,
    # NEW v10.1
    segments = segments,
    stated_importance = stated_importance
  )
}


#' Validate Segments Sheet
#'
#' @param seg_df Segments data frame
#' @keywords internal
validate_segments_sheet <- function(seg_df) {

  required_cols <- c("segment_name", "segment_variable", "segment_values")
  missing_cols <- setdiff(required_cols, names(seg_df))

  if (length(missing_cols) > 0) {
    keydriver_refuse(
      code = "CFG_SEGMENTS_MISSING_COLS",
      title = "Segments Sheet Missing Columns",
      problem = paste0("Segments sheet is missing required columns: ", paste(missing_cols, collapse = ", ")),
      why_it_matters = "Segment analysis requires proper segment definitions.",
      how_to_fix = "Add the missing columns to your Segments sheet: segment_name, segment_variable, segment_values"
    )
  }

  if (nrow(seg_df) == 0) {
    keydriver_refuse(
      code = "CFG_SEGMENTS_EMPTY",
      title = "Segments Sheet Is Empty",
      problem = "Segments sheet has no rows defined.",
      why_it_matters = "Cannot perform segment analysis without segment definitions.",
      how_to_fix = "Add at least one row to the Segments sheet with segment_name, segment_variable, and segment_values."
    )
  }

  invisible(TRUE)
}


#' Validate StatedImportance Sheet
#'
#' @param si_df Stated importance data frame
#' @keywords internal
validate_stated_importance_sheet <- function(si_df) {

  # Must have driver column
  if (!"driver" %in% names(si_df)) {
    keydriver_refuse(
      code = "CFG_STATED_IMPORTANCE_MISSING_DRIVER",
      title = "StatedImportance Missing Driver Column",
      problem = "StatedImportance sheet must have a 'driver' column.",
      why_it_matters = "The driver column identifies which driver variable each importance rating applies to.",
      how_to_fix = "Add a 'driver' column to the StatedImportance sheet listing the driver variable names."
    )
  }

  # Must have numeric importance column
  numeric_cols <- sapply(si_df, is.numeric)
  if (!any(numeric_cols)) {
    keydriver_refuse(
      code = "CFG_STATED_IMPORTANCE_NO_NUMERIC",
      title = "StatedImportance Has No Numeric Column",
      problem = "StatedImportance sheet must have at least one numeric column for importance values.",
      why_it_matters = "Stated importance values must be numeric for comparison with derived importance.",
      how_to_fix = "Add a numeric column (e.g., 'stated_importance') with importance ratings."
    )
  }

  # Standard column name
  if (!"stated_importance" %in% names(si_df)) {
    # Use first numeric column
    num_col <- names(si_df)[numeric_cols][1]
    message(sprintf("Using '%s' as stated importance column", num_col))
    names(si_df)[names(si_df) == num_col] <- "stated_importance"
  }

  invisible(TRUE)
}


#' Get Setting Value with Default
#'
#' Utility to safely extract setting values with fallback.
#'
#' @param settings Settings list
#' @param name Setting name
#' @param default Default value if not found
#' @return Setting value or default
#' @keywords internal
get_setting <- function(settings, name, default = NULL) {
  val <- settings[[name]]
  if (is.null(val) || is.na(val)) {
    return(default)
  }
  val
}


#' Convert Setting to Logical
#'
#' @param value Setting value (may be string, numeric, or logical)
#' @param default Default if NULL/NA
#' @return Logical value
#' @keywords internal
as_logical_setting <- function(value, default = FALSE) {
  if (is.null(value) || is.na(value)) {
    return(default)
  }

  if (is.logical(value)) {
    return(value)
  }

  if (is.character(value)) {
    return(tolower(value) %in% c("true", "yes", "1", "on", "enabled"))
  }

  if (is.numeric(value)) {
    return(value != 0)
  }

  default
}


#' Convert Setting to Numeric
#'
#' @param value Setting value
#' @param default Default if NULL/NA
#' @return Numeric value
#' @keywords internal
as_numeric_setting <- function(value, default = NA_real_) {
  if (is.null(value) || is.na(value)) {
    return(default)
  }

  if (is.numeric(value)) {
    return(value)
  }

  if (is.character(value)) {
    result <- suppressWarnings(as.numeric(value))
    if (is.na(result)) {
      return(default)
    }
    return(result)
  }

  default
}
