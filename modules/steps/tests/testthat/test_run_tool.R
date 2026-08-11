# ==============================================================================
# TESTS - Process execution and exit-code -> TRS mapping
# ==============================================================================
# These use the runtime that is guaranteed present (the one running the suite),
# so process handling is covered even where python3 is not installed.

skip_if_no_processx <- function() {
  testthat::skip_if_not_installed("processx")
}

probe_root <- function(body, args = list()) {
  root <- tempfile("steps_run_")
  dir.create(root, recursive = TRUE)
  writeLines(body, file.path(root, "probe.R"))
  list(root = root, manifest = test_manifest(args = args, requires = character(0)))
}


test_that("a tool that succeeds returns PASS with its output", {
  skip_if_no_processx()
  p <- probe_root(c("cat('first line\\n')", "cat('second line\\n')"))
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  seen <- character(0)
  res <- steps_run_tool(p$manifest, list(), turas_root = p$root,
                        on_output = function(lines) seen <<- c(seen, lines))

  expect_equal(res$status, "PASS")
  expect_equal(res$exit_status, 0L)
  expect_true("first line" %in% res$output)
  expect_true("second line" %in% res$output)
  expect_equal(seen, res$output)   # the callback saw everything, as it happened
})

test_that("a non-zero exit maps to an IO_STEP_FAILED refusal carrying the tail", {
  skip_if_no_processx()
  p <- probe_root(c("cat('working\\n')",
                    "cat('the thing you must fix\\n')",
                    "quit(status = 3)"))
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  res <- steps_run_tool(p$manifest, list(), turas_root = p$root, on_output = NULL)

  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_STEP_FAILED")
  expect_equal(res$exit_status, 3L)
  expect_true(grepl("status 3", res$message, fixed = TRUE))
  expect_true(grepl("the thing you must fix", res$context$last_output, fixed = TRUE))
})

test_that("stderr is interleaved into the output stream", {
  skip_if_no_processx()
  p <- probe_root(c("cat('to stdout\\n')",
                    "cat('to stderr\\n', file = stderr())",
                    "quit(status = 0)"))
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  res <- steps_run_tool(p$manifest, list(), turas_root = p$root, on_output = NULL)
  expect_equal(res$status, "PASS")
  expect_true("to stdout" %in% res$output)
  expect_true("to stderr" %in% res$output)
})

test_that("output written immediately before exit is not lost", {
  skip_if_no_processx()
  # No flush, no pause: the last line is still in the pipe when the process dies.
  p <- probe_root("cat('last gasp')")
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  res <- steps_run_tool(p$manifest, list(), turas_root = p$root, on_output = NULL)
  expect_equal(res$status, "PASS")
  expect_true(any(grepl("last gasp", res$output, fixed = TRUE)))
})

test_that("a tool that overruns its timeout is stopped and refuses", {
  skip_if_no_processx()
  p <- probe_root(c("Sys.sleep(30)", "cat('never\\n')"))
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  res <- steps_run_tool(p$manifest, list(), turas_root = p$root,
                        on_output = NULL, timeout_s = 1)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "IO_STEP_FAILED")
  expect_true(grepl("still running", res$message, fixed = TRUE))
})

test_that("a bad argument refuses before any process starts", {
  skip_if_no_processx()
  p <- probe_root("cat('should not run\\n')",
                  args = list(list(id = "needed", label = "Needed", type = "text",
                                   cli = "--needed", required = TRUE)))
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  res <- steps_run_tool(p$manifest, list(needed = ""), turas_root = p$root,
                        on_output = NULL)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "CFG_STEP_ARG_MISSING")
  expect_null(res$exit_status)
})

test_that("arguments reach the tool", {
  skip_if_no_processx()
  p <- probe_root(c("args <- commandArgs(trailingOnly = TRUE)",
                    "cat(paste(args, collapse = '|'), '\\n')"),
                  args = list(list(id = "alpha", label = "Alpha", type = "text",
                                   cli = "--alpha")))
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  res <- steps_run_tool(p$manifest, list(alpha = "a value with spaces"),
                        turas_root = p$root, on_output = NULL)
  expect_equal(res$status, "PASS")
  expect_true(any(grepl("--alpha|a value with spaces", res$output, fixed = TRUE)))
})

test_that("the environment guard blocks the run when the runtime is absent", {
  skip_if_no_processx()
  p <- probe_root("cat('should not run\\n')")
  on.exit(unlink(p$root, recursive = TRUE), add = TRUE)

  m <- p$manifest
  m$runtime <- "definitely_not_a_real_binary_xyz"
  res <- steps_run_tool(m, list(), turas_root = p$root, on_output = NULL)
  expect_equal(res$status, "REFUSED")
  expect_equal(res$code, "PKG_RUNTIME_MISSING")
})

test_that("a refusal prints to the console in the boxed TRS format", {
  refusal <- steps_refuse("IO_STEP_FAILED", "Something specific went wrong.",
                          c("Do this", "Then this"),
                          context = list(tool = "probe_tool"))
  printed <- capture.output(steps_print_refusal(refusal, context = "Test context"))
  joined <- paste(printed, collapse = "\n")

  expect_true(grepl("[REFUSE] IO_STEP_FAILED", joined, fixed = TRUE))
  expect_true(grepl("Something specific went wrong.", joined, fixed = TRUE))
  expect_true(grepl("Do this", joined, fixed = TRUE))
  expect_true(grepl("Test context", joined, fixed = TRUE))
  expect_true(grepl("probe_tool", joined, fixed = TRUE))
})

test_that("printing a PASS result prints nothing", {
  expect_equal(capture.output(steps_print_refusal(list(status = "PASS"))), character(0))
})
