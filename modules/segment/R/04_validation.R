# ==============================================================================
# SEGMENTATION VALIDATION
# ==============================================================================
# Validate segment quality and stability
# Part of Turas Segmentation Module
# ==============================================================================

#' Assess Segment Stability via Bootstrap
#'
#' Tests segment stability by resampling data and measuring consistency
#'
#' @param data Data frame with clustering variables
#' @param clustering_vars Character vector of clustering variable names
#' @param k Number of segments
#' @param n_bootstrap Number of bootstrap iterations (default: 100)
#' @param nstart Number of random starts for k-means (default: 25)
#' @param seed Random seed for reproducibility
#' @return List with stability metrics
#' @export
assess_segment_stability <- function(data, clustering_vars, k, n_bootstrap = 100, nstart = 25, seed = 123) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENT STABILITY ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  set.seed(seed)

  clustering_data <- data[, clustering_vars, drop = FALSE]
  n <- nrow(clustering_data)

  cat(sprintf("Running %d bootstrap iterations...\n", n_bootstrap))

  # Store bootstrap results
  bootstrap_assignments <- matrix(NA, nrow = n, ncol = n_bootstrap)

  # Run bootstrap
  for (i in 1:n_bootstrap) {
    if (i %% 20 == 0) cat(sprintf("  Iteration %d/%d\n", i, n_bootstrap))

    # Resample with replacement
    boot_idx <- sample(1:n, n, replace = TRUE)
    boot_data <- clustering_data[boot_idx, ]

    # Cluster
    boot_model <- kmeans(scale(boot_data), centers = k, nstart = nstart)

    # Map back to original indices
    bootstrap_assignments[boot_idx, i] <- boot_model$cluster
  }

  cat("\nCalculating stability metrics...\n")

  # Calculate Jaccard similarity between bootstrap iterations
  jaccard_similarities <- numeric(n_bootstrap - 1)

  for (i in 1:(n_bootstrap - 1)) {
    # Compare iteration i with i+1
    valid_rows <- !is.na(bootstrap_assignments[, i]) & !is.na(bootstrap_assignments[, i + 1])

    if (sum(valid_rows) > 0) {
      # For each pair of respondents, check if they're in same segment in both iterations
      same_cluster_i <- outer(bootstrap_assignments[valid_rows, i],
                              bootstrap_assignments[valid_rows, i], "==")
      same_cluster_j <- outer(bootstrap_assignments[valid_rows, i + 1],
                              bootstrap_assignments[valid_rows, i + 1], "==")

      # Jaccard = intersection / union
      intersection <- sum(same_cluster_i & same_cluster_j)
      union <- sum(same_cluster_i | same_cluster_j)

      jaccard_similarities[i] <- intersection / union
    }
  }

  avg_stability <- mean(jaccard_similarities, na.rm = TRUE)

  cat(sprintf("\n✓ Stability analysis complete\n"))
  cat(sprintf("  Average Jaccard similarity: %.3f\n", avg_stability))

  # Interpret stability
  if (avg_stability > 0.8) {
    interpretation <- "Excellent - segments are very stable"
  } else if (avg_stability > 0.6) {
    interpretation <- "Good - segments are reasonably stable"
  } else if (avg_stability > 0.4) {
    interpretation <- "Fair - segments show moderate instability"
  } else {
    interpretation <- "Poor - segments are unstable, consider different k"
  }

  cat(sprintf("  Interpretation: %s\n\n", interpretation))

  return(list(
    avg_stability = avg_stability,
    jaccard_similarities = jaccard_similarities,
    interpretation = interpretation,
    n_bootstrap = n_bootstrap
  ))
}


