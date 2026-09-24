# ==============================================================================
# TEST SUITE: Reference checks for the tracker's headline numbers
# ==============================================================================
# Every number here is compared with a calculation that does NOT share Turas
# code: the survey package, a base R test (prop.test, t.test, cov.wt), or a
# hand calculation written out in the comment beside it. A check against the
# value Turas produced last week is not a reference and does not appear here.
#
# Robustness programme, 24 Sep 2026 (TURAS_ROBUSTNESS_BRIEF.md, Tracker):
#   Reference gate   weighted %, mean, NPS, effective n, the three tests
#   Adversarial gate unit weights, weights with a design effect near 2,
#                    weights grossed to a population total, fractional
#                    effective n, bases either side of minimum_base, NA
# ==============================================================================

library(testthat)

context("Reference checks: tracker statistics")

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)
weights_path <- file.path(turas_root, "modules", "shared", "lib", "weights_utils.R")
if (file.exists(weights_path)) source(weights_path)

source(file.path(tracker_root, "lib", "00_guard.R"))
source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "metric_types.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "wave_loader.R"))
source(file.path(tracker_root, "lib", "aggregate_wave_loader.R"))
source(file.path(tracker_root, "lib", "question_mapper.R"))
source(file.path(tracker_root, "lib", "statistical_core.R"))
source(file.path(tracker_root, "lib", "trend_changes.R"))
source(file.path(tracker_root, "lib", "trend_significance.R"))
source(file.path(tracker_root, "lib", "trend_calculator.R"))
source(file.path(tracker_root, "lib", "tracker_dashboard_reports.R"))

has_survey <- requireNamespace("survey", quietly = TRUE)


# ==============================================================================
# FIXTURES
# ==============================================================================

# Three weight sets for the same 40 respondents.
#   unit    all 1
#   deff2   alternating 0.1 and 5. Kish deff = n * sum(w^2) / sum(w)^2
#           = 40 * (20 * 0.01 + 20 * 25) / (20 * 0.1 + 20 * 5)^2
#           = 40 * 500.2 / 10404 = 1.923, so effective n = 20.8
#   grossed deff2 scaled to a population of 1.2 million. Every share, mean,
#           SD and effective n must be unchanged; only the weighted total moves.
ref_weight_sets <- function(n = 40) {
  deff2 <- rep(c(0.1, 5), length.out = n)
  list(
    unit = rep(1, n),
    deff2 = deff2,
    grossed = deff2 * 1.2e6 / sum(deff2)
  )
}

ref_rating <- function() {
  # 1-5 rating with two missing answers
  c(5, 4, 4, 3, 2, 5, 1, 4, 3, 3, 5, 5, 4, 2, 3, 4, NA, 5, 1, 2,
    3, 4, 5, 4, 4, 3, NA, 2, 5, 4, 3, 3, 4, 5, 2, 1, 4, 4, 3, 5)
}

ref_choice <- function() {
  rep(c("Yes", "No", "Yes", "Unsure", "No", "Yes", "Yes", NA), 5)
}

kish <- function(w) sum(w)^2 / sum(w^2)

svy_design <- function(df) {
  survey::svydesign(ids = ~1, weights = ~w, data = df)
}


# ==============================================================================
# EFFECTIVE N (Kish, by hand)
# ==============================================================================

test_that("effective n is the Kish formula, hand calculated", {
  # w = 1, 1, 1, 3: sum = 6, sum of squares = 12, n_eff = 36 / 12 = 3
  w <- c(1, 1, 1, 3)
  v <- c(1, 2, 3, 4)
  expect_equal(calculate_proportions(v, w)$eff_n, 3)
  expect_equal(calculate_weighted_mean(v, w)$eff_n, 3)
  expect_equal(calculate_nps_score(c(9, 9, 5, 7), w)$eff_n, 3)

  # Fractional: w = 1, 2: n_eff = 9 / 5 = 1.8, not rounded
  expect_equal(calculate_proportions(c("a", "b"), c(1, 2))$eff_n, 1.8)
})

