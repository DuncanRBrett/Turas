# ==============================================================================
# TURAS KEY DRIVER ANALYSIS MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Key Driver Analysis (Relative Importance)
# Purpose: Determine which independent variables (drivers) have the greatest
#          impact on a dependent variable (outcome)
# Version: Turas v10.3 (Continuous Key Driver Upgrade)
# Date: 2025-12
#
# NEW IN v10.3:
#   - Explicit driver_type declarations required (per TURAS-KD-CONTINUOUS-UPGRADE-v1.0)
#   - Partial R² as primary importance method
#   - Feature on_fail policies (refuse vs continue_with_flag)
#   - Enhanced output contract with Run Status sheet
#
# NEW IN v10.2:
#   - TRS v1.0 integration: Refusal framework, guard state, explicit status
#   - No silent failures: All errors produce actionable refusals
#   - PARTIAL status for degraded outputs (e.g., SHAP unavailable)
#
# NEW IN v10.1:
#   - SHAP Analysis: Machine learning-based importance using XGBoost/TreeSHAP
#   - Quadrant Charts: Importance-Performance Analysis (IPA) visualizations
#   - Segment Comparison: Compare driver importance across customer segments
#   - Enhanced Visualizations: Beeswarm, waterfall, dependence plots
#
# ==============================================================================

KEYDRIVER_VERSION <- "10.4"

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
  .guard_path <- file.path(getwd(), "modules", "keydriver", "R", "00_guard.R")
}
if (file.exists(.guard_path)) {
  source(.guard_path)
}

# ==============================================================================
# TRS INFRASTRUCTURE (TRS v1.0)
# ==============================================================================

.source_trs_infrastructure <- function() {
  base_dir <- .get_script_dir_for_guard()
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
        if (file.exists(fpath)) source(fpath)
      }
      break
    }
  }
}

tryCatch({
  .source_trs_infrastructure()
}, error = function(e) {
  cat(sprintf("   [WARN] KD_TRS_LOAD: Could not load TRS infrastructure: %s\n", e$message))
})

# ==============================================================================
# NULL-COALESCING OPERATOR (must precede all usage)
# ==============================================================================

#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Key Driver Analysis
#'
#' Analyzes which variables drive an outcome using multiple statistical methods.
#'
#' @param config_file Path to key driver configuration Excel file.
#'   Required sheets: Settings, Variables.
#'   Optional sheets: SHAPParameters, QuadrantParameters, Segments.
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA).
#'   If NULL, reads from config Settings sheet.
#' @param output_file Path for results Excel file.
#'   If NULL, reads from config Settings sheet.
#' @param html_report Logical; if TRUE, generate an HTML report alongside Excel.
#'   If NULL (default), reads from config Settings sheet enable_html_report.
#'   When provided, overrides the config file setting.
#'
#' @return List with importance, model, correlations, shap, quadrant, config.
#'
#' @examples
#' \dontrun{
#' results <- run_keydriver_analysis("keydriver_config.xlsx")
#' print(results$importance)
#' }
#'
#' @export
run_keydriver_analysis <- function(config_file, data_file = NULL, output_file = NULL,
                                   html_report = NULL) {
  keydriver_with_refusal_handler(
    run_keydriver_analysis_impl(config_file, data_file, output_file,
                                 html_report = html_report)
  )
}

# ==============================================================================
# STEP FUNCTIONS (extracted from run_keydriver_analysis_impl)
# ==============================================================================

#' Load and validate configuration, resolve file paths, detect enabled features.
#' @param config_file Path to config Excel file.
#' @param data_file Optional data file override.
#' @param output_file Optional output file override.
#' @return List with config, data_file, output_file, enable_shap, enable_quadrant.
#' @keywords internal
step_load_config <- function(config_file, data_file, output_file) {
  config <- load_keydriver_config(config_file)
  validate_keydriver_config(config)

  enable_shap <- isTRUE(config$settings$enable_shap) ||
                 isTRUE(as.logical(config$settings$enable_shap))
  enable_quadrant <- isTRUE(config$settings$enable_quadrant) ||
                     isTRUE(as.logical(config$settings$enable_quadrant))

  if (is.null(data_file)) {
    data_file <- config$data_file
    if (is.null(data_file) || is.na(data_file)) {
      keydriver_refuse(
        code = "CFG_DATA_FILE_MISSING",
        title = "Data File Not Specified",
        problem = "No data file specified in function call or config Settings sheet.",
        why_it_matters = "Key driver analysis requires respondent data to analyze.",
        how_to_fix = c(
          "Add 'data_file' to the Settings sheet in your config file",
          "Or pass data_file parameter to run_keydriver_analysis()"
        )
      )
    }
  }

  if (is.null(output_file)) {
    output_file <- config$output_file
    if (is.null(output_file) || is.na(output_file)) {
      output_file <- file.path(config$project_root, "keydriver_results.xlsx")
    }
  }

  list(config = config, data_file = data_file, output_file = output_file,
       enable_shap = enable_shap, enable_quadrant = enable_quadrant)
}

#' Load data, validate driver types, detect mixed predictors, apply encoding.
#' @param data_file Path to respondent data.
#' @param config Parsed configuration list.
#' @return List with data, config (updated), has_mixed.
#' @keywords internal
step_load_and_validate_data <- function(data_file, config) {
  data <- load_keydriver_data(data_file, config)

  if (!is.null(config$driver_settings)) {
    validate_driver_type_consistency(data$data, config$driver_vars, config$driver_settings)
  }

  config$raw_data <- data$data
  has_mixed <- has_categorical_predictors(data$data, config$driver_vars)
  config$has_mixed_predictors <- has_mixed

  if (has_mixed) {
    encoding_result <- enforce_encoding_policy(
      data = data$data, driver_vars = config$driver_vars,
      driver_settings = config$driver_settings, allow_polynomial = FALSE
    )
    data$data <- encoding_result$data
    config$encoding_report <- encoding_result$encoding_report
  }

  list(data = data, config = config, has_mixed = has_mixed)
}

