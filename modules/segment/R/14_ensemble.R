# ==============================================================================
# SEGMENT MODULE - CONSENSUS / ENSEMBLE CLUSTERING
# ==============================================================================
# Combines multiple clustering runs (across methods, k values, and random seeds)
# into a single robust consensus solution via a co-association matrix.
#
# Reference: Fred & Jain (2005) "Combining Multiple Clusterings Using
#            Evidence Accumulation"
#
# Advantages:
#   - More robust than any single method
#   - Reduces sensitivity to random initialization
#   - Combines strengths of different algorithms
#   - Provides a natural measure of cluster certainty
#
# Returns standard clustering result structure for downstream compatibility.
# ==============================================================================


#' Run Ensemble / Consensus Clustering
#'
#' Orchestrates generation of multiple partitions, builds a co-association
#' matrix, and extracts a final consensus clustering via hierarchical
#' clustering on the consensus distance.
#'
#' @param data_list Prepared data list from data prep step
#' @param config Configuration list (see details for ensemble-specific fields)
#' @param guard Guard state object
#' @return Standard clustering result list with ensemble-specific extras
#' @export
run_ensemble_clustering <- function(data_list, config, guard) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ENSEMBLE / CONSENSUS CLUSTERING\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  scaled_data <- data_list$scaled_data
  n <- nrow(scaled_data)
  k <- config$k_fixed

  # Ensemble parameters
  ensemble_methods <- config$ensemble_methods %||% c("kmeans", "hclust")
  ensemble_n_runs <- config$ensemble_n_runs %||% 50
  ensemble_k_range <- config$ensemble_k_range %||% c(max(2, k - 1), k + 1)
  nstart <- config$nstart %||% 25

  cat(sprintf("  Target k: %d\n", k))
  cat(sprintf("  Methods: %s\n", paste(ensemble_methods, collapse = ", ")))
  cat(sprintf("  Runs per method: %d\n", ensemble_n_runs))
  cat(sprintf("  k range for partitions: %d-%d\n",
              ensemble_k_range[1], ensemble_k_range[2]))

  # =========================================================================
  # STEP 1: Generate diverse partitions
  # =========================================================================

  cat("\n  Generating partitions...\n")
  partitions <- generate_ensemble_partitions(
    scaled_data = scaled_data,
    methods = ensemble_methods,
    n_runs = ensemble_n_runs,
    k_range = ensemble_k_range,
    nstart = nstart
  )

  n_partitions <- ncol(partitions)
  cat(sprintf("  Generated %d valid partitions\n", n_partitions))

  if (n_partitions < 5) {
    segment_refuse(
      code = "MODEL_ENSEMBLE_INSUFFICIENT",
      title = "Insufficient Ensemble Partitions",
      problem = sprintf("Only %d valid partitions generated (minimum 5 required).", n_partitions),
      why_it_matters = "Consensus clustering needs enough partitions for reliable results.",
      how_to_fix = c(
        "Increase ensemble_n_runs",
        "Add more methods to ensemble_methods",
        "Check data quality (too few observations or variables)"
      )
    )
  }

  # =========================================================================
  # STEP 2: Build co-association matrix
  # =========================================================================

  cat("  Building co-association matrix...\n")
  coassoc <- build_coassociation_matrix(partitions, n)

  # =========================================================================
  # STEP 3: Final clustering from consensus distance
  # =========================================================================

  cat(sprintf("  Extracting consensus solution (k = %d)...\n", k))
  consensus <- cluster_coassociation(coassoc, k)

  clusters <- consensus$clusters

  # =========================================================================
  # STEP 4: Compute standard output fields
  # =========================================================================

  # Centers
  centers <- matrix(NA, nrow = k, ncol = ncol(scaled_data))
  colnames(centers) <- colnames(scaled_data)
  rownames(centers) <- seq_len(k)
  for (seg in seq_len(k)) {
    mask <- clusters == seg
    if (sum(mask) > 0) {
      centers[seg, ] <- colMeans(scaled_data[mask, , drop = FALSE])
    }
  }

  # Sum of squares
  totss <- sum(scale(scaled_data, center = TRUE, scale = FALSE)^2)
  withinss <- numeric(k)
  for (seg in seq_len(k)) {
    mask <- clusters == seg
    if (sum(mask) > 1) {
      seg_data <- scaled_data[mask, , drop = FALSE]
      withinss[seg] <- sum(sweep(seg_data, 2, centers[seg, ])^2)
    }
  }
  tot_withinss <- sum(withinss)
  betweenss <- totss - tot_withinss

  # Consensus certainty per respondent
  certainty <- compute_consensus_certainty(coassoc, clusters, k)

  # Quality metrics
  quality <- assess_consensus_quality(coassoc, clusters, n_partitions)

  cat(sprintf("\n  Consensus rate: %.1f%%\n", quality$consensus_rate * 100))
  cat(sprintf("  Mean certainty: %.1f%%\n", mean(certainty) * 100))
  cat(sprintf("  Segment sizes: %s\n",
              paste(as.integer(table(clusters)), collapse = ", ")))

  list(
    clusters = as.integer(clusters),
    k = k,
    centers = centers,
    method = "ensemble",
    model = list(coassociation = coassoc, hclust = consensus$hc),
    method_info = list(
      n_partitions = n_partitions,
      methods_used = ensemble_methods,
      consensus_rate = quality$consensus_rate,
      mean_certainty = mean(certainty),
      certainty = certainty,
      quality = quality,
      totss = totss,
      withinss = withinss,
      tot_withinss = tot_withinss,
      betweenss = betweenss,
      size = as.integer(table(clusters))
    )
  )
}


