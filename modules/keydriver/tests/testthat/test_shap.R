# ==============================================================================
# TEST SUITE: SHAP Submodule
# ==============================================================================
# Tests for SHAP model fitting, value calculation, importance extraction,
# interaction analysis, segment analysis, visualization, and Excel export.
# ==============================================================================

library(testthat)

context("SHAP Submodule")

# ==============================================================================
# SETUP
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# module_dir and project_root are provided by helper-paths.R

# Load TRS refusal system
tryCatch({
  source(file.path(project_root, "modules", "shared", "lib", "trs_refusal.R"))
}, error = function(e) skip(paste("Cannot load TRS:", conditionMessage(e))))

# Load guard (provides keydriver_refuse)
tryCatch({
  source(file.path(module_dir, "R", "00_guard.R"))
}, error = function(e) skip(paste("Cannot load guard:", conditionMessage(e))))

# Source SHAP submodule files
shap_files <- c(
  file.path(module_dir, "R", "kda_shap", "shap_calculate.R"),
  file.path(module_dir, "R", "kda_shap", "shap_model.R"),
  file.path(module_dir, "R", "kda_shap", "shap_visualize.R"),
  file.path(module_dir, "R", "kda_shap", "shap_segment.R"),
  file.path(module_dir, "R", "kda_shap", "shap_interaction.R"),
  file.path(module_dir, "R", "kda_shap", "shap_export.R"),
  file.path(module_dir, "R", "kda_methods", "method_shap.R")
)

for (f in shap_files) {
  if (file.exists(f)) {
    tryCatch(
      source(f),
      error = function(e) skip(paste("Cannot load", basename(f), ":", conditionMessage(e)))
    )
  }
}


# Helper: generate synthetic survey data for SHAP tests
make_shap_test_data <- function(n = 200, n_drivers = 5, seed = 42) {
  set.seed(seed)
  drivers <- matrix(rnorm(n * n_drivers), nrow = n, ncol = n_drivers)
  colnames(drivers) <- paste0("Q", seq_len(n_drivers))
  # Q1 strongest effect, diminishing to Q5
  betas <- seq(0.5, 0.1, length.out = n_drivers)
  y <- as.numeric(drivers %*% betas + rnorm(n, sd = 0.5))
  df <- as.data.frame(cbind(satisfaction = y, drivers))
  # Add weight column
  df$wt <- pmax(0.3, pmin(3.0, rlnorm(n, meanlog = 0, sdlog = 0.3)))
  # Add segment column
  df$segment <- sample(c("High", "Low"), n, replace = TRUE)
  df
}

make_shap_config <- function(n_trees = 50, include_interactions = FALSE) {
  list(
    n_trees = n_trees,
    max_depth = 4,
    learning_rate = 0.1,
    subsample = 0.8,
    colsample_bytree = 0.8,
    shap_sample_size = 500,
    include_interactions = include_interactions,
    importance_top_n = 5,
    dependence_top_n = 3,
    n_waterfall_examples = 3,
    n_force_examples = 3,
    waterfall_selection = "extreme",
    show_numbers = TRUE,
    cv_nfold = 3,
    early_stopping_rounds = 10
  )
}


# ==============================================================================
# DATA PREPARATION TESTS
# ==============================================================================

test_that("prepare_shap_data: returns correct structure with numeric data", {
  skip_if_not(exists("prepare_shap_data", mode = "function"),
              "prepare_shap_data not found")

  data <- make_shap_test_data(n = 100)
  drivers <- paste0("Q", 1:5)

  prep <- prepare_shap_data(data, "satisfaction", drivers, weights = "wt")

  expect_true(is.matrix(prep$X))
  expect_equal(nrow(prep$X), 100)
  expect_equal(ncol(prep$X), 5)
  expect_equal(length(prep$y), 100)
  expect_equal(length(prep$w), 100)
  expect_true(is.data.frame(prep$X_display))
  expect_equal(prep$driver_names, drivers)
})

