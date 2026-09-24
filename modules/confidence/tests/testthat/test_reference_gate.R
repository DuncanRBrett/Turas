# ==============================================================================
# REFERENCE GATE - Confidence Module
# ==============================================================================
# Every headline number the module prints, checked against a calculation that
# shares no Turas code: base R (prop.test, t.test, cov.wt, weighted.mean,
# qbeta), the survey package, the boot package, or arithmetic written out in
# the test. Robustness programme, gate 1 (24 Sep 2026).
#
# The numbers are produced by the same functions the pipeline calls
# (process_proportion_question and its siblings), so a check here is a check
# on what reaches the workbook, not on a helper nobody ships.
#
# THE BALANCED FIXTURE
#   y  = rep(c(1, 1, 0), 20)          n = 60, 40 successes
#   w  = rep(c(0.5, 1, 1.5, 2), 15)   n_eff = (sum w)^2 / sum w^2
#                                           = 75^2 / 112.5 = 50 exactly
# Over each block of 12 rows the successes carry every weight twice and the
# failures every weight once, so the weight mix is the same in both groups.
# On such a fixture survey's linearisation variance equals the Kish variance
# times n / (n - 1) exactly. On an unbalanced fixture it does not, and the
# survey check there is a tolerance bracket, not an equality.
# ==============================================================================

library(testthat)

ref_config <- function(conf_level = 0.95, boot_iter = 1000, seed = NULL) {
  ss <- list(Confidence_Level = conf_level, Bootstrap_Iterations = boot_iter)
  if (!is.null(seed)) ss$random_seed <- seed
  list(study_settings = ss)
}

ref_q_row <- function(q_id, categories = NA, run_moe = "Y", run_wilson = "N",
                      run_bootstrap = "N", run_credible = "N",
                      prior_mean = NA, prior_sd = NA, prior_n = NA,
                      promoters = NA, detractors = NA) {
  data.frame(
    Question_ID = q_id, Statistic_Type = "x", Categories = categories,
    Promoter_Codes = promoters, Detractor_Codes = detractors,
    Run_MOE = run_moe, Run_Wilson = run_wilson,
    Run_Bootstrap = run_bootstrap, Run_Credible = run_credible,
    Prior_Mean = prior_mean, Prior_SD = prior_sd, Prior_N = prior_n,
    stringsAsFactors = FALSE
  )
}

balanced_data <- function() {
  data.frame(
    y   = rep(c(1, 1, 0), 20),
    sat = rep(c(3, 4, 5, 5, 2), 12),
    nps = rep(c(10, 9, 8, 7, 6, 3), 10),
    w   = rep(c(0.5, 1, 1.5, 2), 15)
  )
}

z95 <- qnorm(0.975)   # 1.959964


# ------------------------------------------------------------------------------
# PROPORTIONS
# ------------------------------------------------------------------------------

test_that("unweighted Wilson matches prop.test(correct = FALSE)", {
  d <- balanced_data()
  out <- process_proportion_question(
    ref_q_row("y", categories = "1", run_wilson = "Y"), d, NULL, ref_config())
  ref <- prop.test(40, 60, correct = FALSE)$conf.int
  # prop.test's uncorrected interval IS the Wilson score interval
  expect_equal(out$result$proportion, 40 / 60)
  expect_equal(out$result$wilson$lower, ref[1], tolerance = 1e-10)
  expect_equal(out$result$wilson$upper, ref[2], tolerance = 1e-10)
})

test_that("unweighted normal MOE matches the hand formula and survey", {
  d <- balanced_data()
  out <- process_proportion_question(ref_q_row("y", categories = "1"), d, NULL, ref_config())
  # p = 2/3, SE = sqrt(p(1-p)/n) = sqrt((2/9)/60) = 0.06085806
  se_hand <- sqrt((2 / 3) * (1 / 3) / 60)
  expect_equal(out$result$moe$se, se_hand, tolerance = 1e-12)
  expect_equal(out$result$moe$moe, z95 * se_hand, tolerance = 1e-12)
  expect_equal(out$result$moe$lower, 2 / 3 - z95 * se_hand, tolerance = 1e-12)

  # survey divides by n - 1: its SE is sqrt(p(1-p)/59)
  des <- suppressWarnings(survey::svydesign(ids = ~1, data = d))
  se_svy <- as.numeric(survey::SE(survey::svymean(~y, des)))
  expect_equal(out$result$moe$se, se_svy * sqrt(59 / 60), tolerance = 1e-12)
})

