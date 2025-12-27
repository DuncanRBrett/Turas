# ==============================================================================
# OUTPUT FORMATTING UTILITIES - TURAS V10.1
# ==============================================================================
# Excel formatting and numeric conversion utilities for confidence output
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Extracted from 07_output.R (2025-12-27)
#          - Excel number formatting
#          - Numeric column formatting
#          - Default configuration
#
# DEPENDENCIES:
# - openxlsx (for Excel styling)
#
# FUNCTIONS:
# - create_excel_number_format(): Create Excel format strings
# - apply_numeric_formatting(): Apply Excel number formatting to dataframe regions
# - create_default_config(): Create default configuration for output
# ==============================================================================

OUTPUT_FORMATTING_VERSION <- "10.1"


# ==============================================================================
# EXCEL NUMBER FORMATTING
# ==============================================================================

#' Create Excel number format string with decimal separator (internal)
#'
#' Creates an Excel number format code. Note that the actual decimal separator
#' displayed depends on Excel's regional settings, not the format code itself.
#'
#' @param decimal_places Integer. Number of decimal places
#' @param decimal_sep Character. Ignored - kept for API compatibility
#' @return Character. Excel number format code
#' @keywords internal
create_excel_number_format <- function(decimal_places = 2, decimal_sep = ".") {

  if (decimal_places == 0) {
    return("0")
  }

  # IMPORTANT: Excel format codes always use period for decimal position
  # The actual separator displayed (period or comma) depends on Excel's locale
  # We cannot control this through the format code alone
  zeros <- paste(rep("0", decimal_places), collapse = "")
  format_str <- paste0("0.", zeros)  # Always use period in format code

  return(format_str)
}


#' Apply Excel number formatting to numeric columns in dataframe region (internal)
#'
#' Applies Excel cell styles with number formatting to preserve numeric values.
#' Does NOT convert to character strings - keeps values numeric.
#'
#' @param wb Workbook object
#' @param sheet Sheet name
#' @param start_row Starting row
#' @param start_col Starting column
#' @param df Data frame to format
#' @param decimal_sep Character. "." or ","
#' @keywords internal
apply_numeric_formatting <- function(wb, sheet, start_row, start_col, df, decimal_sep) {

  if (!is.data.frame(df) || nrow(df) == 0) {
    return(invisible(NULL))
  }

  # Apply formatting to each numeric column
  for (col_idx in seq_along(df)) {
    col_data <- df[[col_idx]]
    col_name <- names(df)[col_idx]

    if (is.numeric(col_data)) {
      # Determine appropriate decimal places
      digits <- 2

      # Use more precision for small values (SE, MOE, CV, DEFF, etc.)
      if (any(grepl("SE|MOE|CV|DEFF", col_name, ignore.case = TRUE))) {
        digits <- 3
      }

      # Create Excel number format
      num_format <- create_excel_number_format(digits, decimal_sep)
      num_style <- openxlsx::createStyle(numFmt = num_format)

      # Apply to all data rows in this column
      excel_col <- start_col + col_idx - 1
      data_rows <- start_row:(start_row + nrow(df) - 1)

      openxlsx::addStyle(wb, sheet, num_style,
                        rows = data_rows,
                        cols = excel_col,
                        gridExpand = TRUE,
                        stack = TRUE)
    }
  }

  invisible(NULL)
}


# ==============================================================================
# CONFIGURATION
# ==============================================================================

#' Create default configuration for output (internal)
#' @keywords internal
create_default_config <- function() {
  list(
    confidence_level = 0.95,
    bootstrap_iterations = 5000,
    multiple_comparison_method = "None",
    calculate_effective_n = TRUE
  )
}
