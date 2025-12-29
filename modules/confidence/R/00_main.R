# ==============================================================================
# CONFIDENCE ANALYSIS MAIN ORCHESTRATION - TURAS V10.1
# ==============================================================================
# Main script for running complete confidence analysis
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Refactoring release (2025-12-29)
#          - Converted to orchestrator pattern
#          - Extracted question processing to question_processor.R
#          - Extracted CI dispatch to ci_dispatcher.R
#          - Reduced from 1,396 lines to ~600 lines (57% reduction)
#
# Turas v10.0 - Initial release (2025-11-13)
#          - Complete workflow orchestration
#          - Progress reporting
#          - Error handling and validation
#          - Support for 200 question limit
#
# WORKFLOW:
# 1. Load configuration (with 200 question limit check)
# 2. Load survey data
# 3. Calculate study-level statistics (DEFF, effective n)
# 4. Process each question (proportions or means)
# 5. Collect warnings
# 6. Generate Excel output
#
# USAGE:
# source("R/00_main.R")
# run_confidence_analysis("path/to/confidence_config.xlsx")
#
# DEPENDENCIES:
# - All other module R scripts
# - readxl, openxlsx
# ==============================================================================

MAIN_VERSION <- "10.1"

# ==============================================================================
# TRS GUARD LAYER (Must be first)
# ==============================================================================

# Source TRS guard layer for refusal handling
get_script_dir_for_guard <- function() {
  if (exists("script_dir_override")) return(script_dir_override)
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(sub("^--file=", "", file_arg)))
  return(getwd())
}

guard_path <- file.path(get_script_dir_for_guard(), "00_guard.R")
if (!file.exists(guard_path)) {
  guard_path <- file.path(get_script_dir_for_guard(), "R", "00_guard.R")
}
if (file.exists(guard_path)) {
  source(guard_path)
}

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

# Source TRS run state management
source_trs_infrastructure <- function() {
  base_dir <- get_script_dir_for_guard()

  # Try multiple paths to find shared/lib
  possible_paths <- c(
    file.path(base_dir, "..", "..", "shared", "lib"),
    file.path(base_dir, "..", "shared", "lib"),
    file.path(getwd(), "modules", "shared", "lib"),
    file.path(getwd(), "..", "shared", "lib")
  )

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R")

  for (shared_lib in possible_paths) {
    if (dir.exists(shared_lib)) {
      for (f in trs_files) {
        fpath <- file.path(shared_lib, f)
        if (file.exists(fpath)) {
          source(fpath)
        }
      }
      break
    }
  }
}

