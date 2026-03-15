# ==============================================================================
# TABS MODULE - NUMERIC PROCESSOR TESTS
# ==============================================================================
#
# Tests for numeric question processing:
#   1. detect_outliers_iqr() — IQR outlier detection
#   2. categorize_numeric_bins() — bin assignment
#   3. calculate_numeric_statistics() — mean, SD, median, mode
#   4. process_numeric_question() — end-to-end numeric processing
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_numeric_processor.R")
#
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()

source(file.path(turas_root, "modules/shared/lib/trs_refusal.R"))
source(file.path(turas_root, "modules/tabs/lib/00_guard.R"))
source(file.path(turas_root, "modules/tabs/lib/validation_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/path_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/logging_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/config_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/excel_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/filter_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/data_loader.R"))
source(file.path(turas_root, "modules/tabs/lib/numeric_processor.R"))


# ==============================================================================
# 1. detect_outliers_iqr
# ==============================================================================

context("detect_outliers_iqr")

test_that("returns no outliers for less than 4 values", {
  result <- detect_outliers_iqr(c(1, 2, 3))
  expect_equal(result$count, 0)
  expect_equal(length(result$indices), 3)
  expect_true(all(!result$indices))
})

test_that("detects no outliers in tight distribution", {
  result <- detect_outliers_iqr(c(10, 11, 12, 13, 14, 15))
  expect_equal(result$count, 0)
})

test_that("detects outlier in upper tail", {
  result <- detect_outliers_iqr(c(10, 11, 12, 13, 14, 100))
  expect_true(result$count >= 1)
  expect_true(result$indices[6])  # 100 is the outlier
})

test_that("detects outlier in lower tail", {
  result <- detect_outliers_iqr(c(-100, 10, 11, 12, 13, 14))
  expect_true(result$count >= 1)
  expect_true(result$indices[1])  # -100 is the outlier
})

test_that("handles all identical values (IQR = 0)", {
  result <- detect_outliers_iqr(c(5, 5, 5, 5, 5))
  expect_equal(result$count, 0)
})

test_that("returns logical vector of correct length", {
  values <- c(1, 2, 3, 4, 5, 6, 7, 100)
  result <- detect_outliers_iqr(values)
  expect_equal(length(result$indices), length(values))
  expect_true(is.logical(result$indices))
})


# ==============================================================================
# 2. categorize_numeric_bins
# ==============================================================================

context("categorize_numeric_bins")

test_that("assigns values to correct bins", {
  bins <- data.frame(
    Min = c(0, 18, 35, 50),
    Max = c(17, 34, 49, 99),
    OptionText = c("0-17", "18-34", "35-49", "50+"),
    stringsAsFactors = FALSE
  )

  result <- categorize_numeric_bins(c(5, 25, 42, 70), bins)

  expect_equal(result, c("0-17", "18-34", "35-49", "50+"))
})

test_that("returns NA for values outside all bins", {
  bins <- data.frame(
    Min = c(10, 20),
    Max = c(19, 29),
    OptionText = c("10-19", "20-29"),
    stringsAsFactors = FALSE
  )

  result <- categorize_numeric_bins(c(5, 15, 35), bins)

  expect_true(is.na(result[1]))
  expect_equal(result[2], "10-19")
  expect_true(is.na(result[3]))
})

test_that("handles boundary values (inclusive)", {
  bins <- data.frame(
    Min = c(1, 6),
    Max = c(5, 10),
    OptionText = c("1-5", "6-10"),
    stringsAsFactors = FALSE
  )

  # Boundary values should be included
  result <- categorize_numeric_bins(c(1, 5, 6, 10), bins)

  expect_equal(result[1], "1-5")
  expect_equal(result[2], "1-5")
  expect_equal(result[3], "6-10")
  expect_equal(result[4], "6-10")
})

test_that("returns all NA for empty bins", {
  bins <- data.frame(Min = numeric(0), Max = numeric(0),
                     OptionText = character(0), stringsAsFactors = FALSE)

  result <- categorize_numeric_bins(c(1, 2, 3), bins)

  expect_true(all(is.na(result)))
  expect_equal(length(result), 3)
})

