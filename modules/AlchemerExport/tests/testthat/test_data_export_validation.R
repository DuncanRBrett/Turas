# Tests for the data-export validation and safe-reading hardening added to
# scripts/alchemer_to_turas.R.
#
# Covers:
#   .att_validate_data_export      — up-front path/format checks (fail fast)
#   .att_openxlsx_readable_path     — case-insensitive .xlsx/.xlsm reading
#   .att_detect_alchemer_header_row — csv + xlsx + unsupported-format guard
#
# These paths are exercised without touching the Alchemer API: validation runs
# before the fetch, and the readers work on local fixture files built in tempdir.

# --- locate repo root and source the script under test ----------------------
find_repo_root <- function(start = getwd()) {
  d <- normalizePath(start, mustWork = FALSE)
  for (i in seq_len(8L)) {
    if (file.exists(file.path(d, "scripts", "alchemer_to_turas.R"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("Could not locate Turas repo root from: ", start)
}

repo_root <- find_repo_root()
Sys.setenv(TURAS_ROOT = repo_root)
suppressWarnings(suppressMessages(
  source(file.path(repo_root, "scripts", "alchemer_to_turas.R"))
))

# --- fixture helper ---------------------------------------------------------
make_xlsx <- function(path, df = data.frame(a = 1:2, b = c("x", "y"),
                                            stringsAsFactors = FALSE)) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sheet1")
  openxlsx::writeData(wb, "Sheet1", df, colNames = TRUE)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

# --- .att_validate_data_export ----------------------------------------------
test_that("validate returns NULL when no export is supplied", {
  expect_null(.att_validate_data_export(NULL))
  expect_null(.att_validate_data_export(""))
  expect_null(.att_validate_data_export("   "))
})

test_that("validate refuses a missing file with a clear, actionable message", {
  missing <- file.path(tempdir(), "does_not_exist_9f2a.xlsx")
  expect_false(file.exists(missing))
  expect_error(.att_validate_data_export(missing), "not found", ignore.case = TRUE)
  # Message points the user at the escape hatch.
  expect_error(.att_validate_data_export(missing), "structure-only",
               ignore.case = TRUE)
})

test_that("validate refuses an existing file of an unsupported format", {
  bad_xls <- file.path(tempdir(), "old_export.xls")
  writeLines("not a real xls", bad_xls)
  expect_error(.att_validate_data_export(bad_xls), "Supported formats",
               ignore.case = TRUE)

  no_ext <- file.path(tempdir(), "exportfile_noext")
  writeLines("stuff", no_ext)
  expect_error(.att_validate_data_export(no_ext), "no extension",
               ignore.case = TRUE)
})

test_that("validate accepts csv and xlsx and returns the path", {
  csv <- file.path(tempdir(), "export_ok.csv")
  utils::write.csv(data.frame(a = 1), csv, row.names = FALSE)
  expect_identical(.att_validate_data_export(csv), path.expand(csv))

  xlsx <- make_xlsx(file.path(tempdir(), "export_ok.xlsx"))
  expect_identical(.att_validate_data_export(xlsx), path.expand(xlsx))
})

# --- .att_openxlsx_readable_path --------------------------------------------
test_that("readable-path passes a lowercase .xlsx through unchanged", {
  xlsx <- make_xlsx(file.path(tempdir(), "keep.xlsx"))
  expect_identical(.att_openxlsx_readable_path(xlsx), xlsx)
})

test_that("readable-path stages a temp copy for an uppercase extension", {
  up  <- make_xlsx(file.path(tempdir(), "UPPER.XLSX"))
  got <- .att_openxlsx_readable_path(up)
  expect_false(identical(got, up))
  expect_true(file.exists(got))
  expect_match(got, "\\.xlsx$")
  # openxlsx can actually read the staged copy.
  df <- openxlsx::read.xlsx(got)
  expect_true(nrow(df) >= 1L)
})

# --- .att_detect_alchemer_header_row ----------------------------------------
test_that("detect reads a csv header row", {
  csv <- file.path(tempdir(), "hdr.csv")
  utils::write.csv(data.frame(Q1 = 1, Q2 = 2, check.names = FALSE), csv,
                   row.names = FALSE)
  det <- .att_detect_alchemer_header_row(csv)
  expect_equal(det$row_index, 1L)
  expect_true(all(c("Q1", "Q2") %in% det$values))
})

test_that("detect finds the colon-format header row in xlsx (incl. uppercase ext)", {
  df <- data.frame(
    c1 = c("Option A:Q1 label", "resp1"),
    c2 = c("Option B:Q1 label", "resp2"),
    stringsAsFactors = FALSE
  )
  xlsx <- make_xlsx(file.path(tempdir(), "hdr.xlsx"), df)
  det  <- .att_detect_alchemer_header_row(xlsx)
  expect_true(any(grepl(":", det$values)))

  up     <- make_xlsx(file.path(tempdir(), "HDR.XLSX"), df)
  det_up <- .att_detect_alchemer_header_row(up)
  expect_true(any(grepl(":", det_up$values)))
})

test_that("detect refuses an unsupported format cleanly (no raw openxlsx error)", {
  bad <- file.path(tempdir(), "weird.docx")
  writeLines("x", bad)
  expect_error(.att_detect_alchemer_header_row(bad), "unsupported format",
               ignore.case = TRUE)
})
