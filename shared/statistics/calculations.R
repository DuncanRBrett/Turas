# ==============================================================================
# TURAS SHARED - STATISTICAL CALCULATIONS
# ==============================================================================
# Core statistical calculation functions
# Migrated from shared_functions.r V9.9.1
# ==============================================================================

#' Generate Excel column letters (proper base-26 to XFD)
#'
#' CRITICAL FUNCTION: Used for significance testing column mapping
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
    
    # Proper base-26 algorithm (1-based, no zero)
    while (col_num > 0) {
      # Get remainder (1-26, not 0-25)
      remainder <- (col_num - 1) %% 26
      
      # Convert to letter (A=0, B=1, ..., Z=25)
      letter <- paste0(LETTERS[remainder + 1], letter)
      
      # Move to next position
      col_num <- (col_num - remainder - 1) %/% 26
    }
    
    letters_vec[i] <- letter
  }
  
  return(letters_vec)
}

# Success message
cat("Turas statistics calculations loaded\n")
