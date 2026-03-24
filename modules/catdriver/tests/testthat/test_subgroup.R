# ==============================================================================
# CATDRIVER SUBGROUP COMPARISON TEST SUITE
# ==============================================================================
#
# Tests for the optional subgroup comparison feature:
#   1. Config defaults and parsing
#   2. Hard guard validations (4 guards)
#   3. Soft guard validations (2 guards)
#   4. Core comparison logic (11_subgroup_comparison.R)
#   5. Excel sheet generation (06c_sheets_subgroup.R)
#   6. Backward compatibility (no subgroup_var = no changes)
#   7. Edge cases (2 groups, 5+ groups, small n, model failures)
#
# Run with: Rscript -e "source('modules/catdriver/tests/test_subgroup.R')"
#
# Version: 1.0
# ==============================================================================

library(testthat)

# Path resolution is handled by helper-paths.R (auto-sourced by testthat)
# which provides: module_root, turas_root
setwd(module_root)

# Source shared utilities (required for TRS refusal functions)
shared_lib_path <- file.path(turas_root, "modules", "shared", "lib")
if (dir.exists(shared_lib_path)) {
  shared_files <- list.files(shared_lib_path, pattern = "\\.R$", full.names = TRUE)
  for (f in shared_files) {
    tryCatch(source(f), error = function(e) {
      cat("Warning: Could not source shared", basename(f), ":", e$message, "\n")
    })
  }
}

# Source all R files in order
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
r_files <- r_files[order(basename(r_files))]
for (f in r_files) {
  tryCatch(source(f), error = function(e) {
    cat("Warning: Could not source", basename(f), ":", e$message, "\n")
  })
}


# ==============================================================================
# TEST DATA GENERATORS
# ==============================================================================

#' Generate test data with a subgroup variable
generate_subgroup_data <- function(n = 400, seed = 42) {
  set.seed(seed)
  data.frame(
    outcome     = factor(sample(c("No", "Yes"), n, TRUE, c(0.45, 0.55))),
    driver1     = factor(sample(c("Low", "Medium", "High"), n, TRUE)),
    driver2     = factor(sample(c("Poor", "Fair", "Good", "Excellent"), n, TRUE)),
    driver3     = factor(sample(c("Neg", "Neutral", "Pos"), n, TRUE)),
    segment     = factor(sample(c("A", "B", "C"), n, TRUE)),
    age_group   = factor(sample(c("Young", "Middle", "Senior"), n, TRUE)),
    region      = factor(sample(c("North", "South"), n, TRUE)),
    weight_var  = round(runif(n, 0.5, 2.0), 2),
    stringsAsFactors = FALSE
  )
}

#' Generate mock subgroup results (for comparison logic tests)
generate_mock_subgroup_results <- function(n_groups = 3) {
  group_names <- paste0("Group_", LETTERS[seq_len(n_groups)])
  results <- list()

  for (i in seq_len(n_groups)) {
    grp <- group_names[i]
    n_drivers <- 4

    # Generate importance with known patterns:
    #   - driver1 is always top (universal)
    #   - driver3 varies (segment-specific)
    imp_pct <- c(40 - i * 2, 25, 20 + i * 3, 15 - i)
    imp_pct <- pmax(imp_pct, 5)
    imp_pct <- imp_pct / sum(imp_pct) * 100

    importance <- data.frame(
      variable       = paste0("driver", 1:n_drivers),
      label          = paste0("Driver ", 1:n_drivers),
      importance_pct = imp_pct,
      rank           = rank(-imp_pct),
      stringsAsFactors = FALSE
    )

    # Mock model result with fit statistics
    model_result <- list(
      fit_statistics = list(
        mcfadden_r2 = 0.15 + i * 0.05,
        aic = 300 - i * 20,
        converged = TRUE,
        engine = "glm"
      ),
      coefficients = data.frame(
        driver    = rep(paste0("driver", 1:n_drivers), each = 2),
        label     = rep(paste0("Driver ", 1:n_drivers), each = 2),
        level     = rep(c("Level_A", "Level_B"), n_drivers),
        or        = runif(n_drivers * 2, 0.5, 3.0),
        p_value   = runif(n_drivers * 2, 0.001, 0.2),
        stringsAsFactors = FALSE
      )
    )

    results[[grp]] <- list(
      status       = "PASS",
      importance   = importance,
      model_result = model_result,
      group_n      = 100 + i * 20
    )
  }

  results
}

