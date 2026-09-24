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

test_that("mean trend t-test on unit weights equals t.test(var.equal = FALSE)", {
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
  ref <- stats::t.test(x2, x1, var.equal = FALSE)
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

test_that("Welch t-test matches t.test(var.equal = FALSE) from summary stats", {
  # Duncan, 24 Sep 2026: means are tested with Welch's test, the more
  # defensible choice when two waves' spreads differ.
  set.seed(11)
  x1 <- sample(1:5, 45, replace = TRUE)
  x2 <- sample(2:5, 38, replace = TRUE)
  t <- t_test_for_means(mean(x1), stats::sd(x1), 45, mean(x2), stats::sd(x2), 38)
  ref <- stats::t.test(x2, x1, var.equal = FALSE)
  expect_equal(t$t_stat, unname(ref$statistic), tolerance = 1e-10)
  expect_equal(t$p_value, ref$p.value, tolerance = 1e-10)
  expect_equal(t$df, unname(ref$parameter), tolerance = 1e-10)
})

test_that("Welch t-test accepts a fractional effective n, by hand", {
  # n1 = 30.4, n2 = 41.7, SDs 1.1 and 0.9. Written out:
  #   v1 = 1.1^2 / 30.4 = 0.039803,  v2 = 0.9^2 / 41.7 = 0.019424
  #   SE = sqrt(v1 + v2) = 0.243366
  #   t  = (3.6 - 3.2) / SE = 1.64361
  #   df = (v1 + v2)^2 / (v1^2 / 29.4 + v2^2 / 40.7) = 55.5421
  t <- t_test_for_means(3.2, 1.1, 30.4, 3.6, 0.9, 41.7)
  v1 <- 1.1^2 / 30.4; v2 <- 0.9^2 / 41.7
  df <- (v1 + v2)^2 / (v1^2 / 29.4 + v2^2 / 40.7)
  expect_equal(t$t_stat, 0.4 / sqrt(v1 + v2))
  expect_equal(t$df, df)
  expect_equal(t$p_value, 2 * stats::pt(-abs(0.4 / sqrt(v1 + v2)), df))
  expect_equal(round(t$t_stat, 4), 1.6436)
  expect_equal(round(t$df, 4), 55.5421)
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
  expect_true(is.na(dash_under$sig_code))
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
  expect_true(is.na(dash$sig_code))
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


# ==============================================================================
# MULTI-MENTION: base is the respondents who answered the question
# ==============================================================================
# Duncan, 24 Sep 2026: the base is "answered the question at all" (any of its
# option columns non-missing), the rule tabs uses (tracking_wave_values.R).
# Respondents routed past the question are NOT in the base.

mm_frames <- function() {
  # 100 respondents per wave. Rows 1-60 were asked (0 / 1 answers); rows
  # 61-100 were routed past the question (NA in every option column).
  # Option 2 was hidden from rows 1-10 (NA there), as when an option is
  # masked: those 10 still answered, so they stay in the base.
  mk <- function(n_opt1, n_opt2) {
    asked <- 60
    q_1 <- c(rep(1, n_opt1), rep(0, asked - n_opt1), rep(NA, 40))
    q_2 <- c(rep(NA, 10), rep(0, asked - n_opt2 - 10), rep(1, n_opt2), rep(NA, 40))
    q_3 <- c(rep(0, asked), rep(NA, 40))
    data.frame(Q5_1 = q_1, Q5_2 = q_2, Q5_3 = q_3, weight_var = 1)
  }
  list(W1 = mk(30, 15), W2 = mk(42, 15))
}

mm_setup <- function(specs) {
  mapping <- data.frame(QuestionCode = "CHANNELS", QuestionText = "Channels used",
                        QuestionType = "Multi_Mention", TrackingSpecs = specs,
                        W1 = "Q5", W2 = "Q5", stringsAsFactors = FALSE)
  ref_setup(mm_frames(), mapping)
}

test_that("multi-mention option % is out of those who answered, by hand", {
  # Wave 1: 30 of the 60 asked chose option 1 -> 50%   (not 30 / 100)
  #         15 of 60 chose option 2           -> 25%
  # Wave 2: 42 of 60 chose option 1           -> 70%
  # Base 60 in both waves, so the z-test is 0.50 vs 0.70 on n = 60 each.
  s <- mm_setup("auto,any,count_mean")
  capture.output(r <- calculate_multi_mention_trend("CHANNELS", s$question_map,
                                                    s$wave_data, s$config))
  expect_equal(r$wave_results$W1$mention_proportions$Q5_1, 50)
  expect_equal(r$wave_results$W1$mention_proportions$Q5_2, 25)
  expect_equal(r$wave_results$W2$mention_proportions$Q5_1, 70)
  expect_equal(r$wave_results$W1$n_unweighted, 60)
  expect_equal(r$wave_results$W1$eff_n, 60)
  z <- z_test_for_proportions(0.50, 60, 0.70, 60)
  expect_equal(r$significance$Q5_1$W1_vs_W2$p_value, z$p_value)

  # Any mention, wave 1: option 1 rows 1-30, option 2 rows 46-60 -> 45 of 60
  # = 75%. Mean number of mentions: (30 + 15) / 60 = 0.75.
  expect_equal(r$wave_results$W1$additional_metrics$any_mention_pct, 75)
  expect_equal(r$wave_results$W1$additional_metrics$count_mean, 0.75)
})

test_that("tracking one option still uses the whole question to find the base", {
  # option:Q5_2 only. Whether a respondent answered is read from ALL of the
  # question's columns, so the base is still 60 and option 2 is 15 / 60 = 25%.
  # Judged on Q5_2 alone the 10 who never saw option 2 would drop out: 15 / 50.
  s <- mm_setup("option:Q5_2")
  capture.output(r <- calculate_multi_mention_trend("CHANNELS", s$question_map,
                                                    s$wave_data, s$config))
  expect_equal(r$wave_results$W1$mention_proportions$Q5_2, 25)
  expect_equal(r$wave_results$W1$n_unweighted, 60)
})

test_that("text-coded multi-mention (category:) uses the answered base, by hand", {
  # Alchemer style: a column holds the option text when chosen, blank when
  # not. read.csv gives "" for a blank cell, so blanks are "" or NA here.
  # 50 respondents chose something; 30 were routed past (all blank).
  #   "Email" chosen by 20 of the 50 who answered -> 40%
  n_ans <- 50
  df <- data.frame(
    Q9_1 = c(rep("Email", 20), rep("", n_ans - 20), rep("", 30)),
    Q9_2 = c(rep("", 20), rep("Phone", n_ans - 20), rep(NA, 30)),
    weight_var = 1, stringsAsFactors = FALSE)
  mapping <- data.frame(QuestionCode = "CONTACT", QuestionText = "Contact",
                        QuestionType = "Multi_Mention", TrackingSpecs = "category:Email",
                        W1 = "Q9", W2 = "Q9", stringsAsFactors = FALSE)
  s <- ref_setup(list(W1 = df, W2 = df), mapping)
  capture.output(r <- calculate_multi_mention_trend("CONTACT", s$question_map,
                                                    s$wave_data, s$config))
  expect_equal(r$wave_results$W1$mention_proportions$Email, 40)
  expect_equal(r$wave_results$W1$n_unweighted, 50)
})


# ==============================================================================
# TOP / BOTTOM BOX: the scale comes from the Survey_Structure, not the data
# ==============================================================================
# Duncan, 24 Sep 2026: top box is the top of the SCALE, taken from the
# StructureFile's Index_Weight. With no scale defined the question is refused
# (range:4-5 is the way to name a box without a structure). A wave where
# nobody chose the top point must show 0%, not the share at the highest point
# anyone happened to choose.

rating_structure <- function(code = "Q7") {
  data.frame(QuestionCode = code,
             OptionText = c("1", "2", "3", "4", "5", "Don't know"),
             DisplayText = c("1", "2", "3", "4", "5", "Don't know"),
             Index_Weight = c(1, 2, 3, 4, 5, NA),
             BoxCategory = NA_character_, stringsAsFactors = FALSE)
}

test_that("top box counts the top of the scale even when nobody chose it", {
  # 10 answered 4, 10 answered 3, nobody 5, on a 1-5 scale.
  #   top box   (5)    = 0 / 20  = 0%
  #   top-2 box (4, 5) = 10 / 20 = 50%
  #   bottom-2  (1, 2) = 0 / 20  = 0%
  v <- c(rep(4, 10), rep(3, 10))
  w <- rep(1, 20)
  expect_equal(calculate_top_box(v, w, 1, scale_values = 1:5)$proportion, 0)
  expect_equal(calculate_top_box(v, w, 2, scale_values = 1:5)$proportion, 50)
  expect_equal(calculate_bottom_box(v, w, 2, scale_values = 1:5)$proportion, 0)
})

test_that("top box is refused when no scale is given", {
  expect_error(calculate_top_box(c(4, 5), c(1, 1), 1), class = "turas_refusal")
  expect_error(calculate_bottom_box(c(4, 5), c(1, 1), 1), class = "turas_refusal")
})

rating_two_wave <- function(specs, with_structure = TRUE) {
  frames <- list(
    W1 = data.frame(Q7 = c(rep(5, 12), rep(4, 18), rep(3, 10)), weight_var = 1),
    W2 = data.frame(Q7 = c(rep(4, 25), rep(3, 15)), weight_var = 1)  # no 5s
  )
  mapping <- data.frame(QuestionCode = "SAT", QuestionText = "Satisfaction",
                        QuestionType = "Rating", TrackingSpecs = specs,
                        W1 = "Q7", W2 = "Q7", stringsAsFactors = FALSE)
  s <- ref_setup(frames, mapping)
  s$wave_structures <- if (with_structure) {
    list(W1 = rating_structure(), W2 = rating_structure())
  } else NULL
  s
}

test_that("rating trend: top box uses the structure's scale in every wave", {
  # W1: 12 of 40 chose 5 -> 30%; top-2 = (12 + 18) / 40 = 75%
  # W2: nobody chose 5  -> 0%;  top-2 = 25 / 40 = 62.5%
  # The change in top box is -30 points, tested as 0.30 vs 0.00 on n = 40.
  s <- rating_two_wave("top_box,top2_box")
  capture.output(r <- calculate_rating_trend_enhanced("SAT", s$question_map, s$wave_data,
                                                      s$config, s$wave_structures))
  expect_equal(r$wave_results$W1$metrics$top_box, 30)
  expect_equal(r$wave_results$W2$metrics$top_box, 0)
  expect_equal(r$wave_results$W1$metrics$top2_box, 75)
  expect_equal(r$wave_results$W2$metrics$top2_box, 62.5)
  expect_equal(r$significance$top_box$W1_vs_W2$p_value,
               z_test_for_proportions(0.30, 40, 0, 40)$p_value)
})

test_that("rating trend: top box with no StructureFile is refused, the mean still ships", {
  # Duncan, 24 Sep 2026: refuse the box, not the question. The mean is
  # reported, the box is blank, and the result names the refused spec so the
  # run finishes PARTIAL.
  s <- rating_two_wave("mean,top_box", with_structure = FALSE)
  capture.output(res <- dispatch_single_trend("SAT", s$question_map, s$wave_data,
                                              s$config, NULL))
  expect_null(res$skipped)
  r <- res$result
  expect_equal(r$wave_results$W2$metrics$mean, (25 * 4 + 15 * 3) / 40)
  expect_true(is.na(r$wave_results$W2$metrics$top_box))
  expect_identical(r$refused_specs, "top_box")
})

test_that("the refused box is named on the console with the fix", {
  s <- rating_two_wave("mean,top2_box", with_structure = FALSE)
  out <- capture.output(calculate_rating_trend_enhanced("SAT", s$question_map, s$wave_data,
                                                        s$config, NULL))
  expect_true(any(grepl("CFG_BOX_SCALE_UNKNOWN", out)))
  expect_true(any(grepl("top2_box", out)))
  expect_true(any(grepl("range:", out)))
})

test_that("calculate_all_trends finishes PARTIAL and lists the refused box", {
  s <- rating_two_wave("mean,top_box", with_structure = FALSE)
  s$config$tracked_questions <- data.frame(QuestionCode = "SAT", stringsAsFactors = FALSE)
  capture.output(suppressMessages(
    all <- calculate_all_trends(s$config, s$question_map, s$wave_data, wave_structures = NULL)))
  expect_identical(all$run_status, "PARTIAL")
  expect_identical(all$refused_metrics$SAT, "top_box")
  expect_false(is.null(all$trends$SAT))
})

test_that("rating trend: mean alone needs no structure", {
  s <- rating_two_wave("mean", with_structure = FALSE)
  capture.output(r <- calculate_rating_trend_enhanced("SAT", s$question_map, s$wave_data,
                                                      s$config, NULL))
  expect_equal(r$wave_results$W2$metrics$mean, (25 * 4 + 15 * 3) / 40)
})

test_that("bottom box through the calculator uses the scale's bottom points", {
  # W1 answers are 3, 4, 5 only. On the 1-5 scale bottom-2 is {1, 2}: 0%.
  # Read from the data it would be {3, 4}: 70%.
  s <- rating_two_wave("bottom2_box")
  capture.output(r <- calculate_rating_trend_enhanced("SAT", s$question_map, s$wave_data,
                                                      s$config, s$wave_structures))
  expect_equal(r$wave_results$W1$metrics$bottom2_box, 0)
})

test_that("top box on a composite is refused: a row mean has no scale points", {
  df <- data.frame(Q7 = c(5, 4, 3, 4), Q8 = c(4, 4, 2, 5), weight_var = 1)
  mapping <- data.frame(
    QuestionCode = c("SAT", "VAL", "IDX"), QuestionText = c("Sat", "Value", "Index"),
    QuestionType = c("Rating", "Rating", "Composite"),
    TrackingSpecs = c("mean", "mean", "mean,top_box"),
    SourceQuestions = c(NA, NA, "SAT,VAL"),
    W1 = c("Q7", "Q8", "IDX"), W2 = c("Q7", "Q8", "IDX"), stringsAsFactors = FALSE)
  s <- ref_setup(list(W1 = df, W2 = df), mapping)
  structs <- list(W1 = rating_structure("Q7"), W2 = rating_structure("Q7"))
  capture.output(res <- dispatch_single_trend("IDX", s$question_map, s$wave_data,
                                              s$config, structs))
  # Composite scores (4.5, 4, 2.5, 4.5) average 3.875; the box is refused
  expect_equal(res$result$wave_results$W1$metrics$mean, 3.875)
  expect_true(is.na(res$result$wave_results$W1$metrics$top_box))
  expect_identical(res$result$refused_specs, "top_box")
})


# ==============================================================================
# RANGE: an interval, so it holds for composite scores and half points
# ==============================================================================

test_that("range:4-5 counts every score from 4 to 5 inclusive, by hand", {
  # Composite scores (row means) 4, 4.5, 3.667, 5, 2 with equal weight.
  # In 4-5: 4, 4.5, 5 -> 3 / 5 = 60%. Integer matching would give 2 / 5.
  v <- c(4, 4.5, 11 / 3, 5, 2)
  expect_equal(calculate_custom_range(v, rep(1, 5), "4-5")$proportion, 60)
  # Integer data is unchanged: 1-5 answers 2, 4, 5, 5 -> 3 / 4 in 4-5.
  expect_equal(calculate_custom_range(c(2, 4, 5, 5), rep(1, 4), "range:4-5")$proportion, 75)
  # A half-point bound: 3.5-5 on 3, 3.5, 4, 5 -> 3 / 4.
  expect_equal(calculate_custom_range(c(3, 3.5, 4, 5), rep(1, 4), "3.5-5")$proportion, 75)
})


# ==============================================================================
# DON'T KNOW CODES: an option flagged ExcludeFromIndex = Y is not an answer
# ==============================================================================
# Tabs drops ExcludeFromIndex = Y options from a mean (cell_calculator.R,
# calculate_rating_mean). When the data holds numeric codes, a 99 "Don't know"
# must leave the mean, the NPS and the boxes, not be averaged in.

dk_structure <- function(code, points) {
  data.frame(QuestionCode = code,
             OptionText = c(as.character(points), "99"),
             DisplayText = c(as.character(points), "Don't know"),
             Index_Weight = c(points, NA),
             BoxCategory = NA_character_,
             ExcludeFromIndex = c(rep(NA, length(points)), "Y"),
             stringsAsFactors = FALSE)
}

test_that("a numeric don't-know code is dropped from the mean and the boxes", {
  # Answers 5, 4, 99, 3, 99 on a 1-5 scale; 99 = Don't know.
  #   mean over the three real answers = (5 + 4 + 3) / 3 = 4
  #   top box = 1 / 3 = 33.33%   (99 is neither in the box nor the base)
  frames <- list(W1 = data.frame(Q7 = c(5, 4, 99, 3, 99), weight_var = 1),
                 W2 = data.frame(Q7 = c(5, 4, 99, 3, 99), weight_var = 1))
  mapping <- data.frame(QuestionCode = "SAT", QuestionText = "Sat", QuestionType = "Rating",
                        TrackingSpecs = "mean,top_box", W1 = "Q7", W2 = "Q7",
                        stringsAsFactors = FALSE)
  s <- ref_setup(frames, mapping)
  st <- list(W1 = dk_structure("Q7", 1:5), W2 = dk_structure("Q7", 1:5))
  capture.output(r <- calculate_rating_trend_enhanced("SAT", s$question_map, s$wave_data,
                                                      s$config, st))
  expect_equal(r$wave_results$W1$metrics$mean, 4)
  expect_equal(r$wave_results$W1$metrics$top_box, 100 / 3)
  expect_equal(r$wave_results$W1$n_unweighted, 3)
})

test_that("a numeric don't-know code is not an NPS promoter", {
  # Answers 10, 9, 99, 3 on 0-10; 99 = Don't know. Of the three real
  # answers: promoters 2, detractors 1 -> NPS = (2 - 1) / 3 = 33.33.
  frames <- list(W1 = data.frame(Q15 = c(10, 9, 99, 3), weight_var = 1),
                 W2 = data.frame(Q15 = c(10, 9, 99, 3), weight_var = 1))
  mapping <- data.frame(QuestionCode = "REC", QuestionText = "Recommend", QuestionType = "NPS",
                        W1 = "Q15", W2 = "Q15", stringsAsFactors = FALSE)
  s <- ref_setup(frames, mapping)
  st <- list(W1 = dk_structure("Q15", 0:10), W2 = dk_structure("Q15", 0:10))
  capture.output(r <- calculate_nps_trend("REC", s$question_map, s$wave_data, s$config, st))
  expect_equal(r$wave_results$W1$nps, 100 / 3)
  expect_equal(r$wave_results$W1$n_unweighted, 3)
})

test_that("a don't-know option with an Index_Weight is still not a scale point", {
  st <- dk_structure("Q7", 1:5)
  st$Index_Weight[st$OptionText == "99"] <- 99
  expect_equal(get_question_scale(st, "Q7"), 1:5)
})

test_that("a composite drops its sources' don't-know codes, by hand", {
  # Respondent 1: A = 4, B = 99 (DK) -> composite 4 (B skipped)
  # Respondent 2: A = 2, B = 4       -> composite 3
  df <- data.frame(QA = c(4, 2), QB = c(99, 4), weight_var = 1)
  mapping <- data.frame(QuestionCode = c("SA", "SB"), QuestionType = "Rating",
                        W1 = c("QA", "QB"), stringsAsFactors = FALSE)
  s <- ref_setup(list(W1 = df), mapping)
  st <- rbind(dk_structure("QA", 1:5), dk_structure("QB", 1:5))
  capture.output(
    comp <- calculate_composite_values_per_respondent(df, "W1", c("SA", "SB"),
                                                      s$question_map, st))
  expect_equal(comp, c(4, 3))
})

test_that("a text don't-know answer is dropped even if its option has an Index_Weight", {
  st <- dk_structure("Q7", 1:5)
  st$OptionText[st$OptionText == "99"] <- "Don't know"
  st$Index_Weight[st$OptionText == "Don't know"] <- 99
  expect_equal(resolve_question_values(c("5", "Don't know", "2"), st, "Q7"), c(5, NA, 2))
})


# ==============================================================================
# SINGLE CHOICE "all": answers in questionnaire order (Duncan, 24 Sep 2026)
# ==============================================================================
# The tracked answers were ordered as they first appeared in the data, so the
# Dashboard headline (the first answer) could be any of them ("Café"
# rather than "Yes"). With a StructureFile the order is the questionnaire's;
# answers it does not list follow in data order.

test_that("single-choice answers follow the structure's option order", {
  frames <- list(
    W1 = data.frame(Q20 = c("Maybe", "No", "Yes", "Other", "Yes", "No"), weight_var = 1,
                    stringsAsFactors = FALSE),
    W2 = data.frame(Q20 = c("No", "Yes", "Maybe", "Yes"), weight_var = 1,
                    stringsAsFactors = FALSE))
  mapping <- data.frame(QuestionCode = "AWARE", QuestionText = "Aware", QuestionType = "Single_Response",
                        TrackingSpecs = "all", W1 = "Q20", W2 = "Q20", stringsAsFactors = FALSE)
  s <- ref_setup(frames, mapping)
  st <- data.frame(QuestionCode = "Q20", OptionText = c("Yes", "No", "Maybe"),
                   DisplayText = c("Yes", "No", "Maybe"), Index_Weight = NA_real_,
                   BoxCategory = NA_character_, ExcludeFromIndex = NA_character_,
                   stringsAsFactors = FALSE)
  capture.output(r <- calculate_single_choice_trend_enhanced("AWARE", s$question_map, s$wave_data,
                                                             s$config, list(W1 = st, W2 = st)))
  expect_identical(as.character(r$response_codes), c("Yes", "No", "Maybe", "Other"))
  # Without a structure the data order stands
  capture.output(r0 <- calculate_single_choice_trend_enhanced("AWARE", s$question_map, s$wave_data,
                                                              s$config, NULL))
  expect_identical(as.character(r0$response_codes), c("Maybe", "No", "Yes", "Other"))
})
