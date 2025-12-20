# ==============================================================================
# TURAS KEY DRIVER - SHAP INTERACTION ANALYSIS
# ==============================================================================
#
# Purpose: Analyze and visualize SHAP interactions between drivers
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Analyze SHAP Interactions
#'
#' Identifies and visualizes driver interactions.
#'
#' @param shp shapviz object with interactions
#' @param config Configuration parameters
#'
#' @return List with interaction results and plots
#' @keywords internal
analyze_shap_interactions <- function(shp, config) {

  # Check if interactions were calculated
  interactions <- tryCatch(
    shapviz::get_shap_interactions(shp),
    error = function(e) NULL
  )

  if (is.null(interactions)) {
    message("SHAP interactions not calculated. Set include_interactions = TRUE in config.")
    return(NULL)
  }

  top_n <- config$interaction_top_n %||% 10

  # Calculate interaction strength matrix
  interaction_matrix <- calculate_interaction_matrix(interactions)

  # Get top interaction pairs
  top_pairs <- get_top_interaction_pairs(interaction_matrix, top_n)

  # Create interaction plots for top features
  importance <- extract_importance(shp)
  top_features <- head(importance$driver, 5)

  plots <- list()

  for (v in top_features) {
    tryCatch({
      plots[[v]] <- shapviz::sv_dependence(
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
    }, error = function(e) {
      msg <- sprintf("SHAP interaction plot skipped for '%s': %s", v, conditionMessage(e))
      cat(sprintf("   [WARN] %s\n", msg))
      warning(msg, call. = FALSE)
    })
  }

  # Create heatmap of interaction strengths
  heatmap_plot <- create_interaction_heatmap(interaction_matrix, top_n)

  list(
    matrix = interaction_matrix,
    top_pairs = top_pairs,
    plots = plots,
    heatmap = heatmap_plot
  )
}


#' Calculate Interaction Strength Matrix
#'
#' Computes pairwise interaction strengths from SHAP interaction values.
#'
#' @param interactions 3D array of SHAP interactions (n_obs x n_features x n_features)
#' @return Matrix of mean absolute interaction values
#' @keywords internal
calculate_interaction_matrix <- function(interactions) {

  features <- dimnames(interactions)[[2]]
  n_features <- length(features)

  # Mean absolute interaction value for each pair
  mat <- matrix(0, n_features, n_features)
  rownames(mat) <- colnames(mat) <- features

  for (i in seq_len(n_features)) {
    for (j in seq_len(n_features)) {
      if (i != j) {
        mat[i, j] <- mean(abs(interactions[, i, j]))
      }
    }
  }

  mat
}


#' Get Top Interaction Pairs
#'
#' Identifies the strongest pairwise interactions.
#'
#' @param interaction_matrix Interaction strength matrix
#' @param top_n Number of top pairs to return
#' @return Data frame with top interaction pairs
#' @keywords internal
get_top_interaction_pairs <- function(interaction_matrix, top_n = 10) {

  features <- rownames(interaction_matrix)
  n <- length(features)

  # Extract upper triangle (avoid duplicates)
  pairs <- data.frame(
    feature_1 = character(),
    feature_2 = character(),
    interaction_strength = numeric(),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(n - 1)) {
    for (j in (i + 1):n) {
      pairs <- rbind(pairs, data.frame(
        feature_1 = features[i],
        feature_2 = features[j],
        interaction_strength = interaction_matrix[i, j],
        stringsAsFactors = FALSE
      ))
    }
  }

  # Sort by interaction strength
  pairs <- pairs[order(-pairs$interaction_strength), ]

  # Return top N
  head(pairs, top_n)
}


#' Create Interaction Heatmap
#'
#' Creates a heatmap visualization of interaction strengths.
#'
#' @param interaction_matrix Interaction strength matrix
#' @param top_n Number of top features to include
#' @return ggplot object
#' @keywords internal
create_interaction_heatmap <- function(interaction_matrix, top_n = 10) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    return(NULL)
  }

  # Get top features by row sum (overall interaction strength)
  row_sums <- rowSums(interaction_matrix)
  top_features <- names(sort(row_sums, decreasing = TRUE))[seq_len(min(top_n, length(row_sums)))]

  # Subset matrix
  mat_subset <- interaction_matrix[top_features, top_features]

  # Convert to long format
  long_data <- data.frame(
    feature_1 = rep(rownames(mat_subset), ncol(mat_subset)),
    feature_2 = rep(colnames(mat_subset), each = nrow(mat_subset)),
    strength = as.vector(mat_subset),
    stringsAsFactors = FALSE
  )

  # Remove diagonal
  long_data <- long_data[long_data$feature_1 != long_data$feature_2, ]

  # Create heatmap
  p <- ggplot2::ggplot(
    long_data,
    ggplot2::aes(x = feature_1, y = feature_2, fill = strength)
  ) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::scale_fill_gradient2(
      low = "#FFFFFF",
      mid = "#FFC000",
      high = "#E74C3C",
      midpoint = median(long_data$strength),
      name = "Interaction\nStrength"
    ) +
    ggplot2::labs(
      title = "SHAP Interaction Strengths",
      subtitle = "Darker colors indicate stronger interactions",
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 9),
      axis.text.y = ggplot2::element_text(size = 9),
      panel.grid = ggplot2::element_blank()
    )

  p
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
