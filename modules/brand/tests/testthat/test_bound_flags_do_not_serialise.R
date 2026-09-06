# ==============================================================================
# TEST: panel bind flags do not serialise into a saved copy (review F13)
# ==============================================================================
# Panels guard their binder with a "already bound" flag. Written through
# element.dataset it becomes a data-* attribute, and Save a copy writes the
# live DOM out through outerHTML, so the saved file carries the flag. On
# reopen the binder saw it, returned early, and that panel's handlers were
# never attached: the Audience Lens clear button and sub-tabs, and the
# portfolio footprint focal select, brand chips and column sorting.
#
# A plain JS property on the element does the same job and is dropped by
# serialisation. This is a static scan, so a new panel that reaches for
# dataset again fails here rather than in a client's saved copy.
# ==============================================================================

library(testthat)

.bfs_js_dir <- local({
  d <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(d, "CLAUDE.md"))) break
    d <- dirname(d)
  }
  file.path(d, "modules", "brand", "lib", "html_report", "js")
})


test_that("no brand panel writes a bind flag through dataset", {
  expect_true(dir.exists(.bfs_js_dir))
  files <- list.files(.bfs_js_dir, pattern = "\\.js$", full.names = TRUE)
  expect_gt(length(files), 0L)

  offenders <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    code <- lines[!grepl("^\\s*(//|\\*|/\\*)", lines)]
    hits <- grep("dataset\\.[A-Za-z_$][A-Za-z0-9_$]*[Bb]ound", code)
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s: %s", basename(f),
                                        trimws(code[hits])))
    }
  }
  expect_identical(offenders, character(0))
})


test_that("no brand panel reads a bind flag from a data-*-bound attribute", {
  files <- list.files(.bfs_js_dir, pattern = "\\.js$", full.names = TRUE)
  offenders <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    code <- lines[!grepl("^\\s*(//|\\*|/\\*)", lines)]
    hits <- grep("getAttribute\\(\\s*['\"]data-[a-z-]*bound", code)
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s: %s", basename(f),
                                        trimws(code[hits])))
    }
  }
  expect_identical(offenders, character(0))
})


test_that("the two known sites bind on a JS property instead", {
  al <- readLines(file.path(.bfs_js_dir, "brand_audience_lens_panel.js"),
                  warn = FALSE)
  expect_true(any(grepl("panel._alBound === true", al, fixed = TRUE)))
  expect_true(any(grepl("panel._alBound = true", al, fixed = TRUE)))

  pf <- readLines(file.path(.bfs_js_dir, "brand_portfolio_panel.js"),
                  warn = FALSE)
  expect_true(any(grepl("table._pfFpBound === true", pf, fixed = TRUE)))
  expect_true(any(grepl("table._pfFpBound = true", pf, fixed = TRUE)))
})
