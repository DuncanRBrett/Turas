# ==============================================================================
# Tests: Hub App Project Scanner
# ==============================================================================

# Source the scanner
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules", "hub_app", "lib", "project_scanner.R"))

# ==============================================================================
# Helper: Create a mock Turas project directory
# ==============================================================================

create_mock_project <- function(base_dir, name, report_types = "tabs") {
  proj_dir <- file.path(base_dir, name)
  dir.create(proj_dir, recursive = TRUE, showWarnings = FALSE)

  for (rtype in report_types) {
    html_content <- sprintf(
      '<html><head>
        <meta name="turas-report-type" content="%s">
        <title>%s Report - %s</title>
      </head><body><h1>Test Report</h1></body></html>',
      rtype, tools::toTitleCase(rtype), name
    )
    writeLines(html_content, file.path(proj_dir, paste0(rtype, "_report.html")))
  }

  proj_dir
}

# ==============================================================================
# scan_for_projects()
# ==============================================================================

test_that("scan_for_projects returns PASS with empty project list for empty dir", {
  tmp <- file.path(tempdir(), "scan_empty_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  result <- scan_for_projects(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 0)
})

test_that("scan_for_projects finds a single Turas project", {
  tmp <- file.path(tempdir(), "scan_single_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_project(tmp, "BrandStudy2026", "tabs")

  result <- scan_for_projects(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)
  expect_equal(result$result$projects[[1]]$name, "BrandStudy2026")
  expect_equal(result$result$projects[[1]]$report_count, 1)
})

test_that("scan_for_projects finds multiple projects", {
  tmp <- file.path(tempdir(), "scan_multi_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_project(tmp, "ProjectAlpha", c("tabs", "tracker"))
  create_mock_project(tmp, "ProjectBeta", "confidence")

  result <- scan_for_projects(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 2)

  # Check both projects found (order may vary)
  names <- sapply(result$result$projects, function(p) p$name)
  expect_true("ProjectAlpha" %in% names)
  expect_true("ProjectBeta" %in% names)
})

test_that("scan_for_projects handles multiple root directories", {
  tmp1 <- file.path(tempdir(), "scan_root1")
  tmp2 <- file.path(tempdir(), "scan_root2")
  dir.create(tmp1, showWarnings = FALSE)
  dir.create(tmp2, showWarnings = FALSE)
  on.exit({
    unlink(tmp1, recursive = TRUE)
    unlink(tmp2, recursive = TRUE)
  })

  create_mock_project(tmp1, "Root1Project", "tabs")
  create_mock_project(tmp2, "Root2Project", "tracker")

  result <- scan_for_projects(c(tmp1, tmp2))
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 2)
})

test_that("scan_for_projects skips non-Turas HTML files", {
  tmp <- file.path(tempdir(), "scan_skip_test")
  proj <- file.path(tmp, "NotTuras")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  # Create HTML without turas-report-type meta tag
  writeLines("<html><head><title>Not Turas</title></head><body></body></html>",
             file.path(proj, "random.html"))

  result <- scan_for_projects(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 0)
})

test_that("scan_for_projects deduplicates by path", {
  tmp <- file.path(tempdir(), "scan_dedup_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_project(tmp, "UniqueProject", "tabs")

  # Scan the same directory twice
  result <- scan_for_projects(c(tmp, tmp))
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)
})

test_that("scan_for_projects skips hidden directories", {
  tmp <- file.path(tempdir(), "scan_hidden_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  # Create a hidden directory with HTML
  hidden_dir <- file.path(tmp, ".hidden_project")
  dir.create(hidden_dir, showWarnings = FALSE)
  writeLines(
    '<html><head><meta name="turas-report-type" content="tabs"></head><body></body></html>',
    file.path(hidden_dir, "report.html")
  )

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 0)
})

# ==============================================================================
# sniff_report_type()
# ==============================================================================

test_that("sniff_report_type extracts report type from meta tag", {
  tmp <- file.path(tempdir(), "sniff_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  html_path <- file.path(tmp, "tracker_report.html")
  writeLines(
    '<html><head><meta name="turas-report-type" content="tracker"><title>My Tracker</title></head><body></body></html>',
    html_path
  )

  result <- sniff_report_type(html_path)
  expect_false(is.null(result))
  expect_equal(result$type, "tracker")
  expect_equal(result$label, "My Tracker")
  expect_equal(result$filename, "tracker_report.html")
})

test_that("sniff_report_type returns NULL for non-Turas HTML", {
  tmp <- file.path(tempdir(), "sniff_null_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  html_path <- file.path(tmp, "plain.html")
  writeLines("<html><head><title>Not Turas</title></head><body></body></html>",
             html_path)

  result <- sniff_report_type(html_path)
  expect_null(result)
})

test_that("sniff_report_type handles missing title gracefully", {
  tmp <- file.path(tempdir(), "sniff_notitle_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  html_path <- file.path(tmp, "no_title.html")
  writeLines(
    '<html><head><meta name="turas-report-type" content="tabs"></head><body></body></html>',
    html_path
  )

  result <- sniff_report_type(html_path)
  expect_false(is.null(result))
  expect_equal(result$type, "tabs")
  # Should fall back to filename without extension
  expect_equal(result$label, "no_title")
})

# ==============================================================================
# get_project_reports()
# ==============================================================================

test_that("get_project_reports returns REFUSED for nonexistent dir", {
  result <- get_project_reports("/nonexistent/dir/abc123")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_PROJECT_NOT_FOUND")
})

test_that("get_project_reports lists all Turas reports in a project", {
  tmp <- file.path(tempdir(), "get_reports_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_project(file.path(tmp, ".."), "get_reports_test",
                       c("tabs", "tracker", "confidence"))

  result <- get_project_reports(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(result$result$report_count, 3)

  types <- sapply(result$result$reports, function(r) r$type)
  expect_true("tabs" %in% types)
  expect_true("tracker" %in% types)
  expect_true("confidence" %in% types)
})

# ==============================================================================
# Utility functions
# ==============================================================================

test_that("format_file_size produces correct labels", {
  expect_equal(format_file_size(0), "0 B")
  expect_equal(format_file_size(500), "500 B")
  expect_equal(format_file_size(1024), "1.0 KB")
  expect_equal(format_file_size(1536), "1.5 KB")
  expect_equal(format_file_size(1048576), "1.0 MB")
  expect_equal(format_file_size(2.5 * 1024^3), "2.5 GB")
  expect_equal(format_file_size(NA), "0 B")
})

test_that("digest_path produces stable, non-empty output", {
  id1 <- digest_path("/Users/duncan/Projects/BrandHealth")
  id2 <- digest_path("/Users/duncan/Projects/BrandHealth")
  id3 <- digest_path("/Users/duncan/Projects/SomethingElse")

  expect_equal(id1, id2)  # Same path -> same ID
  expect_false(id1 == id3)  # Different path -> different ID
  expect_equal(nchar(id1), 8)  # 8-char hex string
})
