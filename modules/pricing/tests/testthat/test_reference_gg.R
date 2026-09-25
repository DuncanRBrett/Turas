# ==============================================================================
# TURAS PRICING - GABOR-GRANGER REFERENCE CHECKS (robustness gate 1)
# ==============================================================================
#
# Every headline number Gabor-Granger prints, checked against something that
# does not share Turas code: a hand calculation written out in the comment, or
# base R's stats::isoreg for the monotone smoothing. Never against a value the
# engine produced before.
# ==============================================================================

quiet <- function(expr) { capture.output(r <- expr); r }

ref_gg_cfg <- function(cols, prices, weight_var = NA_character_,
                       behavior = "smooth", smoothing = "isotonic",
                       unit_cost = NA_real_) {
  list(
    analysis_method = "gabor_granger", weight_var = weight_var, dk_codes = numeric(0),
    id_var = "respondent_id", unit_cost = unit_cost, currency_symbol = "R",
    gg_monotonicity_behavior = behavior, gg_stop_early_imputation = "NONE",
    gabor_granger = list(data_format = "wide", price_sequence = prices, response_columns = cols,
                         response_type = "binary", binary_coding = "ZERO_ONE",
                         smoothing_method = smoothing, check_monotonicity = FALSE,
                         calculate_elasticity = TRUE, revenue_optimization = TRUE,
                         confidence_intervals = FALSE),
    validation = list(min_completeness = 0.8, min_sample = 1, price_min = 0, price_max = 10000)
  )
}

# A 50-respondent ladder whose rung counts are 15, 25, 16, 10 "would buy",
# so the raw acceptance is 0.30, 0.50, 0.32, 0.20 at R10, R20, R24, R30.
# Column k is 1 for the first count[k] respondents.
nonmonotone_ladder <- function() {
  counts <- c(15, 25, 16, 10)
  m <- sapply(counts, function(k) c(rep(1, k), rep(0, 50 - k)))
  d <- data.frame(respondent_id = 1:50, m)
  names(d)[2:5] <- c("g10", "g20", "g24", "g30")
  d
}

# Reference monotone (non-increasing) fit: stats::isoreg fits a
# non-decreasing step function, so fit the negated curve and negate back.
ref_decreasing_fit <- function(x, y) -isoreg(x, -y)$yf

test_that("isotonic smoothing equals stats::isoreg on hand-checkable curves", {
  # 0.30, 0.50, 0.35, 0.20. Pool-adjacent-violators pools only the violating
  # pair (0.30, 0.50) to 0.40; 0.40 >= 0.35 >= 0.20 then holds, so the answer
  # is 0.40, 0.40, 0.35, 0.20. Pooling the first three to 0.383 is wrong.
  y <- c(0.30, 0.50, 0.35, 0.20)
  expect_equal(smooth_isotonic(1:4, y), c(0.40, 0.40, 0.35, 0.20), tolerance = 1e-12)
  expect_equal(smooth_isotonic(1:4, y), ref_decreasing_fit(1:4, y), tolerance = 1e-12)

  # A second pool forming after the first: 0.9, 0.95 -> 0.925; 0.7, 0.75 -> 0.725.
  y2 <- c(0.90, 0.95, 0.70, 0.75, 0.50)
  expect_equal(smooth_isotonic(1:5, y2), c(0.925, 0.925, 0.725, 0.725, 0.50), tolerance = 1e-12)

  # A pool that must absorb an earlier block: 0.5, 0.4, 0.6 -> all 0.5.
  expect_equal(smooth_isotonic(1:3, c(0.5, 0.4, 0.6)), rep(0.5, 3), tolerance = 1e-12)

  # Random curves, the reference decides.
  set.seed(101)
  for (i in 1:200) {
    n <- sample(3:12, 1)
    y <- runif(n)
    expect_equal(smooth_isotonic(seq_len(n), y), ref_decreasing_fit(seq_len(n), y),
                 tolerance = 1e-12, info = paste(round(y, 3), collapse = ", "))
  }
})

test_that("the default smoothed ladder, its revenue and its optimum match the hand calculation", {
  # Raw acceptance 0.30, 0.50, 0.32, 0.20 at R10, R20, R24, R30.
  # PAVA: 0.40, 0.40, 0.32, 0.20.
  # Revenue index = price x acceptance: 4.00, 8.00, 7.68, 6.00, so the optimum
  # is R20 at 40% acceptance. (Pooling the first three rungs to 0.3733 would
  # put it at R24 with revenue 8.96.)
  d <- nonmonotone_ladder()
  r <- quiet(run_gabor_granger(d, ref_gg_cfg(c("g10", "g20", "g24", "g30"), c(10, 20, 24, 30))))
  expect_equal(r$demand_curve$purchase_intent_raw, c(0.30, 0.50, 0.32, 0.20))
  expect_equal(r$demand_curve$purchase_intent, c(0.40, 0.40, 0.32, 0.20), tolerance = 1e-12)
  expect_equal(r$revenue_curve$revenue_index, c(4.00, 8.00, 7.68, 6.00), tolerance = 1e-12)
  expect_equal(r$optimal_price$price, 20)
  expect_equal(r$optimal_price$purchase_intent, 0.40, tolerance = 1e-12)
})

