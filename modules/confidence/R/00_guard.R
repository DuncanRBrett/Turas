# ==============================================================================
# CONFIDENCE - TRS GUARD LAYER (TRS v1.0 COMPLIANT)
# ==============================================================================
#
# TRS v1.0 integration for the Confidence Interval module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - confidence_refuse() - module-specific refusal wrapper (TRS v1.0 compliant)
#   - confidence_with_refusal_handler() - wraps main analysis with TRS handling
#   - confidence_guard_init() - initialize guard state with confidence-specific fields
#   - Validation helpers for confidence-specific requirements
#   - Sample size validation with metric-specific thresholds
#   - Bootstrap iteration tracking
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
#   MODEL_   - Model fitting errors
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
  script_dir_path <- tryCatch({
    ofile <- sys.frame(1)$ofile
    if (!is.null(ofile)) file.path(dirname(ofile), "../../shared/lib/trs_refusal.R") else NULL
  }, error = function(e) NULL)

  possible_paths <- c(
    script_dir_path,
    file.path(getwd(), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_HOME"), "modules/shared/lib/trs_refusal.R"),
    file.path(Sys.getenv("TURAS_ROOT", getwd()), "modules/shared/lib/trs_refusal.R")
  )
  possible_paths <- possible_paths[!sapply(possible_paths, is.null)]

  trs_loaded <- FALSE
  for (path in possible_paths) {
    if (file.exists(path)) { source(path); trs_loaded <- TRUE; break }
  }

  if (!trs_loaded) {
    warning("TRS infrastructure not found. Using fallback.")
    turas_refuse <- function(code, title, problem, why_it_matters, how_to_fix, ...) {
      stop(paste0("[", code, "] ", title, ": ", problem))
    }
    with_refusal_handler <- function(expr, module = "UNKNOWN") tryCatch(expr, error = function(e) stop(e))
    guard_init <- function(module = "UNKNOWN") list(module = module, warnings = list(), stable = TRUE)
    guard_warn <- function(guard, msg, category = "general") { guard$warnings <- c(guard$warnings, list(list(msg = msg, category = category))); guard }
    guard_flag_stability <- function(guard, reason) { guard$stable <- FALSE; guard }
    guard_summary <- function(guard) list(module = guard$module, warning_count = length(guard$warnings), is_stable = guard$stable, has_issues = length(guard$warnings) > 0)
    trs_status_pass <- function(module) list(status = "PASS", module = module)
    trs_status_partial <- function(module, degraded_reasons, affected_outputs) list(status = "PARTIAL", module = module, degraded_reasons = degraded_reasons)
  }
}


# ==============================================================================
# CONFIDENCE-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Confidence)
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
confidence_refuse <- function(code,
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
    module = "CONFIDENCE"
  )
}


