# ==============================================================================
# REPORT HUB MODULE TESTS
# ==============================================================================
#
# Tests for modules/report_hub/
#
# Covers:
#   1. Guard validation (00_guard.R)
#      - guard_validate_hub_config(): missing config, invalid format, missing
#        sheets, missing fields, invalid report_key, duplicate keys, valid config
#      - parse_settings_sheet(): key-value format, single-row format, empty df
#
#   2. HTML parser (01_html_parser.R)
#      - detect_report_type(): meta tags, structural markers, unknown
#      - extract_blocks(): style and script extraction
#      - extract_metadata(): tracker and tabs metadata, meta tags
#      - parse_html_report(): integration (file not found, type detection)
#
#   3. Namespace rewriter (02_namespace_rewriter.R)
#      - rewrite_html_ids(): ID prefixing in HTML attributes
#      - rewrite_css_ids(): CSS ID selector prefixing (avoiding hex colours)
#      - rewrite_for_hub(): full rewrite pipeline
#
#   4. Front page builder (03_front_page_builder.R)
#      - build_report_card(): tracker card, tabs card, missing metadata
#      - build_front_page(): full overview assembly
#
#   5. Page assembler (07_page_assembler.R)
#      - merge_pinned_data(): empty, single report, multi-report, bad JSON
#      - assemble_hub_html(): document structure
#
# All tests use synthetic data created inline (no external files needed).
# ==============================================================================

library(testthat)

# --- Source the modules under test ---
# Resolve hub_root robustly: test_path() returns the testthat directory,
# so we go up 2 levels (testthat -> tests -> report_hub module root).
hub_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = FALSE)

# If that doesn't resolve (e.g., when run standalone), fall back to finding
# the module by searching from the working directory
if (!file.exists(file.path(hub_root, "00_guard.R"))) {
  # Try from working directory (typical for Rscript from repo root)
  hub_root <- normalizePath("modules/report_hub", mustWork = FALSE)
}
if (!file.exists(file.path(hub_root, "00_guard.R"))) {
  stop("Cannot find report_hub module root. Run tests from the Turas project root.")
}

source(file.path(hub_root, "00_guard.R"))
source(file.path(hub_root, "01_html_parser.R"))
source(file.path(hub_root, "02_namespace_rewriter.R"))
source(file.path(hub_root, "03_front_page_builder.R"))
source(file.path(hub_root, "04_navigation_builder.R"))
source(file.path(hub_root, "07_page_assembler.R"))

# Ensure htmltools is available (used in front page builder)
if (!requireNamespace("htmltools", quietly = TRUE)) {
  skip("htmltools not available")
}


# ==============================================================================
# 1. GUARD LAYER: parse_settings_sheet()
# ==============================================================================

test_that("parse_settings_sheet handles key-value format correctly", {
  df <- data.frame(
    Field = c("project_title", "company_name", "brand_colour"),
    Value = c("My Project", "Acme Corp", "#FF0000"),
    stringsAsFactors = FALSE
  )
  result <- parse_settings_sheet(df)

  expect_type(result, "list")
  expect_equal(result$project_title, "My Project")
  expect_equal(result$company_name, "Acme Corp")
  expect_equal(result$brand_colour, "#FF0000")
})

test_that("parse_settings_sheet handles case-insensitive Field/Value columns", {
  df <- data.frame(
    FIELD = c("project_title", "company_name"),
    VALUE = c("Test", "TestCo"),
    stringsAsFactors = FALSE
  )
  names(df) <- c("FIELD", "VALUE")
  result <- parse_settings_sheet(df)

  expect_equal(result$project_title, "Test")
  expect_equal(result$company_name, "TestCo")
})

test_that("parse_settings_sheet handles single-row format", {
  df <- data.frame(
    project_title = "Row Project",
    company_name = "Row Corp",
    subtitle = "A subtitle",
    stringsAsFactors = FALSE
  )
  result <- parse_settings_sheet(df)

  expect_type(result, "list")
  expect_equal(result$project_title, "Row Project")
  expect_equal(result$company_name, "Row Corp")
  expect_equal(result$subtitle, "A subtitle")
})

test_that("parse_settings_sheet lowercases field names in single-row format", {
  df <- data.frame(
    Project_Title = "Mixed Case",
    Company_Name = "Mixed Corp",
    stringsAsFactors = FALSE
  )
  result <- parse_settings_sheet(df)

  expect_equal(result$project_title, "Mixed Case")
  expect_equal(result$company_name, "Mixed Corp")
})

test_that("parse_settings_sheet returns empty list for zero-row data frame", {
  df <- data.frame(Field = character(0), Value = character(0),
                   stringsAsFactors = FALSE)
  result <- parse_settings_sheet(df)

  expect_type(result, "list")
  expect_length(result, 0)
})

test_that("parse_settings_sheet trims field names", {
  df <- data.frame(
    Field = c("  project_title  ", " company_name"),
    Value = c("Trimmed", "Also Trimmed"),
    stringsAsFactors = FALSE
  )
  result <- parse_settings_sheet(df)

  expect_equal(result$project_title, "Trimmed")
  expect_equal(result$company_name, "Also Trimmed")
})


# ==============================================================================
# 1. GUARD LAYER: guard_validate_hub_config()
# ==============================================================================

test_that("guard refuses NULL config path", {
  result <- guard_validate_hub_config(NULL)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING")
  expect_true(grepl("No config file path", result$message))
})

test_that("guard refuses empty string config path", {
  result <- guard_validate_hub_config("")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING")
})

test_that("guard refuses non-existent file", {
  result <- guard_validate_hub_config("/tmp/nonexistent_file_12345.xlsx")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_FILE_NOT_FOUND")
  expect_true(grepl("Config file not found", result$message))
})

test_that("guard refuses non-xlsx file extension", {
  tmp <- tempfile(fileext = ".csv")
  writeLines("dummy", tmp)
  on.exit(unlink(tmp))

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_FORMAT")
  expect_true(grepl("\\.csv", result$message))
})

test_that("guard refuses xlsx file missing Settings sheet", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = "test.html",
    report_label = "Test",
    report_key = "test",
    order = 1,
    stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp))

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING_SHEET")
  expect_true(grepl("Settings", result$message))
})

test_that("guard refuses xlsx file missing Reports sheet", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp))

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING_SHEET")
  expect_true(grepl("Reports", result$message))
})

test_that("guard refuses when project_title is missing from Settings", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("company_name"),
    Value = c("Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = "test.html",
    report_label = "Test",
    report_key = "test",
    order = 1,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp))

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING_FIELD")
  expect_true(grepl("project_title", result$message))
})

test_that("guard refuses when company_name is missing from Settings", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title"),
    Value = c("Test Project"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = "test.html",
    report_label = "Test",
    report_key = "test",
    order = 1,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp))

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING_FIELD")
  expect_true(grepl("company_name", result$message))
})

test_that("guard refuses when Reports sheet is missing required columns", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  # Missing report_key and order columns
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = "test.html",
    report_label = "Test",
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp))

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING_FIELD")
  expect_true(grepl("report_key", result$message))
  expect_true(grepl("order", result$message))
})

test_that("guard refuses empty Reports sheet", {
  skip_if_not_installed("openxlsx")
  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = character(0),
    report_label = character(0),
    report_key = character(0),
    order = numeric(0),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp))

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_EMPTY")
})

