# ==============================================================================
# TURAS KEY DRIVER - SHAP VALUE CALCULATION
# ==============================================================================
#
# Purpose: Calculate SHAP values using TreeSHAP for XGBoost models
# Version: Turas v10.1
# Date: 2025-12
#
# ==============================================================================

#' Prepare Data for SHAP Analysis
#'
#' Handles missing data, encoding, and weight application for XGBoost/SHAP.
#'
#' @param data Data frame with outcome and driver variables
#' @param outcome Character. Name of outcome variable
#' @param drivers Character vector. Names of driver variables
#' @param weights Character. Name of weight variable (optional)
#'
#' @return List with:
#'   - X: Feature matrix (numeric)
#'   - y: Outcome vector
#'   - w: Weight vector (or NULL)
#'   - X_display: Original features for display
#'   - feature_map: Mapping from encoded to original names
#' @keywords internal
prepare_shap_data <- function(data, outcome, drivers, weights = NULL) {

  # Extract outcome
  y <- data[[outcome]]

  # Handle weights
  w <- if (!is.null(weights) && weights %in% names(data)) {
    data[[weights]]
  } else {
    NULL
  }

  # Subset to drivers
  X_raw <- data[, drivers, drop = FALSE]

  # Store original for display (shapviz can handle factors)
  X_display <- X_raw

  # Convert to numeric matrix for XGBoost
  X_numeric <- encode_features(X_raw)

  # Create feature map for collapsing dummy variables later
  feature_map <- create_feature_map(X_raw, X_numeric)

  list(
    X = as.matrix(X_numeric),
    y = y,
    w = w,
    X_display = X_display,
    feature_map = feature_map,
    driver_names = drivers
  )
}


#' Encode Features for XGBoost
#'
#' Converts factors and characters to numeric. XGBoost requires numeric input.
#' Uses ordinal encoding for ordered factors, one-hot for unordered.
#'
#' @param X Data frame of features
#' @return Data frame with all numeric columns
#' @keywords internal
encode_features <- function(X) {

  X_encoded <- X
  cols_to_remove <- character(0)
  new_cols <- list()

  for (col in names(X)) {
    if (is.factor(X[[col]]) || is.character(X[[col]])) {
      if (is.ordered(X[[col]])) {
        # Ordinal: convert to integer
        X_encoded[[col]] <- as.integer(X[[col]])
      } else if (is.character(X[[col]])) {
        # Convert character to factor then to integer
        X_encoded[[col]] <- as.integer(as.factor(X[[col]]))
      } else {
        # Nominal factor: one-hot encode
        dummies <- stats::model.matrix(~ . - 1, data = X[, col, drop = FALSE])
        cols_to_remove <- c(cols_to_remove, col)
        for (j in seq_len(ncol(dummies))) {
          new_col_name <- colnames(dummies)[j]
          new_cols[[new_col_name]] <- dummies[, j]
        }
      }
    } else if (!is.numeric(X[[col]])) {
      # Try to convert to numeric
      X_encoded[[col]] <- as.numeric(X[[col]])
    }
  }

  # Remove original factor columns and add dummies
  if (length(cols_to_remove) > 0) {
    X_encoded <- X_encoded[, !names(X_encoded) %in% cols_to_remove, drop = FALSE]
  }

  if (length(new_cols) > 0) {
    for (nm in names(new_cols)) {
      X_encoded[[nm]] <- new_cols[[nm]]
    }
  }

  X_encoded
}


