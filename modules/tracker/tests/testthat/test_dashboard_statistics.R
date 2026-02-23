# ==============================================================================
# TEST SUITE: Dashboard Statistics Functions
# ==============================================================================
# Tests for extract_primary_metric() and calculate_pairwise_significance()
# from tracker_dashboard_reports.R.
#
# These functions are critical for:
#   - Extracting the correct metric value from wave results
#   - Calculating statistical significance between waves
#   - Correctly handling the 0-100 proportion scale
# ==============================================================================

library(testthat)

context("Dashboard Statistics: extract_primary_metric & calculate_pairwise_significance")

# ==============================================================================
# SETUP: Source required modules
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

# Source dependencies in order (matching run_tracker.R source order)
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "tracker_dashboard_reports.R"))


# ==============================================================================
# HELPERS: Mock wave result builders
# ==============================================================================

#' Create a mock wave result for proportions metric
#'
#' @param proportions Numeric vector of proportions (0-100 scale)
#' @param n_weighted Numeric. Weighted sample size
#' @param available Logical. Is this wave available?
make_proportion_result <- function(proportions = c(45, 30, 25),
                                   n_weighted = 100,
                                   available = TRUE) {
  list(
    available = available,
    proportions = proportions,
    n_weighted = n_weighted,
    n_unweighted = n_weighted
  )
}

#' Create a mock wave result for mean metric
make_mean_result <- function(mean_val = 3.5, sd_val = 1.0,
                              n_weighted = 100, available = TRUE) {
  list(
    available = available,
    mean = mean_val,
    sd = sd_val,
    n_weighted = n_weighted,
    n_unweighted = n_weighted
  )
}

#' Create a mock wave result for NPS metric
make_nps_result <- function(nps = 25, n_weighted = 100, available = TRUE) {
  list(
    available = available,
    nps = nps,
    n_weighted = n_weighted,
    n_unweighted = n_weighted
  )
}

#' Create a mock wave result for multi-mention metric
make_multi_mention_result <- function(item_proportions = c(60, 40, 20),
                                       n_weighted = 100, available = TRUE) {
  list(
    available = available,
    item_proportions = item_proportions,
    n_weighted = n_weighted,
    n_unweighted = n_weighted
  )
}

#' Create a mock wave result for category mentions metric
make_category_mentions_result <- function(category_proportions = c(55, 35),
                                           n_weighted = 100, available = TRUE) {
  list(
    available = available,
    category_proportions = category_proportions,
    n_weighted = n_weighted,
    n_unweighted = n_weighted
  )
}


# ==============================================================================
# extract_primary_metric() - PROPORTIONS
# ==============================================================================

test_that("extract_primary_metric: proportions returns first proportion (0-100 scale)", {
  result <- make_proportion_result(proportions = c(45, 30, 25))
  value <- extract_primary_metric(result, METRIC_TYPES$PROPORTIONS)
  expect_equal(value, 45)
})

test_that("extract_primary_metric: proportions does NOT double-multiply by 100", {
  # Critical regression test for Phase 1 Fix 7a
  result <- make_proportion_result(proportions = c(75))
  value <- extract_primary_metric(result, METRIC_TYPES$PROPORTIONS)
  expect_equal(value, 75)  # NOT 7500
  expect_true(value <= 100)
})

test_that("extract_primary_metric: proportions falls back to $proportion field", {
  result <- list(available = TRUE, proportion = 42, n_weighted = 100)
  value <- extract_primary_metric(result, METRIC_TYPES$PROPORTIONS)
  expect_equal(value, 42)
})

test_that("extract_primary_metric: proportions returns NA when no proportion data", {
  result <- list(available = TRUE, mean = 3.5, n_weighted = 100)
  value <- extract_primary_metric(result, METRIC_TYPES$PROPORTIONS)
  expect_true(is.na(value))
})


# ==============================================================================
# extract_primary_metric() - MEAN / RATING / COMPOSITE
# ==============================================================================