tryCatch({
  source_trs_infrastructure()
}, error = function(e) {
  message(sprintf("[TRS INFO] CONF_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Get script directory for sourcing
get_script_dir <- function() {
  if (exists("script_dir_override")) {
    return(script_dir_override)
  }

  # Try to get from command line args
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg)
    return(dirname(script_path))
  }

  # Default to current directory
  return(getwd())
}

# Source all module files
source_module_files <- function(base_dir = NULL) {

  if (is.null(base_dir)) {
    base_dir <- get_script_dir()
  }

  # List of files to source in order (including new refactored modules)
  module_files <- c(
    "utils.R",
    "01_load_config.R",
    "02_load_data.R",
    "03_study_level.R",
    "04_proportions.R",
    "05_means.R",
    "question_processor.R",
    "ci_dispatcher.R",
    "07_output.R"
  )

  for (file in module_files) {
    file_path <- file.path(base_dir, file)

    if (!file.exists(file_path)) {
      # Try R subdirectory
      file_path <- file.path(base_dir, "R", file)
    }

    if (!file.exists(file_path)) {
      confidence_refuse(
        code = "IO_MODULE_FILE_MISSING",
        title = "Required Module File Not Found",
        problem = sprintf("Required module file not found: %s", file),
        why_it_matters = "The confidence module requires all component files to function properly.",
        how_to_fix = c(
          sprintf("Verify that %s exists in the module directory", file),
          "Ensure the module installation is complete"
        )
      )
    }

    source(file_path)
  }
}

# Source all modules
tryCatch({
  source_module_files()
}, error = function(e) {
  confidence_refuse(
    code = "IO_MODULE_LOAD_FAILED",
    title = "Failed to Load Module Files",
    problem = sprintf("Failed to load module files: %s", conditionMessage(e)),
    why_it_matters = "All module component files must be loaded before analysis can proceed.",
    how_to_fix = c(
      "Ensure all R files are in the correct location",
      "Check that files are not corrupted",
      "Verify file permissions allow reading"
    )
  )
})


# ==============================================================================
# MAIN ANALYSIS FUNCTION
# ==============================================================================

#' Run complete confidence analysis
#'
#' Main function to orchestrate entire confidence analysis workflow.
#' Reads configuration, loads data, calculates confidence intervals,
#' and generates Excel output.
#'
#' @param config_path Character. Path to confidence_config.xlsx
#' @param verbose Logical. Print progress messages (default TRUE)
#' @param stop_on_warnings Logical. Stop if warnings detected (default FALSE)
#'
#' @return List with analysis results (invisible)
#'
#' @export
run_confidence_analysis <- function(config_path,
                                    verbose = TRUE,
                                    stop_on_warnings = FALSE) {

  # TRS REFUSAL HANDLER WRAPPER
  if (exists("confidence_with_refusal_handler", mode = "function")) {
    confidence_with_refusal_handler(
      run_confidence_analysis_impl(config_path, verbose, stop_on_warnings)
    )
  } else {
    run_confidence_analysis_impl(config_path, verbose, stop_on_warnings)
  }
}


#' Internal Implementation of Confidence Analysis
#' @keywords internal
run_confidence_analysis_impl <- function(config_path,
                                         verbose = TRUE,
                                         stop_on_warnings = FALSE) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION
  # ==========================================================================
  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("CONFIDENCE")
  } else {
    NULL
  }

  # Print TRS start banner
  if (exists("turas_print_start_banner", mode = "function")) {
    turas_print_start_banner("CONFIDENCE", MAIN_VERSION)
  } else if (verbose) {
    cat("\n")
    cat("================================================================================\n")
    cat("TURAS CONFIDENCE ANALYSIS MODULE\n")
    cat(sprintf("Version: %s\n", MAIN_VERSION))
    cat(sprintf("Started: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
    cat("================================================================================\n\n")
  }

  # Start timer
  start_time <- Sys.time()
  warnings_list <- character()

  # ==========================================================================
  # STEP 1: LOAD CONFIGURATION
  # ==========================================================================
  if (verbose) cat("STEP 1/6: Loading configuration...\n")

  config <- load_config_step(config_path)

  if (verbose) {
    cat(sprintf("  + Configuration loaded successfully\n"))
    cat(sprintf("  + Questions to analyze: %d (limit: 200)\n",
                nrow(config$question_analysis)))
    cat(sprintf("  + Confidence level: %.2f\n", as.numeric(config$study_settings$Confidence_Level)))
    cat(sprintf("  + Decimal separator: %s\n", config$study_settings$Decimal_Separator))
  }

  # ==========================================================================
  # STEP 2: LOAD SURVEY DATA
  # ==========================================================================
  if (verbose) cat("\nSTEP 2/6: Loading survey data...\n")

  data_result <- load_data_step(config, verbose)
  survey_data <- data_result$survey_data
  weight_var <- data_result$weight_var

  if (verbose) {
    cat(sprintf("  + Data loaded: %d respondents\n", nrow(survey_data)))
    if (!is.null(weight_var)) {
      cat(sprintf("  + Weighted analysis using: %s\n", weight_var))
    } else {
      cat("  + Unweighted analysis\n")
    }
  }

  # ==========================================================================
  # STEP 3: STUDY-LEVEL STATISTICS
  # ==========================================================================
  if (verbose) cat("\nSTEP 3/6: Calculating study-level statistics...\n")

  study_result <- calculate_study_stats_step(survey_data, weight_var, config, verbose)
  study_stats <- study_result$study_stats
  warnings_list <- c(warnings_list, study_result$warnings)

  # ==========================================================================
  # STEP 4: PROCESS QUESTIONS
  # ==========================================================================
  if (verbose) cat("\nSTEP 4/6: Processing questions...\n")

  question_result <- process_all_questions(config, survey_data, weight_var, verbose)
  proportion_results <- question_result$proportion_results
  mean_results <- question_result$mean_results
  nps_results <- question_result$nps_results
  warnings_list <- c(warnings_list, question_result$warnings)

  if (verbose) {
    cat(sprintf("  + Processed: %d proportions, %d means, %d NPS\n",
                length(proportion_results), length(mean_results), length(nps_results)))
  }

  # ==========================================================================
  # STEP 5: COLLECT WARNINGS
  # ==========================================================================
  if (verbose) cat("\nSTEP 5/6: Quality checks...\n")

  handle_warnings_step(warnings_list, verbose, stop_on_warnings)

  # ==========================================================================
  # STEP 6: GENERATE OUTPUT
  # ==========================================================================
  if (verbose) cat("\nSTEP 6/6: Generating Excel output...\n")

  run_result <- log_trs_events(trs_state, warnings_list)

  generate_output_step(
    config, study_stats, proportion_results, mean_results, nps_results,
    warnings_list, run_result
  )

  # ==========================================================================
  # SUMMARY
  # ==========================================================================
  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))
  n_questions <- nrow(config$question_analysis)

  print_completion_summary(
    verbose, end_time, elapsed, n_questions,
    proportion_results, mean_results, nps_results,
    warnings_list, config$file_paths$Output_File, run_result
  )

  # Return results
  invisible(list(
    study_stats = study_stats,
    proportion_results = proportion_results,
    mean_results = mean_results,
    nps_results = nps_results,
    warnings = warnings_list,
    config = config,
    elapsed_seconds = elapsed,
    run_result = run_result
  ))
}


