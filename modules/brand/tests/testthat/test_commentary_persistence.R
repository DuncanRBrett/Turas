# ==============================================================================
# TEST: one DOM-serialisable persistence mechanism for analyst commentary
# (review 2026-07-12, C2 + H3). Static checks on the shipped JS; the browser
# round-trip was proved with headless Chrome in the fixing session (see the
# commit message).
# ==============================================================================
library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  JS_DIR <<- file.path(find_root(), "modules", "brand", "lib", "html_report", "js")
})

.js <- function(name) paste(readLines(file.path(JS_DIR, name), warn = FALSE), collapse = "\n")

test_that("brand_report.js mirrors textarea value into text content on input and before save", {
  js <- .js("brand_report.js")
  expect_true(grepl("window._brSyncCommentary = function", js, fixed = TRUE))
  expect_true(grepl("ta.textContent = ta.value", js, fixed = TRUE))
  expect_true(grepl("window._brSyncAllCommentary = function", js, fixed = TRUE))
  # delegated listener for both input and change events
  expect_true(grepl('\\["input", "change"\\]', js))
  expect_true(grepl("initCommentaryPersistence();", js, fixed = TRUE))
  # The save path syncs before it reads outerHTML. The chain gained a link
  # when the brand controls started surviving Save too: _brSaveReport calls
  # _brSerialiseReport, which calls _brSyncReportState, which mirrors the
  # commentary and then the selections. The intent is unchanged and is
  # asserted through the whole chain rather than at one hop.
  save_body <- substr(
    sub(".*window._brSaveReport = function\\(\\) \\{", "", js), 1, 900)
  expect_true(grepl("_brSerialiseReport()", save_body, fixed = TRUE))

  ser <- substr(
    sub(".*window._brSerialiseReport = function\\(\\) \\{", "", js), 1, 400)
  sync_at <- regexpr("_brSyncReportState()", ser, fixed = TRUE)
  html_at <- regexpr("document.documentElement.outerHTML", ser, fixed = TRUE)
  expect_gt(sync_at, 0)
  expect_gt(html_at, 0)
  expect_lt(sync_at, html_at)

  state <- substr(
    sub(".*window._brSyncReportState = function\\(\\) \\{", "", js), 1, 400)
  expect_true(grepl("_brSyncAllCommentary()", state, fixed = TRUE))
})

test_that("MA and Audience Lens insight boxes no longer use browser storage", {
  ma <- .js("brand_ma_panel.js")
  bind <- regmatches(ma, regexpr("(?s)function bindInsightBoxPersistence\\(panel\\) \\{.*?\n  \\}\n", ma, perl = TRUE))
  expect_length(bind, 1L)
  expect_false(grepl("sessionStorage", bind, fixed = TRUE))
  expect_false(grepl("localStorage", bind, fixed = TRUE))
  expect_true(grepl("_brSyncCommentary", bind, fixed = TRUE))

  al <- .js("brand_audience_lens_panel.js")
  expect_false(grepl("localStorage.", al, fixed = TRUE))
  expect_false(grepl("turas_al_insight_", al, fixed = TRUE))
  expect_true(grepl("_brSyncCommentary", al, fixed = TRUE))
})

test_that("programmatic writers of commentary boxes call the mirror", {
  expect_true(grepl("_brSyncCommentary(ta)", .js("brand_branded_reach_panel.js"), fixed = TRUE))
  expect_true(grepl("_brSyncCommentary(editor)", .js("brand_summary_panel.js"), fixed = TRUE))
})
