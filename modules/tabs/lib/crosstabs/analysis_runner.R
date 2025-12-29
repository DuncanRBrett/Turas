# ==============================================================================
# ANALYSIS_RUNNER.R - TURAS V10.2 (Phase 4 Refactoring)
# ==============================================================================
# Extracted from run_crosstabs.R for better modularity
#
# PURPOSE: Main analysis processing orchestration
#
# FUNCTIONS:
#   - run_validation() - Run all validations
#   - create_banner_safe() - Create banner structure with error handling
#   - print_config_summary() - Print configuration summary
#   - estimate_runtime() - Estimate processing time
#   - process_questions() - Process all questions
#   - print_partial_status() - Print partial status disclosure
#   - process_composites() - Process composite metrics
#   - add_composites_to_results() - Add composites to results list
#   - run_crosstabs_analysis() - Main entry point
#
# DEPENDENCIES:
#   - validation.R (for run_all_validations)
#   - composite_processor.R (for validate_composite_definitions, process_all_composites)
#   - banner.R (for create_banner_structure)
#   - banner_indices.R (for create_banner_row_indices)
#   - question_orchestrator.R (for process_all_questions)
#   - 00_guard.R (for tabs_refuse, safe_execute)
#   - logging_utils.R (for log_message, log_progress)
#
# ==============================================================================

# ==============================================================================
# VALIDATION
# ==============================================================================

#' Run All Validations
#'
#' Runs comprehensive validation and composite definition validation.
#'
#' @param survey_structure List, survey structure
#' @param survey_data Data frame, survey data
#' @param config_obj List, configuration
#' @param composite_defs Data frame, composite definitions (can be NULL)
#' @return Data frame, error log
#' @export
run_validation <- function(survey_structure, survey_data, config_obj, composite_defs) {
  log_message("Running comprehensive validation...", "INFO")

  error_log <- run_all_validations(survey_structure, survey_data, config_obj)

  if (nrow(error_log) > 0) {
    log_message(sprintf("Found %d validation issues", nrow(error_log)), "WARNING")
  }

  # Validate composites if defined
  if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
    log_message("Validating composite definitions...", "INFO")

    validation_result <- validate_composite_definitions(
      composite_defs = composite_defs,
      questions_df = survey_structure$questions,
      survey_data = survey_data
    )

    if (!validation_result$is_valid) {
      tabs_refuse(
        code = "CFG_COMPOSITE_VALIDATION_FAILED",
        title = "Composite Definition Validation Failed",
        problem = "One or more composite metric definitions are invalid.",
        why_it_matters = "Invalid composites will produce incorrect or missing results.",
        how_to_fix = c(
          "Review the composite definitions in your config",
          "Ensure all referenced questions exist",
          "Check formula syntax is correct"
        ),
        details = paste(validation_result$errors, collapse = "\n")
      )
    }

    if (length(validation_result$warnings) > 0) {
      for (warn in validation_result$warnings) {
        warning(warn, call. = FALSE)
      }
    }

    log_message("Composite definitions validated", "INFO")
  }

  error_log
}


# ==============================================================================
# BANNER CREATION
# ==============================================================================

#' Create Banner Structure Safely
#'
#' Creates banner structure with error handling.
#'
#' @param selection_df Data frame, question selection
#' @param survey_structure List, survey structure
#' @return List, banner info
#' @export
create_banner_safe <- function(selection_df, survey_structure) {
  log_message("Creating banner structure...", "INFO")

  banner_info <- safe_execute(
    create_banner_structure(selection_df, survey_structure),
    default = NULL,
    error_msg = "Failed to create banner structure"
  )

  if (is.null(banner_info)) {
    tabs_refuse(
      code = "CFG_BANNER_CREATION_FAILED",
      title = "Failed to Create Banner Structure",
      problem = "Could not create banner structure from configuration.",
      why_it_matters = "Crosstabs require a valid banner to break down results by segments.",
      how_to_fix = c(
        "Check that at least one question has UseBanner='Y' in Selection sheet",
        "Verify banner question has valid options defined",
        "Check that banner question exists in the data"
      )
    )
  }

  log_message(sprintf("Banner: %d columns", length(banner_info$columns)), "INFO")

  banner_info
}


