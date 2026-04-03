# ==============================================================================
# TURAS PRICING RESEARCH MODULE - MAIN ENTRY POINT
# ==============================================================================
#
# Module: Pricing Research
# Purpose: Analyze pricing sensitivity using Van Westendorp PSM,
#          Gabor-Granger, and Monadic methodologies with segment analysis,
#          price ladder, and recommendation synthesis
# Version: Turas v12.0
# Date: 2026-03-20
#
# ==============================================================================

PRICING_VERSION <- "12.0"

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

  trs_files <- c("trs_run_state.R", "trs_banner.R", "trs_run_status_writer.R",
                 "stats_pack_writer.R")

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
  message(sprintf("[TRS INFO] PRICE_TRS_LOAD: Could not load TRS infrastructure: %s", e$message))
})

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Run Pricing Research Analysis
#'
#' Main entry point for pricing research analysis. Loads configuration from
#' an Excel file and delegates to run_pricing_analysis_from_config().
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
#'   - method: Analysis method used ("van_westendorp", "gabor_granger", "monadic", or "both")
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
#' # Run Gabor-Granger with custom paths
#' results <- run_pricing_analysis(
#'   config_file = "gg_config.xlsx",
#'   data_file = "survey_data.csv",
#'   output_file = "pricing_results.xlsx"
#' )
#' }
#'
#' @export
run_pricing_analysis <- function(config_file, data_file = NULL, output_file = NULL) {

  # Load configuration from file
  config <- load_pricing_config(config_file)

  # Override data_file and output_file if provided as arguments
  if (!is.null(data_file)) {
    config$data_file <- data_file
  }
  if (!is.null(output_file)) {
    config$output_file <- output_file
  }

  # Delegate to canonical implementation
  run_pricing_analysis_from_config(config)
}


