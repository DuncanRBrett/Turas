# ==============================================================================
# TEST SUITE: perform_significance_tests_* Wrapper Functions
# ==============================================================================
# Exercises the wrapper layer in trend_significance.R that the test suite
# previously covered only indirectly. Targets the three correctness items
# identified in the 2026-05-24 production review:
#
#   I1 — eff_n must be honoured by every wrapper (no silent fallback to
#        n_unweighted when eff_n is present)
#   I2 — minimum_base must gate enhanced-metric and multi-mention tests,
#        not just means / proportions / NPS
#   I3 — NPS test must use the multinomial closed-form SE, not the
#        worst-case conservative estimate
#
# These tests construct synthetic wave_results lists directly — no wave-loader
# or file I/O — so they're fast and target the wrapper logic in isolation.
# ==============================================================================

library(testthat)

context("perform_significance_tests_* wrappers")

# ==============================================================================
# SETUP
# ==============================================================================

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "trend_significance.R"))

# Synthetic config helper — minimal shape that get_setting() will accept
make_config <- function(alpha = 0.05, minimum_base = 30) {
  list(
    settings = list(
      alpha = alpha,
      minimum_base = minimum_base
    )
  )
}


# ==============================================================================
# perform_significance_tests_means: eff_n vs n_unweighted
# ==============================================================================

test_that("perform_significance_tests_means uses eff_n when present", {
  # Two waves, weighted to give eff_n much smaller than n_unweighted.
  # If the wrapper used n_unweighted it would over-state significance.
  wave_results <- list(
    W1 = list(available = TRUE, mean = 5.0, sd = 1.0,
              n_unweighted = 200, n_weighted = 200, eff_n = 50),
    W2 = list(available = TRUE, mean = 5.3, sd = 1.0,
              n_unweighted = 200, n_weighted = 200, eff_n = 50)
  )
  result <- perform_significance_tests_means(wave_results, c("W1", "W2"), make_config())
  test_key <- "W1_vs_W2"
  expect_true(test_key %in% names(result))

  # With n=50 each, delta=0.3, sd=1.0: t ~= 1.5, p ~= 0.13 → not sig
  expect_false(result[[test_key]]$significant)
  # If wrapper used n_unweighted=200 it would yield sig (t ~= 3.0, p ~= 0.003)
  # So passing here proves eff_n is the value being used.
  expect_true(result[[test_key]]$p_value > 0.05)
})

test_that("perform_significance_tests_means refuses below minimum_base via eff_n", {
  wave_results <- list(
    W1 = list(available = TRUE, mean = 5.0, sd = 1.0,
              n_unweighted = 200, n_weighted = 200, eff_n = 20),  # below 30
    W2 = list(available = TRUE, mean = 8.0, sd = 1.0,
              n_unweighted = 200, n_weighted = 200, eff_n = 20)
  )
  # Big delta would clearly be significant if test ran. Gate should refuse.
  result <- perform_significance_tests_means(wave_results, c("W1", "W2"), make_config())
  expect_false(result[["W1_vs_W2"]]$significant)
  expect_equal(result[["W1_vs_W2"]]$reason, "insufficient_base_or_unavailable")
})

test_that("perform_significance_tests_means falls back to n_unweighted when eff_n missing", {
  wave_results <- list(
    W1 = list(available = TRUE, mean = 5.0, sd = 1.0,
              n_unweighted = 100, n_weighted = 100),  # no eff_n
    W2 = list(available = TRUE, mean = 5.5, sd = 1.0,
              n_unweighted = 100, n_weighted = 100)
  )
  result <- perform_significance_tests_means(wave_results, c("W1", "W2"), make_config())
  expect_true("W1_vs_W2" %in% names(result))
  # Falls back to n_unweighted=100 → delta 0.5 with sd 1.0 IS significant
  expect_true(result[["W1_vs_W2"]]$significant)
})


