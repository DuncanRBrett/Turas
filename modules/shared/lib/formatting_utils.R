# ==============================================================================
# FORMATTING UTILITIES
# ==============================================================================
# Number and text formatting for consistent output across modules
# Consolidated from /shared/formatting.R - Turas v10.0
# Part of Turas shared module infrastructure
# ==============================================================================

#' Create Number Format Code for Excel
#'
#' Creates Excel numFmt code for number formatting.
#' Excel format codes always use . for decimal (comma means divide by 1000).
#'
#' @param decimal_places Integer, decimal places (0-6)
#' @param decimal_separator Character, user preference (used for reference only)
#' @return Character, Excel format code
#' @export
create_excel_number_format <- function(decimal_places = 1, decimal_separator = ".") {
  if (!is.numeric(decimal_places) || decimal_places < 0 || decimal_places > 6) {
    stop("decimal_places must be an integer between 0 and 6", call. = FALSE)
  }

  decimal_places <- as.integer(decimal_places)

  if (decimal_places == 0) {
    return("0")
  }

  # Excel format codes ALWAYS use . for decimal
  zeros <- paste(rep("0", decimal_places), collapse = "")
  return(paste0("0.", zeros))
}

#' Create Excel Styles for Number Formatting
#'
#' Creates openxlsx style objects for different number types.
#'
#' @param decimal_separator Character, "." or "," (default: ".")
#' @param decimal_places_percent Integer, decimals for percentages (default: 0)
#' @param decimal_places_ratings Integer, decimals for ratings (default: 1)
#' @param decimal_places_index Integer, decimals for indices (default: 1)
#' @param decimal_places_numeric Integer, decimals for numeric (default: 1)
#' @param font_name Character, font name (default: "Aptos")
#' @param font_size Integer, font size (default: 12)
#' @return List of openxlsx Style objects
#' @export
create_excel_number_styles <- function(decimal_separator = ".",
                                       decimal_places_percent = 0,
                                       decimal_places_ratings = 1,
                                       decimal_places_index = 1,
                                       decimal_places_numeric = 1,
                                       font_name = "Aptos",
                                       font_size = 12) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required for Excel style creation", call. = FALSE)
  }

  fmt_pct <- create_excel_number_format(decimal_places_percent)
  fmt_rating <- create_excel_number_format(decimal_places_ratings)
  fmt_index <- create_excel_number_format(decimal_places_index)
  fmt_numeric <- create_excel_number_format(decimal_places_numeric)

  list(
    percentage = openxlsx::createStyle(
      fontSize = font_size, fontName = font_name, fontColour = "black",
      halign = "center", valign = "center", numFmt = fmt_pct
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
}

#' Format Number with Decimal Separator
#'
#' Formats numeric values as strings with specified separator.
#'
#' @param x Numeric value or vector
#' @param decimal_places Integer, decimal places (0-6, default: 1)
#' @param decimal_separator Character, "." or "," (default: ".")
#' @return Character vector
#' @export
format_number <- function(x, decimal_places = 1, decimal_separator = ".") {
  if (is.null(x)) return(NULL)
  if (all(is.na(x))) return(as.character(x))

  if (!decimal_separator %in% c(".", ",")) {
    stop("decimal_separator must be '.' or ','", call. = FALSE)
  }

  if (!is.numeric(decimal_places) || decimal_places < 0 || decimal_places > 6) {
    stop("decimal_places must be an integer between 0 and 6", call. = FALSE)
  }

  decimal_places <- as.integer(decimal_places)
  x_rounded <- round(x, decimal_places)
  x_formatted <- format(x_rounded, nsmall = decimal_places, trim = TRUE)

  if (decimal_separator == ",") {
    x_formatted <- gsub("\\.", ",", x_formatted)
  }

  return(x_formatted)
}

#' Format Percentage
#'
#' @param x Numeric, percentage value (e.g., 95.5 for 95.5%)
#' @param decimal_places Integer (default: 0)
#' @param decimal_separator Character (default: ".")
#' @param include_percent_sign Logical (default: FALSE)
#' @return Character
#' @export
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
#' @param x Numeric value
#' @param decimal_places Integer (default: 1)
#' @param decimal_separator Character (default: ".")
#' @return Character
#' @export
format_index <- function(x, decimal_places = 1, decimal_separator = ".") {
  format_number(x, decimal_places, decimal_separator)
}

#' Validate Decimal Separator Setting
#'
#' @param decimal_separator Character
#' @param default Character (default: ".")
#' @param param_name Character for error messages
#' @return Character, valid separator
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
#' @param decimal_places Numeric or character
#' @param default Integer (default: 1)
#' @param param_name Character for error messages
#' @return Integer
#' @export
validate_decimal_places <- function(decimal_places, default = 1,
                                    param_name = "decimal_places") {
  if (is.null(decimal_places) || length(decimal_places) == 0) {
    return(as.integer(default))
  }

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
