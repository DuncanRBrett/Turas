# ==============================================================================
# TURAS SHARED LIBRARY - CONFIGURATION UTILITIES
# ==============================================================================
# Shared between: TurasTabs, TurasTracker, and future modules
#
# PURPOSE:
#   Common configuration file handling utilities
#
# IMPORTANT: Changes to this file affect multiple modules.
#             Test thoroughly before committing.
#
# VERSION: Turas v10.0
# CREATED: Phase 3 - Code Quality Improvements
# ==============================================================================

CONFIG_UTILS_VERSION <- "10.0"

# ==============================================================================
# EXCEL CONFIG READING
# ==============================================================================

#' Read Configuration Sheet
#'
#' Generic function to read a sheet from Excel config file with error handling.
#' Provides consistent error messages and validation across all modules.
#'
#' @param config_path Character. Path to .xlsx config file
#' @param sheet_name Character. Name of sheet to read
#' @param detect_dates Logical. Parse dates automatically (default: FALSE)
#' @return Data frame with sheet contents, or stops with informative error
#'
#' @export
#' @examples
#' settings <- read_config_sheet("config.xlsx", "Settings")
#' banner <- read_config_sheet("config.xlsx", "Banner")
read_config_sheet <- function(config_path, sheet_name, detect_dates = FALSE) {

  # Validate config file exists
  if (!file.exists(config_path)) {
    stop(sprintf(
      "Configuration file not found:\n  Path: %s\n\nTroubleshooting:\n  1. Check file path spelling\n  2. Verify file exists in specified location\n  3. Check file permissions",
      config_path
    ), call. = FALSE)
  }

  # Try to read the sheet
  sheet_data <- tryCatch({
    if (!requireNamespace("openxlsx", quietly = TRUE)) {
      stop("Package 'openxlsx' is required for reading Excel config files", call. = FALSE)
    }

    openxlsx::read.xlsx(config_path, sheet = sheet_name, detectDates = detect_dates)

  }, error = function(e) {
    # Get list of available sheets for helpful error message
    available_sheets <- tryCatch({
      openxlsx::getSheetNames(config_path)
    }, error = function(e2) {
      NULL
    })

    if (!is.null(available_sheets)) {
      stop(sprintf(
        "Error reading sheet '%s' from config file:\n  File: %s\n  Error: %s\n\nAvailable sheets:\n  %s",
        sheet_name,
        basename(config_path),
        conditionMessage(e),
        paste(available_sheets, collapse = "\n  ")
      ), call. = FALSE)
    } else {
      stop(sprintf(
        "Error reading sheet '%s' from config file:\n  File: %s\n  Error: %s",
        sheet_name,
        basename(config_path),
        conditionMessage(e)
      ), call. = FALSE)
    }
  })

  # Validate sheet has data
  if (nrow(sheet_data) == 0) {
    warning(sprintf("Config sheet '%s' is empty (0 rows)", sheet_name), call. = FALSE)
  }

  return(sheet_data)
}

# ==============================================================================
# SETTINGS PARSING
# ==============================================================================

#' Parse Settings to Named List
#'
#' Converts settings dataframe (Setting, Value columns) to named list.
#' Handles type conversion (Y/N → logical, numeric strings → numbers).
#'
#' DESIGN: Extracted from both TurasTabs and TurasTracker to ensure consistency.
#'
#' @param settings_df Data frame with 'Setting' and 'Value' columns
#'                    (or 'SettingName' and 'Value' for backward compatibility)
#' @return Named list of settings
#'
#' @export
#' @examples
#' settings_df <- data.frame(
#'   Setting = c("decimal_separator", "show_significance", "decimal_places"),
#'   Value = c(",", "Y", "2")
#' )
#' settings <- parse_settings_to_list(settings_df)
#' # Returns: list(decimal_separator = ",", show_significance = TRUE, decimal_places = 2)
parse_settings_to_list <- function(settings_df) {

  # Accept either "Setting" or "SettingName" for backward compatibility
  setting_col <- if ("Setting" %in% names(settings_df)) {
    "Setting"
  } else if ("SettingName" %in% names(settings_df)) {
    "SettingName"
  } else {
    stop("Settings sheet must have 'Setting' (or 'SettingName') and 'Value' columns", call. = FALSE)
  }

  if (!"Value" %in% names(settings_df)) {
    stop("Settings sheet must have 'Value' column", call. = FALSE)
  }

  # Create named list
  settings <- as.list(settings_df$Value)
  names(settings) <- settings_df[[setting_col]]

  # Check for duplicate settings
  duplicates <- names(settings)[duplicated(names(settings))]
  if (length(duplicates) > 0) {
    stop(sprintf(
      "Duplicate settings found in configuration:\n  %s\n\nEach setting must appear only once.",
      paste(unique(duplicates), collapse = "\n  ")
    ), call. = FALSE)
  }

  # Convert Y/N to logical
  for (name in names(settings)) {
    val <- settings[[name]]
    if (!is.na(val) && is.character(val) && toupper(val) %in% c("Y", "N", "YES", "NO", "TRUE", "FALSE")) {
      settings[[name]] <- toupper(val) %in% c("Y", "YES", "TRUE")
    }
  }

  # Convert numeric strings to numbers where appropriate
  for (name in names(settings)) {
    val <- settings[[name]]
    if (!is.na(val) && is.character(val) && grepl("^-?[0-9.]+$", val)) {
      num_val <- suppressWarnings(as.numeric(val))
      if (!is.na(num_val)) {
        settings[[name]] <- num_val
      }
    }
  }

  return(settings)
}


