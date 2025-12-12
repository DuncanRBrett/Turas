# ==============================================================================
# KEY DRIVER CONFIG LOADER
# ==============================================================================
#
# Version: Turas v10.1
# Date: 2025-12
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
    stop("Configuration file not found: ", config_file, call. = FALSE)
  }

  # Set project root to config file directory if not specified
  if (is.null(project_root)) {
    project_root <- dirname(config_file)
  }

  # Get available sheets
  available_sheets <- openxlsx::getSheetNames(config_file)

  # Load settings (required)
  if (!"Settings" %in% available_sheets) {
    stop("Required sheet 'Settings' not found in config file", call. = FALSE)
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
    stop("Required sheet 'Variables' not found in config file", call. = FALSE)
  }
  variables <- openxlsx::read.xlsx(config_file, sheet = "Variables")

  # Validate variables sheet
  required_cols <- c("VariableName", "Type", "Label")
  missing_cols <- setdiff(required_cols, names(variables))
  if (length(missing_cols) > 0) {
    stop("Missing required columns in Variables sheet: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  # Extract outcome and driver variables
  outcome_vars <- variables$VariableName[variables$Type == "Outcome"]
  driver_vars <- variables$VariableName[variables$Type == "Driver"]

  if (length(outcome_vars) == 0) {
    stop("No outcome variable defined. Set Type='Outcome' for one variable.",
         call. = FALSE)
  }

  if (length(outcome_vars) > 1) {
    warning("Multiple outcome variables found. Using first: ", outcome_vars[1])
    outcome_vars <- outcome_vars[1]
  }

  if (length(driver_vars) == 0) {
    stop("No driver variables defined. Set Type='Driver' for independent variables.",
         call. = FALSE)
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
    stop("Segments sheet missing required columns: ",
         paste(missing_cols, collapse = ", "),
         "\nRequired: segment_name, segment_variable, segment_values")
  }

  if (nrow(seg_df) == 0) {
    stop("Segments sheet has no rows")
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
    stop("StatedImportance sheet must have 'driver' column")
  }

  # Must have numeric importance column
  numeric_cols <- sapply(si_df, is.numeric)
  if (!any(numeric_cols)) {
    stop("StatedImportance sheet must have at least one numeric column for importance values")
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
