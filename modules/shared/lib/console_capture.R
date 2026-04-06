# ==============================================================================
# TURAS SHARED: CONSOLE CAPTURE FOR SHINY GUIS
# ==============================================================================
#
# Purpose: Capture ALL console output (stdout, warnings, messages) for display
#          in Shiny GUI console panels. This ensures TRS compliance by
#          guaranteeing no silent failures in GUI mode.
#
# Version: TRS v1.0
# Date: 2025-12
#
# ==============================================================================

#' Capture All Console Output (stdout, warnings, messages)
#'
#' This function captures ALL output types to ensure nothing is silently lost
#' when running in Shiny GUI mode. This is critical for TRS compliance - users
#' must see all warnings and error messages in the GUI console.
#'
#' @param expr Expression to evaluate
#' @return List with:
#'   - result: The return value of the expression (or NULL if error)
#'   - output: Character vector of all captured output lines
#'   - warnings: Character vector of warning messages
#'   - messages: Character vector of informational messages
#'   - error: Error condition if one occurred (or NULL)
#'
#' @examples
#' \dontrun{
#' captured <- capture_console_all({
#'   message("Starting analysis...")
#'   warning("Low sample size")
#'   cat("Processing complete\n")
#'   42
#' })
#' # captured$result == 42
#' # captured$output contains "Processing complete"
#' # captured$warnings contains "Low sample size"
#' # captured$messages contains "Starting analysis..."
#' }
#'
#' @export
capture_console_all <- function(expr) {

  # Use an explicit environment for handler state — avoids <<- and makes
  # the scope of mutations unambiguous.
  state <- new.env(parent = emptyenv())
  state$warnings <- character(0)
  state$messages <- character(0)
  state$error <- NULL
  state$result <- NULL

  # Capture stdout
  output <- capture.output({
    state$result <- withCallingHandlers(
      tryCatch(
        expr,
        error = function(e) {
          state$error <- e
          NULL
        }
      ),
      warning = function(w) {
        state$warnings <- c(state$warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        state$messages <- c(state$messages, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
  }, type = "output")

  # Build combined output — collect parts then concatenate once (avoids O(n^2) growth)
  parts <- list()
  if (length(state$messages) > 0)  parts <- c(parts, list(state$messages))
  if (length(output) > 0)          parts <- c(parts, list(output))
  if (length(state$warnings) > 0) {
    parts <- c(parts, list(c("", "--- WARNINGS ---", paste0("Warning: ", state$warnings))))
  }
  if (!is.null(state$error)) {
    parts <- c(parts, list(c("", "--- ERROR ---", conditionMessage(state$error))))
  }
  combined_output <- unlist(parts, use.names = FALSE)
  if (is.null(combined_output)) combined_output <- character(0)

  list(
    result = state$result,
    output = output,
    combined_output = combined_output,
    warnings = state$warnings,
    messages = state$messages,
    error = state$error,
    has_warnings = length(state$warnings) > 0,
    has_error = !is.null(state$error)
  )
}


#' Format Captured Output for Shiny Console Display
#'
#' Converts captured output to a single string suitable for Shiny text output.
#'
#' @param captured Result from capture_console_all()
#' @return Single character string with all output
#'
#' @export
format_console_output <- function(captured) {
  paste(captured$combined_output, collapse = "\n")
}


#' Run Analysis with Full Console Capture for Shiny
#'
#' Convenience wrapper that runs an analysis expression and returns
#' formatted output ready for Shiny GUI display.
#'
#' @param expr Expression to evaluate
#' @param output_var Shiny output variable to update (optional)
#' @return The result of the expression
#'
#' @export
run_with_console_capture <- function(expr, output_var = NULL) {
  captured <- capture_console_all(expr)

  # If output_var provided, update it
  if (!is.null(output_var)) {
    output_var(format_console_output(captured))
  }

  # Return the result (may be NULL if error)
  captured$result
}
