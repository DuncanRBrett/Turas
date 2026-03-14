# ==============================================================================
# TABS MODULE - CRITICAL-PATH CALCULATION TESTS
# ==============================================================================
#
# Tests for the 3 highest-risk calculation functions:
#   1. calculate_rating_mean — weighted mean for rating scales
#   2. calculate_cell_count / calculate_weighted_percentage — cell data
#   3. weighted_z_test_proportions — significance testing
#
# These are the functions most likely to produce wrong numbers in output.
# All test values are hand-calculated and documented.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_calculations.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

# Source shared infrastructure
source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))

# Source tabs utilities needed by cell_calculator
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))


# ==============================================================================
# 1. calculate_rating_mean
# ==============================================================================

context("calculate_rating_mean")

test_that("unweighted mean matches hand-calculated value", {
  # 5-point scale: 10 responses of [1,2,3,4,5,5,4,3,2,1]
  # Hand-calculated mean: (1+2+3+4+5+5+4+3+2+1) / 10 = 30/10 = 3.0
  data <- data.frame(
    Q1 = c("1", "2", "3", "4", "5", "5", "4", "3", "2", "1"),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 10)
  options_info <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$value, 3.0)
  expect_equal(result$stat_name, "Mean")
  expect_equal(length(result$values), 10)
})

test_that("weighted mean matches hand-calculated value", {
  # 3 responses: "1" (weight=2), "3" (weight=1), "5" (weight=3)
  # Weighted mean: (1*2 + 3*1 + 5*3) / (2+1+3) = (2+3+15)/6 = 20/6 = 3.333...
  data <- data.frame(
    Q1 = c("1", "3", "5"),
    stringsAsFactors = FALSE
  )
  weights <- c(2, 1, 3)
  options_info <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$value, 20/6, tolerance = 1e-10)
  expect_equal(length(result$values), 3)
  expect_equal(length(result$weights), 3)
})

test_that("OptionValue overrides OptionText for numeric mapping", {
  # Text labels with explicit numeric values
  # "Poor"=1, "Fair"=2, "Good"=3 — 3 responses: Poor, Good, Good
  # Mean: (1 + 3 + 3) / 3 = 7/3 = 2.333...
  data <- data.frame(
    Q1 = c("Poor", "Good", "Good"),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 3)
  options_info <- data.frame(
    OptionText = c("Poor", "Fair", "Good"),
    OptionValue = c(1, 2, 3),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$value, 7/3, tolerance = 1e-10)
})

test_that("ExcludeFromIndex = Y excludes options from mean", {
  # 5-point scale, "DK" excluded. Responses: 1, 3, 5, DK
  # Mean should be (1+3+5)/3 = 3.0, NOT (1+3+5+?)/4
  data <- data.frame(
    Q1 = c("1", "3", "5", "DK"),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 4)
  options_info <- data.frame(
    OptionText = c("1", "2", "3", "4", "5", "DK"),
    ExcludeFromIndex = c(NA, NA, NA, NA, NA, "Y"),
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$value, 3.0)
  expect_equal(length(result$values), 3)  # DK excluded
})

test_that("all same response returns that value as mean", {
  data <- data.frame(Q1 = rep("4", 5), stringsAsFactors = FALSE)
  weights <- rep(1, 5)
  options_info <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$value, 4.0)
})

test_that("single response returns that value", {
  data <- data.frame(Q1 = "3", stringsAsFactors = FALSE)
  weights <- 1
  options_info <- data.frame(
    OptionText = c("1", "2", "3", "4", "5"),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$value, 3.0)
})

test_that("all NA responses return NULL", {
  data <- data.frame(Q1 = c(NA, NA, NA), stringsAsFactors = FALSE)
  weights <- rep(1, 3)
  options_info <- data.frame(
    OptionText = c("1", "2", "3"),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)
  expect_null(result)
})

test_that("missing column returns NULL", {
  data <- data.frame(Q2 = c("1", "2"), stringsAsFactors = FALSE)
  weights <- rep(1, 2)
  options_info <- data.frame(
    OptionText = c("1", "2", "3"),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)
  expect_null(result)
})

