# ==============================================================================
# TESTS: stats_pack_writer.R
# ==============================================================================
# Tests for the shared stats pack writer.
# Covers: file creation, sheet structure, content, edge cases, protection.
# ==============================================================================

library(testthat)

# Source the writer
writer_path <- file.path(
  dirname(dirname(dirname(getwd()))),
  "shared", "lib", "stats_pack_writer.R"
)
if (!file.exists(writer_path)) {
  writer_path <- file.path(getwd(), "modules", "shared", "lib", "stats_pack_writer.R")
}
if (file.exists(writer_path)) source(writer_path)

# Skip all tests if openxlsx not available
skip_if_not_installed <- function() {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    skip("openxlsx not available")
  }
}


# ==============================================================================
# FIXTURES
# ==============================================================================

make_minimal_payload <- function() {
  list(
    module           = "TEST",
    run_timestamp    = as.POSIXct("2026-03-21 09:00:00"),
    turas_version    = "1.0",
    status           = "PASS",
    duration_seconds = 5.2,
    data_receipt = list(
      file_name           = "test_data.csv",
      n_rows              = 100,
      n_cols              = 20,
      questions_in_config = 15
    ),
    data_used = list(
      n_respondents      = 100,
      n_excluded         = 0L,
      questions_analysed = 15,
      questions_skipped  = 0L,
      per_item_stats     = data.frame(
        Question_ID   = c("Q1", "Q2", "Q3"),
        Missing_N     = c(0L, 2L, 15L),
        Missing_Pct   = c(0.0, 2.0, 15.0),
        Unique_Values = c(2L, 5L, 3L),
        stringsAsFactors = FALSE
      )
    ),
    assumptions = list(
      "Confidence Level" = "95%",
      "Method"           = "Wilson score interval (base R formula)",
      "Total tests run"  = "15",
      "TRS Status"       = "PASS",
      "TRS Events"       = "No events — ran cleanly"
    ),
    run_result = list(
      status  = "PASS",
      module  = "TEST",
      events  = list(),
      duration_seconds = 5.2
    ),
    packages    = c("openxlsx", "readxl"),
    config_echo = list(
      file_paths     = list("Data_File" = "test_data.csv", "Output_File" = "output.xlsx"),
      study_settings = list("Confidence_Level" = "0.95", "Method" = "wilson")
    )
  )
}

make_payload_with_warnings <- function() {
  p <- make_minimal_payload()
  p$status <- "PARTIAL"
  p$run_result <- list(
    status = "PARTIAL",
    module = "TEST",
    events = list(
      list(level = "PARTIAL", code = "DATA_SMALL_SAMPLE",
           title = "Small sample", question_code = "Q1",
           detail = "n < 30", fix = "Collect more data"),
      list(level = "INFO", code = "DATA_ZERO_CELL",
           title = "Zero cell", question_code = "Q2",
           detail = "No responses in category A", fix = "Check coding")
    ),
    duration_seconds = 5.2
  )
  p
}

make_payload_with_seeds <- function() {
  p <- make_minimal_payload()
  p$module <- "SEGMENT"
  p$seeds  <- list("k-means" = "42", "ensemble" = "12345")
  p
}


# ==============================================================================
# FILE CREATION
# ==============================================================================

test_that("turas_write_stats_pack creates an xlsx file", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  result <- turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  expect_true(file.exists(tmp))
  expect_equal(result, tmp)
})

test_that("returns NULL and does not error when openxlsx unavailable path is bad", {
  # Test graceful failure on bad output path
  skip_if_not_installed()
  result <- turas_write_stats_pack(make_minimal_payload(),
                                   "/nonexistent/path/output.xlsx",
                                   protect_sheets = FALSE)
  expect_null(result)
})

test_that("returns NULL when payload is not a list", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))
  result <- turas_write_stats_pack("not a list", tmp)
  expect_null(result)
})


# ==============================================================================
# SHEET STRUCTURE
# ==============================================================================

test_that("workbook contains all six expected sheets", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  wb     <- openxlsx::loadWorkbook(tmp)
  sheets <- names(wb)

  expect_true("Declaration"     %in% sheets)
  expect_true("Data_Used"       %in% sheets)
  expect_true("Assumptions"     %in% sheets)
  expect_true("Warnings"        %in% sheets)
  expect_true("Reproducibility" %in% sheets)
  expect_true("Config_Echo"     %in% sheets)
})

test_that("sheet order is Declaration first", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  wb <- openxlsx::loadWorkbook(tmp)
  expect_equal(names(wb)[1], "Declaration")
})


# ==============================================================================
# DECLARATION SHEET CONTENT
# ==============================================================================

test_that("Declaration sheet contains module name", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Declaration", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("TEST", text))
})

test_that("Declaration sheet contains data receipt figures", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Declaration", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")

  # n_rows = 100 should appear somewhere
  expect_true(grepl("100", text))
  # file name
  expect_true(grepl("test_data.csv", text))
})

test_that("Declaration sheet reflects PARTIAL status", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_payload_with_warnings(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Declaration", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("PARTIAL", text))
})

