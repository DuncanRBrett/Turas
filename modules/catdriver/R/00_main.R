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

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R", "stats_pack_writer.R")

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
  print_config_fingerprint(config)

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
    # Delegate subgroup loop + comparison to helper
    sg_result <- run_catdriver_subgroup_analysis(
      data, config, guard, update_progress, degraded_reasons, affected_outputs
    )

    # Unpack subgroup results
    model_result       <- sg_result$model_result
    importance         <- sg_result$importance
    odds_ratios        <- sg_result$odds_ratios
    prob_lift          <- sg_result$probability_lift
    factor_patterns    <- sg_result$factor_patterns
    prep_data          <- sg_result$prep_data
    term_mapping       <- sg_result$term_mapping
    missing_result     <- list(missing_report = sg_result$missing_report)
    rare_result        <- list(collapse_report = sg_result$collapse_report)
    vif_check          <- sg_result$multicollinearity
    weight_diagnostics <- sg_result$weight_diagnostics
    bootstrap_results  <- sg_result$bootstrap_results
    guard_status       <- sg_result$guard_status
    guard              <- sg_result$guard
    subgroup_comparison <- sg_result$subgroup_comparison
    subgroup_results   <- sg_result$subgroup_results
    degraded_reasons   <- sg_result$degraded_reasons
    affected_outputs   <- sg_result$affected_outputs

  } else {
    # ========================================================================
    # NON-SUBGROUP PATH — delegate to shared Steps 4-10 helper
    # ========================================================================

    primary <- run_catdriver_steps_4_to_10(
      data, config, guard, update_progress,
      group_label = "", verbose = TRUE
    )

    # Unpack into main-scope variables for Step 11
    model_result     <- primary$model_result
    importance       <- primary$importance
    odds_ratios      <- primary$odds_ratios
    prob_lift        <- primary$probability_lift
    factor_patterns  <- primary$factor_patterns
    prep_data        <- primary$prep_data
    term_mapping     <- primary$term_mapping
    missing_result   <- list(missing_report = primary$missing_report)
    rare_result      <- list(collapse_report = primary$collapse_report)
    vif_check        <- primary$multicollinearity %||% list(checked = FALSE)
    weight_diagnostics <- primary$weight_diagnostics
    bootstrap_results <- primary$bootstrap_results
    guard_status     <- primary$guard_status %||% guard_summary(primary$guard)

    degraded_reasons <- c(degraded_reasons, primary$degraded_reasons)
    affected_outputs <- c(affected_outputs, primary$affected_outputs)

    subgroup_results <- NULL

  }  # end non-subgroup path (else branch)

  # ==========================================================================
  # STEP 11: GENERATE OUTPUT & COMPLETION
  # ==========================================================================

  run_catdriver_step_11_output(
    model_result = model_result,
    importance = importance,
    odds_ratios = odds_ratios,
    prob_lift = prob_lift,
    factor_patterns = factor_patterns,
    prep_data = prep_data,
    term_mapping = term_mapping,
    missing_report = missing_result$missing_report,
    collapse_report = rare_result$collapse_report,
    diagnostics = diagnostics,
    guard = guard,
    guard_status = guard_status,
    vif_check = vif_check,
    weight_diagnostics = weight_diagnostics,
    bootstrap_results = bootstrap_results,
    config = config,
    subgroup_comparison = subgroup_comparison,
    subgroup_results = if (subgroup_active) subgroup_results else NULL,
    subgroup_active = subgroup_active,
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs,
    trs_state = trs_state,
    start_time = start_time,
    update_progress = update_progress
  )
}


# ==============================================================================
# CONFIG FINGERPRINT LOGGING
# ==============================================================================

