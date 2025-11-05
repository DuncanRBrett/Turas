# ==============================================================================
# TURAS>TABS - UTILITIES MODULE
# ==============================================================================
# Purpose: Tabs-specific utility functions
# Dependencies: None (core utilities)
# Author: Turas Analytics Toolkit
# Version: 1.0.0
# ==============================================================================

# ==============================================================================
# SAFE EXECUTION WRAPPERS
# ==============================================================================

#' Safe Execute with Error Handling
#' 
#' Safely executes an expression with error handling
#' Returns default value on error
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

#' Type-Safe Equality with Trimming
#' 
#' CASE SENSITIVITY:
#' - Comparison is CASE-SENSITIVE by default
#' - "Apple" != "apple" 
#' - Both values are trimmed of whitespace before comparison
#' 
#' @param a First value/vector
#' @param b Second value/vector
#' @return Logical vector
#' @export
safe_equal <- function(a, b) {
  if (length(a) == 0 || length(b) == 0) return(logical(0))
  trimws(as.character(a)) == trimws(as.character(b))
}

#' Check if Data Frame Has Data
#' 
#' @param df Data frame
#' @return Logical
#' @export
has_data <- function(df) {
  !is.null(df) && is.data.frame(df) && nrow(df) > 0
}

# ==============================================================================
# VALUE FORMATTING
# ==============================================================================

#' Format Value for Output
#' 
#' Formats numeric values for Excel output
#' Returns NA_real_ for missing values (displays as blank in Excel)
#' 
#' @param value Numeric value
#' @param type Value type ("frequency", "percent", "rating", "index", "numeric")
#' @param decimal_places_percent Decimal places for percentages
#' @param decimal_places_ratings Decimal places for ratings
#' @param decimal_places_index Decimal places for index
#' @param decimal_places_numeric Decimal places for numeric
#' @return Formatted numeric or NA_real_
#' @export
format_output_value <- function(value, 
                               type = "frequency", 
                               decimal_places_percent = 0,
                               decimal_places_ratings = 1,
                               decimal_places_index = 1,
                               decimal_places_numeric = 1) {
  
  if (is.null(value) || is.na(value)) return(NA_real_)
  
  formatted_value <- switch(type,
    "percent" = round(as.numeric(value), decimal_places_percent),
    "rating" = round(as.numeric(value), decimal_places_ratings),
    "index" = round(as.numeric(value), decimal_places_index),
    "numeric" = round(as.numeric(value), decimal_places_numeric),
    "frequency" = round(as.numeric(value), 0),
    round(as.numeric(value), 2)  # Default
  )
  
  return(formatted_value)
}

#' Calculate Percentage
#' 
#' Safely calculates percentage with zero-division handling
#' 
#' @param numerator Numerator
#' @param denominator Denominator
#' @param decimal_places Number of decimal places
#' @param zero_as_blank Return NA for zero denominator
#' @return Percentage or NA
#' @export
calc_percentage <- function(numerator, denominator, decimal_places = 0, 
                           zero_as_blank = TRUE) {
  
  if (is.null(numerator) || is.null(denominator)) return(NA_real_)
  if (is.na(numerator) || is.na(denominator)) return(NA_real_)
  
  if (denominator == 0) {
    return(if (zero_as_blank) NA_real_ else 0)
  }
  
  pct <- (numerator / denominator) * 100
  return(round(pct, decimal_places))
}

# ==============================================================================
# DATA VALIDATION
# ==============================================================================

#' Validate Data Frame
#' 
#' Validates that data frame exists and has required columns
#' 
#' @param df Data frame to validate
#' @param required_cols Required column names
#' @param min_rows Minimum number of rows
#' @param param_name Parameter name for error messages
#' @return TRUE if valid, stops with error if not
#' @export
validate_data_frame <- function(df, required_cols = NULL, min_rows = 1, 
                                param_name = "data") {
  
  # Check exists and is data frame
  if (is.null(df)) {
    stop(sprintf("%s is NULL", param_name), call. = FALSE)
  }
  
  if (!is.data.frame(df)) {
    stop(sprintf("%s must be a data frame", param_name), call. = FALSE)
  }
  
  # Check row count
  if (nrow(df) < min_rows) {
    stop(sprintf(
      "%s must have at least %d row(s), got %d",
      param_name, min_rows, nrow(df)
    ), call. = FALSE)
  }
  
  # Check required columns
  if (!is.null(required_cols)) {
    missing_cols <- setdiff(required_cols, names(df))
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "%s missing required columns: %s",
        param_name,
        paste(missing_cols, collapse = ", ")
      ), call. = FALSE)
    }
  }
  
  return(TRUE)
}

