# ==============================================================================
# TURAS KEY DRIVER ANALYSIS MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Key Driver Analysis (Relative Importance)
# Purpose: Determine which independent variables (drivers) have the greatest
#          impact on a dependent variable (outcome)
# Version: Turas v10.2 (TRS Integration)
# Date: 2025-12
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

#' Run Key Driver Analysis
#'
#' Analyzes which variables drive an outcome using multiple statistical methods.
#'
#' METHODS IMPLEMENTED:
#' 1. Standardized Coefficients (Beta weights)
#' 2. Relative Weights (Johnson's method)
#' 3. Shapley Value Decomposition
#' 4. Correlation-based importance
#' 5. SHAP Analysis (XGBoost-based) - NEW in v10.1
#'
#' OUTPUTS:
#' - Importance rankings from multiple methods
#' - Quadrant charts (IPA) for actionable insights
#' - Segment comparisons (optional)
#' - Interactive visualizations
#'
#' @param config_file Path to key driver configuration Excel file
#'   Required sheets: Settings, Variables
#'   Optional sheets: SHAPParameters, QuadrantParameters, Segments
#'   Settings sheet should include: data_file, output_file
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA).
#'   If NULL, reads from config Settings sheet.
#' @param output_file Path for results Excel file.
#'   If NULL, reads from config Settings sheet.
#'
#' @return List containing:
#'   - importance: Data frame with importance scores from each method
#'   - model: Regression model object
#'   - correlations: Correlation matrix
#'   - shap: SHAP analysis results (if enabled)
#'   - quadrant: Quadrant analysis results (if enabled)
#'   - config: Processed configuration
#'
#' @examples
#' \dontrun{
#' # Using config file with paths specified in Settings
#' results <- run_keydriver_analysis(
#'   config_file = "keydriver_config.xlsx"
#' )
#'
#' # Override paths from config
#' results <- run_keydriver_analysis(
#'   config_file = "keydriver_config.xlsx",
#'   data_file = "my_data.csv",
#'   output_file = "my_results.xlsx"
#' )
#'
#' # View importance rankings
#' print(results$importance)
#'
#' # View SHAP results (if enabled)
#' print(results$shap$importance)
#'
#' # View quadrant chart
#' print(results$quadrant$plots$standard_ipa)
#' }
#'
#' @export
run_keydriver_analysis <- function(config_file, data_file = NULL, output_file = NULL) {

  # ==========================================================================
  # TRS REFUSAL HANDLER WRAPPER
  # ==========================================================================
  # Catches turas_refusal conditions and displays them cleanly
  # without stack traces - they are intentional stops, not crashes.

  keydriver_with_refusal_handler(
    run_keydriver_analysis_impl(config_file, data_file, output_file)
  )
}


