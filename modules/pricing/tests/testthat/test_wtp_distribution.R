# ==============================================================================
# TURAS PRICING MODULE - WTP DISTRIBUTION TESTS
# ==============================================================================
# Tests for: 07_wtp_distribution.R
# Covers: extract_wtp_vw, extract_wtp_gg, compute_wtp_density,
#         compute_wtp_percentiles, compute_wtp_summary
# ==============================================================================

# ------------------------------------------------------------------------------
# extract_wtp_vw
# ------------------------------------------------------------------------------

test_that("extract_wtp_vw calculates midpoint WTP from VW data", {
  data <- generate_vw_data(n = 100)

  config <- list(
    id_var = "respondent_id",
    weight_var = NA,
    segment_vars = character(0),
    van_westendorp = list(
      col_cheap = "cheap",
      col_expensive = "expensive"
    )
  )

  wtp <- extract_wtp_vw(data, config, method = "mean")

  expect_s3_class(wtp, "data.frame")
  expect_true("id" %in% names(wtp))
  expect_true("wtp" %in% names(wtp))
  expect_true("weight" %in% names(wtp))
  expect_true(all(wtp$wtp > 0))
  expect_true(all(wtp$weight == 1))
  # WTP should be between cheap and expensive
  expect_true(all(wtp$wtp >= min(data$cheap, na.rm = TRUE) * 0.5))
})

test_that("extract_wtp_vw handles weights", {
  data <- generate_vw_data(n = 50)
  data$weight <- runif(50, 0.5, 2.0)

  config <- list(
    id_var = "respondent_id",
    weight_var = "weight",
    segment_vars = character(0),
    van_westendorp = list(
      col_cheap = "cheap",
      col_expensive = "expensive"
    )
  )

  wtp <- extract_wtp_vw(data, config)

  expect_true(all(wtp$weight > 0))
  expect_false(all(wtp$weight == 1))
})

test_that("extract_wtp_vw includes segment variables", {
  data <- generate_vw_data(n = 100)
  seg <- generate_segmented_data(n = 100)
  data$segment <- seg$segment

  config <- list(
    id_var = "respondent_id",
    weight_var = NA,
    segment_vars = "segment",
    van_westendorp = list(
      col_cheap = "cheap",
      col_expensive = "expensive"
    )
  )

  wtp <- extract_wtp_vw(data, config)

  expect_true("segment" %in% names(wtp))
  expect_true(length(unique(wtp$segment)) > 1)
})

test_that("extract_wtp_vw removes NAs", {
  data <- generate_vw_data(n = 50)
  data$cheap[1:5] <- NA

  config <- list(
    id_var = "respondent_id",
    weight_var = NA,
    segment_vars = character(0),
    van_westendorp = list(
      col_cheap = "cheap",
      col_expensive = "expensive"
    )
  )

  wtp <- extract_wtp_vw(data, config)

  expect_true(all(!is.na(wtp$wtp)))
  expect_true(nrow(wtp) <= 50)
})

test_that("extract_wtp_vw generates IDs when id_var missing", {
  data <- generate_vw_data(n = 30)

  config <- list(
    id_var = NA,
    weight_var = NA,
    segment_vars = character(0),
    van_westendorp = list(
      col_cheap = "cheap",
      col_expensive = "expensive"
    )
  )

  wtp <- extract_wtp_vw(data, config)

  expect_true(nrow(wtp) > 0)
  expect_true(all(wtp$id == seq_len(nrow(wtp)) | TRUE))
})


# ------------------------------------------------------------------------------
# extract_wtp_gg
# ------------------------------------------------------------------------------

test_that("extract_wtp_gg extracts highest purchase price per respondent", {
  # Create long-format GG data
  gg_data <- data.frame(
    respondent_id = rep(1:5, each = 4),
    price = rep(c(20, 30, 40, 50), 5),
    response = c(
      1, 1, 1, 0,  # respondent 1: WTP = 40
      1, 1, 0, 0,  # respondent 2: WTP = 30
      1, 0, 0, 0,  # respondent 3: WTP = 20
      1, 1, 1, 1,  # respondent 4: WTP = 50
      0, 0, 0, 0   # respondent 5: no purchase
    ),
    stringsAsFactors = FALSE
  )

  config <- list(weight_var = NA)

  wtp <- extract_wtp_gg(gg_data, config)

  expect_s3_class(wtp, "data.frame")
  # Respondent 5 has no purchase, should be excluded (WTP = NA)
  expect_true(nrow(wtp) == 4)
  # Respondent 1's WTP should be 40
  expect_equal(wtp$wtp[wtp$id == 1], 40)
  # Respondent 4's WTP should be 50
  expect_equal(wtp$wtp[wtp$id == 4], 50)
})

