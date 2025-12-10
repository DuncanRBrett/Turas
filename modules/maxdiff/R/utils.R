# ==============================================================================
# MAXDIFF MODULE - UTILITY FUNCTIONS - TURAS V10.0
# ==============================================================================
# Common utility functions for MaxDiff analysis
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# DEPENDENCIES:
# - None (base R only)
# ==============================================================================

MAXDIFF_UTILS_VERSION <- "10.0"

# ==============================================================================
# LOGGING AND PROGRESS
# ==============================================================================

#' Log message with timestamp
#'
#' @param message Character. Message to log
#' @param level Character. Log level: INFO, WARN, ERROR
#' @param verbose Logical. Print message if TRUE
#'
#' @keywords internal
log_message <- function(message, level = "INFO", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  prefix <- switch(level,
    "INFO" = "  ",
    "WARN" = "  [WARNING] ",
    "ERROR" = "  [ERROR] ",
    "  "
  )

  cat(sprintf("%s%s\n", prefix, message))
  invisible(NULL)
}


#' Log progress with percentage
#'
#' @param current Integer. Current item number
#' @param total Integer. Total items
#' @param message Character. Context message
#' @param verbose Logical. Print if TRUE
#'
#' @keywords internal
log_progress <- function(current, total, message = "Progress", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  pct <- round((current / total) * 100)
  cat(sprintf("  %s: %d/%d (%.0f%%)\n", message, current, total, pct))
  invisible(NULL)
}


# ==============================================================================
# VALIDATION UTILITIES
# ==============================================================================

#' Validate that a value is in allowed set
#'
#' @param value Value to check
#' @param allowed Character vector of allowed values
#' @param param_name Character. Parameter name for error message
#' @param case_sensitive Logical. Case-sensitive comparison
#'
#' @return The validated value (possibly transformed)
#' @keywords internal
validate_option <- function(value, allowed, param_name, case_sensitive = FALSE) {
  if (is.null(value) || is.na(value)) {
    stop(sprintf("%s is required but was NULL or NA", param_name), call. = FALSE)
  }

  check_value <- if (case_sensitive) value else toupper(value)
  check_allowed <- if (case_sensitive) allowed else toupper(allowed)

  if (!check_value %in% check_allowed) {
    stop(sprintf(
      "%s must be one of: %s\n  Got: '%s'",
      param_name,
      paste(allowed, collapse = ", "),
      value
    ), call. = FALSE)
  }

  return(value)
}


#' Validate numeric value is within range
#'
#' @param value Numeric value to check
#' @param param_name Character. Parameter name
#' @param min_val Numeric. Minimum value (inclusive)
#' @param max_val Numeric. Maximum value (inclusive)
#' @param allow_na Logical. Allow NA values
#'
#' @return The validated value
#' @keywords internal
validate_numeric_range <- function(value, param_name,
                                   min_val = -Inf, max_val = Inf,
                                   allow_na = FALSE) {
  if (is.null(value)) {
    stop(sprintf("%s is required but was NULL", param_name), call. = FALSE)
  }

  if (is.na(value)) {
    if (allow_na) return(value)
    stop(sprintf("%s is required but was NA", param_name), call. = FALSE)
  }

  if (!is.numeric(value)) {
    stop(sprintf("%s must be numeric, got: %s", param_name, class(value)), call. = FALSE)
  }

  if (value < min_val || value > max_val) {
    stop(sprintf(
      "%s must be between %s and %s\n  Got: %s",
      param_name, min_val, max_val, value
    ), call. = FALSE)
  }

  return(value)
}


#' Validate positive integer
#'
#' @param value Value to check
#' @param param_name Character. Parameter name
#' @param min_val Integer. Minimum value (default: 1)
#'
#' @return Integer value
#' @keywords internal
validate_positive_integer <- function(value, param_name, min_val = 1) {
  if (is.null(value) || is.na(value)) {
    stop(sprintf("%s is required but was NULL or NA", param_name), call. = FALSE)
  }

  value <- suppressWarnings(as.integer(value))

  if (is.na(value)) {
    stop(sprintf("%s must be an integer", param_name), call. = FALSE)
  }

  if (value < min_val) {
    stop(sprintf("%s must be >= %d, got: %d", param_name, min_val, value), call. = FALSE)
  }

  return(value)
}


