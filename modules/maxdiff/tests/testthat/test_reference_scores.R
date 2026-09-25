# ==============================================================================
# MAXDIFF - REFERENCE GATE: SCORES DERIVED FROM UTILITIES
# ==============================================================================
# Rescaled scores, preference shares, head-to-head and the discrimination
# classes, each against values worked by hand in the comments.
# e = 2.718282, 1/e = 0.367879, e + 1 + 1/e = 4.086161.
# ==============================================================================

test_that("0_100 rescaling is min-max, PROBABILITY is a softmax that sums to 100", {
  u <- c(1, 0, -1)
  # 0_100: (u - min) / (max - min) * 100 -> 100, 50, 0.
  expect_equal(rescale_utilities(u, "0_100"), c(100, 50, 0))
  # PROBABILITY: exp(u) / sum(exp(u)) * 100 -> 66.524, 24.473, 9.003.
  expect_equal(rescale_utilities(u, "PROBABILITY"), c(66.524, 24.473, 9.003),
               tolerance = 1e-4)
  expect_equal(rescale_utilities(u, "RAW"), u)
  # All utilities equal: nothing to spread, every item sits at 50.
  expect_equal(rescale_utilities(c(0.3, 0.3), "0_100"), c(50, 50))
})

test_that("preference shares are the mean of each respondent's softmax", {
  # R1 utilities (A, B, C) = (1, 0, -1) -> shares 66.524, 24.473, 9.003.
  # R2 utilities (0, 0, 0)              -> shares 33.333 each.
  # Mean: A 49.929, B 28.903, C 21.168. The softmax of the MEAN utilities
  # (0.5, 0, -0.5) would give 50.648, 30.720, 18.632 instead.
  iu <- data.frame(resp_id = c(10001, 10002), A = c(1, 0), B = c(0, 0), C = c(-1, 0))
  s <- compute_preference_shares(individual_utils = iu)
  expect_equal(unname(s[c("A", "B", "C")]), c(49.929, 28.903, 21.168), tolerance = 1e-4)
  expect_equal(sum(s), 100)
  expect_false("resp_id" %in% names(s))

  # Without individual utilities, the softmax of the aggregate utilities.
  s2 <- compute_preference_shares(aggregate_utils = c(A = 1, B = 0, C = -1))
  expect_equal(unname(s2), c(66.524, 24.473, 9.003), tolerance = 1e-4)
})

test_that("head-to-head is the mean of each respondent's two-item logit", {
  # R1: A - B = 1 -> plogis(1) = 0.731059. R2: A - B = 0 -> 0.5.
  # Mean 0.615529 -> 61.6 / 38.4 after rounding to one decimal.
  iu <- data.frame(resp_id = c("R1", "R2"), A = c(1, 0), B = c(0, 0), C = c(-1, 0))
  h <- compute_head_to_head(iu, "A", "B")
  expect_equal(h$prob_a, 61.6)
  expect_equal(h$prob_b, 38.4)
})

test_that("discrimination classes follow median splits on mean and spread", {
  # Four respondents, five items.  mean   sd
  #   W  2  2  2  2          2      0      high mean, low sd, > 0 -> UNIVERSAL_FAVORITE
  #   X  3 -1  3 -1          1      2.309  high mean, high sd      -> POLARIZING
  #   Y  2 -2  2 -2          0      2.309  low mean, high sd       -> POLARIZING
  #   Z -2 -2 -2 -2         -2      0      low mean, low sd        -> LOW_PRIORITY
  #   V  1  0  1  0          0.5    0.577  ON both medians         -> LOW_PRIORITY
  # Median mean 0.5 and median sd 0.577 are V's own values. "High" means
  # strictly above the median, so V is low on both.
  iu <- data.frame(resp_id = paste0("R", 1:4),
                   W = c(2, 2, 2, 2), X = c(3, -1, 3, -1),
                   Y = c(2, -2, 2, -2), Z = c(-2, -2, -2, -2),
                   V = c(1, 0, 1, 0))
  d <- classify_item_discrimination(iu)
  cls <- setNames(d$Classification, d$Item_ID)
  expect_equal(unname(cls[c("W", "X", "Y", "Z", "V")]),
               c("UNIVERSAL_FAVORITE", "POLARIZING", "POLARIZING", "LOW_PRIORITY",
                 "LOW_PRIORITY"))
  expect_equal(d$SD_Utility[d$Item_ID == "X"], 2.3094, tolerance = 1e-4)
})