#' Calculate correlations (numeric drivers only for mixed) and check collinearity.
#' @param data Data list (uses $data).
#' @param config Configuration list.
#' @param guard Guard state.
#' @param has_mixed Logical; mixed predictors detected.
#' @return List with correlations, guard, degraded_reasons, affected_outputs.
#' @keywords internal
step_calculate_correlations <- function(data, config, guard, has_mixed) {
  degraded_reasons <- character(0)
  affected_outputs <- character(0)
  correlations <- NULL

  if (has_mixed) {
    numeric_drivers <- get_numeric_drivers(data$data, config$driver_vars)
    if (length(numeric_drivers) < length(config$driver_vars)) {
      degraded_reasons <- "Correlations only computed for numeric drivers (categorical excluded)"
      affected_outputs <- c("Correlation matrix", "Quadrant chart correlations")
      if (length(numeric_drivers) >= 2) {
        numeric_config <- config
        numeric_config$driver_vars <- numeric_drivers
        correlations <- calculate_correlations(data$data, numeric_config)
      }
    } else {
      correlations <- calculate_correlations(data$data, config)
    }
  } else {
    correlations <- calculate_correlations(data$data, config)
  }

  if (!is.null(correlations)) {
    available_drivers <- intersect(config$driver_vars, rownames(correlations))
    if (length(available_drivers) >= 2) {
      driver_cors <- correlations[available_drivers, available_drivers]
      diag(driver_cors) <- 0
      high_cors <- which(abs(driver_cors) > 0.9, arr.ind = TRUE)
      if (nrow(high_cors) > 0) {
        for (i in seq_len(nrow(high_cors))) {
          if (high_cors[i, 1] < high_cors[i, 2]) {
            var1 <- rownames(driver_cors)[high_cors[i, 1]]
            var2 <- colnames(driver_cors)[high_cors[i, 2]]
            cor_val <- driver_cors[high_cors[i, 1], high_cors[i, 2]]
            guard <- guard_record_collinearity(guard, var1, var2, cor_val)
          }
        }
      }
    }
  }

  list(correlations = correlations, guard = guard,
       degraded_reasons = degraded_reasons, affected_outputs = affected_outputs)
}

#' Fit regression model and build term mapping for mixed predictors.
#' @param data Data list (uses $data).
#' @param config Configuration list.
#' @param guard Guard state.
#' @param has_mixed Logical; mixed predictors detected.
#' @return List with model, term_mapping, guard.
#' @keywords internal
step_fit_model <- function(data, config, guard, has_mixed) {
  model <- fit_keydriver_model(data$data, config)
  term_mapping <- NULL

  if (has_mixed) {
    formula_str <- paste(config$outcome_var, "~", paste(config$driver_vars, collapse = " + "))
    term_mapping <- build_term_mapping(stats::as.formula(formula_str), data$data, config$driver_vars)
    validate_term_mapping(term_mapping, config$driver_vars)
  } else {
    guard <- validate_keydriver_mapping(model, config$driver_vars, guard)
  }

  list(model = model, term_mapping = term_mapping, guard = guard)
}

#' Calculate importance using mixed-predictor aggregation or traditional method.
#' @param model Fitted lm model.
#' @param data Data list (uses $data).
#' @param config Configuration list.
#' @param correlations Correlation matrix or NULL.
#' @param term_mapping Term mapping or NULL.
#' @param has_mixed Logical; mixed predictors detected.
#' @return Data frame of importance scores.
#' @keywords internal
step_calculate_importance <- function(model, data, config, correlations,
                                      term_mapping, has_mixed) {
  if (has_mixed && !is.null(term_mapping)) {
    calculate_importance_mixed(model, data$data, config, term_mapping,
                              correlations = correlations)
  } else {
    calculate_importance_scores(model, data$data, correlations, config)
  }
}

#' Run an optional feature with on_fail policy (refuse or continue_with_flag).
#' @param feature_name Human-readable name (e.g., "SHAP").
#' @param feature_fn Zero-argument function executing the feature.
#' @param on_fail_policy "refuse" or "continue_with_flag".
#' @param refuse_code TRS refusal code on hard failure.
#' @param guard Guard state.
#' @param guard_tag Tag for guard_warn (e.g., "shap").
#' @param affected Character vector of affected output names on failure.
#' @return List with result, guard, degraded_reasons, affected_outputs.
#' @keywords internal
handle_optional_feature <- function(feature_name, feature_fn, on_fail_policy,
                                     refuse_code, guard, guard_tag, affected) {
  degraded_reasons <- character(0)
  affected_outputs <- character(0)

  feature_result <- tryCatch({
    feature_fn()
  }, error = function(e) {
    if (on_fail_policy == "refuse") {
      keydriver_refuse(
        code = refuse_code,
        title = paste(feature_name, "Analysis Failed"),
        problem = paste0(feature_name, " analysis failed: ", e$message),
        why_it_matters = paste0(
          feature_name, " analysis is enabled with on_fail='refuse' policy. ",
          "Analysis cannot continue without successful ", feature_name, " completion."),
        how_to_fix = c(
          paste0("Fix the underlying ", feature_name, " error"),
          paste0("Or set ", tolower(feature_name), "_on_fail='continue_with_flag' in Settings"),
          paste0("Or disable ", feature_name, " by setting enable_",
                 tolower(feature_name), "=FALSE"))
      )
    } else {
      list(.failed = TRUE, error_message = e$message)
    }
  })

  if (is.list(feature_result) && isTRUE(feature_result$.failed)) {
    guard <- guard_warn(guard, paste0(feature_name, " failed: ", feature_result$error_message), guard_tag)
    guard[[paste0(guard_tag, "_status")]] <- "failed"
    degraded_reasons <- paste0(feature_name, " analysis failed: ", feature_result$error_message)
    affected_outputs <- affected
    feature_result <- NULL
  }

  list(result = feature_result, guard = guard,
       degraded_reasons = degraded_reasons, affected_outputs = affected_outputs)
}

#' Determine final TRS run status (PASS or PARTIAL) from degraded reasons.
#' @param degraded_reasons Character vector of degradation reasons.
#' @param affected_outputs Character vector of affected output names.
#' @param guard Guard state.
#' @return List with run_status, status, status_details, guard_summary.
#' @keywords internal
determine_run_status <- function(degraded_reasons, affected_outputs, guard) {
  guard_summary <- keydriver_guard_summary(guard)
  status_details <- NULL

  if (length(degraded_reasons) > 0) {
    run_status <- "PARTIAL"
    status <- trs_status_partial(module = "KEYDRIVER",
      degraded_reasons = degraded_reasons, affected_outputs = affected_outputs)
    status_details <- list(degraded_reasons = degraded_reasons,
                           affected_outputs = affected_outputs)
  } else {
    run_status <- "PASS"
    status <- trs_status_pass(module = "KEYDRIVER")
  }

  list(run_status = run_status, status = status,
       status_details = status_details, guard_summary = guard_summary)
}

# ==============================================================================
# ORCHESTRATOR
# ==============================================================================