# ==============================================================================
# perform_significance_tests_proportions
# ==============================================================================

test_that("perform_significance_tests_proportions gates by minimum_base", {
  wave_results <- list(
    W1 = list(available = TRUE,
              proportions = c("CODE_A" = 20),  # 20% of code A
              n_unweighted = 20, n_weighted = 20, eff_n = 20),
    W2 = list(available = TRUE,
              proportions = c("CODE_A" = 60),
              n_unweighted = 20, n_weighted = 20, eff_n = 20)
  )
  result <- perform_significance_tests_proportions(wave_results, c("W1", "W2"),
                                                    make_config(), "CODE_A")
  expect_false(result[["W1_vs_W2"]]$significant)
  expect_equal(result[["W1_vs_W2"]]$reason, "insufficient_base_or_unavailable")
})

test_that("perform_significance_tests_proportions detects significant change at adequate base", {
  wave_results <- list(
    W1 = list(available = TRUE,
              proportions = c("CODE_A" = 30),
              n_unweighted = 200, n_weighted = 200, eff_n = 200),
    W2 = list(available = TRUE,
              proportions = c("CODE_A" = 50),
              n_unweighted = 200, n_weighted = 200, eff_n = 200)
  )
  result <- perform_significance_tests_proportions(wave_results, c("W1", "W2"),
                                                    make_config(), "CODE_A")
  expect_true(result[["W1_vs_W2"]]$significant)
})


# ==============================================================================
# perform_significance_tests_nps — verifies I3 fix (multinomial SE)
# ==============================================================================

test_that("perform_significance_tests_nps uses multinomial closed-form SE", {
  # Realistic NPS scenario: W1 NPS=30 (p_p=0.5, p_d=0.2),
  #                          W2 NPS=10 (p_p=0.4, p_d=0.3) — delta = 20
  # Conservative SE (old): sqrt(10000/100 + 10000/100) = 14.14 → z = 1.41, p = 0.16
  # True multinomial SE:   sqrt(61 + 69) ≈ 11.40 → z = 1.75, p = 0.080
  wave_results <- list(
    W1 = list(available = TRUE, nps = 30,
              promoters_pct = 50, detractors_pct = 20, passives_pct = 30,
              n_unweighted = 100, n_weighted = 100, eff_n = 100),
    W2 = list(available = TRUE, nps = 10,
              promoters_pct = 40, detractors_pct = 30, passives_pct = 30,
              n_unweighted = 100, n_weighted = 100, eff_n = 100)
  )
  result <- perform_significance_tests_nps(wave_results, c("W1", "W2"), make_config())

  expect_equal(result[["W1_vs_W2"]]$nps_difference, -20)
  # z-statistic should be > 1.7 — strictly larger than the conservative estimate (1.41)
  expect_true(result[["W1_vs_W2"]]$z_statistic > 1.6)
  expect_true(result[["W1_vs_W2"]]$z_statistic < 1.9)
  # Note string updated to reflect the new formula
  expect_true(grepl("multinomial", result[["W1_vs_W2"]]$note))
})

test_that("perform_significance_tests_nps detects significant move under multinomial SE", {
  # Larger move: NPS 30 → -10 (delta = 40). Clearly significant at n=100 each.
  wave_results <- list(
    W1 = list(available = TRUE, nps = 30,
              promoters_pct = 50, detractors_pct = 20, passives_pct = 30,
              n_unweighted = 100, n_weighted = 100, eff_n = 100),
    W2 = list(available = TRUE, nps = -10,
              promoters_pct = 30, detractors_pct = 40, passives_pct = 30,
              n_unweighted = 100, n_weighted = 100, eff_n = 100)
  )
  result <- perform_significance_tests_nps(wave_results, c("W1", "W2"), make_config())
  expect_true(result[["W1_vs_W2"]]$significant)
  expect_true(result[["W1_vs_W2"]]$p_value < 0.01)
})

