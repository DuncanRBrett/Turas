# ==============================================================================
# Tests: Hub App Project Scanner
# ==============================================================================

# Source the scanner
turas_root <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(turas_root)) {
  # Walk up from testthat dir to find project root
  test_dir <- getwd()
  candidate <- normalizePath(file.path(test_dir, "..", "..", "..", ".."), mustWork = FALSE)
  if (file.exists(file.path(candidate, "launch_turas.R"))) {
    turas_root <- candidate
  } else {
    turas_root <- normalizePath(file.path(test_dir, "..", "..", "..", "..", ".."), mustWork = FALSE)
  }
}
source(file.path(turas_root, "modules", "hub_app", "lib", "project_scanner.R"))

# ==============================================================================
# Helpers: Create mock project directories
# ==============================================================================

#' Create a mock project with HTML reports
create_mock_html_project <- function(base_dir, name, report_types = "tabs") {
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

#' Create a mock config file (empty xlsx with a sheet)
create_mock_config <- function(proj_dir, filename, sheets = "Settings") {
  if (!dir.exists(proj_dir)) dir.create(proj_dir, recursive = TRUE)
  wb <- openxlsx::createWorkbook()
  for (s in sheets) {
    openxlsx::addWorksheet(wb, s)
    openxlsx::writeData(wb, s, data.frame(x = 1))
  }
  path <- file.path(proj_dir, filename)
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

#' Create a mock project with config + data + output files
create_mock_full_project <- function(base_dir, name,
                                      config_name = "Crosstab_Config.xlsx",
                                      config_sheets = "Settings",
                                      report_types = "tabs",
                                      data_files = "survey_data.csv",
                                      excel_outputs = "Results.xlsx",
                                      diagnostics = character(0)) {
  proj_dir <- file.path(base_dir, name)
  dir.create(proj_dir, recursive = TRUE, showWarnings = FALSE)

  # Config
  create_mock_config(proj_dir, config_name, config_sheets)

  # HTML reports
  for (rtype in report_types) {
    html_content <- sprintf(
      '<html><head><meta name="turas-report-type" content="%s"><title>%s</title></head><body></body></html>',
      rtype, paste(name, "-", tools::toTitleCase(rtype))
    )
    writeLines(html_content, file.path(proj_dir, paste0(rtype, "_report.html")))
  }

  # Data files
  for (df in data_files) {
    writeLines("col1,col2\n1,2", file.path(proj_dir, df))
  }

  # Excel outputs (in output/ subdir)
  if (length(excel_outputs) > 0) {
    out_dir <- file.path(proj_dir, "output")
    dir.create(out_dir, showWarnings = FALSE)
    for (xf in excel_outputs) {
      wb <- openxlsx::createWorkbook()
      openxlsx::addWorksheet(wb, "Results")
      openxlsx::writeData(wb, "Results", data.frame(result = "test"))
      openxlsx::saveWorkbook(wb, file.path(out_dir, xf), overwrite = TRUE)
    }
  }

  # Diagnostics
  for (dg in diagnostics) {
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Stats")
    openxlsx::writeData(wb, "Stats", data.frame(stat = 1))
    openxlsx::saveWorkbook(wb, file.path(proj_dir, dg), overwrite = TRUE)
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

test_that("scan_for_projects finds a project with HTML reports", {
  tmp <- file.path(tempdir(), "scan_html_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_html_project(tmp, "BrandStudy2026", "tabs")

  result <- scan_for_projects(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)
  expect_equal(result$result$projects[[1]]$folder_name, "BrandStudy2026")
  expect_true(result$result$projects[[1]]$counts$html_reports >= 1)
})

test_that("scan_for_projects finds a project with config files only (no HTML)", {
  tmp <- file.path(tempdir(), "scan_config_only_test")
  proj_dir <- file.path(tmp, "ConfigOnly")
  dir.create(proj_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj_dir, "Crosstab_Config.xlsx", "Settings")

  result <- scan_for_projects(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)
  expect_equal(result$result$projects[[1]]$counts$configs, 1)
})

test_that("scan_for_projects finds multiple projects", {
  tmp <- file.path(tempdir(), "scan_multi_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_html_project(tmp, "ProjectAlpha", c("tabs", "tracker"))
  create_mock_html_project(tmp, "ProjectBeta", "confidence")

  result <- scan_for_projects(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 2)

  names <- sapply(result$result$projects, function(p) p$folder_name)
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

  create_mock_html_project(tmp1, "Root1Project", "tabs")
  create_mock_html_project(tmp2, "Root2Project", "tracker")

  result <- scan_for_projects(c(tmp1, tmp2))
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 2)
})

test_that("scan_for_projects skips non-Turas directories", {
  tmp <- file.path(tempdir(), "scan_skip_test")
  proj <- file.path(tmp, "NotTuras")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  # Plain HTML without meta tag and no config xlsx
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

  create_mock_html_project(tmp, "UniqueProject", "tabs")

  result <- scan_for_projects(c(tmp, tmp))
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)
})

test_that("scan_for_projects skips hidden directories", {
  tmp <- file.path(tempdir(), "scan_hidden_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

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
# Config File Detection (Tier 1)
# ==============================================================================

test_that("Tier 1 detects tabs config by filename pattern", {
  tmp <- file.path(tempdir(), "tier1_tabs_test")
  proj <- file.path(tmp, "TabsProject")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "MyProject_Crosstab_Config.xlsx", "Settings")

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 1)
  expect_true("tabs" %in% result$result$projects[[1]]$modules)
  expect_equal(result$result$projects[[1]]$counts$configs, 1)
})

test_that("Tier 1 detects tracker config by filename pattern", {
  tmp <- file.path(tempdir(), "tier1_tracker_test")
  proj <- file.path(tmp, "TrackerProject")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "tracking_config.xlsx", "Settings")

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 1)
  expect_true("tracker" %in% result$result$projects[[1]]$modules)
})

test_that("Tier 1 detects maxdiff config by filename pattern", {
  tmp <- file.path(tempdir(), "tier1_maxdiff_test")
  proj <- file.path(tmp, "MaxDiffProject")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "Demo_MaxDiff_Config.xlsx", "Settings")

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 1)
  expect_true("maxdiff" %in% result$result$projects[[1]]$modules)
})

test_that("Tier 1 detects multiple module configs in one project", {
  tmp <- file.path(tempdir(), "tier1_multi_module")
  proj <- file.path(tmp, "MultiModule")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "Tabs_Config.xlsx", "Settings")
  create_mock_config(proj, "keydriver_config.xlsx", "Settings")

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 1)
  p <- result$result$projects[[1]]
  expect_true("tabs" %in% p$modules)
  expect_true("keydriver" %in% p$modules)
  expect_equal(p$counts$configs, 2)
})


