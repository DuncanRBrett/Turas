# ==============================================================================
# TurasTracker - Formatting Utilities
# ==============================================================================
#
# Number and text formatting utilities for output.
#
# VERSION: 2.1.0 - Uses consolidated shared utilities
# CHANGES: Now uses /modules/shared/lib/ (consolidated location)
# ==============================================================================

# Load shared utilities from consolidated location
# Determine path to shared/lib relative to this file
.tracker_fmt_script_dir <- tryCatch({
  dirname(sys.frame(1)$ofile)
}, error = function(e) getwd())

.shared_lib_path <- file.path(dirname(.tracker_fmt_script_dir), "shared", "lib")
if (!dir.exists(.shared_lib_path)) {
  # Fallback: search from current directory
  .shared_lib_path <- file.path(getwd(), "modules", "shared", "lib")
}

# Load dependencies in order (only if not already loaded)
if (!exists("validate_char_param", mode = "function")) {
  source(file.path(.shared_lib_path, "validation_utils.R"), local = FALSE)
}
if (!exists("find_turas_root", mode = "function")) {
  source(file.path(.shared_lib_path, "config_utils.R"), local = FALSE)
}
if (!exists("format_number", mode = "function")) {
  source(file.path(.shared_lib_path, "formatting_utils.R"), local = FALSE)
}

rm(.tracker_fmt_script_dir, .shared_lib_path)


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


message("Turas>Tracker formatting_utils module loaded (v2.1 - using modules/shared/lib/)")
