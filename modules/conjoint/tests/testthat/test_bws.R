# ==============================================================================
# TESTS: BEST-WORST SCALING (10_best_worst.R)
# ==============================================================================

fixture_path <- file.path(
  dirname(dirname(testthat::test_path())),
  "fixtures", "synthetic_data", "generate_conjoint_test_data.R"
)
if (file.exists(fixture_path)) source(fixture_path, local = TRUE)


test_that("BWS data generator produces valid data", {
  bws <- generate_bws_data(n_respondents = 10, n_tasks = 4, seed = 1)

  expect_is(bws$data, "data.frame")
  expect_true("best" %in% names(bws$data))
  expect_true("worst" %in% names(bws$data))

  # Exactly one best and one worst per task
  best_per_task <- tapply(bws$data$best, bws$data$choice_set_id, sum)
  worst_per_task <- tapply(bws$data$worst, bws$data$choice_set_id, sum)
  expect_true(all(best_per_task == 1))
  expect_true(all(worst_per_task == 1))

  # Best and worst are different
  both <- bws$data[bws$data$best == 1 & bws$data$worst == 1, ]
  expect_equal(nrow(both), 0)
})


test_that("validate_best_worst_data accepts valid data", {
  if (!exists("validate_best_worst_data", mode = "function")) skip("validate_best_worst_data not loaded")

  bws <- generate_bws_data(n_respondents = 10, n_tasks = 4, seed = 1)
  validation <- validate_best_worst_data(bws$data, bws$config)

  expect_equal(length(validation$critical), 0)
})


test_that("validate_best_worst_data rejects missing columns", {
  if (!exists("validate_best_worst_data", mode = "function")) skip("validate_best_worst_data not loaded")

  bad_data <- data.frame(x = 1:10, y = 1:10)
  config <- list(choice_set_column = "x")

  validation <- validate_best_worst_data(bad_data, config)
  expect_true(length(validation$critical) > 0)
})


test_that("validate_best_worst_data rejects multiple best per set", {
  if (!exists("validate_best_worst_data", mode = "function")) skip("validate_best_worst_data not loaded")

  bws <- generate_bws_data(n_respondents = 5, n_tasks = 2, seed = 1)
  # Corrupt: set all best to 1 in first task
  first_task <- bws$data$choice_set_id[1]
  bws$data$best[bws$data$choice_set_id == first_task] <- 1

  validation <- validate_best_worst_data(bws$data, bws$config)
  expect_true(length(validation$critical) > 0)
})


test_that("convert_best_worst_to_choice doubles the data", {
  if (!exists("convert_best_worst_to_choice", mode = "function")) skip("convert_best_worst_to_choice not loaded")

  bws <- generate_bws_data(n_respondents = 5, n_tasks = 2, seed = 1)
  choice_data <- convert_best_worst_to_choice(bws$data, bws$config)

  # Should have 2x the original rows
  expect_equal(nrow(choice_data), 2 * nrow(bws$data))
  expect_true("chosen" %in% names(choice_data))
  expect_true("choice_type" %in% names(choice_data))

  # Half should be "best", half "worst"
  expect_equal(sum(choice_data$choice_type == "best"), nrow(bws$data))
  expect_equal(sum(choice_data$choice_type == "worst"), nrow(bws$data))
})


test_that("create_best_worst_template creates valid structure", {
  if (!exists("create_best_worst_template", mode = "function")) skip("create_best_worst_template not loaded")

  template <- create_best_worst_template(n_respondents = 5, n_sets_per_resp = 4, n_alternatives = 3)

  expect_is(template, "data.frame")
  expect_equal(nrow(template), 5 * 4 * 3)
  expect_true("best" %in% names(template))
  expect_true("worst" %in% names(template))
  expect_true("resp_id" %in% names(template))
})
