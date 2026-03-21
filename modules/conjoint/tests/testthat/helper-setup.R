# ==============================================================================
# CONJOINT TEST SETUP
# ==============================================================================
# Source module files, shared utilities, and fixture generators so all
# functions are available to test files. testthat loads helper-*.R
# files automatically before running tests.
# ==============================================================================

find_turas_root <- function() {
  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "launch_turas.R"))) return(current)
    current <- dirname(current)
  }
  stop("Cannot locate Turas root")
}

turas_root <- find_turas_root()
module_root <- file.path(turas_root, "modules", "conjoint")

# Source shared utilities (TRS refusal etc.)
shared_libs <- sort(list.files(file.path(turas_root, "modules", "shared", "lib"),
                               pattern = "[.]R$", full.names = TRUE))
for (f in shared_libs) {
  tryCatch(source(f), error = function(e) NULL)
}

# Source conjoint module R files in order
r_files <- sort(list.files(file.path(module_root, "R"), pattern = "[.]R$", full.names = TRUE))
for (f in r_files) {
  tryCatch(source(f), error = function(e) NULL)
}

# Source fixture data generators
fixture_path <- file.path(module_root, "tests", "fixtures", "synthetic_data",
                          "generate_conjoint_test_data.R")
if (file.exists(fixture_path)) {
  tryCatch(source(fixture_path), error = function(e) {
    message("helper-setup: could not source fixture generator: ", e$message)
  })
}

# Load survival package if available (needed for strata() in clogit formulas)
if (requireNamespace("survival", quietly = TRUE)) {
  library(survival)
}
