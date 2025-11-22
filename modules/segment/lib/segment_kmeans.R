# ==============================================================================
# K-MEANS CLUSTERING ENGINE
# ==============================================================================
# K-means clustering implementation with exploration and final modes
# Part of Turas Segmentation Module
# ==============================================================================

# Source shared utilities
source("modules/shared/lib/logging_utils.R")

#' Run k-means clustering for a single k value
#'
#' DESIGN: Wrapper around stats::kmeans() with safety checks
#' ALGORITHM: Hartigan-Wong (R default)
#'
#' @param data Matrix, standardized clustering data
#' @param k Integer, number of clusters
#' @param nstart Integer, number of random starts
#' @param seed Integer, random seed for reproducibility
#' @return K-means model object from stats::kmeans()
#' @export
run_kmeans_single <- function(data, k, nstart = 25, seed = 123) {
  set.seed(seed)

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

    return(result)

  }, error = function(e) {
    stop(sprintf("K-means clustering failed for k=%d: %s", k, conditionMessage(e)),
         call. = FALSE)
  })
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