# ==============================================================================
# Config File Detection (Tier 2 — sheet inspection)
# ==============================================================================

test_that("Tier 2 detects tabs config by sheet names", {
  tmp <- file.path(tempdir(), "tier2_tabs_test")
  proj <- file.path(tmp, "AmbiguousConfig")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  # Generic config name, but tabs-style sheets
  create_mock_config(proj, "MyProject_Config.xlsx",
                      c("Settings", "Questions", "Banners"))

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 1)
  expect_true("tabs" %in% result$result$projects[[1]]$modules)
})

test_that("Tier 2 detects tracker config by sheet names", {
  tmp <- file.path(tempdir(), "tier2_tracker_test")
  proj <- file.path(tmp, "AmbiguousTracker")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "Project_Config.xlsx",
                      c("Settings", "Questions", "Waves"))

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 1)
  expect_true("tracker" %in% result$result$projects[[1]]$modules)
})


# ==============================================================================
# File Categorization
# ==============================================================================

test_that("files are categorized correctly across all categories", {
  tmp <- file.path(tempdir(), "categorize_test")
  on.exit(unlink(tmp, recursive = TRUE))

  proj <- create_mock_full_project(
    tmp, "FullProject",
    config_name = "Tabs_Config.xlsx",
    report_types = "tabs",
    data_files = "survey_data.csv",
    excel_outputs = "Brand_Results.xlsx",
    diagnostics = "Brand_stats_pack.xlsx"
  )

  result <- scan_for_projects(tmp)
  expect_equal(length(result$result$projects), 1)

  p <- result$result$projects[[1]]
  expect_equal(p$counts$configs, 1)
  expect_equal(p$counts$html_reports, 1)
  expect_equal(p$counts$data_files, 1)
  expect_equal(p$counts$diagnostics, 1)
  expect_equal(p$counts$excel_reports, 1)
})

