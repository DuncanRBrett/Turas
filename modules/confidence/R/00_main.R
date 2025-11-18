# ==============================================================================
# CONFIDENCE ANALYSIS MAIN ORCHESTRATION V1.0.0
# ==============================================================================
# Main script for running complete confidence analysis
# Part of Turas Confidence Analysis Module
#
# VERSION HISTORY:
# V1.0.0 - Initial release (2025-11-13)
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

MAIN_VERSION <- "1.0.0"

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

  # List of files to source in order
  module_files <- c(
    "utils.R",
    "01_load_config.R",
    "02_load_data.R",
    "03_study_level.R",
    "04_proportions.R",
    "05_means.R",
    "07_output.R"
  )

  for (file in module_files) {
    file_path <- file.path(base_dir, file)

    if (!file.exists(file_path)) {
      # Try R subdirectory
      file_path <- file.path(base_dir, "R", file)
    }

    if (!file.exists(file_path)) {
      stop(sprintf("Required module file not found: %s", file), call. = FALSE)
    }

    source(file_path)
  }
}

# Source all modules
tryCatch({
  source_module_files()
}, error = function(e) {
  stop(sprintf(
    "Failed to load module files\nError: %s\n\nPlease ensure all R files are in the correct location.",
    conditionMessage(e)
  ), call. = FALSE)
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

  # Start timer
  start_time <- Sys.time()

  if (verbose) {
    cat("\n")
    cat("================================================================================\n")
    cat("TURAS CONFIDENCE ANALYSIS MODULE\n")
    cat(sprintf("Version: %s\n", MAIN_VERSION))
    cat(sprintf("Started: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))
    cat("================================================================================\n\n")
  }

  # Initialize warnings collector
  warnings_list <- character()

  # ============================================================================
  # STEP 1: LOAD CONFIGURATION
  # ============================================================================

  if (verbose) cat("STEP 1/6: Loading configuration...\n")

  config <- tryCatch({
    load_confidence_config(config_path)
  }, error = function(e) {
    stop(sprintf("Failed to load configuration\nError: %s", conditionMessage(e)), call. = FALSE)
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

  survey_data <- tryCatch({
    load_survey_data(
      data_file_path = config$file_paths$Data_File,
      required_questions = required_questions,
      weight_variable = weight_var,
      verbose = verbose
    )
  }, error = function(e) {
    stop(sprintf("Failed to load survey data\nError: %s", conditionMessage(e)), call. = FALSE)
  })

  if (verbose) {
    cat(sprintf("  ✓ Data loaded: %d respondents\n", nrow(survey_data)))
    if (!is.null(weight_var)) {
      cat(sprintf("  ✓ Weighted analysis using: %s\n", weight_var))
    } else {
      cat("  ✓ Unweighted analysis\n")
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
  } else {
    if (verbose) cat("  ⊘ Study-level stats skipped (disabled in config)\n")
  }

  # ============================================================================
  # STEP 4: PROCESS QUESTIONS
  # ============================================================================

  if (verbose) cat("\nSTEP 4/6: Processing questions...\n")

  proportion_results <- list()
  mean_results <- list()

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
    } else {
      warning(sprintf("Unknown statistic type '%s' for question %s", stat_type, q_id))
      warnings_list <- c(warnings_list, sprintf("Question %s: Unknown statistic type '%s'", q_id, stat_type))
    }
  }

  if (verbose) {
    cat(sprintf("  ✓ Processed: %d proportions, %d means\n",
                length(proportion_results), length(mean_results)))
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
      stop("Analysis stopped due to warnings (stop_on_warnings = TRUE)", call. = FALSE)
    }
  } else {
    if (verbose) cat("  ✓ No warnings detected\n")
  }

  # ============================================================================
  # STEP 6: GENERATE OUTPUT
  # ============================================================================

  if (verbose) cat("\nSTEP 6/6: Generating Excel output...\n")

  output_path <- config$file_paths$Output_File

  tryCatch({
    write_confidence_output(
      output_path = output_path,
      study_level_stats = study_stats,
      proportion_results = proportion_results,
      mean_results = mean_results,
      config = list(
        confidence_level = as.numeric(config$study_settings$Confidence_Level),
        bootstrap_iterations = as.integer(config$study_settings$Bootstrap_Iterations),
        multiple_comparison_method = config$study_settings$Multiple_Comparison_Method,
        calculate_effective_n = config$study_settings$Calculate_Effective_N == "Y"
      ),
      warnings = warnings_list,
      decimal_sep = config$study_settings$Decimal_Separator
    )
  }, error = function(e) {
    stop(sprintf("Failed to write output\nError: %s", conditionMessage(e)), call. = FALSE)
  })

  # ============================================================================
  # SUMMARY
  # ============================================================================

  end_time <- Sys.time()
  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  if (verbose) {
    cat("\n")
    cat("================================================================================\n")
    cat("ANALYSIS COMPLETE\n")
    cat("================================================================================\n")
    cat(sprintf("Finished: %s\n", format(end_time, "%Y-%m-%d %H:%M:%S")))
    cat(sprintf("Elapsed time: %.1f seconds\n", elapsed))
    cat(sprintf("Questions processed: %d\n", n_questions))
    cat(sprintf("Proportions: %d\n", length(proportion_results)))
    cat(sprintf("Means: %d\n", length(mean_results)))
    cat(sprintf("Warnings: %d\n", length(warnings_list)))
    cat(sprintf("Output file: %s\n", output_path))
    cat("================================================================================\n\n")
  }

  # Return results
  invisible(list(
    study_stats = study_stats,
    proportion_results = proportion_results,
    mean_results = mean_results,
    warnings = warnings_list,
    config = config,
    elapsed_seconds = elapsed
  ))
}


# ==============================================================================
# QUESTION PROCESSING FUNCTIONS
# ==============================================================================

#' Process proportion question (internal)
#' @keywords internal
process_proportion_question <- function(q_row, survey_data, weight_var, config, warnings_list) {

  q_id <- q_row$Question_ID
  result <- list()

  tryCatch({
    # Get question data
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(warnings_list, sprintf("Question %s: Not found in data", q_id))
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # Get weights if applicable
    weights <- NULL
    if (!is.null(weight_var)) {
      weights <- survey_data[[weight_var]]
    }

    # Parse categories
    categories <- parse_codes(q_row$Categories)

    # Calculate proportion
    if (length(categories) == 0) {
      warnings_list <- c(warnings_list, sprintf("Question %s: No categories specified", q_id))
      return(list(result = NULL, warnings = warnings_list))
    }

    # For simplicity in Phase 1, use first category or count successes
    # More sophisticated category handling can be added later
    success_values <- values %in% categories

    # Remove NAs
    valid_idx <- !is.na(values)
    success_values <- success_values[valid_idx]

    # Initialize weights_valid for unweighted case
    weights_valid <- NULL

    if (!is.null(weights)) {
      weights_valid <- weights[valid_idx]

      # Filter to valid weights and align success_values accordingly
      valid_weight_idx <- !is.na(weights_valid) & weights_valid > 0
      weights_valid <- weights_valid[valid_weight_idx]
      success_values <- success_values[valid_weight_idx]

      n_eff <- calculate_effective_n(weights_valid)
      p <- sum(weights_valid[success_values]) / sum(weights_valid)
    } else {
      n_eff <- sum(valid_idx)
      p <- mean(success_values)
    }

    result$proportion <- p
    result$n <- sum(valid_idx)
    result$n_eff <- n_eff
    result$category <- paste(categories, collapse = ",")

    # Calculate confidence intervals based on config
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # MOE
    if (toupper(q_row$Run_MOE) == "Y") {
      result$moe_normal <- calculate_proportion_ci_normal(p, n_eff, conf_level)
    }

    # Wilson
    if (toupper(q_row$Run_Wilson) == "Y") {
      result$wilson <- calculate_proportion_ci_wilson(p, n_eff, conf_level)
    }

    # Bootstrap
    if (toupper(q_row$Run_Bootstrap) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
      # Pass raw values and categories, not success_values
      values_valid <- values[valid_idx]
      result$bootstrap <- bootstrap_proportion_ci(values_valid, categories, weights_valid, boot_iter, conf_level)
    }

    # Bayesian
    if (toupper(q_row$Run_Credible) == "Y") {
      # Check for prior specifications (Prior_Mean and Prior_N, not Alpha/Beta)
      prior_mean <- if (!is.na(q_row$Prior_Mean)) as.numeric(q_row$Prior_Mean) else NULL
      prior_n_val <- if (!is.na(q_row$Prior_N)) as.integer(q_row$Prior_N) else NULL

      # Calculate proportion from success_values
      n_bayes <- length(success_values)

      result$bayesian <- credible_interval_proportion(p, n_bayes, conf_level, prior_mean, prior_n_val)
    }

  }, error = function(e) {
    warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, conditionMessage(e)))
  })

  return(list(result = result, warnings = warnings_list))
}


#' Process mean question (internal)
#' @keywords internal
process_mean_question <- function(q_row, survey_data, weight_var, config, warnings_list) {

  q_id <- q_row$Question_ID
  result <- list()

  tryCatch({
    # Get question data
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(warnings_list, sprintf("Question %s: Not found in data", q_id))
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # Ensure numeric
    if (!is.numeric(values)) {
      values <- as.numeric(as.character(values))
    }

    # Get weights if applicable
    weights <- NULL
    if (!is.null(weight_var)) {
      weights <- survey_data[[weight_var]]
    }

    # Remove NAs
    valid_idx <- !is.na(values)
    values_valid <- values[valid_idx]

    if (!is.null(weights)) {
      weights_valid <- weights[valid_idx]
      weights_valid <- weights_valid[!is.na(weights_valid) & weights_valid > 0]
    } else {
      weights_valid <- NULL
    }

    # Calculate mean and stats
    if (!is.null(weights_valid)) {
      mean_val <- weighted.mean(values_valid, weights_valid)
      result$n_eff <- calculate_effective_n(weights_valid)

      # Calculate weighted SD (same formula as in calculate_mean_ci)
      weighted_var <- sum(weights_valid * (values_valid - mean_val)^2) / sum(weights_valid)
      sd_val <- sqrt(weighted_var)
    } else {
      mean_val <- mean(values_valid)
      result$n_eff <- length(values_valid)
      sd_val <- sd(values_valid)
    }

    result$mean <- mean_val
    result$sd <- sd_val
    result$n <- length(values_valid)

    # Calculate confidence intervals based on config
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # t-distribution CI
    if (toupper(q_row$Run_MOE) == "Y") {
      result$t_dist <- calculate_mean_ci(values_valid, weights_valid, conf_level)
    }

    # Bootstrap
    if (toupper(q_row$Run_Bootstrap) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
      result$bootstrap <- bootstrap_mean_ci(values_valid, weights_valid, boot_iter, conf_level)
    }

    # Bayesian
    if (toupper(q_row$Run_Credible) == "Y") {
      # Check for prior specifications
      prior_mean <- if (!is.na(q_row$Prior_Mean)) q_row$Prior_Mean else NULL
      prior_sd <- if (!is.na(q_row$Prior_SD)) q_row$Prior_SD else NULL
      prior_n <- if (!is.na(q_row$Prior_N)) q_row$Prior_N else NULL

      result$bayesian <- credible_interval_mean(values_valid, weights_valid, conf_level,
                                                 prior_mean, prior_sd, prior_n)
    }

  }, error = function(e) {
    warnings_list <- c(warnings_list, sprintf("Question %s: %s", q_id, conditionMessage(e)))
  })

  return(list(result = result, warnings = warnings_list))
}


# ==============================================================================
# CONVENIENCE FUNCTIONS
# ==============================================================================

#' Quick analysis with default settings
#'
#' Convenience wrapper for run_confidence_analysis with common defaults
#'
#' @param config_path Character. Path to confidence_config.xlsx
#'
#' @export
quick_analysis <- function(config_path) {
  run_confidence_analysis(config_path, verbose = TRUE, stop_on_warnings = FALSE)
}


#' Print analysis summary
#'
#' @param results List. Output from run_confidence_analysis()
#'
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
# MODULE INITIALIZATION
# ==============================================================================

cat(sprintf("\n✓ Turas Confidence Analysis Module loaded (v%s)\n", MAIN_VERSION))
cat("  Usage: run_confidence_analysis('path/to/config.xlsx')\n")
cat("  Quick: quick_analysis('path/to/config.xlsx')\n\n")
