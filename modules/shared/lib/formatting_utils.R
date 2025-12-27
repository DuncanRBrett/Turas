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
    turas_refuse(
      code = "CFG_INVALID_DECIMAL_PLACES",
      title = "Invalid Decimal Places Setting",
      problem = "decimal_places parameter must be an integer between 0 and 6.",
      why_it_matters = "Excel number formatting requires valid decimal place specifications.",
      how_to_fix = c(
        sprintf("Current value: %s", as.character(decimal_places)),
        "Change decimal_places to a whole number between 0 and 6",
        "Example: 0 for whole numbers, 1 for one decimal place, 2 for two decimal places"
      ),
      expected = "integer 0-6",
      observed = as.character(decimal_places)
    )
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
    turas_refuse(
      code = "PKG_OPENXLSX_MISSING",
      title = "Missing Required Package: openxlsx",
      problem = "Excel style creation requires the 'openxlsx' package, which is not installed.",
      why_it_matters = "The openxlsx package is needed to format Excel output.",
      how_to_fix = c(
        "Install the openxlsx package by running:",
        "  install.packages('openxlsx')",
        "Then retry your analysis"
      )
    )
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
    turas_refuse(
      code = "CFG_INVALID_DECIMAL_SEPARATOR",
      title = "Invalid Decimal Separator",
      problem = "decimal_separator must be either '.' or ','",
      why_it_matters = "Only period and comma are supported as decimal separators for number formatting.",
      how_to_fix = c(
        sprintf("Current value: '%s'", decimal_separator),
        "Change decimal_separator to either '.' (period) or ',' (comma)",
        "Period is standard in English locales, comma in many European locales"
      ),
      expected = c(".", ","),
      observed = decimal_separator
    )
  }

  if (!is.numeric(decimal_places) || decimal_places < 0 || decimal_places > 6) {
    turas_refuse(
      code = "CFG_INVALID_DECIMAL_PLACES",
      title = "Invalid Decimal Places Setting",
      problem = "decimal_places parameter must be an integer between 0 and 6.",
      why_it_matters = "Number formatting requires valid decimal place specifications.",
      how_to_fix = c(
        sprintf("Current value: %s", as.character(decimal_places)),
        "Change decimal_places to a whole number between 0 and 6",
        "Example: 0 for whole numbers, 1 for one decimal place, 2 for two decimal places"
      ),
      expected = "integer 0-6",
      observed = as.character(decimal_places)
    )
  }

  decimal_places <- as.integer(decimal_places)

  # Track NA positions to preserve them
  na_positions <- is.na(x)

  x_rounded <- round(x, decimal_places)
  x_formatted <- format(x_rounded, nsmall = decimal_places, trim = TRUE)

  if (decimal_separator == ",") {
    x_formatted <- gsub("\\.", ",", x_formatted)
  }

  # Restore NA values (format() converts NA to string "NA")
  x_formatted[na_positions] <- NA_character_

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
    message(sprintf(
      "[TRS INFO] FMT_INVALID_DECIMAL_SEP: %s must be '.' or ',' (got: '%s') - using default: '%s'",
      param_name, decimal_separator, default
    ))
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
    message(sprintf(
      "[TRS INFO] FMT_INVALID_DECIMAL_PLACES: %s must be an integer 0-6 (got: '%s') - using default: %d",
      param_name, decimal_places, default
    ))
    return(as.integer(default))
  }

  return(as.integer(dp_numeric))
}
