# ==============================================================================
# TURAS PRICING MODULE - VISUALIZATION
# ==============================================================================
#
# Purpose: Generate visualizations for pricing analysis results
# Version: 1.0.0
# Date: 2025-11-18
#
# ==============================================================================

#' Generate Pricing Analysis Plots
#'
#' Creates visualizations based on analysis method and results.
#'
#' @param results Analysis results from run_van_westendorp() or run_gabor_granger()
#' @param config Configuration list with visualization settings
#'
#' @return List of plot objects
#'
#' @keywords internal
generate_pricing_plots <- function(results, config) {

  plots <- list()

  # Check if ggplot2 is available
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    warning("Package 'ggplot2' not available. Skipping plot generation.", call. = FALSE)
    return(plots)
  }

  method <- config$analysis_method

  if (method == "van_westendorp") {
    plots$van_westendorp <- plot_van_westendorp(results, config)
  } else if (method == "gabor_granger") {
    plots$demand_curve <- plot_gg_demand(results, config)
    plots$revenue_curve <- plot_gg_revenue(results, config)

    # Add profit curve if profit optimization was performed
    if (!is.null(results$optimal_price_profit)) {
      plots$profit_curve <- plot_gg_profit(results, config)
      plots$revenue_vs_profit <- plot_revenue_vs_profit(results, config)
    }
  } else if (method == "both") {
    plots$van_westendorp <- plot_van_westendorp(results$van_westendorp, config)
    plots$demand_curve <- plot_gg_demand(results$gabor_granger, config)
    plots$revenue_curve <- plot_gg_revenue(results$gabor_granger, config)

    # Add profit curve if available
    if (!is.null(results$gabor_granger$optimal_price_profit)) {
      plots$profit_curve <- plot_gg_profit(results$gabor_granger, config)
      plots$revenue_vs_profit <- plot_revenue_vs_profit(results$gabor_granger, config)
    }
  }

  return(plots)
}


