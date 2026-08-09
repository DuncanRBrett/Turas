# ==============================================================================
# CATDRIVER - the config template this module generates must load in this module
# ==============================================================================
# write_table_sheet() puts a title in row 1, a subtitle in row 2, the real
# column headers in row 3 and per-column help text in row 4. The config loader
# read with openxlsx::read.xlsx() and no startRow, so it took the title as the
# header row and refused the module's own generated template.
#
# Nothing caught it because every test fixture and example script builds configs
# with headers in row 1, and the template tests read at startRow = 3 and never
# went through the loader. This test is the round trip.
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
source(file.path(turas_root, "modules/shared/template_styles.R"))
source(file.path(turas_root, "modules/catdriver/lib/generate_config_templates.R"))

generated_template <- function() {
  p <- tempfile(fileext = ".xlsx")
  suppressMessages(generate_catdriver_config_template(p))
  p
}

test_that("the generated template's sheets load with their real headers", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  settings <- as.data.frame(load_config_table_sheet(
    p, "Settings", required_cols = c("Setting", "Value")
  ))

  # Row 1 is the title. If it were still being read as the header, "Setting"
  # and "Value" would not be column names at all.
  expect_true(all(c("Setting", "Value") %in% names(settings)))
  expect_gt(nrow(settings), 0)

  variables <- as.data.frame(load_config_table_sheet(
    p, "Variables", required_cols = "VariableName"
  ))
  expect_true("VariableName" %in% names(variables))
  expect_gt(nrow(variables), 0)
})

test_that("the help text row never arrives as data", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  variables <- as.data.frame(load_config_table_sheet(
    p, "Variables", required_cols = "VariableName"
  ))

  expect_false(any(grepl("^\\[REQUIRED\\]|^\\[Optional\\]",
                         as.character(variables[[1]]))))
})

test_that("every generated sheet still carries a title in row 1", {
  # If this ever stops being true the loader's header scan is doing nothing,
  # and the test above would pass for the wrong reason.
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  for (sh in openxlsx::getSheetNames(p)) {
    raw <- suppressMessages(readxl::read_excel(p, sheet = sh, col_names = FALSE,
                                               n_max = 1, col_types = "text"))
    expect_true(grepl("TURAS", as.character(raw[[1]][1]), fixed = TRUE),
                info = sprintf("sheet %s", sh))
  }
})

test_that("load_catdriver_config gets past the Settings structure check", {
  p <- generated_template()
  on.exit(unlink(p), add = TRUE)

  for (f in list.files(file.path(turas_root, "modules/catdriver/R"),
                       pattern = "[.]R$", full.names = TRUE)) {
    try(suppressMessages(suppressWarnings(source(f))), silent = TRUE)
  }
  skip_if_not(exists("load_catdriver_config", mode = "function"))

  outcome <- tryCatch(suppressMessages(load_catdriver_config(p)),
                      error = function(e) e)

  # A blank template has no data_file, so refusing is correct — but it must
  # refuse for THAT reason, not because it could not read its own Settings
  # sheet. CFG_SETTINGS_STRUCTURE_INVALID was the defect.
  if (inherits(outcome, "condition")) {
    expect_false(grepl("CFG_SETTINGS_STRUCTURE_INVALID",
                       conditionMessage(outcome), fixed = TRUE))
    expect_false(grepl("CFG_VARIABLES_COLUMNS_MISSING",
                       conditionMessage(outcome), fixed = TRUE))
  } else {
    expect_type(outcome, "list")
  }
})
