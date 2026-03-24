# ==============================================================================
# CONJOINT MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for R/12_config_template.R:
#   - generate_conjoint_config_template()
#
# Run with:
#   testthat::test_file("modules/conjoint/tests/testthat/test_config_templates.R")
# ==============================================================================

# helper-setup.R provides turas_root and module_root, and sources R/*.R files
# including 12_config_template.R


# ==============================================================================
# TESTS: generate_conjoint_config_template()
# ==============================================================================

test_that("generate_conjoint_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_conjoint_config_template(tmp, verbose = FALSE)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})

test_that("conjoint config template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_conjoint_config_template(tmp, verbose = FALSE)
  sheets <- openxlsx::getSheetNames(tmp)

  expected_sheets <- c("Settings", "Attributes", "Design", "Instructions")
  for (s in expected_sheets) {
    expect_true(s %in% sheets,
                info = sprintf("Missing sheet '%s'", s))
  }
})

test_that("conjoint config template includes Custom_Slides sheet", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_conjoint_config_template(tmp, verbose = FALSE)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Custom_Slides" %in% sheets)
})

test_that("conjoint config template includes Custom_Images sheet", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_conjoint_config_template(tmp, verbose = FALSE)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Custom_Images" %in% sheets)
})

test_that("conjoint config template has at least 6 sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_conjoint_config_template(tmp, verbose = FALSE)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_gte(length(sheets), 6)
})

test_that("conjoint config template works with include_examples = FALSE", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_conjoint_config_template(tmp, include_examples = FALSE,
                                               verbose = FALSE)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})

test_that("conjoint config template overwrites existing file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_conjoint_config_template(tmp, verbose = FALSE)
  first_size <- file.size(tmp)

  generate_conjoint_config_template(tmp, verbose = FALSE)
  second_size <- file.size(tmp)

  expect_true(file.exists(tmp))
  expect_true(second_size > 0)
})

test_that("conjoint config template uses default output path when not specified", {
  # Use a temp directory to avoid polluting working directory
  old_wd <- getwd()
  tmp_dir <- tempdir()
  setwd(tmp_dir)
  on.exit({
    setwd(old_wd)
    unlink(file.path(tmp_dir, "Conjoint_Config_Template.xlsx"))
  }, add = TRUE)

  result <- generate_conjoint_config_template(verbose = FALSE)

  expect_true(file.exists(file.path(tmp_dir, "Conjoint_Config_Template.xlsx")))
})
