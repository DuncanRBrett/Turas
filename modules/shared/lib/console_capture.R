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


  # Storage for warnings and messages
  warnings_list <- character(0)
  messages_list <- character(0)
  error_condition <- NULL
  result <- NULL

# Capture stdout
  output <- capture.output({

    # Set up warning handler to collect warnings
    result <<- withCallingHandlers(
      tryCatch(
        expr,
        error = function(e) {
          error_condition <<- e
          NULL
        }
      ),
      warning = function(w) {
        warnings_list <<- c(warnings_list, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        messages_list <<- c(messages_list, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )

  }, type = "output")

  # Build combined output that shows everything
  combined_output <- character(0)

  # Add messages first (informational)
  if (length(messages_list) > 0) {
    for (msg in messages_list) {
      combined_output <- c(combined_output, msg)
    }
  }

  # Add stdout output
  if (length(output) > 0) {
    combined_output <- c(combined_output, output)
  }

  # Add warnings prominently
  if (length(warnings_list) > 0) {
    combined_output <- c(combined_output, "")
    combined_output <- c(combined_output, "--- WARNINGS ---")
    for (w in warnings_list) {
      combined_output <- c(combined_output, paste0("Warning: ", w))
    }
  }

  # Add error if one occurred
  if (!is.null(error_condition)) {
    combined_output <- c(combined_output, "")
    combined_output <- c(combined_output, "--- ERROR ---")
    combined_output <- c(combined_output, conditionMessage(error_condition))
  }

  list(
    result = result,
    output = output,
    combined_output = combined_output,
    warnings = warnings_list,
    messages = messages_list,
    error = error_condition,
    has_warnings = length(warnings_list) > 0,
    has_error = !is.null(error_condition)
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