#' Plot Van Westendorp Price Sensitivity Meter
#'
#' Creates the classic Van Westendorp PSM plot with four cumulative curves
#' and intersection points.
#'
#' @param vw_results Van Westendorp results
#' @param config Configuration list
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_van_westendorp <- function(vw_results, config) {

  library(ggplot2)

  curves <- vw_results$curves
  price_points <- vw_results$price_points

  # Reshape data for plotting
  plot_data <- data.frame(
    price = rep(curves$price, 4),
    percentage = c(curves$too_cheap, curves$not_cheap,
                   curves$not_expensive, curves$too_expensive) * 100,
    curve = rep(c("Too Cheap", "Not Cheap", "Not Expensive", "Too Expensive"),
                each = nrow(curves)),
    stringsAsFactors = FALSE
  )

  # Define colors
  colors <- c(
    "Too Cheap" = "#E74C3C",
    "Not Cheap" = "#3498DB",
    "Not Expensive" = "#2ECC71",
    "Too Expensive" = "#E67E22"
  )

  currency <- config$currency_symbol %||% "$"

  # Create base plot
  p <- ggplot(plot_data, aes(x = price, y = percentage, color = curve)) +
    geom_line(linewidth = 1.2) +
    scale_color_manual(values = colors) +
    labs(
      title = "Van Westendorp Price Sensitivity Meter",
      subtitle = sprintf("Acceptable Range: %s%.2f - %s%.2f | Optimal: %s%.2f - %s%.2f",
                         currency, price_points$PMC, currency, price_points$PME,
                         currency, price_points$OPP, currency, price_points$IDP),
      x = sprintf("Price (%s)", currency),
      y = "Cumulative Percentage (%)",
      color = "Response"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "gray40"),
      legend.position = "right",
      panel.grid.minor = element_blank()
    )

  # Add shaded acceptable range
  viz_config <- config$visualization %||% list()

  if (isTRUE(viz_config$show_range %||% TRUE)) {
    p <- p +
      annotate(
        "rect",
        xmin = price_points$PMC,
        xmax = price_points$PME,
        ymin = 0, ymax = 100,
        alpha = 0.08, fill = "gray50"
      ) +
      annotate(
        "rect",
        xmin = price_points$OPP,
        xmax = price_points$IDP,
        ymin = 0, ymax = 100,
        alpha = 0.12, fill = "blue"
      )
  }

  # Add price point markers
  if (isTRUE(viz_config$show_points %||% TRUE)) {
    # Add vertical lines for price points
    p <- p +
      geom_vline(xintercept = price_points$PMC, linetype = "dashed",
                 color = "gray50", alpha = 0.7) +
      geom_vline(xintercept = price_points$OPP, linetype = "dashed",
                 color = "blue", alpha = 0.7) +
      geom_vline(xintercept = price_points$IDP, linetype = "dashed",
                 color = "blue", alpha = 0.7) +
      geom_vline(xintercept = price_points$PME, linetype = "dashed",
                 color = "gray50", alpha = 0.7)

    # Add labels
    label_y <- 95
    p <- p +
      annotate("text", x = price_points$PMC, y = label_y,
               label = sprintf("PMC\n%s%.2f", currency, price_points$PMC),
               size = 3, vjust = 1, hjust = 0.5, fontface = "bold") +
      annotate("text", x = price_points$OPP, y = label_y - 15,
               label = sprintf("OPP\n%s%.2f", currency, price_points$OPP),
               size = 3, vjust = 1, hjust = 0.5, fontface = "bold", color = "blue") +
      annotate("text", x = price_points$IDP, y = label_y - 15,
               label = sprintf("IDP\n%s%.2f", currency, price_points$IDP),
               size = 3, vjust = 1, hjust = 0.5, fontface = "bold", color = "blue") +
      annotate("text", x = price_points$PME, y = label_y,
               label = sprintf("PME\n%s%.2f", currency, price_points$PME),
               size = 3, vjust = 1, hjust = 0.5, fontface = "bold")
  }

  return(p)
}


#' Plot Gabor-Granger Demand Curve
#'
#' Creates demand curve plot showing purchase intent vs price.
#'
#' @param gg_results Gabor-Granger results
#' @param config Configuration list
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_gg_demand <- function(gg_results, config) {

  library(ggplot2)

  demand <- gg_results$demand_curve
  optimal <- gg_results$optimal_price
  currency <- config$currency_symbol %||% "$"

  p <- ggplot(demand, aes(x = price, y = purchase_intent * 100)) +
    geom_line(color = "#3498DB", linewidth = 1.2) +
    geom_point(size = 3, color = "#3498DB") +
    labs(
      title = "Gabor-Granger Demand Curve",
      subtitle = sprintf("n = %d respondents", gg_results$diagnostics$n_respondents),
      x = sprintf("Price (%s)", currency),
      y = "Purchase Intent (%)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "gray40"),
      panel.grid.minor = element_blank()
    ) +
    scale_y_continuous(limits = c(0, 100))

  # Add confidence bands if available
  if (!is.null(gg_results$confidence_intervals)) {
    ci <- gg_results$confidence_intervals
    p <- p +
      geom_ribbon(
        data = ci,
        aes(x = price, ymin = ci_lower * 100, ymax = ci_upper * 100),
        alpha = 0.2,
        fill = "#3498DB",
        inherit.aes = FALSE
      )
  }

  # Mark optimal price
  if (!is.null(optimal)) {
    p <- p +
      geom_vline(xintercept = optimal$price, linetype = "dashed", color = "red") +
      geom_point(
        data = data.frame(x = optimal$price, y = optimal$purchase_intent * 100),
        aes(x = x, y = y),
        size = 5, color = "red", inherit.aes = FALSE
      ) +
      annotate(
        "text",
        x = optimal$price,
        y = optimal$purchase_intent * 100 + 5,
        label = sprintf("Optimal: %s%.2f\n(%.0f%% intent)",
                        currency, optimal$price, optimal$purchase_intent * 100),
        vjust = 0, hjust = 0.5,
        color = "red", fontface = "bold", size = 3.5
      )
  }

  return(p)
}


