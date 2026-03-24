# ==============================================================================
# Tests: Hub App Integration Tests
# ==============================================================================
# End-to-end tests that exercise the full flow:
#   guard → scan → report listing → export
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules", "hub_app", "00_guard.R"))
source(file.path(turas_root, "modules", "hub_app", "lib", "project_scanner.R"))
source(file.path(turas_root, "modules", "hub_app", "lib", "export_pptx.R"))
source(file.path(turas_root, "modules", "hub_app", "tests", "fixtures",
                  "synthetic_data", "generate_test_data.R"))

# ==============================================================================
# Full Flow: Guard → Scan → Reports → Export
# ==============================================================================

test_that("full flow: guard validates, scanner finds projects, reports listed", {
  # Set up mock project tree
  root <- file.path(tempdir(), "integration_full_flow")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  create_mock_project(root, "Alpha", c("tabs", "tracker"))
  create_mock_project(root, "Beta", c("confidence", "maxdiff"))

  # Step 1: Guard validates the root directory
  guard_result <- guard_hub_app(project_dirs = root)
  expect_equal(guard_result$status, "PASS")

  validated_dirs <- guard_result$result$project_dirs
  expect_equal(length(validated_dirs), 1)

  # Step 2: Scanner finds projects
  scan_result <- scan_for_projects(validated_dirs, max_depth = 2)
  expect_equal(scan_result$status, "PASS")
  expect_equal(length(scan_result$result$projects), 2)

  project_names <- sapply(scan_result$result$projects, function(p) p$folder_name)
  expect_true("Alpha" %in% project_names)
  expect_true("Beta" %in% project_names)

  # Step 3: Get reports for a specific project
  alpha <- scan_result$result$projects[[
    which(project_names == "Alpha")
  ]]
  reports_result <- get_project_reports(alpha$path)
  expect_equal(reports_result$status, "PASS")
  expect_equal(reports_result$result$report_count, 2)

  report_types <- sapply(reports_result$result$reports, function(r) r$type)
  expect_true("tabs" %in% report_types)
  expect_true("tracker" %in% report_types)
})

test_that("full flow: scan with pins sidecar loads correctly", {
  root <- file.path(tempdir(), "integration_pins_flow")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  proj_path <- create_mock_project(root, "PinnedProject", "tabs",
                                    add_pins = TRUE)

  # Verify sidecar exists
  sidecar_path <- file.path(proj_path, ".turas_pins.json")
  expect_true(file.exists(sidecar_path))

  # Read and validate sidecar content
  pin_data <- jsonlite::fromJSON(sidecar_path, simplifyVector = FALSE)
  expect_equal(pin_data$version, 1)
  expect_equal(length(pin_data$pins), 1)
  expect_equal(pin_data$pins[[1]]$id, "pin-test-001")
  expect_equal(length(pin_data$sections), 1)
})

test_that("full flow: export from scanned project data", {
  skip_if_not_installed("officer")
  skip_if_not_installed("base64enc")

  root <- file.path(tempdir(), "integration_export_flow")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  # Create project
  proj_path <- create_mock_project(root, "ExportProject", "tabs")

  # Scan
  scan_result <- scan_for_projects(root, max_depth = 2)
  expect_equal(scan_result$status, "PASS")

  project <- scan_result$result$projects[[1]]
  expect_equal(project$folder_name, "ExportProject")

  # Create mock export items (simulating what the frontend sends)
  items <- create_mock_export_items(n_pins = 3, n_sections = 1)

  # Export
  result <- export_pins_to_pptx(
    items = items,
    project_name = project$name,
    output_dir = proj_path
  )

  expect_equal(result$status, "PASS")
  expect_true(file.exists(result$result$path))
  expect_equal(result$result$pin_count, 3)
  expect_equal(result$result$section_count, 1)

  # Verify the file is in the project directory
  expect_true(startsWith(
    normalizePath(result$result$path, winslash = "/"),
    normalizePath(proj_path, winslash = "/")
  ))
})

# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("scanner handles deeply nested project structure", {
  root <- file.path(tempdir(), "integration_deep_test")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  # Create project 3 levels deep
  deep_path <- file.path(root, "level1", "level2", "level3")
  create_mock_project(file.path(root, "level1", "level2"), "level3", "tabs")

  # max_depth = 3 should find it
  result <- scan_for_projects(root, max_depth = 3)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)

  # max_depth = 1 should not find it
  result_shallow <- scan_for_projects(root, max_depth = 1)
  expect_equal(length(result_shallow$result$projects), 0)
})

test_that("scanner ignores non-Turas HTML alongside Turas reports", {
  root <- file.path(tempdir(), "integration_mixed_html")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  proj_path <- create_mock_project(root, "MixedProject", "tabs")
  create_non_turas_html(proj_path, "random_notes.html")

  result <- scan_for_projects(root, max_depth = 2)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)

  # Project should list 1 Turas report, even though 2 HTML files exist
  project <- result$result$projects[[1]]
  expect_equal(project$report_count, 1)
  expect_equal(project$total_html_count, 2)
})

test_that("scanner handles project with hub config but no reports", {
  root <- file.path(tempdir(), "integration_config_only")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  # Create project dir with only a config file and a non-turas HTML
  proj_dir <- file.path(root, "ConfigOnly")
  dir.create(proj_dir, showWarnings = FALSE)
  writeLines("placeholder",
    file.path(proj_dir, "ConfigOnly_Report_Hub_Config.xlsx"))
  writeLines("<html><body>Not turas</body></html>",
    file.path(proj_dir, "index.html"))

  result <- scan_for_projects(root, max_depth = 2)
  expect_equal(result$status, "PASS")

  # Should find it because it has a hub config
  expect_equal(length(result$result$projects), 1)
  expect_true(result$result$projects[[1]]$has_hub_config)
})

test_that("guard + scanner work together with mixed valid/invalid dirs", {
  root1 <- file.path(tempdir(), "integration_mixed_dirs_valid")
  dir.create(root1, showWarnings = FALSE)
  on.exit(unlink(root1, recursive = TRUE))

  create_mock_project(root1, "GoodProject", "tabs")

  # Guard with one valid and one invalid dir
  guard_result <- guard_hub_app(c(root1, "/nonexistent/abc123"))
  expect_equal(guard_result$status, "PARTIAL")
  expect_equal(length(guard_result$result$project_dirs), 1)

  # Scanner still finds the project from valid dirs
  scan_result <- scan_for_projects(guard_result$result$project_dirs)
  expect_equal(scan_result$status, "PASS")
  expect_equal(length(scan_result$result$projects), 1)
})

# ==============================================================================
# Multi-Module Projects
# ==============================================================================

test_that("scanner correctly identifies multi-module projects", {
  root <- file.path(tempdir(), "integration_multi_module")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  create_mock_project(root, "FullStudy",
    c("tabs", "tracker", "confidence", "maxdiff", "conjoint",
      "keydriver", "catdriver", "segment"))

  result <- scan_for_projects(root, max_depth = 2)
  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$projects), 1)

  project <- result$result$projects[[1]]
  expect_equal(project$report_count, 8)
  expect_equal(project$total_html_count, 8)

  # Verify all types detected
  types <- sapply(project$reports, function(r) r$type)
  expect_true("tabs" %in% types)
  expect_true("tracker" %in% types)
  expect_true("conjoint" %in% types)
  expect_true("segment" %in% types)
})
