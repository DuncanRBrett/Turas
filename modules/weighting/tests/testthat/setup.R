# ==============================================================================
# TEST SETUP - Weighting Module
# ==============================================================================
# Loads shared infrastructure and weighting module libraries for testing.
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
MODULE_DIR <- file.path(TURAS_ROOT, "modules", "weighting")

# Load shared infrastructure - source individual files with absolute paths
# (import_all.R has issues with ofile resolution in testthat context)
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

# Source weighting module libraries
lib_files <- c(
  "lib/00_guard.R", "lib/validation.R", "lib/config_loader.R",
  "lib/design_weights.R", "lib/rim_weights.R", "lib/trimming.R",
  "lib/diagnostics.R", "lib/output.R"
)
for (f in lib_files) {
  fp <- file.path(MODULE_DIR, f)
  if (file.exists(fp)) source(fp, local = FALSE)
}

# Source cell_weights if it exists
cell_path <- file.path(MODULE_DIR, "lib", "cell_weights.R")
if (file.exists(cell_path)) source(cell_path, local = FALSE)

# Source HTML report submodules if they exist
html_report_dir <- file.path(MODULE_DIR, "lib", "html_report")
if (dir.exists(html_report_dir)) {
  assign(".weighting_html_report_dir", html_report_dir, envir = .GlobalEnv)
  assign(".weighting_lib_dir", file.path(MODULE_DIR, "lib"), envir = .GlobalEnv)
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
  # Mark submodules as loaded (setup.R sourced them individually above)
  assign(".whr_submodules_loaded", TRUE, envir = .GlobalEnv)
}

# Set launcher flag in global env so CLI code in run_weighting.R doesn't trigger quit()
assign("TURAS_LAUNCHER_ACTIVE", TRUE, envir = .GlobalEnv)

# Set module directory for get_module_dir() to find in test context
assign("WEIGHTING_MODULE_DIR", MODULE_DIR, envir = .GlobalEnv)

# Source the main run_weighting.R to get run_weighting(), quick_design_weight(), etc.
source(file.path(MODULE_DIR, "run_weighting.R"), local = FALSE)

# Source test data generators
fixture_dir <- file.path(MODULE_DIR, "tests", "fixtures", "synthetic_data")
source(file.path(fixture_dir, "generate_test_data.R"), local = FALSE)
