# ==============================================================================
# TRACKER - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the Tracker module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - tracker_refuse() - module-specific refusal wrapper
#   - tracker_with_refusal_handler() - wraps main analysis with TRS handling
#   - tracker_guard_init() - initialize guard state with tracker-specific fields
#   - Validation helpers for tracker-specific requirements
#
# Related:
#   - modules/shared/lib/trs_refusal.R - shared TRS infrastructure
#
# Version: 1.0 (TRS Integration)
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# SOURCE SHARED TRS INFRASTRUCTURE
# ==============================================================================

if (!exists("turas_refuse", mode = "function")) {
  possible_paths <- c(
    file.path(dirname(sys.frame(1)$ofile), "../shared/lib/trs_refusal.R"),
    file.path(getwd(), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_HOME"), "modules/shared/lib/trs_refusal.R")
  )

  for (path in possible_paths) {
    if (file.exists(path)) {
      source(path)
      break
    }
  }
}


# ==============================================================================
# TRACKER-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Tracker)
#'
#' @param code Refusal code (will be prefixed if needed)
#' @param title Short title for the refusal
#' @param problem One-sentence description of what went wrong
#' @param why_it_matters Explanation of analytical risk (MANDATORY)
#' @param how_to_fix Explicit step-by-step instructions to resolve
#' @param expected Expected entities (for diagnostics)
#' @param observed Observed entities (for diagnostics)
#' @param missing Missing entities (for diagnostics)
#' @param details Additional diagnostic details
#'
#' @keywords internal
tracker_refuse <- function(code,
                           title,
                           problem,
                           why_it_matters,
                           how_to_fix,
                           expected = NULL,
                           observed = NULL,
                           missing = NULL,
                           details = NULL) {

  if (!grepl("^(CFG_|DATA_|IO_|MODEL_|MAPPER_|PKG_|FEATURE_|BUG_)", code)) {
    code <- paste0("CFG_", code)
  }

  turas_refuse(
    code = code,
    title = title,
    problem = problem,
    why_it_matters = why_it_matters,
    how_to_fix = how_to_fix,
    expected = expected,
    observed = observed,
    missing = missing,
    details = details,
    module = "TRACKER"
  )
}


#' Run Tracker Analysis with Refusal Handler
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
tracker_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "TRACKER")

  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("tracker_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# TRACKER GUARD STATE
# ==============================================================================

#' Initialize Tracker Guard State
#'
#' @return Guard state list
#' @export
tracker_guard_init <- function() {
  guard <- guard_init(module = "TRACKER")

  # Add Tracker-specific fields
  guard$missing_waves <- character(0)
  guard$inconsistent_questions <- list()
  guard$wave_sample_sizes <- list()
  guard$question_alignment_issues <- list()

  guard
}


#' Record Missing Wave
#'
#' @param guard Guard state object
#' @param wave_id Wave identifier
#' @param reason Reason for missing
#' @return Updated guard state
#' @keywords internal
guard_record_missing_wave <- function(guard, wave_id, reason) {
  guard$missing_waves <- c(guard$missing_waves, wave_id)
  guard <- guard_warn(guard, paste0("Missing wave: ", wave_id, " (", reason, ")"), "missing_wave")
  guard
}


#' Record Question Inconsistency
#'
#' @param guard Guard state object
#' @param question_code Question code
#' @param wave1 First wave
#' @param wave2 Second wave
#' @param issue Description of inconsistency
#' @return Updated guard state
#' @keywords internal
guard_record_inconsistency <- function(guard, question_code, wave1, wave2, issue) {
  guard$inconsistent_questions[[question_code]] <- list(
    wave1 = wave1,
    wave2 = wave2,
    issue = issue
  )
  guard <- guard_flag_stability(guard, paste0("Question inconsistency: ", question_code))
  guard
}


#' Get Tracker Guard Summary
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
tracker_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  summary$missing_waves <- guard$missing_waves
  summary$inconsistent_questions <- guard$inconsistent_questions
  summary$wave_sample_sizes <- guard$wave_sample_sizes
  summary$question_alignment_issues <- guard$question_alignment_issues

  summary$has_issues <- summary$has_issues ||
                        length(guard$missing_waves) > 0 ||
                        length(guard$inconsistent_questions) > 0

  summary
}


