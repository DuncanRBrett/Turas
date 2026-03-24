# ==============================================================================
# REPORT HUB - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_report_hub_config_template()
#   - generate_all_report_hub_templates()
#
# Run with:
#   testthat::test_file("modules/report_hub/tests/testthat/test_config_templates.R")
# ==============================================================================

# helper-setup.R provides hub_root

# Resolve turas root from hub_root
turas_root_rh <- normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE)
if (!dir.exists(file.path(turas_root_rh, "modules", "shared"))) {
  candidate <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(candidate, "modules", "shared"))) {
      turas_root_rh <- candidate
      break
    }
    candidate <- dirname(candidate)
  }
}

# Source shared template infrastructure
shared_styles <- file.path(turas_root_rh, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator
source(file.path(hub_root, "lib", "generate_config_templates.R"))


# ==============================================================================
# TESTS: generate_report_hub_config_template()
# ==============================================================================

test_that("generate_report_hub_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_report_hub_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
  expect_true(isTRUE(result))
})

test_that("report hub config template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_report_hub_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expected_sheets <- c("Settings", "Reports", "Slides")
  for (s in expected_sheets) {
    expect_true(s %in% sheets,
                info = sprintf("Missing sheet '%s'", s))
  }
})

test_that("Reports sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_report_hub_config_template(tmp)
  reports <- openxlsx::read.xlsx(tmp, sheet = "Reports", startRow = 3)

  expected_cols <- c("report_path", "report_label", "report_key", "order")
  for (col in expected_cols) {
    expect_true(col %in% names(reports),
                info = sprintf("Missing column '%s' in Reports sheet", col))
  }
})

test_that("Slides sheet has expected columns", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_report_hub_config_template(tmp)
  slides <- openxlsx::read.xlsx(tmp, sheet = "Slides", startRow = 3)

  expected_cols <- c("slide_title", "content", "display_order")
  for (col in expected_cols) {
    expect_true(col %in% names(slides),
                info = sprintf("Missing column '%s' in Slides sheet", col))
  }
})

test_that("Reports sheet contains example rows", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_report_hub_config_template(tmp)
  reports <- openxlsx::read.xlsx(tmp, sheet = "Reports", startRow = 3)

  # Should have at least the 3 example rows
  expect_gte(nrow(reports), 3)
})

test_that("report hub config template has exactly 3 sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_report_hub_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_equal(length(sheets), 3)
})


# ==============================================================================
# TESTS: generate_all_report_hub_templates()
# ==============================================================================

test_that("generate_all_report_hub_templates creates file in output dir", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("report_hub_tpl_", Sys.getpid()))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  result <- generate_all_report_hub_templates(out_dir)

  expected_path <- file.path(out_dir, "Report_Hub_Config_Template.xlsx")
  expect_true(file.exists(expected_path))
  expect_true(isTRUE(result))
})

test_that("generate_all_report_hub_templates creates output dir if missing", {
  tmp_dir <- tempdir()
  out_dir <- file.path(tmp_dir, paste0("rh_new_dir_", Sys.getpid()))
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  # Ensure dir does not exist
  if (dir.exists(out_dir)) unlink(out_dir, recursive = TRUE)

  result <- generate_all_report_hub_templates(out_dir)

  expect_true(dir.exists(out_dir))
  expect_true(isTRUE(result))
})
