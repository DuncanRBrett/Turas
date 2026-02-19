# ==============================================================================
# TRACKER - TRS GUARD LAYER (TRS v1.0 COMPLIANT)
# ==============================================================================
#
# TRS v1.0 integration for the Tracker module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - tracker_refuse() - module-specific refusal wrapper (TRS v1.0 compliant)
#   - tracker_with_refusal_handler() - wraps main analysis with TRS handling
#   - tracker_guard_init() - initialize guard state with tracker-specific fields
#   - Validation helpers for tracker-specific requirements
#   - Sample size validation gates
#   - Data modification tracking
#
# TRS v1.0 EXECUTION STATES:
#   PASS    - All outputs valid and complete
#   PARTIAL - Outputs produced with declared degradation
#   REFUSE  - User-fixable issue; no outputs produced
#   ERROR   - Internal Turas bug
#
# TRS v1.0 REFUSAL CODE PREFIXES:
#   CFG_     - Configuration errors
#   DATA_    - Data integrity errors
#   IO_      - File or path errors
#   MODEL_   - Model fitting errors (not used in tracker)
#   MAPPER_  - Mapping / coverage errors
#   PKG_     - Missing dependency errors
#   FEATURE_ - Optional feature failures
#   BUG_     - Internal logic failures
#
# Related:
#   - modules/shared/lib/trs_refusal.R - shared TRS infrastructure
#
# Version: 1.1 (Full TRS v1.0 Compliance)
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# SOURCE SHARED TRS INFRASTRUCTURE
# ==============================================================================