# ==============================================================================
# ORCHESTRATION STEP FUNCTIONS
# ==============================================================================

#' Load configuration step
#' @keywords internal
load_config_step <- function(config_path) {
  tryCatch({
    load_confidence_config(config_path)
  }, error = function(e) {
    confidence_refuse(
      code = "CFG_LOAD_FAILED",
      title = "Failed to Load Configuration",
      problem = sprintf("Failed to load configuration: %s", conditionMessage(e)),
      why_it_matters = "Valid configuration is required to specify analysis parameters.",
      how_to_fix = c(
        "Verify the config file path is correct",
        "Ensure the config file is a valid Excel file (.xlsx)",
        "Check that the file is not open in Excel",
        "Validate all required sheets and columns are present"
      )
    )
  })
}


#' Load data step
#' @keywords internal
load_data_step <- function(config, verbose) {
  required_questions <- config$question_analysis$Question_ID
  required_questions <- required_questions[!is.na(required_questions)]

  weight_var <- config$file_paths$Weight_Variable
  if (is.na(weight_var) || weight_var == "") {
    weight_var <- NULL
  }

  survey_data <- tryCatch({
    load_survey_data(
      data_file_path = config$file_paths$Data_File,
      required_questions = required_questions,
      weight_variable = weight_var,
      verbose = verbose
    )
  }, error = function(e) {
    confidence_refuse(
      code = "DATA_LOAD_FAILED",
      title = "Failed to Load Survey Data",
      problem = sprintf("Failed to load survey data: %s", conditionMessage(e)),
      why_it_matters = "Survey data is required for confidence interval calculations.",
      how_to_fix = c(
        "Verify the data file path in the config is correct",
        "Ensure the data file exists and is accessible",
        "Check that the file format is supported (CSV, XLSX)",
        "Verify the file contains the required question columns"
      )
    )
  })

  # Check weight variable exists if specified
  if (!is.null(weight_var) && weight_var != "" && !weight_var %in% names(survey_data)) {
    confidence_refuse(
      code = "DATA_WEIGHT_NOT_FOUND",
      title = "Configured Weight Variable Not Found",
      problem = sprintf("Weight variable '%s' specified in config but not present in data file", weight_var),
      why_it_matters = "The specified weight variable must exist in the data for weighted analysis.",
      how_to_fix = sprintf("Ensure column '%s' exists in the data file, or remove weight_variable from config", weight_var)
    )
  }

  list(survey_data = survey_data, weight_var = weight_var)
}


