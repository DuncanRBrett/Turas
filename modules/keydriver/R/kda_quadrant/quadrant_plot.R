# ==============================================================================
# TURAS KEY DRIVER - QUADRANT PLOTTING FUNCTIONS
# ==============================================================================
#
# Purpose: Create IPA quadrant charts and related visualizations
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Create Standard IPA Quadrant Plot
#'
#' The classic 2x2 importance-performance matrix.
#'
#' @param quad_data Prepared quadrant data
#' @param config Configuration parameters
#' @return ggplot object
#' @keywords internal
create_ipa_plot <- function(quad_data, config) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    keydriver_refuse(
      code = "FEATURE_QUADRANT_GGPLOT2_MISSING",
      title = "ggplot2 Package Required",
      problem = "Package 'ggplot2' is required for quadrant plots but not installed.",
      why_it_matters = "Quadrant charts are generated using ggplot2.",
      how_to_fix = "Install ggplot2: install.packages('ggplot2')"
    )
  }

  # Get thresholds
  x_thresh <- quad_data$x_threshold[1]
  y_thresh <- quad_data$y_threshold[1]

  # Axis labels
  x_label <- config$x_axis_label %||% "Performance"
  y_label <- config$y_axis_label %||% "Derived Importance"

  # Quadrant colors
  quad_colors <- config$quadrant_colors %||% c(
    "1" = "#E74C3C",
    "2" = "#27AE60",
    "3" = "#95A5A6",
    "4" = "#F39C12"
  )

  # Base plot
  p <- ggplot2::ggplot(
    quad_data,
    ggplot2::aes(x = x, y = y)
  )

  # Add quadrant background shading
  if (isTRUE(config$shade_quadrants)) {
    p <- p + add_quadrant_shading(quad_data, quad_colors, x_thresh, y_thresh)
  }

  # Add quadrant lines
  p <- p +
    ggplot2::geom_vline(
      xintercept = x_thresh,
      linetype = "dashed",
      color = "gray40",
      linewidth = 0.5
    ) +
    ggplot2::geom_hline(
      yintercept = y_thresh,
      linetype = "dashed",
      color = "gray40",
      linewidth = 0.5
    )

  # Add points
  p <- p +
    ggplot2::geom_point(
      ggplot2::aes(color = factor(quadrant)),
      size = 4,
      alpha = 0.8
    ) +
    ggplot2::scale_color_manual(
      values = quad_colors,
      labels = levels(quad_data$quadrant_label),
      name = "Action Zone"
    )

  # Add labels
  p <- add_driver_labels(p, quad_data, config)

  # Add quadrant annotations
  p <- p + add_quadrant_annotations(quad_data, config, x_thresh, y_thresh)

  # Axis formatting
  p <- p +
    ggplot2::scale_x_continuous(
      limits = c(0, 100),
      breaks = seq(0, 100, 20),
      labels = scales::label_number()
    ) +
    ggplot2::scale_y_continuous(
      limits = c(0, 100),
      breaks = seq(0, 100, 20),
      labels = scales::label_number()
    )

  # Labels and theme
  p <- p +
    ggplot2::labs(
      title = "Key Driver Priority Matrix",
      subtitle = "Importance-Performance Analysis",
      x = x_label,
      y = y_label,
      caption = paste(
        "Threshold method:", config$threshold_method %||% "mean",
        "| n drivers:", nrow(quad_data)
      )
    ) +
    turas_quadrant_theme()

  # Add iso-priority diagonal if requested
  if (isTRUE(config$show_diagonal)) {
    p <- p +
      ggplot2::geom_abline(
        slope = 1,
        intercept = 0,
        linetype = "dotted",
        color = "gray60"
      )
  }

  p
}


