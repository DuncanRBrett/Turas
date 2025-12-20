# ==============================================================================
# TURAS KEY DRIVER - QUADRANT ANALYSIS MAIN ORCHESTRATION
# ==============================================================================
#
# Purpose: Main entry point for Importance-Performance Analysis (IPA)
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Create Quadrant Analysis
#'
#' Generates Importance-Performance Analysis (IPA) quadrant charts.
#' This is the actionable output that drives business decisions.
#'
#' @param kda_results Results from run_key_driver_analysis() or importance data frame
#' @param data Original data frame (required if performance not pre-calculated)
#' @param performance_data Optional data frame with pre-calculated performance scores
#' @param config Quadrant configuration parameters (see details)
#' @param stated_importance Optional data frame with stated importance scores
#' @param segments Optional segment definitions for comparison
#'
#' @details
#' Configuration parameters (all optional with sensible defaults):
#' \itemize{
#'   \item \code{importance_source}: Source method - "auto", "shap", "relative_weights", "regression", "correlation"
#'   \item \code{threshold_method}: How to set quadrant lines - "mean", "median", "midpoint", "custom"
#'   \item \code{importance_threshold}: Custom threshold for importance (if method = "custom")
#'   \item \code{performance_threshold}: Custom threshold for performance (if method = "custom")
#'   \item \code{normalize_axes}: Normalize to 0-100 scale (default TRUE)
#'   \item \code{shade_quadrants}: Add background color to quadrants (default TRUE)
#'   \item \code{label_all_points}: Label all drivers vs top N only (default TRUE)
#'   \item \code{label_top_n}: If not labeling all, show top N (default 10)
#'   \item \code{show_diagonal}: Show iso-priority diagonal line (default FALSE)
#'   \item \code{quadrant_1_name}: Custom name for Q1 (default "Concentrate Here")
#'   \item \code{quadrant_2_name}: Custom name for Q2 (default "Keep Up Good Work")
#'   \item \code{quadrant_3_name}: Custom name for Q3 (default "Low Priority")
#'   \item \code{quadrant_4_name}: Custom name for Q4 (default "Possible Overkill")
#' }
#'
#' @return quadrant_results S3 object containing:
#' \itemize{
#'   \item \code{data}: Prepared data with quadrant assignments
#'   \item \code{plots}: List of ggplot objects
#'   \item \code{action_table}: Prioritized action recommendations
#'   \item \code{gap_analysis}: Gap scores and rankings
#' }
#'
#' @examples
#' \dontrun{
#' # After running KDA
#' kda_results <- run_keydriver_analysis("config.xlsx")
#'
#' # Create quadrant analysis
#' quadrant <- create_quadrant_analysis(
#'   kda_results = kda_results,
#'   data = survey_data,
#'   config = list(
#'     importance_source = "shap",
#'     threshold_method = "mean"
#'   )
#' )
#'
#' # View main plot
#' print(quadrant$plots$standard_ipa)
#'
#' # View action table
#' print(quadrant$action_table)
#' }
#'
#' @export
create_quadrant_analysis <- function(
    kda_results,
    data = NULL,
    performance_data = NULL,
    config = list(),
    stated_importance = NULL,
    segments = NULL
) {

  cat("\n")
  cat(rep("-", 60), "\n", sep = "")
  cat("QUADRANT ANALYSIS (IPA)\n")
  cat(rep("-", 60), "\n", sep = "")

  # Check required packages
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    keydriver_refuse(
      code = "FEATURE_QUADRANT_PACKAGES_MISSING",
      title = "Missing Required Package for Quadrant Analysis",
      problem = "Package 'ggplot2' is required for quadrant analysis but not installed.",
      why_it_matters = "Quadrant charts cannot be generated without ggplot2.",
      how_to_fix = c(
        "Install ggplot2: install.packages('ggplot2')",
        "Or disable quadrant analysis if not needed"
      )
    )
  }

  if (!requireNamespace("ggrepel", quietly = TRUE)) {
    warning("Package 'ggrepel' not available. Labels may overlap.")
  }

  # Set defaults for config
  config <- set_quadrant_defaults(config)

  # 1. Extract/validate importance scores
  cat("  1. Extracting importance scores...\n")
  importance <- extract_importance_scores(kda_results, config)
  cat(sprintf("     - %d drivers with importance scores\n", nrow(importance)))

  # 2. Calculate performance scores
  cat("  2. Calculating performance scores...\n")
  performance <- calculate_performance_scores(kda_results, data, performance_data, config)
  cat(sprintf("     - %d drivers with performance scores\n", nrow(performance)))

  # 3. Validate inputs
  validate_quadrant_inputs(importance, performance)

  # 4. Prepare quadrant data
  cat("  3. Preparing quadrant data...\n")
  quad_data <- prepare_quadrant_data(importance, performance, config)

  # Count by quadrant
  q_counts <- table(quad_data$quadrant)
  cat(sprintf("     - Q1 (Concentrate): %d, Q2 (Keep Up): %d, Q3 (Low Priority): %d, Q4 (Overkill): %d\n",
              q_counts["1"] %||% 0, q_counts["2"] %||% 0,
              q_counts["3"] %||% 0, q_counts["4"] %||% 0))

  # 5. Generate standard IPA plot
  cat("  4. Generating visualizations...\n")
  plots <- list()
  plots$standard_ipa <- create_ipa_plot(quad_data, config)

  # 6. Dual importance analysis (if stated importance provided)
  if (!is.null(stated_importance) && nrow(stated_importance) > 0) {
    cat("     - Creating dual importance plot...\n")
    dual_data <- prepare_dual_importance(importance, stated_importance)
    plots$dual_importance <- create_dual_importance_plot(dual_data, config)
  }

  # 7. Gap analysis
  cat("     - Creating gap analysis...\n")
  gap_data <- calculate_gap_analysis(quad_data)
  plots$gap_chart <- create_gap_chart(gap_data, config)

  # 8. Segment comparison (if segments provided)
  segment_results <- NULL
  if (!is.null(segments) && nrow(segments) > 0 && !is.null(data)) {
    cat("  5. Running segment comparison...\n")
    segment_results <- create_segment_quadrants(
      kda_results, data, performance_data, segments, config
    )
    if (!is.null(segment_results$plot)) {
      plots$segment_comparison <- segment_results$plot
    }
  }

  # 9. Create action table
  cat("  6. Creating action table...\n")
  action_table <- create_action_table(quad_data, config)

  # Compile results
  results <- structure(
    list(
      data = quad_data,
      plots = plots,
      action_table = action_table,
      gap_analysis = gap_data,
      segments = segment_results,
      config = config
    ),
    class = "quadrant_results"
  )

  cat("\n")
  cat("  Quadrant analysis complete.\n")
  cat(sprintf("  - Priority actions (Q1): %d drivers\n", sum(quad_data$quadrant == 1)))
  cat(sprintf("  - Top priority: %s\n", action_table$Driver[1]))
  cat("\n")

  results
}


