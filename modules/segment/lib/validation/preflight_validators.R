# ==============================================================================
# PREFLIGHT VALIDATORS - TURAS Segment Module
# ==============================================================================
# Cross-referential validation between config and actual data.
# Catches configuration mistakes before analysis begins.
#
# VERSION HISTORY:
# V1.0 - Initial creation (2026-03-08)
#        - 15 cross-referential checks
#        - Integrates into validate_segment_preflight() pipeline
#
# DEPENDENCIES:
# - log_issue() from modules/shared/lib/logging_utils.R
#   OR create_error_log() / log_issue() must be available in the session
#
# USAGE:
#   source("modules/shared/lib/logging_utils.R")
#   source("modules/segment/lib/validation/preflight_validators.R")
#   error_log <- create_error_log()
#   error_log <- validate_segment_preflight(config, data, error_log)
#
# FUNCTIONS EXPORTED:
# - log_seg_preflight_issue()              - Logging helper
# - check_data_file_exists()               - Data file path resolves
# - check_clustering_vars_in_data()        - Clustering vars exist as columns
# - check_clustering_vars_numeric()        - Clustering vars are numeric
# - check_profile_vars_in_data()           - Profile vars exist (if specified)
# - check_id_variable_in_data()            - ID variable exists
# - check_id_variable_unique()             - ID variable has unique values
# - check_sample_size_adequate()           - n >= max(100, 30*k, 10*p)
# - check_k_range_valid()                  - k_min < k_max, k_fixed valid
# - check_method_packages_available()      - Required packages installed
# - check_missing_data_rates()             - Per-variable missing data rates
# - check_variable_variance()              - Zero/near-zero variance
# - check_high_correlation_pairs()         - Multicollinearity >0.95
# - check_outlier_config_valid()           - Outlier config consistency
# - check_output_directory_writable()      - Output path is writable
# - check_segment_names_file()             - Names file exists if specified
# - validate_segment_preflight()           - Main orchestrator
# ==============================================================================


# ==============================================================================
# LOGGING HELPER
# ==============================================================================

#' Log a segment preflight issue to the error log
#'
#' Convenience wrapper around log_issue() that automatically sets the
#' Component to "Preflight" for all segment preflight checks.
#'
#' @param error_log Data frame, error log to append to
#' @param issue_type Character, type/category of issue
#' @param description Character, detailed description of the issue
#' @param question_code Character, related variable name (default: "")
#' @param severity Character, "Error", "Warning", or "Info" (default: "Warning")
#' @return Data frame, updated error log
#' @keywords internal
log_seg_preflight_issue <- function(error_log, issue_type, description,
                                    question_code = "", severity = "Warning") {
  log_issue(
    error_log = error_log,
    component = "Preflight",
    issue_type = issue_type,
    description = description,
    question_code = question_code,
    severity = severity
  )
}


# ==============================================================================
# CHECK 1: Data file exists
# ==============================================================================

