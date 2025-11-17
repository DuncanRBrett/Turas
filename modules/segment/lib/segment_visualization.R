# ==============================================================================
# SEGMENTATION VISUALIZATION
# ==============================================================================
# Create charts and visualizations for segmentation results
# Part of Turas Segmentation Module
# ==============================================================================

#' Plot Segment Sizes
#'
#' Creates bar chart showing segment sizes (counts and percentages)
#'
#' @param clusters Integer vector of segment assignments
#' @param segment_names Character vector of segment names (optional)
#' @param output_file Optional path to save plot
#' @export
plot_segment_sizes <- function(clusters, segment_names = NULL, output_file = NULL) {

  # Calculate segment counts
  counts <- table(clusters)
  percentages <- 100 * counts / sum(counts)

  # Create labels
  if (is.null(segment_names)) {
    labels <- paste0("Segment ", names(counts))
  } else {
    labels <- segment_names[as.numeric(names(counts))]
  }

  # Open graphics device if saving
  if (!is.null(output_file)) {
    png(output_file, width = 800, height = 600, res = 100)
  }

  # Create plot
  par(mar = c(8, 4, 4, 2))
  barplot_obj <- barplot(
    as.numeric(counts),
    names.arg = labels,
    las = 2,  # Rotate labels
    col = rainbow(length(counts), alpha = 0.7),
    border = "white",
    main = "Segment Sizes",
    ylab = "Number of Respondents",
    ylim = c(0, max(counts) * 1.15)
  )

  # Add percentage labels on top of bars
  text(
    x = barplot_obj,
    y = as.numeric(counts),
    labels = sprintf("%.1f%%", percentages),
    pos = 3,
    cex = 0.9
  )

  # Add count labels
  text(
    x = barplot_obj,
    y = as.numeric(counts) / 2,
    labels = sprintf("n=%d", counts),
    cex = 0.9,
    col = "white",
    font = 2
  )

  # Close device if saving
  if (!is.null(output_file)) {
    dev.off()
    cat(sprintf("Saved segment sizes plot to: %s\n", basename(output_file)))
  }

  invisible(list(counts = counts, percentages = percentages))
}


#' Plot K-Selection Metrics
#'
#' Visualizes elbow and silhouette plots for choosing optimal K
#'
#' @param exploration_result Result from exploration mode
#' @param output_file Optional path to save plot
#' @export
plot_k_selection <- function(exploration_result, output_file = NULL) {

  metrics_df <- exploration_result$metrics_comparison

  # Open graphics device if saving
  if (!is.null(output_file)) {
    png(output_file, width = 1000, height = 500, res = 100)
  }

  # Create 2-panel plot
  par(mfrow = c(1, 2), mar = c(4, 4, 3, 2))

  # Panel 1: Within-cluster sum of squares (Elbow plot)
  plot(
    metrics_df$k,
    metrics_df$tot.withinss,
    type = "b",
    pch = 19,
    col = "steelblue",
    lwd = 2,
    xlab = "Number of Segments (k)",
    ylab = "Total Within-Cluster Sum of Squares",
    main = "Elbow Method",
    xaxt = "n"
  )
  axis(1, at = metrics_df$k)
  grid(col = "gray90", lty = 1)

  # Panel 2: Average silhouette width
  plot(
    metrics_df$k,
    metrics_df$avg_silhouette_width,
    type = "b",
    pch = 19,
    col = "darkgreen",
    lwd = 2,
    xlab = "Number of Segments (k)",
    ylab = "Average Silhouette Width",
    main = "Silhouette Method",
    xaxt = "n",
    ylim = c(0, max(metrics_df$avg_silhouette_width, na.rm = TRUE) * 1.1)
  )
  axis(1, at = metrics_df$k)
  grid(col = "gray90", lty = 1)

  # Add horizontal line at 0
  abline(h = 0, lty = 2, col = "gray50")

  # Close device if saving
  if (!is.null(output_file)) {
    dev.off()
    cat(sprintf("Saved k-selection plot to: %s\n", basename(output_file)))
  }

  invisible(metrics_df)
}


