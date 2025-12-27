# ==============================================================================
# SHARED FORMATTING FUNCTIONS - TURAS V10.0
# ==============================================================================
# Extracted from shared_functions.R for better maintainability
# Provides formatting utilities for output generation
#
# CONTENTS:
# - Excel column letter generation (proper base-26)
# - Value formatting for different data types
# - Percentage calculation with zero handling
#
# DESIGN PRINCIPLES:
# - Excel-compatible output formatting
# - Type-specific decimal place handling
# - Graceful handling of NA/NULL values
# ==============================================================================

#' Generate Excel column letters (proper base-26 to XFD)
#'
#' ALGORITHM: Proper base-26 conversion (not base-26 with zero)
#'   - Excel uses: A, B, ..., Z, AA, AB, ..., AZ, BA, ..., ZZ, AAA, ...
#'   - This is NOT simple base-26 because there's no "zero" digit
#'   - Correct algorithm: treat as base-26 with 1-based indexing
#'
#' RANGE: Handles columns 1 to 16,384 (Excel's maximum: A to XFD)
#' PERFORMANCE: O(n * log n) - efficient for typical banner sizes (<100 cols)
#'
#' EXAMPLES:
#'   1 → "A", 26 → "Z", 27 → "AA", 52 → "AZ", 53 → "BA"
#'   702 → "ZZ", 703 → "AAA", 16384 → "XFD"
#'
#' @param n Integer, number of letters to generate
#' @return Character vector of Excel column letters
#' @export
#' @examples
#' generate_excel_letters(3)    # "A" "B" "C"
#' generate_excel_letters(27)   # includes "AA"
#' generate_excel_letters(703)  # includes "AAA"
generate_excel_letters <- function(n) {
  # Get constants from parent environment
  MAX_EXCEL_COLUMNS <- tryCatch(
    get("MAX_EXCEL_COLUMNS", envir = .GlobalEnv),
    error = function(e) 16384
  )

  # Validate input
  validate_numeric_param(n, "n", min = 0, max = MAX_EXCEL_COLUMNS)

  if (n <= 0) {
    return(character(0))
  }

  letters_vec <- character(n)

  for (i in 1:n) {
    col_num <- i
    letter <- ""

    # Proper base-26 conversion (A=1, not A=0)
    while (col_num > 0) {
      # Subtract 1 to make it 0-indexed for modulo
      remainder <- (col_num - 1) %% 26
      letter <- paste0(LETTERS[remainder + 1], letter)
      col_num <- (col_num - 1) %/% 26
    }

    letters_vec[i] <- letter
  }

  return(letters_vec)
}

#' Format value for output
#'
#' USAGE: Format numeric values before writing to Excel
#' DESIGN: Returns NA_real_ for NULL/NA (displays as blank in Excel)
#' TYPES: frequency, percent, rating, index, numeric
#'
#' V10.0.0: Added numeric type support for numeric questions
#'
#' @param value Numeric value to format
#' @param type Character, type of value (default: "frequency")
#' @param decimal_places_percent Integer, decimals for percentages
#' @param decimal_places_ratings Integer, decimals for ratings
#' @param decimal_places_index Integer, decimals for indices
#' @param decimal_places_numeric Integer, decimals for numeric questions (default: 1)
#' @return Numeric, formatted value or NA_real_
#' @export
format_output_value <- function(value, type = "frequency",
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {
  # Handle NULL and NA up front
  if (is.null(value) || (length(value) == 0L)) {
    return(NA_real_)
  }

  # Coerce to numeric safely
  value_num <- suppressWarnings(as.numeric(value))
  if (is.na(value_num)) {
    return(NA_real_)
  }

  # Choose rounding behaviour by type
  formatted_value <- switch(type,
    # Raw counts – always 0 decimals
    "frequency" = round(value_num, 0),

    # Column / row %s, top 2 box %, etc.
    "percent"   = round(value_num, decimal_places_percent),

    # Ratings (e.g., 1–5, 0–10) – usually 1 decimal
    "rating"    = round(value_num, decimal_places_ratings),

    # Index scores (100 = norm, etc.)
    "index"     = round(value_num, decimal_places_index),

    # NEW: numeric questions (means, medians, SDs, etc.)
    "numeric"   = round(value_num, decimal_places_numeric),

    # Fallback: treat unknown types as percent-style values
    round(value_num, decimal_places_percent)
  )

  return(formatted_value)
}

#' Calculate percentage
#'
#' USAGE: Calculate percentages with automatic 0/0 handling
#' DESIGN: Returns NA_real_ for division by zero (not 0 or error)
#'
#' @param numerator Numeric, numerator
#' @param denominator Numeric, denominator
#' @param decimal_places Integer, decimal places for rounding (default: 0)
#' @return Numeric, percentage (0-100 scale) or NA_real_
#' @export
#' @examples
#' calc_percentage(50, 100)     # 50
#' calc_percentage(1, 3, 1)     # 33.3
#' calc_percentage(10, 0)       # NA
calc_percentage <- function(numerator, denominator, decimal_places = 0) {
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }

  return(round((numerator / denominator) * 100, decimal_places))
}

# ==============================================================================
# END OF SHARED_FORMATTING.R
# ==============================================================================
