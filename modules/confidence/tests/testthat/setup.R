# ==============================================================================
# TEST SETUP - Confidence Module
# ==============================================================================
# Loads shared infrastructure and confidence module libraries for testing.
# This file is automatically sourced by testthat before any test files.
# ==============================================================================

# Find Turas root
find_turas_root <- function() {
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "shared"))) {
      return(path)
    }
    path <- dirname(path)
  }
  # Fallback: try test_path based resolution
  test_dir <- testthat::test_path()
  path <- test_dir
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "shared"))) {
      return(path)
    }
    path <- dirname(path)
  }
  stop("Cannot find Turas root directory")
}

TURAS_ROOT <- find_turas_root()
MODULE_DIR <- file.path(TURAS_ROOT, "modules", "confidence")

# Load shared infrastructure - source individual files with absolute paths
shared_lib <- file.path(TURAS_ROOT, "modules", "shared", "lib")
shared_files <- c(
  "trs_refusal.R", "console_capture.R", "validation_utils.R",
  "data_utils.R", "config_utils.R", "logging_utils.R",
  "formatting_utils.R", "weights_utils.R", "turas_log.R",
  "trs_run_state.R", "trs_run_status_writer.R", "trs_banner.R",
  "turas_save_workbook_atomic.R", "turas_excel_escape.R"
)
for (f in shared_files) {
  fp <- file.path(shared_lib, f)
  if (file.exists(fp)) {
    tryCatch(source(fp, local = FALSE), error = function(e) {
      message("Note: Could not source ", f, ": ", conditionMessage(e))
    })
  }
}

# Source confidence module R files in dependency order
r_dir <- file.path(MODULE_DIR, "R")
r_files <- c(
  "utils.R", "00_guard.R", "03_study_level.R",
  "04_proportions.R", "05_means.R",
  "question_processor.R", "ci_dispatcher.R",
  "output_helpers.R", "01_load_config.R",
  "02_load_data.R", "07_output.R", "00_main.R"
)
for (f in r_files) {
  fp <- file.path(r_dir, f)
  if (file.exists(fp)) {
    tryCatch(source(fp, local = FALSE), error = function(e) {
      message("Note: Could not source ", f, ": ", conditionMessage(e))
    })
  }
}

# Source HTML report submodules if they exist
html_report_dir <- file.path(MODULE_DIR, "lib", "html_report")
if (dir.exists(html_report_dir)) {
  assign(".confidence_html_report_dir", html_report_dir, envir = .GlobalEnv)
  html_files <- c("00_html_guard.R", "01_data_transformer.R",
                   "02_table_builder.R", "05_chart_builder.R",
                   "03_page_builder.R", "04_html_writer.R")
  for (f in html_files) {
    fp <- file.path(html_report_dir, f)
    if (file.exists(fp)) {
      tryCatch(source(fp, local = FALSE), error = function(e) {
        message("Note: Could not source HTML report file ", f, ": ", conditionMessage(e))
      })
    }
  }
  # Source main orchestrator last
  main_html <- file.path(html_report_dir, "99_html_report_main.R")
  if (file.exists(main_html)) {
    tryCatch(source(main_html, local = FALSE), error = function(e) {
      message("Note: Could not source 99_html_report_main.R: ", conditionMessage(e))
    })
  }
  assign(".chr_submodules_loaded", TRUE, envir = .GlobalEnv)
}

# Set launcher flag so CLI code doesn't trigger quit()
assign("TURAS_LAUNCHER_ACTIVE", TRUE, envir = .GlobalEnv)

# Source test data generators if available
fixture_dir <- file.path(MODULE_DIR, "tests", "fixtures", "synthetic_data")
gen_file <- file.path(fixture_dir, "generate_test_data.R")
if (file.exists(gen_file)) {
  tryCatch(source(gen_file, local = FALSE), error = function(e) {
    message("Note: Could not source generate_test_data.R: ", conditionMessage(e))
  })
}
