# ==============================================================================
# SEGMENT - TRS GUARD LAYER
# ==============================================================================
#
# TRS v1.0 integration for the Segmentation module.
# Implements refusal, guard state, and validation gates per TRS standard.
#
# This module provides:
#   - segment_refuse() - module-specific refusal wrapper
#   - segment_with_refusal_handler() - wraps main analysis with TRS handling
#   - segment_guard_init() - initialize guard state with segment-specific fields
#   - Validation helpers for segment-specific requirements
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
    file.path(dirname(sys.frame(1)$ofile), "../../shared/lib/trs_refusal.R"),
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
# SEGMENT-SPECIFIC REFUSAL WRAPPER
# ==============================================================================

#' Refuse to Run with TRS-Compliant Message (Segment)
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
segment_refuse <- function(code,
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
    module = "SEGMENT"
  )
}


#' Run Segment Analysis with Refusal Handler
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
#' @return Guard state list
#' @export
segment_guard_init <- function() {
  guard <- guard_init(module = "SEGMENT")

  # Add Segment-specific fields
  guard$dropped_variables <- character(0)
  guard$low_variance_variables <- character(0)
  guard$cluster_stability <- list()
  guard$outliers_removed <- 0
  guard$clustering_method <- NULL

  guard
}


#' Record Dropped Variable
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param reason Reason for dropping
#' @return Updated guard state
#' @keywords internal
guard_record_dropped_variable <- function(guard, variable, reason) {
  guard$dropped_variables <- c(guard$dropped_variables, variable)
  guard <- guard_warn(guard, paste0("Dropped variable: ", variable, " (", reason, ")"), "dropped")
  guard
}


#' Record Low Variance Variable
#'
#' @param guard Guard state object
#' @param variable Variable name
#' @param variance Variance value
#' @return Updated guard state
#' @keywords internal
guard_record_low_variance <- function(guard, variable, variance) {
  guard$low_variance_variables <- c(guard$low_variance_variables, variable)
  guard <- guard_flag_stability(guard, paste0("Low variance: ", variable, " (var=", round(variance, 4), ")"))
  guard
}


#' Record Cluster Stability Metrics
#'
#' @param guard Guard state object
#' @param k Number of clusters
#' @param silhouette Silhouette score
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
    guard <- guard_flag_stability(guard, paste0("Low cluster quality: silhouette=", round(silhouette, 3)))
  }

  guard
}


#' Get Segment Guard Summary
#'
#' @param guard Guard state object
#' @return List with summary info
#' @export
segment_guard_summary <- function(guard) {
  summary <- guard_summary(guard)

  summary$dropped_variables <- guard$dropped_variables
  summary$low_variance_variables <- guard$low_variance_variables
  summary$cluster_stability <- guard$cluster_stability
  summary$outliers_removed <- guard$outliers_removed
  summary$clustering_method <- guard$clustering_method

  summary$has_issues <- summary$has_issues ||
                        length(guard$dropped_variables) > 0 ||
                        length(guard$low_variance_variables) > 0

  summary
}


# ==============================================================================
# SEGMENT VALIDATION GATES
# ==============================================================================

#' Validate Segment Configuration
#'
#' @param config Configuration list
#' @keywords internal
validate_segment_config <- function(config) {

  if (!is.list(config)) {
    segment_refuse(
      code = "CFG_INVALID_TYPE",
      title = "Invalid Configuration Format",
      problem = "Configuration must be a list.",
      why_it_matters = "Analysis cannot proceed without properly structured configuration.",
      how_to_fix = "Ensure config file was loaded correctly."
    )
  }

  invisible(TRUE)
}