#' Calculate study-level statistics step
#' @keywords internal
calculate_study_stats_step <- function(survey_data, weight_var, config, verbose) {
  study_stats <- NULL
  warnings_list <- character()

  if (config$study_settings$Calculate_Effective_N != "Y") {
    if (verbose) cat("  - Study-level stats skipped (disabled in config)\n")
    return(list(study_stats = NULL, warnings = character()))
  }

  study_stats <- tryCatch({
    calculate_study_level_stats(
      survey_data = survey_data,
      weight_variable = weight_var,
      group_variable = NULL
    )
  }, error = function(e) {
    warning(sprintf("Failed to calculate study-level stats: %s", conditionMessage(e)))
    warnings_list <<- c(warnings_list, sprintf("Study-level stats failed: %s", conditionMessage(e)))
    NULL
  })

  if (!is.null(study_stats) && nrow(study_stats) > 0 && verbose) {
    cat(sprintf("  + Actual n: %d\n", study_stats$Actual_n[1]))
    cat(sprintf("  + Effective n: %d\n", study_stats$Effective_n[1]))
    cat(sprintf("  + DEFF: %.2f\n", study_stats$DEFF[1]))

    if (study_stats$Warning[1] != "") {
      warnings_list <- c(warnings_list, sprintf("Study-level: %s", study_stats$Warning[1]))
    }
  }

  # Add representativeness diagnostics
  if (!is.null(study_stats)) {
    study_stats <- add_representativeness_diagnostics(
      study_stats, survey_data, weight_var, config, verbose, warnings_list
    )
    warnings_list <- attr(study_stats, "additional_warnings") %||% warnings_list
  }

  list(study_stats = study_stats, warnings = warnings_list)
}


#' Add representativeness diagnostics to study stats
#' @keywords internal
add_representativeness_diagnostics <- function(study_stats, survey_data, weight_var,
                                                config, verbose, warnings_list) {
  weights <- if (!is.null(weight_var) && weight_var %in% names(survey_data)) {
    survey_data[[weight_var]]
  } else {
    NULL
  }

  # Weight concentration diagnostics
  weight_conc <- tryCatch({
    compute_weight_concentration(weights)
  }, error = function(e) {
    if (verbose) cat(sprintf("  ! Weight concentration calculation failed: %s\n", conditionMessage(e)))
    NULL
  })

  # Margin comparison
  margin_comp <- tryCatch({
    compute_margin_comparison(
      data = survey_data,
      weights = weights,
      target_margins = config$population_margins
    )
  }, error = function(e) {
    if (verbose) cat(sprintf("  ! Margin comparison failed: %s\n", conditionMessage(e)))
    NULL
  })

  attr(study_stats, "weight_concentration") <- weight_conc
  attr(study_stats, "margin_comparison") <- margin_comp

  if (!is.null(weight_conc) && verbose) {
    cat(sprintf("  + Weight concentration: Top 5%% hold %.1f%% of weight (%s)\n",
                weight_conc$Top_5pct_Share, weight_conc$Concentration_Flag))
  }

  if (!is.null(margin_comp) && verbose) {
    n_red <- sum(margin_comp$Flag == "RED", na.rm = TRUE)
    n_amber <- sum(margin_comp$Flag == "AMBER", na.rm = TRUE)
    n_green <- sum(margin_comp$Flag == "GREEN", na.rm = TRUE)
    cat(sprintf("  + Margin comparison: %d targets (%d GREEN, %d AMBER, %d RED)\n",
                nrow(margin_comp), n_green, n_amber, n_red))
    if (n_red > 0) {
      warnings_list <- c(warnings_list, sprintf(
        "Representativeness: %d margin target(s) off by >5pp (RED flag)", n_red
      ))
    }
  }

  attr(study_stats, "additional_warnings") <- warnings_list
  study_stats
}


#' Handle warnings step
#' @keywords internal
handle_warnings_step <- function(warnings_list, verbose, stop_on_warnings) {
  if (length(warnings_list) > 0) {
    if (verbose) cat(sprintf("  ! %d warnings detected\n", length(warnings_list)))

    if (stop_on_warnings) {
      cat("\nWARNINGS:\n")
      for (i in seq_along(warnings_list)) {
        cat(sprintf("  %d. %s\n", i, warnings_list[i]))
      }
      confidence_refuse(
        code = "DATA_QUALITY_WARNINGS",
        title = "Analysis Stopped Due to Warnings",
        problem = sprintf("Analysis encountered %d warning(s) and stop_on_warnings is enabled",
                         length(warnings_list)),
        why_it_matters = "Data quality warnings may indicate issues that could affect result reliability.",
        how_to_fix = c(
          "Review the warnings listed above",
          "Address data quality issues in the source data",
          "Or run with stop_on_warnings = FALSE to proceed despite warnings"
        ),
        details = warnings_list
      )
    }
  } else {
    if (verbose) cat("  + No warnings detected\n")
  }
}


