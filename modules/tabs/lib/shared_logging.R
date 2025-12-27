# ==============================================================================
# SHARED LOGGING FUNCTIONS - TURAS V10.0
# ==============================================================================
# Extracted from shared_functions.R for better maintainability
# Provides logging, progress tracking, and error recording utilities
#
# CONTENTS:
# - Log messages with timestamps and levels
# - Progress tracking with ETA
# - Time formatting
# - Memory monitoring
# - Error log creation and management
# - Toolkit versioning and branding
#
# DESIGN PRINCIPLES:
# - Structured logging for analysis tracking
# - Performance monitoring capabilities
# - Pure function design for log accumulation
# ==============================================================================

#' Log message with timestamp and level
#'
#' @param msg Character, message to log
#' @param level Character, log level (INFO, WARNING, ERROR, DEBUG)
#' @param verbose Logical, whether to display
#' @return Invisible NULL
#' @export
log_message <- function(msg, level = "INFO", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s: %s\n", timestamp, level, msg))
  invisible(NULL)
}

#' Log progress with percentage and ETA
#'
#' @param current Integer, current item
#' @param total Integer, total items
#' @param item Character, item description
#' @param start_time POSIXct, when processing started
#' @return Invisible NULL
log_progress <- function(current, total, item = "", start_time = NULL) {
  pct <- round(100 * current / total, 1)

  eta_str <- ""
  if (!is.null(start_time) && current > 0) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    rate <- elapsed / current
    remaining <- (total - current) * rate
    eta_str <- sprintf(" | ETA: %s", format_seconds(remaining))
  }

  cat(sprintf("\r[%3d%%] %d/%d%s %s",
             round(pct), current, total, eta_str, item))

  if (current == total) cat("\n")
  invisible(NULL)
}

#' Format seconds into readable time
#'
#' @param seconds Numeric, seconds
#' @return Character, formatted time
format_seconds <- function(seconds) {
  if (seconds < 60) {
    return(sprintf("%.0fs", seconds))
  } else if (seconds < 3600) {
    return(sprintf("%.1fm", seconds / 60))
  } else {
    return(sprintf("%.1fh", seconds / 3600))
  }
}

#' Check and warn about memory usage
#'
#' Memory reported in GiB (1024^3 bytes) to match OS conventions
#' NOTE: Requires MEMORY_WARNING_GIB and MEMORY_CRITICAL_GIB constants from caller
#' V10.0: Updated to use lobstr instead of deprecated pryr package
#'
#' @param force_gc Logical, force garbage collection if high
#' @param warning_threshold Numeric, warning threshold in GiB (default 6)
#' @param critical_threshold Numeric, critical threshold in GiB (default 8)
#' @return Invisible NULL
check_memory <- function(force_gc = TRUE, warning_threshold = 6, critical_threshold = 8) {
  if (!requireNamespace("lobstr", quietly = TRUE)) return(invisible(NULL))

  mem_used_bytes <- lobstr::obj_size(environment())
  mem_used_gib <- as.numeric(mem_used_bytes) / (1024^3)

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

#' Create empty error log data frame
#'
#' STRUCTURE: Timestamp, Component, Issue_Type, Description, QuestionCode, Severity
#' USAGE: Initialize at start of analysis, populate during validation
#'
#' @return Empty error log data frame
#' @export
create_error_log <- function() {
  data.frame(
    Timestamp = character(),
    Component = character(),
    Issue_Type = character(),
    Description = character(),
    QuestionCode = character(),
    Severity = character(),
    stringsAsFactors = FALSE
  )
}

#' Add Log Entry (Pure Function - MUST Capture Return Value)
#'
#' Adds an entry to the error/warning log. This is a PURE FUNCTION that
#' returns a new data frame. You MUST capture the return value.
#'
#' V10.0: Renamed from log_issue() for clarity. The old name suggested a
#' side-effect function, but this is actually a pure function that returns
#' a modified copy.
#'
#' SEVERITY LEVELS:
#'   - "Error": Prevents analysis from running (missing data, invalid config)
#'   - "Warning": Analysis can proceed but results may be affected
#'   - "Info": Informational messages (not actual problems)
#'
#' PERFORMANCE: O(n) per call due to rbind. For logging 100+ entries:
#'   - Better pattern: Accumulate issues in a list
#'   - Then: error_log <- do.call(rbind, list_of_issues)
#'   - Reduces from O(n²) to O(n)
#'
#' @usage error_log <- add_log_entry(error_log, "ERROR", "Q01", "Message")
#'
#' @param error_log Data frame, error log to append to
#' @param component Character, component where issue occurred
#' @param issue_type Character, type of issue
#' @param description Character, issue description
#' @param question_code Character, related question code (default: "")
#' @param severity Character, severity level (default: "Warning")
#' @return Data frame with new log entry appended (MUST BE CAPTURED)
#' @export
#' @examples
#' # CORRECT usage - assign the result:
#' error_log <- add_log_entry(error_log, "Validation", "Missing Column",
#'                           "Column Q1 not found", "Q1", "Error")
#'
#' # INCORRECT - will not work (issue not logged):
#' # add_log_entry(error_log, "Validation", "Missing Column", "Column Q1 not found")
#'
#' # For many issues, use list accumulation:
#' issues <- list()
#' issues[[1]] <- data.frame(Timestamp = ..., Component = ..., ...)
#' issues[[2]] <- data.frame(Timestamp = ..., Component = ..., ...)
#' error_log <- do.call(rbind, issues)
add_log_entry <- function(error_log, component, issue_type, description,
                         question_code = "", severity = "Warning") {
  new_entry <- data.frame(
    Timestamp = as.character(Sys.time()),
    Component = component,
    Issue_Type = issue_type,
    Description = description,
    QuestionCode = question_code,
    Severity = severity,
    stringsAsFactors = FALSE
  )

  rbind(error_log, new_entry)
}

# Backward compatibility alias (V10.0)
# Keep log_issue as an alias so existing code continues to work
log_issue <- add_log_entry

#' Get toolkit version
#'
#' @return Character, version string
#' @export
get_toolkit_version <- function() {
  # Try to get version from parent environment
  version <- tryCatch(
    get("SCRIPT_VERSION", envir = .GlobalEnv),
    error = function(e) "10.0"
  )
  return(version)
}

#' Print toolkit header
#'
#' USAGE: Display at start of analysis scripts for branding
#'
#' @param analysis_type Character, type of analysis being run
#' @export
print_toolkit_header <- function(analysis_type = "Analysis") {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("  R SURVEY ANALYTICS TOOLKIT V", get_toolkit_version(), "\n", sep = "")
  cat("  ", analysis_type, "\n", sep = "")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("\n")
}

# ==============================================================================
# END OF SHARED_LOGGING.R
# ==============================================================================