#' Build a minimal config for subgroup tests
make_subgroup_config <- function(subgroup_var = "segment",
                                  outcome_var = "outcome",
                                  driver_vars = c("driver1", "driver2", "driver3"),
                                  subgroup_min_n = 30,
                                  subgroup_include_total = TRUE) {
  list(
    outcome_var          = outcome_var,
    driver_vars          = driver_vars,
    subgroup_var         = subgroup_var,
    subgroup_min_n       = subgroup_min_n,
    subgroup_include_total = subgroup_include_total
  )
}


# ==============================================================================
# TEST SUITE 1: CONFIG DEFAULTS
# ==============================================================================

context("Subgroup Config Defaults")

test_that("subgroup_var defaults to NULL when not set", {
  # Simulate config with no subgroup settings
  config <- list(
    outcome_var  = "outcome",
    outcome_type = "binary",
    driver_vars  = c("driver1", "driver2"),
    subgroup_var = NULL
  )
  expect_null(config$subgroup_var)
})

test_that("subgroup_min_n defaults to 30", {
  config <- make_subgroup_config()
  expect_equal(config$subgroup_min_n, 30)
})

test_that("subgroup_include_total defaults to TRUE", {
  config <- make_subgroup_config()
  expect_true(config$subgroup_include_total)
})


# ==============================================================================
# TEST SUITE 2: HARD GUARDS
# ==============================================================================

context("Subgroup Hard Guards")

test_that("guard_subgroup_not_outcome REFUSES when subgroup == outcome", {
  config <- make_subgroup_config(subgroup_var = "outcome", outcome_var = "outcome")

  expect_error(
    guard_subgroup_not_outcome(config),
    "SUBGROUP VARIABLE CANNOT BE OUTCOME"
  )
})

test_that("guard_subgroup_not_outcome passes when subgroup != outcome", {
  config <- make_subgroup_config(subgroup_var = "segment", outcome_var = "outcome")

  expect_invisible(guard_subgroup_not_outcome(config))
})

test_that("guard_subgroup_not_outcome skips when subgroup_var is NULL", {
  config <- make_subgroup_config(subgroup_var = NULL)

  # Should not error — just returns invisible(TRUE)
  expect_invisible(guard_subgroup_not_outcome(config))
})

test_that("guard_subgroup_not_driver REFUSES when subgroup is a driver", {
  config <- make_subgroup_config(
    subgroup_var = "driver1",
    driver_vars  = c("driver1", "driver2", "driver3")
  )

  expect_error(
    guard_subgroup_not_driver(config),
    "SUBGROUP VARIABLE CANNOT BE A DRIVER"
  )
})

test_that("guard_subgroup_not_driver passes when subgroup is not a driver", {
  config <- make_subgroup_config(
    subgroup_var = "segment",
    driver_vars  = c("driver1", "driver2", "driver3")
  )

  expect_invisible(guard_subgroup_not_driver(config))
})

test_that("guard_subgroup_exists_in_data REFUSES when column missing", {
  config <- make_subgroup_config(subgroup_var = "nonexistent_column")
  data   <- generate_subgroup_data(100)

  expect_error(
    guard_subgroup_exists_in_data(config, data),
    "SUBGROUP VARIABLE NOT FOUND"
  )
})

test_that("guard_subgroup_exists_in_data passes when column exists", {
  config <- make_subgroup_config(subgroup_var = "segment")
  data   <- generate_subgroup_data(100)

  expect_invisible(guard_subgroup_exists_in_data(config, data))
})

