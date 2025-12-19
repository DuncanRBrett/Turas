# ==============================================================================
# CATEGORICAL KEY DRIVER ANALYSIS - MAIN ENTRY POINT
# ==============================================================================
#
# Version: 2.0
# Date: December 2024
#
# This module performs key driver analysis for categorical outcomes using:
# - Binary logistic regression (2-category outcomes)
# - Ordinal logistic regression (ordered multi-category outcomes)
# - Multinomial logistic regression (unordered multi-category outcomes)
#
# V2.0 Changes:
# - TurasGuard layer for explicit hard/soft failure handling
# - Canonical design-matrix mapper (no more substring parsing)
# - Per-variable missing data strategies
# - Rare level policy with deterministic collapsing
# - Robust fit wrappers with fallback estimators
# - Direction sanity check for ordinal outcomes
# - Probability lift interpretation
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
#' @param outcome_type Optional override: "binary", "ordinal", or "multinomial"
#'
#' @return List containing:
#'   - model_result: Fitted regression model and statistics
#'   - importance: Data frame with importance metrics
#'   - odds_ratios: Detailed odds ratios table
#'   - factor_patterns: Category breakdowns by driver
#'   - diagnostics: Data quality checks
#'   - guard: Guard state with warnings and flags
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
  # TOP-LEVEL REFUSAL HANDLER
  # ==========================================================================
  # Catch catdriver_refusal conditions and display them cleanly
  # without stack traces - they are intentional stops, not crashes.

  tryCatch(
    run_categorical_keydriver_impl(config_file, data_file, output_file, outcome_type),
    catdriver_refusal = function(e) {
      # Print the refusal message cleanly (no "Error:" prefix, no stack trace)
      cat(conditionMessage(e))

      # Return a refusal result object
      invisible(structure(
        list(
          refused = TRUE,
          reason = e$reason,
          message = conditionMessage(e)
        ),
        class = "catdriver_refusal_result"
      ))
    }
  )
}