#' Plot Gabor-Granger Revenue Curve
#'
#' Creates revenue curve plot showing revenue index vs price.
#'
#' @param gg_results Gabor-Granger results
#' @param config Configuration list
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_gg_revenue <- function(gg_results, config) {

  library(ggplot2)

  revenue <- gg_results$revenue_curve
  optimal <- gg_results$optimal_price
  currency <- config$currency_symbol %||% "$"

  p <- ggplot(revenue, aes(x = price, y = revenue_index)) +
    geom_line(color = "#2ECC71", linewidth = 1.2) +
    geom_point(size = 3, color = "#2ECC71") +
    labs(
      title = "Gabor-Granger Revenue Curve",
      subtitle = "Revenue Index = Price x Purchase Intent",
      x = sprintf("Price (%s)", currency),
      y = "Revenue Index"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "gray40"),
      panel.grid.minor = element_blank()
    )

  # Mark optimal price
  if (!is.null(optimal)) {
    p <- p +
      geom_vline(xintercept = optimal$price, linetype = "dashed", color = "red") +
      geom_point(
        data = data.frame(x = optimal$price, y = optimal$revenue_index),
        aes(x = x, y = y),
        size = 5, color = "red", inherit.aes = FALSE
      ) +
      annotate(
        "text",
        x = optimal$price,
        y = optimal$revenue_index,
        label = sprintf("Max Revenue\n%s%.2f", currency, optimal$price),
        vjust = -0.5, hjust = 0.5,
        color = "red", fontface = "bold", size = 3.5
      )
  }

  return(p)
}


#' Plot Gabor-Granger Profit Curve
#'
#' Creates profit curve plot showing profit index vs price.
#'
#' @param gg_results Gabor-Granger results with profit optimization
#' @param config Configuration list
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_gg_profit <- function(gg_results, config) {

  library(ggplot2)

  revenue <- gg_results$revenue_curve
  optimal_profit <- gg_results$optimal_price_profit
  currency <- config$currency_symbol %||% "$"

  # Filter to rows with profit data
  profit_data <- revenue[!is.na(revenue$profit_index), ]

  p <- ggplot(profit_data, aes(x = price, y = profit_index)) +
    geom_line(color = "#9B59B6", linewidth = 1.2) +
    geom_point(size = 3, color = "#9B59B6") +
    labs(
      title = "Gabor-Granger Profit Curve",
      subtitle = "Profit Index = (Price - Cost) x Purchase Intent",
      x = sprintf("Price (%s)", currency),
      y = "Profit Index"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "gray40"),
      panel.grid.minor = element_blank()
    )

  # Mark optimal profit price
  if (!is.null(optimal_profit)) {
    p <- p +
      geom_vline(xintercept = optimal_profit$price, linetype = "dashed", color = "darkviolet") +
      geom_point(
        data = data.frame(x = optimal_profit$price, y = optimal_profit$profit_index),
        aes(x = x, y = y),
        size = 5, color = "darkviolet", inherit.aes = FALSE
      ) +
      annotate(
        "text",
        x = optimal_profit$price,
        y = optimal_profit$profit_index,
        label = sprintf("Max Profit\n%s%.2f", currency, optimal_profit$price),
        vjust = -0.5, hjust = 0.5,
        color = "darkviolet", fontface = "bold", size = 3.5
      )
  }

  return(p)
}