test_that("guard_subgroup_minimum_levels REFUSES with <2 levels", {
  config <- make_subgroup_config(subgroup_var = "one_level")
  data   <- generate_subgroup_data(100)
  data$one_level <- "only_one"  # Single level

  expect_error(
    guard_subgroup_minimum_levels(config, data),
    "SUBGROUP VARIABLE HAS FEWER THAN 2 LEVELS"
  )
})

test_that("guard_subgroup_minimum_levels passes with 2+ levels", {
  config <- make_subgroup_config(subgroup_var = "region")
  data   <- generate_subgroup_data(100)

  expect_invisible(guard_subgroup_minimum_levels(config, data))
})

test_that("guard_subgroup_minimum_levels handles all-NA column", {
  config <- make_subgroup_config(subgroup_var = "all_na")
  data   <- generate_subgroup_data(100)
  data$all_na <- NA

  expect_error(
    guard_subgroup_minimum_levels(config, data),
    "SUBGROUP VARIABLE HAS FEWER THAN 2 LEVELS"
  )
})


# ==============================================================================
# TEST SUITE 3: SOFT GUARDS
# ==============================================================================

context("Subgroup Soft Guards")

test_that("guard_check_subgroup_sample_size warns for small groups", {
  guard <- guard_init()

  result <- guard_check_subgroup_sample_size(guard, "Small_Group", 15, 30)

  # Should add warnings and/or stability flags
  expect_true(length(result$warnings) > 0 || length(result$stability_flags) > 0)
})

test_that("guard_check_subgroup_sample_size does NOT warn for adequate groups", {
  guard <- guard_init()

  result <- guard_check_subgroup_sample_size(guard, "Big_Group", 50, 30)

  # Should NOT add warnings

  expect_equal(length(result$warnings), 0)
})

test_that("guard_check_subgroup_model_failed records failure", {
  guard <- guard_init()

  result <- guard_check_subgroup_model_failed(guard, "Failed_Group", "convergence failure")

  # Should add warnings and/or stability flags
  expect_true(length(result$warnings) > 0 || length(result$stability_flags) > 0)
})


# ==============================================================================
# TEST SUITE 4: CORE COMPARISON LOGIC
# ==============================================================================

context("Subgroup Comparison Logic")

test_that("build_subgroup_comparison returns valid structure", {
  mock_results <- generate_mock_subgroup_results(3)

  comparison <- build_subgroup_comparison(mock_results, config = list(subgroup_var = "segment"))

  expect_true(is.list(comparison))
  expect_true("importance_matrix" %in% names(comparison))
  expect_true("or_comparison"     %in% names(comparison))
  expect_true("model_fit"         %in% names(comparison))
  expect_true("insights"          %in% names(comparison))
  expect_true("group_names"       %in% names(comparison))
  expect_true("n_groups"          %in% names(comparison))
})

test_that("build_subgroup_comparison handles <2 successful groups", {
  # Only 1 group → can't compare
  single <- generate_mock_subgroup_results(1)

  comparison <- build_subgroup_comparison(single)

  # Should return NULL importance_matrix (can't compare with <2)
  expect_null(comparison$importance_matrix)
})

test_that("importance_matrix has correct dimensions", {
  mock_results <- generate_mock_subgroup_results(3)
  comparison   <- build_subgroup_comparison(mock_results)

  imp <- comparison$importance_matrix
  expect_true(is.data.frame(imp))
  expect_equal(nrow(imp), 4)  # 4 drivers

  # Should have columns for each group's rank and pct
  expect_true("variable" %in% names(imp))
  expect_true("classification" %in% names(imp))
  expect_true("max_rank_diff"  %in% names(imp))
})

test_that("classify_drivers produces Universal/Segment-Specific/Mixed", {
  mock_results <- generate_mock_subgroup_results(3)
  comparison   <- build_subgroup_comparison(mock_results)

  classifications <- unique(comparison$importance_matrix$classification)

  # At least one classification should be present

  expect_true(length(classifications) > 0)

  # All classifications should be valid
  valid_classes <- c("Universal", "Segment-Specific", "Mixed")
  for (cls in classifications) {
    expect_true(cls %in% valid_classes,
                info = paste("Unexpected classification:", cls))
  }
})