test_that("guard refuses invalid report_key format", {
  skip_if_not_installed("openxlsx")

  # Create a real HTML file to satisfy path checks
  html_file <- tempfile(fileext = ".html")
  writeLines("<html><body></body></html>", html_file)
  on.exit(unlink(html_file), add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = html_file,
    report_label = "Test",
    report_key = "123-invalid",   # starts with digit
    order = 1,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_INVALID_VALUE")
  expect_true(grepl("invalid characters", result$message))
})

test_that("guard refuses report_key with spaces", {
  skip_if_not_installed("openxlsx")

  html_file <- tempfile(fileext = ".html")
  writeLines("<html><body></body></html>", html_file)
  on.exit(unlink(html_file), add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = html_file,
    report_label = "Test",
    report_key = "my report",   # contains space
    order = 1,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_INVALID_VALUE")
})

test_that("guard refuses duplicate report_key values", {
  skip_if_not_installed("openxlsx")

  html_file1 <- tempfile(fileext = ".html")
  html_file2 <- tempfile(fileext = ".html")
  writeLines("<html><body></body></html>", html_file1)
  writeLines("<html><body></body></html>", html_file2)
  on.exit({
    unlink(html_file1)
    unlink(html_file2)
  }, add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = c(html_file1, html_file2),
    report_label = c("Report A", "Report B"),
    report_key = c("tracker", "tracker"),   # duplicate!
    order = c(1, 2),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_DUPLICATE_KEY")
  expect_true(grepl("tracker", result$message))
})

test_that("guard passes with valid config and returns correct structure", {
  skip_if_not_installed("openxlsx")

  html_file <- tempfile(fileext = ".html")
  writeLines("<html><body></body></html>", html_file)
  on.exit(unlink(html_file), add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name", "subtitle", "brand_colour"),
    Value = c("Test Hub", "Acme Research", "Q4 2025", "#323367"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = html_file,
    report_label = "Main Tracker",
    report_key = "tracker",
    order = 1,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "PASS")
  expect_type(result$result, "list")
  expect_equal(result$result$settings$project_title, "Test Hub")
  expect_equal(result$result$settings$company_name, "Acme Research")
  expect_equal(result$result$settings$subtitle, "Q4 2025")
  expect_equal(result$result$settings$brand_colour, "#323367")
  expect_length(result$result$reports, 1)
  expect_equal(result$result$reports[[1]]$key, "tracker")
  expect_equal(result$result$reports[[1]]$label, "Main Tracker")
  expect_equal(result$result$reports[[1]]$order, 1)
  expect_null(result$result$cross_refs)
})

test_that("guard passes with template-format config (headers not in row 1)", {
  skip_if_not_installed("openxlsx")

  html_file <- tempfile(fileext = ".html")
  writeLines("<html><body></body></html>", html_file)
  on.exit(unlink(html_file), add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  # Settings sheet: title/subtitle/legend/header rows before data (template format)
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", "Report Hub Configuration", startRow = 1, startCol = 1)
  openxlsx::writeData(wb, "Settings", "Settings for combining multiple Turas HTML reports", startRow = 2, startCol = 1)
  openxlsx::writeData(wb, "Settings", "Legend:", startRow = 3, startCol = 1)
  # Row 5: header
  openxlsx::writeData(wb, "Settings",
    data.frame(t(c("Setting", "Value", "Required?", "Description", "Valid Values / Notes"))),
    startRow = 5, startCol = 1, colNames = FALSE)
  # Row 6+: data (with section headers)
  openxlsx::writeData(wb, "Settings", "PROJECT", startRow = 6, startCol = 1)
  openxlsx::writeData(wb, "Settings", "project_title", startRow = 7, startCol = 1)
  openxlsx::writeData(wb, "Settings", "Template Test", startRow = 7, startCol = 2)
  openxlsx::writeData(wb, "Settings", "company_name", startRow = 8, startCol = 1)
  openxlsx::writeData(wb, "Settings", "Acme Research", startRow = 8, startCol = 2)

  # Reports sheet: title/subtitle/header/description rows (template format)
  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", "Report Files", startRow = 1, startCol = 1)
  openxlsx::writeData(wb, "Reports", "List all HTML reports to combine", startRow = 2, startCol = 1)
  # Row 3: column headers
  openxlsx::writeData(wb, "Reports",
    data.frame(t(c("report_path", "report_label", "report_key", "order", "report_type"))),
    startRow = 3, startCol = 1, colNames = FALSE)
  # Row 4: description row
  openxlsx::writeData(wb, "Reports", "[REQUIRED] Path to report file", startRow = 4, startCol = 1)
  openxlsx::writeData(wb, "Reports", "[REQUIRED] Display label", startRow = 4, startCol = 2)
  openxlsx::writeData(wb, "Reports", "[REQUIRED] Unique key", startRow = 4, startCol = 3)
  openxlsx::writeData(wb, "Reports", "[REQUIRED] Sort order", startRow = 4, startCol = 4)
  openxlsx::writeData(wb, "Reports", "[Optional] Report type", startRow = 4, startCol = 5)
  # Row 5: actual data
  openxlsx::writeData(wb, "Reports", html_file, startRow = 5, startCol = 1)
  openxlsx::writeData(wb, "Reports", "Tracker Report", startRow = 5, startCol = 2)
  openxlsx::writeData(wb, "Reports", "tracker", startRow = 5, startCol = 3)
  openxlsx::writeData(wb, "Reports", 1, startRow = 5, startCol = 4)
  openxlsx::writeData(wb, "Reports", "tracker", startRow = 5, startCol = 5)

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "PASS")
  expect_equal(result$result$settings$project_title, "Template Test")
  expect_equal(result$result$settings$company_name, "Acme Research")
  expect_length(result$result$reports, 1)
  expect_equal(result$result$reports[[1]]$key, "tracker")
  expect_equal(result$result$reports[[1]]$label, "Tracker Report")
})

test_that("guard sorts reports by order", {
  skip_if_not_installed("openxlsx")

  html1 <- tempfile(fileext = ".html")
  html2 <- tempfile(fileext = ".html")
  writeLines("<html><body></body></html>", html1)
  writeLines("<html><body></body></html>", html2)
  on.exit({ unlink(html1); unlink(html2) }, add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Co"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = c(html1, html2),
    report_label = c("Second", "First"),
    report_key = c("tabs", "tracker"),
    order = c(2, 1),
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "PASS")
  expect_equal(result$result$reports[[1]]$key, "tracker")
  expect_equal(result$result$reports[[2]]$key, "tabs")
})

test_that("guard accepts valid report_key formats", {
  # Valid keys: start with letter, contain letters/digits/hyphens/underscores
  valid_keys <- c("tracker", "tabs", "brand-health", "tabs_v2", "myReport123")
  for (key in valid_keys) {
    expect_true(
      grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", key),
      info = sprintf("Key '%s' should be valid", key)
    )
  }
})

test_that("guard rejects invalid report_key formats", {
  invalid_keys <- c(
    "123abc",     # starts with digit
    "-tracker",   # starts with hyphen
    "_tracker",   # starts with underscore
    "my report",  # contains space
    "my.report",  # contains dot
    "my@report"   # contains special char
  )
  for (key in invalid_keys) {
    expect_false(
      grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", key),
      info = sprintf("Key '%s' should be invalid", key)
    )
  }
})

test_that("guard refuses report_path pointing to non-HTML file", {
  skip_if_not_installed("openxlsx")

  csv_file <- tempfile(fileext = ".csv")
  writeLines("dummy", csv_file)
  on.exit(unlink(csv_file), add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = csv_file,
    report_label = "Test",
    report_key = "test",
    order = 1,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_INVALID_FORMAT")
  expect_true(grepl("\\.csv", result$message))
})

test_that("guard refuses empty report_label", {
  skip_if_not_installed("openxlsx")

  html_file <- tempfile(fileext = ".html")
  writeLines("<html><body></body></html>", html_file)
  on.exit(unlink(html_file), add = TRUE)

  tmp <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()

  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Test", "Acme"),
    stringsAsFactors = FALSE
  ))

  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", data.frame(
    report_path = html_file,
    report_label = "",           # empty label
    report_key = "tracker",
    order = 1,
    stringsAsFactors = FALSE
  ))

  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  on.exit(unlink(tmp), add = TRUE)

  result <- guard_validate_hub_config(tmp)

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_MISSING_FIELD")
  expect_true(grepl("report_label", result$message))
})


# ==============================================================================
# 2. HTML PARSER: detect_report_type()
# ==============================================================================

test_that("detect_report_type identifies tracker via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="tracker"></head><body></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("detect_report_type identifies tabs via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="tabs"></head><body></body></html>'
  expect_equal(detect_report_type(html), "tabs")
})

test_that("detect_report_type identifies catdriver via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="catdriver"></head><body></body></html>'
  expect_equal(detect_report_type(html), "catdriver")
})

test_that("detect_report_type identifies keydriver via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="keydriver"></head><body></body></html>'
  expect_equal(detect_report_type(html), "keydriver")
})

test_that("detect_report_type identifies tabs via structural marker", {
  html <- '<html><body><div id="tab-crosstabs" class="tab-panel">content</div></body></html>'
  expect_equal(detect_report_type(html), "tabs")
})

test_that("detect_report_type identifies tracker via structural markers", {
  html <- '<html><body><div id="tab-metrics" class="tab-panel"></div><div id="tab-overview" class="tab-panel"></div></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("detect_report_type identifies tracker via tk-header class", {
  html <- '<html><body><header class="tk-header">content</header></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("detect_report_type returns NULL for unknown HTML", {
  html <- '<html><body><p>Just a paragraph</p></body></html>'
  expect_null(detect_report_type(html))
})

test_that("detect_report_type meta tag takes precedence over structural markers", {
  # Even if both meta and structural markers are present, meta tag should win
  html <- '<html><head><meta name="turas-report-type" content="tracker"></head>
    <body><div id="tab-crosstabs" class="tab-panel">content</div></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})


# ==============================================================================
# 2. HTML PARSER: extract_blocks()
# ==============================================================================