#' Internal implementation: orchestrates the key driver pipeline.
#' All console output lives here; step functions are silent.
#' @keywords internal
run_keydriver_analysis_impl <- function(config_file, data_file = NULL, output_file = NULL,
                                        html_report = NULL) {

  # --- TRS Run State Init ---
  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("KEYDRIVER")
  } else { NULL }

  start_time <- Sys.time()
  if (exists("turas_print_start_banner", mode = "function")) {
    turas_print_start_banner("KEYDRIVER", KEYDRIVER_VERSION)
  } else {
    trs_banner_start("KEY DRIVER ANALYSIS", KEYDRIVER_VERSION)
  }

  guard <- keydriver_guard_init()
  degraded_reasons <- character(0)
  affected_outputs <- character(0)

  # --- Step 1: Load Configuration ---
  cat("1. Loading configuration...\n")
  step1 <- step_load_config(config_file, data_file, output_file)
  config <- step1$config; data_file <- step1$data_file; output_file <- step1$output_file
  enable_shap <- step1$enable_shap; enable_quadrant <- step1$enable_quadrant

  cat(sprintf("   [OK] Outcome variable: %s\n", config$outcome_var))
  cat(sprintf("   [OK] Driver variables: %d variables\n", length(config$driver_vars)))
  if (enable_shap) cat("   [OK] SHAP analysis enabled\n")
  if (enable_quadrant) cat("   [OK] Quadrant analysis enabled\n")

  fingerprint_file <- if (!is.null(config$config_file)) config$config_file else config_file
  config_mtime <- file.info(fingerprint_file)$mtime
  cat("\n   [CONFIG FINGERPRINT]\n")
  cat("   Path: ", fingerprint_file, "\n", sep = "")
  cat("   Modified: ", format(config_mtime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
  cat("   Outcome: ", config$outcome_var, "\n", sep = "")
  cat("   Drivers: ", paste(config$driver_vars, collapse = ", "), "\n", sep = "")

  # --- Step 2: Load and Validate Data ---
  cat("\n2. Loading and validating data...\n")
  step2 <- step_load_and_validate_data(data_file, config)
  data <- step2$data; config <- step2$config; has_mixed <- step2$has_mixed

  cat(sprintf("   [OK] Loaded %d respondents\n", data$n_respondents))
  cat(sprintf("   [OK] Complete cases: %d\n", data$n_complete))
  if (data$n_missing > 0) {
    cat(sprintf("   [INFO] Excluded %d rows with missing data (%.1f%%)\n",
                data$n_missing, 100 * data$n_missing / (data$n_complete + data$n_missing)))
  }
  if (!is.null(config$driver_settings)) {
    cat("   [VALIDATING] Driver type consistency...\n")
    cat("   [OK] Driver types match configuration\n")
  }
  if (has_mixed) {
    cat("\n   [MIXED PREDICTORS DETECTED]\n")
    if (!is.null(config$encoding_report)) print_encoding_summary(config$encoding_report)
  }

  # --- Step 3: Calculate Correlations ---
  cat("\n3. Calculating correlations...\n")
  step3 <- step_calculate_correlations(data, config, guard, has_mixed)
  correlations <- step3$correlations; guard <- step3$guard
  degraded_reasons <- c(degraded_reasons, step3$degraded_reasons)
  affected_outputs <- c(affected_outputs, step3$affected_outputs)

  if (has_mixed) {
    numeric_drivers <- get_numeric_drivers(data$data, config$driver_vars)
    if (length(numeric_drivers) < length(config$driver_vars)) {
      cat("   [PARTIAL] Correlations computed for numeric drivers only\n")
      cat(sprintf("   - %d of %d drivers are numeric\n",
                  length(numeric_drivers), length(config$driver_vars)))
    }
    if (is.null(correlations) && length(numeric_drivers) < 2) {
      cat("   [WARN] Not enough numeric drivers for correlation matrix\n")
    }
  }
  if (!is.null(correlations)) {
    cat("   [OK] Correlation matrix calculated\n")
    for (cw in guard$collinearity_warnings) {
      cat(sprintf("   [WARN] High collinearity: %s <-> %s (r=%.2f)\n",
                  cw$var1, cw$var2, cw$correlation))
    }
  }

  # --- Step 4: Fit Regression Model ---
  cat("\n4. Fitting regression model...\n")
  step4 <- step_fit_model(data, config, guard, has_mixed)
  model <- step4$model; term_mapping <- step4$term_mapping; guard <- step4$guard

  cat(sprintf("   [OK] Model R-squared = %.3f\n", summary(model)$r.squared))

  # Post-fit model assumption checks (VIF, residual normality)
  if (exists("guard_validate_model_assumptions", mode = "function")) {
    guard <- guard_validate_model_assumptions(model, data, config, guard)
    if (length(guard$assumption_violations) > 0) {
      for (av in guard$assumption_violations) {
        cat(sprintf("   [WARN] %s\n", av$message))
      }
    }
  }

  if (has_mixed) {
    cat("\n   [BUILDING TERM MAPPING]\n")
    if (!is.null(term_mapping)) print_term_mapping_summary(term_mapping)
  }

  # --- Step 5: Calculate Importance ---
  cat("\n5. Calculating importance scores...\n")
  if (has_mixed && !is.null(term_mapping)) {
    cat("   Using driver-level aggregation for mixed predictors\n")
  }
  importance <- step_calculate_importance(model, data, config, correlations,
                                          term_mapping, has_mixed)
  cat("   [OK] Multiple importance methods calculated\n")

  results <- list(importance = importance, model = model, correlations = correlations,
                  config = config, shap = NULL, quadrant = NULL, guard = guard,
                  run_status = "PASS")

  # --- Step 6: SHAP Analysis (if enabled) ---
  shap_on_fail <- config$feature_policies$shap$on_fail %||% "refuse"
  if (enable_shap) {
    cat("\n6. Running SHAP analysis...\n")
    cat(sprintf("   [POLICY] on_fail = %s\n", shap_on_fail))

    shap_out <- handle_optional_feature(
      feature_name = "SHAP",
      feature_fn = function() run_shap_analysis_internal(data$data, config),
      on_fail_policy = shap_on_fail, refuse_code = "FEATURE_SHAP_FAILED",
      guard = guard, guard_tag = "shap",
      affected = c("SHAP importance", "SHAP plots"))

    guard <- shap_out$guard
    degraded_reasons <- c(degraded_reasons, shap_out$degraded_reasons)
    affected_outputs <- c(affected_outputs, shap_out$affected_outputs)

    if (!is.null(shap_out$result)) {
      results$shap <- shap_out$result
      guard$shap_status <- "complete"
      cat("   [OK] SHAP analysis complete\n")
      if (!is.null(shap_out$result$importance)) {
        importance <- add_shap_to_importance(importance, shap_out$result$importance)
        results$importance <- importance
      }
    } else if (shap_on_fail != "refuse") {
      cat("\n================================================================================\n")
      cat("  [WARNING] SHAP ANALYSIS FAILED - CONTINUING WITH PARTIAL OUTPUT\n")
      cat("================================================================================\n")
      if (length(shap_out$degraded_reasons) > 0) {
        cat(sprintf("  Error: %s\n", sub("^SHAP analysis failed: ", "", shap_out$degraded_reasons[1])))
      }
      cat("  The analysis will continue but SHAP outputs will be missing.\n")
      cat("================================================================================\n\n")
    }
  }

  # --- Step 7: Quadrant Analysis (if enabled) ---
  quadrant_on_fail <- config$feature_policies$quadrant$on_fail %||% "refuse"
  if (enable_quadrant) {
    step_num <- if (enable_shap) "7" else "6"
    cat(sprintf("\n%s. Running quadrant analysis...\n", step_num))
    cat(sprintf("   [POLICY] on_fail = %s\n", quadrant_on_fail))

    quad_out <- handle_optional_feature(
      feature_name = "Quadrant",
      feature_fn = function() run_quadrant_analysis_internal(results, data$data, config),
      on_fail_policy = quadrant_on_fail, refuse_code = "FEATURE_QUADRANT_FAILED",
      guard = guard, guard_tag = "quadrant",
      affected = c("Quadrant charts", "IPA analysis"))

    guard <- quad_out$guard
    degraded_reasons <- c(degraded_reasons, quad_out$degraded_reasons)
    affected_outputs <- c(affected_outputs, quad_out$affected_outputs)

    if (!is.null(quad_out$result)) {
      results$quadrant <- quad_out$result
      guard$quadrant_status <- "complete"
      cat("   [OK] Quadrant analysis complete\n")
    } else if (quadrant_on_fail != "refuse") {
      cat("\n================================================================================\n")
      cat("  [WARNING] QUADRANT ANALYSIS FAILED - CONTINUING WITH PARTIAL OUTPUT\n")
      cat("================================================================================\n")
      if (length(quad_out$degraded_reasons) > 0) {
        cat(sprintf("  Error: %s\n", sub("^Quadrant analysis failed: ", "", quad_out$degraded_reasons[1])))
      }
      cat("  The analysis will continue but Quadrant outputs will be missing.\n")
      cat("================================================================================\n\n")
    }
  }

  # --- Step 8: Bootstrap Confidence Intervals (if enabled) ---
  enable_bootstrap <- isTRUE(as.logical(config$settings$enable_bootstrap))
  if (enable_bootstrap) {
    step_num <- 6 + (if (enable_shap) 1 else 0) + (if (enable_quadrant) 1 else 0) + 1
    cat(sprintf("\n%d. Bootstrap confidence intervals...\n", step_num))

    turas_root <- find_turas_root()
    source(file.path(turas_root, "modules/keydriver/R/05_bootstrap.R"), local = FALSE)

    bootstrap_result <- tryCatch({
      bootstrap_importance_ci(
        data = data$data,
        outcome = config$outcome_var,
        drivers = config$driver_vars,
        weights = config$weight_var,
        n_bootstrap = as.numeric(config$settings$bootstrap_iterations %||% 500),
        ci_level = as.numeric(config$settings$bootstrap_ci_level %||% 0.95)
      )
    }, error = function(e) {
      cat(sprintf("   [WARN] Bootstrap failed: %s\n", e$message))
      degraded_reasons <<- c(degraded_reasons, paste0("Bootstrap CI failed: ", e$message))
      affected_outputs <<- c(affected_outputs, "Bootstrap confidence intervals")
      NULL
    })

    if (!is.null(bootstrap_result)) {
      results$bootstrap_ci <- bootstrap_result
      cat(sprintf("   [OK] Bootstrap CIs computed (%s iterations)\n",
                  config$settings$bootstrap_iterations %||% "500"))
    }
  }

  # --- Step 9: Effect Size Interpretation ---
  step_num_effect <- 6 + (if (enable_shap) 1 else 0) + (if (enable_quadrant) 1 else 0) +
                     (if (enable_bootstrap) 1 else 0) + 1
  cat(sprintf("\n%d. Effect size interpretation...\n", step_num_effect))

  turas_root <- find_turas_root()
  source(file.path(turas_root, "modules/keydriver/R/06_effect_size.R"), local = FALSE)

  effect_result <- tryCatch({
    r2_full <- summary(model)$r.squared
    driver_vars <- config$driver_vars

    r2_reduced <- vapply(driver_vars, function(drv) {
      other_drivers <- setdiff(driver_vars, drv)
      formula_str <- paste(config$outcome_var, "~", paste(other_drivers, collapse = " + "))
      reduced_model <- stats::lm(stats::as.formula(formula_str), data = data$data,
                                  weights = if (!is.null(config$weight_var)) data$data[[config$weight_var]] else NULL)
      summary(reduced_model)$r.squared
    }, numeric(1))
    names(r2_reduced) <- driver_vars

    model_info <- list(r_squared_full = r2_full, r_squared_reduced = r2_reduced)
    generate_effect_interpretation(results$importance, model_summary = model_info)
  }, error = function(e) {
    cat(sprintf("   [WARN] Effect size interpretation failed: %s\n", e$message))
    NULL
  })

  if (!is.null(effect_result)) {
    results$effect_sizes <- effect_result
    cat("   [OK] Effect sizes classified\n")
  }

  # --- Step 10: Segment Comparison (if segments configured) ---
  if (!is.null(config$segments) && nrow(config$segments) > 0) {
    step_num_seg <- step_num_effect + 1
    cat(sprintf("\n%d. Segment comparison analysis...\n", step_num_seg))

    source(file.path(turas_root, "modules/keydriver/R/07_segment_comparison.R"), local = FALSE)

    segment_result <- tryCatch({
      seg_var <- config$segments$segment_variable[1]
      # Use raw_data (pre-filtering) since segment variable may not be in analysis variables
      seg_data <- if (!is.null(config$raw_data)) config$raw_data else data$data
      run_segment_importance_comparison(
        data = seg_data,
        outcome = config$outcome_var,
        drivers = config$driver_vars,
        segment_var = seg_var,
        config = list(top_n = 3, rank_diff_threshold = 3, min_segment_n = 30)
      )
    }, error = function(e) {
      cat(sprintf("   [WARN] Segment comparison failed: %s\n", e$message))
      NULL
    })

    if (!is.null(segment_result)) {
      results$segment_comparison <- segment_result
      cat(sprintf("   [OK] Segment comparison complete (%d segments)\n",
                  nrow(config$segments)))
    }
  }

  # --- Optional Advanced Features (v10.4) ---
  # Each uses requireNamespace() internally and returns PARTIAL if unavailable.
  next_step <- step_num_effect + (if (!is.null(config$segments) && nrow(config$segments) > 0) 1 else 0) + 1

  # Elastic Net
  enable_elastic_net <- isTRUE(as.logical(config$settings$enable_elastic_net))
  if (enable_elastic_net) {
    cat(sprintf("\n%d. Elastic Net analysis...\n", next_step))
    source(file.path(turas_root, "modules/keydriver/R/09_elastic_net.R"), local = FALSE)
    enet_result <- tryCatch(
      run_elastic_net_analysis(data$data, config),
      error = function(e) {
        cat(sprintf("   [WARN] Elastic net failed: %s\n", e$message))
        list(status = "PARTIAL", message = e$message, result = NULL)
      }
    )
    if (!is.null(enet_result$result)) {
      results$elastic_net <- enet_result$result
      cat("   [OK] Elastic net analysis complete\n")
    } else {
      cat(sprintf("   [SKIP] %s\n", enet_result$message))
    }
    next_step <- next_step + 1
  }

  # Necessary Condition Analysis (NCA)
  enable_nca <- isTRUE(as.logical(config$settings$enable_nca))
  if (enable_nca) {
    cat(sprintf("\n%d. Necessary Condition Analysis...\n", next_step))
    source(file.path(turas_root, "modules/keydriver/R/10_nca.R"), local = FALSE)
    nca_result <- tryCatch(
      run_nca_analysis(data$data, config),
      error = function(e) {
        cat(sprintf("   [WARN] NCA failed: %s\n", e$message))
        list(status = "PARTIAL", message = e$message, result = NULL)
      }
    )
    if (!is.null(nca_result$result)) {
      results$nca <- nca_result$result
      cat("   [OK] NCA analysis complete\n")
    } else {
      cat(sprintf("   [SKIP] %s\n", nca_result$message))
    }
    next_step <- next_step + 1
  }

  # Dominance Analysis
  enable_dominance <- isTRUE(as.logical(config$settings$enable_dominance))
  if (enable_dominance) {
    cat(sprintf("\n%d. Dominance Analysis...\n", next_step))
    source(file.path(turas_root, "modules/keydriver/R/11_dominance.R"), local = FALSE)
    dom_result <- tryCatch(
      run_dominance_analysis(data$data, config),
      error = function(e) {
        cat(sprintf("   [WARN] Dominance analysis failed: %s\n", e$message))
        list(status = "PARTIAL", message = e$message, result = NULL)
      }
    )
    if (!is.null(dom_result$result)) {
      results$dominance <- dom_result$result
      cat("   [OK] Dominance analysis complete\n")
    } else {
      cat(sprintf("   [SKIP] %s\n", dom_result$message))
    }
    next_step <- next_step + 1
  }

  # GAM Nonlinear Effects
  enable_gam <- isTRUE(as.logical(config$settings$enable_gam))
  if (enable_gam) {
    cat(sprintf("\n%d. GAM nonlinear effects...\n", next_step))
    source(file.path(turas_root, "modules/keydriver/R/12_gam.R"), local = FALSE)
    gam_result <- tryCatch(
      run_gam_analysis(data$data, config),
      error = function(e) {
        cat(sprintf("   [WARN] GAM analysis failed: %s\n", e$message))
        list(status = "PARTIAL", message = e$message, result = NULL)
      }
    )
    if (!is.null(gam_result$result)) {
      results$gam <- gam_result$result
      cat("   [OK] GAM analysis complete\n")
    } else {
      cat(sprintf("   [SKIP] %s\n", gam_result$message))
    }
    next_step <- next_step + 1
  }

  # --- Executive Summary ---
  step_num_exec <- next_step
  cat(sprintf("\n%d. Generating executive summary...\n", step_num_exec))

  source(file.path(turas_root, "modules/keydriver/R/08_executive_summary.R"), local = FALSE)

  exec_summary <- tryCatch({
    generate_executive_summary(results)
  }, error = function(e) {
    cat(sprintf("   [WARN] Executive summary failed: %s\n", e$message))
    NULL
  })

  if (!is.null(exec_summary)) {
    results$executive_summary <- exec_summary
    cat("   [OK] Executive summary generated\n")
  }

  # --- Determine Final Status ---
  status_out <- determine_run_status(degraded_reasons, affected_outputs, guard)
  results$run_status <- status_out$run_status
  results$status <- status_out$status
  results$guard_summary <- status_out$guard_summary

  # --- Generate Excel Output ---
  step_num_output <- step_num_exec + 1
  cat(sprintf("\n%d. Generating output file...\n", step_num_output))
  write_keydriver_output_enhanced(
    results = results, output_file = output_file,
    run_status = results$run_status, status_details = status_out$status_details)
  cat(sprintf("   [OK] Results written to: %s\n", output_file))

  # --- Generate HTML Report (if enabled) ---
  # GUI parameter overrides config file setting
  enable_html <- if (!is.null(html_report)) {
    isTRUE(html_report)
  } else {
    isTRUE(as.logical(config$settings$enable_html_report))
  }
  if (enable_html) {
    step_num_html <- step_num_output + 1
    cat(sprintf("\n%d. Generating HTML report...\n", step_num_html))

    html_lib_dir <- file.path(turas_root, "modules", "keydriver", "lib", "html_report")
    html_main <- file.path(html_lib_dir, "99_html_report_main.R")

    if (file.exists(html_main)) {
      # Set lib dir for submodule sourcing
      assign(".keydriver_lib_dir", file.path(turas_root, "modules", "keydriver", "lib"),
             envir = globalenv())
      source(html_main, local = FALSE)

      html_output_path <- sub("\\.xlsx$", ".html", output_file)

      html_config <- list(
        brand_colour  = config$settings$brand_colour  %||% "#323367",
        accent_colour = config$settings$accent_colour %||% "#f59e0b",
        report_title  = config$settings$report_title  %||% NULL,
        output_file   = output_file,
        settings      = config$settings
      )

      html_result <- tryCatch({
        generate_keydriver_html_report(
          results = results,
          config = html_config,
          output_path = html_output_path
        )
      }, error = function(e) {
        cat(sprintf("   [WARN] HTML report generation failed: %s\n", e$message))
        degraded_reasons <<- c(degraded_reasons, paste0("HTML report failed: ", e$message))
        affected_outputs <<- c(affected_outputs, "HTML interactive report")
        NULL
      })

      if (!is.null(html_result) && !is.null(html_result$status) && html_result$status != "REFUSED") {
        results$html_report <- html_result
        cat(sprintf("   [OK] HTML report: %s\n", html_output_path))

        # Minify for client delivery (if requested via Shiny checkbox)
        if (exists("turas_prepare_deliverable", mode = "function")) {
          turas_prepare_deliverable(html_output_path)
        }
      }
    } else {
      cat("   [SKIP] HTML report library not found\n")
    }
  }

  # --- Completion ---
  end_time <- Sys.time()
  elapsed <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 1)

  if (!is.null(trs_state) && length(degraded_reasons) > 0) {
    for (reason in degraded_reasons) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(trs_state, "KD_DEGRADED", "Degraded output", problem = reason)
      }
    }
  }

  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else { NULL }
  results$run_result <- run_result

  # --- Generate Stats Pack (optional) ---
  generate_stats_pack_flag <- isTRUE(
    toupper(config$settings$Generate_Stats_Pack %||% "Y") == "Y"
  ) || isTRUE(getOption("turas.generate_stats_pack", FALSE))

  if (generate_stats_pack_flag) {
    cat("\nGenerating stats pack...\n")
    generate_keydriver_stats_pack(
      config      = config,
      survey_data = data$data,
      result      = results,
      run_result  = run_result,
      start_time  = start_time,
      verbose     = TRUE
    )
  }

  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else {
    trs_banner_end("KEY DRIVER ANALYSIS", results$run_status, elapsed)
  }

  cat("TOP 5 DRIVERS:\n")
  if (!is.null(results$shap)) {
    cat("(by SHAP importance)\n")
    top_drivers <- head(results$shap$importance, 5)
    for (i in seq_len(nrow(top_drivers))) {
      cat(sprintf("  %d. %s (%.1f%%)\n", i, top_drivers$driver[i], top_drivers$importance_pct[i]))
    }
  } else {
    cat("(by Shapley value)\n")
    top_drivers <- head(results$importance[order(-results$importance$Shapley_Value), ], 5)
    for (i in seq_len(nrow(top_drivers))) {
      cat(sprintf("  %d. %s (%.1f%%)\n", i, top_drivers$Driver[i], top_drivers$Shapley_Value[i]))
    }
  }

  if (!is.null(results$quadrant) && !is.null(results$quadrant$data)) {
    cat("\nQUADRANT SUMMARY:\n")
    q_vals <- as.character(results$quadrant$data$quadrant)
    q_counts <- table(q_vals)
    q_labels <- c("1" = "Concentrate Here", "2" = "Keep Up Good Work",
                  "3" = "Low Priority", "4" = "Possible Overkill")
    for (q in c("1", "2", "3", "4")) {
      n <- if (q %in% names(q_counts)) as.integer(q_counts[[q]]) else 0L
      cat(sprintf("  Q%s (%s): %d drivers\n", q, q_labels[[q]], n))
    }
  }

  if (status_out$guard_summary$has_issues) {
    cat("\nWARNINGS:\n")
    for (flag in status_out$guard_summary$stability_flags) {
      cat(sprintf("  - %s\n", flag))
    }
  }

  cat("\n")
  invisible(results)
}