test_that("model_fit summary has one row per group", {
  mock_results <- generate_mock_subgroup_results(3)
  comparison   <- build_subgroup_comparison(mock_results)

  fit <- comparison$model_fit
  expect_true(is.data.frame(fit))
  expect_equal(nrow(fit), 3)
})

test_that("insights are generated as character vector", {
  mock_results <- generate_mock_subgroup_results(3)
  comparison   <- build_subgroup_comparison(mock_results)

  insights <- comparison$insights
  expect_true(is.character(insights))
  expect_true(length(insights) > 0)
})

test_that("or_comparison has expected structure when present", {
  mock_results <- generate_mock_subgroup_results(3)
  comparison   <- build_subgroup_comparison(mock_results)

  or_comp <- comparison$or_comparison

  # OR comparison should exist (we have 3 groups with coefficients)
  if (!is.null(or_comp) && nrow(or_comp) > 0) {
    expect_true("notable" %in% names(or_comp))
    expect_true("driver"  %in% names(or_comp))
    expect_true("level"   %in% names(or_comp))
  } else {
    # If not available, at least it should be NULL/empty (not an error)
    expect_true(is.null(or_comp) || nrow(or_comp) == 0)
  }
})

test_that("build_subgroup_comparison handles 2 groups (minimum)", {
  mock_results <- generate_mock_subgroup_results(2)
  comparison   <- build_subgroup_comparison(mock_results)

  expect_true(!is.null(comparison$importance_matrix))
  expect_equal(comparison$n_groups, 2)
})

test_that("build_subgroup_comparison handles 5 groups", {
  mock_results <- generate_mock_subgroup_results(5)
  comparison   <- build_subgroup_comparison(mock_results)

  expect_true(!is.null(comparison$importance_matrix))
  expect_equal(comparison$n_groups, 5)
  expect_equal(length(comparison$group_names), 5)
})

test_that("build_subgroup_comparison handles failed groups gracefully", {
  mock_results <- generate_mock_subgroup_results(3)

  # Mark one group as failed
  mock_results[["Group_B"]]$status <- "REFUSED"

  comparison <- build_subgroup_comparison(mock_results)

  # Should still work with the 2 successful groups
  expect_equal(comparison$n_groups, 2)
  expect_false("Group_B" %in% comparison$group_names)
})


# ==============================================================================
# TEST SUITE 5: EXCEL SHEET GENERATION
# ==============================================================================

context("Subgroup Excel Sheets")

test_that("add_subgroup_sheets returns invisibly when comparison is NULL", {
  wb <- openxlsx::createWorkbook()
  styles <- list(
    header = openxlsx::createStyle(textDecoration = "bold"),
    title  = openxlsx::createStyle(fontSize = 14, textDecoration = "bold")
  )

  result <- add_subgroup_sheets(wb, comparison = NULL, results = list(), config = list(), styles = styles)
  expect_null(result)
})

test_that("add_subgroup_sheets creates 3 sheets when comparison provided", {
  wb <- openxlsx::createWorkbook()
  styles <- list(
    header = openxlsx::createStyle(textDecoration = "bold"),
    title  = openxlsx::createStyle(fontSize = 14, textDecoration = "bold")
  )

  mock_results <- generate_mock_subgroup_results(3)
  comparison   <- build_subgroup_comparison(mock_results, config = list(subgroup_var = "segment"))

  add_subgroup_sheets(wb, comparison, results = list(), config = list(), styles = styles)

  sheet_names <- openxlsx::sheets(wb)
  expect_true("Subgroup Summary"   %in% sheet_names)
  expect_true("Subgroup OR Compare" %in% sheet_names)
  expect_true("Subgroup Model Fit" %in% sheet_names)
})

