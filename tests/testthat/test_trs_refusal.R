# ==============================================================================
# TESTS: TRS REFUSAL INFRASTRUCTURE
# ==============================================================================
#
# Tests for the shared TRS v1.0 refusal and reliability framework.
# Per TRS v1.0, each module must have:
#   - golden-path test
#   - refusal test
#   - mapping failure test
#   - no-silent-partial test
#
# These tests verify the core TRS infrastructure works correctly.
#
# ==============================================================================

# Load testthat and TRS infrastructure
library(testthat)

# Source the TRS refusal module
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
if (!grepl("Turas$", turas_root)) {
  turas_root <- file.path(turas_root, "..")
}
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))


# ==============================================================================
# TEST: Refusal Code Validation
# ==============================================================================

test_that("trs_validate_code accepts valid codes", {
  expect_true(trs_validate_code("CFG_MISSING_FILE"))
  expect_true(trs_validate_code("DATA_INVALID_FORMAT"))
  expect_true(trs_validate_code("IO_FILE_NOT_FOUND"))
  expect_true(trs_validate_code("MODEL_FIT_FAILED"))
  expect_true(trs_validate_code("MAPPER_UNMAPPED_COEFFICIENTS"))
  expect_true(trs_validate_code("PKG_MISSING_DEPENDENCY"))
  expect_true(trs_validate_code("FEATURE_NOT_IMPLEMENTED"))
  expect_true(trs_validate_code("BUG_INTERNAL_ERROR"))
})

test_that("trs_validate_code rejects invalid prefixes", {
  expect_error(trs_validate_code("INVALID_CODE"), "Invalid refusal code prefix")
  expect_error(trs_validate_code("ERROR_SOMETHING"), "Invalid refusal code prefix")
  expect_error(trs_validate_code("WARN_SOMETHING"), "Invalid refusal code prefix")
})

test_that("trs_validate_code rejects invalid formats", {
  expect_error(trs_validate_code("cfg_lowercase"), "Invalid refusal code prefix")
  expect_error(trs_validate_code("CFG-HYPHEN"), "must contain only uppercase")
  expect_error(trs_validate_code("CFG SPACE"), "must contain only uppercase")
})

test_that("trs_validate_code rejects non-string inputs", {
  expect_error(trs_validate_code(NULL), "must be a single character string")
  expect_error(trs_validate_code(123), "must be a single character string")
  expect_error(trs_validate_code(c("CFG_A", "CFG_B")), "must be a single character string")
})


# ==============================================================================
# TEST: turas_refuse() Function
# ==============================================================================

test_that("turas_refuse throws turas_refusal condition", {
  expect_error(
    turas_refuse(
      code = "CFG_TEST_ERROR",
      title = "Test Error",
      problem = "This is a test problem",
      how_to_fix = "Fix the test"
    ),
    class = "turas_refusal"
  )
})

test_that("turas_refuse message contains required sections", {
  err <- tryCatch(
    turas_refuse(
      code = "CFG_TEST_ERROR",
      title = "Test Error",
      problem = "This is a test problem",
      why_it_matters = "This matters because of testing",
      how_to_fix = "Fix the test"
    ),
    turas_refusal = function(e) e
  )

  msg <- conditionMessage(err)
  expect_match(msg, "\\[REFUSE\\]")
  expect_match(msg, "CFG_TEST_ERROR")
  expect_match(msg, "Problem:")
  expect_match(msg, "How to fix:")
  expect_match(msg, "Why it matters:")
})

test_that("turas_refuse includes diagnostics when provided", {
  err <- tryCatch(
    turas_refuse(
      code = "MAPPER_TEST",
      title = "Mapping Error",
      problem = "Test mapping problem",
      how_to_fix = "Fix mapping",
      expected = c("A", "B", "C"),
      observed = c("A", "B"),
      missing = c("C"),
      unmapped = c("D")
    ),
    turas_refusal = function(e) e
  )

  msg <- conditionMessage(err)
  expect_match(msg, "Diagnostics:")
  expect_match(msg, "Expected:")
  expect_match(msg, "Observed:")
  expect_match(msg, "Missing:")
  expect_match(msg, "Unmapped:")
})

test_that("turas_refuse rejects invalid codes", {
  expect_error(
    turas_refuse(
      code = "INVALID_CODE",
      title = "Test",
      problem = "Test",
      how_to_fix = "Test"
    ),
    "Invalid refusal code prefix"
  )
})


