# ==============================================================================
# SEGMENT MODULE - HIERARCHICAL CLUSTERING
# ==============================================================================
# Agglomerative hierarchical clustering using hclust/fastcluster.
#
# Advantages over K-means:
#   - No need to pre-specify k (cut tree at desired level)
#   - Produces dendrogram for visualization
#   - Multiple linkage methods (Ward, complete, average)
#   - Reveals nested cluster structure
#
# Limitations:
#   - O(n^2) memory for distance matrix
#   - Limited to ~15,000 rows (guarded in 00a_guards_hard.R)
#   - Sensitive to linkage method choice
#
# Returns standard clustering result structure (see 03_clustering.R).
# ==============================================================================


#' Run Hierarchical Clustering
#'
#' Fits agglomerative hierarchical clustering and cuts tree at k.
#'
#' @param data_list Prepared data list from data prep step
#' @param config Configuration list
#' @param guard Guard state object
#' @return Standard clustering result list
#' @export
run_hclust_clustering <- function(data_list, config, guard) {

  scaled_data <- data_list$scaled_data
  k <- config$k_fixed
  linkage <- tolower(config$linkage_method %||% "ward.D2")

  # Validate linkage method
  allowed_linkage <- c("ward.d", "ward.d2", "single", "complete",
                       "average", "mcquitty", "median", "centroid")
  if (!(linkage %in% allowed_linkage)) {
    segment_refuse(
      code = "CFG_INVALID_LINKAGE",
      title = "Invalid Linkage Method",
      problem = sprintf("Linkage method '%s' is not supported.", linkage),
      why_it_matters = "Invalid linkage produces incorrect dendrograms.",
      how_to_fix = sprintf("Use one of: %s", paste(allowed_linkage, collapse = ", "))
    )
  }

  cat(sprintf("    Linkage method: %s\n", linkage))
  cat(sprintf("    Computing distance matrix (%d x %d)...\n", nrow(scaled_data), nrow(scaled_data)))

  # Compute distance matrix
  dist_matrix <- dist(scaled_data, method = "euclidean")

  # Use fastcluster if available, otherwise base R
  cat("    Fitting hierarchical model...\n")
  if (requireNamespace("fastcluster", quietly = TRUE)) {
    hc_model <- fastcluster::hclust(dist_matrix, method = linkage)
    hc_engine <- "fastcluster"
  } else {
    hc_model <- stats::hclust(dist_matrix, method = linkage)
    hc_engine <- "stats::hclust"
  }

  # Cut tree at k
  clusters <- stats::cutree(hc_model, k = k)

  # Calculate centers from assignments
  centers <- calculate_cluster_centers(as.data.frame(scaled_data), clusters)

  # Calculate within-cluster sum of squares
  withinss <- numeric(k)
  for (i in seq_len(k)) {
    mask <- clusters == i
    if (sum(mask) > 1) {
      cluster_data <- scaled_data[mask, , drop = FALSE]
      cluster_center <- centers[i, ]
      withinss[i] <- sum(sweep(cluster_data, 2, cluster_center)^2)
    }
  }

  totss <- sum(scale(scaled_data, center = TRUE, scale = FALSE)^2)
  tot_withinss <- sum(withinss)
  betweenss <- totss - tot_withinss

  # Extract dendrogram data for visualization
  dend_data <- extract_dendrogram_data(hc_model, k)

  list(
    clusters = as.integer(clusters),
    k = k,
    centers = centers,
    method = "hclust",
    model = hc_model,
    method_info = list(
      linkage = linkage,
      engine = hc_engine,
      n_observations = nrow(scaled_data),
      height = hc_model$height,
      merge = hc_model$merge,
      order = hc_model$order,
      dendrogram = dend_data,
      totss = totss,
      withinss = withinss,
      tot_withinss = tot_withinss,
      betweenss = betweenss,
      size = as.integer(table(clusters)),
      cophenetic_correlation = compute_cophenetic(hc_model, dist_matrix)
    )
  )
}


#' Extract Dendrogram Data for Visualization
#'
#' Extracts the tree structure in a format suitable for SVG rendering.
#'
#' @param hc_model hclust model object
#' @param k Number of clusters (for cut line)
#' @return List with dendrogram visualization data
#' @keywords internal
extract_dendrogram_data <- function(hc_model, k) {
  n <- length(hc_model$order)

  # Calculate cut height
  heights_sorted <- sort(hc_model$height, decreasing = TRUE)
  cut_height <- if (k <= length(heights_sorted)) {
    mean(c(heights_sorted[k - 1], heights_sorted[k]))
  } else {
    min(hc_model$height) * 0.5
  }

  # Extract merge steps for visualization
  merge_steps <- list()
  for (i in seq_len(nrow(hc_model$merge))) {
    merge_steps[[i]] <- list(
      step = i,
      left = hc_model$merge[i, 1],
      right = hc_model$merge[i, 2],
      height = hc_model$height[i]
    )
  }

  list(
    n_leaves = n,
    n_merges = nrow(hc_model$merge),
    cut_height = cut_height,
    k = k,
    max_height = max(hc_model$height),
    min_height = min(hc_model$height),
    order = hc_model$order,
    merge_steps = merge_steps
  )
}


#' Compute Cophenetic Correlation
#'
#' Measures how well the dendrogram preserves pairwise distances.
#' Values > 0.7 indicate good representation.
#'
#' @param hc_model hclust model
#' @param dist_matrix Original distance matrix
#' @return Cophenetic correlation coefficient
#' @keywords internal
compute_cophenetic <- function(hc_model, dist_matrix) {
  tryCatch({
    coph_dist <- stats::cophenetic(hc_model)
    cor(as.vector(dist_matrix), as.vector(coph_dist))
  }, error = function(e) {
    NA_real_
  })
}
