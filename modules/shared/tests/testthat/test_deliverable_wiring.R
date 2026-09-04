# ==============================================================================
# DELIVERABLE WIRING. A ticked checkbox has to reach a call site
# ==============================================================================
#
# Every module GUI offers "Prepare client deliverable (minify for delivery, dev
# copy kept)". The checkbox sets TURAS_PREPARE_DELIVERABLE and sources the
# minifier. It does nothing at all unless the module then calls
# turas_prepare_deliverable() or turas_minify() on the file it wrote.
#
# Two modules did not. Conjoint lost its call site when its HTML report was
# retired in fc27160a on 27 August 2026, and the simulator that survived was
# never wired up. Brand never had one. Both boxes showed ticked, because
# turas_deliverable_default() returns TRUE whenever javascript-obfuscator is
# installed, and both shipped a readable file. Found 4 September 2026.
#
# Nothing else in the suite can catch this: the modules run, the reports are
# correct, and the only symptom is readable JavaScript in a client file.
#
# Run: Rscript -e 'testthat::test_file("modules/shared/tests/testthat/test_deliverable_wiring.R")'
# ==============================================================================

library(testthat)

turas_root <- local({
  path <- Sys.getenv("TURAS_ROOT", getwd())
  for (i in 1:10) {
    if (dir.exists(file.path(path, "modules", "tabs"))) {
      return(normalizePath(path, mustWork = FALSE))
    }
    path <- dirname(path)
  }
  ""
})

#' Every R file in a module, whatever layout it uses
#'
#' Modules put their source in R/, in lib/ or at the root. All three are read,
#' and the GUI file with them, because a call site in the GUI is a real call
#' site: brand generates its HTML report only from there.
.module_r_files <- function(module) {
  dir <- file.path(turas_root, "modules", module)
  if (!dir.exists(dir)) return(character(0))
  list.files(dir, pattern = "[.]R$", full.names = TRUE, recursive = TRUE)
}

#' Files that are not tests
.non_test_files <- function(files) {
  files[!grepl("/tests?/", files)]
}

test_that("every module that offers the deliverable checkbox also calls it", {
  skip_if(!nzchar(turas_root), "Turas root not found")

  module_dirs <- list.dirs(file.path(turas_root, "modules"),
                           full.names = FALSE, recursive = FALSE)
  module_dirs <- module_dirs[nzchar(module_dirs) & module_dirs != "shared"]
  expect_true(length(module_dirs) > 5L)

  offers <- character(0)
  wired <- character(0)

  for (m in module_dirs) {
    files <- .non_test_files(.module_r_files(m))
    if (length(files) == 0L) next
    text <- vapply(files, function(f) {
      paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    }, character(1))

    has_checkbox <- any(grepl('checkboxInput\\("prepare_deliverable"', text))
    if (!has_checkbox) next
    offers <- c(offers, m)

    # A real call, not the exists() guard that only decides whether to source.
    calls <- grepl("turas_prepare_deliverable\\([^)\"]", text) |
      grepl("turas_minify\\([a-z_.]", text)
    if (any(calls)) wired <- c(wired, m)
  }

  missing <- setdiff(offers, wired)
  expect_equal(
    length(missing), 0L,
    info = sprintf(
      paste("these modules offer the deliverable checkbox and never act on it,",
            "so a ticked box ships a readable file: %s"),
      paste(missing, collapse = ", ")))

  cat(sprintf("\n  %d modules offer the checkbox, %d act on it: %s\n",
              length(offers), length(wired), paste(sort(offers), collapse = ", ")))
})

test_that("the conjoint simulator is handed to the deliverable step", {
  skip_if(!nzchar(turas_root), "Turas root not found")
  f <- file.path(turas_root, "modules/conjoint/R/00_main.R")
  skip_if_not(file.exists(f), "conjoint 00_main.R not found")
  src <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expect_true(grepl("turas_prepare_deliverable(simulator_result$output_path)",
                    src, fixed = TRUE),
              info = paste("the simulator is conjoint's only HTML output since",
                           "the report was retired, so it is the deliverable"))
})

test_that("the standalone maxdiff simulator is handed to the deliverable step", {
  skip_if(!nzchar(turas_root), "Turas root not found")
  f <- file.path(turas_root, "modules/maxdiff/R/00_main.R")
  skip_if_not(file.exists(f), "maxdiff 00_main.R not found")
  src <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expect_true(grepl("turas_prepare_deliverable(sim_result$output_file)",
                    src, fixed = TRUE),
              info = paste("with Generate_HTML_Report off the simulator file",
                           "IS the deliverable, and it was never minified"))
})

test_that("the brand report is handed to the deliverable step", {
  skip_if(!nzchar(turas_root), "Turas root not found")
  f <- file.path(turas_root, "modules/brand/run_brand_gui.R")
  skip_if_not(file.exists(f), "run_brand_gui.R not found")
  src <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expect_true(grepl("turas_prepare_deliverable(out_html)", src, fixed = TRUE),
              info = "brand generates its HTML report only in the GUI")
})
