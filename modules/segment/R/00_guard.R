# ==============================================================================
# SEGMENT MODULE - TRS GUARD FRAMEWORK
# ==============================================================================
# TRS v1.1 guard layer for the Segmentation module.
#
# Provides:
#   - segment_refuse()              - Module-specific refusal wrapper
#   - segment_with_refusal_handler() - Wraps main analysis with TRS handling
#   - segment_guard_init()          - Initialize guard state
#   - segment_guard_summary()       - Get guard summary
#   - segment_determine_status()    - Determine final PASS/PARTIAL status
#   - Guard record helpers for segment-specific tracking
#
# Hard guards (REFUSE) are in 00a_guards_hard.R
# Soft guards (PARTIAL) are in 00b_guards_soft.R
#
# Version: 2.0 (TRS v1.1 Integration)
# ==============================================================================


# ==============================================================================
# SOURCE SHARED TRS INFRASTRUCTURE
# ==============================================================================

if (!exists("turas_refuse", mode = "function")) {
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  trs_path <- file.path(turas_root, "modules/shared/lib/trs_refusal.R")
  if (file.exists(trs_path)) {
    source(trs_path)
  } else {
    cat("\n=== TURAS SEGMENT ERROR ===\n")
    cat("Cannot find TRS infrastructure at:", trs_path, "\n")
    cat("Ensure TURAS_ROOT is set correctly.\n")
    cat("===========================\n\n")
    stop("[SEGMENT] Cannot find TRS infrastructure at: ", trs_path, call. = FALSE)
  }
}


# ==============================================================================
# SEGMENT-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Segment)
#'
#' Wrapper around shared turas_refuse() with SEGMENT module tagging.
#' All refusal codes must use standard TRS prefixes.
#'
#' @param code Refusal code (e.g., "CFG_NO_VARIABLES", "DATA_INSUFFICIENT")
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
segment_refuse <- function(code,
                           title,
                           problem,
                           why_it_matters,
                           how_to_fix,
                           expected = NULL,
                           observed = NULL,
                           missing = NULL,
                           details = NULL) {

  # Validate TRS prefix
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
    module = "SEGMENT"
  )
}


#' Run Segment Analysis with Refusal Handler
#'
#' Wraps segment analysis expression with TRS refusal handling.
#' Catches turas_refusal exceptions and returns clean result objects.
#'
#' @param expr Expression to evaluate
#' @return Result or refusal/error object
#' @export
segment_with_refusal_handler <- function(expr) {
  result <- with_refusal_handler(expr, module = "SEGMENT")

  if (inherits(result, "turas_refusal_result")) {
    class(result) <- c("segment_refusal_result", class(result))
  }

  result
}


# ==============================================================================
# SEGMENT GUARD STATE
# ==============================================================================

#' Initialize Segment Guard State
#'
#' Creates a guard state object with segment-specific tracking fields.
#' The guard state accumulates warnings and stability flags throughout
#' the analysis pipeline for final status determination.
#'
#' @return Guard state list with segment-specific fields
#' @export
segment_guard_init <- function() {
  guard <- guard_init(module = "SEGMENT")

  # Segment-specific tracking fields
  guard$dropped_variables <- character(0)
  guard$low_variance_variables <- character(0)
  guard$cluster_stability <- list()
  guard$outliers_removed <- 0
  guard$clustering_method <- NULL
  guard$imputed_variables <- character(0)
  guard$variables_selected <- FALSE
  guard$original_var_count <- 0
  guard$final_var_count <- 0


  guard
}


#' Record Dropped Variable in Guard State
#'
#' @param guard Guard state object
#' @param variable Variable name that was dropped
#' @param reason Reason for dropping
#' @return Updated guard state
#' @keywords internal
guard_record_dropped_variable <- function(guard, variable, reason) {
  guard$dropped_variables <- c(guard$dropped_variables, variable)
  guard <- guard_warn(guard, paste0("Dropped variable: ", variable, " (", reason, ")"),
                      category = "dropped")
  guard
}


#' Record Low Variance Variable in Guard State
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param variance Variance value
#' @return Updated guard state
#' @keywords internal
guard_record_low_variance <- function(guard, variable, variance) {
  guard$low_variance_variables <- c(guard$low_variance_variables, variable)
  guard <- guard_flag_stability(guard,
    paste0("Low variance: ", variable, " (var=", round(variance, 4), ")"))
  guard
}


