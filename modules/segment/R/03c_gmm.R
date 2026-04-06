# ==============================================================================
# SEGMENT MODULE - GAUSSIAN MIXTURE MODELS (GMM)
# ==============================================================================
# Model-based clustering using mclust package.
#
# Advantages:
#   - Soft assignments (probability of belonging to each segment)
#   - Handles elliptical clusters (not just spherical)
#   - BIC-based principled model selection
#   - Statistical model framework (AIC, BIC, likelihood)
#   - Uncertainty quantification per respondent
#
# Limitations:
#   - Requires mclust package
#   - Computationally heavier than K-means
#   - Assumes Gaussian distribution
#   - Can struggle in very high dimensions
#
# Returns standard clustering result structure + probabilities matrix.
# ==============================================================================


#' Run Gaussian Mixture Model Clustering
#'
#' Fits a Gaussian mixture model using mclust.
#'
#' @param data_list Prepared data list from data prep step
#' @param config Configuration list
#' @param guard Guard state object
#' @return Standard clustering result list with GMM-specific extras
#' @export
run_gmm_clustering <- function(data_list, config, guard) {

  if (!requireNamespace("mclust", quietly = TRUE)) {
    segment_refuse(
      code = "PKG_MCLUST_MISSING",
      title = "Package 'mclust' Not Installed",
      problem = "GMM clustering requires the 'mclust' package, which is not installed.",
      why_it_matters = "Gaussian Mixture Models cannot be fitted without mclust.",
      how_to_fix = "Install mclust: install.packages('mclust')"
    )
  }

  # mclust::Mclust() internally calls mclustBIC() without namespace prefix,

  # so the package must be fully loaded (not just requireNamespace).
  suppressPackageStartupMessages(library(mclust))

  scaled_data <- data_list$scaled_data
  k <- config$k_fixed
  model_type <- config$gmm_model_type %||% NULL

  cat(sprintf("    Fitting GMM with k = %d...\n", k))

  # Fit model
  # G = fixed number of components
  # modelNames = covariance structure (NULL = let mclust choose best)
  gmm_fit <- tryCatch({
    if (!is.null(model_type)) {
      mclust::Mclust(scaled_data, G = k, modelNames = model_type, verbose = FALSE)
    } else {
      mclust::Mclust(scaled_data, G = k, verbose = FALSE)
    }
  }, error = function(e) {
    segment_refuse(
      code = "MODEL_GMM_FAILED",
      title = "GMM Fitting Failed",
      problem = sprintf("mclust::Mclust() failed: %s", e$message),
      why_it_matters = "Cannot create segments without a fitted model.",
      how_to_fix = c(
        "Try fewer clusters (reduce k)",
        "Try a simpler model type (e.g., gmm_model_type = 'EII')",
        "Check for constant variables or extreme outliers",
        "Try K-means as an alternative (method = 'kmeans')"
      )
    )
  })

  if (is.null(gmm_fit)) {
    segment_refuse(
      code = "MODEL_GMM_NULL",
      title = "GMM Returned NULL",
      problem = "mclust::Mclust() returned NULL (no valid model found).",
      why_it_matters = "The data may not support a mixture model with this many components.",
      how_to_fix = c(
        "Try fewer clusters",
        "Try a different covariance structure",
        "Use K-means instead"
      )
    )
  }

  clusters <- gmm_fit$classification
  probabilities <- gmm_fit$z
  uncertainty <- gmm_fit$uncertainty

  # Check for degenerate components (very small membership or high uncertainty)
  component_sizes <- table(clusters)
  small_components <- names(component_sizes)[component_sizes < 5]
  if (length(small_components) > 0) {
    cat(sprintf(
      "[SEGMENT WARNING] GMM: %d component(s) have fewer than 5 members. Solution may be unstable.\n",
      length(small_components)
    ))
  }

  # Calculate centers from model parameters
  centers <- gmm_fit$parameters$mean
  if (!is.null(centers)) {
    if (is.matrix(centers)) {
      centers <- t(centers)  # mclust returns p x k, we want k x p
    } else if (k == 1 && ncol(scaled_data) > 1) {
      # k=1, multiple variables: mean is a vector of length p
      centers <- matrix(centers, nrow = 1, ncol = length(centers))
      colnames(centers) <- colnames(scaled_data)
    } else {
      # Single variable, k > 1: vector of length k
      centers <- matrix(centers, nrow = k, ncol = 1)
      colnames(centers) <- colnames(scaled_data)
    }
  } else {
    centers <- calculate_cluster_centers(as.data.frame(scaled_data), clusters)
  }
  rownames(centers) <- seq_len(k)

  # Calculate SS components for compatibility with k-means metrics
  totss <- sum(scale(scaled_data, center = TRUE, scale = FALSE)^2)
  withinss <- numeric(k)
  for (i in seq_len(k)) {
    mask <- clusters == i
    if (sum(mask) > 1) {
      cluster_data <- scaled_data[mask, , drop = FALSE]
      cluster_center <- centers[i, ]
      withinss[i] <- sum(sweep(cluster_data, 2, cluster_center)^2)
    }
  }
  tot_withinss <- sum(withinss)
  betweenss <- totss - tot_withinss

  # BIC values for different k (useful for exploration)
  bic_value <- gmm_fit$bic

  # Identify borderline cases (high uncertainty)
  borderline_threshold <- 0.3
  n_borderline <- sum(uncertainty > borderline_threshold)

  cat(sprintf("    Model type: %s\n", gmm_fit$modelName))
  cat(sprintf("    BIC: %.1f\n", bic_value))
  cat(sprintf("    Borderline cases (uncertainty > %.0f%%): %d (%.1f%%)\n",
              borderline_threshold * 100, n_borderline,
              n_borderline / length(clusters) * 100))

  list(
    clusters = as.integer(clusters),
    k = k,
    centers = centers,
    method = "gmm",
    model = gmm_fit,
    method_info = list(
      model_type = gmm_fit$modelName,
      bic = bic_value,
      loglik = gmm_fit$loglik,
      n_parameters = gmm_fit$df,
      probabilities = probabilities,
      uncertainty = uncertainty,
      n_borderline = n_borderline,
      borderline_threshold = borderline_threshold,
      covariance_type = gmm_fit$modelName,
      totss = totss,
      withinss = withinss,
      tot_withinss = tot_withinss,
      betweenss = betweenss,
      size = as.integer(table(clusters))
    )
  )
}


