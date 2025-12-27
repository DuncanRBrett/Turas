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
# Find the shared/lib path - try multiple locations
.shared_lib_path <- NULL
.shared_lib_candidates <- c(
  # If script_dir is set (from parent run_tracker.R), go up to modules/shared/lib
  if (exists("script_dir") && !is.null(script_dir) && length(script_dir) > 0 && nzchar(script_dir[1])) {
    file.path(dirname(script_dir[1]), "shared", "lib")  # ../shared/lib from tracker dir
  } else NULL,
  # Try relative to current working directory
  file.path(getwd(), "..", "shared", "lib"),
  file.path(getwd(), "modules", "shared", "lib"),
  # Try TURAS_HOME if set
  file.path(Sys.getenv("TURAS_HOME", unset = ""), "modules", "shared", "lib")
)
.shared_lib_candidates <- .shared_lib_candidates[!is.null(.shared_lib_candidates) & nzchar(.shared_lib_candidates)]

for (.candidate in .shared_lib_candidates) {
  if (dir.exists(.candidate)) {
    .shared_lib_path <- .candidate
    break
  }
}

# Load dependencies in order (only if not already loaded)
if (!is.null(.shared_lib_path)) {
  if (!exists("validate_char_param", mode = "function") && file.exists(file.path(.shared_lib_path, "validation_utils.R"))) {
    source(file.path(.shared_lib_path, "validation_utils.R"), local = FALSE)
  }
  if (!exists("find_turas_root", mode = "function") && file.exists(file.path(.shared_lib_path, "config_utils.R"))) {
    source(file.path(.shared_lib_path, "config_utils.R"), local = FALSE)
  }
  if (!exists("format_number", mode = "function") && file.exists(file.path(.shared_lib_path, "formatting_utils.R"))) {
    source(file.path(.shared_lib_path, "formatting_utils.R"), local = FALSE)
  }
}

rm(list = c(".shared_lib_path", ".shared_lib_candidates", ".candidate")[
  c(".shared_lib_path", ".shared_lib_candidates", ".candidate") %in% ls(all.names = TRUE)
])


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
