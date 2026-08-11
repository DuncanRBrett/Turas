# ==============================================================================
# TURAS STEPS MODULE - Test Runner
# ==============================================================================
# Run with: Rscript modules/steps/tests/testthat.R
# Or use:   testthat::test_dir("modules/steps/tests/testthat")
# ==============================================================================

library(testthat)

test_dir_path <- "modules/steps/tests/testthat"
if (!dir.exists(test_dir_path)) {
  # Running from inside the module's tests directory
  test_dir_path <- file.path(getwd(), "testthat")
}

testthat::test_dir(test_dir_path, reporter = "summary")
