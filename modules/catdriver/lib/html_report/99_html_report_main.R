# ==============================================================================
# CATDRIVER HTML REPORT - MAIN ORCHESTRATOR
# ==============================================================================
# Entry point for HTML report generation.
# Coordinates: guard -> transform -> build tables -> build charts ->
#              assemble page -> write file
#
# Called from 00_main.R when html_report config is TRUE.
# ==============================================================================

# Determine the html_report directory
.cd_html_report_dir <- if (exists(".catdriver_lib_dir", envir = globalenv())) {
  file.path(get(".catdriver_lib_dir", envir = globalenv()), "html_report")
} else {
  .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(.ofile) || !nzchar(.ofile %||% "")) {
    # Fallback: try relative to this file's known location
    "."
  } else {
    dirname(.ofile)
  }
}

# Source submodules
.cd_required_files <- c("00_html_guard.R", "01_data_transformer.R",
                         "02_table_builder.R", "03_page_builder.R",
                         "04_html_writer.R", "05_chart_builder.R",
                         "06_comparison_report.R", "07_unified_report.R",
                         "08_subgroup_report.R")

.cd_missing <- character(0)
for (.cd_file in .cd_required_files) {
  .cd_path <- file.path(.cd_html_report_dir, .cd_file)
  if (!file.exists(.cd_path)) {
    .cd_missing <- c(.cd_missing, .cd_file)
  }
}

# Check JS files
.cd_required_js <- c("cd_navigation.js", "cd_unified_tabs.js", "cd_utils.js",
                      "cd_insights.js", "cd_pinned_views.js", "cd_slide_export.js",
                      "cd_qualitative.js")
for (.cd_js in .cd_required_js) {
  if (!file.exists(file.path(.cd_html_report_dir, "js", .cd_js))) {
    .cd_missing <- c(.cd_missing, paste0("js/", .cd_js))
  }
}

if (length(.cd_missing) > 0) {
  cat("\n\u250C\u2500\u2500\u2500 TURAS ERROR \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n")
  cat("\u2502 Code: IO_CD_HTML_SUBMODULE_MISSING\n")
  cat("\u2502 Missing files:\n")
  for (.cd_f in .cd_missing) {
    cat("\u2502   -", .cd_f, "\n")
  }
  cat("\u2502 Expected in:", .cd_html_report_dir, "\n")
  cat("\u2502 Fix: Restore missing files or check lib/html_report/ directory\n")
  cat("\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n\n")
  warning(sprintf("Catdriver HTML report submodule(s) missing: %s",
                   paste(.cd_missing, collapse = ", ")), call. = FALSE)
} else {
  for (.cd_file in .cd_required_files) {
    source(file.path(.cd_html_report_dir, .cd_file))
  }
}

rm(.cd_file, .cd_path, .cd_required_files)
if (exists(".cd_missing")) rm(.cd_missing)