# ==============================================================================
# STATS PACK HELPER
# ==============================================================================

#' Generate Key Driver Stats Pack
#'
#' Builds the diagnostic payload from key driver analysis results and writes
#' the stats pack Excel workbook alongside the main output.
#'
#' @keywords internal
generate_keydriver_stats_pack <- function(config, survey_data, result,
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

  importance   <- result$importance
  n_drivers    <- if (!is.null(importance) && is.data.frame(importance)) nrow(importance) else length(config$driver_vars)
  r_squared    <- tryCatch(summary(result$model)$r.squared, error = function(e) NA_real_)
  n_model      <- tryCatch(nobs(result$model), error = function(e) nrow(survey_data))
  shap_enabled <- !is.null(result$shap)

  # Calculate n_excluded: original rows minus complete cases used in model
  n_original   <- nrow(survey_data)
  n_excluded   <- n_original - n_model

  # Weight diagnostics (Phase 3 C4: must include when weights present)
  weight_info <- list()
  is_weighted  <- !is.null(config$weight_var) && nzchar(config$weight_var %||% "")
  if (is_weighted) {
    w <- survey_data[[config$weight_var]]
    if (!is.null(w) && is.numeric(w)) {
      w_valid <- w[!is.na(w) & w > 0]
      if (length(w_valid) > 0) {
        sum_w  <- sum(w_valid)
        sum_w2 <- sum(w_valid^2)
        eff_n  <- (sum_w^2) / sum_w2
        weight_info <- list(
          effective_n   = round(eff_n, 1),
          design_effect = round(length(w_valid) / eff_n, 3),
          weight_cv     = round(sd(w_valid) / mean(w_valid), 3),
          min_weight    = round(min(w_valid), 4),
          max_weight    = round(max(w_valid), 4)
        )
      }
    }
  }

  # Bootstrap summary (if run)
  bootstrap_info <- list()
  if (!is.null(result$bootstrap_ci)) {
    bootstrap_info <- list(
      iterations = config$settings$bootstrap_iterations %||% 1000,
      ci_level   = config$settings$bootstrap_ci_level %||% 0.95,
      methods    = "Correlation, Beta_Weight, Relative_Weight"
    )
  }

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
    "Outcome Variable"  = config$outcome_var %||% "—",
    "Drivers tested"    = as.character(n_drivers),
    "Method"            = "Pearson/Spearman correlation (base R cor())",
    "Regression"        = "OLS linear regression (base R lm())",
    "Model R-squared"   = if (!is.na(r_squared)) sprintf("%.4f", r_squared) else "—",
    "Sample (model)"    = as.character(n_model),
    "Excluded (listwise)" = as.character(n_excluded),
    "SHAP Values"       = if (shap_enabled) "shapr package" else "Not used",
    "Quadrant Analysis" = if (!is.null(result$quadrant)) "Enabled" else "Disabled",
    "TRS Status"        = run_result$status %||% "PASS",
    "TRS Events"        = trs_summary
  )

  # Append weight diagnostics to assumptions
  if (length(weight_info) > 0) {
    assumptions[["Weight Variable"]]  <- config$weight_var
    assumptions[["Effective N"]]      <- as.character(weight_info$effective_n)
    assumptions[["Design Effect"]]    <- as.character(weight_info$design_effect)
    assumptions[["Weight CV"]]        <- as.character(weight_info$weight_cv)
    assumptions[["Min Weight"]]       <- as.character(weight_info$min_weight)
    assumptions[["Max Weight"]]       <- as.character(weight_info$max_weight)
  }

  # Append bootstrap info
  if (length(bootstrap_info) > 0) {
    assumptions[["Bootstrap Iterations"]] <- as.character(bootstrap_info$iterations)
    assumptions[["Bootstrap CI Level"]]   <- as.character(bootstrap_info$ci_level)
    assumptions[["Bootstrap Methods"]]    <- bootstrap_info$methods
  }

  # Append VIF flags from guard
  if (!is.null(result$guard_summary) && !is.null(result$guard_summary$stability_flags)) {
    n_flags <- length(result$guard_summary$stability_flags)
    if (n_flags > 0) {
      assumptions[["Model Warnings"]] <- paste(result$guard_summary$stability_flags, collapse = "; ")
    }
  }

  data_receipt <- list(
    file_name           = basename(config$data_file %||% "unknown"),
    n_rows              = n_original,
    n_cols              = ncol(survey_data),
    questions_in_config = length(config$driver_vars)
  )

  data_used <- list(
    n_respondents      = n_model,
    n_excluded         = n_excluded,
    weight_variable    = config$weight_var %||% "",
    weighted           = is_weighted,
    questions_analysed = n_drivers,
    questions_skipped  = 0L
  )

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  payload <- list(
    module           = "KEYDRIVER",
    project_name     = config$settings$Project_Name   %||% NULL,
    analyst_name     = config$settings$Analyst_Name   %||% NULL,
    research_house   = config$settings$Research_House %||% NULL,
    run_timestamp    = start_time,
    turas_version    = KEYDRIVER_VERSION,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = duration_secs,
    data_receipt     = data_receipt,
    data_used        = data_used,
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = c("openxlsx", "data.table"),
    config_echo      = list(settings = config$settings)
  )

  result_path <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result_path) && verbose) {
    cat(sprintf("  + Stats pack written: %s\n", basename(output_path)))
  }

  result_path
}


