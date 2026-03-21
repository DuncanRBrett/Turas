# ==============================================================================
# ROOT TEST SETUP
# ==============================================================================
# Source shared library files so functions like turas_refuse() are available
# to all test files. testthat loads helper-*.R files automatically.
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

# Source TRS refusal infrastructure first (required by validation/config utils)
source(file.path(turas_root, "modules", "shared", "lib", "trs_refusal.R"))

# Source other shared libraries that tests depend on
shared_libs <- c("data_utils.R", "validation_utils.R", "config_utils.R",
                 "formatting_utils.R", "weights_utils.R")
for (lib in shared_libs) {
  lib_path <- file.path(turas_root, "modules", "shared", "lib", lib)
  if (file.exists(lib_path)) {
    tryCatch(source(lib_path), error = function(e) {
      message("helper-setup: could not source ", lib, ": ", e$message)
    })
  }
}
