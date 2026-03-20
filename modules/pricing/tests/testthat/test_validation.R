# ==============================================================================
# TURAS PRICING MODULE - DATA LOADING & VALIDATION TESTS
# ==============================================================================
# Tests for: 02_validation.R
# Covers: load_pricing_data, validate_pricing_data, check_vw_monotonicity
# ==============================================================================


# ------------------------------------------------------------------------------
# load_pricing_data
# ------------------------------------------------------------------------------

test_that("load_pricing_data reads CSV files", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  df <- data.frame(
    id = 1:10,
    cheap = runif(10, 20, 40),
    expensive = runif(10, 40, 60),
    stringsAsFactors = FALSE
  )
  write.csv(df, tmp, row.names = FALSE)

  config <- list(dk_codes = numeric(0))
  result <- load_pricing_data(tmp, config)

  expect_true(is.list(result))
  expect_equal(result$n_rows, 10)
  expect_equal(result$file_type, "csv")
  expect_false(result$dk_recoded)
})

test_that("load_pricing_data reads XLSX files", {
  skip_if_not_installed("openxlsx")

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  df <- data.frame(id = 1:5, price = c(20, 30, 40, 50, 60))
  openxlsx::write.xlsx(df, tmp)

  config <- list(dk_codes = numeric(0))
  result <- load_pricing_data(tmp, config)

  expect_equal(result$n_rows, 5)
  expect_equal(result$file_type, "xlsx")
})

test_that("load_pricing_data reads RDS files", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp), add = TRUE)

  df <- data.frame(id = 1:3, val = c(10, 20, 30))
  saveRDS(df, tmp)

  config <- list(dk_codes = numeric(0))
  result <- load_pricing_data(tmp, config)

  expect_equal(result$n_rows, 3)
  expect_equal(result$file_type, "rds")
})

test_that("load_pricing_data refuses missing file", {
  config <- list(dk_codes = numeric(0))
  expect_error(load_pricing_data("/nonexistent/file.csv", config),
               "IO_DATA_NOT_FOUND")
})

test_that("load_pricing_data refuses unsupported format", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  writeLines("{}", tmp)

  config <- list(dk_codes = numeric(0))
  expect_error(load_pricing_data(tmp, config), "IO_UNSUPPORTED_FORMAT")
})

test_that("load_pricing_data recodes DK values to NA", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  df <- data.frame(
    id = 1:5,
    cheap = c(20, 30, 98, 99, 40),
    expensive = c(50, 60, 70, 98, 80)
  )
  write.csv(df, tmp, row.names = FALSE)

  config <- list(
    dk_codes = c(98, 99),
    van_westendorp = list(
      col_too_cheap = "cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "expensive"
    ),
    gabor_granger = NULL
  )

  result <- load_pricing_data(tmp, config)
  expect_true(result$dk_recoded)
  expect_equal(sum(is.na(result$data$cheap)), 2)  # 98 and 99 recoded
})

test_that("load_pricing_data handles NA strings in CSV", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  writeLines(c("id,price", "1,30", "2,", "3,NA", "4,N/A", "5,-99"), tmp)

  config <- list(dk_codes = numeric(0))
  result <- load_pricing_data(tmp, config)

  # Empty, NA, N/A, -99 should all be NA
  expect_equal(sum(is.na(result$data$price)), 4)
})


# ------------------------------------------------------------------------------
# validate_pricing_data
# ------------------------------------------------------------------------------

test_that("validate_pricing_data returns valid structure for VW data", {
  data <- generate_vw_data(n = 100)

  config <- list(
    analysis_method = "van_westendorp",
    weight_var = NA,
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive",
      validate_monotonicity = FALSE
    ),
    validation = NULL
  )

  result <- validate_pricing_data(data, config)

  expect_true(is.list(result))
  expect_true("clean_data" %in% names(result))
  expect_true("n_total" %in% names(result))
  expect_true("n_valid" %in% names(result))
  expect_true("n_excluded" %in% names(result))
  expect_true("n_warnings" %in% names(result))
  expect_true(result$n_valid > 0)
})

