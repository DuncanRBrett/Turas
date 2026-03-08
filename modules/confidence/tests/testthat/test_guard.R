# ==============================================================================
# TEST SUITE: TRS Guard Layer (00_guard.R)
# ==============================================================================
# Tests for the confidence module's TRS guard system
# ==============================================================================

library(testthat)

# ==============================================================================
# confidence_refuse()
# ==============================================================================

test_that("confidence_refuse throws turas_refusal condition", {
  expect_error(
    confidence_refuse(
      code = "TEST_CODE",
      title = "Test Title",
      problem = "Test problem",
      why_it_matters = "Test impact",
      how_to_fix = "Test fix"
    ),
    class = "turas_refusal"
  )
})

test_that("confidence_refuse auto-prefixes codes without valid prefix", {
  err <- tryCatch(
    confidence_refuse(
      code = "BARE_CODE",
      title = "Test",
      problem = "Test",
      why_it_matters = "Test",
      how_to_fix = "Test"
    ),
    turas_refusal = function(e) e
  )

  expect_true(grepl("^CFG_", err$code))
})

test_that("confidence_refuse preserves valid prefixes", {
  err <- tryCatch(
    confidence_refuse(
      code = "DATA_MISSING",
      title = "Test",
      problem = "Test",
      why_it_matters = "Test",
      how_to_fix = "Test"
    ),
    turas_refusal = function(e) e
  )

  expect_true(grepl("^DATA_", err$code))
})

test_that("confidence_refuse preserves IO_ prefix", {
  err <- tryCatch(
    confidence_refuse(
      code = "IO_FILE_NOT_FOUND",
      title = "Test",
      problem = "Test",
      why_it_matters = "Test",
      how_to_fix = "Test"
    ),
    turas_refusal = function(e) e
  )

  expect_true(grepl("^IO_", err$code))
})

# ==============================================================================
# confidence_guard_init()
# ==============================================================================

test_that("guard init creates correct structure", {
  guard <- confidence_guard_init()

  expect_type(guard, "list")
  expect_equal(guard$module, "CONFIDENCE")
  expect_type(guard$zero_cells, "list")
  expect_type(guard$small_samples, "list")
  expect_null(guard$method_used)
  expect_null(guard$confidence_level)
  expect_false(guard$bounds_capped)
  expect_null(guard$bootstrap_iterations)
  expect_equal(guard$questions_processed, 0)
  expect_type(guard$questions_skipped, "list")
})

# ==============================================================================
# Guard state tracking
# ==============================================================================

test_that("guard_record_zero_cell tracks zero cells", {
  guard <- confidence_guard_init()
  guard <- guard_record_zero_cell(guard, "Q1", "category_A")

  expect_true(length(guard$zero_cells) > 0)
  expect_true("Q1" %in% names(guard$zero_cells))
})

test_that("guard_record_small_sample tracks small samples", {
  guard <- confidence_guard_init()
  guard <- guard_record_small_sample(guard, "Q2", 15)

  expect_true(length(guard$small_samples) > 0)
  expect_equal(guard$small_samples[["Q2"]], 15)
})

test_that("guard_record_skipped_question tracks skipped questions", {
  guard <- confidence_guard_init()
  guard <- guard_record_skipped_question(guard, "Q3", "insufficient data")

  expect_true(length(guard$questions_skipped) > 0)
  expect_true("Q3" %in% names(guard$questions_skipped))
  expect_equal(guard$questions_skipped[["Q3"]]$reason, "insufficient data")
})

test_that("guard_record_bootstrap_iterations stores iterations", {
  guard <- confidence_guard_init()
  guard <- guard_record_bootstrap_iterations(guard, 5000)

  expect_equal(guard$bootstrap_iterations, 5000)
})

# ==============================================================================
# confidence_guard_summary()
# ==============================================================================

test_that("guard summary includes confidence-specific fields", {
  guard <- confidence_guard_init()
  guard <- guard_record_zero_cell(guard, "Q1", "zero_cat")
  guard <- guard_record_small_sample(guard, "Q2", 10)
  guard$method_used <- "Wilson"
  guard$confidence_level <- 0.95

  summary <- confidence_guard_summary(guard)

  expect_true(summary$has_issues)
  expect_true(length(summary$zero_cells) > 0)
  expect_true(length(summary$small_samples) > 0)
  expect_equal(summary$method_used, "Wilson")
  expect_equal(summary$confidence_level, 0.95)
})

