# ==============================================================================
# SEGMENT MODULE - HARD GUARDS (REFUSE)
# ==============================================================================
# Critical validation gates that MUST pass for analysis to proceed.
# Each guard calls segment_refuse() on failure, halting execution.
#
# Convention: guard_require_*() = hard guard (REFUSE if not met)
# ==============================================================================


#' Guard: Require Valid Data File
#'
#' @param config Configuration list
#' @keywords internal
guard_require_data_file <- function(config) {
  if (is.null(config$data_file) || !nzchar(trimws(config$data_file))) {
    segment_refuse(
      code = "CFG_NO_DATA_FILE",
      title = "No Data File Specified",
      problem = "The 'data_file' parameter is missing or empty in the configuration.",
      why_it_matters = "Segmentation requires survey data to cluster respondents.",
      how_to_fix = "Set data_file in your config to the path of your survey data file."
    )
  }

  # Resolve path relative to config file location if needed
  data_path <- config$data_file
  if (!file.exists(data_path)) {
    segment_refuse(
      code = "IO_DATA_FILE_NOT_FOUND",
      title = "Data File Not Found",
      problem = sprintf("Data file not found: %s", data_path),
      why_it_matters = "Cannot run segmentation without input data.",
      how_to_fix = c(
        "Check the file path in your configuration",
        "Ensure the file exists at the specified location",
        "Use a relative path from the config file location or an absolute path"
      )
    )
  }

  invisible(TRUE)
}


#' Guard: Require Clustering Variables
#'
#' @param config Configuration list
#' @param data Data frame
#' @keywords internal
guard_require_clustering_vars <- function(config, data = NULL) {
  vars <- config$clustering_vars

  if (is.null(vars) || length(vars) == 0) {
    segment_refuse(
      code = "CFG_NO_VARIABLES",
      title = "No Clustering Variables Specified",
      problem = "No variables were specified for segmentation.",
      why_it_matters = "Segmentation requires numeric variables to find respondent clusters.",
      how_to_fix = "Set clustering_vars in your config (comma-separated variable names)."
    )
  }

  if (length(vars) < 2) {
    segment_refuse(
      code = "CFG_INSUFFICIENT_VARIABLES",
      title = "Insufficient Clustering Variables",
      problem = sprintf("Only %d variable specified. Need at least 2.", length(vars)),
      why_it_matters = "Meaningful segmentation requires multiple variables to find patterns.",
      how_to_fix = "Add more variables to clustering_vars in your configuration."
    )
  }

  # Check variables exist in data (if data provided)
  if (!is.null(data)) {
    missing_vars <- setdiff(vars, names(data))
    if (length(missing_vars) > 0) {
      segment_refuse(
        code = "DATA_VARIABLES_NOT_FOUND",
        title = "Clustering Variables Not Found in Data",
        problem = sprintf("%d variable(s) not found in data: %s",
                         length(missing_vars), paste(missing_vars, collapse = ", ")),
        why_it_matters = "Cannot segment on variables that don't exist in the data.",
        how_to_fix = "Check variable names match data column names exactly (case-sensitive).",
        expected = vars,
        observed = names(data),
        missing = missing_vars
      )
    }

    # Check variables are numeric
    non_numeric <- character(0)
    for (v in vars) {
      if (v %in% names(data) && !is.numeric(data[[v]])) {
        non_numeric <- c(non_numeric, v)
      }
    }
    if (length(non_numeric) > 0) {
      segment_refuse(
        code = "DATA_NON_NUMERIC_VARS",
        title = "Non-Numeric Clustering Variables",
        problem = sprintf("These clustering variables are not numeric: %s",
                         paste(non_numeric, collapse = ", ")),
        why_it_matters = "K-means and distance-based clustering require numeric variables.",
        how_to_fix = c(
          "Remove non-numeric variables from clustering_vars",
          "Convert categorical variables to numeric codes before clustering",
          "Use numeric rating scales or indices for clustering"
        )
      )
    }
  }

  invisible(TRUE)
}