# ==============================================================================
# TEST: with_refusal_handler()
# ==============================================================================

test_that("with_refusal_handler passes through successful results", {
  result <- with_refusal_handler({
    42
  })
  expect_equal(result, 42)
})

test_that("with_refusal_handler catches turas_refusal", {
  result <- with_refusal_handler({
    turas_refuse(
      code = "CFG_TEST",
      title = "Test",
      problem = "Test problem",
      how_to_fix = "Test fix"
    )
  })

  expect_true(is_refusal(result))
  expect_equal(result$run_status, "REFUSE")
  expect_equal(result$code, "CFG_TEST")
})

test_that("with_refusal_handler catches unexpected errors as BUG", {
  result <- with_refusal_handler({
    stop("Unexpected error")
  })

  expect_true(is_error(result))
  expect_equal(result$run_status, "ERROR")
  expect_match(result$message, "Unexpected error")
})


# ==============================================================================
# TEST: is_refusal() and is_error()
# ==============================================================================

test_that("is_refusal correctly identifies refusal results", {
  refusal_result <- structure(
    list(refused = TRUE, run_status = "REFUSE"),
    class = "turas_refusal_result"
  )
  expect_true(is_refusal(refusal_result))

  normal_result <- list(value = 42)
  expect_false(is_refusal(normal_result))
})

test_that("is_error correctly identifies error results", {
  error_result <- structure(
    list(error = TRUE, run_status = "ERROR"),
    class = "turas_error_result"
  )
  expect_true(is_error(error_result))

  normal_result <- list(value = 42)
  expect_false(is_error(normal_result))
})


# ==============================================================================
# TEST: TRS Status Functions
# ==============================================================================

test_that("trs_status_pass creates correct status", {
  status <- trs_status_pass("TEST_MODULE")
  expect_equal(status$run_status, "PASS")
  expect_equal(status$module, "TEST_MODULE")
  expect_s3_class(status, "trs_status")
})

test_that("trs_status_partial requires reasons and affected outputs", {
  expect_error(
    trs_status_partial("TEST", degraded_reasons = NULL, affected_outputs = c("output1")),
    "requires at least one degraded_reason"
  )

  expect_error(
    trs_status_partial("TEST", degraded_reasons = c("reason1"), affected_outputs = NULL),
    "requires at least one affected_output"
  )

  # Valid call
  status <- trs_status_partial(
    "TEST",
    degraded_reasons = c("Low sample size"),
    affected_outputs = c("confidence_intervals")
  )
  expect_equal(status$run_status, "PARTIAL")
  expect_equal(status$degraded_reasons, c("Low sample size"))
})

test_that("trs_status_refuse creates correct status", {
  status <- trs_status_refuse("TEST", code = "CFG_ERROR", reason = "Configuration error")
  expect_equal(status$run_status, "REFUSE")
  expect_equal(status$details$code, "CFG_ERROR")
})


# ==============================================================================
# TEST: Guard State Functions
# ==============================================================================

test_that("guard_init creates proper structure", {
  guard <- guard_init("TEST_MODULE")
  expect_equal(guard$module, "TEST_MODULE")
  expect_equal(length(guard$warnings), 0)
  expect_equal(length(guard$stability_flags), 0)
  expect_false(guard$fallback_used)
  expect_s3_class(guard, "trs_guard_state")
})

test_that("guard_warn adds warnings correctly", {
  guard <- guard_init("TEST")
  guard <- guard_warn(guard, "Test warning", "test_category")

  expect_equal(length(guard$warnings), 1)
  expect_equal(guard$warnings[1], "Test warning")
  expect_equal(guard$soft_failures$test_category, "Test warning")
})

test_that("guard_flag_stability adds unique flags", {
  guard <- guard_init("TEST")
  guard <- guard_flag_stability(guard, "Flag 1")
  guard <- guard_flag_stability(guard, "Flag 2")
  guard <- guard_flag_stability(guard, "Flag 1")  # Duplicate

  expect_equal(length(guard$stability_flags), 2)
  expect_true("Flag 1" %in% guard$stability_flags)
  expect_true("Flag 2" %in% guard$stability_flags)
})