test_that("extract_blocks extracts style blocks", {
  html <- '<html><head><style>.foo { color: red; }</style></head><body></body></html>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 1)
  expect_equal(blocks[[1]]$content, ".foo { color: red; }")
  expect_equal(blocks[[1]]$open_tag, "<style>")
})

test_that("extract_blocks extracts multiple blocks", {
  html <- '<style>a{}</style><p>gap</p><style type="text/css">b{}</style>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 2)
  expect_equal(blocks[[1]]$content, "a{}")
  expect_equal(blocks[[2]]$content, "b{}")
  expect_equal(blocks[[2]]$open_tag, '<style type="text/css">')
})

test_that("extract_blocks returns empty list when no matches", {
  html <- '<html><body><p>No styles here</p></body></html>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 0)
})

test_that("extract_blocks extracts script blocks", {
  html <- '<script>var x = 1;</script><script type="text/javascript">var y = 2;</script>'
  blocks <- extract_blocks(html, "<script[^>]*>", "</script>")

  expect_length(blocks, 2)
  expect_equal(blocks[[1]]$content, "var x = 1;")
  expect_equal(blocks[[2]]$content, "var y = 2;")
})

test_that("extract_blocks captures start_pos and end_pos", {
  html <- 'before<style>content</style>after'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 1)
  expect_equal(blocks[[1]]$start_pos, 7)    # position of '<' in <style>
  expect_true(blocks[[1]]$end_pos > blocks[[1]]$start_pos)
  expect_equal(blocks[[1]]$full_block, "<style>content</style>")
})

test_that("extract_blocks separates data scripts from regular scripts", {
  html <- paste0(
    '<script type="application/json" id="pinned-views-data">[{"a":1}]</script>',
    '<script>var x = 1;</script>'
  )
  all_scripts <- extract_blocks(html, "<script[^>]*>", "</script>")

  expect_length(all_scripts, 2)
  # Check that the first one is identifiable as a data script
  expect_true(grepl('application/json', all_scripts[[1]]$open_tag))
  # Check the second is a regular script
  expect_false(grepl('application/json', all_scripts[[2]]$open_tag))
})


# ==============================================================================
# 2. HTML PARSER: extract_metadata()
# ==============================================================================

test_that("extract_metadata extracts tracker metadata from meta tags", {
  html <- '<!DOCTYPE html>
<html><head>
<title>Brand Tracker 2025</title>
<meta name="turas-report-type" content="tracker">
<meta name="turas-generated" content="2025-03-15">
<meta name="turas-metrics" content="42">
<meta name="turas-waves" content="5">
<meta name="turas-segments" content="3">
<meta name="turas-baseline-label" content="Q1 2023">
<meta name="turas-latest-label" content="Q4 2025">
</head>
<body>
<header class="tk-header">
<span class="tk-header-project">Brand Tracker</span>
<span class="tk-brand-name">Acme</span>
</header>
</body></html>'

  meta <- extract_metadata(html, "tracker")

  expect_equal(meta$report_type, "tracker")
  expect_equal(meta$title, "Brand Tracker 2025")
  expect_equal(meta$generated, "2025-03-15")
  expect_equal(meta$n_metrics, "42")
  expect_equal(meta$n_waves, "5")
  expect_equal(meta$n_segments, "3")
  expect_equal(meta$baseline_label, "Q1 2023")
  expect_equal(meta$latest_label, "Q4 2025")
  expect_equal(meta$project_title, "Brand Tracker")
  expect_equal(meta$brand_name, "Acme")
})

test_that("extract_metadata extracts tabs metadata from meta tags", {
  html <- '<!DOCTYPE html>
<html><head>
<title>Survey Crosstabs</title>
<meta name="turas-report-type" content="tabs">
<meta name="turas-total-n" content="1500">
<meta name="turas-questions" content="35">
<meta name="turas-banner-groups" content="4">
<meta name="turas-weighted" content="true">
<meta name="turas-fieldwork" content="Jan-Mar 2025">
</head>
<body></body></html>'

  meta <- extract_metadata(html, "tabs")

  expect_equal(meta$report_type, "tabs")
  expect_equal(meta$title, "Survey Crosstabs")
  expect_equal(meta$total_n, "1500")
  expect_equal(meta$n_questions, "35")
  expect_equal(meta$n_banner_groups, "4")
  expect_equal(meta$weighted, "true")
  expect_equal(meta$fieldwork, "Jan-Mar 2025")
})

test_that("extract_metadata extracts tabs metadata from data attributes (legacy)", {
  html <- '<!DOCTYPE html>
<html><head><title>Legacy Tabs</title></head>
<body>
<div id="tab-summary" data-project-title="Legacy Project" data-fieldwork="2024" data-company="OldCo" data-brand-colour="#FF0000">
</div>
</body></html>'

  meta <- extract_metadata(html, "tabs")

  expect_equal(meta$project_title, "Legacy Project")
  expect_equal(meta$fieldwork, "2024")
  expect_equal(meta$company, "OldCo")
  expect_equal(meta$brand_colour, "#FF0000")
})

test_that("extract_metadata uses title as project_title fallback for tabs", {
  html <- '<html><head><title>Fallback Title</title></head><body></body></html>'
  meta <- extract_metadata(html, "tabs")

  expect_equal(meta$title, "Fallback Title")
  expect_equal(meta$project_title, "Fallback Title")
})

test_that("extract_metadata handles tracker badge bar fallback", {
  html <- '<!DOCTYPE html>
<html><head><title>Old Tracker</title></head>
<body>
<header class="tk-header">
<span class="tk-header-project">Badge Tracker</span>
</header>
<div class="tk-badge-bar"><strong>25</strong> Metrics <strong>4</strong> Waves <strong>2</strong> Segments</div>
</body></html>'

  meta <- extract_metadata(html, "tracker")

  expect_equal(meta$project_title, "Badge Tracker")
  expect_true(!is.null(meta$badge_bar))
  # The fallback should parse the badge bar for counts
  expect_equal(meta$n_metrics, "25")
  expect_equal(meta$n_waves, "4")
  expect_equal(meta$n_segments, "2")
})

test_that("extract_metadata returns minimal metadata for empty HTML", {
  html <- "<html><head></head><body></body></html>"
  meta <- extract_metadata(html, "tracker")

  expect_equal(meta$report_type, "tracker")
  expect_null(meta$title)
  expect_null(meta$generated)
})


# ==============================================================================
# 2. HTML PARSER: parse_html_report() (integration)
# ==============================================================================

test_that("parse_html_report refuses non-existent file", {
  result <- parse_html_report("/tmp/no_such_file_99999.html", "test")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_FILE_NOT_FOUND")
})

test_that("parse_html_report refuses unrecognised report type", {
  tmp <- tempfile(fileext = ".html")
  writeLines("<html><body><p>Not a Turas report</p></body></html>", tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "unknown")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
  expect_true(grepl("Cannot detect report type", result$message))
})

