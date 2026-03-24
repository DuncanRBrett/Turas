# ==============================================================================
# TABS MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_crosstab_config_template()
#   - generate_survey_structure_template()
#   - generate_all_templates()
#
# Run with:
#   testthat::test_file("modules/tabs/tests/testthat/test_config_templates.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

detect_turas_root <- function() {
  turas_home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(turas_home) && dir.exists(file.path(turas_home, "modules"))) {
    return(normalizePath(turas_home, mustWork = FALSE))
  }
  candidates <- c(
    getwd(),
    file.path(getwd(), "../.."),
    file.path(getwd(), "../../.."),
    file.path(getwd(), "../../../..")
  )
  for (candidate in candidates) {
    resolved <- tryCatch(normalizePath(candidate, mustWork = FALSE), error = function(e) "")
    if (nzchar(resolved) && dir.exists(file.path(resolved, "modules"))) {
      return(resolved)
    }
  }
  stop("Cannot detect TURAS project root. Set TURAS_HOME environment variable.")
}

turas_root <- detect_turas_root()
tabs_root <- file.path(turas_root, "modules", "tabs")

# Source shared TRS infrastructure
trs_path <- file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R")
if (file.exists(trs_path)) source(trs_path)

# Source shared template infrastructure first (the generator relies on
# sys.frame(1)$ofile which may not resolve in test context)
shared_styles <- file.path(turas_root, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator
source(file.path(tabs_root, "lib", "generate_config_templates.R"))


# ==============================================================================
# TESTS: generate_crosstab_config_template()
# ==============================================================================

test_that("generate_crosstab_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_crosstab_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_equal(result, tmp)
})

test_that("crosstab config template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Settings" %in% sheets)
  expect_true("Selection" %in% sheets)
  expect_true("Comments" %in% sheets)
  expect_true("AddedSlides" %in% sheets)
})

test_that("crosstab config Settings sheet has expected structure", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  settings <- openxlsx::read.xlsx(tmp, sheet = "Settings")

  # Settings sheet uses key-value layout; first column should contain field names
  expect_true(nrow(settings) > 0)
})

test_that("crosstab config Selection sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  selection <- openxlsx::read.xlsx(tmp, sheet = "Selection", startRow = 3)

  expected_cols <- c("QuestionCode", "Include", "UseBanner")
  for (col in expected_cols) {
    expect_true(col %in% names(selection),
                info = sprintf("Missing column '%s' in Selection sheet", col))
  }
})


# ==============================================================================
# TESTS: generate_survey_structure_template()
# ==============================================================================

test_that("generate_survey_structure_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_survey_structure_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_equal(result, tmp)
})

test_that("survey structure template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_survey_structure_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Project" %in% sheets)
  expect_true("Questions" %in% sheets)
  expect_true("Options" %in% sheets)
  expect_true("Composite_Metrics" %in% sheets)
})

test_that("survey structure Questions sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_survey_structure_template(tmp)
  questions <- openxlsx::read.xlsx(tmp, sheet = "Questions", startRow = 3)

  expected_cols <- c("QuestionCode", "QuestionText", "Variable_Type", "Columns")
  for (col in expected_cols) {
    expect_true(col %in% names(questions),
                info = sprintf("Missing column '%s' in Questions sheet", col))
  }
})

test_that("survey structure Options sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_survey_structure_template(tmp)
  options_df <- openxlsx::read.xlsx(tmp, sheet = "Options", startRow = 3)

  expected_cols <- c("QuestionCode", "OptionText", "DisplayText")
  for (col in expected_cols) {
    expect_true(col %in% names(options_df),
                info = sprintf("Missing column '%s' in Options sheet", col))
  }
})


# ==============================================================================
# TESTS: generate_all_templates()
# ==============================================================================

test_that("generate_all_templates creates both files", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("tabs_templates_", Sys.getpid()))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  result <- generate_all_templates(out_dir)

  config_path <- file.path(out_dir, "Crosstab_Config.xlsx")
  structure_path <- file.path(out_dir, "Survey_Structure.xlsx")

  expect_true(file.exists(config_path),
              info = "Crosstab_Config.xlsx should be created")
  expect_true(file.exists(structure_path),
              info = "Survey_Structure.xlsx should be created")
})

test_that("crosstab config template overwrites existing file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_crosstab_config_template(tmp)
  first_size <- file.size(tmp)

  generate_crosstab_config_template(tmp)
  second_size <- file.size(tmp)

  # File should still exist and be valid

  expect_true(file.exists(tmp))
  expect_true(second_size > 0)
})
