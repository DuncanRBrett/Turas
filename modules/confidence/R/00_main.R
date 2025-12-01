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
      nps_results = nps_results,
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
    nps_results = nps_results,
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
    # -------------------------------------------------------------------------
    # 1. Check question exists
    # -------------------------------------------------------------------------
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Not found in data", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # -------------------------------------------------------------------------
    # 2. Get weights (if applicable)
    # -------------------------------------------------------------------------
    weights <- NULL
    if (!is.null(weight_var) && nzchar(weight_var) && weight_var %in% names(survey_data)) {
      weights <- survey_data[[weight_var]]
    }

    # -------------------------------------------------------------------------
    # 3. Parse categories and basic validation
    # -------------------------------------------------------------------------
    categories <- parse_codes(q_row$Categories)
    if (length(categories) == 0) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: No categories specified", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 4. Clean and align values and weights
    # -------------------------------------------------------------------------
    # Start with non-missing values
    valid_value_idx <- !is.na(values)

    if (!is.null(weights)) {
      # Keep only respondents with a valid answer AND valid weight
      weights_raw <- weights
      good_idx <- valid_value_idx & !is.na(weights_raw) & weights_raw > 0

      values_valid  <- values[good_idx]
      weights_valid <- weights_raw[good_idx]

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid cases after applying weights", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    } else {
      values_valid  <- values[valid_value_idx]
      weights_valid <- NULL

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid (non-missing) responses", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 5. Calculate observed proportion and effective n
    # -------------------------------------------------------------------------
    in_category <- values_valid %in% categories

    if (!is.null(weights_valid)) {
      total_w   <- sum(weights_valid)
      success_w <- sum(weights_valid[in_category])

      if (isTRUE(total_w <= 0)) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Total weight is zero or negative", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }

      p      <- success_w / total_w
      n_eff  <- calculate_effective_n(weights_valid)
      n_raw  <- length(values_valid)
    } else {
      p      <- mean(in_category)
      n_eff  <- length(values_valid)
      n_raw  <- length(values_valid)
    }

    # Basic sanity check
    if (is.na(p)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Proportion could not be calculated (NA)", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 6. Store core stats for this question
    # -------------------------------------------------------------------------
    result$category   <- paste(categories, collapse = ",")
    result$proportion <- p
    result$n          <- n_raw
    result$n_eff      <- n_eff

    # -------------------------------------------------------------------------
    # 7. Confidence intervals according to config
    # -------------------------------------------------------------------------
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # Margin of error (normal approximation using effective n)
    run_moe_flag <- q_row$Run_MOE
    if (!is.null(run_moe_flag) &&
        !is.na(run_moe_flag) &&
        toupper(run_moe_flag) == "Y") {
      if (!is.na(n_eff) && n_eff > 0) {
        result$moe <- calculate_proportion_ci_normal(p, n_eff, conf_level)
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Effective n <= 0, MOE CI not calculated", q_id)
        )
      }
    }

    # Wilson interval (using Use_Wilson flag)
    use_wilson_flag <- q_row$Use_Wilson
    if (!is.null(use_wilson_flag) &&
        !is.na(use_wilson_flag) &&
        toupper(use_wilson_flag) == "Y") {
      if (!is.na(n_eff) && n_eff > 0) {
        result$wilson <- calculate_proportion_ci_wilson(p, n_eff, conf_level)
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Effective n <= 0, Wilson CI not calculated", q_id)
        )
      }
    }

    # Bootstrap CI
    run_boot_flag <- q_row$Run_Bootstrap
    if (!is.null(run_boot_flag) &&
        !is.na(run_boot_flag) &&
        toupper(run_boot_flag) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
      result$bootstrap <- bootstrap_proportion_ci(
        data       = values_valid,
        categories = categories,
        weights    = weights_valid,
        B          = boot_iter,
        conf_level = conf_level
      )
    }

    # Bayesian CI (Beta-Binomial)
    run_cred_flag <- q_row$Run_Credible
    if (!is.null(run_cred_flag) &&
        !is.na(run_cred_flag) &&
        toupper(run_cred_flag) == "Y") {
      prior_mean <- if (!is.na(q_row$Prior_Mean)) q_row$Prior_Mean else NULL
      prior_n    <- if (!is.na(q_row$Prior_N))    q_row$Prior_N    else NULL

      # Use effective n for weighted data, raw n otherwise
      n_bayes <- if (!is.null(weights_valid)) n_eff else length(values_valid)

      result$bayesian <- credible_interval_proportion(
        p          = p,
        n          = n_bayes,
        conf_level = conf_level,
        prior_mean = prior_mean,
        prior_n    = prior_n
      )
    }

  }, error = function(e) {
    warnings_list <- c(
      warnings_list,
      sprintf("Question %s: %s", q_id, conditionMessage(e))
    )
  })

  return(list(result = result, warnings = warnings_list))
}


