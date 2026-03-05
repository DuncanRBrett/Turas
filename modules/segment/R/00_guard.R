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
    stop("[SEGMENT] Cannot find TRS infrastructure at: ", trs_path)
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
