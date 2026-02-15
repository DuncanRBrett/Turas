# ==============================================================================
# HTML REPORT - MAIN ORCHESTRATOR (V10.3.2)
# ==============================================================================
# Entry point for HTML crosstab report generation.
# Coordinates: guard -> transform -> build tables -> build page -> write file
#
# Uses plain HTML tables — no reactable, no htmlwidgets dependencies.
# Called from run_crosstabs.R when config html_report = TRUE.
# ==============================================================================

# Source submodules (relative to this file's directory)
.html_report_dir <- if (exists(".tabs_lib_dir", envir = globalenv())) {
  file.path(get(".tabs_lib_dir", envir = globalenv()), "html_report")
} else {
  dirname(sys.frame(1)$ofile %||% ".")
}

# Source all submodules
for (.hr_file in c("00_html_guard.R", "01_data_transformer.R",
                    "02_table_builder.R", "03_page_builder.R",
                    "04_html_writer.R",
                    "05_dashboard_transformer.R",
                    "06_dashboard_builder.R")) {
  .hr_path <- file.path(.html_report_dir, .hr_file)
  if (file.exists(.hr_path)) {
    source(.hr_path)
  }
}
rm(.hr_file, .hr_path)


#' Generate HTML Crosstab Report
#'
#' Main entry point for HTML report generation. Validates inputs,
#' transforms data, builds plain HTML tables, assembles the page,
#' and writes a self-contained HTML file.
#'
#' @param all_results List from analysis_runner (keyed by question code)
#' @param banner_info List from create_banner_structure()
#' @param config_obj List, configuration object from build_config_object()
#' @param output_path Character, path for the output .html file
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{output_file}{Path to generated HTML file (if PASS)}
#'   \item{file_size_mb}{File size in MB (if PASS)}
#'   \item{n_questions}{Number of questions rendered (if PASS)}
#' @export
generate_html_report <- function(all_results, banner_info, config_obj, output_path) {

  start_time <- Sys.time()

  cat("\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  HTML REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ============================================================================
  # STEP 1: VALIDATE INPUTS
  # ============================================================================
  cat("  Step 1: Validating inputs...\n")

  guard_result <- validate_html_report_inputs(all_results, banner_info, config_obj)
  if (guard_result$status == "REFUSED") {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", guard_result$code, "\n")
    cat("Message:", guard_result$message, "\n")
    cat("Fix:", guard_result$how_to_fix, "\n")
    cat("==================\n\n")
    return(guard_result)
  }

  # ============================================================================
  # STEP 2: TRANSFORM DATA
  # ============================================================================
  cat("  Step 2: Transforming data for HTML...\n")

  html_data <- tryCatch({
    transform_for_html(all_results, banner_info, config_obj)
  }, error = function(e) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: DATA_TRANSFORM_FAILED\n")
    cat("Message:", e$message, "\n")
    cat("Traceback:\n")
    calls <- sys.calls()
    for (i in seq_along(calls)) {
      call_text <- tryCatch(deparse(calls[[i]], width.cutoff = 80)[1], error = function(x) "???")
      cat(sprintf("  [%d] %s\n", i, call_text))
    }
    cat("==================\n\n")
    NULL
  })

  if (is.null(html_data)) {
    return(list(
      status = "REFUSED",
      code = "DATA_TRANSFORM_FAILED",
      message = "Failed to transform analysis results for HTML rendering",
      how_to_fix = "Check that all_results contains valid question data with table and bases"
    ))
  }

  if (html_data$n_questions == 0) {
    return(list(
      status = "REFUSED",
      code = "DATA_EMPTY",
      message = "No questions were successfully transformed for HTML rendering",
      how_to_fix = "Ensure at least one question has valid analysis results"
    ))
  }

  cat(sprintf("    %d questions, %d banner groups\n",
              html_data$n_questions, length(html_data$banner_groups)))

  # ============================================================================
  # STEP 2b: BUILD SUMMARY DASHBOARD (if enabled)
  # ============================================================================
  dashboard_html <- NULL

  if (isTRUE(config_obj$include_summary %||% TRUE)) {
    cat("  Step 2b: Building summary dashboard...\n")

    dashboard_data <- tryCatch({
      transform_for_dashboard(all_results, banner_info, config_obj)
    }, error = function(e) {
      cat(sprintf("    [WARNING] Dashboard transform failed: %s\n", e$message))
      cat("    Continuing without summary dashboard.\n")
      NULL
    })

    if (!is.null(dashboard_data) && !is.null(dashboard_data$status) &&
        dashboard_data$status == "PASS") {
      dashboard_html <- tryCatch({
        build_dashboard_panel(dashboard_data, config_obj)
      }, error = function(e) {
        cat(sprintf("    [WARNING] Dashboard build failed: %s\n", e$message))
        cat("    Continuing without summary dashboard.\n")
        NULL
      })

      if (!is.null(dashboard_html)) {
        n_metrics <- length(dashboard_data$headline_metrics)
        n_sig <- length(dashboard_data$sig_findings)
        cat(sprintf("    Dashboard: %d headline metrics, %d sig findings\n",
                    n_metrics, n_sig))
      }
    } else if (!is.null(dashboard_data) && dashboard_data$status == "REFUSED") {
      cat(sprintf("    Dashboard skipped: %s\n", dashboard_data$message %||% ""))
    }
  } else {
    cat("  Step 2b: Summary dashboard disabled (include_summary = FALSE)\n")
  }

  # ============================================================================
  # STEP 3: BUILD HTML TABLES
  # ============================================================================
  cat("  Step 3: Building HTML tables...\n")

  tables <- list()
  for (q_code in names(html_data$questions)) {
    q_data <- html_data$questions[[q_code]]

    tryCatch({
      table_id <- paste0("table-", gsub("[^a-zA-Z0-9]", "-", q_code))
      tables[[q_code]] <- build_question_table(
        question_data = q_data,
        banner_groups = html_data$banner_groups,
        config_obj = config_obj,
        table_id = table_id
      )
    }, error = function(e) {
      cat(sprintf("    [WARNING] Failed to build table for %s: %s\n", q_code, e$message))
    })
  }

  if (length(tables) == 0) {
    return(list(
      status = "REFUSED",
      code = "CALC_TABLE_BUILD_FAILED",
      message = "Failed to build any HTML tables",
      how_to_fix = "Check that question data is valid and htmltools package is installed"
    ))
  }

  cat(sprintf("    %d tables built successfully\n", length(tables)))

  # ============================================================================
  # STEP 4: ASSEMBLE HTML PAGE
  # ============================================================================
  cat("  Step 4: Assembling HTML page...\n")

  page <- tryCatch({
    build_html_page(html_data, tables, config_obj, dashboard_html = dashboard_html)
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

  # ============================================================================
  # STEP 5: WRITE HTML FILE
  # ============================================================================
  cat(sprintf("  Step 5: Writing HTML file to %s...\n", basename(output_path)))

  write_result <- write_html_report(page, output_path)

  if (write_result$status == "REFUSED") {
    return(write_result)
  }

  # ============================================================================
  # DONE
  # ============================================================================
  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)

  cat(sprintf("  Done! %.1f MB in %.1f seconds\n", write_result$file_size_mb, elapsed))
  cat(paste(rep("-", 60), collapse = ""), "\n\n")

  list(
    status = "PASS",
    message = sprintf("HTML report generated: %d questions, %.1f MB",
                      length(tables), write_result$file_size_mb),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    file_size_bytes = write_result$file_size_bytes,
    n_questions = length(tables),
    elapsed_seconds = elapsed
  )
}


# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