#' Generate Diverse Ensemble Partitions
#'
#' Creates M partitions using specified methods with random seeds and
#' varying k values.
#'
#' @param scaled_data Scaled numeric matrix
#' @param methods Character vector of methods ("kmeans", "hclust")
#' @param n_runs Number of runs per method
#' @param k_range Integer vector c(k_min, k_max) for partition k values
#' @param nstart Number of random starts for k-means
#' @return Matrix of cluster assignments (n x M), columns are partitions
#' @keywords internal
generate_ensemble_partitions <- function(scaled_data, methods, n_runs,
                                         k_range, nstart) {

  n <- nrow(scaled_data)
  k_values <- seq(k_range[1], k_range[2])

  all_partitions <- list()
  idx <- 0

  for (method in methods) {
    for (run in seq_len(n_runs)) {
      # Random k from range
      k_this <- sample(k_values, 1)

      partition <- tryCatch({
        if (method == "kmeans") {
          # Random subset of features for diversity (use 70-100% of features)
          p <- ncol(scaled_data)
          n_features <- max(2, sample(ceiling(0.7 * p):p, 1))
          feature_idx <- sort(sample(p, n_features))

          km <- kmeans(scaled_data[, feature_idx, drop = FALSE],
                       centers = k_this, nstart = nstart)
          km$cluster

        } else if (method == "hclust") {
          # Random linkage for diversity
          linkages <- c("ward.D2", "complete", "average")
          linkage <- sample(linkages, 1)

          d <- dist(scaled_data)
          hc <- hclust(d, method = linkage)
          cutree(hc, k = k_this)

        } else {
          NULL
        }
      }, error = function(e) NULL)

      if (!is.null(partition) && length(unique(partition)) >= 2) {
        idx <- idx + 1
        all_partitions[[idx]] <- partition
      }
    }
  }

  # Convert to matrix
  if (length(all_partitions) == 0) {
    return(matrix(nrow = n, ncol = 0))
  }

  do.call(cbind, all_partitions)
}


