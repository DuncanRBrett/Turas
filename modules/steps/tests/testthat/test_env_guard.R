# ==============================================================================
# TESTS - Environment guard
# ==============================================================================
# The guard is checked with injected which/probe functions so the refusal paths
# are exercised on any machine, including one that does have python3.

test_that("a runtime that is not on PATH refuses with PKG_RUNTIME_MISSING", {
  m <- test_manifest(runtime = "python3", requires = c("openpyxl"))
  res <- steps_check_env(m, which_fn = function(x) "")
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "PKG_RUNTIME_MISSING")
  expect_true(grepl("python3", res$message, fixed = TRUE))
})

test_that("Sys.which returning NA is treated as not found", {
  m <- test_manifest(runtime = "python3")
  res <- steps_check_env(m, which_fn = function(x) NA_character_)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "PKG_RUNTIME_MISSING")
})

test_that("a missing module refuses and names it, with the pip fix", {
  m <- test_manifest(runtime = "python3", requires = c("openpyxl", "pandas"))
  res <- steps_check_env(
    m,
    which_fn = function(x) "/usr/bin/python3",
    probe_fn = function(runtime, args) if (grepl("pandas", args[2])) 1L else 0L
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "PKG_RUNTIME_MISSING")
  expect_true(grepl("pandas", res$message, fixed = TRUE))
  expect_false(grepl("openpyxl", res$message, fixed = TRUE))
  expect_true(any(grepl("scripts/requirements.txt", res$how_to_fix, fixed = TRUE)))
})

test_that("all modules importable passes and reports the binary", {
  m <- test_manifest(runtime = "python3", requires = c("openpyxl", "pandas"))
  res <- steps_check_env(
    m,
    which_fn = function(x) "/usr/bin/python3",
    probe_fn = function(runtime, args) 0L
  )
  expect_equal(res$status, "PASS")
  expect_equal(res$runtime_path, "/usr/bin/python3")
})

test_that("a probe that errors counts as missing rather than crashing", {
  m <- test_manifest(runtime = "python3", requires = c("openpyxl"))
  res <- steps_check_env(
    m,
    which_fn = function(x) "/usr/bin/python3",
    probe_fn = function(runtime, args) stop("boom")
  )
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "PKG_RUNTIME_MISSING")
})

test_that("the import probe is runtime-appropriate", {
  expect_equal(.steps_import_probe("python3", "openpyxl"), c("-c", "import openpyxl"))
  expect_equal(.steps_import_probe("/usr/bin/python3.11", "pandas"), c("-c", "import pandas"))
  expect_equal(.steps_import_probe("Rscript", "openxlsx"), c("-e", "library(openxlsx)"))
  expect_null(.steps_import_probe("some_other_binary", "thing"))
})

test_that("a runtime with no known import probe skips module checks", {
  m <- test_manifest(runtime = "some_other_binary", requires = c("nonsense"))
  res <- steps_check_env(m, which_fn = function(x) "/usr/local/bin/some_other_binary")
  expect_equal(res$status, "PASS")
})

test_that("the real environment guard agrees with a direct import check", {
  # Not skipped: it asserts the guard's verdict matches reality either way.
  m <- steps_find_tool("comment_appendix_build")
  res <- steps_check_env(m)
  direct_ok <- nzchar(Sys.which("python3")) &&
    suppressWarnings(system2("python3",
      shQuote(c("-c", "import openpyxl, pandas")),
      stdout = FALSE, stderr = FALSE)) == 0L
  expect_equal(res$status == "PASS", direct_ok)
})
