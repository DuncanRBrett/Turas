# ==============================================================================
# TEST SUITE: v10.4 Analytical Features
# ==============================================================================
# Tests for Elastic Net, NCA, Dominance Analysis, and GAM nonlinear effects.
# ==============================================================================

library(testthat)

context("v10.4 Analytical Features")

# ==============================================================================
# SETUP
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

test_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."))
module_dir <- dirname(test_dir)
project_root <- normalizePath(file.path(module_dir, "..", ".."))

tryCatch({
  source(file.path(project_root, "modules", "shared", "lib", "trs_refusal.R"))
}, error = function(e) skip(paste("Cannot load TRS:", conditionMessage(e))))

# Source guard
tryCatch({
  source(file.path(module_dir, "R", "00_guard.R"))
}, error = function(e) skip(paste("Cannot load guard:", conditionMessage(e))))

# Helper: generate standard test data and config for v10.4 features
make_test_data <- function(n = 200, n_drivers = 5, seed = 42) {
  set.seed(seed)
  drivers <- matrix(rnorm(n * n_drivers), nrow = n, ncol = n_drivers)
  colnames(drivers) <- paste0("x", seq_len(n_drivers))
  # driver x1 has strongest effect, x5 weakest
  betas <- seq(0.5, 0.1, length.out = n_drivers)
  y <- drivers %*% betas + rnorm(n, sd = 0.5)
  df <- as.data.frame(cbind(y = as.numeric(y), drivers))
  # Add weight column
  df$w <- pmax(0.3, pmin(3.0, rlnorm(n, meanlog = 0, sdlog = 0.3)))
  df
}

make_test_config <- function(n_drivers = 5, weighted = FALSE) {
  cfg <- list(
    outcome_var = "y",
    driver_vars = paste0("x", seq_len(n_drivers)),
    weight_var = if (weighted) "w" else NULL,
    settings = list(
      elastic_net_alpha = 0.5,
      elastic_net_nfolds = 5,
      gam_k = 5
    )
  )
  cfg
}


# ==============================================================================
# ELASTIC NET TESTS
# ==============================================================================

test_that("Elastic Net: runs successfully on basic data", {
  skip_if_not(file.exists(file.path(module_dir, "R", "09_elastic_net.R")),
              "09_elastic_net.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "09_elastic_net.R")),
    error = function(e) skip(paste("Cannot load elastic net:", conditionMessage(e)))
  )
  skip_if_not(exists("run_elastic_net_analysis", mode = "function"),
              "run_elastic_net_analysis not found")
  skip_if_not_installed("glmnet")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_elastic_net_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result))
  expect_true(is.data.frame(result$result$coefficients))
  expect_equal(nrow(result$result$coefficients), 5)
  expect_true(all(c("Driver", "Coefficient_1se", "Importance_Pct", "Selected_1se") %in%
    names(result$result$coefficients)))
  expect_true(result$result$alpha == 0.5)
  expect_true(result$result$n_obs == 200)
})

test_that("Elastic Net: importance percentages sum to ~100", {
  skip_if_not(file.exists(file.path(module_dir, "R", "09_elastic_net.R")),
              "09_elastic_net.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "09_elastic_net.R")),
    error = function(e) skip(paste("Cannot load elastic net:", conditionMessage(e)))
  )
  skip_if_not(exists("run_elastic_net_analysis", mode = "function"),
              "run_elastic_net_analysis not found")
  skip_if_not_installed("glmnet")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_elastic_net_analysis(data, config)

  expect_equal(result$status, "PASS")
  total_pct <- sum(result$result$coefficients$Importance_Pct)
  expect_true(abs(total_pct - 100) < 1,
              info = sprintf("Importance should sum to ~100, got %.1f", total_pct))
})

test_that("Elastic Net: supports weighted data", {
  skip_if_not(file.exists(file.path(module_dir, "R", "09_elastic_net.R")),
              "09_elastic_net.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "09_elastic_net.R")),
    error = function(e) skip(paste("Cannot load elastic net:", conditionMessage(e)))
  )
  skip_if_not(exists("run_elastic_net_analysis", mode = "function"),
              "run_elastic_net_analysis not found")
  skip_if_not_installed("glmnet")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5, weighted = TRUE)

  result <- run_elastic_net_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result))
})

