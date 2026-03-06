# ==============================================================================
# TURAS WEIGHTING MODULE - Test Runner
# ==============================================================================
# Run with: Rscript modules/weighting/tests/testthat.R
# Or use:   testthat::test_dir("modules/weighting/tests")
# ==============================================================================

library(testthat)

# Determine the testthat directory (adjacent to this file)
test_dir <- file.path(dirname(normalizePath(sys.frame(1)$ofile %||% ".")),
                       "testthat")

# Fallback if run from Turas root
if (!dir.exists(test_dir)) {
  test_dir <- "modules/weighting/tests/testthat"
}

testthat::test_dir(test_dir, reporter = "summary")
