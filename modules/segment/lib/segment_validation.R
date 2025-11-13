# ==============================================================================
# SEGMENTATION VALIDATION METRICS
# ==============================================================================
# Calculate validation metrics: silhouette, elbow, gap statistic
# Part of Turas Segmentation Module
# ==============================================================================

#' Calculate silhouette scores
#'
#' DESIGN: Uses cluster::silhouette() for quality assessment
#' INTERPRETATION: >0.5 = good, 0.3-0.5 = acceptable, <0.3 = poor
#'
#' @param data Matrix, scaled clustering data
#' @param clusters Integer vector, cluster assignments
#' @return List with avg_silhouette, segment_silhouettes, sil_object
#' @export
calculate_silhouette <- function(data, clusters) {
  if (!requireNamespace("cluster", quietly = TRUE)) {
    stop("Package 'cluster' required for silhouette calculation.\nInstall with: install.packages('cluster')",
         call. = FALSE)
  }

  # Calculate distance matrix
  dist_matrix <- dist(data)

  # Calculate silhouette
  sil <- cluster::silhouette(clusters, dist_matrix)

  # Extract average
  avg_sil <- mean(sil[, "sil_width"])

  # Calculate per-segment averages
  seg_sil <- aggregate(sil[, "sil_width"],
                       by = list(cluster = sil[, "cluster"]),
                       FUN = mean)
  names(seg_sil) <- c("segment", "avg_silhouette")

  return(list(
    avg_silhouette = avg_sil,
    segment_silhouettes = seg_sil,
    sil_object = sil
  ))
}

#' Calculate within-cluster sum of squares
#'
#' DESIGN: Extracts WSS from k-means model
#' USAGE: For elbow plot
#'
#' @param kmeans_model K-means model object
#' @return Numeric, total within-cluster sum of squares
#' @export
calculate_wss <- function(kmeans_model) {
  return(kmeans_model$tot.withinss)
}

#' Calculate gap statistic
#'
#' DESIGN: Uses cluster::clusGap() to compare to null reference
#' WARNING: Computationally expensive - may take several minutes
#'
#' @param data Matrix, scaled clustering data
#' @param k_range Integer vector, k values to test
#' @param nstart Integer, number of random starts for k-means
#' @param B Integer, number of Monte Carlo samples (default: 50)
#' @return Gap statistic object from cluster::clusGap()
#' @export
calculate_gap_statistic <- function(data, k_range, nstart = 25, B = 50) {
  if (!requireNamespace("cluster", quietly = TRUE)) {
    stop("Package 'cluster' required for gap statistic.\nInstall with: install.packages('cluster')",
         call. = FALSE)
  }

  cat("Calculating gap statistic (this may take a few minutes)...\n")

  # Define k-means function for clusGap
  kmeans_fun <- function(x, k) {
    kmeans(x, centers = k, nstart = nstart)
  }

  # Calculate gap statistic
  gap_result <- cluster::clusGap(
    x = data,
    FUNcluster = kmeans_fun,
    K.max = max(k_range),
    B = B,
    verbose = FALSE
  )

  # Extract relevant k range
  gap_values <- gap_result$Tab[k_range, "gap"]

  return(list(
    gap_object = gap_result,
    gap_values = gap_values
  ))
}

#' Calculate all validation metrics for a single k
#'
#' DESIGN: Comprehensive metrics for one clustering solution
#' RETURNS: Named list of all metrics
#'
#' @param data Matrix, scaled clustering data
#' @param model K-means model object
#' @param k Integer, number of clusters
#' @param calculate_gap Logical, whether to calculate gap statistic
#' @return List with all validation metrics
#' @export
calculate_validation_metrics <- function(data, model, k, calculate_gap = FALSE) {
  # Silhouette
  sil_result <- calculate_silhouette(data, model$cluster)

  # WSS
  wss <- calculate_wss(model)

  # Between/Total SS ratio
  betweenss_totss <- model$betweenss / model$totss

  # Segment sizes
  seg_sizes <- table(model$cluster)
  seg_pcts <- prop.table(seg_sizes) * 100

  metrics <- list(
    k = k,
    n_obs = nrow(data),
    avg_silhouette = sil_result$avg_silhouette,
    segment_silhouettes = sil_result$segment_silhouettes,
    wss = wss,
    betweenss = model$betweenss,
    totss = model$totss,
    betweenss_totss = betweenss_totss,
    segment_sizes = as.vector(seg_sizes),
    segment_pcts = as.vector(seg_pcts),
    smallest_segment_n = min(seg_sizes),
    smallest_segment_pct = min(seg_pcts)
  )

  return(metrics)
}