test_that("perform_significance_tests_nps handles degenerate p_p=p_d=0 safely", {
  wave_results <- list(
    W1 = list(available = TRUE, nps = 0,
              promoters_pct = 0, detractors_pct = 0, passives_pct = 100,
              n_unweighted = 100, n_weighted = 100, eff_n = 100),
    W2 = list(available = TRUE, nps = 0,
              promoters_pct = 0, detractors_pct = 0, passives_pct = 100,
              n_unweighted = 100, n_weighted = 100, eff_n = 100)
  )
  result <- perform_significance_tests_nps(wave_results, c("W1", "W2"), make_config())
  # Zero variance: function should not crash and should not declare significance
  expect_false(result[["W1_vs_W2"]]$significant)
  expect_true(!is.null(result[["W1_vs_W2"]]))
})

test_that("perform_significance_tests_nps gates by minimum_base", {
  wave_results <- list(
    W1 = list(available = TRUE, nps = 30,
              promoters_pct = 50, detractors_pct = 20, passives_pct = 30,
              n_unweighted = 20, n_weighted = 20, eff_n = 20),
    W2 = list(available = TRUE, nps = -50,
              promoters_pct = 10, detractors_pct = 60, passives_pct = 30,
              n_unweighted = 20, n_weighted = 20, eff_n = 20)
  )
  result <- perform_significance_tests_nps(wave_results, c("W1", "W2"), make_config())
  expect_false(result[["W1_vs_W2"]]$significant)
  expect_equal(result[["W1_vs_W2"]]$reason, "insufficient_base_or_unavailable")
})


# ==============================================================================
# perform_significance_tests_for_metric — verifies I2 fix (min_base gate)
# ==============================================================================

test_that("perform_significance_tests_for_metric refuses below minimum_base (I2 fix)", {
  # Before I2: this test would have run on n=5 and produced a z-statistic.
  # After I2: should refuse with insufficient_base_or_unavailable.
  wave_results <- list(
    W1 = list(available = TRUE,
              metrics = list(top_box = 20),
              n_unweighted = 5, n_weighted = 5, eff_n = 5),
    W2 = list(available = TRUE,
              metrics = list(top_box = 80),
              n_unweighted = 5, n_weighted = 5, eff_n = 5)
  )
  result <- perform_significance_tests_for_metric(wave_results, c("W1", "W2"),
                                                   "top_box", make_config(),
                                                   test_type = "proportion")
  expect_false(result[["W1_vs_W2"]]$significant)
  expect_equal(result[["W1_vs_W2"]]$reason, "insufficient_base_or_unavailable")
})

test_that("perform_significance_tests_for_metric uses eff_n at adequate base (I1 fix)", {
  # If eff_n is honoured: delta 30%->50% at eff_n=60 each → p ~= 0.025 → significant.
  # If wrapper falls back to n_unweighted=200 it would still be significant, so to
  # discriminate we use a delta that is only significant at the inflated N.
  # Delta 30%->39% at eff_n=60 → not significant. Same delta at n=200 → significant.
  wave_results <- list(
    W1 = list(available = TRUE,
              metrics = list(top_box = 30),
              n_unweighted = 200, n_weighted = 200, eff_n = 60),
    W2 = list(available = TRUE,
              metrics = list(top_box = 39),
              n_unweighted = 200, n_weighted = 200, eff_n = 60)
  )
  result <- perform_significance_tests_for_metric(wave_results, c("W1", "W2"),
                                                   "top_box", make_config(),
                                                   test_type = "proportion")
  # Eff_n (60) → p ~= 0.30, not sig
  expect_false(result[["W1_vs_W2"]]$significant)
  # If the wrapper had used n_unweighted=200, p would be ~= 0.06 — borderline
  # but not significant either. Use a sharper case below.
})