test_that("effective n ignores rows whose answer is missing", {
  # Rows 2 and 4 are NA, so only w = 1 and 3 count: 16 / 10 = 1.6
  v <- c(1, NA, 2, NA)
  w <- c(1, 5, 3, 5)
  expect_equal(calculate_weighted_mean(v, w)$eff_n, 1.6)
})

test_that("grossing weights to a population leaves effective n unchanged", {
  ws <- ref_weight_sets()
  v <- ref_rating()
  ok <- !is.na(v)
  expect_equal(calculate_weighted_mean(v, ws$grossed)$eff_n, kish(ws$deff2[ok]))
  expect_equal(calculate_weighted_mean(v, ws$deff2)$eff_n, kish(ws$deff2[ok]))
  expect_equal(calculate_weighted_mean(v, ws$unit)$eff_n, sum(ok))
})


# ==============================================================================
# WEIGHTED PROPORTIONS against survey::svymean
# ==============================================================================

test_that("single-choice shares match survey::svymean on every weight set", {
  skip_if_not(has_survey, "survey package not installed")
  v <- ref_choice()
  for (set_name in names(ref_weight_sets())) {
    w <- ref_weight_sets()[[set_name]]
    turas <- calculate_proportions(v, w, codes = c("Yes", "No", "Unsure"))

    df <- data.frame(v = factor(v), w = w)[!is.na(v), ]
    ref <- survey::svymean(~v, svy_design(df))
    ref_pct <- 100 * stats::coef(ref)
    for (code in c("Yes", "No", "Unsure")) {
      expect_equal(unname(turas$proportions[[code]]),
                   unname(ref_pct[[paste0("v", code)]]),
                   tolerance = 1e-10,
                   info = paste(set_name, code))
    }
  }
})

test_that("one weighted share, summed by hand", {
  # Pattern Yes, No, Yes, Unsure, No, Yes, Yes, NA repeated 5 times, with
  # weights alternating 0.1 and 5. Positions 1-8 carry weights
  # 0.1, 5, 0.1, 5, 0.1, 5, 0.1, 5, so one block has
  #   Yes (positions 1, 3, 6, 7): 0.1 + 0.1 + 5 + 0.1 = 5.3
  #   answered (positions 1-7):   0.1 * 4 + 5 * 3     = 15.4
  # and five blocks give 26.5 / 77 = 34.4156%.
  w <- ref_weight_sets()$deff2
  turas <- calculate_proportions(ref_choice(), w, codes = "Yes")
  expect_equal(unname(turas$proportions[["Yes"]]), 100 * 26.5 / 77)
})


# ==============================================================================
# WEIGHTED MEAN against survey::svymean; SD against stats::cov.wt
# ==============================================================================

test_that("weighted mean matches survey::svymean on every weight set", {
  skip_if_not(has_survey, "survey package not installed")
  v <- ref_rating()
  for (set_name in names(ref_weight_sets())) {
    w <- ref_weight_sets()[[set_name]]
    df <- data.frame(v = v, w = w)[!is.na(v), ]
    ref <- stats::coef(survey::svymean(~v, svy_design(df)))[["v"]]
    expect_equal(calculate_weighted_mean(v, w)$mean, ref,
                 tolerance = 1e-12, info = set_name)
  }
})

