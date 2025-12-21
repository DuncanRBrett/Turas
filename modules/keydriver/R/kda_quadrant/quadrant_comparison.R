# ==============================================================================
# TURAS KEY DRIVER - QUADRANT SEGMENT COMPARISON
# ==============================================================================
#
# Purpose: Create segment-level quadrant comparisons
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Create Segment Quadrant Comparison
#'
#' Side-by-side or faceted quadrants for different segments.
#'
#' @param kda_results KDA results
#' @param data Original data
#' @param performance_data Pre-calculated performance (optional)
#' @param segments Segment definitions data frame
#' @param config Configuration
#' @return List with segment quadrant data and plots
#' @keywords internal
create_segment_quadrants <- function(kda_results, data, performance_data, segments, config) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    # TRS INFO: Optional package not available for quadrant plots
    message("[TRS INFO] ggplot2 not available - segment comparison quadrant skipped")
    return(NULL)
  }

  segment_results <- list()

  # Get driver names
  drivers <- NULL
  if (is.list(kda_results) && "config" %in% names(kda_results)) {
    drivers <- kda_results$config$driver_vars
  }
  if (is.null(drivers) && is.list(kda_results) && "importance" %in% names(kda_results)) {
    drivers <- kda_results$importance$Driver
  }

  if (is.null(drivers)) {
    # TRS INFO: Cannot determine drivers for this optional feature
    message("[TRS INFO] Cannot determine drivers for segment comparison - skipping")
    return(NULL)
  }

  # Get weight variable
  weights <- NULL
  if (is.list(kda_results) && "config" %in% names(kda_results)) {
    weights <- kda_results$config$weight_var
  }

  # Calculate quadrant data for each segment
  for (i in seq_len(nrow(segments))) {

    seg_name <- as.character(segments$segment_name[i])
    seg_var <- as.character(segments$segment_variable[i])
    seg_vals <- strsplit(as.character(segments$segment_values[i]), ",\\s*")[[1]]

    # Check segment variable exists
    if (!seg_var %in% names(data)) {
      # TRS INFO: Segment variable not found
      message(sprintf("[TRS INFO] Segment variable '%s' not found - skipping segment '%s'",
                      seg_var, seg_name))
      next
    }

    # Filter data to segment
    seg_data <- data[data[[seg_var]] %in% seg_vals, , drop = FALSE]

    if (nrow(seg_data) < 30) {
      # TRS INFO: Small sample size warning
      message(sprintf("[TRS INFO] Segment '%s' has only %d observations (minimum 30 recommended)",
                      seg_name, nrow(seg_data)))
    }

    if (nrow(seg_data) == 0) {
      # TRS INFO: Empty segment
      message(sprintf("[TRS INFO] Segment '%s' has no observations - skipping", seg_name))
      next
    }

    # Recalculate performance for segment
    seg_perf <- calculate_weighted_means(seg_data, drivers, weights)
    seg_perf <- normalize_performance(seg_perf, config)

    # Use same importance for all segments (from original KDA)
    # Or recalculate if we have shap results
    seg_importance <- extract_importance_scores(kda_results, config)

    # Prepare quadrant data
    seg_quad <- tryCatch({
      prepare_quadrant_data(seg_importance, seg_perf, config)
    }, error = function(e) {
      # TRS INFO: Error in segment quadrant preparation
      message(sprintf("[TRS INFO] Could not prepare quadrant data for segment '%s': %s - skipping",
                      seg_name, e$message))
      return(NULL)
    })

    if (!is.null(seg_quad)) {
      seg_quad$segment <- seg_name
      segment_results[[seg_name]] <- seg_quad
    }
  }

  if (length(segment_results) == 0) {
    # TRS INFO: No valid segments
    message("[TRS INFO] No valid segments for comparison - quadrant comparison unavailable")
    return(NULL)
  }

  # Combine all segments
  all_segments <- do.call(rbind, segment_results)
  rownames(all_segments) <- NULL

  # Create faceted comparison plot
  plot <- create_faceted_quadrant_plot(all_segments, config)

  # Create rank comparison table
  rank_table <- create_segment_rank_table(segment_results)

  list(
    data = all_segments,
    segment_data = segment_results,
    rank_table = rank_table,
    plot = plot
  )
}


