# ==============================================================================
# K-MEANS CLUSTERING ENGINE
# ==============================================================================
# K-means clustering implementation with exploration and final modes
# Part of Turas Segmentation Module
#
# Performance notes:
#   - Standard k-means: Best for n < 10,000
#   - Mini-batch k-means: Recommended for n > 10,000
#
# The module automatically selects mini-batch when n > MINIBATCH_THRESHOLD
# ==============================================================================

# Source shared utilities
source("modules/shared/lib/logging_utils.R")

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Threshold for automatic mini-batch selection (in number of rows)
MINIBATCH_THRESHOLD <- 10000

# Default mini-batch settings
MINIBATCH_SIZE <- 1000       # Samples per batch
MINIBATCH_ITERATIONS <- 100  # Number of iterations


# ==============================================================================
# MINI-BATCH K-MEANS FOR LARGE DATASETS
# ==============================================================================

#' Run Mini-Batch K-Means Clustering
#'
#' Efficient k-means variant for large datasets (n > 10,000). Uses random
#' subsampling at each iteration to update cluster centers, achieving
#' near-linear time complexity O(n*k*d*iterations/batch_size).
#'
#' Mini-batch k-means trades off some cluster quality for dramatically
#' improved performance on large datasets. Typical quality loss is < 5%
#' compared to standard k-means.
#'
#' @param data Matrix, standardized clustering data
#' @param k Integer, number of clusters
#' @param batch_size Integer, samples per mini-batch (default: 1000)
#' @param max_iter Integer, maximum iterations (default: 100)
#' @param seed Integer, random seed for reproducibility
#' @param convergence_tol Numeric, convergence threshold for center movement
#' @param verbose Logical, print progress messages
#' @return List matching kmeans() output structure:
#'   - cluster: Integer vector of cluster assignments
#'   - centers: Matrix of cluster centers
#'   - totss: Total sum of squares
#'   - withinss: Within-cluster sum of squares for each cluster
#'   - tot.withinss: Total within-cluster sum of squares
#'   - betweenss: Between-cluster sum of squares
#'   - size: Number of points in each cluster
#'   - iter: Number of iterations performed
#'   - ifault: 0 if converged, 1 if max_iter reached
#' @export
#' @examples
#' # For datasets with > 10,000 rows:
#' large_data <- matrix(rnorm(50000 * 10), ncol = 10)
#' result <- run_minibatch_kmeans(large_data, k = 5)
run_minibatch_kmeans <- function(data,
                                  k,
                                  batch_size = MINIBATCH_SIZE,
                                  max_iter = MINIBATCH_ITERATIONS,
                                  seed = 123,
                                  convergence_tol = 1e-4,
                                  verbose = TRUE) {

  set.seed(seed)

  n <- nrow(data)
  d <- ncol(data)

  # Adjust batch size if larger than data
  batch_size <- min(batch_size, n)

  if (verbose) {
    cat(sprintf("Mini-batch k-means: n=%d, k=%d, batch_size=%d\n",
                n, k, batch_size))
  }

  # Initialize centers using k-means++ style initialization
  centers <- initialize_centers_plusplus(data, k, seed)

  # Track center update counts for weighted averaging
  center_counts <- rep(0, k)

  converged <- FALSE
  iter <- 0

  for (i in 1:max_iter) {
    iter <- i

    # Sample mini-batch
    batch_idx <- sample(n, batch_size, replace = FALSE)
    batch_data <- data[batch_idx, , drop = FALSE]

    # Assign batch points to nearest centers
    batch_clusters <- assign_to_nearest(batch_data, centers)

    # Update centers using mini-batch gradient
    old_centers <- centers

    for (j in 1:k) {
      cluster_points <- batch_data[batch_clusters == j, , drop = FALSE]
      n_points <- nrow(cluster_points)

      if (n_points > 0) {
        # Learning rate decreases with number of updates
        center_counts[j] <- center_counts[j] + n_points
        eta <- 1 / center_counts[j]

        # Weighted update toward batch mean
        batch_mean <- colMeans(cluster_points)
        centers[j, ] <- (1 - eta) * centers[j, ] + eta * batch_mean
      }
    }

    # Check convergence
    center_shift <- max(sqrt(rowSums((centers - old_centers)^2)))
    if (center_shift < convergence_tol) {
      converged <- TRUE
      if (verbose) {
        cat(sprintf("  Converged at iteration %d (shift=%.6f)\n", i, center_shift))
      }
      break
    }

    # Progress update every 10 iterations
    if (verbose && i %% 10 == 0) {
      cat(sprintf("  Iteration %d/%d (center shift=%.6f)\n", i, max_iter, center_shift))
    }
  }

  # Final assignment of all points
  if (verbose) {
    cat("  Final cluster assignment...\n")
  }
  clusters <- assign_to_nearest(data, centers)

  # Calculate statistics (matching kmeans output format)
  cluster_stats <- calculate_cluster_stats(data, clusters, centers, k)

  result <- list(
    cluster = clusters,
    centers = centers,
    totss = cluster_stats$totss,
    withinss = cluster_stats$withinss,
    tot.withinss = cluster_stats$tot_withinss,
    betweenss = cluster_stats$betweenss,
    size = cluster_stats$sizes,
    iter = iter,
    ifault = if (converged) 0L else 1L
  )

  class(result) <- "kmeans"
  return(result)
}


