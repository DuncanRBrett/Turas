# ==============================================================================
# TESTS - The comment-appendix trio, end to end, on synthetic data
# ==============================================================================
# Runs the REAL scripts/build_comment_appendix.py through the Steps runner, in a
# temp folder, against a synthetic survey workbook. No client data, no project
# folder. Skipped where python3/openpyxl/pandas are unavailable (e.g. a Docker
# image that has not yet added them) - which also proves the guard's PASS
# verdict is honest: when it says PASS, the tool really does run.
# ==============================================================================

skip_unless_appendix_ready <- function() {
  testthat::skip_if_not_installed("processx")
  testthat::skip_if_not_installed("openxlsx")
  if (!appendix_env_ready()) {
    testthat::skip("python3 with openpyxl + pandas is not available on this machine")
  }
}

write_survey_data <- function(path, comments) {
  df <- data.frame(
    ResponseID = seq_along(comments),
    Q1Comment  = comments,
    stringsAsFactors = FALSE
  )
  openxlsx::write.xlsx(df, path)
  path
}

APPENDIX_HEADER_ROW <- 5L   # 4 legend rows, then the header row
APPENDIX_ID_COL     <- 1L
APPENDIX_TEXT_COL   <- 3L

read_appendix_sheet <- function(path, sheet = "Q1Comment") {
  wb <- openxlsx::loadWorkbook(path)
  raw <- openxlsx::readWorkbook(wb, sheet = sheet, startRow = APPENDIX_HEADER_ROW,
                                colNames = TRUE, skipEmptyRows = FALSE)
  raw
}


test_that("build creates the appendix, then re-runs without touching it", {
  skip_unless_appendix_ready()

  dir <- tempfile("appendix_e2e_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  data_file <- write_survey_data(file.path(dir, "survey.xlsx"),
                                 c("The service was quick", "Too expensive", ""))
  appendix <- file.path(dir, "appendix.xlsx")

  build <- steps_find_tool("comment_appendix_build")
  res <- steps_run_tool(build,
    list(data = data_file, appendix = appendix, pattern = "Comment"),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)

  expect_equal(res$status, "PASS")
  expect_true(file.exists(appendix))

  sheet <- read_appendix_sheet(appendix)
  expect_true("The service was quick" %in% sheet[[APPENDIX_TEXT_COL]])
  expect_true("Too expensive" %in% sheet[[APPENDIX_TEXT_COL]])
  # The blank verbatim is not a comment, so it is not a row.
  expect_equal(sum(!is.na(sheet[[APPENDIX_ID_COL]])), 2L)

  before <- file.info(appendix)$mtime
  again <- steps_run_tool(build,
    list(data = data_file, appendix = appendix, pattern = "Comment"),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)

  expect_equal(again$status, "PASS")
  expect_true(any(grepl("left untouched", again$output, fixed = TRUE)))
  expect_equal(file.info(appendix)$mtime, before)
})


