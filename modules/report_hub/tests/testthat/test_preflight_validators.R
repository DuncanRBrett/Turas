# ==============================================================================
# TESTS: Preflight Validators (preflight_validators.R)
# ==============================================================================
# Tests for the 11 content-level validation checks that verify config and
# report files before the combine_reports() pipeline runs.
#
# Run with:
#   testthat::test_file("modules/report_hub/tests/testthat/test_preflight_validators.R")
# ==============================================================================

library(testthat)

# ==============================================================================
# SOURCE DEPENDENCIES
# ==============================================================================

hub_root <- normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = FALSE)
if (!file.exists(file.path(hub_root, "00_guard.R"))) {
  hub_root <- normalizePath("modules/report_hub", mustWork = FALSE)
}
if (!file.exists(file.path(hub_root, "00_guard.R"))) {
  # Try climbing from getwd()
  path <- getwd()
  for (i in 1:10) {
    candidate <- file.path(path, "modules", "report_hub")
    if (dir.exists(candidate) && file.exists(file.path(candidate, "00_guard.R"))) {
      hub_root <- candidate
      break
    }
    path <- dirname(path)
  }
}

# Source preflight validators
preflight_path <- file.path(hub_root, "lib", "validation", "preflight_validators.R")
if (file.exists(preflight_path)) {
  source(preflight_path)
} else {
  stop("Cannot find preflight_validators.R at: ", preflight_path)
}


# ==============================================================================
# HELPERS
# ==============================================================================

new_error_log <- function() {
  .hub_create_error_log()
}

make_reports_df <- function(keys = c("report1", "report2"),
                             labels = c("Report One", "Report Two"),
                             paths = NULL,
                             orders = 1:2) {
  if (is.null(paths)) {
    paths <- file.path(tempdir(), paste0(keys, ".html"))
  }
  data.frame(
    report_path = basename(paths),
    report_label = labels,
    report_key = keys,
    order = orders,
    report_type = NA_character_,
    resolved_path = paths,
    stringsAsFactors = FALSE
  )
}

create_html_file <- function(path, content = NULL) {
  if (is.null(content)) {
    content <- '<!DOCTYPE html><html><head><title>Test</title></head><body><p>Test report</p></body></html>'
  }
  writeLines(content, path)
  path
}


# ==============================================================================
# TESTS
# ==============================================================================

# --- 1. check_report_files_readable ---

test_that("check_report_files_readable detects missing files", {
  skip_if(!exists("check_report_files_readable", mode = "function"),
          "check_report_files_readable not available")

  reports_df <- make_reports_df(
    paths = c("/nonexistent/path/r1.html", "/nonexistent/path/r2.html")
  )

  result <- check_report_files_readable(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) >= 2)
})

test_that("check_report_files_readable detects non-HTML files", {
  skip_if(!exists("check_report_files_readable", mode = "function"),
          "check_report_files_readable not available")

  tmp <- tempdir()
  txt_path <- file.path(tmp, "not_html.html")
  writeLines("This is just plain text, not HTML at all.", txt_path)

  reports_df <- make_reports_df(keys = "txt", labels = "Text File", paths = txt_path)

  result <- check_report_files_readable(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Not Valid HTML", errors$Issue)))

  unlink(txt_path)
})

test_that("check_report_files_readable passes with valid HTML files", {
  skip_if(!exists("check_report_files_readable", mode = "function"),
          "check_report_files_readable not available")

  tmp <- tempdir()
  html_path <- file.path(tmp, "valid_report.html")
  create_html_file(html_path)

  reports_df <- make_reports_df(keys = "valid", labels = "Valid Report", paths = html_path)

  result <- check_report_files_readable(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)

  unlink(html_path)
})


# --- 2. check_report_key_format ---

test_that("check_report_key_format detects invalid key characters", {
  skip_if(!exists("check_report_key_format", mode = "function"),
          "check_report_key_format not available")

  reports_df <- make_reports_df(keys = c("valid_key", "bad key!"))

  result <- check_report_key_format(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("bad key!", errors$Detail, fixed = TRUE)))
})

test_that("check_report_key_format detects key starting with number", {
  skip_if(!exists("check_report_key_format", mode = "function"),
          "check_report_key_format not available")

  reports_df <- make_reports_df(keys = c("valid", "123abc"))

  result <- check_report_key_format(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("123abc", errors$Detail)))
})

