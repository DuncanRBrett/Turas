# ==============================================================================
# ADVERSARIAL GATE - Confidence Module
# ==============================================================================
# The reference checks again, on the hard cases: p = 0 and p = 1, bases under
# 30, a design effect near 2, weights grossed to a population total, a
# filter that leaves nobody, an all-missing question, text codes, and a
# single category. Robustness programme gate 3, 24 Sep 2026.
#
# Not covered here, and why:
#   - census / finite population correction: the module does not apply an
#     FPC at all (fpc.R is loaded, never called). OPEN, for Duncan.
#   - "don't know" codes: confidence has no exclusion setting; a 99 in a mean
#     question is averaged in unless the data is recoded. OPEN, for Duncan.
# ==============================================================================

library(testthat)

adv_config <- function() {
  list(study_settings = list(Confidence_Level = 0.95, Bootstrap_Iterations = 1000))
}

adv_q_row <- function(q_id, categories = NA, promoters = NA, detractors = NA,
                      run_bootstrap = "N", filter_var = NA, filter_vals = NA,
                      stat = "proportion") {
  data.frame(
    Question_ID = q_id, Statistic_Type = stat, Categories = categories,
    Promoter_Codes = promoters, Detractor_Codes = detractors,
    Filter_Variable = filter_var, Filter_Values = filter_vals,
    Run_MOE = "Y", Run_Wilson = "Y", Run_Bootstrap = run_bootstrap,
    Run_Credible = "Y", Prior_Mean = NA, Prior_SD = NA, Prior_N = NA,
    stringsAsFactors = FALSE
  )
}

z95 <- qnorm(0.975)

test_that("p = 0 on n = 20: Wilson = prop.test, Beta(1, 21), normal has zero width", {
  d <- data.frame(y = rep(2, 20))
  out <- process_proportion_question(adv_q_row("y", "1"), d, NULL, adv_config())$result
  ref <- prop.test(0, 20, correct = FALSE)$conf.int
  expect_equal(out$proportion, 0)
  expect_equal(out$wilson$lower, ref[1], tolerance = 1e-12)
  expect_equal(out$wilson$upper, ref[2], tolerance = 1e-12)
  expect_equal(out$bayesian$upper, qbeta(0.975, 1, 21), tolerance = 1e-12)
  # The Wald interval collapses at p = 0; that is the method, and the reason
  # the guide recommends Wilson for extreme proportions.
  expect_equal(c(out$moe$lower, out$moe$upper), c(0, 0))
})

test_that("p = 1 weighted, single category: Wilson on n_eff by hand", {
  d <- data.frame(y = rep(1, 12), w = rep(c(1, 1, 3), 4))
  out <- process_proportion_question(adv_q_row("y", "1"), d, "w", adv_config())$result
  ne <- 20^2 / 44                                   # 9.0909
  expect_equal(out$proportion, 1)
  expect_equal(out$wilson$upper, 1)
  lower <- (1 + z95^2 / (2 * ne) - z95 * sqrt(z95^2 / (4 * ne^2))) / (1 + z95^2 / ne)
  expect_equal(out$wilson$lower, lower, tolerance = 1e-12)
  expect_equal(out$bayesian$lower, qbeta(0.025, 1 + ne, 1), tolerance = 1e-12)
})

test_that("a mean on n = 5 matches t.test", {
  d <- data.frame(x = c(2, 3, 5, 8, 13))
  out <- process_mean_question(adv_q_row("x", stat = "mean"), d, NULL, adv_config())$result
  expect_equal(c(out$t_dist$lower, out$t_dist$upper), t.test(d$x)$conf.int[1:2],
               tolerance = 1e-12)
})