test_that("weighted proportion, n_eff and normal MOE match Kish by hand and survey", {
  d <- balanced_data()
  out <- process_proportion_question(ref_q_row("y", categories = "1"), d, "w", ref_config())
  # Weighted p: per 12-row block the successes hold 2 x (0.5+1+1.5+2) = 10
  # of 15, so p = 2/3. n_eff = 75^2 / 112.5 = 50.
  expect_equal(out$result$proportion, 2 / 3, tolerance = 1e-12)
  expect_equal(out$result$n_eff, 50)
  se_hand <- sqrt((2 / 3) * (1 / 3) / 50)   # 0.06666667
  expect_equal(out$result$moe$se, se_hand, tolerance = 1e-12)

  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  est <- survey::svymean(~y, des)
  expect_equal(out$result$proportion, as.numeric(coef(est)), tolerance = 1e-12)
  # Balanced fixture: linearisation variance = Kish variance x n/(n-1)
  expect_equal(out$result$moe$se,
               as.numeric(survey::SE(est)) * sqrt(59 / 60), tolerance = 1e-10)
})

test_that("weighted Wilson uses the exact fractional n_eff (hand arithmetic)", {
  # Weights 1,1,3 per block of three: n_eff = 30 x 25/33 = 22.727..., not whole
  d <- data.frame(y = rep(c(1, 0, 1), 10), w = rep(c(1, 1, 3), 10))
  out <- process_proportion_question(
    ref_q_row("y", categories = "1", run_wilson = "Y"), d, "w", ref_config())
  p <- 40 / 50                             # successes weigh 1 + 3 of every 5
  n_eff <- 50^2 / 110                      # 22.7272...
  centre <- (p + z95^2 / (2 * n_eff)) / (1 + z95^2 / n_eff)
  half <- z95 * sqrt(p * (1 - p) / n_eff + z95^2 / (4 * n_eff^2)) / (1 + z95^2 / n_eff)
  expect_equal(out$result$proportion, p)
  expect_equal(out$result$n_eff, 23L)      # displayed, rounded
  expect_equal(out$result$wilson$lower, centre - half, tolerance = 1e-12)
  expect_equal(out$result$wilson$upper, centre + half, tolerance = 1e-12)
})

test_that("unweighted Bayesian proportion matches the conjugate Beta posterior", {
  d <- balanced_data()
  out <- process_proportion_question(
    ref_q_row("y", categories = "1", run_moe = "N", run_credible = "Y"), d, NULL, ref_config())
  # Beta(1,1) prior + 40 successes, 20 failures -> Beta(41, 21)
  expect_equal(out$result$bayesian$lower, qbeta(0.025, 41, 21), tolerance = 1e-12)
  expect_equal(out$result$bayesian$upper, qbeta(0.975, 41, 21), tolerance = 1e-12)
  expect_equal(out$result$bayesian$post_mean, 41 / 62, tolerance = 1e-12)
})

test_that("informed Bayesian proportion matches the conjugate Beta posterior", {
  d <- balanced_data()
  out <- process_proportion_question(
    ref_q_row("y", categories = "1", run_moe = "N", run_credible = "Y",
              prior_mean = 0.5, prior_n = 20), d, NULL, ref_config())
  # Prior Beta(0.5 x 20, 0.5 x 20) = Beta(10, 10); posterior Beta(50, 30)
  expect_equal(out$result$bayesian$lower, qbeta(0.025, 50, 30), tolerance = 1e-12)
  expect_equal(out$result$bayesian$upper, qbeta(0.975, 50, 30), tolerance = 1e-12)
})