#' Plot Segment Profiles Heatmap
#'
#' Creates heatmap showing segment profiles on clustering variables
#'
#' @param profile Segment profile result
#' @param question_labels Optional question labels
#' @param output_file Optional path to save plot
#' @export
plot_segment_profiles <- function(profile, question_labels = NULL, output_file = NULL) {
  
  # Extract clustering profile
  profile_df <- profile$clustering_profile
  
  # Convert to matrix (variables x segments)
  var_names <- profile_df$Variable
  segment_cols <- setdiff(names(profile_df), "Variable")
  
  profile_matrix <- as.matrix(profile_df[, segment_cols])
  rownames(profile_matrix) <- var_names
  
  # Apply labels if available
  if (!is.null(question_labels)) {
    # Source config for format_variable_label
    source("modules/segment/lib/segment_config.R")
    rownames(profile_matrix) <- format_variable_label(var_names, question_labels)
  }
  
  # Open graphics device if saving
  if (!is.null(output_file)) {
    png(output_file, width = 1000, height = 700, res = 100)
  }
  
  # Create color palette (blue-white-red) for actual values
  colors <- colorRampPalette(c("steelblue", "lightyellow", "coral"))(100)
  
  # Create heatmap with ORIGINAL values (not re-standardized)
  par(mar = c(6, 12, 4, 2))
  
  # Use actual values, not z-scores
  data_range <- range(profile_matrix, na.rm = TRUE)
  
  image(
    x = 1:ncol(profile_matrix),
    y = 1:nrow(profile_matrix),
    z = t(profile_matrix),
    col = colors,
    xlab = "",
    ylab = "",
    main = "Segment Profiles Heatmap\n(Mean Scores)",
    axes = FALSE,
    zlim = data_range
  )
  
  # Add axes
  axis(1, at = 1:ncol(profile_matrix), labels = colnames(profile_matrix), las = 2, cex.axis = 0.9)
  axis(2, at = 1:nrow(profile_matrix), labels = rownames(profile_matrix), las = 2, cex.axis = 0.8)
  
  # Add grid
  abline(h = 0.5:(nrow(profile_matrix) + 0.5), col = "white", lwd = 1)
  abline(v = 0.5:(ncol(profile_matrix) + 0.5), col = "white", lwd = 1)
  
  # Add text values in each cell
  for (i in 1:nrow(profile_matrix)) {
    for (j in 1:ncol(profile_matrix)) {
      text(j, i, sprintf("%.1f", profile_matrix[i, j]), cex = 0.8, font = 2)
    }
  }
  
  # Close device if saving
  if (!is.null(output_file)) {
    dev.off()
    cat(sprintf("Saved segment profiles heatmap to: %s\n", basename(output_file)))
  }
  
  invisible(profile_matrix)
}

