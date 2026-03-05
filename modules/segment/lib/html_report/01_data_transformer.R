# ==============================================================================
# SEGMENT HTML REPORT - DATA TRANSFORMER
# ==============================================================================
# Transforms raw segmentation results into a flat structure for HTML rendering.
# Pure data transformation - no HTML in this file.
# Version: 11.0
# ==============================================================================


#' Transform Segmentation Results for HTML Report
#'
#' @param results List with segmentation results
#' @param config Configuration list
#' @return Flat list of data ready for table/chart builders
#' @keywords internal
transform_segment_for_html <- function(results, config) {

  mode <- results$mode %||% "final"

  if (mode == "final") {
    transform_final_for_html(results, config)
  } else {
    transform_exploration_for_html(results, config)
  }
}


#' Transform Final Mode Results
#' @keywords internal
transform_final_for_html <- function(results, config) {

  cr <- results$cluster_result
  vm <- results$validation_metrics
  pr <- results$profile_result
  sn <- results$segment_names
  k <- cr$k
  method <- cr$method %||% config$method %||% "kmeans"
  clusters <- cr$clusters
  n_obs <- length(clusters)

  # Segment sizes
  seg_table <- table(clusters)
  segment_sizes <- data.frame(
    segment_id = as.integer(names(seg_table)),
    segment_name = sn[as.integer(names(seg_table))],
    n = as.integer(seg_table),
    pct = round(as.numeric(seg_table) / n_obs * 100, 1),
    stringsAsFactors = FALSE
  )

  # Profile data (means per segment per variable)
  profile_data <- NULL
  if (!is.null(pr$clustering_profile)) {
    profile_data <- pr$clustering_profile
  }

  # Variable importance (eta-squared from ANOVA)
  variable_importance <- NULL
  if (!is.null(profile_data)) {
    vi <- .extract_variable_importance(profile_data)
    if (!is.null(vi)) variable_importance <- vi
  }

  # Validation diagnostics
  diagnostics <- list(
    method = method,
    k = k,
    n_observations = n_obs,
    n_variables = ncol(cr$centers),
    avg_silhouette = vm$avg_silhouette %||% NA_real_,
    betweenss_totss = vm$betweenss_totss %||% NA_real_,
    tot_withinss = vm$tot_withinss %||% NA_real_,
    betweenss = vm$betweenss %||% NA_real_
  )

  # Method-specific info
  method_info <- cr$method_info %||% list()

  # Silhouette per cluster
  sil_per_cluster <- vm$sil_per_cluster %||% NULL

  # Enhanced features
  enhanced <- results$enhanced %||% list()

  # Executive summary
  exec_summary <- results$exec_summary %||% NULL

  # GMM membership
  gmm_membership <- results$gmm_membership %||% NULL

  # Question labels
  question_labels <- config$question_labels %||% NULL

  list(
    mode = "final",
    analysis_name = config$report_title %||% config$project_name %||% "Segmentation Analysis",
    method = method,
    k = k,
    n_observations = n_obs,
    segment_sizes = segment_sizes,
    segment_names = sn,
    profile_data = profile_data,
    variable_importance = variable_importance,
    diagnostics = diagnostics,
    method_info = method_info,
    sil_per_cluster = sil_per_cluster,
    centers = cr$centers,
    exec_summary = exec_summary,
    enhanced = enhanced,
    gmm_membership = gmm_membership,
    question_labels = question_labels,
    config = config,
    run_status = "PASS"
  )
}


#' Transform Exploration Mode Results
#' @keywords internal
transform_exploration_for_html <- function(results, config) {

  er <- results$exploration_result
  mr <- results$metrics_result
  rec <- results$recommendation
  method <- er$method %||% config$method %||% "kmeans"

  # Metrics data frame
  metrics_df <- mr$metrics_df

  # Per-k results summary
  k_summaries <- list()
  for (k_str in names(er$results)) {
    res_k <- er$results[[k_str]]
    k_val <- as.integer(k_str)
    seg_table <- table(res_k$clusters)

    k_summaries[[k_str]] <- list(
      k = k_val,
      sizes = as.integer(seg_table),
      pcts = round(as.numeric(seg_table) / length(res_k$clusters) * 100, 1),
      silhouette = res_k$method_info$avg_silhouette %||% NA_real_,
      tot_withinss = res_k$method_info$tot_withinss %||% NA_real_
    )
  }

  list(
    mode = "exploration",
    analysis_name = config$report_title %||% config$project_name %||% "K Selection Analysis",
    method = method,
    k_range = er$k_range,
    n_successful = er$n_successful,
    metrics_df = metrics_df,
    k_summaries = k_summaries,
    recommendation = rec,
    question_labels = config$question_labels %||% NULL,
    config = config,
    run_status = "PASS"
  )
}


#' Extract Variable Importance from Profile Data
#' @keywords internal
.extract_variable_importance <- function(profile_data) {

  # Look for eta-squared or F-statistic
  eta_col <- NULL
  f_col <- NULL

  for (col in c("eta_sq", "eta_squared", "Eta_Sq", "Eta_Squared")) {
    if (col %in% names(profile_data)) { eta_col <- col; break }
  }
  for (col in c("F_statistic", "F_stat", "f_stat", "F")) {
    if (col %in% names(profile_data)) { f_col <- col; break }
  }

  sort_col <- eta_col %||% f_col
  if (is.null(sort_col)) return(NULL)

  valid <- !is.na(profile_data[[sort_col]])
  if (sum(valid) == 0) return(NULL)

  df <- profile_data[valid, , drop = FALSE]
  df <- df[order(-df[[sort_col]]), , drop = FALSE]

  result <- data.frame(
    variable = df$Variable,
    stringsAsFactors = FALSE
  )

  if (!is.null(eta_col)) {
    result$eta_squared <- round(df[[eta_col]], 4)
  }
  if (!is.null(f_col)) {
    result$f_statistic <- round(df[[f_col]], 2)
  }

  # Add rank
  result$rank <- seq_len(nrow(result))

  # Calculate importance percentage (normalized eta-squared)
  if (!is.null(eta_col)) {
    total_eta <- sum(result$eta_squared, na.rm = TRUE)
    if (total_eta > 0) {
      result$importance_pct <- round(result$eta_squared / total_eta * 100, 1)
    }
  }

  result
}