#' Perform Discriminant Analysis
#'
#' Tests how well clustering variables discriminate between segments
#'
#' @param data Data frame with clustering variables
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variable names
#' @return List with discriminant analysis results
#' @export
perform_discriminant_analysis <- function(data, clusters, clustering_vars) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("DISCRIMINANT ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Check if MASS package is available
  if (!requireNamespace("MASS", quietly = TRUE)) {
    cat("⚠ MASS package not installed. Skipping discriminant analysis.\n")
    cat("  Install with: install.packages('MASS')\n")
    return(invisible(NULL))
  }

  # Prepare data
  disc_data <- data[, clustering_vars, drop = FALSE]
  disc_data$segment <- as.factor(clusters)

  cat("Performing Linear Discriminant Analysis (LDA)...\n")

  # Perform LDA
  lda_model <- MASS::lda(segment ~ ., data = disc_data)

  # Predict
  lda_pred <- predict(lda_model)

  # Calculate accuracy
  confusion <- table(Predicted = lda_pred$class, Actual = clusters)
  accuracy <- sum(diag(confusion)) / sum(confusion)

  cat(sprintf("\n✓ Discriminant analysis complete\n"))
  cat(sprintf("  Classification accuracy: %.1f%%\n", accuracy * 100))

  # Interpret accuracy
  if (accuracy > 0.9) {
    interpretation <- "Excellent - segments are very well separated"
  } else if (accuracy > 0.75) {
    interpretation <- "Good - segments are adequately separated"
  } else if (accuracy > 0.6) {
    interpretation <- "Fair - segments have moderate overlap"
  } else {
    interpretation <- "Poor - segments have substantial overlap"
  }

  cat(sprintf("  Interpretation: %s\n", interpretation))

  # Show confusion matrix
  cat("\nConfusion Matrix:\n")
  print(confusion)

  # Variable importance (proportion of trace)
  svd_vals <- lda_model$svd
  prop_trace <- svd_vals^2 / sum(svd_vals^2)

  cat("\nDiscriminant Function Importance:\n")
  for (i in seq_along(prop_trace)) {
    cat(sprintf("  LD%d: %.1f%%\n", i, prop_trace[i] * 100))
  }

  cat("\n")

  return(list(
    lda_model = lda_model,
    accuracy = accuracy,
    confusion_matrix = confusion,
    interpretation = interpretation,
    prop_trace = prop_trace
  ))
}


