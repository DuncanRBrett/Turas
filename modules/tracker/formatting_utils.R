# ==============================================================================
# TurasTracker - Formatting Utilities
# ==============================================================================
#
# Number and text formatting utilities for output.
#
# VERSION: 2.0.0 - Phase 2 Update
# CHANGES: Now uses shared/formatting.R for consistent formatting
# ==============================================================================

# Load shared formatting module (Phase 2 refactoring)
script_dir <- dirname(sys.frame(1)$ofile)
shared_dir <- file.path(script_dir, "..", "..", "shared")
source(file.path(shared_dir, "formatting.R"), local = FALSE)

#' Format Number with Decimal Separator
#'
#' Formats a number using the configured decimal separator (comma or period).
#'
#' NOTE (Phase 2 Update): This function now wraps shared/formatting.R::format_number()
#' to ensure consistent behavior across all TURAS modules.
#'
#' @param x Numeric value or vector
#' @param decimal_places Integer. Number of decimal places
#' @param decimal_sep Character. Decimal separator ("." or ",")
#' @return Character. Formatted number(s)
#'
#' @export
format_number_with_separator <- function(x, decimal_places = 1, decimal_sep = ".") {
  # Wrapper for shared format_number function
  format_number(x, decimal_places, decimal_sep)
}


#' Apply Number Format to Excel Range
#'
#' Applies number formatting to cells with custom decimal separator.
#'
#' NOTE (Phase 2 Update): Now uses create_excel_number_format() from shared module.
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

  # Phase 2 Update: Use shared formatting module
  format_str <- create_excel_number_format(decimal_places, decimal_sep)

  # Create style with this format
  number_style <- openxlsx::createStyle(numFmt = format_str)

  # Apply to range
  openxlsx::addStyle(wb, sheet, number_style, rows = rows, cols = cols, gridExpand = TRUE, stack = TRUE)
}


message("Turas>Tracker formatting_utils module loaded (v2.0 - using shared/formatting.R)")
