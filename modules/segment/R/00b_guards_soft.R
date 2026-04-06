# ==============================================================================
# SEGMENT MODULE - SOFT GUARDS (PARTIAL) + GUARD ORCHESTRATORS
# ==============================================================================
# Data quality checks that produce warnings and PARTIAL status.
# These do NOT halt execution - they update the guard state and continue.
#
# Also provides orchestrator functions that collect guards into
# pre-analysis and post-clustering phases (mirroring catdriver pattern).
#
# Convention: guard_check_*() = soft guard (warn, continue)
# ==============================================================================


#' Soft Guard: Check for Low Variance Variables
#'
#' Variables with near-zero variance contribute little to clustering.
#'
#' @param data Data frame (clustering variables only)
#' @param guard Guard state object
#' @param threshold Minimum variance threshold (default 0.01)
#' @return Updated guard state
#' @keywords internal
guard_check_low_variance <- function(data, guard, threshold = 0.01) {
  for (v in names(data)) {
    if (is.numeric(data[[v]])) {
      v_var <- var(data[[v]], na.rm = TRUE)
      if (!is.na(v_var) && v_var < threshold) {
        guard <- guard_record_low_variance(guard, v, v_var)
      }
    }
  }
  guard
}


#' Soft Guard: Check Cluster Sizes
#'
#' Warns about small or imbalanced clusters.
#'
#' @param clusters Integer vector of cluster assignments
#' @param guard Guard state object
#' @param min_pct Minimum acceptable percentage per cluster (default 5)
#' @return Updated guard state
#' @keywords internal
guard_check_small_clusters <- function(clusters, guard, min_pct = 5) {
  n_total <- length(clusters)
  cluster_sizes <- table(clusters)
  cluster_pcts <- as.numeric(cluster_sizes) / n_total * 100

  for (i in seq_along(cluster_sizes)) {
    if (cluster_pcts[i] < min_pct) {
      guard <- guard_warn(guard,
        sprintf("Segment %s has only %.1f%% of sample (%d cases)",
                names(cluster_sizes)[i], cluster_pcts[i], cluster_sizes[i]),
        category = "small_cluster")
    }
  }

  # Check imbalance (largest / smallest ratio)
  if (length(cluster_sizes) >= 2) {
    ratio <- max(cluster_sizes) / min(cluster_sizes)
    if (ratio > 5) {
      guard <- guard_warn(guard,
        sprintf("Cluster size imbalance: largest is %.1fx the smallest", ratio),
        category = "imbalance")
      guard <- guard_flag_stability(guard, "High cluster size imbalance")
    }
  }

  guard
}


#' Soft Guard: Check Silhouette Quality
#'
#' @param silhouette_score Average silhouette score
#' @param guard Guard state object
#' @return Updated guard state
#' @keywords internal
guard_check_silhouette_quality <- function(silhouette_score, guard) {
  if (is.null(silhouette_score) || is.na(silhouette_score)) return(guard)

  if (silhouette_score < 0.25) {
    guard <- guard_warn(guard,
      sprintf("Weak cluster structure (silhouette=%.3f). Segments may not be well-separated.",
              silhouette_score),
      category = "cluster_quality")
    guard <- guard_flag_stability(guard, "Low silhouette score")
  } else if (silhouette_score < 0.50) {
    guard <- guard_warn(guard,
      sprintf("Moderate cluster structure (silhouette=%.3f). Segments are reasonably separated.",
              silhouette_score),
      category = "cluster_quality")
  }

  guard
}