#' Initialize Cluster Centers using k-means++ Algorithm
#'
#' @param data Matrix of data points
#' @param k Number of centers to initialize
#' @param seed Random seed
#' @return Matrix of k initial centers
#' @keywords internal
initialize_centers_plusplus <- function(data, k, seed) {
  set.seed(seed)
  n <- nrow(data)
  d <- ncol(data)

  centers <- matrix(0, nrow = k, ncol = d)

  # First center: random point
  centers[1, ] <- data[sample(n, 1), ]

  if (k == 1) return(centers)

  # Subsequent centers: weighted by squared distance to nearest existing center
  for (i in 2:k) {
    # Calculate distance to nearest center for each point
    min_dists <- rep(Inf, n)
    for (j in 1:(i-1)) {
      dists <- rowSums((data - matrix(centers[j, ], n, d, byrow = TRUE))^2)
      min_dists <- pmin(min_dists, dists)
    }

    # Sample with probability proportional to squared distance
    probs <- min_dists / sum(min_dists)
    centers[i, ] <- data[sample(n, 1, prob = probs), ]
  }

  return(centers)
}


#' Assign Points to Nearest Center
#'
#' @param data Matrix of data points
#' @param centers Matrix of cluster centers
#' @return Integer vector of cluster assignments
#' @keywords internal
assign_to_nearest <- function(data, centers) {
  n <- nrow(data)
  k <- nrow(centers)
  d <- ncol(data)

  # Calculate distances to all centers
  clusters <- integer(n)

  for (i in 1:n) {
    min_dist <- Inf
    for (j in 1:k) {
      dist <- sum((data[i, ] - centers[j, ])^2)
      if (dist < min_dist) {
        min_dist <- dist
        clusters[i] <- j
      }
    }
  }

  return(clusters)
}


#' Calculate Cluster Statistics
#'
#' @param data Matrix of data points
#' @param clusters Integer vector of cluster assignments
#' @param centers Matrix of cluster centers
#' @param k Number of clusters
#' @return List with totss, withinss, tot_withinss, betweenss, sizes
#' @keywords internal
calculate_cluster_stats <- function(data, clusters, centers, k) {
  n <- nrow(data)
  d <- ncol(data)

  # Overall mean
  overall_mean <- colMeans(data)

  # Total sum of squares
  totss <- sum((data - matrix(overall_mean, n, d, byrow = TRUE))^2)

  # Within-cluster sum of squares
  withinss <- numeric(k)
  sizes <- integer(k)

  for (j in 1:k) {
    cluster_idx <- clusters == j
    sizes[j] <- sum(cluster_idx)

    if (sizes[j] > 0) {
      cluster_data <- data[cluster_idx, , drop = FALSE]
      withinss[j] <- sum((cluster_data - matrix(centers[j, ], sizes[j], d, byrow = TRUE))^2)
    }
  }

  tot_withinss <- sum(withinss)
  betweenss <- totss - tot_withinss

  return(list(
    totss = totss,
    withinss = withinss,
    tot_withinss = tot_withinss,
    betweenss = betweenss,
    sizes = sizes
  ))
}


