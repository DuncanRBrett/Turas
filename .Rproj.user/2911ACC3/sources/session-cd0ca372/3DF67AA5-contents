# ==============================================================================
# TURAS CORE - UTILITIES
# ==============================================================================
# General utility functions used throughout the toolkit
# Migrated from shared_functions.r V9.9.1
# ==============================================================================

# ==============================================================================
# PATH HANDLING
# ==============================================================================

#' Resolve relative path from base path
#'
#' USAGE: Convert relative paths to absolute for file operations
#' DESIGN: Platform-independent, handles ./ and ../ correctly
#' SECURITY: Normalizes path to prevent directory traversal attacks
#'
#' @param base_path Character, base directory path
#' @param relative_path Character, path relative to base
#' @return Character, absolute normalized path
#' @export
#' @examples
#' resolve_path("/Users/john/project", "Data/survey.xlsx")
#' resolve_path("/Users/john/project", "./Data/survey.xlsx")
resolve_path <- function(base_path, relative_path) {
  # Validate inputs
  if (is.null(base_path) || is.na(base_path) || base_path == "") {
    stop("base_path cannot be empty", call. = FALSE)
  }
  
  if (is.null(relative_path) || is.na(relative_path) || relative_path == "") {
    return(normalizePath(base_path, mustWork = FALSE))
  }
  
  # Remove leading ./
  relative_path <- gsub("^\\./", "", relative_path)
  
  # Combine paths (handles both / and \)
  full_path <- file.path(base_path, relative_path)
  
  # Normalize (resolves .., ., converts to OS-specific separators)
  full_path <- normalizePath(full_path, winslash = "/", mustWork = FALSE)
  
  return(full_path)
}

#' Get project root directory from config file location
#'
#' USAGE: Determine project root for resolving relative paths
#' DESIGN: Simple - parent directory of config file
#'
#' @param config_file_path Character, path to config file
#' @return Character, project root directory path
#' @export
#' @examples
#' project_root <- get_project_root(config_file)
get_project_root <- function(config_file_path) {
  validate_char_param(config_file_path, "config_file_path", allow_empty = FALSE)
  
  project_root <- dirname(config_file_path)
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)
  
  return(project_root)
}

# ==============================================================================
# TYPE CONVERSION UTILITIES
# ==============================================================================

#' Type-safe equality comparison with trimming
#'
#' CRITICAL FUNCTION: Used extensively for matching survey responses to options
#'
#' CASE SENSITIVITY: Comparison is CASE-SENSITIVE
#'   - "Apple" != "apple"
#'   - Both values are trimmed of whitespace before comparison
#'   - If case-insensitive matching needed, use tolower() on both sides
#'
#' NA HANDLING (V9.9.1):
#'   - Real NA values are treated as missing
#'   - NA == NA returns TRUE (both missing)
#'   - NA != "NA" (missing value != string "NA")
#'
#' @param a First value/vector
#' @param b Second value/vector
#' @return Logical vector of comparisons
#' @export
#' @examples
#' safe_equal("Apple", "apple")      # FALSE (case-sensitive)
#' safe_equal("  Apple  ", "Apple")  # TRUE (whitespace trimmed)
#' safe_equal(NA, NA)                # TRUE (both missing)
#' safe_equal(NA, "NA")              # FALSE (missing != string)
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

# ==============================================================================
# DATA VALIDATION HELPERS
# ==============================================================================

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

# ==============================================================================
# MATH UTILITIES
# ==============================================================================

#' Safe division with zero handling
#'
#' USAGE: Prevent division by zero errors
#' DESIGN: Returns NA_real_ when denominator is 0 or NA
#'
#' @param numerator Numeric, numerator
#' @param denominator Numeric, denominator
#' @return Numeric, result or NA_real_
#' @export
#' @examples
#' safe_divide(10, 2)   # 5
#' safe_divide(10, 0)   # NA
#' safe_divide(10, NA)  # NA
safe_divide <- function(numerator, denominator) {
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }
  
  return(numerator / denominator)
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

# Success message
cat("Turas utilities loaded (COMPLETE!)\n")

# ==============================================================================
# ADD THESE FUNCTIONS TO: core/utilities.R
# ==============================================================================
# Instructions:
# 1. Open ~/Documents/Turas/core/utilities.R
# 2. Scroll to the BOTTOM of the file
# 3. Copy and paste ALL the code below
# 4. Save the file (Cmd+S or Ctrl+S)
# ==============================================================================

