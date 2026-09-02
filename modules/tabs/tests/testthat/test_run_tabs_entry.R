# ==============================================================================
# TABS MODULE - THE HEADLESS ENTRY POINT FINDS ITS OWN ENGINE
# ==============================================================================
#
# run_tabs.R is the recipe every README gives: source it, call
# run_tabs_analysis(config). Sourced from a script that lives somewhere else
# (the integrated demo, a client runbook), it used to resolve lib/ beside the
# CALLER and fail with "cannot change working directory".
# ==============================================================================

library(testthat)

detect_root <- function() {
  home <- Sys.getenv("TURAS_HOME", "")
  if (nzchar(home) && dir.exists(file.path(home, "modules"))) return(normalizePath(home))
  d <- normalizePath(getwd(), mustWork = FALSE)
  for (i in 1:8) {
    if (dir.exists(file.path(d, "modules", "tabs"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("cannot find the Turas root")
}
root <- detect_root()

test_that("run_tabs.R resolves modules/tabs/lib when sourced from a foreign script", {
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if(!file.exists(rscript), "Rscript not found")
  runner <- file.path(root, "modules", "tabs", "run_tabs.R")
  caller_dir <- tempfile("tabs_caller_")
  dir.create(caller_dir)
  caller <- file.path(caller_dir, "caller.R")
  writeLines(c(
    sprintf('setwd("%s")', caller_dir),          # nowhere near the repo
    sprintf('source("%s")', runner),
    'cat("LIB:", tabs_runner_lib_dir(), "\\n")'
  ), caller)
  out <- suppressWarnings(system2(rscript, shQuote(caller), stdout = TRUE, stderr = TRUE))
  lib_line <- grep("^LIB:", out, value = TRUE)
  expect_length(lib_line, 1)
  expect_match(trimws(lib_line), "modules/tabs/lib$")
  expect_false(any(grepl("cannot change working directory", out, fixed = TRUE)))
  unlink(caller_dir, recursive = TRUE)
})

test_that("a missing config refuses with a boxed message, not an error", {
  src <- new.env()
  sys.source(file.path(root, "modules", "tabs", "run_tabs.R"), envir = src)
  out <- capture.output(res <- src$run_tabs_analysis(file.path(tempdir(), "no_such.xlsx")))
  expect_false(res)
  expect_true(any(grepl("IO_CONFIG_NOT_FOUND", out, fixed = TRUE)))
})
