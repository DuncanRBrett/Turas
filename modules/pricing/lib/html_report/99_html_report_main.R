# ==============================================================================
# TURAS PRICING MODULE - HTML REPORT ORCHESTRATOR
# ==============================================================================
#
# Purpose: Orchestrate the 4-layer HTML report generation pipeline
# Pattern: Follows confidence module architecture
# Version: 1.0.0
# ==============================================================================

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || (length(x) == 1 && is.na(x))) y else x

#' Generate Pricing HTML Report
#'
#' Main entry point for generating a self-contained HTML report from pricing
#' analysis results. Orchestrates the 4-layer pipeline:
#'   Layer 1: Data Transformer  → HTML-optimized structure
#'   Layer 2: Table Builder     → HTML tables
#'   Layer 3: Chart Builder     → SVG visualizations
#'   Layer 4: Page Builder      → Complete HTML document
#'
#' @param pricing_results Full results list from run_pricing_analysis()
#' @param output_path File path for the HTML output
#' @param config Configuration list
#' @return List with status, output_file, file_size
#' @export
generate_pricing_html_report <- function(pricing_results, output_path, config = list()) {

  cat("   HTML Report: Starting generation...\n")

  # --------------------------------------------------------------------------
  # Step 0: Locate and source sub-modules
  # --------------------------------------------------------------------------
  report_dir <- NULL
  possible_dirs <- c(
    file.path(dirname(sys.frame(1)$ofile %||% ""), "html_report"),
    file.path(getwd(), "modules", "pricing", "lib", "html_report"),
    file.path(dirname(sys.frame(1)$ofile %||% ""), "..", "lib", "html_report")
  )

  for (d in possible_dirs) {
    if (dir.exists(d)) { report_dir <- d; break }
  }

  if (is.null(report_dir)) {
    # Try relative to this file
    this_dir <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NULL)
    if (!is.null(this_dir)) report_dir <- this_dir
  }

  if (is.null(report_dir) || !dir.exists(report_dir)) {
    cat("   ! HTML Report: Could not locate html_report directory\n")
    return(list(status = "REFUSED", message = "html_report directory not found"))
  }

  source(file.path(report_dir, "01_data_transformer.R"))
  source(file.path(report_dir, "02_table_builder.R"))
  source(file.path(report_dir, "04_chart_builder.R"))
  source(file.path(report_dir, "03_page_builder.R"))

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

    # Safely extract GG demand data with numeric coercion
    gg_prices <- safe_numeric(gg$demand_curve$price)
    gg_intents <- safe_numeric(gg$demand_curve$purchase_intent)

    # Revenue: prefer revenue_curve$revenue_index, fall back to price * intent
    gg_revenue <- safe_numeric(gg$revenue_curve$revenue_index)
    if (is.null(gg_revenue) || length(gg_revenue) == 0) {
      if (!is.null(gg_prices) && !is.null(gg_intents)) {
        gg_revenue <- gg_prices * gg_intents
      }
    }

    # Optimal price: extract scalar value safely
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
  # Step 4: Assemble page
  # --------------------------------------------------------------------------
  cat("   HTML Report: Assembling page...\n")
  page <- build_pricing_page(html_data, tables, charts, config)

  # --------------------------------------------------------------------------
  # Step 5: Write to disk
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
