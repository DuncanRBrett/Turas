# ==============================================================================
# SEGMENT HTML REPORT - MAIN ORCHESTRATOR
# ==============================================================================
# 6-step HTML report generation pipeline for the segmentation module.
# Follows the catdriver/keydriver pattern exactly.
#
# Steps:
#   1. Validate inputs
#   2. Transform data
#   3. Build tables
#   4. Build charts
#   5. Assemble HTML page
#   6. Write HTML file
#
# Version: 11.0
# ==============================================================================


# ==============================================================================
# LOAD SUBMODULES
# ==============================================================================

# Determine report directory
# Strategy: walk the source stack to find this file's own directory,
# fall back to .seg_html_dir (set by 00_main.R) or TURAS_ROOT.
.seg_html_report_dir <- tryCatch({
  # Walk frames from innermost to outermost to find this file's ofile
  found_dir <- NULL
  for (i in rev(seq_len(sys.nframe()))) {
    ofile <- tryCatch(sys.frame(i)$ofile, error = function(e) NULL)
    if (!is.null(ofile) && grepl("99_html_report_main\\.R$", ofile)) {
      found_dir <- normalizePath(dirname(ofile), mustWork = FALSE)
      break
    }
  }
  if (!is.null(found_dir)) {
    found_dir
  } else if (exists(".seg_html_dir", envir = .GlobalEnv)) {
    # Use the variable set by 00_main.R
    get(".seg_html_dir", envir = .GlobalEnv)
  } else {
    stop("Could not determine HTML report directory")
  }
}, error = function(e) {
  # Final fallback: construct from TURAS_ROOT
  turas_root <- Sys.getenv("TURAS_ROOT", getwd())
  file.path(turas_root, "modules/segment/lib/html_report")
})

# Source required submodules
.seg_html_required_files <- c(
  "00_html_guard.R",
  "01_data_transformer.R",
  "02_table_builder.R",
  "03_page_builder.R",
  "04_html_writer.R",
  "05_chart_builder.R"
)

for (.seg_html_file in .seg_html_required_files) {
  .seg_html_path <- file.path(.seg_html_report_dir, .seg_html_file)
  if (file.exists(.seg_html_path)) {
    source(.seg_html_path)
  } else {
    cat(sprintf("\n=== TURAS ERROR ===\n"))
    cat(sprintf("Context: Segment HTML Report Loader\n"))
    cat(sprintf("Missing file: %s\n", .seg_html_path))
    cat(sprintf("===================\n\n"))
    stop(sprintf("[SEGMENT] Required HTML report file missing: %s", .seg_html_file))
  }
}

# Optional: exploration report builder
.seg_html_exploration_path <- file.path(.seg_html_report_dir, "06_exploration_report.R")
if (file.exists(.seg_html_exploration_path)) {
  source(.seg_html_exploration_path)
}


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

