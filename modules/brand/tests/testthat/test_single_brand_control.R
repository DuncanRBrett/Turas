# ==============================================================================
# The single-brand-control rule.
#
# Duncan opened a Stage 2 report and found FOCAL BRAND twice on one page and
# two brand filters whose counts disagreed. Inside a category the reader gets
# exactly one focal control and exactly one brand-set control, in the header,
# and every panel's own copy stays in the DOM, driven by the header, but
# hidden.
#
# The structural half of the guarantee lives here. The visible half, that
# each per-panel copy really has no box on screen and that the rows a table
# shows are the brands the header names, is asserted in headless Chrome by
# modules/brand/tests/qa/drive_destinations.py.
# ==============================================================================
library(testthat)

.find_root_sbc <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT_SBC <- .find_root_sbc()
REPORT_SBC <- file.path(ROOT_SBC, "modules", "brand", "lib", "html_report")

source(file.path(ROOT_SBC, "modules", "brand", "R", "01b_section_insights.R"))
source(file.path(REPORT_SBC, "03_page_builder.R"))
source(file.path(REPORT_SBC, "panels", "00_brand_selector_widget.R"))

read_sbc <- function(...) paste(readLines(file.path(...), warn = FALSE),
                                collapse = "\n")

n_sbc <- function(html, needle) {
  m <- gregexpr(needle, html, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[1L] == -1L) 0L else length(m)
}


# --- the header carries one of each ------------------------------------------

controls_sbc <- function(config = list(focal_brand = "IPK",
                                       chip_default = "focal_only"),
                         brands = c("IPK", "ROB", "KNORR", "CART")) {
  cat_brands <- data.frame(BrandCode = brands, BrandLabel = brands,
                           stringsAsFactors = FALSE)
  build_br_category_controls("dss", "Dry Seasonings", config,
                             cat_results = list(cat_code = "DSS"),
                             category_choices = NULL,
                             cat_brands = cat_brands)
}

test_that("one focal select and one brand-set trigger, and no second copy", {
  html <- controls_sbc()
  expect_equal(n_sbc(html, 'class="br-focal-select"'), 1L)
  expect_equal(n_sbc(html, 'class="br-cmp-trigger"'), 1L)
  expect_equal(n_sbc(html, 'class="br-cmp-popover"'), 1L)
  # The two sit in one slot, so the reader has one place to go.
  expect_equal(n_sbc(html, 'data-slot="comparison"'), 1L)
})

test_that("the trigger names the state it is in, not a bare number", {
  # Duncan looked straight at the header and reported the brand selector
  # missing, because in its opening state the trigger read "Focal only",
  # which is a status line rather than a control. The word "Brands" now
  # stays on it in every state.
  focal_only <- controls_sbc()
  expect_match(focal_only,
               '<span class="br-cmp-text" data-group="dss">Brands: focal only</span>',
               fixed = TRUE)
  expect_match(focal_only, 'data-cmp-mode="focal"', fixed = TRUE)
  # The count badge starts hidden: the words already pin the number down in
  # the focal-only and all-brands states. It carries "shown of total", so
  # the value it is emitted with matches the state rather than a stray 0.
  expect_match(focal_only, '<span class="br-cmp-count" data-group="dss" hidden>1/4</span>',
               fixed = TRUE)
})

test_that("chip_default = all opens the header on all brands", {
  # chip_default is the analyst's Brand_Config setting for how much the
  # panels show on open. The one control inherits it rather than overriding
  # it, so the header and the config agree from the first paint.
  html <- controls_sbc(config = list(focal_brand = "IPK", chip_default = "all"))
  expect_match(html, 'data-cmp-mode="all"', fixed = TRUE)
  expect_match(html, '>Brands: all 4</span>', fixed = TRUE)
  expect_match(html, '<span class="br-cmp-count" data-group="dss" hidden>4/4</span>',
               fixed = TRUE)
  expect_match(html, 'class="br-cmp-mode active" data-cmp-set="all"', fixed = TRUE)
})

