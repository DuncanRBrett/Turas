# ==============================================================================
# VALIDATION UTILITIES - TURAS V10.1 (Phase 3 Refactoring)
# ==============================================================================
# Input validation functions for data, parameters, files, and columns
# Extracted from shared_functions.R for better modularity
#
# VERSION HISTORY:
# V10.1 - Extracted from shared_functions.R (Phase 3 Refactoring)
#        - validate_data_frame, validate_numeric_param, validate_logical_param
#        - validate_char_param, validate_file_path, validate_column_exists
#        - validate_weights, has_data
#
# DEPENDENCIES:
# - tabs_refuse() from 00_guard.R (for error handling)
#
# ==============================================================================

# ==============================================================================
# CONSTANTS
# ==============================================================================

# File Size Limits (bytes)
MAX_FILE_SIZE_MB <- 500
MAX_FILE_SIZE_BYTES <- MAX_FILE_SIZE_MB * 1024 * 1024

# ==============================================================================
# DATA FRAME VALIDATION
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
    tabs_refuse(
      code = "ARG_INVALID_TYPE",
      title = "Invalid Data Type",
      problem = sprintf("%s must be a data frame, got: %s", param_name, paste(class(data), collapse = ", ")),
      why_it_matters = "Data validation requires a proper data frame structure to check rows and columns.",
      how_to_fix = sprintf("Pass a data frame to %s. Use as.data.frame() to convert if needed.", param_name)
    )
  }

  # Row count check
  n_rows <- nrow(data)
  if (n_rows < min_rows) {
    tabs_refuse(
      code = "DATA_INSUFFICIENT_ROWS",
      title = "Insufficient Data Rows",
      problem = sprintf("%s must have at least %d rows, has %d", param_name, min_rows, n_rows),
      why_it_matters = "Analysis requires a minimum number of data rows to produce meaningful results.",
      how_to_fix = sprintf("Ensure your dataset contains at least %d rows before processing.", min_rows)
    )
  }

  if (n_rows > max_rows) {
    tabs_refuse(
      code = "DATA_EXCEEDS_MAX_ROWS",
      title = "Data Exceeds Maximum Rows",
      problem = sprintf("%s exceeds maximum %d rows, has %d", param_name, max_rows, n_rows),
      why_it_matters = "Processing very large datasets may cause memory issues or performance problems.",
      how_to_fix = sprintf("Reduce dataset to %d rows or fewer, or adjust the max_rows parameter.", max_rows)
    )
  }

  # Column check
  if (!is.null(required_cols) && length(required_cols) > 0) {
    missing <- setdiff(required_cols, names(data))
    if (length(missing) > 0) {
      available_preview <- head(names(data), 10)
      tabs_refuse(
        code = "DATA_MISSING_COLUMNS",
        title = "Missing Required Columns",
        problem = sprintf("%s missing required columns: %s", param_name, paste(missing, collapse = ", ")),
        why_it_matters = "Analysis cannot proceed without the required data columns.",
        how_to_fix = sprintf("Available columns: %s%s. Ensure your data includes: %s",
          paste(available_preview, collapse = ", "),
          if (ncol(data) > 10) sprintf(" ... (%d more)", ncol(data) - 10) else "",
          paste(missing, collapse = ", "))
      )
    }
  }

  invisible(TRUE)
}