#' Calculate validation metrics for all k in exploration mode
#'
#' DESIGN: Runs metrics for each k value tested
#' RETURNS: Data frame with one row per k
#'
#' @param exploration_result Result from run_kmeans_exploration()
#' @return Data frame with metrics for each k
#' @export
calculate_exploration_metrics <- function(exploration_result) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("CALCULATING VALIDATION METRICS\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  models <- exploration_result$models
  data <- exploration_result$data_list$scaled_data
  config <- exploration_result$data_list$config
  k_range <- exploration_result$k_range

  metrics_list <- list()

  for (k in k_range) {
    cat(sprintf("Calculating metrics for k=%d...\n", k))

    model <- models[[as.character(k)]]

    # Calculate metrics (skip gap for now - expensive)
    metrics <- calculate_validation_metrics(data, model, k, calculate_gap = FALSE)

    metrics_list[[as.character(k)]] <- metrics
  }

  # Optional: Calculate gap statistic if requested
  if ("gap" %in% config$k_selection_metrics) {
    cat("\nCalculating gap statistic for all k values...\n")
    cat("  This may take several minutes...\n")

    gap_result <- calculate_gap_statistic(data, k_range, nstart = config$nstart)

    # Add gap values to metrics
    for (i in seq_along(k_range)) {
      k <- k_range[i]
      metrics_list[[as.character(k)]]$gap_statistic <- gap_result$gap_values[i]
    }

    cat("✓ Gap statistic calculated\n")
  } else {
    # Add NULL gap statistics
    for (k in k_range) {
      metrics_list[[as.character(k)]]$gap_statistic <- NA
    }
  }

  # Convert to data frame for easy comparison
  metrics_df <- data.frame(
    k = sapply(metrics_list, function(x) x$k),
    n_obs = sapply(metrics_list, function(x) x$n_obs),
    avg_silhouette = sapply(metrics_list, function(x) x$avg_silhouette),
    wss = sapply(metrics_list, function(x) x$wss),
    betweenss_totss = sapply(metrics_list, function(x) x$betweenss_totss),
    gap_statistic = sapply(metrics_list, function(x) x$gap_statistic),
    smallest_segment_n = sapply(metrics_list, function(x) x$smallest_segment_n),
    smallest_segment_pct = sapply(metrics_list, function(x) x$smallest_segment_pct),
    stringsAsFactors = FALSE
  )

  cat("\n✓ Metrics calculation complete\n")

  return(list(
    metrics_df = metrics_df,
    metrics_detail = metrics_list
  ))
}

#' Recommend optimal k based on metrics
#'
#' DESIGN: Applies heuristics to recommend best k
#' LOGIC: Prioritizes silhouette, checks size constraints
#'
#' @param metrics_df Data frame from calculate_exploration_metrics()
#' @param min_segment_size_pct Minimum segment size threshold
#' @return List with recommended k and rationale
#' @export
recommend_k <- function(metrics_df, min_segment_size_pct = 10) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("K SELECTION RECOMMENDATION\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  # Filter to k values meeting size constraint
  valid_k <- metrics_df$k[metrics_df$smallest_segment_pct >= min_segment_size_pct]

  if (length(valid_k) == 0) {
    warning("No k values meet minimum segment size threshold. Relaxing constraint.",
            call. = FALSE)
    valid_k <- metrics_df$k
  }

  # Among valid k, find best silhouette
  valid_metrics <- metrics_df[metrics_df$k %in% valid_k, ]
  best_idx <- which.max(valid_metrics$avg_silhouette)
  recommended_k <- valid_metrics$k[best_idx]
  recommended_sil <- valid_metrics$avg_silhouette[best_idx]

  # Quality assessment
  quality <- if (recommended_sil > 0.7) {
    "Strong"
  } else if (recommended_sil > 0.5) {
    "Good"
  } else if (recommended_sil > 0.3) {
    "Acceptable"
  } else {
    "Weak"
  }

  # Generate rationale
  rationale <- sprintf(
    "k=%d maximizes silhouette score (%.3f - %s separation) while meeting size constraints",
    recommended_k, recommended_sil, quality
  )

  # Display recommendation
  cat(sprintf("Recommended: k = %d\n", recommended_k))
  cat(sprintf("  Silhouette: %.3f (%s)\n", recommended_sil, quality))
  cat(sprintf("  Smallest segment: %.1f%%\n",
              valid_metrics$smallest_segment_pct[best_idx]))
  cat(sprintf("  Between/Total SS: %.3f\n",
              valid_metrics$betweenss_totss[best_idx]))

  # Show alternatives
  cat("\nAlternatives:\n")
  for (i in 1:nrow(valid_metrics)) {
    k <- valid_metrics$k[i]
    sil <- valid_metrics$avg_silhouette[i]
    marker <- if (k == recommended_k) " ← Recommended" else ""
    cat(sprintf("  k=%d: Silhouette=%.3f%s\n", k, sil, marker))
  }

  return(list(
    recommended_k = recommended_k,
    recommended_silhouette = recommended_sil,
    quality = quality,
    rationale = rationale,
    alternatives = valid_metrics
  ))
}
