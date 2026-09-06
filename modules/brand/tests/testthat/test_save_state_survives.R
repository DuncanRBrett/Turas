# ==============================================================================
# TEST: the brand controls survive Save a copy
# ==============================================================================
# Two selections used to be lost when a reader saved a copy and reopened it.
#
#   * The header's comparison set. A checkbox's .checked and an option's
#     .selected are properties; the content attributes are defaultChecked and
#     defaultSelected, so outerHTML never saw either.
#   * Each chart's "Chart brands" deviation, which lives on a BrandSelector
#     handle and never touched the DOM at all.
#
# The second one was the dangerous one. The note above a narrowed chart is a
# plain text node, so it DID serialise while the state behind it did not: a
# saved file carried eight notes each saying the chart omits a brand, with no
# deviation behind any of them, and a data-chartfocus-clause attribute that a
# pin and a PNG title read. That is a client-facing artefact making a false
# statement.
#
# The behaviour is proved end to end by
# modules/brand/tests/qa/drive_save_roundtrip.py, which drives a real report
# in headless Chrome, serialises it through the report's own
# _brSerialiseReport(), reopens the dump and compares. That needs Chrome, so
# it is not in this suite. This file is the static gate that keeps the
# mechanism in place between those runs: it asserts the shape the round trip
# depends on, so a refactor that removes a mirror fails here rather than in a
# client's saved copy.
# ==============================================================================

library(testthat)

.sss_js_dir <- local({
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "CLAUDE.md"))) break
    d <- dirname(d)
  }
  file.path(d, "modules", "brand", "lib", "html_report", "js")
})

.sss_read <- function(name) {
  paste(readLines(file.path(.sss_js_dir, name), warn = FALSE), collapse = "\n")
}


test_that("Save goes through one serialiser that syncs first", {
  js <- .sss_read("brand_report.js")

  expect_true(grepl("window._brSerialiseReport = function", js, fixed = TRUE))
  expect_true(grepl("window._brSyncReportState = function", js, fixed = TRUE))
  expect_true(grepl("window._brSyncSelectionState = function", js, fixed = TRUE))

  # _brSaveReport must not build the string itself: one path, so the QA round
  # trip and the button cannot drift apart.
  save_body <- sub("^.*window\\._brSaveReport = function\\(\\) \\{", "", js)
  save_body <- substr(save_body, 1, 900)
  expect_true(grepl("_brSerialiseReport()", save_body, fixed = TRUE))
  expect_false(grepl("documentElement.outerHTML", save_body, fixed = TRUE))

  # And the serialiser syncs before it reads.
  ser <- sub("^.*window\\._brSerialiseReport = function\\(\\) \\{", "", js)
  ser <- substr(ser, 1, 400)
  sync_at <- regexpr("_brSyncReportState()", ser, fixed = TRUE)
  html_at <- regexpr("documentElement.outerHTML", ser, fixed = TRUE)
  expect_gt(sync_at, 0)
  expect_gt(html_at, 0)
  expect_lt(sync_at, html_at)
})


test_that("the selection mirror writes the three properties outerHTML misses", {
  js <- .sss_read("brand_report.js")
  body <- sub("^.*window\\._brSyncSelectionState = function\\(\\) \\{", "", js)
  body <- substr(body, 1, 2000)

  # An option's chosen state, written as an attribute.
  expect_true(grepl('setAttribute("selected"', body, fixed = TRUE))
  expect_true(grepl('removeAttribute("selected")', body, fixed = TRUE))
  # A checkbox's ticked state, and the focal brand's locked box.
  expect_true(grepl('setAttribute("checked"', body, fixed = TRUE))
  expect_true(grepl('removeAttribute("checked")', body, fixed = TRUE))
  expect_true(grepl('setAttribute("disabled"', body, fixed = TRUE))
  # The chart deviation, which lives outside the DOM entirely.
  expect_true(grepl("BrandChartFocus.prepareForSave", body, fixed = TRUE))

  # Scoped to the header's own controls. A sweep over every select in the
  # document would freeze each panel's hidden focal select, which the header
  # re-drives on load anyway.
  expect_true(grepl('".br-controls select"', body, fixed = TRUE))
})


