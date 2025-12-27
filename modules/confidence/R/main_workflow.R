# ==============================================================================
# CONFIDENCE ANALYSIS - WORKFLOW ORCHESTRATION MODULE
# ==============================================================================
# Main workflow orchestration for confidence analysis.
# Coordinates the complete analysis pipeline from config to output.
#
# WORKFLOW STEPS:
# 1. Load and validate configuration
# 2. Load survey data
# 3. Calculate study-level statistics (DEFF, effective n)
# 4. Process each question according to specification
# 5. Collect warnings and quality checks
# 6. Generate comprehensive Excel output
#
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# Turas v10.1 - Extracted from 00_main.R for maintainability (2025-12-27)
#
# USAGE:
# This file is sourced automatically by 00_main.R at load time.
# Primary entry point: run_confidence_analysis()
#
# DEPENDENCIES:
# - main_initialization.R (for TRS infrastructure)
# - main_processing.R (for question processing functions)
# - All other module R scripts (config, data, stats, output)
# ==============================================================================

WORKFLOW_VERSION <- "10.1"

# ==============================================================================
# MAIN ANALYSIS FUNCTION
# ==============================================================================

#' Run complete confidence analysis
#'
#' Main function to orchestrate entire confidence analysis workflow.
#' Reads configuration, loads data, calculates confidence intervals,
#' and generates Excel output.
#'
#' WORKFLOW:
#' 1. Load and validate configuration (enforces 200 question limit)
#' 2. Load survey data (CSV or XLSX)
#' 3. Calculate study-level statistics (DEFF, effective n)
#' 4. Process each question according to specification
#' 5. Collect warnings and quality checks
#' 6. Generate comprehensive Excel output
#'
#' @param config_path Character. Path to confidence_config.xlsx
#' @param verbose Logical. Print progress messages (default TRUE)
#' @param stop_on_warnings Logical. Stop if warnings detected (default FALSE)
#'
#' @return List with analysis results (invisible)
#'
#' @examples
#' # Basic usage
#' run_confidence_analysis("config/confidence_config.xlsx")
#'
#' # Quiet mode
#' results <- run_confidence_analysis("config/confidence_config.xlsx", verbose = FALSE)
#'
#' # Stop on warnings
#' run_confidence_analysis("config/confidence_config.xlsx", stop_on_warnings = TRUE)
#'
#' @author Confidence Module Team
#' @date 2025-11-13
#' @export
run_confidence_analysis <- function(config_path,
                                    verbose = TRUE,
                                    stop_on_warnings = FALSE) {

  # ==========================================================================
  # TRS REFUSAL HANDLER WRAPPER (TRS v1.0)
  # ==========================================================================
  # Catches turas_refusal conditions and displays them cleanly
  # without stack traces - they are intentional stops, not crashes.

  if (exists("confidence_with_refusal_handler", mode = "function")) {
    confidence_with_refusal_handler(
      run_confidence_analysis_impl(config_path, verbose, stop_on_warnings)
    )
  } else {
    # Fallback if guard not loaded
    run_confidence_analysis_impl(config_path, verbose, stop_on_warnings)
  }
}


