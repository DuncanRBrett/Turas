# ==============================================================================
# TURAS PRICING RESEARCH MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Pricing Research
# Purpose: Analyze pricing sensitivity using Van Westendorp PSM and
#          Gabor-Granger methodologies
# Version: 1.0.0 (Initial Implementation)
# Date: 2025-11-18
#
# ==============================================================================

#' Run Pricing Research Analysis
#'
#' Main entry point for pricing research analysis. Implements Van Westendorp
#' Price Sensitivity Meter (PSM) and Gabor-Granger methodologies for optimal
#' price determination.
#'
#' METHODOLOGY:
#' - Van Westendorp PSM: Analyzes four price perception questions to find
#'   acceptable price range and optimal price point through cumulative
#'   distribution intersections
#' - Gabor-Granger: Analyzes sequential purchase intent at price points to
#'   construct demand curve and find revenue-maximizing price
#'
#' @param config_file Path to pricing configuration Excel file
#'   Required sheets: Settings, plus method-specific sheets
#'   Settings sheet should include: data_file, output_file, analysis_method
#' @param data_file Path to respondent data (CSV, XLSX, SAV, DTA).
#'   If NULL, reads from config Settings sheet.
#' @param output_file Path for results Excel file.
#'   If NULL, reads from config Settings sheet.
#'
#' @return List containing:
#'   - method: Analysis method used ("van_westendorp", "gabor_granger", or "both")
#'   - results: Method-specific results (price points, demand curves, etc.)
#'   - plots: List of generated plot objects
#'   - diagnostics: Data quality and validation results
#'   - config: Processed configuration
#'
#' @examples
#' \dontrun{
#' # Run Van Westendorp analysis
#' results <- run_pricing_analysis(
#'   config_file = "pricing_config.xlsx"
#' )
#'
#' # View price points
#' print(results$results$price_points)
#'
#' # View acceptable price range
#' print(results$results$acceptable_range)
#'
#' # Run Gabor-Granger with custom paths
#' results <- run_pricing_analysis(
#'   config_file = "gg_config.xlsx",
#'   data_file = "survey_data.csv",
#'   output_file = "pricing_results.xlsx"
#' )
#'
#' # Access demand curve
#' print(results$results$demand_curve)
#'
#' # Access optimal price
#' print(results$results$optimal_price)
#' }
#'
#' @export
run_pricing_analysis <- function(config_file, data_file = NULL, output_file = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS PRICING RESEARCH ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # --------------------------------------------------------------------------
  # STEP 1: Load Configuration
  # --------------------------------------------------------------------------
  cat("1. Loading configuration...\n")
  config <- load_pricing_config(config_file)
  cat(sprintf("   Analysis method: %s\n", config$analysis_method))
  if (!is.null(config$project_name) && !is.na(config$project_name)) {
    cat(sprintf("   Project: %s\n", config$project_name))
  }

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
      # Default to project_root/pricing_results.xlsx
      output_file <- file.path(config$project_root, "pricing_results.xlsx")
    }
  }

  # --------------------------------------------------------------------------
  # STEP 2: Load and Validate Data
  # --------------------------------------------------------------------------
  cat("\n2. Loading and validating data...\n")
  data_result <- load_pricing_data(data_file, config)
  cat(sprintf("   Loaded %d respondents\n", nrow(data_result$data)))

  # Run validation
  validation <- validate_pricing_data(data_result$data, config)
  if (validation$n_warnings > 0) {
    cat(sprintf("   ! %d validation warnings (see diagnostics)\n", validation$n_warnings))
  }
  if (validation$n_excluded > 0) {
    cat(sprintf("   Excluded %d invalid cases\n", validation$n_excluded))
  }
  cat(sprintf("   Valid cases for analysis: %d\n", validation$n_valid))

  # --------------------------------------------------------------------------
  # STEP 3: Run Analysis
  # --------------------------------------------------------------------------
  analysis_method <- tolower(config$analysis_method)

  if (analysis_method == "van_westendorp") {
    cat("\n3. Running Van Westendorp PSM analysis...\n")
    analysis_results <- run_van_westendorp(validation$clean_data, config)
    cat("   Price points calculated:\n")
    cat(sprintf("     PMC (Point of Marginal Cheapness): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$PMC))
    cat(sprintf("     OPP (Optimal Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$OPP))
    cat(sprintf("     IDP (Indifference Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$IDP))
    cat(sprintf("     PME (Point of Marginal Expensiveness): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$PME))

  } else if (analysis_method == "gabor_granger") {
    cat("\n3. Running Gabor-Granger analysis...\n")
    analysis_results <- run_gabor_granger(validation$clean_data, config)
    cat(sprintf("   Demand curve calculated for %d price points\n",
                nrow(analysis_results$demand_curve)))
    if (!is.null(analysis_results$optimal_price)) {
      cat(sprintf("   Optimal price: %s%.2f (%.1f%% purchase intent)\n",
                  config$currency_symbol %||% "$",
                  analysis_results$optimal_price$price,
                  analysis_results$optimal_price$purchase_intent * 100))
    }

  } else if (analysis_method == "both") {
    cat("\n3. Running both Van Westendorp and Gabor-Granger analyses...\n")

    cat("   a) Van Westendorp PSM...\n")
    vw_results <- run_van_westendorp(validation$clean_data, config)
    cat(sprintf("      Acceptable range: %s%.2f - %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PMC,
                config$currency_symbol %||% "$", vw_results$price_points$PME))

    cat("   b) Gabor-Granger...\n")
    gg_results <- run_gabor_granger(validation$clean_data, config)
    if (!is.null(gg_results$optimal_price)) {
      cat(sprintf("      Optimal price: %s%.2f\n",
                  config$currency_symbol %||% "$", gg_results$optimal_price$price))
    }

    analysis_results <- list(
      van_westendorp = vw_results,
      gabor_granger = gg_results
    )

  } else {
    stop(sprintf("Unknown analysis method: '%s'. Use 'van_westendorp', 'gabor_granger', or 'both'",
                 config$analysis_method), call. = FALSE)
  }

  # --------------------------------------------------------------------------
  # STEP 4: Generate Visualizations
  # --------------------------------------------------------------------------
  cat("\n4. Generating visualizations...\n")
  plots <- generate_pricing_plots(analysis_results, config)
  cat(sprintf("   Generated %d plot(s)\n", length(plots)))

  # --------------------------------------------------------------------------
  # STEP 5: Generate Output
  # --------------------------------------------------------------------------
  cat("\n5. Generating output file...\n")
  write_pricing_output(
    results = analysis_results,
    plots = plots,
    validation = validation,
    config = config,
    output_file = output_file
  )
  cat(sprintf("   Results written to: %s\n", output_file))

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ANALYSIS COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Return results
  invisible(list(
    method = analysis_method,
    results = analysis_results,
    plots = plots,
    diagnostics = validation,
    config = config
  ))
}


#' Run Pricing Analysis from Pre-loaded Config
#'
#' Wrapper function for GUI that accepts a pre-loaded config object
#' instead of a config file path.
#'
#' @param config Pre-loaded configuration list (from load_pricing_config)
#'
#' @return List containing analysis results, plots, diagnostics, and config
#'
#' @export
run_pricing_analysis_from_config <- function(config) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS PRICING RESEARCH ANALYSIS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # --------------------------------------------------------------------------
  # STEP 1: Configuration (already loaded)
  # --------------------------------------------------------------------------
  cat("1. Configuration loaded\n")
  cat(sprintf("   Analysis method: %s\n", config$analysis_method))
  if (!is.null(config$project_name) && !is.na(config$project_name)) {
    cat(sprintf("   Project: %s\n", config$project_name))
  }

  # Get data_file from config
  data_file <- config$data_file
  if (is.null(data_file) || is.na(data_file)) {
    stop("data_file not specified in config", call. = FALSE)
  }

  # Get output_file from config
  output_file <- config$output_file
  if (is.null(output_file) || is.na(output_file)) {
    # Construct from output directory and filename prefix
    if (!is.null(config$output$directory) && !is.null(config$output$filename_prefix)) {
      output_file <- file.path(config$output$directory,
                              paste0(config$output$filename_prefix, ".xlsx"))
    } else {
      # Default to project_root/pricing_results.xlsx
      output_file <- file.path(config$project_root, "pricing_results.xlsx")
    }
  }

  # --------------------------------------------------------------------------
  # STEP 2: Load and Validate Data
  # --------------------------------------------------------------------------
  cat("\n2. Loading and validating data...\n")
  data_result <- load_pricing_data(data_file, config)
  cat(sprintf("   Loaded %d respondents\n", nrow(data_result$data)))

  # Run validation
  validation <- validate_pricing_data(data_result$data, config)
  if (validation$n_warnings > 0) {
    cat(sprintf("   ! %d validation warnings (see diagnostics)\n", validation$n_warnings))
  }
  if (validation$n_excluded > 0) {
    cat(sprintf("   Excluded %d invalid cases\n", validation$n_excluded))
  }
  cat(sprintf("   Valid cases for analysis: %d\n", validation$n_valid))

  # --------------------------------------------------------------------------
  # STEP 3: Run Analysis
  # --------------------------------------------------------------------------
  analysis_method <- tolower(config$analysis_method)

  if (analysis_method == "van_westendorp") {
    cat("\n3. Running Van Westendorp PSM analysis...\n")
    analysis_results <- run_van_westendorp(validation$clean_data, config)
    cat("   Price points calculated:\n")
    cat(sprintf("     PMC (Point of Marginal Cheapness): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$PMC))
    cat(sprintf("     OPP (Optimal Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$OPP))
    cat(sprintf("     IDP (Indifference Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$IDP))
    cat(sprintf("     PME (Point of Marginal Expensiveness): %s%.2f\n",
                config$currency_symbol %||% "$", analysis_results$price_points$PME))

  } else if (analysis_method == "gabor_granger") {
    cat("\n3. Running Gabor-Granger analysis...\n")
    analysis_results <- run_gabor_granger(validation$clean_data, config)
    cat(sprintf("   Demand curve calculated for %d price points\n",
                nrow(analysis_results$demand_curve)))
    if (!is.null(analysis_results$optimal_price)) {
      cat(sprintf("   Optimal price (revenue-max): %s%.2f (%.1f%% purchase intent)\n",
                  config$currency_symbol %||% "$",
                  analysis_results$optimal_price$price,
                  analysis_results$optimal_price$purchase_intent * 100))
    }
    if (!is.null(analysis_results$optimal_price_profit)) {
      cat(sprintf("   Optimal price (profit-max): %s%.2f (profit index: %.2f)\n",
                  config$currency_symbol %||% "$",
                  analysis_results$optimal_price_profit$price,
                  analysis_results$optimal_price_profit$profit_index))
    }

  } else if (analysis_method == "both") {
    cat("\n3. Running both Van Westendorp and Gabor-Granger analyses...\n")

    cat("   a) Van Westendorp PSM...\n")
    vw_results <- run_van_westendorp(validation$clean_data, config)
    cat(sprintf("      Acceptable range: %s%.2f - %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PMC,
                config$currency_symbol %||% "$", vw_results$price_points$PME))

    cat("   b) Gabor-Granger...\n")
    gg_results <- run_gabor_granger(validation$clean_data, config)
    if (!is.null(gg_results$optimal_price)) {
      cat(sprintf("      Optimal price (revenue-max): %s%.2f\n",
                  config$currency_symbol %||% "$", gg_results$optimal_price$price))
    }
    if (!is.null(gg_results$optimal_price_profit)) {
      cat(sprintf("      Optimal price (profit-max): %s%.2f\n",
                  config$currency_symbol %||% "$", gg_results$optimal_price_profit$price))
    }

    analysis_results <- list(
      van_westendorp = vw_results,
      gabor_granger = gg_results
    )

  } else {
    stop(sprintf("Unknown analysis method: '%s'. Use 'van_westendorp', 'gabor_granger', or 'both'",
                 config$analysis_method), call. = FALSE)
  }

  # --------------------------------------------------------------------------
  # STEP 4: Generate Visualizations
  # --------------------------------------------------------------------------
  cat("\n4. Generating visualizations...\n")
  plots <- generate_pricing_plots(analysis_results, config)
  cat(sprintf("   Generated %d plot(s)\n", length(plots)))

  # --------------------------------------------------------------------------
  # STEP 5: Generate Output
  # --------------------------------------------------------------------------
  cat("\n5. Generating output file...\n")
  write_pricing_output(
    results = analysis_results,
    plots = plots,
    validation = validation,
    config = config,
    output_file = output_file
  )
  cat(sprintf("   Results written to: %s\n", output_file))

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("ANALYSIS COMPLETE\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Return results
  invisible(list(
    method = analysis_method,
    results = analysis_results,
    plots = plots,
    diagnostics = validation,
    config = config
  ))
}


#' @export
pricing <- run_pricing_analysis  # Alias for convenience


# Helper operator for default values
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}
