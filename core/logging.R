# ==============================================================================
# TURAS CORE - LOGGING
# ==============================================================================
# Error logging and issue tracking system
# Migrated from shared_functions.r V9.9.1
# ==============================================================================

#' Create empty error log data frame
#'
#' STRUCTURE: Timestamp, Component, Issue_Type, Description, QuestionCode, Severity
#' USAGE: Initialize at start of analysis, populate during validation
#'
#' @return Empty error log data frame
#' @export
#' @examples
#' error_log <- create_error_log()
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

#' Log an issue to error log
#'
#' SEVERITY LEVELS:
#'   - "Error": Prevents analysis from running (missing data, invalid config)
#'   - "Warning": Analysis can proceed but results may be affected
#'   - "Info": Informational messages (not actual problems)
#'
#' PERFORMANCE NOTE: O(n) per call due to rbind
#'   For logging 100+ entries, use list accumulation pattern:
#'   issues <- list()
#'   issues[[1]] <- data.frame(Timestamp = ..., Component = ..., ...)
#'   issues[[2]] <- data.frame(Timestamp = ..., Component = ..., ...)
#'   error_log <- do.call(rbind, issues)
#'
#' @param error_log Data frame, error log to append to
#' @param component Character, component where issue occurred
#' @param issue_type Character, type of issue
#' @param description Character, issue description
#' @param question_code Character, related question code (default: "")
#' @param severity Character, severity level (default: "Warning")
#' @return Data frame, updated error log
#' @export
#' @examples
#' error_log <- create_error_log()
#' error_log <- log_issue(error_log, "Validation", "Missing Column",
#'                        "Column Q1 not found", "Q1", "Error")
log_issue <- function(error_log, 
                      component, 
                      issue_type, 
                      description, 
                      question_code = "", 
                      severity = "Warning") {
  # Create new entry
  new_entry <- data.frame(
    Timestamp = as.character(Sys.time()),
    Component = component,
    Issue_Type = issue_type,
    Description = description,
    QuestionCode = question_code,
    Severity = severity,
    stringsAsFactors = FALSE
  )
  
  # Append to log
  rbind(error_log, new_entry)
}

# Success message
cat("Turas logging loaded\n")

# ==============================================================================
# ADD THESE FUNCTIONS TO: core/logging.R
# ==============================================================================
# Instructions:
# 1. Open ~/Documents/Turas/core/logging.R
# 2. Scroll to the BOTTOM of the file
# 3. Copy and paste ALL the code below
# 4. Save the file (Cmd+S or Ctrl+S)
# ==============================================================================

#' Log a message with timestamp
#'
#' General-purpose logging function for progress tracking and debugging.
#' Provides formatted output with timestamp and severity level.
#'
#' USAGE: Call during processing to track execution
#' DESIGN: Simple console output, can be extended to file logging
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
#' Displays a progress bar with percentage complete and estimated time remaining.
#' Updates in place using carriage return for clean console output.
#'
#' USAGE: Call inside loops to show progress
#' DESIGN: Uses \r for in-place updates, prints newline when complete
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
  
  # Print newline when complete
  if (current == total) cat("\n")
  invisible(NULL)
}

#' Format seconds into readable time string
#'
#' Converts seconds to human-readable format (seconds, minutes, or hours).
#'
#' USAGE: Helper for log_progress() ETA display
#' DESIGN: Automatic unit selection based on magnitude
#'
#' @param seconds Numeric, number of seconds
#' @return Character, formatted time (e.g., "45s", "2.3m", "1.5h")
#' @export
#' @examples
#' format_seconds(45)    # "45s"
#' format_seconds(125)   # "2.1m"
#' format_seconds(7200)  # "2.0h"
format_seconds <- function(seconds) {
  if (seconds < 60) {
    return(sprintf("%.0fs", seconds))
  } else if (seconds < 3600) {
    return(sprintf("%.1fm", seconds / 60))
  } else {
    return(sprintf("%.1fh", seconds / 3600))
  }
}

# Success message
cat("Turas logging extensions loaded\n")

