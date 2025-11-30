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
    stop(sprintf("Cannot calculate Calinski-Harabasz index: n (%d) must be greater than k (%d)", n, k), call. = FALSE)
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
    stop("Package 'cluster' is required for exploration metrics. Install with: install.packages('cluster')", call. = FALSE)
  }

  models <- exploration_result$models
  data <- exploration_result$data_list$scaled_data
  
  metrics_list <- list()
  
  for (k_str in names(models)) {
    k <- as.numeric(k_str)
    model <- models[[k_str]]
    
    # Calculate silhouette
    sil <- silhouette(model$cluster, dist(data))
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
    stop("Package 'cluster' is required for validation metrics. Install with: install.packages('cluster')", call. = FALSE)
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
