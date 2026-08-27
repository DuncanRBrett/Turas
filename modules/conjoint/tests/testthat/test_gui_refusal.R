# ==============================================================================
# TESTS: GUI REFUSAL DETECTION (run_conjoint_gui.R)
# ==============================================================================
#
# run_conjoint_analysis() returns refusals rather than throwing them, so the
# GUI's tryCatch never fires on one. Before this was fixed the GUI printed
# "✓ Analysis complete!" on every refused run (review finding H4).
#
# These tests cover .conjoint_gui_refusal(), the detector the GUI now consults
# before it declares success.
# ==============================================================================

turas_root <- Sys.getenv("TURAS_ROOT", unset = "")
if (!nzchar(turas_root)) {
  dir <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in 1:8) {
    if (file.exists(file.path(dir, "modules", "conjoint", "R", "00_main.R"))) {
      turas_root <- dir
      break
    }
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
}

gui_file <- file.path(turas_root, "modules", "conjoint", "run_conjoint_gui.R")

test_that("the GUI launcher file is present", {
  expect_true(file.exists(gui_file), info = gui_file)
})

# The launcher defines .conjoint_gui_refusal at top level, so it can be sourced
# without starting Shiny.
source(gui_file, local = TRUE)

test_that("GUI: a PASS result is not treated as a refusal", {
  expect_null(.conjoint_gui_refusal(list(status = "PASS", utilities = data.frame())))
})

test_that("GUI: a PARTIAL result is not treated as a refusal", {
  expect_null(.conjoint_gui_refusal(list(status = "PARTIAL", warnings = "something minor")))
})

test_that("GUI: a status = REFUSED result is detected", {
  ref <- .conjoint_gui_refusal(list(
    status     = "REFUSED",
    code       = "DATA_NO_CHOICE",
    message    = "No chosen alternative found.",
    how_to_fix = c("Fix one", "Fix two")
  ))

  expect_false(is.null(ref))
  expect_equal(ref$code, "DATA_NO_CHOICE")
  expect_equal(ref$message, "No chosen alternative found.")
  expect_equal(ref$how_to_fix, c("Fix one", "Fix two"))
})

test_that("GUI: a turas_refusal_result object is detected", {
  obj <- structure(
    list(
      run_status = "REFUSE",
      refused    = TRUE,
      code       = "CFG_MISSING_SETTING",
      title      = "Missing Setting",
      message    = "The Settings sheet is missing a required row.",
      how_to_fix = "Add the row."
    ),
    class = "turas_refusal_result"
  )

  ref <- .conjoint_gui_refusal(obj)
  expect_false(is.null(ref))
  expect_equal(ref$code, "CFG_MISSING_SETTING")
  expect_equal(ref$title, "Missing Setting")
})

test_that("GUI: a NULL result is reported as a bug rather than success", {
  ref <- .conjoint_gui_refusal(NULL)
  expect_false(is.null(ref))
  expect_equal(ref$code, "BUG_NO_RESULT")
})

test_that("GUI: a refusal with no message still yields usable text", {
  ref <- .conjoint_gui_refusal(list(status = "REFUSED"))
  expect_false(is.null(ref))
  expect_equal(ref$code, "CONJ_REFUSED")
  expect_true(nzchar(ref$message))
  expect_length(ref$how_to_fix, 0)
})

test_that("GUI: the analysis output capture takes messages as well as stdout", {
  # H5: capturing only type = "output" hid every message()-based TRS notice.
  src <- readLines(gui_file, warn = FALSE)
  expect_true(any(grepl("invokeRestart\\(\"muffleMessage\"\\)", src, fixed = FALSE)),
              info = "GUI must route message() output into the captured console text")
})

test_that("GUI: the module-loading setwd is unwound even when sourcing fails", {
  src <- paste(readLines(gui_file, warn = FALSE), collapse = "\n")
  expect_true(grepl("finally = setwd(old_wd)", src, fixed = TRUE))
})

test_that("GUI: the phantom client_name input is gone", {
  src <- paste(readLines(gui_file, warn = FALSE), collapse = "\n")
  expect_false(grepl("input$client_name", src, fixed = TRUE))
})
