# ==============================================================================
# TURAS KEY DRIVER - SHAP SEGMENT ANALYSIS
# ==============================================================================
#
# Purpose: Calculate and compare SHAP importance across segments
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Run SHAP Analysis by Segment
#'
#' Calculates and compares SHAP importance across customer segments.
#'
#' @param shp shapviz object
#' @param data Original data with segment variables
#' @param segments Segment definition data frame with columns:
#'   - segment_name: Display name for segment
#'   - segment_variable: Variable name in data
#'   - segment_values: Comma-separated values to include
#'
#' @return List with segment-level results and comparison plots
#' @keywords internal
run_segment_shap <- function(shp, data, segments) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' required for segment comparison. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  results <- list()
  sample_indices <- attr(shp, "sample_indices")

  # If we have sample indices, filter data to match
  if (!is.null(sample_indices)) {
    data <- data[sample_indices, , drop = FALSE]
  }

  for (i in seq_len(nrow(segments))) {

    seg_name <- segments$segment_name[i]
    seg_var <- segments$segment_variable[i]
    seg_vals <- strsplit(as.character(segments$segment_values[i]), ",\\s*")[[1]]

    # Check if segment variable exists
    if (!seg_var %in% names(data)) {
      warning(sprintf("Segment variable '%s' not found in data. Skipping segment '%s'.",
                      seg_var, seg_name))
      next
    }

    # Create segment filter
    seg_idx <- data[[seg_var]] %in% seg_vals

    if (sum(seg_idx) < 30) {
      warning(sprintf("Segment '%s' has only %d observations. Minimum 30 recommended.",
                      seg_name, sum(seg_idx)))
    }

    if (sum(seg_idx) == 0) {
      warning(sprintf("Segment '%s' has no observations. Skipping.", seg_name))
      next
    }

    # Split shapviz object
    shp_segment <- shp[seg_idx, ]

    # Calculate importance for segment
    segment_importance <- calculate_segment_importance(shp_segment)
    segment_importance$segment <- seg_name

    # Create segment plot
    segment_plot <- tryCatch({
      shapviz::sv_importance(shp_segment, kind = "both", max_display = 15) +
        ggplot2::labs(
          title = paste("Driver Importance:", seg_name),
          subtitle = sprintf("n = %d", sum(seg_idx))
        ) +
        turas_theme()
    }, error = function(e) NULL)

    results[[seg_name]] <- list(
      n = sum(seg_idx),
      importance = segment_importance,
      plots = list(importance = segment_plot)
    )
  }

  # Create comparison plot if we have at least 2 segments
  if (length(results) >= 2) {
    results$comparison <- create_segment_comparison(results, segments)
  }

  results
}


#' Calculate Segment Importance
#'
#' Calculates mean |SHAP| importance for a segment.
#'
#' @param shp_segment shapviz object for segment
#' @return Data frame with importance scores
#' @keywords internal
calculate_segment_importance <- function(shp_segment) {

  shap_values <- shapviz::get_shap_values(shp_segment)

  # Mean absolute SHAP value for each feature
  mean_abs_shap <- colMeans(abs(shap_values))

  importance <- data.frame(
    feature = names(mean_abs_shap),
    importance = as.numeric(mean_abs_shap),
    stringsAsFactors = FALSE
  )

  # Normalize to percentage
  total <- sum(importance$importance)
  if (total > 0) {
    importance$importance_pct <- importance$importance / total * 100
  } else {
    importance$importance_pct <- 0
  }

  importance
}


#' Create Segment Comparison Plot
#'
#' Side-by-side comparison of driver rankings across segments.
#'
#' @param segment_results List of segment results
#' @param segments Segment definitions
#' @return List with comparison data and plot
#' @keywords internal
create_segment_comparison <- function(segment_results, segments) {

  # Extract importance from each segment
  importance_list <- lapply(names(segment_results), function(seg) {
    if (seg == "comparison") return(NULL)

    imp <- segment_results[[seg]]$importance
    if (is.null(imp)) return(NULL)

    imp$segment <- seg
    imp
  })

  importance_list <- importance_list[!sapply(importance_list, is.null)]

  if (length(importance_list) == 0) {
    return(list(data = NULL, plot = NULL))
  }

  importance_df <- do.call(rbind, importance_list)

  # Create comparison plot
  plot <- ggplot2::ggplot(
    importance_df,
    ggplot2::aes(
      x = stats::reorder(feature, importance_pct),
      y = importance_pct,
      fill = segment
    )
  ) +
    ggplot2::geom_col(position = "dodge", alpha = 0.8) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Driver Importance by Segment",
      subtitle = "SHAP-based importance comparison",
      x = NULL,
      y = "Importance (%)",
      fill = "Segment"
    ) +
    ggplot2::scale_fill_manual(values = turas_colors(length(unique(importance_df$segment)))) +
    turas_theme()

  # Create comparison table
  comparison_table <- create_segment_comparison_table(importance_df)

  list(
    data = importance_df,
    table = comparison_table,
    plot = plot
  )
}


#' Create Segment Comparison Table
#'
#' Creates a pivot table comparing ranks across segments.
#'
#' @param importance_df Combined importance data frame
#' @return Data frame with rank comparison
#' @keywords internal
create_segment_comparison_table <- function(importance_df) {

  # Get unique segments and features
  segments <- unique(importance_df$segment)
  features <- unique(importance_df$feature)

  # Create pivot table
  result <- data.frame(Driver = features, stringsAsFactors = FALSE)

  for (seg in segments) {
    seg_data <- importance_df[importance_df$segment == seg, ]

    # Add rank column
    seg_data$rank <- rank(-seg_data$importance_pct, ties.method = "min")

    # Match to features
    rank_col <- sapply(features, function(f) {
      r <- seg_data$rank[seg_data$feature == f]
      if (length(r) == 0) NA_integer_ else r
    })

    result[[paste0(seg, "_Rank")]] <- rank_col

    # Add importance column
    imp_col <- sapply(features, function(f) {
      imp <- seg_data$importance_pct[seg_data$feature == f]
      if (length(imp) == 0) NA_real_ else round(imp, 1)
    })

    result[[paste0(seg, "_Pct")]] <- imp_col
  }

  # Add delta column if exactly 2 segments
  if (length(segments) == 2) {
    rank_cols <- paste0(segments, "_Rank")
    result$Rank_Delta <- result[[rank_cols[1]]] - result[[rank_cols[2]]]
  }

  # Sort by first segment rank
  first_rank_col <- paste0(segments[1], "_Rank")
  result <- result[order(result[[first_rank_col]]), ]
  rownames(result) <- NULL

  result
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