# ==============================================================================
# INTERNAL HELPERS (kept as-is)
# ==============================================================================

#' Internal: Run SHAP Analysis
#'
#' Wrapper to run SHAP analysis with proper sourcing.
#' @keywords internal
run_shap_analysis_internal <- function(data, config) {
  turas_root <- find_turas_root()
  shap_dir <- file.path(turas_root, "modules/keydriver/R/kda_shap")
  methods_dir <- file.path(turas_root, "modules/keydriver/R/kda_methods")

  source(file.path(shap_dir, "shap_model.R"), local = FALSE)
  source(file.path(shap_dir, "shap_calculate.R"), local = FALSE)
  source(file.path(shap_dir, "shap_visualize.R"), local = FALSE)
  source(file.path(shap_dir, "shap_segment.R"), local = FALSE)
  source(file.path(shap_dir, "shap_interaction.R"), local = FALSE)
  source(file.path(shap_dir, "shap_export.R"), local = FALSE)
  source(file.path(methods_dir, "method_shap.R"), local = FALSE)

  shap_config <- list(
    shap_model = config$settings$shap_model %||% "xgboost",
    n_trees = as.numeric(config$settings$n_trees %||% 100),
    max_depth = as.numeric(config$settings$max_depth %||% 6),
    learning_rate = as.numeric(config$settings$learning_rate %||% 0.1),
    subsample = as.numeric(config$settings$subsample %||% 0.8),
    colsample_bytree = as.numeric(config$settings$colsample_bytree %||% 0.8),
    shap_sample_size = as.numeric(config$settings$shap_sample_size %||% 1000),
    include_interactions = isTRUE(as.logical(config$settings$include_interactions)),
    interaction_top_n = as.numeric(config$settings$interaction_top_n %||% 5),
    importance_top_n = as.numeric(config$settings$importance_top_n %||% 15)
  )

  run_shap_analysis(
    data = data, outcome = config$outcome_var, drivers = config$driver_vars,
    weights = config$weight_var, config = shap_config, segments = config$segments)
}