test_that("extract_primary_metric: mean type returns mean value", {
  result <- make_mean_result(mean_val = 3.7)
  value <- extract_primary_metric(result, METRIC_TYPES$MEAN)
  expect_equal(value, 3.7)
})

test_that("extract_primary_metric: rating_enhanced returns mean", {
  result <- make_mean_result(mean_val = 4.2)
  value <- extract_primary_metric(result, METRIC_TYPES$RATING_ENHANCED)
  expect_equal(value, 4.2)
})

test_that("extract_primary_metric: composite returns mean", {
  result <- make_mean_result(mean_val = 65.3)
  value <- extract_primary_metric(result, METRIC_TYPES$COMPOSITE)
  expect_equal(value, 65.3)
})

test_that("extract_primary_metric: composite_enhanced returns mean", {
  result <- make_mean_result(mean_val = 72.1)
  value <- extract_primary_metric(result, METRIC_TYPES$COMPOSITE_ENHANCED)
  expect_equal(value, 72.1)
})


# ==============================================================================
# extract_primary_metric() - NPS
# ==============================================================================

test_that("extract_primary_metric: NPS returns nps score", {
  result <- make_nps_result(nps = 35)
  value <- extract_primary_metric(result, METRIC_TYPES$NPS)
  expect_equal(value, 35)
})

test_that("extract_primary_metric: NPS handles negative scores", {
  result <- make_nps_result(nps = -20)
  value <- extract_primary_metric(result, METRIC_TYPES$NPS)
  expect_equal(value, -20)
})


# ==============================================================================
# extract_primary_metric() - MULTI_MENTION / CATEGORY_MENTIONS
# ==============================================================================

test_that("extract_primary_metric: multi_mention returns first item proportion", {
  result <- make_multi_mention_result(item_proportions = c(60, 40, 20))
  value <- extract_primary_metric(result, METRIC_TYPES$MULTI_MENTION)
  expect_equal(value, 60)
})

test_that("extract_primary_metric: multi_mention does NOT double-multiply", {
  result <- make_multi_mention_result(item_proportions = c(80))
  value <- extract_primary_metric(result, METRIC_TYPES$MULTI_MENTION)
  expect_equal(value, 80)  # NOT 8000
  expect_true(value <= 100)
})

test_that("extract_primary_metric: category_mentions returns first category proportion", {
  result <- make_category_mentions_result(category_proportions = c(55, 35))
  value <- extract_primary_metric(result, METRIC_TYPES$CATEGORY_MENTIONS)
  expect_equal(value, 55)
})


# ==============================================================================
# extract_primary_metric() - EDGE CASES
# ==============================================================================

test_that("extract_primary_metric: NULL wave_result returns NA", {
  expect_equal(extract_primary_metric(NULL, METRIC_TYPES$MEAN), NA)
})

test_that("extract_primary_metric: unavailable wave returns NA", {
  result <- make_mean_result(available = FALSE)
  expect_equal(extract_primary_metric(result, METRIC_TYPES$MEAN), NA)
})

test_that("extract_primary_metric: fallback returns mean when metric type unknown to branches", {
  # A type that passes validation but doesn't match any if-else branch
  # This tests the default fallback at the end of the function
  result <- list(available = TRUE, mean = 3.14)
  # We can't easily test this without adding a new metric type,
  # but we CAN verify the function handles all VALID types without error
  for (mt in VALID_METRIC_TYPES) {
    val <- extract_primary_metric(list(available = TRUE, mean = 1.0, nps = 1.0,
                                        proportions = c(50), proportion = 50,
                                        item_proportions = c(50),
                                        category_proportions = c(50),
                                        n_weighted = 100), mt)
    expect_true(is.numeric(val), info = paste("Failed for metric_type:", mt))
  }
})


# ==============================================================================
# calculate_pairwise_significance() - PROPORTION Z-TEST
# ==============================================================================

