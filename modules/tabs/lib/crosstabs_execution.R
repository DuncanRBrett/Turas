# ==============================================================================
# MODULE: crosstabs_execution.R
# ==============================================================================
# Purpose: Main execution orchestration for crosstab analysis
#
# This module orchestrates:
# - Checkpoint management for resumable processing
# - Question processing with progress tracking
# - Composite metric processing
# - Excel workbook creation and writing
# - TRS status reporting
# - Output file saving
#
# Version: 10.0
# TRS Compliance: v1.0
# ==============================================================================

# ==============================================================================
# CHECKPOINTING SETUP
# ==============================================================================

#' Setup checkpointing for question processing
#'
#' @param config_obj Configuration object
#' @param project_root Project root directory
#' @param output_subfolder Output subfolder path
#' @param crosstab_questions Data frame of questions to process
#' @return List with all_results, processed_questions, remaining_questions
#' @export
setup_checkpointing <- function(config_obj, project_root, output_subfolder, crosstab_questions) {
  checkpoint_file <- file.path(project_root, output_subfolder,
                               ".crosstabs_checkpoint.rds")

  if (config_obj$enable_checkpointing) {
    checkpoint_data <- load_checkpoint(checkpoint_file)

    if (!is.null(checkpoint_data)) {
      all_results <- checkpoint_data$results
      processed_questions <- checkpoint_data$processed
      remaining_questions <- crosstab_questions[
        !crosstab_questions$QuestionCode %in% processed_questions,
      ]

      log_message(sprintf("Resuming: %d questions remaining",
                         nrow(remaining_questions)), "INFO")
    } else {
      all_results <- list()
      processed_questions <- character(0)
      remaining_questions <- crosstab_questions
    }
  } else {
    all_results <- list()
    processed_questions <- character(0)
    remaining_questions <- crosstab_questions
  }

  return(list(
    checkpoint_file = checkpoint_file,
    all_results = all_results,
    processed_questions = processed_questions,
    remaining_questions = remaining_questions
  ))
}

# ==============================================================================
# QUESTION PROCESSING
# ==============================================================================

#' Process all questions with checkpoint support
#'
#' @param remaining_questions Data frame of questions to process
#' @param survey_data Survey data frame
#' @param survey_structure Survey structure object
#' @param banner_info Banner structure
#' @param master_weights Weight vector
#' @param config_obj Configuration object
#' @param checkpoint_file Checkpoint file path
#' @param crosstab_questions All questions (for checkpoint)
#' @param processed_so_far Already processed questions
#' @param is_weighted Logical flag
#' @return List with all_results, processed_questions, run_status, skipped_questions, partial_questions
#' @export
process_questions_with_checkpointing <- function(remaining_questions, survey_data,
                                                survey_structure, banner_info,
                                                master_weights, config_obj,
                                                checkpoint_file, crosstab_questions,
                                                processed_so_far, is_weighted) {
  log_message(sprintf("Processing %d questions...", nrow(remaining_questions)), "INFO")
  cat("\n")

  # Choose progress callback: GUI progress bar if available, otherwise console log
  active_progress_callback <- if (exists("gui_progress_callback", envir = .GlobalEnv)) {
    get("gui_progress_callback", envir = .GlobalEnv)
  } else {
    log_progress
  }

  orchestration_result <- process_all_questions(
    remaining_questions, survey_data, survey_structure,
    banner_info, master_weights, config_obj,
    checkpoint_config = list(
      enabled = config_obj$enable_checkpointing,
      file = checkpoint_file,
      frequency = CHECKPOINT_FREQUENCY
    ),
    progress_callback = active_progress_callback,
    is_weighted = is_weighted,
    total_column = TOTAL_COLUMN,
    all_questions = crosstab_questions,
    processed_so_far = processed_so_far
  )

  cat("\n")
  log_message(sprintf("✓ Processed %d questions", length(orchestration_result$all_results)), "INFO")

  # Clean up checkpoint file
  if (config_obj$enable_checkpointing && file.exists(checkpoint_file)) {
    file.remove(checkpoint_file)
  }

  return(orchestration_result)
}

# ==============================================================================
# COMPOSITE PROCESSING
# ==============================================================================

