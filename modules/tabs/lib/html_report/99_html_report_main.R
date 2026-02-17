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

# Source all submodules — fail loudly if any file is missing
.hr_required_files <- c("00_html_guard.R", "01_data_transformer.R",
                         "02_table_builder.R", "03_page_builder.R",
                         "04_html_writer.R",
                         "05_dashboard_transformer.R",
                         "06_dashboard_builder.R",
                         "07_chart_builder.R")

# Also check for required JS files
.hr_required_js <- c("core_navigation.js", "chart_picker.js", "slide_export.js",
                      "pinned_views.js", "table_export_init.js")

.hr_missing <- character(0)
for (.hr_file in .hr_required_files) {
  .hr_path <- file.path(.html_report_dir, .hr_file)
  if (!file.exists(.hr_path)) {
    .hr_missing <- c(.hr_missing, .hr_file)
  }
}
for (.hr_js in .hr_required_js) {
  .hr_path <- file.path(.html_report_dir, "js", .hr_js)
  if (!file.exists(.hr_path)) {
    .hr_missing <- c(.hr_missing, file.path("js", .hr_js))
  }
}

if (length(.hr_missing) > 0) {
  cat("\n┌─── TURAS ERROR ───────────────────────────────────────┐\n")
  cat("│ Code: IO_HTML_SUBMODULE_MISSING\n")
  cat("│ Missing files:\n")
  for (.hr_f in .hr_missing) {
    cat("│   -", .hr_f, "\n")
  }
  cat("│ Expected in:", .html_report_dir, "\n")
  cat("│ Fix: Restore missing files or check html_report/ directory\n")
  cat("└───────────────────────────────────────────────────────┘\n\n")
  stop(sprintf("HTML report submodule(s) missing: %s", paste(.hr_missing, collapse = ", ")),
       call. = FALSE)
}