#' Validate file path exists
#'
#' @param path Character. File path
#' @param param_name Character. Parameter name for error message
#' @param must_exist Logical. File must exist
#' @param extensions Character vector. Allowed file extensions (e.g., c("xlsx", "csv"))
#'
#' @return Normalized file path
#' @keywords internal
validate_file_path <- function(path, param_name, must_exist = TRUE, extensions = NULL) {
  if (is.null(path) || is.na(path) || !nzchar(trimws(path))) {
    stop(sprintf("%s is required but was empty or NA", param_name), call. = FALSE)
  }

  path <- normalizePath(path, mustWork = FALSE)

  if (must_exist && !file.exists(path)) {
    stop(sprintf(
      "%s: File not found\n  Path: %s",
      param_name, path
    ), call. = FALSE)
  }

  if (!is.null(extensions)) {
    ext <- tolower(tools::file_ext(path))
    if (!ext %in% tolower(extensions)) {
      stop(sprintf(
        "%s must have extension: %s\n  Got: %s",
        param_name, paste(extensions, collapse = ", "), ext
      ), call. = FALSE)
    }
  }

  return(path)
}


#' Validate directory path exists
#'
#' @param path Character. Directory path
#' @param param_name Character. Parameter name
#' @param create Logical. Create directory if it doesn't exist
#'
#' @return Normalized directory path
#' @keywords internal
validate_directory_path <- function(path, param_name, create = TRUE) {
  if (is.null(path) || is.na(path) || !nzchar(trimws(path))) {
    stop(sprintf("%s is required but was empty or NA", param_name), call. = FALSE)
  }

  path <- normalizePath(path, mustWork = FALSE)

  if (!dir.exists(path)) {
    if (create) {
      tryCatch({
        dir.create(path, recursive = TRUE)
      }, error = function(e) {
        stop(sprintf(
          "Failed to create directory for %s\n  Path: %s\n  Error: %s",
          param_name, path, conditionMessage(e)
        ), call. = FALSE)
      })
    } else {
      stop(sprintf(
        "%s: Directory not found\n  Path: %s",
        param_name, path
      ), call. = FALSE)
    }
  }

  return(path)
}


# ==============================================================================
# STRING UTILITIES
# ==============================================================================

#' Parse yes/no string to logical
#'
#' @param value Character or logical value
#' @param default Logical. Default if parsing fails
#'
#' @return Logical value
#' @keywords internal
parse_yes_no <- function(value, default = FALSE) {
  if (is.null(value) || is.na(value)) return(default)
  if (is.logical(value)) return(value)

  value_upper <- toupper(trimws(as.character(value)))

  if (value_upper %in% c("Y", "YES", "TRUE", "1", "T")) return(TRUE)
  if (value_upper %in% c("N", "NO", "FALSE", "0", "F")) return(FALSE)

  return(default)
}


#' Safe conversion to numeric with default
#'
#' @param value Value to convert
#' @param default Default if conversion fails
#'
#' @return Numeric value or default
#' @keywords internal
safe_numeric <- function(value, default = NA_real_) {
  if (is.null(value) || length(value) == 0) return(default)
  if (is.na(value)) return(default)

  result <- suppressWarnings(as.numeric(value))

  if (is.na(result)) return(default)
  return(result)
}


#' Safe conversion to integer with default
#'
#' @param value Value to convert
#' @param default Default if conversion fails
#'
#' @return Integer value or default
#' @keywords internal
safe_integer <- function(value, default = NA_integer_) {
  if (is.null(value) || length(value) == 0) return(default)
  if (is.na(value)) return(default)

  result <- suppressWarnings(as.integer(value))

  if (is.na(result)) return(default)
  return(result)
}


#' Clean and normalize Item_ID
#'
#' @param item_id Character. Item ID to clean
#'
#' @return Cleaned item ID
#' @keywords internal
clean_item_id <- function(item_id) {
  if (is.null(item_id) || is.na(item_id)) return(NA_character_)

  # Remove leading/trailing whitespace
  cleaned <- trimws(as.character(item_id))

  # Return empty as NA
  if (!nzchar(cleaned)) return(NA_character_)

  return(cleaned)
}


# ==============================================================================
# DATA FRAME UTILITIES
# ==============================================================================