# ==============================================================================
# STANDARD K-MEANS WITH AUTO-SELECTION
# ==============================================================================

#' Run k-means clustering for a single k value
#'
#' DESIGN: Wrapper around stats::kmeans() with automatic mini-batch selection
#' ALGORITHM: Hartigan-Wong for small datasets, mini-batch for n > 10,000
#'
#' For large datasets (n > MINIBATCH_THRESHOLD), automatically uses mini-batch
#' k-means for better performance. This can be overridden with use_minibatch.
#'
#' @param data Matrix, standardized clustering data
#' @param k Integer, number of clusters
#' @param nstart Integer, number of random starts (for standard k-means)
#' @param seed Integer, random seed for reproducibility
#' @param use_minibatch Logical or NULL. If NULL (default), auto-selects based
#'        on data size. If TRUE, forces mini-batch. If FALSE, forces standard.
#' @param batch_size Integer, batch size for mini-batch k-means
#' @param max_iter Integer, max iterations for mini-batch k-means
#' @return K-means model object (compatible with stats::kmeans output)
#' @export
run_kmeans_single <- function(data,
                               k,
                               nstart = 25,
                               seed = 123,
                               use_minibatch = NULL,
                               batch_size = MINIBATCH_SIZE,
                               max_iter = MINIBATCH_ITERATIONS) {
  set.seed(seed)

  n <- nrow(data)

  # Auto-select algorithm based on data size
  if (is.null(use_minibatch)) {
    use_minibatch <- n > MINIBATCH_THRESHOLD
  }

  if (use_minibatch) {
    # Use mini-batch k-means for large datasets
    cat(sprintf("  Using mini-batch k-means (n=%d > threshold=%d)\n",
                n, MINIBATCH_THRESHOLD))

    result <- run_minibatch_kmeans(
      data = data,
      k = k,
      batch_size = batch_size,
      max_iter = max_iter,
      seed = seed,
      verbose = FALSE
    )

    # Add minibatch indicator
    result$method <- "minibatch"

    return(result)

  } else {
    # Use standard k-means for smaller datasets
    tryCatch({
      result <- kmeans(
        x = data,
        centers = k,
        nstart = nstart,
        iter.max = 100,
        algorithm = "Hartigan-Wong"
      )

      # Check convergence
      if (result$ifault == 4) {
        warning(sprintf(
          "K-means did not converge for k=%d. Results may be suboptimal. Consider increasing nstart.",
          k
        ), call. = FALSE)
      }

      result$method <- "standard"
      return(result)

    }, error = function(e) {
      stop(sprintf("K-means clustering failed for k=%d: %s", k, conditionMessage(e)),
           call. = FALSE)
    })
  }
}

#' Run k-means exploration mode (multiple k values)
#'
#' DESIGN: Tests range of k values, stores all models
#' RETURNS: List of models with k as names
#'
#' @param data_list Prepared data from prepare_segment_data()
#' @return List with models for each k value tested
#' @export
run_kmeans_exploration <- function(data_list) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("EXPLORATION MODE: TESTING MULTIPLE K VALUES\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  config <- data_list$config
  data <- data_list$scaled_data
  k_range <- config$k_min:config$k_max

  cat(sprintf("Testing k = %d to %d\n", config$k_min, config$k_max))
  cat(sprintf("Random starts per k: %d\n", config$nstart))
  cat(sprintf("Random seed: %d\n\n", config$seed))

  models <- list()
  start_time <- Sys.time()

  for (k in k_range) {
    cat(sprintf("Running k-means for k=%d...\n", k))

    model <- run_kmeans_single(
      data = data,
      k = k,
      nstart = config$nstart,
      seed = config$seed
    )

    # Store model
    models[[as.character(k)]] <- model

    # Basic output
    cat(sprintf("  ✓ Complete: WSS=%.1f, BSS/TSS=%.3f\n",
                model$tot.withinss,
                model$betweenss / model$totss))
  }

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  cat(sprintf("\n✓ Exploration complete: %d models in %s\n",
              length(models), format_seconds(elapsed)))

  return(list(
    models = models,
    k_range = k_range,
    data_list = data_list
  ))
}

