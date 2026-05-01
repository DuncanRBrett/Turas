# ==============================================================================
# Tests for modules/brand/R/00_guard_role_map.R
# ==============================================================================
library(testthat)

source(file.path("..", "..", "R", "00_guard_role_map.R"))


# ------------------------------------------------------------------------------
# guard_alchemer_parser_shape
# ------------------------------------------------------------------------------

test_that("guard_alchemer_parser_shape passes on parser-shape data", {
  df <- data.frame(
    Response.ID = 1L, Focal_Category = "DSS",
    BRANDAWARE_DSS_1 = "IPK", BRANDAWARE_DSS_2 = "ROB",
    BRANDPEN1_DSS_1 = NA_character_, CATBUY_DSS = 1L
  )
  expect_silent(guard_alchemer_parser_shape(df))
})

test_that("guard_alchemer_parser_shape refuses raw Alchemer X1.. headers", {
  df <- data.frame(X1 = 1, X2 = 2, X3 = 3, X4 = 4, X5 = 5)
  expect_error(guard_alchemer_parser_shape(df),
               "DATA_NO_ALCHEMER_PARSER_OUTPUT")
})

test_that("guard_alchemer_parser_shape refuses legacy column-per-brand shape", {
  df <- data.frame(
    BRANDAWARE_DSS_IPK = 1L, BRANDAWARE_DSS_ROB = 0L,
    BRANDAWARE_DSS_KNORR = 1L, BRANDAWARE_DSS_CART = 0L,
    BRANDAWARE_DSS_CHS = 1L, BRANDAWARE_DSS_FNF = 0L
  )
  expect_error(guard_alchemer_parser_shape(df),
               "DATA_LEGACY_COLUMN_PER_BRAND")
})

test_that("guard_alchemer_parser_shape refuses non-data-frame", {
  expect_error(guard_alchemer_parser_shape(list()),
               "DATA_NOT_DATA_FRAME")
})

test_that("guard_alchemer_parser_shape refuses empty data", {
  df <- data.frame()  # no columns
  expect_error(guard_alchemer_parser_shape(df), "DATA_NO_COLUMNS")
})


# ------------------------------------------------------------------------------
# guard_slot_columns_present
# ------------------------------------------------------------------------------

test_that("guard_slot_columns_present passes when slots exist", {
  df <- data.frame(BRANDAWARE_DSS_1 = "IPK", BRANDAWARE_DSS_2 = "ROB")
  expect_silent(guard_slot_columns_present(df, "BRANDAWARE_DSS"))
})

test_that("guard_slot_columns_present refuses when slots absent", {
  df <- data.frame(SOME_OTHER_COL = 1)
  expect_error(guard_slot_columns_present(df, "BRANDAWARE_DSS"),
               "DATA_SLOT_COLUMNS_MISSING")
})

test_that("guard_slot_columns_present respects min_slots", {
  df <- data.frame(BRANDAWARE_DSS_1 = "IPK")
  expect_silent(guard_slot_columns_present(df, "BRANDAWARE_DSS",
                                           min_slots = 1L))
  expect_error(guard_slot_columns_present(df, "BRANDAWARE_DSS",
                                          min_slots = 5L),
               "DATA_SLOT_COLUMNS_MISSING")
})


# ------------------------------------------------------------------------------
# guard_per_brand_column_present
# ------------------------------------------------------------------------------

test_that("guard_per_brand_column_present passes when column exists", {
  df <- data.frame(BRANDATT1_DSS_IPK = 1L)
  expect_silent(guard_per_brand_column_present(df, "BRANDATT1", "DSS", "IPK"))
})

test_that("guard_per_brand_column_present refuses on missing column", {
  df <- data.frame(BRANDATT1_DSS_IPK = 1L)
  expect_error(
    guard_per_brand_column_present(df, "BRANDATT1", "DSS", "MISSING"),
    "DATA_PER_BRAND_COLUMN_MISSING"
  )
})


# ------------------------------------------------------------------------------
# resolve_active_categories
# ------------------------------------------------------------------------------

test_that("resolve_active_categories classifies categories by data presence", {
  bc <- list(categories = data.frame(
    CategoryCode = c("DSS", "POS", "PAS", "BAK"),
    Active = c("Y", "Y", "Y", "N"),
    stringsAsFactors = FALSE
  ))

  # DSS = full data, POS = partial (just BRANDAWARE), PAS = no data,
  # BAK = inactive.
  df <- data.frame(
    BRANDAWARE_DSS_1 = "IPK", BRANDPEN1_DSS_1 = "IPK",
    BRANDPEN2_DSS_1 = "IPK", CATBUY_DSS = 1L,
    BRANDAWARE_POS_1 = "IPK"
  )

  res <- resolve_active_categories(df, bc)
  expect_equal(res$full, "DSS")
  expect_equal(res$partial, "POS")
  expect_equal(res$awaiting, "PAS")
  expect_equal(res$inactive, "BAK")
})

test_that("resolve_active_categories handles missing/empty config gracefully", {
  res <- resolve_active_categories(data.frame(), NULL)
  expect_equal(res$full, character(0))
  expect_equal(res$partial, character(0))
  expect_equal(res$awaiting, character(0))
  expect_equal(res$inactive, character(0))
})

test_that("resolve_active_categories defaults missing Active to Y", {
  bc <- list(categories = data.frame(
    CategoryCode = c("DSS"), stringsAsFactors = FALSE  # no Active column
  ))
  df <- data.frame(BRANDAWARE_DSS_1 = "IPK", BRANDPEN1_DSS_1 = "IPK",
                   BRANDPEN2_DSS_1 = "IPK", CATBUY_DSS = 1L)
  res <- resolve_active_categories(df, bc)
  expect_equal(res$full, "DSS")
  expect_length(res$inactive, 0L)
})


# ------------------------------------------------------------------------------
# Integration with the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("guards pass + categorisation correct on the IPK Wave 1 fixture", {
  data_path <- file.path("..", "..", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  bc_path <- file.path("..", "..", "tests", "fixtures",
                       "ipk_wave1", "Brand_Config.xlsx")
  skip_if_not(all(file.exists(c(data_path, bc_path))),
              "IPK Wave 1 fixture not built")

  data <- openxlsx::read.xlsx(data_path)
  cats <- openxlsx::read.xlsx(bc_path, sheet = "Categories")
  bc <- list(categories = cats)

  expect_silent(guard_alchemer_parser_shape(data))

  expect_silent(guard_slot_columns_present(data, "BRANDAWARE_DSS",
                                           min_slots = 16L))
  expect_silent(guard_per_brand_column_present(data, "BRANDATT1",
                                               "DSS", "IPK"))

  res <- resolve_active_categories(data, bc)
  # DSS has full deep-dive, POS/PAS/BAK are Active but partial (BRANDAWARE
  # only — no penetration data in fixture)
  expect_true("DSS" %in% res$full)
  expect_true(all(c("POS", "PAS", "BAK") %in% res$partial))
  # All 5 Adjacent categories are also Active and should be partial too
  # (only BRANDAWARE; no CATBUY/BRANDPEN1/2)
  expect_true(all(c("SLD", "STO", "PES", "COO", "ANT") %in% res$partial))
  expect_length(res$inactive, 0L)
})
