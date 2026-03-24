# ==============================================================================
# CONFIDENCE MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_confidence_config_template()
#   - generate_all_confidence_templates()
#
# Run with:
#   testthat::test_file("modules/confidence/tests/testthat/test_config_templates.R")
# ==============================================================================

# setup.R provides TURAS_ROOT and MODULE_DIR

# Source shared template infrastructure first (required by generator)
shared_styles <- file.path(TURAS_ROOT, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator.
# The generator tries sys.frame(1)$ofile to find shared/template_styles.R,
# which fails in test context. We work around this by:
# 1. Already having sourced template_styles.R above
# 2. Sourcing from project root so the fallback path resolves
# 3. Wrapping the source in tryCatch to handle the sys.frame error gracefully
old_wd <- getwd()
setwd(TURAS_ROOT)

# Create a temporary modified version that handles missing ofile
gen_file <- file.path(MODULE_DIR, "lib", "generate_config_templates.R")
gen_code <- readLines(gen_file)
# Replace sys.frame(1)$ofile with a safe alternative that returns "." when NULL
gen_code <- gsub(
  "sys\\.frame\\(1\\)\\$ofile",
  '{x <- sys.frame(1)$ofile; if (is.null(x)) "." else x}',
  gen_code
)
tmp_gen <- tempfile(fileext = ".R")
writeLines(gen_code, tmp_gen)
source(tmp_gen)
unlink(tmp_gen)

setwd(old_wd)


# ==============================================================================
# TESTS: generate_confidence_config_template()
# ==============================================================================

test_that("generate_confidence_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_confidence_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_equal(result, tmp)
})

test_that("confidence config template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_confidence_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expected_sheets <- c("File_Paths", "Study_Settings",
                        "Question_Analysis", "Population_Margins")
  for (s in expected_sheets) {
    expect_true(s %in% sheets,
                info = sprintf("Missing sheet '%s'", s))
  }
})

test_that("Question_Analysis sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_confidence_config_template(tmp)
  qa <- openxlsx::read.xlsx(tmp, sheet = "Question_Analysis", startRow = 3)

  expected_cols <- c("Question_ID", "Statistic_Type", "Run_MOE",
                     "Run_Wilson", "Run_Bootstrap", "Run_Credible")
  for (col in expected_cols) {
    expect_true(col %in% names(qa),
                info = sprintf("Missing column '%s' in Question_Analysis", col))
  }
})

test_that("Population_Margins sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_confidence_config_template(tmp)
  pm <- openxlsx::read.xlsx(tmp, sheet = "Population_Margins", startRow = 3)

  expected_cols <- c("Variable", "Category_Label", "Target_Prop")
  for (col in expected_cols) {
    expect_true(col %in% names(pm),
                info = sprintf("Missing column '%s' in Population_Margins", col))
  }
})

test_that("confidence config template returns TRS refusal for invalid output dir", {
  bad_path <- file.path("/nonexistent_dir_abc123", "config.xlsx")

  result <- generate_confidence_config_template(bad_path)

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_OUTPUT_DIR_MISSING")
})

test_that("Question_Analysis sheet contains example rows", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_confidence_config_template(tmp)
  qa <- openxlsx::read.xlsx(tmp, sheet = "Question_Analysis", startRow = 3)

  # Should have at least the 3 example rows
  expect_gte(nrow(qa), 3)
})


# ==============================================================================
# TESTS: generate_all_confidence_templates()
# ==============================================================================

test_that("generate_all_confidence_templates creates file in output dir", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("confidence_tpl_", Sys.getpid()))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  result <- generate_all_confidence_templates(out_dir)

  expected_path <- file.path(out_dir, "Confidence_Config_Template.xlsx")
  expect_true(file.exists(expected_path))
  expect_equal(result, expected_path)
})

test_that("generate_all_confidence_templates returns TRS refusal for invalid dir", {
  result <- generate_all_confidence_templates("/nonexistent_dir_abc123")

  expect_true(is.list(result))
  expect_equal(result$status, "REFUSED")
})
