# ==============================================================================
# TURAS PRICING RESEARCH MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Pricing Research
# Purpose: Analyze pricing sensitivity using Van Westendorp PSM and
#          Gabor-Granger methodologies with segment analysis, price ladder,
#          and recommendation synthesis
# Version: Turas v11.0
# Date: 2025-12-11
#
# ==============================================================================

#' Run Pricing Research Analysis
#'
#' Main entry point for pricing research analysis. Implements Van Westendorp
#' Price Sensitivity Meter (PSM) and Gabor-Granger methodologies for optimal
#' price determination. Includes segment analysis, price ladder generation,
#' and recommendation synthesis.
#'
#' METHODOLOGY:
#' - Van Westendorp PSM: Analyzes four price perception questions to find
#'   acceptable price range and optimal price point through cumulative
#'   distribution intersections. Now uses pricesensitivitymeter package
#'   with optional NMS (Newton-Miller-Smith) extension.
#' - Gabor-Granger: Analyzes sequential purchase intent at price points to
#'   construct demand curve and find revenue-maximizing price
#' - Segment Analysis: Runs pricing analysis across customer segments
#' - Price Ladder: Generates Good/Better/Best tier structure
#' - Recommendation Synthesis: Creates executive summary with confidence assessment
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
#'   - segment_results: Segmented analysis results (if configured)
#'   - ladder_results: Price ladder results (if VW available)
#'   - synthesis: Recommendation synthesis with executive summary
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
#' # View recommendation synthesis
#' cat(results$synthesis$executive_summary)
#'
#' # View price ladder
#' print(results$ladder_results$tier_table)
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
#' }
#'
#' @export
run_pricing_analysis <- function(config_file, data_file = NULL, output_file = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("TURAS PRICING RESEARCH ANALYSIS v11.0\n")
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
  # STEP 3: Run Core Analysis
  # --------------------------------------------------------------------------
  analysis_method <- tolower(config$analysis_method)
  vw_results <- NULL
  gg_results <- NULL

  if (analysis_method == "van_westendorp") {
    cat("\n3. Running Van Westendorp PSM analysis...\n")
    vw_results <- run_van_westendorp(validation$clean_data, config)
    analysis_results <- vw_results
    cat("   Price points calculated:\n")
    cat(sprintf("     PMC (Point of Marginal Cheapness): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PMC))
    cat(sprintf("     OPP (Optimal Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$OPP))
    cat(sprintf("     IDP (Indifference Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$IDP))
    cat(sprintf("     PME (Point of Marginal Expensiveness): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PME))
    if (!is.null(vw_results$nms_results)) {
      cat(sprintf("     NMS Revenue Optimal: %s%.2f\n",
                  config$currency_symbol %||% "$", vw_results$nms_results$revenue_optimal))
    }

  } else if (analysis_method == "gabor_granger") {
    cat("\n3. Running Gabor-Granger analysis...\n")
    gg_results <- run_gabor_granger(validation$clean_data, config)
    analysis_results <- gg_results
    cat(sprintf("   Demand curve calculated for %d price points\n",
                nrow(gg_results$demand_curve)))
    if (!is.null(gg_results$optimal_price)) {
      cat(sprintf("   Optimal price: %s%.2f (%.1f%% purchase intent)\n",
                  config$currency_symbol %||% "$",
                  gg_results$optimal_price$price,
                  gg_results$optimal_price$purchase_intent * 100))
    }

  } else if (analysis_method == "both") {
    cat("\n3. Running both Van Westendorp and Gabor-Granger analyses...\n")

    cat("   a) Van Westendorp PSM...\n")
    vw_results <- run_van_westendorp(validation$clean_data, config)
    cat(sprintf("      Acceptable range: %s%.2f - %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PMC,
                config$currency_symbol %||% "$", vw_results$price_points$PME))
    if (!is.null(vw_results$nms_results)) {
      cat(sprintf("      NMS Revenue Optimal: %s%.2f\n",
                  config$currency_symbol %||% "$", vw_results$nms_results$revenue_optimal))
    }

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
  # STEP 4: Run Segmented Analysis (if configured)
  # --------------------------------------------------------------------------
  segment_results <- NULL

  if (!is.null(config$segmentation$segment_column) &&
      !is.na(config$segmentation$segment_column) &&
      config$segmentation$segment_column != "") {

    cat("\n4. Running segment analysis...\n")
    cat(sprintf("   Segment column: %s\n", config$segmentation$segment_column))

    tryCatch({
      segment_results <- run_segmented_analysis(
        data = validation$clean_data,
        config = config,
        method = if (analysis_method == "both") "van_westendorp" else analysis_method
      )
      cat(sprintf("   Analyzed %d segments\n", length(segment_results$segment_results)))
      if (length(segment_results$insights) > 0) {
        cat("   Key insights:\n")
        for (insight in segment_results$insights[1:min(3, length(segment_results$insights))]) {
          cat(sprintf("     - %s\n", insight))
        }
      }
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] PRICE_SEGMENT_FAILED: Segment analysis failed: %s", e$message))
      cat(sprintf("   ! Segment analysis failed: %s\n", e$message))
    })
  }

  # --------------------------------------------------------------------------
  # STEP 5: Build Price Ladder (if VW results available)
  # --------------------------------------------------------------------------
  ladder_results <- NULL

  if (!is.null(vw_results)) {
    cat("\n5. Building price ladder...\n")

    tryCatch({
      ladder_results <- build_price_ladder(
        vw_results = vw_results,
        gg_results = gg_results,
        config = config
      )
      cat("   Tier structure generated:\n")
      for (i in 1:nrow(ladder_results$tier_table)) {
        cat(sprintf("     %-10s %s%.2f\n",
                    ladder_results$tier_table$tier[i],
                    config$currency_symbol %||% "$",
                    ladder_results$tier_table$price[i]))
      }
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] PRICE_LADDER_FAILED: Price ladder generation failed: %s", e$message))
      cat(sprintf("   ! Price ladder generation failed: %s\n", e$message))
    })
  }

  # --------------------------------------------------------------------------
  # STEP 6: Synthesize Recommendation
  # --------------------------------------------------------------------------
  synthesis <- NULL

  cat("\n6. Synthesizing recommendation...\n")
  tryCatch({
    synthesis <- synthesize_recommendation(
      vw_results = vw_results,
      gg_results = gg_results,
      segment_results = segment_results,
      ladder_results = ladder_results,
      config = config
    )
    cat(sprintf("   Recommended price: %s%.2f\n",
                config$currency_symbol %||% "$",
                synthesis$recommendation$price))
    cat(sprintf("   Confidence: %s (%.0f%%)\n",
                synthesis$recommendation$confidence,
                synthesis$recommendation$confidence_score * 100))
  }, error = function(e) {
    message(sprintf("[TRS PARTIAL] PRICE_SYNTHESIS_FAILED: Recommendation synthesis failed: %s", e$message))
    cat(sprintf("   ! Synthesis failed: %s\n", e$message))
  })

  # --------------------------------------------------------------------------
  # STEP 7: Generate Visualizations
  # --------------------------------------------------------------------------
  cat("\n7. Generating visualizations...\n")
  plots <- generate_pricing_plots(analysis_results, config)
  cat(sprintf("   Generated %d plot(s)\n", length(plots)))

  # --------------------------------------------------------------------------
  # STEP 8: Generate Output
  # --------------------------------------------------------------------------
  cat("\n8. Generating output file...\n")
  write_pricing_output(
    results = analysis_results,
    plots = plots,
    validation = validation,
    config = config,
    output_file = output_file,
    segment_results = segment_results,
    ladder_results = ladder_results,
    synthesis = synthesis
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
    segment_results = segment_results,
    ladder_results = ladder_results,
    synthesis = synthesis,
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
  cat("TURAS PRICING RESEARCH ANALYSIS v11.0\n")
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
  # STEP 3: Run Core Analysis
  # --------------------------------------------------------------------------
  analysis_method <- tolower(config$analysis_method)
  vw_results <- NULL
  gg_results <- NULL

  if (analysis_method == "van_westendorp") {
    cat("\n3. Running Van Westendorp PSM analysis...\n")
    vw_results <- run_van_westendorp(validation$clean_data, config)
    analysis_results <- vw_results
    cat("   Price points calculated:\n")
    cat(sprintf("     PMC (Point of Marginal Cheapness): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PMC))
    cat(sprintf("     OPP (Optimal Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$OPP))
    cat(sprintf("     IDP (Indifference Price Point): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$IDP))
    cat(sprintf("     PME (Point of Marginal Expensiveness): %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PME))
    if (!is.null(vw_results$nms_results)) {
      cat(sprintf("     NMS Revenue Optimal: %s%.2f\n",
                  config$currency_symbol %||% "$", vw_results$nms_results$revenue_optimal))
    }

  } else if (analysis_method == "gabor_granger") {
    cat("\n3. Running Gabor-Granger analysis...\n")
    gg_results <- run_gabor_granger(validation$clean_data, config)
    analysis_results <- gg_results
    cat(sprintf("   Demand curve calculated for %d price points\n",
                nrow(gg_results$demand_curve)))
    if (!is.null(gg_results$optimal_price)) {
      cat(sprintf("   Optimal price (revenue-max): %s%.2f (%.1f%% purchase intent)\n",
                  config$currency_symbol %||% "$",
                  gg_results$optimal_price$price,
                  gg_results$optimal_price$purchase_intent * 100))
    }
    if (!is.null(gg_results$optimal_price_profit)) {
      cat(sprintf("   Optimal price (profit-max): %s%.2f (profit index: %.2f)\n",
                  config$currency_symbol %||% "$",
                  gg_results$optimal_price_profit$price,
                  gg_results$optimal_price_profit$profit_index))
    }

  } else if (analysis_method == "both") {
    cat("\n3. Running both Van Westendorp and Gabor-Granger analyses...\n")

    cat("   a) Van Westendorp PSM...\n")
    vw_results <- run_van_westendorp(validation$clean_data, config)
    cat(sprintf("      Acceptable range: %s%.2f - %s%.2f\n",
                config$currency_symbol %||% "$", vw_results$price_points$PMC,
                config$currency_symbol %||% "$", vw_results$price_points$PME))
    if (!is.null(vw_results$nms_results)) {
      cat(sprintf("      NMS Revenue Optimal: %s%.2f\n",
                  config$currency_symbol %||% "$", vw_results$nms_results$revenue_optimal))
    }

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
  # STEP 4: Run Segmented Analysis (if configured)
  # --------------------------------------------------------------------------
  segment_results <- NULL

  if (!is.null(config$segmentation$segment_column) &&
      !is.na(config$segmentation$segment_column) &&
      config$segmentation$segment_column != "") {

    cat("\n4. Running segment analysis...\n")
    cat(sprintf("   Segment column: %s\n", config$segmentation$segment_column))

    tryCatch({
      segment_results <- run_segmented_analysis(
        data = validation$clean_data,
        config = config,
        method = if (analysis_method == "both") "van_westendorp" else analysis_method
      )
      cat(sprintf("   Analyzed %d segments\n", length(segment_results$segment_results)))
      if (length(segment_results$insights) > 0) {
        cat("   Key insights:\n")
        for (insight in segment_results$insights[1:min(3, length(segment_results$insights))]) {
          cat(sprintf("     - %s\n", insight))
        }
      }
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] PRICE_SEGMENT_FAILED: Segment analysis failed: %s", e$message))
      cat(sprintf("   ! Segment analysis failed: %s\n", e$message))
    })
  }

  # --------------------------------------------------------------------------
  # STEP 5: Build Price Ladder (if VW results available)
  # --------------------------------------------------------------------------
  ladder_results <- NULL

  if (!is.null(vw_results)) {
    cat("\n5. Building price ladder...\n")

    tryCatch({
      ladder_results <- build_price_ladder(
        vw_results = vw_results,
        gg_results = gg_results,
        config = config
      )
      cat("   Tier structure generated:\n")
      for (i in 1:nrow(ladder_results$tier_table)) {
        cat(sprintf("     %-10s %s%.2f\n",
                    ladder_results$tier_table$tier[i],
                    config$currency_symbol %||% "$",
                    ladder_results$tier_table$price[i]))
      }
    }, error = function(e) {
      message(sprintf("[TRS PARTIAL] PRICE_LADDER_FAILED: Price ladder generation failed: %s", e$message))
      cat(sprintf("   ! Price ladder generation failed: %s\n", e$message))
    })
  }

  # --------------------------------------------------------------------------
  # STEP 6: Synthesize Recommendation
  # --------------------------------------------------------------------------
  synthesis <- NULL

  cat("\n6. Synthesizing recommendation...\n")
  tryCatch({
    synthesis <- synthesize_recommendation(
      vw_results = vw_results,
      gg_results = gg_results,
      segment_results = segment_results,
      ladder_results = ladder_results,
      config = config
    )
    cat(sprintf("   Recommended price: %s%.2f\n",
                config$currency_symbol %||% "$",
                synthesis$recommendation$price))
    cat(sprintf("   Confidence: %s (%.0f%%)\n",
                synthesis$recommendation$confidence,
                synthesis$recommendation$confidence_score * 100))
  }, error = function(e) {
    message(sprintf("[TRS PARTIAL] PRICE_SYNTHESIS_FAILED: Recommendation synthesis failed: %s", e$message))
    cat(sprintf("   ! Synthesis failed: %s\n", e$message))
  })

  # --------------------------------------------------------------------------
  # STEP 7: Generate Visualizations
  # --------------------------------------------------------------------------
  cat("\n7. Generating visualizations...\n")
  plots <- generate_pricing_plots(analysis_results, config)
  cat(sprintf("   Generated %d plot(s)\n", length(plots)))

  # --------------------------------------------------------------------------
  # STEP 8: Generate Output
  # --------------------------------------------------------------------------
  cat("\n8. Generating output file...\n")
  write_pricing_output(
    results = analysis_results,
    plots = plots,
    validation = validation,
    config = config,
    output_file = output_file,
    segment_results = segment_results,
    ladder_results = ladder_results,
    synthesis = synthesis
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
    segment_results = segment_results,
    ladder_results = ladder_results,
    synthesis = synthesis,
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