#' Internal Implementation of Key Driver Analysis
#'
#' @keywords internal
run_keydriver_analysis_impl <- function(config_file, data_file = NULL, output_file = NULL) {

  # ==========================================================================
  # INITIALIZATION
  # ==========================================================================

  start_time <- Sys.time()

  # TRS start banner
  trs_banner_start("KEY DRIVER ANALYSIS", "10.2")

  # Initialize guard state for tracking warnings and issues
  guard <- keydriver_guard_init()

  # Track degraded outputs for PARTIAL status
  degraded_reasons <- character(0)
  affected_outputs <- character(0)

  # ==========================================================================
  # STEP 1: LOAD CONFIGURATION
  # ==========================================================================

  cat("1. Loading configuration...\n")
  config <- load_keydriver_config(config_file)
  cat(sprintf("   [OK] Outcome variable: %s\n", config$outcome_var))
  cat(sprintf("   [OK] Driver variables: %d variables\n", length(config$driver_vars)))

  # Validate config (hard gate)
  validate_keydriver_config(config)

  # Check for optional features
  enable_shap <- isTRUE(config$settings$enable_shap) ||
                 isTRUE(as.logical(config$settings$enable_shap))
  enable_quadrant <- isTRUE(config$settings$enable_quadrant) ||
                     isTRUE(as.logical(config$settings$enable_quadrant))

  if (enable_shap) cat("   [OK] SHAP analysis enabled\n")
  if (enable_quadrant) cat("   [OK] Quadrant analysis enabled\n")

  # TRS: Print config fingerprint for traceability
  # Use config_file parameter if config$config_file is not set
  fingerprint_file <- if (!is.null(config$config_file)) config$config_file else config_file
  config_mtime <- file.info(fingerprint_file)$mtime
  cat("\n   [CONFIG FINGERPRINT]\n")
  cat("   Path: ", fingerprint_file, "\n", sep = "")
  cat("   Modified: ", format(config_mtime, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
  cat("   Outcome: ", config$outcome_var, "\n", sep = "")
  cat("   Drivers: ", paste(config$driver_vars, collapse = ", "), "\n", sep = "")

  # Get data_file from config if not provided
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

  # Get output_file from config if not provided
  if (is.null(output_file)) {
    output_file <- config$output_file
    if (is.null(output_file) || is.na(output_file)) {
      # Default to project_root/keydriver_results.xlsx
      output_file <- file.path(config$project_root, "keydriver_results.xlsx")
    }
  }

  # ==========================================================================
  # STEP 2: LOAD AND VALIDATE DATA
  # ==========================================================================

  cat("\n2. Loading and validating data...\n")
  data <- load_keydriver_data(data_file, config)
  cat(sprintf("   [OK] Loaded %d respondents\n", data$n_respondents))
  cat(sprintf("   [OK] Complete cases: %d\n", data$n_complete))

  # Report exclusions if any
  if (data$n_missing > 0) {
    cat(sprintf("   [INFO] Excluded %d rows with missing data (%.1f%%)\n",
                data$n_missing, 100 * data$n_missing / (data$n_complete + data$n_missing)))
  }

  # Store raw data in config for later use
  config$raw_data <- data$data

  # ==========================================================================
  # STEP 2.5: DETECT MIXED PREDICTORS & APPLY ENCODING POLICY
  # ==========================================================================

  # Check if there are any categorical predictors
  has_mixed <- has_categorical_predictors(data$data, config$driver_vars)
  config$has_mixed_predictors <- has_mixed

  if (has_mixed) {
    cat("\n   [MIXED PREDICTORS DETECTED]\n")

    # Apply encoding policy (TRS-mandated)
    encoding_result <- enforce_encoding_policy(
      data = data$data,
      driver_vars = config$driver_vars,
      driver_settings = config$driver_settings,
      allow_polynomial = FALSE
    )

    # Update data with encoded version
    data$data <- encoding_result$data
    config$encoding_report <- encoding_result$encoding_report

    # Print encoding summary
    print_encoding_summary(encoding_result$encoding_report)
  }

  # ==========================================================================
  # STEP 3: CALCULATE CORRELATIONS
  # ==========================================================================

  cat("\n3. Calculating correlations...\n")

  # For mixed predictors: only compute correlations for numeric drivers
  if (has_mixed) {
    numeric_drivers <- get_numeric_drivers(data$data, config$driver_vars)
    if (length(numeric_drivers) < length(config$driver_vars)) {
      cat("   [PARTIAL] Correlations computed for numeric drivers only\n")
      cat(sprintf("   - %d of %d drivers are numeric\n",
                  length(numeric_drivers), length(config$driver_vars)))
      degraded_reasons <- c(degraded_reasons,
                            "Correlations only computed for numeric drivers (categorical excluded)")
      affected_outputs <- c(affected_outputs, "Correlation matrix", "Quadrant chart correlations")

      # Compute correlations only for numeric subset
      if (length(numeric_drivers) >= 2) {
        numeric_config <- config
        numeric_config$driver_vars <- numeric_drivers
        correlations <- calculate_correlations(data$data, numeric_config)
      } else {
        correlations <- NULL
        cat("   [WARN] Not enough numeric drivers for correlation matrix\n")
      }
    } else {
      # All drivers are numeric despite has_mixed being TRUE (edge case)
      correlations <- calculate_correlations(data$data, config)
    }
  } else {
    correlations <- calculate_correlations(data$data, config)
  }

  if (!is.null(correlations)) {
    cat("   [OK] Correlation matrix calculated\n")

    # Check for high collinearity (soft warning, not hard stop)
    cor_matrix <- correlations
    # Only check drivers that are in the correlation matrix
    available_drivers <- intersect(config$driver_vars, rownames(cor_matrix))
    if (length(available_drivers) >= 2) {
      driver_cors <- cor_matrix[available_drivers, available_drivers]
      diag(driver_cors) <- 0  # Ignore self-correlations

      high_cor_threshold <- 0.9
      high_cors <- which(abs(driver_cors) > high_cor_threshold, arr.ind = TRUE)
      if (nrow(high_cors) > 0) {
        for (i in seq_len(nrow(high_cors))) {
          if (high_cors[i, 1] < high_cors[i, 2]) {  # Avoid duplicates
            var1 <- rownames(driver_cors)[high_cors[i, 1]]
            var2 <- colnames(driver_cors)[high_cors[i, 2]]
            cor_val <- driver_cors[high_cors[i, 1], high_cors[i, 2]]
            guard <- guard_record_collinearity(guard, var1, var2, cor_val)
            cat(sprintf("   [WARN] High collinearity: %s <-> %s (r=%.2f)\n", var1, var2, cor_val))
          }
        }
      }
    }
  }

  # ==========================================================================
  # STEP 4: FIT REGRESSION MODEL
  # ==========================================================================

  cat("\n4. Fitting regression model...\n")
  model <- fit_keydriver_model(data$data, config)
  r_squared <- summary(model)$r.squared
  cat(sprintf("   [OK] Model R-squared = %.3f\n", r_squared))

  # ==========================================================================
  # STEP 4.5: BUILD TERM MAPPING (for mixed predictors)
  # ==========================================================================

  term_mapping <- NULL
  if (has_mixed) {
    cat("\n   [BUILDING TERM MAPPING]\n")

    # Build model formula
    formula_str <- paste(config$outcome_var, "~", paste(config$driver_vars, collapse = " + "))
    model_formula <- stats::as.formula(formula_str)

    # Build term-to-driver mapping
    term_mapping <- build_term_mapping(model_formula, data$data, config$driver_vars)

    # Validate mapping (TRS gate - REFUSES on mismatch)
    validate_term_mapping(term_mapping, config$driver_vars)

    # Print mapping summary
    print_term_mapping_summary(term_mapping)
  } else {
    # For continuous-only, use old validation
    guard <- validate_keydriver_mapping(model, config$driver_vars, guard)
  }

  # ==========================================================================
  # STEP 5: CALCULATE IMPORTANCE SCORES
  # ==========================================================================

  cat("\n5. Calculating importance scores...\n")

  if (has_mixed && !is.null(term_mapping)) {
    # Use mixed predictor importance calculation
    cat("   Using driver-level aggregation for mixed predictors\n")
    importance <- calculate_importance_mixed(model, data$data, config, term_mapping)
  } else {
    # Use traditional importance calculation
    importance <- calculate_importance_scores(model, data$data, correlations, config)
  }

  cat("   [OK] Multiple importance methods calculated\n")

  # Initialize results list
  results <- list(
    importance = importance,
    model = model,
    correlations = correlations,
    config = config,
    shap = NULL,
    quadrant = NULL,
    guard = guard,
    run_status = "PASS"
  )

  # ==========================================================================
  # STEP 6: SHAP ANALYSIS (if enabled)
  # ==========================================================================

  if (enable_shap) {
    cat("\n6. Running SHAP analysis...\n")
    shap_results <- tryCatch({
      run_shap_analysis_internal(data$data, config)
    }, error = function(e) {
      # SHAP failure is degradation, not hard stop
      cat(sprintf("   [WARN] SHAP analysis failed: %s\n", e$message))
      guard <<- guard_warn(guard, paste0("SHAP failed: ", e$message), "shap")
      guard$shap_status <<- "failed"
      degraded_reasons <<- c(degraded_reasons, paste0("SHAP analysis failed: ", e$message))
      affected_outputs <<- c(affected_outputs, "SHAP importance", "SHAP plots")
      NULL
    })

    if (!is.null(shap_results)) {
      results$shap <- shap_results
      guard$shap_status <- "complete"
      cat("   [OK] SHAP analysis complete\n")

      # Add SHAP importance to main importance table
      if (!is.null(shap_results$importance)) {
        importance <- add_shap_to_importance(importance, shap_results$importance)
        results$importance <- importance
      }
    }
  }

  # ==========================================================================
  # STEP 7: QUADRANT ANALYSIS (if enabled)
  # ==========================================================================

  if (enable_quadrant) {
    step_num <- if (enable_shap) "7" else "6"
    cat(sprintf("\n%s. Running quadrant analysis...\n", step_num))

    quadrant_results <- tryCatch({
      run_quadrant_analysis_internal(results, data$data, config)
    }, error = function(e) {
      # Quadrant failure is degradation, not hard stop
      cat(sprintf("   [WARN] Quadrant analysis failed: %s\n", e$message))
      guard <<- guard_warn(guard, paste0("Quadrant failed: ", e$message), "quadrant")
      guard$quadrant_status <<- "failed"
      degraded_reasons <<- c(degraded_reasons, paste0("Quadrant analysis failed: ", e$message))
      affected_outputs <<- c(affected_outputs, "Quadrant charts", "IPA analysis")
      NULL
    })

    if (!is.null(quadrant_results)) {
      results$quadrant <- quadrant_results
      guard$quadrant_status <- "complete"
      cat("   [OK] Quadrant analysis complete\n")
    }
  }

  # ==========================================================================
  # STEP 8: GENERATE OUTPUT
  # ==========================================================================

  step_num <- 6 + (if (enable_shap) 1 else 0) + (if (enable_quadrant) 1 else 0)
  cat(sprintf("\n%d. Generating output file...\n", step_num))

  write_keydriver_output_enhanced(
    results = results,
    output_file = output_file
  )
  cat(sprintf("   [OK] Results written to: %s\n", output_file))

  # ==========================================================================
  # DETERMINE FINAL STATUS
  # ==========================================================================

  guard_status <- keydriver_guard_summary(guard)
  results$guard_summary <- guard_status

  # Determine run_status
  if (length(degraded_reasons) > 0) {
    results$run_status <- "PARTIAL"
    results$status <- trs_status_partial(
      module = "KEYDRIVER",
      degraded_reasons = degraded_reasons,
      affected_outputs = affected_outputs
    )
  } else if (guard_status$has_issues) {
    results$run_status <- "PASS"  # Still PASS, but with warnings
  } else {
    results$run_status <- "PASS"
    results$status <- trs_status_pass(module = "KEYDRIVER")
  }

  # ==========================================================================
  # COMPLETION
  # ==========================================================================

  end_time <- Sys.time()
  elapsed <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 1)

  # TRS end banner
  trs_banner_end("KEY DRIVER ANALYSIS", results$run_status, elapsed)

  # Print top drivers
  cat("TOP 5 DRIVERS:\n")
  # Use SHAP if available, otherwise Shapley
  if (!is.null(results$shap)) {
    cat("(by SHAP importance)\n")
    top_drivers <- head(results$shap$importance, 5)
    for (i in seq_len(nrow(top_drivers))) {
      cat(sprintf("  %d. %s (%.1f%%)\n",
                  i,
                  top_drivers$driver[i],
                  top_drivers$importance_pct[i]))
    }
  } else {
    cat("(by Shapley value)\n")
    top_drivers <- head(importance[order(-importance$Shapley_Value), ], 5)
    for (i in seq_len(nrow(top_drivers))) {
      cat(sprintf("  %d. %s (%.1f%%)\n",
                  i,
                  top_drivers$Driver[i],
                  top_drivers$Shapley_Value[i]))
    }
  }

  # Print quadrant summary if available
  if (!is.null(results$quadrant)) {
    cat("\nQUADRANT SUMMARY:\n")
    q_counts <- table(results$quadrant$data$quadrant)
    cat(sprintf("  Q1 (Concentrate Here): %d drivers\n", q_counts["1"] %||% 0))
    cat(sprintf("  Q2 (Keep Up Good Work): %d drivers\n", q_counts["2"] %||% 0))
    cat(sprintf("  Q3 (Low Priority): %d drivers\n", q_counts["3"] %||% 0))
    cat(sprintf("  Q4 (Possible Overkill): %d drivers\n", q_counts["4"] %||% 0))
  }

  # Print warnings summary if any
  if (guard_status$has_issues) {
    cat("\nWARNINGS:\n")
    for (flag in guard_status$stability_flags) {
      cat(sprintf("  - %s\n", flag))
    }
  }

  cat("\n")

  # Return results
  invisible(results)
}


#' Internal: Run SHAP Analysis
#'
#' Wrapper to run SHAP analysis with proper sourcing.
#'
#' @keywords internal
run_shap_analysis_internal <- function(data, config) {

  # Source SHAP module files
  turas_root <- find_turas_root()
  shap_dir <- file.path(turas_root, "modules/keydriver/R/kda_shap")
  methods_dir <- file.path(turas_root, "modules/keydriver/R/kda_methods")

  # Source in order
  source(file.path(shap_dir, "shap_model.R"), local = FALSE)
  source(file.path(shap_dir, "shap_calculate.R"), local = FALSE)
  source(file.path(shap_dir, "shap_visualize.R"), local = FALSE)
  source(file.path(shap_dir, "shap_segment.R"), local = FALSE)
  source(file.path(shap_dir, "shap_interaction.R"), local = FALSE)
  source(file.path(shap_dir, "shap_export.R"), local = FALSE)
  source(file.path(methods_dir, "method_shap.R"), local = FALSE)

  # Build SHAP config from settings
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

  # Get segments if defined
  segments <- config$segments

  # Run SHAP analysis
  run_shap_analysis(
    data = data,
    outcome = config$outcome_var,
    drivers = config$driver_vars,
    weights = config$weight_var,
    config = shap_config,
    segments = segments
  )
}


#' Internal: Run Quadrant Analysis
#'
#' Wrapper to run quadrant analysis with proper sourcing.
#'
#' @keywords internal
run_quadrant_analysis_internal <- function(results, data, config) {

  # Source Quadrant module files
  turas_root <- find_turas_root()
  quad_dir <- file.path(turas_root, "modules/keydriver/R/kda_quadrant")

  source(file.path(quad_dir, "quadrant_main.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_data_prep.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_calculate.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_plot.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_comparison.R"), local = FALSE)
  source(file.path(quad_dir, "quadrant_export.R"), local = FALSE)

  # Build quadrant config from settings
  quad_config <- list(
    importance_source = config$settings$importance_source %||% "auto",
    threshold_method = config$settings$threshold_method %||% "mean",
    normalize_axes = isTRUE(as.logical(config$settings$normalize_axes %||% TRUE)),
    shade_quadrants = isTRUE(as.logical(config$settings$shade_quadrants %||% TRUE)),
    label_all_points = isTRUE(as.logical(config$settings$label_all_points %||% TRUE)),
    label_top_n = as.numeric(config$settings$label_top_n %||% 10),
    show_diagonal = isTRUE(as.logical(config$settings$show_diagonal %||% FALSE))
  )

  # Get segments if defined
  segments <- config$segments

  # Get stated importance if defined
  stated_importance <- config$stated_importance

  # Determine what to pass as kda_results
  kda_input <- if (!is.null(results$shap)) {
    results$shap
  } else {
    results
  }

  # Run quadrant analysis
  create_quadrant_analysis(
    kda_results = kda_input,
    data = data,
    config = quad_config,
    stated_importance = stated_importance,
    segments = segments
  )
}


#' Add SHAP Importance to Main Importance Table
#'
#' @keywords internal
add_shap_to_importance <- function(importance, shap_importance) {

  # Create mapping from SHAP results
  shap_pct <- setNames(shap_importance$importance_pct, shap_importance$driver)
  shap_rank <- setNames(shap_importance$rank, shap_importance$driver)

  # Add columns
  importance$SHAP_Importance <- sapply(importance$Driver, function(d) {
    shap_pct[d] %||% NA_real_
  })

  importance$SHAP_Rank <- sapply(importance$Driver, function(d) {
    shap_rank[d] %||% NA_integer_
  })

  importance
}


#' Find Turas Root Directory
#'
#' Uses shared utility if available, otherwise falls back to local implementation.
#' @keywords internal
find_turas_root <- function() {
  # Check if shared utility is available (from /modules/shared/lib/config_utils.R)
  if (exists("TURAS_ROOT", envir = .GlobalEnv)) {
    cached <- get("TURAS_ROOT", envir = .GlobalEnv)
    if (!is.null(cached) && nzchar(cached)) {
      return(cached)
    }
  }

  # Search up directory tree for Turas root markers
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
      "The directory must contain 'launch_turas.R' or 'turas.R' or 'modules/shared/'"
    )
  )
}


