# ==============================================================================
# random_seed REACHES EVERY BOOTSTRAP
# ==============================================================================
# The config template promises "Set a random seed for reproducible bootstrap
# results". validate_study_settings() checked random_seed was numeric, but no
# dispatcher read it, so every run gave different bootstrap intervals
# (review 2026-09-24). With a seed, a question's interval must not depend on
# what the R session did before it, including which questions ran first.
# ==============================================================================

library(testthat)

seed_config <- function(seed = NULL) {
  ss <- list(Confidence_Level = 0.95, Bootstrap_Iterations = 1000)
  if (!is.null(seed)) ss$random_seed <- seed
  list(study_settings = ss)
}

seed_q_row <- function(q_id, categories = NA, promoters = NA, detractors = NA) {
  data.frame(
    Question_ID = q_id, Statistic_Type = "x", Categories = categories,
    Promoter_Codes = promoters, Detractor_Codes = detractors,
    Run_MOE = "N", Run_Wilson = "N", Run_Bootstrap = "Y", Run_Credible = "N",
    Prior_Mean = NA, Prior_SD = NA, Prior_N = NA, stringsAsFactors = FALSE
  )
}

seed_data <- data.frame(
  y = rep(c(1, 0, 0, 1, 0), 20),
  x = rep(c(3, 7, 5, 9, 1), 20),
  nps = rep(c(10, 9, 8, 7, 6, 3, 0, 10, 5, 9), 10),
  w = rep(c(0.5, 1, 1.5, 2), 25)
)

run_twice <- function(fun, q_row, seed) {
  set.seed(1); a <- fun(q_row, seed_data, "w", seed_config(seed))$result$bootstrap
  set.seed(2); invisible(runif(10))
  b <- fun(q_row, seed_data, "w", seed_config(seed))$result$bootstrap
  list(a = c(a$lower, a$upper), b = c(b$lower, b$upper))
}

test_that("a configured random_seed makes the proportion bootstrap reproducible", {
  r <- run_twice(process_proportion_question, seed_q_row("y", categories = "1"), 42)
  expect_identical(r$a, r$b)
  # "42" as readxl may deliver it, text not number
  r2 <- run_twice(process_proportion_question, seed_q_row("y", categories = "1"), "42")
  expect_identical(r2$a, r$a)
})

test_that("a configured random_seed makes the mean bootstrap reproducible", {
  r <- run_twice(process_mean_question, seed_q_row("x"), 42)
  expect_identical(r$a, r$b)
})

test_that("a configured random_seed makes the NPS bootstrap reproducible", {
  r <- run_twice(process_nps_question,
                 seed_q_row("nps", promoters = "9,10", detractors = "0,1,2,3,4,5,6"), 42)
  expect_identical(r$a, r$b)
})

test_that("without a seed the bootstrap follows the session's random stream", {
  r <- run_twice(process_mean_question, seed_q_row("x"), NULL)
  expect_false(identical(r$a, r$b))
  r_blank <- run_twice(process_mean_question, seed_q_row("x"), "")
  expect_false(identical(r_blank$a, r_blank$b))
})
