# ==============================================================================
# Tests for run_branded_reach (Branded Reach placeholder migration — Step 3j)
# ==============================================================================
# IPK Wave 1 has no MarketingReach sheet, so v2's primary contract is the
# placeholder path: when assets are absent or empty, return a structured
# PASS-empty payload the panel-data renderer can surface as
# "Data not yet collected for Branded Reach".
#
# Also verifies the live path: when assets are present, the v2 wrapper
# delegates to run_branded_reach() (existing 9cat regression coverage stays
# in test_branded_reach.R — this file only verifies wrapper plumbing).
# ==============================================================================
library(testthat)

.find_root_br <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_br()

source(file.path(ROOT, "modules", "brand", "R", "10_branded_reach.R"))
source(file.path(ROOT, "modules", "brand", "R", "10a_br_panel_data.R"))
source(file.path(ROOT, "modules", "brand", "R", "10b_br_misattribution.R"))
source(file.path(ROOT, "modules", "brand", "R", "10c_br_media_mix.R"))


# ------------------------------------------------------------------------------
# Placeholder contract
# ------------------------------------------------------------------------------

test_that("run_branded_reach returns PASS-empty when structure has no MarketingReach", {
  data <- data.frame(x = 1:10)
  brands <- data.frame(BrandCode = c("IPK", "ROB"),
                        BrandLabel = c("IPK", "ROB"),
                        stringsAsFactors = FALSE)
  out <- run_branded_reach(
    data        = data,
    structure   = list(),
    brand_list  = brands,
    cat_code    = "DSS",
    focal_brand = "IPK"
  )

  expect_equal(out$status, "PASS")
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$meta$note, BR_PLACEHOLDER_NOTE)
  expect_equal(length(out$ads), 0L)
  expect_equal(length(out$misattribution), 0L)
  expect_equal(length(out$media_mix), 0L)
  expect_equal(out$meta$n_respondents, 10L)
  expect_equal(out$meta$cat_code, "DSS")
  expect_equal(out$meta$focal_brand, "IPK")
  expect_false(out$meta$weighted)
})


test_that("run_branded_reach returns PASS-empty when MarketingReach sheet is empty", {
  empty_assets <- data.frame(
    AssetCode = character(0), Brand = character(0),
    Category = character(0),
    SeenQuestionCode = character(0), BrandQuestionCode = character(0),
    MediaQuestionCode = character(0),
    stringsAsFactors = FALSE
  )
  out <- run_branded_reach(
    data       = data.frame(x = 1:5),
    structure  = list(marketing_reach = empty_assets),
    brand_list = NULL,
    cat_code   = "DSS",
    focal_brand = "IPK"
  )
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$status, "PASS")
  expect_equal(out$meta$note, BR_PLACEHOLDER_NOTE)
})


test_that("placeholder result shape matches live result shape", {
  out <- run_branded_reach(
    data = data.frame(x = 1:5), structure = list(),
    brand_list = NULL, cat_code = "DSS", focal_brand = "IPK"
  )
  # Top-level fields the panel renderer reads.
  expect_setequal(
    intersect(names(out),
              c("status", "ads", "misattribution", "media_mix", "meta")),
    c("status", "ads", "misattribution", "media_mix", "meta")
  )
  expect_setequal(
    intersect(names(out$meta),
              c("n_respondents", "n_assets", "cat_code", "focal_brand",
                "weighted", "note")),
    c("n_respondents", "n_assets", "cat_code", "focal_brand",
      "weighted", "note")
  )
})


test_that("placeholder weighted flag reflects whether weights were supplied", {
  out_unweighted <- run_branded_reach(
    data = data.frame(x = 1:3), structure = list(),
    brand_list = NULL, focal_brand = "IPK"
  )
  expect_false(out_unweighted$meta$weighted)

  out_weighted <- run_branded_reach(
    data = data.frame(x = 1:3), structure = list(),
    brand_list = NULL, focal_brand = "IPK",
    weights = c(1, 1, 1)
  )
  expect_true(out_weighted$meta$weighted)
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture (placeholder expected)
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: run_branded_reach returns the placeholder payload", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  skip_if_not(file.exists(data_path), "IPK Wave 1 fixture not built")

  data <- openxlsx::read.xlsx(data_path)
  out <- run_branded_reach(data, structure = list(),
                               brand_list = NULL,
                               cat_code = "DSS",
                               focal_brand = "IPK")
  expect_equal(out$status, "PASS")
  expect_true(isTRUE(out$placeholder))
  expect_equal(out$meta$note, BR_PLACEHOLDER_NOTE)
  expect_equal(out$meta$n_respondents, nrow(data))
})
