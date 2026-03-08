# ==============================================================================
# TEST SUITE: Question Processor (question_processor.R)
# ==============================================================================
# Tests for question validation, weight handling, data preparation,
# and base statistics calculations
# ==============================================================================

library(testthat)

# ==============================================================================
# validate_question_in_data()
# ==============================================================================

test_that("validate_question_in_data finds existing column", {
  df <- data.frame(Q1 = 1:5, Q2 = letters[1:5])
  result <- validate_question_in_data("Q1", df)
  expect_true(result$valid)
  expect_equal(result$message, "")
})

test_that("validate_question_in_data rejects missing column", {
  df <- data.frame(Q1 = 1:5, Q2 = letters[1:5])
  result <- validate_question_in_data("Q99", df)
  expect_false(result$valid)
  expect_true(grepl("Not found", result$message))
})

test_that("validate_question_in_data is case-sensitive", {
  df <- data.frame(Q1 = 1:5)
  result <- validate_question_in_data("q1", df)
  expect_false(result$valid)
})

# ==============================================================================
# get_question_weights()
# ==============================================================================

test_that("get_question_weights returns NULL for no weight var", {
  df <- data.frame(Q1 = 1:5, w = rep(1, 5))
  expect_null(get_question_weights(df, NULL))
  expect_null(get_question_weights(df, ""))
})

test_that("get_question_weights extracts weights column", {
  df <- data.frame(Q1 = 1:5, w = c(0.5, 1.0, 1.5, 2.0, 0.8))
  result <- get_question_weights(df, "w")
  expect_equal(result, c(0.5, 1.0, 1.5, 2.0, 0.8))
})

test_that("get_question_weights returns NULL for missing weight column", {
  df <- data.frame(Q1 = 1:5)
  result <- get_question_weights(df, "nonexistent_weight")
  expect_null(result)
})

# ==============================================================================
# prepare_question_data() — unweighted
# ==============================================================================

test_that("prepare_question_data handles clean numeric data", {
  values <- c(1, 2, 3, 4, 5)
  result <- prepare_question_data(values)
  expect_true(result$success)
  expect_equal(result$values, values)
  expect_null(result$weights)
  expect_equal(result$n_raw, 5)
})

test_that("prepare_question_data removes NAs from numeric data", {
  values <- c(1, NA, 3, NA, 5)
  result <- prepare_question_data(values)
  expect_true(result$success)
  expect_equal(result$values, c(1, 3, 5))
  expect_equal(result$n_raw, 3)
})

test_that("prepare_question_data removes Inf from numeric data", {
  values <- c(1, 2, Inf, -Inf, 5)
  result <- prepare_question_data(values)
  expect_true(result$success)
  expect_equal(result$values, c(1, 2, 5))
  expect_equal(result$n_raw, 3)
})

test_that("prepare_question_data handles all-NA data", {
  values <- c(NA, NA, NA)
  result <- prepare_question_data(values)
  expect_false(result$success)
  expect_equal(result$n_raw, 0)
  expect_true(grepl("No valid", result$message))
})

test_that("prepare_question_data handles character data", {
  values <- c("A", "B", NA, "C")
  result <- prepare_question_data(values)
  expect_true(result$success)
  expect_equal(result$values, c("A", "B", "C"))
  expect_equal(result$n_raw, 3)
})

# ==============================================================================
# prepare_question_data() — numeric conversion
# ==============================================================================

test_that("prepare_question_data converts character to numeric when required", {
  values <- c(as.character(1:20))
  result <- prepare_question_data(values, require_numeric = TRUE)
  expect_true(result$success)
  expect_equal(result$values, 1:20)
})

test_that("prepare_question_data rejects mostly non-numeric strings", {
  values <- c("apple", "banana", "cherry", "date", "elderberry",
              "fig", "grape", "1", "2", "3")
  result <- prepare_question_data(values, require_numeric = TRUE)
  # Only 3 convertible — below minimum of 10
  expect_false(result$success)
  expect_true(grepl("Insufficient numeric", result$message))
})

test_that("prepare_question_data rejects low conversion rate", {
  # Enough values (>10) but conversion rate below 80%
  values <- c(as.character(1:10), rep("text", 10))
  result <- prepare_question_data(values, require_numeric = TRUE)
  # 10/20 = 50% conversion rate — below 80% threshold
  expect_false(result$success)
  expect_true(grepl("Non-numeric", result$message))
})

test_that("prepare_question_data rejects too few convertible values", {
  values <- c("A", "B", "C", "1", "2")
  result <- prepare_question_data(values, require_numeric = TRUE)
  # Only 2 valid — below minimum of 10
  expect_false(result$success)
  expect_true(grepl("Insufficient numeric", result$message))
})

# ==============================================================================
# prepare_question_data() — weighted
# ==============================================================================

test_that("prepare_question_data aligns values and weights", {
  values <- c(1, 2, NA, 4, 5)
  weights <- c(1.0, 1.5, 2.0, 0.8, 1.2)
  result <- prepare_question_data(values, weights)
  expect_true(result$success)
  expect_equal(result$values, c(1, 2, 4, 5))
  expect_equal(result$weights, c(1.0, 1.5, 0.8, 1.2))
  expect_equal(result$n_raw, 4)
})