test_that("Elastic Net: returns PARTIAL when too few cases", {
  skip_if_not(file.exists(file.path(module_dir, "R", "09_elastic_net.R")),
              "09_elastic_net.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "09_elastic_net.R")),
    error = function(e) skip(paste("Cannot load elastic net:", conditionMessage(e)))
  )
  skip_if_not(exists("run_elastic_net_analysis", mode = "function"),
              "run_elastic_net_analysis not found")
  skip_if_not_installed("glmnet")

  data <- make_test_data(n = 10, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_elastic_net_analysis(data, config)

  expect_equal(result$status, "PARTIAL")
  expect_true(is.null(result$result))
})

test_that("Elastic Net: returns PARTIAL when glmnet not installed", {
  skip_if_not(file.exists(file.path(module_dir, "R", "09_elastic_net.R")),
              "09_elastic_net.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "09_elastic_net.R")),
    error = function(e) skip(paste("Cannot load elastic net:", conditionMessage(e)))
  )
  skip_if_not(exists("run_elastic_net_analysis", mode = "function"),
              "run_elastic_net_analysis not found")

  # This test only runs when glmnet is NOT installed
  skip_if(requireNamespace("glmnet", quietly = TRUE),
          "glmnet is installed — cannot test missing-package path")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_elastic_net_analysis(data, config)
  expect_equal(result$status, "PARTIAL")
  expect_true(grepl("not installed", result$message))
})

test_that("Elastic Net: selected drivers is subset of all drivers", {
  skip_if_not(file.exists(file.path(module_dir, "R", "09_elastic_net.R")),
              "09_elastic_net.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "09_elastic_net.R")),
    error = function(e) skip(paste("Cannot load elastic net:", conditionMessage(e)))
  )
  skip_if_not(exists("run_elastic_net_analysis", mode = "function"),
              "run_elastic_net_analysis not found")
  skip_if_not_installed("glmnet")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_elastic_net_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(all(result$result$selected_drivers %in% config$driver_vars))
  expect_true(all(result$result$zeroed_drivers %in% config$driver_vars))
  expect_equal(
    sort(c(result$result$selected_drivers, result$result$zeroed_drivers)),
    sort(config$driver_vars)
  )
})


# ==============================================================================
# NCA TESTS
# ==============================================================================

test_that("NCA: runs successfully on basic data", {
  skip_if_not(file.exists(file.path(module_dir, "R", "10_nca.R")),
              "10_nca.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "10_nca.R")),
    error = function(e) skip(paste("Cannot load NCA:", conditionMessage(e)))
  )
  skip_if_not(exists("run_nca_analysis", mode = "function"),
              "run_nca_analysis not found")
  skip_if_not_installed("NCA")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_nca_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result))
  expect_true(is.data.frame(result$result$nca_summary))
  expect_true(all(c("Driver", "NCA_Effect_Size", "NCA_p_value", "Is_Necessary",
                     "Classification") %in% names(result$result$nca_summary)))
  expect_equal(nrow(result$result$nca_summary), 5)
  expect_true(result$result$n_obs == 200)
})

test_that("NCA: classification is binary Necessary/Not Necessary", {
  skip_if_not(file.exists(file.path(module_dir, "R", "10_nca.R")),
              "10_nca.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "10_nca.R")),
    error = function(e) skip(paste("Cannot load NCA:", conditionMessage(e)))
  )
  skip_if_not(exists("run_nca_analysis", mode = "function"),
              "run_nca_analysis not found")
  skip_if_not_installed("NCA")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_nca_analysis(data, config)

  expect_equal(result$status, "PASS")
  classes <- result$result$nca_summary$Classification
  expect_true(all(classes %in% c("Necessary Condition", "Not Necessary")))
})