test_that("prepare_shap_data: handles NULL weights gracefully", {
  skip_if_not(exists("prepare_shap_data", mode = "function"),
              "prepare_shap_data not found")

  data <- make_shap_test_data(n = 50)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5), weights = NULL)

  expect_null(prep$w)
  expect_equal(nrow(prep$X), 50)
})

test_that("encode_features: converts factors to numeric", {
  skip_if_not(exists("encode_features", mode = "function"),
              "encode_features not found")

  df <- data.frame(
    num_col = c(1.0, 2.0, 3.0, 4.0),
    char_col = c("a", "b", "a", "b"),
    stringsAsFactors = FALSE
  )

  encoded <- encode_features(df)

  expect_true(all(sapply(encoded, is.numeric)))
  expect_equal(nrow(encoded), 4)
})


# ==============================================================================
# DETECT OBJECTIVE / METRIC TESTS
# ==============================================================================

test_that("detect_objective: identifies continuous outcome", {
  skip_if_not(exists("detect_objective", mode = "function"),
              "detect_objective not found")

  expect_equal(detect_objective(c(1.2, 3.4, 5.6)), "reg:squarederror")
})

test_that("detect_objective: identifies binary 0/1 outcome", {
  skip_if_not(exists("detect_objective", mode = "function"),
              "detect_objective not found")

  expect_equal(detect_objective(c(0, 1, 0, 1, 1)), "binary:logistic")
})

test_that("detect_metric: returns rmse for continuous", {
  skip_if_not(exists("detect_metric", mode = "function"),
              "detect_metric not found")

  expect_equal(detect_metric(c(1.0, 2.5, 3.7)), "rmse")
})

test_that("detect_metric: returns logloss for binary", {
  skip_if_not(exists("detect_metric", mode = "function"),
              "detect_metric not found")

  expect_equal(detect_metric(c(0, 1, 0, 1)), "logloss")
})


# ==============================================================================
# MODEL FITTING TESTS
# ==============================================================================

