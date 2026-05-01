# ==============================================================================
# Tests for run_dba (DBA placeholder migration — Step 3h)
# ==============================================================================
# IPK Wave 1 has no DBA columns yet, so v2's primary contract is the
# placeholder path: when assets are absent or the per-asset Fame / Unique
# columns are missing from the data, return a structured PASS-empty payload
# the panel-data renderer can surface as "Data not yet collected for DBA".
#
# Also verifies the live path: when assets and data are both present, the
# v2 wrapper delegates to run_dba() unchanged — same shape, same numbers.
# ==============================================================================
library(testthat)

.find_root_dba <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_dba()

source(file.path(ROOT, "modules", "brand", "R", "07_dba.R"))


# ------------------------------------------------------------------------------
# Placeholder contract
# ------------------------------------------------------------------------------

test_that("run_dba returns PASS-empty when structure has no dba_assets sheet", {
  out <- run_dba(
    data        = data.frame(x = 1:5),
    structure   = list(),
    focal_brand = "IPK"
  )

  expect_equal(out$status, "PASS")
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$note, DBA_PLACEHOLDER_NOTE)
  expect_equal(nrow(out$dba_metrics), 0L)
  expect_equal(out$metrics_summary$focal_brand, "IPK")
  expect_equal(out$metrics_summary$n_assets, 0L)
})


test_that("run_dba returns PASS-empty when dba_assets sheet is empty", {
  empty_assets <- data.frame(
    AssetCode = character(0), AssetLabel = character(0),
    FameQuestionCode = character(0), UniqueQuestionCode = character(0),
    stringsAsFactors = FALSE
  )
  out <- run_dba(
    data        = data.frame(x = 1:5),
    structure   = list(dba_assets = empty_assets),
    focal_brand = "IPK"
  )
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$status, "PASS")
  expect_equal(out$note, DBA_PLACEHOLDER_NOTE)
})


test_that("run_dba returns PASS-empty when assets reference columns absent from data", {
  assets <- data.frame(
    AssetCode = "LOGO",
    AssetLabel = "Logo",
    FameQuestionCode = "DBA_FAME_LOGO",
    UniqueQuestionCode = "DBA_UNIQUE_LOGO",
    stringsAsFactors = FALSE
  )
  data <- data.frame(unrelated = 1:5)  # no DBA_FAME_LOGO / DBA_UNIQUE_LOGO

  out <- run_dba(data, structure = list(dba_assets = assets),
                    focal_brand = "IPK")
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$status, "PASS")
})


test_that("placeholder result shape matches live result shape", {
  placeholder <- run_dba(data = data.frame(x = 1:5),
                             structure = list(), focal_brand = "IPK")

  # Same top-level fields as a real run_dba() result so renderers don't break.
  expect_setequal(
    c("status", "dba_metrics", "metrics_summary", "n_respondents", "n_assets"),
    intersect(names(placeholder),
              c("status", "dba_metrics", "metrics_summary",
                "n_respondents", "n_assets"))
  )
  expect_setequal(
    names(placeholder$dba_metrics),
    c("AssetCode", "AssetLabel", "Fame_Pct", "Uniqueness_Pct",
      "Fame_n", "Uniqueness_n", "Quadrant")
  )
})


# ------------------------------------------------------------------------------
# Live path: hand-coded mini fixture, known-answer Fame / Uniqueness
# ------------------------------------------------------------------------------
# 4 respondents, one asset (LOGO) with focal brand IPK.
# DBA_FAME_LOGO codes: 1 = Yes seen, 2 = No, 3 = Not sure.
# Recognisers (1 or 3) -> r1, r2, r4. r3 said no.
# Among recognisers, attribution to IPK: r1=IPK, r2=ROB, r4=IPK -> 2 of 3.
# Hand-calc:
#   Fame % = 3/4 = 75.0
#   Uniqueness % = 2/3 = round(66.66..., 1) = 66.7
# Quadrant: high fame (>=0.5) + high uniqueness (>=0.5) = "Use or Lose".

test_that("run_dba reproduces hand-calculated Fame and Uniqueness", {
  data <- data.frame(
    DBA_FAME_LOGO   = c(1, 1, 2, 3),
    DBA_UNIQUE_LOGO = c("IPK", "ROB", NA, "IPK"),
    stringsAsFactors = FALSE
  )
  assets <- data.frame(
    AssetCode = "LOGO",
    AssetLabel = "Logo",
    FameQuestionCode = "DBA_FAME_LOGO",
    UniqueQuestionCode = "DBA_UNIQUE_LOGO",
    stringsAsFactors = FALSE
  )
  out <- run_dba(data, structure = list(dba_assets = assets),
                    focal_brand = "IPK", attribution_type = "open")

  expect_equal(out$status, "PASS")
  expect_null(out$placeholder)
  expect_equal(nrow(out$dba_metrics), 1L)
  expect_equal(out$dba_metrics$Fame_Pct[1],       75.0)
  expect_equal(out$dba_metrics$Uniqueness_Pct[1], 66.7)
  expect_equal(out$dba_metrics$Fame_n[1],         3L)
  expect_equal(out$dba_metrics$Uniqueness_n[1],   2L)
  expect_equal(out$dba_metrics$Quadrant[1],       "Use or Lose")
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture (placeholder expected)
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: run_dba returns the placeholder payload", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  ss_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                       "ipk_wave1", "Survey_Structure.xlsx")
  skip_if_not(all(file.exists(c(data_path, ss_path))),
              "IPK Wave 1 fixture not built")

  data <- openxlsx::read.xlsx(data_path)
  structure <- list()  # IPK Wave 1 has no DBA_Assets sheet

  out <- run_dba(data, structure, focal_brand = "IPK")
  expect_equal(out$status, "PASS")
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$note, DBA_PLACEHOLDER_NOTE)
})