#' Add Driver Labels to Plot
#'
#' @param p ggplot object
#' @param quad_data Quadrant data
#' @param config Configuration
#' @return Updated ggplot object
#' @keywords internal
add_driver_labels <- function(p, quad_data, config) {

  use_ggrepel <- requireNamespace("ggrepel", quietly = TRUE)

  if (isTRUE(config$label_all_points)) {
    if (use_ggrepel) {
      p <- p +
        ggrepel::geom_text_repel(
          ggplot2::aes(label = driver),
          size = 3,
          max.overlaps = 20,
          box.padding = 0.5,
          point.padding = 0.3,
          segment.color = "gray60",
          segment.size = 0.3
        )
    } else {
      p <- p +
        ggplot2::geom_text(
          ggplot2::aes(label = driver),
          size = 3,
          vjust = -0.8
        )
    }
  } else {
    # Label only top N by priority
    top_n <- config$label_top_n %||% 10
    top_drivers <- head(
      quad_data[order(-quad_data$priority_score), "driver"],
      top_n
    )

    label_data <- quad_data[quad_data$driver %in% top_drivers, ]

    if (use_ggrepel) {
      p <- p +
        ggrepel::geom_text_repel(
          data = label_data,
          ggplot2::aes(label = driver),
          size = 3,
          max.overlaps = 15,
          box.padding = 0.5
        )
    } else {
      p <- p +
        ggplot2::geom_text(
          data = label_data,
          ggplot2::aes(label = driver),
          size = 3,
          vjust = -0.8
        )
    }
  }

  p
}


#' Add Quadrant Background Shading
#'
#' @param quad_data Quadrant data
#' @param colors Quadrant colors
#' @param x_thresh X threshold
#' @param y_thresh Y threshold
#' @return ggplot2 geom for rectangles
#' @keywords internal
add_quadrant_shading <- function(quad_data, colors, x_thresh, y_thresh) {

  rects <- data.frame(
    quadrant = c(1, 2, 3, 4),
    xmin = c(0, x_thresh, 0, x_thresh),
    xmax = c(x_thresh, 100, x_thresh, 100),
    ymin = c(y_thresh, y_thresh, 0, 0),
    ymax = c(100, 100, y_thresh, y_thresh)
  )

  list(
    ggplot2::geom_rect(
      data = rects,
      ggplot2::aes(
        xmin = xmin, xmax = xmax,
        ymin = ymin, ymax = ymax,
        fill = factor(quadrant)
      ),
      alpha = 0.1,
      inherit.aes = FALSE
    ),
    ggplot2::scale_fill_manual(
      values = colors,
      guide = "none"
    )
  )
}


#' Add Quadrant Annotations
#'
#' Labels in corners of each quadrant.
#'
#' @param quad_data Quadrant data
#' @param config Configuration
#' @param x_thresh X threshold
#' @param y_thresh Y threshold
#' @return ggplot2 geom for text
#' @keywords internal
add_quadrant_annotations <- function(quad_data, config, x_thresh, y_thresh) {

  labels <- data.frame(
    x = c(5, 95, 5, 95),
    y = c(95, 95, 5, 5),
    label = c(
      config$quadrant_1_name %||% "CONCENTRATE\nHERE",
      config$quadrant_2_name %||% "KEEP UP\nGOOD WORK",
      config$quadrant_3_name %||% "LOW\nPRIORITY",
      config$quadrant_4_name %||% "POSSIBLE\nOVERKILL"
    ),
    hjust = c(0, 1, 0, 1),
    vjust = c(1, 1, 0, 0)
  )

  ggplot2::geom_text(
    data = labels,
    ggplot2::aes(x = x, y = y, label = label),
    hjust = labels$hjust,
    vjust = labels$vjust,
    size = 3,
    fontface = "bold",
    color = "gray40",
    alpha = 0.7,
    inherit.aes = FALSE
  )
}