test_that("fit_shap_model: fits XGBoost model successfully", {
  skip_if_not_installed("xgboost")
  skip_if_not(exists("fit_shap_model", mode = "function"),
              "fit_shap_model not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)

  model <- fit_shap_model(prep, config)

  expect_true(inherits(model, "xgb.Booster"))
  expect_true(!is.null(attr(model, "best_iteration")))
  expect_true(attr(model, "best_iteration") > 0)
})

test_that("fit_shap_model: works with weighted data", {
  skip_if_not_installed("xgboost")
  skip_if_not(exists("fit_shap_model", mode = "function"),
              "fit_shap_model not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5), weights = "wt")
  config <- make_shap_config(n_trees = 30)

  model <- fit_shap_model(prep, config)

  expect_true(inherits(model, "xgb.Booster"))
})

test_that("model_diagnostics: returns expected statistics", {
  skip_if_not_installed("xgboost")
  skip_if_not(exists("model_diagnostics", mode = "function"),
              "model_diagnostics not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)
  model <- fit_shap_model(prep, config)

  diag <- model_diagnostics(model, prep)

  expect_equal(diag$model_type, "XGBoost")
  expect_true(is.numeric(diag$r_squared))
  expect_true(is.numeric(diag$rmse))
  expect_true(is.numeric(diag$mae))
  expect_equal(diag$sample_size, 150)
  expect_true(diag$r_squared > 0, info = "R-squared should be positive for structured data")
})


# ==============================================================================
# SHAP VALUE CALCULATION TESTS
# ==============================================================================

test_that("calculate_shap_values: returns shapviz object", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  skip_if_not(exists("calculate_shap_values", mode = "function"),
              "calculate_shap_values not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)
  model <- fit_shap_model(prep, config)

  shp <- calculate_shap_values(model, prep, config)

  expect_true(inherits(shp, "shapviz"))
})

test_that("extract_importance: returns ranked importance data frame", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  skip_if_not(exists("extract_importance", mode = "function"),
              "extract_importance not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)
  model <- fit_shap_model(prep, config)
  shp <- calculate_shap_values(model, prep, config)

  importance <- extract_importance(shp)

  expect_true(is.data.frame(importance))
  expect_true(all(c("driver", "mean_shap", "importance_pct", "rank") %in% names(importance)))
  expect_equal(nrow(importance), 5)
  # Importance percentages should sum to 100
  expect_equal(sum(importance$importance_pct), 100, tolerance = 0.1)
  # Rank 1 should be first row (sorted by importance)
  expect_equal(importance$rank[1], 1)
  # Q1 should be near the top (strongest beta)
  top3 <- importance$driver[1:3]
  expect_true("Q1" %in% top3,
              info = paste("Q1 (strongest driver) should be in top 3, got:", paste(top3, collapse = ", ")))
})

test_that("get_shap_baseline: returns numeric value", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  skip_if_not(exists("get_shap_baseline", mode = "function"),
              "get_shap_baseline not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)
  model <- fit_shap_model(prep, config)
  shp <- calculate_shap_values(model, prep, config)

  baseline <- get_shap_baseline(shp)

  expect_true(is.numeric(baseline))
  expect_equal(length(baseline), 1)
})


# ==============================================================================
# VISUALIZATION TESTS
# ==============================================================================

test_that("generate_shap_plots: returns named list of plot types", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  skip_if_not_installed("ggplot2")
  skip_if_not(exists("generate_shap_plots", mode = "function"),
              "generate_shap_plots not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)
  model <- fit_shap_model(prep, config)
  shp <- calculate_shap_values(model, prep, config)

  plots <- generate_shap_plots(shp, config)

  expect_true(is.list(plots))
  expect_true("importance_bar" %in% names(plots))
  expect_true("importance_beeswarm" %in% names(plots))
  expect_true("importance_combined" %in% names(plots))
  # Check the bar plot is a ggplot object
  expect_true(inherits(plots$importance_bar, "ggplot"))
})

test_that("turas_theme: returns a ggplot2 theme object", {
  skip_if_not_installed("ggplot2")
  skip_if_not(exists("turas_theme", mode = "function"),
              "turas_theme not found")

  theme <- turas_theme()
  expect_true(inherits(theme, "theme"))
})


# ==============================================================================
# SEGMENT ANALYSIS TESTS
# ==============================================================================

test_that("run_segment_shap: analyzes segments and returns results", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  skip_if_not_installed("ggplot2")
  skip_if_not(exists("run_segment_shap", mode = "function"),
              "run_segment_shap not found")

  data <- make_shap_test_data(n = 200)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)
  model <- fit_shap_model(prep, config)
  shp <- calculate_shap_values(model, prep, config)

  segments <- data.frame(
    segment_name = c("High", "Low"),
    segment_variable = c("segment", "segment"),
    segment_values = c("High", "Low"),
    stringsAsFactors = FALSE
  )

  results <- run_segment_shap(shp, data, segments)

  expect_true(is.list(results))
  expect_true("High" %in% names(results))
  expect_true("Low" %in% names(results))
  # Each segment should have importance and n
  expect_true(results[["High"]]$n > 0)
  expect_true(is.data.frame(results[["High"]]$importance))
  # Comparison should exist with 2 segments
  expect_true("comparison" %in% names(results))
})

test_that("run_segment_shap: skips segment with missing variable", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  skip_if_not_installed("ggplot2")
  skip_if_not(exists("run_segment_shap", mode = "function"),
              "run_segment_shap not found")

  data <- make_shap_test_data(n = 150)
  prep <- prepare_shap_data(data, "satisfaction", paste0("Q", 1:5))
  config <- make_shap_config(n_trees = 30)
  model <- fit_shap_model(prep, config)
  shp <- calculate_shap_values(model, prep, config)

  segments <- data.frame(
    segment_name = c("GroupA"),
    segment_variable = c("nonexistent_var"),
    segment_values = c("A"),
    stringsAsFactors = FALSE
  )

  # Should not error, just skip the segment
  results <- run_segment_shap(shp, data, segments)
  expect_true(is.list(results))
  expect_false("GroupA" %in% names(results))
})


