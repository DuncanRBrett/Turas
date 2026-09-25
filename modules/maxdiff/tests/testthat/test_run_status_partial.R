# ==============================================================================
# MAXDIFF - A SKIPPED OR REFUSED ANALYSIS IS PARTIAL, ON THE SHEET TOO
# ==============================================================================
# Pipeline runs (helper_pipeline_fixture.R) whose config asks for something
# the run cannot deliver. The Run_Status sheet in the workbook the client
# opens must say PARTIAL and name the event, the same as the status the run
# returns. None of these runs samples Stan.
# ==============================================================================

source(file.path(TURAS_ROOT, "modules", "maxdiff", "tests", "testthat",
                 "helper_pipeline_fixture.R"), local = TRUE)

.run_status_sheet <- function(path) {
  x <- openxlsx::read.xlsx(path, sheet = "Run_Status", colNames = FALSE,
                           skipEmptyRows = FALSE)
  cells <- as.character(unlist(x))
  status_row <- which(x[[1]] == "Status")
  list(status = if (length(status_row)) x[[2]][status_row[1]] else NA_character_,
       text = paste(cells[!is.na(cells)], collapse = "\n"))
}

# HB off, so there are no individual utilities, while the tabs export and
# TURF are on (the example config turns both on).
PN <- md_pipe_run(n = 60, weighted = FALSE,
                  output_settings = c(Generate_HB_Model = "NO"))

test_that("a refused tabs export makes the Run_Status sheet PARTIAL, not only the banner", {
  expect_true(file.exists(PN$workbook), info = paste(tail(PN$log, 30), collapse = "\n"))
  expect_equal(PN$status, "PARTIAL")
  sheet <- .run_status_sheet(PN$workbook)
  expect_equal(sheet$status, "PARTIAL")
  expect_match(sheet$text, "MODEL_NO_RESPONDENT_UTILITIES", fixed = TRUE)
  # The sheet is replaced in the workbook still in memory and saved again:
  # nothing else in the workbook moves.
  sheets <- openxlsx::getSheetNames(PN$workbook)
  expect_true(all(c("SUMMARY", "ITEM_SCORES", "SEGMENT_SCORES") %in% sheets))
  expect_equal(tail(sheets, 1), "Run_Status")
  expect_equal(sum(sheets == "Run_Status"), 1L)
  sc <- md_pipe_sheet(PN$workbook, "ITEM_SCORES")
  expect_true(all(is.finite(sc$Logit_Utility[!is.na(sc$Item_ID)])))
  # Saving one openxlsx workbook object twice writes width="NA" on every
  # auto-width column, which Excel treats as a damaged file. The sheet must
  # come from a fresh write, not a second save.
  parts <- utils::unzip(PN$workbook, list = TRUE)$Name
  sheets_xml <- grep("^xl/worksheets/sheet[0-9]+[.]xml$", parts, value = TRUE)
  for (sx in sheets_xml) {
    xml <- paste(readLines(unz(PN$workbook, sx), warn = FALSE), collapse = "")
    expect_false(grepl('width="NA"', xml, fixed = TRUE), info = sx)
  }
})

test_that("TURF asked for but skipped for want of individual utilities is an event", {
  # Generate_TURF = YES with HB off: nothing to classify appeal on, so no TURF
  # sheet. Before, the step was silently skipped and nothing said why.
  expect_false("TURF_RESULTS" %in% openxlsx::getSheetNames(PN$workbook))
  expect_match(.run_status_sheet(PN$workbook)$text, "MAXD_TURF_SKIPPED", fixed = TRUE)
  codes <- vapply(PN$run_result$events %||% list(), function(e) e$code %||% "", "")
  expect_true("MAXD_TURF_SKIPPED" %in% codes)
})

# A library folder holding a broken "cmdstanr" (a DESCRIPTION and nothing
# else) placed first on the child's library path: requireNamespace("cmdstanr")
# then returns FALSE and fit_hb_model() takes the empirical-Bayes fallback,
# exactly as on a machine without cmdstanr.
.hide_cmdstanr_lib <- function() {
  lib <- tempfile("no_cmdstanr_")
  dir.create(file.path(lib, "cmdstanr"), recursive = TRUE)
  writeLines(c("Package: cmdstanr", "Version: 0.0.0"), file.path(lib, "cmdstanr", "DESCRIPTION"))
  lib
}

PE <- md_pipe_run(n = 60, weighted = FALSE, lib_prepend = .hide_cmdstanr_lib())

test_that("the empirical-Bayes fallback in place of Stan HB is a PARTIAL event", {
  expect_true(file.exists(PE$workbook), info = paste(tail(PE$log, 30), collapse = "\n"))
  expect_equal(jsonlite::fromJSON(PE$island)$meta$method, "empirical_bayes")
  expect_equal(PE$status, "PARTIAL")
  sheet <- .run_status_sheet(PE$workbook)
  expect_equal(sheet$status, "PARTIAL")
  expect_match(sheet$text, "MAXD_HB_APPROXIMATE", fixed = TRUE)
})

test_that("the stats pack does not call the empirical-Bayes fallback NOT CONVERGED", {
  # There is no sampler on this path, so no convergence to report either way.
  expect_true(file.exists(PE$stats_pack))
  expect_match(md_pipe_stats_value(PE$stats_pack, "Convergence Status"),
               "^Not applicable", fixed = FALSE)
})