test_that("Declaration sheet handles NULL optional identity fields", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  p <- make_minimal_payload()
  p$project_name  <- NULL
  p$analyst_name  <- NULL
  p$research_house <- NULL

  # Should not error
  expect_no_error(turas_write_stats_pack(p, tmp, protect_sheets = FALSE))
  expect_true(file.exists(tmp))
})


# ==============================================================================
# DATA USED SHEET
# ==============================================================================

test_that("Data_Used sheet contains per-item stats when provided", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  # Row 1 is the section header "Response Counts by Question"; data starts at row 2
  df <- openxlsx::read.xlsx(tmp, sheet = "Data_Used", startRow = 2, colNames = TRUE)
  expect_true("Question_ID" %in% names(df))
  expect_equal(nrow(df), 3L)
  expect_true("Q1" %in% df$Question_ID)
})

test_that("Data_Used sheet handles NULL per_item_stats gracefully", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  p <- make_minimal_payload()
  p$data_used$per_item_stats <- NULL

  expect_no_error(turas_write_stats_pack(p, tmp, protect_sheets = FALSE))
  expect_true(file.exists(tmp))
})


# ==============================================================================
# ASSUMPTIONS SHEET
# ==============================================================================

test_that("Assumptions sheet has Parameter and Value columns", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Assumptions", colNames = TRUE)
  expect_true("Parameter" %in% names(df))
  expect_true("Value"     %in% names(df))
})

test_that("Assumptions sheet contains all provided assumption keys", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Assumptions", colNames = TRUE)
  expect_true("Confidence Level" %in% df$Parameter)
  expect_true("TRS Status"       %in% df$Parameter)
  expect_true("TRS Events"       %in% df$Parameter)
})

test_that("Assumptions sheet contains CI method implementation note", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Assumptions", colNames = TRUE)
  vals <- paste(df$Value, collapse = " ")
  expect_true(grepl("base R", vals))
})

test_that("Assumptions sheet handles empty assumptions list", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  p <- make_minimal_payload()
  p$assumptions <- list()

  expect_no_error(turas_write_stats_pack(p, tmp, protect_sheets = FALSE))
  expect_true(file.exists(tmp))
})


# ==============================================================================
# WARNINGS SHEET
# ==============================================================================

test_that("Warnings sheet shows clean message when no events", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Warnings", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("cleanly|No warnings", text, ignore.case = TRUE))
})

test_that("Warnings sheet lists events when present", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_payload_with_warnings(), tmp, protect_sheets = FALSE)

  df <- openxlsx::read.xlsx(tmp, sheet = "Warnings", colNames = TRUE)
  expect_true("Level" %in% names(df))
  expect_equal(nrow(df), 2L)
  expect_true("PARTIAL" %in% df$Level)
  expect_true("INFO"    %in% df$Level)
})

test_that("Warnings sheet handles NULL run_result gracefully", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  p <- make_minimal_payload()
  p$run_result <- NULL

  expect_no_error(turas_write_stats_pack(p, tmp, protect_sheets = FALSE))
  expect_true(file.exists(tmp))
})


# ==============================================================================
# REPRODUCIBILITY SHEET
# ==============================================================================

test_that("Reproducibility sheet contains R version", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Reproducibility", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("R version|R Version", text, ignore.case = TRUE))
})

test_that("Reproducibility sheet contains Turas version", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Reproducibility", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("1\\.0", text))  # turas_version = "1.0"
})

test_that("Reproducibility sheet lists packages with versions", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Reproducibility", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("openxlsx", text))
  expect_true(grepl("readxl",   text))
})

test_that("Reproducibility sheet includes seeds when provided", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_payload_with_seeds(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Reproducibility", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("42",    text))
  expect_true(grepl("12345", text))
})

test_that("Reproducibility sheet omits seeds section when not provided", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  p <- make_minimal_payload()
  p$seeds <- NULL

  expect_no_error(turas_write_stats_pack(p, tmp, protect_sheets = FALSE))
  expect_true(file.exists(tmp))
})


# ==============================================================================
# CONFIG ECHO SHEET
# ==============================================================================

test_that("Config_Echo sheet contains setting keys from config", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)

  df   <- openxlsx::read.xlsx(tmp, sheet = "Config_Echo", colNames = FALSE)
  text <- paste(unlist(df), collapse = " ")
  expect_true(grepl("Data_File|Confidence_Level", text))
})

test_that("Config_Echo sheet handles NULL config gracefully", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  p <- make_minimal_payload()
  p$config_echo <- NULL

  expect_no_error(turas_write_stats_pack(p, tmp, protect_sheets = FALSE))
  expect_true(file.exists(tmp))
})


# ==============================================================================
# EDGE CASES
# ==============================================================================

test_that("handles completely minimal payload with only module field", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  minimal <- list(module = "TEST", status = "PASS")
  expect_no_error(turas_write_stats_pack(minimal, tmp, protect_sheets = FALSE))
  expect_true(file.exists(tmp))
})

test_that("overwrites existing file at output path", {
  skip_if_not_installed()
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  # Write twice
  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)
  size1 <- file.info(tmp)$size

  turas_write_stats_pack(make_minimal_payload(), tmp, protect_sheets = FALSE)
  size2 <- file.info(tmp)$size

  expect_true(file.exists(tmp))
  # Both writes should produce roughly the same size
  expect_true(abs(size1 - size2) < 10000)
})
