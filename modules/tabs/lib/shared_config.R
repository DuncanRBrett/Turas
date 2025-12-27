# ==============================================================================
# SHARED CONFIG FUNCTIONS - TURAS V10.0
# ==============================================================================
# Extracted from shared_functions.R for better maintainability
# Provides configuration loading and access utilities
#
# CONTENTS:
# - Load configuration from Excel sheets
# - Safe config value retrieval with defaults
# - Typed config getters (numeric, logical, character)
#
# DESIGN PRINCIPLES:
# - Returns named lists for easy access
# - Provides detailed error messages
# - Supports default values for optional settings
# - Type-safe getters reduce boilerplate
#
# V9.9.1 ENHANCEMENTS:
# - Duplicate setting detection (blocks silent overwrites)
# - Typed config getters for cleaner code
# ==============================================================================

#' Load configuration from Settings sheet (V9.9.1: Duplicate detection)
#'
#' USAGE: Load config at start of analysis scripts
#' DESIGN: Returns named list for easy access via get_config_value()
#' ERROR HANDLING: Validates structure and provides detailed errors
#' V9.9.1 FIX: Now detects and blocks duplicate Setting names
#'
#' @param file_path Character, path to config Excel file
#' @param sheet_name Character, name of sheet to load (default: "Settings")
#' @return Named list of configuration values
#' @export
#' @examples
#' config <- load_config_sheet("Config.xlsx", "Settings")
#' sig_level <- get_config_value(config, "significance_level", 0.95)
load_config_sheet <- function(file_path, sheet_name = "Settings") {
  # Get constants from parent environment
  SUPPORTED_CONFIG_FORMATS <- tryCatch(
    get("SUPPORTED_CONFIG_FORMATS", envir = .GlobalEnv),
    error = function(e) c("xlsx", "xls")
  )

  # Validate inputs
  validate_file_path(file_path, "config file", must_exist = TRUE,
                    required_extensions = SUPPORTED_CONFIG_FORMATS)
  validate_char_param(sheet_name, "sheet_name", allow_empty = FALSE)

  # Load with detailed error handling
  tryCatch({
    config_df <- readxl::read_excel(file_path, sheet = sheet_name)

    # Validate structure
    if (!all(c("Setting", "Value") %in% names(config_df))) {
      tabs_refuse(
        code = "CFG_INVALID_STRUCTURE",
        title = "Invalid Config Structure",
        problem = sprintf("Config sheet '%s' must have 'Setting' and 'Value' columns. Found: %s", sheet_name, paste(names(config_df), collapse = ", ")),
        why_it_matters = "Configuration sheets must follow the standard two-column format for proper parsing.",
        how_to_fix = "Add 'Setting' and 'Value' column headers to your configuration sheet."
      )
    }

    # Check for data
    if (nrow(config_df) == 0) {
      warning(sprintf("Config sheet '%s' is empty", sheet_name))
      return(list())
    }

    # V9.9.1: Check for duplicate Setting names
    setting_names <- as.character(config_df$Setting)
    setting_names <- setting_names[!is.na(setting_names) & setting_names != ""]

    duplicates <- setting_names[duplicated(setting_names)]
    if (length(duplicates) > 0) {
      tabs_refuse(
        code = "CFG_DUPLICATE_SETTINGS",
        title = "Duplicate Configuration Settings",
        problem = sprintf("Config sheet '%s' contains duplicate Setting names: %s", sheet_name, paste(unique(duplicates), collapse = ", ")),
        why_it_matters = "Duplicate settings are dangerous in production - the last value would silently override earlier ones, causing unpredictable behavior.",
        how_to_fix = "Remove duplicate Setting names from the config file to ensure each setting has a unique name."
      )
    }

    # Convert to named list
    config_list <- setNames(as.list(config_df$Value), config_df$Setting)

    # Remove NA or empty settings
    config_list <- config_list[
      !is.na(names(config_list)) &
      names(config_list) != "" &
      !sapply(config_list, function(x) is.null(x) || (length(x) == 1 && is.na(x)))
    ]

    if (length(config_list) == 0) {
      warning(sprintf("No valid settings found in '%s' sheet", sheet_name))
    }

    return(config_list)

  }, error = function(e) {
    tabs_refuse(
      code = "IO_CONFIG_LOAD_FAILED",
      title = "Failed to Load Config Sheet",
      problem = sprintf("Failed to load config sheet '%s' from %s. Error: %s", sheet_name, basename(file_path), conditionMessage(e)),
      why_it_matters = "Configuration is required to run the analysis with correct parameters.",
      how_to_fix = "Troubleshooting: 1) Verify sheet name exists, 2) Check file is not corrupted, 3) Ensure file is not open in Excel"
    )
  })
}

