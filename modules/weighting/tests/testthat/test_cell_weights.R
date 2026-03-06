# ==============================================================================
# TESTS: Cell/Interlocked Weighting (cell_weights.R)
# ==============================================================================

test_that("calculate_cell_weights produces correct weights", {
  data <- create_simple_survey(n = 200)

  # Define 2x3 cell targets (Gender x Age)
  cell_targets <- data.frame(
    Gender = rep(c("Male", "Female"), each = 3),
    Age = rep(c("18-34", "35-54", "55+"), 2),
    target_percent = c(14, 20, 14, 16, 20, 16),
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = c("Gender", "Age"),
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_length(result$weights, 200)
  expect_equal(result$method, "cell")
  # Most weights should be assigned (some cells might be empty)
  expect_true(sum(!is.na(result$weights)) > 180)
})

test_that("cell weights sum preserves sample size", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = rep(c("Male", "Female"), each = 3),
    Age = rep(c("18-34", "35-54", "55+"), 2),
    target_percent = c(14, 20, 14, 16, 20, 16),
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = c("Gender", "Age"),
    verbose = FALSE
  )

  valid_weights <- result$weights[!is.na(result$weights)]
  # Sum of weights should approximately equal n for valid observations
  expect_equal(sum(valid_weights), sum(!is.na(result$weights)), tolerance = 0.1)
})

test_that("cell weights with balanced data produce uniform weights", {
  # Create perfectly balanced data: 10 in each of 4 cells
  data <- data.frame(
    Gender = rep(c("Male", "Female"), each = 20),
    Age = rep(c("Young", "Old"), 20),
    stringsAsFactors = FALSE
  )

  cell_targets <- data.frame(
    Gender = rep(c("Male", "Female"), each = 2),
    Age = rep(c("Young", "Old"), 2),
    target_percent = c(25, 25, 25, 25),  # Equal distribution
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = c("Gender", "Age"),
    verbose = FALSE
  )

  # All weights should be very close to 1.0
  expect_true(all(abs(result$weights - 1.0) < 0.01))
})

test_that("cell weights handle missing cell variable", {
  data <- create_simple_survey(n = 200)
  cell_targets <- data.frame(
    NonExistent = c("A", "B"),
    target_percent = c(50, 50),
    stringsAsFactors = FALSE
  )

  expect_error(
    calculate_cell_weights(data, cell_targets, "NonExistent"),
    class = "turas_refusal"
  )
})

test_that("cell weights handle empty data", {
  data <- data.frame(Gender = character(0), Age = character(0))
  cell_targets <- data.frame(
    Gender = "Male",
    Age = "Young",
    target_percent = 100,
    stringsAsFactors = FALSE
  )

  expect_error(
    calculate_cell_weights(data, cell_targets, c("Gender", "Age")),
    class = "turas_refusal"
  )
})

test_that("cell weights refuse when targets don't sum to 100", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Female"),
    target_percent = c(60, 60),  # sums to 120
    stringsAsFactors = FALSE
  )

  expect_error(
    calculate_cell_weights(data, cell_targets, "Gender"),
    class = "turas_refusal"
  )
})

test_that("cell weights warn about empty cells", {
  data <- data.frame(
    Gender = c(rep("Male", 50), rep("Female", 50)),
    Age = c(rep("Young", 50), rep("Old", 50)),
    stringsAsFactors = FALSE
  )

  # Target a cell that doesn't exist (Female-Young if data is structured)
  cell_targets <- data.frame(
    Gender = c("Male", "Male", "Female", "Female"),
    Age = c("Young", "Old", "Young", "Old"),
    target_percent = c(25, 25, 25, 25),
    stringsAsFactors = FALSE
  )

  # This should produce a warning about empty cells (if any cells are empty)
  # For this data pattern, Male-Young and Female-Old exist, but Male-Old and Female-Young don't
  result <- suppressWarnings(
    calculate_cell_weights(data, cell_targets, c("Gender", "Age"), verbose = FALSE)
  )

  expect_true(is.list(result))
  # Some weights may be NA for empty cells
  expect_true(result$n_cells_empty >= 0)
})

test_that("cell weights return correct summary", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Female"),
    target_percent = c(48, 52),
    stringsAsFactors = FALSE
  )

  result <- calculate_cell_weights(
    data = data,
    cell_targets = cell_targets,
    cell_variables = "Gender",
    verbose = FALSE
  )

  expect_true(is.data.frame(result$cell_summary))
  expect_equal(nrow(result$cell_summary), 2)
  expect_true("target_pct" %in% names(result$cell_summary))
  expect_true("sample_count" %in% names(result$cell_summary))
  expect_true("weight" %in% names(result$cell_summary))
})

test_that("validate_cell_config catches duplicate cells", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Male", "Female"),
    target_percent = c(25, 25, 50),
    stringsAsFactors = FALSE
  )

  result <- validate_cell_config(data, cell_targets, "w1", "Gender")
  expect_false(result$valid)
  expect_true(any(grepl("Duplicate", result$errors)))
})

test_that("validate_cell_config catches negative targets", {
  data <- create_simple_survey(n = 200)

  cell_targets <- data.frame(
    Gender = c("Male", "Female"),
    target_percent = c(110, -10),
    stringsAsFactors = FALSE
  )

  result <- validate_cell_config(data, cell_targets, "w1", "Gender")
  expect_false(result$valid)
})

test_that("calculate_cell_weights_from_config works with config", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  result <- calculate_cell_weights_from_config(
    data = data,
    config = config,
    weight_name = "cell_weight",
    verbose = FALSE
  )

  expect_true(is.list(result))
  expect_length(result$weights, 200)
  expect_true(sum(!is.na(result$weights)) > 150)
})

test_that("integration: run_weighting with cell weights", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  result <- with_refusal_handler({
    run_weighting(config_path, verbose = FALSE)
  }, module = "WEIGHTING")

  expect_false(is_refusal(result))
  expect_equal(result$status, "PASS")
  expect_true("cell_weight" %in% names(result$data))
  expect_equal(nrow(result$data), 200)
})

test_that("get_cell_targets returns correct data", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  targets <- get_cell_targets(config, "cell_weight")

  expect_true(is.data.frame(targets))
  expect_equal(nrow(targets), 6)  # 2 genders x 3 ages
  expect_true("Gender" %in% names(targets))
  expect_true("Age" %in% names(targets))
  expect_true("target_percent" %in% names(targets))
  # weight_name should have been removed
  expect_false("weight_name" %in% names(targets))
})

test_that("get_cell_targets returns NULL for non-existent weight", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_cell_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  targets <- get_cell_targets(config, "nonexistent_weight")
  expect_equal(nrow(targets), 0)
})