for (.hr_file in .hr_required_files) {
  .hr_path <- file.path(.html_report_dir, .hr_file)
  source(.hr_path)
}
rm(.hr_file, .hr_path, .hr_required_files, .hr_missing)


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
generate_html_report <- function(all_results, banner_info, config_obj, output_path,
                                  survey_structure = NULL) {

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
  table_failures <- character(0)
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
      table_failures <<- c(table_failures, q_code)
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

  if (length(table_failures) > 0) {
    cat(sprintf("    [WARNING] %d of %d questions failed to render: %s\n",
                length(table_failures),
                length(html_data$questions),
                paste(table_failures, collapse = ", ")))
  }
  cat(sprintf("    %d tables built successfully\n", length(tables)))

  # ============================================================================
  # STEP 3b: BUILD CHARTS (if enabled)
  # ============================================================================
  charts <- list()
  chart_failures <- character(0)
  if (isTRUE(config_obj$show_charts)) {
    cat("  Step 3b: Building SVG charts...\n")
    options_df <- if (!is.null(survey_structure) && !is.null(survey_structure$options)) {
      survey_structure$options
    } else {
      NULL
    }

    if (!is.null(options_df)) {
      for (q_code in names(html_data$questions)) {
        tryCatch({
          chart <- build_question_chart(
            question_data = html_data$questions[[q_code]],
            options_df = options_df,
            config_obj = config_obj
          )
          if (!is.null(chart)) {
            charts[[q_code]] <- chart
          }
        }, error = function(e) {
          chart_failures <<- c(chart_failures, q_code)
          cat(sprintf("    [WARNING] Failed to build chart for %s: %s\n", q_code, e$message))
        })
      }
      if (length(chart_failures) > 0) {
        cat(sprintf("    [WARNING] %d charts failed to render: %s\n",
                    length(chart_failures), paste(chart_failures, collapse = ", ")))
      }
      cat(sprintf("    %d charts built successfully\n", length(charts)))
    } else {
      cat("    [INFO] No survey structure options available — charts skipped\n")
    }
  }

  # ============================================================================
  # STEP 3c: PROCESS LOGOS FOR EMBEDDING
  # ============================================================================

  # Helper: encode a single logo file as a base64 data URI
  embed_logo <- function(logo_path, label) {
    if (is.null(logo_path) || !nzchar(logo_path)) return(NULL)

    logo_file <- logo_path

    # Resolve path: try as-is, then relative to output dir, then working dir
    if (!file.exists(logo_file)) {
      candidates <- c(
        file.path(dirname(output_path), logo_file),
        file.path(dirname(output_path), "..", logo_file),
        file.path(getwd(), logo_file),
        file.path(getwd(), basename(logo_file))
      )
      for (cand in candidates) {
        if (file.exists(cand)) {
          logo_file <- normalizePath(cand)
          cat(sprintf("    %s: resolved to %s\n", label, logo_file))
          break
        }
      }
    }

    if (!file.exists(logo_file)) {
      cat(sprintf("    [WARNING] %s file not found: %s\n", label, logo_path))
      return(NULL)
    }

    ext <- tolower(tools::file_ext(logo_file))
    if (ext == "svg") {
      svg_content <- paste(readLines(logo_file, warn = FALSE), collapse = "\n")
      uri <- paste0("data:image/svg+xml;base64,",
                     base64enc::base64encode(charToRaw(svg_content)))
      cat(sprintf("    %s: embedded SVG (%s)\n", label, basename(logo_file)))
      return(uri)
    } else if (ext %in% c("png", "jpg", "jpeg")) {
      mime <- if (ext == "png") "image/png" else "image/jpeg"
      raw_bytes <- readBin(logo_file, "raw", file.info(logo_file)$size)
      uri <- paste0("data:", mime, ";base64,",
                     base64enc::base64encode(raw_bytes))
      cat(sprintf("    %s: embedded %s (%s, %.1f KB)\n",
                  label, toupper(ext), basename(logo_file),
                  file.info(logo_file)$size / 1024))
      return(uri)
    } else {
      cat(sprintf("    [WARNING] Unsupported %s format: %s (use .svg, .png, or .jpg)\n",
                  label, ext))
      return(NULL)
    }
  }

  # Researcher logo: use researcher_logo_path, fall back to legacy logo_path
  researcher_logo_src <- config_obj$researcher_logo_path %||% config_obj$logo_path
  config_obj$researcher_logo_uri <- embed_logo(researcher_logo_src, "Researcher logo")

  # Client logo: separate config field, no fallback
  config_obj$client_logo_uri <- embed_logo(config_obj$client_logo_path, "Client logo")

  # ============================================================================
  # STEP 4: ASSEMBLE HTML PAGE
  # ============================================================================
  cat("  Step 4: Assembling HTML page...\n")

  page <- tryCatch({
    build_html_page(html_data, tables, config_obj,
                    dashboard_html = dashboard_html, charts = charts)
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

  # Determine final status — PARTIAL if some questions/charts failed
  has_failures <- length(table_failures) > 0 || length(chart_failures) > 0
  final_status <- if (has_failures) "PARTIAL" else "PASS"

  warnings <- character(0)
  if (length(table_failures) > 0) {
    warnings <- c(warnings,
      sprintf("%d question(s) failed to render: %s",
              length(table_failures), paste(table_failures, collapse = ", ")))
  }
  if (length(chart_failures) > 0) {
    warnings <- c(warnings,
      sprintf("%d chart(s) failed to render: %s",
              length(chart_failures), paste(chart_failures, collapse = ", ")))
  }

  if (has_failures) {
    cat(sprintf("  Done with warnings! %.1f MB in %.1f seconds\n",
                write_result$file_size_mb, elapsed))
    for (w in warnings) cat(sprintf("    [!] %s\n", w))
  } else {
    cat(sprintf("  Done! %.1f MB in %.1f seconds\n", write_result$file_size_mb, elapsed))
  }
  cat(paste(rep("-", 60), collapse = ""), "\n\n")

  list(
    status = final_status,
    message = sprintf("HTML report generated: %d questions, %.1f MB",
                      length(tables), write_result$file_size_mb),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    file_size_bytes = write_result$file_size_bytes,
    n_questions = length(tables),
    elapsed_seconds = elapsed,
    warnings = if (length(warnings) > 0) warnings else NULL,
    table_failures = if (length(table_failures) > 0) table_failures else NULL,
    chart_failures = if (length(chart_failures) > 0) chart_failures else NULL
  )
}