# ==============================================================================
# INTERACTION ANALYSIS TESTS
# ==============================================================================

test_that("calculate_interaction_matrix: returns square matrix", {
  skip_if_not(exists("calculate_interaction_matrix", mode = "function"),
              "calculate_interaction_matrix not found")

  # Simulate a 3D interaction array (10 obs, 3 features, 3 features)
  n <- 10
  feats <- c("Q1", "Q2", "Q3")
  interactions <- array(rnorm(n * 3 * 3), dim = c(n, 3, 3),
                        dimnames = list(NULL, feats, feats))

  mat <- calculate_interaction_matrix(interactions)

  expect_true(is.matrix(mat))
  expect_equal(nrow(mat), 3)
  expect_equal(ncol(mat), 3)
  expect_equal(rownames(mat), feats)
  # Diagonal should be zero
  expect_equal(unname(diag(mat)), c(0, 0, 0))
})

test_that("get_top_interaction_pairs: returns ranked pairs data frame", {
  skip_if_not(exists("get_top_interaction_pairs", mode = "function"),
              "get_top_interaction_pairs not found")

  mat <- matrix(c(0, 0.5, 0.3, 0.5, 0, 0.1, 0.3, 0.1, 0),
                nrow = 3, ncol = 3,
                dimnames = list(c("Q1", "Q2", "Q3"), c("Q1", "Q2", "Q3")))

  pairs <- get_top_interaction_pairs(mat, top_n = 3)

  expect_true(is.data.frame(pairs))
  expect_true(all(c("feature_1", "feature_2", "interaction_strength") %in% names(pairs)))
  expect_true(nrow(pairs) == 3)
  # First pair should be the strongest interaction
  expect_equal(pairs$interaction_strength[1], 0.5)
})


# ==============================================================================
# EXCEL EXPORT TESTS
# ==============================================================================

test_that("export_shap_to_excel: creates workbook with expected sheets", {
  skip_if_not_installed("openxlsx")
  skip_if_not(exists("export_shap_to_excel", mode = "function"),
              "export_shap_to_excel not found")

  # Build a mock shap_results object
  mock_results <- list(
    importance = data.frame(
      driver = c("Q1", "Q2", "Q3"),
      mean_shap = c(0.5, 0.3, 0.1),
      std_shap = c(0.1, 0.08, 0.05),
      min_shap = c(-0.2, -0.1, -0.05),
      max_shap = c(1.0, 0.6, 0.3),
      importance_pct = c(55.6, 33.3, 11.1),
      rank = c(1, 2, 3),
      stringsAsFactors = FALSE
    ),
    diagnostics = list(
      model_type = "XGBoost",
      n_trees = 50,
      r_squared = 0.85,
      rmse = 0.42,
      mae = 0.33,
      cv_best_score = 0.45,
      sample_size = 200
    ),
    segments = NULL,
    interactions = NULL
  )

  wb <- export_shap_to_excel(mock_results, wb = NULL, output_file = NULL)

  expect_true(inherits(wb, "Workbook"))
  sheets <- openxlsx::sheets(wb)
  expect_true("SHAP_Importance" %in% sheets)
  expect_true("SHAP_Model_Diagnostics" %in% sheets)
})

