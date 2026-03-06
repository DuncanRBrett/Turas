# ==============================================================================
# TESTS: Guard Layer (00_guard.R)
# ==============================================================================

test_that("guard_config_file rejects NULL path", {
  expect_error(guard_config_file(NULL), class = "turas_refusal")
})

test_that("guard_config_file rejects non-string path", {
  expect_error(guard_config_file(123), class = "turas_refusal")
})

test_that("guard_config_file rejects non-existent file", {
  expect_error(guard_config_file("/nonexistent/path.xlsx"), class = "turas_refusal")
})

test_that("guard_config_file accepts valid file", {
  tmp <- tempfile(fileext = ".xlsx")
  file.create(tmp)
  on.exit(unlink(tmp))
  expect_true(guard_config_file(tmp))
})

test_that("guard_required_sheet rejects missing sheet", {
  expect_error(
    guard_required_sheet("config.xlsx", "Missing_Sheet", c("General", "Other")),
    class = "turas_refusal"
  )
})

test_that("guard_required_sheet accepts present sheet", {
  expect_true(
    guard_required_sheet("config.xlsx", "General", c("General", "Other"))
  )
})

test_that("guard_data_file rejects NULL", {
  expect_error(guard_data_file(NULL), class = "turas_refusal")
})

test_that("guard_data_file rejects non-existent file", {
  expect_error(guard_data_file("/nonexistent/data.csv"), class = "turas_refusal")
})

test_that("guard_data_file accepts existing file", {
  tmp <- tempfile(fileext = ".csv")
  file.create(tmp)
  on.exit(unlink(tmp))
  expect_true(guard_data_file(tmp))
})

test_that("guard_required_columns detects missing columns", {
  df <- data.frame(a = 1, b = 2)
  expect_error(
    guard_required_columns(df, c("a", "c"), "TestSheet"),
    class = "turas_refusal"
  )
})

test_that("guard_required_columns passes with all columns present", {
  df <- data.frame(a = 1, b = 2, c = 3)
  expect_true(guard_required_columns(df, c("a", "b"), "TestSheet"))
})

test_that("guard_variable_exists rejects missing variable", {
  data <- data.frame(x = 1, y = 2)
  expect_error(
    guard_variable_exists(data, "missing_col", "test"),
    class = "turas_refusal"
  )
})

test_that("guard_variable_exists accepts present variable", {
  data <- data.frame(x = 1, y = 2)
  expect_true(guard_variable_exists(data, "x", "test"))
})

test_that("guard_rim_targets_sum rejects sum far from 100", {
  expect_error(
    guard_rim_targets_sum("Gender", c("M", "F"), c(60, 60)),
    class = "turas_refusal"
  )
})

test_that("guard_rim_targets_sum accepts sum of exactly 100", {
  expect_true(
    guard_rim_targets_sum("Gender", c("M", "F"), c(48, 52))
  )
})

test_that("guard_rim_targets_sum accepts sum within tolerance", {
  # 0.5% tolerance
  expect_true(
    guard_rim_targets_sum("Gender", c("M", "F"), c(48, 52.3))
  )
})

test_that("guard_rim_targets_sum rejects sum outside tolerance", {
  expect_error(
    guard_rim_targets_sum("Gender", c("M", "F"), c(48, 53)),
    class = "turas_refusal"
  )
})

test_that("guard_survey_available passes when survey package installed", {
  skip_if_not_installed("survey")
  expect_true(guard_survey_available())
})

test_that("guard_positive_population rejects zero population", {
  expect_error(
    guard_positive_population(c("A", "B"), c(100, 0)),
    class = "turas_refusal"
  )
})

test_that("guard_positive_population rejects negative population", {
  expect_error(
    guard_positive_population(c("A", "B"), c(100, -50)),
    class = "turas_refusal"
  )
})

test_that("guard_positive_population accepts valid populations", {
  expect_true(
    guard_positive_population(c("A", "B"), c(100, 200))
  )
})

test_that("guard_categories_match rejects categories not in data", {
  expect_error(
    guard_categories_match(
      c("A", "B", "C"), c("A", "B"), "var1", "test"
    ),
    class = "turas_refusal"
  )
})

test_that("guard_categories_match rejects missing rim categories", {
  expect_error(
    guard_categories_match(
      c("A"), c("A", "B"), "var1", "rim weights"
    ),
    class = "turas_refusal"
  )
})

test_that("guard_categories_match passes with exact match", {
  expect_true(
    guard_categories_match(
      c("A", "B"), c("A", "B"), "var1", "test"
    )
  )
})

test_that("weighting_refuse creates turas_refusal condition", {
  expect_error(
    weighting_refuse(
      code = "CFG_TEST",
      title = "Test Refusal",
      problem = "Test problem",
      why_it_matters = "Test impact",
      how_to_fix = "Test fix"
    ),
    class = "turas_refusal"
  )
})

test_that("RIM_TARGET_SUM_TOLERANCE constant exists", {
  expect_true(exists("RIM_TARGET_SUM_TOLERANCE"))
  expect_equal(RIM_TARGET_SUM_TOLERANCE, 0.5)
})
