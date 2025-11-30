# ==============================================================================
# TURAS SEGMENTATION MODULE - OUTLIER DETECTION
# ==============================================================================
# Purpose: Detect and handle outliers that may distort clustering results
# Author: Turas Development Team
# ==============================================================================

#' Detect Outliers Using Z-Score Method
#'
#' Identifies respondents with extreme values on clustering variables using
#' z-score thresholds. A z-score indicates how many standard deviations a
#' value is from the mean.
#'
#' @param data Standardized data frame (z-scores already calculated)
#' @param clustering_vars Character vector of clustering variable names
#' @param threshold Numeric threshold for extreme values (default: 3.0)
#' @param min_vars Minimum number of variables that must be extreme (default: 1)
#' @return List with outlier_flags (logical vector) and details (data frame)
detect_outliers_zscore <- function(data, clustering_vars, threshold = 3.0,
                                   min_vars = 1) {

  # Validate inputs
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }

  if (!all(clustering_vars %in% names(data))) {
    missing <- clustering_vars[!clustering_vars %in% names(data)]
    stop("Clustering variables not found in data: ", paste(missing, collapse = ", "))
  }

  if (!is.numeric(threshold) || threshold <= 0) {
    stop("threshold must be a positive number")
  }

  if (!is.numeric(min_vars) || min_vars < 1) {
    stop("min_vars must be >= 1")
  }

  # Extract clustering variables
  cluster_data <- data[, clustering_vars, drop = FALSE]

  # Calculate absolute z-scores (data is already standardized)
  abs_z_scores <- abs(cluster_data)

  # Identify extreme values for each variable
  extreme_matrix <- abs_z_scores > threshold

  # Count how many variables are extreme for each respondent
  extreme_count <- rowSums(extreme_matrix, na.rm = TRUE)

  # Flag outliers based on min_vars criterion
  outlier_flags <- extreme_count >= min_vars

  # Create detailed outlier information
  outlier_details <- data.frame(
    row_index = seq_len(nrow(data)),
    extreme_vars = extreme_count,
    is_outlier = outlier_flags,
    stringsAsFactors = FALSE
  )

  # Add max z-score for each respondent
  outlier_details$max_abs_z <- apply(abs_z_scores, 1, max, na.rm = TRUE)

  # Add which variables are extreme (comma-separated list)
  extreme_var_names <- apply(extreme_matrix, 1, function(row) {
    if (sum(row, na.rm = TRUE) == 0) {
      return("")
    }
    paste(clustering_vars[row], collapse = ", ")
  })
  outlier_details$extreme_var_names <- extreme_var_names

  # Return results
  return(list(
    outlier_flags = outlier_flags,
    details = outlier_details,
    extreme_matrix = extreme_matrix,
    threshold = threshold,
    min_vars = min_vars
  ))
}


