# ==============================================================================
# TURAS FINAL BANNER (TRS v1.0)
# ==============================================================================
#
# Prints standardized final banners for module completion.
# Ensures consistent UX across all Turas modules.
#
# USAGE:
#   rr <- turas_run_state_result(state)
#   turas_print_final_banner(rr)
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


#' Print Final TRS Banner
#'
#' Prints a standardized completion banner based on run status.
#' Use at the end of every module's main execution.
#'
#' @param run_result List. Result from turas_run_state_result()
#' @return TRUE invisibly
#' @export
turas_print_final_banner <- function(run_result) {

  status <- run_result$status %||% "UNKNOWN"
  module <- run_result$module %||% "TURAS"
  duration <- run_result$duration_seconds

  divider <- paste0(rep("=", 80), collapse = "")

  # Duration string
  dur_str <- if (!is.null(duration)) {
    sprintf(" (%.1f seconds)", duration)
  } else {
    ""
  }

  message(divider)

  if (status == "PASS") {
    message(sprintf("[TRS PASS] %s - ANALYSIS COMPLETED SUCCESSFULLY%s", module, dur_str))
  } else if (status == "PARTIAL") {
    n_events <- length(run_result$events)
    message(sprintf("[TRS PARTIAL] %s - ANALYSIS COMPLETED WITH %d EVENT(S)%s",
                    module, n_events, dur_str))
    message("  See Run_Status sheet in output for details.")
  } else if (status == "REFUSE") {
    message(sprintf("[TRS REFUSE] %s - ANALYSIS REFUSED%s", module, dur_str))
    message("  Check console output above for refusal details.")
  } else {
    message(sprintf("[TRS %s] %s - ANALYSIS DID NOT COMPLETE NORMALLY%s",
                    status, module, dur_str))
    message("  Check console output for details.")
  }

  message(divider)

  invisible(TRUE)
}


#' Print TRS Start Banner
#'
#' Prints a standardized start banner for module execution.
#' Use at the beginning of every module's main execution.
#'
#' @param module Character. Module name
#' @param version Character. Module version (optional)
#' @return TRUE invisibly
#' @export
turas_print_start_banner <- function(module, version = NULL) {

  divider <- paste0(rep("=", 80), collapse = "")

  ver_str <- if (!is.null(version)) sprintf(" v%s", version) else ""

  message(divider)
  message(sprintf("  TURAS %s%s - Starting Analysis", toupper(module), ver_str))
  message(sprintf("  Started: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  message(divider)

  invisible(TRUE)
}


#' Print TRS Event Summary
#'
#' Prints a summary of events from a run state result.
#' Useful for verbose output before the final banner.
#'
#' @param run_result List. Result from turas_run_state_result()
#' @return TRUE invisibly
#' @export
turas_print_event_summary <- function(run_result) {

  if (length(run_result$events) == 0) {
    return(invisible(TRUE))
  }

  message("\n--- TRS Event Summary ---")

  for (i in seq_along(run_result$events)) {
    ev <- run_result$events[[i]]
    message(sprintf("  %d. [%s] %s (%s)",
                    i,
                    ev$level %||% "?",
                    ev$title %||% "Untitled",
                    ev$code %||% "NO_CODE"))
  }

  message("")

  invisible(TRUE)
}


#' Null coalesce operator (if not already defined)
#' @keywords internal
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
}
