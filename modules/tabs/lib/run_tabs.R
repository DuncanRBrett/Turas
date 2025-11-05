# ==============================================================================
# MODULE 15: RUN_TABS.R
# ==============================================================================
#
# PURPOSE:
#   Main orchestrator for crosstabulation system
#   Loads configuration, processes questions, generates Excel output
#
# FUNCTIONS:
#   - run_crosstabs() - Main entry point
#   - process_all_questions() - Process question loop
#   - apply_base_filter() - Apply BaseFilter expressions
#
# DEPENDENCIES:
#   - All tabs modules (1-14)
#   - Phase 1-6 modules (validation, weighting, ranking)
#
# VERSION: 1.0.0
# DATE: 2025-10-25
# ==============================================================================

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Crosstabulation
#'
#' Main entry point for crosstabulation system.
#' Loads configuration, processes all questions, generates Excel output.
#'
#' @param config_file Character, path to crosstab configuration Excel file
#' @param project_root Character, optional project root directory
#' @param verbose Logical, enable verbose logging
#' @return List with results and metadata
#' @export
run_crosstabs <- function(config_file, project_root = NULL, verbose = TRUE) {
  
  start_time <- Sys.time()
  
  # ===========================================================================
  # STEP 1: LOAD CONFIGURATION
  # ===========================================================================
  
  log_message("=" %R% 70, level = "INFO", verbose = verbose)
  log_message("TURAS CROSSTABULATION SYSTEM", level = "INFO", verbose = verbose)
  log_message("=" %R% 70, level = "INFO", verbose = verbose)
  
  log_message("\nStep 1: Loading configuration...", level = "INFO", verbose = verbose)
  
  config <- load_crosstab_configuration(config_file, project_root)
  config$verbose <- verbose
  
  log_message(sprintf("  [OK] Configuration loaded from: %s", config_file),
             level = "INFO", verbose = verbose)
  
  # ===========================================================================
  # STEP 2: LOAD SURVEY DATA
  # ===========================================================================
  
  log_message("\nStep 2: Loading survey data...", level = "INFO", verbose = verbose)
  
  # Load data using Phase 2 function
  survey_data <- load_survey_data(config$paths$survey_data)
  
  log_message(sprintf("  [OK] Data loaded: %d rows, %d columns",
                     nrow(survey_data), ncol(survey_data)),
             level = "INFO", verbose = verbose)
  
  # ===========================================================================
  # STEP 3: LOAD SURVEY STRUCTURE
  # ===========================================================================
  
  log_message("\nStep 3: Loading survey structure...", level = "INFO", verbose = verbose)
  
  # Load structure using Phase 2 function
  survey_structure <- load_survey_structure(config$paths$survey_structure)
  
  log_message(sprintf("  [OK] Structure loaded: %d questions, %d options",
                     nrow(survey_structure$questions),
                     nrow(survey_structure$options)),
             level = "INFO", verbose = verbose)
  
  # ===========================================================================
  # STEP 4: LOAD AND APPLY WEIGHTING
  # ===========================================================================
  
  log_message("\nStep 4: Applying weighting...", level = "INFO", verbose = verbose)
  
  # Load weights using Phase 3 function
  if (!is.null(config$paths$weights) && config$paths$weights != "") {
    weights_data <- load_weights_file(config$paths$weights)
    master_weights <- apply_weighting(survey_data, weights_data)
    is_weighted <- TRUE
    log_message("  [OK] Weighting applied", level = "INFO", verbose = verbose)
  } else {
    master_weights <- rep(1, nrow(survey_data))
    is_weighted <- FALSE
    log_message("  [OK] No weighting (unweighted analysis)", level = "INFO", verbose = verbose)
  }
  
  # ===========================================================================
  # STEP 5: CREATE BANNER STRUCTURE
  # ===========================================================================
  
  log_message("\nStep 5: Creating banner structure...", level = "INFO", verbose = verbose)
  
  banner_info <- create_banner_structure(
    config$selection$all,
    survey_structure
  )
  
  log_message(sprintf("  [OK] Banner created: %d columns",
                     length(banner_info$internal_keys)),
             level = "INFO", verbose = verbose)
  
  # ===========================================================================
  # STEP 6: PROCESS ALL QUESTIONS
  # ===========================================================================
  
  log_message("\nStep 6: Processing questions...", level = "INFO", verbose = verbose)
  
  all_results <- process_all_questions(
    survey_data,
    survey_structure,
    config$selection$stub,
    banner_info,
    master_weights,
    config,
    is_weighted
  )
  
  log_message(sprintf("  [OK] Processed %d questions", length(all_results)),
             level = "INFO", verbose = verbose)
  
  # ===========================================================================
  # STEP 7: GENERATE EXCEL OUTPUT
  # ===========================================================================
  
  log_message("\nStep 7: Generating Excel output...", level = "INFO", verbose = verbose)
  
  # Determine output file name
  output_file <- config$paths$output
  if (is.null(output_file) || output_file == "") {
    output_file <- file.path(
      dirname(config_file),
      paste0("Crosstabs_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
    )
  }
  
  # Write Excel file
  write_crosstab_workbook(
    output_file,
    all_results,
    banner_info,
    config
  )
  
  log_message(sprintf("  [OK] Excel file created: %s", output_file),
             level = "INFO", verbose = verbose)
  
  # ===========================================================================
  # STEP 8: SUMMARY
  # ===========================================================================
  
  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))
  
  log_message("\n" %R% "=" %R% 70, level = "INFO", verbose = verbose)
  log_message("CROSSTABULATION COMPLETE", level = "INFO", verbose = verbose)
  log_message("=" %R% 70, level = "INFO", verbose = verbose)
  log_message(sprintf("Questions processed: %d", length(all_results)),
             level = "INFO", verbose = verbose)
  log_message(sprintf("Output file: %s", output_file),
             level = "INFO", verbose = verbose)
  log_message(sprintf("Time elapsed: %s", format_seconds(elapsed)),
             level = "INFO", verbose = verbose)
  log_message("=" %R% 70 %R% "\n", level = "INFO", verbose = verbose)
  
  # Return results
  invisible(list(
    results = all_results,
    banner_info = banner_info,
    config = config,
    output_file = output_file,
    elapsed_time = elapsed
  ))
}

