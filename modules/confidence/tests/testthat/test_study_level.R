# ==============================================================================
# TEST SUITE: Study-Level Calculations
# ==============================================================================
# Unit tests for:
#   - calculate_effective_n() — Kish formula
#   - calculate_deff() — design effect
#   - calculate_study_level_stats() — comprehensive stats
#   - compute_weight_concentration() — weight diagnostics
# ==============================================================================

library(testthat)

context("Study-Level Calculations")

# Re-source 03_study_level.R to ensure confidence module's versions of
# calculate_effective_n and calculate_deff are loaded (other modules like
# maxdiff define functions with the same names but different behaviour)
local({
  root <- tryCatch(get("TURAS_ROOT", envir = .GlobalEnv), error = function(e) NULL)
  if (!is.null(root)) {
    sl <- file.path(root, "modules", "confidence", "R", "03_study_level.R")
    if (file.exists(sl)) source(sl, local = FALSE)
  }
})

# ==============================================================================
# EFFECTIVE SAMPLE SIZE (KISH FORMULA)
# ==============================================================================

test_that("calculate_effective_n: equal weights return actual n", {
  weights <- rep(1, 100)
  result <- calculate_effective_n(weights)
  expect_equal(result, 100L)
})

test_that("calculate_effective_n: Kish formula is correct", {
  # Known example: weights = c(1, 2, 3)
  # n_eff = (1+2+3)^2 / (1^2 + 2^2 + 3^2) = 36 / 14 = 2.571...
  # Scaled: w/mean = c(0.5, 1.0, 1.5), sum=3, sum_sq=3.5
  # n_eff = 9/3.5 = 2.571... -> rounds to 3
  weights <- c(1, 2, 3)
  result <- calculate_effective_n(weights)
  expected <- as.integer(round((sum(weights)^2) / sum(weights^2)))
  expect_equal(result, expected)
})

test_that("calculate_effective_n: uniform weights give n_eff = n", {
  # All weights the same (but not 1) should still give n_eff = n
  weights <- rep(2.5, 200)
  result <- calculate_effective_n(weights)
  expect_equal(result, 200L)
})

test_that("calculate_effective_n: extreme variation reduces n_eff", {
  # One very large weight dominates
  weights <- c(rep(1, 99), 100)
  result <- calculate_effective_n(weights)

  # n_eff should be much less than 100

  expect_true(result < 50)
  expect_true(result > 0)
})

test_that("calculate_effective_n: removes NA weights", {
  weights <- c(1, 1, 1, NA, NA)
  result <- calculate_effective_n(weights)
  expect_equal(result, 3L)
})

test_that("calculate_effective_n: removes zero weights", {
  weights <- c(1, 1, 1, 0, 0)
  result <- calculate_effective_n(weights)
  expect_equal(result, 3L)
})

test_that("calculate_effective_n: removes infinite weights", {
  weights <- c(1, 1, 1, Inf)
  result <- calculate_effective_n(weights)
  expect_equal(result, 3L)
})

test_that("calculate_effective_n: all invalid returns 0", {
  expect_equal(calculate_effective_n(c(NA, NA)), 0L)
  expect_equal(calculate_effective_n(c(0, 0)), 0L)
  expect_equal(calculate_effective_n(numeric(0)), 0L)
})

test_that("calculate_effective_n: scale invariant", {
  # Multiplying all weights by a constant shouldn't change n_eff
  weights <- c(1, 2, 3, 4, 5)
  result1 <- calculate_effective_n(weights)
  result2 <- calculate_effective_n(weights * 100)
  result3 <- calculate_effective_n(weights * 0.001)

  expect_equal(result1, result2)
  expect_equal(result1, result3)
})

test_that("calculate_effective_n: large sample works", {
  set.seed(42)
  weights <- runif(10000, 0.5, 2.0)
  result <- calculate_effective_n(weights)

  expect_true(result > 0)
  expect_true(result <= 10000)
})

# ==============================================================================
# DESIGN EFFECT (DEFF)
# ==============================================================================

test_that("calculate_deff: equal weights give DEFF = 1", {
  weights <- rep(1, 100)
  result <- calculate_deff(weights)
  expect_equal(result, 1.0)
})

test_that("calculate_deff: DEFF = 1 + CV^2", {
  weights <- c(1, 2, 3, 4, 5)
  cv <- sd(weights) / mean(weights)
  expected_deff <- 1 + cv^2

  result <- calculate_deff(weights)
  expect_equal(result, expected_deff, tolerance = 1e-10)
})

