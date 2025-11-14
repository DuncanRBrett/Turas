# ==============================================================================
# SEGMENTATION DATA PREPARATION
# ==============================================================================
# Data loading, missing data handling, standardization
# Part of Turas Segmentation Module
# ==============================================================================

# Source shared utilities
source("modules/shared/lib/validation_utils.R")
source("modules/shared/lib/data_utils.R")
source("modules/shared/lib/logging_utils.R")

# Source segment utilities
source("modules/segment/lib/segment_outliers.R")
source("modules/segment/lib/segment_variable_selection.R")

#' Load and prepare segmentation data
#'
#' DESIGN: Loads data, validates structure, extracts variables
#' RETURNS: List with original data, clustering data, and metadata
#'
#' @param config Validated configuration list
#' @return List with data, clustering_data, profile_data, metadata
#' @export
load_segment_data <- function(config) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("DATA LOADING\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  # Load raw data
  project_root <- dirname(config$data_file)
  if (!file.exists(config$data_file)) {
    project_root <- getwd()
  }

  data <- load_survey_data(config$data_file, project_root = project_root)

  # Validate ID variable exists and is unique
  validate_column_exists(data, config$id_variable, "ID variable")

  ids <- data[[config$id_variable]]
  if (anyDuplicated(ids)) {
    stop(sprintf(
      "ID variable '%s' contains %d duplicate values. IDs must be unique.",
      config$id_variable,
      sum(duplicated(ids))
    ), call. = FALSE)
  }

  # Validate clustering variables exist
  cat("\nValidating clustering variables...\n")
  for (var in config$clustering_vars) {
    validate_column_exists(data, var, sprintf("Clustering variable '%s'", var))
  }
  cat(sprintf("✓ All %d clustering variables found\n", length(config$clustering_vars)))

  # Check clustering variables are numeric
  non_numeric <- c()
  for (var in config$clustering_vars) {
    if (!is.numeric(data[[var]])) {
      non_numeric <- c(non_numeric, var)
    }
  }

  if (length(non_numeric) > 0) {
    stop(sprintf(
      "Clustering variables must be numeric. Non-numeric variables:\n  %s",
      paste(non_numeric, collapse = "\n  ")
    ), call. = FALSE)
  }

  # Extract clustering data
  clustering_data <- data[, config$clustering_vars, drop = FALSE]

  # Determine profile variables if not specified
  if (is.null(config$profile_vars)) {
    # Use all numeric variables not used for clustering
    all_vars <- names(data)
    exclude_vars <- c(config$id_variable, config$clustering_vars)
    potential_profile_vars <- setdiff(all_vars, exclude_vars)

    # Filter to numeric variables
    profile_vars <- c()
    for (var in potential_profile_vars) {
      if (is.numeric(data[[var]])) {
        profile_vars <- c(profile_vars, var)
      }
    }

    config$profile_vars <- profile_vars
    cat(sprintf("Auto-detected %d numeric profile variables\n", length(profile_vars)))
  } else {
    # Validate specified profile variables exist
    for (var in config$profile_vars) {
      if (!var %in% names(data)) {
        warning(sprintf("Profile variable '%s' not found in data, skipping", var),
                call. = FALSE)
      }
    }
    # Keep only variables that exist
    config$profile_vars <- intersect(config$profile_vars, names(data))
  }

  # Extract profile data
  if (length(config$profile_vars) > 0) {
    profile_data <- data[, config$profile_vars, drop = FALSE]
  } else {
    profile_data <- NULL
  }

  cat(sprintf("\n✓ Data loaded successfully\n"))
  cat(sprintf("  Total respondents: %d\n", nrow(data)))
  cat(sprintf("  Clustering variables: %d\n", length(config$clustering_vars)))
  cat(sprintf("  Profile variables: %d\n", length(config$profile_vars)))

  return(list(
    data = data,
    clustering_data = clustering_data,
    profile_data = profile_data,
    config = config,
    n_original = nrow(data)
  ))
}

