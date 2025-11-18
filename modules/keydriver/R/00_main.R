# ==============================================================================
# TURAS KEY DRIVER ANALYSIS MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Key Driver Analysis (Relative Importance)
# Purpose: Determine which independent variables (drivers) have the greatest
#          impact on a dependent variable (outcome)
# Version: 1.0.0 (Initial Implementation)
# Date: 2025-11-18
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
#'
#' @param config_file Path to key driver configuration Excel file
#'   Required sheets: Settings, Variables
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA)
#' @param output_file Path for results Excel file (default: keydriver_results.xlsx)
#'
#' @return List containing:
#'   - importance: Data frame with importance scores from each method
#'   - model: Regression model object
#'   - correlations: Correlation matrix
#'   - config: Processed configuration
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' results <- run_keydriver_analysis(
#'   config_file = "keydriver_config.xlsx",
#'   data_file = "survey_data.csv"
#' )
#'
#' # View importance rankings
#' print(results$importance)
#'
#' # View by method
#' print(results$importance[order(-results$importance$Shapley), ])
#' }
#'
#' @export
run_keydriver_analysis <- function(config_file, data_file, output_file = "keydriver_results.xlsx") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS KEY DRIVER ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # STEP 1: Load Configuration
  cat("1. Loading configuration...\n")
  config <- load_keydriver_config(config_file)
  cat(sprintf("   ✓ Outcome variable: %s\n", config$outcome_var))
  cat(sprintf("   ✓ Driver variables: %d variables\n", length(config$driver_vars)))

  # STEP 2: Load and Validate Data
  cat("\n2. Loading and validating data...\n")
  data <- load_keydriver_data(data_file, config)
  cat(sprintf("   ✓ Loaded %d respondents\n", data$n_respondents))
  cat(sprintf("   ✓ Complete cases: %d\n", data$n_complete))

  # STEP 3: Calculate Correlations
  cat("\n3. Calculating correlations...\n")
  correlations <- calculate_correlations(data$data, config)
  cat("   ✓ Correlation matrix calculated\n")

  # STEP 4: Fit Regression Model
  cat("\n4. Fitting regression model...\n")
  model <- fit_keydriver_model(data$data, config)
  cat(sprintf("   ✓ Model R² = %.3f\n", summary(model)$r.squared))

  # STEP 5: Calculate Importance Scores
  cat("\n5. Calculating importance scores...\n")
  importance <- calculate_importance_scores(model, data$data, correlations, config)
  cat("   ✓ Multiple importance methods calculated\n")

  # STEP 6: Generate Output
  cat("\n6. Generating output file...\n")
  write_keydriver_output(
    importance = importance,
    model = model,
    correlations = correlations,
    config = config,
    output_file = output_file
  )
  cat(sprintf("   ✓ Results written to: %s\n", output_file))

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ANALYSIS COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Print top drivers
  cat("TOP 5 DRIVERS (by Shapley value):\n")
  top_drivers <- head(importance[order(-importance$Shapley_Value), ], 5)
  for (i in seq_len(nrow(top_drivers))) {
    cat(sprintf("  %d. %s (%.1f%%)\n",
                i,
                top_drivers$Driver[i],
                top_drivers$Shapley_Value[i]))
  }
  cat("\n")

  # Return results
  invisible(list(
    importance = importance,
    model = model,
    correlations = correlations,
    config = config
  ))
}


#' @export
keydriver <- run_keydriver_analysis  # Alias for convenience
