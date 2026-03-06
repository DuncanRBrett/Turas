# ==============================================================================
# SEGMENT MODULE - TEST HELPER (auto-sourced by testthat)
# ==============================================================================
# This file is automatically sourced by testthat before running tests.
# It sources the test data generator from fixtures/ so that
# generate_segment_test_data() and generate_test_config() are available
# in all test files.
# ==============================================================================

# testthat::test_path() returns the path to the testthat/ directory.
# The fixture file is at ../fixtures/generate_test_data.R relative to testthat/
fixture_file <- file.path(
  testthat::test_path(), "..", "fixtures", "generate_test_data.R"
)

# Normalize the path for cleaner display
fixture_file <- normalizePath(fixture_file, mustWork = FALSE)

if (file.exists(fixture_file)) {
  source(fixture_file, local = FALSE)
} else {
  warning(
    "Could not find generate_test_data.R fixture at: ", fixture_file, ". ",
    "Tests requiring generate_segment_test_data() will fail."
  )
}
