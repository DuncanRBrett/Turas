# ==============================================================================
# SHARED FUNCTIONS - TURAS V10.0
# ==============================================================================
# Common utilities used across all analysis types
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# Turas v10.0 - Numeric question support (2025)
#          - FIXED: format_output_value() now supports numeric question type
#          - ADDED: decimal_places_numeric parameter to format_output_value()
#          - ADDED: SHARED_FUNCTIONS_VERSION constant for version checking
# V9.9.1 - External review fixes (2024)
#          - FIXED: Extension validation now works for output files (must_exist=FALSE)
#          - FIXED: Duplicate config settings now detected and blocked
#          - ADDED: Typed config getters (get_numeric_config, get_logical_config, get_char_config)
#          - ADDED: .sav label normalization option (convert_labelled parameter)
#          - FIXED: safe_equal() NA handling (real NA vs "NA" string)
#          - ADDED: source_if_exists() environment control
#          - ADDED: CSV fast-path via data.table when available
#          - IMPROVED: log_issue() documentation for batch accumulation pattern
# V9.9   - Production release (aligned with run_crosstabs.r V9.9)
#          - FIXED: Excel letter generation (proper base-26 algorithm)
#          - ADDED: Comprehensive input validation functions
#          - ADDED: .sav (SPSS) file support via haven package
# V8.0   - Previous version (deprecated)
#
# MAINTENANCE NOTES:
# - This is a FOUNDATIONAL script - changes affect all toolkit components
# - Always run full integration tests after modifications
# - Performance-critical functions marked with [PERFORMANCE]
# - See DEPENDENCY MAP at end of file before making changes
# ==============================================================================

SCRIPT_VERSION <- "10.0"
SHARED_FUNCTIONS_VERSION <- "10.0"  # For version checking by other modules

# ==============================================================================
# CONSTANTS
# ==============================================================================

# File Size Limits (bytes)
MAX_FILE_SIZE_MB <- 500
MAX_FILE_SIZE_BYTES <- MAX_FILE_SIZE_MB * 1024 * 1024

# Excel Limits
MAX_EXCEL_COLUMNS <- 16384
MAX_EXCEL_ROWS <- 1048576

# Validation Limits
MAX_DECIMAL_PLACES <- 6
MIN_SAMPLE_SIZE <- 1

# Supported File Types
SUPPORTED_DATA_FORMATS <- c("xlsx", "xls", "csv", "sav")
SUPPORTED_CONFIG_FORMATS <- c("xlsx", "xls")

# ==============================================================================
# DEPENDENCY MANAGEMENT
# ==============================================================================

#' Check if package is available
#'
#' @param package_name Character, package name
#' @return Logical, TRUE if available
is_package_available <- function(package_name) {
  requireNamespace(package_name, quietly = TRUE)
}

#' Safely source file if it exists (V9.9.1: Environment control added)
#'
#' SECURITY: Sources into specified environment to prevent namespace pollution
#' DEFAULT: Sources into caller's environment (parent.frame())
#'
#' @param file_path Character, path to R script
#' @param envir Environment, where to source (default: parent.frame())
#' @return Invisible NULL
source_if_exists <- function(file_path, envir = parent.frame()) {
  if (file.exists(file_path)) {
    tryCatch({
      source(file_path, local = envir)
      invisible(NULL)
    }, error = function(e) {
      warning(sprintf("Failed to source %s: %s", file_path, conditionMessage(e)))
      invisible(NULL)
    })
  }
}

# ==============================================================================
# INPUT VALIDATION FUNCTIONS (V9.9 ADDITIONS)
# ==============================================================================
# These functions provide robust input validation matching run_crosstabs.r V9.9
# standards. Use these throughout the toolkit for consistency.
# ==============================================================================

#' Validate data frame structure with detailed errors
#'
#' USAGE: Call at start of any function accepting data frames
#' DESIGN: Provides specific, actionable error messages
#'
#' @param data Data frame to validate
#' @param required_cols Character vector, required column names (NULL = skip check)
#' @param min_rows Integer, minimum rows required (default: 1)
#' @param max_rows Integer, maximum rows allowed (default: Inf)
#' @param param_name Character, parameter name for error messages
#' @return Invisible TRUE if valid, stops with detailed error if invalid
#' @export
#' @examples
#' validate_data_frame(survey_data, c("ID", "Response"), min_rows = 10)
validate_data_frame <- function(data, required_cols = NULL, min_rows = 1, 
                               max_rows = Inf, param_name = "data") {
  # Type check
  if (!is.data.frame(data)) {
    stop(sprintf(
      "%s must be a data frame, got: %s", 
      param_name, 
      paste(class(data), collapse = ", ")
    ), call. = FALSE)
  }
  
  # Row count check
  n_rows <- nrow(data)
  if (n_rows < min_rows) {
    stop(sprintf(
      "%s must have at least %d rows, has %d", 
      param_name, min_rows, n_rows
    ), call. = FALSE)
  }
  
  if (n_rows > max_rows) {
    stop(sprintf(
      "%s exceeds maximum %d rows, has %d", 
      param_name, max_rows, n_rows
    ), call. = FALSE)
  }
  
  # Column check
  if (!is.null(required_cols) && length(required_cols) > 0) {
    missing <- setdiff(required_cols, names(data))
    if (length(missing) > 0) {
      available_preview <- head(names(data), 10)
      stop(sprintf(
        "%s missing required columns: %s\n\nAvailable columns: %s%s", 
        param_name, 
        paste(missing, collapse = ", "),
        paste(available_preview, collapse = ", "),
        if (ncol(data) > 10) sprintf(" ... (%d more)", ncol(data) - 10) else ""
      ), call. = FALSE)
    }
  }
  
  invisible(TRUE)
}

#' Validate numeric parameter with range checking
#'
#' USAGE: Validate configuration values, thresholds, counts
#' DESIGN: Type-safe with clear range violations
#'
#' @param value Numeric value to validate
#' @param param_name Character, parameter name for errors
#' @param min Numeric, minimum allowed value (default: -Inf)
#' @param max Numeric, maximum allowed value (default: Inf)
#' @param allow_na Logical, whether NA is acceptable (default: FALSE)
#' @return Invisible TRUE if valid, stops with error if invalid
#' @export
#' @examples
#' validate_numeric_param(sig_level, "significance_level", min = 0.5, max = 0.9999)
validate_numeric_param <- function(value, param_name, min = -Inf, max = Inf, 
                                  allow_na = FALSE) {
  # NA check
  if (is.na(value)) {
    if (!allow_na) {
      stop(sprintf("%s cannot be NA", param_name), call. = FALSE)
    }
    return(invisible(TRUE))
  }
  
  # Type and length check
  if (!is.numeric(value) || length(value) != 1) {
    stop(sprintf(
      "%s must be a single numeric value, got: %s (length %d)", 
      param_name, class(value)[1], length(value)
    ), call. = FALSE)
  }
  
  # Range check
  if (value < min || value > max) {
    stop(sprintf(
      "%s must be between %g and %g, got: %g", 
      param_name, min, max, value
    ), call. = FALSE)
  }
  
  invisible(TRUE)
}