test_that("whitespace in responses is handled correctly", {
  # Responses with leading/trailing whitespace should still match
  data <- data.frame(Q1 = c(" 1 ", "2", " 3"), stringsAsFactors = FALSE)
  weights <- rep(1, 3)
  options_info <- data.frame(
    OptionText = c("1", "2", "3"),
    ExcludeFromIndex = NA_character_,
    stringsAsFactors = FALSE
  )

  result <- calculate_rating_mean(data, "Q1", options_info, weights)

  expect_false(is.null(result))
  expect_equal(result$value, 2.0)
})


# ==============================================================================
# 2. calculate_cell_count and calculate_weighted_percentage
# ==============================================================================

context("Cell count and percentage calculations")

test_that("unweighted cell count matches expected", {
  # 10 respondents, 4 chose "Brand A"
  data <- data.frame(
    Q1 = c("Brand A", "Brand B", "Brand A", "Brand C",
           "Brand A", "Brand B", "Brand A", "Brand C",
           "Brand B", "Brand C"),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 10)

  count <- calculate_cell_count(data, "Brand A", "Q1", weights)
  expect_equal(count, 4)

  count_b <- calculate_cell_count(data, "Brand B", "Q1", weights)
  expect_equal(count_b, 3)
})

test_that("weighted cell count is correct", {
  # 3 respondents chose "Yes": weights 1.5, 2.0, 0.5
  # Weighted count = 1.5 + 2.0 + 0.5 = 4.0
  data <- data.frame(
    Q1 = c("Yes", "No", "Yes", "Yes", "No"),
    stringsAsFactors = FALSE
  )
  weights <- c(1.5, 1.0, 2.0, 0.5, 1.0)

  count <- calculate_cell_count(data, "Yes", "Q1", weights)
  expect_equal(count, 4.0)
})

test_that("cell count with NA values excludes NAs", {
  data <- data.frame(
    Q1 = c("Yes", NA, "Yes", "No", NA),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 5)

  count <- calculate_cell_count(data, "Yes", "Q1", weights)
  expect_equal(count, 2)
})

test_that("cell count for nonexistent option returns 0", {
  data <- data.frame(
    Q1 = c("Yes", "No", "Yes"),
    stringsAsFactors = FALSE
  )
  weights <- rep(1, 3)

  count <- calculate_cell_count(data, "Maybe", "Q1", weights)
  expect_equal(count, 0)
})

test_that("empty data returns 0", {
  data <- data.frame(Q1 = character(0), stringsAsFactors = FALSE)
  weights <- numeric(0)

  count <- calculate_cell_count(data, "Yes", "Q1", weights)
  expect_equal(count, 0)
})

test_that("weighted percentage calculation is correct", {
  # 40 out of 100 = 40%
  expect_equal(calculate_weighted_percentage(40, 100), 40)

  # 25 out of 200 = 12.5% — rounds to 12 at default decimal_places=0
  # (weighting.R version has decimal_places param, defaults to 0)
  expect_equal(calculate_weighted_percentage(25, 200), 12)

  # With decimal_places=1 it should be 12.5
  expect_equal(calculate_weighted_percentage(25, 200, decimal_places = 1), 12.5)

  # Zero base returns NA
  expect_true(is.na(calculate_weighted_percentage(10, 0)))

  # NA base returns NA
  expect_true(is.na(calculate_weighted_percentage(10, NA)))
})

test_that("zero count gives 0 percent", {
  expect_equal(calculate_weighted_percentage(0, 100), 0)
})


# ==============================================================================
# 3. weighted_z_test_proportions
# ==============================================================================

context("Significance testing (z-test)")

