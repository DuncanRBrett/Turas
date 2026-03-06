# ==============================================================================
# TESTS: Validation Functions (validation.R)
# ==============================================================================

# --- Design Config Validation ---

test_that("validate_design_config passes with valid config", {
  data <- create_simple_survey(n = 100)
  targets <- data.frame(
    weight_name = rep("w1", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  )
  result <- validate_design_config(data, targets, "w1")
  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_design_config detects missing targets", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = "other_weight",
    stratum_variable = "Age",
    stratum_category = "18-34",
    population_size = 30000,
    stringsAsFactors = FALSE
  )
  result <- validate_design_config(data, targets, "w1")
  expect_false(result$valid)
  expect_true(any(grepl("No design targets found", result$errors)))
})

test_that("validate_design_config detects variable not in data", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = "w1",
    stratum_variable = "NonExistentVar",
    stratum_category = "A",
    population_size = 1000,
    stringsAsFactors = FALSE
  )
  result <- validate_design_config(data, targets, "w1")
  expect_false(result$valid)
})

test_that("validate_design_config detects missing values in stratum", {
  data <- create_simple_survey()
  data$Age[1:5] <- NA
  targets <- data.frame(
    weight_name = rep("w1", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  )
  result <- validate_design_config(data, targets, "w1")
  expect_false(result$valid)
  expect_true(any(grepl("missing values", result$errors)))
})

test_that("validate_design_config detects category mismatch", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = rep("w1", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "65+"),  # 65+ doesn't exist
    population_size = c(30000, 40000, 30000),
    stringsAsFactors = FALSE
  )
  result <- validate_design_config(data, targets, "w1")
  expect_false(result$valid)
})

test_that("validate_design_config detects zero population", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = rep("w1", 3),
    stratum_variable = rep("Age", 3),
    stratum_category = c("18-34", "35-54", "55+"),
    population_size = c(30000, 0, 30000),
    stringsAsFactors = FALSE
  )
  result <- validate_design_config(data, targets, "w1")
  expect_false(result$valid)
})

test_that("validate_design_config detects duplicate categories", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = rep("w1", 4),
    stratum_variable = rep("Age", 4),
    stratum_category = c("18-34", "35-54", "55+", "18-34"),  # duplicate
    population_size = c(30000, 40000, 30000, 10000),
    stringsAsFactors = FALSE
  )
  result <- validate_design_config(data, targets, "w1")
  expect_false(result$valid)
  expect_true(any(grepl("Duplicate", result$errors)))
})

# --- Rim Config Validation ---

test_that("validate_rim_config passes with valid config", {
  data <- create_simple_survey(n = 100)
  targets <- data.frame(
    weight_name = rep("w1", 5),
    variable = c("Gender", "Gender", "Age", "Age", "Age"),
    category = c("Male", "Female", "18-34", "35-54", "55+"),
    target_percent = c(48, 52, 30, 40, 30),
    stringsAsFactors = FALSE
  )
  result <- validate_rim_config(data, targets, "w1")
  expect_true(result$valid)
})

test_that("validate_rim_config detects missing targets", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = "other",
    variable = "Gender",
    category = "Male",
    target_percent = 50,
    stringsAsFactors = FALSE
  )
  result <- validate_rim_config(data, targets, "w1")
  expect_false(result$valid)
})

test_that("validate_rim_config detects variable not in data", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = rep("w1", 2),
    variable = rep("Nonexistent", 2),
    category = c("A", "B"),
    target_percent = c(50, 50),
    stringsAsFactors = FALSE
  )
  result <- validate_rim_config(data, targets, "w1")
  expect_false(result$valid)
})

test_that("validate_rim_config detects targets not summing to 100", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = rep("w1", 2),
    variable = rep("Gender", 2),
    category = c("Male", "Female"),
    target_percent = c(60, 60),  # Sum = 120
    stringsAsFactors = FALSE
  )
  result <- validate_rim_config(data, targets, "w1")
  expect_false(result$valid)
})

test_that("validate_rim_config detects negative targets", {
  data <- create_simple_survey()
  targets <- data.frame(
    weight_name = rep("w1", 2),
    variable = rep("Gender", 2),
    category = c("Male", "Female"),
    target_percent = c(-10, 110),
    stringsAsFactors = FALSE
  )
  result <- validate_rim_config(data, targets, "w1")
  expect_false(result$valid)
})

test_that("validate_rim_config warns on >5 variables", {
  data <- data.frame(
    V1 = sample(c("A","B"), 100, TRUE), V2 = sample(c("A","B"), 100, TRUE),
    V3 = sample(c("A","B"), 100, TRUE), V4 = sample(c("A","B"), 100, TRUE),
    V5 = sample(c("A","B"), 100, TRUE), V6 = sample(c("A","B"), 100, TRUE),
    stringsAsFactors = FALSE
  )
  targets <- data.frame(
    weight_name = rep("w1", 12),
    variable = rep(paste0("V", 1:6), each = 2),
    category = rep(c("A", "B"), 6),
    target_percent = rep(c(50, 50), 6),
    stringsAsFactors = FALSE
  )
  result <- validate_rim_config(data, targets, "w1")
  expect_true(length(result$warnings) > 0)
  expect_true(any(grepl("convergence", result$warnings)))
})

# --- Calculated Weights Validation ---

test_that("validate_calculated_weights passes valid weights", {
  weights <- runif(100, 0.5, 2.0)
  result <- validate_calculated_weights(weights, "test")
  expect_true(result$valid)
})

test_that("validate_calculated_weights detects negative weights", {
  weights <- c(1.0, -0.5, 1.5)
  result <- validate_calculated_weights(weights)
  expect_false(result$valid)
  expect_true(any(grepl("negative", result$errors)))
})

test_that("validate_calculated_weights detects infinite weights", {
  weights <- c(1.0, Inf, 1.5)
  result <- validate_calculated_weights(weights)
  expect_false(result$valid)
})

test_that("validate_calculated_weights detects all-NA weights", {
  weights <- rep(NA_real_, 10)
  result <- validate_calculated_weights(weights)
  expect_false(result$valid)
})

test_that("validate_calculated_weights warns on high max weight", {
  weights <- c(rep(1, 99), 15)  # Max > 10
  result <- validate_calculated_weights(weights)
  expect_true(any(grepl("very high", result$warnings)))
})

# --- Weight Spec Validation ---

test_that("validate_weight_spec passes valid design spec", {
  spec <- list(weight_name = "w1", method = "design", apply_trimming = "N")
  result <- validate_weight_spec(spec)
  expect_true(result$valid)
})

test_that("validate_weight_spec passes valid rim spec", {
  spec <- list(weight_name = "w1", method = "rim", apply_trimming = "N")
  result <- validate_weight_spec(spec)
  expect_true(result$valid)
})

test_that("validate_weight_spec rejects empty weight name", {
  spec <- list(weight_name = "", method = "design")
  result <- validate_weight_spec(spec)
  expect_false(result$valid)
})

test_that("validate_weight_spec rejects invalid method", {
  spec <- list(weight_name = "w1", method = "unknown")
  result <- validate_weight_spec(spec)
  expect_false(result$valid)
})

test_that("validate_weight_spec rejects trimming without method", {
  spec <- list(weight_name = "w1", method = "rim",
               apply_trimming = "Y", trim_method = NA, trim_value = NA)
  result <- validate_weight_spec(spec)
  expect_false(result$valid)
})

test_that("validate_weight_spec accepts cell method", {
  spec <- list(weight_name = "w1", method = "cell", apply_trimming = "N")
  result <- validate_weight_spec(spec)
  expect_true(result$valid)
})