#' Guard: Require ID Variable
#'
#' @param config Configuration list
#' @param data Data frame
#' @keywords internal
guard_require_id_variable <- function(config, data = NULL) {
  if (is.null(config$id_variable) || !nzchar(trimws(config$id_variable))) {
    segment_refuse(
      code = "CFG_NO_ID_VARIABLE",
      title = "No ID Variable Specified",
      problem = "The 'id_variable' parameter is missing from the configuration.",
      why_it_matters = "Each respondent needs a unique ID to track segment assignments.",
      how_to_fix = "Set id_variable in your config to the respondent ID column name."
    )
  }

  if (!is.null(data) && !(config$id_variable %in% names(data))) {
    segment_refuse(
      code = "DATA_ID_NOT_FOUND",
      title = "ID Variable Not Found in Data",
      problem = sprintf("ID variable '%s' not found in data columns.", config$id_variable),
      why_it_matters = "Cannot create segment assignments without a respondent ID.",
      how_to_fix = sprintf("Check that '%s' exists in your data. Available columns: %s",
                          config$id_variable, paste(head(names(data), 10), collapse = ", "))
    )
  }

  # Check uniqueness (if data provided)
  if (!is.null(data) && config$id_variable %in% names(data)) {
    ids <- data[[config$id_variable]]
    n_dupes <- sum(duplicated(ids))
    if (n_dupes > 0) {
      segment_refuse(
        code = "DATA_DUPLICATE_IDS",
        title = "Duplicate IDs in Data",
        problem = sprintf("%d duplicate ID(s) found in '%s'.", n_dupes, config$id_variable),
        why_it_matters = "Duplicate IDs create ambiguous segment assignments.",
        how_to_fix = "Remove duplicate rows or use a unique identifier column."
      )
    }
  }

  invisible(TRUE)
}


#' Guard: Require Sufficient Sample Size
#'
#' @param n_cases Number of complete cases
#' @param k Target number of clusters
#' @param n_vars Number of clustering variables
#' @keywords internal
guard_require_sample_size <- function(n_cases, k, n_vars) {
  min_per_cluster <- 30
  min_total <- max(100, k * min_per_cluster, n_vars * 10)

  if (n_cases < min_total) {
    segment_refuse(
      code = "DATA_INSUFFICIENT_SAMPLE",
      title = "Insufficient Sample Size",
      problem = sprintf("Only %d complete cases. Need at least %d.", n_cases, min_total),
      why_it_matters = "Small samples produce unstable clusters that won't replicate.",
      how_to_fix = c(
        "Increase sample size",
        "Reduce number of clusters (k)",
        "Reduce number of clustering variables",
        "Address missing data (try imputation instead of listwise deletion)"
      ),
      details = sprintf("Complete cases: %d | Required: %d | Target k: %d | Variables: %d",
                        n_cases, min_total, k, n_vars)
    )
  }

  invisible(TRUE)
}


#' Guard: Require Valid Clustering Method
#'
#' @param method Method string from config
#' @keywords internal
guard_require_valid_method <- function(method) {
  allowed <- c("kmeans", "hclust", "gmm", "ensemble")

  if (is.null(method) || !(tolower(method) %in% allowed)) {
    segment_refuse(
      code = "CFG_INVALID_METHOD",
      title = "Invalid Clustering Method",
      problem = sprintf("Method '%s' is not supported.", method %||% "NULL"),
      why_it_matters = "Only supported algorithms can produce valid segment solutions.",
      how_to_fix = sprintf("Set method to one of: %s", paste(allowed, collapse = ", ")),
      expected = allowed,
      observed = method
    )
  }

  invisible(TRUE)
}


#' Guard: Require Package for Method
#'
#' Checks that required packages are installed for the chosen method.
#'
#' @param method Clustering method
#' @keywords internal
guard_require_method_packages <- function(method) {
  if (tolower(method) == "gmm") {
    if (!requireNamespace("mclust", quietly = TRUE)) {
      segment_refuse(
        code = "PKG_MCLUST_MISSING",
        title = "Package 'mclust' Not Installed",
        problem = "GMM clustering requires the 'mclust' package, which is not installed.",
        why_it_matters = "Gaussian Mixture Models cannot be fitted without mclust.",
        how_to_fix = "Install mclust: install.packages('mclust')"
      )
    }
  }

  if (tolower(method) == "hclust") {
    # hclust uses stats::hclust (base R) - always available
    # fastcluster is optional for speed
    if (!requireNamespace("fastcluster", quietly = TRUE)) {
      message("[TRS INFO] SEG_FASTCLUSTER: Package 'fastcluster' not installed. ",
              "Using base R hclust (slower for large datasets).")
    }
  }

  invisible(TRUE)
}


