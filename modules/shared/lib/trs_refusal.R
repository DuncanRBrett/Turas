# ==============================================================================
# TURAS RELIABILITY STANDARD (TRS) - SHARED REFUSAL INFRASTRUCTURE
# ==============================================================================
#
# This module implements the mandatory refusal and reliability framework
# defined in TRS v1.0 (TURAS_Mapping_Refusal_Standard_TRS_v1.0.md).
#
# All Turas modules MUST use these functions for error handling.
# Module-specific wrappers are permitted but MUST delegate to these functions.
#
# EXECUTION STATES (TRS v1.0):
#   PASS    - All outputs valid and complete
#   PARTIAL - Outputs produced with declared degradation
#   REFUSE  - User-fixable issue; no outputs produced
#   ERROR   - Internal Turas bug
#
# REFUSAL CODE PREFIXES (TRS v1.0):
#   CFG_     - Configuration errors
#   DATA_    - Data integrity errors
#   IO_      - File or path errors
#   MODEL_   - Model fitting errors
#   MAPPER_  - Mapping / coverage errors
#   PKG_     - Missing dependency errors
#   FEATURE_ - Optional feature failures
#   BUG_     - Internal logic failures
#
# Version: 1.0
# Date: December 2024
#
# ==============================================================================


# ==============================================================================
# REFUSAL CODE REGISTRY
# ==============================================================================
# All valid refusal code prefixes per TRS v1.0

.trs_valid_prefixes <- c(

"CFG_",      # Configuration errors
  "DATA_",     # Data integrity errors
  "IO_",       # File or path errors
  "MODEL_",    # Model fitting errors
"MAPPER_",   # Mapping / coverage errors
  "PKG_",      # Missing dependency errors
  "FEATURE_",  # Optional feature failures
  "BUG_"       # Internal logic failures
)


#' Validate Refusal Code Format
#'
#' Ensures refusal codes follow TRS v1.0 naming conventions.
#' Codes must start with a valid prefix and contain only uppercase letters,
#' numbers, and underscores.
#'
#' @param code The refusal code to validate
#' @return TRUE if valid, stops with error if invalid
#' @keywords internal
trs_validate_code <- function(code) {
  if (is.null(code) || !is.character(code) || length(code) != 1) {
    stop("TRS: Refusal code must be a single character string")
  }

  # Check prefix
  has_valid_prefix <- any(vapply(.trs_valid_prefixes, function(prefix) {
    startsWith(code, prefix)
  }, logical(1)))

  if (!has_valid_prefix) {
    stop(paste0(
      "TRS: Invalid refusal code prefix. Code '", code, "' must start with one of: ",
      paste(.trs_valid_prefixes, collapse = ", ")
    ))
  }

  # Check format (uppercase, numbers, underscores only)
  if (!grepl("^[A-Z][A-Z0-9_]+$", code)) {
    stop(paste0(
      "TRS: Refusal code '", code, "' must contain only uppercase letters, ",
      "numbers, and underscores"
    ))
  }

  TRUE
}