#' Detect Outliers Using Mahalanobis Distance
#'
#' Identifies multivariate outliers using Mahalanobis distance, which accounts
#' for correlations between variables. Uses chi-square distribution to determine
#' outlier threshold.
#'
#' @param data Standardized data frame
#' @param clustering_vars Character vector of clustering variable names
#' @param alpha Significance level for chi-square threshold (default: 0.001)
#' @return List with outlier_flags (logical vector) and distances
detect_outliers_mahalanobis <- function(data, clustering_vars, alpha = 0.001) {

  # Validate inputs
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }

  if (!all(clustering_vars %in% names(data))) {
    missing <- clustering_vars[!clustering_vars %in% names(data)]
    stop("Clustering variables not found in data: ", paste(missing, collapse = ", "))
  }

  # Extract clustering variables
  cluster_data <- data[, clustering_vars, drop = FALSE]

  # Remove any rows with missing values for Mahalanobis calculation
  complete_cases <- complete.cases(cluster_data)
  if (sum(complete_cases) < nrow(cluster_data)) {
    warning(sprintf(
      "Removed %d rows with missing values for Mahalanobis calculation",
      nrow(cluster_data) - sum(complete_cases)
    ))
  }

  cluster_data_complete <- cluster_data[complete_cases, , drop = FALSE]

  # CRITICAL GUARDRAIL: Check sample size vs. number of variables
  # Mahalanobis requires n > p for non-singular covariance matrix
  # Conservative rule: require n >= 5*p for stable estimation
  n <- nrow(cluster_data_complete)
  p <- ncol(cluster_data_complete)

  if (n < 3 * p) {
    stop(sprintf(
      "Mahalanobis distance requires more observations relative to variables.\n  Observations (n): %d\n  Variables (p): %d\n  Minimum required: %d (3 * p)\n  Recommended: %d (5 * p)\n\nOptions:\n  1. Use 'z_score' outlier method instead\n  2. Reduce number of clustering variables\n  3. Increase sample size",
      n, p, 3 * p, 5 * p
    ), call. = FALSE)
  }

  if (n < 5 * p) {
    warning(sprintf(
      "Mahalanobis distance may be unstable with n=%d and p=%d.\n  Recommended: n >= %d (5 * p)\n  Consider using 'z_score' method or reducing variables.",
      n, p, 5 * p
    ), call. = FALSE)
  }

  # Calculate center and covariance
  center <- colMeans(cluster_data_complete)
  cov_matrix <- cov(cluster_data_complete)

  # Calculate Mahalanobis distance
  # Handle potential singularity in covariance matrix
  distances <- rep(NA, nrow(data))

  tryCatch({
    distances[complete_cases] <- mahalanobis(
      cluster_data_complete,
      center = center,
      cov = cov_matrix
    )
  }, error = function(e) {
    stop("Could not calculate Mahalanobis distance. Covariance matrix may be singular.\n",
         "This can happen with highly correlated variables or small sample sizes.\n",
         "Consider using z-score method instead.")
  })

  # Determine threshold using chi-square distribution
  # Degrees of freedom = number of variables
  df <- length(clustering_vars)
  threshold <- qchisq(1 - alpha, df = df)

  # Flag outliers
  outlier_flags <- !is.na(distances) & distances > threshold

  # Return results
  return(list(
    outlier_flags = outlier_flags,
    distances = distances,
    threshold = threshold,
    alpha = alpha,
    df = df
  ))
}


#' Handle Outliers According to Strategy
#'
#' Processes outliers based on the specified handling strategy
#'
#' @param data Data frame with potential outliers
#' @param outlier_flags Logical vector indicating outliers
#' @param handling Strategy: "none", "flag", or "remove"
#' @return List with processed data and outlier information
handle_outliers <- function(data, outlier_flags, handling = "flag") {

  # Validate handling strategy
  valid_strategies <- c("none", "flag", "remove")
  if (!handling %in% valid_strategies) {
    stop("handling must be one of: ", paste(valid_strategies, collapse = ", "))
  }

  # Count outliers
  n_outliers <- sum(outlier_flags, na.rm = TRUE)
  n_total <- length(outlier_flags)
  pct_outliers <- 100 * n_outliers / n_total

  # Initialize result
  result <- list(
    data = data,
    outlier_flags = outlier_flags,
    n_outliers = n_outliers,
    n_total = n_total,
    pct_outliers = pct_outliers,
    handling = handling,
    removed = FALSE
  )

  # Apply handling strategy
  if (handling == "none") {
    # Do nothing, return original data
    result$message <- "Outlier detection disabled"

  } else if (handling == "flag") {
    # Keep outliers but flag them
    result$message <- sprintf(
      "Found %d potential outliers (%.1f%%). Flagged but included in clustering.",
      n_outliers, pct_outliers
    )

  } else if (handling == "remove") {
    # Remove outliers from data
    if (n_outliers > 0) {
      # DEFENSIVE: Handle NA values in outlier_flags
      # Keep rows where outlier_flags is FALSE (not TRUE and not NA)
      keep_rows <- !isTRUE(outlier_flags)
      # Alternative: keep_rows <- isFALSE(outlier_flags) - only keeps explicit FALSE
      # We use !isTRUE() to keep both FALSE and NA rows, then remove NAs explicitly
      keep_rows <- outlier_flags == FALSE
      keep_rows[is.na(keep_rows)] <- FALSE  # Treat NA as "don't keep"

      result$data <- data[keep_rows, , drop = FALSE]
      result$removed <- TRUE
      result$message <- sprintf(
        "Found %d potential outliers (%.1f%%). Removed from clustering.",
        n_outliers, pct_outliers
      )

      # Warn if removing too many records
      if (pct_outliers > 10) {
        warning(sprintf(
          "Removing %.1f%% of records as outliers. Consider reviewing threshold settings.",
          pct_outliers
        ))
      }
    } else {
      result$message <- "No outliers detected."
    }

  }

  return(result)
}


