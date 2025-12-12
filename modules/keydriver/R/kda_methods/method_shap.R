# ==============================================================================
# TURAS KEY DRIVER - SHAP METHOD ORCHESTRATION
# ==============================================================================
#
# Purpose: Main entry point for SHAP-based key driver analysis
# Version: Turas v10.1
# Date: 2025-12
#
# This file orchestrates the SHAP analysis workflow:
# 1. Data preparation
# 2. Model fitting (XGBoost)
# 3. SHAP value calculation
# 4. Visualization generation
# 5. Segment analysis (optional)
# 6. Interaction analysis (optional)
#
# ==============================================================================

#' Run SHAP Analysis for Key Driver Analysis
#'
#' Fits a gradient boosting model and calculates SHAP values
#' for driver importance analysis.
#'
#' @param data Data frame with outcome and driver variables
#' @param outcome Character. Name of outcome variable
#' @param drivers Character vector. Names of driver variables
#' @param weights Character. Name of weight variable (optional)
#' @param config List. SHAP configuration parameters (see details)
#' @param segments Data frame. Segment definitions (optional)
#'
#' @details
#' Configuration parameters (all optional with sensible defaults):
#' \itemize{
#'   \item \code{shap_model}: Model type - "xgboost" (default) or "lightgbm"
#'   \item \code{n_trees}: Number of trees (default 100, or "auto" for CV)
#'   \item \code{max_depth}: Tree depth (default 6)
#'   \item \code{learning_rate}: Learning rate (default 0.1)
#'   \item \code{subsample}: Row subsampling (default 0.8)
#'   \item \code{colsample_bytree}: Column subsampling (default 0.8)
#'   \item \code{shap_sample_size}: Max rows for SHAP calculation (default 1000)
#'   \item \code{include_interactions}: Calculate SHAP interactions (default FALSE)
#'   \item \code{interaction_top_n}: Top N interactions to display (default 5)
#'   \item \code{importance_top_n}: Top N drivers for plots (default 15)
#'   \item \code{n_waterfall_examples}: Number of waterfall plots (default 5)
#'   \item \code{waterfall_selection}: Selection method - "extreme", "random", "first"
#' }
#'
#' @return shap_results S3 object containing:
#' \itemize{
#'   \item \code{model}: Fitted XGBoost model
#'   \item \code{shap}: shapviz object
#'   \item \code{importance}: Data frame of driver importance
#'   \item \code{plots}: List of ggplot objects
#'   \item \code{segments}: Segment analysis results (if requested)
#'   \item \code{interactions}: Interaction analysis (if requested)
#'   \item \code{diagnostics}: Model fit statistics
#' }
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' results <- run_shap_analysis(
#'   data = survey_data,
#'   outcome = "overall_satisfaction",
#'   drivers = c("Q1_Price", "Q2_Quality", "Q3_Service"),
#'   weights = "weight_var"
#' )
#'
#' # With segments
#' results <- run_shap_analysis(
#'   data = survey_data,
#'   outcome = "overall_satisfaction",
#'   drivers = c("Q1_Price", "Q2_Quality", "Q3_Service"),
#'   segments = data.frame(
#'     segment_name = c("Promoters", "Detractors"),
#'     segment_variable = c("nps_group", "nps_group"),
#'     segment_values = c("Promoter", "Detractor")
#'   )
#' )
#'
#' # Access results
#' print(results$importance)
#' print(results$plots$importance_bar)
#' }
#'
#' @export
run_shap_analysis <- function(
    data,
    outcome,
    drivers,
    weights = NULL,
    config = list(),
    segments = NULL
) {

  cat("\n")
  cat(rep("-", 60), "\n", sep = "")
  cat("SHAP ANALYSIS\n")
  cat(rep("-", 60), "\n", sep = "")

  # Check required packages
  check_shap_packages()

  # Set defaults for config
  config <- set_shap_defaults(config)

  # 1. Validate inputs
  cat("  1. Validating inputs...\n")
  validate_shap_inputs(data, outcome, drivers, weights)

  # 2. Prepare data for XGBoost
  cat("  2. Preparing data for XGBoost...\n")
  prep <- prepare_shap_data(data, outcome, drivers, weights)
  cat(sprintf("     - %d observations, %d features\n", nrow(prep$X), ncol(prep$X)))

  # 3. Fit XGBoost model
  cat("  3. Fitting XGBoost model...\n")
  model <- fit_shap_model(prep, config)
  best_iter <- attr(model, "best_iteration")
  cat(sprintf("     - Best iteration: %d trees\n", best_iter))

  # 4. Calculate SHAP values
  cat("  4. Calculating SHAP values...\n")
  shap <- calculate_shap_values(model, prep, config)
  cat("     - SHAP values calculated\n")

  # 5. Extract importance
  importance <- extract_importance(shap)
  cat(sprintf("     - Top driver: %s (%.1f%%)\n",
              importance$driver[1], importance$importance_pct[1]))

  # 6. Generate visualizations
  cat("  5. Generating visualizations...\n")
  plots <- generate_shap_plots(shap, config)
  cat(sprintf("     - Generated %d plot types\n", length(plots)))

  # 7. Segment analysis (if requested)
  segment_results <- NULL
  if (!is.null(segments) && nrow(segments) > 0) {
    cat("  6. Running segment analysis...\n")
    segment_results <- run_segment_shap(shap, data, segments)
    cat(sprintf("     - Analyzed %d segments\n", length(segment_results) - 1))
  }

  # 8. Interaction analysis (if requested)
  interaction_results <- NULL
  if (isTRUE(config$include_interactions)) {
    cat("  7. Analyzing interactions...\n")
    interaction_results <- analyze_shap_interactions(shap, config)
    if (!is.null(interaction_results)) {
      cat(sprintf("     - Found %d top interactions\n", nrow(interaction_results$top_pairs)))
    }
  }

  # 9. Calculate diagnostics
  diagnostics <- model_diagnostics(model, prep)

  # Compile results
  results <- structure(
    list(
      model = model,
      shap = shap,
      importance = importance,
      plots = plots,
      segments = segment_results,
      interactions = interaction_results,
      diagnostics = diagnostics,
      config = config
    ),
    class = "shap_results"
  )

  cat("\n")
  cat("  SHAP analysis complete.\n")
  cat(sprintf("  - Model R²: %.3f\n", diagnostics$r_squared))
  cat(sprintf("  - RMSE: %.3f\n", diagnostics$rmse))
  cat("\n")

  results
}