# ==============================================================================
# CONFIGURATION SUMMARY
# ==============================================================================

#' Estimate Runtime Based on Dataset Size
#'
#' Provides an estimate of how long processing will take.
#'
#' @param n_questions Integer, number of questions to process
#' @param n_respondents Integer, number of respondents in data
#' @param n_banner_cols Integer, number of banner columns
#' @return Character, formatted time estimate
#' @export
estimate_runtime <- function(n_questions, n_respondents, n_banner_cols = 5) {
  # Based on documented benchmarks
  base_time_sec <- (n_respondents / 500) * (n_questions / 20) * (n_banner_cols / 5) * 2.5

  if (base_time_sec < 60) {
    return(sprintf("~%.0f seconds", base_time_sec))
  } else if (base_time_sec < 3600) {
    return(sprintf("~%.1f minutes", base_time_sec / 60))
  } else {
    return(sprintf("~%.1f hours", base_time_sec / 3600))
  }
}


#' Print Configuration Summary
#'
#' Displays analysis configuration before processing.
#'
#' @param config_obj List, configuration object
#' @param n_questions Integer, number of questions
#' @param n_respondents Integer, number of respondents
#' @param n_banner_cols Integer, number of banner columns
#' @return Invisible NULL
#' @export
print_config_summary <- function(config_obj, n_questions, n_respondents, n_banner_cols) {
  cat("\n")
  cat(strrep("=", 60), "\n")
  cat("ANALYSIS CONFIGURATION\n")
  cat(strrep("=", 60), "\n")
  cat(sprintf("  Questions to process:    %d\n", n_questions))
  cat(sprintf("  Respondents:             %d\n", n_respondents))
  cat(sprintf("  Banner columns:          %d\n", n_banner_cols))
  cat(sprintf("  Weighting:               %s\n",
              if(config_obj$apply_weighting) config_obj$weight_variable else "None"))
  cat(sprintf("  Significance testing:    %s\n",
              if(config_obj$enable_significance_testing)
                sprintf("Yes (alpha=%.3f)", config_obj$alpha) else "No"))
  cat(sprintf("  Estimated time:          %s\n",
              estimate_runtime(n_questions, n_respondents, n_banner_cols)))
  cat(strrep("=", 60), "\n\n")

  invisible(NULL)
}


# ==============================================================================
# QUESTION PROCESSING
# ==============================================================================

#' Get Progress Callback
#'
#' Returns the appropriate progress callback (GUI or console).
#'
#' @return Function, progress callback
get_progress_callback <- function() {
  if (exists("gui_progress_callback", envir = .GlobalEnv)) {
    get("gui_progress_callback", envir = .GlobalEnv)
  } else {
    log_progress
  }
}


#' Process All Questions
#'
#' Processes all questions using the question orchestrator.
#'
#' @param remaining_questions Data frame, questions to process
#' @param survey_data Data frame, survey data
#' @param survey_structure List, survey structure
#' @param banner_info List, banner information
#' @param master_weights Numeric vector, weights
#' @param config_obj List, configuration
#' @param checkpoint_file Character, checkpoint file path
#' @param checkpoint_frequency Integer, checkpoint frequency
#' @param is_weighted Logical, whether data is weighted
#' @param total_column Character, total column name
#' @param crosstab_questions Data frame, all questions
#' @param processed_questions Character vector, already processed
#' @return List with results and status
#' @export
process_questions <- function(remaining_questions, survey_data, survey_structure,
                               banner_info, master_weights, config_obj,
                               checkpoint_file, checkpoint_frequency,
                               is_weighted, total_column,
                               crosstab_questions, processed_questions) {

  log_message(sprintf("Processing %d questions...", nrow(remaining_questions)), "INFO")
  cat("\n")

  # Get appropriate progress callback
  active_progress_callback <- get_progress_callback()

  # Process questions
  orchestration_result <- process_all_questions(
    remaining_questions, survey_data, survey_structure,
    banner_info, master_weights, config_obj,
    checkpoint_config = list(
      enabled = config_obj$enable_checkpointing,
      file = checkpoint_file,
      frequency = checkpoint_frequency
    ),
    progress_callback = active_progress_callback,
    is_weighted = is_weighted,
    total_column = total_column,
    all_questions = crosstab_questions,
    processed_so_far = processed_questions
  )

  cat("\n")

  orchestration_result
}