#' Internal: Run Quadrant Analysis
#'
#' Wrapper to run quadrant analysis with proper sourcing.
#' @keywords internal
run_quadrant_analysis_internal <- function(results, data, config) {
  turas_root <- find_turas_root()
  quad_dir <- file.path(turas_root, "modules/keydriver/R/kda_quadrant")

  source(file.path(quad_dir, "quadrant_main.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_data_prep.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_calculate.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_plot.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_comparison.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_export.R"), local = FALSE)

  quad_config <- list(
    importance_source = config$settings$importance_source %||% "auto",
    threshold_method = config$settings$threshold_method %||% "mean",
    normalize_axes = isTRUE(as.logical(config$settings$normalize_axes %||% TRUE)),
    shade_quadrants = isTRUE(as.logical(config$settings$shade_quadrants %||% TRUE)),
    label_all_points = isTRUE(as.logical(config$settings$label_all_points %||% TRUE)),
    label_top_n = as.numeric(config$settings$label_top_n %||% 10),
    show_diagonal = isTRUE(as.logical(config$settings$show_diagonal %||% FALSE))
  )

  # Always pass full results (has $config$driver_vars and $importance$Driver).
 # If SHAP is available and importance_source is "auto", prefer SHAP-based importance.
  if (!is.null(results$shap) && tolower(quad_config$importance_source) == "auto") {
    quad_config$importance_source <- "shap"
  }

  create_quadrant_analysis(
    kda_results = results, data = data, config = quad_config,
    stated_importance = config$stated_importance, segments = config$segments)
}

