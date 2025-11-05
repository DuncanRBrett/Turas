# ==============================================================================
# TURAS CORE - VALIDATION
# ==============================================================================
# Comprehensive input validation functions
# Migrated from shared_functions.r V9.9.1
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
validate_data_frame <- function(data, 
                                required_cols = NULL, 
                                min_rows = 1, 
                                max_rows = Inf, 
                                param_name = "data") {
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
validate_numeric_param <- function(value, 
                                   param_name, 
                                   min = -Inf, 
                                   max = Inf, 
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
#' @examples
#' validate_logical_param(enable_weighting, "enable_weighting")
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
#' @examples
#' validate_char_param("North", "region", allowed_values = c("North", "South", "East", "West"))
validate_char_param <- function(value, 
                                param_name, 
                                allowed_values = NULL, 
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

#' Validate file path exists and is accessible
#'
#' USAGE: Validate file paths before attempting to read OR write
#' DESIGN: Checks existence, readability, optionally file type
#' V9.9.1: Extension validation works for output files (must_exist=FALSE)
#'
#' @param file_path Character, path to file
#' @param param_name Character, parameter name for errors
#' @param must_exist Logical, must file exist (default: TRUE)
#' @param required_extensions Character vector, allowed extensions (NULL = any)
#' @param validate_extension_even_if_missing Logical, validate extension even 
#'        if file doesn't exist yet (default: FALSE)
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
validate_file_path <- function(file_path, 
                               param_name = "file_path", 
                               must_exist = TRUE, 
                               required_extensions = NULL,
                               validate_extension_even_if_missing = FALSE) {
  # Basic validation
  validate_char_param(file_path, param_name, allow_empty = FALSE)
  
  # Existence check
  if (must_exist && !file.exists(file_path)) {
    # Provide helpful context
    dir_path <- dirname(file_path)
    file_name <- basename(file_path)
    
    stop(sprintf(
      "%s: File not found\n  Path: %s\n  Directory exists: %s\n  Looking for: %s\n\nTroubleshooting:\n  1. Check spelling and case sensitivity\n  2. Verify file is in correct location\n  3. Check file permissions",
      param_name,
      file_path,
      if (dir.exists(dir_path)) "YES" else "NO",
      file_name
    ), call. = FALSE)
  }
  
  # Extension check (works for output files too in V9.9.1)
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
#' @examples
#' validate_column_exists(survey_data, "Q1_Response")
#' validate_column_exists(survey_data, "Q1", "Question 1")
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

# Success message
cat("Turas validation loaded (COMPLETE!)\n")