# ==============================================================================
# WEIGHTING HTML REPORT - MAIN ORCHESTRATOR
# ==============================================================================
# Entry point for weighting HTML report generation.
# Coordinates: guard -> transform -> build tables/charts -> build page -> write
#
# Called from run_weighting.R when config html_report = Y.
# ==============================================================================

# Determine the html_report directory
.weighting_html_report_dir <- if (exists(".weighting_lib_dir", envir = globalenv())) {
  file.path(get(".weighting_lib_dir", envir = globalenv()), "html_report")
} else {
  .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(.ofile) && nzchar(.ofile %||% "")) {
    dirname(.ofile)
  } else {
    "."
  }
}
assign(".weighting_html_report_dir", .weighting_html_report_dir, envir = globalenv())

# Source all submodules
.whr_required_files <- c("00_html_guard.R", "01_data_transformer.R",
                           "02_table_builder.R", "03_page_builder.R",
                           "04_html_writer.R", "05_chart_builder.R")

.whr_missing <- character(0)
for (.whr_file in .whr_required_files) {
  .whr_path <- file.path(.weighting_html_report_dir, .whr_file)
  if (!file.exists(.whr_path)) {
    .whr_missing <- c(.whr_missing, .whr_file)
  }
}

# Check for JS files
.whr_js_path <- file.path(.weighting_html_report_dir, "js", "weighting_navigation.js")
if (!file.exists(.whr_js_path)) {
  .whr_missing <- c(.whr_missing, "js/weighting_navigation.js")
}

if (length(.whr_missing) > 0) {
  cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
  cat("│ Code: IO_HTML_SUBMODULE_MISSING\n")
  cat("│ Missing files:\n")
  for (.whr_f in .whr_missing) {
    cat("│   -", .whr_f, "\n")
  }
  cat("│ Expected in:", .weighting_html_report_dir, "\n")
  cat("│ Fix: Restore missing files or check html_report/ directory\n")
  cat("└───────────────────────────────────────────────────────┘\n\n")
  stop(sprintf("Weighting HTML report submodule(s) missing: %s",
               paste(.whr_missing, collapse = ", ")), call. = FALSE)
}

for (.whr_file in .whr_required_files) {
  .whr_path <- file.path(.weighting_html_report_dir, .whr_file)
  source(.whr_path)
}
rm(.whr_file, .whr_path, .whr_required_files, .whr_missing, .whr_js_path)


