# ==============================================================================
# TURAS SHARED LIBRARY - FORMATTING
# ==============================================================================
# Shared between: TurasTabs, TurasTracker, and future modules
#
# PURPOSE:
#   Number and text formatting utilities for consistent output across all modules
#
# IMPORTANT: Changes to this file affect multiple modules.
#             Test thoroughly before committing.
#
# VERSION: 1.0.0
# CREATED: Phase 2 - Code Quality Improvements
# ==============================================================================

FORMATTING_VERSION <- "1.0.0"

# ==============================================================================
# EXCEL NUMBER FORMAT GENERATION
# ==============================================================================

#' Create Number Format Code for Excel
#'
#' Creates Excel numFmt code with proper decimal separator handling.
#' Uses explicit separator in format code for predictable cross-platform behavior.
#'
#' DESIGN DECISION:
#' We use explicit decimal separator in format code (e.g., "0,00" or "0.00")
#' rather than relying on Excel locale conversion. This ensures:
#' - Consistent output regardless of Excel installation locale
#' - User control via config file
#' - Predictable behavior for international clients
#'
#' @param decimal_places Integer. Number of decimal places (0-6)
#' @param decimal_separator Character. "." or "," (default: ".")
#' @return Character. Excel number format code
#'
#' @export
#' @examples
#' create_excel_number_format(2, ",")  # Returns "0,00"
#' create_excel_number_format(1, ".")  # Returns "0.0"
#' create_excel_number_format(0, ".")  # Returns "0"
create_excel_number_format <- function(decimal_places = 1, decimal_separator = ".") {

  # Validate inputs
  if (!decimal_separator %in% c(".", ",")) {
    stop("decimal_separator must be '.' or ','", call. = FALSE)
  }

  if (!is.numeric(decimal_places) || decimal_places < 0 || decimal_places > 6) {
    stop("decimal_places must be an integer between 0 and 6", call. = FALSE)
  }

  decimal_places <- as.integer(decimal_places)

  # No decimals case
  if (decimal_places == 0) {
    return("0")
  }

  # CRITICAL: In Excel format codes, comma is a THOUSANDS separator, not decimal!
  # We must use different format patterns depending on the decimal separator
  zeros <- paste(rep("0", decimal_places), collapse = "")

  if (decimal_separator == ",") {
    # For comma decimal separator: use space as thousands separator and comma as decimal
    # Format pattern: "# ##0,00" uses space for thousands and comma for decimals
    # The space between # symbols creates the thousands separator
    format_code <- paste0("# ##0", ",", zeros)
  } else {
    # For period decimal separator: standard format without thousands separator
    # Format pattern: "0.0" just shows the decimal part
    format_code <- paste0("0", ".", zeros)
  }

  return(format_code)
}


#' Create Excel Styles for Number Formatting
#'
#' Creates openxlsx style objects for different number types.
#' This is the canonical implementation used by all TURAS modules.
#'
#' @param decimal_separator Character. "." or "," (default: ".")
#' @param decimal_places_percent Integer. Decimals for percentages (default: 0)
#' @param decimal_places_ratings Integer. Decimals for ratings (default: 1)
#' @param decimal_places_index Integer. Decimals for indices (default: 1)
#' @param decimal_places_numeric Integer. Decimals for numeric (default: 1)
#' @param font_name Character. Font name (default: "Aptos")
#' @param font_size Integer. Font size (default: 12)
#' @return List of openxlsx Style objects
#'
#' @export
create_excel_number_styles <- function(decimal_separator = ".",
                                       decimal_places_percent = 0,
                                       decimal_places_ratings = 1,
                                       decimal_places_index = 1,
                                       decimal_places_numeric = 1,
                                       font_name = "Aptos",
                                       font_size = 12) {

  # Require openxlsx
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required for Excel style creation", call. = FALSE)
  }

  # Generate format codes
  fmt_pct <- create_excel_number_format(decimal_places_percent, decimal_separator)
  fmt_rating <- create_excel_number_format(decimal_places_ratings, decimal_separator)
  fmt_index <- create_excel_number_format(decimal_places_index, decimal_separator)
  fmt_numeric <- create_excel_number_format(decimal_places_numeric, decimal_separator)

  # Create style objects
  styles <- list(
    percentage = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name, fontColour = "black",
      halign = "center", valign = "center",
      numFmt = fmt_pct
    ),

    rating = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name, fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_rating
    ),

    index = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name, fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_index
    ),

    numeric = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name, fontColour = "black",
      halign = "center", valign = "center", textDecoration = "bold",
      numFmt = fmt_numeric
    )
  )

  return(styles)
}

# ==============================================================================
# STRING NUMBER FORMATTING
# ==============================================================================