test_that("export_shap_to_excel: saves to file when output_file provided", {
  skip_if_not_installed("openxlsx")
  skip_if_not(exists("export_shap_to_excel", mode = "function"),
              "export_shap_to_excel not found")

  mock_results <- list(
    importance = data.frame(
      driver = "Q1", mean_shap = 0.5, std_shap = 0.1,
      min_shap = -0.1, max_shap = 0.9, importance_pct = 100, rank = 1,
      stringsAsFactors = FALSE
    ),
    diagnostics = list(
      model_type = "XGBoost", n_trees = 10, r_squared = 0.7,
      rmse = 0.5, mae = 0.4, cv_best_score = 0.6, sample_size = 50
    ),
    segments = NULL,
    interactions = NULL
  )

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  export_shap_to_excel(mock_results, wb = NULL, output_file = tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})


# ==============================================================================
# VALIDATION / ERROR HANDLING TESTS
# ==============================================================================

test_that("validate_shap_inputs: refuses when outcome not in data", {
  skip_if_not(exists("validate_shap_inputs", mode = "function"),
              "validate_shap_inputs not found")

  data <- make_shap_test_data(n = 50)

  result <- tryCatch(
    validate_shap_inputs(data, "nonexistent_outcome", paste0("Q", 1:5), NULL),
    turas_refusal = function(cond) cond,
    error = function(e) e
  )

  # Should be a TRS refusal (condition or error with code)
  expect_true(
    inherits(result, "turas_refusal") ||
    (inherits(result, "error") && grepl("OUTCOME_NOT_FOUND|not found", result$message, ignore.case = TRUE))
  )
})

test_that("validate_shap_inputs: refuses when drivers not in data", {
  skip_if_not(exists("validate_shap_inputs", mode = "function"),
              "validate_shap_inputs not found")

  data <- make_shap_test_data(n = 50)

  result <- tryCatch(
    validate_shap_inputs(data, "satisfaction", c("Q1", "MISSING_VAR"), NULL),
    turas_refusal = function(cond) cond,
    error = function(e) e
  )

  expect_true(
    inherits(result, "turas_refusal") ||
    (inherits(result, "error") && grepl("DRIVERS_NOT_FOUND|not found", result$message, ignore.case = TRUE))
  )
})

test_that("validate_shap_inputs: refuses on zero-variance outcome", {
  skip_if_not(exists("validate_shap_inputs", mode = "function"),
              "validate_shap_inputs not found")

  data <- data.frame(satisfaction = rep(5, 50), Q1 = rnorm(50))

  result <- tryCatch(
    validate_shap_inputs(data, "satisfaction", "Q1", NULL),
    turas_refusal = function(cond) cond,
    error = function(e) e
  )

  expect_true(
    inherits(result, "turas_refusal") ||
    (inherits(result, "error") && grepl("ZERO_VARIANCE|variance", result$message, ignore.case = TRUE))
  )
})

test_that("set_shap_defaults: fills in missing config values", {
  skip_if_not(exists("set_shap_defaults", mode = "function"),
              "set_shap_defaults not found")

  config <- set_shap_defaults(list())

  expect_equal(config$shap_model, "xgboost")
  expect_equal(config$n_trees, 100)
  expect_equal(config$max_depth, 6)
  expect_equal(config$learning_rate, 0.1)
  expect_false(config$include_interactions)
  expect_equal(config$importance_top_n, 15)
})

test_that("set_shap_defaults: preserves user-provided values", {
  skip_if_not(exists("set_shap_defaults", mode = "function"),
              "set_shap_defaults not found")

  config <- set_shap_defaults(list(n_trees = 200, max_depth = 3))

  expect_equal(config$n_trees, 200)
  expect_equal(config$max_depth, 3)
  # Defaults should still be filled for unset fields
  expect_equal(config$learning_rate, 0.1)
})


# ==============================================================================
# FULL ORCHESTRATION TEST
# ==============================================================================

test_that("run_shap_analysis: end-to-end returns shap_results object", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("shapviz")
  skip_if_not_installed("ggplot2")
  skip_if_not(exists("run_shap_analysis", mode = "function"),
              "run_shap_analysis not found")

  data <- make_shap_test_data(n = 200)

  results <- run_shap_analysis(
    data = data,
    outcome = "satisfaction",
    drivers = paste0("Q", 1:5),
    weights = "wt",
    config = list(n_trees = 30, cv_nfold = 3, early_stopping_rounds = 10)
  )

  expect_true(inherits(results, "shap_results"))
  expect_true(!is.null(results$model))
  expect_true(!is.null(results$shap))
  expect_true(is.data.frame(results$importance))
  expect_true(is.list(results$plots))
  expect_true(!is.null(results$diagnostics))
  expect_true(results$diagnostics$r_squared > 0)
  expect_equal(nrow(results$importance), 5)
})