test_that("guard_summary reports issues correctly", {
  guard <- guard_init("TEST")

  # Empty guard has no issues
  summary <- guard_summary(guard)
  expect_false(summary$has_issues)

  # Guard with warning has issues
  guard <- guard_warn(guard, "Warning")
  summary <- guard_summary(guard)
  expect_true(summary$has_issues)
  expect_equal(summary$n_warnings, 1)
})


# ==============================================================================
# TEST: Mapping Validation Gate
# ==============================================================================

test_that("validate_mapping_coverage passes on complete mapping", {
  mapping_table <- data.frame(
    coef_name = c("varA", "varB", "varC"),
    predictor = c("A", "B", "C"),
    level = c("level1", "level2", "level3")
  )

  model_terms <- c("(Intercept)", "varA", "varB", "varC")

  expect_true(validate_mapping_coverage(
    mapping_table,
    model_terms,
    key_col = "coef_name"
  ))
})

test_that("validate_mapping_coverage refuses on empty model terms", {
  mapping_table <- data.frame(coef_name = c("varA"))

  expect_error(
    validate_mapping_coverage(mapping_table, NULL),
    class = "turas_refusal"
  )

  expect_error(
    validate_mapping_coverage(mapping_table, character(0)),
    class = "turas_refusal"
  )
})

test_that("validate_mapping_coverage refuses on empty mapping", {
  mapping_table <- data.frame(coef_name = character(0))
  model_terms <- c("varA", "varB")

  expect_error(
    validate_mapping_coverage(mapping_table, model_terms),
    class = "turas_refusal"
  )
})

test_that("validate_mapping_coverage refuses on unmapped coefficients", {
  mapping_table <- data.frame(coef_name = c("varA", "varB"))
  model_terms <- c("(Intercept)", "varA", "varB", "varC")

  err <- tryCatch(
    validate_mapping_coverage(mapping_table, model_terms),
    turas_refusal = function(e) e
  )

  expect_equal(err$code, "MAPPER_UNMAPPED_COEFFICIENTS")
  expect_true("varC" %in% err$unmapped)
})

test_that("validate_mapping_coverage excludes intercept and thresholds", {
  mapping_table <- data.frame(coef_name = c("varA"))
  model_terms <- c("(Intercept)", "varA", "1|2", "2|3")  # Ordinal thresholds

  # Should pass because intercept and thresholds are excluded
  expect_true(validate_mapping_coverage(mapping_table, model_terms))
})


# ==============================================================================
# TEST: Console Banner Functions
# ==============================================================================

test_that("trs_banner_start produces output", {
  output <- capture.output(trs_banner_start("TEST_MODULE", "1.0"))
  expect_true(any(grepl("TEST_MODULE", output)))
  expect_true(any(grepl("Starting Analysis", output)))
})

test_that("trs_banner_end produces correct status output", {
  output_pass <- capture.output(trs_banner_end("TEST", "PASS"))
  expect_true(any(grepl("COMPLETED SUCCESSFULLY", output_pass)))

  output_partial <- capture.output(trs_banner_end("TEST", "PARTIAL"))
  expect_true(any(grepl("COMPLETED WITH WARNINGS", output_partial)))

  output_refuse <- capture.output(trs_banner_end("TEST", "REFUSE"))
  expect_true(any(grepl("REFUSED TO RUN", output_refuse)))
})


# ==============================================================================
# TEST: No Silent Degradation
# ==============================================================================

test_that("PARTIAL status cannot be created without declaring degradation", {
  # This tests the TRS v1.0 requirement that degraded outputs must be explicit

  expect_error(
    trs_status_partial("TEST", degraded_reasons = character(0), affected_outputs = c("x")),
    "requires at least one degraded_reason"
  )

  expect_error(
    trs_status_partial("TEST", degraded_reasons = c("x"), affected_outputs = character(0)),
    "requires at least one affected_output"
  )
})


# ==============================================================================
# TEST: Backwards Compatibility Aliases
# ==============================================================================

test_that("trs_refuse is alias for turas_refuse", {
  expect_error(
    trs_refuse(
      code = "CFG_TEST",
      title = "Test",
      problem = "Test",
      how_to_fix = "Test"
    ),
    class = "turas_refusal"
  )
})

test_that("trs_with_handler is alias for with_refusal_handler", {
  result <- trs_with_handler({ 42 })
  expect_equal(result, 42)
})