# ==============================================================================
# CORE REFUSAL MECHANISM
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message
#'
#' Produces a clear, user-actionable refusal message following TRS v1.0 format.
#' This is NOT a crash - it is a controlled, intentional stop that guides
#' the user to fix the issue.
#'
#' The refusal message MUST include:
#' - Problem: One-sentence description
#' - Why it matters: Explanation of analytical risk
#' - How to fix: Explicit step-by-step actions
#' - Diagnostics: Expected/Observed/Missing/Unmapped (when applicable)
#'
#' @param code Refusal code (must follow TRS prefix convention, e.g., "CFG_MISSING_SHEET")
#' @param title Short title for the refusal
#' @param problem One-sentence description of what went wrong
#' @param why_it_matters Explanation of analytical risk (MANDATORY per TRS governance)
#' @param how_to_fix Explicit step-by-step instructions to resolve
#' @param expected Expected entities/values (for diagnostics)
#' @param observed Observed entities/values (for diagnostics)
#' @param missing Missing entities (for diagnostics)
#' @param unmapped Unmapped/extra entities (for diagnostics)
#' @param details Additional diagnostic details (optional)
#' @param module Module name for display (defaults to "TURAS")
#'
#' @return Never returns - always throws a turas_refusal condition
#' @export
turas_refuse <- function(code,
                         title,
                         problem,
                         why_it_matters,
                         how_to_fix,
                         expected = NULL,
                         observed = NULL,
                         missing = NULL,
                         unmapped = NULL,
                         details = NULL,
                         module = "TURAS") {

  # TRS GOVERNANCE: why_it_matters is MANDATORY (Patch D)
  if (is.null(why_it_matters) || !nzchar(trimws(why_it_matters))) {
    stop("TRS: why_it_matters is MANDATORY for all refusals. ",
         "Every refusal must explain why the issue matters to users.",
         call. = FALSE)
  }

  # Validate code format
  trs_validate_code(code)

  # Build the refusal message block
  divider <- paste0(rep("=", 80), collapse = "")

  msg <- paste0(
    "\n", divider, "\n",
    "  [REFUSE] ", code, ": ", title, "\n",
    divider, "\n\n"
  )

  # Problem section (mandatory)
  msg <- paste0(msg, "Problem:\n  ", problem, "\n\n")

  # Why it matters section (required by TRS, but allow fallback)
  if (!is.null(why_it_matters)) {
    msg <- paste0(msg, "Why it matters:\n  ", why_it_matters, "\n\n")
  }

  # How to fix section (mandatory)
  msg <- paste0(msg, "How to fix:\n")
  # Support both single string and vector of steps
  if (length(how_to_fix) == 1) {
    msg <- paste0(msg, "  ", how_to_fix, "\n\n")
  } else {
    for (i in seq_along(how_to_fix)) {
      msg <- paste0(msg, "  ", i, ". ", how_to_fix[i], "\n")
    }
    msg <- paste0(msg, "\n")
  }

  # Diagnostics section
  has_diagnostics <- !is.null(expected) || !is.null(observed) ||
                     !is.null(missing) || !is.null(unmapped)

  if (has_diagnostics) {
    msg <- paste0(msg, "Diagnostics:\n")

    if (!is.null(expected)) {
      exp_str <- if (length(expected) > 10) {
        paste0(paste(head(expected, 10), collapse = ", "), " ... (", length(expected), " total)")
      } else if (length(expected) == 0) {
        "(none)"
      } else {
        paste(expected, collapse = ", ")
      }
      msg <- paste0(msg, "  Expected:  ", exp_str, "\n")
    }

    if (!is.null(observed)) {
      obs_str <- if (length(observed) > 10) {
        paste0(paste(head(observed, 10), collapse = ", "), " ... (", length(observed), " total)")
      } else if (length(observed) == 0) {
        "(none)"
      } else {
        paste(observed, collapse = ", ")
      }
      msg <- paste0(msg, "  Observed:  ", obs_str, "\n")
    }

    if (!is.null(missing)) {
      miss_str <- if (length(missing) > 10) {
        paste0(paste(head(missing, 10), collapse = ", "), " ... (", length(missing), " total)")
      } else if (length(missing) == 0) {
        "(none)"
      } else {
        paste(missing, collapse = ", ")
      }
      msg <- paste0(msg, "  Missing:   ", miss_str, "\n")
    }

    if (!is.null(unmapped)) {
      unmap_str <- if (length(unmapped) > 10) {
        paste0(paste(head(unmapped, 10), collapse = ", "), " ... (", length(unmapped), " total)")
      } else if (length(unmapped) == 0) {
        "(none)"
      } else {
        paste(unmapped, collapse = ", ")
      }
      msg <- paste0(msg, "  Unmapped:  ", unmap_str, "\n")
    }

    msg <- paste0(msg, "\n")
  }

  # Additional details
  if (!is.null(details)) {
    msg <- paste0(msg, "Details:\n  ", details, "\n\n")
  }

  msg <- paste0(msg, divider, "\n")

  # Create custom condition for clean handling
  cond <- structure(
    list(
      message = msg,
      code = code,
      title = title,
      problem = problem,
      how_to_fix = how_to_fix,
      expected = expected,
      observed = observed,
      missing = missing,
      unmapped = unmapped,
      module = module,
      call = NULL
    ),
    class = c("turas_refusal", "error", "condition")
  )

  stop(cond)
}