#' Write Enhanced Key Driver Output
#'
#' Extended output writer that includes SHAP and Quadrant results.
#'
#' @keywords internal
write_keydriver_output_enhanced <- function(results, output_file) {

  # Use standard output first
  write_keydriver_output(
    importance = results$importance,
    model = results$model,
    correlations = results$correlations,
    config = results$config,
    output_file = output_file
  )

  # Then add SHAP and Quadrant sheets if available
  if (!is.null(results$shap) || !is.null(results$quadrant)) {

    wb <- openxlsx::loadWorkbook(output_file)

    # Add SHAP sheets
    if (!is.null(results$shap)) {
      turas_root <- find_turas_root()
      source(file.path(turas_root, "modules/keydriver/R/kda_shap/shap_export.R"), local = FALSE)

      wb <- export_shap_to_excel(results$shap, wb)

      # Add SHAP charts
      if (!is.null(results$shap$plots)) {
        wb <- insert_shap_charts_to_excel(wb, results$shap$plots)
      }
    }

    # Add Quadrant sheets
    if (!is.null(results$quadrant)) {
      turas_root <- find_turas_root()
      source(file.path(turas_root, "modules/keydriver/R/kda_quadrant/quadrant_export.R"), local = FALSE)

      wb <- export_quadrant_to_excel(results$quadrant, wb)

      # Add Quadrant charts
      if (!is.null(results$quadrant$plots)) {
        wb <- insert_quadrant_charts_to_excel(wb, results$quadrant$plots)
      }
    }

    openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  }
}


#' Null-coalescing operator
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a


#' @export
keydriver <- run_keydriver_analysis  # Alias for convenience
