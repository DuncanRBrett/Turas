# ==============================================================================
# Tests: Hub App Hub Generator
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", "")
if (!nzchar(turas_root)) {
  test_dir <- getwd()
  candidate <- normalizePath(file.path(test_dir, "..", "..", "..", ".."), mustWork = FALSE)
  if (file.exists(file.path(candidate, "launch_turas.R"))) {
    turas_root <- candidate
  } else {
    candidate <- normalizePath(file.path(test_dir, "..", "..", "..", "..", ".."), mustWork = FALSE)
    if (file.exists(file.path(candidate, "launch_turas.R"))) {
      turas_root <- candidate
    } else {
      turas_root <- getwd()
    }
  }
  # Set env var so generate_hub_from_project() can find module files
  Sys.setenv(TURAS_ROOT = turas_root)
}
source(file.path(turas_root, "modules", "hub_app", "lib", "hub_generator.R"))
source(file.path(turas_root, "modules", "hub_app", "tests", "fixtures",
                  "synthetic_data", "generate_test_data.R"))

# ==============================================================================
# generate_hub_from_project() — Guard Tests
# ==============================================================================

test_that("generate_hub_from_project refuses NULL path", {
  result <- generate_hub_from_project(NULL)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_PROJECT_PATH_EMPTY")
})

test_that("generate_hub_from_project refuses empty string path", {
  result <- generate_hub_from_project("")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_PROJECT_PATH_EMPTY")
})

test_that("generate_hub_from_project refuses nonexistent path", {
  result <- generate_hub_from_project("/nonexistent/abc123/xyz")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_PROJECT_NOT_FOUND")
})

test_that("generate_hub_from_project refuses directory with no Turas reports", {
  tmp <- file.path(tempdir(), "hubgen_no_reports")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  # Create directory with a non-Turas HTML file
  writeLines("<html><body>Not Turas</body></html>", file.path(tmp, "index.html"))

  result <- generate_hub_from_project(tmp)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_NO_REPORTS")
})

test_that("generate_hub_from_project refuses empty directory", {
  tmp <- file.path(tempdir(), "hubgen_empty")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  result <- generate_hub_from_project(tmp)
  expect_equal(result$status, "REFUSED")
})

# ==============================================================================
# generate_hub_from_project() — Functional Test
# Note: The actual combine_reports() call requires the full report_hub module
# to be functional. This test verifies the guards and report discovery work.
# Full integration testing requires running the complete pipeline.
# ==============================================================================

test_that("generate_hub_from_project discovers reports correctly", {
  root <- file.path(tempdir(), "hubgen_discovery")
  dir.create(root, showWarnings = FALSE)
  on.exit(unlink(root, recursive = TRUE))

  proj_path <- create_mock_project(root, "DiscoveryTest",
    c("tabs", "tracker", "confidence"))

  # The actual combine_reports() will likely fail on synthetic reports

  # (they don't have real content), but we can at least verify that
  # the function attempts it and doesn't fail at the guard stage.
  result <- generate_hub_from_project(proj_path, project_name = "Test Hub")

  # It should either PASS (if report_hub is fully available) or
  # REFUSED with a combine_reports error (expected for synthetic data)
  expect_true(result$status %in% c("PASS", "PARTIAL", "REFUSED"))

  # If REFUSED, should be a combine_reports error, not a guard error
  if (result$status == "REFUSED") {
    expect_false(result$code %in% c("IO_PROJECT_PATH_EMPTY",
                                      "IO_PROJECT_NOT_FOUND",
                                      "DATA_NO_REPORTS"))
  }
})