#' Process composite metrics
#'
#' @param composite_defs Composite definitions data frame
#' @param survey_data Survey data frame
#' @param survey_structure Survey structure object
#' @param banner_info Banner structure (will add subsets if needed)
#' @param config_obj Configuration object
#' @return List of composite results
#' @export
process_composites <- function(composite_defs, survey_data, survey_structure,
                              banner_info, config_obj) {
  composite_results <- list()

  if (!is.null(composite_defs) && nrow(composite_defs) > 0) {
    log_message(sprintf("\nProcessing %d composite metric(s)...", nrow(composite_defs)), "INFO")

    # Create banner row indices for composites
    log_message("Creating banner row indices for composites...", "INFO")
    banner_result <- create_banner_row_indices(survey_data, banner_info)
    banner_row_indices <- banner_result$row_indices

    # Merge row_indices into banner_info as 'subsets' (expected by composite processor)
    banner_info$subsets <- banner_row_indices
    log_message(sprintf("✓ Created indices for %d banner columns", length(banner_row_indices)), "INFO")

    tryCatch({
      composite_results <- process_all_composites(
        composite_defs = composite_defs,
        data = survey_data,
        questions_df = survey_structure$questions,
        banner_info = banner_info,
        config = config_obj
      )

      log_message(sprintf("✓ Processed %d composite(s)", length(composite_results)), "INFO")
    }, error = function(e) {
      # TRS Refusal: MODEL_COMPOSITE_PROCESSING_FAILED
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
  }

  return(composite_results)
}

#' Merge composite results into main results
#'
#' @param all_results Main results list
#' @param composite_results Composite results list
#' @param banner_info Banner structure
#' @return Updated all_results
#' @export
merge_composite_results <- function(all_results, composite_results, banner_info) {
  if (length(composite_results) > 0) {
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
    log_message(sprintf("Added %d composite(s) to results", length(composite_results)), "INFO")
  }

  return(all_results)
}

# ==============================================================================
# EXCEL WORKBOOK CREATION
# ==============================================================================

#' Create Excel styles with proper decimal formatting
#'
#' @param config_obj Configuration object
#' @return List of Excel styles
#' @export
create_crosstabs_styles <- function(config_obj) {
  # Safe extraction of style parameters
  decimal_separator <- if (!is.null(config_obj$decimal_separator) &&
                           length(config_obj$decimal_separator) > 0) {
    config_obj$decimal_separator
  } else {
    "."
  }

  # Get general decimal_places as fallback
  general_decimal_places <- if (!is.null(config_obj$decimal_places) &&
                                 length(config_obj$decimal_places) > 0) {
    config_obj$decimal_places
  } else {
    1
  }

  decimal_places_percent <- if (!is.null(config_obj$decimal_places_percent) &&
                                length(config_obj$decimal_places_percent) > 0) {
    config_obj$decimal_places_percent
  } else {
    general_decimal_places
  }

  decimal_places_ratings <- if (!is.null(config_obj$decimal_places_ratings) &&
                                length(config_obj$decimal_places_ratings) > 0) {
    config_obj$decimal_places_ratings
  } else {
    general_decimal_places
  }

  decimal_places_index <- if (!is.null(config_obj$decimal_places_index) &&
                              length(config_obj$decimal_places_index) > 0) {
    config_obj$decimal_places_index
  } else {
    general_decimal_places
  }

  decimal_places_numeric <- if (!is.null(config_obj$decimal_places_numeric) &&
                                length(config_obj$decimal_places_numeric) > 0) {
    config_obj$decimal_places_numeric
  } else {
    general_decimal_places
  }

  return(create_excel_styles(
    decimal_separator,
    decimal_places_percent,
    decimal_places_ratings,
    decimal_places_index,
    decimal_places_numeric
  ))
}

#' Write all Excel sheets
#'
#' @param wb Workbook object
#' @param all_results All question results
#' @param composite_results Composite results
#' @param composite_defs Composite definitions
#' @param error_log Error log data frame
#' @param survey_data Survey data
#' @param survey_structure Survey structure
#' @param banner_info Banner structure
#' @param config_obj Configuration object
#' @param styles Excel styles
#' @param project_info Project metadata
#' @param run_status TRS run status
#' @param skipped_questions Skipped questions list
#' @param partial_questions Partial questions list
#' @param processed_questions Processed question codes
#' @param crosstab_questions All questions to analyze
#' @param master_weights Weight vector
#' @param effective_n Effective sample size
#' @param trs_state TRS state object
#' @return Invisible NULL
#' @export
write_all_sheets <- function(wb, all_results, composite_results, composite_defs,
                             error_log, survey_data, survey_structure, banner_info,
                             config_obj, styles, project_info, run_status,
                             skipped_questions, partial_questions, processed_questions,
                             crosstab_questions, master_weights, effective_n, trs_state) {
  # Summary sheet
  tryCatch({
    log_message("Creating Summary sheet...", "INFO")
    create_summary_sheet(wb, project_info, all_results, config_obj, styles,
                         SCRIPT_VERSION, TOTAL_COLUMN, VERY_SMALL_BASE_SIZE)
    log_message("✓ Summary sheet created", "INFO")
  }, error = function(e) {
    tabs_refuse(
      code = "IO_SUMMARY_SHEET_FAILED",
      title = "Failed to Create Summary Sheet",
      problem = "An error occurred while creating the Summary sheet.",
      why_it_matters = "The Summary sheet provides an overview of the analysis results.",
      how_to_fix = c(
        "Check that all results were processed correctly",
        "Review the error details below"
      ),
      details = paste0("Error: ", e$message, "\nNumber of results: ", length(all_results))
    )
  })

  # Index_Summary sheet
  default_create_summary <- !is.null(composite_defs) && nrow(composite_defs) > 0
  create_index_summary <- get_config_value(config_obj, "create_index_summary", default_create_summary)

  if (create_index_summary) {
    tryCatch({
      log_message("Building index summary...", "INFO")

      summary_table <- build_index_summary_table(
        results_list = all_results,
        composite_results = composite_results,
        banner_info = banner_info,
        config = config_obj,
        composite_defs = composite_defs
      )

      if (!is.null(summary_table) && nrow(summary_table) > 0) {
        log_message(sprintf("Writing Index_Summary sheet with %d metrics...", nrow(summary_table)), "INFO")

        write_index_summary_sheet(
          wb = wb,
          summary_table = summary_table,
          banner_info = banner_info,
          config = config_obj,
          styles = styles,
          all_results = all_results
        )

        log_message("✓ Index_Summary sheet created", "INFO")
      } else {
        log_message("No metrics to include in Index_Summary", "INFO")
      }
    }, error = function(e) {
      tabs_refuse(
        code = "IO_INDEX_SUMMARY_FAILED",
        title = "Failed to Create Index Summary Sheet",
        problem = "An error occurred while creating the Index_Summary sheet.",
        why_it_matters = "The Index_Summary sheet consolidates key metrics for easy review.",
        how_to_fix = c(
          "Check that composite definitions are valid",
          "Verify all referenced questions have results",
          "Review the error details below"
        ),
        details = paste0("Error: ", e$message)
      )
    })
  }

  # Error log
  write_error_log_sheet(wb, error_log, styles)

  # Run_Status sheet
  write_run_status_sheet(wb, run_status, skipped_questions, partial_questions,
                        processed_questions, crosstab_questions, styles, trs_state)

  # Sample Composition sheet
  if (config_obj$create_sample_composition) {
    log_message("Creating sample composition sheet...", "INFO")
    create_sample_composition_sheet(
      wb, survey_data, banner_info, master_weights, config_obj, styles, survey_structure
    )
  }

  # Crosstabs sheet
  write_crosstabs_sheet(wb, all_results, banner_info, config_obj, styles)

  invisible(NULL)
}

# ==============================================================================
# HELPER FUNCTIONS FOR SHEET WRITING
# ==============================================================================

#' Write Run_Status sheet
#'
#' @return Invisible NULL
write_run_status_sheet <- function(wb, run_status, skipped_questions, partial_questions,
                                   processed_questions, crosstab_questions, styles, trs_state) {
  tryCatch({
    log_message("Creating Run_Status sheet...", "INFO")

    # Log PARTIAL events to TRS state
    if (!is.null(trs_state)) {
      if (length(skipped_questions) > 0) {
        for (skip_code in names(skipped_questions)) {
          skip_info <- skipped_questions[[skip_code]]
          if (exists("turas_run_state_partial", mode = "function")) {
            turas_run_state_partial(
              trs_state,
              sprintf("TABS_SKIP_%s", skip_code),
              sprintf("Question skipped: %s", skip_code),
              problem = skip_info$reason,
              stage = skip_info$stage
            )
          }
        }
      }

      if (length(partial_questions) > 0) {
        for (pq_code in names(partial_questions)) {
          pq_info <- partial_questions[[pq_code]]
          for (section in pq_info$sections) {
            if (exists("turas_run_state_partial", mode = "function")) {
              turas_run_state_partial(
                trs_state,
                sprintf("TABS_PARTIAL_%s", pq_code),
                sprintf("Missing section in %s: %s", pq_code, section$section),
                problem = section$error
              )
            }
          }
        }
      }
    }

    # Get run result for Run_Status sheet
    run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
      turas_run_state_result(trs_state)
    } else {
      NULL
    }

    if (!is.null(run_result) && exists("turas_write_run_status_sheet", mode = "function")) {
      # Use standard TRS writer
      turas_write_run_status_sheet(wb, run_result)
      log_message(sprintf("✓ Run_Status sheet created (status: %s)", run_result$status), "INFO")
    } else {
      # Fallback: Create basic Run_Status sheet manually
      openxlsx::addWorksheet(wb, "Run_Status")

      status_row <- 1
      openxlsx::writeData(wb, "Run_Status", "TRS Run Status Report", startRow = status_row, startCol = 1)
      openxlsx::addStyle(wb, "Run_Status", styles$question, rows = status_row, cols = 1)
      status_row <- status_row + 2

      status_color <- if (run_status == "PASS") "#28a745" else "#dc3545"
      status_style <- openxlsx::createStyle(fontColour = status_color, textDecoration = "bold", fontSize = 14)
      openxlsx::writeData(wb, "Run_Status", sprintf("Overall Status: %s", run_status), startRow = status_row, startCol = 1)
      openxlsx::addStyle(wb, "Run_Status", status_style, rows = status_row, cols = 1)
      status_row <- status_row + 1

      openxlsx::writeData(wb, "Run_Status", sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")), startRow = status_row, startCol = 1)
      status_row <- status_row + 1

      openxlsx::writeData(wb, "Run_Status", sprintf("Questions processed: %d of %d", length(processed_questions), nrow(crosstab_questions)), startRow = status_row, startCol = 1)

      openxlsx::setColWidths(wb, "Run_Status", cols = 1:3, widths = c(20, 60, 25))
      log_message(sprintf("✓ Run_Status sheet created (status: %s)", run_status), "INFO")
    }
  }, error = function(e) {
    warning(sprintf("Failed to create Run_Status sheet: %s", conditionMessage(e)), call. = FALSE)
  })

  invisible(NULL)
}

#' Write Crosstabs sheet
#'
#' @return Invisible NULL
write_crosstabs_sheet <- function(wb, all_results, banner_info, config_obj, styles) {
  openxlsx::addWorksheet(wb, "Crosstabs")
  current_row <- 1
  total_cols <- 2 + length(banner_info$columns)

  current_row <- write_banner_headers(wb, "Crosstabs", banner_info, styles)

  if (config_obj$enable_significance_testing) {
    current_row <- write_column_letters(wb, "Crosstabs", banner_info, styles, current_row)
  }

  openxlsx::freezePane(wb, "Crosstabs", firstActiveRow = current_row, firstActiveCol = 3)

  # Write questions
  for (q_code in names(all_results)) {
    tryCatch({
      question_results <- all_results[[q_code]]

      if (!is.null(question_results$table) && nrow(question_results$table) > 0) {
        cat(sprintf("Writing question: %s\n", q_code))

        header_text <- paste(question_results$question_code, "-",
                            question_results$question_text)

        if (config_obj$apply_weighting) {
          weight_label <- if (!is.null(config_obj$weight_label) &&
                             length(config_obj$weight_label) > 0) {
            config_obj$weight_label
          } else {
            "Weighted"
          }
          header_text <- paste0(header_text, " [", weight_label, "]")
        }

        openxlsx::writeData(wb, "Crosstabs", header_text,
                           startRow = current_row, startCol = 1, colNames = FALSE)
        openxlsx::addStyle(wb, "Crosstabs", styles$question, rows = current_row, cols = 1)
        current_row <- current_row + 1

        if (!is.null(question_results$base_filter) &&
            !is.na(question_results$base_filter) &&
            nchar(trimws(question_results$base_filter)) > 0) {
          filter_display <- paste("  Filter:", question_results$base_filter)
          openxlsx::writeData(wb, "Crosstabs", filter_display,
                             startRow = current_row, startCol = 1, colNames = FALSE)
          openxlsx::addStyle(wb, "Crosstabs", styles$filter, rows = current_row, cols = 1)
          current_row <- current_row + 1
        }

        cat(sprintf("  Writing base rows for %s\n", q_code))
        current_row <- write_base_rows(wb, "Crosstabs", banner_info,
                                       question_results$bases, styles,
                                       current_row, config_obj)

        cat(sprintf("  Writing table for %s\n", q_code))
        current_row <- write_question_table_fast(wb, "Crosstabs", question_results$table,
                                                 banner_info, banner_info$internal_keys,
                                                 styles, current_row)

        current_row <- current_row + 1
        cat(sprintf("  ✓ Completed %s\n", q_code))
      }
    }, error = function(e) {
      tabs_refuse(
        code = "IO_QUESTION_WRITE_FAILED",
        title = "Failed to Write Question to Excel",
        problem = paste0("An error occurred while writing question '", q_code, "' to Excel."),
        why_it_matters = "All questions must be written to produce complete crosstabs output.",
        how_to_fix = c(
          "Check that the question has valid results",
          "Verify the question type is supported",
          "Review the error details below"
        ),
        details = paste0("Question: ", q_code, "\nError: ", e$message)
      )
    })
  }

  openxlsx::setColWidths(wb, "Crosstabs", cols = 1:2, widths = c(25, 12))
  if (length(banner_info$columns) > 0) {
    openxlsx::setColWidths(wb, "Crosstabs", cols = 3:(2 + length(banner_info$columns)),
                          widths = 10)
  }

  invisible(NULL)
}

# ==============================================================================
# END OF MODULE: crosstabs_execution.R
# ==============================================================================
