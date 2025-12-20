# ==============================================================================
# CATEGORICAL KEY DRIVER - TURASGUARD LAYER
# ==============================================================================
#
# Core validation and error enforcement framework.
# Implements "no silent failures" philosophy per TRS v1.0.
#
# This module uses the shared TRS infrastructure from:
#   modules/shared/lib/trs_refusal.R
#
# Functions here are thin wrappers that delegate to the shared TRS
# implementation while maintaining CatDriver-specific naming for
# backwards compatibility.
#
# Related modules:
#   - 08a_guards_hard.R: Hard error guards (require functions)
#   - 08b_guards_soft.R: Soft warning guards (check functions)
#
# Version: 1.1 (TRS Hardening)
# Compliance: TURAS_Categorical_Key_Driver_Hardening_v1.1.md
# Date: December 2024
#
# ==============================================================================

# NOTE: Shared TRS infrastructure is loaded via import_all.R which sources
# trs_refusal.R. The following shared functions are available:
#   - turas_refuse() - shared refusal function
#   - with_refusal_handler() - shared handler wrapper (NOTE: we override below)
#   - is_refusal() - shared refusal check (NOTE: we override below)
#   - guard_init(), guard_warn(), guard_flag_stability(), guard_summary()


# ==============================================================================
# CATDRIVER-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with Clear Message (CatDriver)
#'
#' CatDriver-specific wrapper around turas_refuse() that maintains
#' backwards compatibility with existing guard code.
#'
#' Produces a clear "REFUSED TO RUN" message that looks intentional,
#' not like a crash or error.
#'
#' @param reason Short code for refusal reason (must follow TRS prefix convention)
#' @param message Detailed message explaining the refusal (legacy interface)
#' @param title Short title for the refusal
#' @param problem One-sentence description of what went wrong
#' @param why_it_matters Explanation of analytical risk
#' @param fix Explicit step-by-step instructions to resolve
#' @param details Additional diagnostic details
#'
#' @keywords internal
catdriver_refuse <- function(reason = NULL, message = NULL,
                             title = NULL, problem = NULL,
                             why_it_matters = NULL, fix = NULL,
                             details = NULL) {

  # Ensure reason has valid TRS prefix, add CFG_ if missing
  if (!is.null(reason) && !grepl("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", reason)) {
    reason <- paste0("CFG_", reason)
  }
  if (is.null(reason)) {
    reason <- "CFG_CATDRIVER_ERROR"
  }

  # Handle legacy interface (reason + message only)
  if (!is.null(message) && is.null(problem)) {
    # Legacy call: convert message to structured format
    # why_it_matters is now MANDATORY per TRS governance
    turas_refuse(
      code = reason,
      title = if (!is.null(title)) title else gsub("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", "", reason),
      problem = message,
      why_it_matters = if (!is.null(why_it_matters)) why_it_matters else "This issue prevents the analysis from producing valid results.",
      how_to_fix = if (!is.null(fix)) fix else "Review the error message above and correct your configuration or data.",
      details = details,
      module = "CATDRIVER"
    )
  } else {
    # Structured interface: pass through to turas_refuse
    # why_it_matters is now MANDATORY per TRS governance
    turas_refuse(
      code = reason,
      title = if (!is.null(title)) title else gsub("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", "", reason),
      problem = if (!is.null(problem)) problem else "An error occurred in CatDriver analysis.",
      why_it_matters = if (!is.null(why_it_matters)) why_it_matters else "This issue prevents the analysis from producing valid results.",
      how_to_fix = if (!is.null(fix)) fix else "Review the error details and correct your configuration or data.",
      details = details,
      module = "CATDRIVER"
    )
  }
}


#' Run Analysis with Top-Level Refusal Handler
#'
#' Wraps the main analysis function to catch refusal conditions
#' and display them cleanly without a stack trace.
#'
#' This is the CatDriver override that ensures backwards compatibility
#' with code expecting catdriver_refusal_result class.
#'
#' @param expr Expression to evaluate (typically run_categorical_keydriver call)
#' @return Result of expression, or refusal result if refused
#' @export
with_refusal_handler <- function(expr) {
  # Use the shared TRS handler
  result <- tryCatch(
    expr,
    turas_refusal = function(e) {
      # Print the refusal message cleanly (no "Error:" prefix, no stack trace)
      cat(conditionMessage(e))

      # Return structured refusal result with both classes for compatibility
      invisible(structure(
        list(
          run_status = "REFUSE",
          refused = TRUE,
          code = e$code,
          reason = e$code,  # Backwards compat alias
          title = e$title,
          problem = e$problem,
          how_to_fix = e$how_to_fix,
          expected = e$expected,
          observed = e$observed,
          missing = e$missing,
          unmapped = e$unmapped,
          module = e$module,
          message = conditionMessage(e)
        ),
        class = c("catdriver_refusal_result", "turas_refusal_result")
      ))
    },
    error = function(e) {
      # Unexpected error - this is a BUG, not a refusal
      divider <- paste0(rep("=", 80), collapse = "")
      msg <- paste0(
        "\n", divider, "\n",
        "  [ERROR] BUG_INTERNAL_ERROR: Unexpected CatDriver Error\n",
        divider, "\n\n",
        "Problem:\n",
        "  An unexpected error occurred in CatDriver. This is a bug.\n\n",
        "Error message:\n",
        "  ", conditionMessage(e), "\n\n",
        "What to do:\n",
        "  1. Note down what you were doing when this happened\n",
        "  2. Report this error to the Turas development team\n",
        "  3. Include the full error message above\n\n",
        divider, "\n"
      )
      cat(msg)

      invisible(structure(
        list(
          run_status = "ERROR",
          refused = FALSE,
          error = TRUE,
          message = conditionMessage(e),
          module = "CATDRIVER"
        ),
        class = c("catdriver_error_result", "turas_error_result")
      ))
    }
  )

  result
}


