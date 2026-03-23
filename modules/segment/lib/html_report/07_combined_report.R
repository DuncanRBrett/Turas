# ==============================================================================
# SEGMENT HTML REPORT - COMBINED MULTI-METHOD REPORT (Orchestrator)
# ==============================================================================
# Orchestrates multi-method comparison HTML report generation.
# Entry point: generate_segment_combined_html_report()
# Called from 99_html_report_main.R when results$mode == "combined".
#
# Split files:
#   07_combined_report.R      - This file: orchestrator only
#   07a_combined_builders.R   - Page assembly, CSS, panels, comparison, JS
#
# Version: 12.0
# ==============================================================================


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================


#' Generate Combined Multi-Method Segment HTML Report
#'
#' Main entry point for the combined (multi-method comparison) HTML report.
#' Builds a tabbed interface where each clustering method has its own panel
#' showing the standard report sections, plus a Comparison tab with
#' side-by-side metrics and agreement analysis.
#'
#' @param results List with combined segmentation results. Expected structure:
#'   \describe{
#'     \item{mode}{Character, must be "combined"}
#'     \item{method_results}{Named list of per-method results, each structured
#'       like a "final" mode result (with cluster_result, validation_metrics,
#'       profile_result, segment_names)}
#'     \item{methods}{Character vector of method names (e.g., c("kmeans", "hclust", "gmm"))}
#'     \item{data_list}{Shared data list (original data used for clustering)}
#'   }
#' @param config Configuration list (brand_colour, accent_colour, report_title, etc.)
#' @param output_path Character, output file path (.html)
#' @return List with status, output_file, file_size_mb, elapsed_seconds, warnings
#' @export
generate_segment_combined_html_report <- function(results, config, output_path) {

  start_time <- Sys.time()

  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat("  SEGMENT COMBINED HTML REPORT GENERATION\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")

  # ==========================================================================
  # STEP 1: VALIDATE INPUTS
  # ==========================================================================

  cat("  Step 1: Validating inputs...\n")

  if (!requireNamespace("htmltools", quietly = TRUE)) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: PKG_HTMLTOOLS_MISSING\n")
    cat("Message: Package 'htmltools' is required for HTML report generation.\n")
    cat("Fix: install.packages('htmltools')\n")
    cat("===================\n\n")
    return(list(
      status = "REFUSED",
      code = "PKG_HTMLTOOLS_MISSING",
      message = "Package 'htmltools' is required for HTML report generation but is not installed.",
      how_to_fix = "Install htmltools: install.packages('htmltools')"
    ))
  }

  if (is.null(results) || !is.list(results)) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: DATA_INVALID_RESULTS\n")
    cat("Message: Results object is NULL or not a list.\n")
    cat("===================\n\n")
    return(list(
      status = "REFUSED",
      code = "DATA_INVALID_RESULTS",
      message = "Results object is NULL or not a list.",
      how_to_fix = "Ensure combined segmentation analysis completed successfully."
    ))
  }

  methods <- results$methods
  method_results <- results$method_results

  if (is.null(methods) || length(methods) < 2) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: CFG_COMBINED_MIN_METHODS\n")
    cat("Message: At least 2 methods required for combined report.\n")
    cat("===================\n\n")
    return(list(
      status = "REFUSED",
      code = "CFG_COMBINED_MIN_METHODS",
      message = "At least 2 methods required for combined report.",
      how_to_fix = "Provide results$methods with at least 2 method names and corresponding results$method_results."
    ))
  }

  if (is.null(method_results) || !is.list(method_results)) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: DATA_MISSING_METHOD_RESULTS\n")
    cat("Message: results$method_results is NULL or not a list.\n")
    cat("===================\n\n")
    return(list(
      status = "REFUSED",
      code = "DATA_MISSING_METHOD_RESULTS",
      message = "results$method_results is NULL or not a list.",
      how_to_fix = "Provide a named list of per-method results in results$method_results."
    ))
  }

  if (is.null(output_path) || !nzchar(output_path)) {
    return(list(
      status = "REFUSED",
      code = "IO_INVALID_OUTPUT_PATH",
      message = "Output path is empty or NULL.",
      how_to_fix = "Provide a valid output file path ending in .html."
    ))
  }

  # ==========================================================================
  # STEP 2: TRANSFORM DATA FOR EACH METHOD
  # ==========================================================================

  cat("  Step 2: Transforming per-method data...\n")
  warnings <- character(0)
  brand_colour <- config$brand_colour %||% "#323367"
  accent_colour <- config$accent_colour %||% "#CC9900"

  method_html_data <- list()
  for (m in methods) {
    mr <- method_results[[m]]
    if (is.null(mr)) {
      warnings <- c(warnings, sprintf("Method '%s': no results found, skipping.", m))
      next
    }

    # Build a per-method results object that looks like final mode
    per_method_results <- mr
    per_method_results$mode <- "final"

    # Build a per-method config with method set
    per_method_config <- config
    per_method_config$method <- m

    html_data <- tryCatch(
      transform_segment_for_html(per_method_results, per_method_config),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Method '%s': data transform failed: %s", m, e$message))
        NULL
      }
    )

    if (!is.null(html_data)) {
      method_html_data[[m]] <- html_data
    }
  }

  if (length(method_html_data) == 0) {
    cat("\n=== TURAS ERROR ===\n")
    cat("Code: CALC_NO_METHODS_TRANSFORMED\n")
    cat("Message: No methods could be transformed for HTML report.\n")
    cat("===================\n\n")
    return(list(
      status = "REFUSED",
      code = "CALC_NO_METHODS_TRANSFORMED",
      message = "No methods could be transformed for HTML report.",
      how_to_fix = "Check that method_results contains valid final-mode results for at least one method."
    ))
  }

  active_methods <- names(method_html_data)
  cat(sprintf("    Transformed %d of %d methods\n", length(active_methods), length(methods)))

  # ==========================================================================
  # STEP 3: BUILD PER-METHOD TABLES AND CHARTS
  # ==========================================================================

  cat("  Step 3: Building per-method tables & charts...\n")

  method_tables <- list()
  method_charts <- list()

  for (m in active_methods) {
    hd <- method_html_data[[m]]

    # Tables
    tbls <- list()
    tbls$overview <- tryCatch(build_seg_overview_table(hd), error = function(e) {
      warnings <<- c(warnings, sprintf("Method '%s' overview table: %s", m, e$message))
      NULL
    })
    tbls$validation <- tryCatch(build_seg_validation_table(hd), error = function(e) {
      warnings <<- c(warnings, sprintf("Method '%s' validation table: %s", m, e$message))
      NULL
    })
    tbls$profiles <- tryCatch(build_seg_profile_table(hd), error = function(e) {
      warnings <<- c(warnings, sprintf("Method '%s' profile table: %s", m, e$message))
      NULL
    })
    method_tables[[m]] <- tbls

    # Charts
    chts <- list()
    chts$sizes <- tryCatch(
      build_seg_sizes_chart(hd, brand_colour),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Method '%s' sizes chart: %s", m, e$message))
        NULL
      }
    )
    chts$silhouette <- tryCatch(
      build_seg_silhouette_chart(hd, brand_colour),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Method '%s' silhouette chart: %s", m, e$message))
        NULL
      }
    )
    chts$heatmap <- tryCatch(
      build_seg_heatmap_chart(hd, brand_colour, accent_colour),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Method '%s' heatmap chart: %s", m, e$message))
        NULL
      }
    )
    chts$importance <- tryCatch(
      build_seg_importance_chart(hd, brand_colour),
      error = function(e) {
        warnings <<- c(warnings, sprintf("Method '%s' importance chart: %s", m, e$message))
        NULL
      }
    )
    method_charts[[m]] <- chts
  }

  cat(sprintf("    Built tables & charts for %d methods\n", length(active_methods)))

  # ==========================================================================
  # STEP 4: BUILD COMPARISON CONTENT
  # ==========================================================================

  cat("  Step 4: Building comparison content...\n")

  comparison_table <- tryCatch(
    build_seg_method_comparison_table(method_html_data),
    error = function(e) {
      warnings <- c(warnings, sprintf("Comparison table: %s", e$message))
      NULL
    }
  )

  comparison_chart <- tryCatch(
    build_seg_method_comparison_chart(method_html_data, brand_colour),
    error = function(e) {
      warnings <- c(warnings, sprintf("Comparison chart: %s", e$message))
      NULL
    }
  )

  agreement_matrix <- tryCatch(
    build_seg_agreement_matrix(method_results, active_methods),
    error = function(e) {
      warnings <- c(warnings, sprintf("Agreement matrix: %s", e$message))
      NULL
    }
  )

  comparison_content <- list(
    table = comparison_table,
    chart = comparison_chart,
    agreement = agreement_matrix
  )

  # ==========================================================================
  # STEP 5: ASSEMBLE COMBINED HTML PAGE
  # ==========================================================================

  cat("  Step 5: Assembling combined HTML page...\n")

  page <- tryCatch(
    build_seg_combined_page(
      method_html_data = method_html_data,
      method_tables = method_tables,
      method_charts = method_charts,
      comparison_content = comparison_content,
      config = config,
      recommendation = results$recommendation
    ),
    error = function(e) {
      cat(sprintf("    ERROR: Combined page assembly failed: %s\n", e$message))
      NULL
    }
  )

  if (is.null(page)) {
    return(list(
      status = "REFUSED",
      code = "CALC_PAGE_BUILD_FAILED",
      message = "Failed to assemble combined HTML page."
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
  cat(sprintf("  Combined report complete (%s, %.1fs)\n", final_status, elapsed))
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
