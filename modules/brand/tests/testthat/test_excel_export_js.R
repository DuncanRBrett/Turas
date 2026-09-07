# ==============================================================================
# BRAND MODULE TESTS: the shared Excel workbook builder in brand_report.js
# ==============================================================================
# Every destination toolbar and every section export button goes through
# _brTablesToWorkbook, which reads the rendered table. On 7 September 2026 a QA
# session opened an exported workbook rather than only inspecting it and found
# three defects in that walk: a category average of 61% with a 51 to 72 range
# rail beneath it written as the single number 615172; labels coerced to
# numbers; and rows the reader's brand filter had hidden present in the file.
#
# modules/brand/tests/js/test_excel_export.js drives the real builder in node
# against a stub DOM shaped like the markup the panels write. This wrapper runs
# it inside the brand suite so a regression fails here.
# ==============================================================================

library(testthat)

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

.xljs_root <- function() {
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "launch_turas.R")) ||
        file.exists(file.path(d, "CLAUDE.md"))) return(d)
    d <- dirname(d)
  }
  getwd()
}

ROOT_XLJS <- .xljs_root()
JS_TEST_XLJS <- file.path(ROOT_XLJS, "modules", "brand", "tests", "js",
                          "test_excel_export.js")
REPORT_JS_XLJS <- file.path(ROOT_XLJS, "modules", "brand", "lib", "html_report",
                            "js", "brand_report.js")


test_that("the node test file and the builder it exercises are both present", {
  expect_true(file.exists(JS_TEST_XLJS))
  expect_true(file.exists(REPORT_JS_XLJS))
})


test_that("the workbook builder passes its node known-answer tests", {
  node <- unname(Sys.which("node"))
  skip_if(!nzchar(node), "node is not on PATH")

  out <- suppressWarnings(
    system2(node, shQuote(JS_TEST_XLJS), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status") %||% 0L

  expect_identical(
    as.integer(status), 0L,
    info = paste("node test failed:\n", paste(out, collapse = "\n")))
  expect_true(any(grepl("0 failed", out, fixed = TRUE)),
              info = paste(out, collapse = "\n"))
})


test_that("the builder still asks the three questions the defects came from", {
  js <- paste(readLines(REPORT_JS_XLJS, warn = FALSE), collapse = "\n")

  # A cell is a number only when the whole of it is one. Dropping the anchors
  # from this pattern is how "1/9" became 1.
  expect_true(grepl("_BR_NUMERIC", js, fixed = TRUE))
  expect_true(grepl("^[+-]?(?:\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.\\d+)?%?$",
                    js, fixed = TRUE))

  # The rail is read as a range, not as part of the figure.
  expect_true(grepl("ma-ci-limits", js, fixed = TRUE))
  expect_true(grepl("_BR_RAIL", js, fixed = TRUE))

  # Visibility is the node's OWN computed display, never an ancestor's: a
  # Category Buying sub-tab that is not on screen hides its whole subtree and
  # its tables must still export. An ancestor-aware test would drop them.
  shown <- regmatches(
    js, regexpr("(?s)function _brShown\\(el\\) \\{.*?\\n  \\}", js, perl = TRUE))
  expect_length(shown, 1L)
  expect_true(grepl("getComputedStyle", shown, fixed = TRUE))
  expect_false(grepl("offsetParent", shown, fixed = TRUE))
  expect_false(grepl("getClientRects", shown, fixed = TRUE))

  # An absent value is an en dash.
  expect_true(grepl("_BR_ENDASH", js, fixed = TRUE))
  expect_true(grepl('_BR_ENDASH = "–"', js, fixed = TRUE))

  # All six significance-marker classes are chrome, together. Four draw an
  # arrow and were already being dropped by the glyph strip; the two that
  # draw an asterisk were not, so one column of a table exported numbers and
  # the next exported text. Dropping one of these from the list would bring
  # the split back.
  chrome <- regmatches(
    js, regexpr("(?s)_BR_CHROME = .*?;", js, perl = TRUE))
  expect_length(chrome, 1L)
  for (cls in c("ma-sig", "ma-fv-sig", "ma-adv-sig", "ct-sig",
                "fn-sig-avg", "fn-sig")) {
    expect_true(grepl(paste0(".", cls), chrome, fixed = TRUE),
                info = paste("significance class missing from chrome:", cls))
  }
})
