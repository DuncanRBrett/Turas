# ==============================================================================
# CONFIG UTILITIES
# ==============================================================================
# Configuration file loading, validation, and path handling
# Extracted from shared_functions.R Turas v10.0
# Part of Turas shared module infrastructure
# ==============================================================================

# Constants
SUPPORTED_CONFIG_FORMATS <- c("xlsx", "xls")

#' Load configuration from Settings sheet
#'
#' USAGE: Load config at start of analysis scripts
#' DESIGN: Returns named list for easy access via get_config_value()
#' ERROR HANDLING: Validates structure and provides detailed errors
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

    # Check for duplicate Setting names
    setting_names <- as.character(config_df$Setting)
    setting_names <- setting_names[!is.na(setting_names) & setting_names != ""]

    duplicates <- setting_names[duplicated(setting_names)]
    if (length(duplicates) > 0) {
      stop(sprintf(
        "Config sheet '%s' contains duplicate Setting names: %s\n\nThis is dangerous in production - the last value would silently override earlier ones.\nPlease fix the config file to have unique Setting names.",
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
get_config_value <- function(config_list, setting_name, default_value = NULL,
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
get_numeric_config <- function(config_list, setting_name, default_value = NULL,
                               min = -Inf, max = Inf, required = FALSE) {
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
#' USAGE: Retrieve TRUE/FALSE settings with automatic conversion
#' DESIGN: Handles Y/N, YES/NO, T/F, 1/0, TRUE/FALSE
#'
#' @param config_list Named list of config values
#' @param setting_name Character, setting name
#' @param default_value Logical, default if not found (default: FALSE)
#' @return Logical value
#' @export
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
# PATH HANDLING
# ==============================================================================

#' Resolve relative path from base path
#'
#' USAGE: Convert relative paths to absolute for file operations
#' DESIGN: Platform-independent, handles ./ and ../ correctly
#' SECURITY: Normalizes path to prevent directory traversal attacks
#'
#' @param base_path Character, base directory path
#' @param relative_path Character, path relative to base
#' @return Character, absolute normalized path
#' @export
resolve_path <- function(base_path, relative_path) {
  # Validate inputs
  if (is.null(base_path) || is.na(base_path) || base_path == "") {
    stop("base_path cannot be empty", call. = FALSE)
  }

  if (is.null(relative_path) || is.na(relative_path) || relative_path == "") {
    return(normalizePath(base_path, mustWork = FALSE))
  }

  # Remove leading ./
  relative_path <- gsub("^\\./", "", relative_path)

  # Combine paths (handles both / and \)
  full_path <- file.path(base_path, relative_path)

  # Normalize (resolves .., ., converts to OS-specific separators)
  full_path <- normalizePath(full_path, winslash = "/", mustWork = FALSE)

  return(full_path)
}

#' Get project root directory from config file location
#'
#' USAGE: Determine project root for resolving relative paths
#' DESIGN: Simple - parent directory of config file
#' NOTE: Project root = directory containing config file
#'
#' @param config_file_path Character, path to config file
#' @return Character, project root directory path
#' @export
get_project_root <- function(config_file_path) {
  validate_char_param(config_file_path, "config_file_path", allow_empty = FALSE)

  project_root <- dirname(config_file_path)
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)

  return(project_root)
}

#' Find Turas root directory
#'
#' Searches up the directory tree to locate the Turas installation root.
#' Looks for marker files/directories: launch_turas.R, turas.R, modules/shared/
#'
#' USAGE: Use to resolve paths to shared modules
#' CACHING: Checks TURAS_ROOT global first for performance
#'
#' @return Character, path to Turas root directory
#' @export
find_turas_root <- function() {
  # Check cached value first
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    cached <- get("TURAS_ROOT", envir = .GlobalEnv)
    if (!is.null(cached) && nzchar(cached)) {
      return(cached)
    }
  }

  # Start from current working directory
  current_dir <- getwd()

  # Search up directory tree for Turas root markers
  while (current_dir != dirname(current_dir)) {
    has_launch <- isTRUE(file.exists(file.path(current_dir, "launch_turas.R")))
    has_turas_r <- isTRUE(file.exists(file.path(current_dir, "turas.R")))
    has_modules_shared <- isTRUE(dir.exists(file.path(current_dir, "modules", "shared")))

    if (has_launch || has_turas_r || has_modules_shared) {
      # Cache for future calls
      assign("TURAS_ROOT", current_dir, envir = .GlobalEnv)
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }

  stop(paste0(
    "Cannot locate Turas root directory.\n",
    "Please run from within the Turas directory structure.\n",
    "Current working directory: ", getwd()
  ), call. = FALSE)
}
