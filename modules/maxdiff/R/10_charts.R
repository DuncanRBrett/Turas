# ==============================================================================
# MAXDIFF MODULE - CHART GENERATION - TURAS V10.0
# ==============================================================================
# Publication-quality chart generation for MaxDiff results
# Part of Turas MaxDiff Module
#
# VERSION HISTORY:
# Turas v10.0 - Initial release (2025-12)
#
# CHARTS:
# - Utility bar chart (horizontal)
# - Best-Worst diverging bar chart
# - Segment comparison chart
# - Utility distribution (violin/box plot from HB)
#
# DEPENDENCIES:
# - ggplot2
# - utils.R
# ==============================================================================

CHARTS_VERSION <- "10.0"

# ==============================================================================
# CHART CONFIGURATION
# ==============================================================================

#' Default chart theme
#' @keywords internal
get_maxdiff_theme <- function() {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(NULL)
  }

  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 14, hjust = 0),
      plot.subtitle = ggplot2::element_text(size = 11, hjust = 0, color = "grey40"),
      axis.title = ggplot2::element_text(size = 11),
      axis.text = ggplot2::element_text(size = 10),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(size = 10),
      legend.text = ggplot2::element_text(size = 9),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank()
    )
}


#' MaxDiff color palette
#' @keywords internal
get_maxdiff_colors <- function() {
  list(
    primary = "#2c3e50",
    secondary = "#3498db",
    positive = "#27ae60",
    negative = "#e74c3c",
    neutral = "#95a5a6",
    best = "#27ae60",
    worst = "#e74c3c"
  )
}


# ==============================================================================
# MAIN CHART GENERATOR
# ==============================================================================

#' Generate All MaxDiff Charts
#'
#' Creates all standard MaxDiff visualization charts.
#'
#' @param results List. Analysis results
#' @param config List. Configuration object
#' @param verbose Logical. Print progress messages
#'
#' @return List of file paths to generated charts
#' @export
generate_maxdiff_charts <- function(results, config, verbose = TRUE) {

  # Check ggplot2
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    warning(
      "Package 'ggplot2' is required for chart generation.\n",
      "Install with: install.packages('ggplot2')",
      call. = FALSE
    )
    return(NULL)
  }

  if (verbose) {
    cat("\n")
    log_message("GENERATING CHARTS", "INFO", verbose)
    cat(paste(rep("-", 60), collapse = ""), "\n")
  }

  # Setup output folder
  output_folder <- config$project_settings$Output_Folder
  if (is.null(output_folder) || !nzchar(output_folder)) {
    output_folder <- config$project_root
  }

  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  project_name <- config$project_settings$Project_Name
  chart_paths <- list()

  # ============================================================================
  # UTILITY BAR CHART
  # ============================================================================

  if (verbose) log_message("Creating utility bar chart...", "INFO", verbose)

  utility_chart <- create_utility_bar_chart(results, config)

  if (!is.null(utility_chart)) {
    chart_path <- file.path(output_folder, sprintf("%s_utility_bar.png", project_name))
    save_chart(utility_chart, chart_path)
    chart_paths$utility_bar <- chart_path
  }

  # ============================================================================
  # BEST-WORST DIVERGING CHART
  # ============================================================================

  if (verbose) log_message("Creating best-worst chart...", "INFO", verbose)

  bw_chart <- create_best_worst_chart(results, config)

  if (!is.null(bw_chart)) {
    chart_path <- file.path(output_folder, sprintf("%s_best_worst.png", project_name))
    save_chart(bw_chart, chart_path)
    chart_paths$best_worst <- chart_path
  }

  # ============================================================================
  # SEGMENT CHARTS
  # ============================================================================

  if (!is.null(results$segment_results) &&
      !is.null(config$segment_settings) &&
      nrow(config$segment_settings) > 0) {

    for (i in seq_len(nrow(config$segment_settings))) {
      seg_id <- config$segment_settings$Segment_ID[i]

      if (verbose) log_message(sprintf("Creating segment chart: %s", seg_id), "INFO", verbose)

      seg_chart <- create_segment_chart(results, config, seg_id)

      if (!is.null(seg_chart)) {
        chart_path <- file.path(output_folder,
                                sprintf("%s_segment_%s.png", project_name, seg_id))
        save_chart(seg_chart, chart_path)
        chart_paths[[paste0("segment_", seg_id)]] <- chart_path
      }
    }
  }

  # ============================================================================
  # UTILITY DISTRIBUTION (HB)
  # ============================================================================

  if (!is.null(results$hb_results) &&
      !is.null(results$hb_results$individual_utilities)) {

    if (verbose) log_message("Creating utility distribution chart...", "INFO", verbose)

    dist_chart <- create_utility_distribution_chart(results, config)

    if (!is.null(dist_chart)) {
      chart_path <- file.path(output_folder,
                              sprintf("%s_utility_distribution.png", project_name))
      save_chart(dist_chart, chart_path, height = 8)
      chart_paths$utility_distribution <- chart_path
    }
  }

  if (verbose) {
    log_message(sprintf("Generated %d charts", length(chart_paths)), "INFO", verbose)
  }

  return(chart_paths)
}


