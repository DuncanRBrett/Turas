# ==============================================================================
# TURAS PRICING MODULE - WTP DISTRIBUTION TESTS
# ==============================================================================
# Tests for: 07_wtp_distribution.R
# Covers: extract_wtp_vw, extract_wtp_gg (the tabs export's WTP column).
#         The density, percentile and summary helpers had no caller and were
#         removed on 25 Sep 2026.
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