test_that("design effect near 2: Kish n_eff drives every interval", {
  # Weights 1,1,1,6: per block sum 9, sum of squares 39. n = 100,
  # n_eff = 100 x 81 / 156 = 51.92, DEFF = 1.926. The successes are the
  # weight-6 rows, so weighted p = 6/9 = 0.667 against 0.25 unweighted.
  d <- data.frame(y = rep(c(0, 0, 0, 1), 25), w = rep(c(1, 1, 1, 6), 25))
  out <- process_proportion_question(adv_q_row("y", "1"), d, "w", adv_config())$result
  ne <- sum(d$w)^2 / sum(d$w^2)
  expect_equal(ne, 100 * 81 / 156, tolerance = 1e-12)
  p <- 6 / 9
  expect_equal(out$proportion, p, tolerance = 1e-12)
  expect_equal(out$moe$se, sqrt(p * (1 - p) / ne), tolerance = 1e-12)
  st <- calculate_study_level_stats(d, "w")
  expect_equal(st$DEFF, round(100 / ne, 2))           # 1.93
  # survey's linearisation SE is a different estimator; within 25% here
  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  expect_equal(out$moe$se, as.numeric(survey::SE(survey::svymean(~y, des))), tolerance = 0.25)
})

test_that("weights grossed to a population total give identical results", {
  d <- data.frame(y = rep(c(1, 0, 1), 20), x = rep(c(2, 9, 4, 7), 15),
                  nps = rep(c(10, 3, 8, 9, 6), 12), w = rep(c(0.5, 1, 1.5, 2), 15))
  g <- d; g$w <- d$w * 250000                          # sums to 18.75 million
  a <- process_proportion_question(adv_q_row("y", "1"), d, "w", adv_config())$result
  b <- process_proportion_question(adv_q_row("y", "1"), g, "w", adv_config())$result
  expect_equal(b$proportion, a$proportion, tolerance = 1e-12)
  expect_equal(b$n_eff, a$n_eff)
  expect_equal(b$wilson$lower, a$wilson$lower, tolerance = 1e-12)
  expect_equal(b$bayesian$upper, a$bayesian$upper, tolerance = 1e-12)
  am <- process_mean_question(adv_q_row("x", stat = "mean"), d, "w", adv_config())$result
  bm <- process_mean_question(adv_q_row("x", stat = "mean"), g, "w", adv_config())$result
  expect_equal(bm$t_dist$upper, am$t_dist$upper, tolerance = 1e-12)
  expect_equal(bm$sd, am$sd, tolerance = 1e-12)
  pr <- c("9,10"); de <- "0,1,2,3,4,5,6"
  an <- process_nps_question(adv_q_row("nps", promoters = pr, detractors = de), d, "w", adv_config())$result
  bn <- process_nps_question(adv_q_row("nps", promoters = pr, detractors = de), g, "w", adv_config())$result
  expect_equal(bn$moe_normal$se, an$moe_normal$se, tolerance = 1e-12)
  st_a <- calculate_study_level_stats(d, "w"); st_b <- calculate_study_level_stats(g, "w")
  expect_equal(st_b$Effective_n, st_a$Effective_n)
  expect_equal(st_b$DEFF, st_a$DEFF)
})

test_that("text codes match text categories", {
  d <- data.frame(brand = rep(c("A", "B", "C"), 10), stringsAsFactors = FALSE)
  out <- process_proportion_question(adv_q_row("brand", "A,B"), d, NULL, adv_config())$result
  expect_equal(out$proportion, 2 / 3)
  expect_equal(out$wilson$lower, prop.test(20, 30, correct = FALSE)$conf.int[1], tolerance = 1e-12)
})

test_that("a filter that leaves nobody, and an all-missing question, are skipped with a warning", {
  d <- data.frame(y = rep(c(1, 0), 10), gone = NA_real_, region = 1)
  cfg <- adv_config()
  cfg$question_analysis <- rbind(
    adv_q_row("y", "1", filter_var = "region", filter_vals = "2"),
    adv_q_row("gone", "1")
  )
  res <- process_all_questions(cfg, d, NULL, verbose = FALSE)
  expect_length(res$proportion_results, 0)
  expect_true(any(grepl("Question y: Filter 'region' in \\(2\\) yielded 0 respondents", res$warnings)))
  expect_true(any(grepl("Question gone: No valid", res$warnings)))
})
