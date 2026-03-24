# ==============================================================================
# PRICING MODULE - CONFIG TEMPLATE GENERATOR TESTS
# ==============================================================================
# Tests for generate_config_templates.R:
#   - generate_pricing_config_template()
#
# Run with:
#   testthat::test_file("modules/pricing/tests/testthat/test_config_templates.R")
# ==============================================================================

# setup.R provides TURAS_ROOT

pricing_root <- file.path(TURAS_ROOT, "modules", "pricing")

# Source shared template infrastructure first (required by generator)
shared_styles <- file.path(TURAS_ROOT, "modules", "shared", "template_styles.R")
if (file.exists(shared_styles)) source(shared_styles)

# Source the template generator
source(file.path(pricing_root, "lib", "generate_config_templates.R"))


# ==============================================================================
# TESTS: generate_pricing_config_template()
# ==============================================================================

test_that("generate_pricing_config_template creates a valid Excel file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  result <- generate_pricing_config_template(tmp)

  expect_true(file.exists(tmp))
  expect_true(file.size(tmp) > 0)
})

test_that("pricing config template contains expected sheets", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_pricing_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expected_sheets <- c("Settings", "VanWestendorp", "GaborGranger", "Validation")
  for (s in expected_sheets) {
    expect_true(s %in% sheets,
                info = sprintf("Missing sheet '%s'", s))
  }
})

test_that("pricing config template includes Monadic sheet by default", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_pricing_config_template(tmp, include_monadic = TRUE)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Monadic" %in% sheets)
})

test_that("pricing config template excludes Monadic when disabled", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_pricing_config_template(tmp, include_monadic = FALSE)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_false("Monadic" %in% sheets)
})

test_that("pricing config template includes Simulator sheet by default", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_pricing_config_template(tmp, include_simulator = TRUE)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Simulator" %in% sheets)
})

test_that("pricing config template excludes Simulator when disabled", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_pricing_config_template(tmp, include_simulator = FALSE)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_false("Simulator" %in% sheets)
})

test_that("pricing config template includes Reference sheet", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_pricing_config_template(tmp)
  sheets <- openxlsx::getSheetNames(tmp)

  expect_true("Reference" %in% sheets)
})

test_that("pricing config template overwrites existing file", {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  generate_pricing_config_template(tmp)
  first_size <- file.size(tmp)

  generate_pricing_config_template(tmp)
  second_size <- file.size(tmp)

  expect_true(file.exists(tmp))
  expect_true(second_size > 0)
})