#' Record Cluster Stability Metrics in Guard State
#'
#' @param guard Guard state object
#' @param k Number of clusters
#' @param silhouette Average silhouette score
#' @param within_ss Within-cluster sum of squares
#' @return Updated guard state
#' @keywords internal
guard_record_cluster_stability <- function(guard, k, silhouette, within_ss) {
  guard$cluster_stability <- list(
    k = k,
    silhouette = silhouette,
    within_ss = within_ss
  )

  if (!is.null(silhouette) && silhouette < 0.25) {
    guard <- guard_flag_stability(guard,
      paste0("Low cluster quality: silhouette=", round(silhouette, 3)))
  }

  guard
}


#' Record Imputed Variable in Guard State
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param method Imputation method used
#' @return Updated guard state
#' @keywords internal
guard_record_imputation <- function(guard, variable, method) {
  guard$imputed_variables <- c(guard$imputed_variables, variable)
  guard <- guard_warn(guard,
    paste0("Imputed missing values: ", variable, " (", method, ")"),
    category = "imputation")
  guard
}


#' Record Outlier Removal Count in Guard State
#'
#' @param guard Guard state object
#' @param n_removed Number of outliers removed
#' @return Updated guard state
#' @keywords internal
guard_record_outliers_removed <- function(guard, n_removed) {
  guard$outliers_removed <- guard$outliers_removed + n_removed
  if (n_removed > 0) {
    guard <- guard_warn(guard,
      paste0(n_removed, " outlier(s) removed from clustering"),
      category = "outliers")
  }
  guard
}


# ==============================================================================
# GUARD SUMMARY & STATUS
# ==============================================================================

#' Get Segment Guard Summary
#'
#' @param guard Guard state object
#' @return List with comprehensive summary
#' @export
segment_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  # Add segment-specific fields
  summary$dropped_variables <- guard$dropped_variables
  summary$low_variance_variables <- guard$low_variance_variables
  summary$cluster_stability <- guard$cluster_stability
  summary$outliers_removed <- guard$outliers_removed
  summary$clustering_method <- guard$clustering_method
  summary$imputed_variables <- guard$imputed_variables

  summary$has_issues <- summary$has_issues ||
                        length(guard$dropped_variables) > 0 ||
                        length(guard$low_variance_variables) > 0

  summary
}