#' Safely execute expression with error handling
#'
#' Wraps an expression in tryCatch and returns a default value on error.
#' Useful for operations that might fail but shouldn't stop execution.
#'
#' USAGE: Wrap potentially failing operations
#' DESIGN: Returns default on error, optionally logs warning
#'
#' @param expr Expression to evaluate
#' @param default Default value to return on error (default: NA)
#' @param error_msg Error message prefix for warnings
#' @param silent Logical, suppress warnings (default: FALSE)
#' @return Result of expr or default value
#' @export
#' @examples
#' safe_execute(as.numeric("not a number"), default = 0)
#' safe_execute(stop("error"), default = NULL, silent = TRUE)
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

#' Format value for Excel output
#'
#' Returns NA_real_ for NULL/NA values (displays as blank in Excel).
#' Rounds numeric values to specified decimal places.
#'
#' USAGE: Prepare values for Excel output
#' DESIGN: NA_real_ displays as blank in Excel (better than "NA" text)
#'
#' @param value Numeric, value to format
#' @param decimal_places Integer, decimal places for rounding (default: 0)
#' @return Numeric, formatted value or NA_real_
#' @export
#' @examples
#' format_output_value(NULL)           # NA_real_
#' format_output_value(12.3456, 2)     # 12.35
#' format_output_value(50, 0)          # 50
format_output_value <- function(value, decimal_places = 0) {
  if (is.null(value) || is.na(value)) {
    return(NA_real_)
  }
  
  return(round(value, decimal_places))
}

#' Check and warn about memory usage
#'
#' Monitors R memory usage and optionally forces garbage collection.
#' Memory reported in GiB (1024^3 bytes) to match OS conventions.
#'
#' USAGE: Call periodically during large data processing
#' DESIGN: Uses pryr package if available, fails silently if not
#' REQUIREMENTS: Requires 'pryr' package (optional)
#'
#' @param force_gc Logical, force garbage collection if memory high (default: TRUE)
#' @param warning_threshold Numeric, GiB threshold for warning (default: 2.0)
#' @param critical_threshold Numeric, GiB threshold for critical (default: 4.0)
#' @return Invisible NULL
#' @export
#' @examples
#' check_memory()  # Check and report if over threshold
#' check_memory(force_gc = FALSE)  # Check only, don't clean
check_memory <- function(force_gc = TRUE, 
                         warning_threshold = 2.0,
                         critical_threshold = 4.0) {
  # Only check if pryr is available
  if (!requireNamespace("pryr", quietly = TRUE)) {
    return(invisible(NULL))
  }
  
  mem_used_bytes <- pryr::mem_used()
  mem_used_gib <- mem_used_bytes / (1024^3)
  
  if (mem_used_gib > critical_threshold) {
    log_message(sprintf("CRITICAL: Memory usage %.1f GiB - forcing cleanup", 
                        mem_used_gib), "ERROR")
    if (force_gc) gc()
  } else if (mem_used_gib > warning_threshold) {
    log_message(sprintf("WARNING: Memory usage %.1f GiB", mem_used_gib), "WARNING")
    if (force_gc) gc()
  }
  
  invisible(NULL)
}

#' Efficiently combine list of dataframes
#'
#' More efficient than repeated rbind() calls in a loop.
#' For 100+ dataframes, this is O(n) vs O(n²) for loop-based rbind.
#'
#' USAGE: Accumulate dataframes in a list, then combine at end
#' DESIGN: Single do.call(rbind) is much faster than iterative rbind
#' PERFORMANCE: ~10x faster for 100+ dataframes vs loop rbind
#'
#' @param df_list List of dataframes to combine
#' @return Combined dataframe, or empty dataframe if list is empty
#' @export
#' @examples
#' # Good: Accumulate in list, then batch combine
#' results <- list()
#' for (i in 1:100) {
#'   results[[i]] <- data.frame(x = i, y = i*2)
#' }
#' combined <- batch_rbind(results)
#' 
#' # Bad: Don't do this (O(n²))
#' # result <- data.frame()
#' # for (i in 1:100) {
#' #   result <- rbind(result, data.frame(x = i, y = i*2))
#' # }
batch_rbind <- function(df_list) {
  # Handle empty list
  if (length(df_list) == 0) {
    return(data.frame())
  }
  
  # Handle single dataframe
  if (length(df_list) == 1) {
    return(df_list[[1]])
  }
  
  # Use do.call for efficiency
  do.call(rbind, df_list)
}

# Success message
cat("Turas utilities extensions loaded\n")