#' Run GMM Exploration with BIC Model Selection
#'
#' Tests multiple k values and uses BIC to recommend optimal k.
#'
#' @param data_list Prepared data list
#' @param config Configuration list
#' @return List with BIC values and recommendations
#' @export
run_gmm_exploration <- function(data_list, config) {

  if (!requireNamespace("mclust", quietly = TRUE)) {
    segment_refuse(
      code = "PKG_MCLUST_MISSING",
      title = "Package 'mclust' Not Installed",
      problem = "GMM exploration requires the 'mclust' package, which is not installed.",
      why_it_matters = "Cannot perform BIC-based model selection without mclust.",
      how_to_fix = "Install mclust: install.packages('mclust')"
    )
  }

  # mclust internal functions require the package to be fully loaded
  suppressPackageStartupMessages(library(mclust))

  scaled_data <- data_list$scaled_data
  k_range <- seq(config$k_min, config$k_max)

  cat(sprintf("    GMM BIC exploration: k = %d to %d\n", config$k_min, config$k_max))

  # Use mclust's built-in BIC computation across k values
  bic_result <- tryCatch({
    mclust::mclustBIC(scaled_data, G = k_range, verbose = FALSE)
  }, error = function(e) {
    cat(sprintf("    [WARNING] mclustBIC failed: %s\n", e$message))
    NULL
  })

  if (!is.null(bic_result)) {
    # Find best model
    best <- summary(bic_result)
    cat(sprintf("    Best BIC model: %s with k = %d\n",
                attr(best, "modelNames")[1],
                attr(best, "G")[1]))
  }

  list(
    bic_matrix = bic_result,
    k_range = k_range,
    best_k = if (!is.null(bic_result)) attr(summary(bic_result), "G")[1] else NULL,
    best_model = if (!is.null(bic_result)) attr(summary(bic_result), "modelNames")[1] else NULL
  )
}


#' Get GMM Membership Probabilities Summary
#'
#' Creates a summary of membership probabilities for reporting.
#'
#' @param probabilities Matrix of probabilities (n x k)
#' @param uncertainty Vector of uncertainty values
#' @param segment_names Character vector of segment names
#' @return Data frame with probability summary
#' @export
summarize_gmm_membership <- function(probabilities, uncertainty, segment_names = NULL) {
  if (is.null(probabilities)) return(NULL)

  k <- ncol(probabilities)

  if (is.null(segment_names)) {
    segment_names <- paste("Segment", seq_len(k))
  }

  colnames(probabilities) <- segment_names

  # Summary statistics
  summary_df <- data.frame(
    segment = segment_names,
    mean_probability = colMeans(probabilities),
    median_probability = apply(probabilities, 2, median),
    min_probability = apply(probabilities, 2, min),
    max_probability = apply(probabilities, 2, max),
    n_primary = as.integer(table(factor(apply(probabilities, 1, which.max), levels = seq_len(k)))),
    stringsAsFactors = FALSE
  )

  # Uncertainty distribution
  uncertainty_summary <- list(
    mean = mean(uncertainty),
    median = median(uncertainty),
    q25 = quantile(uncertainty, 0.25),
    q75 = quantile(uncertainty, 0.75),
    max = max(uncertainty),
    pct_high = mean(uncertainty > 0.3) * 100,
    pct_very_high = mean(uncertainty > 0.5) * 100
  )

  list(
    segment_summary = summary_df,
    uncertainty = uncertainty_summary,
    probabilities = probabilities
  )
}