#' Log TRS events for warnings
#' @keywords internal
log_trs_events <- function(trs_state, warnings_list) {
  if (!is.null(trs_state) && length(warnings_list) > 0) {
    for (warn in warnings_list) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(trs_state, "CONF_WARNING", "Analysis warning", problem = warn)
      }
    }
  }

  if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }
}


#' Generate output step
#' @keywords internal
generate_output_step <- function(config, study_stats, proportion_results,
                                  mean_results, nps_results, warnings_list, run_result) {
  output_path <- config$file_paths$Output_File

  tryCatch({
    write_confidence_output(
      output_path = output_path,
      study_level_stats = study_stats,
      proportion_results = proportion_results,
      mean_results = mean_results,
      nps_results = nps_results,
      config = list(
        confidence_level = as.numeric(config$study_settings$Confidence_Level),
        bootstrap_iterations = as.integer(config$study_settings$Bootstrap_Iterations),
        multiple_comparison_method = config$study_settings$Multiple_Comparison_Method,
        calculate_effective_n = config$study_settings$Calculate_Effective_N == "Y"
      ),
      warnings = warnings_list,
      decimal_sep = config$study_settings$Decimal_Separator,
      run_result = run_result
    )
  }, error = function(e) {
    confidence_refuse(
      code = "IO_OUTPUT_WRITE_FAILED",
      title = "Failed to Write Output",
      problem = sprintf("Failed to write output: %s", conditionMessage(e)),
      why_it_matters = "Analysis results cannot be saved without successful output generation.",
      how_to_fix = c(
        "Ensure the output directory exists and is writable",
        "Check that the output file is not open in Excel",
        "Verify sufficient disk space is available",
        "Check file permissions"
      )
    )
  })
}


#' Print completion summary
#' @keywords internal
print_completion_summary <- function(verbose, end_time, elapsed, n_questions,
                                      proportion_results, mean_results, nps_results,
                                      warnings_list, output_path, run_result) {
  if (verbose) {
    cat("\n")
    cat(sprintf("Finished: %s\n", format(end_time, "%Y-%m-%d %H:%M:%S")))
    cat(sprintf("Elapsed time: %.1f seconds\n", elapsed))
    cat(sprintf("Questions processed: %d\n", n_questions))
    cat(sprintf("Proportions: %d\n", length(proportion_results)))
    cat(sprintf("Means: %d\n", length(mean_results)))
    cat(sprintf("NPS: %d\n", length(nps_results)))
    cat(sprintf("Warnings: %d\n", length(warnings_list)))
    cat(sprintf("Output file: %s\n", output_path))
  }

  # TRS FINAL BANNER
  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else if (verbose) {
    cat("================================================================================\n")
    if (length(warnings_list) == 0) {
      cat("[TRS PASS] CONFIDENCE - ANALYSIS COMPLETED SUCCESSFULLY\n")
    } else {
      cat(sprintf("[TRS PARTIAL] CONFIDENCE - ANALYSIS COMPLETED WITH %d WARNING(S)\n",
                  length(warnings_list)))
    }
    cat("================================================================================\n\n")
  }
}


# ==============================================================================
# QUESTION PROCESSING ORCHESTRATION
# ==============================================================================

#' Process all questions
#' @keywords internal
process_all_questions <- function(config, survey_data, weight_var, verbose) {
  proportion_results <- list()
  mean_results <- list()
  nps_results <- list()
  warnings_list <- character()

  n_questions <- nrow(config$question_analysis)

  for (i in seq_len(n_questions)) {
    q_row <- config$question_analysis[i, ]
    q_id <- q_row$Question_ID

    if (verbose && i %% 10 == 0) {
      cat(sprintf("  Progress: %d/%d questions (%.0f%%)\n",
                  i, n_questions, (i / n_questions) * 100))
    }

    stat_type <- tolower(as.character(q_row$Statistic_Type))

    # Handle NA or empty statistic type
    if (is.na(stat_type) || stat_type == "") {
      warnings_list <- c(warnings_list,
        sprintf("Question %s: Statistic_Type is missing or empty", q_id))
      next
    }

    if (stat_type == "proportion") {
      result <- process_proportion_question(q_row, survey_data, weight_var, config)
      proportion_results[[q_id]] <- result$result
      warnings_list <- c(warnings_list, result$warnings)
    } else if (stat_type == "mean") {
      result <- process_mean_question(q_row, survey_data, weight_var, config)
      mean_results[[q_id]] <- result$result
      warnings_list <- c(warnings_list, result$warnings)
    } else if (stat_type == "nps") {
      result <- process_nps_question(q_row, survey_data, weight_var, config)
      nps_results[[q_id]] <- result$result
      warnings_list <- c(warnings_list, result$warnings)
    } else {
      warning(sprintf("Unknown statistic type '%s' for question %s", stat_type, q_id))
      warnings_list <- c(warnings_list,
        sprintf("Question %s: Unknown statistic type '%s'", q_id, stat_type))
    }
  }

  list(
    proportion_results = proportion_results,
    mean_results = mean_results,
    nps_results = nps_results,
    warnings = warnings_list
  )
}


