# ==============================================================================
# SEGMENT MODULE - CLUSTERING METHOD DISPATCHER
# ==============================================================================
# Routes to the appropriate clustering algorithm based on config$method.
# All algorithms return a standard result structure for downstream processing.
#
# Supported methods:
#   - kmeans  : K-means clustering (standard + mini-batch for large n)
#   - hclust  : Hierarchical agglomerative clustering
#   - gmm     : Gaussian Mixture Models (via mclust)
#
# Standard result structure:
#   list(
#     clusters      = integer vector of assignments
#     k             = number of clusters
#     centers       = matrix of cluster centers (k x p)
#     method        = "kmeans" | "hclust" | "gmm"
#     method_info   = list(...) method-specific diagnostics
#     model         = fitted model object
#   )
# ==============================================================================

SEGMENT_VERSION <- "11.1"

#' Run Clustering Analysis
#'
#' Dispatches to the appropriate clustering algorithm based on method.
#' Both exploration and final modes are handled.
#'
#' @param data_list Prepared data list from data prep step
#' @param config Validated configuration list
#' @param guard Guard state object
#' @return List with standard clustering result structure
#' @export
run_clustering <- function(data_list, config, guard) {

  method <- tolower(config$method %||% "kmeans")

  # Guard: validate method
  guard_require_valid_method(method)

  # Guard: check method-specific package requirements
  guard_require_method_packages(method)

  # Guard: hclust size limit
  if (method == "hclust") {
    guard_require_hclust_size(nrow(data_list$scaled_data))
  }

  cat(sprintf("\n  Clustering method: %s\n", toupper(method)))

  # Dispatch to method
  result <- switch(method,
    kmeans = run_kmeans_dispatch(data_list, config, guard),
    hclust = run_hclust_dispatch(data_list, config, guard),
    gmm    = run_gmm_dispatch(data_list, config, guard),
    segment_refuse(
      code = "CFG_INVALID_METHOD",
      title = "Unsupported Clustering Method",
      problem = sprintf("Method '%s' is not implemented.", method),
      why_it_matters = "Only supported methods can produce valid results.",
      how_to_fix = "Use one of: kmeans, hclust, gmm"
    )
  )

  # Store method in guard
  guard$clustering_method <- method

  # Validate result structure
  validate_clustering_result(result, method)

  result
}


#' Run Exploration Mode Clustering
#'
#' Tests multiple values of k and returns comparison metrics.
#'
#' @param data_list Prepared data list
#' @param config Configuration list
#' @param guard Guard state object
#' @return List with exploration results for each k
#' @export
run_clustering_exploration <- function(data_list, config, guard) {

  method <- tolower(config$method %||% "kmeans")
  k_range <- seq(config$k_min, config$k_max)

  cat(sprintf("\n  Exploration mode: testing k = %d to %d (%s)\n",
              config$k_min, config$k_max, toupper(method)))

  results <- list()

  for (k in k_range) {
    cat(sprintf("    Testing k = %d ... ", k))

    # Temporarily set k_fixed for the dispatcher
    temp_config <- config
    temp_config$k_fixed <- k
    temp_config$mode <- "final"

    result_k <- tryCatch({
      run_clustering(data_list, temp_config, guard)
    }, error = function(e) {
      cat(sprintf("FAILED: %s\n", e$message))
      NULL
    })

    if (!is.null(result_k)) {
      results[[as.character(k)]] <- result_k
      cat(sprintf("OK (sizes: %s)\n",
                  paste(sort(table(result_k$clusters), decreasing = TRUE), collapse = ", ")))
    }
  }

  if (length(results) == 0) {
    segment_refuse(
      code = "MODEL_ALL_K_FAILED",
      title = "All Cluster Solutions Failed",
      problem = "No valid cluster solution was found for any tested value of k.",
      why_it_matters = "Cannot recommend a segmentation without at least one working solution.",
      how_to_fix = c(
        "Check your data for quality issues",
        "Try a different clustering method",
        "Review variable selection"
      )
    )
  }

  list(
    mode = "exploration",
    method = method,
    k_range = k_range,
    results = results,
    n_successful = length(results),
    data_list = data_list
  )
}