#' Format Number with Decimal Separator
#'
#' Formats numeric values as strings with specified separator.
#' For use in text outputs, labels, or when writing pre-formatted strings to Excel.
#'
#' USAGE:
#' - Excel cells with numeric values: Use create_excel_number_format() + style
#' - Text labels or pre-formatted strings: Use this function
#'
#' @param x Numeric value or vector
#' @param decimal_places Integer. Number of decimal places (0-6, default: 1)
#' @param decimal_separator Character. "." or "," (default: ".")
#' @return Character vector. Formatted numbers
#'
#' @export
#' @examples
#' format_number(95.5, 1, ".")  # Returns "95.5"
#' format_number(95.5, 1, ",")  # Returns "95,5"
#' format_number(c(10.1, 20.2), 1, ",")  # Returns c("10,1", "20,2")
format_number <- function(x, decimal_places = 1, decimal_separator = ".") {

  # Handle NULL
  if (is.null(x)) {
    return(NULL)
  }

  # Handle all NA
  if (all(is.na(x))) {
    return(as.character(x))
  }

  # Validate inputs
  if (!decimal_separator %in% c(".", ",")) {
    stop("decimal_separator must be '.' or ','", call. = FALSE)
  }

  if (!is.numeric(decimal_places) || decimal_places < 0 || decimal_places > 6) {
    stop("decimal_places must be an integer between 0 and 6", call. = FALSE)
  }

  decimal_places <- as.integer(decimal_places)

  # Round to decimal places
  x_rounded <- round(x, decimal_places)

  # Format with specified decimals
  x_formatted <- format(x_rounded, nsmall = decimal_places, trim = TRUE)

  # Replace period with comma if needed
  if (decimal_separator == ",") {
    x_formatted <- gsub("\\.", ",", x_formatted)
  }

  return(x_formatted)
}


#' Format Percentage
#'
#' Formats percentage value with optional percent sign.
#'
#' @param x Numeric value or vector (as percentage, e.g., 95.5 for 95.5%)
#' @param decimal_places Integer. Number of decimal places (default: 0)
#' @param decimal_separator Character. "." or "," (default: ".")
#' @param include_percent_sign Logical. Add "%" suffix (default: FALSE)
#' @return Character vector. Formatted percentages
#'
#' @export
#' @examples
#' format_percentage(95.5, 1, ".", FALSE)  # Returns "95.5"
#' format_percentage(95.5, 1, ".", TRUE)   # Returns "95.5%"
#' format_percentage(95.5, 0, ",", TRUE)   # Returns "96%"
format_percentage <- function(x, decimal_places = 0, decimal_separator = ".",
                              include_percent_sign = FALSE) {

  formatted <- format_number(x, decimal_places, decimal_separator)

  if (include_percent_sign && !is.null(formatted)) {
    formatted <- paste0(formatted, "%")
  }

  return(formatted)
}


#' Format Index/Rating Value
#'
#' Formats index or rating score.
#' Alias for format_number() with default 1 decimal place.
#'
#' @param x Numeric value or vector
#' @param decimal_places Integer. Number of decimal places (default: 1)
#' @param decimal_separator Character. "." or "," (default: ".")
#' @return Character vector. Formatted values
#'
#' @export
#' @examples
#' format_index(7.5, 1, ".")  # Returns "7.5"
#' format_index(7.5, 1, ",")  # Returns "7,5"
format_index <- function(x, decimal_places = 1, decimal_separator = ".") {
  format_number(x, decimal_places, decimal_separator)
}

# ==============================================================================
# VALIDATION HELPERS
# ==============================================================================

#' Validate Decimal Separator Setting
#'
#' Validates and normalizes decimal separator from config.
#'
#' @param decimal_separator Character. Should be "." or ","
#' @param default Character. Default if invalid (default: ".")
#' @param param_name Character. Parameter name for error messages
#' @return Character. Valid decimal separator
#'
#' @export
validate_decimal_separator <- function(decimal_separator, default = ".",
                                       param_name = "decimal_separator") {

  if (is.null(decimal_separator) || length(decimal_separator) == 0) {
    return(default)
  }

  decimal_separator <- as.character(decimal_separator)

  if (!decimal_separator %in% c(".", ",")) {
    warning(sprintf(
      "%s must be '.' or ',' (got: '%s'). Using default: '%s'",
      param_name, decimal_separator, default
    ), call. = FALSE)
    return(default)
  }

  return(decimal_separator)
}


#' Validate Decimal Places Setting
#'
#' Validates and normalizes decimal places from config.
#'
#' @param decimal_places Numeric or character. Should be 0-6
#' @param default Integer. Default if invalid (default: 1)
#' @param param_name Character. Parameter name for error messages
#' @return Integer. Valid decimal places
#'
#' @export
validate_decimal_places <- function(decimal_places, default = 1,
                                    param_name = "decimal_places") {

  if (is.null(decimal_places) || length(decimal_places) == 0) {
    return(as.integer(default))
  }

  # Try to convert to numeric
  dp_numeric <- suppressWarnings(as.numeric(decimal_places))

  if (is.na(dp_numeric) || dp_numeric < 0 || dp_numeric > 6) {
    warning(sprintf(
      "%s must be an integer 0-6 (got: '%s'). Using default: %d",
      param_name, decimal_places, default
    ), call. = FALSE)
    return(as.integer(default))
  }

  return(as.integer(dp_numeric))
}

# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>Shared formatting module loaded (v%s)", FORMATTING_VERSION))