#' Soft Guard: Check Outlier Proportion
#'
#' Warns if too many cases are flagged as outliers.
#'
#' @param n_outliers Number of outliers detected
#' @param n_total Total number of cases
#' @param guard Guard state object
#' @param max_pct Maximum acceptable outlier percentage (default 10)
#' @return Updated guard state
#' @keywords internal
guard_check_outlier_proportion <- function(n_outliers, n_total, guard, max_pct = 10) {
  if (n_outliers == 0) return(guard)

  pct <- n_outliers / n_total * 100

  if (pct > max_pct) {
    guard <- guard_warn(guard,
      sprintf("%.1f%% of cases flagged as outliers (%d of %d). This is unusually high.",
              pct, n_outliers, n_total),
      category = "outliers")
    guard <- guard_flag_stability(guard, "High outlier proportion")
  } else if (pct > 5) {
    guard <- guard_warn(guard,
      sprintf("%.1f%% of cases flagged as outliers (%d of %d).",
              pct, n_outliers, n_total),
      category = "outliers")
  }

  guard
}


#' Soft Guard: Check Missing Data Proportion
#'
#' @param data Data frame
#' @param vars Variables to check
#' @param guard Guard state object
#' @param threshold Warning threshold percentage (default 15)
#' @return Updated guard state
#' @keywords internal
guard_check_missing_data <- function(data, vars, guard, threshold = 15) {
  for (v in vars) {
    if (v %in% names(data)) {
      n_missing <- sum(is.na(data[[v]]))
      pct_missing <- n_missing / nrow(data) * 100

      if (pct_missing > threshold) {
        guard <- guard_warn(guard,
          sprintf("Variable '%s' has %.1f%% missing values (%d of %d).",
                  v, pct_missing, n_missing, nrow(data)),
          category = "missing_data")
      }
    }
  }

  guard
}


#' Soft Guard: Check High Correlation Between Variables
#'
#' Warns about highly correlated clustering variables.
#'
#' @param data Data frame (clustering variables only)
#' @param guard Guard state object
#' @param threshold Correlation threshold (default 0.85)
#' @return Updated guard state
#' @keywords internal
guard_check_high_correlation <- function(data, guard, threshold = 0.85) {
  # Handle both matrix and data.frame inputs
  if (is.matrix(data)) {
    numeric_data <- data
  } else {
    numeric_data <- data[, sapply(data, is.numeric), drop = FALSE]
  }
  if (ncol(numeric_data) < 2) return(guard)

  cor_matrix <- tryCatch(
    cor(numeric_data, use = "pairwise.complete.obs"),
    error = function(e) NULL
  )
  if (is.null(cor_matrix)) return(guard)

  # Check upper triangle for high correlations
  high_pairs <- character(0)
  for (i in 1:(ncol(cor_matrix) - 1)) {
    for (j in (i + 1):ncol(cor_matrix)) {
      if (!is.na(cor_matrix[i, j]) && abs(cor_matrix[i, j]) > threshold) {
        high_pairs <- c(high_pairs,
          sprintf("%s & %s (r=%.2f)", colnames(cor_matrix)[i],
                  colnames(cor_matrix)[j], cor_matrix[i, j]))
      }
    }
  }

  if (length(high_pairs) > 0) {
    guard <- guard_warn(guard,
      sprintf("%d pair(s) of highly correlated variables (|r| > %.2f): %s",
              length(high_pairs), threshold, paste(high_pairs, collapse = "; ")),
      category = "multicollinearity")
  }

  guard
}


#' Soft Guard: Check Variable Selection Impact
#'
#' Warns when variable selection significantly reduces variable count.
#'
#' @param original_count Original number of variables
#' @param selected_count Number after selection
#' @param guard Guard state object
#' @return Updated guard state
#' @keywords internal
guard_check_variable_selection <- function(original_count, selected_count, guard) {
  if (selected_count < original_count) {
    pct_removed <- (1 - selected_count / original_count) * 100
    guard$variables_selected <- TRUE
    guard$original_var_count <- original_count
    guard$final_var_count <- selected_count

    if (pct_removed > 50) {
      guard <- guard_warn(guard,
        sprintf("Variable selection removed %.0f%% of variables (%d -> %d). Review selected variables.",
                pct_removed, original_count, selected_count),
        category = "variable_selection")
      guard <- guard_flag_stability(guard, "More than half of variables removed by selection")
    } else {
      guard <- guard_warn(guard,
        sprintf("Variable selection reduced from %d to %d variables (%.0f%% removed).",
                original_count, selected_count, pct_removed),
        category = "variable_selection")
    }
  }

  guard
}