test_that("weighted SD is the unbiased reliability-weight SD (stats::cov.wt)", {
  # Chosen 24 Sep 2026 as the most defensible to a statistician: the weighted
  # variance times n_eff / (n_eff - 1), with n_eff the Kish effective base.
  # It is the unbiased estimator for reliability (survey) weights, equals
  # sd() when every weight is 1, is unchanged by grossing, and is the formula
  # the tabs v2 Tracking tab uses (sdOfScores in 22w_waves.js).
  # Hand case: values 1, 3 with weights 1, 3. Mean = 10 / 4 = 2.5.
  #   sum w (x - m)^2 / sum w = (1 * 2.25 + 3 * 0.25) / 4 = 0.75
  #   n_eff = 16 / 10 = 1.6, so variance = 0.75 * 1.6 / 0.6 = 2
  expect_equal(calculate_weighted_mean(c(1, 3), c(1, 3))$sd, sqrt(2))

  v <- ref_rating()
  ok <- !is.na(v)
  expect_equal(calculate_weighted_mean(v, ref_weight_sets()$unit)$sd, stats::sd(v[ok]))
  for (set_name in c("deff2", "grossed")) {
    w <- ref_weight_sets()[[set_name]]
    ref <- stats::cov.wt(matrix(v[ok]), wt = w[ok] / sum(w[ok]), method = "unbiased")$cov
    expect_equal(calculate_weighted_mean(v, w)$sd, sqrt(ref[1, 1]),
                 tolerance = 1e-12, info = set_name)
  }
})

test_that("mean trend t-test on unit weights equals t.test(var.equal = TRUE)", {
  # End to end through the calculator: SD, effective n and the pooled test
  # together must reproduce base R on the raw vectors.
  set.seed(5)
  x1 <- sample(1:5, 36, replace = TRUE)
  x2 <- sample(1:5, 33, replace = TRUE, prob = c(1, 1, 2, 3, 3))
  m1 <- calculate_weighted_mean(x1, rep(1, 36))
  m2 <- calculate_weighted_mean(x2, rep(1, 33))
  waves <- list(A = list(available = TRUE, mean = m1$mean, sd = m1$sd, eff_n = m1$eff_n),
                B = list(available = TRUE, mean = m2$mean, sd = m2$sd, eff_n = m2$eff_n))
  sig <- perform_significance_tests_means(waves, c("A", "B"),
                                          list(settings = list(minimum_base = 30)))
  ref <- stats::t.test(x2, x1, var.equal = TRUE)
  expect_equal(sig$A_vs_B$p_value, ref$p.value, tolerance = 1e-10)
})

test_that("the mean's CI is mean +/- z * sd / sqrt(effective n)", {
  # Documented method (Kish approximation): the standard error of a weighted
  # mean is its SD over the square root of the Kish effective base. This is
  # not the linearisation SE survey::svymean reports; the two differ by a few
  # per cent when weights correlate with the answer. Tabs uses the same Kish
  # method, so the tracker and the tabs report agree.
  v <- ref_rating()
  w <- ref_weight_sets()$deff2
  r <- calculate_weighted_mean(v, w)
  half <- stats::qnorm(0.975) * r$sd / sqrt(r$eff_n)
  expect_equal(r$ci_lower, r$mean - half)
  expect_equal(r$ci_upper, r$mean + half)
})


# ==============================================================================
# NPS, counted by hand
# ==============================================================================

test_that("NPS and its three shares, counted by hand", {
  # Scores 10 9 9 8 7 6 0 3 10 5 with the first respondent weighted 2.
  # Total weight 11.
  #   promoters (9-10):  2 + 1 + 1 + 1 = 5  -> 45.4545%
  #   passives  (7-8):   1 + 1         = 2  -> 18.1818%
  #   detractors (0-6):  1 + 1 + 1 + 1 = 4  -> 36.3636%
  #   NPS = 45.4545 - 36.3636 = 9.0909
  v <- c(10, 9, 9, 8, 7, 6, 0, 3, 10, 5)
  w <- c(2, 1, 1, 1, 1, 1, 1, 1, 1, 1)
  r <- calculate_nps_score(v, w)
  expect_equal(r$promoters_pct, 500 / 11)
  expect_equal(r$passives_pct, 200 / 11)
  expect_equal(r$detractors_pct, 400 / 11)
  expect_equal(r$nps, 100 / 11)
  expect_equal(r$n_unweighted, 10)
})

