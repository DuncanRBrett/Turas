# ==============================================================================
# TURAS PRICING MODULE - SEGMENT STATISTICAL TESTS
# ==============================================================================
# Tests for: test_segment_differences() in 10_segmentation.R
# ==============================================================================

# Helper: create segmented pricing data with known differences
make_segmented_price_data <- function(n_per_seg = 100, diff_size = 10) {
  set.seed(42)
  data.frame(
    respondent_id = seq_len(n_per_seg * 3),
    segment = rep(c("Budget", "Mid", "Premium"), each = n_per_seg),
    wtp = c(
      rnorm(n_per_seg, mean = 30, sd = 5),
      rnorm(n_per_seg, mean = 30 + diff_size, sd = 5),
      rnorm(n_per_seg, mean = 30 + 2 * diff_size, sd = 5)
    ),
    cheap = c(
      rnorm(n_per_seg, mean = 20, sd = 3),
      rnorm(n_per_seg, mean = 25, sd = 3),
      rnorm(n_per_seg, mean = 30, sd = 3)
    ),
    weight = rep(1, n_per_seg * 3),
    stringsAsFactors = FALSE
  )
}

make_seg_config <- function(weight_var = NA) {
  list(
    segmentation = list(
      segment_column = "segment",
      weight_var = weight_var,
      min_segment_n = 30
    ),
    weight_var = weight_var
  )
}


# ------------------------------------------------------------------------------
# test_segment_differences - permutation test
# ------------------------------------------------------------------------------

test_that("test_segment_differences returns expected structure", {
  data <- make_segmented_price_data()
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     method = "permutation", n_perm = 200)

  expect_true(is.list(result))
  expect_true("pairwise" %in% names(result))
  expect_true("overall" %in% names(result))
  expect_true("summary" %in% names(result))
  expect_true("significant_pairs" %in% names(result))
  expect_equal(result$metric, "wtp")
  expect_equal(result$method, "permutation")
})

test_that("test_segment_differences detects significant differences", {
  # Large difference (diff_size = 15) should be detected
  data <- make_segmented_price_data(n_per_seg = 100, diff_size = 15)
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     method = "permutation", n_perm = 500)

  # Overall KW test should be significant
  expect_true(result$overall$significant)
  expect_true(result$overall$p_value < 0.05)

  # At least some pairwise comparisons should be significant
  expect_true(length(result$significant_pairs) > 0)
})

test_that("test_segment_differences finds no difference for identical segments", {
  set.seed(99)
  n <- 100
  data <- data.frame(
    respondent_id = seq_len(n * 2),
    segment = rep(c("A", "B"), each = n),
    wtp = rnorm(n * 2, mean = 50, sd = 10),
    weight = rep(1, n * 2),
    stringsAsFactors = FALSE
  )
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     method = "permutation", n_perm = 500)

  # Should NOT be significant (same distribution)
  expect_true(result$pairwise$p_adjusted[1] > 0.05)
})

test_that("test_segment_differences pairwise table has correct pairs", {
  data <- make_segmented_price_data()
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     n_perm = 100)

  # 3 segments → 3 pairwise comparisons
  expect_equal(nrow(result$pairwise), 3)
  expect_true(all(c("segment_a", "segment_b", "mean_a", "mean_b",
                     "diff", "p_value", "p_adjusted", "significant")
                   %in% names(result$pairwise)))
})


# ------------------------------------------------------------------------------
# test_segment_differences - bootstrap CI method
# ------------------------------------------------------------------------------

test_that("test_segment_differences bootstrap_ci returns CIs", {
  data <- make_segmented_price_data()
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     method = "bootstrap_ci", n_perm = 200)

  expect_equal(result$method, "bootstrap_ci")
  expect_true("ci_lower" %in% names(result$pairwise))
  expect_true("ci_upper" %in% names(result$pairwise))
  expect_true("significant" %in% names(result$pairwise))
})

