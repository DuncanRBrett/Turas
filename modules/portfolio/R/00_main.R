# ==============================================================================
# PORTFOLIO MODULE - MAIN ORCHESTRATION
# ==============================================================================
# Cross-category brand mapping for multi-category studies.
# Three sub-views, all from the same data:
#   1. Portfolio Map: focal brand position across categories
#   2. Priority Quadrants: Defend / Improve / Expand / Evaluate
#   3. Category TURF: optimal category combination for max consumer reach
#
# Requires 2+ categories. Consumes per-category outputs from brand module.
#
# VERSION: 1.0
#
# REFERENCES:
#   Sharp, B. (2010). How Brands Grow. (Category buyer behaviour)
# ==============================================================================

PORTFOLIO_VERSION <- "1.0"


#' Run Portfolio analysis
#'
#' Maps the focal brand's position across multiple categories. Requires
#' per-category metrics from the brand module (MMS, penetration, awareness).
#'
#' @param category_metrics Data frame. One row per category with columns:
#'   Category, Awareness_Pct, Penetration_Pct, MMS (optional),
#'   Category_Buyer_Base (optional).
#' @param focal_brand Character. Focal brand code.
#' @param category_penetration_matrix Matrix. n_resp x n_categories.
#'   Binary: did respondent buy in this category? For Category TURF.
#' @param run_category_turf Logical. Run Category TURF (default: TRUE).
#' @param turf_max_items Integer. Max categories for TURF (default: 10).
#' @param weights Numeric vector. Respondent weights (optional).
#' @param x_axis Character. Metric for X axis (default: "Penetration_Pct").
#' @param y_axis Character. Metric for Y axis (default: "MMS").
#'
#' @return List with:
#'   \item{status}{"PASS" or "REFUSED"}
#'   \item{portfolio_map}{Data frame with position per category}
#'   \item{priority_quadrants}{Data frame with quadrant classification}
#'   \item{category_turf}{TURF result (if run_category_turf = TRUE)}
#'   \item{metrics_summary}{Named list for AI annotations}
#'
#' @export
run_portfolio <- function(category_metrics,
                          focal_brand = NULL,
                          category_penetration_matrix = NULL,
                          run_category_turf = TRUE,
                          turf_max_items = 10,
                          weights = NULL,
                          x_axis = "Penetration_Pct",
                          y_axis = "MMS") {

  if (is.null(category_metrics) || nrow(category_metrics) < 2) {
    return(list(
      status = "REFUSED",
      code = "DATA_MIN_CATEGORIES",
      message = "Portfolio analysis requires 2+ categories"
    ))
  }

  n_cats <- nrow(category_metrics)
  categories <- category_metrics$Category

  # --- Portfolio Map ---
  # Just the metrics table with axes identified
  portfolio_map <- category_metrics
  portfolio_map$X_Value <- category_metrics[[x_axis]]
  portfolio_map$Y_Value <- if (y_axis %in% names(category_metrics)) {
    category_metrics[[y_axis]]
  } else {
    rep(NA_real_, n_cats)
  }

  # --- Priority Quadrants ---
  # Quadrant lines at medians
  x_median <- median(portfolio_map$X_Value, na.rm = TRUE)
  y_median <- median(portfolio_map$Y_Value, na.rm = TRUE)

  portfolio_map$Quadrant <- mapply(function(x, y) {
    if (is.na(x) || is.na(y)) return("Unclassified")
    high_x <- x >= x_median
    high_y <- y >= y_median
    if (high_x && high_y) return("Defend")
    if (high_x && !high_y) return("Improve")
    if (!high_x && high_y) return("Expand")
    "Evaluate"
  }, portfolio_map$X_Value, portfolio_map$Y_Value)

  portfolio_map$X_Median <- x_median
  portfolio_map$Y_Median <- y_median

  # --- Category TURF ---
  cat_turf <- NULL
  if (isTRUE(run_category_turf) && !is.null(category_penetration_matrix)) {

    # Source TURF engine if not loaded
    if (!exists("turf_from_binary", mode = "function")) {
      if (exists("find_turas_root", mode = "function")) {
        turf_path <- file.path(find_turas_root(), "modules", "shared",
                               "lib", "turf_engine.R")
        if (file.exists(turf_path)) source(turf_path, local = FALSE)
      }
    }

    if (exists("turf_from_binary", mode = "function")) {
      turf_items <- data.frame(
        Item_ID = categories,
        Item_Label = categories,
        stringsAsFactors = FALSE
      )

      cat_turf <- tryCatch(
        turf_from_binary(
          binary_matrix = category_penetration_matrix,
          items = turf_items,
          max_items = min(turf_max_items, n_cats),
          weights = weights,
          verbose = FALSE
        ),
        error = function(e) NULL
      )
    }
  }

  # --- Metrics Summary ---
  defend_cats <- portfolio_map$Category[portfolio_map$Quadrant == "Defend"]
  improve_cats <- portfolio_map$Category[portfolio_map$Quadrant == "Improve"]
  expand_cats <- portfolio_map$Category[portfolio_map$Quadrant == "Expand"]

  metrics_summary <- list(
    focal_brand = focal_brand,
    n_categories = n_cats,
    n_defend = length(defend_cats),
    n_improve = length(improve_cats),
    n_expand = length(expand_cats),
    n_evaluate = sum(portfolio_map$Quadrant == "Evaluate"),
    defend_categories = defend_cats,
    improve_categories = improve_cats,
    x_axis = x_axis,
    y_axis = y_axis,
    turf_reach_3 = if (!is.null(cat_turf) &&
                        nrow(cat_turf$incremental_table) >= 3) {
      cat_turf$incremental_table$Reach_Pct[3]
    } else NA_real_
  )

  list(
    status = "PASS",
    portfolio_map = portfolio_map,
    priority_quadrants = portfolio_map[, c("Category", "X_Value", "Y_Value",
                                           "Quadrant"), drop = FALSE],
    category_turf = cat_turf,
    metrics_summary = metrics_summary,
    n_categories = n_cats
  )
}


# ==============================================================================
# MODULE INITIALISATION
# ==============================================================================

if (!identical(Sys.getenv("TESTTHAT"), "true")) {
  message(sprintf("TURAS>Portfolio module loaded (v%s)", PORTFOLIO_VERSION))
}