# ==============================================================================
# TRACKER VALIDATION GATES
# ==============================================================================

#' Validate Tracker Wave Files
#'
#' @param wave_files Named list of wave file paths
#' @keywords internal
validate_tracker_wave_files <- function(wave_files) {

  if (is.null(wave_files) || length(wave_files) == 0) {
    tracker_refuse(
      code = "IO_NO_WAVE_FILES",
      title = "No Wave Files Specified",
      problem = "No wave files were specified in the configuration.",
      why_it_matters = "Tracker analysis requires at least 2 waves of data to show trends.",
      how_to_fix = c(
        "Open your config file",
        "Add wave file paths to the Waves section",
        "Ensure at least 2 waves are defined"
      )
    )
  }

  if (length(wave_files) < 2) {
    tracker_refuse(
      code = "DATA_INSUFFICIENT_WAVES",
      title = "Insufficient Waves for Tracking",
      problem = paste0("Only ", length(wave_files), " wave file specified. Need at least 2."),
      why_it_matters = "Trend analysis requires comparison across multiple time points.",
      how_to_fix = "Add at least one more wave file to your configuration."
    )
  }

  # Check each file exists
  missing_files <- character(0)
  for (wave_id in names(wave_files)) {
    if (!file.exists(wave_files[[wave_id]])) {
      missing_files <- c(missing_files, wave_id)
    }
  }

  if (length(missing_files) > 0) {
    tracker_refuse(
      code = "IO_WAVE_FILE_NOT_FOUND",
      title = "Wave Files Not Found",
      problem = paste0(length(missing_files), " wave file(s) not found."),
      why_it_matters = "Cannot analyze trends without all wave data files.",
      how_to_fix = c(
        "Check that file paths in config are correct",
        "Verify all data files exist at specified locations"
      ),
      expected = names(wave_files),
      missing = missing_files
    )
  }

  invisible(TRUE)
}


#' Validate Question Consistency Across Waves
#'
#' @param question_code Question code
#' @param wave_data List of wave data frames
#' @param guard Guard state
#' @return Updated guard state
#' @keywords internal
validate_question_consistency <- function(question_code, wave_data, guard) {

  wave_ids <- names(wave_data)
  first_wave <- wave_ids[1]

  # Check column exists in all waves
  missing_in_waves <- character(0)
  for (wave_id in wave_ids) {
    if (!question_code %in% names(wave_data[[wave_id]])) {
      missing_in_waves <- c(missing_in_waves, wave_id)
    }
  }

  if (length(missing_in_waves) > 0 && length(missing_in_waves) < length(wave_ids)) {
    guard <- guard_record_inconsistency(
      guard,
      question_code,
      first_wave,
      missing_in_waves[1],
      "Question missing in some waves"
    )
  }

  guard
}


#' Validate Tracker Configuration
#'
#' @param config Configuration list
#' @keywords internal
validate_tracker_config <- function(config) {

  if (!is.list(config)) {
    tracker_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create Tracker PASS Status
#'
#' @param waves_processed Number of waves processed
#' @return TRS status object
#' @export
tracker_status_pass <- function(waves_processed = NULL) {
  status <- trs_status_pass(module = "TRACKER")
  if (!is.null(waves_processed)) {
    status$details <- list(waves_processed = waves_processed)
  }
  status
}


#' Create Tracker PARTIAL Status
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param missing_waves Character vector of missing wave IDs
#' @return TRS status object
#' @export
tracker_status_partial <- function(degraded_reasons,
                                   affected_outputs,
                                   missing_waves = NULL) {
  status <- trs_status_partial(
    module = "TRACKER",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
  if (!is.null(missing_waves) && length(missing_waves) > 0) {
    status$details <- list(missing_waves = missing_waves)
  }
  status
}