#' Run k-means final mode (single k value)
#'
#' DESIGN: Runs k-means for specified k with full diagnostics
#' RETURNS: Single model with cluster assignments
#'
#' @param data_list Prepared data from prepare_segment_data()
#' @return List with model and cluster assignments
#' @export
run_kmeans_final <- function(data_list) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("FINAL MODE: CLUSTERING WITH FIXED K\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  config <- data_list$config
  data <- data_list$scaled_data
  k <- config$k_fixed

  cat(sprintf("Number of segments: %d\n", k))
  cat(sprintf("Random starts: %d\n", config$nstart))
  cat(sprintf("Random seed: %d\n\n", config$seed))

  cat("Running k-means clustering...\n")
  start_time <- Sys.time()

  model <- run_kmeans_single(
    data = data,
    k = k,
    nstart = config$nstart,
    seed = config$seed
  )

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Extract cluster assignments
  clusters <- model$cluster

  # Check segment sizes
  segment_sizes <- table(clusters)
  segment_pcts <- prop.table(segment_sizes) * 100

  cat(sprintf("\n✓ Clustering complete in %s\n\n", format_seconds(elapsed)))

  # Display segment sizes
  cat("Segment sizes:\n")
  for (i in 1:k) {
    cat(sprintf("  Segment %d: %4d (%5.1f%%)\n",
                i, segment_sizes[i], segment_pcts[i]))
  }

  # Check minimum segment size
  min_size_pct <- min(segment_pcts)
  if (min_size_pct < config$min_segment_size_pct) {
    warning(sprintf(
      "Smallest segment is %.1f%% (threshold: %.0f%%)\nSegment %d has only %d respondents.\nConsider reducing k or adjusting min_segment_size_pct.",
      min_size_pct,
      config$min_segment_size_pct,
      which.min(segment_pcts),
      min(segment_sizes)
    ), call. = FALSE)
  } else {
    cat(sprintf("\n✓ All segments meet minimum size threshold (%.0f%%)\n",
                config$min_segment_size_pct))
  }

  # Quality metrics
  cat(sprintf("\nClustering quality:\n"))
  cat(sprintf("  Total within-cluster SS: %.1f\n", model$tot.withinss))
  cat(sprintf("  Total between-cluster SS: %.1f\n", model$betweenss))
  cat(sprintf("  Between/Total SS ratio: %.3f\n", model$betweenss / model$totss))

  return(list(
    model = model,
    clusters = clusters,
    k = k,
    data_list = data_list
  ))
}

#' Check segment sizes against minimum threshold
#'
#' DESIGN: Validates all segments meet minimum size
#' RETURNS: TRUE if valid, FALSE with warnings if not
#'
#' @param clusters Integer vector of cluster assignments
#' @param min_pct Numeric, minimum segment size as percentage
#' @return Logical, TRUE if all segments meet threshold
#' @export
check_segment_sizes <- function(clusters, min_pct) {
  segment_sizes <- table(clusters)
  segment_pcts <- prop.table(segment_sizes) * 100

  min_size <- min(segment_pcts)

  if (min_size < min_pct) {
    warning(sprintf(
      "Smallest segment is %.1f%% (threshold: %.0f%%)",
      min_size, min_pct
    ), call. = FALSE)
    return(FALSE)
  }

  return(TRUE)
}