test_that("NCA: returns PARTIAL when too few cases", {
  skip_if_not(file.exists(file.path(module_dir, "R", "10_nca.R")),
              "10_nca.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "10_nca.R")),
    error = function(e) skip(paste("Cannot load NCA:", conditionMessage(e)))
  )
  skip_if_not(exists("run_nca_analysis", mode = "function"),
              "run_nca_analysis not found")
  skip_if_not_installed("NCA")

  data <- make_test_data(n = 10, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_nca_analysis(data, config)

  expect_equal(result$status, "PARTIAL")
  expect_true(is.null(result$result))
})

test_that("NCA: effect sizes are non-negative", {
  skip_if_not(file.exists(file.path(module_dir, "R", "10_nca.R")),
              "10_nca.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "10_nca.R")),
    error = function(e) skip(paste("Cannot load NCA:", conditionMessage(e)))
  )
  skip_if_not(exists("run_nca_analysis", mode = "function"),
              "run_nca_analysis not found")
  skip_if_not_installed("NCA")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_nca_analysis(data, config)

  expect_equal(result$status, "PASS")
  effect_sizes <- result$result$nca_summary$NCA_Effect_Size
  expect_true(all(is.na(effect_sizes) | effect_sizes >= 0),
              info = "NCA effect sizes should be non-negative")
})


# ==============================================================================
# DOMINANCE ANALYSIS TESTS
# ==============================================================================

test_that("Dominance: runs successfully on basic data", {
  skip_if_not(file.exists(file.path(module_dir, "R", "11_dominance.R")),
              "11_dominance.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "11_dominance.R")),
    error = function(e) skip(paste("Cannot load dominance:", conditionMessage(e)))
  )
  skip_if_not(exists("run_dominance_analysis", mode = "function"),
              "run_dominance_analysis not found")
  skip_if_not_installed("domir")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_dominance_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result))
  expect_true(is.data.frame(result$result$summary))
  expect_true(all(c("Driver", "General_Dominance", "General_Pct", "Rank") %in%
    names(result$result$summary)))
  expect_equal(nrow(result$result$summary), 5)
  expect_true(result$result$n_obs == 200)
})

test_that("Dominance: general dominance sums to total R-squared", {
  skip_if_not(file.exists(file.path(module_dir, "R", "11_dominance.R")),
              "11_dominance.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "11_dominance.R")),
    error = function(e) skip(paste("Cannot load dominance:", conditionMessage(e)))
  )
  skip_if_not(exists("run_dominance_analysis", mode = "function"),
              "run_dominance_analysis not found")
  skip_if_not_installed("domir")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_dominance_analysis(data, config)

  expect_equal(result$status, "PASS")
  dom_sum <- sum(result$result$general_dominance)
  total_r2 <- result$result$total_r_squared
  expect_equal(dom_sum, total_r2, tolerance = 0.001)
})

test_that("Dominance: percentages sum to ~100", {
  skip_if_not(file.exists(file.path(module_dir, "R", "11_dominance.R")),
              "11_dominance.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "11_dominance.R")),
    error = function(e) skip(paste("Cannot load dominance:", conditionMessage(e)))
  )
  skip_if_not(exists("run_dominance_analysis", mode = "function"),
              "run_dominance_analysis not found")
  skip_if_not_installed("domir")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_dominance_analysis(data, config)

  expect_equal(result$status, "PASS")
  total_pct <- sum(result$result$summary$General_Pct)
  expect_true(abs(total_pct - 100) < 1,
              info = sprintf("General_Pct should sum to ~100, got %.1f", total_pct))
})

test_that("Dominance: supports weighted data", {
  skip_if_not(file.exists(file.path(module_dir, "R", "11_dominance.R")),
              "11_dominance.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "11_dominance.R")),
    error = function(e) skip(paste("Cannot load dominance:", conditionMessage(e)))
  )
  skip_if_not(exists("run_dominance_analysis", mode = "function"),
              "run_dominance_analysis not found")
  skip_if_not_installed("domir")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5, weighted = TRUE)

  result <- run_dominance_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result))
})

