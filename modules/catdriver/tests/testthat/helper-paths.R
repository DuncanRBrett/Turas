# ==============================================================================
# CATDRIVER TEST HELPER: Path Resolution
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
  if (nzchar(turas_root) && dir.exists(file.path(turas_root, "modules", "catdriver"))) {
    return(normalizePath(file.path(turas_root, "modules", "catdriver"), mustWork = FALSE))
  }

  # 2. Try testthat::test_path() (works inside test_dir and test_file contexts)
  tp <- tryCatch(testthat::test_path(), error = function(e) NULL)
  if (!is.null(tp) && nzchar(tp) && tp != ".") {
    candidate <- normalizePath(file.path(tp, "..", ".."), mustWork = FALSE)
    if (dir.exists(file.path(candidate, "R"))) return(candidate)
  }

  # 3. Walk up from working directory
  wd <- getwd()
  if (grepl("catdriver", wd)) {
    candidate <- normalizePath(sub("/tests.*$", "", wd), mustWork = FALSE)
    if (dir.exists(file.path(candidate, "R"))) return(candidate)
  }

  # 4. Try relative to working directory (project root)
  if (dir.exists(file.path(wd, "modules", "catdriver"))) {
    return(normalizePath(file.path(wd, "modules", "catdriver"), mustWork = FALSE))
  }

  # 5. Last resort
  normalizePath(".", mustWork = FALSE)
}

# These variables match the names used by all catdriver test files
module_root <- .find_module_dir()
turas_root <- normalizePath(file.path(module_root, "..", ".."), mustWork = FALSE)
