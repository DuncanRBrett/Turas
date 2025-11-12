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
# Robust path resolution - searches up directory tree to find Turas root
find_turas_root <- function() {
  # Method 1: Check if TURAS_ROOT is already set
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    return(get("TURAS_ROOT", envir = .GlobalEnv))
  }
  
  # Method 2: Start from current working directory
  current_dir <- getwd()
  
  # Search up directory tree for Turas root markers
  while (current_dir != dirname(current_dir)) {  # Stop at filesystem root
    # Check for Turas root markers
    if (file.exists(file.path(current_dir, "launch_turas.R")) ||
        (dir.exists(file.path(current_dir, "shared")) && 
         dir.exists(file.path(current_dir, "modules")))) {
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }
  
  # Method 3: Try relative paths from module location
  for (rel_path in c("../..", "../../..", "../../../..")) {
    test_path <- normalizePath(file.path(rel_path, "shared", "formatting.R"), mustWork = FALSE)
    if (file.exists(test_path)) {
      return(normalizePath(dirname(dirname(test_path)), mustWork = TRUE))
    }
  }
  
  stop(paste0(
    "Cannot locate Turas root directory.\n",
    "Please ensure you're running from the Turas directory.\n",
    "Current working directory: ", getwd()
  ))
}

turas_root <- find_turas_root()
source(file.path(turas_root, "shared", "formatting.R"), local = FALSE)


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
