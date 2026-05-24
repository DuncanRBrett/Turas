# ==============================================================================
# Regression tests for the Summary panel cat-avg silent-zero masks (C1).
# ==============================================================================
# The MA / repertoire / WOM engines return 0 (not NA) for brands without data.
# A naive mean() over those columns silently dilutes every cat-avg toward
# zero — the same bug class that caused the May 2026 WOM cat-avg incident
# (fix 3633238b, on the panel-data layer for WOM only). The Summary panel
# .brsum_brand_snapshot() builds 5- and 4-chip cat-avg strips and must apply
# matching masks so the Summary card and the deep-dive tabs agree on the
# same metric.
#
# Each test constructs a tiny three-brand cat_result:
#   AAA — full data
#   BBB — full data
#   ZZZ — all-zero across MA, WOM, repertoire (the "no data collected" brand)
# and asserts that ZZZ is excluded from every cat-avg.
# ==============================================================================

library(testthat)

.find_root_csavg <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_csavg()

source(file.path(ROOT, "modules", "brand", "lib", "html_report", "panels",
                 "14_summary_panel.R"))


# Helper — build a category_result containing the three-brand fixture.
mk_silent_zero_cr <- function() {
  # MA: AAA + BBB have real values; ZZZ is all-zero.
  ma_mms <- data.frame(
    BrandCode = c("AAA", "BBB", "ZZZ"),
    MMS = c(0.40, 0.20, 0.0),
    stringsAsFactors = FALSE
  )
  ma_mpen <- data.frame(
    BrandCode = c("AAA", "BBB", "ZZZ"),
    MPen = c(0.50, 0.30, 0.0),
    stringsAsFactors = FALSE
  )
  ma_ns <- data.frame(
    BrandCode = c("AAA", "BBB", "ZZZ"),
    NS = c(4.0, 2.0, 0.0),
    NS_Base = c(100L, 80L, 0L),
    stringsAsFactors = FALSE
  )

  # Repertoire: ZZZ has 0 buyers; AAA & BBB have real data.
  brp <- data.frame(
    BrandCode = c("AAA", "BBB", "ZZZ"),
    Brand_Buyers_n = c(60L, 40L, 0L),
    Sole_Pct = c(30, 10, 0),  # ZZZ silently 0
    stringsAsFactors = FALSE
  )

  # WOM: ZZZ all-zero on every column.
  wm_metrics <- data.frame(
    BrandCode = c("AAA", "BBB", "ZZZ"),
    ReceivedPos_Pct = c(40, 20, 0),
    ReceivedNeg_Pct = c(5, 10, 0),
    SharedPos_Pct   = c(15,  5, 0),
    SharedNeg_Pct   = c(2,   3, 0),
    SharedPosFreq_Mean = c(2.1, 1.4, 0),
    SharedNegFreq_Mean = c(1.2, 0.8, 0),
    stringsAsFactors = FALSE
  )
  net_balance <- data.frame(
    BrandCode = c("AAA", "BBB", "ZZZ"),
    Net_Received = c(35, 10, 0),
    Net_Shared   = c(13,  2, 0),
    stringsAsFactors = FALSE
  )

  # Funnel: minimal — one bought_target row per brand (engine NAs missing
  # rows, but we leave all three present + finite so the mask doesn't kick in
  # for funnel; cat-avg = 20%).
  stages <- data.frame(
    brand_code = c("AAA", "BBB", "ZZZ"),
    stage_key = "bought_target",
    pct_weighted = c(0.30, 0.20, 0.10),
    base_weighted = c(100, 100, 100),
    base_unweighted = c(100, 100, 100),
    warning_flag = "none",
    stringsAsFactors = FALSE
  )

  list(
    mental_availability = list(mms = ma_mms, mpen = ma_mpen, ns = ma_ns),
    repertoire = list(brand_repertoire_profile = brp),
    wom = list(wom_metrics = wm_metrics, net_balance = net_balance),
    funnel = list(stages = stages,
                  meta = list(n_unweighted = 300L))
  )
}


test_that("MMS cat-avg excludes silent-zero (no-data) brand", {
  cr <- mk_silent_zero_cr()
  snap <- .brsum_brand_snapshot(
    brand_code = "AAA", cr = cr, label_map = list(),
    brand_colours = list(), focal_colour = "#000")
  # AAA's MMS card: cat_avg = mean(0.40, 0.20) * 100 = 30 → renders "30%".
  mms_chip <- Filter(function(x) identical(x$label, "MMS"), snap$focal_metrics)[[1]]
  expect_identical(mms_chip$cat_avg, "30%")
})


test_that("MPen cat-avg excludes silent-zero brand", {
  cr <- mk_silent_zero_cr()
  snap <- .brsum_brand_snapshot("AAA", cr, list(), list(), "#000")
  mpen_chip <- Filter(function(x) identical(x$label, "MPen"), snap$focal_metrics)[[1]]
  # mean(0.50, 0.30) * 100 = 40
  expect_identical(mpen_chip$cat_avg, "40%")
})


test_that("NS cat-avg in the MA strip excludes silent-zero brand", {
  cr <- mk_silent_zero_cr()
  snap <- .brsum_brand_snapshot("AAA", cr, list(), list(), "#000")
  ns_chip <- Filter(function(x) identical(x$key, "ns"), snap$ma_metrics)[[1]]
  # mean(4.0, 2.0) = 3.0 → "3.00" via .brsum_num(digits = 2)
  expect_identical(ns_chip$cat_avg, "3.00")
})