#' Calculate Segment Separation Metrics
#'
#' Computes various metrics measuring how well-separated segments are
#'
#' @param data Data frame with clustering variables
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variable names
#' @return List with separation metrics
#' @export
calculate_separation_metrics <- function(data, clusters, clustering_vars) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENT SEPARATION METRICS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  clustering_data <- scale(data[, clustering_vars, drop = FALSE])
  k <- length(unique(clusters))

  # 1. Calinski-Harabasz Index
  grand_mean <- colMeans(clustering_data)

  # Between-cluster sum of squares
  bgss <- 0
  for (seg in unique(clusters)) {
    seg_data <- clustering_data[clusters == seg, , drop = FALSE]
    seg_mean <- colMeans(seg_data)
    n_seg <- nrow(seg_data)
    bgss <- bgss + n_seg * sum((seg_mean - grand_mean)^2)
  }

  # Within-cluster sum of squares
  wgss <- 0
  for (seg in unique(clusters)) {
    seg_data <- clustering_data[clusters == seg, , drop = FALSE]
    seg_mean <- colMeans(seg_data)
    wgss <- wgss + sum((seg_data - matrix(seg_mean, nrow = nrow(seg_data),
                                          ncol = ncol(seg_data), byrow = TRUE))^2)
  }

  n <- nrow(clustering_data)

  # Validate that we have enough data points for the number of clusters
  if (n <= k) {
    segment_refuse(
      code = "DATA_INSUFFICIENT_FOR_CH",
      title = "Insufficient Data for Calinski-Harabasz Index",
      problem = sprintf("Cannot calculate Calinski-Harabasz index: n (%d) must be greater than k (%d)", n, k),
      why_it_matters = "The CH index requires more observations than clusters for valid calculation.",
      how_to_fix = c(
        "Increase sample size",
        "Reduce number of clusters (k)",
        "Review data filtering and missing data handling"
      )
    )
  }

  ch_index <- (bgss / (k - 1)) / (wgss / (n - k))

  # 2. Davies-Bouldin Index
  centers <- matrix(NA, nrow = k, ncol = ncol(clustering_data))
  for (i in 1:k) {
    centers[i, ] <- colMeans(clustering_data[clusters == i, , drop = FALSE])
  }

  avg_within <- numeric(k)
  for (i in 1:k) {
    seg_data <- clustering_data[clusters == i, , drop = FALSE]
    center <- centers[i, ]
    avg_within[i] <- mean(sqrt(rowSums((seg_data -
                                       matrix(center, nrow = nrow(seg_data),
                                             ncol = ncol(seg_data), byrow = TRUE))^2)))
  }

  db_scores <- numeric(k)
  for (i in 1:k) {
    max_ratio <- 0
    for (j in 1:k) {
      if (i != j) {
        between_dist <- sqrt(sum((centers[i, ] - centers[j, ])^2))
        ratio <- (avg_within[i] + avg_within[j]) / between_dist
        max_ratio <- max(max_ratio, ratio)
      }
    }
    db_scores[i] <- max_ratio
  }
  db_index <- mean(db_scores)

  cat(sprintf("Calinski-Harabasz Index: %.2f\n", ch_index))
  cat("  Higher is better. Typical range: 10-1000+\n")
  cat(sprintf("\nDavies-Bouldin Index: %.2f\n", db_index))
  cat("  Lower is better. Good segmentation: < 1.0\n\n")

  return(list(
    calinski_harabasz = ch_index,
    davies_bouldin = db_index,
    between_ss = bgss,
    within_ss = wgss,
    variance_ratio = bgss / wgss
  ))
}
#' Calculate Exploration Metrics
#'
#' Calculate validation metrics for multiple k values in exploration mode
#'
#' @param exploration_result Result from run_kmeans_exploration()
#' @return List with metrics_df and exploration_result
#' @export
calculate_exploration_metrics <- function(exploration_result) {
  if (!requireNamespace("cluster", quietly = TRUE)) {
    segment_refuse(
      code = "PKG_CLUSTER_MISSING",
      title = "Package cluster Required",
      problem = "Package 'cluster' is not installed.",
      why_it_matters = "The cluster package is required for calculating exploration metrics (silhouette analysis).",
      how_to_fix = "Install the package with: install.packages('cluster')"
    )
  }

  models <- exploration_result$models
  data <- exploration_result$data_list$scaled_data
  
  metrics_list <- list()
  
  for (k_str in names(models)) {
    k <- as.numeric(k_str)
    model <- models[[k_str]]
    
    # Calculate silhouette
    sil <- cluster::silhouette(model$cluster, dist(data))
    avg_sil <- mean(sil[, 3])
    
    # Get segment sizes
    sizes <- table(model$cluster)
    min_size_pct <- min(prop.table(sizes)) * 100
    
    metrics_list[[k_str]] <- data.frame(
      k = k,
      tot.withinss = model$tot.withinss,
      betweenss = model$betweenss,
      totss = model$totss,
      betweenss_totss = model$betweenss / model$totss,
      avg_silhouette_width = avg_sil,
      min_segment_pct = min_size_pct
    )
  }
  
  metrics_df <- do.call(rbind, metrics_list)
  rownames(metrics_df) <- NULL
  
  return(list(
    metrics_df = metrics_df,
    exploration_result = exploration_result
  ))
}

#' Recommend Optimal k
#'
#' Recommend the best k value based on validation metrics
#'
#' @param metrics_df Data frame of metrics from calculate_exploration_metrics
#' @param min_segment_size_pct Minimum segment size percentage threshold
#' @return List with recommended_k, metrics, and reason
#' @export
recommend_k <- function(metrics_df, min_segment_size_pct) {
  # Filter by segment size
  valid <- metrics_df[metrics_df$min_segment_pct >= min_segment_size_pct, ]
  
  if (nrow(valid) == 0) {
    warning("No k values meet minimum segment size requirement")
    valid <- metrics_df
  }
  
  # Recommend k with highest silhouette
  best_idx <- which.max(valid$avg_silhouette_width)
  recommended_k <- valid$k[best_idx]
  
  return(list(
    recommended_k = recommended_k,
    metrics = valid,
    reason = "Highest average silhouette width"
  ))
}
#' Calculate Validation Metrics for Final Run
#'
#' Calculate validation metrics for a single k value in final mode
#'
#' @param data Scaled data matrix
#' @param model K-means model object
#' @param k Number of clusters
#' @param calculate_gap Logical, whether to calculate gap statistic
#' @return List with validation metrics
#' @export
calculate_validation_metrics <- function(data, model, k, calculate_gap = FALSE) {
  if (!requireNamespace("cluster", quietly = TRUE)) {
    segment_refuse(
      code = "PKG_CLUSTER_MISSING",
      title = "Package cluster Required",
      problem = "Package 'cluster' is not installed.",
      why_it_matters = "The cluster package is required for calculating validation metrics (silhouette analysis).",
      how_to_fix = "Install the package with: install.packages('cluster')"
    )
  }

  # Calculate silhouette
  sil <- cluster::silhouette(model$cluster, dist(data))
  avg_sil <- mean(sil[, 3])
  
  # Get quality metrics from model
  betweenss_totss <- model$betweenss / model$totss
  
  metrics <- list(
    avg_silhouette = avg_sil,
    betweenss_totss = betweenss_totss,
    tot_withinss = model$tot.withinss,
    betweenss = model$betweenss,
    totss = model$totss
  )
  
  # Optionally calculate gap statistic (computationally expensive)
  if (calculate_gap) {
    # Gap statistic calculation would go here
    # Skipped for now as it's not critical
    metrics$gap_statistic <- NA
  }

  return(metrics)
}