#' Print Partial Status Disclosure
#'
#' Prints TRS partial status disclosure message.
#'
#' @param run_status Character, "PASS" or "PARTIAL"
#' @param skipped_questions List, skipped questions
#' @param partial_questions List, partial questions
#' @return Invisible NULL
print_partial_status <- function(run_status, skipped_questions, partial_questions) {
  if (run_status != "PARTIAL") return(invisible(NULL))

  cat("\n")
  cat(paste(rep("!", 80), collapse=""), "\n")
  cat("[TRS PARTIAL] ANALYSIS COMPLETED WITH PARTIAL RESULTS\n")
  cat(paste(rep("!", 80), collapse=""), "\n")

  # Report skipped questions
  if (length(skipped_questions) > 0) {
    cat(sprintf("\n  SKIPPED QUESTIONS: %d\n", length(skipped_questions)))
    cat("  The following questions are MISSING from your output:\n\n")
    for (skip_code in names(skipped_questions)) {
      skip_info <- skipped_questions[[skip_code]]
      cat(sprintf("    - %s: %s (stage: %s)\n",
                  skip_code, skip_info$reason, skip_info$stage))
    }
  }

  # Report questions with missing sections
  if (length(partial_questions) > 0) {
    cat(sprintf("\n  QUESTIONS WITH MISSING SECTIONS: %d\n", length(partial_questions)))
    cat("  The following questions have incomplete output:\n\n")
    for (pq_code in names(partial_questions)) {
      pq_info <- partial_questions[[pq_code]]
      cat(sprintf("    - %s:\n", pq_code))
      for (section in pq_info$sections) {
        cat(sprintf("        * %s: %s\n", section$section, section$error))
      }
    }
  }

  cat("\n")
  cat("  ACTION REQUIRED: Review and fix the issues above, then re-run.\n")
  cat("  A 'Run_Status' sheet will be included in your workbook.\n")
  cat(paste(rep("!", 80), collapse=""), "\n\n")

  invisible(NULL)
}


# ==============================================================================
# COMPOSITE PROCESSING
# ==============================================================================

#' Process Composite Metrics
#'
#' Processes all composite metrics.
#'
#' @param composite_defs Data frame, composite definitions
#' @param survey_data Data frame, survey data
#' @param survey_structure List, survey structure
#' @param banner_info List, banner information
#' @param config_obj List, configuration
#' @return List, composite results
#' @export
process_composites <- function(composite_defs, survey_data, survey_structure,
                                banner_info, config_obj) {
  if (is.null(composite_defs) || nrow(composite_defs) == 0) {
    return(list())
  }

  log_message(sprintf("Processing %d composite metric(s)...", nrow(composite_defs)), "INFO")

  # Create banner row indices for composites
  log_message("Creating banner row indices for composites...", "INFO")
  banner_result <- create_banner_row_indices(survey_data, banner_info)
  banner_row_indices <- banner_result$row_indices

  # Merge row_indices into banner_info as 'subsets'
  banner_info$subsets <- banner_row_indices
  log_message(sprintf("Created indices for %d banner columns", length(banner_row_indices)), "INFO")

  composite_results <- tryCatch({
    process_all_composites(
      composite_defs = composite_defs,
      data = survey_data,
      questions_df = survey_structure$questions,
      banner_info = banner_info,
      config = config_obj
    )
  }, error = function(e) {
    tabs_refuse(
      code = "MODEL_COMPOSITE_PROCESSING_FAILED",
      title = "Composite Processing Failed",
      problem = "An error occurred while processing composite metrics.",
      why_it_matters = "Composite metrics are required outputs and cannot be skipped.",
      how_to_fix = c(
        "Check composite definitions for errors",
        "Verify all referenced questions exist in data",
        "Review the error details below"
      ),
      details = paste0("Error: ", e$message, "\n\nCall stack:\n", paste(sys.calls(), collapse = "\n"))
    )
  })

  log_message(sprintf("Processed %d composite(s)", length(composite_results)), "INFO")

  composite_results
}