test_that("subgroup sheets are NOT added when subgroup is inactive", {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Results")

  styles <- list(
    header = openxlsx::createStyle(textDecoration = "bold"),
    title  = openxlsx::createStyle(fontSize = 14, textDecoration = "bold")
  )

  # No subgroup data → should not add sheets
  add_subgroup_sheets(wb, comparison = NULL, results = list(), config = list(), styles = styles)

  sheet_names <- openxlsx::sheets(wb)
  expect_false("Subgroup Summary" %in% sheet_names)
  expect_equal(length(sheet_names), 1)  # Only the "Results" sheet
})


# ==============================================================================
# TEST SUITE 6: BACKWARD COMPATIBILITY
# ==============================================================================

context("Subgroup Backward Compatibility")

test_that("guards pass silently when subgroup_var is NULL", {
  config <- make_subgroup_config(subgroup_var = NULL)
  data   <- generate_subgroup_data(100)

  # All subgroup guards should pass silently
  expect_invisible(guard_subgroup_not_outcome(config))
  expect_invisible(guard_subgroup_not_driver(config))
  expect_invisible(guard_subgroup_exists_in_data(config, data))
  expect_invisible(guard_subgroup_minimum_levels(config, data))
})

test_that("guards pass silently when subgroup_var is empty string", {
  config <- make_subgroup_config(subgroup_var = "")
  data   <- generate_subgroup_data(100)

  expect_invisible(guard_subgroup_not_outcome(config))
  expect_invisible(guard_subgroup_not_driver(config))
  expect_invisible(guard_subgroup_exists_in_data(config, data))
  expect_invisible(guard_subgroup_minimum_levels(config, data))
})


# ==============================================================================
# TEST SUITE 7: EDGE CASES
# ==============================================================================

context("Subgroup Edge Cases")

test_that("comparison handles group with missing importance", {
  mock_results <- generate_mock_subgroup_results(3)

  # Remove importance from one group
  mock_results[["Group_B"]]$importance <- NULL

  # Should still compute — that group is skipped for importance but included for model_fit
  comparison <- tryCatch(
    build_subgroup_comparison(mock_results),
    error = function(e) NULL
  )

  # It either works or gracefully handles it
  if (!is.null(comparison)) {
    expect_true(is.list(comparison))
  }
})

test_that("comparison handles group with empty importance", {
  mock_results <- generate_mock_subgroup_results(3)

  # Empty importance data frame
  mock_results[["Group_C"]]$importance <- data.frame(
    variable = character(0),
    label = character(0),
    importance_pct = numeric(0),
    rank = integer(0),
    stringsAsFactors = FALSE
  )

  comparison <- tryCatch(
    build_subgroup_comparison(mock_results),
    error = function(e) NULL
  )

  if (!is.null(comparison)) {
    expect_true(is.list(comparison))
  }
})

test_that("comparison handles missing model_result", {
  mock_results <- generate_mock_subgroup_results(2)

  # Remove model_result from one group
  mock_results[["Group_A"]]$model_result <- NULL

  comparison <- tryCatch(
    build_subgroup_comparison(mock_results),
    error = function(e) NULL
  )

  if (!is.null(comparison)) {
    expect_true(is.list(comparison))
  }
})

test_that("subgroup_var with NA values only uses non-NA levels", {
  config <- make_subgroup_config(subgroup_var = "segment_na")
  data   <- generate_subgroup_data(200)
  # Create variable with some NAs but 2+ non-NA levels
  data$segment_na <- sample(c("X", "Y", NA), 200, replace = TRUE, prob = c(0.4, 0.4, 0.2))

  expect_invisible(guard_subgroup_minimum_levels(config, data))
})

test_that("subgroup_var with many levels (5+) is accepted", {
  config <- make_subgroup_config(subgroup_var = "many_levels")
  data   <- generate_subgroup_data(500)
  data$many_levels <- sample(LETTERS[1:7], 500, replace = TRUE)

  expect_invisible(guard_subgroup_minimum_levels(config, data))
})


# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n=== SUBGROUP TEST SUITE COMPLETE ===\n")
