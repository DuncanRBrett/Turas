# ==============================================================================
# OUTPUT WRITERS FED BY THE CALCULATORS' REAL OUTPUT
# ==============================================================================
# test_output_integration.R feeds the writers hand-built mocks. Its proportion
# mock carried `moe_normal`, a field the calculators never produce (they store
# `moe`), so the Proportions_Detail sheet dropped the normal interval in every
# real run while that suite passed. These tests build each result with
# process_*_question, write the workbook, and read the numbers back from it.
# Robustness programme, 24 Sep 2026.
# ==============================================================================

library(testthat)

rr_config <- function() {
  list(study_settings = list(Confidence_Level = 0.95, Bootstrap_Iterations = 1000))
}

rr_q_row <- function(q_id, categories = NA, run_credible = "N",
                     promoters = NA, detractors = NA) {
  data.frame(
    Question_ID = q_id, Statistic_Type = "x", Categories = categories,
    Promoter_Codes = promoters, Detractor_Codes = detractors,
    Run_MOE = "Y", Run_Wilson = "Y", Run_Bootstrap = "N",
    Run_Credible = run_credible,
    Prior_Mean = NA, Prior_SD = NA, Prior_N = NA,
    stringsAsFactors = FALSE
  )
}

rr_data <- function() {
  data.frame(
    y   = rep(c(1, 1, 0), 20),
    nps = rep(c(10, 9, 8, 7, 6, 3), 10),
    w   = rep(c(0.5, 1, 1.5, 2), 15)
  )
}

rr_write_and_read <- function(prop = list(), nps = list(), sheet) {
  out <- tempfile(fileext = ".xlsx")
  on.exit(unlink(out), add = TRUE)
  suppressMessages(write_confidence_output(
    output_path = out, proportion_results = prop, nps_results = nps,
    config = list(confidence_level = 0.95), decimal_sep = "."
  ))
  openxlsx::read.xlsx(out, sheet = sheet, startRow = 3, skipEmptyRows = FALSE)
}

test_that("Proportions_Detail carries the normal interval the calculator produced", {
  d <- rr_data()
  res <- process_proportion_question(rr_q_row("y", categories = "1"), d, "w", rr_config())$result
  sheet <- rr_write_and_read(prop = list(y = res), sheet = "Proportions_Detail")
  row <- sheet[sheet$Question_ID %in% "y", ]
  expect_equal(nrow(row), 1)
  expect_true(all(c("MOE_Normal_Lower", "MOE_Normal_Upper", "MOE") %in% names(sheet)))
  # p = 2/3, n_eff = 50: MOE = 1.959964 x sqrt((2/9)/50) = 0.1306643
  expect_equal(row$MOE, qnorm(0.975) * sqrt((2 / 9) / 50), tolerance = 1e-9)
  expect_equal(row$MOE_Normal_Lower, res$moe$lower, tolerance = 1e-9)
  expect_equal(row$MOE_Normal_Upper, res$moe$upper, tolerance = 1e-9)
  expect_equal(row$Wilson_Lower, res$wilson$lower, tolerance = 1e-9)
})

test_that("HTML report builds for a weighted mean whose df is fractional", {
  # Weights 1,1,3: n_eff = 50^2 / 110 = 22.727, so df = 21.727. The mean
  # detail table formatted df with %d, sprintf refused the fractional value,
  # and the whole HTML report came back REFUSED on any weighted study with a
  # mean question (review 2026-09-24).
  d <- data.frame(x = rep(c(2, 4, 7), 10), w = rep(c(1, 1, 3), 10))
  res <- process_mean_question(rr_q_row("x"), d, "w", rr_config())$result
  expect_equal(res$t_dist$df, 50^2 / 110 - 1, tolerance = 1e-12)

  tbl <- build_mean_detail_table(res, 0.95)
  expect_true(grepl("df = 21.7,", tbl, fixed = TRUE))

  cr <- list(
    study_stats = NULL, proportion_results = list(),
    mean_results = list(x = res), nps_results = list(), warnings = character(),
    config = list(study_settings = list(Confidence_Level = "0.95"))
  )
  html_path <- tempfile(fileext = ".html")
  on.exit(unlink(html_path), add = TRUE)
  rep <- suppressMessages(generate_confidence_html_report(cr, html_path, list()))
  expect_equal(rep$status, "PASS")
  expect_true(file.exists(html_path))
})

test_that("HTML mean detail keeps a whole df whole", {
  d <- data.frame(x = rep(c(2, 4, 7), 10))
  res <- process_mean_question(rr_q_row("x"), d, NULL, rr_config())$result
  expect_true(grepl("df = 29,", build_mean_detail_table(res, 0.95), fixed = TRUE))
})