#' Check Data File Exists
#'
#' Verifies that the data file specified in config actually exists on disk.
#'
#' @param config Configuration list
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_data_file_exists <- function(config, error_log) {
  if (is.null(config$data_file) || !nzchar(trimws(config$data_file))) {
    error_log <- log_seg_preflight_issue(
      error_log, "Missing Data File",
      "No 'data_file' parameter found in configuration. A data file is required.",
      severity = "Error"
    )
    return(error_log)
  }

  if (!file.exists(config$data_file)) {
    error_log <- log_seg_preflight_issue(
      error_log, "Data File Not Found",
      sprintf("Data file does not exist: %s", config$data_file),
      severity = "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 2: Clustering variables exist in data
# ==============================================================================

#' Check Clustering Variables Exist in Data
#'
#' Verifies that all clustering variables specified in config exist as
#' columns in the actual data.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_clustering_vars_in_data <- function(config, data, error_log) {
  if (is.null(config$clustering_vars) || length(config$clustering_vars) == 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "No Clustering Variables",
      "No clustering_vars specified in configuration.",
      severity = "Error"
    )
    return(error_log)
  }

  missing_vars <- setdiff(config$clustering_vars, names(data))
  if (length(missing_vars) > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Missing Clustering Variables",
      sprintf("%d clustering variable(s) not found in data: %s",
              length(missing_vars), paste(missing_vars, collapse = ", ")),
      question_code = paste(missing_vars, collapse = ";"),
      severity = "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 3: Clustering variables are numeric
# ==============================================================================

#' Check Clustering Variables Are Numeric
#'
#' Verifies that all clustering variables contain numeric data suitable
#' for distance-based clustering.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_clustering_vars_numeric <- function(config, data, error_log) {
  if (is.null(config$clustering_vars)) return(error_log)

  present_vars <- intersect(config$clustering_vars, names(data))
  non_numeric <- character(0)
  for (v in present_vars) {
    if (!is.numeric(data[[v]])) {
      non_numeric <- c(non_numeric, v)
    }
  }

  if (length(non_numeric) > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Non-Numeric Clustering Variables",
      sprintf("%d clustering variable(s) are not numeric: %s. K-means and distance-based clustering require numeric variables.",
              length(non_numeric), paste(non_numeric, collapse = ", ")),
      question_code = paste(non_numeric, collapse = ";"),
      severity = "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 4: Profile variables exist in data (if specified)
# ==============================================================================

#' Check Profile Variables Exist in Data
#'
#' Verifies that profile variables (used for segment characterization but
#' not clustering) exist in the data.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_profile_vars_in_data <- function(config, data, error_log) {
  if (is.null(config$profile_vars) || length(config$profile_vars) == 0) {
    return(error_log)
  }

  missing_vars <- setdiff(config$profile_vars, names(data))
  if (length(missing_vars) > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Missing Profile Variables",
      sprintf("%d profile variable(s) not found in data: %s. These will be skipped during profiling.",
              length(missing_vars), paste(missing_vars, collapse = ", ")),
      question_code = paste(missing_vars, collapse = ";"),
      severity = "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 5: ID variable exists in data
# ==============================================================================

#' Check ID Variable Exists in Data
#'
#' Verifies that the respondent ID variable specified in config exists
#' in the data.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_id_variable_in_data <- function(config, data, error_log) {
  if (is.null(config$id_variable) || !nzchar(trimws(config$id_variable))) {
    error_log <- log_seg_preflight_issue(
      error_log, "Missing ID Variable",
      "No 'id_variable' specified in configuration. A unique respondent ID is required.",
      severity = "Error"
    )
    return(error_log)
  }

  if (!(config$id_variable %in% names(data))) {
    error_log <- log_seg_preflight_issue(
      error_log, "ID Variable Not Found",
      sprintf("ID variable '%s' not found in data columns.", config$id_variable),
      question_code = config$id_variable,
      severity = "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 6: ID variable has unique values
# ==============================================================================

#' Check ID Variable Has Unique Values
#'
#' Verifies that the ID column has no duplicates so segment assignments
#' are unambiguous.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_id_variable_unique <- function(config, data, error_log) {
  if (is.null(config$id_variable) || !(config$id_variable %in% names(data))) {
    return(error_log)
  }

  ids <- data[[config$id_variable]]
  n_dupes <- sum(duplicated(ids))
  if (n_dupes > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Duplicate IDs",
      sprintf("%d duplicate value(s) in ID variable '%s'. Each respondent must have a unique ID.",
              n_dupes, config$id_variable),
      question_code = config$id_variable,
      severity = "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 7: Sample size adequate
# ==============================================================================

#' Check Sample Size Is Adequate
#'
#' Verifies that the dataset has enough observations for the requested
#' number of clusters and variables.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_sample_size_adequate <- function(config, data, error_log) {
  n <- nrow(data)
  k <- if (!is.null(config$k_fixed)) config$k_fixed else config$k_max
  p <- length(config$clustering_vars)

  if (is.null(k)) return(error_log)

  min_required <- max(100, k * 30, p * 10)

  if (n < min_required) {
    error_log <- log_seg_preflight_issue(
      error_log, "Insufficient Sample Size",
      sprintf("Dataset has %d rows but %d-cluster solution with %d variables requires at least %d. Consider reducing k or variables.",
              n, k, p, min_required),
      severity = "Error"
    )
  } else if (n < min_required * 1.5) {
    error_log <- log_seg_preflight_issue(
      error_log, "Marginal Sample Size",
      sprintf("Dataset has %d rows for %d-cluster solution (minimum: %d). Results may be unstable.",
              n, k, min_required),
      severity = "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 8: K range is valid
# ==============================================================================

#' Check K Range Is Valid
#'
#' Verifies that k_min/k_max or k_fixed are valid and consistent.
#'
#' @param config Configuration list
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_k_range_valid <- function(config, error_log) {
  mode <- config$mode %||% "exploration"

  if (mode == "exploration") {
    if (is.null(config$k_min) || is.null(config$k_max)) {
      error_log <- log_seg_preflight_issue(
        error_log, "Missing K Range",
        "Exploration mode requires both k_min and k_max to be set.",
        severity = "Error"
      )
      return(error_log)
    }

    if (config$k_min >= config$k_max) {
      error_log <- log_seg_preflight_issue(
        error_log, "Invalid K Range",
        sprintf("k_min (%d) must be less than k_max (%d).", config$k_min, config$k_max),
        severity = "Error"
      )
    }

    if (config$k_min < 2) {
      error_log <- log_seg_preflight_issue(
        error_log, "K Too Small",
        sprintf("k_min (%d) must be at least 2.", config$k_min),
        severity = "Error"
      )
    }

    if (config$k_max > 15) {
      error_log <- log_seg_preflight_issue(
        error_log, "K Range Very Large",
        sprintf("k_max (%d) is very large. Solutions with >10 segments are rarely meaningful in market research.",
                config$k_max),
        severity = "Warning"
      )
    }
  } else {
    if (is.null(config$k_fixed) || config$k_fixed < 2) {
      error_log <- log_seg_preflight_issue(
        error_log, "Invalid K Fixed",
        sprintf("Final mode requires k_fixed >= 2, got: %s", config$k_fixed %||% "NULL"),
        severity = "Error"
      )
    }
  }

  error_log
}


# ==============================================================================
# CHECK 9: Required packages available
# ==============================================================================

#' Check Method Packages Are Available
#'
#' Verifies that packages required by the chosen clustering method
#' are installed.
#'
#' @param config Configuration list
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_method_packages_available <- function(config, error_log) {
  method <- tolower(config$method %||% "kmeans")

  if (method == "gmm" && !requireNamespace("mclust", quietly = TRUE)) {
    error_log <- log_seg_preflight_issue(
      error_log, "Package Missing",
      "GMM clustering requires the 'mclust' package. Install with: install.packages('mclust')",
      severity = "Error"
    )
  }

  if (method == "hclust" && !requireNamespace("fastcluster", quietly = TRUE)) {
    error_log <- log_seg_preflight_issue(
      error_log, "Optional Package Missing",
      "Package 'fastcluster' not installed. Using base R hclust (slower for large datasets). Install with: install.packages('fastcluster')",
      severity = "Info"
    )
  }

  if (config$generate_rules %||% FALSE) {
    if (!requireNamespace("rpart", quietly = TRUE)) {
      error_log <- log_seg_preflight_issue(
        error_log, "Optional Package Missing",
        "Classification rules require 'rpart' package. Install with: install.packages('rpart')",
        severity = "Warning"
      )
    }
  }

  error_log
}


# ==============================================================================
# CHECK 10: Per-variable missing data rates
# ==============================================================================

#' Check Missing Data Rates Per Variable
#'
#' Reports variables with high missing data rates that could affect
#' clustering quality.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_missing_data_rates <- function(config, data, error_log) {
  if (is.null(config$clustering_vars)) return(error_log)

  present_vars <- intersect(config$clustering_vars, names(data))
  threshold <- config$missing_threshold %||% 15

  high_missing <- character(0)
  for (v in present_vars) {
    pct_missing <- sum(is.na(data[[v]])) / nrow(data) * 100
    if (pct_missing > threshold) {
      high_missing <- c(high_missing,
        sprintf("%s (%.1f%%)", v, pct_missing))
    }
  }

  if (length(high_missing) > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "High Missing Data",
      sprintf("%d variable(s) exceed %.0f%% missing data threshold: %s",
              length(high_missing), threshold, paste(high_missing, collapse = ", ")),
      severity = "Warning"
    )
  }

  # Check if listwise deletion would remove too many cases
  complete_cases <- sum(complete.cases(data[, present_vars, drop = FALSE]))
  pct_complete <- complete_cases / nrow(data) * 100
  if (pct_complete < 70) {
    error_log <- log_seg_preflight_issue(
      error_log, "Low Complete Cases",
      sprintf("Only %.1f%% of cases (%d of %d) are complete across all clustering variables. Consider imputation instead of listwise deletion.",
              pct_complete, complete_cases, nrow(data)),
      severity = "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 11: Zero/near-zero variance variables
# ==============================================================================

#' Check Variable Variance
#'
#' Flags variables with zero or near-zero variance that add noise
#' without discriminating between segments.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_variable_variance <- function(config, data, error_log) {
  if (is.null(config$clustering_vars)) return(error_log)

  present_vars <- intersect(config$clustering_vars, names(data))

  zero_var <- character(0)
  low_var <- character(0)

  for (v in present_vars) {
    if (!is.numeric(data[[v]])) next
    v_var <- var(data[[v]], na.rm = TRUE)
    if (is.na(v_var) || v_var == 0) {
      zero_var <- c(zero_var, v)
    } else if (v_var < 0.01) {
      low_var <- c(low_var, sprintf("%s (var=%.4f)", v, v_var))
    }
  }

  if (length(zero_var) > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Zero Variance Variables",
      sprintf("%d variable(s) have zero variance (all values identical): %s. Remove these from clustering_vars.",
              length(zero_var), paste(zero_var, collapse = ", ")),
      question_code = paste(zero_var, collapse = ";"),
      severity = "Error"
    )
  }

  if (length(low_var) > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Low Variance Variables",
      sprintf("%d variable(s) have near-zero variance: %s. These contribute little to segment differentiation.",
              length(low_var), paste(low_var, collapse = ", ")),
      severity = "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 12: Multicollinearity (high correlations)
# ==============================================================================

#' Check High Correlation Pairs
#'
#' Flags pairs of clustering variables with very high correlations
#' that may cause redundancy in the clustering solution.
#'
#' @param config Configuration list
#' @param data Data frame, survey data
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_high_correlation_pairs <- function(config, data, error_log) {
  if (is.null(config$clustering_vars)) return(error_log)

  present_vars <- intersect(config$clustering_vars, names(data))
  numeric_data <- data[, present_vars, drop = FALSE]
  numeric_data <- numeric_data[, sapply(numeric_data, is.numeric), drop = FALSE]

  if (ncol(numeric_data) < 2) return(error_log)

  cor_matrix <- tryCatch(
    cor(numeric_data, use = "pairwise.complete.obs"),
    error = function(e) NULL
  )
  if (is.null(cor_matrix)) return(error_log)

  # Check for |r| > 0.95 (near-perfect collinearity)
  near_perfect <- character(0)
  for (i in 1:(ncol(cor_matrix) - 1)) {
    for (j in (i + 1):ncol(cor_matrix)) {
      r <- cor_matrix[i, j]
      if (!is.na(r) && abs(r) > 0.95) {
        near_perfect <- c(near_perfect,
          sprintf("%s & %s (r=%.3f)", colnames(cor_matrix)[i],
                  colnames(cor_matrix)[j], r))
      }
    }
  }

  if (length(near_perfect) > 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Near-Perfect Multicollinearity",
      sprintf("%d pair(s) with |r| > 0.95: %s. Consider removing one variable from each pair.",
              length(near_perfect), paste(near_perfect, collapse = "; ")),
      severity = "Warning"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 13: Outlier configuration consistency
# ==============================================================================

#' Check Outlier Configuration Is Valid
#'
#' Verifies that outlier detection settings are consistent and valid.
#'
#' @param config Configuration list
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_outlier_config_valid <- function(config, error_log) {
  if (!isTRUE(config$outlier_detection)) return(error_log)

  method <- tolower(config$outlier_method %||% "zscore")
  valid_methods <- c("zscore", "mahalanobis")

  if (!(method %in% valid_methods)) {
    error_log <- log_seg_preflight_issue(
      error_log, "Invalid Outlier Method",
      sprintf("Outlier method '%s' not recognized. Valid methods: %s",
              method, paste(valid_methods, collapse = ", ")),
      severity = "Error"
    )
  }

  threshold <- config$outlier_threshold %||% 3.0
  if (!is.numeric(threshold) || threshold <= 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Invalid Outlier Threshold",
      sprintf("Outlier threshold must be a positive number, got: %s", threshold),
      severity = "Error"
    )
  }

  handling <- tolower(config$outlier_handling %||% "none")
  valid_handling <- c("none", "flag", "remove")
  if (!(handling %in% valid_handling)) {
    error_log <- log_seg_preflight_issue(
      error_log, "Invalid Outlier Handling",
      sprintf("Outlier handling '%s' not recognized. Valid options: %s",
              handling, paste(valid_handling, collapse = ", ")),
      severity = "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 14: Output directory writable
# ==============================================================================

#' Check Output Directory Is Writable
#'
#' Verifies that the output directory exists (or can be created) and
#' is writable.
#'
#' @param config Configuration list
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_output_directory_writable <- function(config, error_log) {
  output_dir <- config$output_folder

  if (is.null(output_dir) || !nzchar(trimws(output_dir))) {
    error_log <- log_seg_preflight_issue(
      error_log, "No Output Directory",
      "No 'output_folder' specified in configuration.",
      severity = "Error"
    )
    return(error_log)
  }

  # Check if parent directory exists and is writable
  parent_dir <- dirname(output_dir)
  if (!dir.exists(parent_dir)) {
    error_log <- log_seg_preflight_issue(
      error_log, "Output Parent Directory Missing",
      sprintf("Parent directory does not exist: %s", parent_dir),
      severity = "Error"
    )
  } else if (file.access(parent_dir, mode = 2) != 0) {
    error_log <- log_seg_preflight_issue(
      error_log, "Output Directory Not Writable",
      sprintf("Cannot write to output directory parent: %s", parent_dir),
      severity = "Error"
    )
  }

  error_log
}


# ==============================================================================
# CHECK 15: Segment names file exists (if specified)
# ==============================================================================

#' Check Segment Names File Exists
#'
#' If segment_names_file is specified in config, verifies the file exists.
#'
#' @param config Configuration list
#' @param error_log Data frame, error log
#' @return Updated error_log
#' @keywords internal
check_segment_names_file <- function(config, error_log) {
  if (is.null(config$segment_names_file) || !nzchar(config$segment_names_file)) {
    return(error_log)
  }

  if (!file.exists(config$segment_names_file)) {
    error_log <- log_seg_preflight_issue(
      error_log, "Segment Names File Not Found",
      sprintf("Segment names file not found: %s. Auto-generated names will be used instead.",
              config$segment_names_file),
      severity = "Warning"
    )
  }

  error_log
}


# ==============================================================================
# MAIN ORCHESTRATOR
# ==============================================================================

#' Run All Segment Preflight Validators
#'
#' Orchestrates all 15 cross-referential checks between config and data.
#' Returns an error log with all issues found. Errors prevent analysis;
#' warnings are informational.
#'
#' @param config Configuration list (from read_segment_config + validate)
#' @param data Data frame, survey data (already loaded)
#' @param error_log Data frame, error log (from create_error_log())
#' @return Updated error_log with all preflight issues
#' @export
validate_segment_preflight <- function(config, data, error_log = NULL) {
  if (is.null(error_log)) {
    error_log <- create_error_log()
  }

  cat("  Running preflight validation...\n")

  # --- File & Config Checks (can run without data) ---
  error_log <- check_data_file_exists(config, error_log)
  error_log <- check_k_range_valid(config, error_log)
  error_log <- check_method_packages_available(config, error_log)
  error_log <- check_outlier_config_valid(config, error_log)
  error_log <- check_output_directory_writable(config, error_log)
  error_log <- check_segment_names_file(config, error_log)

  # --- Data Cross-Reference Checks (require loaded data) ---
  if (!is.null(data) && nrow(data) > 0) {
    error_log <- check_clustering_vars_in_data(config, data, error_log)
    error_log <- check_clustering_vars_numeric(config, data, error_log)
    error_log <- check_profile_vars_in_data(config, data, error_log)
    error_log <- check_id_variable_in_data(config, data, error_log)
    error_log <- check_id_variable_unique(config, data, error_log)
    error_log <- check_sample_size_adequate(config, data, error_log)
    error_log <- check_missing_data_rates(config, data, error_log)
    error_log <- check_variable_variance(config, data, error_log)
    error_log <- check_high_correlation_pairs(config, data, error_log)
  }

  # --- Report Results ---
  n_errors <- sum(error_log$Severity == "Error")
  n_warnings <- sum(error_log$Severity == "Warning")
  n_info <- sum(error_log$Severity == "Info")

  if (n_errors > 0) {
    cat(sprintf("  Preflight: %d ERROR(s), %d warning(s)\n", n_errors, n_warnings))

    # Print errors to console for Shiny visibility
    error_rows <- error_log[error_log$Severity == "Error", ]
    cat("\n")
    cat("  ┌─── PREFLIGHT ERRORS ──────────────────────────────────┐\n")
    for (i in seq_len(nrow(error_rows))) {
      cat(sprintf("  │ [%s] %s\n", error_rows$Issue_Type[i], error_rows$Description[i]))
    }
    cat("  └────────────────────────────────────────────────────────┘\n\n")
  } else if (n_warnings > 0) {
    cat(sprintf("  Preflight: PASS with %d warning(s)\n", n_warnings))
  } else {
    cat("  Preflight: PASS (all checks clear)\n")
  }

  error_log
}