# ==============================================================================
# PROCESS ALL QUESTIONS
# ==============================================================================

#' Process All Questions
#'
#' Main loop that processes each question in the stub.
#'
#' @param survey_data Data frame, survey data
#' @param survey_structure List, survey structure
#' @param stub_questions Data frame, questions to process
#' @param banner_info List, banner structure
#' @param master_weights Numeric vector, weights
#' @param config List, configuration
#' @param is_weighted Logical, weighting flag
#' @return List of question results
#' @export
process_all_questions <- function(survey_data, survey_structure, stub_questions,
                                  banner_info, master_weights, config,
                                  is_weighted) {
  
  all_results <- list()
  total_questions <- nrow(stub_questions)
  start_time <- Sys.time()
  
  for (q_idx in seq_len(total_questions)) {
    
    # Progress logging
    log_progress(q_idx, total_questions, stub_questions$QuestionCode[q_idx], start_time)
    
    current_question_code <- stub_questions$QuestionCode[q_idx]
    
    # Get question info
    question_info <- survey_structure$questions[
      survey_structure$questions$QuestionCode == current_question_code,
    ][1, ]
    
    if (nrow(question_info) == 0) {
      warning(sprintf("Question not found in structure: %s", current_question_code))
      next
    }
    
    # Get question options
    if (question_info$Variable_Type == "Multi_Mention") {
      pattern <- paste0("^", current_question_code, "_")
      question_options <- survey_structure$options[
        grepl(pattern, survey_structure$options$QuestionCode),
      ]
    } else {
      question_options <- survey_structure$options[
        survey_structure$options$QuestionCode == current_question_code,
      ]
    }
    
    # Apply base filter
    base_filter <- stub_questions$BaseFilter[q_idx]
    if (!is.na(base_filter) && base_filter != "") {
      filtered_data <- safe_execute(
        apply_base_filter(survey_data, base_filter),
        default = NULL,
        error_msg = paste("Filter failed:", current_question_code)
      )
      
      if (is.null(filtered_data)) {
        warning(sprintf("Skipping %s: filter failed", current_question_code))
        next
      }
      
      # Get weights for filtered data
      if (".original_row" %in% names(filtered_data)) {
        question_weights <- master_weights[filtered_data$.original_row]
      } else {
        question_weights <- master_weights
      }
    } else {
      filtered_data <- survey_data
      question_weights <- master_weights
    }
    
    # Create banner row indices
    banner_result <- create_banner_row_indices(filtered_data, banner_info)
    banner_row_indices <- banner_result$row_indices
    
    # Calculate banner bases
    banner_bases <- calculate_banner_base_sizes(
      banner_row_indices,
      question_weights,
      is_weighted
    )
    
    # Dispatch to appropriate processor
    question_table <- dispatch_question(
      filtered_data,
      question_info,
      question_options,
      banner_info,
      banner_row_indices,
      question_weights,
      banner_bases,
      config,
      is_weighted,
      stub_questions[q_idx, ]
    )
    
    # Store result
    if (!is.null(question_table) && nrow(question_table) > 0) {
      all_results[[length(all_results) + 1]] <- list(
        question_code = current_question_code,
        question_text = question_info$QuestionText,
        question_type = question_info$Variable_Type,
        base_filter = base_filter,
        table = question_table,
        bases = banner_bases
      )
    }
  }
  
  return(all_results)
}