#' Generate Segment HTML Report
#'
#' Main entry point for HTML report generation. Routes to final or
#' exploration report based on results$mode.
#'
#' @param results List with segmentation results (mode, cluster_result, etc.)
#' @param config Configuration list
#' @param output_path Character, output file path (.html)
#' @return List with status, output_file, file_size_mb, warnings
#' @export
generate_segment_html_report <- function(results, config, output_path) {

  # Route exploration mode to dedicated builder
  mode <- results$mode %||% "final"
  if (mode == "exploration" && exists("generate_segment_exploration_html_report", mode = "function")) {
    return(generate_segment_exploration_html_report(results, config, output_path))
  }

  start_time <- Sys.time()

  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  SEGMENT HTML REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================

  cat("  Step 1: Validating inputs...\n")
  guard_result <- validate_segment_html_inputs(results, config, output_path)

  if (guard_result$status == "REFUSED") {
    cat(sprintf("    REFUSED: %s\n", guard_result$message %||% guard_result$code))
    return(guard_result)
  }

  # ==========================================================================
  # STEP 2: TRANSFORM DATA
  # ==========================================================================

  cat("  Step 2: Transforming data...\n")
  html_data <- tryCatch(
    transform_segment_for_html(results, config),
    error = function(e) {
      cat(sprintf("    ERROR: Data transformation failed: %s\n", e$message))
      NULL
    }
  )

  if (is.null(html_data)) {
    return(list(
      status = "REFUSED",
      code = "CALC_TRANSFORM_FAILED",
      message = "Failed to transform segmentation data for HTML report."
    ))
  }

  # ==========================================================================
  # STEP 3: BUILD TABLES
  # ==========================================================================

  cat("  Step 3: Building tables...\n")
  warnings <- character(0)
  tables <- list()

  tables$overview <- tryCatch(build_seg_overview_table(html_data), error = function(e) {
    warnings <<- c(warnings, paste("Overview table:", e$message))
    NULL
  })

  tables$profiles <- tryCatch(build_seg_profile_table(html_data), error = function(e) {
    warnings <<- c(warnings, paste("Profile table:", e$message))
    NULL
  })

  tables$validation <- tryCatch(build_seg_validation_table(html_data), error = function(e) {
    warnings <<- c(warnings, paste("Validation table:", e$message))
    NULL
  })

  tables$demographics <- tryCatch(build_seg_demographics_table(html_data), error = function(e) {
    warnings <<- c(warnings, paste("Demographics table:", e$message))
    NULL
  })

  tables$rules <- tryCatch(build_seg_rules_table(html_data), error = function(e) {
    warnings <<- c(warnings, paste("Rules table:", e$message))
    NULL
  })

  if (html_data$method == "gmm") {
    tables$gmm_membership <- tryCatch(build_seg_gmm_membership_table(html_data), error = function(e) {
      warnings <<- c(warnings, paste("GMM membership table:", e$message))
      NULL
    })
  }

  cat(sprintf("    Built %d tables\n", sum(!sapply(tables, is.null))))

  # ==========================================================================
  # STEP 4: BUILD CHARTS
  # ==========================================================================

  cat("  Step 4: Building charts...\n")
  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"
  charts <- list()

  charts$sizes <- tryCatch(
    build_seg_sizes_chart(html_data, brand_colour),
    error = function(e) {
      warnings <<- c(warnings, paste("Sizes chart:", e$message))
      NULL
    }
  )

  charts$silhouette <- tryCatch(
    build_seg_silhouette_chart(html_data, brand_colour),
    error = function(e) {
      warnings <<- c(warnings, paste("Silhouette chart:", e$message))
      NULL
    }
  )

  charts$importance <- tryCatch(
    build_seg_importance_chart(html_data, brand_colour),
    error = function(e) {
      warnings <<- c(warnings, paste("Importance chart:", e$message))
      NULL
    }
  )

  charts$heatmap <- tryCatch(
    build_seg_heatmap_chart(html_data, brand_colour, accent_colour),
    error = function(e) {
      warnings <<- c(warnings, paste("Heatmap chart:", e$message))
      NULL
    }
  )

  cat(sprintf("    Built %d charts\n", sum(!sapply(charts, is.null))))

  # ==========================================================================
  # STEP 5: ASSEMBLE HTML PAGE
  # ==========================================================================

  cat("  Step 5: Assembling HTML page...\n")
  page <- tryCatch(
    build_seg_html_page(html_data, tables, charts, config),
    error = function(e) {
      cat(sprintf("    ERROR: Page assembly failed: %s\n", e$message))
      NULL
    }
  )

  if (is.null(page)) {
    return(list(
      status = "REFUSED",
      code = "CALC_PAGE_BUILD_FAILED",
      message = "Failed to assemble HTML page."
    ))
  }

  # ==========================================================================
  # STEP 6: WRITE HTML FILE
  # ==========================================================================

  cat("  Step 6: Writing HTML file...\n")
  write_result <- write_seg_html_report(page, output_path)

  if (write_result$status == "REFUSED") {
    return(write_result)
  }

  # ==========================================================================
  # DONE
  # ==========================================================================

  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 1)
  final_status <- if (length(warnings) > 0) "PARTIAL" else "PASS"

  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat(sprintf("  HTML report complete (%s, %.1fs)\n", final_status, elapsed))
  if (length(warnings) > 0) {
    cat(sprintf("  %d warning(s):\n", length(warnings)))
    for (w in warnings) cat(sprintf("    - %s\n", w))
  }
  cat(paste(rep("-", 60), collapse = ""), "\n")

  list(
    status = final_status,
    output_file = write_result$output_file,
    file_size_mb = write_result$file_size_mb,
    elapsed_seconds = elapsed,
    warnings = if (length(warnings) > 0) warnings else NULL
  )
}
