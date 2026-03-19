# ==============================================================================
# CONJOINT HTML REPORT - MAIN ORCHESTRATOR
# ==============================================================================
#
# Module: Conjoint Analysis - HTML Report Generator
# Purpose: Lazy-load orchestrator for combined report + simulator generation
# Version: 3.1.0
# Date: 2026-03-12
#
# USAGE:
#   generate_conjoint_html_report(conjoint_results, output_path, config)
#
# ARCHITECTURE:
#   00_html_guard.R        -> Input validation
#   01_data_transformer.R  -> Transform results to HTML-ready data
#   02_table_builder.R     -> HTML table construction with export attrs
#   03_page_builder.R      -> Full HTML page assembly (header, panels, JS)
#   04_html_writer.R       -> Write to disk
#   05_chart_builder.R     -> SVG chart construction
#   js/*.js                -> 7 JavaScript modules (inline in report)
#
# ==============================================================================

# Null coalesce
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Determine report directory — uses .conjoint_lib_dir global (set by 00_main.R)
.conjoint_html_report_dir <- if (exists(".conjoint_lib_dir", envir = globalenv())) {
  file.path(get(".conjoint_lib_dir", envir = globalenv()), "html_report")
} else {
  tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ".")
}

assign(".chr_conjoint_loaded", FALSE, envir = globalenv())


#' Lazy-Load HTML Report Submodules
#'
#' Sources all component files on first call. Returns NULL on success,
#' TRS refusal on failure.
#'
#' @keywords internal
.chr_load_conjoint_submodules <- function() {

  if (isTRUE(get0(".chr_conjoint_loaded", envir = globalenv()))) return(NULL)

  submodules <- c(
    "00_html_guard.R",
    "01_data_transformer.R",
    "02_table_builder.R",
    "05_chart_builder.R",
    "03_page_builder.R",
    "04_html_writer.R"
  )

  for (f in submodules) {
    fpath <- file.path(.conjoint_html_report_dir, f)
    if (!file.exists(fpath)) {
      return(list(
        status = "REFUSED",
        code = "IO_HTML_SUBMODULE_MISSING",
        message = sprintf("HTML report submodule not found: %s", f),
        how_to_fix = sprintf("Ensure %s exists in %s", f, .conjoint_html_report_dir)
      ))
    }
    source(fpath, local = FALSE)
  }

  assign(".chr_conjoint_loaded", TRUE, envir = globalenv())
  NULL
}


#' Generate Conjoint HTML Report (Combined Report + Simulator)
#'
#' Main entry point for HTML report generation. Produces a single self-contained
#' HTML file with all analysis panels and an embedded market simulator.
#'
#' @param conjoint_results List containing:
#'   - utilities: Data frame with Attribute, Level, Utility
#'   - importance: Data frame with Attribute, Importance
#'   - model_result: turas_conjoint_model object
#'   - diagnostics: Diagnostics list
#'   - config: Module configuration
#'   - wtp: WTP results (optional)
#' @param output_path File path for HTML output
#' @param config Report configuration (brand_colour, accent_colour, project_name,
#'   insight_*, analyst_*, company_name, client_name, closing_notes)
#' @return TRS status list with output_path
#' @export
generate_conjoint_html_report <- function(conjoint_results, output_path, config = list()) {

  # Step 0: Lazy-load submodules
  load_err <- .chr_load_conjoint_submodules()
  if (!is.null(load_err)) return(load_err)

  cat("\n  [HTML REPORT] Generating conjoint analysis report...\n")

  # Step 1: Guard — validate inputs
  guard_result <- validate_conjoint_html_inputs(conjoint_results, config)
  if (!guard_result$valid) {
    cat(sprintf("\n  [HTML REPORT ERROR] Validation failed: %s\n",
                paste(guard_result$errors, collapse = "; ")))
    return(list(
      status = "REFUSED",
      code = "DATA_HTML_VALIDATION_FAILED",
      message = paste("Input validation failed:", paste(guard_result$errors, collapse = "; ")),
      how_to_fix = "Check conjoint_results structure matches expected format"
    ))
  }

  if (length(guard_result$warnings) > 0) {
    for (w in guard_result$warnings) {
      cat(sprintf("  [HTML REPORT WARNING] %s\n", w))
    }
  }

  # Step 2: Transform data
  html_data <- transform_conjoint_for_html(conjoint_results, config)

  # Step 3: Build tables
  brand <- config$brand_colour %||% "#323367"

  tables <- .build_all_tables(html_data)

  # Step 4: Build charts
  charts <- .build_all_charts(html_data, brand)

  # Step 5: Assemble page (combined report + simulator)
  page <- build_conjoint_page(html_data, tables, charts, config)

  # Step 6: Write to disk
  write_result <- write_conjoint_html_report(page, output_path)

  # Report file size warning for large reports
  if (!is.null(write_result$file_size_mb) && write_result$file_size_mb > 5) {
    cat(sprintf("  [HTML REPORT WARNING] Large file (%.1f MB). Consider reducing data.\n",
                write_result$file_size_mb))
  }

  write_result
}