test_that("the word Brands is on the trigger in every state the JS can set", {
  # The R side emits two of the three states. The third, and the wording of
  # all three at runtime, is set by brApplyComparisonSet, so the strings are
  # read out of the JavaScript rather than trusted.
  js <- read_sbc(REPORT_SBC, "js", "brand_report.js")
  expect_match(js, '"Brands: focal only"', fixed = TRUE)
  expect_match(js, '"Brands: all "', fixed = TRUE)
  expect_match(js, '"Brands: focal + "', fixed = TRUE)
  # The compact form is deliberate. Measured in headless Chrome at 800
  # pixels, "Brands: focal and 14 others" takes the trigger to 210 pixels
  # and wraps the control bar; this one holds 161 and one line. The trigger
  # carries a title that spells the state out in words.
  expect_match(js, 'Showing the focal brand and ', fixed = TRUE)
  expect_match(js, 'Showing all ', fixed = TRUE)
  expect_match(js, 'Showing the focal brand only, of ', fixed = TRUE)
  # The badge still says something the words do not: how many of the
  # category's brands are on screen.
  expect_match(js, 'badge.textContent = String(shown) + "/" + String(total);',
               fixed = TRUE)
})


# --- no cap, and no silent reversal ------------------------------------------

test_that("the five-comparator cap is gone from the control", {
  # The cap came from a single-category tracker where every view is a chart.
  # Turas tables have always shown every brand, and chart legibility is the
  # per-chart Chart brands control's job, so the reason for it was designed
  # away rather than relaxed.
  js <- read_sbc(REPORT_SBC, "js", "brand_report.js")
  expect_false(grepl("CMP_MAX", js, fixed = TRUE))
  html <- controls_sbc()
  expect_false(grepl("up to five", html, fixed = TRUE))
  expect_match(html, 'Or tick the brands to compare with the focal brand',
               fixed = TRUE)
})

test_that("ticking a comparator can never untick it again", {
  # The cap was enforced by setting box.checked = false, so a reader ticking
  # a sixth brand watched the tick reverse under their finger with no
  # message. That is the silent failure TRS exists to prevent. This guard is
  # scoped to the one function a checkbox click enters: the focal change and
  # the mode buttons do clear boxes, and both are consequences of a different
  # action the reader just asked for, not a reversal of the click just made.
  js <- read_sbc(REPORT_SBC, "js", "brand_report.js")
  start <- regexpr("window.brComparisonSetChanged = function", js, fixed = TRUE)
  expect_true(start > 0)
  rest <- substring(js, start)
  end <- regexpr("\n  };", rest, fixed = TRUE)
  expect_true(end > 0)
  body <- substring(rest, 1, end)
  expect_false(grepl("checked = false", body, fixed = TRUE))
  expect_false(grepl("checked=false", body, fixed = TRUE))
  # The one early return left is the guard for a checkbox with no popover
  # above it, which is a DOM that cannot exist in a rendered report. It
  # carries no count and no threshold.
  expect_false(grepl(".length >", body, fixed = TRUE))
  expect_false(grepl(".length >=", body, fixed = TRUE))
})

test_that("all brands stays a mode rather than every box ticked", {
  # The two are not the same claim, and the mode is what a category-wide
  # view publishes, so nothing may derive one from the other.
  js <- read_sbc(REPORT_SBC, "js", "brand_report.js")
  expect_match(js, 'window.BrandSelector.setCategoryHidden(group, []);',
               fixed = TRUE)
  # cmpState only ever promotes to "compare" or demotes to "focal"; it never
  # infers "all" from the checkboxes.
  expect_match(js, 'if (mode !== "all") mode = comparators.length > 0 ? "compare" : "focal";',
               fixed = TRUE)
})

test_that("the three states are all reachable from the popover", {
  html <- controls_sbc()
  expect_match(html, 'data-cmp-set="focal"', fixed = TRUE)
  expect_match(html, 'data-cmp-set="all"', fixed = TRUE)
  # One checkbox per brand, the focal one locked on.
  expect_equal(n_sbc(html, 'class="br-cmp-check"'), 4L)
  expect_equal(n_sbc(html, 'value="IPK" disabled checked'), 1L)
})


# --- every per-panel copy is marked ------------------------------------------

test_that("the shared brand-filter trigger is marked wherever it is built", {
  expect_match(build_brand_selector_trigger("demographics", 13L),
               'class="bs-trigger br-header-governed"', fixed = TRUE)
})