#' Set Default Configuration for Quadrant
#'
#' @param config User-provided config list
#' @return Config list with defaults filled in
#' @keywords internal
set_quadrant_defaults <- function(config) {

  defaults <- list(
    importance_source = "auto",
    threshold_method = "mean",
    importance_threshold = 50,
    performance_threshold = 50,
    normalize_axes = TRUE,
    performance_scale_min = NULL,
    performance_scale_max = NULL,
    shade_quadrants = TRUE,
    label_all_points = TRUE,
    label_top_n = 10,
    show_diagonal = FALSE,
    quadrant_1_name = "Concentrate Here",
    quadrant_2_name = "Keep Up Good Work",
    quadrant_3_name = "Low Priority",
    quadrant_4_name = "Possible Overkill",
    x_axis_label = "Performance",
    y_axis_label = "Derived Importance",
    quadrant_colors = c(
      "1" = "#E74C3C",
      "2" = "#27AE60",
      "3" = "#95A5A6",
      "4" = "#F39C12"
    )
  )

  # Merge user config with defaults
  for (name in names(defaults)) {
    if (is.null(config[[name]])) {
      config[[name]] <- defaults[[name]]
    }
  }

  config
}


#' Print Method for quadrant_results
#'
#' @param x quadrant_results object
#' @param ... Additional arguments (ignored)
#' @export
print.quadrant_results <- function(x, ...) {

  cat("\nQuadrant Analysis Results\n")
  cat(rep("=", 50), "\n", sep = "")

  # Quadrant counts
  q_counts <- table(x$data$quadrant)
  cat("\nDrivers by Quadrant:\n")
  cat(sprintf("  Q1 - Concentrate Here: %d drivers\n", q_counts["1"] %||% 0))
  cat(sprintf("  Q2 - Keep Up Good Work: %d drivers\n", q_counts["2"] %||% 0))
  cat(sprintf("  Q3 - Low Priority: %d drivers\n", q_counts["3"] %||% 0))
  cat(sprintf("  Q4 - Possible Overkill: %d drivers\n", q_counts["4"] %||% 0))

  # Top priorities
  cat("\nTop 5 Priority Actions:\n")
  top5 <- head(x$action_table, 5)
  for (i in seq_len(nrow(top5))) {
    cat(sprintf("  %d. %s (%s)\n", i, top5$Driver[i], top5$Zone[i]))
  }

  # Available plots
  cat("\nAvailable Plots:\n")
  for (p in names(x$plots)) {
    cat(sprintf("  - %s\n", p))
  }

  cat("\n")
  invisible(x)
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
