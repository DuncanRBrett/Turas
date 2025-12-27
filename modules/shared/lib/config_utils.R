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
      turas_refuse(
        code = "CFG_INVALID_SHEET_STRUCTURE",
        title = "Invalid Configuration Sheet Structure",
        problem = sprintf("Config sheet '%s' must have 'Setting' and 'Value' columns, but these were not found.", sheet_name),
        why_it_matters = "Configuration cannot be loaded without the required column structure.",
        how_to_fix = c(
          sprintf("Open %s in Excel", basename(file_path)),
          sprintf("Navigate to the '%s' sheet", sheet_name),
          "Ensure the sheet has exactly two columns named 'Setting' and 'Value'",
          sprintf("Current columns found: %s", paste(names(config_df), collapse = ", "))
        ),
        expected = c("Setting", "Value"),
        observed = names(config_df)
      )
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
      turas_refuse(
        code = "CFG_DUPLICATE_SETTINGS",
        title = "Duplicate Setting Names in Configuration",
        problem = sprintf("Config sheet '%s' contains duplicate Setting names.", sheet_name),
        why_it_matters = "Duplicate settings are dangerous - the last value would silently override earlier ones, leading to unpredictable behavior.",
        how_to_fix = c(
          sprintf("Open %s in Excel", basename(file_path)),
          sprintf("Navigate to the '%s' sheet", sheet_name),
          "Find and remove or rename the duplicate Setting names listed below",
          "Ensure each Setting name appears only once"
        ),
        observed = unique(duplicates)
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
    turas_refuse(
      code = "IO_CONFIG_LOAD_FAILED",
      title = "Failed to Load Configuration Sheet",
      problem = sprintf("Could not load sheet '%s' from %s", sheet_name, basename(file_path)),
      why_it_matters = "Configuration must be loaded to proceed with analysis.",
      how_to_fix = c(
        "Verify the sheet name exists in the Excel file",
        "Check that the file is not corrupted",
        "Ensure the file is not currently open in Excel",
        "Try opening the file manually to verify it's accessible"
      ),
      details = conditionMessage(e)
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
      turas_refuse(
        code = "CFG_REQUIRED_SETTING_MISSING",
        title = "Required Configuration Setting Missing",
        problem = sprintf("Required setting '%s' not found in configuration.", setting_name),
        why_it_matters = "This setting is required for the analysis to proceed.",
        how_to_fix = c(
          "Add the missing setting to your configuration file",
          sprintf("Setting name: '%s'", setting_name),
          "Check the available settings listed below to ensure correct spelling"
        ),
        missing = setting_name,
        observed = head(names(config_list), 20)
      )
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
    turas_refuse(
      code = "CFG_INVALID_NUMERIC_VALUE",
      title = "Invalid Numeric Configuration Value",
      problem = sprintf("Setting '%s' must be numeric.", setting_name),
      why_it_matters = "Numeric settings must contain valid numbers for calculations to work correctly.",
      how_to_fix = c(
        sprintf("Open your configuration file and locate setting '%s'", setting_name),
        "Ensure the value is a valid number (e.g., 0.95, 100, -5)",
        "Remove any text, special characters, or formatting"
      ),
      expected = "numeric value",
      observed = if (is.null(value)) "NULL" else as.character(value)
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
    turas_refuse(
      code = "IO_INVALID_BASE_PATH",
      title = "Invalid Base Path",
      problem = "base_path parameter cannot be empty or NULL.",
      why_it_matters = "A valid base path is required to resolve relative file paths.",
      how_to_fix = c(
        "Ensure base_path parameter is provided",
        "Check that the path is a valid directory",
        "Use an absolute path or ensure the directory exists"
      )
    )
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

  turas_refuse(
    code = "IO_TURAS_ROOT_NOT_FOUND",
    title = "Cannot Locate Turas Root Directory",
    problem = "Could not find the Turas root directory by searching up from the current location.",
    why_it_matters = "Turas needs to locate its root directory to access shared modules and resources.",
    how_to_fix = c(
      "Ensure you are running from within the Turas directory structure",
      "Check that one of these files/folders exists in your Turas installation:",
      "  - launch_turas.R",
      "  - turas.R",
      "  - modules/shared/",
      sprintf("Current working directory: %s", getwd()),
      "Consider setting the TURAS_ROOT environment variable to point to your Turas installation"
    )
  )
}
