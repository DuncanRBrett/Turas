# ==============================================================================
# CONFIDENCE HTML REPORT - MAIN ORCHESTRATOR
# ==============================================================================
# Entry point for confidence HTML report generation.
# Coordinates: guard -> transform -> build tables/charts -> build page -> write
#
# Called from 00_main.R when config Generate_HTML_Report = Y.
# ==============================================================================

# Determine the html_report directory
.confidence_html_report_dir <- if (exists(".confidence_lib_dir", envir = globalenv())) {
  file.path(get(".confidence_lib_dir", envir = globalenv()), "html_report")
} else {
  .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(.ofile) && nzchar(.ofile %||% "")) {
    dirname(.ofile)
  } else {
    "."
  }
}
assign(".confidence_html_report_dir", .confidence_html_report_dir, envir = globalenv())

# Submodule sourcing is deferred to generate_confidence_html_report() below.
# This avoids stop() at source time, which would crash Shiny even when HTML
# reports are not requested.
assign(".chr_submodules_loaded", FALSE, envir = globalenv())

#' Load HTML Report Submodules (Lazy)
#'
#' Sources all required submodule files on first call.
#' Returns a TRS-compliant refusal if any files are missing.
#'
#' @return NULL on success, or a TRS refusal list if files are missing
#' @keywords internal
.chr_load_submodules <- function() {
  if (isTRUE(get0(".chr_submodules_loaded", envir = globalenv()))) return(NULL)

  required_files <- c("00_html_guard.R", "01_data_transformer.R",
                       "02_table_builder.R", "03_page_builder.R",
                       "04_html_writer.R", "05_chart_builder.R")

  report_dir <- get(".confidence_html_report_dir", envir = globalenv())

  missing <- character(0)
  for (f in required_files) {
    if (!file.exists(file.path(report_dir, f))) {
      missing <- c(missing, f)
    }
  }

  js_path <- file.path(report_dir, "js", "confidence_navigation.js")
  if (!file.exists(js_path)) {
    missing <- c(missing, "js/confidence_navigation.js")
  }

  if (length(missing) > 0) {
    cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
    cat("│ Code: IO_HTML_SUBMODULE_MISSING\n")
    cat("│ Missing files:\n")
    for (f in missing) {
      cat("│   -", f, "\n")
    }
    cat("│ Expected in:", report_dir, "\n")
    cat("│ Fix: Restore missing files or check html_report/ directory\n")
    cat("└───────────────────────────────────────────────────────┘\n\n")
    return(list(
      status = "REFUSED",
      code = "IO_HTML_SUBMODULE_MISSING",
      message = sprintf("Confidence HTML report submodule(s) missing: %s",
                         paste(missing, collapse = ", ")),
      how_to_fix = sprintf("Restore missing files in %s", report_dir)
    ))
  }

  for (f in required_files) {
    source(file.path(report_dir, f))
  }

  assign(".chr_submodules_loaded", TRUE, envir = globalenv())
  NULL
}


