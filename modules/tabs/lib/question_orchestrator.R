# ==============================================================================
# QUESTION ORCHESTRATOR MODULE
# ==============================================================================
# Question processing coordination and preparation functions
# Part of R Survey Analytics Toolkit
#
# VERSION HISTORY:
# V1.0.0 - Initial creation (2025-11-04)
#          - Extracted from run_crosstabs.R orchestration loop
#          - prepare_question_data() - question metadata and filtering
#
# PURPOSE:
# This module coordinates question processing workflow:
# - Load question metadata
# - Apply base filters
# - Prepare banner indices
# - Calculate base sizes
# - Future: Full orchestration coordination
#
# DESIGN PHILOSOPHY:
# - Separation of concerns (preparation vs processing)
# - Clear input/output contracts
# - Testable components
# - Reusable functions
# ==============================================================================

# ==============================================================================
# QUESTION DATA PREPARATION
# ==============================================================================

#' Prepare Question Data for Processing
#'
#' Loads question metadata, applies base filters, creates banner indices,
#' and calculates base sizes. This function encapsulates all preparation
#' steps needed before question processing.
#'
#' Extracted from orchestration loop for modularity and testability.
#'
#' @param question_code Character, question identifier
#' @param base_filter Character or NA, base filter expression
#' @param survey_data Data frame, raw survey response data
#' @param survey_structure List with questions and options data frames
#' @param banner_info List, banner structure metadata
#' @param master_weights Numeric vector, weight values for all respondents
#'
#' @return List with prepared data, or NULL if preparation failed:
#'   - question_info: Data frame row with question metadata
#'   - question_options: Data frame with question options
#'   - filtered_data: Data frame with filtered survey data
#'   - question_weights: Numeric vector of weights for filtered data
#'   - banner_row_indices: List of row indices by banner column
#'   - banner_bases: List of base sizes by banner column
#'   - base_filter: Character, the applied filter (or NA)
#'
#' @export
#' @examples
#' prepared <- prepare_question_data(
#'   "Q01", NA, survey_data, survey_structure, banner_info, master_weights
#' )
#' if (!is.null(prepared)) {
#'   # Process question with prepared data
#' }
prepare_question_data <- function(question_code, base_filter,
                                  survey_data, survey_structure,
                                  banner_info, master_weights) {

  # ============================================================================
  # STEP 1: LOAD QUESTION METADATA
  # ============================================================================

  question_info <- survey_structure$questions[
    survey_structure$questions$QuestionCode == question_code,
  ]

  if (nrow(question_info) == 0) {
    # TRS v1.0: Missing question must refuse with explanation, not silently skip
    tabs_refuse(
      code = "CFG_QUESTION_NOT_FOUND",
      title = paste0("Question Not Found: ", question_code),
      problem = paste0("Question '", question_code, "' is referenced in config but not found in Survey_Structure."),
      why_it_matters = "This question will be missing from output, producing incomplete results.",
      how_to_fix = c(
        "Check that the QuestionCode in Selection sheet matches Questions sheet exactly",
        "Verify the question exists in Survey_Structure.xlsx Questions sheet",
        "Check for typos or case differences in the question code"
      )
    )
  }

  question_info <- question_info[1, ]

  # Load question options
  # FIXED: Multi-mention uses column names as QuestionCode in Options
  if (question_info$Variable_Type == "Multi_Mention") {
    pattern <- paste0("^", question_code, "_")
    question_options <- survey_structure$options[
      grepl(pattern, survey_structure$options$QuestionCode),
    ]
  } else {
    question_options <- survey_structure$options[
      survey_structure$options$QuestionCode == question_code,
    ]
  }

  # ============================================================================
  # STEP 2: APPLY BASE FILTER
  # ============================================================================

  if (!is.na(base_filter) && base_filter != "") {
    filtered_data <- safe_execute(
      apply_base_filter(survey_data, base_filter),
      default = NULL,
      error_msg = paste("Filter failed:", question_code)
    )

    if (is.null(filtered_data)) {
      # TRS v1.0: Filter failures must refuse with explanation, not silently skip
      tabs_refuse(
        code = "DATA_FILTER_FAILED",
        title = paste0("Base Filter Failed: ", question_code),
        problem = paste0("Could not apply base filter '", base_filter, "' for question ", question_code),
        why_it_matters = "This question cannot be processed without a valid filter. It will be missing from output.",
        how_to_fix = c(
          "Check that the filter expression in Survey_Structure is valid R syntax",
          "Verify the filter column exists in your data",
          "Check for typos in variable names"
        )
      )
    }

    # Extract weights for filtered rows
    if (".original_row" %in% names(filtered_data)) {
      question_weights <- master_weights[filtered_data$.original_row]
    } else {
      question_weights <- master_weights
    }
  } else {
    # No filter - use full dataset
    filtered_data <- survey_data
    question_weights <- master_weights
  }

  # ============================================================================
  # STEP 3: CREATE BANNER ROW INDICES
  # ============================================================================

  banner_result <- create_banner_row_indices(filtered_data, banner_info)
  banner_row_indices <- banner_result$row_indices

  # ============================================================================
  # STEP 4: CALCULATE BASE SIZES
  # ============================================================================

  banner_bases <- list()
  for (key in banner_info$internal_keys) {
    row_idx <- banner_row_indices[[key]]
    if (length(row_idx) > 0) {
      subset_data <- filtered_data[row_idx, , drop = FALSE]
      subset_weights <- question_weights[row_idx]
      base_result <- calculate_weighted_base(
        subset_data, question_info, subset_weights
      )
    } else {
      base_result <- list(unweighted = 0, weighted = 0, effective = 0)
    }
    banner_bases[[key]] <- base_result
  }

  # ============================================================================
  # RETURN PREPARED DATA
  # ============================================================================

  return(list(
    question_info = question_info,
    question_options = question_options,
    filtered_data = filtered_data,
    question_weights = question_weights,
    banner_row_indices = banner_row_indices,
    banner_bases = banner_bases,
    base_filter = base_filter
  ))
}

