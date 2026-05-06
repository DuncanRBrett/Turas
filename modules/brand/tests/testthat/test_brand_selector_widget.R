# ==============================================================================
# Tests for the BrandSelector R-side HTML helpers.
# Covers: build_brand_selector_trigger(),
#         build_brand_selector_legend(),
#         build_brand_selector_toolbar_row(),
#         and the .bs_html_esc internal helper.
# ==============================================================================
library(testthat)

.find_root_bs <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_bs()

source(file.path(ROOT, "modules", "brand", "lib", "html_report", "panels",
                 "00_brand_selector_widget.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report", "panels",
                 "00_brand_selector_styling.R"))


# ------------------------------------------------------------------------------
# build_brand_selector_trigger
# ------------------------------------------------------------------------------

test_that("trigger emits a button with correct panel id and count", {
  html <- build_brand_selector_trigger("demographics", n_total = 13L)
  expect_match(html, 'class="bs-trigger"', fixed = TRUE)
  expect_match(html, 'data-bs-panel="demographics"', fixed = TRUE)
  expect_match(html, '(13/13)', fixed = TRUE)
  expect_match(html, 'aria-haspopup="true"', fixed = TRUE)
  expect_match(html, 'aria-expanded="false"', fixed = TRUE)
})

test_that("trigger label override is honoured", {
  html <- build_brand_selector_trigger("funnel", 5L, label = "Pick brands")
  expect_match(html, ">Pick brands<", fixed = TRUE)
})

test_that("trigger label is HTML-escaped", {
  html <- build_brand_selector_trigger("x", 0L, label = "<script>alert(1)</script>")
  expect_no_match(html, "<script>", fixed = TRUE)
  expect_match(html, "&lt;script&gt;", fixed = TRUE)
})

test_that("trigger refuses invalid panel_id", {
  expect_error(build_brand_selector_trigger("", 5L), "panel_id")
  expect_error(build_brand_selector_trigger(NA_character_, 5L), "panel_id")
  expect_error(build_brand_selector_trigger(c("a", "b"), 5L), "panel_id")
})

test_that("trigger refuses negative n_total", {
  expect_error(build_brand_selector_trigger("p", -1), "n_total")
})


# ------------------------------------------------------------------------------
# build_brand_selector_toolbar_row
# ------------------------------------------------------------------------------

test_that("toolbar row wraps trigger + extra chips with optional label", {
  trigger <- '<button class="bs-trigger">x</button>'
  cat_avg <- '<button class="cat-avg">Cat avg</button>'
  html <- build_brand_selector_toolbar_row(trigger,
                                           extra_chips = cat_avg,
                                           label = "BRANDS:")
  expect_match(html, 'class="bs-toolbar-row"', fixed = TRUE)
  expect_match(html, '<span class="bs-toolbar-label">BRANDS:</span>',
               fixed = TRUE)
  expect_match(html, "bs-trigger", fixed = TRUE)
  expect_match(html, "cat-avg", fixed = TRUE)
})

test_that("toolbar row label is suppressed when empty", {
  html <- build_brand_selector_toolbar_row("<x/>", label = "")
  expect_no_match(html, "bs-toolbar-label", fixed = TRUE)
})


# ------------------------------------------------------------------------------
# build_brand_selector_styles
# ------------------------------------------------------------------------------

test_that("style block opens with <style class='bs-styles'> and contains key selectors", {
  css <- build_brand_selector_styles()
  expect_match(css, '<style class="bs-styles">', fixed = TRUE)
  expect_match(css, ".bs-trigger",     fixed = TRUE)
  expect_match(css, ".bs-popover",     fixed = TRUE)
  expect_match(css, ".bs-popover-row", fixed = TRUE)
})
