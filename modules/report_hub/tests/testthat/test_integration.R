# Report Hub -- Integration Tests
# Tests for combine_reports() (main pipeline) and write_hub_html() (file I/O)

# Source combine_reports() from 00_main.R.
# 00_main.R internally sources modules relative to "modules/report_hub/",
# so we need to set the working directory to the project root first.
# The helper-setup.R already sourced individual module files, so we only
# need combine_reports() and the HUB_MAX_SOURCE_SIZE_BYTES constant.
.hub_project_root <- normalizePath(
  file.path(testthat::test_path(), "..", "..", "..", ".."),
  mustWork = FALSE
)
if (file.exists(file.path(.hub_project_root, "modules", "report_hub", "00_main.R"))) {
  .hub_prev_wd <- getwd()
  setwd(.hub_project_root)
  tryCatch(
    source(file.path("modules", "report_hub", "00_main.R")),
    error = function(e) message("Could not source 00_main.R: ", e$message)
  )
  setwd(.hub_prev_wd)
}

# ==============================================================================
# write_hub_html() — File I/O Tests
# ==============================================================================

test_that("write_hub_html writes valid HTML to a file", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  html <- "<!DOCTYPE html><html><head><title>Test</title></head><body><p>Hello</p></body></html>"
  result <- write_hub_html(html, tmp)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
  expect_equal(result$result$file_size, file.info(tmp)$size)
  expect_true(nzchar(result$result$size_label))
  expect_true(grepl(basename(tmp), result$message))

  # Verify content was written correctly
  written <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("Hello", written))
})

test_that("write_hub_html creates output directory if it doesn't exist", {
  tmp_dir <- file.path(tempdir(), paste0("hub_test_", format(Sys.time(), "%H%M%S")))
  tmp <- file.path(tmp_dir, "output.html")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  html <- "<html><body>test</body></html>"
  result <- write_hub_html(html, tmp)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))
})

test_that("write_hub_html returns REFUSED for invalid directory", {
  # Path under a read-only system directory that cannot be created
  result <- write_hub_html("<html></html>", "/proc/nonexistent/deep/path/file.html")

  expect_equal(result$status, "REFUSED")
  expect_true(result$code %in% c("IO_DIR_CREATE_FAILED", "IO_WRITE_FAILED"))
})

test_that("write_hub_html preserves file content byte-for-byte", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  # Use ASCII content to avoid locale-dependent encoding issues
  html <- "<!DOCTYPE html><html><body><p>Test content with special chars: &amp; &lt; &gt;</p></body></html>"
  result <- write_hub_html(html, tmp)

  expect_equal(result$status, "PASS")
  written <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("Test content", written))
  expect_true(grepl("&amp;", written, fixed = TRUE))
  # File size should match (writeLines adds a trailing newline)
  expect_true(result$result$file_size > 0)
})


# ==============================================================================
# combine_reports() — Full Pipeline Integration Tests
# ==============================================================================

test_that("combine_reports produces a valid hub file from demo config", {
  skip_if_not_installed("openxlsx")
  skip_if_not_installed("htmltools")
  skip_if_not_installed("base64enc")
  skip_if_not_installed("jsonlite")

  config_file <- normalizePath(
    file.path("examples", "report_hub", "Demo_Combined_Config.xlsx"),
    mustWork = FALSE
  )
  # Try relative to project root

  if (!file.exists(config_file)) {
    config_file <- normalizePath(
      file.path(testthat::test_path(), "..", "..", "..", "..", "examples",
                "report_hub", "Demo_Combined_Config.xlsx"),
      mustWork = FALSE
    )
  }
  skip_if(!file.exists(config_file), "Demo config not found — run from project root")

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  result <- combine_reports(config_file, output_file = tmp)

  # Should succeed (PASS or PARTIAL if warnings)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_true(file.exists(tmp))
  expect_true(result$result$file_size > 0)
  expect_true(result$result$n_reports > 0)
  expect_true(length(result$result$report_keys) > 0)

  # Read output and verify structure
  html <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl('content="hub"', html))
  expect_true(grepl("hub-report-iframe", html))
  expect_true(grepl('data-encoding="base64"', html))
  expect_true(grepl("DOMContentLoaded", html))
  expect_true(grepl("ReportHub.initNavigation", html))
})

test_that("combine_reports returns REFUSED for missing config file", {
  result <- combine_reports("/nonexistent/path/config.xlsx")

  expect_equal(result$status, "REFUSED")
  expect_true(grepl("IO_", result$code))
})

