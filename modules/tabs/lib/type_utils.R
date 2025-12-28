# ==============================================================================
# TYPE UTILITIES - TURAS V10.0
# ==============================================================================
# Safe type conversion and comparison utilities
# Extracted from shared_functions.R for better modularity
#
# VERSION HISTORY:
# V10.0 - Extracted from shared_functions.R (2025)
#        - Modular design for better maintainability
#        - All type coercion and comparison functions
# ==============================================================================

# ==============================================================================
# SAFE COMPARISON
# ==============================================================================

#' Safely compare values with NA handling (V9.9.1 REAL NA FIX)
#'
#' USAGE: Use instead of == when comparing survey data that may have NAs
#' DESIGN: Treats NA values consistently (NA == NA returns TRUE)
#' V9.9.1 FIX: Now distinguishes between real NA and string "NA"
#'
#' KEY BEHAVIORS:
#' - Both NA → TRUE (both missing)
#' - One NA, one value → FALSE (mismatch)
#' - Both values → standard equality check (with whitespace trimming)
#' - String "NA" vs real NA → FALSE (different types)
#'
#' @param a First value (scalar or vector)
#' @param b Second value (scalar or vector)
#' @return Logical vector of same length as longer input
#' @export
#' @examples
#' safe_equal(NA, NA)           # TRUE (both missing)
#' safe_equal("A", "A")         # TRUE
#' safe_equal("A", NA)          # FALSE (mismatch)
#' safe_equal("NA", NA)         # FALSE (string vs real NA)
#' safe_equal(c("A", NA), c("A", NA))  # c(TRUE, TRUE)
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


# ==============================================================================
# SAFE TYPE CONVERSIONS
# ==============================================================================

#' Safely convert to numeric with NA handling
#'
#' USAGE: Convert values to numeric without warnings
#' DESIGN: Replaces NAs with specified value
#'
#' @param x Value to convert
#' @param na_value Value to use for NAs (default: NA_real_)
#' @return Numeric value
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


#' Safely convert to character
#'
#' USAGE: Convert values to character with NA handling
#' DESIGN: Preserves NA values unless specified otherwise
#'
#' @param x Value to convert
#' @param na_value Character to use for NAs (default: NA_character_)
#' @return Character value
#' @export
#' @examples
#' safe_char(123)         # "123"
#' safe_char(NA)          # NA_character_
#' safe_char(NA, "")      # ""
safe_char <- function(x, na_value = NA_character_) {
  if (is.null(x)) {
    return(na_value)
  }

  result <- as.character(x)
  result[is.na(result)] <- na_value
  return(result)
}
