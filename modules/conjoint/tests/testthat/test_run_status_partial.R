# ==============================================================================
# CONJOINT - A SKIPPED OR REFUSED STEP IS PARTIAL, EVERYWHERE
# ==============================================================================
# Pipeline runs (helper_pipeline_fixture.R) on clean synthetic data (300
# respondents, 54 profiles, so no data warning fires) where one requested
# step cannot be delivered. The returned status, the closing banner, the
# Run_Status sheet and the stats pack must all say PARTIAL and name it.
# ==============================================================================

source(file.path(Sys.getenv("TURAS_ROOT"), "modules", "conjoint", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)

.clean <- function(seed = 3, truth = NULL) {
  generate_synthetic_cbc(n_respondents = 300, n_tasks = 8, n_alts = 3, seed = seed,
                         true_utilities = truth)
}

.check_partial <- function(p, code) {
  expect_equal(p$result$status, "PARTIAL", info = paste(tail(p$log, 25), collapse = "\n"))
  expect_equal(p$result$run_status, "PARTIAL")
  expect_true(any(grepl("[TRS PARTIAL] CONJOINT", p$log, fixed = TRUE)),
              info = paste(grep("TRS", p$log, value = TRUE), collapse = "\n"))
  sheet <- cj_run_status(p$workbook)
  expect_equal(sheet$status, "PARTIAL")
  expect_match(sheet$text, code, fixed = TRUE)
  parts <- utils::unzip(p$workbook, list = TRUE)$Name
  for (sx in grep("^xl/worksheets/sheet[0-9]+[.]xml$", parts, value = TRUE)) {
    xml <- paste(readLines(unz(p$workbook, sx), warn = FALSE), collapse = "")
    expect_false(grepl('width="NA"', xml, fixed = TRUE), info = sx)
  }
}

test_that("a clean mlogit run with no tabs export asked for is PASS", {
  s <- .clean()
  p <- cj_pipe_run(s$data, s$attributes, settings = list(generate_tabs_export = "N"))
  expect_equal(p$result$status, "PASS", info = paste(tail(p$log, 25), collapse = "\n"))
  expect_equal(cj_run_status(p$workbook)$status, "PASS")
})

test_that("a tabs export asked for but refused (no respondent-level estimates) is PARTIAL", {
  s <- .clean()
  p <- cj_pipe_run(s$data, s$attributes)
  .check_partial(p, "CALC_NO_RESPONDENT_UTILITIES")
})

test_that("a refused WTP (price slope positive) is PARTIAL", {
  # Higher prices chosen more often: the slope is positive and WTP refuses.
  truth <- c(BrandBeta = 0.8, BrandGamma = -0.3, "Price$20" = 0.5, "Price$30" = 1.2,
             SizeMedium = 0.4, SizeLarge = 0.6, ColorBlue = 0.2)
  s <- .clean(seed = 4, truth = truth)
  p <- cj_pipe_run(s$data, s$attributes, settings = list(generate_tabs_export = "N"))
  .check_partial(p, "CALC_WTP_POSITIVE_PRICE_SLOPE")
})

test_that("a failed island or simulator is PARTIAL", {
  s <- .clean()
  p <- cj_pipe_run(s$data, s$attributes, settings = list(generate_tabs_export = "N"),
                   pre = paste(
                     "write_conjoint_island <- function(...) stop('island writer broke')",
                     "generate_conjoint_simulator <- function(...) stop('simulator broke')",
                     sep = "\n"))
  .check_partial(p, "CONJ_ISLAND_FAILED")
  expect_match(cj_run_status(p$workbook)$text, "CONJ_SIMULATOR_FAILED", fixed = TRUE)
})
