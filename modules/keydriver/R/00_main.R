# ==============================================================================
# TURAS KEY DRIVER ANALYSIS MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Key Driver Analysis (Relative Importance)
# Purpose: Determine which independent variables (drivers) have the greatest
#          impact on a dependent variable (outcome)
# Version: Turas v10.1
# Date: 2025-12
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

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS KEY DRIVER ANALYSIS v10.1\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # STEP 1: Load Configuration
  cat("1. Loading configuration...\n")
  config <- load_keydriver_config(config_file)
  cat(sprintf("   ✓ Outcome variable: %s\n", config$outcome_var))
  cat(sprintf("   ✓ Driver variables: %d variables\n", length(config$driver_vars)))

  # Check for optional features
  enable_shap <- isTRUE(config$settings$enable_shap) ||
                 isTRUE(as.logical(config$settings$enable_shap))
  enable_quadrant <- isTRUE(config$settings$enable_quadrant) ||
                     isTRUE(as.logical(config$settings$enable_quadrant))

  if (enable_shap) cat("   ✓ SHAP analysis enabled\n")
  if (enable_quadrant) cat("   ✓ Quadrant analysis enabled\n")

  # Get data_file from config if not provided
  if (is.null(data_file)) {
    data_file <- config$data_file
    if (is.null(data_file) || is.na(data_file)) {
      stop("data_file not specified in function call or config Settings sheet", call. = FALSE)
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

  # STEP 2: Load and Validate Data
  cat("\n2. Loading and validating data...\n")
  data <- load_keydriver_data(data_file, config)
  cat(sprintf("   ✓ Loaded %d respondents\n", data$n_respondents))
  cat(sprintf("   ✓ Complete cases: %d\n", data$n_complete))

  # Store raw data in config for later use
  config$raw_data <- data$data

  # STEP 3: Calculate Correlations
  cat("\n3. Calculating correlations...\n")
  correlations <- calculate_correlations(data$data, config)
  cat("   ✓ Correlation matrix calculated\n")

  # STEP 4: Fit Regression Model
  cat("\n4. Fitting regression model...\n")
  model <- fit_keydriver_model(data$data, config)
  cat(sprintf("   ✓ Model R² = %.3f\n", summary(model)$r.squared))

  # STEP 5: Calculate Importance Scores (Traditional Methods)
  cat("\n5. Calculating importance scores...\n")
  importance <- calculate_importance_scores(model, data$data, correlations, config)
  cat("   ✓ Multiple importance methods calculated\n")

  # Initialize results list
  results <- list(
    importance = importance,
    model = model,
    correlations = correlations,
    config = config,
    shap = NULL,
    quadrant = NULL
  )

  # STEP 6: SHAP Analysis (if enabled)
  shap_results <- NULL
  if (enable_shap) {
    cat("\n6. Running SHAP analysis...\n")
    shap_results <- tryCatch({
      run_shap_analysis_internal(data$data, config)
    }, error = function(e) {
      warning(sprintf("SHAP analysis failed: %s", e$message))
      NULL
    })

    if (!is.null(shap_results)) {
      results$shap <- shap_results
      cat("   ✓ SHAP analysis complete\n")

      # Add SHAP importance to main importance table
      if (!is.null(shap_results$importance)) {
        importance <- add_shap_to_importance(importance, shap_results$importance)
        results$importance <- importance
      }
    }
  }

  # STEP 7: Quadrant Analysis (if enabled)
  quadrant_results <- NULL
  if (enable_quadrant) {
    step_num <- if (enable_shap) "7" else "6"
    cat(sprintf("\n%s. Running quadrant analysis...\n", step_num))

    quadrant_results <- tryCatch({
      run_quadrant_analysis_internal(results, data$data, config)
    }, error = function(e) {
      warning(sprintf("Quadrant analysis failed: %s", e$message))
      NULL
    })

    if (!is.null(quadrant_results)) {
      results$quadrant <- quadrant_results
      cat("   ✓ Quadrant analysis complete\n")
    }
  }

  # STEP 8: Generate Output
  step_num <- 6 + (if (enable_shap) 1 else 0) + (if (enable_quadrant) 1 else 0)
  cat(sprintf("\n%d. Generating output file...\n", step_num))

  write_keydriver_output_enhanced(
    results = results,
    output_file = output_file
  )
  cat(sprintf("   ✓ Results written to: %s\n", output_file))

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ANALYSIS COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

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
#' @keywords internal
find_turas_root <- function() {
  turas_root <- getwd()

  if (basename(turas_root) != "Turas") {
    # Try parent
    if (file.exists(file.path(dirname(turas_root), "launch_turas.R"))) {
      turas_root <- dirname(turas_root)
    }
    # Try going up one more level
    if (basename(turas_root) != "Turas" &&
        file.exists(file.path(dirname(dirname(turas_root)), "launch_turas.R"))) {
      turas_root <- dirname(dirname(turas_root))
    }
  }

  turas_root
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