test_that("validate_pricing_data refuses missing VW columns", {
  data <- data.frame(id = 1:10, cheap = runif(10))

  config <- list(
    analysis_method = "van_westendorp",
    weight_var = NA,
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive"
    ),
    validation = NULL
  )

  expect_error(validate_pricing_data(data, config), "DATA_VW_COLUMNS_MISSING")
})

test_that("validate_pricing_data refuses missing weight variable", {
  data <- generate_vw_data(n = 50)

  config <- list(
    analysis_method = "van_westendorp",
    weight_var = "nonexistent_weight",
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive",
      validate_monotonicity = FALSE
    ),
    validation = NULL
  )

  expect_error(validate_pricing_data(data, config), "DATA_WEIGHT_VAR_MISSING")
})

test_that("validate_pricing_data excludes invalid weights", {
  data <- generate_vw_data(n = 50)
  data$wt <- rep(1, 50)
  data$wt[1:3] <- c(-1, NA, Inf)

  config <- list(
    analysis_method = "van_westendorp",
    weight_var = "wt",
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive",
      validate_monotonicity = FALSE
    ),
    validation = NULL
  )

  result <- validate_pricing_data(data, config)

  expect_true(result$n_excluded >= 3)
  expect_true(!is.null(result$weight_summary))
})

test_that("validate_pricing_data calculates weight summary", {
  data <- generate_vw_data(n = 50)
  data$wt <- runif(50, 0.5, 2.0)

  config <- list(
    analysis_method = "van_westendorp",
    weight_var = "wt",
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive",
      validate_monotonicity = FALSE
    ),
    validation = NULL
  )

  result <- validate_pricing_data(data, config)

  ws <- result$weight_summary
  expect_true(ws$min >= 0.5)
  expect_true(ws$max <= 2.0)
  expect_true(ws$n_valid == 50)
})

test_that("validate_pricing_data warns on missing price values", {
  data <- generate_vw_data(n = 50)
  data$cheap[1:5] <- NA

  config <- list(
    analysis_method = "van_westendorp",
    weight_var = NA,
    van_westendorp = list(
      col_too_cheap = "too_cheap",
      col_cheap = "cheap",
      col_expensive = "expensive",
      col_too_expensive = "too_expensive",
      validate_monotonicity = FALSE
    ),
    validation = NULL
  )

  result <- validate_pricing_data(data, config)
  expect_true(result$n_warnings > 0)
})


# ------------------------------------------------------------------------------
# check_vw_monotonicity
# ------------------------------------------------------------------------------

test_that("check_vw_monotonicity detects violations", {
  # Valid monotonic: too_cheap < cheap < expensive < too_expensive
  tc <- c(10, 15, 20)
  ch <- c(20, 25, 30)
  ex <- c(30, 35, 40)
  te <- c(40, 45, 50)

  result <- check_vw_monotonicity(tc, ch, ex, te)

  expect_true(is.list(result))
  expect_equal(result$count, 0)
  expect_equal(result$rate, 0)
})

test_that("check_vw_monotonicity catches non-monotonic cases", {
  # Violation: cheap > expensive for respondent 2
  tc <- c(10, 15, 20)
  ch <- c(20, 50, 30)  # respondent 2: cheap=50 > expensive=35
  ex <- c(30, 35, 40)
  te <- c(40, 45, 50)

  result <- check_vw_monotonicity(tc, ch, ex, te)

  expect_true(result$count > 0)
  expect_true(result$rate > 0)
})

test_that("check_vw_monotonicity handles NAs", {
  tc <- c(10, NA, 20)
  ch <- c(20, 25, 30)
  ex <- c(30, 35, 40)
  te <- c(40, NA, 50)

  result <- check_vw_monotonicity(tc, ch, ex, te)

  # Should not error, NAs should be handled gracefully
  expect_true(is.list(result))
})
