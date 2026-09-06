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


# The first version of this scan matched "bound" only, and two panels named
# their flag womInit and brReachInit and sailed through it for the same bug.
# The name is not the point: any once-only guard written into dataset is the
# defect, so every word a developer reaches for is listed here.
.BFS_FLAG_WORDS <- c("Bound", "Init", "Built", "Ready", "Wired", "Done",
                     "Mounted", "Bind", "Attached", "Registered", "Setup")

.bfs_flag_pattern <- function() {
  words <- paste(c(.BFS_FLAG_WORDS, tolower(.BFS_FLAG_WORDS)), collapse = "|")
  sprintf("dataset\\.[A-Za-z_$][A-Za-z0-9_$]*(%s)", words)
}


test_that("no brand panel writes a bind flag through dataset", {
  expect_true(dir.exists(.bfs_js_dir))
  files <- list.files(.bfs_js_dir, pattern = "\\.js$", full.names = TRUE)
  expect_gt(length(files), 0L)

  offenders <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    code <- lines[!grepl("^\\s*(//|\\*|/\\*)", lines)]
    hits <- grep(.bfs_flag_pattern(), code)
    if (length(hits)) {
      offenders <- c(offenders, sprintf("%s: %s", basename(f),
                                        trimws(code[hits])))
    }
  }
  expect_identical(offenders, character(0))
})


test_that("the scan would catch a differently named flag", {
  # The regression that motivated widening the pattern: womInit carried
  # exactly this shape and the old scan passed.
  sample <- c('    if (!panel || panel.dataset.womInit === "1") return;',
              '    panel.dataset.brReachInit = "1";',
              '    el.dataset.pfFpBound = "1";')
  expect_equal(length(grep(.bfs_flag_pattern(), sample)), 3L)
  # A dataset read that is real state, not a bind guard, must not trip it.
  expect_equal(length(grep(.bfs_flag_pattern(),
                           c("card.dataset.demoQIdx", "el.dataset.pfFocal"))), 0L)
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


test_that("every known site binds on a JS property instead", {
  sites <- list(
    list(file = "brand_audience_lens_panel.js", expr = "panel._alBound"),
    list(file = "brand_portfolio_panel.js",     expr = "table._pfFpBound"),
    list(file = "brand_wom_panel.js",           expr = "panel._womBound"),
    list(file = "brand_branded_reach_panel.js", expr = "panel._brReachBound")
  )
  for (s in sites) {
    txt <- readLines(file.path(.bfs_js_dir, s$file), warn = FALSE)
    expect_true(any(grepl(paste0(s$expr, " === true"), txt, fixed = TRUE)),
                info = s$file)
    expect_true(any(grepl(paste0(s$expr, " = true"), txt, fixed = TRUE)),
                info = s$file)
  }
})