#' Determine Final Run Status from Guard State
#'
#' Analyzes guard state to determine PASS or PARTIAL status.
#' REFUSE is handled via segment_refuse() throwing, not here.
#'
#' @param guard Guard state object from segment_guard_init()
#' @param clusters_created Number of clusters successfully created
#' @param cases_assigned Number of cases assigned to clusters
#' @param silhouette_score Average silhouette score
#' @return TRS status object (PASS or PARTIAL)
#' @export
segment_determine_status <- function(guard,
                                     clusters_created = NULL,
                                     cases_assigned = NULL,
                                     silhouette_score = NULL) {

  summary <- segment_guard_summary(guard)

  degraded_reasons <- character(0)
  affected_outputs <- character(0)

  # Check dropped variables
  if (length(summary$dropped_variables) > 0) {
    degraded_reasons <- c(degraded_reasons,
      sprintf("%d variable(s) dropped during processing", length(summary$dropped_variables)))
    affected_outputs <- c(affected_outputs, "cluster_centers", "variable_profiles")
  }

  # Check low variance
  if (length(summary$low_variance_variables) > 0) {
    degraded_reasons <- c(degraded_reasons,
      sprintf("%d variable(s) have low variance", length(summary$low_variance_variables)))
    affected_outputs <- c(affected_outputs, "cluster_separation")
  }

  # Check outliers removed
  if (!is.null(summary$outliers_removed) && summary$outliers_removed > 0) {
    degraded_reasons <- c(degraded_reasons,
      sprintf("%d outlier(s) removed from clustering", summary$outliers_removed))
    affected_outputs <- c(affected_outputs, "segment_assignments")
  }

  # Check imputed variables
  if (length(summary$imputed_variables) > 0) {
    degraded_reasons <- c(degraded_reasons,
      sprintf("%d variable(s) had missing values imputed", length(summary$imputed_variables)))
    affected_outputs <- c(affected_outputs, "cluster_centers")
  }

  # Check cluster quality
  if (!is.null(silhouette_score) && silhouette_score < 0.25) {
    degraded_reasons <- c(degraded_reasons,
      sprintf("Low cluster quality (silhouette=%.3f, threshold=0.25)", silhouette_score))
    affected_outputs <- c(affected_outputs, "segment_interpretability")
  }

  # Check stability flags
  if (length(summary$stability_flags) > 0) {
    degraded_reasons <- c(degraded_reasons, summary$stability_flags)
    affected_outputs <- c(affected_outputs, "result_stability")
  }

  # Determine final status
  if (length(degraded_reasons) > 0) {
    status <- segment_status_partial(
      degraded_reasons = unique(degraded_reasons),
      affected_outputs = unique(affected_outputs),
      dropped_variables = summary$dropped_variables
    )
  } else {
    status <- segment_status_pass(
      n_clusters = clusters_created,
      n_cases = cases_assigned
    )
  }

  # Add silhouette to details
  if (!is.null(silhouette_score)) {
    if (is.null(status$details)) status$details <- list()
    status$details$silhouette_score <- silhouette_score
  }

  status
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create Segment PASS Status
#' @param n_clusters Number of clusters created
#' @param n_cases Number of cases assigned
#' @return TRS status object
#' @keywords internal
segment_status_pass <- function(n_clusters = NULL, n_cases = NULL) {
  status <- trs_status_pass(module = "SEGMENT")
  status$details <- list(clusters = n_clusters, cases_assigned = n_cases)
  status
}


#' Create Segment PARTIAL Status
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param dropped_variables Character vector of dropped variable names
#' @return TRS status object
#' @keywords internal
segment_status_partial <- function(degraded_reasons,
                                   affected_outputs,
                                   dropped_variables = NULL) {
  status <- trs_status_partial(
    module = "SEGMENT",
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
  if (!is.null(dropped_variables) && length(dropped_variables) > 0) {
    status$details <- list(dropped_variables = dropped_variables)
  }
  status
}


#' Create Segment REFUSE Status
#' @param code Refusal code
#' @param reason Human-readable reason
#' @return TRS status object
#' @keywords internal
segment_status_refuse <- function(code = NULL, reason = NULL) {
  trs_status_refuse(module = "SEGMENT", code = code, reason = reason)
}


# ==============================================================================
# GUI OUTCOME CLASSIFICATION
# ==============================================================================
# turas_segment_from_config() runs under a refusal handler, so a refusal is
# CAUGHT and RETURNED rather than thrown. Anything deciding whether a run
# worked must therefore look at what came back, not at whether an error was
# raised. The Shiny GUI did the latter and called every refusal a success
# (V2 lift review 2026-07-11, H1).

#' Classify What a Segment Run Returned
#'
#' @param result The value returned by turas_segment_from_config()
#' @return A list with:
#'   \item{success}{TRUE only for a real result}
#'   \item{status}{"PASS", "REFUSED" or "ERROR"}
#'   \item{code}{TRS code, empty for a pass}
#'   \item{title}{Short heading for the UI}
#'   \item{problem}{What went wrong}
#'   \item{how_to_fix}{Character vector of remedies}
#'   \item{message}{Full text, for the console}
#'   \item{result}{The original object}
#' @export
segment_gui_outcome <- function(result) {

  blank <- function(x, fallback = "") {
    if (is.null(x) || length(x) == 0) return(fallback)
    if (is.logical(x)) return(fallback)
    as.character(x)
  }

  # The engine returns its verdict as `status` (00_main.R, the final and
  # exploration return lists); the refusal handler's structure calls it
  # `run_status`. Read both. Reading only `run_status` classified every
  # PARTIAL run as a clean PASS (independent review 2026-09-21, F12).
  verdict <- toupper(blank(result$status %||% result$run_status)[1])

  is_refusal_shaped <- inherits(result, "turas_refusal_result") ||
    isTRUE(result$refused) ||
    identical(verdict, "REFUSE")

  is_error_shaped <- inherits(result, "turas_error_result") ||
    identical(verdict, "ERROR")

  is_partial_shaped <- identical(verdict, "PARTIAL")

  if (is.null(result) || !is.list(result)) {
    return(list(
      success = FALSE, status = "ERROR", code = "BUG_NO_RESULT",
      title = "The run returned nothing",
      problem = "The segmentation returned no result object at all.",
      how_to_fix = "Read the console output above. This is a bug; report it.",
      message = "The segmentation returned no result object at all.",
      result = result
    ))
  }

  if (is_refusal_shaped) {
    return(list(
      success = FALSE,
      status = "REFUSED",
      code = blank(result$code, "CFG_REFUSED"),
      title = blank(result$title, "Analysis refused"),
      problem = paste(blank(result$problem, "The run was refused."), collapse = " "),
      how_to_fix = blank(result$how_to_fix, "Read the console output above."),
      message = blank(result$message, blank(result$problem)),
      result = result
    ))
  }

  if (is_error_shaped) {
    return(list(
      success = FALSE,
      status = "ERROR",
      code = blank(result$code, "BUG_INTERNAL_ERROR"),
      title = blank(result$title, "Unexpected error"),
      problem = paste(blank(result$message, "An unexpected error occurred."), collapse = " "),
      how_to_fix = c("Read the console output above.",
                     "This is a bug rather than a configuration problem. Report it."),
      message = paste(blank(result$message, "An unexpected error occurred."), collapse = " "),
      result = result
    ))
  }

  if (is_partial_shaped) {
    reasons <- segment_gui_partial_reasons(result)
    return(list(
      success = TRUE,
      status = "PARTIAL",
      code = "QUALITY_DEGRADED",
      title = sprintf("Analysis completed with %d warning(s)", length(reasons)),
      problem = paste(reasons, collapse = " "),
      how_to_fix = c(
        "Read the warnings above and the Run_Status sheet of the Excel report.",
        "Decide whether the solution is usable before it is reported."
      ),
      message = paste(reasons, collapse = "\n"),
      warnings = reasons,
      result = result
    ))
  }

  list(
    success = TRUE, status = "PASS", code = "", title = "Analysis complete",
    problem = "", how_to_fix = character(0), message = "", warnings = character(0),
    result = result
  )
}


#' The Reasons a Run Came Back PARTIAL
#'
#' Read from the TRS run state's PARTIAL events first, then from the guard
#' summary's warnings, so the GUI can name them instead of announcing a clean
#' success over a degraded solution.
#'
#' @param result The engine's result list
#' @return Character vector, never empty
#' @keywords internal
segment_gui_partial_reasons <- function(result) {
  reasons <- character(0)

  events <- result$run_result$events
  if (is.list(events) && length(events) > 0) {
    for (ev in events) {
      if (!is.list(ev)) next
      if (!identical(toupper(as.character(ev$level %||% "")), "PARTIAL")) next
      txt <- as.character(ev$problem %||% ev$title %||% "")
      if (length(txt) > 0 && nzchar(txt[1])) reasons <- c(reasons, txt[1])
    }
  }

  if (length(reasons) == 0) {
    gw <- result$guard_summary$warnings
    if (!is.null(gw) && length(gw) > 0) reasons <- as.character(unlist(gw))
  }

  reasons <- unique(reasons[nzchar(reasons)])
  if (length(reasons) == 0) {
    reasons <- "The run reported PARTIAL without naming a reason. Read the Run_Status sheet."
  }
  reasons
}


#' What the Stats-pack Checkbox Should Start As
#'
#' The GUI writes the checkbox into an option on every run, and the option
#' wins over the config (segment_should_write_stats_pack). With the box
#' always starting unticked, the config's generate_stats_pack was never
#' consulted from the GUI (independent review 2026-09-21, F5). The box now
#' starts as the study's setting and a click overrides it for that run.
#'
#' @param config_file Path to the config workbook, or NULL
#' @return TRUE unless the config says generate_stats_pack = N
#' @export
segment_gui_stats_pack_default <- function(config_file) {
  if (is.null(config_file) || !nzchar(config_file) || !file.exists(config_file)) return(TRUE)
  value <- tryCatch({
    raw <- read_segment_config(config_file)
    toupper(trimws(as.character(raw$generate_stats_pack %||% "Y")))
  }, error = function(e) "Y")
  !identical(value, "N")
}


#' Print a Refusal or Error Where a Shiny User Will Find It
#'
#' Turas runs behind a Shiny app and its users debug from the console the app
#' was launched in, so a refusal has to be legible there and not only in the
#' browser (project CLAUDE.md).
#'
#' @param outcome The list returned by segment_gui_outcome()
#' @return invisible(NULL)
#' @export
segment_gui_console_block <- function(outcome) {
  if (identical(outcome$status, "PARTIAL")) {
    line <- strrep("-", 74)
    cat("\n", line, "\n", sep = "")
    cat("  SEGMENT PARTIAL: analysis completed with warnings\n")
    cat(line, "\n", sep = "")
    for (w in outcome$warnings %||% character(0)) cat(sprintf("  - %s\n", w))
    cat(line, "\n\n", sep = "")
    return(invisible(NULL))
  }
  if (isTRUE(outcome$success)) return(invisible(NULL))

  line <- strrep("-", 74)
  cat("\n", line, "\n", sep = "")
  cat(sprintf("  SEGMENT %s\n", outcome$status))
  cat(line, "\n", sep = "")
  cat(sprintf("  Code:    %s\n", outcome$code))
  cat(sprintf("  Title:   %s\n", outcome$title))
  cat(sprintf("  Problem: %s\n", outcome$problem))
  if (length(outcome$how_to_fix) > 0 && nzchar(outcome$how_to_fix[1])) {
    cat("  How to fix:\n")
    for (fix in outcome$how_to_fix) cat(sprintf("    - %s\n", fix))
  }
  cat(line, "\n\n", sep = "")
  invisible(NULL)
}
