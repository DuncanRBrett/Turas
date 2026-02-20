# ==============================================================================
# TurasTracker HTML Report - Main Orchestrator
# ==============================================================================
# Entry point for HTML report generation.
# Pipeline: Guard -> Transform -> Build Tables + Charts -> Assemble -> Write
# VERSION: 1.0.0
# ==============================================================================


#' Generate Tracker HTML Report
#'
#' Creates a self-contained HTML report from tracking crosstab data.
#' The HTML report is a static view of the same data computed for Excel.
#'
#' @param crosstab_data List. Output from build_tracking_crosstab()
#' @param config List. Tracker configuration object
#' @param output_path Character. Path for the output HTML file
#' @return List with status and output details
#' @export
generate_tracker_html_report <- function(crosstab_data, config, output_path) {

  cat("\n  Generating Tracker HTML report...\n")

  # ---- Step 1: Guard ----
  cat("    [1/5] Validating inputs...\n")
  guard_result <- validate_tracker_html_inputs(crosstab_data, config)
  if (guard_result$status == "REFUSED") {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", guard_result$code, "\n")
    cat("Message:", guard_result$message, "\n")
    cat("How to fix:", guard_result$how_to_fix, "\n")
    cat("==================\n\n")
    return(guard_result)
  }

  # ---- Step 2: Transform data ----
  cat("    [2/5] Transforming data for HTML...\n")
  html_data <- tryCatch(
    transform_tracker_for_html(crosstab_data, config),
    error = function(e) {
      list(status = "REFUSED", code = "CALC_TRANSFORM_FAILED",
           message = sprintf("Data transformation failed: %s", e$message),
           how_to_fix = "Check crosstab_data structure is valid",
           context = list(error = e$message))
    }
  )
  if (!is.null(html_data$status) && html_data$status == "REFUSED") {
    return(html_data)
  }

  # ---- Step 3: Build tables ----
  cat("    [3/5] Building tables and charts...\n")
  table_html <- tryCatch(
    build_tracking_table(html_data, config),
    error = function(e) {
      cat(sprintf("    [WARN] Table build failed: %s\n", e$message))
      htmltools::HTML("<p>Table generation failed.</p>")
    }
  )

  # Build line charts for each metric
  charts <- lapply(seq_along(html_data$chart_data), function(i) {
    tryCatch(
      build_line_chart(html_data$chart_data[[i]], config),
      error = function(e) {
        cat(sprintf("    [WARN] Chart build failed for metric %d: %s\n", i, e$message))
        NULL
      }
    )
  })

  # ---- Step 4: Assemble page ----
  cat("    [4/5] Assembling page...\n")
  page <- tryCatch(
    build_tracker_page(html_data, table_html, charts, config),
    error = function(e) {
      cat("\n=== TURAS ERROR ===\n")
      cat("Code: CALC_PAGE_BUILD_FAILED\n")
      cat("Message:", e$message, "\n")
      cat("==================\n\n")
      return(list(
        status = "REFUSED",
        code = "CALC_PAGE_BUILD_FAILED",
        message = sprintf("Page assembly failed: %s", e$message),
        how_to_fix = "Check htmltools is installed and data structure is valid",
        context = list(error = e$message)
      ))
    }
  )
  if (is.list(page) && !is.null(page$status) && page$status == "REFUSED") {
    return(page)
  }

  # ---- Step 5: Write file ----
  cat("    [5/5] Writing HTML file...\n")
  write_result <- write_tracker_html_report(page, output_path)

  if (write_result$status == "PASS") {
    cat(sprintf("  Tracker HTML report saved: %s (%.1f MB)\n",
                output_path, write_result$file_size_mb))
  }

  write_result
}