test_that("check_report_key_format warns about long keys", {
  skip_if(!exists("check_report_key_format", mode = "function"),
          "check_report_key_format not available")

  long_key <- paste0(rep("a", 35), collapse = "")
  reports_df <- make_reports_df(keys = c("short", long_key))

  result <- check_report_key_format(reports_df, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


# --- 3. check_duplicate_report_keys ---

test_that("check_duplicate_report_keys detects duplicates", {
  skip_if(!exists("check_duplicate_report_keys", mode = "function"),
          "check_duplicate_report_keys not available")

  reports_df <- make_reports_df(keys = c("report1", "report1"))

  result <- check_duplicate_report_keys(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("report1", errors$Detail)))
})

test_that("check_duplicate_report_keys passes with unique keys", {
  skip_if(!exists("check_duplicate_report_keys", mode = "function"),
          "check_duplicate_report_keys not available")

  reports_df <- make_reports_df()

  result <- check_duplicate_report_keys(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 4. check_report_order_gaps ---

test_that("check_report_order_gaps detects duplicate order values", {
  skip_if(!exists("check_report_order_gaps", mode = "function"),
          "check_report_order_gaps not available")

  reports_df <- make_reports_df(orders = c(1, 1))

  result <- check_report_order_gaps(reports_df, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
  expect_true(any(grepl("Duplicate", warnings$Issue)))
})

test_that("check_report_order_gaps detects non-positive order values", {
  skip_if(!exists("check_report_order_gaps", mode = "function"),
          "check_report_order_gaps not available")

  reports_df <- make_reports_df(orders = c(0, -1))

  result <- check_report_order_gaps(reports_df, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


# --- 5. check_colour_codes_valid ---

test_that("check_colour_codes_valid detects invalid hex colour", {
  skip_if(!exists("check_colour_codes_valid", mode = "function"),
          "check_colour_codes_valid not available")

  settings <- list(brand_colour = "not-a-hex", accent_colour = "#323367")

  result <- check_colour_codes_valid(settings, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("not-a-hex", errors$Detail)))
})

test_that("check_colour_codes_valid passes with valid hex colours", {
  skip_if(!exists("check_colour_codes_valid", mode = "function"),
          "check_colour_codes_valid not available")

  settings <- list(brand_colour = "#1e3a5f", accent_colour = "#2aa198")

  result <- check_colour_codes_valid(settings, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})

test_that("check_colour_codes_valid accepts shorthand hex", {
  skip_if(!exists("check_colour_codes_valid", mode = "function"),
          "check_colour_codes_valid not available")

  settings <- list(brand_colour = "#abc")

  result <- check_colour_codes_valid(settings, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 6. check_output_dir_writable ---

test_that("check_output_dir_writable passes with writable directory", {
  skip_if(!exists("check_output_dir_writable", mode = "function"),
          "check_output_dir_writable not available")

  settings <- list(output_dir = tempdir())

  result <- check_output_dir_writable(settings, tempdir(), new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_equal(nrow(errors), 0)
})


# --- 7. check_report_file_sizes ---

test_that("check_report_file_sizes warns about very small files", {
  skip_if(!exists("check_report_file_sizes", mode = "function"),
          "check_report_file_sizes not available")

  tmp <- tempdir()
  tiny_path <- file.path(tmp, "tiny.html")
  writeLines("", tiny_path)

  reports_df <- make_reports_df(keys = "tiny", labels = "Tiny", paths = tiny_path)

  result <- check_report_file_sizes(reports_df, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
  expect_true(any(grepl("Small", warnings$Issue, ignore.case = TRUE)))

  unlink(tiny_path)
})


# --- 8. check_logo_file_valid ---

test_that("check_logo_file_valid warns about missing logo file", {
  skip_if(!exists("check_logo_file_valid", mode = "function"),
          "check_logo_file_valid not available")

  settings <- list(logo_path = "nonexistent_logo.png")

  result <- check_logo_file_valid(settings, tempdir(), new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
  expect_true(any(grepl("Not Found", warnings$Issue)))
})

test_that("check_logo_file_valid warns about invalid format", {
  skip_if(!exists("check_logo_file_valid", mode = "function"),
          "check_logo_file_valid not available")

  tmp <- tempdir()
  bad_logo <- file.path(tmp, "logo.bmp")
  writeLines("fake image", bad_logo)

  settings <- list(logo_path = bad_logo)

  result <- check_logo_file_valid(settings, tmp, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
  expect_true(any(grepl("Invalid Logo Format", warnings$Issue)))

  unlink(bad_logo)
})

test_that("check_logo_file_valid skips when no logo specified", {
  skip_if(!exists("check_logo_file_valid", mode = "function"),
          "check_logo_file_valid not available")

  settings <- list(logo_path = NULL)

  result <- check_logo_file_valid(settings, tempdir(), new_error_log())
  expect_equal(nrow(result), 0)
})


# --- 9. check_duplicate_report_paths ---

test_that("check_duplicate_report_paths warns about duplicate paths", {
  skip_if(!exists("check_duplicate_report_paths", mode = "function"),
          "check_duplicate_report_paths not available")

  same_path <- file.path(tempdir(), "same_report.html")
  reports_df <- make_reports_df(
    keys = c("r1", "r2"), labels = c("R1", "R2"),
    paths = c(same_path, same_path)
  )

  result <- check_duplicate_report_paths(reports_df, new_error_log())
  warnings <- result[result$Severity == "Warning", ]
  expect_true(nrow(warnings) > 0)
})


# --- 10. check_report_type_detection ---

test_that("check_report_type_detection detects invalid explicit type", {
  skip_if(!exists("check_report_type_detection", mode = "function"),
          "check_report_type_detection not available")

  tmp <- tempdir()
  html_path <- file.path(tmp, "typed_report.html")
  create_html_file(html_path)

  reports_df <- data.frame(
    report_path = "typed_report.html",
    report_label = "Typed",
    report_key = "typed",
    order = 1,
    report_type = "completely_invalid_type",
    resolved_path = html_path,
    stringsAsFactors = FALSE
  )

  result <- check_report_type_detection(reports_df, new_error_log())
  errors <- result[result$Severity == "Error", ]
  expect_true(nrow(errors) > 0)
  expect_true(any(grepl("Invalid Report Type", errors$Issue)))

  unlink(html_path)
})


# --- 11. validate_report_hub_preflight orchestrator ---

test_that("validate_report_hub_preflight runs on valid config", {
  skip_if(!exists("validate_report_hub_preflight", mode = "function"),
          "validate_report_hub_preflight not available")

  tmp <- tempdir()
  html1 <- file.path(tmp, "hub_r1.html")
  html2 <- file.path(tmp, "hub_r2.html")
  create_html_file(html1)
  create_html_file(html2)

  config_file <- file.path(tmp, "hub_config.xlsx")
  writeLines("placeholder", config_file)

  config <- list(
    reports = list(
      list(path = html1, label = "Report 1", key = "r1", order = 1, type = "tabs"),
      list(path = html2, label = "Report 2", key = "r2", order = 2, type = "tracker")
    ),
    settings = list(
      brand_colour = "#323367",
      accent_colour = "#2aa198",
      output_dir = tmp
    )
  )

  result <- validate_report_hub_preflight(config, config_file)
  expect_true(is.data.frame(result))

  unlink(c(html1, html2, config_file))
})

test_that("validate_report_hub_preflight detects issues in bad config", {
  skip_if(!exists("validate_report_hub_preflight", mode = "function"),
          "validate_report_hub_preflight not available")

  tmp <- tempdir()
  config_file <- file.path(tmp, "bad_hub_config.xlsx")
  writeLines("placeholder", config_file)

  config <- list(
    reports = list(
      list(path = "/nonexistent/report.html", label = "Bad Report",
           key = "123bad", order = 1, type = "invalid_type"),
      list(path = "/nonexistent/report.html", label = "Duplicate Path",
           key = "123bad", order = 1, type = NA)
    ),
    settings = list(
      brand_colour = "not-hex",
      accent_colour = "#323367"
    )
  )

  result <- validate_report_hub_preflight(config, config_file)
  expect_true(is.data.frame(result))
  expect_true(nrow(result) > 0)

  unlink(config_file)
})
