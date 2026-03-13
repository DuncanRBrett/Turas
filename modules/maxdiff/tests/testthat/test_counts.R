# ==============================================================================
# MAXDIFF TESTS - COUNT SCORES
# ==============================================================================

test_that("rescale_utilities 0_100 produces correct range", {
  utils <- c(-2, -1, 0, 1, 2)
  rescaled <- rescale_utilities(utils, "0_100")

  expect_equal(min(rescaled), 0)
  expect_equal(max(rescaled), 100)
  expect_equal(length(rescaled), 5)
})

test_that("rescale_utilities PROBABILITY sums to 100", {
  utils <- c(1.5, 0.5, -0.3, -0.7)
  rescaled <- rescale_utilities(utils, "PROBABILITY")

  expect_equal(round(sum(rescaled), 0), 100)
  expect_true(all(rescaled > 0))
})

test_that("rescale_utilities RAW returns unchanged", {
  utils <- c(1.5, -0.5, 0)
  rescaled <- rescale_utilities(utils, "RAW")

  expect_equal(rescaled, utils)
})

test_that("rescale_utilities handles equal values", {
  utils <- c(5, 5, 5)
  rescaled <- rescale_utilities(utils, "0_100")
  expect_true(all(rescaled == 50))
})

test_that("rank_utilities gives rank 1 to highest", {
  utils <- c(3, 1, 2)
  ranks <- rank_utilities(utils)

  expect_equal(ranks[1], 1)  # 3 is highest
  expect_equal(ranks[2], 3)  # 1 is lowest
  expect_equal(ranks[3], 2)  # 2 is middle
})

test_that("rank_utilities handles ties", {
  utils <- c(2, 2, 1)
  ranks <- rank_utilities(utils)

  expect_equal(ranks[1], 1)  # tied for first
  expect_equal(ranks[2], 1)  # tied for first
  expect_equal(ranks[3], 3)  # last
})

test_that("calculate_effective_n returns correct Kish estimate", {
  # Equal weights should give n
  weights <- rep(1, 100)
  expect_equal(calculate_effective_n(weights), 100)

  # Unequal weights should give less than n
  weights2 <- c(rep(2, 50), rep(0.5, 50))
  eff_n <- calculate_effective_n(weights2)
  expect_true(eff_n < 100)
  expect_true(eff_n > 0)
})

test_that("calculate_effective_n handles empty input", {
  expect_equal(calculate_effective_n(NULL), 0)
  expect_equal(calculate_effective_n(numeric(0)), 0)
})