# ==============================================================================
# APPLY BASE FILTER
# ==============================================================================

#' Apply Base Filter
#'
#' Applies a base filter expression to survey data.
#' Preserves original row indices for weight mapping.
#'
#' @param data Data frame, survey data
#' @param filter_expr Character, filter expression
#' @return Data frame with filtered rows and .original_row column
#' @export
apply_base_filter <- function(data, filter_expr) {
  
  if (is.na(filter_expr) || filter_expr == "") {
    return(data)
  }
  
  # Add original row index
  data$.original_row <- seq_len(nrow(data))
  
  # Evaluate filter expression
  filter_result <- tryCatch({
    eval(parse(text = filter_expr), envir = data, enclos = parent.frame())
  }, error = function(e) {
    warning(sprintf("Filter expression failed: %s\nError: %s", filter_expr, e$message))
    return(NULL)
  })
  
  if (is.null(filter_result)) {
    return(NULL)
  }
  
  # Apply filter
  filtered_data <- data[filter_result & !is.na(filter_result), ]
  
  return(filtered_data)
}

# ==============================================================================
# MODULE INFO
# ==============================================================================

#' Get Run Tabs Module Information
#'
#' Returns metadata about the run_tabs module.
#'
#' @return List with module information
#' @export
get_run_tabs_info <- function() {
  list(
    module = "run_tabs",
    version = "1.0.0",
    date = "2025-10-25",
    description = "Main orchestrator for crosstabulation system",
    functions = c(
      "run_crosstabs",
      "process_all_questions",
      "apply_base_filter",
      "get_run_tabs_info"
    ),
    dependencies = c(
      "All tabs modules",
      "Phase 1-6 modules"
    )
  )
}

# ==============================================================================
# MODULE LOAD MESSAGE
# ==============================================================================

message("[OK] Turas>Tabs run_tabs module loaded")

# ==============================================================================
# END OF MODULE 15: RUN_TABS.R
# ==============================================================================
