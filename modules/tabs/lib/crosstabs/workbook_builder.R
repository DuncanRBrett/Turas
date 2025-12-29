# ==============================================================================
# WORKBOOK_BUILDER.R - TURAS V10.2 (Phase 4 Refactoring)
# ==============================================================================
# Extracted from run_crosstabs.R for better modularity
#
# PURPOSE: Creates and populates the Excel workbook with all sheets
#
# FUNCTIONS:
#   - create_crosstabs_workbook() - Main entry point for workbook creation
#   - build_project_info() - Build project info for summary sheet
#   - get_style_config() - Extract style configuration from config_obj
#   - create_workbook_sheets() - Create all workbook sheets
#   - write_crosstabs_sheet() - Write the main Crosstabs sheet
#   - write_single_question() - Write a single question to the sheet
#   - save_workbook_safe() - Save workbook with error handling
#
# DEPENDENCIES:
#   - openxlsx package
#   - excel_writer.R (for create_excel_styles, write_banner_headers, etc.)
#   - summary_builder.R (for build_index_summary_table, write_index_summary_sheet)
#   - logging_utils.R (for log_message)
#   - 00_guard.R (for tabs_refuse)
#
# ==============================================================================

# ==============================================================================
# STYLE CONFIGURATION
# ==============================================================================

#' Get Style Configuration from Config Object
#'
#' Extracts decimal places and separator settings with safe defaults
#'
#' @param config_obj List, the configuration object
#' @return List with style parameters
#' @export
get_style_config <- function(config_obj) {
  # Safe extraction of decimal separator
  decimal_separator <- if (!is.null(config_obj$decimal_separator) &&
                           length(config_obj$decimal_separator) > 0) {
    config_obj$decimal_separator
  } else {
    "."
  }

  # Get general decimal_places as fallback (defaults to 1 if not specified)
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

  list(
    decimal_separator = decimal_separator,
    decimal_places_percent = decimal_places_percent,
    decimal_places_ratings = decimal_places_ratings,
    decimal_places_index = decimal_places_index,
    decimal_places_numeric = decimal_places_numeric
  )
}


#' Build Project Info for Summary Sheet
#'
#' Creates the project info list used by the summary sheet
#'
#' @param survey_structure List, the survey structure object
#' @param survey_data Data frame, the survey data
#' @param banner_info List, the banner information
#' @param effective_n Numeric, effective sample size
#' @return List with project info
#' @export
build_project_info <- function(survey_structure, survey_data, banner_info, effective_n) {
  project_name <- get_config_value(survey_structure$project, "project_name", "Crosstabs")

  list(
    project_name = project_name,
    total_responses = nrow(survey_data),
    effective_n = effective_n,
    total_banner_cols = length(banner_info$columns),
    num_banner_questions = if (!is.null(banner_info$banner_questions)) {
      nrow(banner_info$banner_questions)
    } else {
      0
    }
  )
}


# ==============================================================================
# TRS STATE LOGGING
# ==============================================================================

#' Log Partial Results to TRS State
#'
#' Logs skipped questions and partial questions to TRS run state
#'
#' @param trs_state TRS state object
#' @param skipped_questions List of skipped questions
#' @param partial_questions List of partial questions
#' @return Invisible NULL
log_partial_to_trs <- function(trs_state, skipped_questions, partial_questions) {
  if (is.null(trs_state)) return(invisible(NULL))

  # Log skipped questions as PARTIAL events
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

  # Log partial questions as PARTIAL events
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

  invisible(NULL)
}


# ==============================================================================
# SHEET CREATION
# ==============================================================================

#' Create Summary Sheet with Error Handling
#'
#' @param wb Workbook object
#' @param project_info List, project information
#' @param all_results List, all question results
#' @param config_obj List, configuration
#' @param styles List, Excel styles
#' @param script_version Character, version string
#' @param total_column Character, total column name
#' @param very_small_base Integer, very small base threshold
#' @return Invisible NULL (side effect: adds sheet to workbook)
create_summary_sheet_safe <- function(wb, project_info, all_results, config_obj,
                                       styles, script_version, total_column,
                                       very_small_base) {
  tryCatch({
    log_message("Creating Summary sheet...", "INFO")
    create_summary_sheet(wb, project_info, all_results, config_obj, styles,
                         script_version, total_column, very_small_base)
    log_message("Summary sheet created", "INFO")
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
      details = paste0("Error: ", e$message, "\nNumber of results: ", length(all_results),
                       "\nResult codes: ", paste(names(all_results), collapse = ", "))
    )
  })

  invisible(NULL)
}


