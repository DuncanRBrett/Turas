# ==============================================================================
# KEYDRIVER TEST HELPER: Path Resolution
# ==============================================================================
# Automatically sourced by testthat before each test file.
# Provides robust module/project root resolution that works with:
#   - testthat::test_dir()
#   - testthat::test_file()
#   - source("tools/run_all_tests.R")
#   - direct Rscript execution
# ==============================================================================

.find_module_dir <- function() {
  # 1. Try TURAS_ROOT env var (set by test runner and launcher)
  turas_root <- Sys.getenv("TURAS_ROOT", "")
  if (nzchar(turas_root) && dir.exists(file.path(turas_root, "modules", "keydriver"))) {
    return(normalizePath(file.path(turas_root, "modules", "keydriver"), mustWork = FALSE))
  }

  # 2. Try testthat::test_path() (works inside test_dir and test_file contexts)
  tp <- tryCatch(testthat::test_path(), error = function(e) NULL)
  if (!is.null(tp) && nzchar(tp) && tp != ".") {
    candidate <- normalizePath(file.path(tp, "..", ".."), mustWork = FALSE)
    if (dir.exists(file.path(candidate, "R"))) return(candidate)
  }

  # 3. Walk up from working directory
  wd <- getwd()
  if (grepl("keydriver", wd)) {
    candidate <- normalizePath(sub("/tests.*$", "", wd), mustWork = FALSE)
    if (dir.exists(file.path(candidate, "R"))) return(candidate)
  }

  # 4. Try relative to working directory (project root)
  if (dir.exists(file.path(wd, "modules", "keydriver"))) {
    return(normalizePath(file.path(wd, "modules", "keydriver"), mustWork = FALSE))
  }

  # 5. Last resort
  normalizePath(".", mustWork = FALSE)
}

# These variables match the names used by all keydriver test files
module_dir <- .find_module_dir()
project_root <- normalizePath(file.path(module_dir, "..", ".."), mustWork = FALSE)


# ==============================================================================
# LOADING THE MODULE (review F17)
# ==============================================================================
# Three test files carried a file-level skip_if(!exists(...)). Under test_dir
# an earlier file happened to have sourced the module, so they ran; under
# test_file they reported 0 tests, 0 skipped, 0 failed, which reads as success
# and is how a file full of assertions can quietly test nothing.
#
# Loading is cheap and idempotent, so these files load what they need instead.

#' Source the keydriver module if it is not already loaded
#'
#' @param what Which parts to load: "core", "shap", "quadrant", "methods",
#'   "html" or "all".
#' @return Invisibly TRUE if anything was sourced.
#' @keywords internal
kd_ensure_module_loaded <- function(what = "core") {
  if (exists("run_keydriver_analysis_impl", mode = "function") &&
      exists("calculate_relative_weights", mode = "function")) {
    return(invisible(FALSE))
  }

  Sys.setenv(TURAS_ROOT = project_root)
  assign("TURAS_ROOT", project_root, envir = .GlobalEnv)

  for (f in list.files(file.path(project_root, "modules", "shared", "lib"),
                       pattern = "[.]R$", full.names = TRUE)) {
    tryCatch(source(f), error = function(e) NULL)
  }

  dirs <- c(core = file.path(module_dir, "R"))
  if (what %in% c("shap", "all")) {
    dirs <- c(dirs, shap = file.path(module_dir, "R", "kda_shap"),
              methods = file.path(module_dir, "R", "kda_methods"))
  }
  if (what %in% c("quadrant", "all")) {
    dirs <- c(dirs, quadrant = file.path(module_dir, "R", "kda_quadrant"))
  }
  if (what %in% c("methods", "all")) {
    dirs <- c(dirs, methods2 = file.path(module_dir, "R", "kda_methods"))
  }
  # Deliberately NOT lib/html_report: the pipeline sources that itself with
  # .keydriver_lib_dir set, and sourcing it here makes its guard report every
  # file missing against a working directory of ".".

  for (d in unique(dirs)) {
    if (!dir.exists(d)) next
    for (f in list.files(d, pattern = "[.]R$", full.names = TRUE)) {
      tryCatch(source(f), error = function(e) NULL)
    }
  }
  invisible(TRUE)
}