#' Run Confidence Analysis with Refusal Handler
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
confidence_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "CONFIDENCE")

  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("confidence_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# CONFIDENCE GUARD STATE
# ==============================================================================

#' Initialize Confidence Guard State
#'
#' Creates a guard state object with confidence-specific fields for tracking
#' issues during analysis. This follows TRS v1.0 guard state pattern.
#'
#' Confidence-specific fields:
#' - zero_cells: Variables with zero counts in categories
#' - small_samples: Variables with sample sizes below threshold
#' - method_used: CI method used (MOE, Wilson, Bootstrap, Bayesian)
#' - confidence_level: Confidence level used
#' - bounds_capped: Whether bounds were capped to [0,1]
#' - bootstrap_iterations: Number of bootstrap iterations performed
#' - questions_processed: Count of successfully processed questions
#' - questions_skipped: List of skipped questions with reasons
#'
#' @return Guard state list with confidence-specific extensions
#' @export
confidence_guard_init <- function() {
  guard <- guard_init(module = "CONFIDENCE")

  # Confidence-specific fields (TRS v1.0 compliant)
  guard$zero_cells <- list()
  guard$small_samples <- list()
  guard$method_used <- NULL
  guard$confidence_level <- NULL
  guard$bounds_capped <- FALSE
  guard$bootstrap_iterations <- NULL
  guard$questions_processed <- 0
  guard$questions_skipped <- list()

  guard
}


#' Record Zero Cell
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param category Category with zero cell
#' @return Updated guard state
#' @keywords internal
guard_record_zero_cell <- function(guard, variable, category) {
  guard$zero_cells[[variable]] <- c(guard$zero_cells[[variable]], category)
  guard <- guard_warn(guard, paste0("Zero cell in ", variable, ": ", category), "zero_cell")
  guard
}


#' Record Small Sample
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param n Sample size
#' @return Updated guard state
#' @keywords internal
guard_record_small_sample <- function(guard, variable, n) {
  guard$small_samples[[variable]] <- n
  guard <- guard_flag_stability(guard, paste0("Small sample for ", variable, " (n=", n, ")"))
  guard
}


#' Get Confidence Guard Summary
#'
#' Creates a comprehensive summary of all guard state issues for output/logging.
#' Includes confidence-specific fields for CI calculations.
#'
#' @param guard Guard state object
#' @return List with summary info including confidence-specific issues
#' @export
confidence_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  # Add confidence-specific summary fields
  summary$zero_cells <- guard$zero_cells
  summary$small_samples <- guard$small_samples
  summary$method_used <- guard$method_used
  summary$confidence_level <- guard$confidence_level
  summary$bounds_capped <- guard$bounds_capped
  summary$bootstrap_iterations <- guard$bootstrap_iterations
  summary$questions_processed <- guard$questions_processed
  summary$questions_skipped <- guard$questions_skipped

  # TRS v1.0: has_issues flag includes all confidence-specific issues
  summary$has_issues <- summary$has_issues ||
                        length(guard$zero_cells) > 0 ||
                        length(guard$small_samples) > 0 ||
                        length(guard$questions_skipped) > 0

  summary
}


#' Record Skipped Question
#'
#' Records when a question is skipped during processing.
#' TRS v1.0: Skipped questions contribute to PARTIAL status.
#'
#' @param guard Guard state object
#' @param question_id Question identifier
#' @param reason Reason for skipping
#' @return Updated guard state
#' @keywords internal
guard_record_skipped_question <- function(guard, question_id, reason) {
  guard$questions_skipped[[question_id]] <- list(
    question_id = question_id,
    reason = reason,
    timestamp = Sys.time()
  )

  guard <- guard_warn(guard,
    paste0("Question ", question_id, " skipped: ", reason),
    category = "skipped"
  )

  invisible(guard)
}


#' Record Bootstrap Iterations
#'
#' Records the number of bootstrap iterations used for tracking.
#'
#' @param guard Guard state object
#' @param iterations Number of bootstrap iterations
#' @return Updated guard state
#' @keywords internal
guard_record_bootstrap_iterations <- function(guard, iterations) {
  guard$bootstrap_iterations <- iterations
  invisible(guard)
}


# ==============================================================================
# CONFIDENCE VALIDATION GATES
# ==============================================================================

