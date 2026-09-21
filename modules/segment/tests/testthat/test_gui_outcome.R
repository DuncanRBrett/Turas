# H1 - the GUI called a refusal a success.
#
# turas_segment_from_config() runs under a refusal handler, which CATCHES the
# refusal condition and RETURNS a structured result. Nothing is thrown, so the
# GUI's tryCatch saw no error, wrapped the refusal in list(success = TRUE),
# printed "ANALYSIS COMPLETE" and fired the success notification. The results
# panel then tested result$error, a field a refusal does not carry, fell into
# the success branch, and read result$mode, which does not exist either, so it
# died on a zero-length comparison. Every deep refusal (preflight, data prep,
# guards, clustering) presented this way.
#
# segment_gui_outcome() is the pure classifier the GUI now asks first. These
# tests are at that function level, which is where a Shiny reactive can be
# exercised honestly.

test_that("a refusal is classified as a refusal, not a success", {
  refusal <- structure(
    list(run_status = "REFUSE", refused = TRUE, code = "DATA_MISSING_VARS",
         title = "Clustering Variables Not Found",
         problem = "Variables q7, q8 are not in the data file.",
         how_to_fix = c("Check the spelling", "Check the data sheet"),
         message = "full refusal text"),
    class = "turas_refusal_result"
  )

  out <- segment_gui_outcome(refusal)

  expect_equal(out$status, "REFUSED")
  expect_false(out$success)
  expect_equal(out$code, "DATA_MISSING_VARS")
  expect_equal(out$title, "Clustering Variables Not Found")
  expect_true(grepl("q7", out$problem, fixed = TRUE))
  expect_equal(length(out$how_to_fix), 2)
})

test_that("an internal error is classified as an error, with its message", {
  # The other half. A turas_error_result carries error = TRUE, a LOGICAL, and
  # the results panel printed that field as if it were the message.
  err <- structure(
    list(run_status = "ERROR", refused = FALSE, error = TRUE,
         message = "object 'clustering_data' not found", module = "SEGMENT"),
    class = "turas_error_result"
  )

  out <- segment_gui_outcome(err)

  expect_equal(out$status, "ERROR")
  expect_false(out$success)
  expect_equal(out$message, "object 'clustering_data' not found")
  expect_false(isTRUE(out$message))
})

test_that("a real result is classified as a success", {
  ok <- list(mode = "final", k = 3, method = "kmeans",
             output_files = list(assignments = "a.xlsx", report = "r.xlsx"))

  out <- segment_gui_outcome(ok)

  expect_equal(out$status, "PASS")
  expect_true(out$success)
})

test_that("a run_status of REFUSE is caught even without the class", {
  # Belt and braces: the class is what the handler sets today, but the field
  # is what the module's own docs describe.
  out <- segment_gui_outcome(list(run_status = "REFUSE", code = "CFG_BAD",
                                  problem = "no"))

  expect_equal(out$status, "REFUSED")
  expect_false(out$success)
})

test_that("NULL is not a success", {
  out <- segment_gui_outcome(NULL)

  expect_false(out$success)
  expect_equal(out$status, "ERROR")
})

test_that("the console block names the code, the problem and the fix", {
  # Turas runs in Shiny and users debug from the console (project CLAUDE.md),
  # so a refusal has to be readable there, not only in the browser.
  refusal <- structure(
    list(run_status = "REFUSE", refused = TRUE, code = "DATA_MISSING_VARS",
         title = "Clustering Variables Not Found",
         problem = "Variables q7, q8 are not in the data file.",
         how_to_fix = "Check the spelling",
         message = "full refusal text"),
    class = "turas_refusal_result"
  )

  text <- paste(capture.output(
    segment_gui_console_block(segment_gui_outcome(refusal))), collapse = "\n")

  expect_true(grepl("DATA_MISSING_VARS", text, fixed = TRUE))
  expect_true(grepl("Variables q7, q8", text, fixed = TRUE))
  expect_true(grepl("Check the spelling", text, fixed = TRUE))
  expect_false(grepl("ANALYSIS COMPLETE", text, fixed = TRUE))
})

test_that("a refusal from a real run is classified correctly end to end", {
  # Not a hand-built object: an actual refusal from the actual entry point.
  bad_config <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Config")
  openxlsx::writeData(wb, "Config", data.frame(
    Setting = c("data_file", "id_variable", "clustering_vars", "k_fixed", "method"),
    Value = c("no_such_file.xlsx", "respondent_id", "q1,q2,q3", "3", "kmeans"),
    stringsAsFactors = FALSE))
  openxlsx::saveWorkbook(wb, bad_config, overwrite = TRUE)
  on.exit(unlink(bad_config), add = TRUE)

  capture.output(result <- turas_segment_from_config(bad_config, verbose = FALSE))
  out <- segment_gui_outcome(result)

  expect_false(out$success)
  expect_equal(out$status, "REFUSED")
  expect_true(nzchar(out$code))
})


# ------------------------------------------------------------------------------
# The wiring. The classifier above is only useful if the GUI actually asks it.
# Everything in run_segment_gui.R lives inside run_segment_gui(), so it cannot
# be reached by sourcing; these are source-level guarantees, the same shape
# maxdiff used for its H4 fix.
# ------------------------------------------------------------------------------

.segment_gui_src <- function() {
  gui <- file.path(Sys.getenv("TURAS_ROOT"), "modules", "segment", "run_segment_gui.R")
  skip_if(!file.exists(gui), "GUI file not present")
  paste(readLines(gui, warn = FALSE), collapse = "\n")
}

test_that("the GUI classifies what came back instead of assuming success (H1)", {
  src <- .segment_gui_src()

  expect_true(grepl("segment_gui_outcome(result)", src, fixed = TRUE))
  expect_true(grepl("segment_gui_console_block(outcome)", src, fixed = TRUE))
  # The line that made every refusal a success.
  expect_false(grepl("list(success = TRUE, result = result)", src, fixed = TRUE))
})

test_that("the results panel renders refusal fields, not $mode (H1)", {
  src <- .segment_gui_src()

  expect_true(grepl("result$turas_outcome", src, fixed = TRUE))
  # An unguarded comparison against a field a refusal does not carry, which
  # is what made the panel die on a zero-length condition.
  expect_false(grepl("if (result$mode == \"exploration\")", src, fixed = TRUE))
})

test_that("the success toast fires once, and only on success (H1)", {
  src <- .segment_gui_src()

  expect_equal(length(gregexpr("completed successfully", src, fixed = TRUE)[[1]]), 1)
  success_at <- regexpr("completed successfully", src, fixed = TRUE)
  guard_at <- regexpr("if (analysis_result_data$success) {", src, fixed = TRUE)
  expect_true(guard_at > 0)
  expect_true(guard_at < success_at)
})

test_that("a refusal notification stays on screen until it is read (H1)", {
  src <- .segment_gui_src()

  # duration = NULL means it does not auto-dismiss. A refusal that vanishes
  # after five seconds is a refusal the user did not read.
  expect_true(grepl('type = "error", duration = NULL', src, fixed = TRUE))
})