test_that("pairwise_significance: detects significant increase in proportions", {
  from <- make_proportion_result(proportions = c(30), n_weighted = 200)
  to <- make_proportion_result(proportions = c(50), n_weighted = 200)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS)

  expect_equal(result$sig_code, 1)       # Significant increase
  expect_true(result$p_value < 0.05)
})

test_that("pairwise_significance: detects significant decrease in proportions", {
  from <- make_proportion_result(proportions = c(60), n_weighted = 200)
  to <- make_proportion_result(proportions = c(35), n_weighted = 200)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS)

  expect_equal(result$sig_code, -1)      # Significant decrease
  expect_true(result$p_value < 0.05)
})

test_that("pairwise_significance: non-significant when proportions are close", {
  from <- make_proportion_result(proportions = c(50), n_weighted = 30)
  to <- make_proportion_result(proportions = c(52), n_weighted = 30)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS)

  expect_equal(result$sig_code, 0)
  expect_true(is.na(result$p_value) || result$p_value >= 0.05)
})

test_that("pairwise_significance: proportion scale conversion is correct (0-100 to 0-1)", {
  # Critical regression test for Phase 1 Fix 7b
  # 40% vs 60% with n=200 each. The function must convert to 0.4 vs 0.6 internally.
  from <- make_proportion_result(proportions = c(40), n_weighted = 200)
  to <- make_proportion_result(proportions = c(60), n_weighted = 200)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS)

  # Verify against manual z-test calculation
  p1 <- 0.40; p2 <- 0.60; n1 <- 200; n2 <- 200
  p_pool <- (p1 * n1 + p2 * n2) / (n1 + n2)
  se <- sqrt(p_pool * (1 - p_pool) * (1/n1 + 1/n2))
  z_expected <- (p2 - p1) / se
  p_expected <- 2 * pnorm(-abs(z_expected))

  expect_equal(result$p_value, p_expected, tolerance = 0.001)
  expect_equal(result$sig_code, 1)
})

test_that("pairwise_significance: uses $proportion field as fallback", {
  from <- list(available = TRUE, proportion = 35, n_weighted = 150)
  to <- list(available = TRUE, proportion = 55, n_weighted = 150)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS)

  expect_true(is.numeric(result$p_value))
  expect_equal(result$sig_code, 1)
})

test_that("pairwise_significance: uses $item_proportions for multi_mention", {
  from <- make_multi_mention_result(item_proportions = c(30), n_weighted = 200)
  to <- make_multi_mention_result(item_proportions = c(55), n_weighted = 200)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MULTI_MENTION)

  expect_equal(result$sig_code, 1)
  expect_true(result$p_value < 0.05)
})


# ==============================================================================
# calculate_pairwise_significance() - NUMERIC T-TEST (Welch's)
# ==============================================================================

test_that("pairwise_significance: detects significant increase in means", {
  from <- make_mean_result(mean_val = 3.0, sd_val = 1.0, n_weighted = 100)
  to <- make_mean_result(mean_val = 4.0, sd_val = 1.0, n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)

  expect_equal(result$sig_code, 1)
  expect_true(result$p_value < 0.05)
})

test_that("pairwise_significance: detects significant decrease in means", {
  from <- make_mean_result(mean_val = 4.0, sd_val = 1.0, n_weighted = 100)
  to <- make_mean_result(mean_val = 3.0, sd_val = 1.0, n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)

  expect_equal(result$sig_code, -1)
  expect_true(result$p_value < 0.05)
})

test_that("pairwise_significance: non-significant when means are close", {
  from <- make_mean_result(mean_val = 3.50, sd_val = 1.0, n_weighted = 30)
  to <- make_mean_result(mean_val = 3.55, sd_val = 1.0, n_weighted = 30)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)

  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: Welch's t-test uses correct degrees of freedom", {
  # Verify with manual calculation for unequal variances
  from <- make_mean_result(mean_val = 3.0, sd_val = 1.0, n_weighted = 50)
  to <- make_mean_result(mean_val = 4.0, sd_val = 2.0, n_weighted = 80)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)

  # Manual Welch-Satterthwaite df
  sd1 <- 1.0; sd2 <- 2.0; n1 <- 50; n2 <- 80
  se <- sqrt(sd1^2/n1 + sd2^2/n2)
  t_stat <- (4.0 - 3.0) / se
  df <- (sd1^2/n1 + sd2^2/n2)^2 / ((sd1^2/n1)^2/(n1-1) + (sd2^2/n2)^2/(n2-1))
  p_expected <- 2 * pt(-abs(t_stat), df)

  expect_equal(result$p_value, p_expected, tolerance = 0.001)
})

