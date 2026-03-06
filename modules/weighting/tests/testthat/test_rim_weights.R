# ==============================================================================
# TESTS: Rim Weight Calculation (rim_weights.R)
# ==============================================================================

test_that("calculate_rim_weights converges with valid targets", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52),
    Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 200)
  expect_true(all(!is.na(result$weights)))
  expect_true(all(result$weights > 0))
})

test_that("rim weights achieve target margins", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 500)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  # Check achieved margin for Gender
  weighted_male <- sum(result$weights[data$Gender == "Male"]) / sum(result$weights)
  expect_equal(weighted_male, 0.48, tolerance = 0.01)
})

test_that("rim weights with base weights (rim-on-design)", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  # Create some base weights
  base_weights <- runif(200, 0.5, 2.0)

  targets <- list(
    Gender = c("Male" = 0.50, "Female" = 0.50)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    base_weights = base_weights,
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 200)
  expect_true(all(result$weights > 0))
})

test_that("rim weights with multiple variables", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 300)

  targets <- list(
    Gender = c("Male" = 0.50, "Female" = 0.50),
    Age = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
    Region = c("North" = 0.25, "South" = 0.25, "East" = 0.25, "West" = 0.25)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 300)
  expect_true(all(result$weights > 0))
})

test_that("rim weights with cap", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    cap_weights = 3.0,
    verbose = FALSE
  )

  expect_true(all(result$weights <= 3.0 + 0.01))  # Small tolerance
})

test_that("calculate_rim_weights_from_config works end-to-end", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("survey")

  data <- create_simple_survey(n = 200)
  data_path <- write_test_survey_csv(data)
  on.exit(unlink(data_path))

  config_path <- create_rim_weight_config(data_path)
  on.exit(unlink(config_path), add = TRUE)

  config <- load_weighting_config(config_path, verbose = FALSE)

  result <- calculate_rim_weights_from_config(
    data = data,
    config = config,
    weight_name = "rim_weight",
    verbose = FALSE
  )

  expect_true(!is.null(result$weights))
  expect_length(result$weights, 200)
  expect_true(!is.null(result$margins))
})

test_that("calculate_achieved_margins returns correct structure", {
  skip_if_not_installed("survey")
  skip_if(!exists("calculate_achieved_margins", mode = "function"),
          "calculate_achieved_margins not available")

  set.seed(42)
  data <- create_simple_survey(n = 200)

  targets <- list(
    Gender = c("Male" = 0.48, "Female" = 0.52)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  if (!is.null(result$margins)) {
    expect_true(is.data.frame(result$margins))
    expect_true("variable" %in% names(result$margins))
    expect_true("category" %in% names(result$margins))
    expect_true("target_pct" %in% names(result$margins) ||
                "target_percent" %in% names(result$margins))
  }
})

test_that("rim weights with single variable produce valid output", {
  skip_if_not_installed("survey")

  set.seed(42)
  data <- data.frame(
    Gender = sample(c("Male", "Female"), 100, replace = TRUE, prob = c(0.6, 0.4)),
    stringsAsFactors = FALSE
  )

  targets <- list(
    Gender = c("Male" = 0.50, "Female" = 0.50)
  )

  result <- calculate_rim_weights(
    data = data,
    target_list = targets,
    verbose = FALSE
  )

  expect_length(result$weights, 100)
  expect_true(all(result$weights > 0))
})
