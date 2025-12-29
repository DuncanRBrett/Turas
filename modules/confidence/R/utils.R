# ==============================================================================
# CONFIDENCE ANALYSIS UTILITIES - TURAS V10.0
# ==============================================================================
# Utility functions for the Confidence Analysis Module
# Part of Turas Survey Analytics Platform
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-11-12)
#          - Decimal separator formatting
#          - Input validation helpers
#          - Common utility functions
#
# DEPENDENCIES: None (base R only)
# ==============================================================================

UTILS_VERSION <- "10.0"

# ==============================================================================
# DECIMAL SEPARATOR FORMATTING
# ==============================================================================

#' Format numeric values with specified decimal separator
#'
#' Converts numeric values to character strings with user-specified
#' decimal separator for output. Internal calculations always use R standard (period).
#' Formatting is applied only at output generation stage.
#'
#' @param x Numeric vector. Values to format
#' @param decimal_sep Character. Either "." or ","
#' @param digits Integer. Number of decimal places (default 2)
#'
#' @return Character vector. Formatted numbers
#'
#' @examples
#' format_decimal(c(0.456, 1.234), decimal_sep = ",", digits = 2)
#' # Returns: c("0,46", "1,23")
#'
#' format_decimal(c(0.456, 1.234), decimal_sep = ".", digits = 3)
#' # Returns: c("0.456", "1.234")
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
format_decimal <- function(x, decimal_sep = ".", digits = 2) {
  # Input validation
  if (!is.numeric(x)) {
    confidence_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Type for Formatting",
      problem = "x must be numeric",
      why_it_matters = "Only numeric values can be formatted with decimal separators.",
      how_to_fix = "Ensure the input is numeric"
    )
  }

  if (!decimal_sep %in% c(".", ",")) {
    confidence_refuse(
      code = "CFG_INVALID_DECIMAL_SEPARATOR",
      title = "Invalid Decimal Separator",
      problem = "decimal_sep must be either '.' or ','",
      why_it_matters = "Only period or comma are valid decimal separators.",
      how_to_fix = "Use either '.' or ',' for decimal_sep"
    )
  }

  if (!is.numeric(digits) || digits < 0 || digits != as.integer(digits)) {
    confidence_refuse(
      code = "CFG_INVALID_DIGITS",
      title = "Invalid Digits Parameter",
      problem = "digits must be a non-negative integer",
      why_it_matters = "Decimal places must be specified as a whole number.",
      how_to_fix = "Specify digits as a non-negative integer (e.g., 2, 3)"
    )
  }

  # Format with period first (R standard)
  formatted <- formatC(x, format = "f", digits = digits)

  # Replace period with comma if requested
  if (decimal_sep == ",") {
    formatted <- gsub("\\.", ",", formatted)
  }

  return(formatted)
}


#' Apply decimal formatting to all numeric columns in data frame
#'
#' Formats numeric columns in a data frame with specified decimal separator.
#' Useful for preparing output tables for Excel export.
#'
#' @param df Data frame. Output data
#' @param decimal_sep Character. "." or "," (default ".")
#' @param digits Integer. Decimal places (default 2)
#' @param exclude_cols Character vector. Column names to exclude from formatting
#'   (e.g., integer counts like Base_n, Effective_n)
#'
#' @return Data frame with formatted numeric columns as character strings
#'
#' @examples
#' df <- data.frame(
#'   Question = "Q1",
#'   Base_n = 1000,
#'   Proportion = 0.456,
#'   CI_Lower = 0.423,
#'   CI_Upper = 0.489
#' )
#' format_output_df(df, decimal_sep = ",", exclude_cols = "Base_n")
#'
#' @author Confidence Module Team
#' @date 2025-11-12
#' @export
format_output_df <- function(df, decimal_sep = ".", digits = 2,
                              exclude_cols = c("Base_n", "Effective_n")) {
  # Input validation
  if (!is.data.frame(df)) {
    confidence_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Type for Output Formatting",
      problem = "df must be a data frame",
      why_it_matters = "Output formatting requires a properly structured data frame.",
      how_to_fix = "Ensure the input is a data frame"
    )
  }

  if (!decimal_sep %in% c(".", ",")) {
    confidence_refuse(
      code = "CFG_INVALID_DECIMAL_SEPARATOR",
      title = "Invalid Decimal Separator",
      problem = "decimal_sep must be either '.' or ','",
      why_it_matters = "Only period or comma are valid decimal separators.",
      how_to_fix = "Use either '.' or ',' for decimal_sep"
    )
  }

  # Make a copy to avoid modifying original
  df_formatted <- df

  # Apply formatting to numeric columns (except excluded ones)
  for (col_name in names(df_formatted)) {
    if (is.numeric(df_formatted[[col_name]]) && !col_name %in% exclude_cols) {
      df_formatted[[col_name]] <- format_decimal(
        df_formatted[[col_name]],
        decimal_sep = decimal_sep,
        digits = digits
      )
    }
  }

  return(df_formatted)
}