# ==============================================================================
# REFACTORED QUESTION PROCESSING FUNCTIONS
# ==============================================================================

#' Process proportion question
#' Uses question_processor.R and ci_dispatcher.R for common logic
#' @keywords internal
process_proportion_question <- function(q_row, survey_data, weight_var, config) {
  q_id <- q_row$Question_ID
  warnings_list <- character()

  tryCatch({
    # Step 1: Prepare question data (using shared module)
    prep <- process_question_data(q_id, survey_data, weight_var, require_numeric = FALSE)

    if (!prep$success) {
      warnings_list <- c(warnings_list, prep$warning)
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 2: Parse categories
    categories <- parse_codes(q_row$Categories)
    if (length(categories) == 0) {
      warnings_list <- c(warnings_list, sprintf("Question %s: No categories specified", q_id))
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 3: Calculate base statistics (using shared module)
    stats <- calculate_proportion_stats(prep$values, categories, prep$weights)

    if (!stats$success) {
      warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, stats$message))
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 4: Build result with base stats
    result <- list(
      category   = paste(categories, collapse = ","),
      proportion = stats$proportion,
      n          = stats$n_raw,
      n_eff      = stats$n_eff
    )

    # Step 5: Dispatch CI calculations (using shared module)
    ci_results <- dispatch_proportion_ci(
      p = stats$proportion,
      n_eff = stats$n_eff,
      values = prep$values,
      categories = categories,
      weights = prep$weights,
      q_row = q_row,
      config = config
    )

    # Merge CI results
    if (!is.null(ci_results$moe)) result$moe <- ci_results$moe
    if (!is.null(ci_results$wilson)) result$wilson <- ci_results$wilson
    if (!is.null(ci_results$bootstrap)) result$bootstrap <- ci_results$bootstrap
    if (!is.null(ci_results$bayesian)) result$bayesian <- ci_results$bayesian
    warnings_list <- c(warnings_list, ci_results$warnings)

    return(list(result = result, warnings = warnings_list))

  }, error = function(e) {
    warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, conditionMessage(e)))
    return(list(result = NULL, warnings = warnings_list))
  })
}


#' Process mean question
#' Uses question_processor.R and ci_dispatcher.R for common logic
#' @keywords internal
process_mean_question <- function(q_row, survey_data, weight_var, config) {
  q_id <- q_row$Question_ID
  warnings_list <- character()

  tryCatch({
    # Step 1: Prepare question data (require numeric)
    prep <- process_question_data(q_id, survey_data, weight_var, require_numeric = TRUE)

    if (!prep$success) {
      warnings_list <- c(warnings_list, prep$warning)
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 2: Calculate base statistics
    stats <- calculate_mean_stats(prep$values, prep$weights)

    if (!stats$success) {
      warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, stats$message))
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 3: Build result with base stats
    result <- list(
      mean  = stats$mean,
      sd    = stats$sd,
      n     = stats$n_raw,
      n_eff = stats$n_eff
    )

    # Step 4: Dispatch CI calculations
    ci_results <- dispatch_mean_ci(
      mean_val = stats$mean,
      sd_val = stats$sd,
      n_eff = stats$n_eff,
      values = prep$values,
      weights = prep$weights,
      q_row = q_row,
      config = config
    )

    # Merge CI results
    if (!is.null(ci_results$t_dist)) result$t_dist <- ci_results$t_dist
    if (!is.null(ci_results$bootstrap)) result$bootstrap <- ci_results$bootstrap
    if (!is.null(ci_results$bayesian)) result$bayesian <- ci_results$bayesian
    warnings_list <- c(warnings_list, ci_results$warnings)

    return(list(result = result, warnings = warnings_list))

  }, error = function(e) {
    warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, conditionMessage(e)))
    return(list(result = NULL, warnings = warnings_list))
  })
}