# ==============================================================================
# UTILITY BAR CHART
# ==============================================================================

#' Create utility bar chart
#'
#' @param results Analysis results
#' @param config Configuration
#'
#' @return ggplot object
#' @export
create_utility_bar_chart <- function(results, config) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) return(NULL)

  # Get item scores
  item_scores <- results$count_scores

  # Add rescaled scores if not present
  rescale_method <- config$output_settings$Score_Rescale_Method

  if ("HB_Utility_Mean" %in% names(item_scores)) {
    item_scores$Utility <- item_scores$HB_Utility_Mean
    score_label <- "HB Utility"
  } else if ("Logit_Utility" %in% names(item_scores)) {
    item_scores$Utility <- item_scores$Logit_Utility
    score_label <- "Logit Utility"
  } else {
    item_scores$Utility <- item_scores$Net_Score
    score_label <- "Net Score"
  }

  item_scores$Rescaled <- rescale_utilities(item_scores$Utility, rescale_method)

  # Sort by rescaled score
  item_scores <- item_scores[order(-item_scores$Rescaled), ]
  item_scores$Item_Label <- factor(item_scores$Item_Label,
                                   levels = rev(item_scores$Item_Label))

  colors <- get_maxdiff_colors()

  ggplot2::ggplot(item_scores,
                  ggplot2::aes(x = Rescaled, y = Item_Label)) +
    ggplot2::geom_col(fill = colors$primary, alpha = 0.9) +
    ggplot2::geom_text(
      ggplot2::aes(label = round(Rescaled, 1)),
      hjust = -0.2,
      size = 3.5
    ) +
    ggplot2::scale_x_continuous(
      expand = ggplot2::expansion(mult = c(0.02, 0.15))
    ) +
    ggplot2::labs(
      title = "MaxDiff Item Utilities",
      subtitle = sprintf("Score: %s (rescaled to %s)", score_label, rescale_method),
      x = "Rescaled Score",
      y = NULL
    ) +
    get_maxdiff_theme()
}


# ==============================================================================
# BEST-WORST DIVERGING CHART
# ==============================================================================

#' Create best-worst diverging bar chart
#'
#' @param results Analysis results
#' @param config Configuration
#'
#' @return ggplot object
#' @export
create_best_worst_chart <- function(results, config) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) return(NULL)

  item_scores <- results$count_scores

  # Sort by Net_Score
  item_scores <- item_scores[order(-item_scores$Net_Score), ]
  item_scores$Item_Label <- factor(item_scores$Item_Label,
                                   levels = rev(item_scores$Item_Label))

  # Reshape for diverging chart
  chart_data <- rbind(
    data.frame(
      Item_Label = item_scores$Item_Label,
      Type = "Best %",
      Value = item_scores$Best_Pct,
      stringsAsFactors = FALSE
    ),
    data.frame(
      Item_Label = item_scores$Item_Label,
      Type = "Worst %",
      Value = -item_scores$Worst_Pct,
      stringsAsFactors = FALSE
    )
  )

  colors <- get_maxdiff_colors()

  ggplot2::ggplot(chart_data,
                  ggplot2::aes(x = Value, y = Item_Label, fill = Type)) +
    ggplot2::geom_col(alpha = 0.9) +
    ggplot2::geom_vline(xintercept = 0, color = "grey40", linewidth = 0.5) +
    ggplot2::scale_fill_manual(
      values = c("Best %" = colors$best, "Worst %" = colors$worst)
    ) +
    ggplot2::scale_x_continuous(
      labels = function(x) abs(x),
      limits = c(-max(abs(chart_data$Value)) * 1.1,
                 max(abs(chart_data$Value)) * 1.1)
    ) +
    ggplot2::labs(
      title = "Best vs. Worst Selection",
      subtitle = "Percentage of times each item was chosen as Best (right) or Worst (left)",
      x = "Percentage",
      y = NULL,
      fill = NULL
    ) +
    get_maxdiff_theme() +
    ggplot2::theme(legend.position = "top")
}


# ==============================================================================
# SEGMENT COMPARISON CHART
# ==============================================================================