test_that("test_segment_differences bootstrap_ci detects large differences", {
  data <- make_segmented_price_data(n_per_seg = 100, diff_size = 15)
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     method = "bootstrap_ci", n_perm = 500)

  # Budget vs Premium should have CI excluding zero
  bp_row <- result$pairwise[result$pairwise$segment_a == "Budget" &
                              result$pairwise$segment_b == "Premium", ]
  expect_true(nrow(bp_row) > 0)
  expect_true(bp_row$significant)
})


# ------------------------------------------------------------------------------
# test_segment_differences - summary statistics
# ------------------------------------------------------------------------------

test_that("test_segment_differences summary has correct segments", {
  data <- make_segmented_price_data()
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     n_perm = 100)

  expect_equal(nrow(result$summary), 3)
  expect_true(all(c("Budget", "Mid", "Premium") %in% result$summary$segment))
  expect_true(all(c("n", "mean", "ci_lower", "ci_upper", "sd")
                   %in% names(result$summary)))
})

test_that("test_segment_differences summary means are reasonable", {
  data <- make_segmented_price_data(diff_size = 10)
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     n_perm = 100)

  budget_mean <- result$summary$mean[result$summary$segment == "Budget"]
  premium_mean <- result$summary$mean[result$summary$segment == "Premium"]

  # Premium should have higher WTP
  expect_true(premium_mean > budget_mean)
})

test_that("test_segment_differences CIs contain the mean", {
  data <- make_segmented_price_data()
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     n_perm = 200)

  for (i in seq_len(nrow(result$summary))) {
    expect_true(result$summary$ci_lower[i] <= result$summary$mean[i])
    expect_true(result$summary$ci_upper[i] >= result$summary$mean[i])
  }
})


# ------------------------------------------------------------------------------
# test_segment_differences - weighted data
# ------------------------------------------------------------------------------

test_that("test_segment_differences handles weighted data", {
  data <- make_segmented_price_data()
  data$weight <- runif(nrow(data), 0.5, 2.0)
  config <- make_seg_config(weight_var = "weight")

  result <- test_segment_differences(data, config, metric = "wtp",
                                     n_perm = 200)

  expect_true(is.list(result))
  expect_true(nrow(result$pairwise) > 0)
})


# ------------------------------------------------------------------------------
# test_segment_differences - error handling
# ------------------------------------------------------------------------------

test_that("test_segment_differences refuses missing segment column", {
  data <- make_segmented_price_data()
  config <- list(segmentation = list(segment_column = "nonexistent"))

  expect_error(test_segment_differences(data, config, metric = "wtp"),
               "DATA_SEGMENT_COLUMN_MISSING")
})

test_that("test_segment_differences refuses missing metric column", {
  data <- make_segmented_price_data()
  config <- make_seg_config()

  expect_error(test_segment_differences(data, config, metric = "nonexistent"),
               "DATA_METRIC_COLUMN_MISSING")
})

test_that("test_segment_differences refuses missing segment config", {
  data <- make_segmented_price_data()
  config <- list(segmentation = list(segment_column = NA))

  expect_error(test_segment_differences(data, config, metric = "wtp"),
               "CFG_MISSING_SEGMENT_COLUMN")
})

test_that("test_segment_differences refuses single segment", {
  data <- make_segmented_price_data()
  data$segment <- "Only One"
  config <- make_seg_config()

  expect_error(test_segment_differences(data, config, metric = "wtp"),
               "DATA_INSUFFICIENT_SEGMENTS")
})

test_that("test_segment_differences works with two segments", {
  data <- make_segmented_price_data()
  data <- data[data$segment != "Mid", ]
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "wtp",
                                     n_perm = 100)

  # 2 segments → 1 pairwise comparison
  expect_equal(nrow(result$pairwise), 1)
})

test_that("test_segment_differences works with different metric columns", {
  data <- make_segmented_price_data()
  config <- make_seg_config()

  result <- test_segment_differences(data, config, metric = "cheap",
                                     n_perm = 100)

  expect_equal(result$metric, "cheap")
  expect_true(nrow(result$pairwise) > 0)
})
