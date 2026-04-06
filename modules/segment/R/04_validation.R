# ==============================================================================
# SEGMENTATION VALIDATION
# ==============================================================================
# Validate segment quality and stability
# Part of Turas Segmentation Module
# ==============================================================================

#' Assess Segment Stability via Bootstrap
#'
#' Tests segment stability by resampling data and measuring consistency.
#' Each bootstrap sample is scaled using the ORIGINAL scaling parameters
#' (not re-scaled independently), and compared against the original solution
#' using greedy center-matching for cluster alignment.
#'
#' @param data Data frame with clustering variables
#' @param clustering_vars Character vector of clustering variable names
#' @param k Number of segments
#' @param n_bootstrap Number of bootstrap iterations (default: 100)
#' @param nstart Number of random starts for k-means (default: 25)
#' @param seed Random seed for reproducibility
#' @param original_clusters Optional integer vector of original cluster assignments
#' @return List with stability metrics
#' @export
assess_segment_stability <- function(data, clustering_vars, k, n_bootstrap = 100,
                                     nstart = 25, seed = 123,
                                     original_clusters = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("SEGMENT STABILITY ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  set.seed(seed)

  clustering_data <- data[, clustering_vars, drop = FALSE]
  n <- nrow(clustering_data)

  # Scale once using original data parameters (Bug fix: all bootstrap samples

  # must use the same scaling to ensure comparability)
  scale_center <- colMeans(clustering_data, na.rm = TRUE)
  scale_sd <- apply(clustering_data, 2, sd, na.rm = TRUE)
  scale_sd[scale_sd == 0] <- 1  # guard against constant columns
  scaled_original <- scale(clustering_data, center = scale_center, scale = scale_sd)

  # Fit original solution if not provided
  if (is.null(original_clusters)) {
    original_model <- kmeans(scaled_original, centers = k, nstart = nstart)
    original_clusters <- original_model$cluster
  }

  # Compute original cluster centers (for greedy matching)
  original_centers <- matrix(NA, nrow = k, ncol = ncol(scaled_original))
  for (seg in seq_len(k)) {
    mask <- original_clusters == seg
    if (sum(mask) > 0) {
      original_centers[seg, ] <- colMeans(scaled_original[mask, , drop = FALSE])
    }
  }

  cat(sprintf("Running %d bootstrap iterations...\n", n_bootstrap))

  # Store per-bootstrap agreement scores (each compared to original)
  agreement_scores <- numeric(n_bootstrap)

  for (i in seq_len(n_bootstrap)) {
    if (i %% 25 == 0) cat(sprintf("  Iteration %d/%d\n", i, n_bootstrap))

    # Resample with replacement
    boot_idx <- sample(n, n, replace = TRUE)
    boot_data <- clustering_data[boot_idx, , drop = FALSE]

    # Scale using ORIGINAL parameters (not re-computed from bootstrap sample)
    boot_scaled <- scale(boot_data, center = scale_center, scale = scale_sd)

    # Cluster bootstrap sample
    boot_result <- tryCatch({
      kmeans(boot_scaled, centers = k, nstart = nstart)
    }, error = function(e) NULL)

    if (is.null(boot_result)) {
      agreement_scores[i] <- NA
      next
    }

    # Map bootstrap clusters back to full sample by assigning each original
    # observation to the nearest bootstrap center
    boot_centers <- boot_result$centers
    boot_full <- assign_to_nearest_centers(scaled_original, boot_centers)

    # Align labels via greedy center-matching against original
    aligned <- align_cluster_labels(original_clusters, boot_full, k)

    # Calculate agreement (fraction of matching assignments)
    agreement_scores[i] <- mean(aligned == original_clusters)
  }

  avg_stability <- mean(agreement_scores, na.rm = TRUE)
  n_failed <- sum(is.na(agreement_scores))

  cat(sprintf("\n✓ Stability analysis complete\n"))
  cat(sprintf("  Average agreement with original: %.1f%%\n", avg_stability * 100))
  if (n_failed > 0) {
    cat(sprintf("  Failed iterations: %d\n", n_failed))
  }

  # Interpret stability
  if (avg_stability > 0.85) {
    interpretation <- "Excellent - segments are very stable"
  } else if (avg_stability > 0.75) {
    interpretation <- "Good - segments are reasonably stable"
  } else if (avg_stability > 0.60) {
    interpretation <- "Fair - segments show moderate instability"
  } else {
    interpretation <- "Poor - segments are unstable, consider different k"
  }

  cat(sprintf("  Interpretation: %s\n\n", interpretation))

  return(list(
    avg_stability = avg_stability,
    agreement_scores = agreement_scores[!is.na(agreement_scores)],
    interpretation = interpretation,
    n_bootstrap = n_bootstrap,
    n_failed = n_failed
  ))
}


#' Assign Observations to Nearest Centers (vectorized)
#'
#' @param data Scaled data matrix (n x p)
#' @param centers Center matrix (k x p)
#' @return Integer vector of cluster assignments
#' @keywords internal
assign_to_nearest_centers <- function(data, centers) {
  k <- nrow(centers)
  dist_matrix <- matrix(NA_real_, nrow = nrow(data), ncol = k)
  for (j in seq_len(k)) {
    diff <- sweep(data, 2, centers[j, ])
    dist_matrix[, j] <- rowSums(diff^2)
  }
  max.col(-dist_matrix, ties.method = "first")
}


#' Align Cluster Labels via Greedy Center-Matching
#'
#' Finds the permutation of labels in clusters_new that best matches
#' clusters_orig, using a greedy contingency-table approach.
#'
#' @param clusters_orig Integer vector of reference assignments
#' @param clusters_new Integer vector of assignments to align
#' @param k Number of clusters
#' @return Integer vector with relabelled clusters_new
#' @keywords internal
align_cluster_labels <- function(clusters_orig, clusters_new, k) {
  cont <- table(factor(clusters_orig, levels = seq_len(k)),
                factor(clusters_new, levels = seq_len(k)))

  # Greedy matching: for each original cluster, find best unmatched new cluster
  mapping <- integer(k)
  used <- logical(k)

  for (pass in seq_len(k)) {
    best_val <- -1
    best_i <- 0
    best_j <- 0
    for (i in seq_len(k)) {
      if (mapping[i] > 0) next
      for (j in seq_len(k)) {
        if (used[j]) next
        if (cont[i, j] > best_val) {
          best_val <- cont[i, j]
          best_i <- i
          best_j <- j
        }
      }
    }
    if (best_i > 0) {
      mapping[best_i] <- best_j
      used[best_j] <- TRUE
    }
  }

  # Create reverse mapping: new_label -> orig_label
  reverse_map <- integer(k)
  for (i in seq_len(k)) {
    if (mapping[i] > 0) reverse_map[mapping[i]] <- i
  }

  # Apply mapping
  aligned <- clusters_new
  for (j in seq_len(k)) {
    aligned[clusters_new == j] <- reverse_map[j]
  }

  aligned
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

  # CH index undefined for k=1 (division by zero in k-1)
  if (k == 1) {
    ch_index <- NA_real_
  } else {
    ch_index <- (bgss / (k - 1)) / (wgss / (n - k))
  }

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
  has_degenerate <- FALSE
  for (i in 1:k) {
    max_ratio <- 0
    for (j in 1:k) {
      if (i != j) {
        between_dist <- sqrt(sum((centers[i, ] - centers[j, ])^2))
        if (between_dist < 1e-10) {
          # Degenerate: two clusters have identical/near-identical centers
          has_degenerate <- TRUE
          next
        }
        ratio <- (avg_within[i] + avg_within[j]) / between_dist
        max_ratio <- max(max_ratio, ratio)
      }
    }
    db_scores[i] <- max_ratio
  }
  if (has_degenerate) {
    cat("  [WARNING] Davies-Bouldin: two or more clusters have near-identical centers.\n")
    cat("            DB index may be unreliable. Consider reducing k.\n")
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

  # Support both legacy field names ($models) and current ($results)
  cluster_results <- exploration_result$results %||% exploration_result$models
  data <- exploration_result$data_list$scaled_data

  metrics_list <- list()

  for (k_str in names(cluster_results)) {
    k <- as.numeric(k_str)
    result_k <- cluster_results[[k_str]]

    # Extract cluster assignments - from result structure, model, or raw kmeans
    # result_k$clusters: wrapped result structure
    # result_k$model$cluster: wrapped result with nested model
    # result_k$cluster: raw kmeans object passed directly
    cluster_assignments <- result_k$clusters %||% result_k$model$cluster %||% result_k$cluster
    if (is.null(cluster_assignments)) next

    # Calculate silhouette
    sil <- cluster::silhouette(cluster_assignments, dist(data))
    avg_sil <- mean(sil[, 3])

    # Get segment sizes
    sizes <- table(cluster_assignments)
    min_size_pct <- min(prop.table(sizes)) * 100

    # Extract SS metrics from model or method_info
    # When result_k is a raw kmeans object, it IS the model
    model <- if (!is.null(result_k$model)) result_k$model else result_k
    method_info <- result_k$method_info

    totss <- model$totss %||% method_info$totss
    tot_withinss <- model$tot.withinss %||% method_info$tot_withinss
    betweenss <- model$betweenss %||% method_info$betweenss

    # Calculate from data if not available
    if (is.null(totss)) {
      grand_mean <- colMeans(data)
      totss <- sum(sweep(data, 2, grand_mean)^2)
    }
    if (is.null(tot_withinss)) {
      tot_withinss <- 0
      for (i in seq_len(k)) {
        mask <- cluster_assignments == i
        if (sum(mask) > 0) {
          cluster_data <- data[mask, , drop = FALSE]
          cluster_center <- colMeans(cluster_data)
          tot_withinss <- tot_withinss + sum(sweep(cluster_data, 2, cluster_center)^2)
        }
      }
    }
    if (is.null(betweenss)) betweenss <- totss - tot_withinss

    betweenss_totss <- if (totss > 0) betweenss / totss else 0

    metrics_list[[k_str]] <- data.frame(
      k = k,
      tot.withinss = tot_withinss,
      betweenss = betweenss,
      totss = totss,
      betweenss_totss = betweenss_totss,
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
    cat("  [SEGMENT WARNING] No k values meet minimum segment size requirement\n")
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
#' Supports kmeans, hclust, and gmm models by extracting cluster assignments
#' and SS metrics from the appropriate source.
#'
#' @param data Scaled data matrix
#' @param model Fitted model object (kmeans, hclust, or Mclust)
#' @param k Number of clusters
#' @param clusters Integer vector of cluster assignments (required for hclust/gmm)
#' @param calculate_gap Logical, whether to calculate gap statistic
#' @return List with validation metrics
#' @export
calculate_validation_metrics <- function(data, model, k, clusters = NULL,
                                         calculate_gap = FALSE) {
  if (!requireNamespace("cluster", quietly = TRUE)) {
    segment_refuse(
      code = "PKG_CLUSTER_MISSING",
      title = "Package cluster Required",
      problem = "Package 'cluster' is not installed.",
      why_it_matters = "The cluster package is required for calculating validation metrics (silhouette analysis).",
      how_to_fix = "Install the package with: install.packages('cluster')"
    )
  }

  # Extract cluster assignments from model or parameter
  cluster_assignments <- if (!is.null(clusters)) {
    clusters
  } else if (!is.null(model$cluster)) {
    model$cluster
  } else {
    segment_refuse(
      code = "CALC_NO_CLUSTERS",
      title = "No Cluster Assignments Available",
      problem = "Could not extract cluster assignments from model or clusters parameter.",
      why_it_matters = "Validation metrics require cluster assignments.",
      how_to_fix = "Pass cluster assignments via the 'clusters' parameter."
    )
  }

  # Calculate silhouette
  sil <- cluster::silhouette(cluster_assignments, dist(data))
  avg_sil <- mean(sil[, 3])

  # Extract SS metrics - handle kmeans (native) vs hclust/gmm (computed)
  if (!is.null(model$totss)) {
    # kmeans model has these directly
    totss <- model$totss
    tot_withinss <- model$tot.withinss
    betweenss <- model$betweenss
  } else {
    # Calculate from data and cluster assignments
    grand_mean <- colMeans(data)
    totss <- sum(sweep(data, 2, grand_mean)^2)

    tot_withinss <- 0
    for (i in seq_len(k)) {
      mask <- cluster_assignments == i
      if (sum(mask) > 0) {
        cluster_data <- data[mask, , drop = FALSE]
        cluster_center <- colMeans(cluster_data)
        tot_withinss <- tot_withinss + sum(sweep(cluster_data, 2, cluster_center)^2)
      }
    }
    betweenss <- totss - tot_withinss
  }

  betweenss_totss <- if (totss > 0) betweenss / totss else 0

  metrics <- list(
    avg_silhouette = avg_sil,
    betweenss_totss = betweenss_totss,
    tot_withinss = tot_withinss,
    betweenss = betweenss,
    totss = totss
  )

  # Optionally calculate gap statistic (Tibshirani et al. 2001)
  if (calculate_gap) {
    gap_result <- tryCatch(
      calculate_gap_statistic(clustering_data, clusters, k),
      error = function(e) {
        cat(sprintf("  [SEGMENT] Gap statistic failed: %s\n", e$message))
        list(gap = NA_real_, se = NA_real_)
      }
    )
    metrics$gap_statistic <- gap_result$gap
    metrics$gap_se <- gap_result$se
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


# ==============================================================================
# GAP STATISTIC (Tibshirani, Walther & Hastie, 2001)
# ==============================================================================

#' Calculate Gap Statistic for a Given Clustering
#'
#' Computes the gap statistic by comparing the observed within-cluster
#' dispersion to that expected under a uniform reference distribution
#' on the data bounding box. Uses B reference datasets.
#'
#' @param data Numeric matrix/data.frame of clustering variables (already scaled)
#' @param clusters Integer vector of cluster assignments
#' @param k Number of clusters
#' @param B Number of reference datasets (default: 50)
#' @param nstart Number of random starts for reference k-means (default: 10)
#' @return List with gap, se, log_wk, E_log_wk_star, sd_log_wk_star
#' @export
calculate_gap_statistic <- function(data, clusters, k, B = 50, nstart = 10) {

  data <- as.matrix(data)
  n <- nrow(data)
  p <- ncol(data)

  # Observed log(W_k) -- pooled within-cluster sum of squares
  log_wk <- log(compute_pooled_wss(data, clusters))

  # Generate B uniform reference datasets on bounding box
  col_mins <- apply(data, 2, min, na.rm = TRUE)
  col_maxs <- apply(data, 2, max, na.rm = TRUE)

  log_wk_stars <- numeric(B)

  for (b in seq_len(B)) {
    # Generate uniform data on bounding box
    ref_data <- matrix(NA_real_, nrow = n, ncol = p)
    for (j in seq_len(p)) {
      ref_data[, j] <- runif(n, min = col_mins[j], max = col_maxs[j])
    }

    # Cluster reference data
    ref_result <- tryCatch(
      kmeans(ref_data, centers = k, nstart = nstart),
      error = function(e) NULL
    )

    if (!is.null(ref_result)) {
      log_wk_stars[b] <- log(ref_result$tot.withinss)
    } else {
      log_wk_stars[b] <- NA
    }
  }

  # Remove any failed reference runs
  log_wk_stars <- log_wk_stars[!is.na(log_wk_stars)]

  if (length(log_wk_stars) < 5) {
    return(list(gap = NA_real_, se = NA_real_))
  }

  # Gap = E*[log(W_k)] - log(W_k)
  E_log_wk_star <- mean(log_wk_stars)
  sd_log_wk_star <- sd(log_wk_stars)
  se <- sd_log_wk_star * sqrt(1 + 1 / length(log_wk_stars))

  gap <- E_log_wk_star - log_wk

  list(
    gap = gap,
    se = se,
    log_wk = log_wk,
    E_log_wk_star = E_log_wk_star,
    sd_log_wk_star = sd_log_wk_star
  )
}


#' Calculate Gap Statistic Across a Range of k Values
#'
#' For exploration mode: compute gap(k) for k_min:k_max and identify
#' optimal k using the Tibshirani et al. (2001) "1-SE" rule:
#' smallest k such that Gap(k) >= Gap(k+1) - SE(k+1).
#'
#' @param data Numeric matrix/data.frame of scaled clustering variables
#' @param k_range Integer vector of k values to test
#' @param B Number of reference datasets per k (default: 50)
#' @param nstart Number of random starts for k-means (default: 10)
#' @return List with gap_values, se_values, optimal_k, gap_df
#' @export
calculate_gap_statistic_range <- function(data, k_range, B = 50, nstart = 10) {

  data <- as.matrix(data)
  n_k <- length(k_range)

  gap_values <- numeric(n_k)
  se_values <- numeric(n_k)

  cat(sprintf("    Gap statistic: computing for k = %d to %d (B = %d)...\n",
              min(k_range), max(k_range), B))

  for (idx in seq_along(k_range)) {
    k <- k_range[idx]

    # Cluster data
    km <- tryCatch(
      kmeans(data, centers = k, nstart = nstart),
      error = function(e) NULL
    )

    if (is.null(km)) {
      gap_values[idx] <- NA
      se_values[idx] <- NA
      next
    }

    gap_result <- calculate_gap_statistic(data, km$cluster, k, B = B, nstart = nstart)
    gap_values[idx] <- gap_result$gap
    se_values[idx] <- gap_result$se
  }

  # Find optimal k: smallest k where Gap(k) >= Gap(k+1) - SE(k+1)
  optimal_k <- NA
  for (idx in seq_len(n_k - 1)) {
    if (!is.na(gap_values[idx]) && !is.na(gap_values[idx + 1]) && !is.na(se_values[idx + 1])) {
      if (gap_values[idx] >= gap_values[idx + 1] - se_values[idx + 1]) {
        optimal_k <- k_range[idx]
        break
      }
    }
  }

  # Fallback: k with max gap
  if (is.na(optimal_k) && any(!is.na(gap_values))) {
    optimal_k <- k_range[which.max(gap_values)]
  }

  gap_df <- data.frame(
    k = k_range,
    gap = round(gap_values, 4),
    se = round(se_values, 4),
    stringsAsFactors = FALSE
  )

  cat(sprintf("    Gap statistic optimal k: %s\n",
              if (is.na(optimal_k)) "indeterminate" else as.character(optimal_k)))

  list(
    gap_values = gap_values,
    se_values = se_values,
    optimal_k = optimal_k,
    gap_df = gap_df
  )
}


#' Compute Pooled Within-Cluster Sum of Squares
#'
#' @param data Numeric matrix
#' @param clusters Integer vector of cluster assignments
#' @return Numeric scalar (total within-SS)
#' @keywords internal
compute_pooled_wss <- function(data, clusters) {
  wss <- 0
  for (seg in unique(clusters)) {
    seg_data <- data[clusters == seg, , drop = FALSE]
    if (nrow(seg_data) > 0) {
      center <- colMeans(seg_data)
      wss <- wss + sum(sweep(seg_data, 2, center)^2)
    }
  }
  wss
}
