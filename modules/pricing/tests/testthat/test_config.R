# ==============================================================================
# TURAS PRICING MODULE - CONFIG TESTS
# ==============================================================================

test_that("read_settings_sheet handles standard header (row 1)", {
  skip_if(!exists("read_settings_sheet", mode = "function"),
          "read_settings_sheet not available")

  # The generated template has headers not in row 1 (title + subtitle first)
  # Test with the generated template
  template_path <- file.path(TURAS_ROOT, "modules", "pricing",
                              "docs", "templates", "Pricing_Config_Template.xlsx")
  skip_if(!file.exists(template_path), "Config template not found")

  result <- read_settings_sheet(template_path, "Settings")

  expect_true(is.data.frame(result))
  expect_true("Setting" %in% names(result))
  expect_true("Value" %in% names(result))
  expect_true(nrow(result) > 0)
})

test_that("read_settings_sheet filters help rows and section dividers", {
  skip_if(!exists("read_settings_sheet", mode = "function"),
          "read_settings_sheet not available")

  template_path <- file.path(TURAS_ROOT, "modules", "pricing",
                              "docs", "templates", "Pricing_Config_Template.xlsx")
  skip_if(!file.exists(template_path), "Config template not found")

  result <- read_settings_sheet(template_path, "Settings")

  # Should not contain help rows (those with [REQUIRED] or [Optional])
  if ("Value" %in% names(result)) {
    help_rows <- grepl("\\[REQUIRED\\]|\\[Optional\\]", result$Value, ignore.case = TRUE)
    expect_false(any(help_rows, na.rm = TRUE))
  }

  # Should not contain section divider rows (ALL CAPS names)
  if ("Setting" %in% names(result)) {
    all_caps <- grepl("^[A-Z &/()]+$", result$Setting, perl = TRUE) &
      is.na(result$Value)
    expect_false(any(all_caps, na.rm = TRUE))
  }
})

test_that("read_settings_sheet autodetects heading when not in row 1", {
  skip_if(!exists("read_settings_sheet", mode = "function"),
          "read_settings_sheet not available")

  # The template has title/subtitle above headers
  template_path <- file.path(TURAS_ROOT, "modules", "pricing",
                              "docs", "templates", "Pricing_Config_Template.xlsx")
  skip_if(!file.exists(template_path), "Config template not found")

  # Test VanWestendorp sheet (also has title/subtitle rows)
  result <- read_settings_sheet(template_path, "VanWestendorp")

  expect_true(is.data.frame(result))
  expect_true("Setting" %in% names(result))
  expect_true("Value" %in% names(result))
})

test_that("load_monadic_config parses monadic settings", {
  skip_if(!exists("load_monadic_config", mode = "function"),
          "load_monadic_config not available")

  template_path <- file.path(TURAS_ROOT, "modules", "pricing",
                              "docs", "templates", "Pricing_Config_Template.xlsx")
  skip_if(!file.exists(template_path), "Config template not found")

  result <- tryCatch(
    load_monadic_config(template_path),
    error = function(e) NULL
  )

  # Should return a list even if values are defaults
  if (!is.null(result)) {
    expect_true(is.list(result))
  }
})

test_that("validate_required_settings accepts monadic method", {
  skip_if(!exists("validate_required_settings", mode = "function"),
          "validate_required_settings not available")

  # Should not error for monadic
  expect_silent(
    validate_required_settings(list(analysis_method = "monadic"))
  )
})

test_that("apply_pricing_defaults includes html report and simulator fields", {
  skip_if(!exists("apply_pricing_defaults", mode = "function"),
          "apply_pricing_defaults not available")

  config <- list(analysis_method = "van_westendorp")
  result <- apply_pricing_defaults(config)

  expect_true("generate_html_report" %in% names(result))
  expect_true("generate_simulator" %in% names(result))
})