test_that("handles NA values in input", {
  bins <- data.frame(
    Min = c(1, 6),
    Max = c(5, 10),
    OptionText = c("1-5", "6-10"),
    stringsAsFactors = FALSE
  )

  result <- categorize_numeric_bins(c(3, NA, 8), bins)

  expect_equal(result[1], "1-5")
  expect_true(is.na(result[2]))
  expect_equal(result[3], "6-10")
})


# ==============================================================================
# 3. calculate_numeric_statistics — unweighted
# ==============================================================================

context("calculate_numeric_statistics — unweighted")

test_that("calculates mean correctly", {
  data <- data.frame(Q1 = c(10, 20, 30, 40, 50))
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  config <- list(show_numeric_median = FALSE, show_numeric_mode = FALSE,
                 show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, rep(1, 5),
                                         config, is_weighted = FALSE)

  expect_equal(result$mean, 30)
})

test_that("calculates SD correctly (matches base R)", {
  values <- c(10, 20, 30, 40, 50)
  data <- data.frame(Q1 = values)
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  config <- list(show_numeric_median = FALSE, show_numeric_mode = FALSE,
                 show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, rep(1, 5),
                                         config, is_weighted = FALSE)

  expect_equal(result$sd, sd(values), tolerance = 0.001)
})

test_that("calculates median when enabled", {
  data <- data.frame(Q1 = c(10, 20, 30, 40, 50))
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  config <- list(show_numeric_median = TRUE, show_numeric_mode = FALSE,
                 show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, rep(1, 5),
                                         config, is_weighted = FALSE)

  expect_equal(result$median, 30)
})

test_that("calculates mode when enabled", {
  data <- data.frame(Q1 = c(10, 20, 20, 30, 30, 30))
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  config <- list(show_numeric_median = FALSE, show_numeric_mode = TRUE,
                 show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, rep(1, 6),
                                         config, is_weighted = FALSE)

  expect_equal(result$mode, 30)
})

test_that("handles all NA values", {
  data <- data.frame(Q1 = c(NA, NA, NA))
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  config <- list(show_numeric_median = FALSE, show_numeric_mode = FALSE,
                 show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, rep(1, 3),
                                         config, is_weighted = FALSE)

  expect_true(is.na(result$mean))
})


# ==============================================================================
# 4. calculate_numeric_statistics — weighted
# ==============================================================================

context("calculate_numeric_statistics — weighted")

test_that("calculates weighted mean correctly", {
  data <- data.frame(Q1 = c(10, 20, 30))
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  weights <- c(1, 2, 1)  # weighted mean = (10*1 + 20*2 + 30*1) / (1+2+1) = 80/4 = 20
  config <- list(show_numeric_median = FALSE, show_numeric_mode = FALSE,
                 show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, weights,
                                         config, is_weighted = TRUE)

  expect_equal(result$mean, 20, tolerance = 0.001)
})

test_that("calculates Bessel-corrected weighted SD", {
  data <- data.frame(Q1 = c(10, 20, 30))
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  weights <- c(1, 1, 1)  # Equal weights: should match base R sd()
  config <- list(show_numeric_median = FALSE, show_numeric_mode = FALSE,
                 show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, weights,
                                         config, is_weighted = TRUE)

  expect_equal(result$sd, sd(c(10, 20, 30)), tolerance = 0.001)
})

test_that("detects outliers when enabled", {
  data <- data.frame(Q1 = c(10, 11, 12, 13, 14, 100))
  question_info <- data.frame(QuestionCode = "Q1", stringsAsFactors = FALSE)
  config <- list(show_numeric_median = FALSE, show_numeric_mode = FALSE,
                 show_numeric_outliers = TRUE, exclude_outliers_from_stats = FALSE)

  result <- calculate_numeric_statistics(data, question_info, rep(1, 6),
                                         config, is_weighted = FALSE)

  expect_true(result$outlier_count >= 1)
})
