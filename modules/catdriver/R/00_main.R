# ==============================================================================
# CATEGORICAL KEY DRIVER ANALYSIS - MAIN ENTRY POINT
# ==============================================================================
#
# Version: 1.1 (TRS Hardening)
# Date: December 2024
# Compliance: TRS v1.0 (TURAS_Categorical_Key_Driver_Hardening_v1.1.md)
#
# This module performs key driver analysis for categorical outcomes using:
# - Binary logistic regression (2-category outcomes)
# - Ordinal logistic regression (ordered multi-category outcomes)
# - Multinomial logistic regression (unordered multi-category outcomes)
#
# V1.1 (Hardening) Changes:
# - Full TRS v1.0 compliance
# - Explicit run_status tracking (PASS/PARTIAL)
# - Warning elimination: degraded outputs via PARTIAL status
# - TRS-compliant console banners
# - All outputs include run_status, degraded, degraded_reasons
#
# V2.0 (Base) Features:
# - TurasGuard layer for explicit hard/soft failure handling
# - Canonical design-matrix mapper (no more substring parsing)
# - Per-variable missing data strategies
# - Rare level policy with deterministic collapsing
# - Robust fit wrappers with fallback estimators
# - Direction sanity check for ordinal outcomes
# - Probability lift interpretation
#
# ==============================================================================

CATDRIVER_VERSION <- "1.1"

# ==============================================================================
# TRS GUARD LAYER (Must be first)
# ==============================================================================

# Source TRS guard layer for refusal handling
.get_script_dir_for_guard <- function() {
  if (exists("script_dir_override", envir = globalenv())) {
    return(get("script_dir_override", envir = globalenv()))
  }
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(sub("^--file=", "", file_arg)))
  return(getwd())
}

.guard_path <- file.path(.get_script_dir_for_guard(), "00_guard.R")
if (!file.exists(.guard_path)) {
  .guard_path <- file.path(.get_script_dir_for_guard(), "R", "00_guard.R")
}
if (!file.exists(.guard_path)) {
  # Try modules path
  .guard_path <- file.path(getwd(), "modules", "catdriver", "R", "00_guard.R")
}
if (file.exists(.guard_path)) {
  source(.guard_path)
}

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

