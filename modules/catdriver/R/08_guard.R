# ==============================================================================
# CATEGORICAL KEY DRIVER - TURASGUARD LAYER
# ==============================================================================
#
# Core validation and error enforcement framework.
# Implements "no silent failures" philosophy.
#
# Related modules:
#   - 08a_guards_hard.R: Hard error guards (require functions)
#   - 08b_guards_soft.R: Soft warning guards (check functions)
#
# Version: 2.0
# Date: December 2024
#
# ==============================================================================

# ==============================================================================
# REFUSAL MECHANISM (intentional, not crash)
# ==============================================================================

#' Refuse to Run with Clear Message
#'
#' Produces a clear "REFUSED TO RUN" message that looks intentional,
#' not like a crash or error. Uses a custom condition class that can
#' be caught at the top level for clean display.
#'
#' @param reason Short code for refusal reason (for programmatic handling)
#' @param message Detailed message explaining the refusal
#' @param title Optional custom title (defaults to reason)
#' @param problem Optional problem description (alternative interface)
#' @param why_it_matters Optional explanation (alternative interface)
#' @param fix Optional fix instructions (alternative interface)
#' @param details Optional additional details
#' @keywords internal
catdriver_refuse <- function(reason = NULL, message = NULL,
                             title = NULL, problem = NULL,
                             why_it_matters = NULL, fix = NULL,
                             details = NULL) {

  # Support both interfaces:
  # 1. Simple: reason + message
  # 2. Structured: title + problem + why_it_matters + fix

  if (!is.null(message)) {
    # Simple interface
    display_title <- if (!is.null(title)) title else if (!is.null(reason)) reason else "Analysis Refused"

    msg <- paste0(
      "\n",
      "================================================================================\n",
      "  CATDRIVER REFUSED TO RUN\n",
      "================================================================================\n",
      "  ", display_title, "\n",
      "================================================================================\n\n",
      message, "\n",
      "\n================================================================================\n"
    )

  } else if (!is.null(problem)) {
    # Structured interface
    display_title <- if (!is.null(title)) title else "Analysis Refused"

    msg <- paste0(
      "\n",
      "================================================================================\n",
      "  CATDRIVER REFUSED TO RUN\n",
      "================================================================================\n",
      "  ", display_title, "\n",
      "================================================================================\n\n",
      "PROBLEM:\n",
      "  ", problem, "\n\n"
    )

    if (!is.null(why_it_matters)) {
      msg <- paste0(msg, "WHY THIS MATTERS:\n  ", why_it_matters, "\n\n")
    }

    if (!is.null(fix)) {
      msg <- paste0(msg, "HOW TO FIX:\n  ", fix, "\n")
    }

    if (!is.null(details)) {
      msg <- paste0(msg, "\nDETAILS:\n  ", details, "\n")
    }

    msg <- paste0(msg, "\n================================================================================\n")

  } else {
    msg <- paste0(
      "\n",
      "================================================================================\n",
      "  CATDRIVER REFUSED TO RUN\n",
      "================================================================================\n",
      "  No details provided\n",
      "================================================================================\n"
    )
  }

  # Create a custom condition so it can be caught/handled specially
  cond <- structure(
    list(
      message = msg,
      reason = reason,
      call = NULL
    ),
    class = c("catdriver_refusal", "error", "condition")
  )

  stop(cond)
}


#' Run Analysis with Top-Level Refusal Handler
#'
#' Wraps the main analysis function to catch catdriver_refusal conditions
#' and display them cleanly without a stack trace.
#'
#' @param expr Expression to evaluate (typically run_categorical_keydriver call)
#' @return Result of expression, or NULL if refused
#' @export
with_refusal_handler <- function(expr) {
  tryCatch(
    expr,
    catdriver_refusal = function(e) {
      # Print the refusal message cleanly (no Error: prefix, no stack trace)
      cat(conditionMessage(e))

      # Return invisible NULL to indicate refusal
      invisible(structure(
        list(
          refused = TRUE,
          reason = e$reason,
          message = conditionMessage(e)
        ),
        class = "catdriver_refusal_result"
      ))
    }
  )
}


#' Check if Result was a Refusal
#'
#' @param result Result from with_refusal_handler()
#' @return TRUE if analysis was refused
#' @export
is_refusal <- function(result) {
  inherits(result, "catdriver_refusal_result") && isTRUE(result$refused)
}


# ==============================================================================
# GUARD STATE TRACKING
# ==============================================================================

#' Initialize Guard State
#'
#' Creates a new guard state object to track warnings and issues.
#'
#' @return Guard state list
#' @export
guard_init <- function() {
  list(
    warnings = character(0),
    soft_failures = list(),
    fallback_used = FALSE,
    fallback_reason = NULL,
    stability_flags = character(0),
    collapsed_levels = list(),
    dropped_predictors = character(0),
    missing_handled = list()
  )
}


#' Add Warning to Guard State
#'
#' @param guard Guard state object
#' @param message Warning message
#' @param category Warning category
#' @return Updated guard state
#' @keywords internal
guard_warn <- function(guard, message, category = "general") {
  guard$warnings <- c(guard$warnings, message)
  guard$soft_failures[[category]] <- c(guard$soft_failures[[category]], message)
  guard
}


#' Add Stability Flag
#'
#' @param guard Guard state object
#' @param flag Stability flag text
#' @return Updated guard state
#' @keywords internal
guard_flag_stability <- function(guard, flag) {
  guard$stability_flags <- unique(c(guard$stability_flags, flag))
  guard
}


#' Get Guard Summary for Output
#'
#' Creates summary of all warnings and flags for output.
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
guard_summary <- function(guard) {
  has_issues <- length(guard$warnings) > 0 ||
                length(guard$stability_flags) > 0 ||
                guard$fallback_used

  list(
    has_issues = has_issues,
    n_warnings = length(guard$warnings),
    warnings = guard$warnings,
    stability_flags = guard$stability_flags,
    fallback_used = guard$fallback_used,
    fallback_reason = guard$fallback_reason,
    use_with_caution = length(guard$stability_flags) > 0
  )
}