#' Get Setting with Default
#'
#' Safely retrieves a setting value with fallback to default.
#' Works with config objects from both TurasTabs and TurasTracker.
#'
#' @param config List. Configuration object (must have $settings element)
#' @param setting_name Character. Setting name to retrieve
#' @param default Default value if not found (default: NULL)
#' @return Setting value or default
#'
#' @export
#' @examples
#' get_setting(config, "decimal_separator", default = ".")
#' get_setting(config, "show_significance", default = TRUE)
get_setting <- function(config, setting_name, default = NULL) {

  # Handle different config structures
  # TurasTracker: config$settings$setting_name
  # TurasTabs: config$setting_name
  if ("settings" %in% names(config)) {
    # Tracker-style config
    if (setting_name %in% names(config$settings)) {
      return(config$settings[[setting_name]])
    }
  } else {
    # Tabs-style config (flat)
    if (setting_name %in% names(config)) {
      return(config[[setting_name]])
    }
  }

  # Not found - return default
  return(default)
}


#' Get Typed Config Value
#'
#' Retrieves config value with type conversion and validation.
#' Wrapper around get_setting() with explicit type handling.
#'
#' @param config List. Configuration object
#' @param setting_name Character. Setting name
#' @param default Default value
#' @param type Character. Expected type: "logical", "numeric", "character"
#' @return Typed value or default
#'
#' @export
get_typed_setting <- function(config, setting_name, default = NULL, type = "character") {

  value <- get_setting(config, setting_name, default = default)

  if (is.null(value)) {
    return(default)
  }

  # Type conversion
  result <- tryCatch({
    switch(type,
      "logical" = as.logical(value),
      "numeric" = as.numeric(value),
      "character" = as.character(value),
      value  # Unknown type - return as-is
    )
  }, warning = function(w) {
    warning(sprintf(
      "Could not convert setting '%s' to type '%s'. Using default: %s",
      setting_name, type, default
    ), call. = FALSE)
    default
  }, error = function(e) {
    warning(sprintf(
      "Error converting setting '%s' to type '%s': %s. Using default: %s",
      setting_name, type, conditionMessage(e), default
    ), call. = FALSE)
    default
  })

  return(result)
}

# ==============================================================================
# VALIDATION UTILITIES
# ==============================================================================

#' Validate Required Columns
#'
#' Checks that required columns exist in dataframe.
#' Provides clear error message with missing column names.
#'
#' @param df Data frame to validate
#' @param required_cols Character vector of required column names
#' @param context_name Character. Name for error messages (e.g., "Banner sheet")
#' @return Invisible TRUE if valid, stops with error if invalid
#'
#' @export
#' @examples
#' validate_required_columns(banner_df, c("BreakVariable", "BreakLabel"), "Banner sheet")
validate_required_columns <- function(df, required_cols, context_name = "Data frame") {

  if (!is.data.frame(df)) {
    stop(sprintf("%s is not a data frame", context_name), call. = FALSE)
  }

  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    stop(sprintf(
      "%s is missing required columns:\n  Missing: %s\n  Found: %s",
      context_name,
      paste(missing_cols, collapse = ", "),
      paste(names(df), collapse = ", ")
    ), call. = FALSE)
  }

  invisible(TRUE)
}


#' Check for Duplicates
#'
#' Validates uniqueness of identifiers.
#' Provides clear error message with duplicate values.
#'
#' @param values Vector of values to check
#' @param value_name Character. Name of value type (e.g., "WaveID", "QuestionCode")
#' @param context_name Character. Context for error messages
#' @return Invisible TRUE if no duplicates, stops with error if duplicates found
#'
#' @export
#' @examples
#' check_duplicates(wave_ids, "WaveID", "Waves sheet")
check_duplicates <- function(values, value_name, context_name = "Configuration") {

  duplicates <- values[duplicated(values)]

  if (length(duplicates) > 0) {
    stop(sprintf(
      "Duplicate %s found in %s:\n  %s\n\nEach %s must be unique.",
      value_name,
      context_name,
      paste(unique(duplicates), collapse = "\n  "),
      value_name
    ), call. = FALSE)
  }

  invisible(TRUE)
}


#' Validate Date Range
#'
#' Checks that end_date >= start_date.
#'
#' @param start_date Date or character
#' @param end_date Date or character
#' @param context_name Character. Context for error messages
#' @return Invisible TRUE if valid, stops with error if invalid
#'
#' @export
validate_date_range <- function(start_date, end_date, context_name = "Date range") {

  # Convert to Date if needed
  if (is.character(start_date)) {
    start_date <- as.Date(start_date)
  }
  if (is.character(end_date)) {
    end_date <- as.Date(end_date)
  }

  # Check validity
  if (is.na(start_date)) {
    stop(sprintf("%s: Start date is invalid or missing", context_name), call. = FALSE)
  }

  if (is.na(end_date)) {
    stop(sprintf("%s: End date is invalid or missing", context_name), call. = FALSE)
  }

  if (end_date < start_date) {
    stop(sprintf(
      "%s: End date (%s) is before start date (%s)",
      context_name, end_date, start_date
    ), call. = FALSE)
  }

  invisible(TRUE)
}

# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Shared config_utils module loaded (v%s)", CONFIG_UTILS_VERSION))