#' Plot Segment Spider/Radar Chart
#'
#' Creates radar chart comparing segments on clustering variables
#'
#' @param profile Segment profile result
#' @param max_vars Maximum number of variables to display (default: 10)
#' @param question_labels Optional question labels
#' @param output_file Optional path to save plot
#' @export
plot_segment_spider <- function(profile, max_vars = 10, question_labels = NULL,
                                output_file = NULL) {

  # Check if fmsb package is available
  if (!requireNamespace("fmsb", quietly = TRUE)) {
    cat("⚠ fmsb package not installed. Skipping spider plot.\n")
    cat("  Install with: install.packages('fmsb')\n")
    return(invisible(NULL))
  }

  # Extract clustering profile
  profile_df <- profile$clustering_profile

  # Limit to max_vars
  if (nrow(profile_df) > max_vars) {
    cat(sprintf("⚠ Limiting spider plot to %d variables (use max_vars to adjust)\n", max_vars))
    profile_df <- profile_df[1:max_vars, ]
  }

  var_names <- profile_df$Variable
  segment_cols <- setdiff(names(profile_df), "Variable")

  # Transpose for radarchart (segments as rows)
  profile_matrix <- as.data.frame(t(profile_df[, segment_cols]))

  # Apply labels if available
  if (!is.null(question_labels)) {
    source("modules/segment/lib/segment_config.R")
    names(profile_matrix) <- format_variable_label(var_names, question_labels)
  } else {
    names(profile_matrix) <- var_names
  }

  # Add max/min rows for scaling
  max_row <- apply(profile_matrix, 2, max) * 1.2
  min_row <- apply(profile_matrix, 2, min) * 0.8
  profile_matrix <- rbind(max_row, min_row, profile_matrix)

  # Open graphics device if saving
  if (!is.null(output_file)) {
    png(output_file, width = 800, height = 800, res = 100)
  }

  # Create radar chart
  par(mar = c(1, 1, 3, 1))
  fmsb::radarchart(
    profile_matrix,
    axistype = 1,
    pcol = rainbow(nrow(profile_matrix) - 2, alpha = 0.8),
    pfcol = rainbow(nrow(profile_matrix) - 2, alpha = 0.3),
    plwd = 2,
    cglcol = "grey",
    cglty = 1,
    axislabcol = "grey",
    caxislabels = seq(0, 100, 25),
    cglwd = 0.8,
    vlcex = 0.7,
    title = "Segment Profiles Comparison"
  )

  # Add legend
  legend(
    x = "topright",
    legend = segment_cols,
    col = rainbow(length(segment_cols), alpha = 0.8),
    lty = 1,
    lwd = 2,
    cex = 0.8
  )

  # Close device if saving
  if (!is.null(output_file)) {
    dev.off()
    cat(sprintf("Saved segment spider plot to: %s\n", basename(output_file)))
  }

  invisible(profile_matrix)
}


#' Create All Standard Visualizations
#'
#' Convenience function to create all standard segmentation visualizations
#'
#' @param result Segmentation result (exploration or final)
#' @param output_folder Folder to save plots
#' @param prefix File prefix for outputs
#' @param question_labels Optional question labels
#' @export
create_all_visualizations <- function(result, output_folder, prefix = "seg_",
                                     question_labels = NULL) {

  cat("\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("CREATING VISUALIZATIONS\n")
  cat(rep("=", 80), "\n", sep = "")
  cat("\n")

  # Create output folder if needed
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  # Determine result type
  is_exploration <- !is.null(result$models)

  if (is_exploration) {
    # Exploration mode: create k-selection plot
    cat("Creating k-selection visualization...\n")
    k_plot_path <- file.path(output_folder, paste0(prefix, "k_selection.png"))
    plot_k_selection(result, k_plot_path)

    # Create visualization for best k
    cat("\nCreating visualizations for recommended solution...\n")
    best_k <- result$recommended_k
    model <- result$models[[as.character(best_k)]]
    clusters <- model$cluster

  } else {
    # Final mode
    cat("Creating visualizations for final segmentation...\n")
    clusters <- result$clusters
  }

  # Segment sizes
  cat("Creating segment sizes plot...\n")
  sizes_path <- file.path(output_folder, paste0(prefix, "segment_sizes.png"))
  segment_names <- if (!is.null(result$segment_names)) result$segment_names else NULL
  plot_segment_sizes(clusters, segment_names, sizes_path)

  # Segment profiles heatmap
  if (!is.null(result$profile)) {
    cat("Creating segment profiles heatmap...\n")
    heatmap_path <- file.path(output_folder, paste0(prefix, "profiles_heatmap.png"))
    plot_segment_profiles(result$profile, question_labels, heatmap_path)

    cat("Creating segment spider plot...\n")
    spider_path <- file.path(output_folder, paste0(prefix, "profiles_spider.png"))
    plot_segment_spider(result$profile, question_labels = question_labels,
                       output_file = spider_path)
  }

  cat("\n✓ All visualizations created\n\n")

  invisible(TRUE)
}
