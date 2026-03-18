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
                                      progress_callback = NULL,
                                      config_overrides = NULL) {

  # ==========================================================================
  # TOP-LEVEL REFUSAL HANDLER (TRS v1.0)
  # ==========================================================================
  # Use shared with_refusal_handler() to catch BOTH turas_refusal and
  # catdriver_refusal conditions, plus unexpected errors. This ensures
  # consistent handling per TRS v1.0 requirements.

  with_refusal_handler(
    run_categorical_keydriver_impl(config_file, data_file, output_file, outcome_type,
                                   progress_callback, config_overrides)
  )
}


#' Internal Implementation of Categorical Key Driver Analysis
#'
#' @keywords internal
run_categorical_keydriver_impl <- function(config_file,
                                           data_file = NULL,
                                           output_file = NULL,
                                           outcome_type = NULL,
                                           progress_callback = NULL,
                                           config_overrides = NULL) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION (TRS v1.0)
  # ==========================================================================

  # Helper function for progress updates
  TOTAL_STEPS <- 11L
  update_progress <- function(step, message) {
    if (!is.null(progress_callback) && is.function(progress_callback)) {
      progress_callback(step / TOTAL_STEPS, message)
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

  # Apply arbitrary config overrides (e.g., from GUI)
  if (!is.null(config_overrides) && is.list(config_overrides)) {
    for (key in names(config_overrides)) {
      config[[key]] <- config_overrides[[key]]
    }
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
  # SUBGROUP DETECTION & BRANCHING
  # ==========================================================================

  subgroup_active <- !is.null(config$subgroup_var) && nzchar(config$subgroup_var)
  subgroup_comparison <- NULL

  if (subgroup_active) {
    # Build the list of subgroups to analyse
    subgroup_col <- data[[config$subgroup_var]]
    subgroup_levels <- sort(unique(as.character(na.omit(subgroup_col))))

    run_list <- list()
    if (isTRUE(config$subgroup_include_total)) {
      run_list[["Total"]] <- data
    }
    for (lvl in subgroup_levels) {
      run_list[[lvl]] <- data[!is.na(subgroup_col) & as.character(subgroup_col) == lvl, , drop = FALSE]
    }

    cat("\n")
    log_message(sprintf(
      "Subgroup analysis activated: splitting by '%s' (%d groups: %s)",
      config$subgroup_var, length(run_list), paste(names(run_list), collapse = ", ")
    ), "info")

    subgroup_results <- list()

    for (group_name in names(run_list)) {
      group_data <- run_list[[group_name]]
      group_n <- nrow(group_data)

      cat("\n")
      cat(paste(rep("=", 60), collapse = ""), "\n")
      cat(sprintf("  SUBGROUP: %s (n=%d)\n", group_name, group_n))
      cat(paste(rep("=", 60), collapse = ""), "\n")

      # Soft guard: check minimum sample size
      guard <- guard_check_subgroup_sample_size(
        guard, group_name, group_n, config$subgroup_min_n
      )

      # Run Steps 4-10 in tryCatch for graceful per-group failure
      group_result <- tryCatch({
        run_catdriver_steps_4_to_10(
          group_data, config, guard,
          degraded_reasons, affected_outputs,
          update_progress, group_label = group_name
        )
      }, turas_refusal = function(e) {
        cat(sprintf("   [PARTIAL] Subgroup '%s' REFUSED: %s\n",
                    group_name, conditionMessage(e)))
        guard <<- guard_check_subgroup_model_failed(guard, group_name, conditionMessage(e))
        degraded_reasons <<- c(degraded_reasons,
          sprintf("Subgroup '%s' failed: %s", group_name, e$code %||% "UNKNOWN"))
        list(status = "REFUSED", group_name = group_name,
             code = e$code %||% "UNKNOWN", message = conditionMessage(e))
      }, catdriver_refusal = function(e) {
        cat(sprintf("   [PARTIAL] Subgroup '%s' REFUSED: %s\n",
                    group_name, conditionMessage(e)))
        guard <<- guard_check_subgroup_model_failed(guard, group_name, conditionMessage(e))
        degraded_reasons <<- c(degraded_reasons,
          sprintf("Subgroup '%s' failed: %s", group_name, e$code %||% "UNKNOWN"))
        list(status = "REFUSED", group_name = group_name,
             code = e$code %||% "UNKNOWN", message = conditionMessage(e))
      }, error = function(e) {
        cat(sprintf("   [PARTIAL] Subgroup '%s' ERROR: %s\n",
                    group_name, e$message))
        guard <<- guard_check_subgroup_model_failed(guard, group_name, e$message)
        degraded_reasons <<- c(degraded_reasons,
          sprintf("Subgroup '%s' error: %s", group_name, e$message))
        list(status = "ERROR", group_name = group_name, message = e$message)
      })

      group_result$group_name <- group_name
      group_result$group_n <- group_n
      subgroup_results[[group_name]] <- group_result

      # Collect degraded reasons from per-group analysis
      if (!is.null(group_result$degraded_reasons)) {
        for (dr in group_result$degraded_reasons) {
          degraded_reasons <- c(degraded_reasons, sprintf("[%s] %s", group_name, dr))
        }
      }
      if (!is.null(group_result$affected_outputs)) {
        affected_outputs <- c(affected_outputs, group_result$affected_outputs)
      }
    }

    # Build comparison
    if (exists("build_subgroup_comparison", mode = "function")) {
      subgroup_comparison <- tryCatch(
        build_subgroup_comparison(subgroup_results, config),
        error = function(e) {
          cat(sprintf("   [WARNING] Subgroup comparison generation failed: %s\n", e$message))
          NULL
        }
      )
    }

    # Use "Total" as the primary result (backward compat for existing output)
    # If no Total, use first successful subgroup
    primary_name <- if ("Total" %in% names(subgroup_results) &&
                        subgroup_results[["Total"]]$status %in% c("PASS", "PARTIAL")) {
      "Total"
    } else {
      successful_names <- names(Filter(
        function(r) r$status %in% c("PASS", "PARTIAL"), subgroup_results))
      if (length(successful_names) > 0) successful_names[1] else NULL
    }

    if (is.null(primary_name)) {
      catdriver_refuse(
        reason = "SUBGROUP_ALL_FAILED",
        title = "ALL SUBGROUP ANALYSES FAILED",
        problem = "No subgroup produced a successful model fit.",
        why_it_matters = "Cannot generate any output without at least one successful subgroup.",
        fix = "Check the data quality and sample sizes for each subgroup."
      )
    }

    # Extract primary result fields for backward-compatible Step 11
    primary <- subgroup_results[[primary_name]]
    model_result <- primary$model_result
    importance <- primary$importance
    odds_ratios <- primary$odds_ratios
    prob_lift <- primary$probability_lift
    factor_patterns <- primary$factor_patterns
    prep_data <- primary$prep_data
    term_mapping <- primary$term_mapping
    missing_result <- list(missing_report = primary$missing_report)
    rare_result <- list(collapse_report = primary$collapse_report)
    vif_check <- primary$multicollinearity %||% list(checked = FALSE)
    weight_diagnostics <- primary$weight_diagnostics
    bootstrap_results <- primary$bootstrap_results
    guard_status <- if (!is.null(primary$guard)) guard_summary(primary$guard) else guard_summary(guard)

    log_message(sprintf("Subgroup analysis complete. Primary result: %s", primary_name), "success")

  } else {
    # ========================================================================
    # NON-SUBGROUP PATH (original Steps 4-10, unchanged)
    # ========================================================================

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
      reason = "MAPPER_TERM_MAPPING_FAILED",
      title = "TERM MAPPING FAILED",
      problem = paste0("Cannot create canonical term-to-level mapping.\nError: ", e$message),
      why_it_matters = "This mapping is required for correct odds ratio interpretation. Without it, CatDriver cannot guarantee which factor level each coefficient belongs to.",
      fix = paste0(
        "Possible causes and solutions:\n",
        "  1. Model did not converge - check for sparse cells or separation\n",
        "  2. Unexpected coefficient naming - check for special characters in level names\n",
        "  3. Data structure issue - verify config matches data\n",
        "  4. Contact support with your config file"
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
  do_bootstrap <- isTRUE(as.logical(config$bootstrap_ci))
  if (do_bootstrap && prep_data$outcome_info$type != "multinomial") {

    # Validate bootstrap parameters (safe defaults for missing/invalid)
    if (is.null(config$bootstrap_reps) || is.na(config$bootstrap_reps) ||
        !is.numeric(config$bootstrap_reps) || config$bootstrap_reps < 10) {
      config$bootstrap_reps <- 200L
      cat("   [INFO] Bootstrap reps not configured or too low - using default 200\n")
    }
    if (is.null(config$confidence_level) || is.na(config$confidence_level) ||
        !is.numeric(config$confidence_level) ||
        config$confidence_level <= 0 || config$confidence_level >= 1) {
      config$confidence_level <- 0.95
      cat("   [INFO] Confidence level not configured or invalid - using default 0.95\n")
    }

    log_message(paste0("Running bootstrap (", config$bootstrap_reps, " resamples)..."), "info")
    cat("   [INFO] Bootstrap may take 1-3 minutes\n")

    # Build formula for bootstrap
    boot_formula <- as.formula(paste(
      config$outcome_var, "~",
      paste(config$driver_vars, collapse = " + ")
    ))

    bootstrap_results <- run_bootstrap_or(
      data = prep_data$data,
      formula = boot_formula,
      outcome_type = prep_data$outcome_info$type,
      weights = weights,
      n_boot = config$bootstrap_reps,
      conf_level = config$confidence_level,
      progress_callback = NULL  # Could add GUI callback here
    )

    if (!is.null(bootstrap_results) && isTRUE(bootstrap_results$n_successful > 0)) {
      log_message(paste0("Bootstrap complete (", bootstrap_results$n_successful, "/",
                         bootstrap_results$n_boot, " successful)"), "success")

      # Initialize bootstrap columns with NA
      odds_ratios$boot_median_or <- NA_real_
      odds_ratios$boot_ci_lower <- NA_real_
      odds_ratios$boot_ci_upper <- NA_real_
      odds_ratios$sign_stability <- NA_real_

      # Add bootstrap columns to odds_ratios
      for (i in seq_len(nrow(odds_ratios))) {
        term <- odds_ratios$term[i]
        idx <- which(bootstrap_results$term == term)
        if (length(idx) == 1) {
          odds_ratios$boot_median_or[i] <- bootstrap_results$median_or[idx]
          odds_ratios$boot_ci_lower[i] <- bootstrap_results$ci_lower[idx]
          odds_ratios$boot_ci_upper[i] <- bootstrap_results$ci_upper[idx]
          odds_ratios$sign_stability[i] <- bootstrap_results$sign_consistency[idx]
        }
        # If idx is empty or multiple matches, leave as NA (already initialized)
      }
    } else if (!is.null(bootstrap_results)) {
      # Bootstrap ran but all iterations failed
      cat("   [PARTIAL] All bootstrap iterations failed - bootstrap results dropped\n")
      bootstrap_results <- NULL
      degraded_reasons <- c(degraded_reasons, "All bootstrap iterations failed")
      affected_outputs <- c(affected_outputs, "bootstrap_ci")
    }
  }

  # Calculate probability lift (configurable — default TRUE)
  prob_lift <- if (isTRUE(config$probability_lifts %||% TRUE)) {
    calculate_probability_lift(model_result, prep_data, config)
  } else NULL

  # Factor patterns
  factor_patterns <- calculate_factor_patterns(prep_data, config, odds_ratios)
  log_message(paste("Generated patterns for", length(factor_patterns), "factors"), "info")

  }  # end non-subgroup path (else branch)

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
    # Subgroup comparison (NULL when subgroup_var not set)
    subgroup_comparison = subgroup_comparison,
    subgroup_results = if (subgroup_active) subgroup_results else NULL,
    subgroup_active = subgroup_active,
    # TRS v1.0: Include status fields for Run_Status sheet
    run_status = run_status,
    status = status,
    degraded = length(degraded_reasons) > 0,
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )

  # Write Excel output
  write_catdriver_output(results, config, config$output_file)

  log_message(paste("Excel output saved to:", basename(config$output_file)), "success")

  # ==========================================================================
  # HTML REPORT (if enabled)
  # ==========================================================================
  if (isTRUE(config$html_report)) {
    html_path <- sub("\\.xlsx$", ".html", config$output_file)

    # Source HTML report module if not already loaded
    if (!exists("generate_catdriver_html_report", mode = "function")) {
      html_main <- file.path(dirname(dirname(config$output_file %||% ".")),
                              "modules", "catdriver", "lib", "html_report",
                              "99_html_report_main.R")
      # Try standard module locations
      candidates <- c(
        html_main,
        file.path(.get_script_dir_for_guard(), "..", "lib", "html_report", "99_html_report_main.R"),
        file.path(getwd(), "modules", "catdriver", "lib", "html_report", "99_html_report_main.R")
      )
      for (cand in candidates) {
        if (file.exists(cand)) {
          tryCatch(source(cand), error = function(e) {
            log_message(sprintf("Could not source HTML report module: %s", e$message), "warning")
          })
          break
        }
      }
    }

    if (exists("generate_catdriver_html_report", mode = "function")) {
      html_result <- tryCatch({
        generate_catdriver_html_report(results, config, html_path)
      }, error = function(e) {
        log_message(sprintf("HTML report generation failed: %s", e$message), "warning")
        list(status = "REFUSED", message = e$message)
      })

      if (html_result$status != "REFUSED") {
        log_message(paste("HTML report saved to:", basename(html_result$output_file)), "success")
      } else {
        log_message(paste("HTML report skipped:", html_result$message), "warning")
      }
    } else {
      log_message("HTML report module not available - skipping HTML output", "info")
    }
  }

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

  # Print structured completion summary for Shiny console visibility
  cat("\n\u250C\u2500\u2500\u2500 CATDRIVER COMPLETE \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n")
  cat(sprintf("\u2502 Status: %s\n", run_status))
  cat(sprintf("\u2502 Outcome: %s (%s)\n",
              config$outcome_label %||% config$outcome_var,
              config$outcome_type %||% "unknown"))
  cat(sprintf("\u2502 Drivers: %d analysed\n", length(config$driver_vars)))
  if (!is.null(model_result$fit_statistics$mcfadden_r2)) {
    cat(sprintf("\u2502 Model fit: McFadden R\u00B2 = %.3f\n",
                model_result$fit_statistics$mcfadden_r2))
  }
  if (!is.null(diagnostics$analysis_n)) {
    cat(sprintf("\u2502 Sample: %d respondents (of %d original)\n",
                diagnostics$analysis_n %||% nrow(data),
                diagnostics$original_n %||% nrow(data)))
  }
  cat(sprintf("\u2502 Output: %s\n", basename(config$output_file)))
  if (isTRUE(config$html_report)) {
    cat(sprintf("\u2502 HTML: %s\n", basename(sub("\\.xlsx$", ".html", config$output_file))))
  }
  if (length(degraded_reasons) > 0) {
    cat(sprintf("\u2502 Warnings: %d (see Run_Status sheet)\n", length(degraded_reasons)))
  }
  cat(sprintf("\u2502 Time: %.1f seconds\n", elapsed))
  cat("\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n\n")

  # Print console summary (includes output file path)
  print_console_summary(results, config, output_file = config$output_file)

  invisible(results)
}


# ==============================================================================
# SUBGROUP HELPER: Run Steps 4-10 on a single data subset
# ==============================================================================

#' Run Analysis Steps 4-10 on a Data Subset
#'
#' Executes the core analysis pipeline (missing data handling through
#' result extraction) on a single dataset. Used by the subgroup loop
#' to analyse each subgroup independently.
#'
#' @param group_data Data frame (already filtered to subgroup)
#' @param config Configuration list
#' @param guard Guard state object
#' @param degraded_reasons Character vector of degraded reasons (for tracking)
#' @param affected_outputs Character vector of affected outputs (for tracking)
#' @param update_progress Progress callback function
#' @param group_label Label for console output
#' @return List with all analysis results for this group
#' @keywords internal
run_catdriver_steps_4_to_10 <- function(group_data, config, guard,
                                         degraded_reasons, affected_outputs,
                                         update_progress, group_label = "") {

  local_degraded <- character(0)
  local_affected <- character(0)

  # Step 4: Missing data
  cat(sprintf("   [%s] Step 4: Missing data handling...\n", group_label))
  missing_result <- handle_missing_data(group_data, config)
  data_g <- missing_result$data

  # Step 5: Rare level policy
  cat(sprintf("   [%s] Step 5: Rare level policy...\n", group_label))
  rare_result <- apply_rare_level_policy(data_g, config)
  data_g <- rare_result$data

  n_collapsed <- sum(sapply(rare_result$collapse_report, function(x) {
    if (x$action == "collapsed") length(x$rare_levels) else 0
  }))
  if (n_collapsed > 0) {
    local_degraded <- c(local_degraded,
      paste0("Rare level collapsing applied: ", n_collapsed, " levels collapsed"))
    local_affected <- c(local_affected, "Odds ratios", "Factor patterns")
  }

  # Step 6: Preprocess
  cat(sprintf("   [%s] Step 6: Preprocessing...\n", group_label))

  weights_g <- NULL
  weight_diagnostics_g <- NULL
  if (!is.null(config$weight_var) && config$weight_var %in% names(data_g)) {
    weights_g <- data_g[[config$weight_var]]
    weights_g[is.na(weights_g)] <- 1
    weights_g[weights_g < 0] <- 0
    weight_diagnostics_g <- calculate_weight_diagnostics(weights_g)
  }

  prep_data_g <- preprocess_catdriver_data(data_g, config)

  # Step 7: Model fitting
  cat(sprintf("   [%s] Step 7: Fitting model...\n", group_label))
  guard_g <- guard_init()
  model_result_g <- run_catdriver_model(
    prep_data_g, config, weights = weights_g, guard = guard_g
  )
  if (!is.null(model_result_g$guard)) {
    guard_g <- model_result_g$guard
  }

  if (!model_result_g$convergence) {
    local_degraded <- c(local_degraded, "Model convergence warning")
  }
  if (isTRUE(model_result_g$fallback_used)) {
    local_degraded <- c(local_degraded,
      paste0("Fallback estimator used: ", model_result_g$engine_used))
  }

  # Step 8: Post-model guards
  cat(sprintf("   [%s] Step 8: Post-model checks...\n", group_label))
  guard_g <- guard_post_model(guard_g, prep_data_g, model_result_g, config)

  vif_check_g <- check_multicollinearity(model_result_g$model)
  if (vif_check_g$checked && vif_check_g$status == "WARNING") {
    guard_g <- guard_check_multicollinearity(guard_g, vif_check_g)
    local_degraded <- c(local_degraded, vif_check_g$interpretation)
  }

  # Step 9: Importance
  cat(sprintf("   [%s] Step 9: Calculating importance...\n", group_label))
  importance_g <- calculate_importance(model_result_g, config)

  cat(sprintf("   [%s] Top 3:", group_label))
  for (i in 1:min(3, nrow(importance_g))) {
    cat(sprintf(" %d.%s(%s%%)", i, importance_g$label[i], importance_g$importance_pct[i]))
  }
  cat("\n")

  # Step 10: Extract results
  cat(sprintf("   [%s] Step 10: Extracting results...\n", group_label))

  term_mapping_g <- if (prep_data_g$outcome_info$type %in% c("multinomial", "nominal")) {
    map_multinomial_terms(model_result_g$model, prep_data_g$data,
                          prep_data_g$model_formula, config$outcome_var)
  } else {
    map_terms_to_levels(model_result_g$model, prep_data_g$data,
                        prep_data_g$model_formula)
  }

  odds_ratios_g <- extract_odds_ratios_mapped(model_result_g, term_mapping_g, config)

  bootstrap_results_g <- NULL
  if (isTRUE(config$bootstrap_ci)) {
    bootstrap_results_g <- tryCatch({
      run_bootstrap_ci(model_result_g, prep_data_g, config,
                       weights = weights_g,
                       n_boot = config$bootstrap_reps,
                       conf_level = config$confidence_level)
    }, error = function(e) {
      local_degraded <<- c(local_degraded, "Bootstrap CI failed")
      NULL
    })

    if (!is.null(bootstrap_results_g) && isTRUE(bootstrap_results_g$n_successful > 0)) {
      odds_ratios_g$boot_median_or <- NA_real_
      odds_ratios_g$boot_ci_lower <- NA_real_
      odds_ratios_g$boot_ci_upper <- NA_real_
      odds_ratios_g$sign_stability <- NA_real_
      for (i in seq_len(nrow(odds_ratios_g))) {
        term <- odds_ratios_g$term[i]
        idx <- which(bootstrap_results_g$term == term)
        if (length(idx) == 1) {
          odds_ratios_g$boot_median_or[i] <- bootstrap_results_g$median_or[idx]
          odds_ratios_g$boot_ci_lower[i] <- bootstrap_results_g$ci_lower[idx]
          odds_ratios_g$boot_ci_upper[i] <- bootstrap_results_g$ci_upper[idx]
          odds_ratios_g$sign_stability[i] <- bootstrap_results_g$sign_consistency[idx]
        }
      }
    }
  }

  prob_lift_g <- if (isTRUE(config$probability_lifts %||% TRUE)) {
    calculate_probability_lift(model_result_g, prep_data_g, config)
  } else NULL

  factor_patterns_g <- calculate_factor_patterns(prep_data_g, config, odds_ratios_g)

  cat(sprintf("   [%s] COMPLETE (status: %s)\n", group_label,
              if (length(local_degraded) > 0) "PARTIAL" else "PASS"))

  list(
    status = if (length(local_degraded) > 0) "PARTIAL" else "PASS",
    model_result = model_result_g,
    importance = importance_g,
    odds_ratios = odds_ratios_g,
    probability_lift = prob_lift_g,
    factor_patterns = factor_patterns_g,
    prep_data = prep_data_g,
    term_mapping = term_mapping_g,
    missing_report = missing_result$missing_report,
    collapse_report = rare_result$collapse_report,
    multicollinearity = vif_check_g,
    weight_diagnostics = weight_diagnostics_g,
    bootstrap_results = bootstrap_results_g,
    guard = guard_g,
    degraded_reasons = local_degraded,
    affected_outputs = local_affected
  )
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
    log_message("Probability lift skipped - no predicted probabilities available", "info")
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
