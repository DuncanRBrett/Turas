# ==============================================================================
# TEST: significance and CIs run on the Kish effective n (review 2026-07-12, H2)
# Weighted estimates used to be tested on the raw weighted total, so with
# dispersed weights p-values were too small and markers over-fired.
# ==============================================================================
library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  ROOT <<- find_root()
  Sys.setenv(TURAS_ROOT = ROOT)
  for (f in c("00_guard.R", "00_data_access.R", "03a_funnel_derive.R",
              "03b_funnel_metrics.R", "11_demographics.R",
              "09_portfolio.R", "09e_portfolio_extension.R"))
    source(file.path(ROOT, "modules", "brand", "R", f), local = FALSE)
})

# A two-proportion z-test closure in the shape run_significance_tests expects
.z_tester <- function(x1, n1, x2, n2, alpha) {
  p1 <- x1 / n1; p2 <- x2 / n2
  pp <- (x1 + x2) / (n1 + n2)
  se <- sqrt(pp * (1 - pp) * (1 / n1 + 1 / n2))
  z  <- (p1 - p2) / se
  p  <- 2 * stats::pnorm(-abs(z))
  list(p_value = p, significant = p < alpha,
       direction = if (p1 > p2) "higher" else "lower")
}

test_that(".brand_effective_n is the shared Kish statistic, plain count when unweighted", {
  expect_equal(.brand_effective_n(NULL, n = 40), 40)
  expect_equal(.brand_effective_n(rep(1, 40)), 40)
  expect_equal(.brand_effective_n(c(1, 1, 3)), 25 / 11, tolerance = 1e-12)
  expect_true(exists("calculate_effective_n", mode = "function"))
  expect_equal(.brand_effective_n(c(0.5, 1, 1.5, 2, 3)),
               calculate_effective_n(c(0.5, 1, 1.5, 2, 3)))
})

test_that("funnel stage rows carry n_effective and sig tests use it", {
  set.seed(11)
  n <- 200
  # Two brands, same weighted proportions by construction on two halves
  aware <- matrix(0L, n, 2, dimnames = list(NULL, c("F", "C")))
  aware[1:110, 1] <- 1L
  aware[1:90,  2] <- 1L
  stages <- list(aware = list(key = "aware", matrix = aware))
  # Weights: extremely dispersed, so the Kish n is a small fraction of n
  w <- rep(0.05, n); w[c(1, 2, 3, 4, 5, 111, 112, 113, 114, 115)] <- 40

  sm_uw <- calculate_stage_metrics(stages, weights = NULL)
  sm_w  <- calculate_stage_metrics(stages, weights = w)

  expect_true("n_effective" %in% names(sm_uw))
  expect_equal(sm_uw$n_effective, c(200, 200))
  n_eff_w <- calculate_effective_n(w)
  expect_equal(sm_w$n_effective, rep(n_eff_w, 2), tolerance = 1e-9)
  expect_lt(n_eff_w, 25)

  sig_uw <- run_significance_tests(sm_uw, "F", sig_tester = .z_tester, alpha = 0.05)
  sig_w  <- run_significance_tests(sm_w,  "F", sig_tester = .z_tester, alpha = 0.05)
  r_uw <- sig_uw[sig_uw$comparison == "focal_vs_competitor", ]
  r_w  <- sig_w[sig_w$comparison == "focal_vs_competitor", ]
  # On raw counts the 55% vs 45% gap is significant; on a Kish n under 25
  # it is not. Before H2 the weighted test ran on sum(w) and over-fired.
  expect_true(r_uw$significant)
  expect_false(r_w$significant)
  expect_gt(r_w$p_value, r_uw$p_value)
})

test_that("legacy stage rows without n_effective still test on the implied weighted total", {
  row_f <- data.frame(brand_code = "F", stage_key = "aware", pct_weighted = 0.55,
                      base_weighted = 110, stringsAsFactors = FALSE)
  inp <- .sig_inputs(row_f)
  expect_equal(inp$n, 200)
  expect_equal(inp$x, 110)
})