#' K-means Dispatcher (Exploration + Final)
#' @keywords internal
run_kmeans_dispatch <- function(data_list, config, guard) {
  k <- config$k_fixed

  scaled_data <- data_list$scaled_data
  n <- nrow(scaled_data)

  # Choose standard vs mini-batch based on size
  use_minibatch <- n > 10000

  if (use_minibatch) {
    cat(sprintf("    Using mini-batch k-means (n=%d > 10000)\n", n))
    model <- run_minibatch_kmeans(
      data = scaled_data,
      k = k,
      batch_size = min(1000, n),
      max_iter = 100,
      nstart = config$nstart %||% 50
    )
  } else {
    model <- kmeans(
      x = scaled_data,
      centers = k,
      nstart = config$nstart %||% 50,
      algorithm = "Hartigan-Wong",
      iter.max = 100
    )
  }

  # Check convergence (ifault: 0=success, 1=max iterations, 2=empty cluster)
  conv_warn <- NULL
  if (!is.null(model$ifault) && model$ifault != 0) {
    conv_warn <- sprintf("ifault=%d", model$ifault)
    cat(sprintf(
      "[SEGMENT WARNING] K-means convergence issue for k=%d: %s. Results may be suboptimal. Consider increasing nstart.\n",
      k, conv_warn
    ))
  }

  list(
    clusters = as.integer(model$cluster),
    k = k,
    centers = model$centers,
    method = "kmeans",
    model = model,
    convergence_warning = conv_warn,
    method_info = list(
      algorithm = if (use_minibatch) "mini-batch" else "Hartigan-Wong",
      nstart = config$nstart %||% 50,
      totss = model$totss,
      withinss = model$withinss,
      tot_withinss = model$tot.withinss,
      betweenss = model$betweenss,
      iter = model$iter,
      size = model$size
    )
  )
}


#' Hierarchical Clustering Dispatcher
#' @keywords internal
run_hclust_dispatch <- function(data_list, config, guard) {
  run_hclust_clustering(data_list, config, guard)
}


#' GMM Dispatcher
#' @keywords internal
run_gmm_dispatch <- function(data_list, config, guard) {
  run_gmm_clustering(data_list, config, guard)
}


#' Validate Clustering Result Structure
#'
#' Ensures all required fields are present in the result.
#'
#' @param result Clustering result list
#' @param method Clustering method name
#' @keywords internal
validate_clustering_result <- function(result, method) {
  required_fields <- c("clusters", "k", "centers", "method", "model")

  for (field in required_fields) {
    if (is.null(result[[field]])) {
      segment_refuse(
        code = "BUG_MISSING_RESULT_FIELD",
        title = "Clustering Result Incomplete",
        problem = sprintf("Required field '%s' missing from %s clustering result.", field, method),
        why_it_matters = "Downstream processing requires all standard fields.",
        how_to_fix = "This is a bug in the clustering implementation. Report to developer."
      )
    }
  }

  invisible(TRUE)
}


#' Calculate Cluster Centers from Assignments
#'
#' Utility for methods that don't natively return centers (e.g., hclust).
#'
#' @param data Numeric matrix/data frame
#' @param clusters Integer vector of assignments
#' @return Matrix of cluster centers (k x p)
#' @keywords internal
calculate_cluster_centers <- function(data, clusters) {
  k <- length(unique(clusters))
  centers <- matrix(NA, nrow = k, ncol = ncol(data))
  colnames(centers) <- colnames(data)
  rownames(centers) <- seq_len(k)

  for (i in seq_len(k)) {
    mask <- clusters == i
    if (sum(mask) > 0) {
      centers[i, ] <- colMeans(data[mask, , drop = FALSE], na.rm = TRUE)
    }
  }

  centers
}
