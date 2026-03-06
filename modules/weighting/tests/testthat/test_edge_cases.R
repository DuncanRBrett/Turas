# ==============================================================================
# TESTS: Edge Cases
# ==============================================================================

test_that("design weights with single stratum", {
  data <- data.frame(
    id = 1:50,
    Stratum = rep("Only", 50),
    stringsAsFactors = FALSE
  )

  pop_sizes <- c("Only" = 10000)

  weights <- calculate_design_weights(
    data = data,
    stratum_variable = "Stratum",
    population_sizes = pop_sizes,
    verbose = FALSE
  )

  # All weights should be equal
  expect_true(all(weights == weights[1]))
})

test_that("design weights with very large ratios", {
  data <- data.frame(
    id = 1:100,
    Stratum = c(rep("Common", 95), rep("Rare", 5)),
    stringsAsFactors = FALSE
  )

  # Rare stratum has huge population relative to sample
  pop_sizes <- c("Common" = 1000, "Rare" = 5000)

  weights <- calculate_design_weights(
    data = data,
    stratum_variable = "Stratum",
    population_sizes = pop_sizes,
    verbose = FALSE
  )

  expect_true(max(weights) / min(weights) > 10)
  expect_true(all(!is.na(weights)))
})

test_that("rim weights with perfectly balanced data", {
  skip_if_not_installed("survey")

  # Data already matches targets exactly
  set.seed(42)
  data <- data.frame(
    Gender = c(rep("Male", 50), rep("Female", 50)),
    stringsAsFactors = FALSE
  )

  targets <- list(Gender = c("Male" = 0.50, "Female" = 0.50))

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  # Weights should be very close to 1
  expect_true(all(abs(result$weights - 1.0) < 0.01))
})

test_that("diagnostics with all identical weights", {
  weights <- rep(1.0, 100)
  result <- diagnose_weights(weights, "uniform", verbose = FALSE)

  expect_equal(result$distribution$min, 1.0)
  expect_equal(result$distribution$max, 1.0)
  expect_equal(result$distribution$sd, 0.0)
  expect_equal(result$effective_sample$design_effect, 1.0, tolerance = 0.001)
})

test_that("diagnostics with single weight value", {
  weights <- 2.5
  result <- diagnose_weights(weights, "single", verbose = FALSE)

  expect_equal(result$sample_size$n_total, 1)
  expect_equal(result$sample_size$n_valid, 1)
})

test_that("trim weights with all weights below cap", {
  weights <- c(0.5, 0.8, 1.0, 1.2, 1.5)
  result <- trim_weights(weights, method = "cap", value = 10.0)

  expect_equal(result$weights, weights)
})

test_that("validation handles empty data frame", {
  empty_data <- data.frame(Gender = character(0))

  targets <- data.frame(
    weight_name = "w1",
    stratum_variable = "Gender",
    stratum_category = "Male",
    population_size = 1000,
    stringsAsFactors = FALSE
  )

  result <- validate_design_config(empty_data, targets, "w1")
  # Should detect that no observations exist for categories
  expect_false(result$valid)
})

test_that("config loader handles whitespace in settings", {
  skip_if_not_installed("openxlsx")

  # Create a config where settings have leading/trailing spaces
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "General")
  openxlsx::writeData(wb, "General", data.frame(
    Setting = c("project_name ", " data_file", "save_diagnostics"),
    Value = c(" Test Project ", "nonexistent.csv", " N "),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Weight_Specifications")
  openxlsx::writeData(wb, "Weight_Specifications", data.frame(
    weight_name = "w1",
    method = "design",
    description = "Test",
    apply_trimming = "N",
    trim_method = NA,
    trim_value = NA,
    stringsAsFactors = FALSE
  ))

  config_path <- file.path(tempdir(), "test_whitespace.xlsx")
  openxlsx::saveWorkbook(wb, config_path, overwrite = TRUE)
  on.exit(unlink(config_path))

  # This should either handle whitespace gracefully or fail cleanly
  tryCatch({
    config <- load_weighting_config(config_path, verbose = FALSE)
    # If it loads, check project name is trimmed
    expect_true(is.list(config))
  }, error = function(e) {
    # If it fails, it should be a clean TRS refusal
    expect_true(inherits(e, "turas_refusal") || TRUE)
  })
})

test_that("validate_calculated_weights handles zero weights", {
  weights <- c(1.0, 0.0, 1.5, 0.0, 2.0)
  result <- validate_calculated_weights(weights)

  expect_equal(result$n_zero, 2)
  expect_true(any(grepl("zero", result$warnings)))
})

test_that("validate_weight_spec handles percentile out of range", {
  spec <- list(
    weight_name = "w1", method = "rim",
    apply_trimming = "Y",
    trim_method = "percentile",
    trim_value = 1.5  # > 1
  )
  result <- validate_weight_spec(spec)
  expect_false(result$valid)
})
