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
run_validation <- function(survey_structure, survey_data, config_obj,
                           composite_defs, selection_df = NULL) {
  log_message("Running comprehensive validation...", "INFO")

  error_log <- run_all_validations(survey_structure, survey_data, config_obj,
                                    selection_df = selection_df)

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
        cat(sprintf("  [WARNING] %s\n", warn))
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

  # Output features. The interactive report is decided later in the run (the
  # GUI's default and an explicit config opt-out both feed into it), so this
  # header states what is settled here: the workbook.
  cat(sprintf("  Interactive report:      %s\n",
              if (isTRUE(config_obj$html_report_v2)) "Yes (config)" else "Set at run time"))

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
#' @param results_so_far List, results restored from a checkpoint (carried into
#'   the run so a resume does not lose everything processed before the crash)
#' @return List with results and status
#' @export
process_questions <- function(remaining_questions, survey_data, survey_structure,
                               banner_info, master_weights, config_obj,
                               checkpoint_file, checkpoint_frequency,
                               is_weighted, total_column,
                               crosstab_questions, processed_questions,
                               results_so_far = list(),
                               checkpoint_fingerprint = NULL) {

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
      frequency = checkpoint_frequency,
      fingerprint = checkpoint_fingerprint
    ),
    progress_callback = active_progress_callback,
    is_weighted = is_weighted,
    total_column = total_column,
    all_questions = crosstab_questions,
    processed_so_far = processed_questions,
    results_so_far = results_so_far
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

  # Report skipped questions. The two kinds are listed apart: an empty subgroup
  # is not something to go and fix, so it must not appear under ACTION REQUIRED
  # alongside skips that are genuinely wrong.
  is_empty_base <- vapply(skipped_questions,
                          function(s) identical(s$kind, "empty_base"), logical(1))
  degrading_skips <- skipped_questions[!is_empty_base]
  empty_base_skips <- skipped_questions[is_empty_base]

  if (length(degrading_skips) > 0) {
    cat(sprintf("\n  SKIPPED QUESTIONS: %d\n", length(degrading_skips)))
    cat("  The following questions are MISSING from your output:\n\n")
    for (skip_code in names(degrading_skips)) {
      skip_info <- degrading_skips[[skip_code]]
      cat(sprintf("    - %s: %s (stage: %s)\n",
                  skip_code, skip_info$reason, skip_info$stage))
    }
  }

  if (length(empty_base_skips) > 0) {
    cat(sprintf("\n  NO RESPONDENTS TO TABULATE: %d (not a fault)\n",
                length(empty_base_skips)))
    cat("  Nobody falls into these subgroups, so there is nothing to tabulate:\n\n")
    for (skip_code in names(empty_base_skips)) {
      cat(sprintf("    - %s: %s\n", skip_code, empty_base_skips[[skip_code]]$reason))
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
      config = config_obj,
      options_df = survey_structure$options
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


#' Provenance an analyst declared for a question on the Selection sheet
#'
#' Composites do not go through prepare_question_data(), so this is how their
#' Selection row is read. Returns "" for a field the sheet does not carry or
#' leaves blank, which is what lets the caller fall back to the composite's own
#' definition per field rather than all-or-nothing.
#'
#' @param selection_df Data frame, the Selection sheet (may be NULL)
#' @param code Character, the question code to look up
#' @return list(source = character, formula = character)
#' @keywords internal
selection_declared_provenance <- function(selection_df, code) {
  blank <- list(source = "", formula = "")
  if (is.null(selection_df) || !is.data.frame(selection_df) ||
      !"QuestionCode" %in% names(selection_df)) {
    return(blank)
  }
  idx <- which(as.character(selection_df$QuestionCode) == code)
  if (length(idx) == 0) return(blank)
  cell <- function(col) {
    if (!col %in% names(selection_df)) return("")
    v <- selection_df[[col]][idx[1]]
    if (is.null(v) || length(v) == 0 || is.na(v)) return("")
    trimws(as.character(v))
  }
  list(source = cell("Source"), formula = cell("Formula"))
}

#' Add Composites to Results
#'
#' Adds composite results to the main results list.
#'
#' @param all_results List, all question results
#' @param composite_results List, composite results
#' @param banner_info List, banner information
#' @param composite_defs Data frame, the Composite_Metrics sheet. Optional,
#'   supplied so each composite can state its own provenance (which questions
#'   feed it and how they combine) without the analyst retyping it.
#' @param selection_df Data frame, the Selection sheet. Optional. An analyst's
#'   own Source / Formula wins over the generated wording, per field.
#' @return List, updated all_results
#' @export
add_composites_to_results <- function(all_results, composite_results, banner_info,
                                      composite_defs = NULL, selection_df = NULL) {
  if (length(composite_results) == 0) {
    return(all_results)
  }

  for (comp_code in names(composite_results)) {
    comp_result <- composite_results[[comp_code]]

    # Safety check
    if (is.null(comp_result) || is.null(comp_result$question_table)) {
      cat(sprintf("  [WARNING] Composite '%s' has no results table, skipping\n", comp_code))
      next
    }

    if (nrow(comp_result$question_table) == 0) {
      cat(sprintf("  [WARNING] Composite '%s' has empty results table, skipping\n", comp_code))
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

    # Get bases from the first source question (composites share the same
    # respondent pool as their source questions, so bases match)
    comp_bases <- NULL
    if (!is.null(comp_result$metadata$source_questions)) {
      for (src_q in comp_result$metadata$source_questions) {
        if (!is.null(all_results[[src_q]]) && !is.null(all_results[[src_q]]$bases)) {
          comp_bases <- all_results[[src_q]]$bases
          break
        }
      }
    }
    # Fallback: use first available question's bases
    if (is.null(comp_bases)) {
      for (result in all_results) {
        if (!is.null(result$bases)) {
          comp_bases <- result$bases
          break
        }
      }
    }

    # Provenance. A composite is the one derived question the engine builds
    # itself, so it can say which questions feed it and how they combine
    # without anyone declaring it. Otherwise a calculated index would be the
    # one obviously derived figure on the page with nothing said about it.
    # The analyst's own words still win, per field.
    comp_def <- NULL
    if (!is.null(composite_defs) && is.data.frame(composite_defs) &&
        nrow(composite_defs) > 0 && "CompositeCode" %in% names(composite_defs)) {
      di <- which(as.character(composite_defs$CompositeCode) == comp_code)
      if (length(di) > 0) comp_def <- composite_defs[di[1], , drop = FALSE]
    }
    auto <- composite_provenance(comp_def)
    declared <- selection_declared_provenance(selection_df, comp_code)
    comp_source <- if (nzchar(declared$source)) declared$source else auto$source
    comp_formula <- if (nzchar(declared$formula)) declared$formula else auto$formula

    # Convert to standard result format
    all_results[[comp_code]] <- list(
      question_code = comp_code,
      question_text = comp_label,
      question_type = "Composite",
      base_filter = NA,
      filter_label = NA_character_,
      source = if (nzchar(comp_source)) comp_source else NA_character_,
      formula = if (nzchar(comp_formula)) comp_formula else NA_character_,
      table = comp_result$question_table,
      bases = comp_bases
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
    data_result$composite_defs,
    data_result$selection_df
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

  # A checkpoint may only be resumed into the run that created it (C-1).
  checkpoint_fingerprint <- build_checkpoint_fingerprint(
    config_file = config_result$config_file,
    structure_file = config_result$structure_file_path,
    data_file = data_result$data_file_path,
    question_codes = data_result$crosstab_questions$QuestionCode,
    banner_labels = as.character(banner_info$internal_keys),
    config_obj = config_result$config_obj
  )

  checkpoint_state <- setup_checkpointing(
    config_result$config_obj$enable_checkpointing,
    checkpoint_file,
    data_result$crosstab_questions,
    checkpoint_fingerprint
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
    checkpoint_state$processed_questions,
    checkpoint_state$all_results,
    checkpoint_fingerprint
  )

  all_results <- orchestration_result$all_results
  processed_questions <- orchestration_result$processed_questions
  run_status <- orchestration_result$run_status
  skipped_questions <- orchestration_result$skipped_questions
  partial_questions <- orchestration_result$partial_questions

  # Print partial status if needed
  print_partial_status(run_status, skipped_questions, partial_questions)

  log_message(sprintf("Processed %d questions", length(all_results)), "INFO")

  # NOTE: the checkpoint is NOT cleaned up here. It used to be, which threw away
  # the whole analysis if composites, sheet building or the save then failed,
  # the re-run started from zero (review 2026-08-21, M-11). run_crosstabs.R now
  # removes it only after the workbook is safely on disk.

  # Process composites
  composite_results <- process_composites(
    data_result$composite_defs,
    data_result$survey_data,
    data_result$survey_structure,
    banner_info,
    config_result$config_obj
  )

  # A failed composite (REFUSED entry) makes the run PARTIAL. A contractual
  # metric is absent from the deliverable (review 2026-08, I12).
  failed_comps <- names(Filter(
    function(x) is.list(x) && identical(x$status, "REFUSED"), composite_results))
  if (length(failed_comps) > 0) {
    run_status <- "PARTIAL"
    for (fc in failed_comps) {
      partial_questions[[fc]] <- list(sections = list(list(
        section = "Composite",
        error = if (is.null(composite_results[[fc]]$message)) "processing failed" else composite_results[[fc]]$message
      )))
    }
    composite_results <- composite_results[setdiff(names(composite_results), failed_comps)]
    cat(sprintf("\n  [TURAS] %d composite(s) FAILED and are absent from the output: %s\n",
                length(failed_comps), paste(failed_comps, collapse = ", ")))
    cat("  Run status: PARTIAL\n\n")
  }

  # Add composites to results
  all_results <- add_composites_to_results(all_results, composite_results, banner_info,
                                           data_result$composite_defs,
                                           data_result$selection_df)

  # Return all results
  list(
    all_results = all_results,
    composite_results = composite_results,
    banner_info = banner_info,
    checkpoint_file = checkpoint_file,
    checkpoint_enabled = isTRUE(config_result$config_obj$enable_checkpointing),
    error_log = error_log,
    run_status = run_status,
    skipped_questions = skipped_questions,
    partial_questions = partial_questions,
    processed_questions = processed_questions
  )
}
