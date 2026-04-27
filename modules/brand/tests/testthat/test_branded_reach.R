# ==============================================================================
# Tests for run_branded_reach()
# ==============================================================================
# A small hand-constructed dataset so the expected numbers are verifiable
# on paper. Single ad ADTV01 with focal brand IPK; 6 respondents:
#   r1: seen=Y attributed=IPK   media=TV,SOCIAL
#   r2: seen=Y attributed=IPK   media=TV
#   r3: seen=Y attributed=KNORR media=SOCIAL
#   r4: seen=Y attributed=DK    media=TV
#   r5: seen=N
#   r6: seen=N
#
# Expected:
#   reach          = 4 / 6 = 0.6667
#   correct        = 2 / 6 = 0.3333
#   branding %     = 2 / 4 = 0.5
#   misattribution: IPK 2/4=50%, KNORR 1/4=25%, DK 1/4=25%, others 0%
#   media TV       = 3 / 4 = 75%   SOCIAL = 2 / 4 = 50%
# ==============================================================================

source("../../R/10a_br_panel_data.R", chdir = FALSE)
source("../../R/10b_br_misattribution.R", chdir = FALSE)
source("../../R/10c_br_media_mix.R", chdir = FALSE)
source("../../R/10d_br_output.R", chdir = FALSE)
source("../../R/10_branded_reach.R", chdir = FALSE)


build_br_fixture <- function() {
  data <- data.frame(
    REACH_SEEN_ADTV01  = c(1L, 1L, 1L, 1L, 2L, 2L),
    REACH_BRAND_ADTV01 = c("IPK", "IPK", "KNORR", "DK", NA, NA),
    REACH_MEDIA_ADTV01 = c("TV,SOCIAL", "TV", "SOCIAL", "TV", NA, NA),
    stringsAsFactors = FALSE
  )
  asset_list <- data.frame(
    AssetCode         = "ADTV01",
    AssetLabel        = "TV ad",
    Brand             = "IPK",
    Category          = "ALL",
    ImagePath         = "assets/reach/ipk_tv_ad_01.jpg",
    SeenQuestionCode  = "REACH_SEEN_ADTV01",
    BrandQuestionCode = "REACH_BRAND_ADTV01",
    MediaQuestionCode = "REACH_MEDIA_ADTV01",
    stringsAsFactors  = FALSE
  )
  brand_list <- data.frame(
    BrandCode  = c("IPK", "KNORR", "ROB"),
    BrandLabel = c("Ina Paarman", "Knorr", "Robertsons"),
    stringsAsFactors = FALSE
  )
  media_list <- data.frame(
    MediaCode    = c("TV", "SOCIAL", "ONLINE"),
    MediaLabel   = c("Television", "Social media", "Online"),
    DisplayOrder = 1:3,
    stringsAsFactors = FALSE
  )
  list(data = data, asset_list = asset_list, brand_list = brand_list,
       media_list = media_list)
}


test_that("run_branded_reach computes hand-verified reach metrics", {
  fx <- build_br_fixture()
  res <- run_branded_reach(
    data = fx$data, asset_list = fx$asset_list,
    brand_list = fx$brand_list, media_list = fx$media_list,
    focal_brand = "IPK"
  )
  expect_equal(res$status, "PASS")
  expect_length(res$ads, 1L)
  ad <- res$ads[[1]]
  expect_equal(ad$asset_code, "ADTV01")
  expect_equal(ad$correct_brand, "IPK")
  expect_equal(ad$image_path, "assets/reach/ipk_tv_ad_01.jpg")
  expect_equal(ad$n_eligible, 6)
  expect_equal(ad$n_seen, 4)
  expect_equal(ad$n_correct, 2)
  expect_equal(round(ad$reach_pct, 4),         round(4/6, 4))
  expect_equal(round(ad$branded_reach_pct, 4), round(2/6, 4))
  expect_equal(ad$branding_pct,                0.5)
})


