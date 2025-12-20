# ==============================================================================
# TURAS KEY DRIVER - SHAP VISUALIZATIONS
# ==============================================================================
#
# Purpose: Generate SHAP visualization plots using shapviz
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Generate All SHAP Plots
#'
#' Creates standard suite of SHAP visualizations.
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#'
#' @return Named list of ggplot objects
#' @keywords internal
generate_shap_plots <- function(shp, config) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' required for SHAP plots. Install with: install.packages('ggplot2')",
         call. = FALSE)
  }

  plots <- list()

  # 1. Importance Bar Plot
  plots$importance_bar <- create_importance_bar(shp, config)

  # 2. Beeswarm Plot (SHAP summary)
  plots$importance_beeswarm <- create_beeswarm(shp, config)

  # 3. Combined Importance Plot
  plots$importance_combined <- create_importance_combined(shp, config)

  # 4. Dependence Plots (top drivers)
  plots$dependence <- create_dependence_plots(shp, config)

  # 5. Waterfall Plots (individual explanations)
  plots$waterfalls <- create_waterfall_plots(shp, config)

  # 6. Force Plots (alternative individual view)
  plots$force <- create_force_plots(shp, config)

  # 7. Interaction Plot (if enabled and available)
  shap_interactions <- tryCatch(
    shapviz::get_shap_interactions(shp),
    error = function(e) NULL
  )
  if (!is.null(shap_interactions)) {
    plots$interactions <- create_interaction_plot(shp, config)
  }

  plots
}


#' Create Importance Bar Plot
#'
#' Bar chart showing mean |SHAP| for each driver.
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#' @return ggplot object
#' @keywords internal
create_importance_bar <- function(shp, config) {

  top_n <- config$importance_top_n %||% 15
  show_numbers <- config$show_numbers %||% TRUE

  p <- shapviz::sv_importance(
    shp,
    kind = "bar",
    max_display = top_n,
    show_numbers = show_numbers
  ) +
    ggplot2::labs(
      title = "Driver Importance (SHAP)",
      subtitle = "Mean absolute SHAP value",
      x = "Mean |SHAP|",
      y = NULL
    ) +
    turas_theme()

  p
}


#' Create Beeswarm Plot
#'
#' Summary plot showing SHAP value distribution for each driver.
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#' @return ggplot object
#' @keywords internal
create_beeswarm <- function(shp, config) {

  top_n <- config$importance_top_n %||% 15

  p <- shapviz::sv_importance(
    shp,
    kind = "beeswarm",
    max_display = top_n,
    viridis_args = list(option = "D")  # Colorblind-friendly
  ) +
    ggplot2::labs(
      title = "SHAP Summary Plot",
      subtitle = "Distribution of SHAP values by driver",
      x = "SHAP Value (impact on prediction)",
      y = NULL
    ) +
    turas_theme()

  p
}


#' Create Combined Importance Plot
#'
#' Bar + beeswarm overlay for maximum information.
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#' @return ggplot object
#' @keywords internal
create_importance_combined <- function(shp, config) {

  top_n <- config$importance_top_n %||% 15

  p <- shapviz::sv_importance(
    shp,
    kind = "both",
    max_display = top_n,
    show_numbers = TRUE,
    viridis_args = list(option = "D")
  ) +
    ggplot2::labs(
      title = "Key Driver Importance (SHAP Analysis)",
      subtitle = "Bar = mean |SHAP|, points = individual SHAP values",
      x = "SHAP Value",
      y = NULL
    ) +
    turas_theme()

  p
}


#' Create Dependence Plots
#'
#' Scatter plots showing relationship between driver value and SHAP.
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#' @return List with individual plots and combined grid
#' @keywords internal
create_dependence_plots <- function(shp, config) {

  if (!requireNamespace("patchwork", quietly = TRUE)) {
    warning("Package 'patchwork' not available. Returning individual plots only.")
    return(list(individual = list(), combined = NULL))
  }

  top_n <- config$dependence_top_n %||% 6

  # Get top drivers by importance
  importance <- extract_importance(shp)
  top_drivers <- head(importance$driver, top_n)

  # Create dependence plot for each
  plots <- list()

  for (driver in top_drivers) {
    tryCatch({
      p <- shapviz::sv_dependence(
        shp,
        v = driver,
        color_var = "auto",  # Auto-detect best interaction
        alpha = 0.5
      ) +
        ggplot2::labs(
          title = paste("SHAP Dependence:", driver),
          x = driver,
          y = "SHAP Value"
        ) +
        turas_theme()

      plots[[driver]] <- p
    }, error = function(e) {
      warning(sprintf("Could not create dependence plot for %s: %s", driver, e$message))
    })
  }

  # Combine into grid
  combined <- NULL
  if (length(plots) > 0) {
    tryCatch({
      combined <- patchwork::wrap_plots(plots, ncol = 2)
    }, error = function(e) {
      warning(sprintf("Could not combine dependence plots: %s", e$message))
    })
  }

  list(
    individual = plots,
    combined = combined
  )
}