#' Validate logical parameter
#'
#' USAGE: Validate TRUE/FALSE configuration settings
#' DESIGN: Strict - only accepts TRUE or FALSE (no NA)
#'
#' @param value Value to validate
#' @param param_name Character, parameter name for errors
#' @return Invisible TRUE if valid, stops with error if invalid
#' @export
validate_logical_param <- function(value, param_name) {
  if (!is.logical(value) || length(value) != 1 || is.na(value)) {
    stop(sprintf(
      "%s must be TRUE or FALSE, got: %s", 
      param_name, 
      if (is.null(value)) "NULL" else as.character(value)
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate character parameter
#'
#' USAGE: Validate string settings, column names, file paths
#' DESIGN: Optionally validates against allowed values list
#'
#' @param value Character value to validate
#' @param param_name Character, parameter name for errors
#' @param allowed_values Character vector, allowed values (NULL = any allowed)
#' @param allow_empty Logical, allow empty string (default: FALSE)
#' @return Invisible TRUE if valid, stops with error if invalid
#' @export
validate_char_param <- function(value, param_name, allowed_values = NULL, 
                               allow_empty = FALSE) {
  # Type check
  if (!is.character(value) || length(value) != 1 || is.na(value)) {
    stop(sprintf(
      "%s must be a single character value, got: %s", 
      param_name, 
      if (is.null(value)) "NULL" else class(value)[1]
    ), call. = FALSE)
  }
  
  # Empty check
  if (!allow_empty && nchar(trimws(value)) == 0) {
    stop(sprintf("%s cannot be empty", param_name), call. = FALSE)
  }
  
  # Allowed values check
  if (!is.null(allowed_values) && !value %in% allowed_values) {
    stop(sprintf(
      "%s must be one of: %s\nGot: '%s'", 
      param_name, 
      paste(allowed_values, collapse = ", "), 
      value
    ), call. = FALSE)
  }
  
  invisible(TRUE)
}

#' Validate file path exists and is accessible (V9.9.1: Output file extension validation)
#'
#' USAGE: Validate file paths before attempting to read OR write
#' DESIGN: Checks existence, readability, optionally file type
#' V9.9.1 FIX: Extension validation now works for output files (must_exist=FALSE)
#'
#' @param file_path Character, path to file
#' @param param_name Character, parameter name for errors
#' @param must_exist Logical, must file exist (default: TRUE)
#' @param required_extensions Character vector, allowed extensions (NULL = any)
#' @param validate_extension_even_if_missing Logical, validate extension even if file doesn't exist yet (default: FALSE)
#' @return Invisible TRUE if valid, stops with detailed error if invalid
#' @export
#' @examples
#' # Input file (must exist)
#' validate_file_path("data.xlsx", must_exist = TRUE, required_extensions = "xlsx")
#' 
#' # Output file (doesn't exist yet, but check extension)
#' validate_file_path("output.xlsx", must_exist = FALSE, 
#'                    required_extensions = "xlsx", 
#'                    validate_extension_even_if_missing = TRUE)
validate_file_path <- function(file_path, param_name = "file_path", 
                               must_exist = TRUE, 
                               required_extensions = NULL,
                               validate_extension_even_if_missing = FALSE) {
  # Basic validation
  validate_char_param(file_path, param_name, allow_empty = FALSE)
  
  # Existence check
  if (must_exist && !file.exists(file_path)) {
    # Provide helpful context
    dir_part <- dirname(file_path)
    file_part <- basename(file_path)
    
    stop(sprintf(
      "%s: File not found\n  Path: %s\n  Directory exists: %s\n  Looking for: %s\n\nTroubleshooting:\n  1. Check spelling and case sensitivity\n  2. Verify file is in correct location\n  3. Check file permissions",
      param_name,
      file_path,
      if (dir.exists(dir_part)) "YES" else "NO",
      file_part
    ), call. = FALSE)
  }
  
  # Extension check (V9.9.1: Now works for output files too)
  if (!is.null(required_extensions) && 
      (must_exist || validate_extension_even_if_missing)) {
    file_ext <- tolower(tools::file_ext(file_path))
    
    # Check extension is present and valid
    if (!nzchar(file_ext) || !file_ext %in% required_extensions) {
      stop(sprintf(
        "%s: Invalid file type\n  Expected: %s\n  Got: .%s\n\nNote: This prevents typos like 'output.csvx' from causing errors later.",
        param_name,
        paste0(".", required_extensions, collapse = " or "),
        if (nzchar(file_ext)) file_ext else "(no extension)"
      ), call. = FALSE)
    }
  }
  
  # Size check (if exists)
  if (must_exist) {
    file_size <- file.info(file_path)$size
    if (file_size > MAX_FILE_SIZE_BYTES) {
      warning(sprintf(
        "%s: Large file detected (%.1f MB). Loading may be slow or cause memory issues.\n  Tip: For faster loading, consider converting to CSV format.",
        param_name,
        file_size / (1024 * 1024)
      ), call. = FALSE)
    }
  }
  
  invisible(TRUE)
}

# ==============================================================================
# CONFIGURATION LOADING (V9.9.1: Duplicate detection added)
# ==============================================================================
# [PERFORMANCE] These functions read Excel files - can be slow for large configs
# Consider caching if calling repeatedly
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
# PATH HANDLING
# ==============================================================================
# SECURITY NOTE: All path functions normalize to prevent directory traversal
# PLATFORM: Works on Windows, Mac, Linux
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
#' @examples
#' # Returns: /Users/john/project/Data/survey.xlsx
#' resolve_path("/Users/john/project", "Data/survey.xlsx")
#' 
#' # Handles ./ prefix
#' resolve_path("/Users/john/project", "./Data/survey.xlsx")
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
#' @examples
#' # Config at: /Users/john/MyProject/Config.xlsx
#' # Returns:   /Users/john/MyProject
#' project_root <- get_project_root(config_file)
get_project_root <- function(config_file_path) {
  validate_char_param(config_file_path, "config_file_path", allow_empty = FALSE)
  
  project_root <- dirname(config_file_path)
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  
  return(project_root)
}

# ==============================================================================
# DATA TYPE UTILITIES (V9.9.1: safe_equal NA handling fixed)
# ==============================================================================
# CASE SENSITIVITY NOTE: safe_equal() is CASE-SENSITIVE by default
# This is intentional for data matching - document in survey structure
# ==============================================================================

#' Type-safe equality comparison with trimming (V9.9.1: Fixed NA handling)
#'
#' CASE SENSITIVITY: Comparison is CASE-SENSITIVE
#'   - "Apple" != "apple"
#'   - Both values are trimmed of whitespace before comparison
#'   - If case-insensitive matching needed, use tolower() on both sides
#'
#' NA HANDLING (V9.9.1 FIX):
#'   - Real NA values are treated as missing (non-match)
#'   - NA == NA returns TRUE (both missing)
#'   - NA != "NA" (missing value != string "NA")
#'   - Previous version incorrectly matched NA to string "NA"
#'
#' DESIGN: Converts to character for safety, trims whitespace
#' USAGE: Use for matching survey responses to option text
#'
#' @param a First value/vector
#' @param b Second value/vector
#' @return Logical vector of comparisons
#' @export
#' @examples
#' # Case-sensitive (default)
#' safe_equal("Apple", "apple")  # FALSE
#' 
#' # With whitespace handling
#' safe_equal("  Apple  ", "Apple")  # TRUE
#' 
#' # NA handling (V9.9.1 fix)
#' safe_equal(NA, NA)        # TRUE (both missing)
#' safe_equal(NA, "NA")      # FALSE (missing != string)
#' safe_equal("Apple", NA)   # FALSE
#' 
#' # Case-insensitive (if needed)
#' safe_equal(tolower("Apple"), tolower("apple"))  # TRUE
safe_equal <- function(a, b) {
  if (length(a) == 0 || length(b) == 0) {
    return(logical(0))
  }
  
  # Vectorize to longer length
  max_len <- max(length(a), length(b))
  if (length(a) < max_len) a <- rep_len(a, max_len)
  if (length(b) < max_len) b <- rep_len(b, max_len)
  
  # Initialize result
  result <- rep(FALSE, max_len)
  
  # Identify NAs
  na_a <- is.na(a)
  na_b <- is.na(b)
  
  # Both NA = TRUE (both missing)
  both_na <- na_a & na_b
  result[both_na] <- TRUE
  
  # Compare non-NA values (trim whitespace)
  neither_na <- !na_a & !na_b
  if (any(neither_na)) {
    result[neither_na] <- trimws(as.character(a[neither_na])) == 
                          trimws(as.character(b[neither_na]))
  }
  
  # One NA, one not = FALSE (already initialized to FALSE)
  
  return(result)
}

#' Safely convert to numeric
#'
#' USAGE: Convert config values, survey responses to numeric
#' DESIGN: Suppresses warnings, replaces failures with na_value
#'
#' @param x Value(s) to convert
#' @param na_value Value to use for conversion failures (default: NA_real_)
#' @return Numeric value(s)
#' @export
#' @examples
#' safe_numeric("123")     # 123
#' safe_numeric("abc")     # NA
#' safe_numeric("abc", 0)  # 0
safe_numeric <- function(x, na_value = NA_real_) {
  result <- suppressWarnings(as.numeric(x))
  result[is.na(result)] <- na_value
  return(result)
}

#' Safely convert to logical
#'
#' USAGE: Convert config settings to TRUE/FALSE
#' DESIGN: Handles multiple text representations (Y/N, YES/NO, T/F, 1/0)
#' CASE INSENSITIVE: Converts to uppercase before checking
#'
#' @param x Value to convert (TRUE/FALSE/Y/N/YES/NO/T/F/1/0)
#' @param default Default value if conversion fails (default: FALSE)
#' @return Logical value
#' @export
#' @examples
#' safe_logical("Y")      # TRUE
#' safe_logical("yes")    # TRUE
#' safe_logical("1")      # TRUE
#' safe_logical("N")      # FALSE
#' safe_logical("maybe")  # FALSE (with warning)
safe_logical <- function(x, default = FALSE) {
  if (is.null(x) || (length(x) == 1 && is.na(x))) {
    return(default)
  }
  
  # Already logical
  if (is.logical(x)) {
    return(x)
  }
  
  # Convert to uppercase string
  x_upper <- toupper(trimws(as.character(x)))
  
  # Check TRUE values
  if (x_upper %in% c("TRUE", "T", "Y", "YES", "1")) {
    return(TRUE)
  }
  
  # Check FALSE values
  if (x_upper %in% c("FALSE", "F", "N", "NO", "0")) {
    return(FALSE)
  }
  
  # Couldn't convert
  warning(sprintf(
    "Could not convert '%s' to logical, using default: %s", 
    x, default
  ), call. = FALSE)
  return(default)
}

# ==============================================================================
# DATA VALIDATION HELPERS
# ==============================================================================

#' Check if data frame has data
#'
#' USAGE: Guard clause at start of functions expecting data
#' DESIGN: Simple null/empty check
#'
#' @param df Data frame to check
#' @return Logical, TRUE if data frame has at least 1 row
#' @export
#' @examples
#' if (!has_data(filtered_data)) {
#'   return(NULL)
#' }
has_data <- function(df) {
  !is.null(df) && is.data.frame(df) && nrow(df) > 0
}

#' Validate that column exists in data
#'
#' USAGE: Check column exists before accessing
#' DESIGN: Stops with helpful error if missing
#'
#' @param data Data frame
#' @param column_name Character, column to check
#' @param friendly_name Character, optional friendly name for error (default: column_name)
#' @return Invisible TRUE if exists, stops with error if not
#' @export
validate_column_exists <- function(data, column_name, friendly_name = NULL) {
  if (is.null(friendly_name)) {
    friendly_name <- column_name
  }
  
  if (!column_name %in% names(data)) {
    available_preview <- head(names(data), 10)
    stop(sprintf(
      "Required column '%s' (%s) not found in data\n\nAvailable columns:\n  %s%s",
      friendly_name,
      column_name,
      paste(available_preview, collapse = "\n  "),
      if (ncol(data) > 10) sprintf("\n  ... (%d more columns)", ncol(data) - 10) else ""
    ), call. = FALSE)
  }
  
  invisible(TRUE)
}

# ==============================================================================
# EXCEL UTILITIES
# ==============================================================================
# [CRITICAL] Excel letter generation - used for significance testing columns
# ALGORITHM: Proper base-26 (not base-26 with zero)
# TESTED: Handles A-Z (1-26), AA-ZZ (27-702), AAA-XFD (703-16384)
# ==============================================================================

#' Generate Excel column letters (proper base-26 to XFD)
#'
#' ALGORITHM: Proper base-26 conversion (not base-26 with zero)
#'   - Excel uses: A, B, ..., Z, AA, AB, ..., AZ, BA, ..., ZZ, AAA, ...
#'   - This is NOT simple base-26 because there's no "zero" digit
#'   - Correct algorithm: treat as base-26 with 1-based indexing
#'
#' RANGE: Handles columns 1 to 16,384 (Excel's maximum: A to XFD)
#' PERFORMANCE: O(n * log n) - efficient for typical banner sizes (<100 cols)
#'
#' EXAMPLES:
#'   1 → "A", 26 → "Z", 27 → "AA", 52 → "AZ", 53 → "BA"
#'   702 → "ZZ", 703 → "AAA", 16384 → "XFD"
#'
#' @param n Integer, number of letters to generate
#' @return Character vector of Excel column letters
#' @export
#' @examples
#' generate_excel_letters(3)    # "A" "B" "C"
#' generate_excel_letters(27)   # includes "AA"
#' generate_excel_letters(703)  # includes "AAA"
generate_excel_letters <- function(n) {
  # Validate input
  validate_numeric_param(n, "n", min = 0, max = MAX_EXCEL_COLUMNS)
  
  if (n <= 0) {
    return(character(0))
  }
  
  letters_vec <- character(n)
  
  for (i in 1:n) {
    col_num <- i
    letter <- ""
    
    # Proper base-26 conversion (A=1, not A=0)
    while (col_num > 0) {
      # Subtract 1 to make it 0-indexed for modulo
      remainder <- (col_num - 1) %% 26
      letter <- paste0(LETTERS[remainder + 1], letter)
      col_num <- (col_num - 1) %/% 26
    }
    
    letters_vec[i] <- letter
  }
  
  return(letters_vec)
}

# ==============================================================================
# FORMATTING UTILITIES
# ==============================================================================

#' Format value for output
#'
#' USAGE: Format numeric values before writing to Excel
#' DESIGN: Returns NA_real_ for NULL/NA (displays as blank in Excel)
#' TYPES: frequency, percent, rating, index, numeric
#'
#' V10.0.0: Added numeric type support for numeric questions
#'
#' @param value Numeric value to format
#' @param type Character, type of value (default: "frequency")
#' @param decimal_places_percent Integer, decimals for percentages
#' @param decimal_places_ratings Integer, decimals for ratings
#' @param decimal_places_index Integer, decimals for indices
#' @param decimal_places_numeric Integer, decimals for numeric questions (default: 1)
#' @return Numeric, formatted value or NA_real_
#' @export
format_output_value <- function(value, type = "frequency",
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {
  # Handle NULL and NA up front
  if (is.null(value) || (length(value) == 0L)) {
    return(NA_real_)
  }

  # Coerce to numeric safely
  value_num <- suppressWarnings(as.numeric(value))
  if (is.na(value_num)) {
    return(NA_real_)
  }

  # Choose rounding behaviour by type
  formatted_value <- switch(type,
    # Raw counts – always 0 decimals
    "frequency" = round(value_num, 0),

    # Column / row %s, top 2 box %, etc.
    "percent"   = round(value_num, decimal_places_percent),

    # Ratings (e.g., 1–5, 0–10) – usually 1 decimal
    "rating"    = round(value_num, decimal_places_ratings),

    # Index scores (100 = norm, etc.)
    "index"     = round(value_num, decimal_places_index),

    # NEW: numeric questions (means, medians, SDs, etc.)
    "numeric"   = round(value_num, decimal_places_numeric),

    # Fallback: treat unknown types as percent-style values
    round(value_num, decimal_places_percent)
  )

  return(formatted_value)
}
#' Calculate percentage
#'
#' USAGE: Calculate percentages with automatic 0/0 handling
#' DESIGN: Returns NA_real_ for division by zero (not 0 or error)
#'
#' @param numerator Numeric, numerator
#' @param denominator Numeric, denominator
#' @param decimal_places Integer, decimal places for rounding (default: 0)
#' @return Numeric, percentage (0-100 scale) or NA_real_
#' @export
#' @examples
#' calc_percentage(50, 100)     # 50
#' calc_percentage(1, 3, 1)     # 33.3
#' calc_percentage(10, 0)       # NA
calc_percentage <- function(numerator, denominator, decimal_places = 0) {
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }
  
  return(round((numerator / denominator) * 100, decimal_places))
}

# ==============================================================================
# ERROR LOGGING (V9.9.1: Performance note added)
# ==============================================================================
# DESIGN: Structured error logging for validation and runtime errors
# INTEGRATION: Used by validation.R and main analysis scripts
# PERFORMANCE NOTE: Row-by-row rbind is O(n²) for large logs
#   - For <100 entries: Current approach is fine
#   - For 100+ entries: Accumulate in list, then do.call(rbind, list) once
# ==============================================================================

#' Create empty error log data frame
#'
#' STRUCTURE: Timestamp, Component, Issue_Type, Description, QuestionCode, Severity
#' USAGE: Initialize at start of analysis, populate during validation
#'
#' @return Empty error log data frame
#' @export
create_error_log <- function() {
  data.frame(
    Timestamp = character(),
    Component = character(),
    Issue_Type = character(),
    Description = character(),
    QuestionCode = character(),
    Severity = character(),
    stringsAsFactors = FALSE
  )
}

#' Add Log Entry (Pure Function - MUST Capture Return Value)
#'
#' Adds an entry to the error/warning log. This is a PURE FUNCTION that
#' returns a new data frame. You MUST capture the return value.
#'
#' V10.0: Renamed from log_issue() for clarity. The old name suggested a
#' side-effect function, but this is actually a pure function that returns
#' a modified copy.
#'
#' SEVERITY LEVELS:
#'   - "Error": Prevents analysis from running (missing data, invalid config)
#'   - "Warning": Analysis can proceed but results may be affected
#'   - "Info": Informational messages (not actual problems)
#'
#' PERFORMANCE: O(n) per call due to rbind. For logging 100+ entries:
#'   - Better pattern: Accumulate issues in a list
#'   - Then: error_log <- do.call(rbind, list_of_issues)
#'   - Reduces from O(n²) to O(n)
#'
#' @usage error_log <- add_log_entry(error_log, "ERROR", "Q01", "Message")
#'
#' @param error_log Data frame, error log to append to
#' @param component Character, component where issue occurred
#' @param issue_type Character, type of issue
#' @param description Character, issue description
#' @param question_code Character, related question code (default: "")
#' @param severity Character, severity level (default: "Warning")
#' @return Data frame with new log entry appended (MUST BE CAPTURED)
#' @export
#' @examples
#' # CORRECT usage - assign the result:
#' error_log <- add_log_entry(error_log, "Validation", "Missing Column",
#'                           "Column Q1 not found", "Q1", "Error")
#'
#' # INCORRECT - will not work (issue not logged):
#' # add_log_entry(error_log, "Validation", "Missing Column", "Column Q1 not found")
#'
#' # For many issues, use list accumulation:
#' issues <- list()
#' issues[[1]] <- data.frame(Timestamp = ..., Component = ..., ...)
#' issues[[2]] <- data.frame(Timestamp = ..., Component = ..., ...)
#' error_log <- do.call(rbind, issues)
add_log_entry <- function(error_log, component, issue_type, description,
                         question_code = "", severity = "Warning") {
  new_entry <- data.frame(
    Timestamp = as.character(Sys.time()),
    Component = component,
    Issue_Type = issue_type,
    Description = description,
    QuestionCode = question_code,
    Severity = severity,
    stringsAsFactors = FALSE
  )

  rbind(error_log, new_entry)
}

# Backward compatibility alias (V10.0)
# Keep log_issue as an alias so existing code continues to work
log_issue <- add_log_entry

# ==============================================================================
# SURVEY STRUCTURE LOADING
# ==============================================================================
# [PERFORMANCE] Reads multiple Excel sheets - cache result if calling repeatedly
# VALIDATION: Performs basic structure validation, detailed checks in validation.R
# ==============================================================================

#' Load complete survey structure
#'
#' USAGE: Load at start of analysis to get questions and options
#' DESIGN: Returns list with project config, questions, and options
#' VALIDATION: Basic checks here, comprehensive validation in validation.R
#' ERROR HANDLING: Detailed, actionable error messages
#'
#' @param structure_file_path Character, path to Survey_Structure.xlsx
#' @param project_root Character, optional project root for resolving paths
#' @return List with $project, $questions, $options, $structure_file, $project_root
#' @export
#' @examples
#' survey_structure <- load_survey_structure("Survey_Structure.xlsx")
#' questions <- survey_structure$questions
#' options <- survey_structure$options
load_survey_structure <- function(structure_file_path, project_root = NULL) {
  # Validate path
  validate_file_path(structure_file_path, "structure_file_path", 
                    must_exist = TRUE, 
                    required_extensions = SUPPORTED_CONFIG_FORMATS)
  
  # Determine project root
  if (is.null(project_root)) {
    project_root <- dirname(structure_file_path)
  }
  
  cat("Loading survey structure from:", basename(structure_file_path), "\n")
  
  # Load sheets with error handling
  tryCatch({
    # Load Project sheet
    project_config <- load_config_sheet(structure_file_path, "Project")
    
    # Load Questions sheet
    questions_df <- readxl::read_excel(structure_file_path, sheet = "Questions", col_types = "text")

    # Load Options sheet
    options_df <- readxl::read_excel(structure_file_path, sheet = "Options", col_types = "text")
    
  }, error = function(e) {
    stop(sprintf(
      "Failed to load survey structure\nFile: %s\nError: %s\n\nTroubleshooting:\n  1. Verify file has sheets: Project, Questions, Options\n  2. Check file is not corrupted\n  3. Ensure file is not open in Excel",
      basename(structure_file_path),
      conditionMessage(e)
    ), call. = FALSE)
  })
  
  # Validate Questions sheet structure
  required_question_cols <- c("QuestionCode", "QuestionText", "Variable_Type", "Columns")
  missing_q <- setdiff(required_question_cols, names(questions_df))
  
  if (length(missing_q) > 0) {
    stop(sprintf(
      "Questions sheet missing required columns: %s\n\nFound columns: %s\n\nRequired columns: %s",
      paste(missing_q, collapse = ", "),
      paste(names(questions_df), collapse = ", "),
      paste(required_question_cols, collapse = ", ")
    ), call. = FALSE)
  }
  
  # Validate Options sheet structure
  required_option_cols <- c("QuestionCode", "OptionText", "DisplayText")
  missing_o <- setdiff(required_option_cols, names(options_df))
  
  if (length(missing_o) > 0) {
    stop(sprintf(
      "Options sheet missing required columns: %s\n\nFound columns: %s\n\nRequired columns: %s",
      paste(missing_o, collapse = ", "),
      paste(names(options_df), collapse = ", "),
      paste(required_option_cols, collapse = ", ")
    ), call. = FALSE)
  }
  
  # Success message
  cat(sprintf(
    "✓ Loaded: %d questions, %d options\n",
    nrow(questions_df),
    nrow(options_df)
  ))
  
  return(list(
    project = project_config,
    questions = questions_df,
    options = options_df,
    structure_file = structure_file_path,
    project_root = project_root
  ))
}

# ==============================================================================
# DATA LOADING (V9.9: .SAV SUPPORT, V9.9.1: CSV fast-path + .sav label handling)
# ==============================================================================
# [PERFORMANCE] Can be slow for large files - shows file size warning
# FORMATS: .xlsx, .xls, .csv, .sav (SPSS)
# MEMORY: Loads entire file into memory - check available RAM for large files
# V9.9.1: CSV fast-path via data.table (10x speedup when available)
# V9.9.1: Optional .sav label normalization to prevent downstream type issues
# ==============================================================================

#' Load survey data file (V9.9.1: CSV fast-path + .sav label handling)
#'
#' SUPPORTED FORMATS: .xlsx, .xls, .csv, .sav (SPSS via haven package)
#' 
#' PERFORMANCE: 
#'   - Excel: ~10MB/sec on typical hardware
#'   - CSV (base R): ~50MB/sec
#'   - CSV (data.table): ~500MB/sec [V9.9.1: Auto-enabled if package available]
#'   - SPSS: ~20MB/sec
#' 
#' MEMORY: Loads entire file into RAM
#'   - Files >500MB will show warning
#'   - Consider splitting very large datasets
#'
#' SPSS LABELS (V9.9.1): 
#'   - convert_labelled=FALSE (default): Keeps SPSS labels (labelled class)
#'   - convert_labelled=TRUE: Converts to plain R types (numeric/character/factor)
#'   - Use TRUE if downstream code expects standard R types
#'
#' @param data_file_path Character, path to data file (relative or absolute)
#' @param project_root Character, optional project root for resolving relative paths
#' @param convert_labelled Logical, convert SPSS labelled to plain R types (default: FALSE)
#' @return Data frame with survey responses
#' @export
#' @examples
#' survey_data <- load_survey_data("Data/survey.xlsx", project_root)
#' survey_data <- load_survey_data("Data/spss_data.sav", project_root)
#' 
#' # For .sav with label conversion
#' survey_data <- load_survey_data("Data/spss_data.sav", project_root, 
#'                                 convert_labelled = TRUE)
load_survey_data <- function(data_file_path, project_root = NULL, 
                             convert_labelled = FALSE) {
  # Resolve path if relative
  if (!is.null(project_root) && !file.exists(data_file_path)) {
    data_file_path <- resolve_path(project_root, data_file_path)
  }
  
  # Validate file exists
  validate_file_path(data_file_path, "data_file_path", must_exist = TRUE)
  
  cat("Loading survey data from:", basename(data_file_path), "\n")
  
  # Detect file type
  file_ext <- tolower(tools::file_ext(data_file_path))
  
  if (!file_ext %in% SUPPORTED_DATA_FORMATS) {
    stop(sprintf(
      "Unsupported file type: .%s\n\nSupported formats: %s",
      file_ext,
      paste0(".", SUPPORTED_DATA_FORMATS, collapse = ", ")
    ), call. = FALSE)
  }
  
  # Load data with format-specific handling
  survey_data <- tryCatch({
    switch(file_ext,
      "xlsx" = readxl::read_excel(data_file_path),
      "xls"  = readxl::read_excel(data_file_path),
      "csv"  = {
        # V9.9.1: CSV fast-path via data.table if available
        if (is_package_available("data.table")) {
          cat("  Using data.table::fread() for faster loading...\n")
          data.table::fread(data_file_path, data.table = FALSE)
        } else {
          read.csv(data_file_path, stringsAsFactors = FALSE)
        }
      },
      "sav"  = {
        # SPSS support via haven package
        if (!is_package_available("haven")) {
          stop(
            ".sav files require the 'haven' package\n\nInstall with:\n  install.packages('haven')",
            call. = FALSE
          )
        }
        
        dat <- haven::read_sav(data_file_path)
        
        # V9.9.1: Optional label conversion
        if (convert_labelled) {
          cat("  Converting SPSS labels to plain R types...\n")
          # Remove label attributes but keep numeric values
          dat <- haven::zap_labels(dat)
          # Optionally convert value labels to factors:
          # dat <- haven::as_factor(dat, levels = "labels")
        }
        
        dat
      }
    )
  }, error = function(e) {
    stop(sprintf(
      "Failed to load data file\nFile: %s\nError: %s\n\nTroubleshooting:\n  1. Verify file is not corrupted\n  2. Check file is not open in another program\n  3. For Excel: try saving as .csv and retry\n  4. Check file permissions",
      basename(data_file_path),
      conditionMessage(e)
    ), call. = FALSE)
  })
  
  # Validate loaded data
  if (!is.data.frame(survey_data)) {
    stop(sprintf(
      "Data file loaded but is not a data frame (got: %s)",
      paste(class(survey_data), collapse = ", ")
    ), call. = FALSE)
  }
  
  if (nrow(survey_data) == 0) {
    stop("Data file is empty (0 rows)", call. = FALSE)
  }
  
  if (ncol(survey_data) == 0) {
    stop("Data file has no columns", call. = FALSE)
  }
  
  # Success message
  cat(sprintf(
    "✓ Loaded: %s rows, %s columns\n",
    format(nrow(survey_data), big.mark = ","),
    format(ncol(survey_data), big.mark = ",")
  ))
  
  return(survey_data)
}

#' Load Survey Data with Smart Caching (V10.0)
#'
#' For large Excel files (>50MB), automatically creates a CSV cache
#' for dramatically faster subsequent loads. Excel loads at ~10MB/sec
#' while CSV via data.table loads at ~500MB/sec (50x faster).
#'
#' USAGE: Drop-in replacement for load_survey_data() when working with
#' large Excel files that are read multiple times.
#'
#' CACHING BEHAVIOR:
#' - Cache file stored alongside source as {filename}_cache.csv
#' - Cache auto-regenerates when source file is modified
#' - Cache only created if file size exceeds threshold
#' - Falls back to standard load_survey_data() if caching not beneficial
#'
#' @param data_file_path Character, path to data file
#' @param project_root Character, optional project root
#' @param auto_cache Logical, enable CSV caching for large files (default: TRUE)
#' @param cache_threshold_mb Numeric, file size threshold in MB for caching (default: 50)
#' @param convert_labelled Logical, convert SPSS labels (default: FALSE)
#' @return Data frame with survey responses
#' @export
#' @examples
#' # Standard usage - will cache large Excel files automatically
#' survey_data <- load_survey_data_smart("Data/large_survey.xlsx", project_root)
#'
#' # Disable caching
#' survey_data <- load_survey_data_smart("Data/survey.xlsx", auto_cache = FALSE)
#'
#' # Lower threshold (cache files >10MB)
#' survey_data <- load_survey_data_smart("Data/survey.xlsx", cache_threshold_mb = 10)
load_survey_data_smart <- function(data_file_path, project_root = NULL,
                                   auto_cache = TRUE,
                                   cache_threshold_mb = 50,
                                   convert_labelled = FALSE) {

  # Resolve path if relative
  if (!is.null(project_root) && !file.exists(data_file_path)) {
    data_file_path <- resolve_path(project_root, data_file_path)
  }

  file_ext <- tolower(tools::file_ext(data_file_path))

  # Smart caching for large Excel files
  if (auto_cache && file_ext %in% c("xlsx", "xls")) {
    file_size_mb <- file.info(data_file_path)$size / 1024^2

    if (file_size_mb > cache_threshold_mb && is_package_available("data.table")) {
      csv_cache_path <- sub("\\.(xlsx|xls)$", "_cache.csv", data_file_path)

      # Check if cache exists and is newer than source
      cache_valid <- file.exists(csv_cache_path) &&
                     file.mtime(csv_cache_path) >= file.mtime(data_file_path)

      if (!cache_valid) {
        cat(sprintf("Large Excel file (%.1f MB) detected. Creating CSV cache...\n", file_size_mb))
        data <- readxl::read_excel(data_file_path)
        data.table::fwrite(data, csv_cache_path)
        cat("✓ CSV cache created:", basename(csv_cache_path), "\n")
        return(as.data.frame(data))
      } else {
        cat("Loading from CSV cache (faster)...\n")
        return(data.table::fread(csv_cache_path, data.table = FALSE))
      }
    }
  }

  # Default: use standard loader
  load_survey_data(data_file_path, project_root, convert_labelled)
}

# ==============================================================================
# VERSION & BRANDING
# ==============================================================================

#' Get toolkit version
#'
#' @return Character, version string
#' @export
get_toolkit_version <- function() {
  return(SCRIPT_VERSION)
}

#' Print toolkit header
#'
#' USAGE: Display at start of analysis scripts for branding
#'
#' @param analysis_type Character, type of analysis being run
#' @export
print_toolkit_header <- function(analysis_type = "Analysis") {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("  R SURVEY ANALYTICS TOOLKIT V", get_toolkit_version(), "\n", sep = "")
  cat("  ", analysis_type, "\n", sep = "")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("\n")
}

# ==============================================================================
# BASE FILTER APPLICATION
# ==============================================================================

# ==============================================================================
# BASE FILTER HELPERS (INTERNAL)
# ==============================================================================

#' Clean Unicode and special characters from filter expression
#' @keywords internal
clean_filter_expression <- function(filter_expression) {
  # Clean Unicode and special characters
  filter_expression <- tryCatch({
    cleaned <- iconv(filter_expression, to = "ASCII//TRANSLIT", sub = "")
    if (is.na(cleaned)) filter_expression else cleaned
  }, error = function(e) filter_expression)

  # Replace Unicode spaces and quotes
  filter_expression <- gsub("[\u00A0\u2000-\u200B\u202F\u205F\u3000]", " ", filter_expression)
  filter_expression <- gsub("[\u2018\u2019\u201A\u201B]", "'", filter_expression)
  filter_expression <- gsub("[\u201C\u201D\u201E\u201F]", '"', filter_expression)
  filter_expression <- trimws(filter_expression)

  return(filter_expression)
}

#' Check filter expression for dangerous patterns
#' @keywords internal
check_filter_security <- function(filter_expression) {
  # Security: Check for dangerous characters
  if (grepl("[^A-Za-z0-9_$.()&|!<>= +*/,'\"\\[\\]%:-]", filter_expression)) {
    stop(sprintf(
      "Filter contains potentially unsafe characters: '%s'",
      filter_expression
    ), call. = FALSE)
  }

  # Check for dangerous patterns
  dangerous_patterns <- c(
    "system\\s*\\(", "eval\\s*\\(", "source\\s*\\(", "library\\s*\\(",
    "require\\s*\\(", "<-", "<<-", "->", "->>", "rm\\s*\\(",
    "file\\.", "sink\\s*\\(", "options\\s*\\(", "\\.GlobalEnv",
    "::", ":::", "get\\s*\\(", "assign\\s*\\(", "mget\\s*\\(", "do\\.call\\s*\\("
  )

  for (pattern in dangerous_patterns) {
    if (grepl(pattern, filter_expression, ignore.case = TRUE)) {
      stop(sprintf(
        "Filter contains unsafe pattern: '%s' not allowed",
        gsub("\\\\s\\*\\\\\\(", "(", pattern)
      ), call. = FALSE)
    }
  }

  return(invisible(NULL))
}

#' Validate filter evaluation result
#' @keywords internal
validate_filter_result <- function(filter_result, data, filter_expression) {
  # Check return type
  if (!is.logical(filter_result)) {
    stop(sprintf(
      "Filter must return logical vector, got: %s",
      class(filter_result)[1]
    ), call. = FALSE)
  }

  # Check length
  if (length(filter_result) != nrow(data)) {
    stop(sprintf(
      "Filter returned %d values but data has %d rows",
      length(filter_result),
      nrow(data)
    ), call. = FALSE)
  }

  # Replace NAs with FALSE
  filter_result[is.na(filter_result)] <- FALSE

  # Check if any rows retained
  n_retained <- sum(filter_result)
  if (n_retained == 0) {
    warning(sprintf(
      "Filter retains 0 rows (filters out all data): '%s'",
      filter_expression
    ), call. = FALSE)
  }

  return(filter_result)
}

#' Apply base filter to survey data
#'
#' USAGE: Filter data for specific question analysis
#' DESIGN: Returns filtered data with .original_row tracking
#' SECURITY: Uses same validation as validate_base_filter()
#'
#' @param data Data frame, survey data
#' @param filter_expression Character, R expression for filtering
#' @return Data frame, filtered subset with .original_row column
#' @export
#' @examples
#' # Filter to adults only
#' filtered <- apply_base_filter(survey_data, "Age >= 18")
#' 
#' # Filter with multiple conditions
#' filtered <- apply_base_filter(survey_data, "Age >= 18 & Region == 'North'")
apply_base_filter <- function(data, filter_expression) {
  # Validate inputs
  if (!is.data.frame(data) || nrow(data) == 0) {
    stop("data must be a non-empty data frame", call. = FALSE)
  }

  # Empty/null filter = return all data with row indices
  if (is.null(filter_expression) || is.na(filter_expression) ||
      trimws(filter_expression) == "") {
    data$.original_row <- seq_len(nrow(data))
    return(data)
  }

  # Validate filter is safe
  if (!is.character(filter_expression) || length(filter_expression) != 1) {
    stop("filter_expression must be a single character string", call. = FALSE)
  }

  # Clean and validate filter expression (delegated to helpers)
  filter_expression <- clean_filter_expression(filter_expression)
  check_filter_security(filter_expression)

  # Apply filter
  tryCatch({
    # Evaluate filter expression
    filter_result <- eval(
      parse(text = filter_expression),
      envir = data,
      enclos = parent.frame()
    )

    # Validate and clean result (delegated to helper)
    filter_result <- validate_filter_result(filter_result, data, filter_expression)

    # Create filtered dataset with original row tracking
    original_rows <- which(filter_result)
    filtered_data <- data[filter_result, , drop = FALSE]
    filtered_data$.original_row <- original_rows

    return(filtered_data)

  }, error = function(e) {
    stop(sprintf(
      "Filter evaluation failed: %s\nExpression: '%s'",
      conditionMessage(e),
      filter_expression
    ), call. = FALSE)
  })
}        
        
# ==============================================================================
# MAINTENANCE DOCUMENTATION
# ==============================================================================
# 
# OVERVIEW:
# This script provides foundational utilities used across ALL toolkit components.
# Changes here affect: run_crosstabs.r, validation.R, weighting.R, ranking.R
#
# TESTING PROTOCOL:
# Before deploying changes to production:
# 1. Run unit tests on changed functions (see test_shared_functions.R)
# 2. Run integration tests with all dependent scripts
# 3. Test with small dataset (fast feedback)
# 4. Test with large dataset (performance validation)
# 5. Test error cases (missing files, corrupted data, etc.)
#
# DEPENDENCY MAP:
# 
# shared_functions.R (THIS FILE)
#   ├─→ Used by: run_crosstabs.r
#   ├─→ Used by: validation.R
#   ├─→ Used by: weighting.R
#   ├─→ Used by: ranking.R
#   └─→ External packages: readxl, tools, haven (optional), data.table (optional)
#
# CRITICAL FUNCTIONS (Extra care when modifying):
# - generate_excel_letters(): Used for significance testing column mapping
# - safe_equal(): Used for matching survey responses to options
# - load_survey_structure(): Core data loading function
# - validate_data_frame(): Used extensively for input validation
#
# PERFORMANCE NOTES:
# - Excel loading: Use load_survey_data_smart() for auto CSV caching (V10.0)
# - CSV with data.table: 10x faster than base read.csv (auto-enabled if available)
# - Path resolution: Results can be cached if calling repeatedly
# - Config loading: Cache config objects, don't reload on every function call
# - add_log_entry(): For 100+ entries, use list accumulation pattern (see function docs)
# - Memory monitoring: Uses lobstr::obj_size() (V10.0 - replaces deprecated pryr)
#
# BACKWARD COMPATIBILITY:
# - V8.0 → V9.9: Breaking changes in excel letter generation only
# - V9.9 → V9.9.1: All changes are additions (no breaking changes)
# - V9.9.1 → V10.0.0: New optional parameter (backward compatible)
#   - format_output_value() gains decimal_places_numeric parameter (optional, has default)
#   - All existing calls continue to work without modification
# - V10.0.0 → V10.0: All changes are backward compatible
#   - log_issue() kept as alias for new add_log_entry()
#   - load_survey_data() unchanged, new load_survey_data_smart() added as drop-in replacement
#   - pryr → lobstr only affects internal memory monitoring (no API change)
# - Function signatures unchanged except new optional parameters
# - All V8.0 code calling these functions will work (with warnings)
#
# COMMON ISSUES:
# 1. "File not found" errors: Check working directory and relative paths
# 2. Excel file corruption: Try opening and re-saving in Excel
# 3. Memory issues with large files: Consider chunking or sampling
# 4. Case sensitivity: safe_equal() is case-sensitive by design
# 5. SPSS labelled columns: Use convert_labelled=TRUE if downstream code expects plain types
#
# VERSION HISTORY DETAIL:
# V10.0 (Current - Practical Enhancements):
# - Replaced deprecated pryr package with lobstr for memory monitoring
# - Renamed log_issue() to add_log_entry() for clarity (alias kept for compatibility)
# - Added load_survey_data_smart() for automatic CSV caching of large Excel files
# - Enhanced check_memory() to use lobstr::obj_size()
# - Updated documentation throughout
#
# V10.0.0 (Numeric Question Support):
# - CRITICAL FIX: format_output_value() now supports "numeric" type (prevents crashes in numeric_processor.R)
# - Added decimal_places_numeric parameter to format_output_value()
# - Added SHARED_FUNCTIONS_VERSION constant for version checking
# - Improved NULL/NA handling in format_output_value()
# - Better error handling for edge cases
#
# V9.9.1 (External Review Fixes):
# - Fixed extension validation for output files (validate_extension_even_if_missing)
# - Fixed duplicate config settings detection (blocks silently overwriting values)
# - Added typed config getters (get_numeric_config, get_logical_config, get_char_config)
# - Fixed safe_equal() NA handling (real NA vs string "NA")
# - Added source_if_exists() environment control
# - Added CSV fast-path via data.table (10x speedup when available)
# - Added .sav label normalization option (convert_labelled parameter)
# - Added performance note for log_issue() batch pattern
#
# V9.9 (Production Release):
# - Fixed Excel letter bug (proper base-26 algorithm)
# - Added comprehensive validation functions
# - Added .sav (SPSS) support
# - Enhanced all error messages
# - Added performance documentation
# - Added maintenance documentation
#
# V8.0 (Deprecated):
# - Excel letter generation had bug after column Z
# - Missing modern validation functions
# - Limited file format support
# - Basic error messages
#
# ==============================================================================
# LOGGING & MONITORING FUNCTIONS (Added from run_crosstabs.R migration)
# ==============================================================================

#' Log message with timestamp and level
#'
#' @param msg Character, message to log
#' @param level Character, log level (INFO, WARNING, ERROR, DEBUG)
#' @param verbose Logical, whether to display
#' @return Invisible NULL
#' @export
log_message <- function(msg, level = "INFO", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s: %s\n", timestamp, level, msg))
  invisible(NULL)
}

#' Log progress with percentage and ETA
#'
#' @param current Integer, current item
#' @param total Integer, total items
#' @param item Character, item description
#' @param start_time POSIXct, when processing started
#' @return Invisible NULL
log_progress <- function(current, total, item = "", start_time = NULL) {
  pct <- round(100 * current / total, 1)

  eta_str <- ""
  if (!is.null(start_time) && current > 0) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    rate <- elapsed / current
    remaining <- (total - current) * rate
    eta_str <- sprintf(" | ETA: %s", format_seconds(remaining))
  }

  cat(sprintf("\r[%3d%%] %d/%d%s %s",
             round(pct), current, total, eta_str, item))

  if (current == total) cat("\n")
  invisible(NULL)
}

#' Format seconds into readable time
#'
#' @param seconds Numeric, seconds
#' @return Character, formatted time
format_seconds <- function(seconds) {
  if (seconds < 60) {
    return(sprintf("%.0fs", seconds))
  } else if (seconds < 3600) {
    return(sprintf("%.1fm", seconds / 60))
  } else {
    return(sprintf("%.1fh", seconds / 3600))
  }
}

#' Check and warn about memory usage
#'
#' Memory reported in GiB (1024^3 bytes) to match OS conventions
#' NOTE: Requires MEMORY_WARNING_GIB and MEMORY_CRITICAL_GIB constants from caller
#' V10.0: Updated to use lobstr instead of deprecated pryr package
#'
#' @param force_gc Logical, force garbage collection if high
#' @param warning_threshold Numeric, warning threshold in GiB (default 6)
#' @param critical_threshold Numeric, critical threshold in GiB (default 8)
#' @return Invisible NULL
check_memory <- function(force_gc = TRUE, warning_threshold = 6, critical_threshold = 8) {
  if (!requireNamespace("lobstr", quietly = TRUE)) return(invisible(NULL))

  mem_used_bytes <- lobstr::obj_size(environment())
  mem_used_gib <- as.numeric(mem_used_bytes) / (1024^3)

  if (mem_used_gib > critical_threshold) {
    log_message(sprintf("CRITICAL: Memory usage %.1f GiB - forcing cleanup",
                       mem_used_gib), "ERROR")
    if (force_gc) gc()
  } else if (mem_used_gib > warning_threshold) {
    log_message(sprintf("WARNING: Memory usage %.1f GiB", mem_used_gib), "WARNING")
    if (force_gc) gc()
  }

  invisible(NULL)
}

#' Validate weight vector against data
#'
#' @param weights Numeric vector of weights
#' @param data_rows Integer, expected number of rows
#' @param allow_zero Logical, allow zero weights
#' @return Invisible TRUE if valid
#' @export
validate_weights <- function(weights, data_rows, allow_zero = TRUE) {
  if (!is.numeric(weights)) {
    stop("Weights must be numeric, got: ", class(weights)[1])
  }

  if (length(weights) != data_rows) {
    stop(sprintf("Weight vector length (%d) must match data rows (%d)",
                length(weights), data_rows))
  }

  if (any(weights < 0, na.rm = TRUE)) {
    stop("Weights cannot be negative")
  }

  if (!allow_zero && all(weights == 0)) {
    stop("All weights are zero")
  }

  n_na <- sum(is.na(weights))
  if (n_na > 0) {
    warning(sprintf("Weight vector contains %d NA values (%.1f%%)",
                   n_na, 100 * n_na / length(weights)))
  }

  invisible(TRUE)
}

#' Safely execute with error handling
#'
#' @param expr Expression to evaluate
#' @param default Default value on error
#' @param error_msg Error message prefix
#' @param silent Suppress warnings
#' @return Result or default
#' @export
safe_execute <- function(expr, default = NA, error_msg = "Operation failed",
                        silent = FALSE) {
  tryCatch(
    expr,
    error = function(e) {
      if (!silent) {
        warning(sprintf("%s: %s", error_msg, conditionMessage(e)), call. = FALSE)
      }
      return(default)
    }
  )
}

#' Batch rbind (efficient)
#'
#' @param row_list List of data frames
#' @return Single data frame
#' @export
batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  do.call(rbind, row_list)
}

# ==============================================================================
# END OF SHARED_FUNCTIONS.R V9.9.1
# ==============================================================================