#' Create Dual Importance Plot
#'
#' Compares stated (self-reported) vs. derived importance.
#' Reveals "hidden gems" and "false priorities".
#'
#' @param dual_data Data with both stated and derived importance
#' @param config Configuration parameters
#' @return ggplot object
#' @keywords internal
create_dual_importance_plot <- function(dual_data, config) {

  # Get thresholds (mean of each axis)
  x_thresh <- mean(dual_data$stated_importance, na.rm = TRUE)
  y_thresh <- mean(dual_data$derived_importance, na.rm = TRUE)

  # Assign interpretation zones
  dual_data$zone <- assign_dual_zones(
    dual_data$stated_importance,
    dual_data$derived_importance,
    x_thresh,
    y_thresh
  )

  zone_colors <- c(
    "Obvious Priority" = "#27AE60",
    "Hidden Gem" = "#3498DB",
    "False Priority" = "#E74C3C",
    "True Low Priority" = "#95A5A6"
  )

  p <- ggplot2::ggplot(
    dual_data,
    ggplot2::aes(x = stated_importance, y = derived_importance)
  ) +
    # Quadrant lines
    ggplot2::geom_vline(xintercept = x_thresh, linetype = "dashed", color = "gray40") +
    ggplot2::geom_hline(yintercept = y_thresh, linetype = "dashed", color = "gray40") +
    # Diagonal reference (stated = derived)
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dotted", color = "gray60") +
    # Points
    ggplot2::geom_point(
      ggplot2::aes(color = zone),
      size = 4,
      alpha = 0.8
    ) +
    ggplot2::scale_color_manual(values = zone_colors, name = "Interpretation")

  # Labels
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    p <- p +
      ggrepel::geom_text_repel(
        ggplot2::aes(label = driver),
        size = 3,
        max.overlaps = 15
      )
  } else {
    p <- p +
      ggplot2::geom_text(
        ggplot2::aes(label = driver),
        size = 3,
        vjust = -0.8
      )
  }

  # Formatting
  p <- p +
    ggplot2::scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
    ggplot2::scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
    ggplot2::labs(
      title = "Stated vs. Derived Importance",
      subtitle = "Points above diagonal: underestimated importance | Below: overestimated",
      x = "Stated Importance (self-reported)",
      y = "Derived Importance (statistical)",
      caption = "Hidden Gems = high derived, low stated | False Priorities = high stated, low derived"
    ) +
    turas_quadrant_theme()

  p
}


#' Assign Dual Importance Zones
#'
#' @param stated Stated importance values
#' @param derived Derived importance values
#' @param x_thresh Stated threshold
#' @param y_thresh Derived threshold
#' @return Character vector of zone assignments
#' @keywords internal
assign_dual_zones <- function(stated, derived, x_thresh, y_thresh) {

  zone <- rep(NA_character_, length(stated))

  zone[stated >= x_thresh & derived >= y_thresh] <- "Obvious Priority"
  zone[stated < x_thresh & derived >= y_thresh] <- "Hidden Gem"
  zone[stated >= x_thresh & derived < y_thresh] <- "False Priority"
  zone[stated < x_thresh & derived < y_thresh] <- "True Low Priority"

  zone
}


#' Create Gap Analysis Chart
#'
#' Horizontal bar chart showing performance gaps.
#'
#' @param gap_data Gap analysis data
#' @param config Configuration
#' @return ggplot object
#' @keywords internal
create_gap_chart <- function(gap_data, config) {

  p <- ggplot2::ggplot(
    gap_data,
    ggplot2::aes(
      x = stats::reorder(driver, gap),
      y = gap,
      fill = gap_direction
    )
  ) +
    ggplot2::geom_col(alpha = 0.8) +
    ggplot2::geom_hline(yintercept = 0, color = "gray40") +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(
      values = c(
        "Underperforming" = "#E74C3C",
        "Overperforming" = "#27AE60"
      ),
      name = NULL
    ) +
    ggplot2::labs(
      title = "Importance-Performance Gap Analysis",
      subtitle = "Positive gap = performance below importance level",
      x = NULL,
      y = "Gap (Importance - Performance)",
      caption = "Priority: Address largest positive gaps first"
    ) +
    turas_quadrant_theme()

  p
}


#' Turas Quadrant Theme
#'
#' Extends base turas theme for quadrant charts.
#'
#' @return ggplot2 theme object
#' @export
turas_quadrant_theme <- function() {

  ggplot2::theme_minimal() +
    ggplot2::theme(
      # Text
      text = ggplot2::element_text(family = "sans"),
      plot.title = ggplot2::element_text(size = 14, face = "bold", hjust = 0),
      plot.subtitle = ggplot2::element_text(size = 11, color = "gray40", hjust = 0),
      axis.title = ggplot2::element_text(size = 10),
      axis.text = ggplot2::element_text(size = 9),

      # Square aspect ratio for quadrant
      aspect.ratio = 1,

      # Panel styling
      panel.border = ggplot2::element_rect(
        color = "gray80",
        fill = NA,
        linewidth = 0.5
      ),

      # Legend at bottom
      legend.position = "bottom",
      legend.direction = "horizontal",
      legend.title = ggplot2::element_text(size = 10),
      legend.text = ggplot2::element_text(size = 9),

      # Grid
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = "gray90"),

      # Axis styling
      axis.line = ggplot2::element_blank(),

      # Plot margins
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    )
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
