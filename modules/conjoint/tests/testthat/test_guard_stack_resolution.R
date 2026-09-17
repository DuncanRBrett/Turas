# ==============================================================================
# CONJOINT - GUARD AND MODULE DIRECTORY RESOLUTION FROM THE CALL STACK
# ==============================================================================
# F7 from the maxdiff v2 independent review. `Rscript demo.R` passed while
# `Rscript -e 'source("demo.R")'` refused at the conjoint step with
# CONJ_ANALYSIS_FAILED: could not find function "validate_hb_config".
#
# Cause: .get_guard_dir() read sys.frame(1)$ofile and the module-directory walk
# went outermost-first, so both found the CALLER's file rather than this
# module's own frame, and the guard and the module files were looked up beside
# the caller.
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT")

test_that("the guard and module files load when 00_main.R is source()d from another script", {
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if(!file.exists(rscript), "Rscript not found")
  skip_if(!nzchar(turas_root), "TURAS_ROOT not set")
  main <- file.path(turas_root, "modules", "conjoint", "R", "00_main.R")
  caller_dir <- tempfile("cj_caller_")
  dir.create(caller_dir)
  caller <- file.path(caller_dir, "caller.R")
  writeLines(c(
    sprintf('setwd("%s")', tempdir()),
    sprintf('source("%s")', main),
    'cat("GUARD:", exists("conjoint_refuse", mode = "function"), "\\n")',
    'cat("MODULE:", exists("validate_hb_config", mode = "function"), "\\n")'
  ), caller)
  out <- suppressWarnings(system2(
    rscript, c("-e", shQuote(sprintf('source("%s")', caller))),
    stdout = TRUE, stderr = TRUE
  ))
  expect_true(any(grepl("GUARD: TRUE", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
  expect_true(any(grepl("MODULE: TRUE", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
  expect_false(any(grepl("could not find function", out, fixed = TRUE)),
               info = paste(out, collapse = "\n"))
  unlink(caller_dir, recursive = TRUE)
})

test_that("the guard loads when the caller is itself named 00_main.R", {
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if(!file.exists(rscript), "Rscript not found")
  skip_if(!nzchar(turas_root), "TURAS_ROOT not set")
  main <- file.path(turas_root, "modules", "conjoint", "R", "00_main.R")
  caller_dir <- tempfile("cj_caller_00main_")
  dir.create(caller_dir)
  caller <- file.path(caller_dir, "00_main.R")
  writeLines(c(
    sprintf('setwd("%s")', tempdir()),
    sprintf('source("%s")', main),
    'cat("GUARD:", exists("conjoint_refuse", mode = "function"), "\\n")',
    'cat("MODULE:", exists("validate_hb_config", mode = "function"), "\\n")'
  ), caller)
  out <- suppressWarnings(system2(
    rscript, c("-e", shQuote(sprintf('source("%s")', caller))),
    stdout = TRUE, stderr = TRUE
  ))
  expect_true(any(grepl("GUARD: TRUE", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
  expect_true(any(grepl("MODULE: TRUE", out, fixed = TRUE)), info = paste(out, collapse = "\n"))
  unlink(caller_dir, recursive = TRUE)
})