#' Generate Weighting HTML Report
#'
#' Main entry point for weighting HTML report generation. Validates inputs,
#' transforms data, builds tables and charts, assembles the page, and writes
#' a self-contained HTML file.
#'
#' @param weighting_results List from run_weighting()
#' @param output_path Character, path for the output .html file
#' @param config List with optional brand_colour, accent_colour, etc.
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{output_file}{Path to generated HTML file (if PASS)}
#'   \item{file_size_mb}{File size in MB (if PASS)}
#' @export
generate_weighting_html_report <- function(weighting_results, output_path,
                                            config = list()) {
  start_time <- Sys.time()

  cat("\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  WEIGHTING HTML REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================
  cat("  Step 1: Validating inputs...\n")

  guard_result <- validate_html_report_inputs(weighting_results, config)
  if (!guard_result$valid) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: DATA_HTML_VALIDATION_FAILED\n")
    for (err in guard_result$errors) cat("  -", err, "\n")
    cat("==================\n\n")
    return(list(
      status = "REFUSED",
      code = "DATA_HTML_VALIDATION_FAILED",
      message = paste("HTML report validation failed:", paste(guard_result$errors, collapse = "; ")),
      how_to_fix = "Check weighting results contain valid data, weight_names, and weight_results"
    ))
  }

  # ==========================================================================
  # STEP 2: TRANSFORM DATA
  # ==========================================================================
  cat("  Step 2: Transforming data for HTML...\n")

  html_data <- tryCatch({
    transform_for_html(weighting_results, config)
  }, error = function(e) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: DATA_TRANSFORM_FAILED\n")
    cat("Message:", e$message, "\n")
    cat("==================\n\n")
    NULL
  })

  if (is.null(html_data)) {
    return(list(
      status = "REFUSED",
      code = "DATA_TRANSFORM_FAILED",
      message = "Failed to transform weighting results for HTML rendering",
      how_to_fix = "Check that weighting_results contains valid data and diagnostics"
    ))
  }

  cat(sprintf("    %d weights to render\n", length(html_data$weight_details)))

  # ==========================================================================
  # STEP 3: BUILD TABLES
  # ==========================================================================
  cat("  Step 3: Building HTML tables...\n")

  tables <- list()

  # Summary table
  tables$summary_table <- tryCatch(
    build_summary_table(html_data$weight_details),
    error = function(e) {
      cat(sprintf("    [WARNING] Summary table failed: %s\n", e$message))
      ""
    }
  )

  # Per-weight tables
  for (detail in html_data$weight_details) {
    wn <- detail$weight_name

    # Diagnostics
    tables[[paste0("diagnostics_", wn)]] <- tryCatch(
      build_diagnostics_table(detail$diagnostics),
      error = function(e) { cat(sprintf("    [WARNING] Diagnostics table for %s failed: %s\n", wn, e$message)); "" }
    )

    # Rim margins
    if (!is.null(detail$margins)) {
      tables[[paste0("margins_", wn)]] <- tryCatch(
        build_margins_table(detail$margins),
        error = function(e) { cat(sprintf("    [WARNING] Margins table for %s failed: %s\n", wn, e$message)); "" }
      )
    }

    # Design strata
    if (!is.null(detail$stratum_summary)) {
      tables[[paste0("stratum_", wn)]] <- tryCatch(
        build_stratum_table(detail$stratum_summary),
        error = function(e) { cat(sprintf("    [WARNING] Stratum table for %s failed: %s\n", wn, e$message)); "" }
      )
    }

    # Cell details
    if (!is.null(detail$cell_summary)) {
      tables[[paste0("cell_", wn)]] <- tryCatch(
        build_cell_table(detail$cell_summary),
        error = function(e) { cat(sprintf("    [WARNING] Cell table for %s failed: %s\n", wn, e$message)); "" }
      )
    }
  }

  cat(sprintf("    %d tables built\n", length(tables)))

  # ==========================================================================
  # STEP 4: BUILD CHARTS
  # ==========================================================================
  cat("  Step 4: Building SVG charts...\n")

  charts <- list()
  brand <- config$brand_colour %||% "#1e3a5f"

  for (detail in html_data$weight_details) {
    if (!is.null(detail$weights)) {
      hist_data <- tryCatch(
        build_histogram_data(detail$weights),
        error = function(e) NULL
      )
      if (!is.null(hist_data)) {
        charts[[detail$weight_name]] <- tryCatch(
          build_histogram_svg(hist_data, detail$weight_name, brand),
          error = function(e) {
            cat(sprintf("    [WARNING] Chart for %s failed: %s\n", detail$weight_name, e$message))
            ""
          }
        )
      }
    }
  }

  cat(sprintf("    %d charts built\n", length(charts)))

  # ==========================================================================
  # STEP 5: ASSEMBLE HTML PAGE
  # ==========================================================================
  cat("  Step 5: Assembling HTML page...\n")

  source_filename <- tools::file_path_sans_ext(basename(output_path))

  page <- tryCatch({
    build_weighting_page(html_data, tables, charts, config,
                          source_filename = source_filename)
  }, error = function(e) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: CALC_PAGE_BUILD_FAILED\n")
    cat("Message:", e$message, "\n")
    cat("==================\n\n")
    NULL
  })

  if (is.null(page)) {
    return(list(
      status = "REFUSED",
      code = "CALC_PAGE_BUILD_FAILED",
      message = "Failed to assemble HTML page",
      how_to_fix = "Check error messages above for details"
    ))
  }

  # ==========================================================================
  # STEP 6: WRITE HTML FILE
  # ==========================================================================
  cat(sprintf("  Step 6: Writing HTML file to %s...\n", basename(output_path)))

  write_result <- write_weighting_html_report(page, output_path)

  if (write_result$status == "REFUSED") {
    return(write_result)
  }

  # ==========================================================================
  # DONE
  # ==========================================================================
  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)

  cat(sprintf("  Done! %.1f KB in %.1f seconds\n",
              write_result$file_size_bytes / 1024, elapsed))
  cat(paste(rep("-", 60), collapse = ""), "\n\n")

  list(
    status = "PASS",
    message = sprintf("Weighting HTML report generated: %d weights, %.1f KB",
                      length(html_data$weight_details),
                      write_result$file_size_bytes / 1024),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    file_size_bytes = write_result$file_size_bytes,
    n_weights = length(html_data$weight_details),
    elapsed_seconds = elapsed
  )
}