# ==============================================================================
# SINGLE QUESTION PROCESSING
# ==============================================================================

#' Process Single Question
#'
#' Routes question processing based on type, combines results, and returns
#' structured result object. Handles Ranking, Numeric, and Standard questions.
#'
#' Extracted from orchestration loop for modularity.
#'
#' @param question_code Character, question identifier
#' @param prepared_data List from prepare_question_data()
#' @param banner_info List, banner structure metadata
#' @param config Configuration object
#' @param is_weighted Logical, whether analysis is weighted
#' @param total_column Character, name of total column
#'
#' @return List with question results:
#'   - question_code: Character
#'   - question_text: Character
#'   - question_type: Character
#'   - base_filter: Character or NA
#'   - bases: List of base sizes
#'   - table: Data frame with results
#'
#' Returns NULL if processing fails.
#'
#' @export
process_single_question <- function(question_code, prepared_data,
                                   banner_info, config, is_weighted,
                                   question_row,
                                   total_column = "Total") {

  # Unpack prepared data
  question_info <- prepared_data$question_info
  question_options <- prepared_data$question_options
  filtered_data <- prepared_data$filtered_data
  question_weights <- prepared_data$question_weights
  banner_row_indices <- prepared_data$banner_row_indices
  banner_bases <- prepared_data$banner_bases
  base_filter <- prepared_data$base_filter

  # ===========================================================================
  # ROUTE BY QUESTION TYPE
  # ===========================================================================

  if (question_info$Variable_Type == "Ranking") {
    # ---------------------------------------------------------------------
    # RANKING QUESTIONS
    # ---------------------------------------------------------------------
    ranking_data <- safe_execute(
      extract_ranking_data(filtered_data, question_info, question_options),
      default = NULL,
      error_msg = paste("Ranking failed:", question_code)
    )

    if (is.null(ranking_data)) {
      # TRS v1.0: Ranking failures must refuse with explanation
      tabs_refuse(
        code = "DATA_RANKING_EXTRACTION_FAILED",
        title = paste0("Ranking Data Extraction Failed: ", question_code),
        problem = paste0("Could not extract ranking data for question ", question_code),
        why_it_matters = "This ranking question cannot be processed. It will be missing from output.",
        how_to_fix = c(
          "Check that ranking columns follow the expected naming pattern",
          "Verify Ranking_Format in Survey_Structure is correct",
          "Ensure ranking data contains valid numeric values"
        )
      )
    }

    # Build banner_data_list and weights_list
    banner_data_list <- list()
    weights_list <- list()

    for (key in banner_info$internal_keys) {
      row_idx <- banner_row_indices[[key]]

      if (length(row_idx) > 0) {
        subset_df <- filtered_data[row_idx, , drop = FALSE]
        subset_df$.original_row <- row_idx
        banner_data_list[[key]] <- subset_df
        weights_list[[key]] <- question_weights[row_idx]
      } else {
        banner_data_list[[key]] <- filtered_data[integer(0), , drop = FALSE]
        weights_list[[key]] <- numeric(0)
      }
    }

    # Create rows for each item
    question_results <- list()
    for (item in ranking_data$items) {
      item_rows <- create_ranking_rows_for_item(
        ranking_data$matrix, item, banner_data_list, banner_info,
        banner_info$internal_keys, weights_list,
        show_top_n = TRUE, top_n = 3,
        num_positions = ranking_data$num_positions,
        decimal_places_percent = config$decimal_places_percent,
        decimal_places_index = config$decimal_places_index
      )
      question_results <- c(question_results, item_rows)
    }

    question_table <- if (length(question_results) > 0) {
      batch_rbind(question_results)
    } else {
      data.frame(stringsAsFactors = FALSE)
    }

  } else if (question_info$Variable_Type == "Numeric") {
    # ---------------------------------------------------------------------
    # NUMERIC QUESTIONS
    # TRS v1.0: Processing failures must refuse, not warn and continue
    # ---------------------------------------------------------------------
    individual_results <- tryCatch({
      process_numeric_question(
        filtered_data, question_info, question_options,
        banner_info, banner_row_indices, question_weights,
        banner_bases, config, is_weighted
      )
    }, error = function(e) {
      tabs_refuse(
        code = "DATA_NUMERIC_QUESTION_FAILED",
        title = paste0("Failed to Process Numeric Question: ", question_code),
        problem = paste0("Numeric question processing failed: ", conditionMessage(e)),
        why_it_matters = "This question will be missing from output, producing incomplete results.",
        how_to_fix = c(
          "Check that the question data is in the expected numeric format",
          "Verify the question configuration in Survey_Structure",
          "Review the error message for specific issues"
        )
      )
    })

    question_table <- if (!is.null(individual_results)) {
      individual_results
    } else {
      data.frame(stringsAsFactors = FALSE)
    }

  } else {
    # ---------------------------------------------------------------------
    # STANDARD QUESTIONS
    # TRS v1.0: Processing failures must refuse, not warn and continue
    # ---------------------------------------------------------------------
    individual_results <- tryCatch({
      process_standard_question(filtered_data, question_info, question_options,
                      banner_info, banner_row_indices, question_weights,
                      banner_bases, config,
                      is_weighted = is_weighted)
    }, error = function(e) {
      tabs_refuse(
        code = "DATA_QUESTION_PROCESSING_FAILED",
        title = paste0("Failed to Process Question: ", question_code),
        problem = paste0("Question processing failed: ", conditionMessage(e)),
        why_it_matters = "This question will be missing from output, producing incomplete results.",
        how_to_fix = c(
          "Check the question data and configuration",
          "Verify response options match the data",
          "Review the error message for specific issues"
        )
      )
    })

    boxcategory_results <- tryCatch({
      add_boxcategory_summaries(filtered_data, question_info, question_options,
                               banner_info, banner_row_indices, question_weights,
                               banner_bases, config,
                               is_weighted = is_weighted)
    }, error = function(e) {
      return(NULL)
    })

    # Add net difference testing
    if (!is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      boxcategory_results <- tryCatch({
        add_net_significance_rows(
          boxcategory_results, filtered_data, question_info, question_options,
          banner_info, banner_row_indices, question_weights, banner_bases,
          config, is_weighted = is_weighted
        )
      }, error = function(e) {
        warning(sprintf("Net difference testing failed for %s: %s",
                       question_code, conditionMessage(e)), call. = FALSE)
        boxcategory_results
      })
    }

    # Chi-square test
    chi_square_row <- NULL
    enable_chi <- FALSE
    if ("enable_chi_square" %in% names(config)) {
      enable_chi <- safe_logical(config$enable_chi_square, default = FALSE)
    }

    if (enable_chi && !is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      chi_square_row <- calculate_chi_square_row(
        boxcategory_results, banner_info, config, total_column, question_code
      )
    }

    # Net positive calculation
    if (!is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      boxcategory_results <- tryCatch({
        add_net_positive_row(
          boxcategory_results, filtered_data, question_info, question_options,
          banner_info, banner_row_indices, question_weights, banner_bases,
          config, is_weighted = is_weighted
        )
      }, error = function(e) {
        warning(sprintf("Net positive calculation failed for %s: %s",
                       question_code, conditionMessage(e)), call. = FALSE)
        boxcategory_results
      })
    }

    # Summary statistics
    summary_results <- tryCatch({
      add_summary_statistic(filtered_data, question_info, question_options,
                           banner_info, banner_row_indices, question_weights,
                           banner_bases, question_row, config,
                           is_weighted = is_weighted)
    }, error = function(e) {
      return(NULL)
    })

    # Combine all results
    question_table <- data.frame(stringsAsFactors = FALSE)
    if (!is.null(individual_results) && nrow(individual_results) > 0) {
      question_table <- rbind(question_table, individual_results)
    }
    if (!is.null(boxcategory_results) && nrow(boxcategory_results) > 0) {
      question_table <- rbind(question_table, boxcategory_results)
    }
    if (!is.null(chi_square_row) && nrow(chi_square_row) > 0) {
      question_table <- rbind(question_table, chi_square_row)
    }
    if (!is.null(summary_results) && nrow(summary_results) > 0) {
      question_table <- rbind(question_table, summary_results)
    }
  }

  # ===========================================================================
  # RETURN STRUCTURED RESULT
  # ===========================================================================

  return(list(
    question_code = question_code,
    question_text = question_info$QuestionText,
    question_type = question_info$Variable_Type,
    base_filter = base_filter,
    bases = banner_bases,
    table = question_table
  ))
}