#' Build Co-Association Matrix
#'
#' Computes the n x n co-association matrix where entry (i, j) is the
#' fraction of partitions in which observations i and j were assigned
#' to the same cluster. Uses sparse counting for memory efficiency.
#'
#' @param partitions Matrix of cluster assignments (n x M)
#' @param n Number of observations
#' @return Symmetric numeric matrix (n x n) with values in [0, 1]
#' @keywords internal
build_coassociation_matrix <- function(partitions, n) {

  M <- ncol(partitions)
  # Use integer counting to save memory, convert to proportion at the end
  coassoc <- matrix(0L, nrow = n, ncol = n)

  for (m in seq_len(M)) {
    clust <- partitions[, m]
    for (label in unique(clust)) {
      members <- which(clust == label)
      if (length(members) > 1) {
        # Vectorized: all pairs in this cluster
        coassoc[members, members] <- coassoc[members, members] + 1L
      }
    }
  }

  # Convert to proportions
  coassoc <- coassoc / M
  diag(coassoc) <- 1

  coassoc
}


#' Cluster the Co-Association Matrix
#'
#' Converts co-association to a distance matrix (1 - coassoc) and applies
#' average-linkage hierarchical clustering, then cuts at k clusters.
#'
#' @param coassoc Co-association matrix (n x n)
#' @param k Number of clusters to extract
#' @return List with clusters and hclust object
#' @keywords internal
cluster_coassociation <- function(coassoc, k) {

  # Convert to distance: observations that always co-cluster have distance 0
  consensus_dist <- as.dist(1 - coassoc)

  # Average linkage is standard for consensus clustering
  hc <- hclust(consensus_dist, method = "average")
  clusters <- cutree(hc, k = k)

  list(clusters = clusters, hc = hc)
}


#' Compute Consensus Certainty Per Respondent
#'
#' For each respondent, certainty is the average co-association with their
#' assigned cluster members (how consistently they cluster together).
#'
#' @param coassoc Co-association matrix
#' @param clusters Final cluster assignments
#' @param k Number of clusters
#' @return Numeric vector of certainty scores in [0, 1]
#' @keywords internal
compute_consensus_certainty <- function(coassoc, clusters, k) {

  n <- length(clusters)
  certainty <- numeric(n)

  for (seg in seq_len(k)) {
    members <- which(clusters == seg)
    if (length(members) > 1) {
      # Mean co-association with other cluster members
      for (i in members) {
        other_members <- members[members != i]
        certainty[i] <- mean(coassoc[i, other_members])
      }
    } else if (length(members) == 1) {
      certainty[members] <- 1  # sole member
    }
  }

  certainty
}


#' Assess Consensus Quality
#'
#' Computes quality metrics for the ensemble solution.
#'
#' @param coassoc Co-association matrix
#' @param clusters Final cluster assignments
#' @param n_partitions Number of partitions used
#' @return List with consensus_rate, cluster_cohesion, cluster_separation
#' @keywords internal
assess_consensus_quality <- function(coassoc, clusters, n_partitions) {

  k <- length(unique(clusters))
  n <- length(clusters)

  # Consensus rate: fraction of co-association values that are "decisive"

  # (close to 0 or 1, meaning pairs consistently go together or apart)
  off_diag <- coassoc[lower.tri(coassoc)]
  decisive <- mean(off_diag > 0.8 | off_diag < 0.2)

  # Per-cluster cohesion (mean within-cluster co-association)
  cohesion <- numeric(k)
  separation <- numeric(k)

  for (seg in seq_len(k)) {
    members <- which(clusters == seg)
    non_members <- which(clusters != seg)

    if (length(members) > 1) {
      within_vals <- coassoc[members, members]
      cohesion[seg] <- mean(within_vals[lower.tri(within_vals)])
    } else {
      cohesion[seg] <- 1
    }

    if (length(non_members) > 0 && length(members) > 0) {
      separation[seg] <- 1 - mean(coassoc[members, non_members])
    } else {
      separation[seg] <- 1
    }
  }

  list(
    consensus_rate = decisive,
    mean_cohesion = mean(cohesion),
    mean_separation = mean(separation),
    cluster_cohesion = cohesion,
    cluster_separation = separation
  )
}
