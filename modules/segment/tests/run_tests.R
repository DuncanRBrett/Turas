# ==============================================================================
# SEGMENT MODULE - TEST RUNNER
# ==============================================================================
# Sources all module files and runs testthat tests.
#
# Usage:
#   Rscript modules/segment/tests/run_tests.R
#   # or from R console:
#   source("modules/segment/tests/run_tests.R")
# ==============================================================================

# Set TURAS_ROOT if not already set
if (Sys.getenv("TURAS_ROOT") == "") {
  # Try to find the root
  candidate <- getwd()
  while (candidate != dirname(candidate)) {
    if (file.exists(file.path(candidate, "launch_turas.R"))) {
      Sys.setenv(TURAS_ROOT = candidate)
      break
    }
    candidate <- dirname(candidate)
  }
  if (Sys.getenv("TURAS_ROOT") == "") {
    Sys.setenv(TURAS_ROOT = getwd())
  }
}

turas_root <- Sys.getenv("TURAS_ROOT")
cat(sprintf("[TEST] TURAS_ROOT = %s\n", turas_root))

# Source the module (which sources all dependencies)
source(file.path(turas_root, "modules/segment/R/00_main.R"))

# Source test data generator
source(file.path(turas_root, "modules/segment/tests/fixtures/generate_test_data.R"))

# Run tests
cat("\n[TEST] Running segment module tests...\n\n")

test_dir <- file.path(turas_root, "modules/segment/tests/testthat")

if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("testthat package required for running tests")
}

results <- testthat::test_dir(test_dir, reporter = "summary")

# Print summary
cat(sprintf("\n[TEST] Tests complete: %d passed, %d failed, %d skipped\n",
            sum(results$passed), sum(results$failed), sum(results$skipped)))

invisible(results)