#' Validate Column Exists
#' 
#' Checks if a column exists in data frame
#' 
#' @param data Data frame
#' @param column_name Column name to check
#' @param friendly_name Friendly name for error message
#' @return TRUE if exists, stops with error if not
#' @export
validate_column_exists <- function(data, column_name, friendly_name = NULL) {
  
  if (is.null(friendly_name)) {
    friendly_name <- column_name
  }
  
  if (!column_name %in% names(data)) {
    stop(sprintf(
      "Column '%s' not found in data\nAvailable columns: %s",
      friendly_name,
      paste(head(names(data), 20), collapse = ", ")
    ), call. = FALSE)
  }
  
  return(TRUE)
}

#' Validate Weights
#' 
#' Validates weight vector
#' 
#' @param weights Weight vector
#' @param data_rows Number of data rows
#' @param allow_zero Allow zero weights
#' @return TRUE if valid, stops with error if not
#' @export
validate_weights <- function(weights, data_rows, allow_zero = TRUE) {
  
  if (is.null(weights)) {
    stop("Weights cannot be NULL", call. = FALSE)
  }
  
  if (length(weights) != data_rows) {
    stop(sprintf(
      "Weight vector length (%d) doesn't match data rows (%d)",
      length(weights), data_rows
    ), call. = FALSE)
  }
  
  if (any(is.na(weights))) {
    stop("Weights contain NA values", call. = FALSE)
  }
  
  if (any(weights < 0)) {
    stop("Weights cannot be negative", call. = FALSE)
  }
  
  if (!allow_zero && any(weights == 0)) {
    stop("Weights cannot be zero", call. = FALSE)
  }
  
  return(TRUE)
}

# ==============================================================================
# EFFICIENT DATA OPERATIONS
# ==============================================================================

#' Batch Row Bind
#' 
#' Efficiently combines list of data frames
#' 
#' @param row_list List of data frames
#' @return Single data frame
#' @export
batch_rbind <- function(row_list) {
  if (length(row_list) == 0) return(data.frame())
  do.call(rbind, row_list)
}

#' Batch Column Bind
#' 
#' Efficiently combines list of vectors as columns
#' 
#' @param col_list List of vectors
#' @param col_names Column names
#' @return Data frame
#' @export
batch_cbind <- function(col_list, col_names = NULL) {
  if (length(col_list) == 0) return(data.frame())
  
  df <- as.data.frame(do.call(cbind, col_list), stringsAsFactors = FALSE)
  
  if (!is.null(col_names) && length(col_names) == ncol(df)) {
    names(df) <- col_names
  }
  
  return(df)
}

# ==============================================================================
# MEMORY MANAGEMENT
# ==============================================================================

#' Check Memory Usage
#' 
#' Checks current memory usage and optionally forces garbage collection
#' 
#' @param force_gc Force garbage collection
#' @param verbose Print memory info
#' @return Memory info (invisibly)
#' @export
check_memory <- function(force_gc = TRUE, verbose = FALSE) {
  
  if (force_gc) {
    gc(verbose = FALSE)
  }
  
  mem_used <- gc()[2, 2]  # Vcells used
  
  if (verbose) {
    cat(sprintf("Memory used: %.1f MB\n", mem_used))
  }
  
  return(invisible(mem_used))
}

# ==============================================================================
# LOGGING
# ==============================================================================

#' Log Message
#' 
#' Simple logging function
#' 
#' @param msg Message to log
#' @param level Log level ("INFO", "WARNING", "ERROR")
#' @param verbose Print message
#' @export
log_message <- function(msg, level = "INFO", verbose = TRUE) {
  if (verbose) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    cat(sprintf("[%s] %s: %s\n", timestamp, level, msg))
  }
}