test_that("CSV files are categorized as data files", {
  tmp <- file.path(tempdir(), "csv_data_test")
  proj <- file.path(tmp, "CSVProject")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "Crosstab_Config.xlsx", "Settings")
  writeLines("a,b\n1,2", file.path(proj, "responses.csv"))

  result <- scan_for_projects(tmp)
  p <- result$result$projects[[1]]
  expect_equal(p$counts$data_files, 1)
})

test_that("stats_pack files are categorized as diagnostics", {
  tmp <- file.path(tempdir(), "diag_test")
  proj <- file.path(tmp, "DiagProject")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "Tabs_Config.xlsx", "Settings")

  # Create a diagnostic file
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Stats")
  openxlsx::writeData(wb, "Stats", data.frame(x = 1))
  openxlsx::saveWorkbook(wb, file.path(proj, "CCS_stats_pack.xlsx"),
                          overwrite = TRUE)

  result <- scan_for_projects(tmp)
  p <- result$result$projects[[1]]
  expect_equal(p$counts$diagnostics, 1)
})

test_that("subdirectory files are attributed to parent project", {
  tmp <- file.path(tempdir(), "subdir_test")
  proj <- file.path(tmp, "SubdirProject")
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  create_mock_config(proj, "Tabs_Config.xlsx", "Settings")

  # Put results in output/ subdir
  out_dir <- file.path(proj, "output")
  dir.create(out_dir, showWarnings = FALSE)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Results")
  openxlsx::writeData(wb, "Results", data.frame(x = 1))
  openxlsx::saveWorkbook(wb, file.path(out_dir, "Report_Results.xlsx"),
                          overwrite = TRUE)

  result <- scan_for_projects(tmp)
  p <- result$result$projects[[1]]
  expect_equal(p$counts$excel_reports, 1)
})


# ==============================================================================
# Project Notes
# ==============================================================================

test_that("read_project_note returns empty for nonexistent file", {
  tmp <- file.path(tempdir(), "note_empty_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  expect_equal(read_project_note(tmp), "")
})

test_that("save_project_note and read_project_note roundtrip correctly", {
  tmp <- file.path(tempdir(), "note_roundtrip_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  result <- save_project_note(tmp, "Test note for Q1 study")
  expect_equal(result$status, "PASS")

  note <- read_project_note(tmp)
  expect_equal(note, "Test note for Q1 study")
})

test_that("save_project_note preserves existing fields", {
  tmp <- file.path(tempdir(), "note_preserve_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  # Write initial data with extra field
  jsonlite::write_json(
    list(note = "old", custom = "keep me"),
    file.path(tmp, ".turas_project.json"),
    auto_unbox = TRUE
  )

  save_project_note(tmp, "new note")

  data <- jsonlite::fromJSON(
    file.path(tmp, ".turas_project.json"),
    simplifyVector = FALSE
  )
  expect_equal(data$note, "new note")
  expect_equal(data$custom, "keep me")
  expect_true(!is.null(data$updated))
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

  create_mock_html_project(file.path(tmp, ".."), "get_reports_test",
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

  expect_equal(id1, id2)
  expect_false(id1 == id3)
  expect_equal(nchar(id1), 8)
})

test_that("full_display_path does not truncate long paths", {
  home <- Sys.getenv("HOME", path.expand("~"))
  long_path <- file.path(home, "Documents", "very", "deeply",
                           "nested", "directory", "structure")
  result <- full_display_path(long_path)

  # Should start with ~ and contain the full structure
  expect_true(grepl("^~", result))
  expect_true(grepl("structure$", result))
  # Should NOT be truncated with "..."
  expect_false(grepl("\\.\\.\\.", result))
})

test_that("clean_folder_name handles underscored names", {
  expect_equal(clean_folder_name("brand_health_q1"), "Brand Health Q1")
  expect_equal(clean_folder_name("2026-03-25"), "2026-03-25")
  expect_equal(clean_folder_name(""), "Untitled Project")
})

test_that("get_config_patterns covers all expected modules", {
  patterns <- get_config_patterns()
  expected_modules <- c("tabs", "tracker", "maxdiff", "conjoint", "segment",
                          "pricing", "keydriver", "catdriver", "confidence",
                          "weighting", "report_hub")
  expect_true(all(expected_modules %in% names(patterns)))
})
