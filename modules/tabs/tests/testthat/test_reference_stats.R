# ==============================================================================
# TABS. FUNCTION-LEVEL REFERENCE CHECKS (robustness programme, session 2)
# ==============================================================================
#
# Each statistic tabs prints, computed by the engine on a small dataset and
# compared with a calculation that does not share Turas code: stats::cov.wt,
# stats::t.test, or a hand value written out in the comment above the check.
# The pipeline-level twin of this file is test_reference_pipeline.R, which reads
# the same statistics back from a real run's workbook and report.
# ==============================================================================

library(testthat)

.rs_root <- local({
  home <- Sys.getenv("TURAS_HOME", "")
  cands <- c(home, getwd(), file.path(getwd(), "../.."), file.path(getwd(), "../../.."),
             file.path(getwd(), "../../../.."))
  hit <- NULL
  for (cd in cands) {
    if (nzchar(cd) && dir.exists(file.path(cd, "modules", "tabs"))) {
      hit <- normalizePath(cd); break
    }
  }
  hit
})
skip_if(is.null(.rs_root), "Turas root not found (set TURAS_HOME)")

# The loader sources the tabs pipeline into the global environment and needs
# turas_root there (the same arrangement as test_cross_engine_stats.R).
assign("turas_root", .rs_root, envir = globalenv())
source(file.path(.rs_root, "modules/tabs/tests/fixtures/parity_project/load_tabs_pipeline.R"))

# Unbiased reliability-weighted SD: stats::cov.wt with normalised weights,
# method = "unbiased". Equals the population variance times n_eff/(n_eff - 1),
# the rule the tracker and the v2 report use; for unit weights it is sd().
.rs_ref_sd <- function(v, w) {
  sqrt(stats::cov.wt(matrix(v, ncol = 1), wt = w / sum(w), method = "unbiased")$cov[1, 1])
}

.rs_sd_row <- function(v, w) {
  row <- create_standard_deviation_row(
    stat_value_sets = list(A = v), stat_weight_sets = list(A = w),
    banner_row_indices = list(A = seq_along(v)), internal_keys = "A",
    config = list(decimal_places_ratings = 6))
  as.numeric(row$A)
}

.rs_numeric_sd <- function(v, w, weighted = TRUE) {
  calculate_numeric_statistics(
    data = data.frame(QN = v), question_info = data.frame(QuestionCode = "QN"),
    weights = w,
    config = list(show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE,
                  show_numeric_median = FALSE, show_numeric_mode = FALSE),
    is_weighted = weighted)$sd
}

# ==============================================================================
# STANDARD DEVIATION ROW
# ==============================================================================
#
# Hand example. v = 1, 2, 3, 4, 5 with w = 1, 1, 1, 1, 2.
#   sum w = 6; mean = (1 + 2 + 3 + 4 + 10) / 6 = 3.3333
#   sum w (x - mean)^2 = 5.4444 + 1.7778 + 0.1111 + 0.4444 + 2 * 2.7778 = 13.3333
#   population variance = 13.3333 / 6 = 2.2222
#   n_eff = 6^2 / (1 + 1 + 1 + 1 + 4) = 4.5
#   unbiased variance = 2.2222 * 4.5 / 3.5 = 2.8571;  SD = 1.6903
# Dividing by (sum w - 1) instead gives 13.3333 / 5 = 2.6667, SD 1.6330, and
# with the weights grossed up by 1000 it falls to the population SD, 1.4907:
# a statistic that changes when every weight is multiplied by a constant.

test_that("reference: weighted SD row is the unbiased reliability-weighted SD", {
  v <- c(1, 2, 3, 4, 5); w <- c(1, 1, 1, 1, 2)
  expect_equal(.rs_ref_sd(v, w), sqrt((40 / 18) * 4.5 / 3.5), tolerance = 1e-12)
  expect_equal(.rs_sd_row(v, w), round(.rs_ref_sd(v, w), 6), tolerance = 1e-9)
  expect_equal(.rs_numeric_sd(v, w), .rs_ref_sd(v, w), tolerance = 1e-9)
})

test_that("reference: the weighted SD does not move when every weight is grossed up", {
  v <- c(1, 2, 3, 4, 5); w <- c(1, 1, 1, 1, 2)
  expect_equal(.rs_sd_row(v, w * 1000), .rs_sd_row(v, w), tolerance = 1e-9)
  expect_equal(.rs_numeric_sd(v, w * 1000), .rs_numeric_sd(v, w), tolerance = 1e-9)
  # Weights scaled DOWN to sum to 1 (a normalised weight) must not break it either.
  expect_equal(.rs_sd_row(v, w / sum(w)), .rs_sd_row(v, w), tolerance = 1e-9)
  expect_equal(.rs_numeric_sd(v, w / sum(w)), .rs_numeric_sd(v, w), tolerance = 1e-9)
})

test_that("reference: unweighted SD row is the ordinary sample SD", {
  v <- c(2, 4, 4, 4, 5, 5, 7, 9)
  expect_equal(.rs_sd_row(v, rep(1, 8)), round(sd(v), 6), tolerance = 1e-9)
  expect_equal(.rs_numeric_sd(v, rep(1, 8), weighted = FALSE), sd(v), tolerance = 1e-12)
})