# ==============================================================================
# FEATURE 9: SIMPLE STABILITY CHECK
# ==============================================================================

#' Run Simple Stability Check
#'
#' Performs a quick stability check by running k-means with multiple random
#' seeds and checking if segment assignments are consistent. Much faster than
#' full bootstrap validation.
#'
#' @param data Data frame with clustering variables
#' @param clustering_vars Character vector of clustering variable names
#' @param k Integer, number of clusters
#' @param n_runs Integer, number of different random seed runs (default: 5)
#' @param nstart Integer, number of random starts per run (default: 50)
#'
#' @return List with stability_score, run_results, agreement_matrix, interpretation
#' @export
#' @examples
#' stability <- check_stability_simple(
#'   data = survey_data,
#'   clustering_vars = c("q1", "q2", "q3", "q4", "q5"),
#'   k = 4,
#'   n_runs = 5
#' )
check_stability_simple <- function(data, clustering_vars, k, n_runs = 5, nstart = 50) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("STABILITY CHECK (Simple)\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  cat(sprintf("Running %d k-means iterations with different seeds...\n", n_runs))
  cat(sprintf("  k = %d, nstart = %d per run\n\n", k, nstart))

  # Prepare data
  clustering_data <- scale(data[, clustering_vars, drop = FALSE])
  n <- nrow(clustering_data)

  # Store results from each run
  run_results <- list()
  all_clusters <- matrix(NA, nrow = n, ncol = n_runs)

  base_seed <- as.integer(Sys.time())

  for (run in 1:n_runs) {
    seed <- base_seed + run * 1000
    set.seed(seed)

    model <- kmeans(clustering_data, centers = k, nstart = nstart)

    run_results[[run]] <- list(
      seed = seed,
      model = model,
      tot_withinss = model$tot.withinss
    )

    all_clusters[, run] <- model$cluster

    cat(sprintf("  Run %d: tot.withinss = %.1f\n", run, model$tot.withinss))
  }

  # ===========================================================================
  # CALCULATE PAIRWISE AGREEMENT
  # ===========================================================================

  # Calculate agreement between all pairs of runs
  # Use Rand Index or simple agreement after alignment

  agreement_scores <- numeric(0)
  n_pairs <- n_runs * (n_runs - 1) / 2

  for (i in 1:(n_runs - 1)) {
    for (j in (i + 1):n_runs) {
      # Calculate agreement using best cluster matching
      agreement <- calculate_cluster_agreement(all_clusters[, i], all_clusters[, j])
      agreement_scores <- c(agreement_scores, agreement)
    }
  }

  # ===========================================================================
  # CALCULATE STABILITY SCORE
  # ===========================================================================

  avg_agreement <- mean(agreement_scores)
  min_agreement <- min(agreement_scores)
  max_agreement <- max(agreement_scores)

  # Overall stability score (0-100)
  stability_score <- avg_agreement * 100

  # ===========================================================================
  # INTERPRETATION
  # ===========================================================================

  if (stability_score >= 90) {
    interpretation <- "EXCELLENT: Very stable segmentation"
    color <- "green"
  } else if (stability_score >= 80) {
    interpretation <- "GOOD: Reasonably stable segmentation"
    color <- "green"
  } else if (stability_score >= 70) {
    interpretation <- "ACCEPTABLE: Some instability, consider fewer segments"
    color <- "yellow"
  } else if (stability_score >= 60) {
    interpretation <- "MARGINAL: Significant instability, review clustering variables"
    color <- "orange"
  } else {
    interpretation <- "POOR: Unstable segmentation, consider different approach"
    color <- "red"
  }

  # ===========================================================================
  # IDENTIFY BEST RUN
  # ===========================================================================

  # Best run = lowest total within-cluster sum of squares
  withinss_values <- sapply(run_results, function(r) r$tot_withinss)
  best_run_idx <- which.min(withinss_values)
  best_model <- run_results[[best_run_idx]]$model

  # ===========================================================================
  # OUTPUT RESULTS
  # ===========================================================================

  cat("\n")
  cat(rep("-", 60), "\n", sep = "")
  cat("STABILITY RESULTS\n")
  cat(rep("-", 60), "\n", sep = "")
  cat("\n")

  cat(sprintf("Stability Score: %.0f%%\n", stability_score))
  cat(sprintf("Interpretation: %s\n", interpretation))
  cat("\n")
  cat(sprintf("Agreement between runs:\n"))
  cat(sprintf("  Average: %.1f%%\n", avg_agreement * 100))
  cat(sprintf("  Min: %.1f%%\n", min_agreement * 100))
  cat(sprintf("  Max: %.1f%%\n", max_agreement * 100))
  cat("\n")
  cat(sprintf("Best run: #%d (seed = %d)\n", best_run_idx, run_results[[best_run_idx]]$seed))
  cat("\n")

  # Recommendation
  if (stability_score < 70) {
    cat("Recommendations:\n")
    cat("  - Try fewer clusters (k-1)\n")
    cat("  - Review and reduce clustering variables\n")
    cat("  - Check for outliers that may cause instability\n")
    cat("\n")
  }

  return(list(
    stability_score = stability_score,
    interpretation = interpretation,
    avg_agreement = avg_agreement,
    agreement_scores = agreement_scores,
    run_results = run_results,
    best_model = best_model,
    best_run_idx = best_run_idx,
    all_clusters = all_clusters
  ))
}


