# ==============================================================================
# Tests: Hub App Guard Layer
# ==============================================================================

# Source the guard file
turas_root <- Sys.getenv("TURAS_ROOT", getwd())
source(file.path(turas_root, "modules", "hub_app", "00_guard.R"))

# ==============================================================================
# guard_hub_app()
# ==============================================================================

test_that("guard_hub_app returns PASS for valid directories", {
  # Use temp directory as a known-good path
  tmp <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  result <- guard_hub_app(project_dirs = tmp)

  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$project_dirs), 1)
  expect_true(grepl("1 project directory", result$message))
})

test_that("guard_hub_app returns PASS for multiple valid directories", {
  tmp1 <- tempdir()
  tmp2 <- file.path(tempdir(), "test_guard_dir")
  dir.create(tmp2, showWarnings = FALSE)
  on.exit(unlink(tmp2, recursive = TRUE))

  result <- guard_hub_app(project_dirs = c(tmp1, tmp2))

  expect_equal(result$status, "PASS")
  expect_equal(length(result$result$project_dirs), 2)
  expect_true(grepl("2 project directories", result$message))
})

test_that("guard_hub_app returns REFUSED when no directories are valid", {
  result <- guard_hub_app(project_dirs = c(
    "/nonexistent/path/abc123",
    "/another/fake/path"
  ))

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_NO_VALID_DIRS")
  expect_true(nzchar(result$how_to_fix))
})

test_that("guard_hub_app returns PARTIAL when some directories are invalid", {
  tmp <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  result <- guard_hub_app(project_dirs = c(
    tmp,
    "/nonexistent/path/abc123"
  ))

  expect_equal(result$status, "PARTIAL")
  expect_equal(length(result$result$project_dirs), 1)
  expect_true(length(result$warnings) > 0)
})

test_that("guard_hub_app uses defaults when NULL is passed", {
  result <- guard_hub_app(project_dirs = NULL)

  # Should not be REFUSED (home directories should exist)
  expect_true(result$status %in% c("PASS", "PARTIAL"))
})

test_that("guard_hub_app handles empty strings in directory list", {
  tmp <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  result <- guard_hub_app(project_dirs = c("", "  ", tmp))

  expect_true(result$status %in% c("PASS", "PARTIAL"))
  expect_equal(length(result$result$project_dirs), 1)
})

# ==============================================================================
# guard_project()
# ==============================================================================

test_that("guard_project returns REFUSED for NULL path", {
  result <- guard_project(NULL)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_PROJECT_PATH_EMPTY")
})

test_that("guard_project returns REFUSED for empty string", {
  result <- guard_project("")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_PROJECT_PATH_EMPTY")
})

test_that("guard_project returns REFUSED for nonexistent path", {
  result <- guard_project("/nonexistent/path/abc123")
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_PROJECT_NOT_FOUND")
})

test_that("guard_project returns REFUSED for directory with no HTML files", {
  tmp <- file.path(tempdir(), "empty_project_test")
  dir.create(tmp, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE))

  result <- guard_project(tmp)
  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_NO_REPORTS")
})

test_that("guard_project returns PASS for directory with HTML files", {
  tmp <- file.path(tempdir(), "html_project_test")
  dir.create(tmp, showWarnings = FALSE)
  writeLines("<html><body>test</body></html>", file.path(tmp, "test.html"))
  on.exit(unlink(tmp, recursive = TRUE))

  result <- guard_project(tmp)
  expect_equal(result$status, "PASS")
  expect_equal(result$result$html_count, 1)
})
