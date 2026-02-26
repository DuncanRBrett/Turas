# ==============================================================================
# MODULE 6: QUESTION_DISPATCHER.R
# ==============================================================================
# 
# PURPOSE:
#   Orchestrates question processing by routing to appropriate processors
#   based on question type (Variable_Type)
#
# ROUTES TO:
#   - Standard questions (Single/Multi choice) -> process_standard_question()
#   - Ranking questions -> process_ranking_question() [Phase 6]
#   - Numeric questions -> process_numeric_question()
#
# DEPENDENCIES:
#   - utilities.R (safe_execute, logging, validation)
#   - cell_calculator.R (process_standard_question, boxcategory, summaries)
#   - statistics.R (significance testing)
#   - Phase 6 ranking module (for ranking questions)
#
# ARCHITECTURE:
#   This is the main dispatcher that:
#   1. Receives question metadata, data, and configuration
#   2. Routes to appropriate processor based on Variable_Type
#   3. Adds supplementary analyses (boxcategory, significance, summaries)
#   4. Combines all results into final table
#
# VERSION: 1.0.0
# DATE: 2025-10-25
# ==============================================================================

# Row type constants (matching V9.9.3)
FREQUENCY_ROW_TYPE <- "Frequency"
COLUMN_PCT_ROW_TYPE <- "Column %"
ROW_PCT_ROW_TYPE <- "Row %"
AVERAGE_ROW_TYPE <- "Average"
SIGNIFICANCE_ROW_TYPE <- "Significance"
TOTAL_COLUMN <- "Total"

# ==============================================================================
# MAIN DISPATCHER FUNCTION
# ==============================================================================