#' Create Index Summary Sheet with Error Handling
#'
#' @param wb Workbook object
#' @param all_results List, all question results
#' @param composite_results List, composite results
#' @param composite_defs Data frame, composite definitions
#' @param banner_info List, banner information
#' @param config_obj List, configuration
#' @param styles List, Excel styles
#' @return Invisible NULL
create_index_summary_safe <- function(wb, all_results, composite_results,
                                       composite_defs, banner_info, config_obj,
                                       styles) {
  # Default to TRUE if composites are defined, otherwise FALSE
  default_create_summary <- !is.null(composite_defs) && nrow(composite_defs) > 0
  create_index_summary <- get_config_value(config_obj, "create_index_summary", default_create_summary)

  if (!create_index_summary) return(invisible(NULL))

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

      log_message("Index_Summary sheet created", "INFO")
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
      details = paste0("Error: ", e$message, "\n\nTraceback:\n",
                       paste(capture.output(traceback()), collapse = "\n"))
    )
  })

  invisible(NULL)
}


#' Create Run Status Sheet
#'
#' Creates the TRS Run_Status sheet with processing status
#'
#' @param wb Workbook object
#' @param trs_state TRS state object (can be NULL)
#' @param run_status Character, "PASS" or "PARTIAL"
#' @param processed_questions Character vector, processed question codes
#' @param total_questions Integer, total number of questions
#' @param styles List, Excel styles
#' @return Invisible NULL
create_run_status_sheet <- function(wb, trs_state, run_status,
                                     processed_questions, total_questions, styles) {
  # Get run result for Run_Status sheet
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

  tryCatch({
    log_message("Creating Run_Status sheet...", "INFO")

    if (!is.null(run_result) && exists("turas_write_run_status_sheet", mode = "function")) {
      # Use standard TRS writer
      turas_write_run_status_sheet(wb, run_result)
      log_message(sprintf("Run_Status sheet created (status: %s)", run_result$status), "INFO")
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

      openxlsx::writeData(wb, "Run_Status", sprintf("Questions processed: %d of %d", length(processed_questions), total_questions), startRow = status_row, startCol = 1)

      openxlsx::setColWidths(wb, "Run_Status", cols = 1:3, widths = c(20, 60, 25))
      log_message(sprintf("Run_Status sheet created (status: %s)", run_status), "INFO")
    }
  }, error = function(e) {
    warning(sprintf("Failed to create Run_Status sheet: %s", conditionMessage(e)), call. = FALSE)
  })

  # Return run_result for use in saving
  run_result
}


# ==============================================================================
# CROSSTABS SHEET
# ==============================================================================