test_that("prepare_question_data excludes zero weights", {
  values <- c(1, 2, 3, 4)
  weights <- c(1.0, 0, 1.5, 0)
  result <- prepare_question_data(values, weights)
  expect_true(result$success)
  expect_equal(result$values, c(1, 3))
  expect_equal(result$weights, c(1.0, 1.5))
  expect_equal(result$n_raw, 2)
})

test_that("prepare_question_data excludes NA weights", {
  values <- c(1, 2, 3, 4)
  weights <- c(1.0, NA, 1.5, 1.0)
  result <- prepare_question_data(values, weights)
  expect_true(result$success)
  expect_equal(result$values, c(1, 3, 4))
  expect_equal(result$weights, c(1.0, 1.5, 1.0))
})

test_that("prepare_question_data fails when all weights zero", {
  values <- c(1, 2, 3)
  weights <- c(0, 0, 0)
  result <- prepare_question_data(values, weights)
  expect_false(result$success)
  expect_true(grepl("No valid cases", result$message))
})

# ==============================================================================
# calculate_proportion_stats()
# ==============================================================================

test_that("calculate_proportion_stats handles unweighted binary", {
  values <- c("Yes", "No", "Yes", "Yes", "No", "No", "Yes", "No", "Yes", "No")
  result <- calculate_proportion_stats(values, "Yes")
  expect_true(result$success)
  expect_equal(result$proportion, 0.5)
  expect_equal(result$n_raw, 10)
  expect_equal(result$n_eff, 10)
})

test_that("calculate_proportion_stats handles multiple categories", {
  values <- c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5)
  result <- calculate_proportion_stats(values, c(1, 2))
  expect_true(result$success)
  expect_equal(result$proportion, 0.4)
})

test_that("calculate_proportion_stats handles all-success", {
  values <- c("Yes", "Yes", "Yes")
  result <- calculate_proportion_stats(values, "Yes")
  expect_true(result$success)
  expect_equal(result$proportion, 1.0)
})

test_that("calculate_proportion_stats handles zero-success", {
  values <- c("No", "No", "No")
  result <- calculate_proportion_stats(values, "Yes")
  expect_true(result$success)
  expect_equal(result$proportion, 0.0)
})

test_that("calculate_proportion_stats handles weighted data", {
  values <- c("Yes", "No", "Yes", "No")
  weights <- c(2.0, 1.0, 2.0, 1.0)
  result <- calculate_proportion_stats(values, "Yes", weights)
  expect_true(result$success)
  # Weighted: 4/6 = 0.667
  expect_equal(result$proportion, 4/6, tolerance = 1e-10)
  expect_equal(result$n_raw, 4)
  # n_eff = round((sum_w)^2 / sum_w^2) = round(36/10) = round(3.6) = 4
  expect_true(result$n_eff > 0)
})

test_that("calculate_proportion_stats reduces n_eff for very unequal weights", {
  values <- c("Yes", "No", "Yes", "No", "Yes")
  weights <- c(10.0, 1.0, 10.0, 1.0, 1.0)
  result <- calculate_proportion_stats(values, "Yes", weights)
  expect_true(result$success)
  # Very unequal weights → much smaller n_eff
  expect_true(result$n_eff < result$n_raw)
})

test_that("calculate_proportion_stats returns failure for zero total weight", {
  values <- c("Yes", "No")
  weights <- c(0, 0)
  # weights sum to 0 — but note prepare_question_data would normally filter these
  # testing the function directly with edge case
  result <- calculate_proportion_stats(values, "Yes", weights)
  expect_false(result$success)
})

# ==============================================================================
# calculate_mean_stats()
# ==============================================================================

test_that("calculate_mean_stats handles unweighted data", {
  values <- c(10, 20, 30, 40, 50)
  result <- calculate_mean_stats(values)
  expect_true(result$success)
  expect_equal(result$mean, 30)
  expect_equal(result$sd, sd(c(10, 20, 30, 40, 50)))
  expect_equal(result$n_raw, 5)
  expect_equal(result$n_eff, 5)
})

test_that("calculate_mean_stats handles weighted data", {
  values <- c(10, 20, 30)
  weights <- c(1, 2, 1)
  result <- calculate_mean_stats(values, weights)
  expect_true(result$success)
  # Weighted mean: (10*1 + 20*2 + 30*1) / 4 = 80/4 = 20
  expect_equal(result$mean, 20)
  expect_equal(result$n_raw, 3)
  expect_true(result$n_eff > 0)
  expect_true(result$sd > 0)
})

test_that("calculate_mean_stats returns zero sd for constant data", {
  values <- c(5, 5, 5, 5, 5)
  result <- calculate_mean_stats(values)
  expect_true(result$success)
  expect_equal(result$mean, 5)
  expect_equal(result$sd, 0)
})