#' Process mean question (internal)
#' @keywords internal
process_mean_question <- function(q_row, survey_data, weight_var, config, warnings_list) {
  q_id <- q_row$Question_ID
  result <- list()

  tryCatch({
    # -------------------------------------------------------------------------
    # 1. Check question exists
    # -------------------------------------------------------------------------
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Not found in data", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # Attempt to convert to numeric if not already numeric
    # (handles case where numeric data is stored as character/text in source file)
    if (!is.numeric(values)) {
      # Try conversion
      values_converted <- suppressWarnings(as.numeric(values))

      # Check if conversion was mostly successful (>50% valid numbers)
      n_total <- length(values)
      n_valid_after_conversion <- sum(!is.na(values_converted))
      n_was_na_before <- sum(is.na(values))

      # If we got valid numbers, use the converted version
      if (n_valid_after_conversion > 0 &&
          (n_valid_after_conversion / n_total) > 0.5) {
        values <- values_converted
      } else {
        # Truly non-numeric - cannot convert
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Non-numeric values for mean analysis (only %d/%d convertible to numeric)",
                  q_id, n_valid_after_conversion, n_total)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 2. Get weights (if applicable)
    # -------------------------------------------------------------------------
    weights <- NULL
    if (!is.null(weight_var) && nzchar(weight_var) && weight_var %in% names(survey_data)) {
      weights <- survey_data[[weight_var]]
    }

    # -------------------------------------------------------------------------
    # 3. Clean and align values and weights
    # -------------------------------------------------------------------------
    # Start with non-missing numeric values
    valid_value_idx <- !is.na(values) & is.finite(values)

    if (!is.null(weights)) {
      weights_raw <- weights
      # Keep only respondents with valid value AND valid weight
      good_idx <- valid_value_idx & !is.na(weights_raw) & weights_raw > 0

      values_valid  <- values[good_idx]
      weights_valid <- weights_raw[good_idx]

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid cases after applying weights", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    } else {
      values_valid  <- values[valid_value_idx]
      weights_valid <- NULL

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid (non-missing) numeric responses", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 4. Calculate mean, SD and effective n
    # -------------------------------------------------------------------------
    if (!is.null(weights_valid) && length(weights_valid) > 0) {
      # Weighted mean
      total_w <- sum(weights_valid)
      if (isTRUE(total_w <= 0)) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Total weight is zero or negative", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }

      mean_val <- sum(values_valid * weights_valid) / total_w

      # Weighted variance (population estimator, consistent with effective n)
      weighted_var <- sum(weights_valid * (values_valid - mean_val)^2) / total_w
      sd_val       <- sqrt(weighted_var)

      n_eff <- calculate_effective_n(weights_valid)
      n_raw <- length(values_valid)
    } else {
      # Unweighted
      mean_val <- mean(values_valid)
      sd_val   <- sd(values_valid)
      n_eff    <- length(values_valid)
      n_raw    <- length(values_valid)
      weights_valid <- NULL  # be explicit
    }

    result$mean  <- mean_val
    result$sd    <- sd_val
    result$n     <- n_raw
    result$n_eff <- n_eff

    # -------------------------------------------------------------------------
    # 5. Confidence intervals according to config
    # -------------------------------------------------------------------------
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # t-distribution CI (uses n_eff internally in calculate_mean_ci)
    run_moe_flag <- q_row$Run_MOE
    if (!is.null(run_moe_flag) &&
        !is.na(run_moe_flag) &&
        toupper(run_moe_flag) == "Y") {
      result$t_dist <- calculate_mean_ci(
        values     = values_valid,
        weights    = weights_valid,
        conf_level = conf_level
      )
    }

    # Bootstrap CI
    run_boot_flag <- q_row$Run_Bootstrap
    if (!is.null(run_boot_flag) &&
        !is.na(run_boot_flag) &&
        toupper(run_boot_flag) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)
      result$bootstrap <- bootstrap_mean_ci(
        values     = values_valid,
        weights    = weights_valid,
        B          = boot_iter,
        conf_level = conf_level
      )
    }

    # Bayesian CI for the mean
    run_cred_flag <- q_row$Run_Credible
    if (!is.null(run_cred_flag) &&
        !is.na(run_cred_flag) &&
        toupper(run_cred_flag) == "Y") {
      prior_mean <- if (!is.na(q_row$Prior_Mean)) q_row$Prior_Mean else NULL
      prior_sd   <- if (!is.na(q_row$Prior_SD))   q_row$Prior_SD   else NULL
      prior_n    <- if (!is.na(q_row$Prior_N))    q_row$Prior_N    else NULL

      result$bayesian <- credible_interval_mean(
        values     = values_valid,
        weights    = weights_valid,
        conf_level = conf_level,
        prior_mean = prior_mean,
        prior_sd   = prior_sd,
        prior_n    = prior_n
      )
    }

  }, error = function(e) {
    warnings_list <- c(
      warnings_list,
      sprintf("Question %s: %s", q_id, conditionMessage(e))
    )
  })

  return(list(result = result, warnings = warnings_list))
}


#' Process NPS question (internal)
#' @keywords internal
process_nps_question <- function(q_row, survey_data, weight_var, config, warnings_list) {
  q_id <- q_row$Question_ID
  result <- list()

  tryCatch({
    # -------------------------------------------------------------------------
    # 1. Check question exists
    # -------------------------------------------------------------------------
    if (!q_id %in% names(survey_data)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Not found in data", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    values <- survey_data[[q_id]]

    # Require numeric for NPS analysis
    if (!is.numeric(values)) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: Non-numeric values for NPS analysis", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 2. Get weights (if applicable)
    # -------------------------------------------------------------------------
    weights <- NULL
    if (!is.null(weight_var) && nzchar(weight_var) && weight_var %in% names(survey_data)) {
      weights <- survey_data[[weight_var]]
    }

    # -------------------------------------------------------------------------
    # 3. Parse promoter and detractor codes
    # -------------------------------------------------------------------------
    promoter_codes <- parse_codes(q_row$Promoter_Codes)
    detractor_codes <- parse_codes(q_row$Detractor_Codes)

    if (length(promoter_codes) == 0) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: No promoter codes specified", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    if (length(detractor_codes) == 0) {
      warnings_list <- c(
        warnings_list,
        sprintf("Question %s: No detractor codes specified", q_id)
      )
      return(list(result = NULL, warnings = warnings_list))
    }

    # -------------------------------------------------------------------------
    # 4. Clean and align values and weights
    # -------------------------------------------------------------------------
    # Start with non-missing numeric values
    valid_value_idx <- !is.na(values) & is.finite(values)

    if (!is.null(weights)) {
      weights_raw <- weights
      # Keep only respondents with valid answer AND valid weight
      good_idx <- valid_value_idx & !is.na(weights_raw) & weights_raw > 0

      values_valid  <- values[good_idx]
      weights_valid <- weights_raw[good_idx]

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid cases after applying weights", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    } else {
      values_valid  <- values[valid_value_idx]
      weights_valid <- NULL

      if (length(values_valid) == 0) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: No valid (non-missing) responses", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }
    }

    # -------------------------------------------------------------------------
    # 5. Calculate NPS components
    # -------------------------------------------------------------------------
    is_promoter  <- values_valid %in% promoter_codes
    is_detractor <- values_valid %in% detractor_codes

    if (!is.null(weights_valid)) {
      total_w <- sum(weights_valid)

      if (isTRUE(total_w <= 0)) {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Total weight is zero or negative", q_id)
        )
        return(list(result = NULL, warnings = warnings_list))
      }

      pct_promoters  <- 100 * sum(weights_valid[is_promoter]) / total_w
      pct_detractors <- 100 * sum(weights_valid[is_detractor]) / total_w
      n_eff <- calculate_effective_n(weights_valid)
      n_raw <- length(values_valid)
    } else {
      pct_promoters  <- 100 * mean(is_promoter)
      pct_detractors <- 100 * mean(is_detractor)
      n_eff <- length(values_valid)
      n_raw <- length(values_valid)
    }

    nps_score <- pct_promoters - pct_detractors

    # -------------------------------------------------------------------------
    # 6. Store core stats
    # -------------------------------------------------------------------------
    result$nps_score       <- nps_score
    result$pct_promoters   <- pct_promoters
    result$pct_detractors  <- pct_detractors
    result$pct_passives    <- 100 - pct_promoters - pct_detractors
    result$n               <- n_raw
    result$n_eff           <- n_eff
    result$promoter_codes  <- paste(promoter_codes, collapse = ",")
    result$detractor_codes <- paste(detractor_codes, collapse = ",")

    # -------------------------------------------------------------------------
    # 7. Confidence intervals according to config
    # -------------------------------------------------------------------------
    conf_level <- as.numeric(config$study_settings$Confidence_Level)

    # Normal approximation (using variance of difference formula)
    run_moe_flag <- q_row$Run_MOE
    if (!is.null(run_moe_flag) &&
        !is.na(run_moe_flag) &&
        toupper(run_moe_flag) == "Y") {
      if (!is.na(n_eff) && n_eff > 0) {
        # Convert percentages to proportions for variance calculation
        p_prom <- pct_promoters / 100
        p_detr <- pct_detractors / 100

        # Variance of difference (assuming independence)
        var_prom <- p_prom * (1 - p_prom) / n_eff
        var_detr <- p_detr * (1 - p_detr) / n_eff
        se_nps <- sqrt(var_prom + var_detr) * 100  # Convert back to percentage scale

        z <- qnorm(1 - (1 - conf_level) / 2)
        moe <- z * se_nps

        result$moe_normal <- list(
          lower = nps_score - moe,
          upper = nps_score + moe,
          se = se_nps
        )
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Effective n <= 0, MOE CI not calculated", q_id)
        )
      }
    }

    # Bootstrap CI
    run_boot_flag <- q_row$Run_Bootstrap
    if (!is.null(run_boot_flag) &&
        !is.na(run_boot_flag) &&
        toupper(run_boot_flag) == "Y") {
      boot_iter <- as.integer(config$study_settings$Bootstrap_Iterations)

      # Bootstrap NPS
      B <- boot_iter
      validate_sample_size(B, "B", min_n = 1000)

      n <- length(values_valid)
      boot_nps <- numeric(B)

      for (b in 1:B) {
        boot_idx <- sample(1:n, size = n, replace = TRUE)
        boot_values <- values_valid[boot_idx]

        if (!is.null(weights_valid)) {
          boot_weights <- weights_valid[boot_idx]
          total_w_boot <- sum(boot_weights)

          if (total_w_boot > 0) {
            is_prom_boot <- boot_values %in% promoter_codes
            is_detr_boot <- boot_values %in% detractor_codes

            pct_prom_boot <- 100 * sum(boot_weights[is_prom_boot]) / total_w_boot
            pct_detr_boot <- 100 * sum(boot_weights[is_detr_boot]) / total_w_boot

            boot_nps[b] <- pct_prom_boot - pct_detr_boot
          } else {
            boot_nps[b] <- NA
          }
        } else {
          is_prom_boot <- boot_values %in% promoter_codes
          is_detr_boot <- boot_values %in% detractor_codes

          pct_prom_boot <- 100 * mean(is_prom_boot)
          pct_detr_boot <- 100 * mean(is_detr_boot)

          boot_nps[b] <- pct_prom_boot - pct_detr_boot
        }
      }

      # Remove any NAs from bootstrap
      boot_nps <- boot_nps[!is.na(boot_nps)]

      if (length(boot_nps) > 0) {
        alpha <- 1 - conf_level
        result$bootstrap <- list(
          lower = quantile(boot_nps, alpha / 2, names = FALSE),
          upper = quantile(boot_nps, 1 - alpha / 2, names = FALSE)
        )
      } else {
        warnings_list <- c(
          warnings_list,
          sprintf("Question %s: Bootstrap failed (all NA)", q_id)
        )
      }
    }

    # Bayesian CI (using normal approximation for NPS)
    run_cred_flag <- q_row$Run_Credible
    if (!is.null(run_cred_flag) &&
        !is.na(run_cred_flag) &&
        toupper(run_cred_flag) == "Y") {
      prior_mean <- if (!is.na(q_row$Prior_Mean)) q_row$Prior_Mean else 0
      prior_sd   <- if (!is.na(q_row$Prior_SD))   q_row$Prior_SD   else 50  # Wide prior if not specified

      # Use normal approximation for NPS posterior
      # Likelihood: NPS ~ Normal(nps_score, se_nps^2)
      # Prior: NPS ~ Normal(prior_mean, prior_sd^2)

      p_prom <- pct_promoters / 100
      p_detr <- pct_detractors / 100
      var_prom <- p_prom * (1 - p_prom) / n_eff
      var_detr <- p_detr * (1 - p_detr) / n_eff
      se_nps <- sqrt(var_prom + var_detr) * 100

      # Posterior (normal-normal conjugate)
      precision_prior <- 1 / (prior_sd^2)
      precision_data  <- 1 / (se_nps^2)
      precision_post  <- precision_prior + precision_data

      mean_post <- (precision_prior * prior_mean + precision_data * nps_score) / precision_post
      sd_post   <- sqrt(1 / precision_post)

      # Credible interval
      alpha <- 1 - conf_level
      result$bayesian <- list(
        lower = qnorm(alpha / 2, mean = mean_post, sd = sd_post),
        upper = qnorm(1 - alpha / 2, mean = mean_post, sd = sd_post),
        posterior_mean = mean_post,
        posterior_sd = sd_post
      )
    }

  }, error = function(e) {
    warnings_list <- c(
      warnings_list,
      sprintf("Question %s: %s", q_id, conditionMessage(e))
    )
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
