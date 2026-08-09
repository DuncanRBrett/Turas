# ==============================================================================
# SHARED - load_config_table_sheet() keeps column types through a template read
# ==============================================================================
# Generated templates put a row of per-column help text directly under the
# headers. readxl types a column from everything it reads, so that one text row
# turned every column character — and dropping it afterwards does not undo the
# typing. A column of ratings then arrived as "8.2", "7.5", and the calling
# module refused it as non-numeric.
# ==============================================================================

library(testthat)

turas_root <- local({
  p <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(p, "modules", "shared", "lib"))) return(normalizePath(p))
    p <- dirname(p)
  }
  NULL
})

skip_if(is.null(turas_root), "Turas root not found")
skip_if_not_installed("openxlsx")
skip_if_not_installed("readxl")

source(file.path(turas_root, "modules/shared/lib/config_utils.R"))

# A sheet shaped like a generated template: title, subtitle, headers, help, data.
write_template_shaped_sheet <- function(path, help_row = TRUE) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "StatedImportance")

  # Title, subtitle, headers — the rows a generated template puts above the data.
  openxlsx::writeData(wb, "StatedImportance",
                      "TURAS Module - Stated Importance", startRow = 1)
  openxlsx::writeData(wb, "StatedImportance",
                      "Ratings used for the quadrant analysis", startRow = 2)
  openxlsx::writeData(wb, "StatedImportance",
                      data.frame(driver = character(0),
                                 stated_importance = numeric(0)),
                      startRow = 3, colNames = TRUE)

  data_row <- 4
  if (help_row) {
    openxlsx::writeData(wb, "StatedImportance",
                        data.frame(a = "[REQUIRED] Must match the Variables sheet",
                                   b = "[REQUIRED] Mean rating (1-10)",
                                   stringsAsFactors = FALSE),
                        startRow = 4, colNames = FALSE)
    data_row <- 5
  }

  # The values are written as real numbers, as a generated template writes them.
  openxlsx::writeData(wb, "StatedImportance",
                      data.frame(driver = c("service_quality", "value_for_money",
                                            "brand_trust"),
                                 stated_importance = c(8.2, 7.5, 7.1),
                                 stringsAsFactors = FALSE),
                      startRow = data_row, colNames = FALSE)

  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

test_that("a numeric column stays numeric when a help row sits above the data", {
  p <- tempfile(fileext = ".xlsx")
  on.exit(unlink(p), add = TRUE)
  write_template_shaped_sheet(p)

  df <- as.data.frame(load_config_table_sheet(
    p, "StatedImportance", required_cols = c("driver", "stated_importance")
  ))

  expect_equal(names(df), c("driver", "stated_importance"))
  expect_equal(nrow(df), 3)
  expect_true(is.numeric(df$stated_importance))
  expect_equal(df$stated_importance, c(8.2, 7.5, 7.1))
  expect_equal(df$driver[1], "service_quality")
})

test_that("the help row itself never survives as data", {
  p <- tempfile(fileext = ".xlsx")
  on.exit(unlink(p), add = TRUE)
  write_template_shaped_sheet(p)

  df <- as.data.frame(load_config_table_sheet(
    p, "StatedImportance", required_cols = c("driver", "stated_importance")
  ))

  expect_false(any(grepl("^\\[REQUIRED\\]", as.character(df$driver))))
})

test_that("a template with no help row is read the same way", {
  p <- tempfile(fileext = ".xlsx")
  on.exit(unlink(p), add = TRUE)
  write_template_shaped_sheet(p, help_row = FALSE)

  df <- as.data.frame(load_config_table_sheet(
    p, "StatedImportance", required_cols = c("driver", "stated_importance")
  ))

  expect_equal(nrow(df), 3)
  expect_true(is.numeric(df$stated_importance))
})

test_that("headers already in row 1 are returned untouched", {
  # The hand-built case. It must not go anywhere near the re-read path.
  p <- tempfile(fileext = ".xlsx")
  on.exit(unlink(p), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "StatedImportance")
  openxlsx::writeData(wb, "StatedImportance", data.frame(
    driver = c("a", "b"), stated_importance = c(1.5, 2.5),
    stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, p, overwrite = TRUE)

  df <- as.data.frame(load_config_table_sheet(
    p, "StatedImportance", required_cols = c("driver", "stated_importance")
  ))

  expect_equal(nrow(df), 2)
  expect_true(is.numeric(df$stated_importance))
  expect_equal(df$stated_importance, c(1.5, 2.5))
})