if (!exists("turas_refuse", mode = "function")) {
  # Try multiple paths to find trs_refusal.R
  # Use tryCatch for sys.frame path since it fails in Jupyter/notebook contexts
  script_dir_path <- tryCatch({
    ofile <- sys.frame(1)$ofile
    if (!is.null(ofile)) {
      file.path(dirname(ofile), "../shared/lib/trs_refusal.R")
    } else {
      NULL
    }
  }, error = function(e) NULL)

  possible_paths <- c(
    script_dir_path,
    file.path(getwd(), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_HOME"), "modules/shared/lib/trs_refusal.R"),
    if (exists("script_dir")) file.path(script_dir, "../shared/lib/trs_refusal.R") else NULL
  )

  possible_paths <- possible_paths[!sapply(possible_paths, is.null)]

  trs_loaded <- FALSE
  for (path in possible_paths) {
    if (file.exists(path)) {
      source(path)
      trs_loaded <- TRUE
      break
    }
  }

  if (!trs_loaded) {
    warning("TRS infrastructure not found. Using fallback error handling.")
    turas_refuse <- function(code, title, problem, why_it_matters, how_to_fix, ...) {
      stop(paste0("[", code, "] ", title, ": ", problem))
    }
    with_refusal_handler <- function(expr, module = "UNKNOWN") {
      tryCatch(expr, error = function(e) stop(e))
    }
    guard_init <- function(module = "UNKNOWN") {
      list(module = module, warnings = list(), stable = TRUE)
    }
    guard_warn <- function(guard, msg, category = "general") {
      guard$warnings <- c(guard$warnings, list(list(msg = msg, category = category)))
      guard
    }
    guard_flag_stability <- function(guard, reason) {
      guard$stable <- FALSE
      guard
    }
    guard_summary <- function(guard) {
      list(module = guard$module, warning_count = length(guard$warnings),
           is_stable = guard$stable, has_issues = length(guard$warnings) > 0)
    }
    trs_status_pass <- function(module) list(status = "PASS", module = module)
    trs_status_partial <- function(module, degraded_reasons, affected_outputs) {
      list(status = "PARTIAL", module = module, degraded_reasons = degraded_reasons)
    }
  }
}


# ==============================================================================
# TRACKER-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Tracker)
#'
#' Module-specific refusal wrapper that delegates to shared TRS infrastructure.
#' Automatically prefixes codes with CFG_ if no valid prefix is present.
#'
#' TRS v1.0 Compliance:
#' - All refusals include mandatory why_it_matters explanation
#' - Diagnostics section shows expected/observed/missing/unmapped for clarity
#' - Refusal codes follow TRS prefix convention
#'
#' @param code Refusal code (will be prefixed with CFG_ if needed)
#' @param title Short title for the refusal
#' @param problem One-sentence description of what went wrong
#' @param why_it_matters Explanation of analytical risk (MANDATORY per TRS v1.0)
#' @param how_to_fix Explicit step-by-step instructions to resolve
#' @param expected Expected entities (for diagnostics)
#' @param observed Observed entities (for diagnostics)
#' @param missing Missing entities (for diagnostics)
#' @param unmapped Unmapped/extra entities (for diagnostics, TRS v1.0)
#' @param details Additional diagnostic details
#'
#' @return Never returns - always throws a turas_refusal condition
#' @keywords internal
tracker_refuse <- function(code,
                           title,
                           problem,
                           why_it_matters,
                           how_to_fix,
                           expected = NULL,
                           observed = NULL,
                           missing = NULL,
                           unmapped = NULL,
                           details = NULL) {

  # TRS v1.0: Validate code prefix, add default if missing
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
    unmapped = unmapped,
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
#' Creates a guard state object with tracker-specific fields for tracking
#' issues during analysis. This follows TRS v1.0 guard state pattern.
#'
#' Tracker-specific fields:
#' - missing_waves: Wave IDs that failed to load
#' - inconsistent_questions: Questions with cross-wave inconsistencies
#' - wave_sample_sizes: Sample size info per wave (for validation)
#' - question_alignment_issues: Questions not aligned across waves
#' - data_modifications: Tracked data cleaning operations
#' - low_sample_warnings: Waves/questions with sample size concerns
#'
#' @return Guard state list with tracker-specific extensions
#' @export
tracker_guard_init <- function() {
  guard <- guard_init(module = "TRACKER")


  # Tracker-specific fields (TRS v1.0 compliant)
  guard$missing_waves <- character(0)
  guard$inconsistent_questions <- list()
  guard$wave_sample_sizes <- list()
  guard$question_alignment_issues <- list()
  guard$low_sample_warnings <- list()
  guard$data_modifications <- list()

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
#' Creates a comprehensive summary of all guard state issues for output/logging.
#' Includes tracker-specific fields for wave and question tracking.
#'
#' @param guard Guard state object
#' @return List with summary info including tracker-specific issues
#' @export
tracker_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  # Add tracker-specific summary fields
  summary$missing_waves <- guard$missing_waves
  summary$inconsistent_questions <- guard$inconsistent_questions
  summary$wave_sample_sizes <- guard$wave_sample_sizes
  summary$question_alignment_issues <- guard$question_alignment_issues
  summary$low_sample_warnings <- guard$low_sample_warnings
  summary$data_modifications <- guard$data_modifications

  # TRS v1.0: has_issues flag includes all tracker-specific issues
  summary$has_issues <- summary$has_issues ||
                        length(guard$missing_waves) > 0 ||
                        length(guard$inconsistent_questions) > 0 ||
                        length(guard$low_sample_warnings) > 0

  summary
}


#' Record Wave Sample Size
#'
#' Records sample size information for a wave (for validation and reporting).
#'
#' @param guard Guard state object
#' @param wave_id Wave identifier
#' @param n_unweighted Unweighted sample size
#' @param n_weighted Weighted sample size (sum of weights)
#' @param n_effective Effective sample size (after design effect)
#' @return Updated guard state
#' @keywords internal
guard_record_sample_size <- function(guard, wave_id, n_unweighted, n_weighted, n_effective = NULL) {
  guard$wave_sample_sizes[[wave_id]] <- list(
    n_unweighted = n_unweighted,
    n_weighted = n_weighted,
    n_effective = n_effective
  )
  invisible(guard)
}


#' Record Low Sample Warning
#'
#' Records a warning when sample size is below recommended threshold.
#' TRS v1.0: Low sample sizes trigger PARTIAL status, not refusal.
#'
#' @param guard Guard state object
#' @param context Context (wave_id, question_code, or segment)
#' @param sample_size Observed sample size
#' @param threshold Recommended minimum threshold
#' @param metric Metric being calculated (e.g., "mean", "proportion")
#' @return Updated guard state
#' @keywords internal
guard_record_low_sample <- function(guard, context, sample_size, threshold, metric = NULL) {
  warning_info <- list(
    context = context,
    sample_size = sample_size,
    threshold = threshold,
    metric = metric,
    timestamp = Sys.time()
  )

  guard$low_sample_warnings <- c(guard$low_sample_warnings, list(warning_info))
  guard <- guard_warn(guard,
    paste0("Low sample size in ", context, ": ", sample_size, " (threshold: ", threshold, ")"),
    category = "sample_size"
  )

  invisible(guard)
}


#' Record Data Modification (Tracker)
#'
#' Records any modifications made to input data during processing.
#' TRS v1.0 requires transparency about data transformations.
#'
#' @param guard Guard state object
#' @param modification_type Type of modification (e.g., "dk_to_na", "comma_decimal", "weight_normalization")
#' @param wave_id Wave identifier (optional)
#' @param count Number of values modified
#' @param details Additional details
#' @return Updated guard state
#' @keywords internal
tracker_guard_record_modification <- function(guard, modification_type, wave_id = NULL, count = NULL, details = NULL) {
  mod_info <- list(
    type = modification_type,
    wave_id = wave_id,
    count = count,
    details = details,
    timestamp = Sys.time()
  )

  guard$data_modifications <- c(guard$data_modifications, list(mod_info))

  invisible(guard)
}


#' Record Question Alignment Issue
#'
#' Records when a question is not aligned across all waves.
#' TRS v1.0: Alignment issues may trigger PARTIAL status.
#'
#' @param guard Guard state object
#' @param question_code Question code
#' @param available_waves Waves where question is available
#' @param missing_waves Waves where question is missing
#' @return Updated guard state
#' @keywords internal
guard_record_alignment_issue <- function(guard, question_code, available_waves, missing_waves) {
  guard$question_alignment_issues[[question_code]] <- list(
    available_waves = available_waves,
    missing_waves = missing_waves
  )

  guard <- guard_warn(guard,
    paste0("Question ", question_code, " missing in waves: ", paste(missing_waves, collapse = ", ")),
    category = "alignment"
  )

  invisible(guard)
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
#' Performs comprehensive validation of tracker configuration structure.
#' TRS v1.0: Configuration validation is a hard gate - refuses on any mismatch.
#'
#' @param config Configuration list
#' @keywords internal
validate_tracker_config <- function(config) {

  # Check basic structure
  if (!is.list(config)) {
    tracker_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  # Check required sections exist
  required_sections <- c("waves", "tracked_questions")
  missing_sections <- setdiff(required_sections, names(config))

  if (length(missing_sections) > 0) {
    tracker_refuse(
      code = "CFG_MISSING_SECTIONS",
      title = "Missing Configuration Sections",
      problem = paste0("Required configuration sections are missing: ", paste(missing_sections, collapse = ", ")),
      why_it_matters = "Cannot run tracker without wave definitions and tracked questions.",
      how_to_fix = c(
        "Ensure your config file has a 'Waves' sheet with WaveID, WaveName, DataFile columns",
        "Ensure your config file has a 'TrackedQuestions' sheet with QuestionCode column"
      ),
      expected = required_sections,
      missing = missing_sections
    )
  }

  # Validate waves section has required columns
  if (!is.null(config$waves)) {
    required_wave_cols <- c("WaveID", "WaveName", "DataFile")
    missing_wave_cols <- setdiff(required_wave_cols, names(config$waves))

    if (length(missing_wave_cols) > 0) {
      tracker_refuse(
        code = "CFG_MISSING_WAVE_COLUMNS",
        title = "Missing Wave Configuration Columns",
        problem = paste0("Waves sheet is missing required columns: ", paste(missing_wave_cols, collapse = ", ")),
        why_it_matters = "Cannot identify and load wave data files without complete wave configuration.",
        how_to_fix = c(
          "Add the missing columns to the Waves sheet in your config file",
          "WaveID: Unique identifier for each wave (e.g., W1, W2)",
          "WaveName: Display name for each wave (e.g., 'Wave 1 - Jan 2024')",
          "DataFile: Path to the data file for each wave"
        ),
        expected = required_wave_cols,
        observed = names(config$waves),
        missing = missing_wave_cols
      )
    }
  }

  # Validate tracked_questions section has required columns
  if (!is.null(config$tracked_questions)) {
    if (!"QuestionCode" %in% names(config$tracked_questions)) {
      tracker_refuse(
        code = "CFG_MISSING_QUESTION_COLUMN",
        title = "Missing QuestionCode Column",
        problem = "TrackedQuestions sheet is missing required QuestionCode column.",
        why_it_matters = "Cannot identify which questions to track without QuestionCode column.",
        how_to_fix = "Add QuestionCode column to TrackedQuestions sheet listing the standardized question codes to track."
      )
    }
  }

  # Validate baseline_wave setting (if specified, must be a valid WaveID)
  if (!is.null(config$settings) && !is.null(config$waves)) {
    baseline_wave <- get_setting(config, "baseline_wave", default = NULL)
    if (!is.null(baseline_wave) && !is.na(baseline_wave) && trimws(as.character(baseline_wave)) != "") {
      baseline_wave <- trimws(as.character(baseline_wave))
      if (!baseline_wave %in% config$waves$WaveID) {
        tracker_refuse(
          code = "CFG_INVALID_BASELINE_WAVE",
          title = "Invalid Baseline Wave",
          problem = paste0("baseline_wave '", baseline_wave, "' is not a valid WaveID."),
          why_it_matters = "Baseline wave must reference an existing wave for 'vs Baseline' comparisons.",
          how_to_fix = paste0("Set baseline_wave to one of: ", paste(config$waves$WaveID, collapse = ", ")),
          expected = config$waves$WaveID,
          observed = baseline_wave
        )
      }
    }
  }

  invisible(TRUE)
}


#' Validate Sample Size for Metric Calculation
#'
#' Checks if sample size is sufficient for reliable metric calculation.
#' TRS v1.0: Warns but does not refuse for low sample sizes (PARTIAL status).
#'
#' @param n_effective Effective sample size
#' @param metric_type Type of metric (affects threshold)
#' @param context Context for warning message (e.g., "W1", "W1:Q10")
#' @param guard Guard state object (optional, for recording warnings)
#' @return List with $sufficient (logical) and $threshold (numeric)
#'
#' @keywords internal
validate_sample_size <- function(n_effective, metric_type = "mean", context = NULL, guard = NULL) {

  # TRS v1.0 recommended minimum sample sizes by metric type
  thresholds <- list(
    mean = 30,           # Central limit theorem recommendation
    proportion = 30,     # Standard statistical threshold
    nps = 50,            # NPS requires larger samples for stability
    significance = 30    # Minimum for statistical testing
  )

  threshold <- thresholds[[metric_type]]
  if (is.null(threshold)) threshold <- 30

  sufficient <- !is.na(n_effective) && n_effective >= threshold

  # Record warning if guard provided and sample is low
 if (!sufficient && !is.null(guard) && !is.null(context)) {
    guard <- guard_record_low_sample(guard, context, n_effective, threshold, metric_type)
  }

  list(
    sufficient = sufficient,
    threshold = threshold,
    n_effective = n_effective
  )
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
#' For use when execution continues with declared degradation.
#' Common reasons for PARTIAL in tracker:
#' - Low sample sizes in some waves
#' - Questions missing in some waves
#' - Significance tests not performed due to sample size
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param missing_waves Character vector of missing wave IDs
#' @param skipped_questions List of skipped questions with reasons
#' @return TRS status object
#' @export
tracker_status_partial <- function(degraded_reasons,
                                   affected_outputs,
                                   missing_waves = NULL,
                                   skipped_questions = NULL) {
  status <- trs_status_partial(
    module = "TRACKER",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )

  # Add tracker-specific details
  status$details <- list()
  if (!is.null(missing_waves) && length(missing_waves) > 0) {
    status$details$missing_waves <- missing_waves
  }
  if (!is.null(skipped_questions) && length(skipped_questions) > 0) {
    status$details$skipped_questions <- skipped_questions
  }

  status
}


#' Create Tracker REFUSE Status
#'
#' Creates a REFUSE status object for cases where analysis cannot proceed.
#' TRS v1.0: REFUSE means user-fixable issue, no outputs produced.
#'
#' @param code Refusal code
#' @param reason Refusal reason
#' @return TRS status object with REFUSE state
#' @export
tracker_status_refuse <- function(code = NULL, reason = NULL) {
  trs_status_refuse(
    module = "TRACKER",
    code = code,
    reason = reason
  )
}


#' Determine Final Run Status from Guard State
#'
#' Analyzes guard state to determine appropriate TRS run status.
#' TRS v1.0: Uses guard warnings and issues to determine PASS vs PARTIAL.
#'
#' @param guard Guard state object
#' @param waves_processed Number of waves successfully processed
#' @param questions_processed Number of questions successfully processed
#' @param skipped_questions List of skipped questions with reasons
#' @return TRS status object (PASS or PARTIAL)
#' @export
tracker_determine_status <- function(guard,
                                     waves_processed = NULL,
                                     questions_processed = NULL,
                                     skipped_questions = NULL) {

  summary <- tracker_guard_summary(guard)

  # Determine if any degradation occurred
  has_degradation <- summary$has_issues ||
                     length(summary$missing_waves) > 0 ||
                     length(summary$question_alignment_issues) > 0 ||
                     length(summary$low_sample_warnings) > 0 ||
                     (!is.null(skipped_questions) && length(skipped_questions) > 0)

  if (has_degradation) {
    # Build degradation reasons
    degraded_reasons <- character(0)

    if (length(summary$missing_waves) > 0) {
      degraded_reasons <- c(degraded_reasons,
        paste0("Missing waves: ", paste(summary$missing_waves, collapse = ", "))
      )
    }

    if (length(summary$question_alignment_issues) > 0) {
      degraded_reasons <- c(degraded_reasons,
        paste0(length(summary$question_alignment_issues), " question(s) not aligned across all waves")
      )
    }

    if (length(summary$low_sample_warnings) > 0) {
      degraded_reasons <- c(degraded_reasons,
        paste0(length(summary$low_sample_warnings), " low sample size warning(s)")
      )
    }

    if (!is.null(skipped_questions) && length(skipped_questions) > 0) {
      degraded_reasons <- c(degraded_reasons,
        paste0(length(skipped_questions), " question(s) skipped")
      )
    }

    # Build affected outputs list
    affected_outputs <- "Trend calculations may be incomplete or less reliable"
    if (length(summary$question_alignment_issues) > 0) {
      affected_outputs <- c(affected_outputs,
        paste0("Questions affected: ", paste(names(summary$question_alignment_issues), collapse = ", "))
      )
    }

    return(tracker_status_partial(
      degraded_reasons = degraded_reasons,
      affected_outputs = affected_outputs,
      missing_waves = summary$missing_waves,
      skipped_questions = skipped_questions
    ))
  }

  # All good - return PASS
  tracker_status_pass(waves_processed = waves_processed)
}
