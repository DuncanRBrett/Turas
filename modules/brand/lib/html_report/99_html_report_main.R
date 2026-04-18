# ==============================================================================
# BRAND HTML REPORT - ORCHESTRATOR
# ==============================================================================
# Generates a complete, self-contained interactive HTML report using
# the 4-layer pipeline:
#   Layer 1: 01_data_transformer.R  — transform results to chart/table data
#   Layer 2: 02_table_builder.R     — build styled HTML tables
#   Layer 3: 04_chart_builder.R     — build inline SVG charts
#   Layer 4: 03_page_builder.R      — assemble full HTML page
#
# VERSION: 2.0
# ==============================================================================

BRAND_HTML_VERSION <- "2.0"

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# Capture this file's directory at source time (reliable path anchor for JS/CSS assets)
.BRAND_HTML_REPORT_DIR <- tryCatch({
  f <- sys.frame(length(sys.frames()))$ofile
  if (!is.null(f) && nchar(f) > 0) dirname(normalizePath(f)) else NULL
}, error = function(e) NULL)


#' Generate interactive brand HTML report
#'
#' Creates a complete, self-contained HTML page with tabbed navigation,
#' SVG charts, styled tables, TurasPins integration, and insight editors.
#'
#' @param results List. Output from \code{run_brand()}.
#' @param output_path Character. Path for the HTML file.
#' @param config List. Brand config (uses results$config if NULL).
#'
#' @return List with status and output_path.
#'
#' @export
generate_brand_html_report <- function(results, output_path, config = NULL) {

  if (is.null(results) || identical(results$status, "REFUSED")) {
    return(list(status = "REFUSED", message = "No results to render"))
  }

  if (is.null(config)) config <- results$config %||% list()

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # --- Source sub-modules ---
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (!nzchar(turas_root) && exists("find_turas_root", mode = "function")) {
    turas_root <- find_turas_root()
  }
  if (!nzchar(turas_root)) turas_root <- getwd()

  report_dir <- file.path(turas_root, "modules", "brand", "lib", "html_report")
  if (!dir.exists(report_dir)) {
    report_dir <- tryCatch({
      # Try relative to this file
      d <- dirname(sys.frame(1)$ofile)
      if (dir.exists(d)) d else "modules/brand/lib/html_report"
    }, error = function(e) "modules/brand/lib/html_report")
  }

  for (layer_file in c("04_chart_builder.R", "02_table_builder.R",
                        "01_data_transformer.R", "03_page_builder.R")) {
    fp <- file.path(report_dir, layer_file)
    if (file.exists(fp)) source(fp, local = FALSE)
  }

  # --- Source dedicated panel renderers (role-registry architecture) ---
  panels_dir <- file.path(report_dir, "panels")
  if (dir.exists(panels_dir)) {
    for (f in sort(list.files(panels_dir, pattern = "\\.R$",
                              full.names = TRUE))) {
      tryCatch(source(f, local = FALSE), error = function(e) NULL)
    }
  }

  # --- Load JS modules ---
  js_dir <- file.path(report_dir, "js")
  brand_js <- ""
  for (js_file in c("brand_report.js", "brand_pins.js")) {
    fp <- file.path(js_dir, js_file)
    if (file.exists(fp)) {
      brand_js <- paste(brand_js, paste(readLines(fp, warn = FALSE), collapse = "\n"), sep = "\n")
    }
  }

  # Load shared TurasPins JS
  pins_js <- ""
  if (exists("turas_pins_js", mode = "function")) {
    pins_js <- tryCatch(turas_pins_js(include_vendor = TRUE), error = function(e) "")
  }

  # --- Layer 1: Transform data ---
  charts <- tryCatch(
    transform_brand_charts(results, config),
    error = function(e) {
      message(sprintf("[BRAND HTML] Chart transform failed: %s", e$message))
      list()
    }
  )

  # --- Layer 2: Build tables ---
  tables <- tryCatch(
    transform_brand_tables(results, config),
    error = function(e) {
      message(sprintf("[BRAND HTML] Table transform failed: %s", e$message))
      list()
    }
  )

  # --- Layer 2b: Dedicated role-registry panels (funnel in v1) ---
  panels <- tryCatch(
    transform_brand_panels(results, config),
    error = function(e) {
      message(sprintf("[BRAND HTML] Panel transform failed: %s", e$message))
      list()
    }
  )

  # Load panel styles + JS (funnel panel only for now)
  panel_styles <- if (exists("build_funnel_panel_styles", mode = "function")) {
    tryCatch(build_funnel_panel_styles(config$colour_focal %||% "#1A5276"),
             error = function(e) "")
  } else ""
  panel_js <- ""
  # Resolve JS path: prefer source-time anchor, fall back to working dir and TURAS_ROOT
  .js_candidates <- c(
    if (!is.null(.BRAND_HTML_REPORT_DIR))
      file.path(.BRAND_HTML_REPORT_DIR, "js", "brand_funnel_panel.js"),
    file.path(getwd(), "modules", "brand", "lib", "html_report",
              "js", "brand_funnel_panel.js"),
    tryCatch(file.path(find_turas_root(), "modules", "brand", "lib",
                       "html_report", "js", "brand_funnel_panel.js"),
             error = function(e) NULL)
  )
  .js_found <- Filter(function(p) !is.null(p) && file.exists(p), .js_candidates)
  if (length(.js_found) > 0) {
    panel_js <- paste(readLines(.js_found[[1]], warn = FALSE), collapse = "\n")
  }

  # --- Layers 3+4: Assemble page ---
  html <- tryCatch(
    build_brand_page(results, charts, tables, config, brand_js, pins_js,
                     panels = panels, panel_styles = panel_styles,
                     panel_js = panel_js),
    error = function(e) {
      message(sprintf("[BRAND HTML] Page assembly failed: %s", e$message))
      # Fallback: minimal page
      sprintf("<!DOCTYPE html><html><body><h1>Report generation failed</h1><p>%s</p></body></html>",
              e$message)
    }
  )

  # --- Write file ---
  writeLines(html, output_path, useBytes = TRUE)

  file_size <- file.size(output_path)
  cat(sprintf("  Brand HTML report generated: %s (%.1f KB)\n",
              output_path, file_size / 1024))

  list(
    status = "PASS",
    output_path = output_path,
    file_size_bytes = file_size,
    message = sprintf("HTML report generated at %s", output_path)
  )
}
