# ==============================================================================
# TESTS: Weight Trimming (trimming.R)
# ==============================================================================

test_that("trim_weights caps at specified value", {
  weights <- c(0.5, 1.0, 2.0, 5.0, 10.0)
  result <- trim_weights(weights, method = "cap", value = 5.0)

  expect_true(all(result$weights <= 5.0))
  expect_equal(result$weights[1:3], c(0.5, 1.0, 2.0))
  expect_equal(result$weights[5], 5.0)
  expect_true(result$n_trimmed > 0 || result$trimming_applied)
})

test_that("trim_weights handles percentile trimming", {
  set.seed(42)
  weights <- c(rep(1, 90), rep(5, 5), rep(10, 5))
  result <- trim_weights(weights, method = "percentile", value = 0.95)

  # 95th percentile should cap the top 5%
  expect_true(max(result$weights) <= quantile(weights, 0.95) + 0.01)
})

test_that("trim_weights rejects invalid type", {
  weights <- c(1.0, 2.0, 3.0)
  expect_error(
    trim_weights(weights, type = "invalid_type", value = 5.0)
  )
})

test_that("trim_weights with zero cap is an error", {
  weights <- c(1.0, 2.0, 3.0)
  expect_error(
    trim_weights(weights, method = "cap", value = 0)
  )
})

test_that("trim_weights with no weights exceeding cap changes nothing", {
  weights <- c(0.5, 1.0, 1.5)
  result <- trim_weights(weights, method = "cap", value = 5.0)

  expect_equal(result$weights, weights)
})

test_that("apply_trimming_from_config applies trimming when enabled", {
  weights <- c(0.5, 1.0, 2.0, 5.0, 10.0)
  spec <- list(
    apply_trimming = "Y",
    trim_method = "cap",
    trim_value = 5.0
  )

  result <- apply_trimming_from_config(weights, spec, verbose = FALSE)
  expect_true(result$trimming_applied)
  expect_true(all(result$weights <= 5.0))
})

test_that("apply_trimming_from_config skips when disabled", {
  weights <- c(0.5, 1.0, 2.0, 5.0, 10.0)
  spec <- list(apply_trimming = "N")

  result <- apply_trimming_from_config(weights, spec, verbose = FALSE)
  expect_false(result$trimming_applied)
  expect_equal(result$weights, weights)
})

test_that("apply_trimming_from_config handles NA trimming flag", {
  weights <- c(0.5, 1.0, 2.0)
  spec <- list(apply_trimming = NA)

  result <- apply_trimming_from_config(weights, spec, verbose = FALSE)
  expect_false(result$trimming_applied)
})

test_that("trim_weights_two_sided trims both ends", {
  skip_if(!exists("trim_weights_two_sided", mode = "function"),
          "trim_weights_two_sided not available")

  weights <- c(0.1, 0.5, 1.0, 2.0, 8.0)
  result <- trim_weights_two_sided(weights, lower_pct = 0.10, upper_pct = 0.90)

  lower_bound <- quantile(weights, 0.10)
  upper_bound <- quantile(weights, 0.90)
  expect_true(all(result$weights >= lower_bound - 0.01))
  expect_true(all(result$weights <= upper_bound + 0.01))
})

test_that("rescale_after_trimming preserves sum", {
  skip_if(!exists("rescale_after_trimming", mode = "function"),
          "rescale_after_trimming not available")

  original_weights <- c(0.5, 1.0, 2.0, 5.0, 10.0)
  trimmed_weights <- pmin(original_weights, 5.0)
  original_sum <- sum(original_weights)

  rescaled <- rescale_after_trimming(original_weights, trimmed_weights)

  expect_equal(sum(rescaled), original_sum, tolerance = 1e-6)
})

test_that("winsorize_weights works correctly", {
  skip_if(!exists("winsorize_weights", mode = "function"),
          "winsorize_weights not available")

  set.seed(42)
  weights <- c(0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0)
  result <- winsorize_weights(weights, trim_pct = 0.10)

  expect_length(result$weights, 7)
  expect_true(min(result$weights) >= quantile(weights, 0.10) - 0.01)
})