test_that("Dominance: requires at least 2 numeric drivers", {
  skip_if_not(file.exists(file.path(module_dir, "R", "11_dominance.R")),
              "11_dominance.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "11_dominance.R")),
    error = function(e) skip(paste("Cannot load dominance:", conditionMessage(e)))
  )
  skip_if_not(exists("run_dominance_analysis", mode = "function"),
              "run_dominance_analysis not found")
  skip_if_not_installed("domir")

  data <- make_test_data(n = 200, n_drivers = 1)
  config <- make_test_config(n_drivers = 1)

  result <- run_dominance_analysis(data, config)

  expect_equal(result$status, "PARTIAL")
  expect_true(grepl("at least 2", result$message))
})

test_that("Dominance: returns PARTIAL when too few cases", {
  skip_if_not(file.exists(file.path(module_dir, "R", "11_dominance.R")),
              "11_dominance.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "11_dominance.R")),
    error = function(e) skip(paste("Cannot load dominance:", conditionMessage(e)))
  )
  skip_if_not(exists("run_dominance_analysis", mode = "function"),
              "run_dominance_analysis not found")
  skip_if_not_installed("domir")

  data <- make_test_data(n = 10, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_dominance_analysis(data, config)

  expect_equal(result$status, "PARTIAL")
  expect_true(is.null(result$result))
})


# ==============================================================================
# GAM NONLINEAR EFFECTS TESTS
# ==============================================================================

test_that("GAM: runs successfully on basic data", {
  skip_if_not(file.exists(file.path(module_dir, "R", "12_gam.R")),
              "12_gam.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "12_gam.R")),
    error = function(e) skip(paste("Cannot load GAM:", conditionMessage(e)))
  )
  skip_if_not(exists("run_gam_analysis", mode = "function"),
              "run_gam_analysis not found")
  skip_if_not_installed("mgcv")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_gam_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result))
  expect_true(is.data.frame(result$result$nonlinearity_summary))
  expect_true(all(c("Driver", "EDF", "F_statistic", "p_value",
                     "Is_Nonlinear", "Shape") %in%
    names(result$result$nonlinearity_summary)))
  expect_equal(nrow(result$result$nonlinearity_summary), 5)
  expect_true(result$result$n_obs == 200)
})

test_that("GAM: deviance explained >= linear R-squared", {
  skip_if_not(file.exists(file.path(module_dir, "R", "12_gam.R")),
              "12_gam.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "12_gam.R")),
    error = function(e) skip(paste("Cannot load GAM:", conditionMessage(e)))
  )
  skip_if_not(exists("run_gam_analysis", mode = "function"),
              "run_gam_analysis not found")
  skip_if_not_installed("mgcv")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_gam_analysis(data, config)

  expect_equal(result$status, "PASS")
  # GAM should explain at least as much as linear (it's a superset)
  expect_true(result$result$deviance_explained >= result$result$linear_r_squared - 0.01,
              info = "GAM deviance explained should be >= linear R²")
})

test_that("GAM: shapes are valid categories", {
  skip_if_not(file.exists(file.path(module_dir, "R", "12_gam.R")),
              "12_gam.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "12_gam.R")),
    error = function(e) skip(paste("Cannot load GAM:", conditionMessage(e)))
  )
  skip_if_not(exists("run_gam_analysis", mode = "function"),
              "run_gam_analysis not found")
  skip_if_not_installed("mgcv")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)
  result <- run_gam_analysis(data, config)

  expect_equal(result$status, "PASS")
  shapes <- result$result$nonlinearity_summary$Shape
  valid_shapes <- c("Approximately linear", "Moderate curvature", "Complex")
  expect_true(all(shapes %in% valid_shapes),
              info = paste("Invalid shapes found:", paste(setdiff(shapes, valid_shapes), collapse = ", ")))
})

