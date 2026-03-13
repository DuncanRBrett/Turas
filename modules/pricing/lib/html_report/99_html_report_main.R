# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT ORCHESTRATOR
# ==============================================================================
#
# Purpose: Orchestrate the 4-layer HTML report generation pipeline
# Pattern: Follows confidence module architecture
# Version: 2.0.0
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

# Consolidated htmlEscape — defined once here, available to all sourced layers
htmlEscape <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

#' Generate Pricing HTML Report
#'
#' Main entry point for generating a self-contained HTML report from pricing
#' analysis results. Orchestrates the 4-layer pipeline:
#'   Layer 1: Data Transformer  -> HTML-optimized structure
#'   Layer 2: Table Builder     -> HTML tables
#'   Layer 3: Chart Builder     -> SVG visualizations
#'   Layer 4: Page Builder      -> Complete HTML document
#'
#' @param pricing_results Full results list from run_pricing_analysis()
#' @param output_path File path for the HTML output
#' @param config Configuration list
#' @param report_dir Optional path to html_report directory (passed from 00_main.R)
#' @return List with status, output_file, file_size
#' @export
generate_pricing_html_report <- function(pricing_results, output_path,
                                          config = list(), report_dir = NULL) {

  cat("   HTML Report: Starting generation...\n")

  # --------------------------------------------------------------------------
  # Step 0: Locate and source sub-modules
  # --------------------------------------------------------------------------
  if (is.null(report_dir) || !dir.exists(report_dir)) {
    # Reliable fallback: try multiple known locations
    possible_dirs <- c(
      file.path(getwd(), "modules", "pricing", "lib", "html_report"),
      tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ""),
      file.path(Sys.getenv("TURAS_ROOT", getwd()), "modules", "pricing", "lib", "html_report")
    )

    for (d in possible_dirs) {
      if (nzchar(d) && dir.exists(d)) { report_dir <- d; break }
    }
  }

  if (is.null(report_dir) || !dir.exists(report_dir)) {
    cat("   ! HTML Report: Could not locate html_report directory\n")
    return(list(status = "REFUSED", message = "html_report directory not found"))
  }

  source(file.path(report_dir, "01_data_transformer.R"), local = FALSE)
  source(file.path(report_dir, "02_table_builder.R"), local = FALSE)
  source(file.path(report_dir, "04_chart_builder.R"), local = FALSE)
  source(file.path(report_dir, "03_page_builder.R"), local = FALSE)

  # Source simulator data extraction helpers
  sim_builder_path <- file.path(dirname(report_dir), "simulator", "simulator_builder.R")
  if (file.exists(sim_builder_path)) {
    source(sim_builder_path, local = FALSE)
  }

  # Locate JS directory for file-based JS embedding
  js_dir <- file.path(report_dir, "js")
  if (!dir.exists(js_dir)) js_dir <- NULL

  # --------------------------------------------------------------------------
  # Step 1: Transform data
  # --------------------------------------------------------------------------
  cat("   HTML Report: Transforming data...\n")
  html_data <- transform_pricing_for_html(pricing_results, config)

  method <- html_data$meta$method
  currency <- html_data$meta$currency
  brand <- html_data$meta$brand_colour

  # --------------------------------------------------------------------------
  # Step 2: Build tables
  # --------------------------------------------------------------------------
  cat("   HTML Report: Building tables...\n")
  tables <- list()

  if (!is.null(html_data$van_westendorp)) {
    tables$vw_price_points <- build_vw_price_points_table(html_data$van_westendorp, currency)
    tables$vw_ci <- build_vw_ci_table(html_data$van_westendorp, currency)
  }

  if (!is.null(html_data$gabor_granger)) {
    tables$gg_optimal <- build_gg_optimal_table(html_data$gabor_granger, currency)
    tables$gg_demand <- build_gg_demand_table(html_data$gabor_granger, currency)
    tables$gg_elasticity <- build_gg_elasticity_table(html_data$gabor_granger, currency)
  }

  if (!is.null(html_data$monadic)) {
    tables$monadic_model <- build_monadic_model_table(html_data$monadic)
    tables$monadic_observed <- build_monadic_observed_table(html_data$monadic, currency)
    tables$monadic_optimal <- build_monadic_optimal_table(html_data$monadic, currency)
  }

  if (!is.null(html_data$segments)) {
    tables$segment_comparison <- build_segment_comparison_table(html_data$segments)
  }

  if (!is.null(html_data$recommendation)) {
    tables$evidence <- build_evidence_html_table(html_data$recommendation$evidence_table, currency)
  }

  # --------------------------------------------------------------------------
  # Step 3: Build charts
  # --------------------------------------------------------------------------
  cat("   HTML Report: Building charts...\n")
  charts <- list()

  # Helper: safely coerce to numeric vector, handling NULL/list/character
  safe_numeric <- function(x) {
    if (is.null(x)) return(NULL)
    if (is.list(x) && !is.data.frame(x)) x <- unlist(x)
    as.numeric(x)
  }

  if (!is.null(html_data$van_westendorp)) {
    tryCatch({
      charts$vw_curves <- build_vw_curves_chart(html_data$van_westendorp, brand)
    }, error = function(e) {
      cat(sprintf("   ! VW curves chart failed: %s\n", e$message))
      charts$vw_curves <<- ""
    })
  }

  if (!is.null(html_data$gabor_granger)) {
    gg <- html_data$gabor_granger

    gg_prices <- safe_numeric(gg$demand_curve$price)
    gg_intents <- safe_numeric(gg$demand_curve$purchase_intent)

    gg_revenue <- safe_numeric(gg$revenue_curve$revenue_index)
    if (is.null(gg_revenue) || length(gg_revenue) == 0) {
      if (!is.null(gg_prices) && !is.null(gg_intents)) {
        gg_revenue <- gg_prices * gg_intents
      }
    }

    gg_optimal <- safe_numeric(gg$optimal_price$price)
    if (!is.null(gg_optimal) && length(gg_optimal) > 1) gg_optimal <- gg_optimal[1]

    tryCatch({
      charts$gg_demand <- build_demand_curve_chart(
        prices = gg_prices,
        intents = gg_intents,
        revenue = gg_revenue,
        optimal_price = gg_optimal,
        brand_colour = brand,
        title = "Gabor-Granger Demand & Revenue Curves",
        currency = currency
      )
    }, error = function(e) {
      cat(sprintf("   ! GG demand chart failed: %s\n", e$message))
      charts$gg_demand <<- ""
    })

    if (!is.null(gg$elasticity)) {
      tryCatch({
        charts$gg_elasticity <- build_elasticity_chart(gg$elasticity, brand, currency)
      }, error = function(e) {
        cat(sprintf("   ! GG elasticity chart failed: %s\n", e$message))
        charts$gg_elasticity <<- ""
      })
    }
  }

  if (!is.null(html_data$monadic)) {
    mon <- html_data$monadic
    ci_lower <- ci_upper <- NULL
    if (!is.null(mon$confidence_intervals$demand_curve_ci)) {
      ci_lower <- safe_numeric(mon$confidence_intervals$demand_curve_ci$ci_lower)
      ci_upper <- safe_numeric(mon$confidence_intervals$demand_curve_ci$ci_upper)
    }

    tryCatch({
      charts$monadic_demand <- build_demand_curve_chart(
        prices = safe_numeric(mon$demand_curve$price),
        intents = safe_numeric(mon$demand_curve$predicted_intent),
        revenue = safe_numeric(mon$demand_curve$revenue_index),
        ci_lower = ci_lower,
        ci_upper = ci_upper,
        observed_prices = safe_numeric(mon$observed_data$price),
        observed_intents = safe_numeric(mon$observed_data$observed_intent),
        optimal_price = safe_numeric(mon$optimal_price$price),
        brand_colour = brand,
        title = "Monadic Demand Curve (Logistic Model)",
        currency = currency
      )
    }, error = function(e) {
      cat(sprintf("   ! Monadic demand chart failed: %s\n", e$message))
      charts$monadic_demand <<- ""
    })

    if (!is.null(mon$elasticity)) {
      tryCatch({
        charts$monadic_elasticity <- build_elasticity_chart(mon$elasticity, brand, currency)
      }, error = function(e) {
        cat(sprintf("   ! Monadic elasticity chart failed: %s\n", e$message))
        charts$monadic_elasticity <<- ""
      })
    }
  }

  if (!is.null(html_data$segments)) {
    tryCatch({
      charts$segment_comparison <- build_segment_comparison_chart(
        html_data$segments, brand, currency
      )
    }, error = function(e) {
      cat(sprintf("   ! Segment comparison chart failed: %s\n", e$message))
      charts$segment_comparison <<- ""
    })
  }

  # --------------------------------------------------------------------------
  # Step 4: Extract simulator data (if demand curve available)
  # --------------------------------------------------------------------------
  simulator_data <- NULL
  if (exists("extract_demand_data", mode = "function")) {
    tryCatch({
      results <- pricing_results$results
      analysis_method <- tolower(pricing_results$method %||% "unknown")
      demand_data <- extract_demand_data(results, analysis_method)

      if (!is.null(demand_data)) {
        cat("   HTML Report: Preparing simulator data...\n")
        optimal_price <- extract_optimal_price(results, analysis_method)
        segment_demand <- extract_segment_demand(pricing_results$segment_results, analysis_method)

        currency <- config$currency_symbol %||% "$"
        brand <- config$brand_colour %||% "#1e3a5f"
        unit_cost <- as.numeric(config$unit_cost %||% 0)
        project_name <- config$project_name %||% "Pricing Analysis"
        scenarios <- config$simulator$scenarios %||% list()

        pricing_json <- build_pricing_json(demand_data, optimal_price, segment_demand)
        config_json <- sprintf(
          '{"currency":"%s","brand_colour":"%s","unit_cost":%s,"project_name":"%s","scenarios":%s}',
          jsonEscape(currency),
          jsonEscape(brand),
          if (unit_cost > 0) sprintf("%.2f", unit_cost) else "0",
          jsonEscape(project_name),
          build_scenarios_json(scenarios, currency)
        )

        simulator_data <- list(
          pricing_json = pricing_json,
          config_json = config_json,
          has_segments = length(segment_demand) > 0
        )
      }
    }, error = function(e) {
      cat(sprintf("   ! HTML Report: Simulator data extraction failed: %s\n", e$message))
    })
  }

  # --------------------------------------------------------------------------
  # Step 5: Assemble page
  # --------------------------------------------------------------------------
  cat("   HTML Report: Assembling page...\n")
  page <- build_pricing_page(html_data, tables, charts, config,
                              js_dir = js_dir, simulator_data = simulator_data)

  # --------------------------------------------------------------------------
  # Step 6: Write to disk
  # --------------------------------------------------------------------------
  cat("   HTML Report: Writing file...\n")

  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE)
  }

  writeLines(page, output_path)

  file_size <- file.info(output_path)$size
  file_size_mb <- round(file_size / 1024 / 1024, 2)

  cat(sprintf("   HTML Report: Written to %s (%.1f KB)\n",
              basename(output_path), file_size / 1024))

  list(
    status = "PASS",
    output_file = output_path,
    file_size_bytes = file_size,
    file_size_mb = file_size_mb
  )
}