# ==============================================================================
# INPUT VALIDATION HELPERS
# ==============================================================================

#' Validate proportion value
#'
#' Checks if a value is a valid proportion (between 0 and 1)
#'
#' @param p Numeric. Proportion to validate
#' @param param_name Character. Name of parameter (for error messages)
#'
#' @return Logical. TRUE if valid (invisible)
#'
#' @keywords internal
validate_proportion <- function(p, param_name = "proportion") {
  if (!is.numeric(p)) {
    confidence_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Proportion Type",
      problem = sprintf("%s must be numeric", param_name),
      why_it_matters = "Proportions must be numeric values for calculations.",
      how_to_fix = sprintf("Ensure %s is numeric", param_name)
    )
  }

  if (any(is.na(p))) {
    confidence_refuse(
      code = "DATA_CONTAINS_NA",
      title = "Proportion Contains NA Values",
      problem = sprintf("%s contains NA values", param_name),
      why_it_matters = "NA values prevent proper proportion calculations.",
      how_to_fix = sprintf("Remove or handle NA values in %s", param_name)
    )
  }

  if (any(p < 0 | p > 1)) {
    confidence_refuse(
      code = "DATA_OUT_OF_RANGE",
      title = "Proportion Out of Range",
      problem = sprintf("%s must be between 0 and 1", param_name),
      why_it_matters = "Proportions are by definition between 0 and 1.",
      how_to_fix = sprintf("Ensure all values in %s are in the range [0, 1]", param_name)
    )
  }

  invisible(TRUE)
}


#' Validate sample size
#'
#' Checks if a value is a valid sample size (positive integer)
#'
#' @param n Numeric. Sample size to validate
#' @param param_name Character. Name of parameter (for error messages)
#' @param min_n Integer. Minimum acceptable sample size (default 1)
#'
#' @return Logical. TRUE if valid (invisible)
#'
#' @keywords internal
validate_sample_size <- function(n, param_name = "n", min_n = 1) {
  if (!is.numeric(n)) {
    confidence_refuse(
      code = "DATA_INVALID_TYPE",
      title = "Invalid Sample Size Type",
      problem = sprintf("%s must be numeric", param_name),
      why_it_matters = "Sample sizes must be numeric values.",
      how_to_fix = sprintf("Ensure %s is numeric", param_name)
    )
  }

  if (any(is.na(n))) {
    confidence_refuse(
      code = "DATA_CONTAINS_NA",
      title = "Sample Size Contains NA",
      problem = sprintf("%s contains NA values", param_name),
      why_it_matters = "NA values prevent proper sample size validation.",
      how_to_fix = sprintf("Remove or handle NA values in %s", param_name)
    )
  }

  if (any(n < min_n)) {
    confidence_refuse(
      code = "DATA_INSUFFICIENT_SAMPLE",
      title = "Sample Size Too Small",
      problem = sprintf("%s must be >= %d", param_name, min_n),
      why_it_matters = sprintf("Minimum sample size of %d is required for valid analysis.", min_n),
      how_to_fix = sprintf("Ensure %s is at least %d", param_name, min_n)
    )
  }

  if (any(n != as.integer(n))) {
    confidence_refuse(
      code = "DATA_NON_INTEGER",
      title = "Sample Size Must Be Integer",
      problem = sprintf("%s must be an integer", param_name),
      why_it_matters = "Sample sizes must be whole numbers.",
      how_to_fix = sprintf("Ensure %s contains only integer values", param_name)
    )
  }

  invisible(TRUE)
}