#' Validate Segment Variables
#'
#' @param variables Character vector of variable names
#' @param data Survey data
#' @keywords internal
validate_segment_variables <- function(variables, data) {

  if (is.null(variables) || length(variables) == 0) {
    segment_refuse(
      code = "CFG_NO_VARIABLES",
      title = "No Segmentation Variables Specified",
      problem = "No variables were specified for segmentation.",
      why_it_matters = "Segmentation requires variables to cluster respondents.",
      how_to_fix = c(
        "Open your config file",
        "Specify which variables to use for segmentation",
        "Choose variables that differentiate respondent groups"
      )
    )
  }

  if (length(variables) < 2) {
    segment_refuse(
      code = "CFG_INSUFFICIENT_VARIABLES",
      title = "Insufficient Variables for Segmentation",
      problem = paste0("Only ", length(variables), " variable specified. Need at least 2."),
      why_it_matters = "Meaningful segmentation requires multiple variables to find patterns.",
      how_to_fix = "Add more segmentation variables to your configuration."
    )
  }

  # Check variables exist in data
  missing_vars <- setdiff(variables, names(data))
  if (length(missing_vars) > 0) {
    segment_refuse(
      code = "DATA_VARIABLES_NOT_FOUND",
      title = "Segmentation Variables Not Found in Data",
      problem = paste0(length(missing_vars), " variable(s) not found in data."),
      why_it_matters = "Cannot segment on variables that don't exist in the data.",
      how_to_fix = c(
        "Check variable names match data column names exactly",
        "Variable names are case-sensitive"
      ),
      expected = variables,
      observed = names(data),
      missing = missing_vars
    )
  }

  invisible(TRUE)
}


#' Validate Sample Size for Clustering
#'
#' @param n_cases Number of complete cases
#' @param n_clusters Target number of clusters
#' @param n_variables Number of variables
#' @keywords internal
validate_segment_sample_size <- function(n_cases, n_clusters, n_variables) {

  min_per_cluster <- 30
  min_total <- max(100, n_clusters * min_per_cluster, n_variables * 10)

  if (n_cases < min_total) {
    segment_refuse(
      code = "DATA_INSUFFICIENT_SAMPLE",
      title = "Insufficient Sample Size for Segmentation",
      problem = paste0("Only ", n_cases, " complete cases. Need at least ", min_total, "."),
      why_it_matters = "Small samples produce unstable cluster solutions that won't replicate.",
      how_to_fix = c(
        "Increase sample size",
        "Reduce number of clusters",
        "Reduce number of segmentation variables",
        "Address missing data issues"
      ),
      details = paste0(
        "Complete cases: ", n_cases, "\n",
        "Required minimum: ", min_total, "\n",
        "Target clusters: ", n_clusters, "\n",
        "Variables: ", n_variables
      )
    )
  }

  invisible(TRUE)
}


#' Validate Cluster Solution
#'
#' @param cluster_result Clustering result
#' @param min_cluster_size Minimum acceptable cluster size
#' @keywords internal
validate_cluster_solution <- function(cluster_result, min_cluster_size = 10) {

  if (is.null(cluster_result) || is.null(cluster_result$cluster)) {
    segment_refuse(
      code = "MODEL_CLUSTER_FAILED",
      title = "Clustering Algorithm Failed",
      problem = "The clustering algorithm did not produce a valid solution.",
      why_it_matters = "Cannot assign respondents to segments without a cluster solution.",
      how_to_fix = c(
        "Check data for extreme outliers",
        "Try a different number of clusters",
        "Try a different clustering method",
        "Check for constant or near-constant variables"
      )
    )
  }

  # Check cluster sizes
  cluster_sizes <- table(cluster_result$cluster)
  small_clusters <- names(cluster_sizes)[cluster_sizes < min_cluster_size]

  if (length(small_clusters) > 0) {
    segment_refuse(
      code = "MODEL_CLUSTER_UNSTABLE",
      title = "Cluster Solution is Unstable",
      problem = paste0(length(small_clusters), " cluster(s) have fewer than ", min_cluster_size, " members."),
      why_it_matters = "Very small clusters are unreliable and may not represent real segments.",
      how_to_fix = c(
        "Reduce the number of clusters",
        "Remove outliers before clustering",
        "Check if data has natural groupings"
      ),
      details = paste0("Cluster sizes: ", paste(paste(names(cluster_sizes), "=", cluster_sizes), collapse = ", "))
    )
  }

  invisible(TRUE)
}


# ==============================================================================
# TRS STATUS HELPERS
# ==============================================================================

#' Create Segment PASS Status
#'
#' @param n_clusters Number of clusters created
#' @param n_cases Number of cases assigned
#' @return TRS status object
#' @export
segment_status_pass <- function(n_clusters = NULL, n_cases = NULL) {
  status <- trs_status_pass(module = "SEGMENT")
  status$details <- list(
    clusters = n_clusters,
    cases_assigned = n_cases
  )
  status
}


#' Create Segment PARTIAL Status
#'
#' @param degraded_reasons Character vector of degradation reasons
#' @param affected_outputs Character vector of affected outputs
#' @param dropped_variables Character vector of dropped variable names
#' @return TRS status object
#' @export
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
