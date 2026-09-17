# ==============================================================================
# SHARED - import_all.R MUST FIND ITSELF
# ==============================================================================
# It resolved its own directory from sys.frame(1)$ofile, which is the OUTERMOST
# frame, not the frame doing the sourcing. Sourced from the top of a script
# that is what you want. Sourced from inside a function, which is what a Shiny
# GUI does, it is NULL or another file entirely, and the working-directory
# fallbacks are all that is left. With the working directory anywhere but the
# project root they all miss, the file fails, and the caller carries on without
# the shared library until something dies with "could not find function".
#
# Duncan hit exactly that running the keydriver GUI: the error named
# capture_console_all, which is a symptom three steps from the cause.
# ==============================================================================

find_root <- function() {
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "modules", "shared", "lib", "import_all.R"))) return(d)
    p <- dirname(d)
    if (identical(p, d)) break
    d <- p
  }
  NA_character_
}

turas_root <- find_root()
skip_if(is.na(turas_root), "cannot locate the project root")
import_all <- file.path(turas_root, "modules", "shared", "lib", "import_all.R")

# Each case runs in its own R process, because sourcing import_all.R into this
# one would define the functions and make every case pass trivially.
probe <- function(setup) {
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    setup,
    sprintf('ok <- tryCatch({ source("%s"); TRUE }, error = function(e) FALSE)', import_all),
    'cat(if (ok && exists("capture_console_all", mode = "function")) "FOUND" else "MISSING", "\\n")'
  ), script)
  out <- suppressWarnings(system2("Rscript", c("--vanilla", shQuote(script)),
                                  stdout = TRUE, stderr = TRUE))
  paste(out, collapse = "\n")
}

test_that("it loads when sourced from the project root", {
  expect_match(probe(sprintf('setwd("%s")', turas_root)), "FOUND")
})

test_that("it loads when the working directory is somewhere else entirely", {
  # This is the case that failed. Nothing about the shared library depends on
  # the caller's working directory, and it should not.
  expect_match(probe('setwd(tempdir())'), "FOUND")
})

test_that("it loads when sourced from inside nested function calls", {
  # What a Shiny observer does.
  setup <- c(
    'setwd(tempdir())',
    'outer <- function() inner()',
    'inner <- function() eval.parent(quote(NULL))'
  )
  script_body <- c(
    setup,
    sprintf('load_it <- function() source("%s")', import_all),
    'wrapper <- function() load_it()',
    'ok <- tryCatch({ wrapper(); TRUE }, error = function(e) FALSE)',
    'cat(if (ok && exists("capture_console_all", mode = "function")) "FOUND" else "MISSING", "\\n")'
  )
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(script_body, script)
  out <- suppressWarnings(system2("Rscript", c("--vanilla", shQuote(script)),
                                  stdout = TRUE, stderr = TRUE))
  expect_match(paste(out, collapse = "\n"), "FOUND")
})

test_that("the keydriver GUI treats a missing shared library as fatal", {
  gui <- file.path(turas_root, "modules", "keydriver", "run_keydriver_gui.R")
  skip_if(!file.exists(gui), "GUI not present")
  src <- paste(readLines(gui, warn = FALSE), collapse = "\n")
  # It used to print a warning and carry on, so the run died later naming a
  # function instead of the load that failed.
  expect_true(grepl("Nothing downstream can run without it", src, fixed = TRUE))
})