#' Validate confidence level
#'
#' Checks if a value is a valid confidence level (between 0 and 1)
#'
#' @param conf_level Numeric. Confidence level to validate
#' @param allowed_values Numeric vector. Allowed values (default c(0.90, 0.95, 0.99))
#'
#' @return Logical. TRUE if valid (invisible)
#'
#' @keywords internal
validate_conf_level <- function(conf_level, allowed_values = c(0.90, 0.95, 0.99)) {
  if (!is.numeric(conf_level)) {
    confidence_refuse(
      code = "CFG_INVALID_CONF_LEVEL_TYPE",
      title = "Invalid Confidence Level Type",
      problem = "conf_level must be numeric",
      why_it_matters = "Confidence level must be a numeric value.",
      how_to_fix = "Specify conf_level as a numeric value (e.g., 0.95)"
    )
  }

  if (is.na(conf_level)) {
    confidence_refuse(
      code = "CFG_CONF_LEVEL_NA",
      title = "Confidence Level is NA",
      problem = "conf_level cannot be NA",
      why_it_matters = "Confidence level must be specified for analysis.",
      how_to_fix = "Set Confidence_Level in config to a valid value (e.g., 0.95)"
    )
  }

  if (conf_level <= 0 || conf_level >= 1) {
    confidence_refuse(
      code = "CFG_CONF_LEVEL_OUT_OF_RANGE",
      title = "Confidence Level Out of Range",
      problem = "conf_level must be between 0 and 1",
      why_it_matters = "Confidence levels are probabilities and must be in (0, 1).",
      how_to_fix = "Set Confidence_Level to a value between 0 and 1 (e.g., 0.95)"
    )
  }

  if (!is.null(allowed_values) && !conf_level %in% allowed_values) {
    confidence_refuse(
      code = "CFG_CONF_LEVEL_NOT_ALLOWED",
      title = "Confidence Level Not in Allowed Values",
      problem = sprintf("conf_level must be one of: %s", paste(allowed_values, collapse = ", ")),
      why_it_matters = "Only specific confidence levels are supported.",
      how_to_fix = sprintf("Set Confidence_Level to one of: %s", paste(allowed_values, collapse = ", "))
    )
  }

  invisible(TRUE)
}


#' Validate decimal separator
#'
#' Checks if decimal separator is valid ("." or ",")
#'
#' @param decimal_sep Character. Decimal separator to validate
#'
#' @return Logical. TRUE if valid (invisible)
#'
#' @keywords internal
validate_decimal_separator <- function(decimal_sep) {
  if (!is.character(decimal_sep)) {
    confidence_refuse(
      code = "CFG_INVALID_DECIMAL_SEP_TYPE",
      title = "Invalid Decimal Separator Type",
      problem = "decimal_sep must be a character string",
      why_it_matters = "Decimal separator must be specified as a character.",
      how_to_fix = "Set Decimal_Separator as a character value"
    )
  }

  if (length(decimal_sep) != 1) {
    confidence_refuse(
      code = "CFG_DECIMAL_SEP_LENGTH",
      title = "Invalid Decimal Separator Length",
      problem = "decimal_sep must be a single character",
      why_it_matters = "Decimal separator must be a single character.",
      how_to_fix = "Set Decimal_Separator to either '.' or ','"
    )
  }

  if (!decimal_sep %in% c(".", ",")) {
    confidence_refuse(
      code = "CFG_INVALID_DECIMAL_SEPARATOR",
      title = "Invalid Decimal Separator Value",
      problem = "decimal_sep must be either '.' or ','",
      why_it_matters = "Only period or comma are valid decimal separators.",
      how_to_fix = "Set Decimal_Separator to either '.' or ','"
    )
  }

  invisible(TRUE)
}


