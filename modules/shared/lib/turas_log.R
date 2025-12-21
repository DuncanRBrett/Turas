# ==============================================================================
# TURAS UNIFIED LOGGING HELPER (TRS v1.0)
# ==============================================================================
#
# Provides a unified logging interface for all Turas modules.
# Replaces ad-hoc mix of message(), cat(), and warning() calls.
#
# USAGE:
#   turas_log("INFO", "MODULE", "Operation completed successfully")
#   turas_log("PARTIAL", "SEGMENT", "Missing values imputed", code = "SEG_IMPUTE")
#   turas_log("REFUSE", "CONJOINT", "Required column missing", code = "CONJ_MISSING_COL")
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


#' Unified Logging Function for Turas Modules
#'
#' Logs messages to console in a standardized TRS format.
#'
#' @param level Character. Log level: "INFO", "PARTIAL", "REFUSE", "DEBUG"
#' @param module Character. Module name (e.g., "SEGMENT", "CONJOINT", "PRICING")
#' @param message Character. Log message
#' @param code Character. Optional TRS event code (e.g., "SEG_IMPUTE")
#' @param detail Character. Optional additional detail
#' @param verbose Logical. If FALSE, only logs PARTIAL and REFUSE (default TRUE)
#' @param to_console Logical. Print to console (default TRUE)
#' @param to_message Logical. Also send to R's message() (default FALSE)
#'
#' @return Invisibly returns the formatted log string
#' @export
#'
#' @examples
#' turas_log("INFO", "SEGMENT", "Starting analysis")
#' turas_log("PARTIAL", "SEGMENT", "Missing values detected", code = "SEG_MISSING")
turas_log <- function(level = "INFO",
                      module = "",
                      message = "",
                      code = NULL,
                      detail = NULL,
                      verbose = TRUE,
                      to_console = TRUE,
                      to_message = FALSE) {

  # Validate level
  valid_levels <- c("INFO", "PARTIAL", "REFUSE", "DEBUG", "WARN", "ERROR")
  level <- toupper(level)
  if (!level %in% valid_levels) {
    level <- "INFO"
  }

  # Map WARN to PARTIAL, ERROR to REFUSE for TRS consistency
  if (level == "WARN") level <- "PARTIAL"
  if (level == "ERROR") level <- "REFUSE"

  # Skip DEBUG and INFO if not verbose
  if (!verbose && level %in% c("DEBUG", "INFO")) {
    return(invisible(""))
  }

  # Build the log message in TRS format
  # Format: [TRS LEVEL] MODULE_CODE: message (detail)
  if (!is.null(code) && nzchar(code)) {
    log_prefix <- sprintf("[TRS %s] %s: ", level, code)
  } else if (nzchar(module)) {
    log_prefix <- sprintf("[TRS %s] %s: ", level, module)
  } else {
    log_prefix <- sprintf("[TRS %s] ", level)
  }

  log_str <- paste0(log_prefix, message)

  # Add detail if provided
  if (!is.null(detail) && nzchar(detail)) {
    log_str <- paste0(log_str, " (", detail, ")")
  }

  # Output to console
  if (to_console) {
    # Use cat for consistent formatting
    cat(log_str, "\n", sep = "")
  }

  # Also send to message() if requested (for capture by tryCatch etc)
  if (to_message) {
    message(log_str)
  }

  invisible(log_str)
}


#' Log INFO Message
#' @param module Module name
#' @param message Log message
#' @param ... Additional arguments passed to turas_log
#' @export
turas_log_info <- function(module, message, ...) {
  turas_log("INFO", module, message, ...)
}


#' Log PARTIAL Message (Degraded Output)
#' @param module Module name
#' @param message Log message
#' @param code Optional TRS code
#' @param ... Additional arguments passed to turas_log
#' @export
turas_log_partial <- function(module, message, code = NULL, ...) {
  turas_log("PARTIAL", module, message, code = code, ...)
}


#' Log REFUSE Message (Fatal Error)
#' @param module Module name
#' @param message Log message
#' @param code Optional TRS code
#' @param ... Additional arguments passed to turas_log
#' @export
turas_log_refuse <- function(module, message, code = NULL, ...) {
  turas_log("REFUSE", module, message, code = code, ...)
}


#' Log DEBUG Message
#' @param module Module name
#' @param message Log message
#' @param ... Additional arguments passed to turas_log
#' @export
turas_log_debug <- function(module, message, ...) {
  turas_log("DEBUG", module, message, ...)
}


#' Print Progress Step
#'
#' Convenience function for printing progress steps in a consistent format.
#'
#' @param step_num Step number
#' @param description Step description
#' @param module Module name (optional)
#' @export
turas_step <- function(step_num, description, module = NULL) {
  if (!is.null(module)) {
    cat(sprintf("[%s] STEP %d: %s\n", module, step_num, description))
  } else {
    cat(sprintf("STEP %d: %s\n", step_num, description))
  }
}


#' Print Sub-step Message
#'
#' @param message Message to print
#' @param indent Number of spaces to indent (default 3)
#' @export
turas_substep <- function(message, indent = 3) {
  cat(sprintf("%s%s\n", strrep(" ", indent), message))
}


#' Print Success Message
#'
#' @param message Success message
#' @export
turas_success <- function(message) {
  cat(sprintf("   %s %s\n", "\U2713", message))  # Unicode checkmark
}


#' Print Warning in Turas Style
#'
#' @param message Warning message
#' @export
turas_warn <- function(message) {
  cat(sprintf("   ! %s\n", message))
}


# ==============================================================================
# MODULE INITIALIZATION MESSAGE
# ==============================================================================

# Only show initialization if being sourced interactively
if (interactive()) {
  message("[TRS INFO] Turas unified logging helper loaded (turas_log v1.0)")
}
