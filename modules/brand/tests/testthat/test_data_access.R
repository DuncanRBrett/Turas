# ==============================================================================
# Tests for modules/brand/R/00_data_access.R
# ==============================================================================
# Known-answer tests for the data-access layer. Every test uses literal
# data frames so expected outputs are hand-verifiable.
# ==============================================================================
library(testthat)

source(file.path("..", "..", "R", "00_data_access.R"))


# ------------------------------------------------------------------------------
# respondent_picked()
# ------------------------------------------------------------------------------

test_that("respondent_picked returns TRUE only where the option appears in any slot", {
  df <- data.frame(
    Q_1 = c("IPK", "ROB", NA,    "NONE", "IPK"),
    Q_2 = c("ROB", NA,    "IPK", NA,     NA),
    Q_3 = c(NA,    NA,    NA,    NA,     "ROB"),
    stringsAsFactors = FALSE
  )
  ipk_picks <- respondent_picked(df, "Q", "IPK")
  expect_equal(ipk_picks, c(TRUE, FALSE, TRUE, FALSE, TRUE))

  rob_picks <- respondent_picked(df, "Q", "ROB")
  expect_equal(rob_picks, c(TRUE, TRUE, FALSE, FALSE, TRUE))

  none_picks <- respondent_picked(df, "Q", "NONE")
  expect_equal(none_picks, c(FALSE, FALSE, FALSE, TRUE, FALSE))
})

test_that("respondent_picked returns all FALSE if root has no slot columns", {
  df <- data.frame(other = 1:3)
  expect_equal(respondent_picked(df, "Q", "IPK"), c(FALSE, FALSE, FALSE))
})

test_that("respondent_picked is NA-safe", {
  df <- data.frame(Q_1 = c(NA_character_, NA_character_, NA_character_))
  expect_equal(respondent_picked(df, "Q", "IPK"), c(FALSE, FALSE, FALSE))
})

test_that("respondent_picked handles roots with regex special characters", {
  df <- data.frame(`Q.A_1` = c("X", "Y"), stringsAsFactors = FALSE,
                   check.names = FALSE)
  expect_equal(respondent_picked(df, "Q.A", "X"), c(TRUE, FALSE))
})

test_that("respondent_picked refuses non-scalar option_code", {
  df <- data.frame(Q_1 = c("A", "B"))
  expect_error(respondent_picked(df, "Q", c("A", "B")),
               "DATA_ACCESS_OPTION_CODE_NOT_SCALAR")
})

test_that("respondent_picked refuses non-data-frame input", {
  expect_error(respondent_picked(list(), "Q", "X"),
               "DATA_ACCESS_NOT_DATA_FRAME")
})

test_that("respondent_picked refuses bad root", {
  df <- data.frame(Q_1 = "A")
  expect_error(respondent_picked(df, "", "X"),
               "DATA_ACCESS_INVALID_ROOT")
  expect_error(respondent_picked(df, character(0), "X"),
               "DATA_ACCESS_INVALID_ROOT")
})


# ------------------------------------------------------------------------------
# multi_mention_brand_matrix()
# ------------------------------------------------------------------------------

test_that("multi_mention_brand_matrix builds a logical matrix per brand", {
  df <- data.frame(
    BAW_1 = c("IPK", "ROB",  NA),
    BAW_2 = c("ROB", "NONE", NA),
    BAW_3 = c(NA,    NA,     NA),
    stringsAsFactors = FALSE
  )
  mat <- multi_mention_brand_matrix(df, "BAW", c("IPK", "ROB", "KNORR"))
  expect_equal(dim(mat), c(3, 3))
  expect_equal(colnames(mat), c("IPK", "ROB", "KNORR"))
  expect_equal(mat[, "IPK"],   c(TRUE,  FALSE, FALSE))
  expect_equal(mat[, "ROB"],   c(TRUE,  TRUE,  FALSE))
  expect_equal(mat[, "KNORR"], c(FALSE, FALSE, FALSE))
})

test_that("multi_mention_brand_matrix returns all-FALSE when root absent", {
  df <- data.frame(other = 1:3)
  mat <- multi_mention_brand_matrix(df, "MISSING", c("A", "B"))
  expect_equal(dim(mat), c(3, 2))
  expect_true(all(!mat))
})

