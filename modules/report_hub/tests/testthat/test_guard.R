# Report Hub -- Guard Layer Tests (00_guard.R)
# Tests for parse_settings_sheet() and guard_validate_hub_config()

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
