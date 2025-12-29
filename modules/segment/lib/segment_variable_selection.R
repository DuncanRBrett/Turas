# ==============================================================================
# TURAS SEGMENTATION MODULE - VARIABLE SELECTION
# ==============================================================================
# Purpose: Select optimal subset of variables for clustering
# Methods: Correlation, variance, factor analysis
# Author: Turas Development Team
# ==============================================================================

# Source config utilities for label formatting
source("modules/segment/lib/segment_config.R")

#' Analyze Variable Variance
#'
#' Identifies and flags low-variance variables that provide little
#' discrimination between respondents
#'
#' @param data Data frame with potential clustering variables
#' @param candidate_vars Character vector of variable names to analyze
#' @param min_variance Minimum variance threshold (default: 0.1)
#' @return List with variance analysis results
analyze_variable_variance <- function(data, candidate_vars, min_variance = 0.1) {

  # Calculate variance for each variable
  variances <- sapply(candidate_vars, function(var) {
    var(data[[var]], na.rm = TRUE)
  })

  # Identify low-variance variables
  low_variance <- variances < min_variance

  # Create results data frame
  variance_df <- data.frame(
    variable = candidate_vars,
    variance = variances,
    sd = sqrt(variances),
    low_variance = low_variance,
    stringsAsFactors = FALSE
  )

  # Sort by variance descending
  variance_df <- variance_df[order(-variance_df$variance), ]

  return(list(
    variance_df = variance_df,
    low_variance_vars = candidate_vars[low_variance],
    n_low_variance = sum(low_variance),
    threshold = min_variance
  ))
}