# Six respondents, three rungs, weights 1, 1, 2, 2, 0.5, 0.5 (sum 7).
#   id  w    R20 R40 R60
#   1   1     1   1   0
#   2   1     1   0   0
#   3   2     1   1   1
#   4   2     0   0   0
#   5   0.5   1   1   1
#   6   0.5   1   0   0
# Weighted acceptance = sum(w * yes) / sum(w):
#   R20: (1 + 1 + 2 + 0.5 + 0.5) / 7 = 5/7   = 0.714286
#   R40: (1 + 2 + 0.5) / 7           = 3.5/7 = 0.5
#   R60: (2 + 0.5) / 7               = 2.5/7 = 0.357143
# Unweighted: 5/6, 3/6, 2/6.
# Revenue (weighted): 14.2857, 20.0000, 21.4286 -> optimum R60.
# Revenue (unweighted): 16.667, 20.000, 20.000 -> tie at R40 and R60; the first
# (R40) is taken.
# Profit at unit cost R25 (weighted): (20-25)*5/7 = -3.571, 15*0.5 = 7.5,
# 35*2.5/7 = 12.5 -> profit optimum R60.
# Arc elasticity (weighted), R20 -> R40:
#   dQ/avgQ = (0.5 - 5/7) / ((0.5 + 5/7)/2) = -0.352941
#   dP/avgP = 20 / 30 = 0.666667  ->  E = -0.529412
six_ladder <- function() {
  data.frame(respondent_id = 1:6, w = c(1, 1, 2, 2, 0.5, 0.5),
             g20 = c(1, 1, 1, 0, 1, 1), g40 = c(1, 0, 1, 0, 1, 0), g60 = c(0, 0, 1, 0, 1, 0))
}

test_that("weighted and unweighted demand equal the hand calculation", {
  d <- six_ladder()
  cols <- c("g20", "g40", "g60"); prices <- c(20, 40, 60)
  we <- quiet(run_gabor_granger(d, ref_gg_cfg(cols, prices, weight_var = "w", behavior = "diagnostic_only")))
  un <- quiet(run_gabor_granger(d, ref_gg_cfg(cols, prices, behavior = "diagnostic_only")))
  expect_equal(we$demand_curve$purchase_intent, c(5/7, 0.5, 2.5/7), tolerance = 1e-12)
  expect_equal(we$demand_curve$weighted_n, rep(7, 3))
  expect_equal(we$demand_curve$n_respondents, rep(6L, 3))
  expect_equal(un$demand_curve$purchase_intent, c(5/6, 3/6, 2/6), tolerance = 1e-12)
  # Independent: stats::weighted.mean on each column.
  for (k in seq_along(cols)) {
    expect_equal(we$demand_curve$purchase_intent[k], weighted.mean(d[[cols[k]]], d$w), tolerance = 1e-12)
  }
  expect_equal(we$revenue_curve$revenue_index, prices * c(5/7, 0.5, 2.5/7), tolerance = 1e-12)
  expect_equal(we$optimal_price$price, 60)
  expect_equal(un$optimal_price$price, 40)   # first of the tied maxima
})

test_that("profit optimum and arc elasticity equal the hand calculation", {
  d <- six_ladder()
  cols <- c("g20", "g40", "g60"); prices <- c(20, 40, 60)
  r <- quiet(run_gabor_granger(d, ref_gg_cfg(cols, prices, weight_var = "w",
                                             behavior = "diagnostic_only", unit_cost = 25)))
  expect_equal(r$revenue_curve$profit_index, (prices - 25) * c(5/7, 0.5, 2.5/7), tolerance = 1e-12)
  expect_equal(r$optimal_price_profit$price, 60)
  expect_equal(r$optimal_price_profit$profit_index, 12.5, tolerance = 1e-12)
  expect_equal(r$elasticity$arc_elasticity[1], -0.352941176 / (2/3), tolerance = 1e-8)
  # R40 -> R60: dQ/avgQ = (2.5/7 - 0.5) / ((2.5/7 + 0.5)/2) = -0.333333;
  # dP/avgP = 20/50 = 0.4; E = -0.833333.
  expect_equal(r$elasticity$arc_elasticity[2], -0.8333333, tolerance = 1e-6)
  # Unweighted the two optima part: revenue ties R40 and R60 (first taken, R40),
  # profit at R25 is 15 x 3/6 = 7.5 at R40 and 35 x 2/6 = 11.667 at R60.
  un <- quiet(run_gabor_granger(d, ref_gg_cfg(cols, prices, behavior = "diagnostic_only", unit_cost = 25)))
  expect_equal(un$optimal_price$price, 40)
  expect_equal(un$optimal_price_profit$price, 60)
  expect_equal(un$optimal_price_profit$profit_index, 35 * 2 / 6, tolerance = 1e-12)
})