test_that("multi_mention_brand_matrix returns 0-col matrix for empty brand list", {
  df <- data.frame(Q_1 = c("A", "B"))
  mat <- multi_mention_brand_matrix(df, "Q", character(0))
  expect_equal(dim(mat), c(2, 0))
})


# ------------------------------------------------------------------------------
# single_response_brand_column()
# ------------------------------------------------------------------------------

test_that("single_response_brand_column returns the named column", {
  df <- data.frame(
    BAT_DSS_IPK = c(1L, 2L, 3L, NA),
    BAT_DSS_ROB = c(4L, 5L, NA, 1L),
    stringsAsFactors = FALSE
  )
  ipk <- single_response_brand_column(df, "BAT", "DSS", "IPK")
  expect_equal(ipk, c(1L, 2L, 3L, NA))

  rob <- single_response_brand_column(df, "BAT", "DSS", "ROB")
  expect_equal(rob, c(4L, 5L, NA, 1L))
})

test_that("single_response_brand_column refuses on missing column", {
  df <- data.frame(BAT_DSS_IPK = 1L)
  expect_error(
    single_response_brand_column(df, "BAT", "DSS", "MISSING"),
    "DATA_ACCESS_COLUMN_MISSING"
  )
})


# ------------------------------------------------------------------------------
# single_response_brand_matrix()
# ------------------------------------------------------------------------------

test_that("single_response_brand_matrix collects per-brand columns", {
  df <- data.frame(
    BAT_DSS_IPK = c("1", "2", "3"),
    BAT_DSS_ROB = c("4", NA,  "5"),
    stringsAsFactors = FALSE
  )
  mat <- single_response_brand_matrix(df, "BAT", "DSS", c("IPK", "ROB"))
  expect_equal(dim(mat), c(3, 2))
  expect_equal(colnames(mat), c("IPK", "ROB"))
  expect_equal(mat[, "IPK"], c("1", "2", "3"))
  expect_equal(mat[, "ROB"], c("4", NA, "5"))
})

test_that("single_response_brand_matrix returns NA col for absent brand", {
  df <- data.frame(BAT_DSS_IPK = c("1", "2"))
  mat <- single_response_brand_matrix(df, "BAT", "DSS", c("IPK", "ROB"))
  expect_equal(mat[, "IPK"], c("1", "2"))
  expect_true(all(is.na(mat[, "ROB"])))
})

test_that("single_response_brand_matrix returns 0-col matrix for empty brands", {
  df <- data.frame(other = 1:3)
  mat <- single_response_brand_matrix(df, "BAT", "DSS", character(0))
  expect_equal(dim(mat), c(3, 0))
})


# ------------------------------------------------------------------------------
# Integration: against the real IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("data access works against the IPK Wave 1 fixture", {
  fixture <- file.path("..", "..", "tests", "fixtures",
                       "ipk_wave1", "ipk_wave1_data.xlsx")
  skip_if_not(file.exists(fixture),
              "IPK Wave 1 fixture not built; run 00_generate.R")

  df <- openxlsx::read.xlsx(fixture)
  dss <- df[!is.na(df$Focal_Category) & df$Focal_Category == "DSS", ]

  # IPK awareness rate among DSS focal cohort should match the
  # awareness probability in helpers (~0.92, with sampling noise)
  ipk_aware <- respondent_picked(dss, "BRANDAWARE_DSS", "IPK")
  expect_gt(mean(ipk_aware), 0.85)
  expect_lt(mean(ipk_aware), 0.99)

  # Multi-brand matrix shape
  brands <- c("IPK", "ROB", "KNORR", "NONE")
  mat <- multi_mention_brand_matrix(dss, "BRANDAWARE_DSS", brands)
  expect_equal(dim(mat), c(nrow(dss), 4))
  expect_equal(mean(mat[, "IPK"]), mean(ipk_aware))

  # Per-brand attitude column (numeric)
  ipk_att <- single_response_brand_column(dss, "BRANDATT1", "DSS", "IPK")
  expect_true(is.numeric(ipk_att))
  expect_true(all(ipk_att %in% c(1:5, NA)))

  # Per-brand matrix
  att_mat <- single_response_brand_matrix(dss, "BRANDATT1", "DSS",
                                          c("IPK", "ROB"))
  expect_equal(dim(att_mat), c(nrow(dss), 2))
})