test_that("pairwise_significance: rating_enhanced uses t-test", {
  from <- make_mean_result(mean_val = 3.0, sd_val = 1.0, n_weighted = 100)
  to <- make_mean_result(mean_val = 4.5, sd_val = 1.0, n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$RATING_ENHANCED)

  expect_equal(result$sig_code, 1)
  expect_true(result$p_value < 0.05)
})

test_that("pairwise_significance: composite uses t-test", {
  from <- make_mean_result(mean_val = 60, sd_val = 10, n_weighted = 100)
  to <- make_mean_result(mean_val = 70, sd_val = 10, n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$COMPOSITE)

  expect_equal(result$sig_code, 1)
})


# ==============================================================================
# calculate_pairwise_significance() - NPS
# ==============================================================================

test_that("pairwise_significance: detects significant NPS increase", {
  from <- make_nps_result(nps = -10, n_weighted = 200)
  to <- make_nps_result(nps = 30, n_weighted = 200)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$NPS)

  expect_equal(result$sig_code, 1)
  expect_true(result$p_value < 0.05)
})

test_that("pairwise_significance: detects significant NPS decrease", {
  from <- make_nps_result(nps = 40, n_weighted = 200)
  to <- make_nps_result(nps = -5, n_weighted = 200)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$NPS)

  expect_equal(result$sig_code, -1)
  expect_true(result$p_value < 0.05)
})

test_that("pairwise_significance: NPS non-significant for small change", {
  from <- make_nps_result(nps = 20, n_weighted = 50)
  to <- make_nps_result(nps = 22, n_weighted = 50)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$NPS)

  expect_equal(result$sig_code, 0)
})


# ==============================================================================
# calculate_pairwise_significance() - EDGE CASES
# ==============================================================================

