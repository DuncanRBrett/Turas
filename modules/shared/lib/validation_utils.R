# ==============================================================================
# VALIDATION UTILITIES
# ==============================================================================
# Input validation functions for robust error handling
# Extracted from shared_functions.R Turas v10.0
# Part of Turas shared module infrastructure
# ==============================================================================

# Constants
MAX_FILE_SIZE_MB <- 500
MAX_FILE_SIZE_BYTES <- MAX_FILE_SIZE_MB * 1024 * 1024
SUPPORTED_DATA_FORMATS <- c("xlsx", "xls", "csv", "sav")
SUPPORTED_CONFIG_FORMATS <- c("xlsx", "xls")

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
validate_data_frame <- function(data, required_cols = NULL, min_rows = 1,
                               max_rows = Inf, param_name = "data") {
  # Type check
  if (!is.data.frame(data)) {
    turas_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Data Type",
      problem = sprintf("%s must be a data frame.", param_name),
      why_it_matters = "Data processing functions require data in data frame format.",
      how_to_fix = c(
        "Ensure the data is loaded as a data frame",
        "If using a matrix or list, convert to data frame using as.data.frame()",
        sprintf("Current type: %s", paste(class(data), collapse = ", "))
      ),
      expected = "data.frame",
      observed = paste(class(data), collapse = ", ")
    )
  }

  # Row count check
  n_rows <- nrow(data)
  if (n_rows < min_rows) {
    turas_refuse(
      code = "DATA_INSUFFICIENT_ROWS",
      title = "Insufficient Data Rows",
      problem = sprintf("%s must have at least %d rows.", param_name, min_rows),
      why_it_matters = "Analysis requires a minimum number of observations to produce valid results.",
      how_to_fix = c(
        sprintf("Current row count: %d", n_rows),
        sprintf("Required minimum: %d", min_rows),
        "Check that data loaded correctly",
        "Ensure data filters are not too restrictive"
      ),
      expected = sprintf(">= %d rows", min_rows),
      observed = sprintf("%d rows", n_rows)
    )
  }

  if (n_rows > max_rows) {
    turas_refuse(
      code = "DATA_TOO_MANY_ROWS",
      title = "Data Exceeds Maximum Row Count",
      problem = sprintf("%s exceeds maximum allowed rows.", param_name),
      why_it_matters = "Dataset is too large for the current function's constraints.",
      how_to_fix = c(
        sprintf("Current row count: %d", n_rows),
        sprintf("Maximum allowed: %d", max_rows),
        "Consider filtering or sampling the data",
        "Contact support if you need to process larger datasets"
      ),
      expected = sprintf("<= %d rows", max_rows),
      observed = sprintf("%d rows", n_rows)
    )
  }

  # Column check
  if (!is.null(required_cols) && length(required_cols) > 0) {
    missing <- setdiff(required_cols, names(data))
    if (length(missing) > 0) {
      available_preview <- head(names(data), 10)
      turas_refuse(
        code = "DATA_MISSING_COLUMNS",
        title = "Required Columns Missing",
        problem = sprintf("%s is missing required columns.", param_name),
        why_it_matters = "These columns are needed for the analysis to proceed.",
        how_to_fix = c(
          "Verify column names in your data file match exactly (case-sensitive)",
          "Check for typos or extra spaces in column names",
          "Ensure data export included all necessary columns"
        ),
        expected = required_cols,
        observed = names(data),
        missing = missing
      )
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
validate_numeric_param <- function(value, param_name, min = -Inf, max = Inf,
                                  allow_na = FALSE) {
  # Length check first (safe for any type)
  if (length(value) != 1) {
    turas_refuse(
      code = "DATA_INVALID_PARAM_LENGTH",
      title = "Invalid Parameter Length",
      problem = sprintf("%s must be a single value, not a vector.", param_name),
      why_it_matters = "This parameter expects exactly one value.",
      how_to_fix = c(
        sprintf("Current length: %d", length(value)),
        "Provide a single numeric value instead of a vector",
        "If you need to pass multiple values, check the function documentation"
      ),
      expected = "length 1",
      observed = sprintf("length %d", length(value))
    )
  }

  # NA check (safe now since we know length is 1)
  if (is.na(value)) {
    if (!allow_na) {
      turas_refuse(
        code = "DATA_INVALID_NA_VALUE",
        title = "NA Value Not Allowed",
        problem = sprintf("%s cannot be NA.", param_name),
        why_it_matters = "This parameter requires a valid value to proceed.",
        how_to_fix = c(
          sprintf("Parameter '%s' is currently NA", param_name),
          "Provide a valid numeric value",
          "Check that the value is being set correctly in your configuration or code"
        )
      )
    }
    return(invisible(TRUE))
  }

  # Type check (after NA check, since NA can be logical)
  if (!is.numeric(value)) {
    turas_refuse(
      code = "DATA_INVALID_PARAM_TYPE",
      title = "Invalid Parameter Type",
      problem = sprintf("%s must be numeric.", param_name),
      why_it_matters = "This parameter requires a numeric value for calculations.",
      how_to_fix = c(
        sprintf("Current type: %s", class(value)[1]),
        "Provide a numeric value (e.g., 5, 3.14, -2.5)",
        "If the value is stored as text, convert it to numeric"
      ),
      expected = "numeric",
      observed = class(value)[1]
    )
  }

  # Range check
  if (value < min || value > max) {
    turas_refuse(
      code = "DATA_VALUE_OUT_OF_RANGE",
      title = "Parameter Value Out of Range",
      problem = sprintf("%s is outside the allowed range.", param_name),
      why_it_matters = "This parameter must fall within specified bounds for valid results.",
      how_to_fix = c(
        sprintf("Current value: %g", value),
        sprintf("Allowed range: %g to %g", min, max),
        "Adjust the value to fall within the allowed range"
      ),
      expected = sprintf("%g to %g", min, max),
      observed = sprintf("%g", value)
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
    turas_refuse(
      code = "DATA_INVALID_LOGICAL_VALUE",
      title = "Invalid Logical Value",
      problem = sprintf("%s must be TRUE or FALSE.", param_name),
      why_it_matters = "This parameter requires a boolean (true/false) value.",
      how_to_fix = c(
        "Set the value to either TRUE or FALSE",
        sprintf("Current value: %s", if (is.null(value)) "NULL" else as.character(value)),
        "Do not use quoted strings like 'TRUE' - use the bare keyword TRUE"
      ),
      expected = "TRUE or FALSE",
      observed = if (is.null(value)) "NULL" else as.character(value)
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
    turas_refuse(
      code = "DATA_INVALID_CHAR_VALUE",
      title = "Invalid Character Value",
      problem = sprintf("%s must be a single character string.", param_name),
      why_it_matters = "This parameter requires a text value.",
      how_to_fix = c(
        "Provide a character string value",
        sprintf("Current type: %s", if (is.null(value)) "NULL" else class(value)[1]),
        "Ensure the value is quoted (e.g., 'text' or \"text\")"
      ),
      expected = "character",
      observed = if (is.null(value)) "NULL" else class(value)[1]
    )
  }

  # Empty check
  if (!allow_empty && nchar(trimws(value)) == 0) {
    turas_refuse(
      code = "DATA_EMPTY_STRING_VALUE",
      title = "Empty String Not Allowed",
      problem = sprintf("%s cannot be an empty string.", param_name),
      why_it_matters = "This parameter requires a non-empty value.",
      how_to_fix = c(
        sprintf("Parameter '%s' is currently empty or contains only whitespace", param_name),
        "Provide a non-empty text value",
        "Check your configuration or data source"
      )
    )
  }

  # Allowed values check
  if (!is.null(allowed_values) && !value %in% allowed_values) {
    turas_refuse(
      code = "DATA_INVALID_CHOICE",
      title = "Invalid Choice",
      problem = sprintf("%s must be one of the allowed values.", param_name),
      why_it_matters = "Only specific predefined values are supported for this parameter.",
      how_to_fix = c(
        sprintf("Current value: '%s'", value),
        "Choose one of the allowed values listed below",
        "Check for typos and ensure exact match (case-sensitive)"
      ),
      expected = allowed_values,
      observed = value
    )
  }

  invisible(TRUE)
}

#' Validate file path exists and is accessible
#'
#' USAGE: Validate file paths before attempting to read OR write
#' DESIGN: Checks existence, readability, optionally file type
#'
#' @param file_path Character, path to file
#' @param param_name Character, parameter name for errors
#' @param must_exist Logical, must file exist (default: TRUE)
#' @param required_extensions Character vector, allowed extensions (NULL = any)
#' @param validate_extension_even_if_missing Logical, validate extension even if file doesn't exist yet (default: FALSE)
#' @return Invisible TRUE if valid, stops with detailed error if invalid
#' @export
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

    turas_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "File Not Found",
      problem = sprintf("The file specified in %s does not exist.", param_name),
      why_it_matters = "The file must exist to be loaded or processed.",
      how_to_fix = c(
        "Check spelling and case sensitivity of the filename",
        "Verify the file is in the correct location",
        "Check file permissions",
        sprintf("Looking for: %s", file_part),
        sprintf("Full path: %s", file_path),
        sprintf("Directory exists: %s", if (dir.exists(dir_part)) "YES" else "NO")
      ),
      missing = file_path
    )
  }

  # Extension check
  if (!is.null(required_extensions) &&
      (must_exist || validate_extension_even_if_missing)) {
    file_ext <- tolower(tools::file_ext(file_path))

    # Check extension is present and valid
    if (!nzchar(file_ext) || !file_ext %in% required_extensions) {
      turas_refuse(
        code = "IO_INVALID_FILE_EXTENSION",
        title = "Invalid File Extension",
        problem = sprintf("File specified in %s has an invalid extension.", param_name),
        why_it_matters = "Only specific file types are supported. This check prevents typos like 'output.csvx' from causing errors later.",
        how_to_fix = c(
          sprintf("Expected file type: %s", paste0(".", required_extensions, collapse = " or ")),
          sprintf("Current extension: .%s", if (nzchar(file_ext)) file_ext else "(no extension)"),
          "Rename the file with the correct extension",
          "Ensure you're using a supported file format"
        ),
        expected = required_extensions,
        observed = if (nzchar(file_ext)) file_ext else "(no extension)"
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

#' Check if data frame has data
#'
#' USAGE: Guard clause at start of functions expecting data
#' DESIGN: Simple null/empty check
#'
#' @param df Data frame to check
#' @return Logical, TRUE if data frame has at least 1 row
#' @export
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
    turas_refuse(
      code = "DATA_COLUMN_NOT_FOUND",
      title = "Required Column Not Found",
      problem = sprintf("Column '%s' is not present in the data.", friendly_name),
      why_it_matters = "This column is required for the analysis to proceed.",
      how_to_fix = c(
        "Verify the column name matches exactly (case-sensitive)",
        "Check for typos or extra spaces",
        sprintf("Looking for: '%s'", column_name),
        "See available columns listed below"
      ),
      missing = column_name,
      observed = names(data)
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
    turas_refuse(
      code = "DATA_WEIGHTS_INVALID_TYPE",
      title = "Invalid Weight Variable Type",
      problem = "Weight variable must be numeric.",
      why_it_matters = "Weights must be numeric values for proper weighting calculations.",
      how_to_fix = c(
        sprintf("Current type: %s", class(weights)[1]),
        "Ensure the weight column contains numeric values only",
        "Check for non-numeric characters in the weight column"
      ),
      expected = "numeric",
      observed = class(weights)[1]
    )
  }

  if (length(weights) != data_rows) {
    turas_refuse(
      code = "DATA_WEIGHTS_LENGTH_MISMATCH",
      title = "Weight Vector Length Mismatch",
      problem = "Weight vector length does not match the number of data rows.",
      why_it_matters = "Each data row must have exactly one corresponding weight value.",
      how_to_fix = c(
        sprintf("Weight vector length: %d", length(weights)),
        sprintf("Data rows: %d", data_rows),
        "Ensure weights are calculated for all rows",
        "Check that no rows were inadvertently added or removed"
      ),
      expected = sprintf("%d weights", data_rows),
      observed = sprintf("%d weights", length(weights))
    )
  }

  if (any(weights < 0, na.rm = TRUE)) {
    turas_refuse(
      code = "DATA_WEIGHTS_NEGATIVE",
      title = "Negative Weights Detected",
      problem = "Weight vector contains negative values.",
      why_it_matters = "Weights must be non-negative for valid statistical calculations.",
      how_to_fix = c(
        sprintf("Number of negative weights: %d", sum(weights < 0, na.rm = TRUE)),
        "Check your weighting calculation",
        "Ensure all weight values are >= 0"
      )
    )
  }

  if (!allow_zero && all(weights == 0)) {
    turas_refuse(
      code = "DATA_WEIGHTS_ALL_ZERO",
      title = "All Weights Are Zero",
      problem = "All weights in the weight vector are zero.",
      why_it_matters = "At least some non-zero weights are required for meaningful analysis.",
      how_to_fix = c(
        "Check your weighting calculation",
        "Ensure weight values are being computed correctly",
        "Verify the weight column in your data file"
      )
    )
  }

  n_na <- sum(is.na(weights))
  if (n_na > 0) {
    warning(sprintf("Weight vector contains %d NA values (%.1f%%)",
                   n_na, 100 * n_na / length(weights)))
  }

  invisible(TRUE)
}
