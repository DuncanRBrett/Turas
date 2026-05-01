# ==============================================================================
# Tests for build_portfolio_base (Portfolio screener-qualifier migration)
# ==============================================================================
# First step of §9 step 3i. Migrates the central denominator helper
# (build_portfolio_base) to slot-indexed SQ1 / SQ2 columns. Per the spec
# (§3.1 of PORTFOLIO_SPEC_v1) build_portfolio_base is the single source
# of truth for the screener-qualifier filter — all sub-analyses
# (footprint, constellation, clutter, strength, extension) call it.
#
# The remaining sub-analyses (09a..09e) still use legacy
# BRANDAWARE_{cat}_{brand} column-per-brand reads and are not yet
# migrated. They are scheduled for a follow-up commit.
# ==============================================================================
library(testthat)

.find_root_pf <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_pf()

source(file.path(ROOT, "modules", "brand", "R", "00_guard.R"))
source(file.path(ROOT, "modules", "brand", "R", "00_data_access.R"))
source(file.path(ROOT, "modules", "brand", "R", "09_portfolio.R"))


# ------------------------------------------------------------------------------
# Hand-coded mini-fixture: 6 respondents, slot-indexed SQ1 + SQ2
# ------------------------------------------------------------------------------
# SQ1 (long window): r1=DSS,POS  r2=DSS  r3=POS  r4=PAS  r5=DSS  r6=BAK,DSS
# SQ2 (target window): r1=DSS  r2=DSS  r3=NONE r4=PAS  r5=NONE r6=DSS
#
# DSS qualifiers @ 3m: r1, r2, r6 -> 3
# DSS qualifiers @ 13m: r1, r2, r5, r6 -> 4
# POS qualifiers @ 3m (no SQ2 hit): falls back to SQ1 if SQ2 missing — but
#   SQ2 columns DO exist in this fixture so 3m-no-fallback returns 0 SQ2
#   matches for POS. Hand check: r1 SQ2=DSS, none = POS, so 0.
# ------------------------------------------------------------------------------

mk_pf_mini_data <- function() {
  data.frame(
    SQ1_1 = c("DSS", "DSS", "POS", "PAS", "DSS", "BAK"),
    SQ1_2 = c("POS", NA,    NA,    NA,    NA,    "DSS"),

    SQ2_1 = c("DSS", "DSS", "NONE","PAS", "NONE","DSS"),
    SQ2_2 = c(NA,    NA,    NA,    NA,    NA,    NA),

    stringsAsFactors = FALSE
  )
}


test_that("build_portfolio_base: DSS @ 3m hits SQ2 slots", {
  data <- mk_pf_mini_data()
  out <- build_portfolio_base(data, "DSS", timeframe = "3m")
  expect_equal(out$col_used, "SQ2")
  expect_equal(out$idx, c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE))
  expect_equal(out$n_uw, 3L)
  expect_equal(out$n_w, 3)
})


test_that("build_portfolio_base: DSS @ 13m reads SQ1 slots", {
  data <- mk_pf_mini_data()
  out <- build_portfolio_base(data, "DSS", timeframe = "13m")
  expect_equal(out$col_used, "SQ1")
  expect_equal(out$idx, c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE))
  expect_equal(out$n_uw, 4L)
})


test_that("build_portfolio_base: weighted base sums correctly", {
  data <- mk_pf_mini_data()
  w <- c(2, 1, 1, 1, 1, 3)  # r1*2, r6*3 weighted
  out <- build_portfolio_base(data, "DSS", timeframe = "3m", weights = w)
  # DSS @ 3m hits r1, r2, r6 -> w = 2 + 1 + 3 = 6
  expect_equal(out$n_w, 6)
})


test_that("build_portfolio_base: SQ2 absent + 3m falls back to SQ1", {
  data <- mk_pf_mini_data()
  data$SQ2_1 <- NULL
  data$SQ2_2 <- NULL
  out <- build_portfolio_base(data, "DSS", timeframe = "3m")
  expect_equal(out$col_used, "SQ1")
  expect_equal(out$n_uw, 4L)
})


test_that("build_portfolio_base: refuses with structured shape on bad input", {
  out_empty <- build_portfolio_base(data.frame(), "DSS", timeframe = "3m")
  expect_equal(out_empty$status, "REFUSED")
  expect_equal(out_empty$code, "DATA_PORTFOLIO_NOT_DATA_FRAME")

  out_no_cat <- build_portfolio_base(mk_pf_mini_data(), "",
                                         timeframe = "3m")
  expect_equal(out_no_cat$status, "REFUSED")
  expect_equal(out_no_cat$code, "DATA_PORTFOLIO_MISSING_CAT_CODE")

  out_no_cols <- build_portfolio_base(
    data.frame(other = 1:3, stringsAsFactors = FALSE),
    "DSS", timeframe = "3m")
  expect_equal(out_no_cols$status, "REFUSED")
})


# ------------------------------------------------------------------------------
# Integration: against the IPK Wave 1 fixture
# ------------------------------------------------------------------------------

test_that("IPK Wave 1: build_portfolio_base resolves DSS qualifiers", {
  data_path <- file.path(ROOT, "modules", "brand", "tests", "fixtures",
                         "ipk_wave1", "ipk_wave1_data.xlsx")
  skip_if_not(file.exists(data_path), "IPK Wave 1 fixture not built")
  data <- openxlsx::read.xlsx(data_path)

  out_3m <- build_portfolio_base(data, "DSS", timeframe = "3m")
  expect_null(out_3m$status)  # PASS path returns no $status
  expect_equal(out_3m$col_used, "SQ2")
  expect_gt(out_3m$n_uw, 0L)
  expect_lte(out_3m$n_uw, nrow(data))

  out_13m <- build_portfolio_base(data, "DSS", timeframe = "13m")
  expect_equal(out_13m$col_used, "SQ1")
  # 13m window must include the 3m respondents (subset relationship).
  expect_gte(out_13m$n_uw, out_3m$n_uw)
})