#' Generate Catdriver HTML Report
#'
#' Main entry point for HTML report generation. Validates inputs,
#' transforms data, builds tables and charts, assembles the page,
#' and writes a self-contained HTML file.
#'
#' @param results Analysis results from run_categorical_keydriver()
#' @param config Configuration list
#' @param output_path Character, path for the output .html file
#' @return List with status, output_file, file_size_mb, elapsed_seconds
#' @export
generate_catdriver_html_report <- function(results, config, output_path) {

  start_time <- Sys.time()

  cat("\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  CATDRIVER HTML REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ============================================================================
  # STEP 1: VALIDATE INPUTS
  # ============================================================================
  cat("  Step 1: Validating inputs...\n")

  guard_result <- validate_catdriver_html_inputs(results, config, output_path)
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
    transform_catdriver_for_html(results, config)
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
      message = "Failed to transform catdriver results for HTML rendering",
      how_to_fix = "Check that results contain valid analysis data"
    ))
  }

  cat(sprintf("    %d drivers, %d odds ratios\n",
              length(html_data$importance), length(html_data$odds_ratios)))

  # ============================================================================
  # STEP 3: BUILD TABLES
  # ============================================================================
  cat("  Step 3: Building HTML tables...\n")

  tables <- list()
  warnings <- character(0)

  # Importance table
  tables$importance <- tryCatch(
    build_cd_importance_table(html_data$importance),
    error = function(e) {
      warnings <<- c(warnings, sprintf("Importance table failed: %s", e$message))
      NULL
    }
  )

  # Pattern tables (one per driver)
  tables$patterns <- list()
  for (var_name in names(html_data$patterns)) {
    tables$patterns[[var_name]] <- tryCatch(
      build_cd_pattern_table(html_data$patterns[[var_name]], var_name),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Pattern table for %s failed: %s", var_name, e$message))
        NULL
      }
    )
  }

  # Odds ratio table
  tables$odds_ratios <- tryCatch(
    build_cd_odds_ratio_table(html_data$odds_ratios, html_data$has_bootstrap),
    error = function(e) {
      warnings <<- c(warnings, sprintf("Odds ratio table failed: %s", e$message))
      NULL
    }
  )

  # Probability lift tables (one per driver, conditional)
  tables$probability_lifts <- list()
  if (!is.null(html_data$probability_lifts)) {
    for (var_name in names(html_data$probability_lifts)) {
      tables$probability_lifts[[var_name]] <- tryCatch(
        build_cd_probability_lift_table(html_data$probability_lifts[[var_name]], var_name),
        error = function(e) {
          warnings <<- c(warnings, sprintf("Probability lift table for %s failed: %s", var_name, e$message))
          NULL
        }
      )
    }
  }

  # Diagnostics table
  tables$diagnostics <- tryCatch(
    build_cd_diagnostics_table(html_data$diagnostics, html_data$model_info, config),
    error = function(e) {
      warnings <<- c(warnings, sprintf("Diagnostics table failed: %s", e$message))
      NULL
    }
  )

  # Check we have at least importance and OR tables
  if (is.null(tables$importance) && is.null(tables$odds_ratios)) {
    return(list(
      status = "REFUSED",
      code = "CALC_TABLE_BUILD_FAILED",
      message = "Failed to build critical HTML tables",
      how_to_fix = "Check that results data is valid and htmltools is installed"
    ))
  }

  cat(sprintf("    Built: importance=%s, patterns=%d, OR=%s, diagnostics=%s\n",
              if (!is.null(tables$importance)) "OK" else "FAIL",
              sum(!vapply(tables$patterns, is.null, logical(1))),
              if (!is.null(tables$odds_ratios)) "OK" else "FAIL",
              if (!is.null(tables$diagnostics)) "OK" else "FAIL"))

  # ============================================================================
  # STEP 4: BUILD CHARTS
  # ============================================================================
  cat("  Step 4: Building SVG charts...\n")

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"

  charts <- list()

  charts$importance <- tryCatch(
    build_cd_importance_chart(html_data$importance, brand_colour),
    error = function(e) {
      cat(sprintf("    [WARNING] Importance chart failed: %s\n", e$message))
      NULL
    }
  )

  charts$forest <- tryCatch(
    build_cd_forest_plot(html_data$odds_ratios, brand_colour, accent_colour),
    error = function(e) {
      cat(sprintf("    [WARNING] Forest plot failed: %s\n", e$message))
      NULL
    }
  )

  charts$probability_lift <- tryCatch(
    build_cd_probability_lift_chart(html_data$probability_lifts, brand_colour, accent_colour),
    error = function(e) {
      cat(sprintf("    [WARNING] Probability lift chart failed: %s\n", e$message))
      NULL
    }
  )

  n_charts <- sum(!vapply(charts, is.null, logical(1)))
  cat(sprintf("    %d charts built\n", n_charts))

  # ============================================================================
  # STEP 5: ASSEMBLE HTML PAGE
  # ============================================================================
  cat("  Step 5: Assembling HTML page...\n")

  page <- tryCatch({
    build_cd_html_page(html_data, tables, charts, config,
                       subgroup_comparison = results$subgroup_comparison)
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
      message = "Failed to assemble catdriver HTML page",
      how_to_fix = "Check error messages above for details"
    ))
  }

  # ============================================================================
  # STEP 6: WRITE HTML FILE
  # ============================================================================
  cat(sprintf("  Step 6: Writing HTML file to %s...\n", basename(output_path)))

  write_result <- write_cd_html_report(page, output_path)

  if (write_result$status == "REFUSED") {
    return(write_result)
  }

  # ============================================================================
  # DONE
  # ============================================================================
  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)

  final_status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  if (length(warnings) > 0) {
    cat(sprintf("  Done with warnings! %.2f MB in %.1f seconds\n",
                write_result$file_size_mb, elapsed))
    for (w in warnings) cat(sprintf("    [!] %s\n", w))
  } else {
    cat(sprintf("  Done! %.2f MB in %.1f seconds\n", write_result$file_size_mb, elapsed))
  }
  cat(paste(rep("-", 60), collapse = ""), "\n\n")

  list(
    status = final_status,
    message = sprintf("Catdriver HTML report generated: %d drivers, %.2f MB",
                      length(html_data$importance), write_result$file_size_mb),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    file_size_bytes = write_result$file_size_bytes,
    n_drivers = length(html_data$importance),
    elapsed_seconds = elapsed,
    warnings = if (length(warnings) > 0) warnings else NULL
  )
}