#' Print Configuration Fingerprint
#'
#' Outputs config file metadata and driver order sources to the console
#' for traceability and debugging.
#'
#' @param config Configuration list
#' @keywords internal
print_config_fingerprint <- function(config) {
  config_mtime <- file.info(config$config_file)$mtime
  cat("\n   [CONFIG FINGERPRINT]\n")
  cat("   Path: ", config$config_file, "\n", sep = "")
  cat("   Modified: ", format(config_mtime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")

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
}


# ==============================================================================
# SUBGROUP ANALYSIS HELPER
# ==============================================================================

#' Run CatDriver Subgroup Analysis Loop
#'
#' Splits data by subgroup variable, runs Steps 4-10 on each group,
#' builds comparison, and returns the primary result for output generation.
#'
#' @param data Full data frame
#' @param config Configuration list (must have subgroup_var set)
#' @param guard Guard state object
#' @param update_progress Progress callback function
#' @param degraded_reasons Character vector of existing degraded reasons
#' @param affected_outputs Character vector of existing affected outputs
#' @return List with primary result fields and subgroup metadata
#' @keywords internal
run_catdriver_subgroup_analysis <- function(data, config, guard,
                                            update_progress,
                                            degraded_reasons, affected_outputs) {

  subgroup_col <- data[[config$subgroup_var]]
  subgroup_levels <- sort(unique(as.character(na.omit(subgroup_col))))

  # Build run list
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

    guard <- guard_check_subgroup_sample_size(
      guard, group_name, group_n, config$subgroup_min_n
    )

    group_result <- tryCatch({
      run_catdriver_steps_4_to_10(
        group_data, config, guard, update_progress,
        group_label = group_name, verbose = FALSE
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
  subgroup_comparison <- NULL
  if (exists("build_subgroup_comparison", mode = "function")) {
    subgroup_comparison <- tryCatch(
      build_subgroup_comparison(subgroup_results, config),
      error = function(e) {
        cat(sprintf("   [WARNING] Subgroup comparison generation failed: %s\n", e$message))
        NULL
      }
    )
  }

  # Select primary result
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

  primary <- subgroup_results[[primary_name]]
  guard_status <- if (!is.null(primary$guard)) guard_summary(primary$guard) else guard_summary(guard)

  log_message(sprintf("Subgroup analysis complete. Primary result: %s", primary_name), "success")

  # Return primary result fields + subgroup metadata
  list(
    model_result = primary$model_result,
    importance = primary$importance,
    odds_ratios = primary$odds_ratios,
    probability_lift = primary$probability_lift,
    factor_patterns = primary$factor_patterns,
    prep_data = primary$prep_data,
    term_mapping = primary$term_mapping,
    missing_report = primary$missing_report,
    collapse_report = primary$collapse_report,
    multicollinearity = primary$multicollinearity %||% list(checked = FALSE),
    weight_diagnostics = primary$weight_diagnostics,
    bootstrap_results = primary$bootstrap_results,
    guard = guard,
    guard_status = guard_status,
    subgroup_comparison = subgroup_comparison,
    subgroup_results = subgroup_results,
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )
}


# ==============================================================================
# CORE PIPELINE: Run Steps 4-10 on a single dataset
# ==============================================================================

#' Run Analysis Steps 4-10 on a Dataset
#'
#' Executes the core analysis pipeline (missing data handling through
#' result extraction) on a single dataset. Used by both the main path
#' and the subgroup loop.
#'
#' @param group_data Data frame (full dataset or subgroup subset)
#' @param config Configuration list
#' @param guard Guard state object
#' @param update_progress Progress callback function
#' @param group_label Label for console output (empty string for main path)
#' @param verbose Logical; if TRUE, use detailed step logging (main path).
#'   If FALSE, use compact per-group logging (subgroup path).
#' @return List with all analysis results for this group
#' @keywords internal
run_catdriver_steps_4_to_10 <- function(group_data, config, guard,
                                         update_progress,
                                         group_label = "",
                                         verbose = FALSE) {

  local_degraded <- character(0)
  local_affected <- character(0)

  # Logging helpers — verbose for main path, compact for subgroups
  log_step <- function(step, msg) {
    if (verbose) {
      update_progress(step, msg)
      log_section(step, msg)
    } else {
      cat(sprintf("   [%s] Step %d: %s\n", group_label, step, msg))
    }
  }

  # --------------------------------------------------------------------------
  # STEP 4: HANDLE MISSING DATA
  # --------------------------------------------------------------------------
  log_step(4, "Handling missing data...")
  missing_result <- handle_missing_data(group_data, config)
  data_g <- missing_result$data

  if (verbose) {
    log_message(paste("Missing data handled:",
                      missing_result$missing_report$summary$total_rows_dropped,
                      "rows dropped"), "info")
    log_message(paste("Retained:", nrow(data_g), "respondents (",
                      missing_result$missing_report$summary$pct_retained, "%)"), "success")
  }

  # --------------------------------------------------------------------------
  # STEP 5: APPLY RARE LEVEL POLICY
  # --------------------------------------------------------------------------
  log_step(5, "Applying rare level policy...")
  rare_result <- apply_rare_level_policy(data_g, config)
  data_g <- rare_result$data

  n_collapsed <- sum(sapply(rare_result$collapse_report, function(x) {
    if (x$action == "collapsed") length(x$rare_levels) else 0
  }))
  if (n_collapsed > 0) {
    cat("   [PARTIAL] Collapsed", n_collapsed, "rare levels\n")
    guard <- guard_check_collapsing(guard, rare_result$collapse_report)
    local_degraded <- c(local_degraded,
      paste0("Rare level collapsing applied: ", n_collapsed, " levels collapsed"))
    local_affected <- c(local_affected, "Odds ratios", "Factor patterns")
  } else if (verbose) {
    cat("   [OK] No rare level collapsing required\n")
  }

  # Sparse cells -> PARTIAL
  if (length(rare_result$cell_warnings) > 0) {
    for (var_name in names(rare_result$cell_warnings)) {
      warn_info <- rare_result$cell_warnings[[var_name]]
      cat("   [PARTIAL] Sparse cells in", var_name, "- min cell:", warn_info$min_cell, "\n")
      local_degraded <- c(local_degraded,
        paste0("Sparse cells in ", var_name, " (min cell: ", warn_info$min_cell, ")"))
    }
    local_affected <- unique(c(local_affected, "Odds ratio confidence intervals"))
  }

  # --------------------------------------------------------------------------
  # STEP 6: PREPROCESS DATA
  # --------------------------------------------------------------------------
  log_step(6, "Preparing data for analysis...")

  weights_g <- NULL
  weight_diagnostics_g <- NULL
  if (!is.null(config$weight_var) && config$weight_var %in% names(data_g)) {
    weights_g <- data_g[[config$weight_var]]
    weights_g[is.na(weights_g)] <- 1
    weights_g[weights_g < 0] <- 0
    if (verbose) log_message(paste("Using weights from:", config$weight_var), "info")

    weight_diagnostics_g <- calculate_weight_diagnostics(weights_g)
    if (!is.null(weight_diagnostics_g)) {
      if (verbose) {
        log_message(paste("Weight range:", round(weight_diagnostics_g$min_weight, 3),
                          "-", round(weight_diagnostics_g$max_weight, 3)), "info")
        log_message(paste("Effective n:", round(weight_diagnostics_g$effective_n, 0),
                          "(design effect:", round(weight_diagnostics_g$design_effect, 2), ")"), "info")
      }
      if (weight_diagnostics_g$has_extreme_weights) {
        cat("   [PARTIAL] Extreme weights detected (ratio > 10)\n")
        local_degraded <- c(local_degraded,
          paste0("Extreme weights detected (max/min = ", round(weight_diagnostics_g$weight_ratio, 1), ")"))
        local_affected <- c(local_affected, "Standard errors", "Confidence intervals")
      }
    }
  }

  prep_data_g <- preprocess_catdriver_data(data_g, config)

  if (verbose) {
    outcome_type_label <- switch(prep_data_g$outcome_info$type,
      binary = "Binary (2 categories)",
      ordinal = "Ordinal (ordered categories)",
      nominal = "Nominal (unordered categories)",
      multinomial = "Multinomial (unordered categories)"
    )
    log_message(paste("Outcome type:", outcome_type_label), "success")
    log_message(paste("Categories:", paste(prep_data_g$outcome_info$categories, collapse = " < ")), "info")
  }

  # --------------------------------------------------------------------------
  # STEP 7: FIT MODEL
  # --------------------------------------------------------------------------
  log_step(7, "Fitting regression model...")

  if (verbose) {
    method_label <- switch(prep_data_g$outcome_info$type,
      binary = "Binary Logistic Regression",
      ordinal = "Ordinal Logistic Regression (Proportional Odds)",
      nominal = "Multinomial Logistic Regression",
      multinomial = "Multinomial Logistic Regression"
    )
    log_message(paste("Method:", method_label), "info")
  }

  guard_g <- if (verbose) guard else guard_init()
  model_result_g <- run_catdriver_model(
    prep_data_g, config, weights = weights_g, guard = guard_g
  )
  if (!is.null(model_result_g$guard)) {
    guard_g <- model_result_g$guard
  }

  if (model_result_g$convergence) {
    if (verbose) cat("   [OK] Model converged successfully\n")
  } else {
    cat("   [PARTIAL] Model convergence warning - check results\n")
    local_degraded <- c(local_degraded, "Model convergence warning - results may be unstable")
    local_affected <- unique(c(local_affected, "Odds ratios", "Confidence intervals", "P-values"))
  }

  if (isTRUE(model_result_g$fallback_used)) {
    cat("   [PARTIAL] Fallback estimator used:", model_result_g$engine_used, "\n")
    local_degraded <- c(local_degraded,
      paste0("Fallback estimator used: ", model_result_g$engine_used))
    local_affected <- unique(c(local_affected, "Standard errors"))
  } else if (verbose && !is.null(model_result_g$engine_used)) {
    cat("   [INFO] Engine:", model_result_g$engine_used, "\n")
  }

  if (verbose) {
    fit <- model_result_g$fit_statistics
    if (!is.na(fit$mcfadden_r2)) {
      log_message(paste("McFadden R-squared:", sprintf("%.3f", fit$mcfadden_r2),
                        "(", interpret_pseudo_r2(fit$mcfadden_r2), ")"), "info")
    }
  }

  # --------------------------------------------------------------------------
  # STEP 8: POST-MODEL GUARDS
  # --------------------------------------------------------------------------
  log_step(8, "Running post-model validations...")
  guard_g <- guard_post_model(guard_g, prep_data_g, model_result_g, config)

  vif_check_g <- check_multicollinearity(model_result_g$model)
  if (vif_check_g$checked) {
    if (vif_check_g$status == "WARNING") {
      cat("   [PARTIAL]", vif_check_g$interpretation, "\n")
      guard_g <- guard_check_multicollinearity(guard_g, vif_check_g)
      local_degraded <- c(local_degraded, vif_check_g$interpretation)
      local_affected <- unique(c(local_affected, "Relative importance scores"))
    } else if (verbose) {
      cat("   [OK] Multicollinearity check: OK\n")
    }
  }

  guard_status_g <- guard_summary(guard_g)
  if (guard_status_g$has_issues) {
    cat("   [PARTIAL] Stability flags:", length(guard_status_g$stability_flags), "\n")
    for (flag in guard_status_g$stability_flags) {
      local_degraded <- c(local_degraded, flag)
    }
  } else if (verbose) {
    cat("   [OK] All quality checks passed\n")
  }

  # --------------------------------------------------------------------------
  # STEP 9: CALCULATE IMPORTANCE
  # --------------------------------------------------------------------------
  log_step(9, "Calculating variable importance...")
  importance_g <- calculate_importance(model_result_g, config)

  # Add stability flag column
  importance_g$stability_flag <- if (guard_status_g$use_with_caution) {
    "Use with caution"
  } else {
    "OK"
  }

  if (verbose) {
    log_message(paste("Calculated importance for", nrow(importance_g), "drivers"), "success")
  }

  cat("\n   Top drivers:\n")
  for (i in 1:min(3, nrow(importance_g))) {
    cat(sprintf("   %d. %s (%s%%)\n",
                i, importance_g$label[i], importance_g$importance_pct[i]))
  }

  # --------------------------------------------------------------------------
  # STEP 10: EXTRACT DETAILED RESULTS
  # --------------------------------------------------------------------------
  log_step(10, "Extracting detailed results...")

  # Create term-level mapping (REQUIRED — no legacy fallback)
  term_mapping_g <- tryCatch({
    if (prep_data_g$outcome_info$type %in% c("multinomial", "nominal")) {
      map_multinomial_terms(model_result_g$model, prep_data_g$data,
                            prep_data_g$model_formula, config$outcome_var)
    } else {
      map_terms_to_levels(model_result_g$model, prep_data_g$data,
                          prep_data_g$model_formula)
    }
  }, error = function(e) {
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

  # Validate mapping covers all model coefficients
  model_coef_names <- tryCatch({
    coefs <- coef(model_result_g$model)
    if (is.matrix(coefs)) colnames(coefs) else names(coefs)
  }, error = function(e) {
    catdriver_refuse(
      reason = "MODEL_COEF_EXTRACT_FAILED",
      title = "CANNOT VALIDATE TERM MAPPING",
      problem = "Failed to extract coefficient names from the fitted model.",
      why_it_matters = "Without coefficient names, CatDriver cannot prove that every model term is mapped correctly.",
      fix = "Check model convergence and model type; ensure required packages are installed; then re-run.",
      details = paste0("Error: ", e$message)
    )
  })

  validate_mapping(term_mapping_g, model_coef_names)
  if (verbose) log_message("Term mapping validated - all coefficients mapped", "info")

  # Extract odds ratios using canonical mapping
  odds_ratios_g <- extract_odds_ratios_mapped(model_result_g, term_mapping_g, config)
  if (verbose) log_message(paste("Extracted", nrow(odds_ratios_g), "odds ratio comparisons"), "info")

  # Bootstrap confidence intervals (optional)
  bootstrap_results_g <- NULL
  do_bootstrap <- isTRUE(as.logical(config$bootstrap_ci))
  if (do_bootstrap && prep_data_g$outcome_info$type != "multinomial") {

    # Validate bootstrap parameters (safe defaults for missing/invalid)
    boot_reps <- config$bootstrap_reps
    if (is.null(boot_reps) || is.na(boot_reps) || !is.numeric(boot_reps) || boot_reps < 10) {
      boot_reps <- 200L
      cat("   [INFO] Bootstrap reps not configured or too low - using default 200\n")
    }
    conf_level <- config$confidence_level
    if (is.null(conf_level) || is.na(conf_level) || !is.numeric(conf_level) ||
        conf_level <= 0 || conf_level >= 1) {
      conf_level <- 0.95
      cat("   [INFO] Confidence level not configured or invalid - using default 0.95\n")
    }

    if (verbose) {
      log_message(paste0("Running bootstrap (", boot_reps, " resamples)..."), "info")
      cat("   [INFO] Bootstrap may take 1-3 minutes\n")
    }

    boot_formula <- as.formula(paste(
      config$outcome_var, "~",
      paste(config$driver_vars, collapse = " + ")
    ))

    bootstrap_results_g <- tryCatch({
      run_bootstrap_or(
        data = prep_data_g$data,
        formula = boot_formula,
        outcome_type = prep_data_g$outcome_info$type,
        weights = weights_g,
        n_boot = boot_reps,
        conf_level = conf_level,
        progress_callback = NULL
      )
    }, error = function(e) {
      cat("   [PARTIAL] Bootstrap failed:", e$message, "\n")
      local_degraded <<- c(local_degraded, paste0("Bootstrap CI failed: ", e$message))
      local_affected <<- c(local_affected, "bootstrap_ci")
      NULL
    })

    if (!is.null(bootstrap_results_g) && isTRUE(bootstrap_results_g$n_successful > 0)) {
      if (verbose) {
        log_message(paste0("Bootstrap complete (", bootstrap_results_g$n_successful, "/",
                           bootstrap_results_g$n_boot, " successful)"), "success")
      }

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
    } else if (!is.null(bootstrap_results_g)) {
      cat("   [PARTIAL] All bootstrap iterations failed - bootstrap results dropped\n")
      bootstrap_results_g <- NULL
      local_degraded <- c(local_degraded, "All bootstrap iterations failed")
      local_affected <- c(local_affected, "bootstrap_ci")
    }
  }

  # Calculate probability lift
  prob_lift_g <- if (isTRUE(config$probability_lifts %||% TRUE)) {
    calculate_probability_lift(model_result_g, prep_data_g, config)
  } else NULL

  # Factor patterns
  factor_patterns_g <- calculate_factor_patterns(prep_data_g, config, odds_ratios_g)
  if (verbose) log_message(paste("Generated patterns for", length(factor_patterns_g), "factors"), "info")

  cat(sprintf("   [%s] COMPLETE (status: %s)\n",
              if (nzchar(group_label)) group_label else "MAIN",
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
    guard_status = guard_status_g,
    multicollinearity = vif_check_g,
    weight_diagnostics = weight_diagnostics_g,
    bootstrap_results = bootstrap_results_g,
    guard = guard_g,
    degraded_reasons = local_degraded,
    affected_outputs = unique(local_affected)
  )
}


# ==============================================================================
# OUTPUT HELPER: Step 11 — Generate output, HTML report, and completion banner
# ==============================================================================

#' Run CatDriver Step 11: Output Generation and Completion
#'
#' Generates Excel output, optional HTML report, TRS status tracking,
#' and completion banner. Extracted from run_categorical_keydriver_impl()
#' for maintainability.
#'
#' @param model_result Fitted model result
#' @param importance Importance data frame
#' @param odds_ratios Odds ratios data frame
#' @param prob_lift Probability lift data frame (or NULL)
#' @param factor_patterns Factor patterns list
#' @param prep_data Preprocessed data list
#' @param term_mapping Term-to-level mapping
#' @param missing_report Missing data report
#' @param collapse_report Rare level collapse report
#' @param diagnostics Data validation diagnostics
#' @param guard Guard state object
#' @param guard_status Guard summary
#' @param vif_check Multicollinearity check result
#' @param weight_diagnostics Weight diagnostics (or NULL)
#' @param bootstrap_results Bootstrap results (or NULL)
#' @param config Configuration list
#' @param subgroup_comparison Subgroup comparison (or NULL)
#' @param subgroup_results Subgroup results list (or NULL)
#' @param subgroup_active Logical; whether subgroup analysis was active
#' @param degraded_reasons Character vector of degraded reasons
#' @param affected_outputs Character vector of affected outputs
#' @param trs_state TRS run state (or NULL)
#' @param start_time POSIXct start time
#' @param update_progress Progress callback function
#' @return Invisibly returns the compiled results list
#' @keywords internal
run_catdriver_step_11_output <- function(model_result, importance, odds_ratios,
                                         prob_lift, factor_patterns, prep_data,
                                         term_mapping, missing_report,
                                         collapse_report, diagnostics,
                                         guard, guard_status, vif_check,
                                         weight_diagnostics, bootstrap_results,
                                         config, subgroup_comparison,
                                         subgroup_results, subgroup_active,
                                         degraded_reasons, affected_outputs,
                                         trs_state, start_time,
                                         update_progress) {

  update_progress(11, "Generating Excel output...")
  log_section(11, "Generating Excel output...")

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

  # Compile all results
  results <- list(
    model_result = model_result,
    importance = importance,
    odds_ratios = odds_ratios,
    probability_lift = prob_lift,
    factor_patterns = factor_patterns,
    prep_data = prep_data,
    term_mapping = term_mapping,
    missing_report = missing_report,
    collapse_report = collapse_report,
    diagnostics = diagnostics,
    guard = guard,
    guard_summary = guard_status,
    multicollinearity = vif_check,
    weight_diagnostics = weight_diagnostics,
    bootstrap_results = bootstrap_results,
    config = config,
    subgroup_comparison = subgroup_comparison,
    subgroup_results = subgroup_results,
    subgroup_active = subgroup_active,
    run_status = run_status,
    status = status,
    degraded = length(degraded_reasons) > 0,
    degraded_reasons = degraded_reasons,
    affected_outputs = affected_outputs
  )

  # Write Excel output
  write_catdriver_output(results, config, config$output_file)
  log_message(paste("Excel output saved to:", basename(config$output_file)), "success")

  # HTML report (if enabled)
  if (isTRUE(config$html_report)) {
    html_path <- sub("\\.xlsx$", ".html", config$output_file)

    if (!exists("generate_catdriver_html_report", mode = "function")) {
      html_main <- file.path(dirname(dirname(config$output_file %||% ".")),
                              "modules", "catdriver", "lib", "html_report",
                              "99_html_report_main.R")
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

        # Minify for client delivery (if requested via Shiny checkbox)
        if (exists("turas_prepare_deliverable", mode = "function")) {
          turas_prepare_deliverable(html_path)
        }
      } else {
        log_message(paste("HTML report skipped:", html_result$message), "warning")
      }
    } else {
      log_message("HTML report module not available - skipping HTML output", "info")
    }
  }

  # Completion timing and banners
  end_time <- Sys.time()
  elapsed <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 1)

  # TRS: Log PARTIAL events
  if (!is.null(trs_state) && length(degraded_reasons) > 0) {
    for (reason in degraded_reasons) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(trs_state, "CATD_DEGRADED", "Degraded output", problem = reason)
      }
    }
  }

  # TRS: Get run result
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }
  results$run_result <- run_result

  # TRS v1.0: End banner
  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else {
    trs_banner_end("CATEGORICAL KEY DRIVER ANALYSIS", status, elapsed)
  }

  # Structured completion summary for Shiny console
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
                diagnostics$analysis_n %||% nrow(prep_data$data),
                diagnostics$original_n %||% nrow(prep_data$data)))
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

  # Stats pack (optional)
  generate_stats_pack_flag <- isTRUE(
    toupper(config$settings$Generate_Stats_Pack %||% "Y") == "Y"
  ) || isTRUE(getOption("turas.generate_stats_pack", FALSE))

  if (generate_stats_pack_flag) {
    cat("\nGenerating stats pack...\n")
    generate_catdriver_stats_pack(
      config      = config,
      survey_data = prep_data$data,
      result      = results,
      run_result  = run_result,
      start_time  = start_time,
      verbose     = TRUE
    )
  }

  print_console_summary(results, config, output_file = config$output_file)

  invisible(results)
}


# ==============================================================================
# STATS PACK HELPER
# ==============================================================================

#' Generate CatDriver Stats Pack
#'
#' Builds the diagnostic payload from catdriver analysis results and writes
#' the stats pack Excel workbook alongside the main output.
#'
#' @keywords internal
generate_catdriver_stats_pack <- function(config, survey_data, result,
                                          run_result, start_time, verbose = TRUE) {

  if (!exists("turas_write_stats_pack", mode = "function")) {
    if (verbose) cat("  ! Stats pack writer not loaded - skipping\n")
    return(NULL)
  }

  # Output path: same base as main output, with _stats_pack suffix
  main_out    <- config$output_file %||% "output.xlsx"
  output_path <- sub("(\\.xlsx)$", "_stats_pack.xlsx", main_out, ignore.case = TRUE)
  if (identical(output_path, main_out)) {
    output_path <- paste0(tools::file_path_sans_ext(main_out), "_stats_pack.xlsx")
  }

  importance  <- result$importance
  n_drivers   <- if (!is.null(importance) && is.data.frame(importance)) nrow(importance) else length(config$driver_vars)
  n_subgroups <- if (!is.null(result$subgroup_results)) length(result$subgroup_results) else 0L
  outcome_type <- result$prep_data$outcome_info$type %||% config$outcome_type %||% "—"
  model_type_label <- switch(outcome_type,
    binary      = "Binary logistic regression (base R glm())",
    ordinal     = "Ordinal logistic regression (ordinal::clm())",
    multinomial = "Multinomial logistic regression (nnet::multinom())",
    nominal     = "Multinomial logistic regression (nnet::multinom())",
    "Logistic/multinomial regression"
  )
  # TRS execution summary
  n_events   <- length(run_result$events %||% list())
  n_refusals <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "REFUSE"), logical(1)))
  n_partials <- sum(vapply(run_result$events %||% list(),
                           function(e) identical(e$level, "PARTIAL"), logical(1)))
  trs_summary <- if (n_events == 0) {
    "No events — ran cleanly"
  } else {
    parts <- character(0)
    if (n_refusals > 0) parts <- c(parts, sprintf("%d refusal(s)", n_refusals))
    if (n_partials > 0) parts <- c(parts, sprintf("%d partial(s)", n_partials))
    remainder <- n_events - n_refusals - n_partials
    if (remainder  > 0) parts <- c(parts, sprintf("%d info event(s)", remainder))
    paste(parts, collapse = ", ")
  }

  assumptions <- list(
    "Outcome Variable"   = config$outcome_label %||% config$outcome_var %||% "—",
    "Drivers tested"     = as.character(n_drivers),
    "Model Type"         = model_type_label,
    "Importance Method"  = "Type II Wald chi-square (car::Anova)",
    "Subgroup Analysis"  = if (n_subgroups > 0) sprintf("%d subgroups", n_subgroups) else "None",
    "TRS Status"         = run_result$status %||% "PASS",
    "TRS Events"         = trs_summary
  )

  data_receipt <- list(
    file_name           = basename(config$data_file %||% "unknown"),
    n_rows              = nrow(survey_data),
    n_cols              = ncol(survey_data),
    questions_in_config = length(config$driver_vars)
  )

  data_used <- list(
    n_respondents      = nrow(survey_data),
    n_excluded         = 0L,
    weight_variable    = config$weight_var %||% "",
    weighted           = !is.null(config$weight_var) && nzchar(config$weight_var %||% ""),
    questions_analysed = n_drivers,
    questions_skipped  = 0L
  )

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  payload <- list(
    module           = "CATDRIVER",
    project_name     = config$project_name   %||% NULL,
    analyst_name     = config$analyst_name   %||% NULL,
    research_house   = config$research_house %||% NULL,
    run_timestamp    = start_time,
    turas_version    = CATDRIVER_VERSION,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = duration_secs,
    data_receipt     = data_receipt,
    data_used        = data_used,
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = c("openxlsx", "data.table", "nnet", "ordinal"),
    config_echo      = list(settings = config[c("outcome_var", "outcome_type", "driver_vars",
                                                 "weight_var", "subgroup_var", "bootstrap_ci")])
  )

  result_path <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result_path) && verbose) {
    cat(sprintf("  + Stats pack written: %s\n", basename(output_path)))
  }

  result_path
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