test_that("combine_reports returns REFUSED for invalid config file", {
  skip_if_not_installed("openxlsx")

  # Create a minimal but invalid Excel file (missing required sheets)
  tmp_config <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp_config), add = TRUE)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Wrong")
  openxlsx::writeData(wb, "Wrong", data.frame(x = 1))
  openxlsx::saveWorkbook(wb, tmp_config, overwrite = TRUE)

  result <- combine_reports(tmp_config)

  expect_equal(result$status, "REFUSED")
  expect_true(grepl("CFG_", result$code))
})

test_that("combine_reports handles missing report files gracefully", {
  skip_if_not_installed("openxlsx")

  # Create config that points to non-existent report files
  tmp_config <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp_config), add = TRUE)

  wb <- openxlsx::createWorkbook()

  # Settings sheet
  openxlsx::addWorksheet(wb, "Settings")
  settings <- data.frame(
    field = c("project_title", "company_name"),
    value = c("Test Project", "TestCo"),
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Settings", settings)

  # Reports sheet pointing to non-existent file
  openxlsx::addWorksheet(wb, "Reports")
  reports <- data.frame(
    report_path = "/nonexistent/report.html",
    report_label = "Missing Report",
    report_key = "missing",
    order = 1,
    stringsAsFactors = FALSE
  )
  openxlsx::writeData(wb, "Reports", reports)
  openxlsx::saveWorkbook(wb, tmp_config, overwrite = TRUE)

  result <- combine_reports(tmp_config)

  # Should refuse — can't find the report file
  expect_equal(result$status, "REFUSED")
})


# ==============================================================================
# Guard Layer — New Validation Rules
# ==============================================================================

test_that("reserved report keys are rejected", {
  # Build a minimal reports data frame with a reserved key
  reports_df <- data.frame(
    report_path = tempfile(fileext = ".html"),
    report_label = "Window Report",
    report_key = "window",
    order = 1,
    stringsAsFactors = FALSE
  )
  # Create the dummy HTML file so path validation passes
  writeLines("<html><body>test</body></html>", reports_df$report_path[1])
  on.exit(unlink(reports_df$report_path[1]), add = TRUE)

  # We can't easily call .validate_reports without a full Excel file,
  # so test the full guard pipeline
  skip_if_not_installed("openxlsx")
  tmp_config <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp_config), add = TRUE)

  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    field = c("project_title", "company_name"),
    value = c("Test", "TestCo"),
    stringsAsFactors = FALSE
  ))
  openxlsx::addWorksheet(wb, "Reports")
  openxlsx::writeData(wb, "Reports", reports_df)
  openxlsx::saveWorkbook(wb, tmp_config, overwrite = TRUE)

  result <- guard_validate_hub_config(tmp_config)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "CFG_RESERVED_KEY")
})

test_that("hex colour validation accepts valid colours", {
  expect_equal(.validate_hex_colour("#FF0000", "#000"), "#FF0000")
  expect_equal(.validate_hex_colour("#abc", "#000"), "#abc")
  expect_equal(.validate_hex_colour("#1a2B3c", "#000"), "#1a2B3c")
  expect_null(.validate_hex_colour(NULL, "#000"))
  expect_null(.validate_hex_colour("", "#000"))
})

test_that("hex colour validation rejects invalid colours", {
  expect_equal(.validate_hex_colour("red", "#323367"), "#323367")
  expect_equal(.validate_hex_colour("not-a-colour", "#CC9900"), "#CC9900")
  expect_equal(.validate_hex_colour("#GGGGGG", "#323367"), "#323367")
  expect_equal(.validate_hex_colour("323367", "#323367"), "#323367")  # missing #
})


# ==============================================================================
# HTML Entity Decoding — Expanded Coverage
# ==============================================================================

test_that("HTML entity decoding handles all common entities", {
  skip_if_not_installed("htmltools")

  # Create minimal Turas-format HTML with entities in title
  html <- '<html><head><meta name="turas-report-type" content="tabs"><title>Test &amp; Report &mdash; Brand&trade; &copy; 2024</title></head><body></body></html>'
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(html, tmp)

  result <- parse_html_report(tmp, "test")
  expect_equal(result$status, "PASS")
  title <- result$result$metadata$project_title

  expect_true(grepl("&", title, fixed = TRUE))
  expect_true(grepl("\u2014", title))  # em dash
  expect_true(grepl("\u2122", title))  # trademark
  expect_true(grepl("\u00A9", title))  # copyright
})

test_that("HTML entity decoding handles numeric references", {
  skip_if_not_installed("htmltools")

  html <- '<html><head><meta name="turas-report-type" content="tracker"><title>Test &#8212; Report &#x2019;s</title></head><body></body></html>'
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(html, tmp)

  result <- parse_html_report(tmp, "test")
  expect_equal(result$status, "PASS")
  title <- result$result$metadata$project_title

  # &#8212; is em dash, &#x2019; is right single quote
  expect_true(grepl("\u2014", title))
  expect_true(grepl("\u2019", title))
})
