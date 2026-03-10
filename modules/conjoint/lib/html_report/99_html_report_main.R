# ==============================================================================
# CONJOINT HTML REPORT - MAIN ORCHESTRATOR
# ==============================================================================
#
# Module: Conjoint Analysis - HTML Report Generator
# Purpose: Lazy-load orchestrator for 4-layer HTML report generation
# Version: 3.0.0
# Date: 2026-03-10
#
# USAGE:
#   generate_conjoint_html_report(conjoint_results, output_path, config)
#
# ARCHITECTURE:
#   00_html_guard.R        -> Input validation
#   01_data_transformer.R  -> Transform results to chart-ready format
#   02_table_builder.R     -> HTML table construction
#   03_page_builder.R      -> Full HTML page assembly
#   04_html_writer.R       -> Write to disk
#   05_chart_builder.R     -> SVG chart construction
#
# ==============================================================================

# Null coalesce
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Determine report directory
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


#' Generate Conjoint HTML Report
#'
#' Main entry point for HTML report generation. Lazy-loads submodules,
#' validates inputs, transforms data, builds tables/charts/page, and writes.
#'
#' @param conjoint_results List containing:
#'   - utilities: Data frame with Attribute, Level, Utility
#'   - importance: Data frame with Attribute, Importance
#'   - model_result: turas_conjoint_model object
#'   - diagnostics: Diagnostics list
#'   - config: Module configuration
#' @param output_path File path for HTML output
#' @param config Report configuration (brand_colour, accent_colour, project_name)
#' @return TRS status list with output_path
#' @export
generate_conjoint_html_report <- function(conjoint_results, output_path, config = list()) {

  # Step 0: Lazy-load submodules
  load_err <- .chr_load_conjoint_submodules()
  if (!is.null(load_err)) return(load_err)

  cat("\n  [HTML REPORT] Generating conjoint analysis report...\n")

  # Step 1: Guard - validate inputs
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

  # Step 2: Transform data
  html_data <- transform_conjoint_for_html(conjoint_results, config)

  # Step 3: Build tables
  tables <- list(
    importance = build_importance_table(html_data$importance),
    model_fit = build_model_fit_table(html_data$diagnostics, html_data$model_result),
    utility_tables = lapply(html_data$utilities_by_attr, build_utilities_table)
  )

  # HB convergence table
  if (!is.null(html_data$hb_data) && !is.null(html_data$hb_data$convergence)) {
    tables$convergence <- build_convergence_table(html_data$hb_data$convergence)
  }

  # LC comparison table
  if (!is.null(html_data$lc_data)) {
    tables$lc_comparison <- build_lc_comparison_table(
      html_data$lc_data$comparison, html_data$lc_data$optimal_k
    )
  }

  # Step 4: Build charts
  brand <- config$brand_colour %||% "#323367"
  charts <- list(
    importance = build_importance_chart(html_data$importance, brand),
    utility_charts = lapply(names(html_data$utilities_by_attr), function(attr_name) {
      build_utility_chart(html_data$utilities_by_attr[[attr_name]], attr_name, brand)
    })
  )
  names(charts$utility_charts) <- names(html_data$utilities_by_attr)

  # BIC chart for LC
  if (!is.null(html_data$lc_data) && !is.null(html_data$lc_data$comparison)) {
    charts$bic <- build_bic_chart(
      html_data$lc_data$comparison, html_data$lc_data$optimal_k, brand
    )
  }

  # Step 5: Assemble page
  page <- build_conjoint_page(html_data, tables, charts, config)

  # Step 6: Write to disk
  write_result <- write_conjoint_html_report(page, output_path)

  write_result
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message("TURAS>Conjoint HTML Report orchestrator loaded (v3.0.0)")
