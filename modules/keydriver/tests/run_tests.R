# ==============================================================================
# KEYDRIVER MODULE - TEST RUNNER
# ==============================================================================
#
# Run all keydriver module tests using testthat.
#
# Usage:
#   source("modules/keydriver/tests/run_tests.R")
#
# Or from project root:
#   testthat::test_dir("modules/keydriver/tests")
#
# ==============================================================================

# Determine paths
test_dir <- if (exists("script_dir_override", envir = globalenv())) {
  file.path(get("script_dir_override", envir = globalenv()), "tests")
} else {
  dirname(sys.frame(1)$ofile %||% ".")
}

module_dir <- dirname(test_dir)
project_root <- file.path(module_dir, "..", "..")

# Source test data generators
source(file.path(test_dir, "fixtures", "generate_test_data.R"))

# Source shared TRS infrastructure (must be loaded before module files)
shared_lib <- file.path(project_root, "modules", "shared", "lib")
source(file.path(shared_lib, "trs_refusal.R"))
source(file.path(shared_lib, "trs_run_state.R"))
source(file.path(shared_lib, "trs_banner.R"))
source(file.path(shared_lib, "trs_run_status_writer.R"))

# Source module files
source(file.path(module_dir, "R", "00_guard.R"))
source(file.path(module_dir, "R", "01_config.R"))
source(file.path(module_dir, "R", "02_term_mapping.R"))
source(file.path(module_dir, "R", "02_validation.R"))
source(file.path(module_dir, "R", "03_analysis.R"))
source(file.path(module_dir, "R", "04_output.R"))
source(file.path(module_dir, "R", "05_bootstrap.R"))
source(file.path(module_dir, "R", "06_effect_size.R"))
source(file.path(module_dir, "R", "07_segment_comparison.R"))
source(file.path(module_dir, "R", "08_executive_summary.R"))

# Run tests
if (requireNamespace("testthat", quietly = TRUE)) {
  cat("\n")
  cat(paste(rep("=", 60), collapse = ""), "\n")
  cat("  KEYDRIVER MODULE - TEST SUITE\n")
  cat(paste(rep("=", 60), collapse = ""), "\n\n")

  results <- testthat::test_dir(
    file.path(test_dir, "testthat"),
    reporter = testthat::SummaryReporter$new()
  )

  cat("\n")
  cat(paste(rep("=", 60), collapse = ""), "\n\n")
} else {
  cat("[ERROR] testthat package is required to run tests.\n")
  cat("Install with: install.packages('testthat')\n")
}
