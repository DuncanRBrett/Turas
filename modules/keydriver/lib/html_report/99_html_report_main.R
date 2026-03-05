# ==============================================================================
# KEYDRIVER HTML REPORT - MAIN ORCHESTRATOR
# ==============================================================================
# Entry point for HTML report generation.
# Coordinates: guard -> transform -> build tables -> build charts ->
#              assemble page -> write file
#
# Called from 00_main.R when html_report config is TRUE.
# ==============================================================================

# Null-coalescing operator
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Determine the html_report directory
.kd_html_report_dir <- if (exists(".keydriver_lib_dir", envir = globalenv())) {
  file.path(get(".keydriver_lib_dir", envir = globalenv()), "html_report")
} else {
  .ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (is.null(.ofile) || !nzchar(.ofile %||% "")) {
    "."
  } else {
    dirname(.ofile)
  }
}

# Source submodules
.kd_required_files <- c("00_html_guard.R", "01_data_transformer.R",
                         "02_table_builder.R", "03_page_builder.R",
                         "04_html_writer.R", "05_chart_builder.R",
                         "06_quadrant_section.R")

.kd_missing <- character(0)
for (.kd_file in .kd_required_files) {
  .kd_path <- file.path(.kd_html_report_dir, .kd_file)
  if (!file.exists(.kd_path)) {
    .kd_missing <- c(.kd_missing, .kd_file)
  }
}

# Check JS files
.kd_required_js <- c("kd_navigation.js", "kd_utils.js",
                      "kd_pinned_views.js", "kd_slide_export.js")
for (.kd_js in .kd_required_js) {
  if (!file.exists(file.path(.kd_html_report_dir, "js", .kd_js))) {
    .kd_missing <- c(.kd_missing, paste0("js/", .kd_js))
  }
}

if (length(.kd_missing) > 0) {
  cat("\n\u250C\u2500\u2500\u2500 TURAS ERROR \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510\n")
  cat("\u2502 Code: IO_KD_HTML_SUBMODULE_MISSING\n")
  cat("\u2502 Missing files:\n")
  for (.kd_f in .kd_missing) {
    cat("\u2502   -", .kd_f, "\n")
  }
  cat("\u2502 Expected in:", .kd_html_report_dir, "\n")
  cat("\u2502 Fix: Restore missing files or check lib/html_report/ directory\n")
  cat("\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518\n\n")
  cat(sprintf("   [WARN] Keydriver HTML report submodule(s) missing: %s\n",
              paste(.kd_missing, collapse = ", ")))
} else {
  for (.kd_file in .kd_required_files) {
    source(file.path(.kd_html_report_dir, .kd_file))
  }
}

rm(.kd_file, .kd_path, .kd_required_files)
if (exists(".kd_missing")) rm(.kd_missing)


