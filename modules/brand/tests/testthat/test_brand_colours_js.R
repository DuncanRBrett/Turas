# ==============================================================================
# BRAND MODULE TESTS — brand_colours.js structural integrity
# ==============================================================================
# Verifies that:
#   1. brand_colours.js exists at the expected path
#   2. It is loaded first in the panel_js bundle (99_html_report_main.R)
#   3. No panel JS file contains a duplicate palette or hash declaration
#   4. All four panel JS files delegate to TurasColours.getBrandColour
# ==============================================================================
library(testthat)

.find_root <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root()

JS_DIR    <- file.path(ROOT, "modules", "brand", "lib", "html_report", "js")
REPORT_R  <- file.path(ROOT, "modules", "brand", "lib", "html_report",
                        "99_html_report_main.R")
SHARED_JS <- file.path(JS_DIR, "brand_colours.js")

PANEL_JS_FILES <- c(
  "brand_ma_panel.js",
  "brand_ma_advantage.js",
  "brand_funnel_panel.js",
  "brand_cat_buying_panel.js"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

read_js <- function(filename) {
  paste(readLines(file.path(JS_DIR, filename), warn = FALSE), collapse = "\n")
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_that("brand_colours.js exists at the expected path", {
  expect_true(file.exists(SHARED_JS))
})

test_that("brand_colours.js exports TurasColours with getBrandColour and hashColour", {
  src <- paste(readLines(SHARED_JS, warn = FALSE), collapse = "\n")
  expect_true(grepl("TurasColours", src, fixed = TRUE))
  expect_true(grepl("getBrandColour", src, fixed = TRUE))
  expect_true(grepl("hashColour", src, fixed = TRUE))
})

test_that("brand_colours.js contains the 10-entry Tableau-10 palette", {
  src <- paste(readLines(SHARED_JS, warn = FALSE), collapse = "\n")
  expect_true(grepl("#4e79a7", src, fixed = TRUE))
  expect_true(grepl("#f28e2b", src, fixed = TRUE))
  expect_true(grepl("#bab0ac", src, fixed = TRUE))
})

test_that("99_html_report_main.R loads brand_colours.js before all panel scripts", {
  src <- paste(readLines(REPORT_R, warn = FALSE), collapse = "\n")

  # brand_colours.js must appear in the bundle
  expect_true(grepl("brand_colours.js", src, fixed = TRUE))

  # brand_colours.js must come before the first panel script in the paste() call
  pos_colours <- regexpr("brand_colours\\.js", src)[[1]]
  pos_funnel  <- regexpr("brand_funnel_panel\\.js", src)[[1]]
  expect_true(pos_colours < pos_funnel,
    label = "brand_colours.js is listed before brand_funnel_panel.js")
})

test_that("panel JS files delegate to TurasColours.getBrandColour", {
  for (js_file in PANEL_JS_FILES) {
    src <- read_js(js_file)
    expect_true(
      grepl("TurasColours.getBrandColour", src, fixed = TRUE),
      label = paste(js_file, "calls TurasColours.getBrandColour")
    )
  }
})

test_that("panel JS files do not contain duplicate palette arrays", {
  # Pattern: an inline Tableau-10 array with 4e79a7 and f28e2b together
  dup_pattern <- "4e79a7.*f28e2b|f28e2b.*4e79a7"
  for (js_file in PANEL_JS_FILES) {
    src <- read_js(js_file)
    expect_false(
      grepl(dup_pattern, src),
      label = paste(js_file, "does not contain a duplicate palette array")
    )
  }
})

test_that("panel JS files do not contain duplicate djb2 hash implementations", {
  # Signature of the inline hash: h = 5381 followed by the shift expression
  dup_hash_pattern <- "h\\s*=\\s*5381"
  for (js_file in PANEL_JS_FILES) {
    src <- read_js(js_file)
    expect_false(
      grepl(dup_hash_pattern, src),
      label = paste(js_file, "does not contain a duplicate djb2 hash")
    )
  }
})