#' Run Expression with Top-Level Refusal Handler
#'
#' Wraps module execution to catch turas_refusal conditions and display
#' them cleanly without a stack trace. This is the standard entry point
#' wrapper for all Turas modules.
#'
#' @param expr Expression to evaluate (typically module main function call)
#' @param module Module name for status tracking
#' @return Result of expression if successful, or a turas_refusal_result
#'         structure if refused
#' @export
with_refusal_handler <- function(expr, module = "TURAS") {
  tryCatch(
    expr,
    turas_refusal = function(e) {
      # Print the refusal message cleanly (no "Error:" prefix, no stack trace)
      cat(conditionMessage(e))

      # Return structured refusal result
      invisible(structure(
        list(
          run_status = "REFUSE",
          refused = TRUE,
          code = e$code,
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
        class = "turas_refusal_result"
      ))
    },
    error = function(e) {
      # Unexpected error - this is a BUG, not a refusal
      divider <- paste0(rep("=", 80), collapse = "")
      msg <- paste0(
        "\n", divider, "\n",
        "  [ERROR] BUG_INTERNAL_ERROR: Unexpected Turas Error\n",
        divider, "\n\n",
        "Problem:\n",
        "  An unexpected error occurred in Turas. This is a bug.\n\n",
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
          module = module
        ),
        class = "turas_error_result"
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
  inherits(result, "turas_refusal_result") && isTRUE(result$refused)
}


#' Check if Result was an Error
#'
#' @param result Result from with_refusal_handler()
#' @return TRUE if an unexpected error occurred
#' @export
is_error <- function(result) {
  inherits(result, "turas_error_result") && isTRUE(result$error)
}


# ==============================================================================
# RUN STATUS MANAGEMENT
# ==============================================================================

#' Create TRS Status Object
#'
#' Creates a structured status object following TRS v1.0 states.
#'
#' @param status One of: "PASS", "PARTIAL", "REFUSE", "ERROR"
#' @param module Module name
#' @param degraded_reasons Character vector of degradation reasons (for PARTIAL)
#' @param affected_outputs Character vector of affected outputs (for PARTIAL)
#' @param details Additional details list
#' @return TRS status object
#' @keywords internal
trs_status <- function(status,
                       module = "TURAS",
                       degraded_reasons = NULL,
                       affected_outputs = NULL,
                       details = NULL) {

  valid_states <- c("PASS", "PARTIAL", "REFUSE", "ERROR")
  if (!status %in% valid_states) {
    stop(paste0("TRS: Invalid status '", status, "'. Must be one of: ",
                paste(valid_states, collapse = ", ")))
  }

  structure(
    list(
      run_status = status,
      module = module,
      degraded_reasons = degraded_reasons,
      affected_outputs = affected_outputs,
      details = details,
      timestamp = Sys.time()
    ),
    class = "trs_status"
  )
}


#' Create PASS Status
#'
#' @param module Module name
#' @return TRS status object with PASS state
#' @export
trs_status_pass <- function(module = "TURAS") {
  trs_status("PASS", module = module)
}


#' Create PARTIAL Status
#'
#' For use when execution continues with declared degradation.
#' PARTIAL outputs must clearly state what is degraded and why.
#'
#' @param module Module name
#' @param degraded_reasons Character vector explaining why output is degraded
#' @param affected_outputs Character vector listing which outputs are affected
#' @return TRS status object with PARTIAL state
#' @export
trs_status_partial <- function(module = "TURAS",
                               degraded_reasons,
                               affected_outputs) {

  if (is.null(degraded_reasons) || length(degraded_reasons) == 0) {
    stop("TRS: PARTIAL status requires at least one degraded_reason")
  }
  if (is.null(affected_outputs) || length(affected_outputs) == 0) {
    stop("TRS: PARTIAL status requires at least one affected_output")
  }

  trs_status("PARTIAL",
             module = module,
             degraded_reasons = degraded_reasons,
             affected_outputs = affected_outputs)
}


#' Create REFUSE Status
#'
#' @param module Module name
#' @param code Refusal code
#' @param reason Refusal reason
#' @return TRS status object with REFUSE state
#' @export
trs_status_refuse <- function(module = "TURAS", code = NULL, reason = NULL) {
  trs_status("REFUSE",
             module = module,
             details = list(code = code, reason = reason))
}


# ==============================================================================
# GUARD STATE TRACKING (Shared Implementation)
# ==============================================================================

#' Initialize Guard State
#'
#' Creates a new guard state object to track warnings and issues during
#' module execution. All modules should use this pattern to collect
#' issues before final status determination.
#'
#' @param module Module name for tracking
#' @return Guard state list
#' @export
guard_init <- function(module = "TURAS") {
  structure(
    list(
      module = module,
      warnings = character(0),
      soft_failures = list(),
      fallback_used = FALSE,
      fallback_reason = NULL,
      stability_flags = character(0),
      data_modifications = list(),
      timestamp = Sys.time()
    ),
    class = "trs_guard_state"
  )
}


#' Add Warning to Guard State
#'
#' @param guard Guard state object
#' @param message Warning message
#' @param category Warning category (for grouping)
#' @return Updated guard state (invisibly)
#' @export
guard_warn <- function(guard, message, category = "general") {
  guard$warnings <- c(guard$warnings, message)
  guard$soft_failures[[category]] <- c(guard$soft_failures[[category]], message)
  invisible(guard)
}


#' Add Stability Flag
#'
#' Records conditions that may affect result stability but don't
#' prevent execution.
#'
#' @param guard Guard state object
#' @param flag Stability flag description
#' @return Updated guard state (invisibly)
#' @export
guard_flag_stability <- function(guard, flag) {
  guard$stability_flags <- unique(c(guard$stability_flags, flag))
  invisible(guard)
}


#' Record Data Modification
#'
#' Records any modifications made to input data (for transparency).
#'
#' @param guard Guard state object
#' @param type Type of modification (e.g., "level_collapse", "missing_impute")
#' @param details Details of the modification
#' @return Updated guard state (invisibly)
#' @export
guard_record_modification <- function(guard, type, details) {
  guard$data_modifications[[type]] <- c(guard$data_modifications[[type]], list(details))
  invisible(guard)
}


#' Get Guard Summary
#'
#' Creates summary of all warnings and flags for output/logging.
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
guard_summary <- function(guard) {
  has_issues <- length(guard$warnings) > 0 ||
                length(guard$stability_flags) > 0 ||
                guard$fallback_used

  list(
    module = guard$module,
    has_issues = has_issues,
    n_warnings = length(guard$warnings),
    warnings = guard$warnings,
    stability_flags = guard$stability_flags,
    fallback_used = guard$fallback_used,
    fallback_reason = guard$fallback_reason,
    use_with_caution = length(guard$stability_flags) > 0,
    data_modifications = guard$data_modifications
  )
}


# ==============================================================================
# MAPPING VALIDATION GATE (TRS v1.0 Hard Requirement)
# ==============================================================================

#' Validate Mapping Coverage (Hard Gate)
#'
#' Performs the mandatory TRS v1.0 mapping validation gate.
#' This function MUST be called after any config-to-model mapping
#' and MUST refuse on any mismatch.
#'
#' Warnings are NEVER sufficient for mapping failures.
#'
#' @param mapping_table Data frame with mapping (must have column specified by `key_col`)
#' @param model_terms Character vector of terms from fitted model
#' @param key_col Column name in mapping_table containing mapped terms
#' @param module Module name for refusal message
#' @param exclude_patterns Character vector of regex patterns for terms to exclude
#'        from validation (e.g., intercepts, thresholds)
#' @param context Additional context for error messages
#'
#' @return TRUE if validation passes, otherwise refuses (never returns FALSE)
#' @export
validate_mapping_coverage <- function(mapping_table,
                                      model_terms,
                                      key_col = "coef_name",
                                      module = "TURAS",
                                      exclude_patterns = c("^\\(Intercept\\)$", "\\|"),
                                      context = NULL) {

  # --- Check 1: Coefficient extraction ---
  if (is.null(model_terms) || length(model_terms) == 0) {
    turas_refuse(
      code = "MODEL_COEF_EXTRACT_FAILED",
      title = "Failed to Extract Model Coefficients",
      problem = "Could not extract coefficient names from the fitted model.",
      why_it_matters = "Without coefficient names, outputs cannot be mapped to predictors.",
      how_to_fix = c(
        "Check that the model fitted successfully",
        "Verify the model type is supported",
        "Check for convergence warnings"
      ),
      details = context,
      module = module
    )
  }

  # --- Check 2: Empty mapping table ---
  if (is.null(mapping_table) || nrow(mapping_table) == 0) {
    turas_refuse(
      code = "MAPPER_EMPTY_MAPPING",
      title = "Empty Mapping Table",
      problem = "The mapping table is empty but model has coefficients.",
      why_it_matters = "Cannot produce valid outputs without mapping coefficients to predictors.",
      how_to_fix = c(
        "Check that predictor variables are correctly specified in config",
        "Verify that variable names in config match data columns",
        "Check that categorical variables have the expected levels"
      ),
      expected = model_terms,
      observed = character(0),
      details = context,
      module = module
    )
  }

  # --- Filter out excluded terms ---
  terms_to_validate <- model_terms
  for (pattern in exclude_patterns) {
    terms_to_validate <- terms_to_validate[!grepl(pattern, terms_to_validate)]
  }

  # --- Get mapped terms ---
  if (!key_col %in% names(mapping_table)) {
    turas_refuse(
      code = "MAPPER_INVALID_KEY_COL",
      title = "Invalid Mapping Table Structure",
      problem = paste0("Mapping table does not contain required column '", key_col, "'."),
      why_it_matters = "Cannot validate mapping without the key column.",
      how_to_fix = c(
        "Ensure mapping table has the correct structure",
        "Check that mapper function returns expected columns"
      ),
      expected = key_col,
      observed = names(mapping_table),
      module = module
    )
  }

  mapped_terms <- mapping_table[[key_col]]

  # --- Check 3: Unmapped coefficients ---
  unmapped <- setdiff(terms_to_validate, mapped_terms)
  if (length(unmapped) > 0) {
    turas_refuse(
      code = "MAPPER_UNMAPPED_COEFFICIENTS",
      title = "Unmapped Model Coefficients",
      problem = paste0(length(unmapped), " coefficient(s) from the model could not be mapped to predictors."),
      why_it_matters = "Unmapped coefficients mean incomplete or incorrect results would be produced.",
      how_to_fix = c(
        "Check that all predictor variables are specified in config",
        "Verify variable names match exactly (case-sensitive)",
        "Check for unexpected factor levels in the data",
        "Review the list of unmapped coefficients below"
      ),
      expected = terms_to_validate,
      observed = mapped_terms,
      unmapped = unmapped,
      details = context,
      module = module
    )
  }

  # --- All checks passed ---
  TRUE
}


# ==============================================================================
# CONSOLE OUTPUT HELPERS (TRS UX Requirements)
# ==============================================================================

#' Display TRS Start Banner
#'
#' Displays the standard module start banner per TRS UX requirements.
#'
#' @param module Module name
#' @param version Module version (optional)
#' @return NULL (called for side effect)
#' @export
trs_banner_start <- function(module, version = NULL) {
  divider <- paste0(rep("=", 80), collapse = "")
  ver_str <- if (!is.null(version)) paste0(" v", version) else ""

  cat("\n", divider, "\n", sep = "")
  cat("  ", toupper(module), ver_str, " - Starting Analysis\n", sep = "")
  cat(divider, "\n\n", sep = "")

  invisible(NULL)
}


#' Display TRS End Banner
#'
#' Displays the standard module completion banner per TRS UX requirements.
#'
#' @param module Module name
#' @param status TRS status object or status string ("PASS", "PARTIAL", "REFUSE", "ERROR")
#' @param duration Duration in seconds (optional)
#' @return NULL (called for side effect)
#' @export
trs_banner_end <- function(module, status, duration = NULL) {
  divider <- paste0(rep("=", 80), collapse = "")

  # Extract status string if object
  status_str <- if (inherits(status, "trs_status")) status$run_status else status

  # Status-specific messaging
  status_display <- switch(status_str,
    "PASS" = "COMPLETED SUCCESSFULLY",
    "PARTIAL" = "COMPLETED WITH WARNINGS (see above)",
    "REFUSE" = "REFUSED TO RUN (see above)",
    "ERROR" = "FAILED WITH ERROR (see above)",
    status_str
  )

  dur_str <- if (!is.null(duration)) {
    paste0(" (", round(duration, 1), " seconds)")
  } else ""

  cat("\n", divider, "\n", sep = "")
  cat("  ", toupper(module), " - ", status_display, dur_str, "\n", sep = "")
  cat(divider, "\n\n", sep = "")

  # For PARTIAL, show degradation details
  if (status_str == "PARTIAL" && inherits(status, "trs_status")) {
    if (!is.null(status$degraded_reasons)) {
      cat("Degraded because:\n")
      for (reason in status$degraded_reasons) {
        cat("  - ", reason, "\n", sep = "")
      }
    }
    if (!is.null(status$affected_outputs)) {
      cat("Affected outputs:\n")
      for (output in status$affected_outputs) {
        cat("  - ", output, "\n", sep = "")
      }
    }
    cat("\n")
  }

  invisible(NULL)
}


#' Display Validation Summary
#'
#' Shows a summary of input validation results.
#'
#' @param checks Named list of check results (TRUE/FALSE or descriptive string)
#' @return NULL (called for side effect)
#' @export
trs_validation_summary <- function(checks) {
  cat("Input Validation:\n")
  for (name in names(checks)) {
    result <- checks[[name]]
    symbol <- if (isTRUE(result)) "[OK]" else if (isFALSE(result)) "[FAIL]" else "[INFO]"
    value <- if (is.logical(result)) "" else paste0(": ", result)
    cat("  ", symbol, " ", name, value, "\n", sep = "")
  }
  cat("\n")

  invisible(NULL)
}


#' Display Data Exclusion Summary
#'
#' Shows summary of any data exclusions applied.
#'
#' @param exclusions Named list of exclusion counts/descriptions
#' @param total_before Total rows before exclusions
#' @param total_after Total rows after exclusions
#' @return NULL (called for side effect)
#' @export
trs_exclusion_summary <- function(exclusions, total_before = NULL, total_after = NULL) {
  cat("Data Exclusions:\n")

  if (!is.null(total_before) && !is.null(total_after)) {
    cat("  Starting rows: ", total_before, "\n", sep = "")
    cat("  Ending rows:   ", total_after, "\n", sep = "")
    cat("  Excluded:      ", total_before - total_after,
        " (", round((total_before - total_after) / total_before * 100, 1), "%)\n", sep = "")
  }

  if (length(exclusions) > 0) {
    cat("  Breakdown:\n")
    for (name in names(exclusions)) {
      cat("    - ", name, ": ", exclusions[[name]], "\n", sep = "")
    }
  }
  cat("\n")

  invisible(NULL)
}


# ==============================================================================
# PATH RESOLUTION (TRS v1.0 - Avoid setwd())
# ==============================================================================

#' Resolve TURAS Project Root
#'
#' Canonical function to find TURAS project root directory. This should be used
#' instead of setwd() to maintain working directory stability in Shiny and
#' multi-run contexts.
#'
#' Resolution order:
#' 1. TURAS_HOME environment variable
#' 2. Current working directory if it contains modules/ folder
#' 3. Parent directories up to 5 levels
#'
#' @return Character string with absolute path to TURAS root
#' @export
turas_resolve_home <- function() {
  # 1. Check environment variable
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(turas_home) &&
      dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }

  # 2. Check current working directory
  wd <- getwd()
  if (dir.exists(file.path(wd, "modules"))) {
    return(normalizePath(wd, mustWork = FALSE))
  }

  # 3. Check parent directories (up to 5 levels)
  check_dir <- wd
  for (i in 1:5) {
    check_dir <- dirname(check_dir)
    if (dir.exists(file.path(check_dir, "modules"))) {
      return(normalizePath(check_dir, mustWork = FALSE))
    }
  }

  # 4. Return current directory as fallback with warning
  warning("Could not resolve TURAS_HOME. Using current working directory.")
  return(normalizePath(wd, mustWork = FALSE))
}


#' Resolve Path Relative to TURAS Root
#'
#' Creates an absolute path from a path relative to TURAS root.
#' Use this instead of setwd() + relative paths.
#'
#' @param relative_path Character. Path relative to TURAS root
#' @param must_exist Logical. If TRUE, refuses if path doesn't exist
#' @return Character string with absolute path
#' @export
turas_path <- function(relative_path, must_exist = FALSE) {
  root <- turas_resolve_home()
  abs_path <- normalizePath(file.path(root, relative_path), mustWork = FALSE)

  if (must_exist && !file.exists(abs_path)) {
    turas_refuse(
      code = "IO_PATH_NOT_FOUND",
      title = "Required Path Not Found",
      problem = paste0("Path '", relative_path, "' does not exist."),
      why_it_matters = "Required file or directory is missing.",
      how_to_fix = c(
        paste0("Check that '", relative_path, "' exists in your project"),
        paste0("Full path checked: ", abs_path)
      ),
      missing = abs_path
    )
  }

  return(abs_path)
}


#' Resolve Module Path
#'
#' Creates an absolute path within a specific module.
#'
#' @param module Character. Module name (e.g., "tabs", "keydriver")
#' @param relative_path Character. Path relative to module directory
#' @return Character string with absolute path
#' @export
turas_module_path <- function(module, relative_path = "") {
  root <- turas_resolve_home()
  module_root <- file.path(root, "modules", module)

  if (nzchar(relative_path)) {
    return(normalizePath(file.path(module_root, relative_path), mustWork = FALSE))
  }
  return(normalizePath(module_root, mustWork = FALSE))
}


# ==============================================================================
# BACKWARD COMPATIBILITY SUPPORT
# ==============================================================================
# These aliases support modules that may have been using older function names.
# New code should use the turas_* functions directly.

#' @rdname turas_refuse
#' @export
trs_refuse <- turas_refuse

#' @rdname with_refusal_handler
#' @export
trs_with_handler <- with_refusal_handler
