# ==============================================================================
# MAXDIFF HTML REPORT - MAIN ORCHESTRATOR - TURAS V11.0
# ==============================================================================
# Entry point for MaxDiff HTML report generation
# Sources the 4-layer pipeline and pipes data through to produce a
# self-contained HTML report file.
# ==============================================================================

MAXDIFF_HTML_REPORT_VERSION <- "11.1"

# Flag to prevent re-sourcing
.md_html_loaded <- FALSE

#' Source HTML report sub-modules
#'
#' @keywords internal
.md_load_report_submodules <- function() {

  if (.md_html_loaded) return(invisible(NULL))

  # Find html_report directory
  report_dir <- NULL

  # Method 1: Relative to this file
  for (i in seq_len(sys.nframe())) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(ofile) && is.character(ofile) && length(ofile) == 1) {
      candidate <- dirname(normalizePath(ofile, mustWork = FALSE))
      if (file.exists(file.path(candidate, "01_data_transformer.R"))) {
        report_dir <- candidate
        break
      }
    }
  }

  # Method 2: Common paths
  if (is.null(report_dir)) {
    candidates <- c(
      file.path(getwd(), "modules", "maxdiff", "lib", "html_report"),
      file.path(getwd(), "lib", "html_report")
    )
    if (exists("script_dir_override", envir = globalenv())) {
      sd <- get("script_dir_override", envir = globalenv())
      candidates <- c(
        file.path(sd, "..", "lib", "html_report"),
        file.path(dirname(sd), "lib", "html_report"),
        candidates
      )
    }
    for (c in candidates) {
      c <- normalizePath(c, mustWork = FALSE)
      if (file.exists(file.path(c, "01_data_transformer.R"))) {
        report_dir <- c
        break
      }
    }
  }

  if (is.null(report_dir)) {
    message("[TRS INFO] MAXD_HTML_DIR_NOT_FOUND: Could not locate html_report directory")
    return(invisible(NULL))
  }

  files <- c(
    "01_data_transformer.R",
    "02_table_builder.R",
    "04_chart_builder.R",
    "03_page_builder.R"
  )

  for (f in files) {
    fpath <- file.path(report_dir, f)
    if (file.exists(fpath)) {
      source(fpath, local = FALSE)
    } else {
      message(sprintf("[TRS INFO] MAXD_HTML_FILE_MISSING: %s not found", f))
    }
  }

  .md_html_loaded <<- TRUE
  invisible(NULL)
}


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Generate MaxDiff HTML Report
#'
#' Produces a self-contained HTML report from MaxDiff analysis results.
#'
#' @param maxdiff_results List. Full results from run_maxdiff() analysis mode.
#'   Must contain count_scores, logit_results, and/or hb_results.
#' @param output_path Character. Path for the output HTML file.
#' @param config List. Module configuration (from load_maxdiff_config).
#'
#' @return List with status, output_file, file_size_bytes
#'
#' @export
generate_maxdiff_html_report <- function(maxdiff_results, output_path, config) {

  # Source sub-modules
  .md_load_report_submodules()

  # Validate inputs
  if (is.null(maxdiff_results)) {
    message("[TRS INFO] MAXD_HTML_NO_RESULTS: No results provided for HTML report")
    return(list(status = "REFUSED", message = "No results provided"))
  }

  if (is.null(output_path) || !nzchar(output_path)) {
    message("[TRS INFO] MAXD_HTML_NO_PATH: No output path specified")
    return(list(status = "REFUSED", message = "No output path"))
  }

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # --- Layer 1: Transform ---
  html_data <- tryCatch({
    transform_maxdiff_for_html(maxdiff_results, config)
  }, error = function(e) {
    message(sprintf("[TRS PARTIAL] MAXD_HTML_TRANSFORM_FAILED: %s", e$message))
    return(NULL)
  })

  if (is.null(html_data)) {
    return(list(status = "REFUSED", message = "Data transformation failed"))
  }

  brand <- html_data$meta$brand_colour %||% "#323367"

  # --- Layer 2: Tables ---
  tables <- list()

  tables$preference_scores <- tryCatch(
    build_preference_scores_table(
      html_data$preferences$scores,
      html_data$preferences$anchor_data
    ),
    error = function(e) { message(sprintf("  Table error (preferences): %s", e$message)); "" }
  )

  tables$count_scores <- tryCatch(
    build_count_scores_table(
      html_data$items$count_data,
      html_data$items$discrimination
    ),
    error = function(e) { message(sprintf("  Table error (counts): %s", e$message)); "" }
  )

  if (!is.null(html_data$turf)) {
    tables$turf <- tryCatch(
      build_turf_table(html_data$turf$incremental_table),
      error = function(e) { message(sprintf("  Table error (turf): %s", e$message)); "" }
    )
  }

  if (!is.null(html_data$segments)) {
    tables$segments <- tryCatch(
      build_segment_table(html_data$segments$segment_data),
      error = function(e) { message(sprintf("  Table error (segments): %s", e$message)); "" }
    )
  }

  tables$diagnostics <- tryCatch(
    build_diagnostics_table(html_data$diagnostics),
    error = function(e) { message(sprintf("  Table error (diagnostics): %s", e$message)); "" }
  )

  # --- Layer 3: Charts ---
  charts <- list()

  if (!is.null(html_data$preferences$scores)) {
    charts$preference_chart <- tryCatch(
      build_preference_chart(html_data$preferences$scores, brand, use_shares = TRUE),
      error = function(e) { message(sprintf("  Chart error (pref shares): %s", e$message)); "" }
    )
    charts$preference_detail_chart <- tryCatch(
      build_preference_chart(html_data$preferences$scores, brand, use_shares = FALSE),
      error = function(e) { message(sprintf("  Chart error (pref detail): %s", e$message)); "" }
    )
  }

  if (!is.null(html_data$items$count_data)) {
    charts$diverging_chart <- tryCatch(
      build_diverging_chart(html_data$items$count_data, brand),
      error = function(e) { message(sprintf("  Chart error (diverging): %s", e$message)); "" }
    )
  }

  if (!is.null(html_data$turf)) {
    charts$turf_chart <- tryCatch(
      build_turf_chart(html_data$turf$reach_curve, brand),
      error = function(e) { message(sprintf("  Chart error (turf): %s", e$message)); "" }
    )
  }

  if (!is.null(html_data$segments)) {
    charts$segment_chart <- tryCatch(
      build_segment_chart(html_data$segments$segment_data, brand),
      error = function(e) { message(sprintf("  Chart error (segments): %s", e$message)); "" }
    )
  }

  # --- Layer 4: Page assembly ---
  page <- tryCatch({
    build_maxdiff_page(html_data, tables, charts, config)
  }, error = function(e) {
    message(sprintf("[TRS PARTIAL] MAXD_HTML_PAGE_FAILED: %s", e$message))
    return(NULL)
  })

  if (is.null(page)) {
    return(list(status = "REFUSED", message = "Page assembly failed"))
  }

  # --- Write ---
  tryCatch({
    writeLines(page, output_path)
  }, error = function(e) {
    message(sprintf("[TRS PARTIAL] MAXD_HTML_WRITE_FAILED: %s", e$message))
    return(list(status = "REFUSED", message = sprintf("Write failed: %s", e$message)))
  })

  file_size <- file.info(output_path)$size

  message(sprintf("  HTML report generated: %s (%.1f KB)", output_path, file_size / 1024))

  list(
    status = "PASS",
    output_file = output_path,
    file_size_bytes = file_size,
    file_size_mb = round(file_size / 1024 / 1024, 2)
  )
}