#' Write Single Question to Crosstabs Sheet
#'
#' Writes a single question's results to the Crosstabs sheet
#'
#' @param wb Workbook object
#' @param sheet Character, sheet name
#' @param question_results List, question results
#' @param q_code Character, question code
#' @param banner_info List, banner information
#' @param config_obj List, configuration
#' @param styles List, Excel styles
#' @param current_row Integer, current row position
#' @return Integer, next row position
write_single_question <- function(wb, sheet, question_results, q_code,
                                   banner_info, config_obj, styles, current_row) {
  if (is.null(question_results$table) || nrow(question_results$table) == 0) {
    return(current_row)
  }

  tryCatch({
    # Build header text
    header_text <- paste(question_results$question_code, "-",
                         question_results$question_text)

    # Safe weighting check
    apply_weighting <- !is.null(config_obj$apply_weighting) &&
                       length(config_obj$apply_weighting) > 0 &&
                       config_obj$apply_weighting

    if (apply_weighting) {
      weight_label <- if (!is.null(config_obj$weight_label) &&
                          length(config_obj$weight_label) > 0) {
        config_obj$weight_label
      } else {
        "Weighted"
      }
      header_text <- paste0(header_text, " [", weight_label, "]")
    }

    # Write question header
    openxlsx::writeData(wb, sheet, header_text,
                        startRow = current_row, startCol = 1, colNames = FALSE)
    openxlsx::addStyle(wb, sheet, styles$question, rows = current_row, cols = 1)
    current_row <- current_row + 1

    # Write filter if present
    if (!is.null(question_results$base_filter) &&
        !is.na(question_results$base_filter) &&
        nchar(trimws(question_results$base_filter)) > 0) {
      filter_display <- paste("  Filter:", question_results$base_filter)
      openxlsx::writeData(wb, sheet, filter_display,
                          startRow = current_row, startCol = 1, colNames = FALSE)
      openxlsx::addStyle(wb, sheet, styles$filter, rows = current_row, cols = 1)
      current_row <- current_row + 1
    }

    # Write base rows
    current_row <- write_base_rows(wb, sheet, banner_info,
                                   question_results$bases, styles,
                                   current_row, config_obj)

    # Write question table
    current_row <- write_question_table_fast(wb, sheet, question_results$table,
                                              banner_info, banner_info$internal_keys,
                                              styles, current_row)

    # Add spacing
    current_row <- current_row + 1

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
      details = paste0("Question: ", q_code,
                       "\nError: ", e$message,
                       "\nQuestion type: ", question_results$question_type,
                       "\nHas table: ", !is.null(question_results$table),
                       "\nTable rows: ", if(!is.null(question_results$table)) nrow(question_results$table) else "NULL",
                       "\nHas bases: ", !is.null(question_results$bases))
    )
  })

  return(current_row)
}


#' Write Crosstabs Sheet
#'
#' Creates and populates the main Crosstabs sheet with all questions
#'
#' @param wb Workbook object
#' @param all_results List, all question results
#' @param banner_info List, banner information
#' @param config_obj List, configuration
#' @param styles List, Excel styles
#' @return Invisible NULL
write_crosstabs_sheet <- function(wb, all_results, banner_info, config_obj, styles) {
  openxlsx::addWorksheet(wb, "Crosstabs")

  # Write banner headers
  current_row <- write_banner_headers(wb, "Crosstabs", banner_info, styles)

  # Write column letters for significance testing
  if (config_obj$enable_significance_testing) {
    current_row <- write_column_letters(wb, "Crosstabs", banner_info, styles, current_row)
  }

  # Freeze panes
  openxlsx::freezePane(wb, "Crosstabs", firstActiveRow = current_row, firstActiveCol = 3)

  # Write all questions
  for (q_code in names(all_results)) {
    question_results <- all_results[[q_code]]
    current_row <- write_single_question(wb, "Crosstabs", question_results, q_code,
                                          banner_info, config_obj, styles, current_row)
  }

  # Set column widths
  openxlsx::setColWidths(wb, "Crosstabs", cols = 1:2, widths = c(25, 12))
  if (length(banner_info$columns) > 0) {
    openxlsx::setColWidths(wb, "Crosstabs", cols = 3:(2 + length(banner_info$columns)),
                           widths = 10)
  }

  invisible(NULL)
}


# ==============================================================================
# WORKBOOK SAVE
# ==============================================================================