#' Guard: Require Valid K Range
#'
#' @param config Configuration list
#' @keywords internal
guard_require_valid_k <- function(config) {
  if (config$mode == "exploration") {
    if (config$k_min >= config$k_max) {
      segment_refuse(
        code = "CFG_INVALID_K_RANGE",
        title = "Invalid K Range",
        problem = sprintf("k_min (%d) must be less than k_max (%d).", config$k_min, config$k_max),
        why_it_matters = "Exploration mode needs a valid range to compare solutions.",
        how_to_fix = "Set k_max to a value greater than k_min."
      )
    }
  } else {
    if (is.null(config$k_fixed) || config$k_fixed < 2) {
      segment_refuse(
        code = "CFG_INVALID_K_FIXED",
        title = "Invalid K Fixed Value",
        problem = sprintf("k_fixed must be at least 2, got: %s", config$k_fixed %||% "NULL"),
        why_it_matters = "A segment solution needs at least 2 clusters.",
        how_to_fix = "Set k_fixed to 2 or greater."
      )
    }
  }

  invisible(TRUE)
}


#' Guard: Require Valid Cluster Solution
#'
#' @param clusters Integer vector of cluster assignments
#' @param k Expected number of clusters
#' @param min_cluster_size Minimum acceptable cluster size
#' @keywords internal
guard_require_valid_solution <- function(clusters, k, min_cluster_size = 10) {
  if (is.null(clusters) || length(clusters) == 0) {
    segment_refuse(
      code = "MODEL_CLUSTER_FAILED",
      title = "Clustering Algorithm Failed",
      problem = "The clustering algorithm did not produce a valid solution.",
      why_it_matters = "Cannot assign respondents to segments.",
      how_to_fix = c(
        "Check data for extreme outliers",
        "Try a different number of clusters",
        "Try a different clustering method"
      )
    )
  }

  cluster_sizes <- table(clusters)
  empty_clusters <- k - length(cluster_sizes)
  if (empty_clusters > 0) {
    segment_refuse(
      code = "MODEL_EMPTY_CLUSTERS",
      title = "Empty Clusters Detected",
      problem = sprintf("%d cluster(s) have no members.", empty_clusters),
      why_it_matters = "Empty clusters indicate the data doesn't support this many segments.",
      how_to_fix = "Reduce k (number of clusters) or check for data quality issues."
    )
  }

  small_clusters <- names(cluster_sizes)[cluster_sizes < min_cluster_size]
  if (length(small_clusters) > 0) {
    segment_refuse(
      code = "MODEL_CLUSTER_TOO_SMALL",
      title = "Cluster Too Small",
      problem = sprintf("%d cluster(s) have fewer than %d members.",
                       length(small_clusters), min_cluster_size),
      why_it_matters = "Very small clusters are unreliable and may not represent real segments.",
      how_to_fix = c(
        "Reduce the number of clusters",
        "Remove outliers before clustering",
        "Check if data has natural groupings"
      ),
      details = paste("Cluster sizes:", paste(paste(names(cluster_sizes), "=", cluster_sizes), collapse = ", "))
    )
  }

  invisible(TRUE)
}


#' Guard: Require Hierarchical Clustering Size Limit
#'
#' Hierarchical clustering requires O(n^2) distance matrix.
#'
#' @param n Number of observations
#' @param max_n Maximum allowed (default 15000)
#' @keywords internal
guard_require_hclust_size <- function(n, max_n = 15000) {
  if (n > max_n) {
    segment_refuse(
      code = "DATA_TOO_LARGE_FOR_HCLUST",
      title = "Dataset Too Large for Hierarchical Clustering",
      problem = sprintf("Dataset has %d rows. Hierarchical clustering requires O(n^2) memory and is limited to %d rows.",
                       n, max_n),
      why_it_matters = sprintf("A %d-row distance matrix would require ~%.1f GB of memory.",
                              n, (as.numeric(n)^2 * 8) / (1024^3)),
      how_to_fix = c(
        sprintf("Use K-means (method='kmeans') for datasets > %d rows", max_n),
        "Use GMM (method='gmm') for a model-based alternative",
        "Sample your data to reduce size"
      )
    )
  }

  invisible(TRUE)
}