test_that("dry run reports and writes nothing", {
  skip_unless_appendix_ready()

  dir <- tempfile("appendix_dry_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  data_file <- write_survey_data(file.path(dir, "survey.xlsx"), c("A real comment"))
  appendix <- file.path(dir, "appendix.xlsx")

  res <- steps_run_tool(steps_find_tool("comment_appendix_build"),
    list(data = data_file, appendix = appendix, pattern = "Comment", dry_run = TRUE),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)

  expect_equal(res$status, "PASS")
  expect_true(any(grepl("no file written", res$output, fixed = TRUE)))
  expect_false(file.exists(appendix))
})


test_that("a tool failure surfaces as a refusal, not a silent pass", {
  skip_unless_appendix_ready()

  dir <- tempfile("appendix_fail_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  # A pattern that matches nothing: the script resolves no comment columns,
  # writes nothing, and exits 2.
  data_file <- write_survey_data(file.path(dir, "survey.xlsx"), c("A real comment"))
  res <- steps_run_tool(steps_find_tool("comment_appendix_build"),
    list(data = data_file, appendix = file.path(dir, "appendix.xlsx"),
         pattern = "no_such_column_anywhere"),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)

  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_STEP_FAILED")
  expect_equal(res$exit_status, 2L)
  expect_true(grepl("no comment columns resolved", res$context$last_output, fixed = TRUE))
})


test_that("report-changes then apply-changes updates only the approved row", {
  skip_unless_appendix_ready()

  dir <- tempfile("appendix_changes_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  data_file <- file.path(dir, "survey.xlsx")
  appendix  <- file.path(dir, "appendix.xlsx")
  write_survey_data(data_file, c("original one", "original two"))

  built <- steps_run_tool(steps_find_tool("comment_appendix_build"),
    list(data = data_file, appendix = appendix, pattern = "Comment"),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)
  expect_equal(built$status, "PASS")

  # Both verbatims are corrected in the data (a backcheck, say).
  write_survey_data(data_file, c("corrected one", "corrected two"))

  review <- file.path(dir, "review.xlsx")
  reported <- steps_run_tool(steps_find_tool("comment_appendix_report_changes"),
    list(data = data_file, appendix = appendix, pattern = "Comment",
         report_changes = review),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)

  expect_equal(reported$status, "PASS")
  expect_true(file.exists(review))
  changes <- openxlsx::read.xlsx(review)
  expect_equal(nrow(changes), 2L)

  # Approve the first row only. The mark is written with openpyxl (as Excel
  # would): openxlsx's own writer produces workbooks openpyxl cannot re-open.
  mark <- processx::run("python3", c("-c", paste(
    "import openpyxl, sys",
    "wb = openpyxl.load_workbook(sys.argv[1])",
    "wb.active.cell(2, 5).value = 'y'",
    "wb.save(sys.argv[1])",
    sep = "\n"), review), error_on_status = FALSE)
  expect_equal(mark$status, 0L)

  applied <- steps_run_tool(steps_find_tool("comment_appendix_apply_changes"),
    list(data = data_file, appendix = appendix, pattern = "Comment",
         changes_file = review),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)

  expect_equal(applied$status, "PASS")

  sheet <- read_appendix_sheet(appendix)
  texts <- sheet[[APPENDIX_TEXT_COL]]
  expect_true("corrected one" %in% texts)    # approved
  expect_true("original two" %in% texts)     # not approved, left alone
})


test_that("report-changes with a blank output path auto-names beside the appendix", {
  skip_unless_appendix_ready()

  # This is the default path the field's help text points at, and the one that
  # sends `--report-changes` to argparse as a bare switch (nargs="?"), so it is
  # worth running against the real script rather than reasoning about.
  dir <- tempfile("appendix_auto_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  data_file <- file.path(dir, "survey.xlsx")
  appendix  <- file.path(dir, "appendix.xlsx")
  write_survey_data(data_file, c("original one"))

  built <- steps_run_tool(steps_find_tool("comment_appendix_build"),
    list(data = data_file, appendix = appendix, pattern = "Comment"),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)
  expect_equal(built$status, "PASS")

  write_survey_data(data_file, c("corrected one"))

  res <- steps_run_tool(steps_find_tool("comment_appendix_report_changes"),
    list(data = data_file, appendix = appendix, pattern = "Comment",
         report_changes = ""),
    turas_root = TURAS_ROOT, on_output = NULL, timeout_s = 120)

  expect_equal(res$status, "PASS")
  auto_named <- list.files(dir, pattern = "^appendix changes .*\\.xlsx$")
  expect_equal(length(auto_named), 1L)
  expect_equal(nrow(openxlsx::read.xlsx(file.path(dir, auto_named[1]))), 1L)
})


test_that("the review modes refuse before running when the appendix is absent", {
  skip_if_not_installed("processx")

  dir <- tempfile("appendix_missing_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines("x", file.path(dir, "data.xlsx"))   # existence is all that is checked

  res <- steps_build_command(steps_find_tool("comment_appendix_report_changes"),
    list(data = file.path(dir, "data.xlsx"),
         appendix = file.path(dir, "no_appendix_here.xlsx")),
    turas_root = TURAS_ROOT)

  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_STEP_ARG_NOT_FOUND")
})
