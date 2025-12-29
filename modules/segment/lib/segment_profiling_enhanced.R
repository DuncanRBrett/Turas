# ==============================================================================
# ENHANCED SEGMENT PROFILING
# ==============================================================================
# Statistical significance tests, effect sizes, and index scores
# Part of Turas Segmentation Module
# ==============================================================================

#' Calculate Statistical Significance of Segment Differences
#'
#' Performs ANOVA/Kruskal-Wallis tests to determine which variables
#' significantly differentiate segments
#'
#' IMPORTANT NOTE: P-values are DESCRIPTIVE, not inferential. Since segments
#' are defined using these variables (or correlates), statistical tests are
#' used for exploration and ranking, not hypothesis testing. Focus on effect
#' sizes (Cohen's d, eta-squared) and practical significance.
#'
#' @param data Data frame with all variables
#' @param clusters Integer vector of segment assignments
#' @param variables Character vector of variables to test
#' @param alpha Significance level (default: 0.05)
#' @return Data frame with significance test results
#' @export
test_segment_differences <- function(data, clusters, variables, alpha = 0.05) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("STATISTICAL SIGNIFICANCE TESTS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")
  cat("NOTE: P-values are DESCRIPTIVE (exploratory), not inferential.\n")
  cat("      Focus on effect sizes for practical interpretation.\n")
  cat("\n")

  results <- data.frame(
    Variable = character(),
    Test = character(),
    Statistic = numeric(),
    P_Value = numeric(),
    Significant = logical(),
    Effect_Size = numeric(),
    stringsAsFactors = FALSE
  )

  for (var in variables) {
    var_data <- data[[var]]
    
    # Remove missing values
    complete_idx <- !is.na(var_data) & !is.na(clusters)
    var_complete <- var_data[complete_idx]
    clusters_complete <- clusters[complete_idx]
    
    if (length(unique(var_complete)) < 10) {
      # Categorical or few unique values: Chi-square or Kruskal-Wallis
      test_result <- tryCatch({
        kruskal.test(var_complete ~ clusters_complete)
      }, error = function(e) NULL)
      
      if (!is.null(test_result)) {
        # Calculate eta-squared as effect size
        n <- length(var_complete)
        k <- length(unique(clusters_complete))
        eta_sq <- (test_result$statistic - k + 1) / (n - k)
        
        results <- rbind(results, data.frame(
          Variable = var,
          Test = "Kruskal-Wallis",
          Statistic = round(test_result$statistic, 3),
          P_Value = round(test_result$p.value, 4),
          Significant = test_result$p.value < alpha,
          Effect_Size = round(max(0, eta_sq), 3),
          stringsAsFactors = FALSE
        ))
      }
    } else {
      # Continuous: ANOVA
      test_result <- tryCatch({
        anova_model <- aov(var_complete ~ as.factor(clusters_complete))
        summary(anova_model)
      }, error = function(e) NULL)
      
      if (!is.null(test_result)) {
        f_stat <- test_result[[1]]$"F value"[1]
        p_value <- test_result[[1]]$"Pr(>F)"[1]
        
        # Calculate eta-squared (effect size for ANOVA)
        ss_between <- test_result[[1]]$"Sum Sq"[1]
        ss_total <- sum(test_result[[1]]$"Sum Sq")
        eta_sq <- ss_between / ss_total
        
        results <- rbind(results, data.frame(
          Variable = var,
          Test = "ANOVA",
          Statistic = round(f_stat, 3),
          P_Value = round(p_value, 4),
          Significant = p_value < alpha,
          Effect_Size = round(eta_sq, 3),
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # Sort by p-value
  results <- results[order(results$P_Value), ]
  
  cat(sprintf("Tested %d variables\n", nrow(results)))
  cat(sprintf("Significant at α=%.2f: %d (%.1f%%)\n", 
              alpha, 
              sum(results$Significant),
              100 * sum(results$Significant) / nrow(results)))
  
  cat("\nTop 10 most discriminating variables:\n")
  print(head(results[, c("Variable", "Test", "P_Value", "Effect_Size")], 10))
  
  cat("\n")
  
  return(results)
}


#' Calculate Index Scores
#'
#' Computes index scores showing how each segment compares to overall average
#' Index = 100 means segment matches overall average
#' Index > 100 means segment is above average
#' Index < 100 means segment is below average
#'
#' @param data Data frame with variables
#' @param clusters Integer vector of segment assignments
#' @param variables Character vector of variables to index
#' @return Data frame with index scores
#' @export
calculate_index_scores <- function(data, clusters, variables) {

  k <- length(unique(clusters))
  index_matrix <- matrix(NA, nrow = length(variables), ncol = k)
  rownames(index_matrix) <- variables
  colnames(index_matrix) <- paste0("Segment_", sort(unique(clusters)))

  for (var in variables) {
    var_data <- data[[var]]
    
    # Overall mean
    overall_mean <- mean(var_data, na.rm = TRUE)
    
    if (overall_mean == 0) {
      # Avoid division by zero
      next
    }
    
    # Segment means
    for (seg in sort(unique(clusters))) {
      seg_mean <- mean(var_data[clusters == seg], na.rm = TRUE)
      index <- 100 * (seg_mean / overall_mean)
      index_matrix[var, paste0("Segment_", seg)] <- round(index, 1)
    }
  }

  index_df <- as.data.frame(index_matrix)
  index_df$Variable <- rownames(index_matrix)
  index_df <- index_df[, c("Variable", setdiff(names(index_df), "Variable"))]
  rownames(index_df) <- NULL

  return(index_df)
}


#' Calculate Cohen's d Effect Sizes
#'
#' Computes Cohen's d effect sizes for pairwise segment comparisons
#' Small: 0.2, Medium: 0.5, Large: 0.8
#'
#' @param data Data frame with variables
#' @param clusters Integer vector of segment assignments
#' @param variables Character vector of variables to analyze
#' @return List with effect size matrices for each variable
#' @export
calculate_cohens_d <- function(data, clusters, variables) {

  k <- length(unique(clusters))
  effect_sizes <- list()

  for (var in variables) {
    var_data <- data[[var]]
    
    # Create pairwise comparison matrix
    d_matrix <- matrix(NA, nrow = k, ncol = k)
    rownames(d_matrix) <- paste0("Seg", sort(unique(clusters)))
    colnames(d_matrix) <- paste0("Seg", sort(unique(clusters)))
    
    segs <- sort(unique(clusters))
    
    for (i in 1:(k-1)) {
      for (j in (i+1):k) {
        seg_i <- segs[i]
        seg_j <- segs[j]
        
        data_i <- var_data[clusters == seg_i]
        data_j <- var_data[clusters == seg_j]
        
        # Remove NAs
        data_i <- data_i[!is.na(data_i)]
        data_j <- data_j[!is.na(data_j)]
        
        if (length(data_i) > 0 && length(data_j) > 0) {
          # Cohen's d = (mean1 - mean2) / pooled_sd
          mean_i <- mean(data_i)
          mean_j <- mean(data_j)
          sd_i <- sd(data_i)
          sd_j <- sd(data_j)
          n_i <- length(data_i)
          n_j <- length(data_j)
          
          pooled_sd <- sqrt(((n_i - 1) * sd_i^2 + (n_j - 1) * sd_j^2) / (n_i + n_j - 2))
          
          cohens_d <- (mean_i - mean_j) / pooled_sd
          
          d_matrix[i, j] <- round(cohens_d, 2)
          d_matrix[j, i] <- round(-cohens_d, 2)
        }
      }
    }
    
    diag(d_matrix) <- 0
    effect_sizes[[var]] <- d_matrix
  }

  return(effect_sizes)
}


#' Create Enhanced Profile Report
#'
#' Generates comprehensive profile with significance tests and effect sizes
#'
#' @param data Data frame with all data
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variables
#' @param profile_vars Character vector of profiling variables
#' @param output_path Path to save Excel report
#' @param question_labels Optional question labels
#' @export
create_enhanced_profile_report <- function(data, clusters, clustering_vars, 
                                          profile_vars = NULL, output_path,
                                          question_labels = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("CREATING ENHANCED PROFILE REPORT\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  all_vars <- unique(c(clustering_vars, profile_vars))
  
  sheets <- list()

  # Sheet 1: Significance tests
  cat("Running significance tests...\n")
  sig_tests <- test_segment_differences(data, clusters, all_vars)
  sheets[["Significance_Tests"]] <- sig_tests

  # Sheet 2: Index scores
  cat("Calculating index scores...\n")
  index_scores <- calculate_index_scores(data, clusters, all_vars)
  
  # Add labels if available
  if (!is.null(question_labels)) {
    source("modules/segment/lib/segment_config.R")
    index_scores$Variable <- format_variable_label(index_scores$Variable, question_labels)
  }
  
  sheets[["Index_Scores"]] <- index_scores

  # Sheet 3: Effect sizes summary
  cat("Calculating effect sizes...\n")
  effect_sizes <- calculate_cohens_d(data, clusters, clustering_vars)
  
  # Create summary sheet with largest effect sizes
  effect_summary <- data.frame(
    Variable = character(),
    Comparison = character(),
    Cohens_d = numeric(),
    Effect_Size_Magnitude = character(),
    stringsAsFactors = FALSE
  )
  
  for (var in names(effect_sizes)) {
    d_matrix <- effect_sizes[[var]]
    
    # Find largest effect sizes
    for (i in 1:nrow(d_matrix)) {
      for (j in (i+1):ncol(d_matrix)) {
        d_value <- abs(d_matrix[i, j])
        
        if (!is.na(d_value) && d_value > 0.2) {  # Only report small+ effects
          magnitude <- if (d_value >= 0.8) "Large" else if (d_value >= 0.5) "Medium" else "Small"
          
          effect_summary <- rbind(effect_summary, data.frame(
            Variable = var,
            Comparison = paste(rownames(d_matrix)[i], "vs", colnames(d_matrix)[j]),
            Cohens_d = round(d_matrix[i, j], 2),
            Effect_Size_Magnitude = magnitude,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }
  
  # Sort by absolute effect size
  effect_summary <- effect_summary[order(-abs(effect_summary$Cohens_d)), ]
  
  # Add labels if available
  if (!is.null(question_labels)) {
    effect_summary$Variable <- format_variable_label(effect_summary$Variable, question_labels)
  }
  
  sheets[["Effect_Sizes"]] <- effect_summary

  # Write to Excel (TRS v1.0: Use atomic save if available)
  cat("Exporting enhanced profile report...\n")
  if (exists("turas_save_writexl_atomic", mode = "function")) {
    save_result <- turas_save_writexl_atomic(
      sheets = sheets,
      file_path = output_path,
      module = "SEGMENT"
    )
    if (!save_result$success) {
      warning(sprintf("[SEGMENT] Failed to save enhanced profile report: %s", save_result$error))
    }
  } else {
    writexl::write_xlsx(sheets, output_path)
  }

  cat(sprintf("✓ Enhanced profile report saved to: %s\n", basename(output_path)))
  cat(sprintf("  Sheets: %d\n\n", length(sheets)))

  return(invisible(list(
    significance_tests = sig_tests,
    index_scores = index_scores,
    effect_sizes = effect_sizes
  )))
}


# ==============================================================================
# FEATURE 3: GOLDEN QUESTIONS IDENTIFIER
# ==============================================================================

#' Identify Golden Questions (Key Discriminating Variables)
#'
#' Finds the minimum set of variables needed to predict segment membership.
#' Uses Random Forest variable importance if available, falls back to eta-squared
#' from ANOVA.
#'
#' @param data Data frame with all variables
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variable names
#' @param n_questions Integer, number of golden questions to identify (default: 3)
#' @param question_labels Named vector of question labels (optional)
#'
#' @return List with golden_questions, importance_scores, importance_df
#' @export
#' @examples
#' golden <- identify_golden_questions(
#'   data = survey_data,
#'   clusters = result$clusters,
#'   clustering_vars = config$clustering_vars,
#'   n_questions = 3
#' )
identify_golden_questions <- function(data, clusters, clustering_vars,
                                       n_questions = 3, question_labels = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("IDENTIFYING GOLDEN QUESTIONS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Prepare data
  analysis_data <- data[, clustering_vars, drop = FALSE]
  analysis_data$segment <- as.factor(clusters)

  # Remove rows with missing values
  complete_rows <- complete.cases(analysis_data)
  analysis_data <- analysis_data[complete_rows, ]

  cat(sprintf("Analyzing %d variables across %d segments...\n",
              length(clustering_vars), length(unique(clusters))))

  # ===========================================================================
  # TRY RANDOM FOREST METHOD
  # ===========================================================================

  importance_scores <- NULL
  method_used <- NULL
  classification_accuracy <- NULL

  if (requireNamespace("randomForest", quietly = TRUE)) {
    cat("Using Random Forest for variable importance...\n")
    method_used <- "Random Forest"

    tryCatch({
      # Fit random forest
      rf_formula <- as.formula(paste("segment ~", paste(clustering_vars, collapse = " + ")))

      rf_model <- randomForest::randomForest(
        rf_formula,
        data = analysis_data,
        importance = TRUE,
        ntree = 500
      )

      # Get importance (MeanDecreaseGini or MeanDecreaseAccuracy)
      importance_matrix <- randomForest::importance(rf_model)

      # Use MeanDecreaseAccuracy if available, otherwise MeanDecreaseGini
      if ("MeanDecreaseAccuracy" %in% colnames(importance_matrix)) {
        importance_scores <- importance_matrix[, "MeanDecreaseAccuracy"]
      } else {
        importance_scores <- importance_matrix[, "MeanDecreaseGini"]
      }

      # Calculate classification accuracy
      predictions <- predict(rf_model, analysis_data)
      classification_accuracy <- mean(predictions == analysis_data$segment)

      cat(sprintf("✓ Random Forest fitted successfully\n"))
      cat(sprintf("  Classification accuracy: %.1f%%\n", classification_accuracy * 100))

    }, error = function(e) {
      cat(sprintf("⚠ Random Forest failed: %s\n", e$message))
      cat("  Falling back to eta-squared method...\n")
      message(sprintf("[TRS PARTIAL] SEG_RF_FAILED: Random Forest failed (%s) - using eta-squared method", e$message))
      importance_scores <<- NULL
    })
  } else {
    cat("randomForest not installed. Using eta-squared method...\n")
    cat("  Install with: install.packages('randomForest')\n")
    message("[TRS PARTIAL] SEG_RF_MISSING: randomForest package not available - using eta-squared method")
  }

  # ===========================================================================
  # FALLBACK: ETA-SQUARED FROM ANOVA
  # ===========================================================================

  if (is.null(importance_scores)) {
    method_used <- "ANOVA (eta-squared)"

    importance_scores <- numeric(length(clustering_vars))
    names(importance_scores) <- clustering_vars

    for (var in clustering_vars) {
      var_data <- analysis_data[[var]]

      tryCatch({
        anova_result <- aov(var_data ~ analysis_data$segment)
        anova_summary <- summary(anova_result)

        # Calculate eta-squared
        ss_between <- anova_summary[[1]]$"Sum Sq"[1]
        ss_total <- sum(anova_summary[[1]]$"Sum Sq")
        eta_squared <- ss_between / ss_total

        importance_scores[var] <- eta_squared

      }, error = function(e) {
        importance_scores[var] <- 0
      })
    }

    cat(sprintf("✓ Eta-squared calculated for %d variables\n", length(clustering_vars)))
  }

  # ===========================================================================
  # RANK AND SELECT TOP N
  # ===========================================================================

  # Sort by importance (descending)
  sorted_idx <- order(importance_scores, decreasing = TRUE)
  ranked_vars <- names(importance_scores)[sorted_idx]
  ranked_scores <- importance_scores[sorted_idx]

  # Select top n
  n_questions <- min(n_questions, length(clustering_vars))
  golden_questions <- ranked_vars[1:n_questions]
  golden_scores <- ranked_scores[1:n_questions]

  # ===========================================================================
  # CREATE IMPORTANCE DATA FRAME
  # ===========================================================================

  importance_df <- data.frame(
    Variable = ranked_vars,
    Importance = round(ranked_scores, 4),
    Rank = 1:length(ranked_vars),
    Golden_Question = ranked_vars %in% golden_questions,
    stringsAsFactors = FALSE
  )

  # Add labels if available
  if (!is.null(question_labels)) {
    importance_df$Label <- sapply(importance_df$Variable, function(v) {
      if (v %in% names(question_labels)) question_labels[v] else v
    }, USE.NAMES = FALSE)
    # Reorder columns
    importance_df <- importance_df[, c("Rank", "Variable", "Label", "Importance", "Golden_Question")]
  }

  # ===========================================================================
  # CONSOLE OUTPUT
  # ===========================================================================

  cat("\n")
  cat(sprintf("Top %d discriminating variables:\n", n_questions))
  for (i in 1:n_questions) {
    var_name <- golden_questions[i]
    score <- golden_scores[i]

    # Get label if available
    display_name <- if (!is.null(question_labels) && var_name %in% names(question_labels)) {
      paste0(var_name, ": ", question_labels[var_name])
    } else {
      var_name
    }

    cat(sprintf("  %d. %s (importance: %.2f)\n", i, display_name, score))
  }

  if (!is.null(classification_accuracy)) {
    cat(sprintf("\nThese %d questions predict segment membership with %.0f%% accuracy.\n",
                n_questions, classification_accuracy * 100))
  }

  cat(sprintf("\nMethod used: %s\n", method_used))
  cat("\n")

  return(list(
    golden_questions = golden_questions,
    importance_scores = importance_scores,
    importance_df = importance_df,
    n_questions = n_questions,
    method = method_used,
    classification_accuracy = classification_accuracy
  ))
}


# ==============================================================================
# FEATURE 10: VARIABLE IMPORTANCE RANKING
# ==============================================================================

#' Rank Variable Importance for Clustering
#'
#' Determines which clustering variables actually matter most for segment
#' differentiation. Uses eta-squared from ANOVA and categorizes variables
#' as "Essential", "Useful", or "Minimal Impact".
#'
#' @param data Data frame with all variables
#' @param clusters Integer vector of segment assignments
#' @param clustering_vars Character vector of clustering variable names
#' @param question_labels Named vector of question labels (optional)
#'
#' @return List with ranking data frame, essential_vars, drop_candidates
#' @export
rank_variable_importance <- function(data, clusters, clustering_vars,
                                      question_labels = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("VARIABLE IMPORTANCE FOR CLUSTERING\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Calculate eta-squared for each variable
  eta_squared_values <- numeric(length(clustering_vars))
  names(eta_squared_values) <- clustering_vars

  for (var in clustering_vars) {
    var_data <- data[[var]]

    tryCatch({
      complete_idx <- !is.na(var_data) & !is.na(clusters)
      var_complete <- var_data[complete_idx]
      clusters_complete <- clusters[complete_idx]

      anova_result <- aov(var_complete ~ as.factor(clusters_complete))
      anova_summary <- summary(anova_result)

      ss_between <- anova_summary[[1]]$"Sum Sq"[1]
      ss_total <- sum(anova_summary[[1]]$"Sum Sq")
      eta_squared_values[var] <- ss_between / ss_total

    }, error = function(e) {
      eta_squared_values[var] <- 0
    })
  }

  # ===========================================================================
  # CATEGORIZE VARIABLES
  # ===========================================================================

  # Thresholds based on Cohen's guidelines for eta-squared:
  # Small: 0.01, Medium: 0.06, Large: 0.14
  # Our thresholds are more stringent for clustering context
  essential_threshold <- 0.30  # Large effect
  useful_threshold <- 0.10     # Medium-large effect
  minimal_threshold <- 0.10    # Below this is minimal

  # Sort by eta-squared
  sorted_idx <- order(eta_squared_values, decreasing = TRUE)
  sorted_vars <- clustering_vars[sorted_idx]
  sorted_eta <- eta_squared_values[sorted_idx]

  # Categorize
  category <- character(length(sorted_vars))
  for (i in seq_along(sorted_vars)) {
    eta <- sorted_eta[i]
    if (eta >= essential_threshold) {
      category[i] <- "ESSENTIAL"
    } else if (eta >= useful_threshold) {
      category[i] <- "USEFUL"
    } else {
      category[i] <- "MINIMAL IMPACT"
    }
  }

  # ===========================================================================
  # CREATE RANKING DATA FRAME
  # ===========================================================================

  ranking_df <- data.frame(
    Variable = sorted_vars,
    Eta_Squared = round(sorted_eta, 4),
    Rank = 1:length(sorted_vars),
    Category = category,
    stringsAsFactors = FALSE
  )

  # Add labels if available
  if (!is.null(question_labels)) {
    ranking_df$Label <- sapply(ranking_df$Variable, function(v) {
      if (v %in% names(question_labels)) question_labels[v] else ""
    }, USE.NAMES = FALSE)
    ranking_df <- ranking_df[, c("Rank", "Variable", "Label", "Eta_Squared", "Category")]
  }

  # Identify essential and drop candidates
  essential_vars <- sorted_vars[category == "ESSENTIAL"]
  useful_vars <- sorted_vars[category == "USEFUL"]
  drop_candidates <- sorted_vars[category == "MINIMAL IMPACT"]

  # ===========================================================================
  # CONSOLE OUTPUT
  # ===========================================================================

  cat("Variable importance for clustering:\n\n")

  # Essential
  if (length(essential_vars) > 0) {
    cat(sprintf("ESSENTIAL (η² > %.2f):\n", essential_threshold))
    for (var in essential_vars) {
      display_name <- if (!is.null(question_labels) && var %in% names(question_labels)) {
        paste0(var, ": ", substr(question_labels[var], 1, 40))
      } else {
        var
      }
      cat(sprintf("  %s: %.2f\n", display_name, eta_squared_values[var]))
    }
    cat("\n")
  }

  # Useful
  if (length(useful_vars) > 0) {
    cat(sprintf("USEFUL (η² %.2f-%.2f):\n", minimal_threshold, essential_threshold))
    for (var in useful_vars) {
      display_name <- if (!is.null(question_labels) && var %in% names(question_labels)) {
        paste0(var, ": ", substr(question_labels[var], 1, 40))
      } else {
        var
      }
      cat(sprintf("  %s: %.2f\n", display_name, eta_squared_values[var]))
    }
    cat("\n")
  }

  # Minimal impact
  if (length(drop_candidates) > 0) {
    cat(sprintf("MINIMAL IMPACT (η² < %.2f):\n", minimal_threshold))
    for (var in drop_candidates) {
      display_name <- if (!is.null(question_labels) && var %in% names(question_labels)) {
        paste0(var, ": ", substr(question_labels[var], 1, 40))
      } else {
        var
      }
      cat(sprintf("  %s: %.2f  ← Consider removing\n", display_name, eta_squared_values[var]))
    }
    cat("\n")
  }

  # Recommendation
  if (length(drop_candidates) > 0) {
    cat(sprintf("Suggestion: Variables %s contribute little.\n",
                paste(drop_candidates, collapse = ", ")))
    cat("Re-run without them for cleaner segments.\n")
  } else {
    cat("All variables contribute meaningfully to segment differentiation.\n")
  }

  cat("\n")

  return(list(
    ranking = ranking_df,
    essential_vars = essential_vars,
    useful_vars = useful_vars,
    drop_candidates = drop_candidates,
    eta_squared_values = eta_squared_values
  ))
}
