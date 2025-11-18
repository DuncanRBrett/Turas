# ==============================================================================
# TURAS CONJOINT ANALYSIS MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Conjoint Analysis
# Purpose: Calculate part-worth utilities and attribute importance from
#          choice-based or rating-based conjoint data
# Version: 1.0.0 (Initial Implementation)
# Date: 2025-11-18
#
# ==============================================================================

#' Run Conjoint Analysis
#'
#' Main entry point for conjoint analysis. Calculates part-worth utilities
#' and attribute importance scores from conjoint experimental data.
#'
#' METHODOLOGY:
#' - Uses regression-based approach (OLS or logistic depending on data type)
#' - Calculates part-worth utilities for each level of each attribute
#' - Derives attribute importance from range of utilities
#' - Supports both choice-based and rating-based designs
#'
#' @param config_file Path to conjoint configuration Excel file
#'   Required sheets: Settings, Attributes, Design, Data
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA)
#' @param output_file Path for results Excel file (default: conjoint_results.xlsx)
#'
#' @return List containing:
#'   - utilities: Data frame of part-worth utilities by attribute level
#'   - importance: Data frame of attribute importance scores
#'   - fit: Model fit statistics
#'   - config: Processed configuration
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' results <- run_conjoint_analysis(
#'   config_file = "conjoint_config.xlsx",
#'   data_file = "survey_data.csv"
#' )
#'
#' # View attribute importance
#' print(results$importance)
#'
#' # View part-worth utilities
#' print(results$utilities)
#' }
#'
#' @export
run_conjoint_analysis <- function(config_file, data_file, output_file = "conjoint_results.xlsx") {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS CONJOINT ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # STEP 1: Load Configuration
  cat("1. Loading configuration...\n")
  config <- load_conjoint_config(config_file)
  cat(sprintf("   ✓ Loaded %d attributes with %d total levels\n",
              nrow(config$attributes),
              sum(config$attributes$NumLevels)))

  # STEP 2: Load and Validate Data
  cat("\n2. Loading and validating data...\n")
  data <- load_conjoint_data(data_file, config)
  cat(sprintf("   ✓ Loaded %d respondents with %d profiles each\n",
              data$n_respondents,
              data$n_profiles))

  # STEP 3: Run Analysis
  cat("\n3. Calculating part-worth utilities...\n")
  analysis_results <- calculate_conjoint_utilities(data, config)
  cat(sprintf("   ✓ Estimated %d part-worth utilities\n",
              nrow(analysis_results$utilities)))

  # STEP 4: Calculate Importance
  cat("\n4. Calculating attribute importance...\n")
  importance <- calculate_attribute_importance(analysis_results$utilities, config)
  cat("   ✓ Importance scores calculated\n")

  # STEP 5: Generate Output
  cat("\n5. Generating output file...\n")
  write_conjoint_output(
    utilities = analysis_results$utilities,
    importance = importance,
    fit = analysis_results$fit,
    config = config,
    output_file = output_file
  )
  cat(sprintf("   ✓ Results written to: %s\n", output_file))

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ANALYSIS COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Return results
  invisible(list(
    utilities = analysis_results$utilities,
    importance = importance,
    fit = analysis_results$fit,
    config = config
  ))
}


#' @export
conjoint <- run_conjoint_analysis  # Alias for convenience