# ==============================================================================
# GUARD ORCHESTRATORS
# ==============================================================================
# These functions collect all guards into coordinated pre/post phases,
# matching the catdriver pattern for maintainability and clarity.
# ==============================================================================


#' Run All Pre-Analysis Guards
#'
#' Validates config and data before clustering begins.
#' Runs all hard-error guards that use segment_refuse().
#' Also runs data-quality soft guards that set PARTIAL status.
#'
#' @param config Configuration list
#' @param data_list Prepared data list from prepare_segment_data()
#' @return Guard state object with all pre-analysis checks recorded
#' @export
segment_guard_pre_analysis <- function(config, data_list) {
  guard <- segment_guard_init()

  # --- Hard guards (REFUSE on failure) ---

  # Config completeness
  guard_require_clustering_vars(config, data_list$data)
  guard_require_id_variable(config, data_list$data)
  guard_require_valid_method(config$method)
  guard_require_method_packages(config$method)
  guard_require_valid_k(config)

  # Sample size (use k_max for exploration, k_fixed for final)
  k_check <- if (config$mode == "exploration") config$k_max else config$k_fixed
  guard_require_sample_size(nrow(data_list$scaled_data), k_check, ncol(data_list$scaled_data))

  # Hclust size limit
  if (tolower(config$method) == "hclust") {
    guard_require_hclust_size(nrow(data_list$scaled_data))
  }

  # --- Soft guards (warn, set PARTIAL) ---

  # Data quality checks
  guard <- guard_check_missing_data(data_list$data, config$clustering_vars, guard,
                                     threshold = config$missing_threshold)
  guard <- guard_check_low_variance(data_list$scaled_data, guard)
  guard <- guard_check_high_correlation(data_list$scaled_data, guard)

  # Outlier proportion
  if (!is.null(data_list$outlier_count) && data_list$outlier_count > 0) {
    guard <- guard_check_outlier_proportion(data_list$outlier_count,
                                            nrow(data_list$data), guard)
    guard <- guard_record_outliers_removed(guard, data_list$outlier_count)
  }

  guard
}


#' Run All Post-Clustering Guards
#'
#' Validates clustering results and adds appropriate warnings.
#' Called after clustering and validation metrics are computed.
#'
#' @param guard Guard state object from segment_guard_pre_analysis()
#' @param cluster_result Clustering result list (clusters, k, centers, method)
#' @param validation_metrics Validation metrics list (avg_silhouette, etc.)
#' @param config Configuration list
#' @return Updated guard state
#' @export
segment_guard_post_clustering <- function(guard, cluster_result, validation_metrics, config) {

  # Record clustering method

  guard$clustering_method <- config$method

  # Cluster size checks
  guard <- guard_check_small_clusters(cluster_result$clusters, guard,
                                       min_pct = config$min_segment_size_pct)

  # Silhouette quality
  guard <- guard_check_silhouette_quality(validation_metrics$avg_silhouette, guard)

  # Record stability metrics
  guard <- guard_record_cluster_stability(guard, cluster_result$k,
    validation_metrics$avg_silhouette, validation_metrics$tot_withinss)

  # Flag convergence warnings from clustering algorithms
  if (!is.null(cluster_result$convergence_warning)) {
    guard$warnings <- c(guard$warnings,
      sprintf("Clustering convergence issue: %s", cluster_result$convergence_warning))
    guard$stability_flags <- c(guard$stability_flags, "kmeans_convergence")
  }

  # Flag degenerate GMM components
  if (!is.null(cluster_result$degenerate_components)) {
    guard$warnings <- c(guard$warnings,
      sprintf("GMM degenerate components: %s", cluster_result$degenerate_components))
    guard$stability_flags <- c(guard$stability_flags, "gmm_degenerate")
  }

  guard
}