#' Check if Result was a Refusal
#'
#' @param result Result from with_refusal_handler()
#' @return TRUE if analysis was refused
#' @export
is_refusal <- function(result) {
  # Check for both new TRS and legacy CatDriver result classes
  (inherits(result, "turas_refusal_result") || inherits(result, "catdriver_refusal_result")) &&
    isTRUE(result$refused)
}


# ==============================================================================
# GUARD STATE TRACKING
# ==============================================================================
# CatDriver uses the shared guard_init, guard_warn, guard_flag_stability,
# and guard_summary functions from trs_refusal.R but adds CatDriver-specific
# fields for tracking collapsed levels, dropped predictors, etc.

#' Initialize Guard State
#'
#' Creates a new guard state object to track warnings and issues.
#' Includes CatDriver-specific fields for collapsed levels and dropped predictors.
#'
#' @return Guard state list
#' @export
guard_init <- function() {
  # Start with base structure matching TRS shared implementation
  list(
    module = "CATDRIVER",
    warnings = character(0),
    soft_failures = list(),
    fallback_used = FALSE,
    fallback_reason = NULL,
    stability_flags = character(0),
    # CatDriver-specific fields
    collapsed_levels = list(),
    dropped_predictors = character(0),
    missing_handled = list(),
    separation_detected = FALSE,
    data_modifications = list(),
    timestamp = Sys.time()
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
                isTRUE(guard$fallback_used) ||
                length(guard$collapsed_levels) > 0 ||
                length(guard$dropped_predictors) > 0 ||
                isTRUE(guard$separation_detected)

  list(
    module = guard$module,
    has_issues = has_issues,
    n_warnings = length(guard$warnings),
    warnings = guard$warnings,
    stability_flags = guard$stability_flags,
    fallback_used = isTRUE(guard$fallback_used),
    fallback_reason = guard$fallback_reason,
    use_with_caution = length(guard$stability_flags) > 0,
    # CatDriver-specific
    collapsed_levels = guard$collapsed_levels,
    dropped_predictors = guard$dropped_predictors,
    separation_detected = isTRUE(guard$separation_detected),
    data_modifications = guard$data_modifications
  )
}


# ==============================================================================
# CATDRIVER-SPECIFIC GUARD EXTENSIONS
# ==============================================================================

#' Record Collapsed Levels
#'
#' Records when rare levels have been collapsed.
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param original_levels Original level names
#' @param collapsed_to Name of level they were collapsed to
#' @return Updated guard state
#' @keywords internal
guard_record_collapse <- function(guard, variable, original_levels, collapsed_to) {
  guard$collapsed_levels[[variable]] <- list(
    original = original_levels,
    collapsed_to = collapsed_to
  )
  guard <- guard_flag_stability(guard, paste0("Rare levels collapsed in ", variable))
  guard
}


#' Record Dropped Predictor
#'
#' Records when a predictor has been dropped from analysis.
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param reason Reason for dropping
#' @return Updated guard state
#' @keywords internal
guard_record_dropped <- function(guard, variable, reason) {
  guard$dropped_predictors <- c(guard$dropped_predictors, variable)
  guard <- guard_warn(guard, paste0("Dropped predictor: ", variable, " (", reason, ")"), "dropped")
  guard
}


#' Record Separation Detection
#'
#' Records when perfect/quasi separation was detected.
#'
#' @param guard Guard state object
#' @param details Details about the separation
#' @return Updated guard state
#' @keywords internal
guard_record_separation <- function(guard, details = NULL) {
  guard$separation_detected <- TRUE
  guard <- guard_flag_stability(guard, "Perfect or quasi-separation detected")
  if (!is.null(details)) {
    guard <- guard_warn(guard, details, "separation")
  }
  guard
}


#' Record Fallback Estimator Usage
#'
#' Records when fallback estimator was used due to primary engine failure.
#'
#' @param guard Guard state object
#' @param primary_engine Name of primary engine that failed
#' @param fallback_engine Name of fallback engine used
#' @param reason Reason for fallback
#' @return Updated guard state
#' @keywords internal
guard_record_fallback <- function(guard, primary_engine, fallback_engine, reason) {
  guard$fallback_used <- TRUE
  guard$fallback_reason <- reason
  guard <- guard_flag_stability(guard, paste0("Fallback estimator used: ", fallback_engine))
  guard <- guard_warn(guard,
    paste0("Primary engine (", primary_engine, ") failed: ", reason, "; used ", fallback_engine),
    "fallback"
  )
  guard
}


#' Record Data Modification
#'
#' Records any modifications made to input data (for transparency).
#'
#' @param guard Guard state object
#' @param type Type of modification (e.g., "level_collapse", "missing_impute")
#' @param details Details of the modification
#' @return Updated guard state
#' @keywords internal
guard_record_modification <- function(guard, type, details) {
  guard$data_modifications[[type]] <- c(guard$data_modifications[[type]], list(details))
  guard
}