#' Internal Implementation of Categorical Key Driver Analysis
#'
#' @keywords internal
run_categorical_keydriver_impl <- function(config_file,
                                           data_file = NULL,
                                           output_file = NULL,
                                           outcome_type = NULL) {

  # ==========================================================================
  # INITIALIZATION
  # ==========================================================================

  cat("\n")
  cat("==============================================================================\n")
  cat("  TURAS CATEGORICAL KEY DRIVER ANALYSIS v2.0\n")
  cat("==============================================================================\n")
  cat("\n")

  start_time <- Sys.time()

  # Initialize guard state for tracking warnings and issues
  guard <- guard_init()

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

  log_section(2, "Loading data...")

  data <- load_catdriver_data(config$data_file, config)

  log_message(paste("Loaded", nrow(data), "respondents,", ncol(data), "variables"), "success")

  # ==========================================================================
  # STEP 3: RUN PRE-ANALYSIS GUARDS
  # ==========================================================================

  log_section(3, "Validating configuration and data...")

  # Run guard validations (will hard error if critical issues)
  guard <- guard_pre_analysis(config, data)

  log_message("Configuration validated", "success")

  # Basic data validation
  diagnostics <- validate_catdriver_data(data, config)

  if (!diagnostics$passed) {
    catdriver_refuse(
      reason = "DATA_VALIDATION_FAILED",
      title = "DATA VALIDATION FAILED",
      problem = "Data does not meet minimum requirements for analysis.",
      why_it_matters = "Analysis cannot proceed with invalid or insufficient data.",
      fix = "Review the errors below and correct your data or configuration.",
      details = paste0("ERRORS:\n  - ", paste(diagnostics$errors, collapse = "\n  - "))
    )
  }

  log_message(paste("Original sample:", diagnostics$original_n, "respondents"), "info")

  # ==========================================================================
  # STEP 4: HANDLE MISSING DATA
  # ==========================================================================

  log_section(4, "Handling missing data...")

  missing_result <- handle_missing_data(data, config)
  data <- missing_result$data

  log_message(paste("Missing data handled:",
                    missing_result$missing_report$summary$total_rows_dropped,
                    "rows dropped"), "info")
  log_message(paste("Retained:", nrow(data), "respondents (",
                    missing_result$missing_report$summary$pct_retained, "%)"), "success")

  # ==========================================================================
  # STEP 5: APPLY RARE LEVEL POLICY
  # ==========================================================================

  log_section(5, "Applying rare level policy...")

  rare_result <- apply_rare_level_policy(data, config)
  data <- rare_result$data

  # Report collapsing
  n_collapsed <- sum(sapply(rare_result$collapse_report, function(x) {
    if (x$action == "collapsed") length(x$rare_levels) else 0
  }))

  if (n_collapsed > 0) {
    log_message(paste("Collapsed", n_collapsed, "rare levels"), "warning")
    guard <- guard_check_collapsing(guard, rare_result$collapse_report)
  } else {
    log_message("No rare level collapsing required", "success")
  }

  # Warn about sparse cells
  if (length(rare_result$cell_warnings) > 0) {
    for (var_name in names(rare_result$cell_warnings)) {
      warn_info <- rare_result$cell_warnings[[var_name]]
      log_message(paste("Sparse cells in", var_name, "- min cell:", warn_info$min_cell), "warning")
    }
  }

  # ==========================================================================
  # STEP 6: PREPROCESS DATA
  # ==========================================================================

  log_section(6, "Preparing data for analysis...")

  # Prepare weights
  weights <- NULL
  if (!is.null(config$weight_var) && config$weight_var %in% names(data)) {
    weights <- data[[config$weight_var]]
    weights[is.na(weights)] <- 1
    weights[weights < 0] <- 0
    log_message(paste("Using weights from:", config$weight_var), "info")
  }

  # Preprocess variables
  prep_data <- preprocess_catdriver_data(data, config)

  # Report outcome type
  outcome_type_label <- switch(prep_data$outcome_info$type,
    binary = "Binary (2 categories)",
    ordinal = "Ordinal (ordered categories)",
    nominal = "Nominal (unordered categories)",
    multinomial = "Multinomial (unordered categories)"
  )
  log_message(paste("Outcome type:", outcome_type_label), "success")
  log_message(paste("Categories:", paste(prep_data$outcome_info$categories, collapse = " < ")), "info")

  # ==========================================================================
  # STEP 7: FIT MODEL
  # ==========================================================================

  log_section(7, "Fitting regression model...")

  method_label <- switch(prep_data$outcome_info$type,
    binary = "Binary Logistic Regression",
    ordinal = "Ordinal Logistic Regression (Proportional Odds)",
    nominal = "Multinomial Logistic Regression",
    multinomial = "Multinomial Logistic Regression"
  )
  log_message(paste("Method:", method_label), "info")

  model_result <- run_catdriver_model(
    prep_data,
    config,
    weights = weights,
    guard = guard
  )

  # Update guard from model result
  if (!is.null(model_result$guard)) {
    guard <- model_result$guard
  }

  if (model_result$convergence) {
    log_message("Model converged successfully", "success")
  } else {
    log_message("Model convergence warning - check results", "warning")
  }

  # Report fallback usage
  if (isTRUE(model_result$fallback_used)) {
    log_message(paste("Fallback estimator used:", model_result$engine_used), "warning")
  } else if (!is.null(model_result$engine_used)) {
    log_message(paste("Engine:", model_result$engine_used), "info")
  }

  # Report fit statistics
  fit <- model_result$fit_statistics
  if (!is.na(fit$mcfadden_r2)) {
    log_message(paste("McFadden R-squared:", sprintf("%.3f", fit$mcfadden_r2),
                      "(", interpret_pseudo_r2(fit$mcfadden_r2), ")"), "info")
  }

  # ==========================================================================
  # STEP 8: POST-MODEL GUARDS
  # ==========================================================================

  log_section(8, "Running post-model validations...")

  guard <- guard_post_model(guard, prep_data, model_result, config)

  # Check multicollinearity
  vif_check <- check_multicollinearity(model_result$model)
  if (vif_check$checked) {
    if (vif_check$status == "WARNING") {
      log_message(vif_check$interpretation, "warning")
      guard <- guard_check_multicollinearity(guard, vif_check)
    } else {
      log_message("Multicollinearity check: OK", "success")
    }
  }

  # Report guard status
  guard_status <- guard_summary(guard)
  if (guard_status$has_issues) {
    log_message(paste("Stability flags:", length(guard_status$stability_flags)), "warning")
  } else {
    log_message("All quality checks passed", "success")
  }

  # ==========================================================================
  # STEP 9: CALCULATE IMPORTANCE
  # ==========================================================================

  log_section(9, "Calculating variable importance...")

  importance <- calculate_importance(model_result, config)

  # Add stability flag column
  importance$stability_flag <- if (guard_status$use_with_caution) {
    "Use with caution"
  } else {
    "OK"
  }

  log_message(paste("Calculated importance for", nrow(importance), "drivers"), "success")

  # Report top 3
  cat("\n   Top drivers:\n")
  for (i in 1:min(3, nrow(importance))) {
    cat(sprintf("   %d. %s (%s%%)\n",
                i, importance$label[i], importance$importance_pct[i]))
  }

  # ==========================================================================
  # STEP 10: EXTRACT DETAILED RESULTS
  # ==========================================================================

  log_section(10, "Extracting detailed results...")

  # Create term-level mapping (REQUIRED - no legacy fallback)
  term_mapping <- tryCatch({
    if (prep_data$outcome_info$type %in% c("multinomial", "nominal")) {
      map_multinomial_terms(model_result$model, prep_data$data,
                           prep_data$model_formula, config$outcome_var)
    } else {
      map_terms_to_levels(model_result$model, prep_data$data,
                         prep_data$model_formula)
    }
  }, error = function(e) {
    # HARD STOP - no legacy fallback allowed
    catdriver_refuse(
      reason = "term_mapping_failed",
      message = paste0(
        "Cannot create canonical term-to-level mapping.\n\n",
        "Error: ", e$message, "\n\n",
        "This mapping is required for correct odds ratio interpretation.\n",
        "Possible causes:\n",
        "  - Model did not converge properly\n",
        "  - Unexpected coefficient naming from model\n",
        "  - Data structure incompatible with expected design matrix\n\n",
        "Please check your data and configuration, or contact support."
      )
    )
  })

  # HARD GATE: Validate mapping covers all model coefficients (no silent partial mapping)
  # Extract coefficient names based on model type
  model_coef_names <- tryCatch({
    coefs <- coef(model_result$model)
    if (is.matrix(coefs)) {
      # Multinomial: coef() returns matrix, column names are coefficient names
      colnames(coefs)
    } else {
      # Binary/Ordinal: coef() returns named vector
      names(coefs)
    }
  }, error = function(e) {
    character(0)  # If we can't extract, validation will catch it
  })

  validate_mapping(term_mapping, model_coef_names)
  log_message("Term mapping validated - all coefficients mapped", "info")

  # Extract odds ratios using canonical mapping (no legacy fallback)
  odds_ratios <- extract_odds_ratios_mapped(model_result, term_mapping, config)
  log_message(paste("Extracted", nrow(odds_ratios), "odds ratio comparisons"), "info")

  # Calculate probability lift (new in v2.0)
  prob_lift <- calculate_probability_lift(model_result, prep_data, config)

  # Factor patterns
  factor_patterns <- calculate_factor_patterns(prep_data, config, odds_ratios)
  log_message(paste("Generated patterns for", length(factor_patterns), "factors"), "info")

  # ==========================================================================
  # STEP 11: GENERATE OUTPUT
  # ==========================================================================

  log_section(11, "Generating Excel output...")

  # Compile all results
  results <- list(
    model_result = model_result,
    importance = importance,
    odds_ratios = odds_ratios,
    probability_lift = prob_lift,
    factor_patterns = factor_patterns,
    prep_data = prep_data,
    term_mapping = term_mapping,
    missing_report = missing_result$missing_report,
    collapse_report = rare_result$collapse_report,
    diagnostics = diagnostics,
    guard = guard,
    guard_summary = guard_status,
    multicollinearity = vif_check,
    config = config
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

  # Report any warnings
  if (guard_status$has_issues) {
    cat("\n   WARNINGS:\n")
    for (flag in guard_status$stability_flags) {
      cat(sprintf("   - %s\n", flag))
    }
  }

  cat("\n")

  # Print console summary
  print_console_summary(results, config)

  invisible(results)
}


#' Calculate Probability Lift
#'
#' Calculates predicted probability differences for each driver level.
#'
#' @param model_result Model results
#' @param prep_data Preprocessed data
#' @param config Configuration list
#' @return Data frame with probability lift metrics
#' @keywords internal
calculate_probability_lift <- function(model_result, prep_data, config) {

  # Get predicted probabilities
  pred_probs <- model_result$predicted_probs

  if (is.null(pred_probs)) {
    return(NULL)
  }

  data <- prep_data$data
  outcome_var <- config$outcome_var

  lift_list <- list()

  for (driver_var in config$driver_vars) {
    driver_data <- data[[driver_var]]

    if (!is.factor(driver_data)) next

    driver_levels <- levels(driver_data)
    ref_level <- driver_levels[1]

    for (level in driver_levels) {
      level_mask <- driver_data == level

      if (sum(level_mask) == 0) next

      # Get mean predicted probability for this level
      if (is.matrix(pred_probs)) {
        # Binary or ordinal: use last column (highest outcome)
        mean_prob <- mean(pred_probs[level_mask, ncol(pred_probs)], na.rm = TRUE)
        ref_prob <- mean(pred_probs[driver_data == ref_level, ncol(pred_probs)], na.rm = TRUE)
      } else if (is.vector(pred_probs)) {
        # Binary: direct
        mean_prob <- mean(pred_probs[level_mask], na.rm = TRUE)
        ref_prob <- mean(pred_probs[driver_data == ref_level], na.rm = TRUE)
      } else {
        next
      }

      lift_list[[length(lift_list) + 1]] <- data.frame(
        driver = driver_var,
        driver_label = get_var_label(config, driver_var),
        level = level,
        is_reference = level == ref_level,
        mean_predicted_prob = round(mean_prob, 3),
        reference_prob = round(ref_prob, 3),
        prob_lift = round(mean_prob - ref_prob, 3),
        prob_lift_pct = round(100 * (mean_prob - ref_prob), 1),
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(lift_list) == 0) {
    return(NULL)
  }

  do.call(rbind, lift_list)
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
