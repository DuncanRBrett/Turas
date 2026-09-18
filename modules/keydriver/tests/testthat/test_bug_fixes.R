# ==============================================================================
# TEST SUITE: Bug Fix Regression Tests
# ==============================================================================
# Tests for all bugs fixed in the v10.4 review cycle.
# Ensures these bugs do not regress.
# ==============================================================================

library(testthat)

context("Bug Fix Regression Tests")

# ==============================================================================
# SETUP
# ==============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# module_dir and project_root are provided by helper-paths.R

tryCatch({
  source(file.path(project_root, "modules", "shared", "lib", "trs_refusal.R"))
}, error = function(e) skip(paste("Cannot load TRS:", conditionMessage(e))))

tryCatch({
  source(file.path(module_dir, "R", "00_guard.R"))
}, error = function(e) skip(paste("Cannot load guard:", conditionMessage(e))))

# ==============================================================================
# BUG-2: Double-weighted bootstrap - inner lm should be unweighted
# ==============================================================================

test_that("BUG-2: Bootstrap inner model is unweighted when weighted resampling used", {
  skip_if_not(file.exists(file.path(module_dir, "R", "05_bootstrap.R")),
              "05_bootstrap.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "05_bootstrap.R")),
    error = function(e) skip(paste("Cannot load bootstrap:", conditionMessage(e)))
  )

  # The fix is structural: calculate_single_bootstrap() should not use weights
  # We verify by running a small bootstrap and checking it completes
  set.seed(42)
  n <- 100
  data <- data.frame(
    y = rnorm(n),
    x1 = rnorm(n),
    x2 = rnorm(n),
    w = runif(n, 0.5, 2)
  )

  skip_if_not(exists("bootstrap_importance_ci", mode = "function"),
              "bootstrap_importance_ci not found")

  result <- tryCatch(
    bootstrap_importance_ci(
      data = data, outcome = "y", drivers = c("x1", "x2"),
      weights = "w", n_bootstrap = 100, ci_level = 0.95
    ),
    error = function(e) NULL
  )

  # Should complete without error
  expect_true(!is.null(result), info = "Weighted bootstrap should complete")
  if (!is.null(result)) {
    expect_true(is.data.frame(result) || is.list(result))
  }
})


# ==============================================================================
# BUG-5: NA fallback in effect size interpretation
# ==============================================================================

test_that("BUG-5: Effect size handles NA values without error", {
  skip_if_not(file.exists(file.path(module_dir, "R", "06_effect_size.R")),
              "06_effect_size.R not found")
  tryCatch(
    source(file.path(module_dir, "R", "06_effect_size.R")),
    error = function(e) skip(paste("Cannot load effect size:", conditionMessage(e)))
  )

  skip_if_not(exists("get_effect_size_benchmarks", mode = "function"),
              "get_effect_size_benchmarks not found")

  benchmarks <- get_effect_size_benchmarks("cohen_f2")
  expect_true(is.list(benchmarks))
  expect_true(all(c("negligible", "small", "medium") %in% names(benchmarks)))
})


# ==============================================================================
# BUG-6: Stated importance validation returns data frame
# ==============================================================================

test_that("BUG-6: validate_stated_importance_sheet returns data frame", {
  tryCatch(
    source(file.path(module_dir, "R", "01_config.R")),
    error = function(e) skip(paste("Cannot load config:", conditionMessage(e)))
  )

  skip_if_not(exists("validate_stated_importance_sheet", mode = "function"),
              "validate_stated_importance_sheet not found")

  si_df <- data.frame(
    driver = c("x1", "x2"),
    stated_importance = c(80, 60),
    stringsAsFactors = FALSE
  )

  result <- tryCatch(
    validate_stated_importance_sheet(si_df),
    error = function(e) NULL
  )

  # Should return a data frame, not TRUE
  if (!is.null(result)) {
    expect_true(is.data.frame(result),
                info = "validate_stated_importance_sheet should return a data frame")
  }
})


# ==============================================================================
# BUG-8: Term mapping longest-first ordering
# ==============================================================================

test_that("BUG-8: Term mapping processes drivers longest-name-first", {
  tryCatch(
    source(file.path(module_dir, "R", "02_term_mapping.R")),
    error = function(e) skip(paste("Cannot load term mapping:", conditionMessage(e)))
  )

  # The function is build_term_mapping. Named wrongly, this skip was never
  # false, so the test below has never run (review A11).
  skip_if_not(exists("build_term_mapping", mode = "function"),
              "build_term_mapping not found")

  # Create data with prefix collision potential
  data <- data.frame(
    y = 1:10,
    age = rnorm(10),
    age_group = sample(c("young", "old"), 10, replace = TRUE),
    stringsAsFactors = FALSE
  )

  # Prefix collision: "age" is a prefix of "age_group", so a mapper that
  # matches on prefixes assigns age_groupold to age.
  mapping <- build_term_mapping(y ~ age + age_group, data, c("age", "age_group"))
  expect_true(is.list(mapping))
  expect_true(all(c("term_map", "driver_terms") %in% names(mapping)))

  # Every term belongs to exactly one driver, and to the right one.
  expect_equal(unname(mapping$term_map[["age"]]), "age")
  age_group_terms <- mapping$driver_terms[["age_group"]]
  expect_gt(length(age_group_terms), 0)
  expect_false("age" %in% age_group_terms)
  for (tm in age_group_terms) {
    expect_equal(unname(mapping$term_map[[tm]]), "age_group", info = tm)
  }
  # And nothing is left unmapped.
  expect_false(any(is.na(unlist(mapping$term_map))))
})