#' Create Feature Map for Collapsing Dummy Variables
#'
#' Creates a mapping to collapse one-hot encoded dummies back to original features.
#'
#' @param X_raw Original data frame
#' @param X_encoded Encoded data frame
#' @return Named list mapping encoded names to original names, or NULL if no mapping needed
#' @keywords internal
create_feature_map <- function(X_raw, X_encoded) {

  # If no new columns were added, no mapping needed
  if (ncol(X_encoded) == ncol(X_raw)) {
    return(NULL)
  }

  # Build mapping
  feature_map <- list()

  for (col in names(X_raw)) {
    if (is.factor(X_raw[[col]]) && !is.ordered(X_raw[[col]])) {
      # Find dummy columns for this factor
      dummy_pattern <- paste0("^", col)
      matches <- grep(dummy_pattern, names(X_encoded), value = TRUE)
      if (length(matches) > 0) {
        for (m in matches) {
          feature_map[[m]] <- col
        }
      }
    }
  }

  if (length(feature_map) == 0) {
    return(NULL)
  }

  feature_map
}


#' Calculate SHAP Values
#'
#' Uses TreeSHAP for fast, exact SHAP value computation.
#' Creates shapviz object for visualization.
#'
#' @param model Fitted XGBoost model
#' @param prep Prepared data from prepare_shap_data()
#' @param config Configuration parameters
#'
#' @return shapviz object
#' @keywords internal
calculate_shap_values <- function(model, prep, config) {

  if (!requireNamespace("shapviz", quietly = TRUE)) {
    stop("Package 'shapviz' required for SHAP visualization. Install with: install.packages('shapviz')",
         call. = FALSE)
  }

  # Sample data if too large
  n <- nrow(prep$X)
  max_n <- config$shap_sample_size %||% 1000

  if (n > max_n) {
    set.seed(42)  # For reproducibility
    idx <- sample(n, max_n)
    X_explain <- prep$X[idx, , drop = FALSE]
    X_display <- prep$X_display[idx, , drop = FALSE]
    message(sprintf("Sampled %d of %d observations for SHAP calculation", max_n, n))
  } else {
    idx <- seq_len(n)
    X_explain <- prep$X
    X_display <- prep$X_display
  }

  # Calculate SHAP values with interactions if requested
  include_interactions <- isTRUE(config$include_interactions)

  # Create shapviz object
  shp <- shapviz::shapviz(
    object = model,
    X_pred = X_explain,
    X = X_display,
    collapse = prep$feature_map,
    interactions = include_interactions
  )

  # Store sample indices for reference
  attr(shp, "sample_indices") <- idx

  shp
}


#' Extract Importance from shapviz Object
#'
#' Calculates mean |SHAP| importance scores.
#'
#' @param shp shapviz object
#' @return Data frame with driver, importance, and statistics
#' @keywords internal
extract_importance <- function(shp) {

  shap_values <- shapviz::get_shap_values(shp)

  # Mean absolute SHAP value for each feature
  mean_abs_shap <- colMeans(abs(shap_values))

  # Additional statistics
  std_shap <- apply(shap_values, 2, sd)
  min_shap <- apply(shap_values, 2, min)
  max_shap <- apply(shap_values, 2, max)

  # Create importance data frame
  importance <- data.frame(
    driver = names(mean_abs_shap),
    mean_shap = as.numeric(mean_abs_shap),
    std_shap = as.numeric(std_shap),
    min_shap = as.numeric(min_shap),
    max_shap = as.numeric(max_shap),
    stringsAsFactors = FALSE
  )

  # Calculate percentage importance
  total_importance <- sum(importance$mean_shap)
  if (total_importance > 0) {
    importance$importance_pct <- importance$mean_shap / total_importance * 100
  } else {
    importance$importance_pct <- 0
  }

  # Add rank
  importance$rank <- rank(-importance$mean_shap, ties.method = "min")

  # Sort by importance
  importance <- importance[order(-importance$mean_shap), ]
  rownames(importance) <- NULL

  importance
}


#' Get Baseline (Expected Value) from shapviz
#'
#' @param shp shapviz object
#' @return Numeric baseline value
#' @keywords internal
get_shap_baseline <- function(shp) {
  shapviz::get_baseline(shp)
}


#' Null-coalescing operator (if not already defined)
#' @keywords internal
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