#' Save Workbook Safely
#'
#' Saves the workbook with TRS atomic save if available, otherwise standard save
#'
#' @param wb Workbook object
#' @param output_path Character, output file path
#' @param run_result TRS run result (can be NULL)
#' @return Invisible NULL
save_workbook_safe <- function(wb, output_path, run_result = NULL) {
  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    log_message("Created output directory", "INFO")
  }

  # Use TRS atomic save if available
  if (exists("turas_save_workbook_atomic", mode = "function")) {
    save_result <- turas_save_workbook_atomic(wb, output_path, run_result = run_result, module = "TABS")
    if (!save_result$success) {
      tabs_refuse(
        code = "IO_EXCEL_SAVE_FAILED",
        title = "Failed to Save Excel File",
        problem = "Could not save the Excel workbook to disk.",
        why_it_matters = "The analysis results cannot be delivered without saving the file.",
        how_to_fix = c(
          "Check that the output directory is writable",
          "Ensure the file is not open in another application",
          "Verify there is sufficient disk space"
        ),
        details = paste0("Output path: ", output_path, "\nError: ", save_result$error)
      )
    } else {
      log_message(sprintf("Saved: %s", output_path), "INFO")
    }
  } else {
    tryCatch({
      openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
      log_message(sprintf("Saved: %s", output_path), "INFO")
    }, error = function(e) {
      tabs_refuse(
        code = "IO_EXCEL_SAVE_FAILED",
        title = "Failed to Save Excel File",
        problem = "Could not save the Excel workbook to disk.",
        why_it_matters = "The analysis results cannot be delivered without saving the file.",
        how_to_fix = c(
          "Check that the output directory is writable",
          "Ensure the file is not open in another application",
          "Verify there is sufficient disk space"
        ),
        details = paste0("Output path: ", output_path, "\nError: ", conditionMessage(e))
      )
    })
  }

  invisible(NULL)
}


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Create Crosstabs Workbook
#'
#' Main entry point for creating the complete Excel workbook.
#' This function orchestrates the creation of all sheets.
#'
#' @param all_results List, all question results
#' @param composite_results List, composite results (can be empty)
#' @param composite_defs Data frame, composite definitions (can be NULL)
#' @param survey_structure List, survey structure
#' @param survey_data Data frame, survey data
#' @param banner_info List, banner information
#' @param config_obj List, configuration
#' @param error_log Data frame, error log
#' @param trs_state TRS state object (can be NULL)
#' @param run_status Character, "PASS" or "PARTIAL"
#' @param skipped_questions List, skipped questions
#' @param partial_questions List, partial questions
#' @param processed_questions Character vector, processed question codes
#' @param crosstab_questions Data frame, all crosstab questions
#' @param effective_n Numeric, effective sample size
#' @param master_weights Numeric vector, weights
#' @param output_path Character, output file path
#' @param script_version Character, version string
#' @param total_column Character, total column name (default: "Total")
#' @param very_small_base Integer, very small base threshold (default: 10)
#' @return List with output_path and run_result
#' @export
create_crosstabs_workbook <- function(all_results,
                                       composite_results,
                                       composite_defs,
                                       survey_structure,
                                       survey_data,
                                       banner_info,
                                       config_obj,
                                       error_log,
                                       trs_state,
                                       run_status,
                                       skipped_questions,
                                       partial_questions,
                                       processed_questions,
                                       crosstab_questions,
                                       effective_n,
                                       master_weights,
                                       output_path,
                                       script_version,
                                       total_column = "Total",
                                       very_small_base = 10) {

  log_message("Creating Excel output...", "INFO")

  # Create workbook

  wb <- openxlsx::createWorkbook()

  # Get style configuration
  style_config <- get_style_config(config_obj)
  styles <- create_excel_styles(
    style_config$decimal_separator,
    style_config$decimal_places_percent,
    style_config$decimal_places_ratings,
    style_config$decimal_places_index,
    style_config$decimal_places_numeric
  )

  # Build project info
  project_info <- build_project_info(survey_structure, survey_data, banner_info, effective_n)

  # Create Summary sheet
  create_summary_sheet_safe(wb, project_info, all_results, config_obj, styles,
                             script_version, total_column, very_small_base)

  # Create Index Summary sheet
  create_index_summary_safe(wb, all_results, composite_results, composite_defs,
                             banner_info, config_obj, styles)

  # Write error log sheet
  write_error_log_sheet(wb, error_log, styles)

  # Log partial results to TRS state
  log_partial_to_trs(trs_state, skipped_questions, partial_questions)

  # Create Run Status sheet
  run_result <- create_run_status_sheet(wb, trs_state, run_status,
                                         processed_questions, nrow(crosstab_questions), styles)

  # Create Sample Composition sheet if enabled
  if (config_obj$create_sample_composition) {
    log_message("Creating sample composition sheet...", "INFO")
    create_sample_composition_sheet(
      wb, survey_data, banner_info, master_weights, config_obj, styles, survey_structure
    )
  }

  # Write main Crosstabs sheet
  write_crosstabs_sheet(wb, all_results, banner_info, config_obj, styles)

  # Save workbook
  save_workbook_safe(wb, output_path, run_result)

  # Return result info
  list(
    output_path = output_path,
    run_result = run_result,
    project_name = project_info$project_name
  )
}