test_that("calculate_mean_stats weighted sd uses Bessel correction", {
  # Equal weights should give same result as unweighted
  values <- c(10, 20, 30, 40, 50)
  weights <- rep(1, 5)
  result_w <- calculate_mean_stats(values, weights)
  result_uw <- calculate_mean_stats(values)

  expect_equal(result_w$mean, result_uw$mean)
  # With equal weights, Bessel-corrected weighted sd should match unweighted sd
  expect_equal(result_w$sd, result_uw$sd, tolerance = 1e-10)
})

test_that("calculate_mean_stats fails for zero total weight", {
  values <- c(10, 20, 30)
  weights <- c(0, 0, 0)
  result <- calculate_mean_stats(values, weights)
  expect_false(result$success)
  expect_true(grepl("zero or negative", result$message))
})

# ==============================================================================
# calculate_nps_stats()
# ==============================================================================

test_that("calculate_nps_stats calculates correct NPS", {
  # Standard NPS scale: 0-10
  # Promoters: 9-10, Detractors: 0-6, Passives: 7-8
  values <- c(10, 9, 8, 7, 5, 3, 10, 9, 8, 6)
  promoter_codes <- c(9, 10)
  detractor_codes <- c(0, 1, 2, 3, 4, 5, 6)

  result <- calculate_nps_stats(values, promoter_codes, detractor_codes)
  expect_true(result$success)

  # Promoters: 10, 9, 10, 9 → 4/10 = 40%
  # Detractors: 5, 3, 6 → 3/10 = 30%
  # NPS = 40 - 30 = +10
  expect_equal(result$pct_promoters, 40)
  expect_equal(result$pct_detractors, 30)
  expect_equal(result$nps_score, 10)
  expect_equal(result$pct_passives, 30)
})

test_that("calculate_nps_stats handles all-promoters", {
  values <- c(9, 10, 9, 10)
  result <- calculate_nps_stats(values, c(9, 10), c(0:6))
  expect_equal(result$nps_score, 100)
  expect_equal(result$pct_promoters, 100)
  expect_equal(result$pct_detractors, 0)
})

test_that("calculate_nps_stats handles all-detractors", {
  values <- c(1, 2, 3, 4)
  result <- calculate_nps_stats(values, c(9, 10), c(0:6))
  expect_equal(result$nps_score, -100)
  expect_equal(result$pct_promoters, 0)
  expect_equal(result$pct_detractors, 100)
})

test_that("calculate_nps_stats handles weighted data", {
  values <- c(10, 5, 7)
  weights <- c(3, 1, 1)
  result <- calculate_nps_stats(values, c(9, 10), c(0:6), weights)
  expect_true(result$success)
  # Promoter weight: 3/5 = 60%, Detractor weight: 1/5 = 20%
  expect_equal(result$pct_promoters, 60)
  expect_equal(result$pct_detractors, 20)
  expect_equal(result$nps_score, 40)
})

# ==============================================================================
# process_question_data() — unified pipeline
# ==============================================================================

test_that("process_question_data handles valid unweighted question", {
  df <- data.frame(Q1 = c("A", "B", "A", "C", NA), stringsAsFactors = FALSE)
  result <- process_question_data("Q1", df, NULL)
  expect_true(result$success)
  expect_equal(result$values, c("A", "B", "A", "C"))
  expect_null(result$weights)
  expect_equal(result$n_raw, 4)
})

test_that("process_question_data handles valid weighted question", {
  df <- data.frame(Q1 = c(1, 2, 3, 4), w = c(1.0, 1.5, 0.8, 1.2))
  result <- process_question_data("Q1", df, "w")
  expect_true(result$success)
  expect_equal(result$values, c(1, 2, 3, 4))
  expect_equal(result$weights, c(1.0, 1.5, 0.8, 1.2))
})

test_that("process_question_data fails for missing question", {
  df <- data.frame(Q1 = 1:5)
  result <- process_question_data("Q99", df, NULL)
  expect_false(result$success)
  expect_true(grepl("Not found", result$warning))
})

test_that("process_question_data fails for all-NA column", {
  df <- data.frame(Q1 = c(NA, NA, NA))
  result <- process_question_data("Q1", df, NULL)
  expect_false(result$success)
  expect_true(grepl("No valid", result$warning))
})

test_that("process_question_data handles missing weight column gracefully", {
  df <- data.frame(Q1 = 1:5)
  result <- process_question_data("Q1", df, "missing_weight")
  expect_true(result$success)  # Falls back to unweighted
  expect_null(result$weights)
})

test_that("process_question_data with require_numeric on character data", {
  df <- data.frame(Q1 = c(as.character(1:15), rep(NA, 5)), stringsAsFactors = FALSE)
  result <- process_question_data("Q1", df, NULL, require_numeric = TRUE)
  expect_true(result$success)
  expect_true(is.numeric(result$values))
  expect_equal(length(result$values), 15)
})

test_that("process_question_data with require_numeric fails on text", {
  df <- data.frame(Q1 = letters[1:10], stringsAsFactors = FALSE)
  result <- process_question_data("Q1", df, NULL, require_numeric = TRUE)
  expect_false(result$success)
})

# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