#' Create Outlier Report
#'
#' Generates a detailed report of outlier detection results
#'
#' @param outlier_result Result from detect_outliers_zscore()
#' @param data Original data frame (with ID variable)
#' @param id_var Name of ID variable
#' @param standardized_data Standardized data (z-scores)
#' @param clustering_vars Clustering variable names
#' @return Data frame with outlier details for export
create_outlier_report <- function(outlier_result, data, id_var,
                                  standardized_data, clustering_vars) {

  # Get outlier details
  details <- outlier_result$details

  # Filter to only outliers
  outlier_rows <- details$is_outlier

  if (sum(outlier_rows) == 0) {
    # No outliers found, return empty data frame with proper structure
    report <- data.frame(
      respondent_id = character(0),
      extreme_vars = numeric(0),
      max_abs_z = numeric(0),
      extreme_var_names = character(0),
      stringsAsFactors = FALSE
    )

    # Add z-score columns
    for (var in clustering_vars) {
      report[[paste0(var, "_z")]] <- numeric(0)
    }

    return(report)
  }

  # Build report for outliers
  report <- data.frame(
    respondent_id = data[[id_var]][outlier_rows],
    extreme_vars = details$extreme_vars[outlier_rows],
    max_abs_z = round(details$max_abs_z[outlier_rows], 3),
    extreme_var_names = details$extreme_var_names[outlier_rows],
    stringsAsFactors = FALSE
  )

  # Add z-scores for each clustering variable
  for (var in clustering_vars) {
    report[[paste0(var, "_z")]] <- round(
      standardized_data[[var]][outlier_rows],
      3
    )
  }

  # Sort by number of extreme variables (descending), then by max z-score
  report <- report[order(-report$extreme_vars, -report$max_abs_z), ]

  return(report)
}


#' Print Outlier Detection Summary
#'
#' Displays outlier detection results to console
#'
#' @param outlier_detection Result from detect_outliers_zscore()
#' @param outlier_handling Result from handle_outliers()
#' @param clustering_vars Clustering variable names
#' @param method Detection method ("zscore" or "mahalanobis")
print_outlier_summary <- function(outlier_detection, outlier_handling,
                                 clustering_vars, method = "zscore") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("OUTLIER DETECTION\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  if (method == "zscore") {
    cat(sprintf("Detection method: Z-score (threshold: %.1f)\n",
                outlier_detection$threshold))
    cat(sprintf("Minimum extreme variables required: %d\n\n",
                outlier_detection$min_vars))

    cat(sprintf("Checking %d clustering variables...\n",
                length(clustering_vars)))

    # Count extreme values per variable
    extreme_matrix <- outlier_detection$extreme_matrix
    for (i in seq_along(clustering_vars)) {
      var <- clustering_vars[i]
      n_extreme <- sum(extreme_matrix[, i], na.rm = TRUE)
      cat(sprintf("  %s: %d extreme values found\n", var, n_extreme))
    }

  } else if (method == "mahalanobis") {
    cat(sprintf("Detection method: Mahalanobis distance (alpha: %.3f)\n",
                outlier_detection$alpha))
    cat(sprintf("Chi-square threshold (df=%d): %.2f\n\n",
                outlier_detection$df, outlier_detection$threshold))
  }

  cat("\nOutlier summary:\n")

  # Overall counts
  details <- outlier_detection$details
  cat(sprintf("  Total respondents: %d\n", outlier_handling$n_total))
  cat(sprintf("  Flagged as outliers: %d (%.1f%%)\n",
              outlier_handling$n_outliers, outlier_handling$pct_outliers))

  if (method == "zscore") {
    # Breakdown by number of extreme variables
    for (i in 1:max(details$extreme_vars, 1)) {
      count <- sum(details$extreme_vars >= i)
      pct <- 100 * count / outlier_handling$n_total
      cat(sprintf("  Respondents with %d+ extreme variables: %d (%.1f%%)\n",
                  i, count, pct))
    }
  }

  cat("\n")
  cat(sprintf("Handling strategy: %s\n", outlier_handling$handling))
  cat(outlier_handling$message, "\n")

  if (outlier_handling$removed) {
    cat(sprintf("✓ %d records retained for clustering\n",
                nrow(outlier_handling$data)))
  } else {
    cat("✓ All respondents retained for clustering\n")
  }

  cat("\n")
}