#' Generate Confidence HTML Report
#'
#' Main entry point for confidence HTML report generation. Validates inputs,
#' transforms data, builds tables and charts, assembles the page, and writes
#' a self-contained HTML file.
#'
#' @param confidence_results List from run_confidence_analysis()
#' @param output_path Character, path for the output .html file
#' @param config List with optional brand_colour, accent_colour, etc.
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{output_file}{Path to generated HTML file (if PASS)}
#'   \item{file_size_mb}{File size in MB (if PASS)}
#' @export
generate_confidence_html_report <- function(confidence_results, output_path,
                                             config = list()) {
  # Load submodules on first call (lazy, avoids stop() at source time)
  load_err <- .chr_load_submodules()
  if (!is.null(load_err)) return(load_err)

  start_time <- Sys.time()

  cat("\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  CONFIDENCE HTML REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================
  cat("  Step 1: Validating inputs...\n")

  guard_result <- validate_confidence_html_inputs(confidence_results, config)
  if (!guard_result$valid) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: DATA_HTML_VALIDATION_FAILED\n")
    for (err in guard_result$errors) cat("  -", err, "\n")
    cat("==================\n\n")
    return(list(
      status = "REFUSED",
      code = "DATA_HTML_VALIDATION_FAILED",
      message = paste("HTML report validation failed:",
                       paste(guard_result$errors, collapse = "; ")),
      how_to_fix = "Check confidence_results contains valid config and at least one result set"
    ))
  }

  # ==========================================================================
  # STEP 2: TRANSFORM DATA
  # ==========================================================================
  cat("  Step 2: Transforming data for HTML...\n")

  html_data <- tryCatch({
    transform_confidence_for_html(confidence_results, config)
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
      message = "Failed to transform confidence results for HTML rendering",
      how_to_fix = "Check that confidence_results contains valid data and study stats"
    ))
  }

  n_questions <- length(html_data$questions)
  cat(sprintf("    %d question(s) to render\n", n_questions))

  # ==========================================================================
  # STEP 3: BUILD TABLES
  # ==========================================================================
  cat("  Step 3: Building HTML tables...\n")

  tables <- list()
  conf_level <- html_data$summary$confidence_level %||% 0.95

  # Summary table (all questions overview)
  tables$summary <- tryCatch(
    build_ci_summary_table(html_data$questions),
    error = function(e) {
      cat(sprintf("    [WARNING] Summary table failed: %s\n", e$message))
      ""
    }
  )

  # Study-level table
  if (!is.null(html_data$study_level)) {
    tables$study_level <- tryCatch(
      build_study_level_table(html_data$study_level),
      error = function(e) {
        cat(sprintf("    [WARNING] Study-level table failed: %s\n", e$message))
        ""
      }
    )
  }

  # Representativeness table
  if (!is.null(html_data$study_level$margin_comparison)) {
    tables$representativeness <- tryCatch(
      build_representativeness_table(html_data$study_level$margin_comparison),
      error = function(e) {
        cat(sprintf("    [WARNING] Representativeness table failed: %s\n", e$message))
        ""
      }
    )
  }

  # Per-question detail tables
  for (q in html_data$questions) {
    q_key <- q$question_id

    detail_table <- tryCatch({
      if (q$type == "proportion") {
        build_proportion_detail_table(q$results, conf_level)
      } else if (q$type == "mean") {
        build_mean_detail_table(q$results, conf_level)
      } else if (q$type == "nps") {
        build_nps_detail_table(q$results, conf_level)
      } else {
        ""
      }
    }, error = function(e) {
      cat(sprintf("    [WARNING] Detail table for %s failed: %s\n", q_key, e$message))
      ""
    })

    tables[[paste0("detail_", q_key)]] <- detail_table
  }

  cat(sprintf("    %d tables built\n", length(tables)))

  # ==========================================================================
  # STEP 4: BUILD CHARTS
  # ==========================================================================
  cat("  Step 4: Building SVG charts...\n")

  charts <- list()
  brand <- config$brand_colour %||% "#1e3a5f"
  if (is.na(brand) || !nzchar(trimws(brand))) brand <- "#1e3a5f"

  # Forest plot (overview of all questions)
  charts$forest_plot <- tryCatch(
    build_ci_forest_plot(html_data$questions, brand),
    error = function(e) {
      cat(sprintf("    [WARNING] Forest plot failed: %s\n", e$message))
      ""
    }
  )

  # Per-question method comparison charts
  for (q in html_data$questions) {
    charts[[paste0("methods_", q$question_id)]] <- tryCatch(
      build_method_comparison_chart(q, brand),
      error = function(e) {
        cat(sprintf("    [WARNING] Method chart for %s failed: %s\n",
                     q$question_id, e$message))
        ""
      }
    )
  }

  cat(sprintf("    %d charts built\n", length(charts)))

  # ==========================================================================
  # STEP 5: ASSEMBLE HTML PAGE
  # ==========================================================================
  cat("  Step 5: Assembling HTML page...\n")

  source_filename <- tools::file_path_sans_ext(basename(output_path))

  page <- tryCatch({
    build_confidence_page(html_data, tables, charts, config,
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
      message = "Failed to assemble confidence HTML page",
      how_to_fix = "Check error messages above for details"
    ))
  }

  # ==========================================================================
  # STEP 6: WRITE HTML FILE
  # ==========================================================================
  cat(sprintf("  Step 6: Writing HTML file to %s...\n", basename(output_path)))

  write_result <- write_confidence_html_report(page, output_path)

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
    message = sprintf("Confidence HTML report generated: %d questions, %.1f KB",
                      n_questions, write_result$file_size_bytes / 1024),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    file_size_bytes = write_result$file_size_bytes,
    n_questions = n_questions,
    elapsed_seconds = elapsed
  )
}