#' Analyze Variable Correlations
#'
#' Identifies highly correlated variable pairs and recommends which to remove
#'
#' @param data Data frame with potential clustering variables
#' @param candidate_vars Character vector of variable names to analyze
#' @param max_correlation Maximum allowed correlation (default: 0.8)
#' @return List with correlation analysis results
analyze_variable_correlations <- function(data, candidate_vars, max_correlation = 0.8) {

  # Calculate correlation matrix
  cor_data <- data[, candidate_vars, drop = FALSE]
  cor_matrix <- cor(cor_data, use = "pairwise.complete.obs")

  # Find highly correlated pairs
  high_cor_pairs <- data.frame(
    var1 = character(),
    var2 = character(),
    correlation = numeric(),
    stringsAsFactors = FALSE
  )

  for (i in 1:(length(candidate_vars) - 1)) {
    for (j in (i + 1):length(candidate_vars)) {
      cor_val <- abs(cor_matrix[i, j])
      if (cor_val > max_correlation) {
        high_cor_pairs <- rbind(high_cor_pairs, data.frame(
          var1 = candidate_vars[i],
          var2 = candidate_vars[j],
          correlation = cor_matrix[i, j],
          abs_correlation = cor_val,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # Sort by absolute correlation descending
  if (nrow(high_cor_pairs) > 0) {
    high_cor_pairs <- high_cor_pairs[order(-high_cor_pairs$abs_correlation), ]
  }

  # Determine which variables to remove from correlated pairs
  # Strategy: For each pair, remove the one with lower overall variance
  vars_to_remove <- character()

  if (nrow(high_cor_pairs) > 0) {
    variances <- sapply(candidate_vars, function(var) var(data[[var]], na.rm = TRUE))

    for (i in 1:nrow(high_cor_pairs)) {
      var1 <- high_cor_pairs$var1[i]
      var2 <- high_cor_pairs$var2[i]

      # Skip if already removed
      if (var1 %in% vars_to_remove || var2 %in% vars_to_remove) {
        next
      }

      # Remove the one with lower variance
      if (variances[var1] < variances[var2]) {
        vars_to_remove <- c(vars_to_remove, var1)
        high_cor_pairs$removed[i] <- var1
        high_cor_pairs$kept[i] <- var2
      } else {
        vars_to_remove <- c(vars_to_remove, var2)
        high_cor_pairs$removed[i] <- var2
        high_cor_pairs$kept[i] <- var1
      }
    }

    vars_to_remove <- unique(vars_to_remove)
  }

  return(list(
    cor_matrix = cor_matrix,
    high_cor_pairs = high_cor_pairs,
    vars_to_remove = vars_to_remove,
    n_high_cor_pairs = nrow(high_cor_pairs),
    threshold = max_correlation
  ))
}


#' Perform Factor Analysis for Variable Selection
#'
#' Uses exploratory factor analysis to identify underlying dimensions
#' and select representative variables
#'
#' @param data Data frame with potential clustering variables
#' @param candidate_vars Character vector of variable names to analyze
#' @param n_factors Number of factors to extract (default: auto-detect)
#' @param vars_per_factor Number of variables to keep per factor (default: 2)
#' @return List with factor analysis results
perform_factor_analysis <- function(data, candidate_vars, n_factors = NULL,
                                   vars_per_factor = 2) {

  # Check if psych package is available
  if (!requireNamespace("psych", quietly = TRUE)) {
    # TRS INFO: Optional package not available
    message("[TRS INFO] psych package not installed - skipping factor analysis method")
    return(NULL)
  }

  # Extract data for factor analysis
  fa_data <- data[, candidate_vars, drop = FALSE]

  # Remove any rows with missing data for FA
  fa_data_complete <- fa_data[complete.cases(fa_data), ]

  if (nrow(fa_data_complete) < 50) {
    # TRS INFO: Insufficient data for factor analysis
    message("[TRS INFO] Insufficient complete cases for factor analysis (< 50) - skipping")
    return(NULL)
  }

  # Determine number of factors if not specified
  if (is.null(n_factors)) {
    # Use parallel analysis to suggest number of factors
    pa_result <- psych::fa.parallel(fa_data_complete, plot = FALSE, fm = "pa")
    n_factors <- pa_result$nfact

    # Ensure at least 2 factors, max 5
    n_factors <- max(2, min(5, n_factors))
  }

  # Perform factor analysis
  fa_result <- psych::fa(fa_data_complete, nfactors = n_factors, rotate = "varimax",
                        fm = "pa", max.iter = 100)

  # Extract loadings
  loadings_matrix <- fa_result$loadings
  loadings_df <- as.data.frame(unclass(loadings_matrix))
  loadings_df$variable <- rownames(loadings_df)
  rownames(loadings_df) <- NULL

  # For each factor, identify top variables
  selected_vars <- character()
  factor_assignments <- data.frame(
    variable = candidate_vars,
    primary_factor = NA,
    primary_loading = NA,
    stringsAsFactors = FALSE
  )

  for (i in 1:n_factors) {
    factor_name <- paste0("PA", i)

    # Get loadings for this factor
    factor_loadings <- abs(loadings_df[[factor_name]])
    names(factor_loadings) <- loadings_df$variable

    # Sort by loading descending
    sorted_loadings <- sort(factor_loadings, decreasing = TRUE)

    # Select top vars_per_factor variables
    top_vars <- names(sorted_loadings)[1:min(vars_per_factor, length(sorted_loadings))]
    selected_vars <- c(selected_vars, top_vars)

    # Record primary factor for each variable
    for (var in loadings_df$variable) {
      var_loadings <- abs(loadings_df[loadings_df$variable == var, 1:n_factors])
      max_factor <- which.max(var_loadings)

      if (factor_assignments$variable[factor_assignments$variable == var][1] == var) {
        idx <- which(factor_assignments$variable == var)
        if (max_factor == i) {
          factor_assignments$primary_factor[idx] <- i
          factor_assignments$primary_loading[idx] <- loadings_df[loadings_df$variable == var, i]
        }
      }
    }
  }

  # Remove duplicates (a variable might load highly on multiple factors)
  selected_vars <- unique(selected_vars)

  return(list(
    fa_result = fa_result,
    loadings_df = loadings_df,
    n_factors = n_factors,
    selected_vars = selected_vars,
    factor_assignments = factor_assignments,
    variance_explained = sum(fa_result$Vaccounted["Proportion Var", ])
  ))
}


#' Select Variables Using Combined Criteria
#'
#' Main variable selection function that combines multiple methods
#'
#' @param data Data frame with all variables
#' @param candidate_vars Character vector of all potential clustering variables
#' @param target_n Target number of variables to select
#' @param method Selection method: "variance_correlation", "factor_analysis", or "both"
#' @param min_variance Minimum variance threshold
#' @param max_correlation Maximum correlation threshold
#' @return List with selection results
select_clustering_variables <- function(data, candidate_vars, target_n,
                                       method = "variance_correlation",
                                       min_variance = 0.1,
                                       max_correlation = 0.8,
                                       question_labels = NULL) {

  # Track selection process
  selection_log <- list()
  remaining_vars <- candidate_vars

  # Step 1: Remove low-variance variables
  cat(sprintf("Step 1: Analyzing variance (threshold: %.2f)\n", min_variance))

  variance_analysis <- analyze_variable_variance(data, remaining_vars, min_variance)

  if (variance_analysis$n_low_variance > 0) {
    # Format variable names with labels
    vars_display <- if (!is.null(question_labels)) {
      paste(format_variable_label(variance_analysis$low_variance_vars, question_labels),
            collapse = ", ")
    } else {
      paste(variance_analysis$low_variance_vars, collapse = ", ")
    }

    cat(sprintf("  Removed %d low-variance variables: %s\n",
                variance_analysis$n_low_variance, vars_display))
    remaining_vars <- setdiff(remaining_vars, variance_analysis$low_variance_vars)
  } else {
    cat("  No low-variance variables found\n")
  }

  cat(sprintf("  Remaining: %d\n", length(remaining_vars)))
  selection_log$variance <- variance_analysis

  # Step 2: Remove highly correlated variables
  cat(sprintf("\nStep 2: Analyzing correlations (threshold: %.2f)\n", max_correlation))

  correlation_analysis <- analyze_variable_correlations(data, remaining_vars, max_correlation)

  if (length(correlation_analysis$vars_to_remove) > 0) {
    # Format variable names with labels
    vars_display <- if (!is.null(question_labels)) {
      paste(format_variable_label(correlation_analysis$vars_to_remove, question_labels),
            collapse = ", ")
    } else {
      paste(correlation_analysis$vars_to_remove, collapse = ", ")
    }

    cat(sprintf("  Found %d highly correlated pairs\n",
                correlation_analysis$n_high_cor_pairs))
    cat(sprintf("  Removed %d correlated variables: %s\n",
                length(correlation_analysis$vars_to_remove), vars_display))
    remaining_vars <- setdiff(remaining_vars, correlation_analysis$vars_to_remove)
  } else {
    cat("  No highly correlated pairs found\n")
  }

  cat(sprintf("  Remaining: %d\n", length(remaining_vars)))
  selection_log$correlation <- correlation_analysis

  # Step 3: If still too many variables, use ranking method
  if (length(remaining_vars) > target_n) {
    cat(sprintf("\nStep 3: Ranking variables (%d → %d)\n",
                length(remaining_vars), target_n))

    if (method %in% c("factor_analysis", "both")) {
      # Try factor analysis
      fa_analysis <- perform_factor_analysis(
        data, remaining_vars,
        n_factors = NULL,
        vars_per_factor = ceiling(target_n / 3)
      )

      if (!is.null(fa_analysis)) {
        # Use factor analysis selections
        final_vars <- fa_analysis$selected_vars[1:min(target_n, length(fa_analysis$selected_vars))]
        selection_log$factor_analysis <- fa_analysis
        cat(sprintf("  Using factor analysis: selected %d variables\n", length(final_vars)))
      } else {
        # Fall back to variance ranking
        final_vars <- variance_analysis$variance_df$variable[1:target_n]
        cat(sprintf("  Factor analysis not available, using variance ranking\n"))
      }
    } else {
      # Use variance ranking
      var_ranks <- variance_analysis$variance_df
      var_ranks <- var_ranks[var_ranks$variable %in% remaining_vars, ]
      final_vars <- var_ranks$variable[1:min(target_n, nrow(var_ranks))]
      cat(sprintf("  Using variance ranking: selected top %d variables\n", length(final_vars)))
    }

    remaining_vars <- final_vars
  }

  # Create summary
  selected_vars <- remaining_vars
  removed_vars <- setdiff(candidate_vars, selected_vars)

  cat(sprintf("\n✓ Variable selection complete: %d → %d variables\n",
              length(candidate_vars), length(selected_vars)))

  return(list(
    selected_vars = selected_vars,
    removed_vars = removed_vars,
    n_original = length(candidate_vars),
    n_selected = length(selected_vars),
    n_removed = length(removed_vars),
    selection_log = selection_log,
    method = method,
    parameters = list(
      min_variance = min_variance,
      max_correlation = max_correlation,
      target_n = target_n
    )
  ))
}


#' Print Variable Selection Summary
#'
#' Displays variable selection results to console
#'
#' @param selection_result Result from select_clustering_variables()
#' @param question_labels Optional named vector of question labels
print_variable_selection_summary <- function(selection_result, question_labels = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("VARIABLE SELECTION SUMMARY\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  cat(sprintf("Method: %s\n", selection_result$method))
  cat(sprintf("Original variables: %d\n", selection_result$n_original))
  cat(sprintf("Selected variables: %d\n", selection_result$n_selected))
  cat(sprintf("Removed variables: %d\n\n", selection_result$n_removed))

  # Format selected variables with labels
  selected_display <- if (!is.null(question_labels)) {
    paste(format_variable_label(selection_result$selected_vars, question_labels), collapse = ", ")
  } else {
    paste(selection_result$selected_vars, collapse = ", ")
  }

  cat("Selected variables:\n")
  cat(sprintf("  %s\n", selected_display))

  if (selection_result$n_removed > 0) {
    # Format removed variables with labels
    removed_display <- if (!is.null(question_labels)) {
      paste(format_variable_label(selection_result$removed_vars, question_labels), collapse = ", ")
    } else {
      paste(selection_result$removed_vars, collapse = ", ")
    }

    cat("\nRemoved variables:\n")
    cat(sprintf("  %s\n", removed_display))
  }

  cat("\n")
}


#' Create Variable Selection Report
#'
#' Generates detailed Excel report of variable selection process
#'
#' @param selection_result Result from select_clustering_variables()
#' @param output_path Path for Excel output
export_variable_selection_report <- function(selection_result, output_path) {

  cat(sprintf("Exporting variable selection report to: %s\n", basename(output_path)))

  sheets <- list()

  # Sheet 1: Summary
  summary_df <- data.frame(
    Metric = c(
      "Original Variables",
      "Selected Variables",
      "Removed Variables",
      "Selection Method",
      "Min Variance Threshold",
      "Max Correlation Threshold"
    ),
    Value = c(
      selection_result$n_original,
      selection_result$n_selected,
      selection_result$n_removed,
      selection_result$method,
      selection_result$parameters$min_variance,
      selection_result$parameters$max_correlation
    ),
    stringsAsFactors = FALSE
  )

  sheets[["Summary"]] <- summary_df

  # Sheet 2: Selected Variables
  selected_df <- data.frame(
    Variable = selection_result$selected_vars,
    Status = "Selected",
    stringsAsFactors = FALSE
  )

  sheets[["Selected_Variables"]] <- selected_df

  # Sheet 3: Removed Variables
  if (selection_result$n_removed > 0) {
    removed_df <- data.frame(
      Variable = selection_result$removed_vars,
      Status = "Removed",
      Reason = "See Variable_Statistics sheet",
      stringsAsFactors = FALSE
    )

    sheets[["Removed_Variables"]] <- removed_df
  }

  # Sheet 4: Variable Statistics
  variance_df <- selection_result$selection_log$variance$variance_df
  variance_df$selected <- variance_df$variable %in% selection_result$selected_vars
  variance_df <- variance_df[, c("variable", "variance", "sd", "low_variance", "selected")]

  sheets[["Variable_Statistics"]] <- variance_df

  # Sheet 5: Correlation Pairs (if any)
  if (!is.null(selection_result$selection_log$correlation$high_cor_pairs) &&
      nrow(selection_result$selection_log$correlation$high_cor_pairs) > 0) {
    cor_pairs <- selection_result$selection_log$correlation$high_cor_pairs
    cor_pairs$correlation <- round(cor_pairs$correlation, 3)
    cor_pairs$abs_correlation <- round(cor_pairs$abs_correlation, 3)

    sheets[["High_Correlations"]] <- cor_pairs
  }

  # Sheet 6: Factor Analysis (if available)
  if (!is.null(selection_result$selection_log$factor_analysis)) {
    fa_log <- selection_result$selection_log$factor_analysis

    # Loadings
    loadings_df <- fa_log$loadings_df
    for (col in names(loadings_df)[grepl("PA", names(loadings_df))]) {
      loadings_df[[col]] <- round(loadings_df[[col]], 3)
    }

    sheets[["Factor_Loadings"]] <- loadings_df

    # Factor assignments
    factor_assign <- fa_log$factor_assignments
    factor_assign$primary_loading <- round(factor_assign$primary_loading, 3)

    sheets[["Factor_Assignments"]] <- factor_assign
  }

  # Write to Excel (TRS v1.0: Use atomic save if available)
  if (exists("turas_save_writexl_atomic", mode = "function")) {
    save_result <- turas_save_writexl_atomic(
      sheets = sheets,
      file_path = output_path,
      module = "SEGMENT"
    )
    if (!save_result$success) {
      warning(sprintf("[SEGMENT] Failed to save variable selection report: %s", save_result$error))
    }
  } else {
    writexl::write_xlsx(sheets, output_path)
  }

  cat(sprintf("✓ Exported variable selection report with %d sheets\n", length(sheets)))

  return(invisible(output_path))
}