test_that("run_branded_reach builds a misattribution table with focal flagged", {
  fx <- build_br_fixture()
  res <- run_branded_reach(
    data = fx$data, asset_list = fx$asset_list,
    brand_list = fx$brand_list, media_list = fx$media_list,
    focal_brand = "IPK"
  )
  tbl <- res$misattribution[["ADTV01"]]
  expect_true(is.data.frame(tbl))
  expect_setequal(tbl$BrandCode, c("IPK", "KNORR", "ROB", "DK", "OTHER"))

  ipk <- tbl[tbl$BrandCode == "IPK", ]
  expect_true(ipk$is_correct)
  expect_equal(ipk$n, 2)
  expect_equal(ipk$pct_of_seen, 0.5)

  knorr <- tbl[tbl$BrandCode == "KNORR", ]
  expect_false(knorr$is_correct)
  expect_equal(knorr$n, 1)
  expect_equal(knorr$pct_of_seen, 0.25)

  rob <- tbl[tbl$BrandCode == "ROB", ]
  expect_equal(rob$n, 0)

  dk <- tbl[tbl$BrandCode == "DK", ]
  expect_equal(dk$n, 1)
  expect_equal(dk$pct_of_seen, 0.25)
})


test_that("run_branded_reach builds a media mix table", {
  fx <- build_br_fixture()
  res <- run_branded_reach(
    data = fx$data, asset_list = fx$asset_list,
    brand_list = fx$brand_list, media_list = fx$media_list,
    focal_brand = "IPK"
  )
  tbl <- res$media_mix[["ADTV01"]]
  expect_true(is.data.frame(tbl))
  tv     <- tbl[tbl$MediaCode == "TV", ]
  social <- tbl[tbl$MediaCode == "SOCIAL", ]
  online <- tbl[tbl$MediaCode == "ONLINE", ]
  expect_equal(tv$n, 3)
  expect_equal(round(tv$pct_of_seen, 4), 0.75)
  expect_equal(social$n, 2)
  expect_equal(round(social$pct_of_seen, 4), 0.5)
  expect_equal(online$n, 0)
  expect_equal(online$pct_of_seen, 0)
})


test_that("run_branded_reach respects category filtering on cat_code", {
  fx <- build_br_fixture()
  fx$asset_list$Category <- "DSS"
  # cat_code = POS — the asset is for DSS, so no ads run
  res <- run_branded_reach(
    data = fx$data, asset_list = fx$asset_list,
    brand_list = fx$brand_list, media_list = fx$media_list,
    cat_code = "POS", focal_brand = "IPK"
  )
  expect_equal(res$status, "PASS")
  expect_length(res$ads, 0L)
  expect_length(res$misattribution, 0L)
})


test_that("run_branded_reach returns PASS with empty ads when asset_list is missing", {
  fx <- build_br_fixture()
  res <- run_branded_reach(
    data = fx$data, asset_list = NULL,
    brand_list = fx$brand_list, media_list = fx$media_list,
    focal_brand = "IPK"
  )
  expect_equal(res$status, "PASS")
  expect_length(res$ads, 0L)
})


test_that("run_branded_reach refuses on empty data", {
  fx <- build_br_fixture()
  res <- run_branded_reach(
    data = fx$data[0, ], asset_list = fx$asset_list,
    brand_list = fx$brand_list, media_list = fx$media_list,
    focal_brand = "IPK"
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "DATA_MISSING")
})


test_that("build_branded_reach_panel_data shapes the engine output for the renderer", {
  fx <- build_br_fixture()
  res <- run_branded_reach(
    data = fx$data, asset_list = fx$asset_list,
    brand_list = fx$brand_list, media_list = fx$media_list,
    focal_brand = "IPK"
  )
  pd <- build_branded_reach_panel_data(
    res, category_label = "Spices", focal_brand = "IPK",
    focal_colour = "#1A5276", decimal_places = 0L
  )
  expect_equal(pd$meta$status, "PASS")
  expect_equal(pd$meta$category_label, "Spices")
  expect_equal(pd$meta$focal_brand, "IPK")
  expect_length(pd$ads, 1L)
  expect_true(!is.null(pd$misattribution[["ADTV01"]]))
  expect_true(!is.null(pd$media_mix[["ADTV01"]]))
})