test_that("calculate_deff: more variation gives higher DEFF", {
  low_var <- c(0.9, 1.0, 1.1, 0.95, 1.05)
  high_var <- c(0.1, 0.5, 1.0, 2.0, 5.0)

  deff_low <- calculate_deff(low_var)
  deff_high <- calculate_deff(high_var)

  expect_true(deff_high > deff_low)
})

test_that("calculate_deff: DEFF >= 1 always", {
  set.seed(42)
  for (i in 1:10) {
    weights <- runif(100, 0.1, 5.0)
    expect_true(calculate_deff(weights) >= 1.0)
  }
})

test_that("calculate_deff: removes NA and zero weights", {
  # These should match since NA/zero are filtered
  w1 <- c(1, 2, 3, NA, 0)
  w2 <- c(1, 2, 3)
  expect_equal(calculate_deff(w1), calculate_deff(w2))
})

test_that("calculate_deff: empty weights return NA", {
  expect_true(is.na(calculate_deff(numeric(0))))
  expect_true(is.na(calculate_deff(c(NA, NA))))
})

# ==============================================================================
# COMPREHENSIVE STUDY-LEVEL STATS
# ==============================================================================

test_that("calculate_study_level_stats: unweighted returns correct values", {
  df <- data.frame(q1 = rnorm(100), q2 = rnorm(100))
  result <- calculate_study_level_stats(df, weight_variable = NULL)

  expect_true(is.data.frame(result))
  expect_equal(result$Group, "Total")
  expect_equal(result$Actual_n, 100)
  expect_equal(result$DEFF, 1.00)
  expect_equal(result$Effective_n, 100)
  expect_equal(result$Mean_Weight, 1.000)
  expect_equal(result$Warning, "")
})

test_that("calculate_study_level_stats: weighted returns valid DEFF", {
  set.seed(42)
  df <- data.frame(q1 = rnorm(200), weight = runif(200, 0.5, 2.0))
  result <- calculate_study_level_stats(df, weight_variable = "weight")

  expect_true(is.data.frame(result))
  expect_equal(result$Actual_n, 200)
  expect_true(result$DEFF >= 1.0)
  expect_true(result$Effective_n > 0)
  expect_true(result$Effective_n <= 200)
})

test_that("calculate_study_level_stats: grouped analysis returns multiple rows", {
  set.seed(42)
  df <- data.frame(
    q1 = rnorm(200),
    gender = rep(c("M", "F"), 100),
    weight = runif(200, 0.5, 2.0)
  )
  result <- calculate_study_level_stats(df, weight_variable = "weight",
                                         group_variable = "gender")

  expect_true(nrow(result) == 2)
  expect_true("M" %in% result$Group)
  expect_true("F" %in% result$Group)
})

test_that("calculate_study_level_stats: flags high DEFF", {
  # Create extreme weights that should produce DEFF > 2
  df <- data.frame(
    q1 = rnorm(100),
    weight = c(rep(0.1, 90), rep(10, 10))
  )
  result <- calculate_study_level_stats(df, weight_variable = "weight")

  expect_true(result$DEFF > 2.0)
  expect_true(grepl("High DEFF", result$Warning))
})

# ==============================================================================
# WEIGHT CONCENTRATION DIAGNOSTICS
# ==============================================================================

test_that("compute_weight_concentration: returns correct structure", {
  set.seed(42)
  weights <- runif(1000, 0.5, 2.0)
  result <- compute_weight_concentration(weights)

  expect_true(is.data.frame(result))
  expect_true("n_weights" %in% names(result))
  expect_true("Top_1pct_Share" %in% names(result))
  expect_true("Top_5pct_Share" %in% names(result))
  expect_true("Top_10pct_Share" %in% names(result))
  expect_true("Concentration_Flag" %in% names(result))
})

test_that("compute_weight_concentration: equal weights give low concentration", {
  weights <- rep(1, 1000)
  result <- compute_weight_concentration(weights)

  # Top 1% should hold ~1% of weight (equal distribution)
  expect_true(result$Top_1pct_Share < 5)
  expect_equal(result$Concentration_Flag, "LOW")
})

test_that("compute_weight_concentration: extreme weights give high concentration", {
  weights <- c(rep(0.01, 990), rep(100, 10))
  result <- compute_weight_concentration(weights)

  # Top 1% should hold most of the weight
  expect_true(result$Top_1pct_Share > 50)
  expect_equal(result$Concentration_Flag, "HIGH")
})

test_that("compute_weight_concentration: NULL input returns NULL", {
  expect_null(compute_weight_concentration(NULL))
})

test_that("compute_weight_concentration: all zero returns NULL", {
  expect_null(compute_weight_concentration(c(0, 0, 0)))
})

