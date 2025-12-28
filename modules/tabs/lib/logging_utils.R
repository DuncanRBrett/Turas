# ==============================================================================
# LOGGING UTILITIES - TURAS V10.0
# ==============================================================================
# Logging and monitoring utilities
# Extracted from shared_functions.R for better modularity
#
# VERSION HISTORY:
# V10.0 - Extracted from shared_functions.R (2025)
#        - Modular design for better maintainability
#        - Updated memory monitoring to use lobstr instead of pryr
# ==============================================================================

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

#' Log message with timestamp
#'
#' USAGE: Log informational messages during processing
#' DESIGN: Simple timestamp + level + message format
#'
#' @param msg Character, message to log
#' @param level Character, log level (INFO, WARNING, ERROR)
#' @param verbose Logical, whether to print (default: TRUE)
#' @return Invisible NULL
#' @export
#' @examples
#' log_message("Starting analysis", "INFO")
#' log_message("Missing data detected", "WARNING")
log_message <- function(msg, level = "INFO", verbose = TRUE) {
  if (!verbose) return(invisible(NULL))

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] %s: %s\n", timestamp, level, msg))
  invisible(NULL)
}


#' Log progress with percentage and ETA
#'
#' USAGE: Show progress during long-running operations
#' DESIGN: Inline progress with carriage return for updating same line
#'
#' @param current Integer, current item number
#' @param total Integer, total items
#' @param item Character, item description (default: "")
#' @param start_time POSIXct, when processing started (for ETA calculation)
#' @return Invisible NULL
#' @export
#' @examples
#' start <- Sys.time()
#' for (i in 1:100) {
#'   log_progress(i, 100, "Processing questions", start)
#'   Sys.sleep(0.1)
#' }
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
#' USAGE: Convert seconds to human-readable format
#' DESIGN: Automatically chooses appropriate unit (s/m/h)
#'
#' @param seconds Numeric, seconds to format
#' @return Character, formatted time string
#' @export
#' @examples
#' format_seconds(45)      # "45s"
#' format_seconds(90)      # "1.5m"
#' format_seconds(7200)    # "2.0h"
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
# ERROR LOG MANAGEMENT
# ==============================================================================

#' Add entry to error log (V10.0: Renamed from log_issue for clarity)
#'
#' USAGE: Accumulate errors and warnings during batch processing
#' DESIGN: Returns modified log - caller MUST capture the result
#' BEST PRACTICE: For many issues, use list accumulation then rbind
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


# ==============================================================================
# MEMORY MONITORING
# ==============================================================================

#' Check and warn about memory usage
#'
#' USAGE: Monitor memory during long-running operations
#' DESIGN: Warns at configurable thresholds, optionally forces GC
#' V10.0: Updated to use lobstr instead of deprecated pryr package
#'
#' Memory reported in GiB (1024^3 bytes) to match OS conventions
#'
#' @param force_gc Logical, force garbage collection if high (default: TRUE)
#' @param warning_threshold Numeric, warning threshold in GiB (default: 6)
#' @param critical_threshold Numeric, critical threshold in GiB (default: 8)
#' @return Invisible NULL
#' @export
#' @examples
#' # Check memory and warn if high
#' check_memory()
#'
#' # With custom thresholds
#' check_memory(warning_threshold = 4, critical_threshold = 6)
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