#' Check Required Packages for SHAP
#'
#' @keywords internal
check_shap_packages <- function() {

  required <- c("xgboost", "shapviz", "ggplot2")
  missing <- required[!sapply(required, requireNamespace, quietly = TRUE)]

  if (length(missing) > 0) {
    stop(sprintf(
      "Missing required packages for SHAP analysis: %s\nInstall with: install.packages(c('%s'))",
      paste(missing, collapse = ", "),
      paste(missing, collapse = "', '")
    ), call. = FALSE)
  }

  # Check optional packages
  optional <- c("patchwork", "viridis")
  missing_optional <- optional[!sapply(optional, requireNamespace, quietly = TRUE)]

  if (length(missing_optional) > 0) {
    message(sprintf(
      "Optional packages not available: %s. Some visualizations may be limited.",
      paste(missing_optional, collapse = ", ")
    ))
  }

  invisible(TRUE)
}


#' Set Default Configuration for SHAP
#'
#' @param config User-provided config list
#' @return Config list with defaults filled in
#' @keywords internal
set_shap_defaults <- function(config) {

  defaults <- list(
    shap_model = "xgboost",
    n_trees = 100,
    max_depth = 6,
    learning_rate = 0.1,
    subsample = 0.8,
    colsample_bytree = 0.8,
    shap_sample_size = 1000,
    include_interactions = FALSE,
    interaction_top_n = 5,
    importance_top_n = 15,
    dependence_top_n = 6,
    n_waterfall_examples = 5,
    n_force_examples = 5,
    waterfall_selection = "extreme",
    show_numbers = TRUE
  )

  # Merge user config with defaults
  for (name in names(defaults)) {
    if (is.null(config[[name]])) {
      config[[name]] <- defaults[[name]]
    }
  }

  config
}


