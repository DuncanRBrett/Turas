# ==============================================================================
# SHARED SAFE OPERATIONS - TURAS V10.0
# ==============================================================================
# Extracted from shared_functions.R for better maintainability
# Provides safe type conversion and data utilities
#
# CONTENTS:
# - Type-safe equality comparison with NA handling
# - Safe numeric and logical conversions
# - Data presence checking
# - Safe execution wrapper
# - Efficient batch operations
#
# DESIGN PRINCIPLES:
# - Graceful degradation with defaults
# - Explicit NA handling
# - Case-sensitive by default (documented)
# - Performance-optimized for common operations
# ==============================================================================

#' Type-safe equality comparison with trimming (V9.9.1: Fixed NA handling)
#'
#' CASE SENSITIVITY: Comparison is CASE-SENSITIVE
#'   - "Apple" != "apple"
#'   - Both values are trimmed of whitespace before comparison
#'   - If case-insensitive matching needed, use tolower() on both sides
#'
#' NA HANDLING (V9.9.1 FIX):
#'   - Real NA values are treated as missing (non-match)
#'   - NA == NA returns TRUE (both missing)
#'   - NA != "NA" (missing value != string "NA")
#'   - Previous version incorrectly matched NA to string "NA"
#'
#' DESIGN: Converts to character for safety, trims whitespace
#' USAGE: Use for matching survey responses to option text
#'
#' @param a First value/vector
#' @param b Second value/vector
#' @return Logical vector of comparisons
#' @export
#' @examples
#' # Case-sensitive (default)
#' safe_equal("Apple", "apple")  # FALSE
#'
#' # With whitespace handling
#' safe_equal("  Apple  ", "Apple")  # TRUE
#'
#' # NA handling (V9.9.1 fix)
#' safe_equal(NA, NA)        # TRUE (both missing)
#' safe_equal(NA, "NA")      # FALSE (missing != string)
#' safe_equal("Apple", NA)   # FALSE
#'
#' # Case-insensitive (if needed)
#' safe_equal(tolower("Apple"), tolower("apple"))  # TRUE
safe_equal <- function(a, b) {
  if (length(a) == 0 || length(b) == 0) {
    return(logical(0))
  }

  # Vectorize to longer length
  max_len <- max(length(a), length(b))
  if (length(a) < max_len) a <- rep_len(a, max_len)
  if (length(b) < max_len) b <- rep_len(b, max_len)

  # Initialize result
  result <- rep(FALSE, max_len)

  # Identify NAs
  na_a <- is.na(a)
  na_b <- is.na(b)

  # Both NA = TRUE (both missing)
  both_na <- na_a & na_b
  result[both_na] <- TRUE

  # Compare non-NA values (trim whitespace)
  neither_na <- !na_a & !na_b
  if (any(neither_na)) {
    result[neither_na] <- trimws(as.character(a[neither_na])) ==
                          trimws(as.character(b[neither_na]))
  }

  # One NA, one not = FALSE (already initialized to FALSE)

  return(result)
}

#' Safely convert to numeric
#'
#' USAGE: Convert config values, survey responses to numeric
#' DESIGN: Suppresses warnings, replaces failures with na_value
#'
#' @param x Value(s) to convert
#' @param na_value Value to use for conversion failures (default: NA_real_)
#' @return Numeric value(s)
#' @export
#' @examples
#' safe_numeric("123")     # 123
#' safe_numeric("abc")     # NA
#' safe_numeric("abc", 0)  # 0
safe_numeric <- function(x, na_value = NA_real_) {
  result <- suppressWarnings(as.numeric(x))
  result[is.na(result)] <- na_value
  return(result)
}

#' Safely convert to logical
#'
#' USAGE: Convert config settings to TRUE/FALSE
#' DESIGN: Handles multiple text representations (Y/N, YES/NO, T/F, 1/0)
#' CASE INSENSITIVE: Converts to uppercase before checking
#'
#' @param x Value to convert (TRUE/FALSE/Y/N/YES/NO/T/F/1/0)
#' @param default Default value if conversion fails (default: FALSE)
#' @return Logical value
#' @export
#' @examples
#' safe_logical("Y")      # TRUE
#' safe_logical("yes")    # TRUE
#' safe_logical("1")      # TRUE
#' safe_logical("N")      # FALSE
#' safe_logical("maybe")  # FALSE (with warning)
safe_logical <- function(x, default = FALSE) {
  if (is.null(x) || (length(x) == 1 && is.na(x))) {
    return(default)
  }

  # Already logical
  if (is.logical(x)) {
    return(x)
  }

  # Convert to uppercase string
  x_upper <- toupper(trimws(as.character(x)))

  # Check TRUE values
  if (x_upper %in% c("TRUE", "T", "Y", "YES", "1")) {
    return(TRUE)
  }

  # Check FALSE values
  if (x_upper %in% c("FALSE", "F", "N", "NO", "0")) {
    return(FALSE)
  }

  # Couldn't convert
  warning(sprintf(
    "Could not convert '%s' to logical, using default: %s",
    x, default
  ), call. = FALSE)
  return(default)
}

#' Check if data frame has data
#'
#' USAGE: Guard clause at start of functions expecting data
#' DESIGN: Simple null/empty check
#'
#' @param df Data frame to check
#' @return Logical, TRUE if data frame has at least 1 row
#' @export
#' @examples
#' if (!has_data(filtered_data)) {
#'   return(NULL)
#' }
has_data <- function(df) {
  !is.null(df) && is.data.frame(df) && nrow(df) > 0
}

#' Safely execute with error handling
#'
#' @param expr Expression to evaluate
#' @param default Default value on error
#' @param error_msg Error message prefix
#' @param silent Suppress warnings
#' @return Result or default
#' @export
safe_execute <- function(expr, default = NA, error_msg = "Operation failed",
                        silent = FALSE) {
  tryCatch(
    expr,
    error = function(e) {
      if (!silent) {
        warning(sprintf("%s: %s", error_msg, conditionMessage(e)), call. = FALSE)
      }
      return(default)
    }
  )
}

#' Batch rbind (efficient)
#'
#' @param row_list List of data frames
#' @return Single data frame
#' @export
batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  do.call(rbind, row_list)
}

# ==============================================================================
# END OF SHARED_SAFE_OPS.R
# ==============================================================================