# ==============================================================================
# TABLE BUILDING
# ==============================================================================

#' @keywords internal
.build_all_tables <- function(html_data) {

  tables <- list()

  # Importance table
  if (!is.null(html_data$importance)) {
    tables$importance <- build_importance_table(html_data$importance)
  }

  # Model fit table
  tables$model_fit <- build_model_fit_table(
    html_data$diagnostics, html_data$model_result
  )

  # Utility tables per attribute
  tables$utility_tables <- lapply(html_data$utilities_by_attr, build_utilities_table)

  # HB convergence
  if (!is.null(html_data$hb_data) && !is.null(html_data$hb_data$convergence)) {
    tables$convergence <- build_convergence_table(html_data$hb_data$convergence)
  }

  # Respondent quality
  if (!is.null(html_data$hb_data) && !is.null(html_data$hb_data$quality)) {
    tables$respondent_quality <- build_respondent_quality_table(
      html_data$hb_data$quality,
      html_data$summary$n_respondents
    )
  }

  # LC comparison
  if (!is.null(html_data$lc_data)) {
    tables$lc_comparison <- build_lc_comparison_table(
      html_data$lc_data$comparison, html_data$lc_data$optimal_k
    )

    # Class importance
    if (!is.null(html_data$lc_data$class_importance)) {
      tables$class_importance <- build_class_importance_table(
        html_data$lc_data$class_importance,
        html_data$lc_data$class_proportions
      )
    }
  }

  # WTP table
  if (!is.null(html_data$wtp_data)) {
    tables$wtp <- build_wtp_table(html_data$wtp_data)

    # Demand curve table
    if (!is.null(html_data$wtp_data$demand_curve)) {
      tables$demand_curve <- build_demand_table(
        html_data$wtp_data$demand_curve,
        html_data$wtp_data$currency_symbol %||% "$"
      )
    }
  }

  tables
}


# ==============================================================================
# CHART BUILDING
# ==============================================================================

#' @keywords internal
.build_all_charts <- function(html_data, brand) {

  charts <- list()

  # Importance chart
  if (!is.null(html_data$importance)) {
    charts$importance <- build_importance_chart(html_data$importance, brand)
  }

  # Utility charts per attribute (bar + dot plot)
  charts$utility_charts <- lapply(names(html_data$utilities_by_attr), function(attr_name) {
    build_utility_chart(html_data$utilities_by_attr[[attr_name]], attr_name, brand)
  })
  names(charts$utility_charts) <- names(html_data$utilities_by_attr)

  charts$utility_dot_charts <- lapply(names(html_data$utilities_by_attr), function(attr_name) {
    build_utility_dot_plot(html_data$utilities_by_attr[[attr_name]], attr_name, brand)
  })
  names(charts$utility_dot_charts) <- names(html_data$utilities_by_attr)

  # BIC chart for LC
  if (!is.null(html_data$lc_data) && !is.null(html_data$lc_data$comparison)) {
    charts$bic <- build_bic_chart(
      html_data$lc_data$comparison, html_data$lc_data$optimal_k, brand
    )
  }

  # Class size chart
  if (!is.null(html_data$lc_data) && !is.null(html_data$lc_data$class_sizes)) {
    sizes <- html_data$lc_data$class_proportions %||% html_data$lc_data$class_sizes
    charts$class_sizes <- build_class_size_chart(sizes, brand)
  }

  # Class importance chart
  if (!is.null(html_data$lc_data) && !is.null(html_data$lc_data$class_importance)) {
    charts$class_importance <- build_class_importance_chart(
      html_data$lc_data$class_importance, brand
    )
  }

  # WTP chart
  if (!is.null(html_data$wtp_data)) {
    charts$wtp <- build_wtp_chart(html_data$wtp_data, brand)

    # Demand curve chart
    if (!is.null(html_data$wtp_data$demand_curve)) {
      charts$demand_curve <- build_demand_curve_chart(
        html_data$wtp_data$demand_curve, brand,
        html_data$wtp_data$currency_symbol %||% "$"
      )
    }
  }

  charts
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message("TURAS>Conjoint HTML Report orchestrator loaded (v3.1.0)")
