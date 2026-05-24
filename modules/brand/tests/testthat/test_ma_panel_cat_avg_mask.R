# ==============================================================================
# Regression: MA panel cat-avg masks silent-zero (no-data) brands.
# ==============================================================================
# Same bug class as the C1 fix in 14_summary_panel.R but on the MA tab:
# the MA engine returns 0 (not NA) for brands with no linkage data, so a
# naive mean(<col>) cat-avg drags the reference toward zero. After the
# 2026-05-24 fix, the masked cat-avg + CI bounds + CI bands all read off
# the active-brand subset.
# ==============================================================================

library(testthat)

.find_root_mam <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_mam()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "02_mental_availability.R"))
source(file.path(ROOT, "modules", "brand", "R", "02a_ma_panel_data.R"))


# Hand-built ma_result with three brands. AAA + BBB are real (have MA
# data); ZZZ is silent-zero (engine returned 0 across MPen / NS / MMS
# because no respondent linked it to any CEP).
mk_ma_result <- function() {
  list(
    n_respondents = 200L,
    n_ceps        = 7L,
    mpen = data.frame(
      BrandCode = c("AAA", "BBB", "ZZZ"),
      MPen      = c(0.50, 0.30, 0.0),
      stringsAsFactors = FALSE
    ),
    ns = data.frame(
      BrandCode = c("AAA", "BBB", "ZZZ"),
      NS        = c(4.0, 2.0, 0.0),
      NS_Base   = c(100L, 60L, 0L),
      stringsAsFactors = FALSE
    ),
    mms = data.frame(
      BrandCode   = c("AAA", "BBB", "ZZZ"),
      MMS         = c(0.40, 0.20, 0.0),
      Total_Links = c(400, 120, 0),
      stringsAsFactors = FALSE
    )
  )
}


test_that("MA cat-avg MPen excludes the silent-zero brand", {
  ma <- mk_ma_result()
  block <- .ma_build_metrics_block(
    ma, brand_codes = c("AAA","BBB","ZZZ"),
    brand_names = c("Alpha","Bravo","Charlie"),
    focal_code = "AAA"
  )
  # Hand-calc: mean(50%, 30%) = 40% (ZZZ excluded)
  expect_equal(block$cat_avg$mpen, 40.0)
})


test_that("MA cat-avg MMS excludes the silent-zero brand", {
  ma <- mk_ma_result()
  block <- .ma_build_metrics_block(
    ma, c("AAA","BBB","ZZZ"), c("Alpha","Bravo","Charlie"), "AAA"
  )
  # mean(40%, 20%) = 30%
  expect_equal(block$cat_avg$mms, 30.0)
})


test_that("MA cat-avg NS excludes the silent-zero brand", {
  ma <- mk_ma_result()
  block <- .ma_build_metrics_block(
    ma, c("AAA","BBB","ZZZ"), c("Alpha","Bravo","Charlie"), "AAA"
  )
  # mean(4.0, 2.0) = 3.0
  expect_equal(block$cat_avg$ns, 3.0)
})


test_that("MA cat-avg SOM excludes the silent-zero brand", {
  ma <- mk_ma_result()
  block <- .ma_build_metrics_block(
    ma, c("AAA","BBB","ZZZ"), c("Alpha","Bravo","Charlie"), "AAA"
  )
  # SOM_AAA = 40% / 50% × 100 = 80; SOM_BBB = 20% / 30% × 100 = 66.6667
  # ZZZ SOM is NA (mpen = 0). Masked mean = (80 + 66.67) / 2 ≈ 73.3
  expect_equal(block$cat_avg$som, 73.3, tolerance = 0.05)
})


test_that("MA CI bounds exclude the silent-zero brand", {
  ma <- mk_ma_result()
  block <- .ma_build_metrics_block(
    ma, c("AAA","BBB","ZZZ"), c("Alpha","Bravo","Charlie"), "AAA"
  )
  # Bounds reference the active subset (AAA, BBB), so neither bound
  # should be biased down by the included ZZZ zero. With only 2 active
  # brands and sd(c(50,30)) = ~14.14, SE ≈ 10.0, so bounds widen but
  # remain finite (not NA).
  expect_true(is.finite(block$cat_avg$mpen_ci_lo))
  expect_true(is.finite(block$cat_avg$mpen_ci_hi))
  # Centre should sit at the masked mean (40%), not the diluted mean of 26.6%
  expect_lt(abs((block$cat_avg$mpen_ci_lo + block$cat_avg$mpen_ci_hi) / 2 - 40), 1)
})


test_that("MA band classification tags the silent-zero brand as 'na', not 'below'", {
  ma <- mk_ma_result()
  block <- .ma_build_metrics_block(
    ma, c("AAA","BBB","ZZZ"), c("Alpha","Bravo","Charlie"), "AAA"
  )
  zzz_row <- block$table[[3]]  # block$table is the per-brand row list
  expect_identical(zzz_row$brand_code, "ZZZ")
  # Pre-fix: ZZZ at 0% on a category mean of ~27% would get "below".
  # Post-fix: ZZZ is masked from the reference distribution → "na".
  expect_identical(zzz_row$mpen_band, "na")
  expect_identical(zzz_row$mms_band,  "na")
  expect_identical(zzz_row$ns_band,   "na")
})


test_that("Active brand band still classifies correctly post-mask", {
  ma <- mk_ma_result()
  block <- .ma_build_metrics_block(
    ma, c("AAA","BBB","ZZZ"), c("Alpha","Bravo","Charlie"), "AAA"
  )
  # AAA at 50% vs masked mean of 40% — band membership depends on the
  # 2-brand SE which is wide. Assert it's NOT "na" (i.e. the masking
  # didn't accidentally drop AAA from the classification).
  aaa_row <- block$table[[1]]
  expect_identical(aaa_row$brand_code, "AAA")
  expect_true(aaa_row$mpen_band %in% c("above", "within", "below"))
})


test_that("All-zero category yields NA cat-avgs (no silent-zero centre)", {
  ma <- list(
    n_respondents = 100L, n_ceps = 5L,
    mpen = data.frame(BrandCode = c("X","Y"), MPen = c(0, 0),
                      stringsAsFactors = FALSE),
    ns   = data.frame(BrandCode = c("X","Y"), NS = c(0, 0), NS_Base = c(0L, 0L),
                      stringsAsFactors = FALSE),
    mms  = data.frame(BrandCode = c("X","Y"), MMS = c(0, 0), Total_Links = c(0,0),
                      stringsAsFactors = FALSE)
  )
  block <- .ma_build_metrics_block(
    ma, c("X","Y"), c("X","Y"), "X"
  )
  # Active set is empty — cat-avg must be NA, not a misleading 0.
  expect_true(is.na(block$cat_avg$mpen))
  expect_true(is.na(block$cat_avg$ns))
  expect_true(is.na(block$cat_avg$mms))
})
