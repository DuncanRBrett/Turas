# ==============================================================================
# KEYDRIVER GUARD LAYER TESTS
# ==============================================================================
#
# Tests for modules/keydriver/R/00_guard.R
#
# Covers:
#   - keydriver_refuse() TRS structure and code prefix handling
#   - keydriver_guard_init() state initialization
#   - guard_record_assumption_violation() and guard_record_encoding_issue()
#   - guard_check_feature_packages() package availability checks
#   - guard_validate_model_assumptions() post-fit validation
#   - validate_keydriver_config() config validation gate
#   - validate_keydriver_data() data validation gate
#
# ==============================================================================

# Locate module root robustly (works with test_file and test_dir)
.find_module_dir <- function() {
  ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(ofile)) {
    return(normalizePath(file.path(dirname(ofile), "..", ".."), mustWork = FALSE))
  }
  tp <- tryCatch(testthat::test_path(), error = function(e) ".")
  normalizePath(file.path(tp, "..", ".."), mustWork = FALSE)
}
module_dir <- .find_module_dir()
project_root <- normalizePath(file.path(module_dir, "..", ".."), mustWork = FALSE)

# Source test data generators
source(file.path(module_dir, "tests", "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure (required by guard functions)
shared_lib <- file.path(project_root, "modules", "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))

# Source the guard module under test
guard_path <- file.path(module_dir, "R", "00_guard.R")
source(guard_path)


# ==============================================================================
# keydriver_refuse() - TRS refusal wrapper
# ==============================================================================

test_that("keydriver_refuse returns correct TRS condition structure", {

  err <- tryCatch(
    keydriver_refuse(
      code = "CFG_TEST_ERROR",
      title = "Test Error",
      problem = "Something went wrong in the test.",
      why_it_matters = "This matters because tests must work.",
      how_to_fix = "Fix the test."
    ),
    turas_refusal = function(e) e
  )

  expect_s3_class(err, "turas_refusal")
  expect_equal(err$code, "CFG_TEST_ERROR")
  expect_equal(err$title, "Test Error")
  expect_equal(err$problem, "Something went wrong in the test.")
  expect_equal(err$module, "KEYDRIVER")
  expect_match(err$message, "REFUSE")
})

test_that("keydriver_refuse auto-prefixes codes without valid TRS prefix", {

  # A code without a recognized prefix should get "CFG_" prepended

  err <- tryCatch(
    keydriver_refuse(
      code = "MISSING_SOMETHING",
      title = "Missing Something",
      problem = "A required thing is missing.",
      why_it_matters = "Analysis cannot proceed without it.",
      how_to_fix = "Add the missing thing."
    ),
    turas_refusal = function(e) e
  )

  expect_equal(err$code, "CFG_MISSING_SOMETHING")
})

test_that("keydriver_refuse preserves codes that already have valid prefix", {
  prefixed_codes <- c("DATA_BAD_INPUT", "IO_FILE_GONE", "MODEL_FIT_FAIL",
                       "MAPPER_NO_MAP", "PKG_NOT_FOUND", "FEATURE_BROKEN", "BUG_OOPS")

  for (code in prefixed_codes) {
    err <- tryCatch(
      keydriver_refuse(
        code = code,
        title = "Test",
        problem = "Test problem.",
        why_it_matters = "Test importance.",
        how_to_fix = "Test fix."
      ),
      turas_refusal = function(e) e
    )
    expect_equal(err$code, code, info = paste("Code should be preserved:", code))
  }
})

test_that("keydriver_refuse passes optional diagnostics through", {
  err <- tryCatch(
    keydriver_refuse(
      code = "DATA_MISSING_COLS",
      title = "Missing Columns",
      problem = "Required columns are missing.",
      why_it_matters = "Cannot run analysis without required columns.",
      how_to_fix = "Add the missing columns.",
      expected = c("col_a", "col_b"),
      observed = c("col_a", "col_c"),
      missing = c("col_b")
    ),
    turas_refusal = function(e) e
  )

  expect_equal(err$expected, c("col_a", "col_b"))
  expect_equal(err$observed, c("col_a", "col_c"))
  expect_equal(err$missing, c("col_b"))
})


# ==============================================================================
# keydriver_guard_init() - Guard state initialization
# ==============================================================================

test_that("keydriver_guard_init creates guard state with all expected fields", {
  guard <- keydriver_guard_init()

  # Standard TRS guard fields

expect_equal(guard$module, "KEYDRIVER")
  expect_true(length(guard$warnings) == 0)

  # KeyDriver-specific fields
  expect_equal(guard$excluded_drivers, character(0))
  expect_equal(guard$zero_variance_drivers, character(0))
  expect_equal(guard$collinearity_warnings, list())
  expect_equal(guard$shap_status, "not_run")
  expect_equal(guard$quadrant_status, "not_run")
  expect_equal(guard$assumption_violations, list())
  expect_equal(guard$encoding_issues, list())
})

test_that("keydriver_guard_init inherits trs_guard_state class", {
  guard <- keydriver_guard_init()
  expect_s3_class(guard, "trs_guard_state")
})


# ==============================================================================
# guard_record_assumption_violation()
# ==============================================================================

test_that("guard_record_assumption_violation records a single violation", {
  guard <- keydriver_guard_init()
  guard <- guard_record_assumption_violation(guard, "high_vif", "VIF for driver_1 is 15.2")

  expect_equal(length(guard$assumption_violations), 1)
  expect_equal(guard$assumption_violations[[1]]$assumption, "high_vif")
  expect_equal(guard$assumption_violations[[1]]$details, "VIF for driver_1 is 15.2")
})

test_that("guard_record_assumption_violation accumulates multiple violations", {
  guard <- keydriver_guard_init()
  guard <- guard_record_assumption_violation(guard, "high_vif", "VIF=12 for driver_1")
  guard <- guard_record_assumption_violation(guard, "non_normal_residuals", "Shapiro p=0.001")
  guard <- guard_record_assumption_violation(guard, "high_vif", "VIF=18 for driver_3")

  expect_equal(length(guard$assumption_violations), 3)
  expect_equal(guard$assumption_violations[[2]]$assumption, "non_normal_residuals")
  # Each violation should also generate a warning
  expect_true(length(guard$warnings) >= 3)
})


# ==============================================================================
# guard_record_encoding_issue()
# ==============================================================================

test_that("guard_record_encoding_issue records driver encoding problems", {
  guard <- keydriver_guard_init()
  guard <- guard_record_encoding_issue(guard, "region", "Factor with 50 levels collapsed to 10")

  expect_equal(length(guard$encoding_issues), 1)
  expect_equal(guard$encoding_issues[[1]]$driver, "region")
  expect_match(guard$encoding_issues[[1]]$issue, "Factor with 50 levels")
})

test_that("guard_record_encoding_issue accumulates multiple issues", {
  guard <- keydriver_guard_init()
  guard <- guard_record_encoding_issue(guard, "region", "Too many levels")
  guard <- guard_record_encoding_issue(guard, "brand", "Non-ASCII characters found")

  expect_equal(length(guard$encoding_issues), 2)
  expect_equal(guard$encoding_issues[[1]]$driver, "region")
  expect_equal(guard$encoding_issues[[2]]$driver, "brand")
  expect_true(length(guard$warnings) >= 2)
})


# ==============================================================================
# guard_check_feature_packages()
# ==============================================================================

test_that("guard_check_feature_packages adds no warnings when features are disabled", {
  guard <- keydriver_guard_init()
  guard <- guard_check_feature_packages(enable_shap = FALSE, enable_quadrant = FALSE, guard = guard)

  expect_equal(length(guard$warnings), 0)
})

test_that("guard_check_feature_packages warns when SHAP packages are missing", {
  guard <- keydriver_guard_init()

  # Mock requireNamespace to simulate missing packages
  # Since xgboost/shapviz may or may not be installed, we test the logic path

  # by checking that warnings are produced when packages are truly missing
  mock_env <- new.env(parent = environment(guard_check_feature_packages))
  mock_env$requireNamespace <- function(pkg, quietly = TRUE) {
    return(FALSE)  # Simulate all packages missing
  }

  # Temporarily override requireNamespace in the function's environment
  original_fn <- guard_check_feature_packages
  environment(original_fn) <- mock_env
  guard <- original_fn(enable_shap = TRUE, enable_quadrant = FALSE, guard = guard)

  # Should have warnings for xgboost and shapviz
  shap_warnings <- grep("SHAP requires", guard$warnings, value = TRUE)
  expect_true(length(shap_warnings) >= 1)
})

test_that("guard_check_feature_packages warns when quadrant package (ggplot2) is missing", {
  guard <- keydriver_guard_init()

  mock_env <- new.env(parent = environment(guard_check_feature_packages))
  mock_env$requireNamespace <- function(pkg, quietly = TRUE) {
    return(FALSE)
  }

  original_fn <- guard_check_feature_packages
  environment(original_fn) <- mock_env
  guard <- original_fn(enable_shap = FALSE, enable_quadrant = TRUE, guard = guard)

  ggplot_warnings <- grep("ggplot2", guard$warnings, value = TRUE)
  expect_true(length(ggplot_warnings) >= 1)
})


# ==============================================================================
# guard_validate_model_assumptions()
# ==============================================================================

test_that("guard_validate_model_assumptions detects high VIF", {
  # Generate data with collinear drivers
  set.seed(99)
  n <- 200
  x1 <- rnorm(n)
  x2 <- x1 + rnorm(n, sd = 0.05)  # nearly identical to x1 => high VIF
  x3 <- rnorm(n)
  y <- 0.5 * x1 + 0.3 * x3 + rnorm(n, sd = 0.5)
  data <- data.frame(y = y, x1 = x1, x2 = x2, x3 = x3)

  model <- lm(y ~ x1 + x2 + x3, data = data)
  guard <- keydriver_guard_init()
  config <- list(driver_vars = c("x1", "x2", "x3"))

  guard <- guard_validate_model_assumptions(model, data, config, guard)

  # Should detect high VIF for x1 and/or x2
  vif_violations <- Filter(
    function(v) v$assumption == "high_vif",
    guard$assumption_violations
  )
  expect_true(length(vif_violations) > 0)
})

test_that("guard_validate_model_assumptions detects non-normal residuals", {
  # Generate data with skewed residuals
  set.seed(101)
  n <- 300
  x1 <- rnorm(n)
  x2 <- rnorm(n)
  # Use exponential noise to create non-normal residuals
  y <- 0.5 * x1 + 0.3 * x2 + rexp(n, rate = 1)
  data <- data.frame(y = y, x1 = x1, x2 = x2)

  model <- lm(y ~ x1 + x2, data = data)
  guard <- keydriver_guard_init()
  config <- list(driver_vars = c("x1", "x2"))

  guard <- guard_validate_model_assumptions(model, data, config, guard)

  # Should detect non-normal residuals (p < 0.01 from Shapiro-Wilk)
  normality_violations <- Filter(
    function(v) v$assumption == "non_normal_residuals",
    guard$assumption_violations
  )
  expect_true(length(normality_violations) > 0)
})

test_that("guard_validate_model_assumptions records no violations for well-behaved data", {
  # Generate well-behaved data
  set.seed(202)
  n <- 200
  x1 <- rnorm(n)
  x2 <- rnorm(n)
  x3 <- rnorm(n)
  y <- 0.5 * x1 + 0.3 * x2 + 0.2 * x3 + rnorm(n, sd = 0.5)
  data <- data.frame(y = y, x1 = x1, x2 = x2, x3 = x3)

  model <- lm(y ~ x1 + x2 + x3, data = data)
  guard <- keydriver_guard_init()
  config <- list(driver_vars = c("x1", "x2", "x3"))

  guard <- guard_validate_model_assumptions(model, data, config, guard)

  expect_equal(length(guard$assumption_violations), 0)
})


# ==============================================================================
# validate_keydriver_config() - Config validation gate
# ==============================================================================

test_that("validate_keydriver_config refuses when outcome_var is missing", {
  config <- list(outcome_var = NULL, driver_vars = c("d1", "d2", "d3"))

  expect_error(
    validate_keydriver_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_keydriver_config refuses when driver_vars is empty", {
  config <- list(outcome_var = "outcome", driver_vars = character(0))

  expect_error(
    validate_keydriver_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_keydriver_config refuses when fewer than 2 drivers", {
  config <- list(outcome_var = "outcome", driver_vars = c("d1"))

  expect_error(
    validate_keydriver_config(config),
    class = "turas_refusal"
  )
})

test_that("validate_keydriver_config passes with valid config", {
  config <- list(outcome_var = "outcome", driver_vars = c("d1", "d2", "d3"))

  # Should not throw any error
  result <- validate_keydriver_config(config)
  expect_true(result)
})


# ==============================================================================
# keydriver_guard_summary() - Summary with KDA-specific fields
# ==============================================================================

test_that("keydriver_guard_summary includes assumption_violations and encoding_issues in has_issues", {
  guard <- keydriver_guard_init()

  # Clean guard should not have issues
  summary_clean <- keydriver_guard_summary(guard)
  expect_false(summary_clean$has_issues)

  # Add an assumption violation
  guard <- guard_record_assumption_violation(guard, "high_vif", "VIF=12")
  summary_with_issue <- keydriver_guard_summary(guard)
  expect_true(summary_with_issue$has_issues)
  expect_equal(length(summary_with_issue$assumption_violations), 1)
})