#' Internal Implementation of Confidence Analysis
#'
#' @keywords internal
run_confidence_analysis_impl <- function(config_path,
                                         verbose = TRUE,
                                         stop_on_warnings = FALSE) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION (TRS v1.0)
  # ==========================================================================

  # Create TRS run state for tracking events
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

  # Initialize warnings collector
  warnings_list <- character()

  # ============================================================================
  # STEP 1: LOAD CONFIGURATION
  # ============================================================================

  if (verbose) cat("STEP 1/6: Loading configuration...\n")

  config <- tryCatch({
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

  if (verbose) {
    cat(sprintf("  ✓ Configuration loaded successfully\n"))
    cat(sprintf("  ✓ Questions to analyze: %d (limit: 200)\n",
                nrow(config$question_analysis)))
    cat(sprintf("  ✓ Confidence level: %.2f\n", as.numeric(config$study_settings$Confidence_Level)))
    cat(sprintf("  ✓ Decimal separator: %s\n", config$study_settings$Decimal_Separator))
  }

  # ============================================================================
  # STEP 2: LOAD SURVEY DATA
  # ============================================================================

  if (verbose) cat("\nSTEP 2/6: Loading survey data...\n")

  # Get required questions from config
  required_questions <- config$question_analysis$Question_ID
  required_questions <- required_questions[!is.na(required_questions)]

  # Get weight variable
  weight_var <- config$file_paths$Weight_Variable
  if (is.na(weight_var) || weight_var == "") {
    weight_var <- NULL
  }

  # ==========================================================================
  # TRS WEIGHT VALIDATION (TRS v1.0 - REFUSE on missing configured weight)
  # ==========================================================================
  if (!is.null(weight_var) && weight_var != "") {
    # Weight was configured - it MUST exist in data
    # This will be checked after data load; prepare for refusal if missing
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

  if (verbose) {
    cat(sprintf("  ✓ Data loaded: %d respondents\n", nrow(survey_data)))
    if (!is.null(weight_var)) {
      cat(sprintf("  ✓ Weighted analysis using: %s\n", weight_var))
    } else {
      cat("  ✓ Unweighted analysis\n")
    }
  }

  # ==========================================================================
  # TRS WEIGHT REFUSAL CHECK (TRS v1.0)
  # ==========================================================================
  # If weight was configured but not found in data, REFUSE the run
  if (!is.null(weight_var) && weight_var != "" && !weight_var %in% names(survey_data)) {
    if (exists("turas_refuse", mode = "function")) {
      turas_refuse(
        "CONF_WEIGHT_MISSING",
        "Configured weight variable not found in data",
        sprintf("Weight variable '%s' specified in config but not present in data file", weight_var),
        sprintf("Ensure column '%s' exists in the data file, or remove weight_variable from config", weight_var)
      )
    } else {
      confidence_refuse(
        code = "DATA_WEIGHT_NOT_FOUND",
        title = "Configured Weight Variable Not Found",
        problem = sprintf("Weight variable '%s' specified in config but not present in data file", weight_var),
        why_it_matters = "The specified weight variable must exist in the data for weighted analysis.",
        how_to_fix = sprintf("Ensure column '%s' exists in the data file, or remove weight_variable from config", weight_var)
      )
    }
  }

  # ============================================================================
  # STEP 3: STUDY-LEVEL STATISTICS
  # ============================================================================

  if (verbose) cat("\nSTEP 3/6: Calculating study-level statistics...\n")

  study_stats <- NULL
  if (config$study_settings$Calculate_Effective_N == "Y") {
    study_stats <- tryCatch({
      calculate_study_level_stats(
        survey_data = survey_data,
        weight_variable = weight_var,
        group_variable = NULL
      )
    }, error = function(e) {
      warning(sprintf("Failed to calculate study-level stats: %s", conditionMessage(e)))
      warnings_list <- c(warnings_list, sprintf("Study-level stats failed: %s", conditionMessage(e)))
      NULL
    })

    if (!is.null(study_stats) && verbose) {
      if (nrow(study_stats) > 0) {
        cat(sprintf("  ✓ Actual n: %d\n", study_stats$Actual_n[1]))
        cat(sprintf("  ✓ Effective n: %d\n", study_stats$Effective_n[1]))
        cat(sprintf("  ✓ DEFF: %.2f\n", study_stats$DEFF[1]))

        # Check for warnings in study stats
        if (study_stats$Warning[1] != "") {
          warnings_list <- c(warnings_list, sprintf("Study-level: %s", study_stats$Warning[1]))
        }
      }
    }

    # Add representativeness diagnostics if study stats were calculated
    if (!is.null(study_stats)) {
      # Get weights vector for diagnostics
      weights <- if (!is.null(weight_var) && weight_var %in% names(survey_data)) {
        survey_data[[weight_var]]
      } else {
        NULL
      }

      # Weight concentration diagnostics
      weight_conc <- tryCatch({
        compute_weight_concentration(weights)
      }, error = function(e) {
        if (verbose) cat(sprintf("  ⚠ Weight concentration calculation failed: %s\n", conditionMessage(e)))
        NULL
      })

      # Margin comparison (if Population_Margins provided)
      margin_comp <- tryCatch({
        compute_margin_comparison(
          data = survey_data,
          weights = weights,
          target_margins = config$population_margins
        )
      }, error = function(e) {
        if (verbose) cat(sprintf("  ⚠ Margin comparison failed: %s\n", conditionMessage(e)))
        NULL
      })

      # Attach to study_stats as attributes (so they travel with study_stats)
      attr(study_stats, "weight_concentration") <- weight_conc
      attr(study_stats, "margin_comparison") <- margin_comp

      # Report if calculated
      if (!is.null(weight_conc) && verbose) {
        cat(sprintf("  ✓ Weight concentration: Top 5%% hold %.1f%% of weight (%s)\n",
                    weight_conc$Top_5pct_Share,
                    weight_conc$Concentration_Flag))
      }

      if (!is.null(margin_comp) && verbose) {
        n_red <- sum(margin_comp$Flag == "RED", na.rm = TRUE)
        n_amber <- sum(margin_comp$Flag == "AMBER", na.rm = TRUE)
        n_green <- sum(margin_comp$Flag == "GREEN", na.rm = TRUE)
        cat(sprintf("  ✓ Margin comparison: %d targets (%d GREEN, %d AMBER, %d RED)\n",
                    nrow(margin_comp), n_green, n_amber, n_red))
        if (n_red > 0) {
          warnings_list <- c(warnings_list, sprintf(
            "Representativeness: %d margin target(s) off by >5pp (RED flag)",
            n_red
          ))
        }
      }
    }
  } else {
    if (verbose) cat("  ⊘ Study-level stats skipped (disabled in config)\n")
  }

  # ============================================================================
  # STEP 4: PROCESS QUESTIONS
  # ============================================================================

  if (verbose) cat("\nSTEP 4/6: Processing questions...\n")

  proportion_results <- list()
  mean_results <- list()
  nps_results <- list()

  n_questions <- nrow(config$question_analysis)

  for (i in seq_len(n_questions)) {
    q_row <- config$question_analysis[i, ]
    q_id <- q_row$Question_ID

    if (verbose && i %% 10 == 0) {
      cat(sprintf("  Progress: %d/%d questions (%.0f%%)\n",
                  i, n_questions, (i / n_questions) * 100))
    }

    # Process based on statistic type
    stat_type <- tolower(q_row$Statistic_Type)

    if (stat_type == "proportion") {
      result <- process_proportion_question(q_row, survey_data, weight_var, config, warnings_list)
      proportion_results[[q_id]] <- result$result
      warnings_list <- result$warnings
    } else if (stat_type == "mean") {
      result <- process_mean_question(q_row, survey_data, weight_var, config, warnings_list)
      mean_results[[q_id]] <- result$result
      warnings_list <- result$warnings
    } else if (stat_type == "nps") {
      result <- process_nps_question(q_row, survey_data, weight_var, config, warnings_list)
      nps_results[[q_id]] <- result$result
      warnings_list <- result$warnings
    } else {
      warning(sprintf("Unknown statistic type '%s' for question %s", stat_type, q_id))
      warnings_list <- c(warnings_list, sprintf("Question %s: Unknown statistic type '%s'", q_id, stat_type))
    }
  }

  if (verbose) {
    cat(sprintf("  ✓ Processed: %d proportions, %d means, %d NPS\n",
                length(proportion_results), length(mean_results), length(nps_results)))
  }

  # ============================================================================
  # STEP 5: COLLECT WARNINGS
  # ============================================================================

  if (verbose) cat("\nSTEP 5/6: Quality checks...\n")

  if (length(warnings_list) > 0) {
    if (verbose) {
      cat(sprintf("  ⚠ %d warnings detected\n", length(warnings_list)))
    }

    if (stop_on_warnings) {
      cat("\nWARNINGS:\n")
      for (i in seq_along(warnings_list)) {
        cat(sprintf("  %d. %s\n", i, warnings_list[i]))
      }
      confidence_refuse(
        code = "DATA_QUALITY_WARNINGS",
        title = "Analysis Stopped Due to Warnings",
        problem = sprintf("Analysis encountered %d warning(s) and stop_on_warnings is enabled", length(warnings_list)),
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
    if (verbose) cat("  ✓ No warnings detected\n")
  }

  # ============================================================================
  # STEP 6: GENERATE OUTPUT
  # ============================================================================

  if (verbose) cat("\nSTEP 6/6: Generating Excel output...\n")

  output_path <- config$file_paths$Output_File

  # ==========================================================================
  # TRS: Log PARTIAL events for any warnings
  # ==========================================================================
  if (!is.null(trs_state) && length(warnings_list) > 0) {
    for (warn in warnings_list) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(
          trs_state,
          "CONF_WARNING",
          "Analysis warning",
          problem = warn
        )
      }
    }
  }

  # ==========================================================================
  # TRS: Get run result for output
  # ==========================================================================
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

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

  # ============================================================================
  # SUMMARY
  # ============================================================================

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  if (verbose) {
    cat("\n")
    cat(sprintf("Finished: %s\n", format(end_time, "%Y-%m-%d %H:%M:%S")))
    cat(sprintf("Elapsed time: %.1f seconds\n", elapsed))
    cat(sprintf("Questions processed: %d\n", n_questions))
    cat(sprintf("Proportions: %d\n", length(proportion_results)))
    cat(sprintf("Means: %d\n", length(mean_results)))
    cat(sprintf("Warnings: %d\n", length(warnings_list)))
    cat(sprintf("Output file: %s\n", output_path))
  }

  # ==========================================================================
  # TRS FINAL BANNER (TRS v1.0)
  # ==========================================================================
  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else if (verbose) {
    cat("================================================================================\n")
    if (length(warnings_list) == 0) {
      cat("[TRS PASS] CONFIDENCE - ANALYSIS COMPLETED SUCCESSFULLY\n")
    } else {
      cat(sprintf("[TRS PARTIAL] CONFIDENCE - ANALYSIS COMPLETED WITH %d WARNING(S)\n", length(warnings_list)))
    }
    cat("================================================================================\n\n")
  }

  # Return results (include run_result for programmatic access)
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
# MODULE METADATA
# ==============================================================================

if (exists("VERBOSE_LOAD") && VERBOSE_LOAD) {
  message(sprintf("  ✓ Workflow module loaded (v%s)", WORKFLOW_VERSION))
}