#' Get column value safely with default
#'
#' @param df Data frame
#' @param col_name Character. Column name
#' @param row_idx Integer. Row index (default: 1)
#' @param default Default value if not found
#'
#' @return Value or default
#' @keywords internal
get_col_value <- function(df, col_name, row_idx = 1, default = NA) {
  if (!col_name %in% names(df)) return(default)
  if (row_idx > nrow(df)) return(default)

  value <- df[[col_name]][row_idx]

  if (is.null(value) || is.na(value)) return(default)
  return(value)
}


#' Check if column exists and has non-NA values
#'
#' @param df Data frame
#' @param col_name Character. Column name
#'
#' @return Logical
#' @keywords internal
has_valid_column <- function(df, col_name) {
  if (!col_name %in% names(df)) return(FALSE)
  if (all(is.na(df[[col_name]]))) return(FALSE)
  return(TRUE)
}


# ==============================================================================
# MAXDIFF-SPECIFIC UTILITIES
# ==============================================================================

#' Create unique task identifier
#'
#' @param version Integer. Design version
#' @param task Integer. Task number
#'
#' @return Character. Task identifier
#' @keywords internal
make_task_id <- function(version, task) {
  sprintf("V%d_T%d", version, task)
}


#' Parse task identifier
#'
#' @param task_id Character. Task identifier (e.g., "V1_T3")
#'
#' @return Named list with version and task numbers
#' @keywords internal
parse_task_id <- function(task_id) {
  parts <- regmatches(task_id, regexec("^V(\\d+)_T(\\d+)$", task_id))[[1]]

  if (length(parts) != 3) {
    return(list(version = NA_integer_, task = NA_integer_))
  }

  list(
    version = as.integer(parts[2]),
    task = as.integer(parts[3])
  )
}


#' Calculate effective sample size from weights (Kish formula)
#'
#' @param weights Numeric vector of weights
#'
#' @return Numeric. Effective sample size
#' @keywords internal
calculate_effective_n <- function(weights) {
  if (is.null(weights) || length(weights) == 0) return(0)

  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) return(0)

  sum_w <- sum(weights)
  sum_w2 <- sum(weights^2)

  if (sum_w2 == 0) return(0)

  return((sum_w^2) / sum_w2)
}


#' Calculate design effect from weights
#'
#' @param weights Numeric vector of weights
#'
#' @return Numeric. Design effect
#' @keywords internal
calculate_deff <- function(weights) {
  if (is.null(weights) || length(weights) == 0) return(1)

  weights <- weights[!is.na(weights) & weights > 0]

  if (length(weights) == 0) return(1)

  n <- length(weights)
  eff_n <- calculate_effective_n(weights)

  if (eff_n == 0) return(NA_real_)

  return(n / eff_n)
}


#' Rescale utilities to specified scale
#'
#' @param utilities Numeric vector of raw utilities
#' @param method Character. Rescaling method: "RAW", "0_100", or "PROBABILITY"
#'
#' @return Numeric vector of rescaled utilities
#' @keywords internal
rescale_utilities <- function(utilities, method = "0_100") {
  if (length(utilities) == 0) return(numeric(0))

  method <- toupper(method)

  if (method == "RAW") {
    return(utilities)
  }

  if (method == "0_100") {
    min_u <- min(utilities, na.rm = TRUE)
    max_u <- max(utilities, na.rm = TRUE)

    if (max_u == min_u) {
      return(rep(50, length(utilities)))
    }

    return(100 * (utilities - min_u) / (max_u - min_u))
  }

  if (method == "PROBABILITY") {
    # Softmax transformation
    exp_u <- exp(utilities - max(utilities, na.rm = TRUE))  # Subtract max for numerical stability
    return(100 * exp_u / sum(exp_u, na.rm = TRUE))
  }

  warning(sprintf("Unknown rescale method: %s. Using RAW.", method))
  return(utilities)
}


#' Rank utilities (1 = highest utility)
#'
#' @param utilities Numeric vector of utilities
#'
#' @return Integer vector of ranks
#' @keywords internal
rank_utilities <- function(utilities) {
  if (length(utilities) == 0) return(integer(0))

  # Higher utility = lower rank (rank 1 = best)
  rank(-utilities, ties.method = "min", na.last = "keep")
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff utils module loaded (v%s)", MAXDIFF_UTILS_VERSION))
