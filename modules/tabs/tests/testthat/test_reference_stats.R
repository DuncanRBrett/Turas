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

# ==============================================================================
# MEAN SIGNIFICANCE: Welch's t-test
# ==============================================================================
#
# Unweighted, weighted_t_test_means() must BE stats::t.test(var.equal = FALSE):
# the Welch statistic on the sample variances with Welch-Satterthwaite df.
# Weighted, the same test on the unbiased reliability-weighted variance (the
# printed SD, squared) and the Kish effective base, written out below.

.rs_q2 <- function(dist) rep(1:5, times = dist)

test_that("reference: unweighted mean test equals stats::t.test(var.equal = FALSE)", {
  # Parity fixture Q2, Alpha vs Gamma, and two other pairs of spreads.
  pairs <- list(
    list(.rs_q2(c(2, 4, 10, 14, 10)), .rs_q2(c(8, 12, 10, 12, 8))),
    list(.rs_q2(c(2, 6, 13, 24, 15)), .rs_q2(c(4, 6, 10, 18, 12))),
    list(c(rep(3, 30), rep(4, 5)), .rs_q2(c(10, 0, 0, 0, 25)))
  )
  for (p in pairs) {
    got <- weighted_t_test_means(p[[1]], p[[2]], min_base = 2, alpha = 0.05)
    ref <- stats::t.test(p[[1]], p[[2]], var.equal = FALSE)
    expect_equal(got$p_value, ref$p.value, tolerance = 1e-10)
    expect_equal(got$higher, mean(p[[1]]) > mean(p[[2]]))
  }
})

test_that("reference: weighted mean test is Welch on the unbiased variance and Kish n_eff", {
  x <- .rs_q2(c(2, 4, 10, 14, 10)); y <- .rs_q2(c(8, 12, 10, 12, 8))
  wx <- rep(c(1.6, 1.6, 2.8), length.out = length(x))
  wy <- rep(c(1.2, 1.2, 2.1), length.out = length(y))
  welch <- function(x, w, y, v) {
    ref_var <- function(a, b) stats::cov.wt(matrix(a, ncol = 1), wt = b / sum(b), method = "unbiased")$cov[1, 1]
    n1 <- sum(w)^2 / sum(w^2); n2 <- sum(v)^2 / sum(v^2)
    s1 <- ref_var(x, w) / n1; s2 <- ref_var(y, v) / n2
    t <- (weighted.mean(x, w) - weighted.mean(y, v)) / sqrt(s1 + s2)
    df <- (s1 + s2)^2 / (s1^2 / (n1 - 1) + s2^2 / (n2 - 1))
    2 * stats::pt(-abs(t), df)
  }
  got <- weighted_t_test_means(x, y, wx, wy, min_base = 2, alpha = 0.05)
  expect_equal(got$p_value, welch(x, wx, y, wy), tolerance = 1e-10)
})

# ==============================================================================
# NPS: a "don't know" is never a promoter
# ==============================================================================
#
# Hand example. Answers 10, 9, 99, 6, 8, 99, with 99 the don't-know code.
#   promoters (9-10): 10, 9 = 2;  detractors (0-6): 6 = 1;  passive: 8;  n = 4
#   NPS = (2 - 1) / 4 * 100 = 25
# The engine scored 99 as a promoter (v >= 9), giving (4 - 1) / 6 * 100 = 50,
# whether or not the option was flagged ExcludeFromIndex.

.rs_nps_opts <- function(flag) {
  data.frame(QuestionCode = "N", OptionText = c(as.character(0:10), "99"),
             DisplayText = c(as.character(0:10), "Don't know"),
             ExcludeFromIndex = c(rep(NA, 11), if (flag) "Y" else NA),
             stringsAsFactors = FALSE)
}
.rs_nps_data <- data.frame(N = c(10, 9, 99, 6, 8, 99))

test_that("reference: nps_bucket_score scores 0 to 10 only", {
  expect_equal(nps_bucket_score(10), 100)
  expect_equal(nps_bucket_score(9), 100)
  expect_equal(nps_bucket_score(7), 0)
  expect_equal(nps_bucket_score(0), -100)
  expect_true(is.na(nps_bucket_score(99)))
  expect_true(is.na(nps_bucket_score(11)))
  expect_true(is.na(nps_bucket_score(-1)))
})

test_that("reference: an NPS DK flagged ExcludeFromIndex leaves the score and its base", {
  qi <- data.frame(QuestionCode = "N", Variable_Type = "NPS", stringsAsFactors = FALSE)
  r <- calculate_summary_statistic(.rs_nps_data, qi, .rs_nps_opts(TRUE), rep(1, 6))
  expect_equal(r$value, 25)
  expect_equal(length(r$values), 4)
})

test_that("reference: an unflagged out-of-range code still leaves the NPS base", {
  qi <- data.frame(QuestionCode = "N", Variable_Type = "NPS", stringsAsFactors = FALSE)
  r <- calculate_summary_statistic(.rs_nps_data, qi, .rs_nps_opts(FALSE), rep(1, 6))
  expect_equal(r$value, 25)
})