# ==============================================================================
# PARAMETER VALIDATION
# ==============================================================================

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
      tabs_refuse(
        code = "ARG_NA_NOT_ALLOWED",
        title = "NA Value Not Allowed",
        problem = sprintf("%s cannot be NA", param_name),
        why_it_matters = "This parameter requires a valid numeric value to proceed with calculations.",
        how_to_fix = sprintf("Provide a valid numeric value for %s instead of NA.", param_name)
      )
    }
    return(invisible(TRUE))
  }

  # Type and length check
  if (!is.numeric(value) || length(value) != 1) {
    tabs_refuse(
      code = "ARG_INVALID_NUMERIC",
      title = "Invalid Numeric Parameter",
      problem = sprintf("%s must be a single numeric value, got: %s (length %d)", param_name, class(value)[1], length(value)),
      why_it_matters = "Numeric parameters must be single values for proper validation and calculations.",
      how_to_fix = sprintf("Provide a single numeric value for %s (e.g., 0.95 instead of c(0.95, 0.99)).", param_name)
    )
  }

  # Range check
  if (value < min || value > max) {
    tabs_refuse(
      code = "ARG_OUT_OF_RANGE",
      title = "Parameter Out of Range",
      problem = sprintf("%s must be between %g and %g, got: %g", param_name, min, max, value),
      why_it_matters = "Values outside the valid range can produce incorrect or meaningless results.",
      how_to_fix = sprintf("Set %s to a value between %g and %g.", param_name, min, max)
    )
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
    tabs_refuse(
      code = "ARG_INVALID_LOGICAL",
      title = "Invalid Logical Parameter",
      problem = sprintf("%s must be TRUE or FALSE, got: %s", param_name, if (is.null(value)) "NULL" else as.character(value)),
      why_it_matters = "Logical parameters control critical analysis behavior and must be explicitly TRUE or FALSE.",
      how_to_fix = sprintf("Set %s to either TRUE or FALSE (not NA, NULL, or other values).", param_name)
    )
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
    tabs_refuse(
      code = "ARG_INVALID_CHARACTER",
      title = "Invalid Character Parameter",
      problem = sprintf("%s must be a single character value, got: %s", param_name, if (is.null(value)) "NULL" else class(value)[1]),
      why_it_matters = "Character parameters must be valid strings for configuration and file operations.",
      how_to_fix = sprintf("Provide a single character string for %s (e.g., \"value\" not c(\"val1\", \"val2\")).", param_name)
    )
  }

  # Empty check
  if (!allow_empty && nchar(trimws(value)) == 0) {
    tabs_refuse(
      code = "ARG_EMPTY_STRING",
      title = "Empty String Not Allowed",
      problem = sprintf("%s cannot be empty", param_name),
      why_it_matters = "Empty strings cannot be used for meaningful configuration or data operations.",
      how_to_fix = sprintf("Provide a non-empty value for %s.", param_name)
    )
  }

  # Allowed values check
  if (!is.null(allowed_values) && !value %in% allowed_values) {
    tabs_refuse(
      code = "ARG_INVALID_VALUE",
      title = "Invalid Parameter Value",
      problem = sprintf("%s must be one of: %s. Got: '%s'", param_name, paste(allowed_values, collapse = ", "), value),
      why_it_matters = "Only specific values are supported for this parameter to ensure correct behavior.",
      how_to_fix = sprintf("Set %s to one of the allowed values: %s", param_name, paste(allowed_values, collapse = ", "))
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# FILE PATH VALIDATION
# ==============================================================================

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

    tabs_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "File Not Found",
      problem = sprintf("%s: File not found at path: %s", param_name, file_path),
      why_it_matters = sprintf("The file is required for processing. Directory exists: %s", if (dir.exists(dir_part)) "YES" else "NO"),
      how_to_fix = sprintf("Looking for: %s. Check: 1) spelling and case sensitivity, 2) file is in correct location, 3) file permissions", file_part)
    )
  }

  # Extension check (V9.9.1: Now works for output files too)
  if (!is.null(required_extensions) &&
      (must_exist || validate_extension_even_if_missing)) {
    file_ext <- tolower(tools::file_ext(file_path))

    # Check extension is present and valid
    if (!nzchar(file_ext) || !file_ext %in% required_extensions) {
      tabs_refuse(
        code = "IO_INVALID_FILE_TYPE",
        title = "Invalid File Type",
        problem = sprintf("%s: Expected %s, got .%s", param_name, paste0(".", required_extensions, collapse = " or "), if (nzchar(file_ext)) file_ext else "(no extension)"),
        why_it_matters = "File type validation prevents typos (like 'output.csvx') from causing errors later in processing.",
        how_to_fix = sprintf("Use a file with one of these extensions: %s", paste0(".", required_extensions, collapse = " or "))
      )
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
    tabs_refuse(
      code = "DATA_COLUMN_NOT_FOUND",
      title = "Required Column Not Found",
      problem = sprintf("Required column '%s' (%s) not found in data", friendly_name, column_name),
      why_it_matters = "This column is required for the analysis to proceed.",
      how_to_fix = sprintf("Available columns: %s%s. Ensure your data includes the '%s' column.",
        paste(available_preview, collapse = ", "),
        if (ncol(data) > 10) sprintf(" ... (%d more)", ncol(data) - 10) else "",
        column_name)
    )
  }

  invisible(TRUE)
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
    tabs_refuse(
      code = "ARG_INVALID_WEIGHTS_TYPE",
      title = "Invalid Weights Type",
      problem = sprintf("Weights must be numeric, got: %s", class(weights)[1]),
      why_it_matters = "Weights must be numeric values to properly weight survey responses.",
      how_to_fix = "Ensure weights are a numeric vector (use as.numeric() if needed)."
    )
  }

  if (length(weights) != data_rows) {
    tabs_refuse(
      code = "DATA_WEIGHTS_LENGTH_MISMATCH",
      title = "Weights Length Mismatch",
      problem = sprintf("Weight vector length (%d) must match data rows (%d)", length(weights), data_rows),
      why_it_matters = "Each data row must have exactly one corresponding weight value.",
      how_to_fix = sprintf("Ensure your weight vector has exactly %d values, one per data row.", data_rows)
    )
  }

  if (any(weights < 0, na.rm = TRUE)) {
    tabs_refuse(
      code = "DATA_NEGATIVE_WEIGHTS",
      title = "Negative Weights Not Allowed",
      problem = "Weights cannot be negative",
      why_it_matters = "Negative weights would produce meaningless statistical results.",
      how_to_fix = "Check your weighting data - all weight values must be >= 0."
    )
  }

  if (!allow_zero && all(weights == 0)) {
    tabs_refuse(
      code = "DATA_ALL_ZERO_WEIGHTS",
      title = "All Weights Are Zero",
      problem = "All weights are zero",
      why_it_matters = "Zero weights mean no data will be counted in the analysis.",
      how_to_fix = "Check your weighting data - at least some weights must be non-zero."
    )
  }

  n_na <- sum(is.na(weights))
  if (n_na > 0) {
    warning(sprintf("Weight vector contains %d NA values (%.1f%%)",
                   n_na, 100 * n_na / length(weights)))
  }

  invisible(TRUE)
}


# ==============================================================================
# END OF VALIDATION_UTILS.R
# ==============================================================================