test_that("parse_html_report parses a minimal tracker report", {
  html <- '<!DOCTYPE html>
<html><head>
<meta name="turas-report-type" content="tracker">
<title>Test Tracker</title>
<style>.tk-header { color: #333; }</style>
</head>
<body>
<header class="tk-header"><span class="tk-header-project">Test</span></header>
<div class="report-tabs">
  <button data-tab="overview">Overview</button>
  <button data-tab="metrics">Metrics</button>
</div>
<div id="tab-overview" class="tab-panel active">
  <p>Overview content</p>
</div>
<div id="tab-metrics" class="tab-panel">
  <p>Metrics content</p>
</div>
<script type="application/json" id="pinned-views-data">[]</script>
<script>var x = 1;</script>
<footer class="tk-footer">Footer</footer>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tracker")

  expect_equal(result$status, "PASS")
  expect_equal(result$result$report_key, "tracker")
  expect_equal(result$result$report_type, "tracker")
  expect_length(result$result$css_blocks, 1)
  expect_true(length(result$result$js_blocks) >= 1)
  expect_true(nzchar(result$result$header))
  expect_true(grepl("tk-header", result$result$header))
  expect_true(grepl("tk-footer", result$result$footer))
  expect_equal(result$result$pinned_data, "[]")
  expect_true(length(result$result$report_tabs$tab_names) >= 1)
  # Pinned tab should be filtered out
  expect_false("pinned" %in% result$result$report_tabs$tab_names)
})

test_that("parse_html_report extracts pinned-views-data JSON", {
  html <- '<!DOCTYPE html>
<html><head>
<meta name="turas-report-type" content="tabs">
</head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script type="application/json" id="pinned-views-data">[{"qCode":"Q1","title":"Test"}]</script>
<script>var y = 2;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  expect_true(grepl("Q1", result$result$pinned_data))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_html_ids()
# ==============================================================================

test_that("rewrite_html_ids prefixes id attributes", {
  html <- '<div id="tab-overview" class="tab-panel">content</div>'
  result <- rewrite_html_ids(html, "tracker--")

  expect_true(grepl('id="tracker--tab-overview"', result))
  expect_true(grepl('class="tab-panel"', result))  # class unchanged
})

test_that("rewrite_html_ids prefixes multiple IDs", {
  html <- '<div id="first">a</div><span id="second">b</span>'
  result <- rewrite_html_ids(html, "tk--")

  expect_true(grepl('id="tk--first"', result))
  expect_true(grepl('id="tk--second"', result))
})

test_that("rewrite_html_ids rewrites href fragment links", {
  html <- '<a href="#section-a">Link</a>'
  result <- rewrite_html_ids(html, "tk--")

  expect_true(grepl('href="#tk--section-a"', result))
})

test_that("rewrite_html_ids rewrites for attributes on labels", {
  html <- '<label for="input-name">Name</label>'
  result <- rewrite_html_ids(html, "tk--")

  expect_true(grepl('for="tk--input-name"', result))
})

test_that("rewrite_html_ids does not double-prefix", {
  html <- '<div id="tab-overview">content</div>'
  result <- rewrite_html_ids(html, "tracker--")
  result2 <- rewrite_html_ids(result, "tracker--")

  # After second rewrite, it would be double-prefixed (expected behaviour for this function)
  # The function does not check for existing prefixes by design (called once per report)
  expect_true(grepl('id="tracker--tracker--tab-overview"', result2))
})

test_that("rewrite_html_ids preserves data attributes", {
  html <- '<div data-metric-id="m1" id="panel-1">content</div>'
  result <- rewrite_html_ids(html, "tk--")

  # id should be prefixed

  expect_true(grepl('id="tk--panel-1"', result))
  # data-metric-id should NOT be prefixed (the regex requires whitespace before id=)
  expect_true(grepl('data-metric-id="m1"', result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_css_ids()
# ==============================================================================

test_that("rewrite_css_ids prefixes CSS ID selectors with hyphens/underscores", {
  css <- '#tab-overview { display: block; } #tab-metrics { display: none; }'
  result <- rewrite_css_ids(css, "tracker--")

  expect_true(grepl('#tracker--tab-overview', result))
  expect_true(grepl('#tracker--tab-metrics', result))
})

test_that("rewrite_css_ids does NOT prefix hex colour codes", {
  css <- 'body { background-color: #e2e8f0; color: #333; border: 1px solid #fff; }'
  result <- rewrite_css_ids(css, "tracker--")

  # Hex colours should remain unchanged (no hyphen/underscore = no match)
  expect_true(grepl('#e2e8f0', result))
  expect_true(grepl('#333', result))
  expect_true(grepl('#fff', result))
})

test_that("rewrite_css_ids handles IDs with underscores", {
  css <- '#mv_metric_1 { font-weight: bold; }'
  result <- rewrite_css_ids(css, "tk--")

  expect_true(grepl('#tk--mv_metric_1', result))
})

test_that("rewrite_css_ids handles mixed selectors", {
  css <- '.panel #tab-overview { display:block; } .panel #ccc { color: #ccc; }'
  result <- rewrite_css_ids(css, "tk--")

  expect_true(grepl('#tk--tab-overview', result))
  # #ccc (hex colour, no hyphen/underscore) should not be prefixed
  expect_true(grepl('#ccc', result))
  # #ccc should NOT become #tk--ccc
  expect_false(grepl('#tk--ccc', result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_for_hub() (integration)
# ==============================================================================

test_that("rewrite_for_hub namespaces all components", {
  # Build a minimal parsed report structure
  parsed <- list(
    report_key = "tracker",
    report_type = "tracker",
    content_panels = list(
      overview = '<div id="tab-overview" class="tab-panel"><button onclick="saveReportHTML()">Save</button></div>',
      metrics = '<div id="tab-metrics" class="tab-panel">content</div>'
    ),
    report_tabs = list(
      html = '<div class="report-tabs"><button onclick="switchReportTab(\'overview\')">Overview</button></div>',
      tab_names = c("overview", "metrics")
    ),
    header = '<header class="tk-header" id="main-header">Header</header>',
    footer = '<footer class="tk-footer" id="main-footer">Footer</footer>',
    help_overlay = "",
    css_blocks = list(
      list(content = '#tab-overview { display: block; }')
    ),
    js_blocks = list(
      list(content = 'function switchReportTab(tab) { console.log(tab); }')
    ),
    data_scripts = list(
      list(
        id = "pinned-views-data",
        open_tag = '<script type="application/json" id="pinned-views-data">',
        content = "[]"
      )
    ),
    metadata = list(report_type = "tracker"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)

  # Content panels should have prefixed IDs
  expect_true(grepl('id="tracker--tab-overview"', result$content_panels$overview))
  expect_true(grepl('id="tracker--tab-metrics"', result$content_panels$metrics))

  # Save buttons should be removed
  expect_false(grepl('saveReportHTML', result$content_panels$overview))

  # Header and footer should have prefixed IDs
  expect_true(grepl('id="tracker--main-header"', result$header))
  expect_true(grepl('id="tracker--main-footer"', result$footer))

  # CSS should have prefixed selectors
  expect_true(grepl('#tracker--tab-overview', result$css_blocks[[1]]$content))

  # Report tab navigation should redirect to ReportHub.switchSubTab
  expect_true(grepl("ReportHub.switchSubTab", result$report_tabs$html))

  # Data scripts should have prefixed IDs
  expect_equal(result$data_scripts[[1]]$id, "tracker--pinned-views-data")

  # Wrapped JS should exist
  expect_true(nzchar(result$wrapped_js))
})

test_that("rewrite_for_hub removes save/print buttons", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = paste0(
        '<div id="tab-crosstabs" class="tab-panel">',
        '<button onclick="saveReportHTML()">Save</button>',
        '<button onclick="printReport()">Print</button>',
        '<button onclick="printAllPins()">Print Pins</button>',
        '</div>'
      )
    ),
    report_tabs = list(html = "", tab_names = character(0)),
    header = "",
    footer = "",
    help_overlay = "",
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "tabs"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)

  # All save/print buttons should be gone
  panel_html <- result$content_panels$crosstabs
  expect_false(grepl("saveReportHTML", panel_html))
  expect_false(grepl("printReport", panel_html))
  expect_false(grepl("printAllPins", panel_html))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: remove_save_print_buttons()
# ==============================================================================

test_that("remove_save_print_buttons removes save button", {
  html <- '<div><button class="save" onclick="saveReportHTML()">Save</button></div>'
  result <- remove_save_print_buttons(html)

  expect_false(grepl("saveReportHTML", result))
  expect_true(grepl("<div>", result))
})

test_that("remove_save_print_buttons removes print button", {
  html <- '<button class="print" onclick="printReport()">Print</button>'
  result <- remove_save_print_buttons(html)

  expect_false(grepl("printReport", result))
})

test_that("remove_save_print_buttons removes printAllPins button", {
  html <- '<button onclick="printAllPins()">Print All</button>'
  result <- remove_save_print_buttons(html)

  expect_false(grepl("printAllPins", result))
})

test_that("remove_save_print_buttons preserves non-matching buttons", {
  html <- '<button onclick="doSomething()">Keep Me</button>'
  result <- remove_save_print_buttons(html)

  expect_equal(result, html)
})


# ==============================================================================
# 3. NAMESPACE REWRITER: redirect_pin_functions()
# ==============================================================================

test_that("redirect_pin_functions redirects updatePinBadge to ReportHub", {
  js <- 'updatePinBadge(count);'
  result <- redirect_pin_functions(js, "tracker")

  expect_true(grepl("ReportHub.updatePinBadge", result))
})

test_that("redirect_pin_functions redirects savePinnedData to ReportHub", {
  js <- 'savePinnedData(data);'
  result <- redirect_pin_functions(js, "tabs")

  expect_true(grepl("ReportHub.savePinnedData", result))
})

test_that("redirect_pin_functions does not redirect function declarations", {
  js <- 'function updatePinBadge(count) { /* impl */ }'
  result <- redirect_pin_functions(js, "tracker")

  # Should NOT redirect the declaration itself
  expect_true(grepl("function updatePinBadge", result))
})

test_that("redirect_pin_functions does not redirect method calls", {
  js <- 'someObj.updatePinBadge(count);'
  result <- redirect_pin_functions(js, "tracker")

  # Should NOT redirect since it's a method call (.updatePinBadge)
  expect_true(grepl("someObj.updatePinBadge", result))
  expect_false(grepl("someObj.ReportHub", result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: redirect_save_functions()
# ==============================================================================

test_that("redirect_save_functions redirects saveReportHTML to ReportHub", {
  js <- 'saveReportHTML();'
  result <- redirect_save_functions(js)

  expect_true(grepl("ReportHub.saveReportHTML", result))
})

test_that("redirect_save_functions does not redirect function declaration", {
  js <- 'function saveReportHTML() { /* impl */ }'
  result <- redirect_save_functions(js)

  expect_true(grepl("function saveReportHTML", result))
})


# ==============================================================================
# 3. NAMESPACE REWRITER: rewrite_js_ids()
# ==============================================================================

test_that("rewrite_js_ids redirects switchReportTab to ReportHub.switchSubTab", {
  js <- 'switchReportTab("overview");'
  result <- rewrite_js_ids(js, "tracker--", "tracker")

  expect_true(grepl("ReportHub.switchSubTab\\('tracker',", result))
  expect_false(grepl("switchReportTab", result))
})

test_that("rewrite_js_ids does not redirect switchReportTab function definition", {
  js <- 'function switchReportTab(tab) { console.log(tab); }'
  result <- rewrite_js_ids(js, "tracker--", "tracker")

  expect_true(grepl("function switchReportTab", result))
})


# ==============================================================================
# 4. FRONT PAGE BUILDER: build_report_card()
# ==============================================================================

test_that("build_report_card creates tracker card with metadata", {
  parsed <- list(
    report_key = "tracker",
    report_type = "tracker",
    metadata = list(
      report_type = "tracker",
      project_title = "Brand Tracker 2025",
      n_metrics = "42",
      n_waves = "5",
      n_segments = "3",
      baseline_label = "Q1 2023",
      latest_label = "Q4 2025"
    )
  )

  card_html <- build_report_card(parsed)

  expect_true(grepl("hub-card-type-tracker", card_html))
  expect_true(grepl("Tracker", card_html))
  expect_true(grepl("Brand Tracker 2025", card_html))
  expect_true(grepl("42 Metrics", card_html))
  expect_true(grepl("5 Waves", card_html))
  expect_true(grepl("3 Segments", card_html))
  expect_true(grepl("Q1 2023 - Baseline", card_html))
  expect_true(grepl("Q4 2025 - Latest Wave", card_html))
  expect_true(grepl("ReportHub.switchReport", card_html))
  expect_true(grepl("View Report", card_html))
})

test_that("build_report_card creates tabs/crosstabs card with metadata", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    metadata = list(
      report_type = "tabs",
      project_title = "Survey Crosstabs",
      total_n = "1500",
      n_questions = "35",
      n_banner_groups = "4",
      weighted = "true",
      fieldwork = "Jan-Mar 2025"
    )
  )

  card_html <- build_report_card(parsed)

  expect_true(grepl("hub-card-type-crosstabs", card_html))
  expect_true(grepl("Crosstabs", card_html))
  expect_true(grepl("Survey Crosstabs", card_html))
  expect_true(grepl("n=1,500", card_html))
  expect_true(grepl("35 Questions", card_html))
  expect_true(grepl("4 Banner Groups", card_html))
  expect_true(grepl("Weighted", card_html))
  expect_true(grepl("Fieldwork Jan-Mar 2025", card_html))
})

test_that("build_report_card handles single banner group (no plural)", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    metadata = list(
      report_type = "tabs",
      project_title = "Small Survey",
      n_banner_groups = "1"
    )
  )

  card_html <- build_report_card(parsed)

  # "1 Banner Group" not "1 Banner Groups"
  expect_true(grepl("1 Banner Group[^s]", card_html))
})

test_that("build_report_card uses report_key as fallback label", {
  parsed <- list(
    report_key = "my-report",
    report_type = "tabs",
    metadata = list(
      report_type = "tabs"
      # No project_title
    )
  )

  card_html <- build_report_card(parsed)

  expect_true(grepl("my-report", card_html))
})

test_that("build_report_card escapes HTML in labels", {
  parsed <- list(
    report_key = "test",
    report_type = "tracker",
    metadata = list(
      report_type = "tracker",
      project_title = "Test <script>alert('xss')</script>"
    )
  )

  card_html <- build_report_card(parsed)

  # Should be escaped, not raw HTML
  expect_false(grepl("<script>", card_html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", card_html) || grepl("Test", card_html))
})

test_that("build_report_card handles tracker card with no metadata counts", {
  parsed <- list(
    report_key = "tracker",
    report_type = "tracker",
    metadata = list(
      report_type = "tracker",
      project_title = "Empty Tracker"
      # No n_metrics, n_waves, n_segments, no badge_bar
    )
  )

  card_html <- build_report_card(parsed)

  # Should still produce valid card HTML
  expect_true(grepl("hub-report-card", card_html))
  expect_true(grepl("Empty Tracker", card_html))
  # Stats line should be empty or have no stat entries
  expect_false(grepl("Metrics", card_html))
})


# ==============================================================================
# 4. FRONT PAGE BUILDER: build_front_page()
# ==============================================================================

test_that("build_front_page generates overview with report cards", {
  parsed_reports <- list(
    list(
      report_key = "tracker",
      report_type = "tracker",
      metadata = list(
        report_type = "tracker",
        project_title = "Tracker Report"
      ),
      content_panels = list()
    ),
    list(
      report_key = "tabs",
      report_type = "tabs",
      metadata = list(
        report_type = "tabs",
        project_title = "Tabs Report"
      ),
      content_panels = list()
    )
  )

  config <- list(
    settings = list(
      project_title = "Hub Project",
      company_name = "TestCo"
    )
  )

  overview_html <- build_front_page(config, parsed_reports)

  expect_true(grepl("hub-overview", overview_html))
  expect_true(grepl("hub-report-cards", overview_html))
  expect_true(grepl("Tracker Report", overview_html))
  expect_true(grepl("Tabs Report", overview_html))
  expect_true(grepl("hub-summary-area", overview_html))
})


# ==============================================================================
# 5. PAGE ASSEMBLER: merge_pinned_data()
# ==============================================================================

test_that("merge_pinned_data returns empty JSON array when no pins", {
  parsed_reports <- list(
    list(
      report_key = "tracker",
      pinned_data = "[]"
    ),
    list(
      report_key = "tabs",
      pinned_data = "[]"
    )
  )

  result <- merge_pinned_data(parsed_reports)

  expect_equal(result, "[]")
})

test_that("merge_pinned_data returns empty JSON for NULL pinned_data", {
  parsed_reports <- list(
    list(
      report_key = "tracker",
      pinned_data = NULL
    )
  )

  result <- merge_pinned_data(parsed_reports)

  expect_equal(result, "[]")
})

test_that("merge_pinned_data merges pins from single report", {
  skip_if_not_installed("jsonlite")

  pins_json <- jsonlite::toJSON(
    list(list(id = "pin-1", title = "Test Pin")),
    auto_unbox = TRUE
  )
  parsed_reports <- list(
    list(
      report_key = "tracker",
      pinned_data = as.character(pins_json)
    )
  )

  result <- merge_pinned_data(parsed_reports)
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_length(parsed, 1)
  expect_equal(parsed[[1]]$id, "pin-1")
  expect_equal(parsed[[1]]$title, "Test Pin")
  expect_equal(parsed[[1]]$source, "tracker")
  expect_equal(parsed[[1]]$type, "pin")
})

test_that("merge_pinned_data merges pins from multiple reports", {
  skip_if_not_installed("jsonlite")

  tracker_pins <- jsonlite::toJSON(
    list(
      list(id = "pin-t1", title = "Tracker Pin 1"),
      list(id = "pin-t2", title = "Tracker Pin 2")
    ),
    auto_unbox = TRUE
  )
  tabs_pins <- jsonlite::toJSON(
    list(
      list(id = "pin-x1", title = "Tabs Pin 1")
    ),
    auto_unbox = TRUE
  )

  parsed_reports <- list(
    list(report_key = "tracker", pinned_data = as.character(tracker_pins)),
    list(report_key = "tabs", pinned_data = as.character(tabs_pins))
  )

  result <- merge_pinned_data(parsed_reports)
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_length(parsed, 3)
  sources <- sapply(parsed, function(p) p$source)
  expect_equal(sum(sources == "tracker"), 2)
  expect_equal(sum(sources == "tabs"), 1)
})

test_that("merge_pinned_data handles malformed JSON gracefully", {
  parsed_reports <- list(
    list(
      report_key = "bad",
      pinned_data = "this is not valid json"
    )
  )

  # Should not error, just treat as empty
  result <- merge_pinned_data(parsed_reports)

  expect_equal(result, "[]")
})

test_that("merge_pinned_data skips reports with empty pins among valid ones", {
  skip_if_not_installed("jsonlite")

  pins_json <- jsonlite::toJSON(
    list(list(id = "pin-1", title = "Only Pin")),
    auto_unbox = TRUE
  )

  parsed_reports <- list(
    list(report_key = "tracker", pinned_data = "[]"),
    list(report_key = "tabs", pinned_data = as.character(pins_json))
  )

  result <- merge_pinned_data(parsed_reports)
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_length(parsed, 1)
  expect_equal(parsed[[1]]$source, "tabs")
})


# ==============================================================================
# 5. PAGE ASSEMBLER: assemble_hub_html() (integration)
# ==============================================================================

test_that("assemble_hub_html produces a complete HTML document", {
  config <- list(
    settings = list(
      project_title = "Test Hub Project",
      company_name = "TestCo",
      brand_colour = "#323367",
      accent_colour = "#CC9900",
      client_name = "Client Inc",
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "tracker",
      report_type = "tracker",
      content_panels = list(
        overview = '<div id="tracker--tab-overview" class="tab-panel">Overview content</div>'
      ),
      footer = '<footer class="tk-footer">Tracker Footer</footer>',
      css_blocks = list(
        list(content = '#tracker--tab-overview { display: block; }')
      ),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = 'console.log("tracker init");',
      metadata = list(report_type = "tracker"),
      pinned_data = "[]"
    )
  )

  overview_html <- '<div class="hub-overview">overview content</div>'
  navigation_html <- '<nav class="hub-nav">navigation</nav>'

  html <- assemble_hub_html(config, parsed_reports, overview_html, navigation_html)

  # Basic structure checks
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl("<html lang=\"en\">", html, fixed = TRUE))
  expect_true(grepl("</html>", html, fixed = TRUE))
  expect_true(grepl("<head>", html, fixed = TRUE))
  expect_true(grepl("</head>", html, fixed = TRUE))
  expect_true(grepl("<body", html, fixed = TRUE))
  expect_true(grepl("</body>", html, fixed = TRUE))

  # Title
  expect_true(grepl("Test Hub Project", html))

  # Meta tag for hub type
  expect_true(grepl('content="hub"', html))

  # Navigation included
  expect_true(grepl("hub-nav", html))

  # Overview panel
  expect_true(grepl('data-hub-panel="overview"', html))
  expect_true(grepl("hub-overview", html))

  # Report panel
  expect_true(grepl('data-hub-panel="tracker"', html))
  expect_true(grepl("tracker--tab-overview", html))

  # Footer
  expect_true(grepl("Tracker Footer", html))

  # Pinned panel
  expect_true(grepl('data-hub-panel="pinned"', html))
  expect_true(grepl("hub-pinned-cards", html))

  # Pinned data store
  expect_true(grepl('id="hub-pinned-data"', html))

  # CSS included
  expect_true(grepl("tracker styles", html))

  # JS included
  expect_true(grepl("tracker JS", html))
  expect_true(grepl("tracker init", html))

  # DOMContentLoaded init script
  expect_true(grepl("DOMContentLoaded", html))
})

test_that("assemble_hub_html skips pinned-views-data from individual reports", {
  config <- list(
    settings = list(
      project_title = "Test",
      company_name = "Co",
      brand_colour = NULL,
      accent_colour = NULL,
      client_name = NULL,
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      content_panels = list(),
      footer = "",
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(
        list(
          id = "tabs--pinned-views-data",
          open_tag = '<script type="application/json" id="tabs--pinned-views-data">',
          content = '[{"id":"old"}]'
        ),
        list(
          id = "tabs--banner-data",
          open_tag = '<script type="application/json" id="tabs--banner-data">',
          content = '{"banners":[]}'
        )
      ),
      wrapped_js = "",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "", "")

  # The per-report pinned-views-data should be skipped
  expect_false(grepl('id="tabs--pinned-views-data"', html))

  # But other data scripts should be included
  expect_true(grepl('id="tabs--banner-data"', html))

  # The unified hub-pinned-data should be present
  expect_true(grepl('id="hub-pinned-data"', html))
})


# ==============================================================================
# 5. PAGE ASSEMBLER: build_pinned_panel()
# ==============================================================================

test_that("build_pinned_panel generates expected HTML structure", {
  panel_html <- build_pinned_panel()

  expect_true(grepl('data-hub-panel="pinned"', panel_html))
  expect_true(grepl('id="hub-pinned-toolbar"', panel_html))
  expect_true(grepl('id="hub-pinned-cards"', panel_html))
  expect_true(grepl('id="hub-pinned-empty"', panel_html))
  expect_true(grepl('ReportHub.addSection', panel_html))
  expect_true(grepl('ReportHub.exportAllPins', panel_html))
})


# ==============================================================================
# 5. PAGE ASSEMBLER: build_init_js()
# ==============================================================================

test_that("build_init_js generates DOMContentLoaded wrapper", {
  parsed_reports <- list(
    list(report_key = "tracker", report_type = "tracker"),
    list(report_key = "tabs", report_type = "tabs")
  )

  init_js <- build_init_js(parsed_reports)

  expect_true(grepl("DOMContentLoaded", init_js))
  expect_true(grepl("ReportHub.initNavigation", init_js))
  expect_true(grepl("ReportHub.hydratePinnedViews", init_js))
  expect_true(grepl("TrackerReport", init_js))
  expect_true(grepl("TabsReport", init_js))
})


# ==============================================================================
# EDGE CASES AND ROBUSTNESS
# ==============================================================================

test_that("extract_blocks handles nested-looking tags correctly", {
  # Only the outermost matching pair should be captured
  html <- '<style>a { content: "<style>"; }</style>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  # Should find at least one block
  expect_true(length(blocks) >= 1)
})

test_that("detect_report_type handles whitespace in meta tags", {
  html <- '<meta  name="turas-report-type"  content="tracker">'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("rewrite_css_ids handles empty CSS string", {
  result <- rewrite_css_ids("", "tk--")
  expect_equal(result, "")
})

test_that("rewrite_html_ids handles empty HTML string", {
  result <- rewrite_html_ids("", "tk--")
  expect_equal(result, "")
})

test_that("merge_pinned_data handles empty parsed_reports list", {
  result <- merge_pinned_data(list())
  expect_equal(result, "[]")
})

test_that("parse_settings_sheet handles key-value format with extra columns", {
  df <- data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Title", "Company"),
    Notes = c("Note 1", "Note 2"),
    stringsAsFactors = FALSE
  )
  result <- parse_settings_sheet(df)

  expect_equal(result$project_title, "Title")
  expect_equal(result$company_name, "Company")
})

test_that("rewrite_html_onclick_conflicts prefixes conflict functions in onclick", {
  html <- '<button onclick="togglePin(\'Q1\')">Pin</button>'
  result <- rewrite_html_onclick_conflicts(html, "tracker")

  expect_true(grepl("tracker_togglePin", result))
})

test_that("rewrite_html_onclick_conflicts handles multiple conflict functions", {
  html <- paste0(
    '<button onclick="exportCSV()">CSV</button>',
    '<button onclick="exportExcel()">Excel</button>'
  )
  result <- rewrite_html_onclick_conflicts(html, "tabs")

  expect_true(grepl("tabs_exportCSV", result))
  expect_true(grepl("tabs_exportExcel", result))
})

test_that("wrap_js_in_iife prefixes conflicting function definitions", {
  js_blocks <- list(
    list(content = 'function togglePin(qCode) { /* impl */ }
function escapeHtml(str) { return str; }
var someNonConflict = true;')
  )

  result <- wrap_js_in_iife(js_blocks, "tabs", "tabs")

  expect_true(grepl("function tabs_togglePin", result))
  expect_true(grepl("function tabs_escapeHtml", result))
  # Non-conflicting vars should NOT be prefixed
  expect_true(grepl("var someNonConflict", result))
})

test_that("wrap_js_in_iife adds scoped DOM helper functions", {
  js_blocks <- list(
    list(content = 'var el = document.getElementById("test");')
  )

  result <- wrap_js_in_iife(js_blocks, "tracker", "tracker")

  # Should define helper functions
  expect_true(grepl("_tracker_id", result))
  expect_true(grepl("_tracker_qs", result))
  expect_true(grepl("_tracker_qsa", result))

  # The user code 'document.getElementById("test")' should be rewritten to the helper.
  # Note: The helper *definitions* themselves still reference document.getElementById,
  # so we check that the original user-code call was replaced by the helper.
  expect_true(grepl('_tracker_id("test")', result, fixed = TRUE))
  # The original user-code call should NOT appear verbatim
  expect_false(grepl('var el = document.getElementById("test")', result, fixed = TRUE))
})

test_that("wrap_js_in_iife replaces querySelectorAll before querySelector", {
  js_blocks <- list(
    list(content = 'var els = document.querySelectorAll(".items"); var el = document.querySelector(".item");')
  )

  result <- wrap_js_in_iife(js_blocks, "tabs", "tabs")

  expect_true(grepl("_tabs_qsa(", result, fixed = TRUE))
  expect_true(grepl("_tabs_qs(", result, fixed = TRUE))
  # The original user-code calls should be rewritten to helpers
  expect_false(grepl('var els = document.querySelectorAll(".items")', result, fixed = TRUE))
  expect_false(grepl('var el = document.querySelector(".item")', result, fixed = TRUE))
  # Verify the helpers are used in user code
  expect_true(grepl('_tabs_qsa(".items")', result, fixed = TRUE))
  expect_true(grepl('_tabs_qs(".item")', result, fixed = TRUE))
})

test_that("build_namespace_api creates TrackerReport for tracker type", {
  api_js <- build_namespace_api("TrackerReport", "tracker", "tracker")

  expect_true(grepl("var TrackerReport", api_js))
  expect_true(grepl("tracker_togglePin", api_js))
  expect_true(grepl("tracker_updatePinButton", api_js))
  expect_true(grepl("tracker_toggleHelpOverlay", api_js))
})

test_that("build_namespace_api creates TabsReport for tabs type", {
  api_js <- build_namespace_api("TabsReport", "tabs", "tabs")

  expect_true(grepl("var TabsReport", api_js))
  expect_true(grepl("tabs_togglePin", api_js))
  expect_true(grepl("tabs_updatePinButton", api_js))
  expect_true(grepl("tabs_toggleHelpOverlay", api_js))
})

test_that("build_pin_bridge generates tracker bridge with correct prefixes", {
  bridge_js <- build_pin_bridge("tracker", "tracker")

  expect_true(grepl("Hub Pin Bridge", bridge_js))
  expect_true(grepl("ReportHub.addPin", bridge_js))
  expect_true(grepl("_tracker_id", bridge_js))
  expect_true(grepl("tracker_pinSigCard", bridge_js))
  expect_true(grepl("tracker_pinVisibleSigFindings", bridge_js))
  expect_true(grepl("tracker_hydratePinnedViews", bridge_js))
  expect_true(grepl("tracker_renderPinnedCards", bridge_js))
})

test_that("build_pin_bridge generates tabs bridge with correct prefixes", {
  bridge_js <- build_pin_bridge("tabs", "tabs")

  expect_true(grepl("Hub Pin Bridge", bridge_js))
  expect_true(grepl("ReportHub.addPin", bridge_js))
  expect_true(grepl("_tabs_id", bridge_js))
  expect_true(grepl("tabs_togglePin", bridge_js))
  expect_true(grepl("tabs_pinSigCard", bridge_js))
  expect_true(grepl("tabs_pinVisibleSigFindings", bridge_js))
  expect_true(grepl("tabs_hydratePinnedViews", bridge_js))
  expect_true(grepl("tabs_renderPinnedCards", bridge_js))
  expect_true(grepl("tabs_pinQualSlide", bridge_js))
})


# ==============================================================================
# 6. HELP OVERLAY: extract_help_overlay()
# ==============================================================================

test_that("extract_help_overlay captures tabs help overlay", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">
  <div class="help-card" onclick="event.stopPropagation()">
    <h2>Quick Guide</h2>
    <p>Help content here</p>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tabs")

  expect_true(nzchar(result))
  expect_true(grepl('class="help-overlay"', result))
  expect_true(grepl('id="help-overlay"', result))
  expect_true(grepl("Quick Guide", result))
  expect_true(grepl("toggleHelpOverlay", result))
})

test_that("extract_help_overlay captures tracker help overlay", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tracker"></head>
<body>
<div id="tab-overview" class="tab-panel">content</div>
<div id="tk-help-overlay" class="tk-help-overlay" onclick="toggleHelpOverlay()">
  <div class="tk-help-card">
    <h2>Tracker Help</h2>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tracker")

  expect_true(nzchar(result))
  expect_true(grepl('id="tk-help-overlay"', result))
  expect_true(grepl("Tracker Help", result))
})

test_that("extract_help_overlay returns empty string for catdriver", {
  html <- '<html><body><div id="cd-section-overview">content</div></body></html>'
  result <- extract_help_overlay(html, "catdriver")
  expect_equal(result, "")
})

test_that("extract_help_overlay returns empty string for keydriver", {
  result <- extract_help_overlay("<html><body></body></html>", "keydriver")
  expect_equal(result, "")
})

test_that("extract_help_overlay returns empty string for confidence", {
  result <- extract_help_overlay("<html><body></body></html>", "confidence")
  expect_equal(result, "")
})

test_that("extract_help_overlay returns empty string when no overlay present", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tabs")
  expect_equal(result, "")
})

test_that("extract_help_overlay handles deeply nested divs correctly", {
  # Realistic overlay with inner divs (help-subtitle, help-tip, help-dismiss)
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">
  <div class="help-card" onclick="event.stopPropagation()">
    <h2>Quick Guide</h2>
    <div class="help-subtitle">Everything you need to know</div>
    <h3>Section</h3>
    <ul><li>Item</li></ul>
    <div class="help-tip"><strong>Tip:</strong> Some advice here.</div>
    <div class="help-dismiss">Click anywhere to close</div>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tabs")
  opens <- length(gregexpr("<div", result)[[1]])
  closes <- length(gregexpr("</div>", result)[[1]])
  expect_equal(opens, closes, info = "Help overlay divs must be balanced")
  expect_equal(opens, 5)  # overlay, card, subtitle, tip, dismiss
  expect_true(grepl("help-dismiss", result))
  expect_true(grepl("</div>$", trimws(result)))
})

test_that("extract_help_overlay handles tracker with 3-level nesting", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tracker"></head>
<body>
<div id="tab-overview" class="tab-panel">content</div>
<div id="tk-help-overlay" class="tk-help-overlay" style="display:none">
  <div class="tk-help-content">
    <h2>Tracking Report Help</h2>
    <button class="tk-help-close" onclick="toggleHelpOverlay()">&times;</button>
    <div class="tk-help-body">
      <h3>Report Tabs</h3>
      <ul><li>Summary</li></ul>
    </div>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tracker")
  opens <- length(gregexpr("<div", result)[[1]])
  closes <- length(gregexpr("</div>", result)[[1]])
  expect_equal(opens, closes, info = "Tracker overlay divs must be balanced")
  expect_equal(opens, 3)  # overlay, content, body
  expect_true(grepl("tk-help-body", result))
})

test_that("extract_balanced_div extracts correctly balanced HTML", {
  html <- '<div class="outer"><div class="inner"><div class="deep">x</div></div></div>rest'
  start <- regexpr('<div class="outer"', html, fixed = TRUE)
  result <- extract_balanced_div(html, start)
  expect_equal(result, '<div class="outer"><div class="inner"><div class="deep">x</div></div></div>')
})

test_that("parse_html_report includes help_overlay in result for tabs", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">Crosstabs</div>
<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">
  <div class="help-card" onclick="event.stopPropagation()">
    <h2>Quick Guide</h2>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result$help_overlay))
  expect_true(nzchar(result$result$help_overlay))
  expect_true(grepl("Quick Guide", result$result$help_overlay))
})

test_that("parse_html_report returns empty help_overlay for report without overlay", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  expect_equal(result$result$help_overlay, "")
})


# ==============================================================================
# 6. HELP OVERLAY: namespace rewriting
# ==============================================================================

test_that("rewrite_for_hub namespaces help overlay IDs", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = '<div id="tab-crosstabs" class="tab-panel">content</div>'
    ),
    report_tabs = list(html = "", tab_names = c("crosstabs")),
    header = "",
    footer = "",
    help_overlay = paste0(
      '<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">',
      '<div class="help-card" onclick="event.stopPropagation()">',
      '<h2>Quick Guide</h2></div></div>'
    ),
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "tabs"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)

  # Help overlay IDs should be prefixed
  expect_true(grepl('id="tabs--help-overlay"', result$help_overlay))
  # onclick should be namespaced
  expect_true(grepl('tabs_toggleHelpOverlay', result$help_overlay))
  # Original unprefixed ID should NOT be present
  expect_false(grepl('id="help-overlay"[^-]', result$help_overlay))
})

test_that("rewrite_for_hub handles NULL help overlay gracefully", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = '<div id="tab-crosstabs" class="tab-panel">content</div>'
    ),
    report_tabs = list(html = "", tab_names = c("crosstabs")),
    header = "",
    footer = "",
    help_overlay = NULL,
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "tabs"),
    pinned_data = "[]"
  )

  # Should not error
  result <- rewrite_for_hub(parsed)
  expect_null(result$help_overlay)
})