#' Process NPS question
#' Uses question_processor.R and ci_dispatcher.R for common logic
#' @keywords internal
process_nps_question <- function(q_row, survey_data, weight_var, config) {
  q_id <- q_row$Question_ID
  warnings_list <- character()

  tryCatch({
    # Step 1: Prepare question data (require numeric)
    prep <- process_question_data(q_id, survey_data, weight_var, require_numeric = TRUE)

    if (!prep$success) {
      warnings_list <- c(warnings_list, prep$warning)
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 2: Parse promoter and detractor codes
    promoter_codes <- parse_codes(q_row$Promoter_Codes)
    detractor_codes <- parse_codes(q_row$Detractor_Codes)

    if (length(promoter_codes) == 0) {
      warnings_list <- c(warnings_list, sprintf("Question %s: No promoter codes specified", q_id))
      return(list(result = NULL, warnings = warnings_list))
    }
    if (length(detractor_codes) == 0) {
      warnings_list <- c(warnings_list, sprintf("Question %s: No detractor codes specified", q_id))
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 3: Calculate NPS statistics
    stats <- calculate_nps_stats(prep$values, promoter_codes, detractor_codes, prep$weights)

    if (!stats$success) {
      warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, stats$message))
      return(list(result = NULL, warnings = warnings_list))
    }

    # Step 4: Build result with base stats
    result <- list(
      nps_score       = stats$nps_score,
      pct_promoters   = stats$pct_promoters,
      pct_detractors  = stats$pct_detractors,
      pct_passives    = stats$pct_passives,
      n               = stats$n_raw,
      n_eff           = stats$n_eff,
      promoter_codes  = paste(promoter_codes, collapse = ","),
      detractor_codes = paste(detractor_codes, collapse = ",")
    )

    # Step 5: Dispatch CI calculations
    ci_results <- dispatch_nps_ci(
      nps_stats = stats,
      values = prep$values,
      promoter_codes = promoter_codes,
      detractor_codes = detractor_codes,
      weights = prep$weights,
      q_row = q_row,
      config = config
    )

    # Merge CI results
    if (!is.null(ci_results$moe_normal)) result$moe_normal <- ci_results$moe_normal
    if (!is.null(ci_results$bootstrap)) result$bootstrap <- ci_results$bootstrap
    if (!is.null(ci_results$bayesian)) result$bayesian <- ci_results$bayesian
    warnings_list <- c(warnings_list, ci_results$warnings)

    return(list(result = result, warnings = warnings_list))

  }, error = function(e) {
    warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, conditionMessage(e)))
    return(list(result = NULL, warnings = warnings_list))
  })
}


# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

#' Quick analysis with default settings
#' @export
quick_analysis <- function(config_path) {
  run_confidence_analysis(config_path, verbose = TRUE, stop_on_warnings = FALSE)
}


#' Print analysis summary
#' @export
print_analysis_summary <- function(results) {
  cat("\n=== CONFIDENCE ANALYSIS SUMMARY ===\n\n")

  if (!is.null(results$study_stats)) {
    cat("Study-Level Statistics:\n")
    print(results$study_stats, row.names = FALSE)
    cat("\n")
  }

  cat(sprintf("Proportions analyzed: %d\n", length(results$proportion_results)))
  cat(sprintf("Means analyzed: %d\n", length(results$mean_results)))
  cat(sprintf("NPS analyzed: %d\n", length(results$nps_results)))
  cat(sprintf("Warnings: %d\n", length(results$warnings)))
  cat(sprintf("Elapsed time: %.1f seconds\n", results$elapsed_seconds))

  if (length(results$warnings) > 0) {
    cat("\nWarnings:\n")
    for (i in seq_along(results$warnings)) {
      cat(sprintf("  %d. %s\n", i, results$warnings[i]))
    }
  }
}


# ==============================================================================
# NULL-COALESCING OPERATOR
# ==============================================================================

`%||%` <- function(a, b) if (is.null(a)) b else a


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

cat(sprintf("\n+ Turas Confidence Analysis Module loaded (v%s)\n", MAIN_VERSION))
cat("  Usage: run_confidence_analysis('path/to/config.xlsx')\n")
cat("  Quick: quick_analysis('path/to/config.xlsx')\n\n")
