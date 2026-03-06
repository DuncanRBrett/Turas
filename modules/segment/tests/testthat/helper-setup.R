# ==============================================================================
# SEGMENT MODULE - TEST HELPER (auto-sourced by testthat)
# ==============================================================================
# This file is automatically sourced by testthat before running tests.
# It:
#   1. Sets TURAS_ROOT so source paths resolve correctly
#   2. Sources the segment module (00_main.R) to load all functions
#   3. Sources the test data generator from fixtures/
# ==============================================================================

# --- Step 1: Set TURAS_ROOT ---
# Navigate up from testthat/ -> tests/ -> segment/ -> modules/ -> Turas root
if (Sys.getenv("TURAS_ROOT") == "") {
  candidate <- normalizePath(
    file.path(testthat::test_path(), "..", "..", "..", ".."),
    mustWork = FALSE
  )
  if (file.exists(file.path(candidate, "launch_turas.R"))) {
    Sys.setenv(TURAS_ROOT = candidate)
  } else {
    # Fallback: walk up from working directory
    candidate <- getwd()
    while (candidate != dirname(candidate)) {
      if (file.exists(file.path(candidate, "launch_turas.R"))) {
        Sys.setenv(TURAS_ROOT = candidate)
        break
      }
      candidate <- dirname(candidate)
    }
  }
}

turas_root <- Sys.getenv("TURAS_ROOT")

# --- Step 2: Source the segment module ---
main_file <- file.path(turas_root, "modules", "segment", "R", "00_main.R")
if (file.exists(main_file)) {
  source(main_file, local = FALSE)
} else {
  warning(
    "Could not find segment module at: ", main_file, ". ",
    "Tests requiring module functions will fail."
  )
}

# --- Step 3: Source test data generator ---
fixture_file <- file.path(
  testthat::test_path(), "..", "fixtures", "generate_test_data.R"
)
fixture_file <- normalizePath(fixture_file, mustWork = FALSE)

if (file.exists(fixture_file)) {
  source(fixture_file, local = FALSE)
} else {
  warning(
    "Could not find generate_test_data.R fixture at: ", fixture_file, ". ",
    "Tests requiring generate_segment_test_data() will fail."
  )
}
