# ==============================================================================
# TESTS: Integration Tests (full pipeline)
# ==============================================================================
# Note: run_weighting.R is sourced in setup.R with TURAS_LAUNCHER_ACTIVE = TRUE
# so all functions (run_weighting, quick_design_weight, quick_rim_weight) are
# already available.
# ==============================================================================

test_that("run_weighting with design weights returns PASS", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_false(is_refusal(result))
  expect_equal(result$status, "PASS")
  expect_true("design_weight" %in% names(result$data))
  expect_equal(nrow(result$data), 200)
  expect_true(all(!is.na(result$data$design_weight)))
})

test_that("run_weighting with rim weights returns PASS", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("survey")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_rim_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_false(is_refusal(result))
  expect_equal(result$status, "PASS")
  expect_true("rim_weight" %in% names(result$data))
})

test_that("run_weighting with combined config produces both weights", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("survey")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_combined_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_false(is_refusal(result))
  expect_true("design_weight" %in% names(result$data))
  expect_true("rim_weight" %in% names(result$data))
  expect_equal(length(result$weight_names), 2)
})

test_that("run_weighting with invalid config returns refusal", {
  skip_if_not_installed("openxlsx")

  config_path <- create_bad_config_missing_sheet()
  on.exit(unlink(config_path))

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_true(is_refusal(result) || is_error(result))
})

test_that("run_weighting writes output file when configured", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  output_path <- file.path(tempdir(), "test_output.csv")
  on.exit({
    unlink(data_path)
    unlink(output_path)
  })

  config_path <- create_design_weight_config(data_path,
                                              output_file = output_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_false(is_refusal(result))
  expect_true(file.exists(output_path))
})

test_that("run_weighting result contains run_state", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 100)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_false(is_refusal(result))
  expect_true("run_state" %in% names(result))
  expect_true("status" %in% names(result$run_state))
  expect_true("duration_seconds" %in% names(result$run_state))
})

test_that("quick_design_weight works", {
  data <- data.frame(
    id = 1:60,
    Size = c(rep("Small", 20), rep("Medium", 20), rep("Large", 20)),
    stringsAsFactors = FALSE
  )

  pop <- c("Small" = 5000, "Medium" = 2000, "Large" = 500)

  result <- quick_design_weight(data, "Size", pop)

  expect_true("weight" %in% names(result))
  expect_equal(nrow(result), 60)
  # Small has largest pop, so should have highest weight
  expect_true(mean(result$weight[result$Size == "Small"]) >
              mean(result$weight[result$Size == "Large"]))
})

test_that("quick_rim_weight works", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- data.frame(
    Gender = sample(c("Male", "Female"), 100, replace = TRUE, prob = c(0.6, 0.4)),
    stringsAsFactors = FALSE
  )

  targets <- list(
    Gender = c("Male" = 0.50, "Female" = 0.50)
  )

  result <- quick_rim_weight(data, targets)

  expect_true("weight" %in% names(result))
  expect_equal(nrow(result), 100)
})