#' Create Waterfall Plots
#'
#' Individual prediction explanations showing driver contributions.
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#' @return Named list of ggplot objects
#' @keywords internal
create_waterfall_plots <- function(shp, config) {

  n_examples <- config$n_waterfall_examples %||% 5
  selection <- config$waterfall_selection %||% "extreme"

  # Get row indices based on selection strategy
  shap_values <- shapviz::get_shap_values(shp)
  row_sums <- rowSums(shap_values)

  idx <- switch(selection,
    "extreme" = {
      # Highest and lowest predictions
      n_high <- ceiling(n_examples / 2)
      n_low <- floor(n_examples / 2)
      c(
        order(row_sums, decreasing = TRUE)[seq_len(n_high)],
        order(row_sums, decreasing = FALSE)[seq_len(n_low)]
      )
    },
    "random" = sample(nrow(shap_values), min(n_examples, nrow(shap_values))),
    "first" = seq_len(min(n_examples, nrow(shap_values)))
  )

  # Create waterfall for each
  plots <- list()
  baseline <- get_shap_baseline(shp)

  for (i in idx) {
    tryCatch({
      p <- shapviz::sv_waterfall(shp, row_id = i) +
        ggplot2::labs(
          title = paste("Respondent", i),
          subtitle = paste(
            "Prediction:",
            round(baseline + sum(shap_values[i, ]), 2)
          )
        ) +
        turas_theme()

      plots[[paste0("respondent_", i)]] <- p
    }, error = function(e) {
      warning(sprintf("Could not create waterfall plot for row %d: %s", i, e$message))
    })
  }

  plots
}


#' Create Force Plots
#'
#' Compact horizontal visualization of individual predictions.
#'
#' @param shp shapviz object
#' @param config Configuration parameters
#' @return Named list of ggplot objects
#' @keywords internal
create_force_plots <- function(shp, config) {

  n_examples <- config$n_force_examples %||% 5

  # Use extreme predictions
  shap_values <- shapviz::get_shap_values(shp)
  row_sums <- rowSums(shap_values)
  idx <- order(row_sums, decreasing = TRUE)[seq_len(min(n_examples, nrow(shap_values)))]

  plots <- list()

  for (i in idx) {
    tryCatch({
      p <- shapviz::sv_force(shp, row_id = i) +
        turas_theme()

      plots[[paste0("respondent_", i)]] <- p
    }, error = function(e) {
      warning(sprintf("Could not create force plot for row %d: %s", i, e$message))
    })
  }

  plots
}


#' Create Interaction Plot
#'
#' Visualizes top driver interactions.
#'
#' @param shp shapviz object with interactions
#' @param config Configuration parameters
#' @return List with interaction plots
#' @keywords internal
create_interaction_plot <- function(shp, config) {

  # Get top features
  importance <- extract_importance(shp)
  top_features <- head(importance$driver, 5)

  plots <- list()

  for (v in top_features) {
    tryCatch({
      p <- shapviz::sv_dependence(
        shp,
        v = v,
        color_var = "auto",
        interactions = TRUE
      ) +
        ggplot2::labs(
          title = paste("Interaction:", v),
          subtitle = "Color indicates strongest interacting variable"
        ) +
        turas_theme()

      plots[[v]] <- p
    }, error = function(e) {
      msg <- sprintf("SHAP interaction dependence plot skipped for '%s': %s", v, conditionMessage(e))
      cat(sprintf("   [WARN] %s\n", msg))
      warning(msg, call. = FALSE)
    })
  }

  plots
}


#' Turas ggplot2 Theme
#'
#' Consistent styling for all Turas visualizations.
#'
#' @return ggplot2 theme object
#' @export
turas_theme <- function() {

  ggplot2::theme_minimal() +
    ggplot2::theme(
      # Text
      text = ggplot2::element_text(family = "sans"),
      plot.title = ggplot2::element_text(
        size = 14,
        face = "bold",
        hjust = 0
      ),
      plot.subtitle = ggplot2::element_text(
        size = 11,
        color = "gray40",
        hjust = 0
      ),
      axis.title = ggplot2::element_text(size = 10),
      axis.text = ggplot2::element_text(size = 9),

      # Legend
      legend.position = "bottom",
      legend.title = ggplot2::element_text(size = 10),
      legend.text = ggplot2::element_text(size = 9),

      # Grid
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = "gray90"),

      # Plot margins
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    )
}


#' Turas Color Palette
#'
#' Colorblind-friendly palette for categorical data.
#'
#' @param n Number of colors needed
#' @return Vector of color codes
#' @export
turas_colors <- function(n = 8) {
  if (requireNamespace("viridis", quietly = TRUE)) {
    viridis::viridis(n, option = "D")
  } else {
    # Fallback palette
    grDevices::colorRampPalette(c("#4472C4", "#ED7D31", "#A5A5A5", "#FFC000", "#5B9BD5"))(n)
  }
}


#' Turas Diverging Color Palette
#'
#' For SHAP values (negative to positive).
#'
#' @return Named vector of colors
#' @export
turas_diverging <- function() {
  c(
    negative = "#2166AC",  # Blue
    neutral = "#F7F7F7",   # White
    positive = "#B2182B"   # Red
  )
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
