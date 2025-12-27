# ==============================================================================
# SEGMENTATION UTILITIES - DATA VALIDATION
# ==============================================================================
# Purpose: Input data quality validation and checking
# Part of: Turas Segmentation Module
# Version: 1.1.0 (Refactored for maintainability)
# ==============================================================================

#' Validate Input Data Quality
#'
#' Performs comprehensive validation of input data before segmentation
#'
#' @param data Data frame to validate
#' @param id_variable Name of ID variable
#' @param clustering_vars Character vector of clustering variables
#' @return List with validation results
#' @export
validate_input_data <- function(data, id_variable, clustering_vars) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("DATA QUALITY VALIDATION\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  issues <- list()
  warnings_count <- 0
  errors_count <- 0

  # 1. Check ID variable
  cat("1. Validating ID variable...\n")

  if (!id_variable %in% names(data)) {
    issues <- c(issues, sprintf("ERROR: ID variable '%s' not found in data", id_variable))
    errors_count <- errors_count + 1
  } else {
    # Check for duplicates
    n_duplicates <- sum(duplicated(data[[id_variable]]))
    if (n_duplicates > 0) {
      issues <- c(issues, sprintf("ERROR: %d duplicate IDs found", n_duplicates))
      errors_count <- errors_count + 1
    }

    # Check for missing IDs
    n_missing_ids <- sum(is.na(data[[id_variable]]))
    if (n_missing_ids > 0) {
      issues <- c(issues, sprintf("ERROR: %d missing IDs", n_missing_ids))
      errors_count <- errors_count + 1
    }
  }

  # 2. Check clustering variables
  cat("2. Validating clustering variables...\n")

  missing_vars <- setdiff(clustering_vars, names(data))
  if (length(missing_vars) > 0) {
    issues <- c(issues, sprintf("ERROR: Missing clustering variables: %s",
                               paste(missing_vars, collapse = ", ")))
    errors_count <- errors_count + 1
  }

  # 3. Check data types
  cat("3. Checking variable types...\n")

  for (var in intersect(clustering_vars, names(data))) {
    if (!is.numeric(data[[var]])) {
      issues <- c(issues, sprintf("ERROR: Variable '%s' is not numeric", var))
      errors_count <- errors_count + 1
    }
  }

  # 4. Check missing data
  cat("4. Analyzing missing data patterns...\n")

  for (var in intersect(clustering_vars, names(data))) {
    n_missing <- sum(is.na(data[[var]]))
    pct_missing <- 100 * n_missing / nrow(data)

    if (pct_missing > 50) {
      issues <- c(issues, sprintf("ERROR: Variable '%s' has %.1f%% missing data",
                                 var, pct_missing))
      errors_count <- errors_count + 1
    } else if (pct_missing > 20) {
      issues <- c(issues, sprintf("WARNING: Variable '%s' has %.1f%% missing data",
                                 var, pct_missing))
      warnings_count <- warnings_count + 1
    }
  }

  # 5. Check variance
  cat("5. Checking variable variance...\n")

  for (var in intersect(clustering_vars, names(data))) {
    var_data <- data[[var]][!is.na(data[[var]])]
    if (length(var_data) > 0) {
      var_variance <- var(var_data)
      if (var_variance == 0) {
        issues <- c(issues, sprintf("ERROR: Variable '%s' has zero variance (constant)",
                                   var))
        errors_count <- errors_count + 1
      } else if (var_variance < 0.01) {
        issues <- c(issues, sprintf("WARNING: Variable '%s' has very low variance (%.4f)",
                                   var, var_variance))
        warnings_count <- warnings_count + 1
      }
    }
  }

  # 6. Check sample size
  cat("6. Checking sample size...\n")

  n_complete <- sum(complete.cases(data[, intersect(clustering_vars, names(data))]))

  if (n_complete < 100) {
    issues <- c(issues, sprintf("WARNING: Only %d complete cases (recommend 100+)",
                               n_complete))
    warnings_count <- warnings_count + 1
  }

  # Summary
  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("VALIDATION SUMMARY\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  if (length(issues) == 0) {
    cat("✓ All validation checks passed!\n")
    cat(sprintf("  Total respondents: %d\n", nrow(data)))
    cat(sprintf("  Complete cases: %d\n", n_complete))
    cat(sprintf("  Clustering variables: %d\n", length(clustering_vars)))
  } else {
    cat(sprintf("Found %d issue(s):\n", length(issues)))
    cat(sprintf("  Errors: %d\n", errors_count))
    cat(sprintf("  Warnings: %d\n", warnings_count))
    cat("\n")

    for (issue in issues) {
      cat(paste0("  ", issue, "\n"))
    }
  }

  cat("\n")

  return(list(
    valid = errors_count == 0,
    errors = errors_count,
    warnings = warnings_count,
    issues = issues,
    n_respondents = nrow(data),
    n_complete = n_complete
  ))
}