test_that("proportion bootstrap agrees with boot::boot percentile interval", {
  set.seed(7)
  n <- 400
  y <- rbinom(n, 1, 0.3)
  w <- runif(n, 0.5, 2)
  d <- data.frame(y = y, w = w)
  cfg <- ref_config(boot_iter = 5000)
  out <- process_proportion_question(
    ref_q_row("y", categories = "1", run_moe = "Y", run_bootstrap = "Y"), d, "w", cfg)

  set.seed(99)
  b <- boot::boot(d, function(dd, i) sum(dd$w[i] * dd$y[i]) / sum(dd$w[i]), R = 5000)
  ref <- boot::boot.ci(b, type = "perc")$percent[4:5]
  # Two independent 5000-draw bootstraps: percentiles agree to about 0.01
  expect_equal(out$result$bootstrap$lower, ref[1], tolerance = 0.012 / ref[1])
  expect_equal(out$result$bootstrap$upper, ref[2], tolerance = 0.012 / ref[2])
  # Bootstrap spread tracks the design SE (survey), within 10%
  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  se_svy <- as.numeric(survey::SE(survey::svymean(~y, des)))
  expect_equal(out$result$bootstrap$boot_se, se_svy, tolerance = 0.10)
})


# ------------------------------------------------------------------------------
# MEANS
# ------------------------------------------------------------------------------

test_that("unweighted mean interval matches t.test exactly", {
  d <- balanced_data()
  out <- process_mean_question(ref_q_row("sat"), d, NULL, ref_config())
  tt <- t.test(d$sat)
  expect_equal(out$result$mean, mean(d$sat))
  expect_equal(out$result$sd, sd(d$sat))
  expect_equal(out$result$t_dist$lower, tt$conf.int[1], tolerance = 1e-12)
  expect_equal(out$result$t_dist$upper, tt$conf.int[2], tolerance = 1e-12)
  expect_equal(out$result$t_dist$df, 59)
})

test_that("weighted mean, SD and interval match weighted.mean, cov.wt and Kish", {
  d <- balanced_data()
  out <- process_mean_question(ref_q_row("sat"), d, "w", ref_config())
  wm <- weighted.mean(d$sat, d$w)
  # Unbiased reliability-weight SD: cov.wt(method = "unbiased")
  sd_ref <- sqrt(cov.wt(matrix(d$sat), wt = d$w / sum(d$w), method = "unbiased")$cov[1, 1])
  n_eff <- sum(d$w)^2 / sum(d$w^2)
  se_hand <- sd_ref / sqrt(n_eff)
  t_crit <- qt(0.975, df = n_eff - 1)
  expect_equal(out$result$mean, wm, tolerance = 1e-12)
  expect_equal(out$result$sd, sd_ref, tolerance = 1e-12)
  expect_equal(out$result$t_dist$se, se_hand, tolerance = 1e-12)
  expect_equal(out$result$t_dist$df, n_eff - 1, tolerance = 1e-12)
  expect_equal(out$result$t_dist$lower, wm - t_crit * se_hand, tolerance = 1e-12)
  expect_equal(out$result$t_dist$upper, wm + t_crit * se_hand, tolerance = 1e-12)

  # The weighted mean also matches survey. Its linearisation SE is a different
  # estimator from Kish on this (unbalanced for sat) fixture, so only a bracket.
  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  est <- survey::svymean(~sat, des)
  expect_equal(out$result$mean, as.numeric(coef(est)), tolerance = 1e-12)
  expect_equal(out$result$t_dist$se, as.numeric(survey::SE(est)), tolerance = 0.15)
})

test_that("weighted mean with fractional n_eff sizes df on the exact n_eff", {
  d <- data.frame(x = rep(c(2, 4, 7), 10), w = rep(c(1, 1, 3), 10))
  out <- process_mean_question(ref_q_row("x"), d, "w", ref_config())
  n_eff <- 50^2 / 110                      # 22.7272...
  expect_equal(out$result$t_dist$df, n_eff - 1, tolerance = 1e-12)
  expect_equal(out$result$n_eff, 23L)
})