test_that("reference: a DK flagged ExcludeFromIndex with an in-range code leaves NPS", {
  # A study that codes don't-know as 10 on an 11-point scale would be unusual,
  # but the flag, not the number, is what decides: flagged means excluded.
  opts <- .rs_nps_opts(FALSE); opts$ExcludeFromIndex[opts$OptionText == "0"] <- "Y"
  qi <- data.frame(QuestionCode = "N", Variable_Type = "NPS", stringsAsFactors = FALSE)
  r <- calculate_summary_statistic(data.frame(N = c(10, 0, 6, 9)), qi, opts, rep(1, 4))
  # 0 excluded: promoters 10, 9; detractor 6; n = 3 -> (2 - 1) / 3 * 100
  expect_equal(r$value, 100 / 3)
})

# ==============================================================================
# LIKERT INDEX: ExcludeFromIndex wins over an Index_Weight
# ==============================================================================
#
# Hand example. Options 1..5 carry Index_Weight 0, 25, 50, 75, 100; "DK"
# carries Index_Weight 0 (filled in by habit) and ExcludeFromIndex = Y.
# Answers 1, 5, DK, DK: index without the DKs = (0 + 100) / 2 = 50. The engine
# counted them at weight 0: (0 + 100 + 0 + 0) / 4 = 25. The microdata writer
# and the island's index_scores already honour the flag, so the Excel index and
# the report's recompute disagreed.

test_that("reference: an option flagged ExcludeFromIndex stays out of the Likert index", {
  opts <- data.frame(QuestionCode = "L", OptionText = c(as.character(1:5), "DK"),
                     Index_Weight = c(0, 25, 50, 75, 100, 0),
                     ExcludeFromIndex = c(rep(NA, 5), "Y"), stringsAsFactors = FALSE)
  qi <- data.frame(QuestionCode = "L", Variable_Type = "Likert", stringsAsFactors = FALSE)
  r <- calculate_summary_statistic(data.frame(L = c("1", "5", "DK", "DK")), qi, opts, rep(1, 4))
  expect_equal(r$value, 50)
  expect_equal(length(r$values), 2)
})

# ==============================================================================
# NUMERIC: the letters test the values the printed mean uses
# ==============================================================================
#
# Max_Value = 100. Column A: 40 answers alternating 49 / 51 (mean 50). Column B:
# 32 answers alternating 49 / 51 plus 8 answers of 999 (above Max_Value).
# Printed means: A = 50, B = 50 (the 999s are dropped). With no difference to
# see there must be no letter. The engine tested B on all 40 values, mean
# (32 * 50 + 8 * 999) / 40 = 239.8: t.test(B40, A) p ~ 0.004, a letter "A" on
# B under two identical printed means.

test_that("reference: numeric letters test the same values as the printed mean", {
  kt <- "TOTAL::Total"; ka <- "GRP::A"; kb <- "GRP::B"
  a <- rep(c(49, 51), 20)
  b <- c(rep(c(49, 51), 16), rep(999, 8))
  d <- data.frame(NUM = c(a, b))
  idx <- list(seq_len(80), 1:40, 41:80); names(idx) <- c(kt, ka, kb)
  bases <- lapply(idx, function(i) list(unweighted = length(i), weighted = length(i),
                                          effective = length(i)))
  banner <- list(internal_keys = c(kt, ka, kb),
                 columns = data.frame(BannerLabel = c("Total", "A", "B")),
                 banner_info = list(GRP = list(internal_keys = c(ka, kb),
                                               letters = setNames(c("A", "B"), c(ka, kb)))))
  cfg <- list(enable_significance_testing = TRUE, alpha = 0.05,
              bonferroni_correction = FALSE, significance_min_base = 30,
              alpha_secondary = NULL, show_frequency = FALSE,
              show_numeric_median = FALSE, show_numeric_mode = FALSE,
              show_numeric_outliers = FALSE, exclude_outliers_from_stats = FALSE,
              outlier_method = "IQR", decimal_places_numeric = 1,
              show_numeric_sd = TRUE, show_percent_column = FALSE,
              show_percent_row = FALSE, decimal_places_percent = 0)
  qi <- data.frame(QuestionCode = "NUM", QuestionText = "Spend", Variable_Type = "Numeric",
                   Columns = 1, Min_Value = 0, Max_Value = 100, stringsAsFactors = FALSE)
  # The reference claim itself: with the 999s in, t.test says significant.
  expect_lt(stats::t.test(b, a, var.equal = FALSE)$p.value, 0.05)
  res <- process_numeric_question(d, qi, data.frame(), banner, idx, rep(1, 80), bases,
                                  cfg, is_weighted = FALSE)
  mean_row <- res[res$RowType == "Average", , drop = FALSE]
  expect_equal(as.numeric(mean_row[[ka]][1]), 50)
  expect_equal(as.numeric(mean_row[[kb]][1]), 50)
  sig <- res[res$RowType == "Sig.", , drop = FALSE]
  expect_equal(nrow(sig), 1)
  expect_equal(sig[[kb]][1], "")
  expect_equal(sig[[ka]][1], "")
})