test_that("NPS matches survey::svymean of per-respondent +100 / 0 / -100", {
  skip_if_not(has_survey, "survey package not installed")
  set.seed(7)
  v <- sample(0:10, 40, replace = TRUE)
  for (set_name in names(ref_weight_sets())) {
    w <- ref_weight_sets()[[set_name]]
    score <- ifelse(v >= 9, 100, ifelse(v <= 6, -100, 0))
    ref <- stats::coef(survey::svymean(~score, svy_design(data.frame(score, w))))
    expect_equal(calculate_nps_score(v, w)$nps, unname(ref),
                 tolerance = 1e-10, info = set_name)
  }
})


# ==============================================================================
# THE THREE WAVE-ON-WAVE TESTS
# ==============================================================================

test_that("two-proportion z-test matches prop.test without continuity correction", {
  # 40 / 100 against 39 / 75. Pooled p = 79 / 175 = 0.451429.
  # SE = sqrt(0.451429 * 0.548571 * (1/100 + 1/75)) = 0.076003
  # z  = (0.52 - 0.40) / 0.076003 = 1.5789, two-sided p = 0.1144
  z <- z_test_for_proportions(0.40, 100, 0.52, 75)
  ref <- stats::prop.test(c(40, 39), c(100, 75), correct = FALSE)
  expect_equal(z$p_value, ref$p.value, tolerance = 1e-10)
  expect_equal(z$z_stat^2, unname(ref$statistic), tolerance = 1e-10)
  expect_equal(z$z_stat, 0.12 / sqrt((79 / 175) * (96 / 175) * (1 / 100 + 1 / 75)))
})

test_that("pooled t-test matches t.test(var.equal = TRUE) from summary stats", {
  set.seed(11)
  x1 <- sample(1:5, 45, replace = TRUE)
  x2 <- sample(2:5, 38, replace = TRUE)
  t <- t_test_for_means(mean(x1), stats::sd(x1), 45, mean(x2), stats::sd(x2), 38)
  ref <- stats::t.test(x2, x1, var.equal = TRUE)
  expect_equal(t$t_stat, unname(ref$statistic), tolerance = 1e-10)
  expect_equal(t$p_value, ref$p.value, tolerance = 1e-10)
  expect_equal(t$df, unname(ref$parameter))
})

test_that("pooled t-test accepts a fractional effective n without rounding", {
  # n1 = 30.4, n2 = 41.7: df = 70.1. Written out:
  #   pooled var = (29.4 * 1.1^2 + 40.7 * 0.9^2) / 70.1 = 0.977789
  #   SE = sqrt(0.977789 * (1/30.4 + 1/41.7)) = 0.235965
  #   t  = (3.6 - 3.2) / SE
  t <- t_test_for_means(3.2, 1.1, 30.4, 3.6, 0.9, 41.7)
  pooled <- (29.4 * 1.1^2 + 40.7 * 0.9^2) / 70.1
  se <- sqrt(pooled * (1 / 30.4 + 1 / 41.7))
  expect_equal(t$df, 70.1)
  expect_equal(t$t_stat, 0.4 / se)
  expect_equal(t$p_value, 2 * stats::pt(-abs(0.4 / se), 70.1))
})

nps_wave <- function(nps, pp, pd, eff_n) {
  list(available = TRUE, nps = nps, promoters_pct = pp, detractors_pct = pd,
       eff_n = eff_n, n_unweighted = round(eff_n))
}