#' Calculate Cluster Agreement Between Two Solutions
#'
#' Uses optimal matching to align cluster labels and calculate agreement.
#'
#' @param clusters1 Integer vector of cluster assignments
#' @param clusters2 Integer vector of cluster assignments
#' @return Numeric agreement score (0-1)
#' @keywords internal
calculate_cluster_agreement <- function(clusters1, clusters2) {

  k <- max(c(clusters1, clusters2))
  n <- length(clusters1)

  # Create contingency table
  cont_table <- table(clusters1, clusters2)

  # Find optimal matching (greedy approach for simplicity)
  # More sophisticated: Hungarian algorithm

  matched <- logical(k)
  total_matched <- 0

  for (i in 1:k) {
    if (i > nrow(cont_table)) next

    # Find best unmatched column for this row
    best_col <- 0
    best_count <- 0

    for (j in 1:k) {
      if (j > ncol(cont_table)) next
      if (!matched[j]) {
        if (cont_table[i, j] > best_count) {
          best_count <- cont_table[i, j]
          best_col <- j
        }
      }
    }

    if (best_col > 0) {
      matched[best_col] <- TRUE
      total_matched <- total_matched + best_count
    }
  }

  agreement <- total_matched / n

  return(agreement)
}


#' Quick Stability Report
#'
#' Generate a simple stability report as text
#'
#' @param stability_result Result from check_stability_simple()
#' @return Character string with report
#' @export
format_stability_report <- function(stability_result) {

  report <- sprintf("
STABILITY CHECK REPORT
======================

Stability Score: %.0f%% (%s)

Runs Performed: %d
Average Agreement: %.1f%%
Range: %.1f%% - %.1f%%

Best Run: #%d

",
    stability_result$stability_score,
    stability_result$interpretation,
    length(stability_result$run_results),
    stability_result$avg_agreement * 100,
    min(stability_result$agreement_scores) * 100,
    max(stability_result$agreement_scores) * 100,
    stability_result$best_run_idx
  )

  return(report)
}