test_that("clear significant difference is detected", {
  # Group 1: 80/100 = 80%, Group 2: 40/100 = 40%
  # This is a large difference with decent sample sizes — must be significant
  result <- weighted_z_test_proportions(
    count1 = 80, base1 = 100,
    count2 = 40, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expect_true(result$significant)
  expect_true(result$p_value < 0.05)
  expect_true(result$higher)  # Group 1 is higher
})

test_that("equal proportions are not significant", {
  # Both groups: 50/100 = 50%
  result <- weighted_z_test_proportions(
    count1 = 50, base1 = 100,
    count2 = 50, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expect_false(result$significant)
  expect_equal(result$p_value, 1, tolerance = 0.01)
})

test_that("small difference with small sample is not significant", {
  # Group 1: 16/30, Group 2: 14/30 — too close to tell with n=30
  result <- weighted_z_test_proportions(
    count1 = 16, base1 = 30,
    count2 = 14, base2 = 30,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expect_false(result$significant)
})

test_that("below min_base returns non-significant", {
  # Sample size below minimum threshold
  result <- weighted_z_test_proportions(
    count1 = 8, base1 = 10,
    count2 = 2, base2 = 10,
    is_weighted = FALSE,
    min_base = 30,
    alpha = 0.05
  )

  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})

test_that("NA inputs return non-significant", {
  result <- weighted_z_test_proportions(
    count1 = NA, base1 = 100,
    count2 = 50, base2 = 100
  )

  expect_false(result$significant)
  expect_true(is.na(result$p_value))
})

test_that("zero base returns non-significant", {
  result <- weighted_z_test_proportions(
    count1 = 0, base1 = 0,
    count2 = 50, base2 = 100
  )

  expect_false(result$significant)
})

test_that("count exceeding base returns non-significant with warning", {
  expect_warning(
    result <- weighted_z_test_proportions(
      count1 = 110, base1 = 100,
      count2 = 50, base2 = 100
    ),
    "Count exceeds base"
  )

  expect_false(result$significant)
})

test_that("p_value matches hand calculation for known case", {
  # Group 1: 60/100 = 0.60, Group 2: 40/100 = 0.40
  # Pooled p = 100/200 = 0.50
  # SE = sqrt(0.5 * 0.5 * (1/100 + 1/100)) = sqrt(0.005) = 0.07071
  # z = (0.60 - 0.40) / 0.07071 = 2.8284
  # p = 2 * pnorm(-2.8284) = 0.004678
  result <- weighted_z_test_proportions(
    count1 = 60, base1 = 100,
    count2 = 40, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expected_z <- (0.60 - 0.40) / sqrt(0.50 * 0.50 * (1/100 + 1/100))
  expected_p <- 2 * pnorm(-abs(expected_z))

  expect_equal(result$p_value, expected_p, tolerance = 1e-8)
  expect_true(result$significant)
})

test_that("weighted test uses effective-n correctly", {
  # Weighted counts: 60/100 vs 40/100, but effective n = 50 each (heavy weights)
  # With effective n=50, SE is larger, so same proportions may not be significant
  result_unweighted <- weighted_z_test_proportions(
    count1 = 60, base1 = 100,
    count2 = 40, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  result_weighted <- weighted_z_test_proportions(
    count1 = 60, base1 = 100,
    count2 = 40, base2 = 100,
    eff_n1 = 50, eff_n2 = 50,
    is_weighted = TRUE,
    alpha = 0.05
  )

  # Weighted p-value should be larger (less significant) due to smaller effective n
  expect_true(result_weighted$p_value > result_unweighted$p_value)
})

test_that("alpha threshold is respected", {
  # A case that's significant at 0.05 but not at 0.01
  result_05 <- weighted_z_test_proportions(
    count1 = 65, base1 = 100,
    count2 = 50, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  result_01 <- weighted_z_test_proportions(
    count1 = 65, base1 = 100,
    count2 = 50, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.01
  )

  # p-value is the same in both cases
  expect_equal(result_05$p_value, result_01$p_value)

  # But significance may differ
  # p = 2 * pnorm(-abs((0.65-0.50) / sqrt(0.575*0.425*(2/100))))
  # This should be significant at 0.05 but may or may not at 0.01
  expect_true(result_05$significant)
})

test_that("higher flag correctly identifies which group is higher", {
  result <- weighted_z_test_proportions(
    count1 = 30, base1 = 100,
    count2 = 70, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expect_false(result$higher)  # Group 2 is higher, so higher=FALSE

  result2 <- weighted_z_test_proportions(
    count1 = 70, base1 = 100,
    count2 = 30, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expect_true(result2$higher)  # Group 1 is higher
})

test_that("degenerate proportions (all 0% or all 100%) handled", {
  # Both groups 100%
  result <- weighted_z_test_proportions(
    count1 = 100, base1 = 100,
    count2 = 100, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expect_false(result$significant)
  expect_equal(result$p_value, 1)

  # Both groups 0%
  result2 <- weighted_z_test_proportions(
    count1 = 0, base1 = 100,
    count2 = 0, base2 = 100,
    is_weighted = FALSE,
    alpha = 0.05
  )

  expect_false(result2$significant)
  expect_equal(result2$p_value, 1)
})
