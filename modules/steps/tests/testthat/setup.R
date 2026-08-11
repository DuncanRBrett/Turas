# ==============================================================================
# TEST SETUP - Steps Module
# ==============================================================================
# Sources the (Shiny-free) Steps libraries so the suite can exercise manifest
# validation, command construction, the environment guard and process handling
# without launching a GUI.
# ==============================================================================

find_turas_root <- function() {
  path <- getwd()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "steps"))) return(path)
    path <- dirname(path)
  }
  path <- testthat::test_path()
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "steps"))) return(path)
    path <- dirname(path)
  }
  stop("Cannot find Turas root directory")
}

TURAS_ROOT <- find_turas_root()
MODULE_DIR <- file.path(TURAS_ROOT, "modules", "steps")

source(file.path(MODULE_DIR, "lib", "registry.R"), local = FALSE)
source(file.path(MODULE_DIR, "lib", "run_tool.R"), local = FALSE)
source(file.path(MODULE_DIR, "lib", "runbook.R"), local = FALSE)


# ---- shared test helpers -----------------------------------------------------

#' A minimal valid manifest, cheap to mutate in validation tests
#'
#' Named arguments REPLACE the corresponding field wholesale. (modifyList()
#' would recurse into the args list and, since arg descriptors are unnamed,
#' silently leave it unchanged.)
test_manifest <- function(...) {
  base <- list(
    id          = "probe_tool",
    name        = "Probe tool",
    description = "A tool used only by the test suite",
    runtime     = "Rscript",
    entry       = "probe.R",
    requires    = character(0),
    args = list(
      list(id = "input", label = "Input file", type = "file",
           required = TRUE, must_exist = TRUE, cli = "--input")
    )
  )
  overrides <- list(...)
  for (nm in names(overrides)) base[[nm]] <- overrides[[nm]]
  base
}

#' Write an R script into `dir` and return a manifest pointing at it.
#'
#' Lets the process tests exercise start/drain/finish with the runtime that is
#' guaranteed present (the one running the suite), independent of python3.
write_probe_tool <- function(dir, body, args = list()) {
  writeLines(body, file.path(dir, "probe.R"))
  test_manifest(args = args)
}

#' Skip unless openxlsx is installed (it writes and reads every runbook)
skip_unless_xlsx <- function() testthat::skip_if_not_installed("openxlsx")


#' Is the comment-appendix runtime available on this machine?
appendix_env_ready <- function() {
  m <- steps_find_tool("comment_appendix_build")
  if (is.null(m)) return(FALSE)
  identical(steps_check_env(m)$status, "PASS")
}