#' Run Pricing Analysis from Pre-loaded Config
#'
#' Canonical implementation of the pricing analysis pipeline. Accepts a
#' pre-loaded configuration list and runs all analysis steps: data loading,
#' validation, core analysis (VW/GG/Monadic), segmentation, price ladder,
#' recommendation synthesis, visualizations, Excel output, and HTML report.
#'
#' @param config Pre-loaded configuration list (from load_pricing_config)
#'
#' @return List containing:
#'   - method: Analysis method used ("van_westendorp", "gabor_granger", "monadic", or "both")
#'   - results: Method-specific results (price points, demand curves, etc.)
#'   - segment_results: Segmented analysis results (if configured)
#'   - ladder_results: Price ladder results (if VW available)
#'   - synthesis: Recommendation synthesis with executive summary
#'   - plots: List of generated plot objects
#'   - diagnostics: Data quality and validation results
#'   - config: Processed configuration
#'   - run_result: TRS run result (if TRS infrastructure available)
#'   - html_report_path: Path to HTML report (if generated)
#'
#' @examples
#' \dontrun{
#' config <- load_pricing_config("pricing_config.xlsx")
#' results <- run_pricing_analysis_from_config(config)
#' }
#'
#' @export
run_pricing_analysis_from_config <- function(config) {

  # ==========================================================================
  # TRS RUN STATE INITIALIZATION (TRS v1.0)
  # ==========================================================================
  trs_state <- if (exists("turas_run_state_new", mode = "function")) {
    turas_run_state_new("PRICING")
  } else {
    NULL
  }

  if (exists("turas_print_start_banner", mode = "function")) {
    turas_print_start_banner("PRICING", PRICING_VERSION)
  } else {
    cat("\n")
    cat(rep("=", 80), "\n", sep = "")
    cat(sprintf("TURAS PRICING RESEARCH ANALYSIS v%s\n", PRICING_VERSION))
    cat(rep("=", 80), "\n", sep = "")
    cat("\n")
  }

  # Initialize guard state for pre-flight tracking
  guard <- pricing_guard_init()
  warnings_list <- character()

  # --------------------------------------------------------------------------
  # STEP 1: Configuration (already loaded)
  # --------------------------------------------------------------------------
  cat("1. Configuration loaded\n")
  cat(sprintf("   Analysis method: %s\n", config$analysis_method))
  guard$analysis_type <- config$analysis_method
  if (!is.null(config$project_name) && !is.na(config$project_name)) {
    cat(sprintf("   Project: %s\n", config$project_name))
  }

  # Resolve data_file
  data_file <- config$data_file
  if (is.null(data_file) || is.na(data_file)) {
    pricing_refuse(
      code = "CFG_MISSING_DATA_FILE",
      title = "Data File Not Specified",
      problem = "No data file path found in configuration",
      why_it_matters = "Cannot load survey data without knowing which file to read",
      how_to_fix = "Add 'data_file' to the Settings sheet in your configuration, or pass data_file parameter when calling run_pricing_analysis()"
    )
  }

  # Resolve output_file
  output_file <- config$output_file
  if (is.null(output_file) || is.na(output_file)) {
    if (!is.null(config$output$directory) && !is.null(config$output$filename_prefix)) {
      output_file <- file.path(config$output$directory,
                              paste0(config$output$filename_prefix, ".xlsx"))
    } else {
      output_file <- file.path(config$project_root, "pricing_results.xlsx")
    }
  }

  # --------------------------------------------------------------------------
  # STEP 2: Load and Validate Data
  # --------------------------------------------------------------------------
  cat("\n2. Loading and validating data...\n")
  data_result <- load_pricing_data(data_file, config)
  cat(sprintf("   Loaded %d respondents\n", nrow(data_result$data)))

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
  monadic_results <- NULL

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

  } else if (analysis_method == "monadic") {
    cat("\n3. Running Monadic Price Testing analysis...\n")

    # Source monadic module
    monadic_path <- file.path(.get_script_dir_for_guard(), "13_monadic.R")
    if (!file.exists(monadic_path)) {
      monadic_path <- file.path(getwd(), "modules", "pricing", "R", "13_monadic.R")
    }
    if (file.exists(monadic_path)) {
      source(monadic_path)
    } else {
      pricing_refuse(
        code = "BUG_MONADIC_NOT_FOUND",
        title = "Monadic Module Not Found",
        problem = "Could not locate 13_monadic.R",
        why_it_matters = "Monadic analysis implementation is required",
        how_to_fix = "Ensure modules/pricing/R/13_monadic.R exists"
      )
    }

    # Pre-flight validation for monadic data
    guard <- validate_monadic_data(validation$clean_data, config, guard)
    pricing_print_guard_summary(guard, nrow(validation$clean_data))

    monadic_results <- run_monadic_analysis(validation$clean_data, config)
    analysis_results <- monadic_results
    cat(sprintf("   Demand curve modelled across %d price points\n",
                length(monadic_results$demand_curve$price)))
    if (!is.null(monadic_results$optimal_price)) {
      cat(sprintf("   Optimal price (revenue-max): %s%.2f (%.1f%% predicted intent)\n",
                  config$currency_symbol %||% "$",
                  monadic_results$optimal_price$price,
                  monadic_results$optimal_price$predicted_intent * 100))
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
    pricing_refuse(
      code = "CFG_INVALID_METHOD",
      title = "Unknown Analysis Method",
      problem = sprintf("Analysis method '%s' is not recognized", config$analysis_method),
      why_it_matters = "Cannot run analysis without a valid methodology",
      how_to_fix = c(
        "Set analysis_method in Settings sheet to one of:",
        "  - 'van_westendorp' for price sensitivity meter",
        "  - 'gabor_granger' for demand curve analysis",
        "  - 'monadic' for randomized cell monadic testing",
        "  - 'both' for combined VW + GG analysis"
      ),
      observed = config$analysis_method,
      expected = c("van_westendorp", "gabor_granger", "monadic", "both")
    )
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
      monadic_results = monadic_results,
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

  # ==========================================================================
  # TRS: Log PARTIAL events for any warnings
  # ==========================================================================
  if (!is.null(trs_state) && length(warnings_list) > 0) {
    for (warn in warnings_list) {
      if (exists("turas_run_state_partial", mode = "function")) {
        turas_run_state_partial(
          trs_state,
          "PRICE_WARNING",
          "Analysis warning",
          problem = warn
        )
      }
    }
  }

  # ==========================================================================
  # TRS: Get run result (before output generation)
  # ==========================================================================
  run_result <- if (!is.null(trs_state) && exists("turas_run_state_result", mode = "function")) {
    turas_run_state_result(trs_state)
  } else {
    NULL
  }

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
    synthesis = synthesis,
    run_result = run_result
  )
  cat(sprintf("   Results written to: %s\n", output_file))

  # --------------------------------------------------------------------------
  # STEP 9: Generate HTML Report (consolidated with simulator)
  # --------------------------------------------------------------------------
  html_report_path <- NULL
  if (isTRUE(config$generate_html_report) || isTRUE(config$generate_simulator)) {
    cat("\n9. Generating HTML report (consolidated)...\n")

    html_report_main <- NULL
    possible_paths <- c(
      file.path(.get_script_dir_for_guard(), "..", "lib", "html_report", "99_html_report_main.R"),
      file.path(getwd(), "modules", "pricing", "lib", "html_report", "99_html_report_main.R")
    )
    for (p in possible_paths) {
      if (file.exists(p)) { html_report_main <- p; break }
    }

    if (!is.null(html_report_main)) {
      tryCatch({
        source(html_report_main)

        html_path <- sub("\\.xlsx$", ".html", output_file, ignore.case = TRUE)
        if (html_path == output_file) {
          html_path <- paste0(tools::file_path_sans_ext(output_file), ".html")
        }

        full_results <- list(
          method = analysis_method,
          results = analysis_results,
          segment_results = segment_results,
          ladder_results = ladder_results,
          synthesis = synthesis,
          diagnostics = validation
        )

        # Pass resolved report_dir so child doesn't need sys.frame()
        resolved_report_dir <- dirname(html_report_main)
        html_result <- generate_pricing_html_report(full_results, html_path, config,
                                                     report_dir = resolved_report_dir)
        if (html_result$status == "PASS") {
          html_report_path <- html_result$output_file
          cat(sprintf("   HTML report: %s\n", basename(html_report_path)))

          # Minify for client delivery (if requested via Shiny checkbox)
          if (exists("turas_prepare_deliverable", mode = "function")) {
            turas_prepare_deliverable(html_path)
          }
        }
      }, error = function(e) {
        message(sprintf("[TRS PARTIAL] PRICE_HTML_FAILED: HTML report generation failed: %s", e$message))
        cat(sprintf("   ! HTML report failed: %s\n", e$message))
      })
    } else {
      cat("   ! HTML report module not found, skipping\n")
    }
  }

  # --------------------------------------------------------------------------
  # STEP 10: Generate Stats Pack (Optional)
  # --------------------------------------------------------------------------
  generate_stats_pack_flag <- isTRUE(
    toupper(config$settings$Generate_Stats_Pack %||% "N") == "Y"
  ) || isTRUE(getOption("turas.generate_stats_pack", FALSE))

  if (generate_stats_pack_flag) {
    cat("\n10. Generating stats pack...\n")
    generate_pricing_stats_pack(
      config          = config,
      data_result     = data_result,
      validation      = validation,
      analysis_method = analysis_method,
      vw_results      = vw_results,
      gg_results      = gg_results,
      monadic_results = monadic_results,
      segment_results = segment_results,
      run_result      = run_result,
      output_file     = output_file,
      start_time      = Sys.time()
    )
  }

  # ==========================================================================
  # TRS FINAL BANNER (TRS v1.0)
  # ==========================================================================
  if (!is.null(run_result) && exists("turas_print_final_banner", mode = "function")) {
    turas_print_final_banner(run_result)
  } else {
    cat("\n")
    cat(rep("=", 80), "\n", sep = "")
    if (length(warnings_list) == 0) {
      cat("[TRS PASS] PRICING - ANALYSIS COMPLETED SUCCESSFULLY\n")
    } else {
      cat(sprintf("[TRS PARTIAL] PRICING - ANALYSIS COMPLETED WITH %d WARNING(S)\n", length(warnings_list)))
    }
    cat(rep("=", 80), "\n", sep = "")
    cat("\n")
  }

  # Return results
  invisible(list(
    method = analysis_method,
    results = analysis_results,
    segment_results = segment_results,
    ladder_results = ladder_results,
    synthesis = synthesis,
    plots = plots,
    diagnostics = validation,
    config = config,
    run_result = run_result,
    html_report_path = html_report_path
  ))
}


