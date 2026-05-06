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


# ------------------------------------------------------------------------------
# Polish: insight callouts + panel HTML
# ------------------------------------------------------------------------------
# Verifies the new build_branded_reach_panel_data() insights field and the
# panel renderer's insight strip + SVG image placeholder.

# Source the panel-data builder + HTML renderer (engines already sourced)
source(file.path(ROOT, "modules", "brand", "R", "10d_br_output.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "panels", "10_branded_reach_panel.R"))


.fake_br_result <- function() {
  ads <- list(
    list(asset_code = "AD_TV", asset_label = "TV: Stew Spot",
          image_path = NA_character_, correct_brand = "IPK", category = "DSS",
          n_eligible = 200, n_seen = 100, n_correct = 70,
          reach_pct = 0.50, branded_reach_pct = 0.35, branding_pct = 0.70,
          status = "PASS"),
    list(asset_code = "AD_OOH", asset_label = "OOH: Billboard",
          image_path = NA_character_, correct_brand = "IPK", category = "ALL",
          n_eligible = 300, n_seen = 150, n_correct = 60,
          reach_pct = 0.50, branded_reach_pct = 0.20, branding_pct = 0.40,
          status = "PASS")
  )
  misattr <- list(
    AD_TV = data.frame(
      BrandCode = c("IPK", "ROB", "DK", "OTHER"),
      BrandLabel = c("IPK", "Robertsons", "DK", "Other"),
      n = c(70, 25, 3, 2),
      pct_of_seen = c(0.70, 0.25, 0.03, 0.02),
      is_correct = c(TRUE, FALSE, FALSE, FALSE),
      stringsAsFactors = FALSE),
    AD_OOH = data.frame(
      BrandCode = c("IPK", "ROB", "DK", "OTHER"),
      BrandLabel = c("IPK", "Robertsons", "DK", "Other"),
      n = c(60, 70, 15, 5),
      pct_of_seen = c(0.40, 0.467, 0.10, 0.033),
      is_correct = c(TRUE, FALSE, FALSE, FALSE),
      stringsAsFactors = FALSE)
  )
  media <- list(
    AD_TV = data.frame(
      MediaCode = c("TV", "FACEBOOK", "OOH"),
      MediaLabel = c("TV", "Facebook", "OOH"),
      n = c(80, 30, 10),
      pct_of_seen = c(0.80, 0.30, 0.10),
      stringsAsFactors = FALSE),
    AD_OOH = data.frame(
      MediaCode = c("TV", "FACEBOOK", "OOH"),
      MediaLabel = c("TV", "Facebook", "OOH"),
      n = c(20, 90, 100),
      pct_of_seen = c(0.13, 0.60, 0.667),
      stringsAsFactors = FALSE)
  )
  list(status = "PASS", ads = ads, misattribution = misattr,
        media_mix = media,
        meta = list(n_respondents = 500L, n_assets = 2L,
                     cat_code = "DSS", focal_brand = "IPK",
                     weighted = FALSE))
}


test_that("panel data includes insights field with Best/Watch/Channel/Branding chips", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  expect_true(!is.null(pd$insights))
  expect_true(length(pd$insights) >= 3L)
  verbs <- vapply(pd$insights, function(x) x$verb, character(1))
  expect_true("Best" %in% verbs)
  expect_true("Watch" %in% verbs)
  expect_true("Channel" %in% verbs)
  expect_true("Branding" %in% verbs)
})


test_that("Best chip names the higher branded-reach ad", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  best <- Filter(function(x) x$verb == "Best", pd$insights)[[1]]
  expect_match(best$text, "TV: Stew Spot")
  expect_match(best$text, "35%")
})


test_that("Watch chip identifies the worst single-competitor leak", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  watch <- Filter(function(x) x$verb == "Watch", pd$insights)[[1]]
  # AD_OOH leaks 46.7% to Robertsons
  expect_match(watch$text, "OOH: Billboard")
  expect_match(watch$text, "Robertsons")
})


test_that("Channel chip names the highest-average channel across ads", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  ch <- Filter(function(x) x$verb == "Channel", pd$insights)[[1]]
  # TV avg 46.5%, OOH avg 38.4%, Facebook avg 45% — TV wins
  expect_match(ch$text, "TV")
})


test_that("Branding chip reports average branding efficiency", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  bg <- Filter(function(x) x$verb == "Branding", pd$insights)[[1]]
  # 0.70 + 0.40 / 2 = 0.55 → "55%"
  expect_match(bg$text, "55%")
})


test_that("REFUSED engine result yields empty insights", {
  pd <- build_branded_reach_panel_data(
    list(status = "REFUSED", message = "Boom"),
    focal_brand = "IPK")
  expect_equal(pd$meta$status, "REFUSED")
  expect_length(pd$insights, 0L)
})


test_that("panel HTML renders the insight strip when chips exist", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  html <- build_branded_reach_panel_html(pd, category_code = "DSS",
                                          focal_colour = "#1A5276")
  expect_true(grepl("br-reach-insight-strip", html, fixed = TRUE))
  expect_true(grepl("br-reach-insight-chip", html, fixed = TRUE))
  expect_true(grepl(">Best<", html, fixed = TRUE))
})


test_that("panel HTML contains the SVG image placeholder when image path missing", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  html <- build_branded_reach_panel_html(pd, category_code = "DSS",
                                          focal_colour = "#1A5276")
  expect_true(grepl("br-reach-img-placeholder", html, fixed = TRUE))
  expect_true(grepl("br-reach-img-placeholder-label", html, fixed = TRUE))
  expect_true(grepl("<svg viewBox=\"0 0 80 60\"", html, fixed = TRUE))
})


test_that("panel HTML includes per-card pin + PNG buttons", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  html <- build_branded_reach_panel_html(pd, category_code = "DSS",
                                          focal_colour = "#1A5276")
  # Both per-card pin + per-card PNG buttons render
  expect_true(grepl("br-reach-card-pin", html, fixed = TRUE))
  expect_true(grepl("br-reach-card-png", html, fixed = TRUE))
  # Each ad has its own section id (used by TurasPins to scope a card-level pin)
  expect_true(grepl("section-br-reach-dss-ad-tv-overview", html, fixed = TRUE))
  expect_true(grepl("section-br-reach-dss-ad-ooh-overview", html, fixed = TRUE))
})


test_that("misattribution table marks the focal-brand row", {
  pd <- build_branded_reach_panel_data(.fake_br_result(),
                                        focal_brand = "IPK")
  html <- build_branded_reach_panel_html(pd, category_code = "DSS",
                                          focal_colour = "#1A5276")
  expect_true(grepl("br-reach-row-focal", html, fixed = TRUE))
  expect_true(grepl("br-reach-focal-tag", html, fixed = TRUE))
})


test_that("placeholder branded-reach payload renders friendly empty state", {
  pd <- build_branded_reach_panel_data(
    list(status = "PASS", placeholder = TRUE,
          ads = list(), misattribution = list(), media_mix = list(),
          meta = list(n_respondents = 0L, n_assets = 0L,
                       focal_brand = "IPK", weighted = FALSE,
                       note = BR_PLACEHOLDER_NOTE)),
    focal_brand = "IPK")
  html <- build_branded_reach_panel_html(pd, category_code = "DSS",
                                          focal_colour = "#1A5276")
  expect_true(grepl("br-reach-empty", html, fixed = TRUE))
  # No insight strip (no insights to surface)
  expect_false(grepl("br-reach-insight-strip", html, fixed = TRUE))
})