#' Validate question count limit
#'
#' Checks if number of questions exceeds maximum limit (200)
#'
#' @param n_questions Integer. Number of questions
#' @param max_questions Integer. Maximum allowed (default 200)
#'
#' @return Logical. TRUE if valid (invisible)
#'
#' @keywords internal
validate_question_limit <- function(n_questions, max_questions = 200) {
  if (!is.numeric(n_questions) || n_questions != as.integer(n_questions)) {
    confidence_refuse(
      code = "CFG_INVALID_QUESTION_COUNT",
      title = "Invalid Question Count",
      problem = "n_questions must be an integer",
      why_it_matters = "Number of questions must be a whole number.",
      how_to_fix = "Ensure n_questions is an integer value"
    )
  }

  if (n_questions < 1) {
    confidence_refuse(
      code = "CFG_NO_QUESTIONS",
      title = "No Questions Specified",
      problem = "n_questions must be at least 1",
      why_it_matters = "At least one question is required for analysis.",
      how_to_fix = "Specify at least one question in the config"
    )
  }

  if (n_questions > max_questions) {
    confidence_refuse(
      code = "CFG_QUESTION_LIMIT_EXCEEDED",
      title = "Question Limit Exceeded",
      problem = sprintf("Question limit exceeded: %d questions specified (maximum %d)", n_questions, max_questions),
      why_it_matters = "The module has limits to ensure reasonable performance.",
      how_to_fix = c(
        "Reduce the number of questions in the config",
        sprintf("Or increase Max_Questions setting (current max: %d)", max_questions)
      )
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# COMMON UTILITY FUNCTIONS
# ==============================================================================

#' Check for small sample size and issue warning
#'
#' Issues appropriate warnings for small sample sizes
#'
#' @param n Integer. Sample size
#' @param threshold_critical Integer. Critical threshold (default 30)
#' @param threshold_warning Integer. Warning threshold (default 50)
#'
#' @return Character. Warning message (empty string if no warning)
#'
#' @keywords internal
check_small_sample <- function(n, threshold_critical = 30, threshold_warning = 50) {
  if (n < threshold_critical) {
    return(sprintf("Very small base (n=%d) - results may be unstable", n))
  } else if (n < threshold_warning) {
    return(sprintf("Small base (n=%d) - interpret with caution", n))
  } else {
    return("")
  }
}


#' Check for extreme proportion and issue warning
#'
#' Issues warnings for proportions near 0 or 1, where normal approximation
#' may be inadequate and Wilson score interval should be considered
#'
#' @param p Numeric. Proportion (0 to 1)
#' @param threshold Numeric. Threshold for extreme values (default 0.10)
#'
#' @return Character. Warning message (empty string if no warning)
#'
#' @keywords internal
check_extreme_proportion <- function(p, threshold = 0.10) {
  if (p < threshold || p > (1 - threshold)) {
    return(sprintf(
      "Extreme proportion (p=%.3f) - consider Wilson score interval",
      p
    ))
  } else {
    return("")
  }
}


#' Parse comma-separated codes
#'
#' Parses comma-separated string of codes into vector
#' Handles both numeric and character codes
#'
#' @param codes_string Character. Comma-separated codes (e.g., "1,2,3" or "A,B,C")
#'
#' @return Vector. Parsed codes (numeric or character)
#'
#' @examples
#' parse_codes("1,2,3")  # Returns numeric vector c(1, 2, 3)
#' parse_codes("A,B,C")  # Returns character vector c("A", "B", "C")
#' parse_codes("9,10")   # Returns numeric vector c(9, 10)
#'
#' @keywords internal
parse_codes <- function(codes_string) {
  # Handle NULL, NA, or empty string
  if (is.null(codes_string) || length(codes_string) == 0 ||
      (length(codes_string) == 1 && (is.na(codes_string) || codes_string == ""))) {
    return(NULL)
  }

  # Split by comma and trim whitespace
  codes <- trimws(strsplit(codes_string, ",")[[1]])

  # Try to convert to numeric if all codes are numeric
  codes_numeric <- suppressWarnings(as.numeric(codes))

  if (all(!is.na(codes_numeric))) {
    return(codes_numeric)
  } else {
    return(codes)
  }
}


#' Create timestamp string
#'
#' Creates formatted timestamp for output headers
#'
#' @return Character. Formatted timestamp (e.g., "2025-11-12 14:32:15")
#'
#' @keywords internal
create_timestamp <- function() {
  format(Sys.time(), "%Y-%m-%d %H:%M:%S")
}


#' Safe division with zero handling
#'
#' Performs division with proper handling of zero denominators
#'
#' @param numerator Numeric. Numerator
#' @param denominator Numeric. Denominator
#' @param na_on_zero Logical. Return NA if denominator is zero (default TRUE)
#'
#' @return Numeric. Result of division, or NA/Inf depending on na_on_zero
#'
#' @keywords internal
safe_divide <- function(numerator, denominator, na_on_zero = TRUE) {
  result <- numerator / denominator

  if (na_on_zero) {
    result[denominator == 0] <- NA
  }

  return(result)
}


# ==============================================================================
# MODULE INFORMATION
# ==============================================================================

#' Get module version information
#'
#' Returns version information for the confidence analysis module
#'
#' @return Character. Version string
#'
#' @export
get_confidence_module_version <- function() {
  return(UTILS_VERSION)
}


#' Print module information
#'
#' Prints module information to console
#'
#' @export
print_confidence_module_info <- function() {
  cat("===============================================\n")
  cat("Turas Confidence Analysis Module\n")
  cat(sprintf("Version: %s\n", UTILS_VERSION))
  cat(sprintf("Date: %s\n", create_timestamp()))
  cat("===============================================\n")
}