#' @export
pricing <- run_pricing_analysis  # Alias for convenience


# Helper operator for default values
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x
}


# ==============================================================================
# STATS PACK HELPER
# ==============================================================================

#' Generate Pricing Stats Pack
#'
#' Builds the diagnostic payload from pricing analysis results and writes
#' the stats pack Excel workbook alongside the main output.
#'
#' @keywords internal
generate_pricing_stats_pack <- function(config, data_result, validation,
                                        analysis_method, vw_results, gg_results,
                                        monadic_results, segment_results,
                                        run_result, output_file, start_time) {

  if (!exists("turas_write_stats_pack", mode = "function")) {
    cat("  ! Stats pack writer not loaded - skipping\n")
    return(invisible(NULL))
  }

  # Output path: same base as main output, with _stats_pack suffix
  output_path <- sub("(\\.xlsx)$", "_stats_pack.xlsx", output_file, ignore.case = TRUE)
  if (identical(output_path, output_file)) {
    output_path <- paste0(tools::file_path_sans_ext(output_file), "_stats_pack.xlsx")
  }

  # Data receipt
  raw_data <- data_result$data
  data_receipt <- list(
    file_name           = basename(config$data_file %||% "unknown"),
    n_rows              = nrow(raw_data),
    n_cols              = ncol(raw_data),
    questions_in_config = 0L  # pricing does not use a question list
  )

  # Price points tested (from config ladder/grid)
  n_price_points <- length(config$price_points %||%
                           config$gabor_granger$price_points %||%
                           config$van_westendorp$price_range %||%
                           list())

  # Segmentation status
  seg_enabled <- !is.null(config$segmentation$segment_column) &&
                 !is.na(config$segmentation$segment_column %||% NA) &&
                 nzchar(config$segmentation$segment_column %||% "")
  n_segments   <- if (seg_enabled && !is.null(segment_results)) {
    length(segment_results$segment_results)
  } else {
    0L
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
    "Method"            = analysis_method,
    "Van Westendorp"    = if (!is.null(vw_results))
                            "Cumulative frequency intersections (base R)"
                          else "Not used",
    "Gabor-Granger"     = if (!is.null(gg_results))
                            "Demand curve regression (base R lm())"
                          else "Not used",
    "Price Points tested" = if (n_price_points > 0L) as.character(n_price_points) else "—",
    "Segmentation"      = if (seg_enabled) {
                            sprintf("Enabled — %d segment(s)", n_segments)
                          } else "Disabled",
    "TRS Status"        = run_result$status %||% "PASS",
    "TRS Events"        = trs_summary
  )

  duration_secs <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  payload <- list(
    module           = "PRICING",
    project_name     = config$project_name %||% NULL,
    analyst_name     = config$analyst_name %||% NULL,
    research_house   = config$research_house %||% NULL,
    run_timestamp    = start_time,
    turas_version    = PRICING_VERSION,
    r_version        = R.version$version.string,
    status           = run_result$status %||% "PASS",
    duration_seconds = duration_secs,
    data_receipt     = data_receipt,
    data_used        = list(
      n_respondents = validation$n_valid %||% nrow(raw_data),
      n_excluded    = validation$n_excluded %||% 0L,
      n_variables   = n_price_points,
      method        = analysis_method
    ),
    assumptions      = assumptions,
    run_result       = run_result,
    packages         = c("openxlsx", "data.table"),
    config_echo      = list(settings = config[c("analysis_method", "currency_symbol",
                                                 "project_name", "data_file",
                                                 "output_file")])
  )

  result <- turas_write_stats_pack(payload, output_path)

  if (!is.null(result)) {
    cat(sprintf("   Stats pack written: %s\n", basename(output_path)))
  }

  invisible(result)
}