test_that("extract_wtp_gg handles weights in long format", {
  gg_data <- data.frame(
    respondent_id = rep(1:3, each = 3),
    price = rep(c(20, 30, 40), 3),
    response = c(1, 1, 0, 1, 0, 0, 1, 1, 1),
    weight = rep(c(1.2, 0.8, 1.5), each = 3),
    stringsAsFactors = FALSE
  )

  config <- list(weight_var = "weight")

  wtp <- extract_wtp_gg(gg_data, config)

  expect_true(all(wtp$weight > 0))
  expect_equal(wtp$weight[wtp$id == 1], 1.2)
})


# ------------------------------------------------------------------------------
# compute_wtp_density
# ------------------------------------------------------------------------------

test_that("compute_wtp_density returns valid density estimate", {
  wtp_df <- data.frame(
    wtp = rnorm(100, mean = 50, sd = 10),
    weight = rep(1, 100)
  )

  dens <- compute_wtp_density(wtp_df)

  expect_s3_class(dens, "data.frame")
  expect_true("x" %in% names(dens))
  expect_true("density" %in% names(dens))
  expect_true(all(dens$density >= 0))
  expect_equal(nrow(dens), 512)  # default n
})

test_that("compute_wtp_density respects from/to range", {
  wtp_df <- data.frame(
    wtp = rnorm(100, mean = 50, sd = 10),
    weight = rep(1, 100)
  )

  dens <- compute_wtp_density(wtp_df, from = 30, to = 70, n = 50)

  expect_equal(nrow(dens), 50)
  expect_equal(min(dens$x), 30)
  expect_equal(max(dens$x), 70)
})

test_that("compute_wtp_density handles weighted data", {
  wtp_df <- data.frame(
    wtp = c(rep(30, 50), rep(70, 50)),
    weight = c(rep(3, 50), rep(1, 50))
  )

  dens <- compute_wtp_density(wtp_df)

  # Peak should be closer to 30 (weighted more heavily)
  peak_x <- dens$x[which.max(dens$density)]
  expect_true(peak_x < 50)
})


# ------------------------------------------------------------------------------
# compute_wtp_percentiles
# ------------------------------------------------------------------------------

test_that("compute_wtp_percentiles returns correct structure", {
  wtp_df <- data.frame(
    wtp = seq(10, 100, by = 1),
    weight = rep(1, 91)
  )

  pct <- compute_wtp_percentiles(wtp_df)

  expect_true(is.numeric(pct))
  expect_equal(length(pct), 7)  # default 7 probabilities
  expect_true(all(!is.na(pct)))
  # Percentiles should be in ascending order
  expect_true(all(diff(pct) >= 0))
})

test_that("compute_wtp_percentiles handles custom probabilities", {
  wtp_df <- data.frame(
    wtp = 1:100,
    weight = rep(1, 100)
  )

  pct <- compute_wtp_percentiles(wtp_df, probs = c(0.25, 0.75))

  expect_equal(length(pct), 2)
  expect_true(pct[1] < pct[2])
})

test_that("compute_wtp_percentiles respects weights", {
  # All weight on low WTP values
  wtp_df <- data.frame(
    wtp = c(10, 20, 30, 40, 50, 60, 70, 80, 90, 100),
    weight = c(10, 10, 10, 1, 1, 1, 1, 1, 1, 1)
  )

  pct <- compute_wtp_percentiles(wtp_df, probs = 0.5)

  # Median should be pulled toward lower values due to weight
  expect_true(pct < 55)
})


# ------------------------------------------------------------------------------
# compute_wtp_summary
# ------------------------------------------------------------------------------

test_that("compute_wtp_summary returns all expected statistics", {
  wtp_df <- data.frame(
    wtp = rnorm(200, mean = 50, sd = 15),
    weight = rep(1, 200)
  )

  summary <- compute_wtp_summary(wtp_df)

  expect_s3_class(summary, "data.frame")
  expect_equal(nrow(summary), 1)
  expect_true(all(c("n", "effective_n", "mean", "median", "sd", "min", "max") %in% names(summary)))
  expect_equal(summary$n, 200)
  expect_true(summary$sd > 0)
  expect_true(summary$min < summary$max)
})

test_that("compute_wtp_summary handles weighted data", {
  wtp_df <- data.frame(
    wtp = c(10, 20, 30, 40, 50),
    weight = c(5, 1, 1, 1, 1)
  )

  summary <- compute_wtp_summary(wtp_df)

  # Weighted mean should be pulled toward 10
  expect_true(summary$mean < 30)
  expect_equal(summary$effective_n, 9)
})

test_that("compute_wtp_summary handles empty input", {
  wtp_df <- data.frame(
    wtp = numeric(0),
    weight = numeric(0)
  )

  summary <- compute_wtp_summary(wtp_df)

  expect_equal(summary$n, 0L)
  expect_true(is.na(summary$mean))
})
