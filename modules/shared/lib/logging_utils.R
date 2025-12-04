# ==============================================================================
# LOGGING UTILITIES
# ==============================================================================
# Logging, progress tracking, and error tracking utilities
# Extracted from shared_functions.R Turas v10.0
# Part of Turas shared module infrastructure
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
#' @export
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

#' Log an issue to error log
#'
#' SEVERITY LEVELS:
#'   - "Error": Prevents analysis from running (missing data, invalid config)
#'   - "Warning": Analysis can proceed but results may be affected
#'   - "Info": Informational messages (not actual problems)
#'
#' PERFORMANCE: For logging 100+ entries:
#'   - Better pattern: Accumulate issues in a list
#'   - Then: error_log <- do.call(rbind, list_of_issues)
#'
#' @param error_log Data frame, error log to append to
#' @param component Character, component where issue occurred
#' @param issue_type Character, type of issue
#' @param description Character, issue description
#' @param question_code Character, related question code (default: "")
#' @param severity Character, severity level (default: "Warning")
#' @return Data frame, updated error log
#' @export
log_issue <- function(error_log, component, issue_type, description,
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

#' Print toolkit header
#'
#' USAGE: Display at start of analysis scripts for branding
#'
#' @param analysis_type Character, type of analysis being run
#' @param version Character, version string (default: "1.0")
#' @export
print_toolkit_header <- function(analysis_type = "Analysis", version = "1.0") {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("  TURAS ANALYTICS TOOLKIT V", version, "\n", sep = "")
  cat("  ", analysis_type, "\n", sep = "")
  cat(paste(rep("=", 80), collapse = ""), "\n", sep = "")
  cat("\n")
}