# Source TRS run state management
.source_trs_infrastructure <- function() {
  base_dir <- .get_script_dir_for_guard()

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
  .source_trs_infrastructure()
}, error = function(e) {
  message(sprintf("[TRS INFO] CATD_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# ==============================================================================
# MAIN ENTRY POINT
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
#' @param progress_callback Optional callback function for GUI progress updates.
#'   Function should accept (value, message) where value is 0-1 progress.
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
                                      outcome_type = NULL,
                                      progress_callback = NULL) {

  # ==========================================================================
  # TOP-LEVEL REFUSAL HANDLER (TRS v1.0)
  # ==========================================================================
  # Use shared with_refusal_handler() to catch BOTH turas_refusal and
  # catdriver_refusal conditions, plus unexpected errors. This ensures
  # consistent handling per TRS v1.0 requirements.

  with_refusal_handler(
    run_categorical_keydriver_impl(config_file, data_file, output_file, outcome_type, progress_callback)
  )
}


#' Internal Implementation of Categorical Key Driver Analysis
#'
#' @keywords internal
run_categorical_keydriver_impl <- function(config_file,
                                           data_file = NULL,
                                           output_file = NULL,
                                           outcome_type = NULL,
                                           progress_callback = NULL) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION (TRS v1.0)
  # ==========================================================================

  # Helper function for progress updates (11 steps total)
  update_progress <- function(step, message) {
    if (!is.null(progress_callback) && is.function(progress_callback)) {
      progress_callback(step / 11, message)
    }
  }

  # Create TRS run state for tracking events
  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("CATDRIVER")
  } else {
    NULL
  }

  start_time <- Sys.time()

  # TRS v1.0: Start banner - use shared if available, fallback to local
  if (exists("turas_print_start_banner", mode = "function")) {
    turas_print_start_banner("CATDRIVER", CATDRIVER_VERSION)
  } else {
    trs_banner_start("CATEGORICAL KEY DRIVER ANALYSIS", "1.1")
  }

  # Initialize guard state for tracking warnings and issues
  guard <- guard_init()

  # TRS v1.0: Track degraded outputs for PARTIAL status
  degraded_reasons <- character(0)
  affected_outputs <- character(0)

  # ==========================================================================
  # STEP 1: LOAD CONFIGURATION
  # ==========================================================================

  update_progress(1, "Loading configuration...")
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

  # TRS: Print config fingerprint for traceability
  config_mtime <- file.info(config$config_file)$mtime
  cat("\n   [CONFIG FINGERPRINT]\n")
  cat("   Path: ", config$config_file, "\n", sep = "")
  cat("   Modified: ", format(config_mtime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")

  # Show effective order sources for each driver
  has_driver_settings <- !is.null(config$driver_settings) &&
                         is.data.frame(config$driver_settings) &&
                         nrow(config$driver_settings) > 0

  for (drv in config$driver_vars) {
    order_vec <- NULL
    order_source <- "none"

    if (has_driver_settings) {
      settings_idx <- which(config$driver_settings$driver == drv)
      if (length(settings_idx) > 0) {
        settings_order <- config$driver_settings$levels_order[settings_idx[1]]
        if (!is.null(settings_order) && !is.na(settings_order) && nzchar(trimws(settings_order))) {
          order_vec <- trimws(strsplit(settings_order, ";")[[1]])
          order_source <- "Driver_Settings"
        }
      }
    }

    if (is.null(order_vec) || length(order_vec) == 0) {
      order_vec <- config$driver_orders[[drv]]
      if (!is.null(order_vec) && length(order_vec) > 0) {
        order_source <- "Variables"
      }
    }

    if (!is.null(order_vec) && length(order_vec) > 0) {
      cat("   Driver '", drv, "' order from ", order_source, ": [",
          paste(order_vec, collapse = ";"), "]\n", sep = "")
    }
  }
  cat("\n")

  # ==========================================================================
  # STEP 2: LOAD DATA
  # ==========================================================================

  update_progress(2, "Loading data...")
  log_section(2, "Loading data...")

  data <- load_catdriver_data(config$data_file, config)

  log_message(paste("Loaded", nrow(data), "respondents,", ncol(data), "variables"), "success")

  # ==========================================================================
  # STEP 3: RUN PRE-ANALYSIS GUARDS
  # ==========================================================================

  update_progress(3, "Validating configuration and data...")
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

  update_progress(4, "Handling missing data...")
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

  update_progress(5, "Applying rare level policy...")
  log_section(5, "Applying rare level policy...")

  rare_result <- apply_rare_level_policy(data, config)
  data <- rare_result$data

  # Report collapsing - TRS v1.0: track as degraded output
  n_collapsed <- sum(sapply(rare_result$collapse_report, function(x) {
    if (x$action == "collapsed") length(x$rare_levels) else 0
  }))

  if (n_collapsed > 0) {
    cat("   [PARTIAL] Collapsed", n_collapsed, "rare levels\n")
    guard <- guard_check_collapsing(guard, rare_result$collapse_report)
    degraded_reasons <- c(degraded_reasons,
      paste0("Rare level collapsing applied: ", n_collapsed, " levels collapsed"))
    affected_outputs <- c(affected_outputs, "Odds ratios", "Factor patterns")
  } else {
    cat("   [OK] No rare level collapsing required\n")
  }

  # TRS v1.0: Sparse cells -> PARTIAL, not warning
  if (length(rare_result$cell_warnings) > 0) {
    for (var_name in names(rare_result$cell_warnings)) {
      warn_info <- rare_result$cell_warnings[[var_name]]
      cat("   [PARTIAL] Sparse cells in", var_name, "- min cell:", warn_info$min_cell, "\n")
      degraded_reasons <- c(degraded_reasons,
        paste0("Sparse cells in ", var_name, " (min cell: ", warn_info$min_cell, ")"))
    }
    affected_outputs <- unique(c(affected_outputs, "Odds ratio confidence intervals"))
  }

  # ==========================================================================
  # STEP 6: PREPROCESS DATA
  # ==========================================================================

  update_progress(6, "Preparing data for analysis...")
  log_section(6, "Preparing data for analysis...")

  # Prepare weights
  weights <- NULL
  weight_diagnostics <- NULL
  if (!is.null(config$weight_var) && config$weight_var %in% names(data)) {
    weights <- data[[config$weight_var]]
    weights[is.na(weights)] <- 1
    weights[weights < 0] <- 0
    log_message(paste("Using weights from:", config$weight_var), "info")

    # Calculate weight diagnostics
    weight_diagnostics <- calculate_weight_diagnostics(weights)
    if (!is.null(weight_diagnostics)) {
      log_message(paste("Weight range:", round(weight_diagnostics$min_weight, 3),
                        "-", round(weight_diagnostics$max_weight, 3)), "info")
      log_message(paste("Effective n:", round(weight_diagnostics$effective_n, 0),
                        "(design effect:", round(weight_diagnostics$design_effect, 2), ")"), "info")
      if (weight_diagnostics$has_extreme_weights) {
        cat("   [PARTIAL] Extreme weights detected (ratio > 10)\n")
        degraded_reasons <- c(degraded_reasons,
          paste0("Extreme weights detected (max/min = ", round(weight_diagnostics$weight_ratio, 1), ")"))
        affected_outputs <- c(affected_outputs, "Standard errors", "Confidence intervals")
      }
    }
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

  update_progress(7, "Fitting regression model...")
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

  # TRS v1.0: Convergence issues -> PARTIAL status
  if (model_result$convergence) {
    cat("   [OK] Model converged successfully\n")
  } else {
    cat("   [PARTIAL] Model convergence warning - check results\n")
    degraded_reasons <- c(degraded_reasons, "Model convergence warning - results may be unstable")
    affected_outputs <- unique(c(affected_outputs, "Odds ratios", "Confidence intervals", "P-values"))
  }

  # TRS v1.0: Fallback usage -> PARTIAL status
  if (isTRUE(model_result$fallback_used)) {
    cat("   [PARTIAL] Fallback estimator used:", model_result$engine_used, "\n")
    degraded_reasons <- c(degraded_reasons,
      paste0("Fallback estimator used: ", model_result$engine_used))
    affected_outputs <- unique(c(affected_outputs, "Standard errors"))
  } else if (!is.null(model_result$engine_used)) {
    cat("   [INFO] Engine:", model_result$engine_used, "\n")
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

  update_progress(8, "Running post-model validations...")
  log_section(8, "Running post-model validations...")

  guard <- guard_post_model(guard, prep_data, model_result, config)

  # Check multicollinearity - TRS v1.0: track as PARTIAL
  vif_check <- check_multicollinearity(model_result$model)
  if (vif_check$checked) {
    if (vif_check$status == "WARNING") {
      cat("   [PARTIAL]", vif_check$interpretation, "\n")
      guard <- guard_check_multicollinearity(guard, vif_check)
      degraded_reasons <- c(degraded_reasons, vif_check$interpretation)
      affected_outputs <- unique(c(affected_outputs, "Relative importance scores"))
    } else {
      cat("   [OK] Multicollinearity check: OK\n")
    }
  }

  # Report guard status
  guard_status <- guard_summary(guard)
  if (guard_status$has_issues) {
    cat("   [PARTIAL] Stability flags:", length(guard_status$stability_flags), "\n")
    for (flag in guard_status$stability_flags) {
      degraded_reasons <- c(degraded_reasons, flag)
    }
  } else {
    cat("   [OK] All quality checks passed\n")
  }

  # ==========================================================================
  # STEP 9: CALCULATE IMPORTANCE
  # ==========================================================================

  update_progress(9, "Calculating variable importance...")
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

  update_progress(10, "Extracting detailed results...")
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
    # HARD REFUSAL - cannot validate mapping without coefficient names
    catdriver_refuse(
      reason = "MODEL_COEF_EXTRACT_FAILED",
      title = "CANNOT VALIDATE TERM MAPPING",
      problem = "Failed to extract coefficient names from the fitted model.",
      why_it_matters = "Without coefficient names, CatDriver cannot prove that every model term is mapped correctly.",
      fix = "Check model convergence and model type; ensure required packages are installed; then re-run.",
      details = paste0("Error: ", e$message)
    )
  })

  validate_mapping(term_mapping, model_coef_names)
  log_message("Term mapping validated - all coefficients mapped", "info")

  # Extract odds ratios using canonical mapping (no legacy fallback)
  odds_ratios <- extract_odds_ratios_mapped(model_result, term_mapping, config)
  log_message(paste("Extracted", nrow(odds_ratios), "odds ratio comparisons"), "info")

  # Bootstrap confidence intervals (optional)
  bootstrap_results <- NULL
  do_bootstrap <- as.logical(config$bootstrap_ci) %in% TRUE
  if (do_bootstrap && prep_data$outcome_info$type != "multinomial") {
    log_message(paste0("Running bootstrap (", config$bootstrap_reps, " resamples)..."), "info")
    cat("   [INFO] Bootstrap may take 1-3 minutes\n")

    # Build formula for bootstrap
    boot_formula <- as.formula(paste(
      config$outcome_var, "~",
      paste(config$driver_vars, collapse = " + ")
    ))

    bootstrap_results <- run_bootstrap_or(
      data = prep_data$analysis_data,
      formula = boot_formula,
      outcome_type = prep_data$outcome_info$type,
      weights = weights,
      n_boot = config$bootstrap_reps,
      conf_level = config$confidence_level,
      progress_callback = NULL  # Could add GUI callback here
    )

    if (!is.null(bootstrap_results)) {
      log_message(paste0("Bootstrap complete (", bootstrap_results$n_successful, "/",
                         bootstrap_results$n_boot, " successful)"), "success")

      # Add bootstrap columns to odds_ratios
      for (i in seq_len(nrow(odds_ratios))) {
        term <- odds_ratios$term[i]
        if (term %in% bootstrap_results$term) {
          idx <- which(bootstrap_results$term == term)
          odds_ratios$boot_median_or[i] <- bootstrap_results$median_or[idx]
          odds_ratios$boot_ci_lower[i] <- bootstrap_results$ci_lower[idx]
          odds_ratios$boot_ci_upper[i] <- bootstrap_results$ci_upper[idx]
          odds_ratios$sign_stability[i] <- bootstrap_results$sign_consistency[idx]
        } else {
          odds_ratios$boot_median_or[i] <- NA
          odds_ratios$boot_ci_lower[i] <- NA
          odds_ratios$boot_ci_upper[i] <- NA
          odds_ratios$sign_stability[i] <- NA
        }
      }
    }
  }

  # Calculate probability lift (new in v2.0)
  prob_lift <- calculate_probability_lift(model_result, prep_data, config)

  # Factor patterns
  factor_patterns <- calculate_factor_patterns(prep_data, config, odds_ratios)
  log_message(paste("Generated patterns for", length(factor_patterns), "factors"), "info")

  # ==========================================================================
  # STEP 11: GENERATE OUTPUT
  # ==========================================================================

  update_progress(11, "Generating Excel output...")
  log_section(11, "Generating Excel output...")

  # ==========================================================================
  # DETERMINE FINAL STATUS (TRS v1.0) - Must happen BEFORE output generation
  # ==========================================================================

  # Deduplicate degraded reasons
  degraded_reasons <- unique(degraded_reasons)
  affected_outputs <- unique(affected_outputs)

  # Determine run_status
  if (length(degraded_reasons) > 0) {
    run_status <- "PARTIAL"
    status <- trs_status_partial(
      module = "CATDRIVER",
      degraded_reasons = degraded_reasons,
      affected_outputs = affected_outputs
    )
  } else {
    run_status <- "PASS"
    status <- trs_status_pass(module = "CATDRIVER")
  }

  # Compile all results (including status for Run_Status sheet)
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
    weight_diagnostics = weight_diagnostics,
    bootstrap_results = bootstrap_results,
    config = config,
    # TRS v1.0: Include status fields for Run_Status sheet
    run_status = run_status,
    status = status,
    degraded = length(degraded_reasons) > 0,
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )

  # Write Excel output
  write_catdriver_output(results, config, config$output_file)

  log_message(paste("Output saved to:", basename(config$output_file)), "success")

  # ==========================================================================
  # COMPLETION
  # ==========================================================================

  end_time <- Sys.time()
  elapsed <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 1)

  # ==========================================================================
  # TRS: Log PARTIAL events for any degraded outputs
  # ==========================================================================
  if (!is.null(trs_state) && length(degraded_reasons) > 0) {
    for (reason in degraded_reasons) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(
          trs_state,
          "CATD_DEGRADED",
          "Degraded output",
          problem = reason
        )
      }
    }
  }

  # ==========================================================================
  # TRS: Get run result
  # ==========================================================================
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }
  results$run_result <- run_result

  # TRS v1.0: End banner - use shared if available, fallback to local
  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else {
    trs_banner_end("CATEGORICAL KEY DRIVER ANALYSIS", status, elapsed)
  }

  cat(sprintf("   Output: %s\n", config$output_file))

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
