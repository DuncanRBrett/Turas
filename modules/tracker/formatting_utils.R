# ==============================================================================
# TurasTracker - Formatting Utilities
# ==============================================================================
#
# Number and text formatting utilities for output.
#
# ==============================================================================

#' Format Number with Decimal Separator
#'
#' Formats a number using the configured decimal separator (comma or period).
#'
#' @param x Numeric value or vector
#' @param decimal_places Integer. Number of decimal places
#' @param decimal_sep Character. Decimal separator ("." or ",")
#' @return Character. Formatted number(s)
#'
#' @export
format_number_with_separator <- function(x, decimal_places = 1, decimal_sep = ".") {

  if (is.null(x) || all(is.na(x))) {
    return(as.character(x))
  }

  # Round to decimal places
  x_rounded <- round(x, decimal_places)

  # Format with period first
  x_formatted <- format(x_rounded, nsmall = decimal_places, trim = TRUE)

  # Replace period with comma if needed
  if (decimal_sep == ",") {
    x_formatted <- gsub("\\.", ",", x_formatted)
  }

  return(x_formatted)
}


#' Apply Number Format to Excel Range
#'
#' Applies number formatting to cells with custom decimal separator.
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param rows Row indices
#' @param cols Column indices
#' @param decimal_places Integer
#' @param decimal_sep Character. "." or ","
#'
#' @export
apply_number_format_excel <- function(wb, sheet, rows, cols, decimal_places = 1, decimal_sep = ".") {

  # Create Excel number format string
  if (decimal_sep == ",") {
    # Use European format with comma decimal separator
    format_str <- paste0("#", decimal_sep, paste(rep("0", decimal_places), collapse = ""))
  } else {
    # Use standard format with period
    format_str <- paste0("#", decimal_sep, paste(rep("0", decimal_places), collapse = ""))
  }

  # Create style with this format
  number_style <- openxlsx::createStyle(numFmt = format_str)

  # Apply to range
  openxlsx::addStyle(wb, sheet, number_style, rows = rows, cols = cols, gridExpand = TRUE, stack = TRUE)
}


message("Turas>Tracker formatting_utils module loaded")