#' Add SHAP Importance to Main Importance Table
#' @keywords internal
add_shap_to_importance <- function(importance, shap_importance) {
  shap_pct <- setNames(shap_importance$importance_pct, shap_importance$driver)
  shap_rank <- setNames(shap_importance$rank, shap_importance$driver)

  importance$SHAP_Importance <- vapply(importance$Driver, function(d) {
    shap_pct[d] %||% NA_real_
  }, numeric(1))
  importance$SHAP_Rank <- vapply(importance$Driver, function(d) {
    as.integer(shap_rank[d] %||% NA_integer_)
  }, integer(1))
  importance
}

#' Find Turas Root Directory
#'
#' Uses shared utility if available, otherwise falls back to local implementation.
#' @keywords internal
find_turas_root <- function() {
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    cached <- get("TURAS_ROOT", envir = .GlobalEnv)
    if (!is.null(cached) && nzchar(cached)) return(cached)
  }

  current_dir <- getwd()
  while (current_dir != dirname(current_dir)) {
    has_launch <- isTRUE(file.exists(file.path(current_dir, "launch_turas.R")))
    has_turas_r <- isTRUE(file.exists(file.path(current_dir, "turas.R")))
    has_modules_shared <- isTRUE(dir.exists(file.path(current_dir, "modules", "shared")))
    if (has_launch || has_turas_r || has_modules_shared) {
      assign("TURAS_ROOT", current_dir, envir = .GlobalEnv)
      return(current_dir)
    }
    current_dir <- dirname(current_dir)
  }

  keydriver_refuse(
    code = "IO_TURAS_ROOT_NOT_FOUND",
    title = "Cannot Locate Turas Root Directory",
    problem = "Could not find the Turas root directory by searching parent directories.",
    why_it_matters = "Turas needs to locate its module files to run analysis.",
    how_to_fix = c(
      "Ensure you are running from within the Turas project directory",
      "The directory must contain 'launch_turas.R' or 'turas.R' or 'modules/shared/'")
  )
}

