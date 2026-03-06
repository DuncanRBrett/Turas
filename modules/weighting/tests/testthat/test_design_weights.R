# ==============================================================================
# TESTS: Design Weight Calculation (design_weights.R)
# ==============================================================================

test_that("calculate_design_weights produces correct weights", {
  skip_if_not_installed("survey")

  # Create known data: 3 strata with known sizes
  set.seed(42)
  data <- data.frame(
    id = 1:100,
    Stratum = c(rep("A", 50), rep("B", 30), rep("C", 20)),
    stringsAsFactors = FALSE
  )

  pop_sizes <- c("A" = 5000, "B" = 3000, "C" = 2000)

  weights <- calculate_design_weights(
    data = data,
    stratum_variable = "Stratum",
    population_sizes = pop_sizes,
    verbose = FALSE
  )

  expect_length(weights, 100)
  expect_true(all(!is.na(weights)))
  expect_true(all(weights > 0))

  # Weight = pop/sample for each stratum
  # A: 5000/50 = 100, B: 3000/30 = 100, C: 2000/20 = 100
  # In this case all weights should be equal (proportional sample)
  expect_equal(weights[1], weights[51])
  expect_equal(weights[1], weights[81])
})

test_that("calculate_design_weights handles unequal strata correctly", {
  data <- data.frame(
    id = 1:100,
    Stratum = c(rep("A", 70), rep("B", 30)),
    stringsAsFactors = FALSE
  )

  # Population is 50/50 but sample is 70/30
  pop_sizes <- c("A" = 5000, "B" = 5000)

  weights <- calculate_design_weights(
    data = data,
    stratum_variable = "Stratum",
    population_sizes = pop_sizes,
    verbose = FALSE
  )

  # A: 5000/70 ≈ 71.4, B: 5000/30 ≈ 166.7
  expect_true(weights[1] < weights[71])  # A's weight < B's weight
})

test_that("normalize_design_weights normalizes to mean 1", {
  weights <- c(100, 200, 150, 100, 200)
  normalized <- normalize_design_weights(weights)
  expect_equal(mean(normalized), 1.0, tolerance = 1e-10)
  expect_length(normalized, 5)
})

test_that("normalize_design_weights preserves relative ratios", {
  weights <- c(100, 200)
  normalized <- normalize_design_weights(weights)
  expect_equal(normalized[2] / normalized[1], 2.0, tolerance = 1e-10)
})

test_that("calculate_design_weights_from_config works end-to-end", {
  skip_if_not_installed("openxlsx")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_design_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  result <- calculate_design_weights_from_config(
    data = data,
    config = config,
    weight_name = "design_weight",
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 200)
  expect_true(all(!is.na(result$weights)))
  expect_true(!is.null(result$stratum_summary))
})

test_that("design weights handle factor variables", {
  data <- data.frame(
    id = 1:50,
    Group = factor(c(rep("X", 25), rep("Y", 25))),
    stringsAsFactors = FALSE
  )

  pop_sizes <- c("X" = 5000, "Y" = 3000)

  weights <- calculate_design_weights(
    data = data,
    stratum_variable = "Group",
    population_sizes = pop_sizes,
    verbose = FALSE
  )

  expect_length(weights, 50)
  expect_true(all(weights > 0))
})

test_that("calculate_grossing_weights scales to population total", {
  skip_if(!exists("calculate_grossing_weights", mode = "function"),
          "calculate_grossing_weights not available")

  weights <- c(1.0, 1.5, 0.8, 1.2, 1.0)
  grossing <- calculate_grossing_weights(weights, population_total = 10000)

  expect_equal(sum(grossing), 10000, tolerance = 1e-6)
  expect_true(all(grossing > 0))
})