#' Generate Keydriver HTML Report
#'
#' Main entry point for HTML report generation. Validates inputs,
#' transforms data, builds tables and charts, assembles the page,
#' and writes a self-contained HTML file.
#'
#' @param results Analysis results from run_keydriver_analysis()
#' @param config Configuration list
#' @param output_path Character, path for the output .html file
#' @return List with status, output_file, file_size_mb, elapsed_seconds
#' @export
generate_keydriver_html_report <- function(results, config, output_path) {

  start_time <- Sys.time()

  cat("\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  KEYDRIVER HTML REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================
  cat("  Step 1: Validating inputs...\n")

  guard_result <- validate_keydriver_html_inputs(results, config, output_path)
  if (guard_result$status == "REFUSED") {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code:", guard_result$code, "\n")
    cat("Message:", guard_result$message, "\n")
    cat("Fix:", guard_result$how_to_fix, "\n")
    cat("==================\n\n")
    return(guard_result)
  }

  # ==========================================================================
  # STEP 2: TRANSFORM DATA
  # ==========================================================================
  cat("  Step 2: Transforming data for HTML...\n")

  html_data <- tryCatch({
    transform_keydriver_for_html(results, config)
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
      message = "Failed to transform keydriver results for HTML rendering",
      how_to_fix = "Check that results contain valid analysis data"
    ))
  }

  cat(sprintf("    %d drivers, %d importance methods\n",
              html_data$n_drivers, length(html_data$methods_available)))

  # ==========================================================================
  # STEP 3: BUILD TABLES
  # ==========================================================================
  cat("  Step 3: Building HTML tables...\n")

  tables <- list()
  warnings <- character(0)

  # Importance table
  tables$importance <- tryCatch(
    build_kd_importance_table(html_data$importance),
    error = function(e) {
      warnings <<- c(warnings, sprintf("Importance table failed: %s", e$message))
      NULL
    }
  )

  # Method comparison table
  tables$method_comparison <- tryCatch(
    build_kd_method_comparison_table(html_data$method_comparison),
    error = function(e) {
      warnings <<- c(warnings, sprintf("Method comparison table failed: %s", e$message))
      NULL
    }
  )

  # Model summary table
  tables$model_summary <- tryCatch(
    build_kd_model_summary_table(html_data$model_info),
    error = function(e) {
      warnings <<- c(warnings, sprintf("Model summary table failed: %s", e$message))
      NULL
    }
  )

  # Correlation matrix table
  tables$correlations <- tryCatch(
    build_kd_correlation_table(html_data$correlations),
    error = function(e) {
      warnings <<- c(warnings, sprintf("Correlation table failed: %s", e$message))
      NULL
    }
  )

  # VIF diagnostics table
  tables$vif <- tryCatch(
    build_kd_vif_table(html_data$vif_values),
    error = function(e) {
      warnings <<- c(warnings, sprintf("VIF table failed: %s", e$message))
      NULL
    }
  )

  # Effect size table
  if (!is.null(html_data$effect_sizes)) {
    tables$effect_sizes <- tryCatch(
      build_kd_effect_size_table(html_data$effect_sizes),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Effect size table failed: %s", e$message))
        NULL
      }
    )
  }

  # Quadrant action table
  if (!is.null(html_data$quadrant_data)) {
    tables$quadrant_actions <- tryCatch(
      build_kd_quadrant_action_table(html_data$quadrant_data),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Quadrant action table failed: %s", e$message))
        NULL
      }
    )
  }

  # Bootstrap CI table
  if (!is.null(html_data$bootstrap_ci)) {
    tables$bootstrap_ci <- tryCatch(
      build_kd_bootstrap_ci_table(html_data$bootstrap_ci),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Bootstrap CI table failed: %s", e$message))
        NULL
      }
    )
  }

  # Segment comparison table
  if (!is.null(html_data$segment_comparison)) {
    tables$segment_comparison <- tryCatch(
      build_kd_segment_comparison_table(html_data$segment_comparison),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Segment comparison table failed: %s", e$message))
        NULL
      }
    )
  }

  # Check we have at least importance table
  if (is.null(tables$importance)) {
    return(list(
      status = "REFUSED",
      code = "CALC_TABLE_BUILD_FAILED",
      message = "Failed to build critical HTML tables",
      how_to_fix = "Check that results data is valid and htmltools is installed"
    ))
  }

  n_tables <- sum(!vapply(tables, is.null, logical(1)))
  cat(sprintf("    Built %d tables\n", n_tables))

  # ==========================================================================
  # STEP 4: BUILD CHARTS
  # ==========================================================================
  cat("  Step 4: Building SVG charts...\n")

  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#f59e0b"

  charts <- list()

  charts$importance <- tryCatch(
    build_kd_importance_chart(html_data$importance, brand_colour),
    error = function(e) {
      cat(sprintf("    [WARN] Importance chart failed: %s\n", e$message))
      NULL
    }
  )

  charts$method_agreement <- tryCatch(
    build_kd_method_agreement_chart(html_data$method_comparison, brand_colour, accent_colour),
    error = function(e) {
      cat(sprintf("    [WARN] Method agreement chart failed: %s\n", e$message))
      NULL
    }
  )

  charts$correlation_heatmap <- tryCatch(
    build_kd_correlation_heatmap(html_data$correlations, brand_colour),
    error = function(e) {
      cat(sprintf("    [WARN] Correlation heatmap failed: %s\n", e$message))
      NULL
    }
  )

  if (!is.null(html_data$effect_sizes)) {
    charts$effect_sizes <- tryCatch(
      build_kd_effect_size_chart(html_data$effect_sizes, brand_colour, accent_colour),
      error = function(e) {
        cat(sprintf("    [WARN] Effect size chart failed: %s\n", e$message))
        NULL
      }
    )
  }

  if (!is.null(html_data$bootstrap_ci)) {
    charts$bootstrap_ci <- tryCatch(
      build_kd_bootstrap_ci_chart(html_data$bootstrap_ci, brand_colour, accent_colour),
      error = function(e) {
        cat(sprintf("    [WARN] Bootstrap CI chart failed: %s\n", e$message))
        NULL
      }
    )
  }

  if (!is.null(html_data$quadrant_data)) {
    charts$quadrant <- tryCatch(
      build_kd_quadrant_chart(html_data$quadrant_data, config),
      error = function(e) {
        cat(sprintf("    [WARN] Quadrant chart failed: %s\n", e$message))
        NULL
      }
    )
  }

  # SHAP importance chart
  if (!is.null(html_data$shap_importance)) {
    charts$shap_importance <- tryCatch(
      build_kd_shap_importance_chart(html_data$shap_importance, brand_colour),
      error = function(e) {
        cat(sprintf("    [WARN] SHAP importance chart failed: %s\n", e$message))
        NULL
      }
    )
  }

  # Segment comparison chart
  if (!is.null(html_data$segment_comparison)) {
    charts$segment_comparison <- tryCatch(
      build_kd_segment_comparison_chart(html_data$segment_comparison,
                                         brand_colour, accent_colour),
      error = function(e) {
        cat(sprintf("    [WARN] Segment comparison chart failed: %s\n", e$message))
        NULL
      }
    )
  }

  n_charts <- sum(!vapply(charts, is.null, logical(1)))
  cat(sprintf("    %d charts built\n", n_charts))

  # ==========================================================================
  # STEP 5: ASSEMBLE HTML PAGE
  # ==========================================================================
  cat("  Step 5: Assembling HTML page...\n")

  page <- tryCatch({
    build_kd_html_page(html_data, tables, charts, config)
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
      message = "Failed to assemble keydriver HTML page",
      how_to_fix = "Check error messages above for details"
    ))
  }

  # ==========================================================================
  # STEP 6: WRITE HTML FILE
  # ==========================================================================
  cat(sprintf("  Step 6: Writing HTML file to %s...\n", basename(output_path)))

  write_result <- write_kd_html_report(page, output_path)

  if (write_result$status == "REFUSED") {
    return(write_result)
  }

  # ==========================================================================
  # DONE
  # ==========================================================================
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
    message = sprintf("Keydriver HTML report generated: %d drivers, %.2f MB",
                      html_data$n_drivers, write_result$file_size_mb),
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    file_size_bytes = write_result$file_size_bytes,
    n_drivers = html_data$n_drivers,
    elapsed_seconds = elapsed,
    warnings = if (length(warnings) > 0) warnings else NULL
  )
}