test_that("every per-panel focal control is marked", {
  # One assertion per emission site. The count guard below is what stops a
  # sixth site being added without a mark.
  expect_match(read_sbc(REPORT_SBC, "panels", "02_ma_panel.R"),
               '<span class="ma-focus-pick br-header-governed">', fixed = TRUE)
  expect_match(read_sbc(REPORT_SBC, "panels", "03_funnel_panel.R"),
               '<div class="fn-focus-bar br-header-governed">', fixed = TRUE)
  expect_match(read_sbc(REPORT_SBC, "panels", "05_wom_panel.R"),
               '<div class="wom-focus-bar br-header-governed">', fixed = TRUE)
  expect_match(read_sbc(REPORT_SBC, "panels", "08_cat_buying_panel.R"),
               '<div class="cb-focus-bar br-header-governed">', fixed = TRUE)
  expect_match(read_sbc(REPORT_SBC, "panels", "11_demographics_panel.R"),
               'demo-focal-row br-header-governed', fixed = TRUE)
})

test_that("no unmarked focal control has appeared in a panel", {
  # A focal select emitted anywhere in the panel layer without a
  # br-header-governed wrapper would be the second FOCAL BRAND on the page
  # that this whole change exists to remove.
  files <- list.files(file.path(REPORT_SBC, "panels"), pattern = "\\.R$",
                      full.names = TRUE)
  sites <- character(0)
  for (f in files) {
    txt <- readLines(f, warn = FALSE)
    hits <- grep('class="(ma|fn|wom|cb)-focus-select|class="demo-focal-select',
                 txt, value = TRUE)
    if (length(hits) > 0) sites <- c(sites, paste(basename(f), hits))
  }
  expect_equal(length(sites), 5L,
               info = paste("focal-select emission sites:",
                            paste(sites, collapse = " | ")))
})

test_that("the hiding rule names the class alone, with no ancestor", {
  # A rule scoped under .br-destination would let the control reappear in a
  # pin or a PNG, because TurasPins re-parents the captured node out of the
  # destination and its inliner skips values that look like defaults.
  css <- read_sbc(REPORT_SBC, "03_page_builder.R")
  expect_match(css, '.br-header-governed { display: none !important; }',
               fixed = TRUE)
  expect_false(grepl('[^ ]+ \\.br-header-governed \\{', css))
})


# --- the header still drives every panel, which is why hiding is safe --------

test_that("the header reaches every panel that carries a focal select", {
  js <- read_sbc(REPORT_SBC, "js", "brand_report.js")
  for (sel in c(".fn-focus-select", ".ma-focus-select", ".cb-focus-select",
                ".wom-focus-select", ".demo-focal-select")) {
    expect_match(js, sel, fixed = TRUE, info = sel)
  }
  for (sel in c(".fn-panel[data-category-key=", ".ma-panel[data-category-key=",
                ".cb-panel[data-cb-cat-code=", ".wom-panel[data-cat-code=",
                ".demo-panel[id=")) {
    expect_match(js, sel, fixed = TRUE, info = sel)
  }
})

test_that("the opening state is published after the panels have registered", {
  js <- read_sbc(REPORT_SBC, "js", "brand_report.js")
  # categoryBrands() is a union over registered subscribers, so publishing
  # on DOMContentLoaded would find nothing: brand_report.js is first in the
  # bundle and its handler runs before every panel's.
  expect_match(js, "brApplyAllComparisonSets", fixed = TRUE)
  expect_match(js, 'window.addEventListener("load"', fixed = TRUE)
})

test_that("the views that cannot narrow say so on their face", {
  # cb-norms, cb-dop, cb-context and cb-shopper do not respond to the brand
  # set: the cat-buying selector writes only the brands, loyalty, dist and
  # heaviness scopes. Leaving a filter control on them was what made the
  # Dirichlet Norms tab read "1 of 11" beside a table of eleven brands.
  cb <- read_sbc(REPORT_SBC, "panels", "08_cat_buying_panel.R")
  # Three notes in this file: Category Context, Dirichlet Norms and
  # Duplication of Purchase. Shopper Behaviour carries the fourth.
  expect_equal(n_sbc(cb, "brand comparison set"), 3L)
  expect_equal(n_sbc(read_sbc(REPORT_SBC, "panels",
                              "08_cat_buying_panel_shopper.R"),
                     "brand comparison set"), 1L)
})