#' Create Faceted Quadrant Plot
#'
#' Multi-panel quadrant chart with one panel per segment.
#'
#' @param all_segments Combined segment data
#' @param config Configuration
#' @return ggplot object
#' @keywords internal
create_faceted_quadrant_plot <- function(all_segments, config) {

  quad_colors <- config$quadrant_colors %||% c(
    "1" = "#E74C3C",
    "2" = "#27AE60",
    "3" = "#95A5A6",
    "4" = "#F39C12"
  )

  p <- ggplot2::ggplot(
    all_segments,
    ggplot2::aes(x = x, y = y, color = factor(quadrant))
  ) +
    # Quadrant lines (use first row's threshold as reference)
    ggplot2::geom_vline(
      xintercept = all_segments$x_threshold[1],
      linetype = "dashed",
      color = "gray40"
    ) +
    ggplot2::geom_hline(
      yintercept = all_segments$y_threshold[1],
      linetype = "dashed",
      color = "gray40"
    ) +
    # Points
    ggplot2::geom_point(size = 3, alpha = 0.8)

  # Labels
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    p <- p +
      ggrepel::geom_text_repel(
        ggplot2::aes(label = driver),
        size = 2.5,
        max.overlaps = 10
      )
  }

  p <- p +
    ggplot2::facet_wrap(~ segment, ncol = 2) +
    ggplot2::scale_color_manual(
      values = quad_colors,
      guide = "none"
    ) +
    ggplot2::scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
    ggplot2::scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
    ggplot2::labs(
      title = "Driver Priority by Segment",
      subtitle = "Quadrant positions may shift across customer groups",
      x = "Performance",
      y = "Derived Importance"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      strip.text = ggplot2::element_text(face = "bold", size = 11),
      panel.border = ggplot2::element_rect(color = "gray80", fill = NA),
      aspect.ratio = 1
    )

  p
}


#' Create Segment Rank Comparison Table
#'
#' Shows how driver ranks change across segments.
#'
#' @param segment_results List of segment quadrant data
#' @return Data frame with rank comparison
#' @keywords internal
create_segment_rank_table <- function(segment_results) {

  # Get all drivers
  all_drivers <- unique(unlist(lapply(segment_results, function(x) x$driver)))

  # Create base table
  result <- data.frame(Driver = all_drivers, stringsAsFactors = FALSE)

  # Add columns for each segment
  for (seg_name in names(segment_results)) {
    seg_data <- segment_results[[seg_name]]

    # Calculate ranks within segment (by priority score)
    seg_data$rank <- rank(-seg_data$priority_score, ties.method = "min")

    # Map to all drivers
    rank_col <- sapply(all_drivers, function(d) {
      r <- seg_data$rank[seg_data$driver == d]
      if (length(r) == 0) NA_integer_ else r
    })

    result[[paste0(seg_name, "_Rank")]] <- rank_col

    # Add quadrant column
    quad_col <- sapply(all_drivers, function(d) {
      q <- seg_data$quadrant[seg_data$driver == d]
      if (length(q) == 0) NA_integer_ else q
    })

    result[[paste0(seg_name, "_Quadrant")]] <- quad_col
  }

  # Sort by first segment rank
  first_rank_col <- paste0(names(segment_results)[1], "_Rank")
  if (first_rank_col %in% names(result)) {
    result <- result[order(result[[first_rank_col]]), ]
  }

  rownames(result) <- NULL
  result
}


#' Recalculate KDA for Segment
#'
#' Re-runs importance calculation for a specific segment.
#' Currently uses same importance; in future could recalculate.
#'
#' @param kda_results Original KDA results
#' @param seg_data Segment data
#' @param config Configuration
#' @return List with recalculated importance
#' @keywords internal
recalculate_kda_for_segment <- function(kda_results, seg_data, config) {
  # For now, return the original importance

# In future, this could re-run SHAP or other methods on the segment
  list(
    importance = extract_importance_scores(kda_results, config)
  )
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