test_that("guard summary reports no issues for clean guard", {
  guard <- confidence_guard_init()
  summary <- confidence_guard_summary(guard)

  expect_false(summary$has_issues)
  expect_equal(length(summary$zero_cells), 0)
  expect_equal(length(summary$small_samples), 0)
})

# ==============================================================================
# Validation gates
# ==============================================================================

test_that("validate_confidence_config refuses non-list", {
  expect_error(
    validate_confidence_config("not_a_list"),
    class = "turas_refusal"
  )
})

test_that("validate_confidence_config accepts list", {
  expect_invisible(validate_confidence_config(list(a = 1)))
})

test_that("validate_confidence_level refuses NULL", {
  expect_error(validate_confidence_level(NULL), class = "turas_refusal")
})

test_that("validate_confidence_level refuses out-of-range", {
  expect_error(validate_confidence_level(0), class = "turas_refusal")
  expect_error(validate_confidence_level(1), class = "turas_refusal")
  expect_error(validate_confidence_level(-0.5), class = "turas_refusal")
  expect_error(validate_confidence_level(1.5), class = "turas_refusal")
})

test_that("validate_confidence_level refuses very low values", {
  expect_error(validate_confidence_level(0.1), class = "turas_refusal")
  expect_error(validate_confidence_level(0.49), class = "turas_refusal")
})

test_that("validate_confidence_level accepts valid levels", {
  expect_invisible(validate_confidence_level(0.90))
  expect_invisible(validate_confidence_level(0.95))
  expect_invisible(validate_confidence_level(0.99))
  expect_invisible(validate_confidence_level(0.50))
})

test_that("validate_proportion_data refuses zero total", {
  guard <- confidence_guard_init()
  expect_error(
    validate_proportion_data(5, 0, "Q1", guard),
    class = "turas_refusal"
  )
})

test_that("validate_proportion_data refuses invalid successes", {
  guard <- confidence_guard_init()
  expect_error(
    validate_proportion_data(NA, 100, "Q1", guard),
    class = "turas_refusal"
  )
})

test_that("validate_proportion_data refuses successes > total", {
  guard <- confidence_guard_init()
  expect_error(
    validate_proportion_data(150, 100, "Q1", guard),
    class = "turas_refusal"
  )
})

test_that("validate_proportion_data tracks zero cells", {
  guard <- confidence_guard_init()
  guard <- validate_proportion_data(0, 100, "Q1", guard)
  expect_true(length(guard$zero_cells) > 0)
})

test_that("validate_proportion_data tracks small samples", {
  guard <- confidence_guard_init()
  guard <- validate_proportion_data(5, 20, "Q1", guard)
  expect_true(length(guard$small_samples) > 0)
})

test_that("validate_mean_data refuses empty values", {
  guard <- confidence_guard_init()
  expect_error(
    validate_mean_data(numeric(0), "Q1", guard),
    class = "turas_refusal"
  )
})

test_that("validate_mean_data refuses all-NA values", {
  guard <- confidence_guard_init()
  expect_error(
    validate_mean_data(c(NA, NA, NA), "Q1", guard),
    class = "turas_refusal"
  )
})

test_that("validate_mean_data refuses single value", {
  guard <- confidence_guard_init()
  expect_error(
    validate_mean_data(c(5.0), "Q1", guard),
    class = "turas_refusal"
  )
})

test_that("validate_mean_data flags zero variance", {
  guard <- confidence_guard_init()
  guard <- validate_mean_data(rep(5, 10), "Q1", guard)
  expect_true(length(guard$stability_flags) > 0)
  expect_true(any(grepl("Zero variance", guard$stability_flags)))
})

# ==============================================================================
# Status determination
# ==============================================================================

test_that("confidence_determine_status returns PASS for clean guard", {
  guard <- confidence_guard_init()
  status <- confidence_determine_status(guard, questions_processed = 5)

  expect_equal(status$run_status, "PASS")
})

test_that("confidence_determine_status returns PARTIAL for issues", {
  guard <- confidence_guard_init()
  guard <- guard_record_zero_cell(guard, "Q1", "cat_a")

  status <- confidence_determine_status(guard, questions_processed = 5)

  expect_equal(status$run_status, "PARTIAL")
  expect_true(length(status$degraded_reasons) > 0)
})

test_that("confidence_determine_status returns PARTIAL for skipped questions", {
  guard <- confidence_guard_init()

  status <- confidence_determine_status(
    guard,
    questions_processed = 3,
    skipped_questions = list(Q4 = "too few observations")
  )

  expect_equal(status$run_status, "PARTIAL")
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