#' Write Enhanced Key Driver Output
#'
#' Extended output writer that includes SHAP and Quadrant results.
#' @param results Results list.
#' @param output_file Output file path.
#' @param run_status TRS run status (PASS, PARTIAL).
#' @param status_details Optional list with status details.
#' @keywords internal
write_keydriver_output_enhanced <- function(results, output_file,
                                             run_status = "PASS",
                                             status_details = NULL) {
  write_keydriver_output(
    importance = results$importance, model = results$model,
    correlations = results$correlations, config = results$config,
    output_file = output_file, run_status = run_status,
    status_details = status_details)

  # Re-open workbook to add optional sheets
  has_extras <- !is.null(results$shap) || !is.null(results$quadrant) ||
    !is.null(results$elastic_net) || !is.null(results$nca) ||
    !is.null(results$dominance) || !is.null(results$gam)

  if (has_extras) {
    wb <- openxlsx::loadWorkbook(output_file)

    header_style <- openxlsx::createStyle(
      fontSize = 11, fontColour = "#FFFFFF", fgFill = "#4472C4",
      halign = "left", valign = "center", textDecoration = "bold",
      border = "TopBottomLeftRight"
    )

    if (!is.null(results$shap)) {
      turas_root <- find_turas_root()
      source(file.path(turas_root, "modules/keydriver/R/kda_shap/shap_export.R"), local = FALSE)
      wb <- export_shap_to_excel(results$shap, wb)
      if (!is.null(results$shap$plots)) {
        wb <- insert_shap_charts_to_excel(wb, results$shap$plots)
      }
    }

    if (!is.null(results$quadrant)) {
      turas_root <- find_turas_root()
      source(file.path(turas_root, "modules/keydriver/R/kda_quadrant/quadrant_export.R"), local = FALSE)
      wb <- export_quadrant_to_excel(results$quadrant, wb)
      if (!is.null(results$quadrant$plots)) {
        wb <- insert_quadrant_charts_to_excel(wb, results$quadrant$plots)
      }
    }

    # --- v10.4 Elastic Net sheet ---
    if (!is.null(results$elastic_net)) {
      tryCatch({
        openxlsx::addWorksheet(wb, "Elastic_Net")
        enet <- results$elastic_net
        if (!is.null(enet$coefficients) && is.data.frame(enet$coefficients)) {
          openxlsx::writeData(wb, "Elastic_Net", enet$coefficients, startRow = 1)
          openxlsx::addStyle(wb, "Elastic_Net", header_style, rows = 1,
                            cols = 1:ncol(enet$coefficients), gridExpand = TRUE)
          openxlsx::setColWidths(wb, "Elastic_Net", cols = 1:ncol(enet$coefficients), widths = "auto")
          # Add summary below
          summary_row <- nrow(enet$coefficients) + 3
          summary_df <- data.frame(
            Metric = c("Alpha", "Lambda (1se)", "Lambda (min)", "CV MSE (1se)",
                       "CV MSE (min)", "Selected drivers (1se)", "N observations"),
            Value = c(
              round(enet$alpha %||% 0.5, 3),
              round(enet$lambda_1se %||% 0, 6),
              round(enet$lambda_min %||% 0, 6),
              round(enet$cv_mse_1se %||% 0, 4),
              round(enet$cv_mse_min %||% 0, 4),
              length(enet$selected_drivers %||% character(0)),
              enet$n_obs %||% 0
            ),
            stringsAsFactors = FALSE
          )
          openxlsx::writeData(wb, "Elastic_Net", summary_df, startRow = summary_row)
          openxlsx::addStyle(wb, "Elastic_Net", header_style, rows = summary_row,
                            cols = 1:2, gridExpand = TRUE)
        }
      }, error = function(e) {
        cat(sprintf("   [WARN] Failed to write Elastic Net sheet: %s\n", e$message))
      })
    }

    # --- v10.4 NCA sheet ---
    if (!is.null(results$nca)) {
      tryCatch({
        openxlsx::addWorksheet(wb, "NCA")
        nca <- results$nca
        if (!is.null(nca$nca_summary) && is.data.frame(nca$nca_summary)) {
          openxlsx::writeData(wb, "NCA", nca$nca_summary, startRow = 1)
          openxlsx::addStyle(wb, "NCA", header_style, rows = 1,
                            cols = 1:ncol(nca$nca_summary), gridExpand = TRUE)
          openxlsx::setColWidths(wb, "NCA", cols = 1:ncol(nca$nca_summary), widths = "auto")
          # Summary
          summary_row <- nrow(nca$nca_summary) + 3
          summary_df <- data.frame(
            Metric = c("Necessary drivers", "Analysed drivers", "N observations"),
            Value = c(nca$n_necessary %||% 0, nca$n_analysed %||% 0, nca$n_obs %||% 0),
            stringsAsFactors = FALSE
          )
          openxlsx::writeData(wb, "NCA", summary_df, startRow = summary_row)
          openxlsx::addStyle(wb, "NCA", header_style, rows = summary_row,
                            cols = 1:2, gridExpand = TRUE)
        }
        # Bottleneck table
        if (!is.null(nca$bottleneck_table) && is.data.frame(nca$bottleneck_table)) {
          bt_row <- (nrow(nca$nca_summary) %||% 0) + 8
          openxlsx::writeData(wb, "NCA", "Bottleneck Table:", startRow = bt_row - 1, startCol = 1)
          openxlsx::writeData(wb, "NCA", nca$bottleneck_table, startRow = bt_row)
          openxlsx::addStyle(wb, "NCA", header_style, rows = bt_row,
                            cols = 1:ncol(nca$bottleneck_table), gridExpand = TRUE)
        }
      }, error = function(e) {
        cat(sprintf("   [WARN] Failed to write NCA sheet: %s\n", e$message))
      })
    }

    # --- v10.4 Dominance sheet ---
    if (!is.null(results$dominance)) {
      tryCatch({
        openxlsx::addWorksheet(wb, "Dominance")
        dom <- results$dominance
        if (!is.null(dom$summary) && is.data.frame(dom$summary)) {
          openxlsx::writeData(wb, "Dominance", dom$summary, startRow = 1)
          openxlsx::addStyle(wb, "Dominance", header_style, rows = 1,
                            cols = 1:ncol(dom$summary), gridExpand = TRUE)
          openxlsx::setColWidths(wb, "Dominance", cols = 1:ncol(dom$summary), widths = "auto")
          summary_row <- nrow(dom$summary) + 3
          summary_df <- data.frame(
            Metric = c("Total R-squared", "N drivers", "N sub-models", "N observations"),
            Value = c(
              round(dom$total_r_squared %||% 0, 4),
              dom$n_drivers %||% 0,
              2^(dom$n_drivers %||% 0),
              dom$n_obs %||% 0
            ),
            stringsAsFactors = FALSE
          )
          openxlsx::writeData(wb, "Dominance", summary_df, startRow = summary_row)
          openxlsx::addStyle(wb, "Dominance", header_style, rows = summary_row,
                            cols = 1:2, gridExpand = TRUE)
        }
      }, error = function(e) {
        cat(sprintf("   [WARN] Failed to write Dominance sheet: %s\n", e$message))
      })
    }

    # --- v10.4 GAM sheet ---
    if (!is.null(results$gam)) {
      tryCatch({
        openxlsx::addWorksheet(wb, "GAM")
        gam_data <- results$gam
        if (!is.null(gam_data$nonlinearity_summary) && is.data.frame(gam_data$nonlinearity_summary)) {
          openxlsx::writeData(wb, "GAM", gam_data$nonlinearity_summary, startRow = 1)
          openxlsx::addStyle(wb, "GAM", header_style, rows = 1,
                            cols = 1:ncol(gam_data$nonlinearity_summary), gridExpand = TRUE)
          openxlsx::setColWidths(wb, "GAM", cols = 1:ncol(gam_data$nonlinearity_summary), widths = "auto")
          summary_row <- nrow(gam_data$nonlinearity_summary) + 3
          summary_df <- data.frame(
            Metric = c("Deviance explained (GAM)", "Linear R-squared", "Improvement",
                       "Nonlinear drivers", "Analysed drivers", "Basis dimension (k)",
                       "N observations"),
            Value = c(
              round(gam_data$deviance_explained %||% 0, 4),
              round(gam_data$linear_r_squared %||% 0, 4),
              round(gam_data$improvement %||% 0, 4),
              gam_data$n_nonlinear %||% 0,
              gam_data$n_analysed %||% 0,
              gam_data$k_basis %||% 5,
              gam_data$n_obs %||% 0
            ),
            stringsAsFactors = FALSE
          )
          openxlsx::writeData(wb, "GAM", summary_df, startRow = summary_row)
          openxlsx::addStyle(wb, "GAM", header_style, rows = summary_row,
                            cols = 1:2, gridExpand = TRUE)
        }
      }, error = function(e) {
        cat(sprintf("   [WARN] Failed to write GAM sheet: %s\n", e$message))
      })
    }

    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  }
}

#' @export
keydriver <- run_keydriver_analysis  # Alias for convenience
