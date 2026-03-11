# ==============================================================================
# MAXDIFF TESTS - PREFERENCE SHARES & HEAD-TO-HEAD
# ==============================================================================

test_that("compute_preference_shares from individual utils sums to 100", {
  td <- generate_test_data()
  shares <- compute_preference_shares(individual_utils = td$individual_utils)

  expect_equal(length(shares), td$n_items)
  expect_equal(round(sum(shares), 0), 100)
  expect_true(all(shares > 0))
  expect_true(all(shares < 100))
})

test_that("compute_preference_shares from aggregate utils sums to 100", {
  agg <- c(A = 2.0, B = 1.0, C = -0.5, D = 0.0)
  shares <- compute_preference_shares(aggregate_utils = agg)

  expect_equal(length(shares), 4)
  expect_equal(round(sum(shares), 0), 100)
  # Higher utility should get higher share
  expect_true(shares["A"] > shares["B"])
  expect_true(shares["B"] > shares["C"])
})

test_that("compute_preference_shares returns empty for null input", {
  shares <- compute_preference_shares()
  expect_equal(length(shares), 0)
})

test_that("compute_preference_shares handles equal utilities", {
  agg <- c(A = 1.0, B = 1.0, C = 1.0)
  shares <- compute_preference_shares(aggregate_utils = agg)

  expect_equal(round(sum(shares), 0), 100)
  # All equal should give ~33.3% each
  expect_true(all(abs(shares - 100/3) < 0.1))
})

test_that("compute_head_to_head returns valid probabilities", {
  td <- generate_test_data()

  result <- compute_head_to_head(td$individual_utils, "I1", "I2")

  expect_true(result$prob_a >= 0 && result$prob_a <= 100)
  expect_true(result$prob_b >= 0 && result$prob_b <= 100)
  expect_equal(round(result$prob_a + result$prob_b, 0), 100)
})

test_that("compute_head_to_head returns 50/50 for identical items", {
  mat <- matrix(rep(c(1.0, 2.0), each = 10), nrow = 10, ncol = 2)
  colnames(mat) <- c("A", "B")

  result <- compute_head_to_head(mat, "A", "A")
  # Same item vs itself should be 50/50
  expect_equal(result$prob_a, 50)
})

test_that("compute_head_to_head returns 50/50 for null input", {
  result <- compute_head_to_head(NULL, "A", "B")
  expect_equal(result$prob_a, 50)
  expect_equal(result$prob_b, 50)
})

test_that("compute_head_to_head handles missing item IDs", {
  td <- generate_test_data()
  result <- compute_head_to_head(td$individual_utils, "MISSING", "I1")
  expect_equal(result$prob_a, 50)
})