# ==============================================================================
# FULL ORCHESTRATION COORDINATOR
# ==============================================================================

#' Process All Questions
#'
#' Main orchestration function that coordinates processing of all selected
#' questions. Handles progress tracking, memory management, checkpointing,
#' and error recovery.
#'
#' Extracted from run_crosstabs.R main loop for modularity.
#'
#' @param questions_to_process Data frame with question selection
#' @param survey_data Data frame, raw survey data
#' @param survey_structure List with questions and options
#' @param banner_info List, banner structure metadata
#' @param master_weights Numeric vector, weights for all respondents
#' @param config Configuration object
#' @param checkpoint_config List with enabled, file, frequency
#' @param progress_callback Function for progress updates (optional)
#' @param is_weighted Logical, whether analysis is weighted
#' @param total_column Character, name of total column
#' @param all_questions Data frame, full question list for progress calculation
#' @param processed_so_far Character vector, already processed questions
#'
#' @return List with:
#'   - all_results: List of question results
#'   - processed_questions: Character vector of processed question codes
#'
#' @export
process_all_questions <- function(questions_to_process, survey_data,
                                 survey_structure, banner_info, master_weights,
                                 config, checkpoint_config,
                                 progress_callback = NULL,
                                 is_weighted = FALSE,
                                 total_column = "Total",
                                 all_questions = NULL,
                                 processed_so_far = character(0)) {

  all_results <- list()
  processed_questions <- processed_so_far
  skipped_questions <- list()  # TRS v1.0: Track skipped questions for PARTIAL status
  processing_start <- Sys.time()
  checkpoint_counter <- 0

  # Use all_questions for progress if provided, otherwise use questions_to_process
  total_question_count <- if (!is.null(all_questions)) {
    nrow(all_questions)
  } else {
    nrow(questions_to_process)
  }

  for (q_idx in seq_len(nrow(questions_to_process))) {
    current_question_code <- questions_to_process$QuestionCode[q_idx]

    # Progress logging
    total_processed <- length(processed_questions) + q_idx
    if (!is.null(progress_callback)) {
      progress_callback(total_processed, total_question_count,
                       current_question_code, processing_start)
    }

    # Memory check every 10 questions
    if (q_idx %% 10 == 0) {
      check_memory(force_gc = TRUE)
    }

    # Prepare question data
    base_filter <- questions_to_process$BaseFilter[q_idx]
    prepared_data <- prepare_question_data(
      current_question_code, base_filter,
      survey_data, survey_structure, banner_info, master_weights
    )

    if (is.null(prepared_data)) {
      # TRS v1.0: Record skipped question for PARTIAL status disclosure
      skipped_questions[[current_question_code]] <- list(
        question_code = current_question_code,
        reason = "Preparation failed (unexpected - check data and config)",
        stage = "prepare_question_data"
      )
      message(sprintf("[TRS PARTIAL] Skipping %s: preparation failed unexpectedly", current_question_code))
      next
    }

    # Process question
    question_result <- process_single_question(
      current_question_code, prepared_data,
      banner_info, config, is_weighted,
      questions_to_process[q_idx, ],
      total_column
    )

    if (is.null(question_result)) {
      # TRS v1.0: Record skipped question for PARTIAL status disclosure
      skipped_questions[[current_question_code]] <- list(
        question_code = current_question_code,
        reason = "Processing failed (unexpected - check question configuration)",
        stage = "process_single_question"
      )
      message(sprintf("[TRS PARTIAL] Skipping %s: processing failed unexpectedly", current_question_code))
      next
    }

    # Store result
    all_results[[current_question_code]] <- question_result
    processed_questions <- c(processed_questions, current_question_code)

    # Checkpointing
    checkpoint_counter <- checkpoint_counter + 1
    if (checkpoint_config$enabled &&
        checkpoint_counter >= checkpoint_config$frequency) {
      save_checkpoint(checkpoint_config$file, all_results, processed_questions)
      checkpoint_counter <- 0
    }
  }

  # TRS v1.0: Determine run status based on skipped questions
  run_status <- if (length(skipped_questions) > 0) "PARTIAL" else "PASS"

  if (run_status == "PARTIAL") {
    message(sprintf("[TRS] Run completed with PARTIAL status: %d questions skipped",
                    length(skipped_questions)))
  }

  return(list(
    all_results = all_results,
    processed_questions = processed_questions,
    skipped_questions = skipped_questions,
    run_status = run_status
  ))
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Question Orchestrator Module Information
#'
#' Returns metadata about the question_orchestrator module.
#'
#' @return List with module information
#' @export
get_question_orchestrator_info <- function() {
  list(
    module = "question_orchestrator",
    version = "1.0.0",
    date = "2025-11-04",
    description = "Question processing coordination and preparation",
    functions = c(
      "prepare_question_data",
      "process_single_question",
      "process_all_questions",
      "get_question_orchestrator_info"
    ),
    dependencies = c(
      "shared_functions.R",
      "banner.R",
      "weighting.R",
      "validation.R"
    )
  )
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs question_orchestrator module loaded")

# ==============================================================================
# END OF MODULE: QUESTION_ORCHESTRATOR.R
# ==============================================================================