#' Perform Variable Selection
#'
#' DESIGN: Selects optimal subset of clustering variables if enabled
#' METHODS: Variance, correlation, factor analysis
#'
#' @param data_list List from load_segment_data()
#' @return Updated data_list with selected variables
#' @export
perform_variable_selection <- function(data_list) {
  config <- data_list$config

  # Skip if variable selection is disabled
  if (!config$variable_selection) {
    cat("\nVariable selection: Skipped (disabled in config)\n")
    data_list$variable_selection_result <- NULL
    return(data_list)
  }

  # Skip if already at or below target
  if (length(config$clustering_vars) <= config$max_clustering_vars) {
    cat(sprintf("\nVariable selection: Skipped (%d vars <= target of %d)\n",
                length(config$clustering_vars), config$max_clustering_vars))
    data_list$variable_selection_result <- NULL
    return(data_list)
  }

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("VARIABLE SELECTION\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Perform variable selection
  selection_result <- select_clustering_variables(
    data = data_list$data,
    candidate_vars = config$clustering_vars,
    target_n = config$max_clustering_vars,
    method = config$variable_selection_method,
    min_variance = config$varsel_min_variance,
    max_correlation = config$varsel_max_correlation
  )

  # Print summary
  print_variable_selection_summary(selection_result)

  # Update config with selected variables
  config$clustering_vars <- selection_result$selected_vars
  config$clustering_vars_original <- data_list$config$clustering_vars

  # Update clustering data with selected variables
  data_list$clustering_data <- data_list$data[, selection_result$selected_vars, drop = FALSE]
  data_list$config <- config
  data_list$variable_selection_result <- selection_result

  return(data_list)
}

#' Handle missing data in clustering variables
#'
#' DESIGN: Implements four strategies per config
#' TRACKS: Number of rows removed and missing percentage
#'
#' @param data_list List from load_segment_data()
#' @return Updated data_list with missing data handled
#' @export
handle_missing_data <- function(data_list) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("MISSING DATA HANDLING\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  config <- data_list$config
  clustering_data <- data_list$clustering_data

  # Check for missing data
  missing_rows <- !complete.cases(clustering_data)
  n_missing <- sum(missing_rows)
  pct_missing <- (n_missing / nrow(clustering_data)) * 100

  cat(sprintf("Missing data check:\n"))
  cat(sprintf("  Rows with missing data: %d (%.1f%%)\n", n_missing, pct_missing))

  if (n_missing == 0) {
    cat("✓ No missing data found\n")
    return(data_list)
  }

  # Check against threshold
  if (pct_missing > config$missing_threshold) {
    msg <- sprintf(
      "%.1f%% of data has missing values (threshold: %.0f%%)",
      pct_missing, config$missing_threshold
    )

    if (config$missing_data == "refuse") {
      stop(msg, "\n\nRefusing to proceed. Please clean data or adjust threshold.",
           call. = FALSE)
    } else {
      warning(msg, call. = FALSE)
    }
  }

  # Apply missing data strategy
  cat(sprintf("\nApplying strategy: %s\n", config$missing_data))

  if (config$missing_data == "listwise_deletion") {
    # Remove rows with any missing data
    keep_rows <- complete.cases(clustering_data)

    data_list$data <- data_list$data[keep_rows, ]
    data_list$clustering_data <- clustering_data[keep_rows, ]
    if (!is.null(data_list$profile_data)) {
      data_list$profile_data <- data_list$profile_data[keep_rows, ]
    }

    cat(sprintf("✓ Removed %d rows with missing data\n", n_missing))
    cat(sprintf("  Remaining: %d rows (%.1f%%)\n",
                nrow(data_list$data),
                (nrow(data_list$data) / data_list$n_original) * 100))

  } else if (config$missing_data == "mean_imputation") {
    # Impute with column means
    for (col in names(clustering_data)) {
      na_idx <- is.na(clustering_data[[col]])
      if (any(na_idx)) {
        col_mean <- mean(clustering_data[[col]], na.rm = TRUE)
        clustering_data[[col]][na_idx] <- col_mean
        cat(sprintf("  Imputed %d values in %s (mean = %.2f)\n",
                    sum(na_idx), col, col_mean))
      }
    }
    data_list$clustering_data <- clustering_data

  } else if (config$missing_data == "median_imputation") {
    # Impute with column medians
    for (col in names(clustering_data)) {
      na_idx <- is.na(clustering_data[[col]])
      if (any(na_idx)) {
        col_median <- median(clustering_data[[col]], na.rm = TRUE)
        clustering_data[[col]][na_idx] <- col_median
        cat(sprintf("  Imputed %d values in %s (median = %.2f)\n",
                    sum(na_idx), col, col_median))
      }
    }
    data_list$clustering_data <- clustering_data
  }

  return(data_list)
}

#' Standardize clustering variables
#'
#' DESIGN: Z-score standardization (mean=0, sd=1)
#' STORES: Scaling parameters for potential future use
#'
#' @param data_list List from handle_missing_data()
#' @return Updated data_list with standardized clustering data
#' @export
standardize_data <- function(data_list) {
  if (!data_list$config$standardize) {
    cat("\nStandardization: Skipped (disabled in config)\n")
    data_list$scaled_data <- as.matrix(data_list$clustering_data)
    data_list$scale_params <- NULL
    return(data_list)
  }

  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("STANDARDIZATION\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  clustering_data <- data_list$clustering_data

  # Standardize (mean = 0, sd = 1)
  scaled_matrix <- scale(clustering_data, center = TRUE, scale = TRUE)

  # Extract scaling parameters
  scale_params <- list(
    center = attr(scaled_matrix, "scaled:center"),
    scale = attr(scaled_matrix, "scaled:scale")
  )

  # Check for zero variance variables
  zero_var_vars <- names(scale_params$scale)[scale_params$scale == 0]
  if (length(zero_var_vars) > 0) {
    stop(sprintf(
      "Variables with zero variance cannot be standardized:\n  %s\n\nThese variables have no variation and should be removed.",
      paste(zero_var_vars, collapse = "\n  ")
    ), call. = FALSE)
  }

  cat("✓ Data standardized (z-scores)\n")
  cat(sprintf("  Variables: %d\n", ncol(scaled_matrix)))
  cat(sprintf("  Observations: %d\n", nrow(scaled_matrix)))

  # Show summary statistics
  cat("\nStandardized variable ranges:\n")
  for (i in 1:ncol(scaled_matrix)) {
    var_name <- colnames(scaled_matrix)[i]
    var_min <- min(scaled_matrix[, i], na.rm = TRUE)
    var_max <- max(scaled_matrix[, i], na.rm = TRUE)
    cat(sprintf("  %s: [%.2f, %.2f]\n", var_name, var_min, var_max))
  }

  data_list$scaled_data <- scaled_matrix
  data_list$scale_params <- scale_params

  return(data_list)
}

#' Detect and Handle Outliers
#'
#' DESIGN: Identifies extreme values that may distort clustering
#' METHODS: Z-score or Mahalanobis distance
#' STRATEGIES: Flag, remove, or skip outlier detection
#'
#' @param data_list List from standardize_data()
#' @return Updated data_list with outlier information
#' @export
detect_and_handle_outliers <- function(data_list) {
  config <- data_list$config

  # Skip if outlier detection is disabled
  if (!config$outlier_detection) {
    cat("\nOutlier detection: Skipped (disabled in config)\n")
    data_list$outlier_flags <- rep(FALSE, nrow(data_list$data))
    data_list$outlier_result <- NULL
    data_list$outlier_handling <- list(handling = "none", n_outliers = 0)
    return(data_list)
  }

  # Prepare standardized data as data frame
  scaled_df <- as.data.frame(data_list$scaled_data)
  colnames(scaled_df) <- config$clustering_vars

  # Detect outliers based on method
  if (config$outlier_method == "zscore") {
    outlier_result <- detect_outliers_zscore(
      data = scaled_df,
      clustering_vars = config$clustering_vars,
      threshold = config$outlier_threshold,
      min_vars = config$outlier_min_vars
    )
  } else if (config$outlier_method == "mahalanobis") {
    outlier_result <- detect_outliers_mahalanobis(
      data = scaled_df,
      clustering_vars = config$clustering_vars,
      alpha = config$outlier_alpha
    )
  } else {
    stop("Unknown outlier detection method: ", config$outlier_method, call. = FALSE)
  }

  # Handle outliers according to strategy
  outlier_handling <- handle_outliers(
    data = data_list$data,
    outlier_flags = outlier_result$outlier_flags,
    handling = config$outlier_handling
  )

  # Print summary
  print_outlier_summary(
    outlier_detection = outlier_result,
    outlier_handling = outlier_handling,
    clustering_vars = config$clustering_vars,
    method = config$outlier_method
  )

  # Update data_list based on handling strategy
  if (outlier_handling$removed && outlier_handling$n_outliers > 0) {
    # Remove outliers from all data structures
    keep_rows <- !outlier_result$outlier_flags

    data_list$data <- data_list$data[keep_rows, ]
    data_list$clustering_data <- data_list$clustering_data[keep_rows, ]
    if (!is.null(data_list$profile_data)) {
      data_list$profile_data <- data_list$profile_data[keep_rows, ]
    }
    data_list$scaled_data <- data_list$scaled_data[keep_rows, , drop = FALSE]

    # Update outlier flags to reflect remaining records
    data_list$outlier_flags <- rep(FALSE, nrow(data_list$data))
  } else {
    # Keep outlier flags for reporting
    data_list$outlier_flags <- outlier_result$outlier_flags
  }

  # Store outlier results for reporting
  data_list$outlier_result <- outlier_result
  data_list$outlier_handling <- outlier_handling

  return(data_list)
}

#' Run pre-clustering quality checks
#'
#' DESIGN: Validates data is suitable for clustering
#' CHECKS: Sample size, variance, correlations
#'
#' @param data_list List from standardize_data()
#' @return Updated data_list with quality check results
#' @export
pre_clustering_checks <- function(data_list) {
  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("PRE-CLUSTERING QUALITY CHECKS\n")
  cat(paste(rep("=", 80), collapse = ""), "\n\n")

  config <- data_list$config
  scaled_data <- data_list$scaled_data
  n_obs <- nrow(scaled_data)
  n_vars <- ncol(scaled_data)

  warnings_list <- c()

  # Sample size check
  min_required_n <- config$k_max * 50
  cat(sprintf("Sample size: %d\n", n_obs))
  if (n_obs < min_required_n) {
    stop(sprintf(
      "Sample size (%d) insufficient for k=%d\nMinimum required: %d (50 obs per cluster)",
      n_obs, config$k_max, min_required_n
    ), call. = FALSE)
  }
  cat(sprintf("✓ Sufficient for k_max=%d\n", config$k_max))

  # Variance check
  cat("\nVariable variance check:\n")
  for (i in 1:n_vars) {
    var_sd <- sd(scaled_data[, i], na.rm = TRUE)
    var_name <- colnames(scaled_data)[i]

    if (var_sd < 0.1) {
      warning_msg <- sprintf("Variable '%s' has very low variance (SD=%.3f)", var_name, var_sd)
      warnings_list <- c(warnings_list, warning_msg)
      cat(sprintf("⚠ %s\n", warning_msg))
    } else {
      cat(sprintf("✓ %s: SD = %.3f\n", var_name, var_sd))
    }
  }

  # Correlation check
  cat("\nCorrelation check:\n")
  cor_matrix <- cor(scaled_data, use = "complete.obs")
  high_cor_pairs <- which(abs(cor_matrix) > 0.9 & cor_matrix != 1, arr.ind = TRUE)

  if (nrow(high_cor_pairs) > 0) {
    unique_pairs <- high_cor_pairs[high_cor_pairs[,1] < high_cor_pairs[,2], , drop = FALSE]
    if (nrow(unique_pairs) > 0) {
      for (i in 1:nrow(unique_pairs)) {
        var1 <- colnames(cor_matrix)[unique_pairs[i, 1]]
        var2 <- colnames(cor_matrix)[unique_pairs[i, 2]]
        cor_val <- cor_matrix[unique_pairs[i, 1], unique_pairs[i, 2]]
        warning_msg <- sprintf("%s & %s highly correlated (r=%.3f)", var1, var2, cor_val)
        warnings_list <- c(warnings_list, warning_msg)
        cat(sprintf("⚠ %s\n", warning_msg))
      }
    }
  } else {
    cat("✓ No highly correlated pairs (r > 0.9)\n")
  }

  # Summary
  cat(sprintf("\n✓ Pre-clustering checks complete\n"))
  if (length(warnings_list) > 0) {
    cat(sprintf("  Warnings: %d (review above)\n", length(warnings_list)))
  } else {
    cat("  No warnings\n")
  }

  data_list$quality_warnings <- warnings_list

  return(data_list)
}

#' Complete data preparation pipeline
#'
#' DESIGN: Runs all preparation steps in sequence
#' RETURNS: Fully prepared data ready for clustering
#'
#' @param config Validated configuration list
#' @return Prepared data list
#' @export
prepare_segment_data <- function(config) {
  # Load data
  data_list <- load_segment_data(config)

  # Perform variable selection (if enabled)
  data_list <- perform_variable_selection(data_list)

  # Handle missing data
  data_list <- handle_missing_data(data_list)

  # Standardize
  data_list <- standardize_data(data_list)

  # Detect and handle outliers
  data_list <- detect_and_handle_outliers(data_list)

  # Quality checks
  data_list <- pre_clustering_checks(data_list)

  cat("\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("DATA PREPARATION COMPLETE\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat(sprintf("✓ Ready for clustering: %d observations, %d variables\n",
              nrow(data_list$scaled_data), ncol(data_list$scaled_data)))

  return(data_list)
}