test_that("pairwise_significance: NULL from_result returns default", {
  to <- make_mean_result()
  result <- calculate_pairwise_significance(NULL, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
  expect_true(is.na(result$p_value))
})

test_that("pairwise_significance: NULL to_result returns default", {
  from <- make_mean_result()
  result <- calculate_pairwise_significance(from, NULL, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
  expect_true(is.na(result$p_value))
})

test_that("pairwise_significance: unavailable from_result returns default", {
  from <- make_mean_result(available = FALSE)
  to <- make_mean_result()
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: unavailable to_result returns default", {
  from <- make_mean_result()
  to <- make_mean_result(available = FALSE)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: zero sample size returns default", {
  from <- make_mean_result(n_weighted = 0)
  to <- make_mean_result(n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: n=1 for numeric returns default (insufficient df)", {
  from <- make_mean_result(n_weighted = 1)
  to <- make_mean_result(n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: NA in mean returns default", {
  from <- make_mean_result(mean_val = NA)
  to <- make_mean_result()
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: NA in sd returns default", {
  from <- make_mean_result(sd_val = NA)
  to <- make_mean_result()
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: zero SE for proportions returns default", {
  # Both 0% proportions -> se = 0
  from <- make_proportion_result(proportions = c(0), n_weighted = 100)
  to <- make_proportion_result(proportions = c(0), n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: zero SE for numeric returns default", {
  # Both SDs zero -> se = 0
  from <- make_mean_result(mean_val = 3.0, sd_val = 0)
  to <- make_mean_result(mean_val = 3.0, sd_val = 0)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: custom alpha respected", {
  from <- make_proportion_result(proportions = c(40), n_weighted = 100)
  to <- make_proportion_result(proportions = c(55), n_weighted = 100)

  result_strict <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS, alpha = 0.01)
  result_loose <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS, alpha = 0.10)

  # With stricter alpha, might not be significant; with looser alpha, more likely
  # At minimum, sig_code should be >= for looser alpha
  expect_true(result_loose$sig_code >= result_strict$sig_code)
})

test_that("pairwise_significance: equal proportions returns non-significant", {
  from <- make_proportion_result(proportions = c(50), n_weighted = 100)
  to <- make_proportion_result(proportions = c(50), n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$PROPORTIONS)
  expect_equal(result$sig_code, 0)
})

test_that("pairwise_significance: equal means returns non-significant", {
  from <- make_mean_result(mean_val = 3.5, sd_val = 1.0, n_weighted = 100)
  to <- make_mean_result(mean_val = 3.5, sd_val = 1.0, n_weighted = 100)
  result <- calculate_pairwise_significance(from, to, METRIC_TYPES$MEAN)
  expect_equal(result$sig_code, 0)
})


# ==============================================================================
# CROSS-VALIDATION: Proportion scale pipeline consistency
# ==============================================================================

test_that("full pipeline: calculate_proportions -> extract -> pairwise all use 0-100 consistently", {
  # Simulate the actual pipeline:
  # 1. calculate_proportions() stores on 0-100 scale
  # 2. extract_primary_metric() reads without re-scaling
  # 3. calculate_pairwise_significance() converts to 0-1 for z-test

  # Step 1: calculate_proportions produces 0-100 values (returns named list)
  set.seed(123)
  wave1_vals <- sample(c("A", "B"), 200, replace = TRUE, prob = c(0.40, 0.60))
  wave2_vals <- sample(c("A", "B"), 200, replace = TRUE, prob = c(0.65, 0.35))
  wave1_data <- calculate_proportions(wave1_vals, rep(1, 200), codes = c("A", "B"))
  wave2_data <- calculate_proportions(wave2_vals, rep(1, 200), codes = c("A", "B"))

  # Verify proportions are on 0-100 scale (sum to 100)
  expect_equal(sum(wave1_data$proportions), 100)
  expect_equal(sum(wave2_data$proportions), 100)

  # Step 2: Build wave results as the tracker would
  # Use explicit field names to avoid R's partial matching:
  #   - $proportion (singular) for the first/primary proportion value
  #   - $proportions (plural) for the full named vector
  # In real tracker data, the singular form is used for pairwise significance.
  wave1_prop_A <- wave1_data$proportions[["A"]]
  wave2_prop_A <- wave2_data$proportions[["A"]]

  wave1_result <- list(
    available = TRUE,
    proportion = wave1_prop_A,
    proportions = wave1_data$proportions,
    n_weighted = 200,
    n_unweighted = 200
  )
  wave2_result <- list(
    available = TRUE,
    proportion = wave2_prop_A,
    proportions = wave2_data$proportions,
    n_weighted = 200,
    n_unweighted = 200
  )

  # Step 3: extract_primary_metric reads the value (should be on 0-100 scale)
  val1 <- extract_primary_metric(wave1_result, METRIC_TYPES$PROPORTIONS)
  val2 <- extract_primary_metric(wave2_result, METRIC_TYPES$PROPORTIONS)
  expect_true(val1 > 0 && val1 <= 100)
  expect_true(val2 > 0 && val2 <= 100)

  # Step 4: pairwise significance should work correctly with 0-100 input
  sig_result <- calculate_pairwise_significance(
    wave1_result, wave2_result, METRIC_TYPES$PROPORTIONS
  )
  expect_true(is.numeric(sig_result$p_value))
  # p_value should be a valid probability (not NaN from bad scale conversion)
  expect_true(sig_result$p_value >= 0 && sig_result$p_value <= 1)
  # With ~40% vs ~65% and n=200, should be significant
  expect_equal(sig_result$sig_code, 1)
})


# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