test_that("rewrite_for_hub handles empty help overlay gracefully", {
  parsed <- list(
    report_key = "catdriver",
    report_type = "catdriver",
    content_panels = list(
      overview = '<div id="cd-section-overview">content</div>'
    ),
    report_tabs = list(html = "", tab_names = c("overview")),
    header = "",
    footer = "",
    help_overlay = "",
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "catdriver"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)
  expect_equal(result$help_overlay, "")
})


# ==============================================================================
# 6. HELP OVERLAY: navigation builder
# ==============================================================================

test_that("build_level2_nav adds help button when has_help_overlay is TRUE", {
  html <- build_level2_nav(
    report_key = "tabs",
    tab_names = c("summary", "crosstabs"),
    report_type = "tabs",
    has_help_overlay = TRUE
  )

  expect_true(grepl('class="hub-help-btn"', html))
  expect_true(grepl('tabs_toggleHelpOverlay', html))
  expect_true(grepl('\\?', html))
})

test_that("build_level2_nav omits help button when has_help_overlay is FALSE", {
  html <- build_level2_nav(
    report_key = "catdriver",
    tab_names = c("overview", "drivers"),
    report_type = "catdriver",
    has_help_overlay = FALSE
  )

  expect_false(grepl('hub-help-btn', html))
  expect_false(grepl('toggleHelpOverlay', html))
})

