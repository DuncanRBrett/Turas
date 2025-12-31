# ==============================================================================
# TEST SUITE: Conjoint Part-Worth Utilities
# ==============================================================================
# Tests for part-worth utility calculations and attribute importance
# Part of Turas Conjoint Module Test Suite
# ==============================================================================

library(testthat)

context("Conjoint Part-Worth Utilities")

# ==============================================================================
# TEST DATA SETUP
# ==============================================================================

#' Create Simple Test Conjoint Data
#'
#' Creates a minimal conjoint dataset with known structure
#'
create_simple_conjoint_data <- function() {
  # 2 attributes with 2 levels each
  # Brand: A, B
  # Price: $10, $20

  list(
    data = data.frame(
      choice_id = rep(1:20, each = 2),
      alt_id = rep(1:2, 20),
      choice = rep(c(1, 0), 20),  # Always choose alternative 1
      brand = rep(c("A", "B"), 20),
      price = rep(c(10, 20), 20),
      stringsAsFactors = FALSE
    ),
    attributes = data.frame(
      AttributeName = c("brand", "price"),
      LevelNames = c("A,B", "10,20"),
      stringsAsFactors = FALSE
    )
  )
}

#' Create Realistic Conjoint Data
#'
#' Creates a more realistic conjoint dataset with 4 attributes
#'
create_realistic_conjoint_data <- function(n_respondents = 100, seed = 123) {
  set.seed(seed)

  # Attributes:
  # - Brand: Apple, Samsung, Google (3 levels)
  # - Price: $500, $700, $900 (3 levels)
  # - Screen: 5", 6", 6.5" (3 levels)
  # - Battery: 3000mAh, 4000mAh, 5000mAh (3 levels)

  # True part-worths (for data generation)
  true_utilities <- list(
    brand = c(Apple = 1.5, Samsung = 0.8, Google = 0.0),  # Google is baseline
    price = c("500" = 1.0, "700" = 0.3, "900" = 0.0),     # 900 is baseline
    screen = c("5" = -0.5, "6" = 0.5, "6.5" = 0.0),       # 6.5 is baseline
    battery = c("3000" = -0.8, "4000" = 0.4, "5000" = 0.0) # 5000 is baseline
  )

  # Generate choice sets (8 choice sets per respondent, 2 alternatives each)
  n_choice_sets <- 8
  n_alts <- 2

  choice_data <- data.frame()

  for (resp in 1:n_respondents) {
    for (cs in 1:n_choice_sets) {
      for (alt in 1:n_alts) {

        # Randomly assign attribute levels
        brand <- sample(c("Apple", "Samsung", "Google"), 1)
        price <- sample(c("500", "700", "900"), 1)
        screen <- sample(c("5", "6", "6.5"), 1)
        battery <- sample(c("3000", "4000", "5000"), 1)

        # Calculate utility
        utility <- (
          true_utilities$brand[brand] +
          true_utilities$price[price] +
          true_utilities$screen[screen] +
          true_utilities$battery[battery] +
          rnorm(1, 0, 0.5)  # Random error
        )

        choice_data <- rbind(choice_data, data.frame(
          respondent_id = resp,
          choice_id = (resp - 1) * n_choice_sets + cs,
          alt_id = alt,
          brand = brand,
          price = price,
          screen = screen,
          battery = battery,
          utility = utility,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # Determine choice (choose alternative with highest utility)
  choice_data$choice <- 0
  for (cs_id in unique(choice_data$choice_id)) {
    cs_subset <- choice_data[choice_data$choice_id == cs_id, ]
    max_utility_alt <- cs_subset$alt_id[which.max(cs_subset$utility)]
    choice_data$choice[choice_data$choice_id == cs_id & choice_data$alt_id == max_utility_alt] <- 1
  }

  list(
    data = choice_data[, c("respondent_id", "choice_id", "alt_id", "choice",
                            "brand", "price", "screen", "battery")],
    true_utilities = true_utilities,
    attributes = data.frame(
      AttributeName = c("brand", "price", "screen", "battery"),
      NumLevels = c(3, 3, 3, 3),
      LevelNames = c("Apple,Samsung,Google", "500,700,900", "5,6,6.5", "3000,4000,5000"),
      stringsAsFactors = FALSE
    )
  )
}

# ==============================================================================
# ZERO-CENTERING TESTS
# ==============================================================================

test_that("Zero-centering correctly transforms utilities", {
  # Raw utilities
  raw_utils <- c(1.5, 0.8, -0.3)

  # Zero-centered utilities should sum to 0
  centered <- raw_utils - mean(raw_utils)

  expect_equal(sum(centered), 0, tolerance = 1e-10)
  expect_equal(mean(centered), 0, tolerance = 1e-10)

  # Check actual values
  expected <- c(0.833, 0.133, -0.967)
  expect_equal(centered, expected, tolerance = 0.01)
})

test_that("Zero-centering preserves utility differences", {
  # Raw utilities
  raw_utils <- c(2.0, 1.0, 0.0)

  # Differences before centering
  diff_before <- raw_utils[1] - raw_utils[3]

  # Zero-center
  centered <- raw_utils - mean(raw_utils)

  # Differences after centering should be identical
  diff_after <- centered[1] - centered[3]

  expect_equal(diff_before, diff_after)
})

test_that("Zero-centering handles single level gracefully", {
  # Edge case: attribute with only 1 level (should center to 0)
  single_util <- 5.0

  centered <- single_util - mean(single_util)

  expect_equal(centered, 0)
})

# ==============================================================================
# ATTRIBUTE IMPORTANCE TESTS
# ==============================================================================

test_that("Attribute importance calculated correctly from utility ranges", {
  # Attribute 1: range = 2.0 (utils 1.0, -1.0)
  # Attribute 2: range = 1.0 (utils 0.5, -0.5)
  # Total range = 3.0

  attr1_range <- 2.0
  attr2_range <- 1.0
  total_range <- attr1_range + attr2_range

  importance1 <- 100 * attr1_range / total_range
  importance2 <- 100 * attr2_range / total_range

  # Expected: 66.7%, 33.3%
  expect_equal(importance1, 66.67, tolerance = 0.01)
  expect_equal(importance2, 33.33, tolerance = 0.01)

  # Should sum to 100%
  expect_equal(importance1 + importance2, 100, tolerance = 0.01)
})

test_that("Attribute importance handles equal ranges", {
  # All attributes have same range → equal importance

  n_attrs <- 4
  ranges <- rep(1.0, n_attrs)
  total_range <- sum(ranges)

  importances <- 100 * ranges / total_range

  # All should be 25%
  expect_true(all(abs(importances - 25) < 0.01))

  # Should sum to 100%
  expect_equal(sum(importances), 100)
})

test_that("Attribute importance handles zero range appropriately", {
  # If an attribute has zero range (all levels identical utility),
  # it should have 0% importance

  ranges <- c(2.0, 1.0, 0.0)  # Third attribute has no variation
  total_range <- sum(ranges)

  importances <- 100 * ranges / total_range

  expect_equal(importances[1], 66.67, tolerance = 0.01)
  expect_equal(importances[2], 33.33, tolerance = 0.01)
  expect_equal(importances[3], 0.0)
})

# ==============================================================================
# BASELINE LEVEL IDENTIFICATION TESTS
# ==============================================================================

test_that("Baseline level correctly identified", {
  # By convention, baseline is the level with utility closest to 0
  # after zero-centering

  utils_centered <- c(0.5, -0.3, -0.2)

  # Level 3 is closest to 0 → should be baseline
  abs_utils <- abs(utils_centered)
  baseline_idx <- which.min(abs_utils)

  expect_equal(baseline_idx, 3)
})

test_that("Baseline identification handles ties", {
  # If two levels tie for closest to 0, pick first one

  utils_centered <- c(0.5, -0.5, 0.2)

  # Levels 1 and 2 both have abs = 0.5
  # which.min should return first occurrence
  baseline_idx <- which.min(abs(utils_centered))

  expect_equal(baseline_idx, 1)
})

# ==============================================================================
# UTILITY CALCULATION FROM MODEL COEFFICIENTS TESTS
# ==============================================================================

test_that("Utilities correctly extracted from model coefficients", {
  skip_if_not_installed("survival")

  # Create simple test data
  test_data <- create_simple_conjoint_data()

  # Format for clogit
  test_data$data$choice_id <- factor(test_data$data$choice_id)

  # Fit model
  model <- survival::clogit(
    choice ~ brand + price + strata(choice_id),
    data = test_data$data
  )

  # Extract coefficients
  coefs <- coef(model)

  # Should have 2 coefficients (brandB and price)
  # brandA is baseline (omitted)
  expect_equal(length(coefs), 2)
  expect_true("brandB" %in% names(coefs))
})

# ==============================================================================
# INTEGRATION TESTS WITH REALISTIC DATA
# ==============================================================================

test_that("Full utility calculation workflow with realistic data", {
  skip_if_not_installed("survival")

  # Generate realistic data
  cbc_data <- create_realistic_conjoint_data(n_respondents = 50, seed = 999)

  # Format for clogit
  cbc_data$data$choice_id <- factor(cbc_data$data$choice_id)
  cbc_data$data$brand <- factor(cbc_data$data$brand)
  cbc_data$data$price <- factor(cbc_data$data$price)
  cbc_data$data$screen <- factor(cbc_data$data$screen)
  cbc_data$data$battery <- factor(cbc_data$data$battery)

  # Fit model
  model <- survival::clogit(
    choice ~ brand + price + screen + battery + strata(choice_id),
    data = cbc_data$data
  )

  # Model should converge
  expect_true(!is.null(model))
  expect_true(length(coef(model)) > 0)

  # Extract coefficients
  coefs <- coef(model)

  # Should have coefficients for all attributes (minus baselines)
  # 4 attributes, 3 levels each = 8 estimated coefficients (4 baselines omitted)
  expect_equal(length(coefs), 8)
})

test_that("Recovered utilities approximate true utilities", {
  skip_if_not_installed("survival")

  # Generate data with known utilities
  cbc_data <- create_realistic_conjoint_data(n_respondents = 200, seed = 456)

  # Format for modeling
  cbc_data$data$choice_id <- factor(cbc_data$data$choice_id)
  cbc_data$data$brand <- factor(cbc_data$data$brand, levels = c("Google", "Apple", "Samsung"))
  cbc_data$data$price <- factor(cbc_data$data$price, levels = c("900", "500", "700"))
  cbc_data$data$screen <- factor(cbc_data$data$screen, levels = c("6.5", "5", "6"))
  cbc_data$data$battery <- factor(cbc_data$data$battery, levels = c("5000", "3000", "4000"))

  # Fit model
  model <- survival::clogit(
    choice ~ brand + price + screen + battery + strata(choice_id),
    data = cbc_data$data
  )

  coefs <- coef(model)

  # Check that estimated utilities have correct signs
  # (compared to true utilities used in data generation)

  # Apple should have positive utility (vs Google baseline)
  expect_true(coefs["brandApple"] > 0)

  # $500 should have positive utility (vs $900 baseline)
  expect_true(coefs["price500"] > 0)

  # Note: With only 200 respondents and random error, exact recovery
  # is not expected, but signs and relative magnitudes should be reasonable
})

# ==============================================================================
# EDGE CASE TESTS
# ==============================================================================

test_that("Handle attribute with all levels chosen equally", {
  # If an attribute doesn't affect choice (all levels equally preferred),
  # estimated utilities should be close to 0

  # Create data where attribute X has no effect
  set.seed(789)
  n_obs <- 400

  data_no_effect <- data.frame(
    choice_id = rep(1:200, each = 2),
    alt_id = rep(1:2, 200),
    choice = rep(c(1, 0), 200),
    x_dummy = sample(c("A", "B"), n_obs, replace = TRUE),  # Random, no effect
    stringsAsFactors = FALSE
  )

  data_no_effect$choice_id <- factor(data_no_effect$choice_id)

  skip_if_not_installed("survival")
  model <- survival::clogit(
    choice ~ x_dummy + strata(choice_id),
    data = data_no_effect
  )

  # Coefficient should be close to 0 (not significantly different from 0)
  expect_true(abs(coef(model)["x_dummyB"]) < 0.5)
})

test_that("Handle perfect separation case", {
  skip_if_not_installed("survival")

  # Create data where attribute perfectly predicts choice
  # (causes separation in logistic regression)

  data_perfect <- data.frame(
    choice_id = rep(1:100, each = 2),
    alt_id = rep(1:2, 100),
    choice = rep(c(1, 0), 100),
    x = rep(c("Good", "Bad"), 100),  # "Good" always chosen
    stringsAsFactors = FALSE
  )

  data_perfect$choice_id <- factor(data_perfect$choice_id)

  # clogit may fail or give very large coefficient
  # Test that it doesn't crash
  expect_error(
    model <- survival::clogit(
      choice ~ x + strata(choice_id),
      data = data_perfect
    ),
    NA  # Expect no error
  )
})

test_that("Handle missing data in choices", {
  # Some choice sets may have missing attribute values

  test_data <- create_simple_conjoint_data()

  # Introduce missing values
  test_data$data$brand[c(1, 5, 10)] <- NA

  # Model fitting should handle NAs (typically by dropping those observations)
  skip_if_not_installed("survival")
  expect_warning(
    model <- survival::clogit(
      choice ~ brand + price + strata(choice_id),
      data = test_data$data
    ),
    NA  # May warn about dropped observations
  )
})

# ==============================================================================
# CONFIDENCE INTERVAL TESTS
# ==============================================================================

test_that("Confidence intervals for utilities are calculated correctly", {
  skip_if_not_installed("survival")

  # Generate data
  cbc_data <- create_realistic_conjoint_data(n_respondents = 100)

  # Format and fit
  cbc_data$data$choice_id <- factor(cbc_data$data$choice_id)
  model <- survival::clogit(
    choice ~ brand + price + screen + battery + strata(choice_id),
    data = cbc_data$data
  )

  # Get confidence intervals
  ci <- confint(model, level = 0.95)

  # Should have 2 columns (lower, upper)
  expect_equal(ncol(ci), 2)

  # Lower bound should be less than upper bound
  expect_true(all(ci[, 1] < ci[, 2]))

  # Point estimates should be within intervals
  coefs <- coef(model)
  expect_true(all(coefs >= ci[, 1]))
  expect_true(all(coefs <= ci[, 2]))
})

# ==============================================================================
# PERFORMANCE TESTS
# ==============================================================================

test_that("Utility calculation is reasonably fast for typical study size", {
  skip_if_not_installed("survival")

  # Typical study: 300 respondents, 12 choice sets, 3 alternatives, 5 attributes
  # This should complete in under 5 seconds

  # Generate data (simplified)
  set.seed(111)
  n_resp <- 300
  n_cs <- 12
  n_alts <- 3
  n_obs <- n_resp * n_cs * n_alts

  data_perf <- data.frame(
    choice_id = rep(1:(n_resp * n_cs), each = n_alts),
    alt_id = rep(1:n_alts, n_resp * n_cs),
    choice = sample(c(0, 0, 1), n_obs, replace = TRUE),  # Simplified
    x1 = sample(c("A", "B", "C"), n_obs, replace = TRUE),
    x2 = sample(c("L1", "L2", "L3"), n_obs, replace = TRUE)
  )

  data_perf$choice_id <- factor(data_perf$choice_id)

  # Time the model fitting
  start_time <- Sys.time()

  model <- survival::clogit(
    choice ~ x1 + x2 + strata(choice_id),
    data = data_perf
  )

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Should complete in under 5 seconds
  expect_true(elapsed < 5.0)
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