#' Add Composites to Results
#'
#' Adds composite results to the main results list.
#'
#' @param all_results List, all question results
#' @param composite_results List, composite results
#' @param banner_info List, banner information
#' @return List, updated all_results
#' @export
add_composites_to_results <- function(all_results, composite_results, banner_info) {
  if (length(composite_results) == 0) {
    return(all_results)
  }

  for (comp_code in names(composite_results)) {
    comp_result <- composite_results[[comp_code]]

    # Safety check
    if (is.null(comp_result) || is.null(comp_result$question_table)) {
      warning(sprintf("Composite '%s' has no results table, skipping", comp_code))
      next
    }

    if (nrow(comp_result$question_table) == 0) {
      warning(sprintf("Composite '%s' has empty results table, skipping", comp_code))
      next
    }

    # Get composite label safely
    comp_label <- if ("RowLabel" %in% names(comp_result$question_table) &&
                      nrow(comp_result$question_table) > 0) {
      comp_result$question_table$RowLabel[1]
    } else if (!is.null(comp_result$metadata$composite_code)) {
      comp_result$metadata$composite_code
    } else {
      comp_code
    }

    # Convert to standard result format
    all_results[[comp_code]] <- list(
      question_code = comp_code,
      question_text = comp_label,
      question_type = "Composite",
      base_filter = NA,
      table = comp_result$question_table,
      bases = banner_info$base_sizes
    )
  }

  if (length(composite_results) > 0) {
    log_message(sprintf("Added %d composite(s) to results", length(composite_results)), "INFO")
  }

  all_results
}


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Crosstabs Analysis
#'
#' Main entry point for running the crosstabs analysis.
#'
#' @param config_result List, result from load_crosstabs_config()
#' @param data_result List, result from load_crosstabs_data()
#' @param checkpoint_frequency Integer, checkpoint frequency (default: 10)
#' @param total_column Character, total column name (default: "Total")
#' @return List with all analysis results
#' @export
run_crosstabs_analysis <- function(config_result, data_result,
                                    checkpoint_frequency = 10,
                                    total_column = "Total") {

  # Run validation
  error_log <- run_validation(
    data_result$survey_structure,
    data_result$survey_data,
    config_result$config_obj,
    data_result$composite_defs
  )

  # Create banner structure
  banner_info <- create_banner_safe(
    data_result$selection_df,
    data_result$survey_structure
  )

  # Print configuration summary
  print_config_summary(
    config_result$config_obj,
    nrow(data_result$crosstab_questions),
    nrow(data_result$survey_data),
    length(banner_info$columns)
  )

  # Setup checkpointing
  checkpoint_file <- get_checkpoint_path(
    config_result$project_root,
    config_result$output_subfolder
  )

  checkpoint_state <- setup_checkpointing(
    config_result$config_obj$enable_checkpointing,
    checkpoint_file,
    data_result$crosstab_questions
  )

  # Process questions
  orchestration_result <- process_questions(
    checkpoint_state$remaining_questions,
    data_result$survey_data,
    data_result$survey_structure,
    banner_info,
    data_result$master_weights,
    config_result$config_obj,
    checkpoint_file,
    checkpoint_frequency,
    data_result$is_weighted,
    total_column,
    data_result$crosstab_questions,
    checkpoint_state$processed_questions
  )

  all_results <- orchestration_result$all_results
  processed_questions <- orchestration_result$processed_questions
  run_status <- orchestration_result$run_status
  skipped_questions <- orchestration_result$skipped_questions
  partial_questions <- orchestration_result$partial_questions

  # Print partial status if needed
  print_partial_status(run_status, skipped_questions, partial_questions)

  log_message(sprintf("Processed %d questions", length(all_results)), "INFO")

  # Cleanup checkpoint
  if (config_result$config_obj$enable_checkpointing) {
    cleanup_checkpoint(checkpoint_file)
  }

  # Process composites
  composite_results <- process_composites(
    data_result$composite_defs,
    data_result$survey_data,
    data_result$survey_structure,
    banner_info,
    config_result$config_obj
  )

  # Add composites to results
  all_results <- add_composites_to_results(all_results, composite_results, banner_info)

  # Return all results
  list(
    all_results = all_results,
    composite_results = composite_results,
    banner_info = banner_info,
    error_log = error_log,
    run_status = run_status,
    skipped_questions = skipped_questions,
    partial_questions = partial_questions,
    processed_questions = processed_questions
  )
}