test_that("SOM cat-avg in the MA strip excludes silent-zero brand", {
  cr <- mk_silent_zero_cr()
  snap <- .brsum_brand_snapshot("AAA", cr, list(), list(), "#000")
  som_chip <- Filter(function(x) identical(x$key, "som"), snap$ma_metrics)[[1]]
  # SOM_AAA = 0.40 / 0.50 * 100 = 80; SOM_BBB = 0.20 / 0.30 * 100 ≈ 66.67;
  # cat-avg = mean(80, 66.67) ≈ 73 → "73%"
  expect_identical(som_chip$cat_avg, "73%")
})


test_that("Loyalty (Sole_Pct) cat-avg excludes brands with zero buyers", {
  cr <- mk_silent_zero_cr()
  snap <- .brsum_brand_snapshot("AAA", cr, list(), list(), "#000")
  loy_chip <- Filter(function(x) identical(x$label, "Loyalty (Sole)"),
                     snap$focal_metrics)[[1]]
  # mean(30, 10) = 20 → "20%"
  expect_identical(loy_chip$cat_avg, "20%")
})


test_that("Net WOM cat-avg excludes silent-zero brand", {
  cr <- mk_silent_zero_cr()
  snap <- .brsum_brand_snapshot("AAA", cr, list(), list(), "#000")
  wom_chip <- Filter(function(x) identical(x$label, "Net WOM"),
                     snap$focal_metrics)[[1]]
  # mean(35, 10) = 22.5 → "+22" (.brsum_signed rounds to integer)
  expect_identical(wom_chip$cat_avg, "+22")
})


test_that("Summary Net WOM cat-avg matches the WOM card's Net heard cat-avg", {
  # The reason this test exists: the two values appear on the same page;
  # they MUST be the same number. Pre-fix they diverged because the 5-chip
  # strip used unfiltered mean() while the WOM card filtered by wom_active.
  cr <- mk_silent_zero_cr()
  snap <- .brsum_brand_snapshot("AAA", cr, list(), list(), "#000")
  net_wom <- Filter(function(x) identical(x$label, "Net WOM"),
                    snap$focal_metrics)[[1]]
  # Note: the WOM card formats Net heard via .brsum_signed too, so identical
  # string equality is the right contract.
  expect_identical(net_wom$cat_avg, snap$wom$heard$net$cat_avg)
})


test_that("Headline sentence MMS comparison uses the masked cat-avg", {
  cr <- mk_silent_zero_cr()
  # Pre-fix the headline used the unfiltered mean(0.40, 0.20, 0.0) = 0.20,
  # so AAA (0.40) sat at "+20pp above cat avg of 20%". Post-fix the cat
  # avg is mean(0.40, 0.20) = 0.30, so AAA is "above category average of
  # 30%". Assert the post-fix value appears in the headline.
  snap <- .brsum_brand_snapshot("AAA", cr, list(),
                                 list(AAA = "#A00", BBB = "#0A0", ZZZ = "#00A"),
                                 "#000", cat_name = "TestCat")
  expect_match(snap$headline,
               "category average of 30%",
               fixed = TRUE,
               info = "headline should compare AAA's MMS to the masked cat avg, not the silent-zero-diluted mean")
})


test_that("All-zero category yields NA cat-avgs (no division-by-empty)", {
  # Edge case: every brand has no data. Mask is empty. Expect NA-rendered
  # ("—") rather than NaN or a spurious 0.
  cr <- mk_silent_zero_cr()
  # Wipe AAA + BBB to all-zero so only the "active" set is empty.
  cr$mental_availability$mms$MMS  <- c(0, 0, 0)
  cr$mental_availability$mpen$MPen <- c(0, 0, 0)
  cr$mental_availability$ns$NS    <- c(0, 0, 0)
  cr$repertoire$brand_repertoire_profile$Brand_Buyers_n <- c(0L, 0L, 0L)
  cr$repertoire$brand_repertoire_profile$Sole_Pct <- c(0, 0, 0)
  cr$wom$wom_metrics$ReceivedPos_Pct <- c(0, 0, 0)
  cr$wom$wom_metrics$ReceivedNeg_Pct <- c(0, 0, 0)
  cr$wom$wom_metrics$SharedPos_Pct   <- c(0, 0, 0)
  cr$wom$wom_metrics$SharedNeg_Pct   <- c(0, 0, 0)
  cr$wom$net_balance$Net_Received    <- c(0, 0, 0)

  snap <- .brsum_brand_snapshot("AAA", cr, list(), list(), "#000")
  mms_chip <- Filter(function(x) identical(x$label, "MMS"), snap$focal_metrics)[[1]]
  loy_chip <- Filter(function(x) identical(x$label, "Loyalty (Sole)"),
                     snap$focal_metrics)[[1]]
  wom_chip <- Filter(function(x) identical(x$label, "Net WOM"),
                     snap$focal_metrics)[[1]]
  expect_identical(mms_chip$cat_avg, "—")
  expect_identical(loy_chip$cat_avg, "—")
  expect_identical(wom_chip$cat_avg, "—")
})
