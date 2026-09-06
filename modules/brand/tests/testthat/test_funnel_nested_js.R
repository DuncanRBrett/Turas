# ==============================================================================
# BRAND MODULE TESTS: the nested-funnel helpers in brand_funnel_panel.js
# ==============================================================================
# The four base views are resolved in JavaScript, over the payload the R panel
# already writes. Nothing was added to the JSON island for the nested view, so
# the derivation cannot be exercised from R directly.
#
# modules/brand/tests/js/test_funnel_nested.js runs the real panel file in
# node against a stub document and asserts the derivations by known answer.
# This wrapper runs it inside the brand suite so a regression fails here.
# ==============================================================================

library(testthat)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

.fnjs_root <- function() {
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R")) ||
        file.exists(file.path(d, "CLAUDE.md"))) return(d)
    d <- dirname(d)
  }
  getwd()
}

ROOT_FNJS <- .fnjs_root()
JS_TEST_FNJS <- file.path(ROOT_FNJS, "modules", "brand", "tests", "js",
                          "test_funnel_nested.js")
PANEL_JS_FNJS <- file.path(ROOT_FNJS, "modules", "brand", "lib", "html_report",
                           "js", "brand_funnel_panel.js")


test_that("the node test file and the panel it exercises are both present", {
  expect_true(file.exists(JS_TEST_FNJS))
  expect_true(file.exists(PANEL_JS_FNJS))
})


test_that("the nested-funnel helpers pass their node known-answer tests", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node is not on PATH")

  out <- suppressWarnings(
    system2(node, shQuote(JS_TEST_FNJS), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status") %||% 0L

  expect_identical(
    as.integer(status), 0L,
    info = paste("node test failed:\n", paste(out, collapse = "\n")))
  expect_true(any(grepl("0 failed", out, fixed = TRUE)),
              info = paste(out, collapse = "\n"))
})


test_that("every view the toggle offers has a branch in the JS", {
  js <- paste(readLines(PANEL_JS_FNJS, warn = FALSE), collapse = "\n")
  # The primary attribute each view reads.
  expect_true(grepl('mode === "chain"    ? "data-fn-pct-chn"', js,
                    fixed = TRUE))
  # The sort attribute suffix.
  expect_true(grepl('pctMode === "chain"  ? "-chn"', js, fixed = TRUE))
  # The chart series, the mini funnels and the Excel export.
  expect_true(grepl("chainByBrand", js, fixed = TRUE))
  expect_true(grepl("chainAvgMF", js, fixed = TRUE))
  expect_true(grepl("chainAvgEx", js, fixed = TRUE))
})