test_that("NPS z-test uses the multinomial closed form, by hand", {
  # Wave A: 40% promoters, 25% detractors, NPS 15, effective n 120
  # Wave B: 48% promoters, 20% detractors, NPS 28, effective n 95.5
  # Var(NPS) = 10000 * ((pp + pd) - (pp - pd)^2) / n
  #   A: 10000 * (0.65 - 0.0225) / 120  = 52.2917
  #   B: 10000 * (0.68 - 0.0784) / 95.5 = 62.9948
  # z = 13 / sqrt(115.2865) = 1.21076
  waves <- list(A = nps_wave(15, 40, 25, 120), B = nps_wave(28, 48, 20, 95.5))
  sig <- perform_significance_tests_nps(waves, c("A", "B"), list(settings = list()))
  var_a <- 10000 * (0.65 - 0.15^2) / 120
  var_b <- 10000 * (0.68 - 0.28^2) / 95.5
  expect_equal(sig$A_vs_B$z_statistic, 13 / sqrt(var_a + var_b))
  expect_equal(sig$A_vs_B$p_value, 2 * (1 - stats::pnorm(13 / sqrt(var_a + var_b))))

  # The Dashboard runs its own copy of this test; it must give the same p.
  dash <- calculate_pairwise_significance(waves$A, waves$B, "nps")
  expect_equal(dash$p_value, sig$A_vs_B$p_value, tolerance = 1e-12)
})

test_that("NPS closed-form variance equals the variance of +100 / 0 / -100 scores", {
  # The closed form is the population variance of the per-respondent score.
  # 20 respondents: 8 promoters, 7 passives, 5 detractors.
  score <- c(rep(100, 8), rep(0, 7), rep(-100, 5))
  pop_var <- mean((score - mean(score))^2)
  expect_equal(10000 * ((0.40 + 0.25) - (0.40 - 0.25)^2), pop_var)
})


# ==============================================================================
# MINIMUM BASE: effective n exactly at and just under the threshold
# ==============================================================================

prop_wave <- function(pct, eff_n) {
  list(available = TRUE, proportions = c(Yes = pct), eff_n = eff_n,
       n_unweighted = ceiling(eff_n))
}

test_that("a pair tests at effective n 30 and not at 29.99, trend and Dashboard alike", {
  cfg <- list(settings = list(minimum_base = 30))
  at <- list(A = prop_wave(20, 30), B = prop_wave(60, 30))
  under <- list(A = prop_wave(20, 29.99), B = prop_wave(60, 30))

  trend_at <- perform_significance_tests_proportions(at, c("A", "B"), cfg, "Yes")
  trend_under <- perform_significance_tests_proportions(under, c("A", "B"), cfg, "Yes")
  expect_false(is.null(trend_at$A_vs_B$p_value))
  expect_true(trend_at$A_vs_B$significant)
  expect_identical(trend_under$A_vs_B$reason, "insufficient_base_or_unavailable")

  dash_at <- calculate_pairwise_significance(at$A, at$B, "proportions", min_base = 30)
  dash_under <- calculate_pairwise_significance(under$A, under$B, "proportions", min_base = 30)
  expect_equal(dash_at$p_value, trend_at$A_vs_B$p_value, tolerance = 1e-12)
  expect_equal(dash_at$sig_code, 1)
  expect_true(is.na(dash_under$p_value))
  expect_equal(dash_under$sig_code, 0)
})

test_that("the base gate reads effective n, not the weighted total", {
  # Grossed weights put the weighted total in the millions. The gate must
  # still refuse a pair whose effective base is 20.
  cfg <- list(settings = list(minimum_base = 30))
  waves <- list(A = c(prop_wave(20, 20), list(n_weighted = 1.2e6)),
                B = c(prop_wave(60, 20), list(n_weighted = 1.2e6)))
  trend <- perform_significance_tests_proportions(waves, c("A", "B"), cfg, "Yes")
  expect_identical(trend$A_vs_B$reason, "insufficient_base_or_unavailable")
  dash <- calculate_pairwise_significance(waves$A, waves$B, "proportions", min_base = 30)
  expect_equal(dash$sig_code, 0)
})


# ==============================================================================
# THROUGH THE CALCULATORS: grossed weights change nothing a client sees
# ==============================================================================

ref_setup <- function(wave_frames, mapping) {
  wave_ids <- names(wave_frames)
  config <- list(
    waves = data.frame(WaveID = wave_ids, stringsAsFactors = FALSE),
    settings = list(minimum_base = 30, alpha = 0.05)
  )
  qmap <- suppressMessages(capture.output(
    m <- build_question_map_index(mapping, config)))
  list(config = config, question_map = m, wave_data = wave_frames)
}

