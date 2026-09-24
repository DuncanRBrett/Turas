# ==============================================================================
# SMALL-BASE NOTES REACH THE WORKBOOK
# ==============================================================================
# The calculators wrote "Very small base (n=20)" and "Extreme proportion ...
# consider Wilson" into each interval's own $warnings, and nothing collected
# them: a question on a base of 20 shipped with an empty Warnings sheet. The
# mean's note also tested the raw n while proportions tested n_eff
# (review 2026-09-24). They now travel as NOTES: listed on the Warnings sheet,
# sized on n_eff, and kept out of the run status (a small base is not a
# skipped question, so the run is not made PARTIAL by it).
# ==============================================================================

library(testthat)

bn_config <- function() {
  list(study_settings = list(Confidence_Level = 0.95, Bootstrap_Iterations = 1000))
}
bn_q_row <- function(q_id, categories = NA, wilson = "N", stat = "proportion") {
  data.frame(
    Question_ID = q_id, Statistic_Type = stat, Categories = categories,
    Promoter_Codes = NA, Detractor_Codes = NA,
    Run_MOE = "Y", Run_Wilson = wilson, Run_Bootstrap = "N", Run_Credible = "N",
    Prior_Mean = NA, Prior_SD = NA, Prior_N = NA, stringsAsFactors = FALSE
  )
}

test_that("a small base gives a note on n_eff, not a warning", {
  d <- data.frame(y = rep(c(1, 0), 10), x = 1:20)
  out <- process_proportion_question(bn_q_row("y", "1"), d, NULL, bn_config())
  expect_length(out$warnings, 0)
  expect_true(any(grepl("Question y: Very small base (n=20)", out$notes, fixed = TRUE)))
})

test_that("a weighted mean's note uses n_eff, not the raw count", {
  # 60 respondents, weights 1,1,6: n_eff = 60 x 64 / 3 / 38 = 33.7, so
  # "Small base" (under 50) and not "Very small" (under 30). The raw n of 60
  # would have said nothing.
  d <- data.frame(x = rep(c(2, 5, 9), 20), w = rep(c(1, 1, 6), 20))
  out <- process_mean_question(bn_q_row("x", stat = "mean"), d, "w", bn_config())
  expect_true(any(grepl("Question x: Small base (n=33.7)", out$notes, fixed = TRUE)))
})

test_that("an extreme proportion is noted only when Wilson was not run", {
  d <- data.frame(y = c(1, rep(0, 99)))
  no_wilson <- process_proportion_question(bn_q_row("y", "1"), d, NULL, bn_config())
  expect_true(any(grepl("Question y: Extreme proportion", no_wilson$notes, fixed = TRUE)))
  with_wilson <- process_proportion_question(bn_q_row("y", "1", wilson = "Y"), d, NULL, bn_config())
  expect_false(any(grepl("Extreme proportion", with_wilson$notes, fixed = TRUE)))
})

test_that("process_all_questions returns notes separately from warnings", {
  d <- data.frame(y = rep(c(1, 0), 10))
  cfg <- bn_config(); cfg$question_analysis <- bn_q_row("y", "1")
  res <- process_all_questions(cfg, d, NULL, verbose = FALSE)
  expect_length(res$warnings, 0)
  expect_true(any(grepl("Question y: Very small base", res$notes, fixed = TRUE)))
})

test_that("the Warnings sheet lists the notes under their own heading", {
  out <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out), add = TRUE)
  suppressWarnings(suppressMessages(write_confidence_output(
    output_path = out, config = list(confidence_level = 0.95), decimal_sep = ".",
    warnings = character(), notes = "Question y: Very small base (n=20) - results may be unstable")))
  ws <- openxlsx::read.xlsx(out, sheet = "Warnings", colNames = FALSE, skipEmptyRows = FALSE)
  cells <- unlist(ws, use.names = FALSE)
  expect_true("No warnings detected" %in% cells)
  expect_true(any(grepl("^NOTES", cells)))
  expect_true("Question y: Very small base (n=20) - results may be unstable" %in% cells)
})