#' Process Question - Main Dispatcher
#'
#' Routes question to appropriate processor based on Variable_Type.
#' Handles all question types and adds supplementary analyses.
#'
#' @param data Data frame, full survey data (may be filtered by BaseFilter)
#' @param question_info Data frame row, question metadata from survey structure
#' @param question_options Data frame, options/items for this question
#' @param banner_info List, banner structure from create_banner_structure()
#' @param banner_row_indices List, row indices by banner column
#' @param master_weights Numeric vector, weights for ALL data rows
#' @param banner_bases List, base sizes by banner column
#' @param config List, configuration object
#' @param is_weighted Logical, whether weighting is applied
#' @param selection_row Data frame row, from Selection sheet (for summary stats)
#' @return Data frame with all question results, or NULL if processing fails
#' @export
dispatch_question <- function(data, question_info, question_options,
                              banner_info, banner_row_indices, master_weights,
                              banner_bases, config, is_weighted = FALSE,
                              selection_row = NULL) {
  
  question_code <- question_info$QuestionCode
  var_type <- question_info$Variable_Type
  
  log_message(
    sprintf("Processing %s (%s)", question_code, var_type),
    level = "DEBUG",
    verbose = config$verbose
  )
  
  # Initialize results list
  all_results <- list()
  
  # ===========================================================================
  # STEP 1: ROUTE TO APPROPRIATE PROCESSOR
  # ===========================================================================
  
  if (var_type == "Ranking") {
    # -------------------------------------------------------------------------
    # RANKING QUESTIONS - Use Phase 6 Ranking Module
    # -------------------------------------------------------------------------
    primary_results <- safe_execute(
      process_ranking_question(
        data, question_info, question_options,
        banner_info, banner_row_indices, master_weights,
        banner_bases, config, is_weighted
      ),
      default = NULL,
      error_msg = sprintf("Ranking processing failed: %s", question_code),
      silent = !config$verbose
    )
    
  } else if (var_type == "Numeric") {
    # -------------------------------------------------------------------------
    # NUMERIC QUESTIONS - Bins + Statistics
    # -------------------------------------------------------------------------
    primary_results <- safe_execute(
      process_numeric_question(
        data, question_info, question_options,
        banner_info, banner_row_indices, master_weights,
        banner_bases, config, is_weighted
      ),
      default = NULL,
      error_msg = sprintf("Numeric processing failed: %s", question_code),
      silent = !config$verbose
    )
    
  } else {
    # -------------------------------------------------------------------------
    # STANDARD QUESTIONS - Single/Multi Choice, Rating, Likert, NPS, etc.
    # -------------------------------------------------------------------------
    primary_results <- safe_execute(
      process_standard_question(
        data, question_info, question_options,
        banner_info, banner_row_indices, master_weights,
        banner_bases, config, is_weighted
      ),
      default = NULL,
      error_msg = sprintf("Standard processing failed: %s", question_code),
      silent = !config$verbose
    )
    
    # =========================================================================
    # STEP 2: ADD BOXCATEGORY SUMMARIES (for standard questions only)
    # =========================================================================
    
    if (!is.null(primary_results)) {
      all_results[[length(all_results) + 1]] <- primary_results
    }
    
    boxcategory_results <- safe_execute(
      add_boxcategory_summaries(
        data, question_info, question_options,
        banner_info, banner_row_indices, master_weights,
        banner_bases, config, is_weighted
      ),
      default = NULL,
      error_msg = sprintf("BoxCategory processing failed: %s", question_code),
      silent = TRUE  # BoxCategory is optional
    )
    
    # =========================================================================
    # STEP 3: ADD NET SIGNIFICANCE TESTING (for boxcategories)
    # =========================================================================
    
    if (!is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      
      # Add net difference significance rows
      boxcategory_results <- safe_execute(
        add_net_significance_rows(
          boxcategory_results, data, question_info, question_options,
          banner_info, banner_row_indices, master_weights, banner_bases,
          config, is_weighted
        ),
        default = boxcategory_results,  # Return original on error
        error_msg = sprintf("Net significance failed: %s", question_code),
        silent = TRUE
      )
      
      # Add chi-square test (if enabled)
      chi_square_row <- safe_execute(
        add_chi_square_test(
          boxcategory_results, banner_info, config
        ),
        default = NULL,
        error_msg = sprintf("Chi-square test failed: %s", question_code),
        silent = TRUE
      )
      
      if (!is.null(chi_square_row)) {
        boxcategory_results <- batch_rbind(list(
          boxcategory_results,
          chi_square_row
        ))
      }
      
      # Add net positive row (Top - Bottom with significance)
      boxcategory_results <- safe_execute(
        add_net_positive_row(
          boxcategory_results, data, question_info, question_options,
          banner_info, banner_row_indices, master_weights, banner_bases,
          config, is_weighted
        ),
        default = boxcategory_results,  # Return original on error
        error_msg = sprintf("Net positive calculation failed: %s", question_code),
        silent = TRUE
      )
      
      all_results[[length(all_results) + 1]] <- boxcategory_results
    }
    
    # =========================================================================
    # STEP 4: ADD SUMMARY STATISTICS (Mean/Index for Rating/Likert/NPS)
    # =========================================================================
    
    summary_results <- safe_execute(
      add_summary_statistic(
        data, question_info, question_options,
        banner_info, banner_row_indices, master_weights,
        banner_bases, selection_row, config, is_weighted
      ),
      default = NULL,
      error_msg = sprintf("Summary statistic failed: %s", question_code),
      silent = TRUE  # Summary statistics are optional
    )
    
    if (!is.null(summary_results)) {
      all_results[[length(all_results) + 1]] <- summary_results
    }
  }
  
  # ===========================================================================
  # STEP 5: COMBINE ALL RESULTS
  # ===========================================================================
  
  # For ranking and numeric, only primary results
  if (var_type %in% c("Ranking", "Numeric")) {
    if (!is.null(primary_results) && nrow(primary_results) > 0) {
      return(primary_results)
    } else {
      return(NULL)
    }
  }
  
  # For standard questions, combine all parts
  if (length(all_results) > 0) {
    final_table <- batch_rbind(all_results)
    
    if (!is.null(final_table) && nrow(final_table) > 0) {
      log_message(
        sprintf("  -> %d rows generated", nrow(final_table)),
        level = "DEBUG",
        verbose = config$verbose
      )
      return(final_table)
    }
  }
  
  # No results generated
  log_message(
    sprintf("  -> No results for %s", question_code),
    level = "WARNING",
    verbose = config$verbose
  )
  
  return(NULL)
}

# ==============================================================================
# HELPER FUNCTIONS FOR SUPPLEMENTARY ANALYSES
# ==============================================================================

