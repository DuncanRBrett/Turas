# test-vas_pipeline.R
# Tests for the shared runner setup: locating the export, loading the library,
# and refusing a workbook that is not an export.

#' Create a folder of empty workbooks with fixed modification times
#'
#' @param files A named character vector: name = file name, value = an ISO
#'   timestamp to stamp it with.
#'
#' @return The folder path.
fixture_folder <- function(files) {
  folder <- file.path(tempdir(), paste0("vas_folder_", length(files), "_",
                                        substr(digest_names(names(files)), 1, 8)))
  unlink(folder, recursive = TRUE)
  dir.create(folder, recursive = TRUE)
  for (i in seq_along(files)) {
    path <- file.path(folder, names(files)[i])
    writeLines("placeholder", path)
    Sys.setFileTime(path, as.POSIXct(files[[i]], tz = "UTC"))
  }
  return(folder)
}

#' A stable short key for a set of file names, so folders do not collide
#'
#' @param names A character vector.
#'
#' @return A character value.
digest_names <- function(names) {
  return(paste0(sprintf("%08x", sum(utf8ToInt(paste(names, collapse = "")))), "0000"))
}

test_that("the newest matching export is chosen", {
  folder <- fixture_folder(c(
    "VAS Export.xlsx"      = "2026-07-20 09:00:00",
    "VAS Export Test.xlsx" = "2026-07-22 21:38:00"
  ))
  expect_equal(basename(find_latest_export(folder)), "VAS Export Test.xlsx")
})

test_that("workbooks that are not exports are ignored, however recent", {
  # REGRESSION: the real fieldwork folder holds checklists and sample frames,
  # and the most recently touched workbook was a sample file, not an export.
  folder <- fixture_folder(c(
    "VAS Export Test.xlsx"                   = "2026-07-22 21:38:00",
    "Infield VAS sample.xlsx"                = "2026-07-22 22:13:00",
    "VAS 2026 Fieldwork checklist.xlsx"      = "2026-07-22 22:14:00",
    "Provisional Electrum sample.xlsx"       = "2026-07-22 22:15:00"
  ))
  expect_equal(basename(find_latest_export(folder)), "VAS Export Test.xlsx")
})

test_that("the pipeline's own output is never taken as input", {
  folder <- fixture_folder(c(
    "VAS Export Test.xlsx"    = "2026-07-22 21:38:00",
    "VAS Derived Numbers.xlsx" = "2026-07-22 23:00:00"
  ))
  expect_equal(basename(find_latest_export(folder)), "VAS Export Test.xlsx")
})

test_that("Excel lock files are ignored", {
  folder <- fixture_folder(c(
    "VAS Export Test.xlsx"    = "2026-07-22 21:38:00",
    "~$VAS Export Open.xlsx"  = "2026-07-22 23:00:00"
  ))
  expect_equal(basename(find_latest_export(folder)), "VAS Export Test.xlsx")
})

test_that("a folder with no export throws, naming what it did see", {
  folder <- fixture_folder(c(
    "Interviewer status VAS 2026.xlsx" = "2026-07-22 22:00:00",
    "Checkers VAS.xlsx"                = "2026-07-22 22:01:00"
  ))
  error <- tryCatch(find_latest_export(folder), error = function(e) e)
  expect_s3_class(error, "vas_no_export")
  expect_true(grepl("Interviewer status VAS 2026.xlsx", conditionMessage(error), fixed = TRUE))
  expect_true(grepl("VAS Export", conditionMessage(error), fixed = TRUE))
})

test_that("an entirely empty folder throws rather than returning nothing", {
  folder <- fixture_folder(character(0))
  expect_error(find_latest_export(folder), class = "vas_no_export")
})

test_that("the export pattern can be changed", {
  folder <- fixture_folder(c("Alchemer dump.xlsx" = "2026-07-22 22:00:00"))
  expect_error(find_latest_export(folder), class = "vas_no_export")
  expect_equal(basename(find_latest_export(folder, pattern = "Alchemer*.xlsx")),
               "Alchemer dump.xlsx")
})

test_that("a workbook that is not an Alchemer export is refused by name", {
  path <- file.path(tempdir(), "VAS Export NotReally.xlsx")
  openxlsx::write.xlsx(data.frame(Region = "Gauteng", Interviewer = "A. Smith",
                                  stringsAsFactors = FALSE), path, colNames = TRUE)
  error <- tryCatch(read_vas_export(path), error = function(e) e)
  expect_s3_class(error, "vas_not_an_export")
  expect_true(grepl("does not look like an Alchemer export", conditionMessage(error),
                    fixed = TRUE))
  expect_true(grepl("Response ID", conditionMessage(error), fixed = TRUE))
})

test_that("a missing export file is reported separately from a wrong one", {
  expect_error(read_vas_export(file.path(tempdir(), "no_such_file.xlsx")),
               class = "vas_export_unreadable")
})

test_that("loading from a directory without the code throws, listing what is absent", {
  empty <- file.path(tempdir(), "vas_empty_code_dir")
  dir.create(empty, showWarnings = FALSE)
  error <- tryCatch(load_vas_library(empty), error = function(e) e)
  expect_s3_class(error, "vas_code_missing")
  expect_true(grepl("vas_derive.R", conditionMessage(error), fixed = TRUE))
  expect_true(grepl("vas_category_map.csv", conditionMessage(error), fixed = TRUE))
})

test_that("the library list names every file the runners need", {
  expect_true(all(c("vas_amount_parser.R", "vas_frequency.R", "vas_read_source.R",
                    "vas_derive_category.R", "vas_derive.R", "vas_sense_check.R",
                    "vas_data_dictionary.R", "vas_data_dictionary_headline.R",
                    "vas_write_excel.R") %in% VAS_LIBRARY_FILES))
  expect_true(all(file.exists(file.path(VAS_PROJECT_ROOT, VAS_LIBRARY_FILES))))
})

test_that("derive_and_report returns the result, the dictionary and the failures", {
  map <- fixture_totals_map()
  derived <- expect_output(derive_and_report(fixture_totals_source(), map, VAS_CONFIG))
  expect_equal(names(derived), c("result", "dictionary", "failures"))
  expect_equal(nrow(derived$result$wide), 2L)
  expect_equal(nrow(derived$dictionary), ncol(derived$result$wide))
  expect_equal(length(derived$failures), 0L)
})