test_that("Bayesian mean matches the normal-normal update by hand", {
  d <- balanced_data()
  # Flat prior: posterior N(mean, s^2 / n)
  out <- process_mean_question(
    ref_q_row("sat", run_moe = "N", run_credible = "Y"), d, NULL, ref_config())
  s2n <- var(d$sat) / 60
  expect_equal(out$result$bayesian$lower, mean(d$sat) - z95 * sqrt(s2n), tolerance = 1e-12)

  # Informed prior N(3, 1^2) worth 20 respondents:
  # tau0 = 20 / 1 = 20; tau_data = 60 / s^2; mu' = (tau0 x 3 + tau_data x mean) / (tau0 + tau_data)
  out2 <- process_mean_question(
    ref_q_row("sat", run_moe = "N", run_credible = "Y",
              prior_mean = 3, prior_sd = 1, prior_n = 20), d, NULL, ref_config())
  tau0 <- 20
  tau_d <- 60 / var(d$sat)
  mu <- (tau0 * 3 + tau_d * mean(d$sat)) / (tau0 + tau_d)
  sdp <- sqrt(1 / (tau0 + tau_d))
  expect_equal(out2$result$bayesian$post_mean, mu, tolerance = 1e-12)
  expect_equal(out2$result$bayesian$lower, mu - z95 * sdp, tolerance = 1e-12)
  expect_equal(out2$result$bayesian$upper, mu + z95 * sdp, tolerance = 1e-12)
})

test_that("mean bootstrap agrees with boot::boot percentile interval", {
  set.seed(11)
  n <- 400
  d <- data.frame(x = sample(1:10, n, replace = TRUE), w = runif(n, 0.5, 2))
  out <- process_mean_question(
    ref_q_row("x", run_bootstrap = "Y"), d, "w", ref_config(boot_iter = 5000))
  set.seed(98)
  b <- boot::boot(d, function(dd, i) sum(dd$w[i] * dd$x[i]) / sum(dd$w[i]), R = 5000)
  ref <- boot::boot.ci(b, type = "perc")$percent[4:5]
  # Mean SE here is about 0.15; two independent bootstraps agree to about 0.05
  expect_lt(abs(out$result$bootstrap$lower - ref[1]), 0.06)
  expect_lt(abs(out$result$bootstrap$upper - ref[2]), 0.06)
})


# ------------------------------------------------------------------------------
# NPS
# ------------------------------------------------------------------------------

nps_row <- function(...) {
  ref_q_row("nps", promoters = "9,10", detractors = "0,1,2,3,4,5,6", ...)
}

test_that("unweighted NPS SE matches svymean on a +1/0/-1 score", {
  d <- balanced_data()
  out <- process_nps_question(nps_row(), d, NULL, ref_config())
  # 20 promoters, 20 passives, 20 detractors: NPS 0
  expect_equal(out$result$nps_score, 0)
  expect_equal(out$result$pct_promoters, 100 / 3)
  d$score <- ifelse(d$nps >= 9, 1, ifelse(d$nps <= 6, -1, 0))
  des <- suppressWarnings(survey::svydesign(ids = ~1, data = d))
  se_svy <- as.numeric(survey::SE(survey::svymean(~score, des))) * 100
  # survey divides by n - 1, the closed form by n
  expect_equal(out$result$moe_normal$se, se_svy * sqrt(59 / 60), tolerance = 1e-10)
  expect_equal(out$result$moe_normal$upper, z95 * out$result$moe_normal$se, tolerance = 1e-12)
})

test_that("weighted NPS score and SE match survey on the balanced fixture", {
  # nps cycles 6, w cycles 4: in each 12-row block promoters, passives and
  # detractors each carry the weights 0.5, 1, 1.5, 2 once, so balanced.
  d <- balanced_data()
  out <- process_nps_question(nps_row(), d, "w", ref_config())
  d$score <- ifelse(d$nps >= 9, 1, ifelse(d$nps <= 6, -1, 0))
  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  est <- survey::svymean(~score, des)
  expect_equal(out$result$nps_score, as.numeric(coef(est)) * 100, tolerance = 1e-10)
  expect_equal(out$result$moe_normal$se,
               as.numeric(survey::SE(est)) * 100 * sqrt(59 / 60), tolerance = 1e-10)
})

test_that("weighted NPS SE on an unbalanced fixture: closed form by hand, survey bracket", {
  set.seed(3)
  d <- data.frame(nps = sample(0:10, 300, replace = TRUE), w = runif(300, 0.4, 2.5))
  out <- process_nps_question(nps_row(), d, "w", ref_config())
  pp <- sum(d$w[d$nps >= 9]) / sum(d$w)
  pd <- sum(d$w[d$nps <= 6]) / sum(d$w)
  n_eff <- sum(d$w)^2 / sum(d$w^2)
  se_hand <- sqrt(((pp + pd) - (pp - pd)^2) / n_eff) * 100
  expect_equal(out$result$nps_score, 100 * (pp - pd), tolerance = 1e-12)
  expect_equal(out$result$moe_normal$se, se_hand, tolerance = 1e-12)
  d$score <- ifelse(d$nps >= 9, 1, ifelse(d$nps <= 6, -1, 0))
  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  expect_equal(se_hand, as.numeric(survey::SE(survey::svymean(~score, des))) * 100,
               tolerance = 0.10)
})

