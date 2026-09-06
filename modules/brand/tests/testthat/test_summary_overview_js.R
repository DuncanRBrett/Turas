# ==============================================================================
# BRAND MODULE TESTS: the Overview derivations in brand_summary_panel.js
# ==============================================================================
# The Overview's headline tiles, its "What the numbers say" sentence, its two
# Why blocks and its Opportunities block are all derived in JavaScript from the
# payload the R panel already writes. Nothing is added to the JSON island, so
# the derivations cannot be exercised from R directly.
#
# modules/brand/tests/js/test_summary_overview.js runs the real panel file in
# node against a stub document and asserts the derivations by known answer.
# This wrapper runs it inside the brand suite so a regression fails here rather
# than waiting for someone to remember the node command.
#
# It also asserts, by reading the source, the one thing the node run cannot see
# from outside: that the rank is read from the field the R payload writes.
# ==============================================================================

library(testthat)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

.so_root <- function() {
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R")) ||
        file.exists(file.path(d, "CLAUDE.md"))) return(d)
    d <- dirname(d)
  }
  getwd()
}

ROOT_SO <- .so_root()
JS_TEST_SO <- file.path(ROOT_SO, "modules", "brand", "tests", "js",
                        "test_summary_overview.js")
PANEL_JS_SO <- file.path(ROOT_SO, "modules", "brand", "lib", "html_report",
                         "js", "brand_summary_panel.js")


test_that("the node test file and the panel it exercises are both present", {
  expect_true(file.exists(JS_TEST_SO))
  expect_true(file.exists(PANEL_JS_SO))
})


test_that("the Overview derivations pass their node known-answer tests", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node is not on PATH")

  out <- suppressWarnings(
    system2(node, shQuote(JS_TEST_SO), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status") %||% 0L

  expect_identical(
    as.integer(status), 0L,
    info = paste("node test failed:\n", paste(out, collapse = "\n")))
  expect_true(any(grepl("0 failed", out, fixed = TRUE)),
              info = paste(out, collapse = "\n"))
})


test_that("the hero rank is read from the field the R payload writes", {
  # The regression: heroAnchors() read `rank` off each ma_metrics entry, but
  # .brsum_brand_snapshot() writes the rank on focal_metrics as the string
  # "Rank %d / %d" and writes no rank field on ma_metrics at all. So mms_rank
  # was always null, .brsum-hero-rank was never emitted, and heroHeadline()
  # fell through to a bare "<brand> in <category>" clause.
  js <- paste(readLines(PANEL_JS_SO, warn = FALSE), collapse = "\n")
  expect_true(grepl("function parseRank", js, fixed = TRUE))
  expect_true(grepl("metricByLabel(snap.focal_metrics", js, fixed = TRUE))
  expect_true(grepl("mms_rank_of", js, fixed = TRUE))
  expect_true(grepl("window.brsumDerive", js, fixed = TRUE))

  # And the payload side still writes it where the reader now looks.
  panel_r <- file.path(ROOT_SO, "modules", "brand", "lib", "html_report",
                       "panels", "14_summary_panel.R")
  src <- paste(readLines(panel_r, warn = FALSE), collapse = "\n")
  expect_true(grepl('sprintf("Rank %d / %d", mms_rank, n_brands)', src,
                    fixed = TRUE))
})

