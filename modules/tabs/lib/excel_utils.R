# ==============================================================================
# EXCEL UTILITIES - TURAS V10.0
# ==============================================================================
# Excel-specific utility functions
# Extracted from shared_functions.R for better modularity
#
# VERSION HISTORY:
# V10.0 - Extracted from shared_functions.R (2025)
#        - Modular design for better maintainability
#        - All Excel-specific utilities
# V9.9 - Proper base-26 algorithm implemented
# ==============================================================================

# ==============================================================================
# CONSTANTS
# ==============================================================================

# Excel Limits
MAX_EXCEL_COLUMNS <- 16384  # Excel's maximum (A to XFD)
MAX_EXCEL_ROWS <- 1048576

# ==============================================================================
# EXCEL COLUMN LETTER GENERATION
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


#' Convert Excel column number to letter
#'
#' USAGE: Convert single column number to Excel letter
#' DESIGN: Wrapper around generate_excel_letters for single column
#'
#' @param col_num Integer, column number (1-based)
#' @return Character, Excel column letter
#' @export
#' @examples
#' excel_column_letter(1)    # "A"
#' excel_column_letter(27)   # "AA"
excel_column_letter <- function(col_num) {
  validate_numeric_param(col_num, "col_num", min = 1, max = MAX_EXCEL_COLUMNS)
  generate_excel_letters(col_num)[col_num]
}


# ==============================================================================
# VALUE FORMATTING FOR EXCEL
# ==============================================================================

#' Format value for Excel output
#'
#' USAGE: Format numeric values before writing to Excel
#' DESIGN: Returns NA_real_ for NULL/NA (displays as blank in Excel)
#' TYPES: frequency, percent, rating, index, numeric
#'
#' V10.0: Added numeric type support for numeric questions
#'
#' @param value Numeric value to format
#' @param type Character, type of value (default: "frequency")
#' @param decimal_places_percent Integer, decimals for percentages
#' @param decimal_places_ratings Integer, decimals for ratings
#' @param decimal_places_index Integer, decimals for indices
#' @param decimal_places_numeric Integer, decimals for numeric questions (default: 1)
#' @return Numeric, formatted value or NA_real_
#' @export
#' @examples
#' format_output_value(1234, "frequency")         # 1234
#' format_output_value(0.456, "percent", 1)       # 45.6
#' format_output_value(3.14159, "rating", 2)      # 3.14
#' format_output_value(NA, "percent")             # NA_real_
format_output_value <- function(value, type = "frequency",
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {
  # Handle NULL and NA up front
  if (is.null(value) || (length(value) == 0L)) {
    return(NA_real_)
  }

  # Single value extraction for safety
  if (length(value) > 1) {
    warning("format_output_value received vector, using first element only")
    value <- value[1]
  }

  # NA handling
  if (is.na(value)) {
    return(NA_real_)
  }

  # Type-specific formatting
  result <- switch(type,
    "frequency" = round(value, 0),
    "percent" = round(value, decimal_places_percent),
    "rating" = round(value, decimal_places_ratings),
    "index" = round(value, decimal_places_index),
    "numeric" = round(value, decimal_places_numeric),
    # Default: round to integer
    round(value, 0)
  )

  return(result)
}
