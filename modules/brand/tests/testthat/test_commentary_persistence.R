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
  # the save path syncs before it reads outerHTML
  save_body <- sub(".*window._brSaveReport = function\\(\\) \\{", "", js)
  save_body <- sub("document.documentElement.outerHTML.*", "", save_body)
  expect_true(grepl("_brSyncAllCommentary()", save_body, fixed = TRUE))
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