two_wave_choice <- function(weight_fun) {
  set.seed(21)
  mk <- function(p_yes) {
    v <- sample(c("Yes", "No"), 80, replace = TRUE, prob = c(p_yes, 1 - p_yes))
    data.frame(Q1 = v, weight_var = weight_fun(80), stringsAsFactors = FALSE)
  }
  frames <- list(W1 = mk(0.35), W2 = mk(0.60))
  mapping <- data.frame(QuestionCode = "AWARE", QuestionText = "Aware?",
                        QuestionType = "Single_Response", TrackingSpecs = "category:Yes",
                        W1 = "Q1", W2 = "Q1", stringsAsFactors = FALSE)
  ref_setup(frames, mapping)
}

test_that("single-choice trend: grossed weights give the same %, n_eff and p-value", {
  deff2 <- function(n) rep(c(0.1, 5), length.out = n)
  grossed <- function(n) deff2(n) * 250000
  a <- two_wave_choice(deff2)
  b <- two_wave_choice(grossed)
  capture.output({
    ra <- calculate_single_choice_trend_enhanced("AWARE", a$question_map, a$wave_data, a$config)
    rb <- calculate_single_choice_trend_enhanced("AWARE", b$question_map, b$wave_data, b$config)
  })
  for (wid in c("W1", "W2")) {
    expect_equal(ra$wave_results[[wid]]$proportions[["Yes"]],
                 rb$wave_results[[wid]]$proportions[["Yes"]], tolerance = 1e-12)
    expect_equal(ra$wave_results[[wid]]$eff_n, rb$wave_results[[wid]]$eff_n,
                 tolerance = 1e-12)
  }
  expect_equal(ra$significance$Yes$W1_vs_W2$p_value,
               rb$significance$Yes$W1_vs_W2$p_value, tolerance = 1e-12)

  # And the p-value is the hand z-test on the Kish bases, not on the raw 80.
  w1 <- ra$wave_results$W1; w2 <- ra$wave_results$W2
  expect_equal(w1$eff_n, kish(deff2(80)))
  z <- z_test_for_proportions(w1$proportions[["Yes"]] / 100, w1$eff_n,
                              w2$proportions[["Yes"]] / 100, w2$eff_n)
  expect_equal(ra$significance$Yes$W1_vs_W2$p_value, z$p_value)
})


# ==============================================================================
# COMPOSITE: row mean by hand, then a weighted mean
# ==============================================================================

test_that("composite score is the per-respondent mean of its sources", {
  # Respondent 1: (4 + 2 + 3) / 3 = 3
  # Respondent 2: (5 + NA + 4) / 2 = 4.5   (a missing source is skipped)
  # Respondent 3: all missing -> NA        (not 0, not NaN)
  df <- data.frame(A = c(4, 5, NA), B = c(2, NA, NA), C = c(3, 4, NA))
  mapping <- data.frame(QuestionCode = c("SA", "SB", "SC"),
                        QuestionType = "Rating",
                        W1 = c("A", "B", "C"), stringsAsFactors = FALSE)
  s <- ref_setup(list(W1 = df), mapping)
  capture.output(
    comp <- calculate_composite_values_per_respondent(df, "W1", c("SA", "SB", "SC"),
                                                      s$question_map))
  expect_equal(comp, c(3, 4.5, NA))
})


# ==============================================================================
# WEIGHT COLUMN MISSING FROM A WAVE (Duncan, 24 Sep 2026: run unweighted, warn)
# ==============================================================================

test_that("a wave without its weight column runs unweighted and says so", {
  df <- data.frame(Q1 = 1:5)
  out <- capture.output(res <- apply_wave_weights(df, "wgt_typo", "W2"))
  expect_equal(res$weight_var, rep(1, 5))
  expect_true(any(grepl("wgt_typo", out) & grepl("W2", out) & grepl("unweighted", out)))
})
