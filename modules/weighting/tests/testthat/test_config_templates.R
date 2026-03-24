# ==============================================================================
# WEIGHTING MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_weight_config_template()
#   - generate_all_weighting_templates()
#
# Run with:
#   testthat::test_file("modules/weighting/tests/testthat/test_config_templates.R")
# ==============================================================================

# setup.R provides TURAS_ROOT and MODULE_DIR

# Source shared template infrastructure first (required by generator)
shared_styles <- file.path(TURAS_ROOT, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator
source(file.path(MODULE_DIR, "lib", "generate_config_templates.R"))


# ==============================================================================
# TESTS: generate_weight_config_template()
# ==============================================================================

test_that("generate_weight_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_weight_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_true(isTRUE(result))
})

test_that("weighting config template contains all 7 expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expected_sheets <- c("General", "Weight_Specifications", "Design_Targets",
                        "Rim_Targets", "Cell_Targets", "Advanced_Settings", "Notes")
  for (s in expected_sheets) {
    expect_true(s %in% sheets,
                info = sprintf("Missing sheet '%s'", s))
  }
})

test_that("Weight_Specifications sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  ws <- openxlsx::read.xlsx(tmp, sheet = "Weight_Specifications", startRow = 3)

  expected_cols <- c("weight_name", "method", "apply_trimming")
  for (col in expected_cols) {
    expect_true(col %in% names(ws),
                info = sprintf("Missing column '%s' in Weight_Specifications", col))
  }
})

test_that("Rim_Targets sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  rt <- openxlsx::read.xlsx(tmp, sheet = "Rim_Targets", startRow = 3)

  expected_cols <- c("weight_name", "variable", "category", "target_percent")
  for (col in expected_cols) {
    expect_true(col %in% names(rt),
                info = sprintf("Missing column '%s' in Rim_Targets", col))
  }
})

test_that("Design_Targets sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_weight_config_template(tmp)
  dt <- openxlsx::read.xlsx(tmp, sheet = "Design_Targets", startRow = 3)

  expected_cols <- c("weight_name", "stratum_variable", "stratum_category", "population_size")
  for (col in expected_cols) {
    expect_true(col %in% names(dt),
                info = sprintf("Missing column '%s' in Design_Targets", col))
  }
})

test_that("generate_weight_config_template returns TRS refusal for NULL path", {
  result <- generate_weight_config_template(NULL)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})

test_that("generate_weight_config_template returns TRS refusal for non-character path", {
  result <- generate_weight_config_template(123)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})


# ==============================================================================
# TESTS: generate_all_weighting_templates()
# ==============================================================================

test_that("generate_all_weighting_templates creates file in output dir", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("weighting_tpl_", Sys.getpid()))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  result <- generate_all_weighting_templates(out_dir)

  expected_path <- file.path(out_dir, "Weight_Config.xlsx")
  expect_true(file.exists(expected_path))
  expect_true(isTRUE(result))
})

test_that("generate_all_weighting_templates returns TRS refusal for NULL dir", {
  result <- generate_all_weighting_templates(NULL)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_PATH")
})