test_that("compute_weight_concentration: handles NA weights", {
  weights <- c(1, 1, 1, NA, NA)
  result <- compute_weight_concentration(weights)
  expect_equal(result$n_weights, 3)
})

# ==============================================================================
# CONSISTENCY CHECKS
# ==============================================================================

test_that("DEFF and effective_n are consistent: n_eff ≈ n / DEFF", {
  set.seed(42)
  weights <- runif(500, 0.3, 3.0)

  deff <- calculate_deff(weights)
  n_eff <- calculate_effective_n(weights)
  valid_n <- sum(!is.na(weights) & is.finite(weights) & weights > 0)

  # n_eff should be approximately n / DEFF (may differ due to rounding)
  expected_n_eff <- valid_n / deff
  expect_true(abs(n_eff - expected_n_eff) < 2)
})

# ==============================================================================
# FINITE POPULATION CORRECTION (FPC)
# ==============================================================================

test_that("calculate_fpc_factor: known-answer values", {
  # FPC = sqrt((N - n) / (N - 1))
  expect_equal(calculate_fpc_factor(20, 27), sqrt(7 / 26), tolerance = 1e-9)
  expect_equal(calculate_fpc_factor(167, 556), sqrt(389 / 555), tolerance = 1e-9)
  expect_equal(calculate_fpc_factor(50, 100), sqrt(50 / 99), tolerance = 1e-9)
})

test_that("calculate_fpc_factor: full census returns 0 (zero sampling error)", {
  expect_equal(calculate_fpc_factor(27, 27), 0)
  expect_equal(calculate_fpc_factor(30, 27), 0) # rounding over-coverage clamps
})

test_that("calculate_fpc_factor: no usable population returns 1 (no correction)", {
  expect_equal(calculate_fpc_factor(50, NA), 1)
  expect_equal(calculate_fpc_factor(50, NULL), 1)
  expect_equal(calculate_fpc_factor(50, 1), 1)
  expect_equal(calculate_fpc_factor(50, 0), 1)
  expect_equal(calculate_fpc_factor(50, Inf), 1)
})

test_that("calculate_fpc_factor: invalid n returns 1 (no correction)", {
  expect_equal(calculate_fpc_factor(0, 100), 1)
  expect_equal(calculate_fpc_factor(NA, 100), 1)
  expect_equal(calculate_fpc_factor(-5, 100), 1)
})

test_that("calculate_fpc_factor: a thin sample (coverage <= 5%) gets no correction", {
  # A sample, not a census — matches the v2 report's FPC coverage gate.
  expect_equal(calculate_fpc_factor(396, 14563), 1)   # CCPB shape: 2.7%
  expect_equal(calculate_fpc_factor(50, 1000), 1)     # exactly 5% -> still no correction
  expect_lt(calculate_fpc_factor(51, 1000), 1)        # just above 5% -> a real correction
})

test_that("apply_fpc: a thin sample (coverage <= 5%) leaves the effective base unchanged", {
  expect_equal(apply_fpc(396, 396, 14563), 396)
  expect_equal(apply_fpc(50, 50, 1000), 50)           # exactly 5%
  expect_gt(apply_fpc(51, 51, 1000), 51)              # just above 5% -> inflated
})

test_that("apply_fpc: inflates effective base by (N-1)/(N-n)", {
  # n=20, N=27 -> 20 * 26 / 7 = 74.2857...
  expect_equal(apply_fpc(20, 20, 27), 20 * 26 / 7, tolerance = 1e-9)
  # weighted: Kish n_eff=18 but actual count 20 of 27
  expect_equal(apply_fpc(18, 20, 27), 18 * 26 / 7, tolerance = 1e-9)
})

test_that("apply_fpc: full census returns Inf (zero-width interval)", {
  expect_equal(apply_fpc(27, 27, 27), Inf)
  expect_equal(apply_fpc(30, 30, 27), Inf)
})

test_that("apply_fpc: no usable population returns n_eff unchanged", {
  expect_equal(apply_fpc(50, 50, NA), 50)
  expect_equal(apply_fpc(50, 50, NULL), 50)
  expect_equal(apply_fpc(50, 50, 1), 50)
  expect_equal(apply_fpc(50, 0, 100), 50) # invalid count -> unchanged
})

test_that("apply_fpc: consistent with calculate_fpc_factor on the SE", {
  # SE scales by FPC; effective base scales by 1/FPC^2. Check the identity
  # n_eff_fpc = n / FPC^2 for the unweighted case.
  n <- 40; N <- 120
  fpc <- calculate_fpc_factor(n, N)
  expect_equal(apply_fpc(n, n, N), n / (fpc^2), tolerance = 1e-9)
})
