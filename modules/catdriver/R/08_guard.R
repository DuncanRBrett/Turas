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
#' not like a crash or error. Uses a custom condition class.
#'
#' @param title Short title for refusal reason
#' @param problem Description of the problem
#' @param why_it_matters Why this is a problem
#' @param fix How to fix it
#' @param details Optional additional details
#' @keywords internal
catdriver_refuse <- function(title, problem, why_it_matters, fix, details = NULL) {

  msg <- paste0(
    "\n",
    "================================================================================\n",
    "  CATDRIVER REFUSED TO RUN\n",
    "================================================================================\n",
    "  ", title, "\n",
    "================================================================================\n\n",
    "PROBLEM:\n",
    "  ", problem, "\n\n",
    "WHY THIS MATTERS:\n",
    "  ", why_it_matters, "\n\n",
    "HOW TO FIX:\n",
    "  ", fix, "\n"
  )

  if (!is.null(details)) {
    msg <- paste0(msg, "\nDETAILS:\n  ", details, "\n")
  }

  msg <- paste0(msg,
    "\n================================================================================\n"
  )

  # Create a custom condition so it can be caught/handled specially
  cond <- structure(
    list(message = msg, call = NULL),
    class = c("catdriver_refusal", "error", "condition")
  )

  stop(cond)
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