#' Add Chi-Square Test Row
#'
#' Performs chi-square test on BoxCategory frequency rows and adds result.
#' Uses relaxed thresholds for small banner groups.
#'
#' @param boxcategory_results Data frame, BoxCategory results
#' @param banner_info List, banner structure
#' @param config List, configuration object
#' @return Data frame with one row, or NULL if test not applicable
#' @export
add_chi_square_test <- function(boxcategory_results, banner_info, config) {
  
  # Check if chi-square is enabled
  enable_chi <- FALSE
  if ("enable_chi_square" %in% names(config)) {
    enable_chi <- safe_logical(config$enable_chi_square, default = FALSE)
  }
  
  if (!enable_chi) {
    return(NULL)
  }
  
  # Get BoxCategory FREQUENCY rows
  box_freq_rows <- boxcategory_results[
    boxcategory_results$RowType == "Frequency",
  ]
  
  if (nrow(box_freq_rows) < 2) {
    return(NULL)  # Need at least 2 categories
  }
  
  # Extract numeric matrix
  obs_matrix <- as.matrix(
    box_freq_rows[, banner_info$internal_keys, drop = FALSE]
  )
  storage.mode(obs_matrix) <- "double"
  
  # Remove Total column
  total_key <- paste0("TOTAL::", TOTAL_COLUMN)
  if (total_key %in% colnames(obs_matrix)) {
    obs_matrix <- obs_matrix[, colnames(obs_matrix) != total_key, drop = FALSE]
  }
  
  if (ncol(obs_matrix) < 2 || nrow(obs_matrix) < 2) {
    return(NULL)  # Need at least 2x2 table
  }
  
  # SMART FILTERING - Remove sparse BoxCategories
  row_totals <- rowSums(obs_matrix)
  row_labels <- box_freq_rows$RowLabel
  
  # Keep rows with at least 5 total responses OR 1% of sample
  min_count <- max(5, 0.01 * sum(obs_matrix))
  keep_rows <- row_totals >= min_count
  
  if (sum(keep_rows) < 2) {
    return(NULL)  # Not enough valid rows after filtering
  }
  
  obs_matrix_filtered <- obs_matrix[keep_rows, , drop = FALSE]
  filtered_labels <- row_labels[keep_rows]
  
  # Check expected frequencies
  row_totals_f <- rowSums(obs_matrix_filtered)
  col_totals_f <- colSums(obs_matrix_filtered)
  grand_total_f <- sum(obs_matrix_filtered)
  
  if (grand_total_f == 0) {
    return(NULL)
  }
  
  expected_matrix <- outer(row_totals_f, col_totals_f) / grand_total_f
  min_expected <- min(expected_matrix)
  low_expected_pct <- 100 * sum(expected_matrix < 5) / length(expected_matrix)
  
  # V9.9.5: RELAXED THRESHOLDS for small banner groups
  # - Min expected: 0.5 (was 1.0) - allows smaller cells
  # - Low expected %: 40% (was 20%) - more permissive for small groups
  if (min_expected < 0.5 || low_expected_pct > 40) {
    return(NULL)  # Chi-square assumptions not met
  }
  
  # Perform chi-square test
  chi_result <- chi_square_test(
    obs_matrix_filtered,
    alpha = config$alpha
  )
  
  # Build message
  chi_message <- sprintf(
    "Chi-square (%d categories): χ²=%.2f, df=%d, p=%.4f%s",
    nrow(obs_matrix_filtered),
    chi_result$chi_square_stat,
    chi_result$df,
    chi_result$p_value,
    if (chi_result$significant) " **" else ""
  )
  
  # Note if categories were excluded
  if (sum(keep_rows) < length(keep_rows)) {
    excluded_cats <- row_labels[!keep_rows]
    chi_message <- paste0(
      chi_message,
      sprintf(" [Excluded: %s]", paste(excluded_cats, collapse = ", "))
    )
  }
  
  # Add warning note if thresholds are marginal
  if (min_expected < 1 || low_expected_pct > 20) {
    chi_message <- paste0(chi_message, " [Note: Small sample in some cells]")
  }
  
  # Create display row
  chi_row <- data.frame(
    RowLabel = chi_message,
    RowType = "ChiSquare",
    stringsAsFactors = FALSE
  )

  for (key in banner_info$internal_keys) {
    chi_row[[key]] <- NA_real_
  }

  # Tag as chi_square for downstream classification
  chi_row$RowSource <- "chi_square"

  return(chi_row)
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Question Dispatcher Module Information
#'
#' Returns metadata about the question_dispatcher module.
#'
#' @return List with module information
#' @export
get_question_dispatcher_info <- function() {
  list(
    module = "question_dispatcher",
    version = "1.0.0",
    date = "2025-10-25",
    description = "Question routing and orchestration system",
    functions = c(
      "dispatch_question",
      "add_chi_square_test",
      "get_question_dispatcher_info"
    ),
    dependencies = c(
      "utilities.R",
      "cell_calculator.R",
      "statistics.R",
      "Phase 6 ranking module"
    )
  )
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs question_dispatcher module loaded")

# ==============================================================================
# END OF MODULE 6: QUESTION_DISPATCHER.R
# ==============================================================================