#' Validate Confidence Configuration
#'
#' @param config Configuration list
#' @keywords internal
validate_confidence_config <- function(config) {

  if (!is.list(config)) {
    confidence_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  invisible(TRUE)
}


#' Validate Confidence Level
#'
#' @param conf_level Confidence level (e.g., 0.95)
#' @keywords internal
validate_confidence_level <- function(conf_level) {

  if (is.null(conf_level)) {
    confidence_refuse(
      code = "CFG_MISSING_CONFIDENCE_LEVEL",
      title = "Missing Confidence Level",
      problem = "No confidence level was specified.",
      why_it_matters = "Confidence level determines the width of intervals.",
      how_to_fix = "Specify confidence_level in config (typical values: 0.90, 0.95, 0.99)."
    )
  }

  if (!is.numeric(conf_level) || conf_level <= 0 || conf_level >= 1) {
    confidence_refuse(
      code = "CFG_INVALID_CONFIDENCE_LEVEL",
      title = "Invalid Confidence Level",
      problem = paste0("Confidence level must be between 0 and 1, got: ", conf_level),
      why_it_matters = "Invalid confidence level will produce incorrect intervals.",
      how_to_fix = c(
        "Use a value between 0 and 1",
        "Common values: 0.90 (90%), 0.95 (95%), 0.99 (99%)"
      )
    )
  }

  if (conf_level < 0.5) {
    confidence_refuse(
      code = "CFG_LOW_CONFIDENCE_LEVEL",
      title = "Unusually Low Confidence Level",
      problem = paste0("Confidence level ", conf_level, " is below 50%."),
      why_it_matters = "Such a low confidence level is rarely meaningful in practice.",
      how_to_fix = "Use a standard confidence level: 0.90, 0.95, or 0.99."
    )
  }

  invisible(TRUE)
}


#' Validate Proportion Data
#'
#' @param successes Number of successes
#' @param total Total observations
#' @param variable_name Variable name for error messages
#' @param guard Guard state
#' @return Updated guard state
#' @keywords internal
validate_proportion_data <- function(successes, total, variable_name, guard) {

  if (is.null(total) || is.na(total) || total <= 0) {
    confidence_refuse(
      code = "DATA_ZERO_DENOMINATOR",
      title = "Zero or Invalid Total",
      problem = paste0("Variable '", variable_name, "' has zero or invalid total."),
      why_it_matters = "Cannot calculate proportions without a valid denominator.",
      how_to_fix = c(
        "Check data for missing values",
        "Verify the base filter isn't too restrictive"
      )
    )
  }

  if (is.null(successes) || is.na(successes)) {
    confidence_refuse(
      code = "DATA_INVALID_SUCCESSES",
      title = "Invalid Success Count",
      problem = paste0("Variable '", variable_name, "' has invalid success count."),
      why_it_matters = "Cannot calculate proportions without valid counts.",
      how_to_fix = "Check data for issues with the numerator variable."
    )
  }

  if (successes < 0 || successes > total) {
    confidence_refuse(
      code = "DATA_INVALID_PROPORTION",
      title = "Invalid Proportion",
      problem = paste0("Variable '", variable_name, "': successes (", successes, ") invalid for total (", total, ")."),
      why_it_matters = "Proportions must be between 0 and 1.",
      how_to_fix = "Check data coding and calculation."
    )
  }

  # Track zero cells and small samples
  if (successes == 0 || successes == total) {
    guard <- guard_record_zero_cell(guard, variable_name, if(successes == 0) "zero successes" else "all successes")
  }

  if (total < 30) {
    guard <- guard_record_small_sample(guard, variable_name, total)
  }

  guard
}


#' Validate Mean Data
#'
#' @param values Numeric vector of values
#' @param variable_name Variable name for error messages
#' @param guard Guard state
#' @return Updated guard state
#' @keywords internal
validate_mean_data <- function(values, variable_name, guard) {

  if (is.null(values) || length(values) == 0) {
    confidence_refuse(
      code = "DATA_NO_VALUES",
      title = "No Values for Mean",
      problem = paste0("Variable '", variable_name, "' has no valid values."),
      why_it_matters = "Cannot calculate mean confidence interval without data.",
      how_to_fix = c(
        "Check data for missing values",
        "Verify variable name is correct"
      )
    )
  }

  valid_values <- values[!is.na(values)]

  if (length(valid_values) == 0) {
    confidence_refuse(
      code = "DATA_ALL_MISSING",
      title = "All Values Missing",
      problem = paste0("Variable '", variable_name, "' has all NA values."),
      why_it_matters = "Cannot calculate statistics on missing data.",
      how_to_fix = c(
        "Check for data issues",
        "Consider imputation if appropriate"
      )
    )
  }

  if (length(valid_values) < 2) {
    confidence_refuse(
      code = "DATA_INSUFFICIENT_FOR_CI",
      title = "Insufficient Data for Confidence Interval",
      problem = paste0("Variable '", variable_name, "' has only ", length(valid_values), " valid value(s)."),
      why_it_matters = "Need at least 2 observations to calculate standard error.",
      how_to_fix = "Collect more data or check for data issues."
    )
  }

  if (length(valid_values) < 30) {
    guard <- guard_record_small_sample(guard, variable_name, length(valid_values))
  }

  # Check for zero variance
  if (sd(valid_values) == 0) {
    guard <- guard_flag_stability(guard, paste0("Zero variance in ", variable_name))
  }

  guard
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create Confidence PASS Status
#'
#' @param n_estimates Number of estimates produced
#' @param method Method used
#' @param confidence_level Confidence level
#' @return TRS status object
#' @export
confidence_status_pass <- function(n_estimates = NULL, method = NULL, confidence_level = NULL) {
  status <- trs_status_pass(module = "CONFIDENCE")
  status$details <- list(
    estimates = n_estimates,
    method = method,
    confidence_level = confidence_level
  )
  status
}


#' Create Confidence PARTIAL Status
#'
#' For use when execution continues with declared degradation.
#' Common reasons for PARTIAL in confidence module:
#' - Zero cells in proportion calculations
#' - Small sample sizes (n < 30)
#' - Bootstrap sampling issues
#' - Some questions skipped due to data issues
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param zero_cells Character vector of zero cell issues
#' @param skipped_questions List of skipped questions with reasons
#' @return TRS status object
#' @export
confidence_status_partial <- function(degraded_reasons,
                                      affected_outputs,
                                      zero_cells = NULL,
                                      skipped_questions = NULL) {
  status <- trs_status_partial(
    module = "CONFIDENCE",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )

  # Add confidence-specific details
  status$details <- list()
  if (!is.null(zero_cells) && length(zero_cells) > 0) {
    status$details$zero_cells <- zero_cells
  }
  if (!is.null(skipped_questions) && length(skipped_questions) > 0) {
    status$details$skipped_questions <- skipped_questions
  }

  status
}


#' Create Confidence REFUSE Status
#'
#' Creates a REFUSE status object for cases where analysis cannot proceed.
#' TRS v1.0: REFUSE means user-fixable issue, no outputs produced.
#'
#' @param code Refusal code
#' @param reason Refusal reason
#' @return TRS status object with REFUSE state
#' @export
confidence_status_refuse <- function(code = NULL, reason = NULL) {
  trs_status_refuse(
    module = "CONFIDENCE",
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
#' @param questions_processed Number of questions successfully processed
#' @param skipped_questions List of skipped questions with reasons
#' @return TRS status object (PASS or PARTIAL)
#' @export
confidence_determine_status <- function(guard,
                                        questions_processed = NULL,
                                        skipped_questions = NULL) {

  summary <- confidence_guard_summary(guard)

  # Determine if any degradation occurred
  has_degradation <- summary$has_issues ||
                     length(summary$zero_cells) > 0 ||
                     length(summary$small_samples) > 0 ||
                     (!is.null(skipped_questions) && length(skipped_questions) > 0)

  if (has_degradation) {
    # Build degradation reasons
    degraded_reasons <- character(0)

    if (length(summary$zero_cells) > 0) {
      degraded_reasons <- c(degraded_reasons,
        paste0(length(summary$zero_cells), " variable(s) with zero cells")
      )
    }

    if (length(summary$small_samples) > 0) {
      degraded_reasons <- c(degraded_reasons,
        paste0(length(summary$small_samples), " variable(s) with small samples (n < 30)")
      )
    }

    if (!is.null(skipped_questions) && length(skipped_questions) > 0) {
      degraded_reasons <- c(degraded_reasons,
        paste0(length(skipped_questions), " question(s) skipped")
      )
    }

    # Build affected outputs list
    affected_outputs <- "Confidence intervals may be less reliable for affected variables"
    if (length(summary$zero_cells) > 0) {
      affected_outputs <- c(affected_outputs,
        paste0("Zero cell warnings: ", paste(names(summary$zero_cells), collapse = ", "))
      )
    }

    return(confidence_status_partial(
      degraded_reasons = degraded_reasons,
      affected_outputs = affected_outputs,
      zero_cells = names(summary$zero_cells),
      skipped_questions = skipped_questions
    ))
  }

  # All good - return PASS
  confidence_status_pass(
    n_estimates = questions_processed,
    method = summary$method_used,
    confidence_level = summary$confidence_level
  )
}