test_that("GAM: supports weighted data", {
  skip_if_not(file.exists(file.path(module_dir, "R", "12_gam.R")),
              "12_gam.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "12_gam.R")),
    error = function(e) skip(paste("Cannot load GAM:", conditionMessage(e)))
  )
  skip_if_not(exists("run_gam_analysis", mode = "function"),
              "run_gam_analysis not found")
  skip_if_not_installed("mgcv")

  data <- make_test_data(n = 200, n_drivers = 5)
  config <- make_test_config(n_drivers = 5, weighted = TRUE)

  result <- run_gam_analysis(data, config)

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result))
})

test_that("GAM: returns PARTIAL when too few cases", {
  skip_if_not(file.exists(file.path(module_dir, "R", "12_gam.R")),
              "12_gam.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "12_gam.R")),
    error = function(e) skip(paste("Cannot load GAM:", conditionMessage(e)))
  )
  skip_if_not(exists("run_gam_analysis", mode = "function"),
              "run_gam_analysis not found")
  skip_if_not_installed("mgcv")

  data <- make_test_data(n = 20, n_drivers = 5)
  config <- make_test_config(n_drivers = 5)

  result <- run_gam_analysis(data, config)

  expect_equal(result$status, "PARTIAL")
  expect_true(is.null(result$result))
})

test_that("GAM: handles nonlinear data correctly", {
  skip_if_not(file.exists(file.path(module_dir, "R", "12_gam.R")),
              "12_gam.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "12_gam.R")),
    error = function(e) skip(paste("Cannot load GAM:", conditionMessage(e)))
  )
  skip_if_not(exists("run_gam_analysis", mode = "function"),
              "run_gam_analysis not found")
  skip_if_not_installed("mgcv")

  # Create data with known nonlinear relationship
  set.seed(99)
  n <- 300
  x1 <- runif(n, -3, 3)
  x2 <- runif(n, -3, 3)
  x3 <- runif(n, -3, 3)
  # x1 has quadratic effect, x2 linear, x3 sine-wave
  y <- x1^2 + 0.5 * x2 + sin(x3) + rnorm(n, sd = 0.3)
  data <- data.frame(y = y, x1 = x1, x2 = x2, x3 = x3)

  config <- list(
    outcome_var = "y",
    driver_vars = c("x1", "x2", "x3"),
    weight_var = NULL,
    settings = list(gam_k = 5)
  )

  result <- run_gam_analysis(data, config)

  expect_equal(result$status, "PASS")
  # x1 should show nonlinearity (quadratic)
  x1_row <- result$result$nonlinearity_summary[
    result$result$nonlinearity_summary$Driver == "x1", ]
  expect_true(nrow(x1_row) == 1)
  expect_true(x1_row$EDF > 1.5,
              info = sprintf("x1 EDF should be > 1.5 for quadratic, got %.2f", x1_row$EDF))
  # GAM should improve on linear for this data
  expect_true(result$result$improvement > 0,
              info = "GAM should improve on linear R² for nonlinear data")
})


# ==============================================================================
# CROSS-FEATURE: Configurable threshold tests
# ==============================================================================

test_that("Effect size benchmarks accept config overrides", {
  skip_if_not(file.exists(file.path(module_dir, "R", "06_effect_size.R")),
              "06_effect_size.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "06_effect_size.R")),
    error = function(e) skip(paste("Cannot load effect size:", conditionMessage(e)))
  )
  skip_if_not(exists("get_effect_size_benchmarks", mode = "function"),
              "get_effect_size_benchmarks not found")

  # Default benchmarks
  default <- get_effect_size_benchmarks("cohen_f2")
  expect_equal(default$negligible, 0.02)
  expect_equal(default$small, 0.15)
  expect_equal(default$medium, 0.35)

  # Custom benchmarks via config
  custom_config <- list(
    effect_size_benchmarks = list(
      cohen_f2 = list(negligible = 0.05, small = 0.20, medium = 0.40)
    )
  )
  custom <- get_effect_size_benchmarks("cohen_f2", config = custom_config)
  expect_equal(custom$negligible, 0.05)
  expect_equal(custom$small, 0.20)
  expect_equal(custom$medium, 0.40)
})
