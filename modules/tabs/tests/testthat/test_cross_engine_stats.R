# ==============================================================================
# TABS MODULE - CROSS-ENGINE STATISTICS PARITY HARNESS
# ==============================================================================
#
# The R engine (Excel workbook + the letters carried into the v2 island) and the
# v2 JS engine (live filters / custom banners, plus what the published view
# renders) must not disagree on the same deliverable. This file is the R half of
# a permanent parity gate; the JS half is
# modules/tabs/lib/html_report_v2/tests/parity_stats_tests.mjs.
#
# Spec: docs/tabs_production_review_2026-08/CROSS_ENGINE_STATS_SPEC.md
#
# Sections, in the order the spec's stages landed them:
#   R-4  Fractional n_eff (D3) — means and proportions gate on the same base
#
# Every expected value below is hand-derived in the comment above it. A parity
# gate that re-blesses whatever the code produced is a tautology, not a gate.
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_cross_engine_stats.R")
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
source(file.path(turas_root, "modules/tabs/lib/type_utils.R"))
source(file.path(turas_root, "modules/tabs/lib/weighting.R"))
source(file.path(turas_root, "modules/tabs/lib/cell_calculator.R"))


# ==============================================================================
# R-4. FRACTIONAL n_eff (D3)
# ==============================================================================
#
# THE BUG THIS PINS. calculate_effective_n() (weighting.R) used to return
# as.integer(round(n_effective)); calculate_effective_base() (cell_calculator.R)
# has always returned the raw fraction. Proportion tests ride the latter via
# banner_bases[[key]]$effective; the mean test recomputes its own n_eff through
# the former. So on the very same column, an n_eff of 29.63 FAILED a min_base of
# 30 for proportions and PASSED it for means — one table, two bases.
#
# THE FIXTURE WEIGHTS, hand-derived. 26 respondents at weight 1 and 7 at
# weight 2 (n = 33):
#     Sum(w)   = 26*1 + 7*2  = 40
#     Sum(w^2) = 26*1 + 7*4  = 54
#     n_eff    = 40^2 / 54   = 1600 / 54 = 29.6296...
# Chosen because it sits in [29.5, 30): it rounds UP to 30, so the old integer
# return crossed min_base and the fractional one does not. That crossing is the
# whole behaviour change, so the test has to sit exactly on it.

context("R-4: fractional n_eff")

# 26 at weight 1, 7 at weight 2 -> n_eff = 1600/54 = 29.6296...
NEFF_WEIGHTS <- c(rep(1, 26), rep(2, 7))
NEFF_EXPECTED <- 1600 / 54

test_that("calculate_effective_n returns the fraction, not the rounded integer", {
  eff <- calculate_effective_n(NEFF_WEIGHTS)

  expect_equal(eff, NEFF_EXPECTED, tolerance = 1e-9)
  # The specific regression: it must NOT be 30. (round(29.6296) == 30.)
  expect_false(isTRUE(all.equal(eff, 30)))
  expect_lt(eff, 30)
  expect_gt(eff, 29.5)
})

test_that("means and proportions are sized on the SAME effective base", {
  # weighting.R's calculate_effective_n (mean path) and cell_calculator.R's
  # calculate_effective_base (proportion path) must agree cell for cell.
  expect_equal(
    calculate_effective_n(NEFF_WEIGHTS),
    calculate_effective_base(NEFF_WEIGHTS),
    tolerance = 1e-12
  )

  # And on a second, differently-shaped weight vector: 10 at weight 1, 10 at
  # weight 3 -> Sum(w) = 40, Sum(w^2) = 10 + 90 = 100, n_eff = 1600/100 = 16.
  w2 <- c(rep(1, 10), rep(3, 10))
  expect_equal(calculate_effective_n(w2), 16, tolerance = 1e-12)
  expect_equal(calculate_effective_base(w2), 16, tolerance = 1e-12)
})

test_that("n_eff 29.63 does NOT test at min_base 30 for MEANS", {
  # Two groups sharing the fixture weights, with a large mean gap (1 vs 5) that
  # would be significant on any base big enough to test. The only thing standing
  # between these values and a letter is the min_base gate.
  values1 <- rep(c(1, 1, 1, 1, 2), length.out = 33)
  values2 <- rep(c(5, 5, 5, 5, 4), length.out = 33)

  res <- weighted_t_test_means(
    values1, values2,
    weights1 = NEFF_WEIGHTS, weights2 = NEFF_WEIGHTS,
    min_base = 30, alpha = 0.05
  )

  expect_false(res$significant)
  expect_true(is.na(res$p_value))   # NA = "refused to test", not "tested, p >= alpha"
})

test_that("n_eff 29.63 does NOT test at min_base 30 for PROPORTIONS either", {
  # Same base, same gate — the point of D3 is that these two agree. A 10%/60%
  # split across weighted bases of 40 would be significant if it were tested.
  res <- weighted_z_test_proportions(
    count1 = 4,  base1 = 40,
    count2 = 24, base2 = 40,
    eff_n1 = calculate_effective_base(NEFF_WEIGHTS),
    eff_n2 = calculate_effective_base(NEFF_WEIGHTS),
    is_weighted = TRUE, min_base = 30, alpha = 0.05
  )

  expect_false(res$significant)
  expect_true(is.na(res$p_value))
})

test_that("the same pair DOES test once the effective base clears min_base", {
  # Guard against a false pass: prove the refusals above come from the base
  # gate and nothing else. 52 at weight 1 and 14 at weight 2 (n = 66) doubles
  # the fixture: Sum(w) = 80, Sum(w^2) = 108, n_eff = 6400/108 = 59.259 > 30.
  big_w <- c(rep(1, 52), rep(2, 14))
  expect_equal(calculate_effective_n(big_w), 6400 / 108, tolerance = 1e-9)

  values1 <- rep(c(1, 1, 1, 1, 2), length.out = 66)
  values2 <- rep(c(5, 5, 5, 5, 4), length.out = 66)

  res_mean <- weighted_t_test_means(
    values1, values2,
    weights1 = big_w, weights2 = big_w,
    min_base = 30, alpha = 0.05
  )
  expect_true(res_mean$significant)
  expect_false(is.na(res_mean$p_value))

  res_prop <- weighted_z_test_proportions(
    count1 = 8,  base1 = 80,
    count2 = 48, base2 = 80,
    eff_n1 = calculate_effective_base(big_w),
    eff_n2 = calculate_effective_base(big_w),
    is_weighted = TRUE, min_base = 30, alpha = 0.05
  )
  expect_true(res_prop$significant)
  expect_false(is.na(res_prop$p_value))
})

test_that("unit weights still return exactly n (no design effect)", {
  expect_equal(calculate_effective_n(rep(1, 100)), 100)
  expect_equal(calculate_effective_n(rep(2.5, 40)), 40)   # constant, any scale
  expect_equal(calculate_effective_n(numeric(0)), 0)
  expect_equal(calculate_effective_n(c(NA, NA)), 0)
})