#' Safely retrieve configuration value
#'
#' USAGE: Access config values with type safety and defaults
#' DESIGN: Graceful degradation - returns default if not found
#' BEST PRACTICE: Always provide sensible defaults for optional settings
#'
#' @param config_list Named list of config values (from load_config_sheet)
#' @param setting_name Character, name of setting to retrieve
#' @param default_value Default value if setting not found (default: NULL)
#' @param required Logical, stop if setting not found and no default (default: FALSE)
#' @return Configuration value or default
#' @export
#' @examples
#' # Required setting - will stop if missing
#' data_file <- get_config_value(config, "data_file", required = TRUE)
#'
#' # Optional setting with default
#' decimals <- get_config_value(config, "decimal_places", default_value = 0)
get_config_value <- function(config_list, setting_name, default_value = NULL,
                             required = FALSE) {
  validate_char_param(setting_name, "setting_name", allow_empty = FALSE)

  value <- config_list[[setting_name]]

  # Handle missing value
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    if (required && is.null(default_value)) {
      tabs_refuse(
        code = "CFG_MISSING_SETTING",
        title = "Missing Required Setting",
        problem = sprintf("Required setting '%s' not found in configuration", setting_name),
        why_it_matters = "This setting is required for the analysis to proceed correctly.",
        how_to_fix = sprintf("Add '%s' to your configuration. Available settings: %s", setting_name, paste(head(names(config_list), 20), collapse = ", "))
      )
    }
    return(default_value)
  }

  return(value)
}

# ==============================================================================
# TYPED CONFIG GETTERS (V9.9.1: NEW - Reduces downstream validation boilerplate)
# ==============================================================================
# USAGE: Cleaner, safer config access with automatic type conversion & validation
# DESIGN: Wraps get_config_value + type conversion + validation in one call
# BENEFIT: Eliminates repetitive validation code in calling scripts
# ==============================================================================

#' Get numeric configuration value with validation
#'
#' USAGE: Retrieve numeric settings with automatic validation
#' DESIGN: Combines get_config_value + type conversion + range validation
#'
#' @param config_list Named list of config values
#' @param setting_name Character, setting name
#' @param default_value Numeric, default if not found (default: NULL)
#' @param min Numeric, minimum allowed value (default: -Inf)
#' @param max Numeric, maximum allowed value (default: Inf)
#' @param required Logical, stop if missing and no default (default: FALSE)
#' @return Numeric value
#' @export
#' @examples
#' # With range validation
#' sig_level <- get_numeric_config(config, "significance_level",
#'                                 default = 0.95, min = 0.5, max = 0.9999)
#'
#' # Required setting
#' min_base <- get_numeric_config(config, "min_base", min = 1, required = TRUE)
get_numeric_config <- function(config_list, setting_name, default_value = NULL,
                               min = -Inf, max = Inf, required = FALSE) {
  value <- get_config_value(config_list, setting_name, default_value, required)

  # Convert to numeric
  numeric_value <- suppressWarnings(as.numeric(value))

  if (is.na(numeric_value)) {
    tabs_refuse(
      code = "CFG_INVALID_NUMERIC",
      title = "Invalid Numeric Setting",
      problem = sprintf("Setting '%s' must be numeric, got: %s", setting_name, if (is.null(value)) "NULL" else as.character(value)),
      why_it_matters = "Numeric settings are required for calculations and threshold comparisons.",
      how_to_fix = sprintf("Set '%s' to a valid numeric value in your configuration (e.g., 0.95 or 100).", setting_name)
    )
  }

  # Validate range
  validate_numeric_param(numeric_value, setting_name, min = min, max = max)

  return(numeric_value)
}

#' Get logical configuration value with validation
#'
#' USAGE: Retrieve TRUE/FALSE settings with automatic conversion
#' DESIGN: Handles Y/N, YES/NO, T/F, 1/0, TRUE/FALSE
#'
#' @param config_list Named list of config values
#' @param setting_name Character, setting name
#' @param default_value Logical, default if not found (default: FALSE)
#' @return Logical value
#' @export
#' @examples
#' apply_weights <- get_logical_config(config, "apply_weighting", default = FALSE)
#' show_sig <- get_logical_config(config, "enable_significance_testing", default = TRUE)
get_logical_config <- function(config_list, setting_name, default_value = FALSE) {
  value <- get_config_value(config_list, setting_name, default_value = default_value)
  return(safe_logical(value, default = default_value))
}

#' Get character configuration value with validation
#'
#' USAGE: Retrieve string settings with optional allowed values check
#' DESIGN: Validates against whitelist if provided
#'
#' @param config_list Named list of config values
#' @param setting_name Character, setting name
#' @param default_value Character, default if not found (default: NULL)
#' @param allowed_values Character vector, allowed values (default: NULL)
#' @param required Logical, stop if missing and no default (default: FALSE)
#' @return Character value
#' @export
#' @examples
#' # With allowed values
#' sep <- get_char_config(config, "decimal_separator", default = ".",
#'                        allowed = c(".", ","))
#'
#' # Required setting
#' data_file <- get_char_config(config, "data_file", required = TRUE)
get_char_config <- function(config_list, setting_name, default_value = NULL,
                            allowed_values = NULL, required = FALSE) {
  value <- get_config_value(config_list, setting_name, default_value, required)

  # Convert to character
  char_value <- as.character(value)

  # Validate
  validate_char_param(char_value, setting_name,
                     allowed_values = allowed_values,
                     allow_empty = FALSE)

  return(char_value)
}

# ==============================================================================
# END OF SHARED_CONFIG.R
# ==============================================================================
