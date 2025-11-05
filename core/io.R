# ==============================================================================
# TURAS CORE - INPUT/OUTPUT
# ==============================================================================
# Configuration loading and file I/O utilities
# Migrated from shared_functions.r V9.9.1
# ==============================================================================

#' Load configuration from Settings sheet
#'
#' USAGE: Load config at start of analysis scripts
#' DESIGN: Returns named list for easy access via get_config_value()
#' ERROR HANDLING: Validates structure and provides detailed errors
#' V9.9.1: Detects and blocks duplicate Setting names
#'
#' @param file_path Character, path to config Excel file
#' @param sheet_name Character, name of sheet to load (default: "Settings")
#' @return Named list of configuration values
#' @export
#' @examples
#' config <- load_config_sheet("Config.xlsx", "Settings")
#' sig_level <- get_config_value(config, "significance_level", 0.95)
load_config_sheet <- function(file_path, sheet_name = "Settings") {
  # Validate inputs
  validate_file_path(file_path, "config file", must_exist = TRUE, 
                     required_extensions = SUPPORTED_CONFIG_FORMATS)
  validate_char_param(sheet_name, "sheet_name", allow_empty = FALSE)
  
  # Load with detailed error handling
  tryCatch({
    config_df <- readxl::read_excel(file_path, sheet = sheet_name)
    
    # Validate structure
    if (!all(c("Setting", "Value") %in% names(config_df))) {
      stop(sprintf(
        "Config sheet '%s' must have 'Setting' and 'Value' columns.\nFound: %s",
        sheet_name,
        paste(names(config_df), collapse = ", ")
      ))
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
      stop(sprintf(
        "Config sheet '%s' contains duplicate Setting names: %s\n\nThis is dangerous - the last value would silently override earlier ones.\nPlease fix the config file to have unique Setting names.",
        sheet_name,
        paste(unique(duplicates), collapse = ", ")
      ), call. = FALSE)
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
    stop(sprintf(
      "Failed to load config sheet '%s' from %s\nError: %s\n\nTroubleshooting:\n  1. Verify sheet name exists\n  2. Check file is not corrupted\n  3. Ensure file is not open in Excel",
      sheet_name,
      basename(file_path),
      conditionMessage(e)
    ), call. = FALSE)
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
get_config_value <- function(config_list, 
                             setting_name, 
                             default_value = NULL, 
                             required = FALSE) {
  validate_char_param(setting_name, "setting_name", allow_empty = FALSE)
  
  value <- config_list[[setting_name]]
  
  # Handle missing value
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    if (required && is.null(default_value)) {
      stop(sprintf(
        "Required setting '%s' not found in configuration\n\nAvailable settings:\n  %s",
        setting_name,
        paste(head(names(config_list), 20), collapse = "\n  ")
      ), call. = FALSE)
    }
    return(default_value)
  }
  
  return(value)
}

# ==============================================================================
# TYPED CONFIG GETTERS (V9.9.1 - Reduces validation boilerplate)
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
#' sig_level <- get_numeric_config(config, "significance_level", 
#'                                 default = 0.95, min = 0.5, max = 0.9999)
get_numeric_config <- function(config_list, 
                               setting_name, 
                               default_value = NULL, 
                               min = -Inf, 
                               max = Inf, 
                               required = FALSE) {
  value <- get_config_value(config_list, setting_name, default_value, required)
  
  # Convert to numeric
  numeric_value <- suppressWarnings(as.numeric(value))
  
  if (is.na(numeric_value)) {
    stop(sprintf(
      "Setting '%s' must be numeric, got: %s",
      setting_name,
      if (is.null(value)) "NULL" else as.character(value)
    ), call. = FALSE)
  }
  
  # Validate range
  validate_numeric_param(numeric_value, setting_name, min = min, max = max)
  
  return(numeric_value)
}

#' Get logical configuration value with validation
#'
#' USAGE: Retrieve TRUE/FALSE settings with automatic validation
#' DESIGN: Accepts multiple formats (TRUE/FALSE, Y/N, YES/NO, 1/0)
#'
#' @param config_list Named list of config values
#' @param setting_name Character, setting name
#' @param default_value Logical, default if not found (default: NULL)
#' @param required Logical, stop if missing and no default (default: FALSE)
#' @return Logical value
#' @export
#' @examples
#' enable_weights <- get_logical_config(config, "enable_weighting", default = FALSE)
get_logical_config <- function(config_list, 
                               setting_name, 
                               default_value = NULL, 
                               required = FALSE) {
  value <- get_config_value(config_list, setting_name, default_value, required)
  
  # Convert using safe_logical
  logical_value <- safe_logical(value, default = FALSE)
  
  return(logical_value)
}

#' Get character configuration value with validation
#'
#' USAGE: Retrieve string settings with automatic validation
#' DESIGN: Optionally validates against allowed values
#'
#' @param config_list Named list of config values
#' @param setting_name Character, setting name
#' @param default_value Character, default if not found (default: NULL)
#' @param allowed_values Character vector, allowed values (NULL = any)
#' @param required Logical, stop if missing and no default (default: FALSE)
#' @return Character value
#' @export
#' @examples
#' output_format <- get_char_config(config, "format", 
#'                                  allowed_values = c("excel", "csv"))
get_char_config <- function(config_list, 
                            setting_name, 
                            default_value = NULL, 
                            allowed_values = NULL, 
                            required = FALSE) {
  value <- get_config_value(config_list, setting_name, default_value, required)
  
  # Convert to character
  char_value <- as.character(value)
  
  # Validate against allowed values if specified
  if (!is.null(allowed_values)) {
    validate_char_param(char_value, setting_name, allowed_values = allowed_values)
  }
  
  return(char_value)
}

# Success message
cat("Turas I/O loaded (COMPLETE!)\n")