test_that("the commentary mirror still runs on Save", {
  js <- .sss_read("brand_report.js")
  body <- sub("^.*window\\._brSyncReportState = function\\(\\) \\{", "", js)
  body <- substr(body, 1, 600)
  expect_true(grepl("_brSyncAllCommentary()", body, fixed = TRUE))
  expect_true(grepl("_brSyncSelectionState()", body, fixed = TRUE))
})


test_that("a chart deviation is written to the DOM and read back after the header", {
  js <- .sss_read("brand_chart_focus.js")

  expect_true(grepl("function prepareForSave()", js, fixed = TRUE))
  expect_true(grepl("function restoreAll()", js, fixed = TRUE))
  expect_true(grepl("prepareForSave: prepareForSave", js, fixed = TRUE))
  expect_true(grepl("restoreAll: restoreAll", js, fixed = TRUE))
  expect_true(grepl('var SAVE_ATTR = "data-cf-saved"', js, fixed = TRUE))

  # The attribute is written only at save time. If refreshMount wrote it too,
  # a repaint could clear the value a restore was about to read.
  refresh <- sub("^.*function refreshMount\\(mount\\) \\{", "", js)
  refresh <- substr(refresh, 1, 1600)
  expect_false(grepl("SAVE_ATTR", refresh, fixed = TRUE))

  # A restore can only narrow, the same rule the control itself obeys: the
  # saved codes are added to the header's hidden set, never subtracted.
  restore <- sub("^.*function restoreAll\\(\\) \\{", "", js)
  restore <- substr(restore, 1, 1400)
  expect_true(grepl("handle.getHidden()", restore, fixed = TRUE))
  expect_true(grepl("setHiddenChart(hidden)", restore, fixed = TRUE))

  # And it runs after the load-time header publish, because every published
  # set resets a panel's chart-only set to its table set.
  rep_js <- .sss_read("brand_report.js")
  pub <- sub("^.*function brApplyAllComparisonSets\\(\\) \\{", "", rep_js)
  pub <- substr(pub, 1, 1200)
  loop_at <- regexpr("brApplyComparisonSet(g)", pub, fixed = TRUE)
  rest_at <- regexpr("BrandChartFocus.restoreAll()", pub, fixed = TRUE)
  expect_gt(loop_at, 0)
  expect_gt(rest_at, 0)
  expect_lt(loop_at, rest_at)
})


test_that("a reopened copy adopts the trigger it saved rather than adding one", {
  js <- .sss_read("brand_chart_focus.js")
  body <- sub("^.*function buildMount\\(mount\\) \\{", "", js)
  body <- substr(body, 1, 1400)

  # The trigger is built by JavaScript, so outerHTML carries it while the
  # __cfBuilt property does not. Appending unconditionally gave every chart
  # in a reopened copy two "Chart brands" buttons.
  expect_true(grepl('mount.querySelector(".br-cf-trigger")', body, fixed = TRUE))
  expect_true(grepl("if (!trigger)", body, fixed = TRUE))
  expect_true(grepl('trigger.querySelector(".br-cf-label")', body, fixed = TRUE))
  expect_true(grepl("if (!lbl)", body, fixed = TRUE))
  # A stale popover carries dead checkbox state and is dropped.
  expect_true(grepl('mount.querySelectorAll(".br-cf-pop")', body, fixed = TRUE))
})


test_that("the QA round trip script is present and drives the real serialiser", {
  qa <- file.path(dirname(dirname(.sss_js_dir)), "..", "tests", "qa",
                  "drive_save_roundtrip.py")
  qa <- normalizePath(qa, mustWork = FALSE)
  expect_true(file.exists(qa))
  txt <- paste(readLines(qa, warn = FALSE), collapse = "\n")
  expect_true(grepl("_brSerialiseReport", txt, fixed = TRUE))
  # The gate that would have caught the note with nothing behind it.
  expect_true(grepl("every deviation note in the saved markup has state",
                    txt, fixed = TRUE))
})