#' Log Progress
#' 
#' Logs progress through a series of items
#' 
#' @param current Current item number
#' @param total Total items
#' @param item Item description
#' @param start_time Start time for ETA calculation
#' @export
log_progress <- function(current, total, item = "", start_time = NULL) {
  
  pct <- round((current / total) * 100, 1)
  
  msg <- sprintf("Progress: %d/%d (%s%%)", current, total, pct)
  
  if (item != "") {
    msg <- paste0(msg, " - ", item)
  }
  
  if (!is.null(start_time)) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    if (current > 0 && current < total) {
      eta <- (elapsed / current) * (total - current)
      msg <- paste0(msg, sprintf(" [ETA: %s]", format_seconds(eta)))
    }
  }
  
  cat(msg, "")

}

#' Format Seconds
#' 
#' Formats seconds as human-readable time
#' 
#' @param seconds Number of seconds
#' @return Formatted string
#' @export
format_seconds <- function(seconds) {
  if (seconds < 60) {
    return(sprintf("%.0fs", seconds))
  } else if (seconds < 3600) {
    return(sprintf("%.1fm", seconds / 60))
  } else {
    return(sprintf("%.1fh", seconds / 3600))
  }
}

# ==============================================================================
# ERROR HANDLING
# ==============================================================================

#' Create Error Log
#' 
#' Creates a new error log structure
#' 
#' @return Empty error log list
#' @export
create_error_log <- function() {
  return(list(
    errors = list(),
    warnings = list(),
    info = list()
  ))
}

#' Log Issue
#' 
#' Adds an issue to error log
#' 
#' @param error_log Error log structure
#' @param component Component name
#' @param issue_type Type ("error", "warning", "info")
#' @param description Issue description
#' @param details Additional details
#' @return Updated error log
#' @export
log_issue <- function(error_log, component, issue_type = "error", 
                     description, details = NULL) {
  
  issue <- list(
    timestamp = Sys.time(),
    component = component,
    description = description,
    details = details
  )
  
  if (issue_type == "error") {
    error_log$errors <- append(error_log$errors, list(issue))
  } else if (issue_type == "warning") {
    error_log$warnings <- append(error_log$warnings, list(issue))
  } else {
    error_log$info <- append(error_log$info, list(issue))
  }
  
  return(error_log)
}

#' Print Error Log
#' 
#' Prints error log summary
#' 
#' @param error_log Error log structure
#' @export
print_error_log <- function(error_log) {
  
  n_errors <- length(error_log$errors)
  n_warnings <- length(error_log$warnings)
  n_info <- length(error_log$info)
  
  cat("")

  cat("==============================================")

  cat("ERROR LOG SUMMARY")

  cat("==============================================")

  cat(sprintf("Errors: %d\n", n_errors))
  cat(sprintf("Warnings: %d\n", n_warnings))
  cat(sprintf("Info: %d\n", n_info))
  cat("==============================================")

  
  if (n_errors > 0) {
    cat("\nERRORS:")

    for (i in seq_along(error_log$errors)) {
      err <- error_log$errors[[i]]
      cat(sprintf("  %d. [%s] %s\n", i, err$component, err$description))
    }
  }
  
  if (n_warnings > 0) {
    cat("\nWARNINGS:")

    for (i in seq_along(error_log$warnings)) {
      warn <- error_log$warnings[[i]]
      cat(sprintf("  %d. [%s] %s\n", i, warn$component, warn$description))
    }
  }
  
  cat("")

}

# ==============================================================================
# MODULE METADATA
# ==============================================================================

#' Get Module Version
#' @export
get_utilities_version <- function() {
  return("1.0.0")
}

#' Get Module Info
#' @export
get_utilities_info <- function() {
  cat("")

  cat("================================================")

  cat("TURAS>TABS Utilities Module")

  cat("================================================")

  cat("Version:", get_utilities_version(), "")

  cat("Purpose: Tabs-specific utility functions")

  cat("")

  cat("Functions:")

  cat("  - safe_execute(), safe_equal()")

  cat("  - format_output_value(), calc_percentage()")

  cat("  - validate_data_frame(), validate_weights()")

  cat("  - batch_rbind(), check_memory()")

  cat("  - log_message(), log_progress()")

  cat("================================================\n")

}

# Module loaded message
message("Turas>Tabs utilities module loaded")

# String repeat operator
`%R%` <- function(string, times) {
  paste(rep(string, times), collapse = "")
}
