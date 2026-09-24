# ==============================================================================
# STATS PACK METHOD TEXT MATCHES WHAT RAN
# ==============================================================================
# The stats pack Assumptions sheet said NPS intervals used the Wilson score,
# means used base R t.test() and DEFF came from the survey package. None was
# true (review 2026-09-24). The text is now built from the results.
# ==============================================================================

library(testthat)

sp_config <- function() {
  list(study_settings = list(Confidence_Level = 0.95, Bootstrap_Iterations = 1000))
}
sp_q_row <- function(q_id, categories = NA, wilson = "N", promoters = NA, detractors = NA) {
  data.frame(
    Question_ID = q_id, Statistic_Type = "x", Categories = categories,
    Promoter_Codes = promoters, Detractor_Codes = detractors,
    Run_MOE = "Y", Run_Wilson = wilson, Run_Bootstrap = "N", Run_Credible = "N",
    Prior_Mean = NA, Prior_SD = NA, Prior_N = NA, stringsAsFactors = FALSE
  )
}

test_that("stats pack method text describes the intervals that ran", {
  d <- data.frame(y = rep(c(1, 0), 20), x = 1:40, nps = rep(c(10, 3, 8, 9), 10))
  prop <- list(
    a = process_proportion_question(sp_q_row("y", "1", wilson = "Y"), d, NULL, sp_config())$result,
    b = process_proportion_question(sp_q_row("y", "1"), d, NULL, sp_config())$result
  )
  means <- list(x = process_mean_question(sp_q_row("x"), d, NULL, sp_config())$result)
  nps <- list(n = process_nps_question(
    sp_q_row("nps", promoters = "9,10", detractors = "0,1,2,3,4,5,6"), d, NULL, sp_config())$result)

  expect_equal(describe_methods_run(prop, "proportion"),
               paste0("Normal approximation (Wald), SE = sqrt(p(1-p)/n_eff) (2 questions); ",
                      "Wilson score on the Kish effective n (1 question)"))
  expect_match(describe_methods_run(means, "mean"), "^t-distribution, SE = SD / sqrt\\(n_eff\\)")
  expect_match(describe_methods_run(nps, "nps"), "covariance")
  expect_false(grepl("Wilson", describe_methods_run(nps, "nps")))
  expect_equal(describe_methods_run(list(), "mean"), "None run")
})