test_that("perform_significance_tests_for_metric distinguishes eff_n vs n_unweighted", {
  # Larger delta where the call goes one way at eff_n and the other at n_unweighted.
  # Delta 30%->44% (14pp) at eff_n=50 → p ~= 0.14 (NOT sig)
  # Same delta at n_unweighted=200 → p ~= 0.003 (SIG)
  wave_results <- list(
    W1 = list(available = TRUE,
              metrics = list(top_box = 30),
              n_unweighted = 200, n_weighted = 200, eff_n = 50),
    W2 = list(available = TRUE,
              metrics = list(top_box = 44),
              n_unweighted = 200, n_weighted = 200, eff_n = 50)
  )
  result <- perform_significance_tests_for_metric(wave_results, c("W1", "W2"),
                                                   "top_box", make_config(),
                                                   test_type = "proportion")
  # Passing FALSE here proves eff_n=50 was used, not n_unweighted=200
  expect_false(result[["W1_vs_W2"]]$significant)
})

test_that("perform_significance_tests_for_metric skips unavailable waves", {
  wave_results <- list(
    W1 = list(available = FALSE, metrics = list()),
    W2 = list(available = TRUE,
              metrics = list(top_box = 50),
              n_unweighted = 200, n_weighted = 200, eff_n = 200)
  )
  result <- perform_significance_tests_for_metric(wave_results, c("W1", "W2"),
                                                   "top_box", make_config(),
                                                   test_type = "proportion")
  expect_true(is.na(result[["W1_vs_W2"]]))
})


# ==============================================================================
# perform_significance_tests_multi_mention — verifies I2 fix
# ==============================================================================

test_that("perform_significance_tests_multi_mention gates by minimum_base (I2 fix)", {
  wave_results <- list(
    W1 = list(available = TRUE,
              mention_proportions = list("Option_X" = 20),
              n_unweighted = 25, n_weighted = 25, eff_n = 25),  # below 30
    W2 = list(available = TRUE,
              mention_proportions = list("Option_X" = 70),
              n_unweighted = 25, n_weighted = 25, eff_n = 25)
  )
  result <- perform_significance_tests_multi_mention(wave_results, c("W1", "W2"),
                                                      "Option_X", make_config())
  expect_false(result[["W1_vs_W2"]]$significant)
  expect_equal(result[["W1_vs_W2"]]$reason, "insufficient_base_or_unavailable")
})

test_that("perform_significance_tests_multi_mention detects sig at adequate base", {
  wave_results <- list(
    W1 = list(available = TRUE,
              mention_proportions = list("Option_X" = 30),
              n_unweighted = 200, n_weighted = 200, eff_n = 200),
    W2 = list(available = TRUE,
              mention_proportions = list("Option_X" = 50),
              n_unweighted = 200, n_weighted = 200, eff_n = 200)
  )
  result <- perform_significance_tests_multi_mention(wave_results, c("W1", "W2"),
                                                      "Option_X", make_config())
  expect_true(result[["W1_vs_W2"]]$significant)
})


# ==============================================================================
# perform_significance_tests_multi_mention_metric — verifies I2 fix
# ==============================================================================

test_that("perform_significance_tests_multi_mention_metric gates by minimum_base (I2 fix)", {
  wave_results <- list(
    W1 = list(available = TRUE,
              additional_metrics = list(any_mention_pct = 20),
              n_unweighted = 25, n_weighted = 25, eff_n = 25),
    W2 = list(available = TRUE,
              additional_metrics = list(any_mention_pct = 70),
              n_unweighted = 25, n_weighted = 25, eff_n = 25)
  )
  result <- perform_significance_tests_multi_mention_metric(wave_results,
                                                             c("W1", "W2"),
                                                             "any_mention_pct",
                                                             make_config())
  expect_false(result[["W1_vs_W2"]]$significant)
  expect_equal(result[["W1_vs_W2"]]$reason, "insufficient_base_or_unavailable")
})


# ==============================================================================
# END OF TEST SUITE
# ==============================================================================