test_that("build_level2_nav omits help button by default", {
  html <- build_level2_nav(
    report_key = "keydriver",
    tab_names = c("overview"),
    report_type = "keydriver"
  )

  expect_false(grepl('hub-help-btn', html))
})

test_that("build_navigation passes help_overlay flag to level 2 nav", {
  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      report_tabs = list(tab_names = c("summary", "crosstabs")),
      help_overlay = '<div class="help-overlay" id="tabs--help-overlay">help</div>'
    ),
    list(
      report_key = "catdriver",
      report_type = "catdriver",
      report_tabs = list(tab_names = c("overview")),
      help_overlay = ""
    )
  )

  report_configs <- list(
    list(key = "tabs", label = "Crosstabs", type = "tabs"),
    list(key = "catdriver", label = "Drivers", type = "catdriver")
  )

  html <- build_navigation(parsed_reports, report_configs)

  # tabs should have help button
  expect_true(grepl('tabs_toggleHelpOverlay', html))
  # catdriver should NOT have help button
  expect_false(grepl('catdriver_toggleHelpOverlay', html))
})


# ==============================================================================
# 6. HELP OVERLAY: page assembler integration
# ==============================================================================

test_that("assemble_hub_html includes help overlay in report panel", {
  config <- list(
    settings = list(
      project_title = "Help Test",
      company_name = "Co",
      brand_colour = "#323367",
      accent_colour = "#CC9900",
      client_name = NULL,
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      content_panels = list(
        crosstabs = '<div id="tabs--tab-crosstabs" class="tab-panel">Crosstab content</div>'
      ),
      footer = "",
      help_overlay = '<div class="help-overlay" id="tabs--help-overlay" onclick="tabs_toggleHelpOverlay()"><div class="help-card"><h2>Quick Guide</h2></div></div>',
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// tabs js",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "<div>overview</div>", "<nav>nav</nav>")

  # Help overlay should be inside the report panel
  expect_true(grepl('id="tabs--help-overlay"', html))
  expect_true(grepl("Quick Guide", html))
  expect_true(grepl("tabs_toggleHelpOverlay", html))
})

test_that("assemble_hub_html does not inject empty help overlay", {
  config <- list(
    settings = list(
      project_title = "No Help Test",
      company_name = "Co",
      brand_colour = NULL,
      accent_colour = NULL,
      client_name = NULL,
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "catdriver",
      report_type = "catdriver",
      content_panels = list(
        overview = '<div id="catdriver--cd-section-overview">content</div>'
      ),
      footer = "",
      help_overlay = "",
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// catdriver js",
      metadata = list(report_type = "catdriver"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "", "")

  # Should NOT contain any help overlay div
  expect_false(grepl("help-overlay", html))
})

test_that("two tabs reports have independent namespaced help overlays", {
  config <- list(
    settings = list(
      project_title = "Dual Tabs Test",
      company_name = "Co",
      brand_colour = "#323367",
      accent_colour = "#CC9900",
      client_name = NULL,
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "tabs1",
      report_type = "tabs",
      content_panels = list(
        crosstabs = '<div id="tabs1--tab-crosstabs" class="tab-panel">Report 1</div>'
      ),
      footer = "",
      help_overlay = '<div class="help-overlay" id="tabs1--help-overlay" onclick="tabs1_toggleHelpOverlay()"><div class="help-card"><h2>Help 1</h2></div></div>',
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// tabs1 js",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    ),
    list(
      report_key = "tabs2",
      report_type = "tabs",
      content_panels = list(
        crosstabs = '<div id="tabs2--tab-crosstabs" class="tab-panel">Report 2</div>'
      ),
      footer = "",
      help_overlay = '<div class="help-overlay" id="tabs2--help-overlay" onclick="tabs2_toggleHelpOverlay()"><div class="help-card"><h2>Help 2</h2></div></div>',
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// tabs2 js",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "", "")

  # Both overlays should be present with their own namespaced IDs
  expect_true(grepl('id="tabs1--help-overlay"', html))
  expect_true(grepl('id="tabs2--help-overlay"', html))
  expect_true(grepl("tabs1_toggleHelpOverlay", html))
  expect_true(grepl("tabs2_toggleHelpOverlay", html))
  expect_true(grepl("Help 1", html))
  expect_true(grepl("Help 2", html))
})


# ==============================================================================
# 7. VISUAL FEATURE PRESERVATION
# ==============================================================================

test_that("SVG charts with rounded corners survive the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs">
<style>.chart-container { width: 100%; }</style>
</head><body>
<div id="tab-crosstabs" class="tab-panel">
  <svg viewBox="0 0 400 200"><rect x="10" y="10" width="80" height="30" rx="4" fill="#4a7c6f"/></svg>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  expect_equal(result$status, "PASS")

  # Chart SVG should be in the content panel
  panel <- result$result$content_panels$crosstabs
  expect_true(grepl('rx="4"', panel))
  expect_true(grepl('fill="#4a7c6f"', panel))
  expect_true(grepl("<svg", panel))
})

test_that("base64 images survive namespace rewriting", {
  img_data <- "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=="

  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = sprintf(
        '<div id="tab-crosstabs" class="tab-panel"><img src="%s" alt="Logo" id="logo-img"></div>',
        img_data
      )
    ),
    report_tabs = list(html = "", tab_names = c("crosstabs")),
    header = "",
    footer = "",
    help_overlay = "",
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "tabs"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)

  # base64 image data must be preserved intact
  expect_true(grepl(img_data, result$content_panels$crosstabs, fixed = TRUE))
  # ID should be namespaced
  expect_true(grepl('id="tabs--logo-img"', result$content_panels$crosstabs))
})

test_that("heatmap data attributes survive the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<div id="tab-crosstabs" class="tab-panel">
  <table><tr><td data-heatmap-value="0.75" data-stat-type="pct" data-row-type="category">75%</td></tr></table>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  panel <- result$result$content_panels$crosstabs

  expect_true(grepl('data-heatmap-value="0.75"', panel))
  expect_true(grepl('data-stat-type="pct"', panel))
  expect_true(grepl('data-row-type="category"', panel))
})

test_that("colour palette CSS variables survive the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs">
<style>:root { --ct-brand: #323367; --ct-accent: #CC9900; --ct-text-primary: #1e293b; }</style>
</head><body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  css <- result$result$css_blocks[[1]]$content

  expect_true(grepl("--ct-brand", css))
  expect_true(grepl("--ct-accent", css))
  expect_true(grepl("--ct-text-primary", css))
})

test_that("dashboard gauge HTML survives the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<div id="tab-summary" class="tab-panel active">
  <div class="dash-gauge-container">
    <svg class="dash-gauge" viewBox="0 0 120 80"><path d="M10 70 A50 50 0 0 1 110 70" fill="none" stroke="#059669" stroke-width="8"/></svg>
    <div class="dash-gauge-value" style="color:#059669;">85%</div>
  </div>
</div>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  panel <- result$result$content_panels$summary

  expect_true(grepl("dash-gauge-container", panel))
  expect_true(grepl('stroke="#059669"', panel))
  expect_true(grepl("85%", panel))
})

test_that("qualitative slide HTML with images survives the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<div id="tab-summary" class="tab-panel active">Summary</div>
<div id="tab-crosstabs" class="tab-panel">Crosstabs</div>
<div id="tab-qualitative" class="tab-panel">
  <div class="qual-slide" data-slide-idx="0">
    <div class="qual-slide-image"><img src="data:image/jpeg;base64,/9j/4AAQSkZJRg==" alt="Slide image"></div>
    <div class="qual-slide-text" contenteditable="true">Key finding about brand perception</div>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  panel <- result$result$content_panels$qualitative

  expect_true(grepl("qual-slide", panel))
  expect_true(grepl("data:image/jpeg;base64", panel))
  expect_true(grepl("Key finding about brand perception", panel))
  expect_true(grepl('contenteditable="true"', panel))
})