test_that("NPS Bayesian matches the normal-normal update with the documented default prior", {
  d <- balanced_data()
  out <- process_nps_question(nps_row(run_moe = "N", run_credible = "Y"), d, NULL, ref_config())
  se <- sqrt((2 / 3) / 60) * 100            # closed form at pp = pd = 1/3
  tau0 <- 1 / 50^2                          # default prior N(0, 50^2)
  tau_d <- 1 / se^2
  mu <- (tau0 * 0 + tau_d * 0) / (tau0 + tau_d)
  sdp <- sqrt(1 / (tau0 + tau_d))
  expect_equal(out$result$bayesian$lower, mu - z95 * sdp, tolerance = 1e-10)
  expect_equal(out$result$bayesian$upper, mu + z95 * sdp, tolerance = 1e-10)
})

test_that("NPS bootstrap agrees with boot::boot percentile interval", {
  set.seed(5)
  n <- 400
  d <- data.frame(nps = sample(0:10, n, replace = TRUE), w = runif(n, 0.5, 2))
  out <- process_nps_question(nps_row(run_bootstrap = "Y"), d, "w",
                              ref_config(boot_iter = 5000))
  set.seed(97)
  stat <- function(dd, i) {
    ww <- dd$w[i]; x <- dd$nps[i]
    100 * (sum(ww[x >= 9]) - sum(ww[x <= 6])) / sum(ww)
  }
  ref <- boot::boot.ci(boot::boot(d, stat, R = 5000), type = "perc")$percent[4:5]
  # NPS SE here is about 4.5 points; two bootstraps agree to about 1.5
  expect_lt(abs(out$result$bootstrap$lower - ref[1]), 1.5)
  expect_lt(abs(out$result$bootstrap$upper - ref[2]), 1.5)
})


# ------------------------------------------------------------------------------
# STUDY LEVEL AND DIAGNOSTICS
# ------------------------------------------------------------------------------

test_that("study-level effective n is Kish by hand and equals the per-question n_eff", {
  d <- balanced_data()
  st <- calculate_study_level_stats(d, weight_variable = "w")
  expect_equal(st$Actual_n, 60)
  expect_equal(st$Effective_n, 50L)                    # 75^2 / 112.5
  expect_equal(st$Sum_Weights, 75)
  q <- process_proportion_question(ref_q_row("y", categories = "1"), d, "w", ref_config())
  expect_equal(q$result$n_eff, st$Effective_n)
})

test_that("weight concentration shares match a hand count", {
  w <- c(10, rep(1, 19))                               # n = 20, total 29
  wc <- compute_weight_concentration(w)
  # top 5% of 20 = 1 case (the 10); top 10% = 2 cases (10 + 1)
  expect_equal(wc$Top_5pct_Share, round(10 / 29 * 100, 1))
  expect_equal(wc$Top_10pct_Share, round(11 / 29 * 100, 1))
  expect_equal(wc$Concentration_Flag, "HIGH")          # 34.5% > 25%
})

test_that("margin comparison diffs and flags match a hand calculation", {
  d <- data.frame(g = c(1, 1, 1, 2), w = c(1, 1, 1, 3))
  tgt <- data.frame(Variable = "g", Category_Label = c("A", "B"),
                    Category_Code = c("1", "2"), Target_Prop = c(0.52, 0.48),
                    stringsAsFactors = FALSE)
  mc <- compute_margin_comparison(d, d$w, tgt)
  mc <- mc[order(mc$Category_Code), ]
  # Weighted shares 3/6 = 50% and 3/6 = 50%: diffs -2pp (AMBER) and +2pp (AMBER)
  expect_equal(mc$Weighted_Sample_Pct, c(50, 50))
  expect_equal(mc$Diff_pp, c(-2, 2), tolerance = 1e-12)
  expect_equal(mc$Flag, c("AMBER", "AMBER"))
})
