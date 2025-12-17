# ==============================================================================
# CATEGORICAL KEY DRIVER ANALYSIS - MAIN ENTRY POINT
# ==============================================================================
#
# Version: 1.0
# Date: December 2024
#
# This module performs key driver analysis for categorical outcomes using:
# - Binary logistic regression (2-category outcomes)
# - Ordinal logistic regression (ordered multi-category outcomes)
# - Multinomial logistic regression (unordered multi-category outcomes)
#
# ==============================================================================

#' Run Categorical Key Driver Analysis
#'
#' Main entry point for categorical key driver analysis. Reads configuration,
#' loads data, fits appropriate logistic regression model, and generates
#' formatted Excel output.
#'
#' @param config_file Path to configuration Excel file
#' @param data_file Optional override for data file path
#' @param output_file Optional override for output file path
#' @param outcome_type Optional override: "auto", "binary", "ordinal", or "nominal"
#'
#' @return List containing:
#'   - model_result: Fitted regression model and statistics
#'   - importance: Data frame with importance metrics
#'   - odds_ratios: Detailed odds ratios table
#'   - factor_patterns: Category breakdowns by driver
#'   - diagnostics: Data quality checks
#'   - config: Processed configuration
#'
#' @examples
#' \dontrun{
#' results <- run_categorical_keydriver("project/catdriver_config.xlsx")
#' print(results$importance)
#' }
#'
#' @export
run_categorical_keydriver <- function(config_file,
                                      data_file = NULL,
                                      output_file = NULL,
                                      outcome_type = NULL) {

  # ==========================================================================
  # INITIALIZATION
  # ==========================================================================

  cat("\n")
  cat("==============================================================================\n")
  cat("  TURAS CATEGORICAL KEY DRIVER ANALYSIS v1.0\n")
  cat("==============================================================================\n")
  cat("\n")

  start_time <- Sys.time()

  # ==========================================================================
  # STEP 1: LOAD CONFIGURATION
  # ==========================================================================

  log_section(1, "Loading configuration...")

  config <- load_catdriver_config(config_file)

  # Apply overrides if provided
  if (!is.null(data_file)) {
    config$data_file <- data_file
  }
  if (!is.null(output_file)) {
    config$output_file <- output_file
  }
  if (!is.null(outcome_type)) {
    config$outcome_type <- outcome_type
  }

  log_message(paste("Analysis:", config$analysis_name), "success")
  log_message(paste("Outcome:", config$outcome_label, "(", config$outcome_var, ")"), "info")
  log_message(paste("Drivers:", length(config$driver_vars), "variables"), "info")
  log_message(paste("Data file:", basename(config$data_file)), "info")

  # ==========================================================================
  # STEP 2: LOAD DATA
  # ==========================================================================

  log_section(2, "Loading and validating data...")

  data <- load_catdriver_data(config$data_file, config)

  log_message(paste("Loaded", nrow(data), "respondents,", ncol(data), "variables"), "success")

  # Validate data
  diagnostics <- validate_catdriver_data(data, config)

  if (!diagnostics$passed) {
    cat("\n")
    log_message("ANALYSIS CANNOT PROCEED", "error")
    for (err in diagnostics$errors) {
      log_message(err, "error")
    }
    stop("Data validation failed. See errors above.", call. = FALSE)
  }

  # Report complete cases
  log_message(paste("Complete cases:", diagnostics$complete_n,
                    "(", diagnostics$pct_complete, "% of total)"), "info")

  # Show warnings
  if (length(diagnostics$warnings) > 0) {
    for (warn in diagnostics$warnings[1:min(3, length(diagnostics$warnings))]) {
      log_message(warn, "warning")
    }
  }

  # ==========================================================================
  # STEP 3: PREPROCESS DATA
  # ==========================================================================

  log_section(3, "Preparing data for analysis...")

  # Filter to complete cases
  analysis_data <- prepare_analysis_data(data, config, diagnostics)
  log_message(paste("Analysis sample:", analysis_data$n_complete, "respondents"), "info")

  # Preprocess variables
  prep_data <- preprocess_catdriver_data(analysis_data$data, config)

  # Report outcome type
  outcome_type_label <- switch(prep_data$outcome_info$type,
    binary = "Binary (2 categories)",
    ordinal = "Ordinal (ordered categories)",
    nominal = "Nominal (unordered categories)"
  )
  log_message(paste("Outcome type:", outcome_type_label), "success")
  log_message(paste("Categories:", paste(prep_data$outcome_info$categories, collapse = ", ")), "info")

  # ==========================================================================
  # STEP 4: FIT MODEL
  # ==========================================================================

  log_section(4, "Fitting regression model...")

  method_label <- switch(prep_data$outcome_info$type,
    binary = "Binary Logistic Regression",
    ordinal = "Ordinal Logistic Regression (Proportional Odds)",
    nominal = "Multinomial Logistic Regression"
  )
  log_message(paste("Method:", method_label), "info")

  model_result <- run_catdriver_model(
    prep_data,
    config,
    weights = analysis_data$weights
  )

  if (model_result$convergence) {
    log_message("Model converged successfully", "success")
  } else {
    log_message("Model convergence warning - check results", "warning")
  }

  # Report fit statistics
  fit <- model_result$fit_statistics
  if (!is.na(fit$mcfadden_r2)) {
    log_message(paste("McFadden R-squared:", sprintf("%.3f", fit$mcfadden_r2),
                      "(", interpret_pseudo_r2(fit$mcfadden_r2), ")"), "info")
  }

  # ==========================================================================
  # STEP 5: CALCULATE IMPORTANCE
  # ==========================================================================

  log_section(5, "Calculating variable importance...")

  importance <- calculate_importance(model_result, config)

  log_message(paste("Calculated importance for", nrow(importance), "drivers"), "success")

  # Report top 3
  cat("\n   Top drivers:\n")
  for (i in 1:min(3, nrow(importance))) {
    cat(sprintf("   %d. %s (%s%%)\n",
                i, importance$label[i], importance$importance_pct[i]))
  }

  # ==========================================================================
  # STEP 6: EXTRACT DETAILED RESULTS
  # ==========================================================================

  log_section(6, "Extracting detailed results...")

  # Odds ratios
  odds_ratios <- extract_odds_ratios(model_result, config, prep_data)
  log_message(paste("Extracted", nrow(odds_ratios), "odds ratio comparisons"), "info")

  # Factor patterns
  factor_patterns <- calculate_factor_patterns(prep_data, config, odds_ratios)
  log_message(paste("Generated patterns for", length(factor_patterns), "factors"), "info")

  # Check multicollinearity
  vif_check <- check_multicollinearity(model_result$model)
  if (vif_check$checked && vif_check$status == "WARNING") {
    log_message(vif_check$interpretation, "warning")
    diagnostics$warnings <- c(diagnostics$warnings, vif_check$interpretation)
  }

  # ==========================================================================
  # STEP 7: GENERATE OUTPUT
  # ==========================================================================

  log_section(7, "Generating Excel output...")

  # Compile all results
  results <- list(
    model_result = model_result,
    importance = importance,
    odds_ratios = odds_ratios,
    factor_patterns = factor_patterns,
    prep_data = prep_data,
    diagnostics = diagnostics,
    config = config,
    analysis_data = analysis_data,
    multicollinearity = vif_check
  )

  # Write Excel output
  write_catdriver_output(results, config, config$output_file)

  log_message(paste("Output saved to:", basename(config$output_file)), "success")

  # ==========================================================================
  # COMPLETION
  # ==========================================================================

  end_time <- Sys.time()
  elapsed <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 1)

  cat("\n")
  cat("==============================================================================\n")
  cat("  ANALYSIS COMPLETE\n")
  cat("==============================================================================\n")
  cat("\n")
  cat(sprintf("   Duration: %.1f seconds\n", elapsed))
  cat(sprintf("   Output: %s\n", config$output_file))
  cat("\n")

  # Print console summary
  print_console_summary(results, config)

  invisible(results)
}


#' Categorical Key Driver Analysis (Alias)
#'
#' Alias for run_categorical_keydriver for convenience.
#'
#' @inheritParams run_categorical_keydriver
#' @export
catdriver <- run_categorical_keydriver


#' Run Categorical Key Driver from Command Line
#'
#' Entry point for command-line execution.
#'
#' @keywords internal
run_catdriver_cli <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) == 0) {
    cat("Usage: Rscript run_catdriver.R <config_file> [data_file] [output_file]\n")
    quit(status = 1)
  }

  config_file <- args[1]
  data_file <- if (length(args) > 1) args[2] else NULL
  output_file <- if (length(args) > 2) args[3] else NULL

  run_categorical_keydriver(
    config_file = config_file,
    data_file = data_file,
    output_file = output_file
  )
}