#' Create segment comparison chart
#'
#' @param results Analysis results
#' @param config Configuration
#' @param segment_id Character. Segment ID to plot
#'
#' @return ggplot object
#' @export
create_segment_chart <- function(results, config, segment_id) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) return(NULL)

  if (is.null(results$segment_results)) return(NULL)

  segment_scores <- results$segment_results$segment_scores
  segment_scores <- segment_scores[segment_scores$Segment_ID == segment_id, ]

  if (nrow(segment_scores) == 0) return(NULL)

  # Get segment info
  seg_info <- config$segment_settings[config$segment_settings$Segment_ID == segment_id, ]
  seg_label <- seg_info$Segment_Label[1]

  # Sort items by overall Net_Score
  overall_scores <- results$count_scores
  item_order <- overall_scores$Item_ID[order(-overall_scores$Net_Score)]

  segment_scores$Item_Label <- factor(
    segment_scores$Item_Label,
    levels = rev(overall_scores$Item_Label[match(item_order, overall_scores$Item_ID)])
  )

  ggplot2::ggplot(segment_scores,
                  ggplot2::aes(x = Net_Score, y = Item_Label,
                               fill = Segment_Value)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8),
                      alpha = 0.9, width = 0.7) +
    ggplot2::labs(
      title = sprintf("MaxDiff Scores by %s", seg_label),
      subtitle = sprintf("Net Score (Best%% - Worst%%) by segment level"),
      x = "Net Score",
      y = NULL,
      fill = seg_label
    ) +
    ggplot2::scale_fill_brewer(palette = "Set2") +
    get_maxdiff_theme() +
    ggplot2::theme(legend.position = "top")
}


# ==============================================================================
# UTILITY DISTRIBUTION CHART
# ==============================================================================

#' Create utility distribution chart (from HB)
#'
#' @param results Analysis results
#' @param config Configuration
#'
#' @return ggplot object
#' @export
create_utility_distribution_chart <- function(results, config) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) return(NULL)

  if (is.null(results$hb_results)) return(NULL)

  ind_utils <- results$hb_results$individual_utilities

  if (is.null(ind_utils) || nrow(ind_utils) == 0) return(NULL)

  # Reshape to long format
  items <- config$items
  included_items <- items$Item_ID[items$Include == 1]

  # Get item columns
  item_cols <- intersect(names(ind_utils), included_items)

  if (length(item_cols) == 0) return(NULL)

  # Reshape
  long_utils <- do.call(rbind, lapply(item_cols, function(item_id) {
    data.frame(
      resp_id = ind_utils$resp_id,
      Item_ID = item_id,
      Utility = ind_utils[[item_id]],
      stringsAsFactors = FALSE
    )
  }))

  # Add item labels
  long_utils <- merge(long_utils, items[, c("Item_ID", "Item_Label")],
                      by = "Item_ID", all.x = TRUE)

  # Sort by mean utility
  item_means <- aggregate(Utility ~ Item_ID + Item_Label, data = long_utils, FUN = mean)
  item_means <- item_means[order(-item_means$Utility), ]

  long_utils$Item_Label <- factor(long_utils$Item_Label,
                                  levels = rev(item_means$Item_Label))

  colors <- get_maxdiff_colors()

  ggplot2::ggplot(long_utils,
                  ggplot2::aes(x = Utility, y = Item_Label)) +
    ggplot2::geom_violin(fill = colors$primary, alpha = 0.3, color = NA) +
    ggplot2::geom_boxplot(width = 0.2, fill = colors$primary, alpha = 0.7,
                         outlier.size = 0.5) +
    ggplot2::labs(
      title = "Distribution of Individual Utilities",
      subtitle = "From Hierarchical Bayes estimation",
      x = "Utility",
      y = NULL
    ) +
    get_maxdiff_theme()
}


# ==============================================================================
# CHART SAVING
# ==============================================================================

#' Save chart to file
#'
#' @param chart ggplot object
#' @param path Output file path
#' @param width Chart width in inches
#' @param height Chart height in inches
#' @param dpi Resolution
#'
#' @keywords internal
save_chart <- function(chart, path, width = 10, height = 7, dpi = 300) {

  if (is.null(chart)) return(invisible(NULL))

  ggplot2::ggsave(
    filename = path,
    plot = chart,
    width = width,
    height = height,
    dpi = dpi,
    bg = "white"
  )

  invisible(path)
}


# ==============================================================================
# MODULE INITIALIZATION
# ==============================================================================

message(sprintf("TURAS>MaxDiff charts module loaded (v%s)", CHARTS_VERSION))