test_that("demographics Wilson interval widens under dispersed weights (Kish n, not count)", {
  n <- 120
  values <- rep(c("F", "M"), each = 60)
  mask <- rep(TRUE, n)
  w_flat <- rep(1, n)
  w_disp <- rep(0.1, n); w_disp[1:6] <- 20
  d_flat <- .demo_distribution(values, c("F", "M"), c("Female", "Male"), mask, w_flat, 0.95)
  d_disp <- .demo_distribution(values, c("F", "M"), c("Female", "Male"), mask, w_disp, 0.95)
  width <- function(d) d$CI_Upper - d$CI_Lower
  expect_true(all(width(d_disp) > width(d_flat)))
  # Counts stay unweighted counts
  expect_equal(d_disp$n, c(60L, 60L))
  # Unweighted: the interval is exactly the Wilson interval on n = 120
  w_ci <- .demo_wilson_ci(0.5, 120, 0.95)
  expect_equal(d_flat$CI_Lower[1], round(100 * w_ci$lower, 1))
})

test_that("portfolio extension p-value rises under dispersed weights", {
  data <- data.frame(
    BRANDAWARE_DSS_1 = c(rep("A", 45), rep("B", 15), rep(NA, 40)),
    BRANDAWARE_POS_1 = c(rep("A", 20), rep("B", 40), rep(NA, 40)),
    SQ2_1 = c(rep("DSS", 60), rep("POS", 40)),
    SQ2_2 = c(rep("POS", 60), rep(NA, 40)),
    stringsAsFactors = FALSE
  )
  categories <- data.frame(Category = c("Dressings", "Pour"),
                           CategoryCode = c("DSS", "POS"), Active = "Y",
                           stringsAsFactors = FALSE)
  structure <- list(brands = data.frame(
    Category = rep(c("Dressings", "Pour"), each = 2),
    CategoryCode = rep(c("DSS", "POS"), each = 2),
    BrandCode = rep(c("A", "B"), 2), BrandLabel = rep(c("A", "B"), 2),
    stringsAsFactors = FALSE), questionmap = NULL)
  config <- list(focal_brand = "A", portfolio_timeframe = "3m",
                 portfolio_min_base = 1L, portfolio_extension_baseline = "all",
                 focal_home_category = "DSS")
  out_flat <- compute_extension_table(data, NULL, categories, structure, config)
  w <- rep(0.05, 100); w[c(1:3, 61:63)] <- 30
  out_disp <- compute_extension_table(data, NULL, categories, structure, config,
                                      weights = w)
  expect_equal(out_flat$status, "PASS"); expect_equal(out_disp$status, "PASS")
  # DSS: focal aware 45 of 60 category buyers (75%) vs 45% of everyone.
  pv <- function(out) out$extension_df$p_value[out$extension_df$cat == "DSS"]
  expect_lt(pv(out_flat), 0.001)
  # Six respondents carry almost all the weight, so the Kish n collapses and
  # the same weighted gap is no longer significant.
  expect_gt(pv(out_disp), pv(out_flat))
  expect_gt(pv(out_disp), 0.05)
})

test_that(".brand_meets_min_base is the shared disclosure predicate; NA never passes", {
  expect_equal(.brand_meets_min_base(c(29, 30, 31)), c(FALSE, TRUE, TRUE))
  expect_false(.brand_meets_min_base(NA))
  expect_false(.brand_meets_min_base(NaN, 10))
  expect_true(.brand_meets_min_base(0, 0))        # suppress_base = 0 never suppresses
  expect_true(exists("meets_min_base", mode = "function"))
})


test_that("funnel stage flags accept text thresholds from a Settings sheet", {
  aware <- matrix(0L, 50, 2, dimnames = list(NULL, c("F", "C")))
  aware[1:40, 1] <- 1L; aware[1:10, 2] <- 1L
  stages <- list(aware = list(key = "aware", matrix = aware))
  sm <- calculate_stage_metrics(stages, weights = NULL, warn_base = "75", suppress_base = "30")
  expect_equal(sm$warning_flag[sm$brand_code == "F"], "warn")      # 40 < 75
  expect_equal(sm$warning_flag[sm$brand_code == "C"], "suppress")  # 10 < 30
  sm2 <- calculate_stage_metrics(stages, weights = NULL, warn_base = "junk", suppress_base = NA)
  expect_true(all(sm2$warning_flag %in% c("warn", "none", "suppress")))
})