#' Plot Revenue vs Profit Comparison
#'
#' Creates dual-axis plot comparing revenue and profit optimization.
#'
#' @param gg_results Gabor-Granger results with profit optimization
#' @param config Configuration list
#'
#' @return ggplot2 object
#'
#' @keywords internal
plot_revenue_vs_profit <- function(gg_results, config) {

  library(ggplot2)

  revenue <- gg_results$revenue_curve
  optimal_revenue <- gg_results$optimal_price
  optimal_profit <- gg_results$optimal_price_profit
  currency <- config$currency_symbol %||% "$"

  # Filter to rows with profit data
  plot_data <- revenue[!is.na(revenue$profit_index), ]

  # Normalize both curves to 0-100 scale for comparison
  plot_data$revenue_norm <- (plot_data$revenue_index / max(plot_data$revenue_index, na.rm = TRUE)) * 100
  plot_data$profit_norm <- (plot_data$profit_index / max(plot_data$profit_index, na.rm = TRUE)) * 100

  # Reshape for ggplot
  plot_long <- data.frame(
    price = rep(plot_data$price, 2),
    value = c(plot_data$revenue_norm, plot_data$profit_norm),
    metric = rep(c("Revenue", "Profit"), each = nrow(plot_data)),
    stringsAsFactors = FALSE
  )

  p <- ggplot(plot_long, aes(x = price, y = value, color = metric)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 2.5) +
    scale_color_manual(values = c("Revenue" = "#2ECC71", "Profit" = "#9B59B6")) +
    labs(
      title = "Revenue vs Profit Optimization",
      subtitle = "Normalized to 100 = Maximum",
      x = sprintf("Price (%s)", currency),
      y = "Index (Normalized)",
      color = "Metric"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "gray40"),
      legend.position = "right",
      panel.grid.minor = element_blank()
    )

  # Mark optimal points
  if (!is.null(optimal_revenue)) {
    revenue_norm_val <- (optimal_revenue$revenue_index / max(plot_data$revenue_index, na.rm = TRUE)) * 100
    p <- p +
      geom_vline(xintercept = optimal_revenue$price, linetype = "dashed",
                 color = "#2ECC71", alpha = 0.6) +
      annotate("text", x = optimal_revenue$price, y = 95,
               label = sprintf("Rev Max\n%s%.2f", currency, optimal_revenue$price),
               size = 3, color = "#2ECC71", fontface = "bold", hjust = 0.5)
  }

  if (!is.null(optimal_profit)) {
    profit_norm_val <- (optimal_profit$profit_index / max(plot_data$profit_index, na.rm = TRUE)) * 100
    p <- p +
      geom_vline(xintercept = optimal_profit$price, linetype = "dashed",
                 color = "#9B59B6", alpha = 0.6) +
      annotate("text", x = optimal_profit$price, y = 85,
               label = sprintf("Profit Max\n%s%.2f", currency, optimal_profit$price),
               size = 3, color = "#9B59B6", fontface = "bold", hjust = 0.5)
  }

  return(p)
}


#' Save Plots to Files
#'
#' Saves plot objects to files in specified formats.
#'
#' @param plots List of plot objects
#' @param output_dir Directory to save plots
#' @param config Visualization configuration
#'
#' @return Vector of saved file paths
#'
#' @keywords internal
save_pricing_plots <- function(plots, output_dir, config) {

  if (length(plots) == 0) {
    return(character(0))
  }

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(character(0))
  }

  viz_config <- config$visualization %||% list()

  # Get export settings
  width <- as.numeric(viz_config$plot_width %||% 10)
  height <- as.numeric(viz_config$plot_height %||% 7)
  dpi <- as.numeric(viz_config$plot_dpi %||% 300)
  format <- viz_config$export_format %||% "png"

  # Create output directory if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  saved_files <- character(0)

  for (name in names(plots)) {
    filename <- file.path(output_dir, paste0(name, ".", format))

    tryCatch({
      ggplot2::ggsave(
        filename = filename,
        plot = plots[[name]],
        width = width,
        height = height,
        dpi = dpi
      )
      saved_files <- c(saved_files, filename)
    }, error = function(e) {
      warning(sprintf("Failed to save plot '%s': %s", name, e$message), call. = FALSE)
    })
  }

  return(saved_files)
}