#' Validate SHAP Inputs
#'
#' @keywords internal
validate_shap_inputs <- function(data, outcome, drivers, weights) {

  # Check outcome exists
  if (!outcome %in% names(data)) {
    stop(sprintf(
      "Outcome variable '%s' not found in data.\nAvailable columns: %s",
      outcome, paste(head(names(data), 10), collapse = ", ")
    ), call. = FALSE)
  }

  # Check drivers exist
  missing_drivers <- setdiff(drivers, names(data))
  if (length(missing_drivers) > 0) {
    stop(sprintf(
      "Driver variables not found in data: %s",
      paste(missing_drivers, collapse = ", ")
    ), call. = FALSE)
  }

  # Check minimum sample size
  if (nrow(data) < 100) {
    warning(sprintf(
      "Small sample size for SHAP analysis: %d observations. Recommended: >= 200.",
      nrow(data)
    ))
  }

  # Check outcome variance
  if (is.numeric(data[[outcome]])) {
    outcome_sd <- sd(data[[outcome]], na.rm = TRUE)
    if (is.na(outcome_sd) || outcome_sd < 0.01) {
      stop("Outcome variable has near-zero variance. Cannot fit meaningful model.",
           call. = FALSE)
    }
  }

  # Check for highly correlated drivers
  if (all(sapply(data[drivers], is.numeric))) {
    driver_data <- data[drivers]
    driver_data <- driver_data[complete.cases(driver_data), ]

    if (nrow(driver_data) > 10) {
      cor_mat <- cor(driver_data, use = "pairwise.complete.obs")
      high_cor <- which(abs(cor_mat) > 0.9 & cor_mat < 1, arr.ind = TRUE)

      if (nrow(high_cor) > 0) {
        pairs <- unique(apply(high_cor, 1, function(x) {
          paste(sort(c(drivers[x[1]], drivers[x[2]])), collapse = " - ")
        }))
        warning(sprintf(
          "Highly correlated drivers detected (r > 0.9): %s\nSHAP will still work but importance may be split between correlated drivers.",
          paste(pairs, collapse = "; ")
        ))
      }
    }
  }

  invisible(TRUE)
}


#' Print Method for shap_results
#'
#' @param x shap_results object
#' @param ... Additional arguments (ignored)
#' @export
print.shap_results <- function(x, ...) {

  cat("\nSHAP Analysis Results\n")
  cat(rep("=", 50), "\n", sep = "")

  # Diagnostics
  cat("\nModel Performance:\n")
  cat(sprintf("  R-squared: %.3f\n", x$diagnostics$r_squared))
  cat(sprintf("  RMSE: %.3f\n", x$diagnostics$rmse))
  cat(sprintf("  Sample size: %d\n", x$diagnostics$sample_size))
  cat(sprintf("  Trees: %d\n", x$diagnostics$n_trees))

  # Top drivers
  cat("\nTop 5 Drivers (SHAP Importance):\n")
  top5 <- head(x$importance, 5)
  for (i in seq_len(nrow(top5))) {
    cat(sprintf("  %d. %s (%.1f%%)\n", i, top5$driver[i], top5$importance_pct[i]))
  }

  # Segments
  if (!is.null(x$segments)) {
    n_segments <- length(x$segments) - 1  # Exclude 'comparison'
    if (n_segments > 0) {
      cat(sprintf("\nSegment Analysis: %d segments analyzed\n", n_segments))
    }
  }

  # Interactions
  if (!is.null(x$interactions)) {
    cat("\nTop Interactions:\n")
    top_int <- head(x$interactions$top_pairs, 3)
    for (i in seq_len(nrow(top_int))) {
      cat(sprintf("  %s <-> %s\n", top_int$feature_1[i], top_int$feature_2[i]))
    }
  }

  cat("\n")
  invisible(x)
}
