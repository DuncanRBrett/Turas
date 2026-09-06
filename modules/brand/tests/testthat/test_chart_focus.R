# ==============================================================================
# Chart brands: the per-chart deviation from the header's comparison set.
#
# Stage 2 hid every per-panel brand filter, and with it the "Sync table and
# chart" toggle that let an analyst hide a brand from a chart while keeping it
# in the table. That capability is back as a control of its own. These tests
# hold the three properties that make it a deviation rather than a second
# selection, and the one property that keeps an exported chart honest:
#
#   1. It is offered only where a chart, a table and a chart-only visibility
#      map all exist. The four views that cannot narrow get nothing.
#   2. It can only narrow, and any header change resets it.
#   3. It is neither a focal control nor a brand-set control, so the
#      single-control census in test_single_brand_control.R still holds.
#   4. A deviating chart is marked, and the mark survives a capture while the
#      control itself does not.
#
# The behavioural half runs in headless Chrome, in
# modules/brand/tests/qa/drive_destinations.py: it drives the control, reads
# the chart and the table apart, and captures the chart area.
# ==============================================================================
library(testthat)

.find_root_cf <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT_CF <- .find_root_cf()
REPORT_CF <- file.path(ROOT_CF, "modules", "brand", "lib", "html_report")
PANELS_CF <- file.path(REPORT_CF, "panels")

source(file.path(PANELS_CF, "00_chart_focus_widget.R"))
# Sourced after the widget, so the guarded call inside it resolves and the
# MA chart section can be rendered for real rather than read as text.
source(file.path(PANELS_CF, "02_ma_panel.R"))

read_cf <- function(...) paste(readLines(file.path(...), warn = FALSE),
                               collapse = "\n")

n_cf <- function(html, needle) {
  m <- gregexpr(needle, html, fixed = TRUE)[[1]]
  if (length(m) == 1L && m[1L] == -1L) 0L else length(m)
}


# --- the widget itself --------------------------------------------------------

test_that("the widget emits one mount and one note, and they agree on scope", {
  html <- build_chart_focus_control("loyalty")
  expect_equal(n_cf(html, '<div class="br-cf" data-chartfocus="loyalty">'), 1L)
  expect_equal(n_cf(html, 'data-chartfocus-note="loyalty"'), 1L)
  # The note starts hidden: it claims nothing until a chart deviates.
  expect_match(html, 'class="br-cf-note" data-chartfocus-note="loyalty" hidden',
               fixed = TRUE)
})

test_that("the widget refuses a scope it cannot key on", {
  expect_error(build_chart_focus_control(""), "non-empty string")
  expect_error(build_chart_focus_control(NULL), "non-empty string")
  expect_error(build_chart_focus_control(c("a", "b")), "non-empty string")
})

test_that("the control is neither a focal control nor a brand-set control", {
  # The single-control rule is that one focal select and one brand-set
  # trigger are visible per category. This control is a third thing: it
  # selects no set of its own, only a subset of the header's. If it ever
  # borrowed either class it would break that census silently.
  html <- build_chart_focus_control("funnel")
  expect_false(grepl("bs-trigger", html, fixed = TRUE))
  expect_false(grepl("focus-select", html, fixed = TRUE))
  expect_false(grepl("focal-select", html, fixed = TRUE))
  expect_false(grepl("br-cmp-", html, fixed = TRUE))
})


# --- the styles have to survive a capture ------------------------------------

test_that("every chart-brands rule names its class with no ancestor", {
  # TurasPins re-parents a captured node out of its panel and its style
  # inliner skips values that look like defaults, so a rule scoped under a
  # panel class would look right on screen and be lost in a pin. The note is
  # the one element that has to come through a capture intact.
  css <- build_chart_focus_styles()
  lines <- strsplit(css, "\n", fixed = TRUE)[[1]]
  selectors <- trimws(sub("\\{\\s*$", "", grep("\\{\\s*$", lines, value = TRUE)))
  expect_gt(length(selectors), 5L)
  for (sel in selectors) {
    expect_match(sel, "^\\.br-cf", info = sel)
    # A descendant combinator would put a panel or destination class in
    # front of the rule. Only the input-plus-span pair inside the popover
    # is allowed a combinator, and it stays inside .br-cf-item.
    expect_false(grepl("^\\.br-cf[^ ]* +\\.", sel), info = sel)
  }
})

test_that("the note carries its own colour, weight and rail", {
  # capturePortableHtml copies computed values for a fixed property list. A
  # note that inherited its colour from the panel would come through a pin
  # as plain black text with no rail, which is exactly the case where a
  # reader most needs to see it.
  css <- build_chart_focus_styles()
  note <- sub(".*\\.br-cf-note \\{", "", css)
  note <- sub("\\}.*", "", note)
  for (prop in c("font-size", "font-weight", "color", "background",
                 "border-left", "padding")) {
    expect_match(note, prop, fixed = TRUE, info = prop)
  }
  # No CSS variable: a panel-scoped variable resolves to nothing once the
  # captured HTML sits in a body-level container.
  expect_false(grepl("var(--", note, fixed = TRUE))
})

test_that("the styles reach the page, from the widget that emits the markup", {
  pb <- read_cf(REPORT_CF, "03_page_builder.R")
  expect_match(pb, "build_chart_focus_styles()", fixed = TRUE)
})


# --- scope: only where a chart, a table and a chart-only map all exist --------

test_that("the mount is emitted at exactly the sites that can deviate", {
  # One call per chart that keeps a chart-only visibility map behind it:
  # the funnel slope and bar chart, the attribute and CEP dot charts, the
  # Brand Summary bar chart, the three stacked-segment charts, and Word of
  # Mouth. Eight charts, six call sites, because two builders serve more
  # than one scope.
  files <- list.files(PANELS_CF, pattern = "\\.R$", full.names = TRUE)
  sites <- list()
  for (f in files) {
    n <- n_cf(read_cf(f), "build_chart_focus_control(")
    if (n > 0) sites[[basename(f)]] <- n
  }
  expect_equal(sites[["03_funnel_panel_chart.R"]], 1L)
  expect_equal(sites[["02_ma_panel.R"]], 1L)
  expect_equal(sites[["05_wom_panel.R"]], 1L)
  expect_equal(sites[["08_cat_buying_panel.R"]], 3L)
  # Nothing else. A seventh site would mean a control on a view whose
  # chart follows the table, which is a control that does nothing.
  expect_equal(sort(names(sites)),
               sort(c("02_ma_panel.R", "03_funnel_panel_chart.R",
                      "05_wom_panel.R", "08_cat_buying_panel.R")))
})

test_that("the four views that cannot narrow carry no control", {
  # Category Context, Dirichlet Norms, Duplication of Purchase and Shopper
  # Behaviour show the whole category whatever the comparison set is, and
  # each says so in its own caption. A brand control on any of them would
  # be the dead control this whole change exists to remove.
  shopper <- read_cf(PANELS_CF, "08_cat_buying_panel_shopper.R")
  expect_equal(n_cf(shopper, "build_chart_focus_control("), 0L)
  cb <- read_cf(PANELS_CF, "08_cat_buying_panel.R")
  for (fn in c(".cb_context_tab", ".cb_norms_tab", ".cb_dop_tab")) {
    body <- sub(paste0(".*", fn, " <- function"), "", cb)
    body <- sub("\n[.a-zA-Z_]+ <- function.*", "", body)
    expect_false(grepl("build_chart_focus_control(", body, fixed = TRUE),
                 info = fn)
  }
})

test_that("the MA mount is built for the two matrices and no other sub-tab", {
  # .ma_chart_placeholder is the only MA site, and it is called twice:
  # Brand Attributes and Category Entry Points. Mental Advantage and
  # Headline Metrics read the TABLE hidden set for their charts, so they
  # have no chart-only set to deviate with.
  ma <- read_cf(PANELS_CF, "02_ma_panel.R")
  expect_equal(n_cf(ma, '.ma_chart_placeholder(stim = "attributes"'), 1L)
  expect_equal(n_cf(ma, '.ma_chart_placeholder(stim = "ceps"'), 1L)
  expect_equal(n_cf(ma, ".ma_chart_placeholder(stim ="), 2L)
  html <- .ma_chart_placeholder("attributes", NULL)
  expect_match(html, 'data-chartfocus="attributes"', fixed = TRUE)
  expect_match(html, 'data-chartfocus-note="attributes"', fixed = TRUE)
})

test_that("every emission site is guarded, so a lone-file test still renders", {
  # The panel tests source one panel file at a time. An unguarded call would
  # turn every one of them red the moment this widget moved.
  for (f in c("03_funnel_panel_chart.R", "02_ma_panel.R", "05_wom_panel.R",
              "08_cat_buying_panel.R")) {
    txt <- read_cf(PANELS_CF, f)
    guards <- n_cf(txt, 'exists("build_chart_focus_control", mode = "function")')
    calls  <- n_cf(txt, "build_chart_focus_control(")
    expect_equal(guards, calls, info = f)
  }
})


# --- the JavaScript contract -------------------------------------------------

test_that("the control's script is in the bundle", {
  expect_true(file.exists(file.path(REPORT_CF, "js", "brand_chart_focus.js")))
  main <- read_cf(REPORT_CF, "99_html_report_main.R")
  expect_match(main, '.resolve_js("brand_chart_focus.js")', fixed = TRUE)
})

test_that("the chart-only setter exists and stays inside its own panel", {
  js <- read_cf(REPORT_CF, "js", "brand_selector_dropdown.js")
  expect_match(js, "setHiddenChart: function (codes)", fixed = TRUE)
  expect_match(js, "getBrands: function ()", fixed = TRUE)
  # Split mode only: a unified panel has no separate chart set, so there is
  # nothing there to deviate.
  expect_match(js, 'if (state.mode !== "split") return false;', fixed = TRUE)
  # It must not publish. A chart deviation that reached the category store
  # would leak into the header and into every sibling host, which is the
  # duplication Stage 2 removed.
  setter <- sub(".*setHiddenChart: function \\(codes\\) \\{", "", js)
  setter <- sub("\\n      \\},.*", "", setter)
  expect_false(grepl("publishCategoryChange", setter, fixed = TRUE))
  expect_false(grepl("setCategoryHidden", setter, fixed = TRUE))
  expect_false(grepl("CATEGORY_STORE", setter, fixed = TRUE))
})

test_that("the header remains the source of truth, in all three states", {
  js <- read_cf(REPORT_CF, "js", "brand_report.js")
  expect_match(js, "window.BrandChartFocus.refreshAll()", fixed = TRUE)
  # The all-brands branch used to return early. It must not, or a deviation
  # would survive that one header state and the report would show a chart
  # narrower than its table with nothing saying so.
  apply_fn <- sub(".*window.brApplyComparisonSet = function\\(group\\) \\{", "", js)
  apply_fn <- sub("\\n  \\};.*", "", apply_fn)
  expect_match(apply_fn, "refreshAll", fixed = TRUE)
  expect_false(grepl("setCategoryHidden(group, []);\n      return;", apply_fn,
                     fixed = TRUE))
})

test_that("each split-mode panel hands its handle to the control", {
  for (f in c("brand_funnel_panel.js", "brand_ma_panel.js",
              "brand_cat_buying_panel.js", "brand_wom_panel.js")) {
    js <- read_cf(REPORT_CF, "js", f)
    expect_match(js, "panel.__brChartSelector =", fixed = TRUE, info = f)
  }
  # And the control finds it by that one name.
  cf <- read_cf(REPORT_CF, "js", "brand_chart_focus.js")
  expect_match(cf, "el.__brChartSelector", fixed = TRUE)
})

test_that("the control can only narrow, never widen", {
  cf <- read_cf(REPORT_CF, "js", "brand_chart_focus.js")
  # The popover offers the brands the header shows, which is the panel's
  # brand list minus its table-hidden set.
  expect_match(cf, "if (hiddenTable.has(b.code)) return;", fixed = TRUE)
  # The published chart set is the union of the table-hidden set and the
  # unticked brands, so a brand the header excluded cannot come back.
  expect_match(cf, "handle.getHidden().forEach(function (c) { hidden.push(c); });",
               fixed = TRUE)
  # The focal brand stays in its own chart.
  expect_match(cf, "if (b.isFocal) { cb.checked = true; cb.disabled = true; }",
               fixed = TRUE)
})


# --- a deviating chart is marked, and the mark survives a capture ------------

test_that("the control is stripped from a capture and the note is not", {
  pins <- read_cf(REPORT_CF, "js", "brand_pins.js")
  interactive <- sub(".*var INTERACTIVE_SELECTORS = \\[", "", pins)
  interactive <- sub("\\].join.*", "", interactive)
  expect_match(interactive, "'.br-cf'", fixed = TRUE)
  # The note must not be an entry in the strip list. It is the only thing on
  # a captured chart that says why it shows fewer brands than its table.
  # The list does mention it in a comment, so the entry is what is tested.
  expect_false(grepl("'.br-cf-note'", interactive, fixed = TRUE))
  expect_false(grepl('".br-cf-note"', interactive, fixed = TRUE))
})

test_that("a capture carries the clause, and only when it carries the chart", {
  pins <- read_cf(REPORT_CF, "js", "brand_pins.js")
  expect_match(pins, "window.brChartDeviationClause", fixed = TRUE)
  expect_match(pins, "chartDeviation: chartDeviation", fixed = TRUE)
  # A table pinned on its own is not deviating from anything and must not
  # be labelled as though it were.
  expect_match(pins, "if (!includeChart || !clause) return title;", fixed = TRUE)
})

test_that("every capture path that pairs a chart with its table is covered", {
  # These are the pins and PNG exports that put a chart and a table on one
  # card. They are where a reader would otherwise get two views of the same
  # brands that disagree, with nothing to say why.
  for (f in c("brand_cat_buying_panel.js", "brand_ma_panel.js",
              "brand_funnel_panel.js", "brand_wom_panel.js")) {
    js <- read_cf(REPORT_CF, "js", f)
    expect_match(js, "brTitleWithChartDeviation", fixed = TRUE, info = f)
  }
  pins <- read_cf(REPORT_CF, "js", "brand_pins.js")
  # Once in brExecutePin and twice in the two PNG export paths. The
  # definition itself does not match: it reads "= function(title, ...".
  expect_equal(n_cf(pins, "window.brTitleWithChartDeviation("), 3L)
})

test_that("the note names both counts and what is missing", {
  cf <- read_cf(REPORT_CF, "js", "brand_chart_focus.js")
  expect_match(cf, '"Chart shows " + nChart + " of the " + nTable', fixed = TRUE)
  expect_match(cf, '" brands in the table. Hidden from the chart: "', fixed = TRUE)
  # And the trigger says the same thing in fewer words.
  expect_match(cf, '"Chart brands: " + nChart + " of " + st.shown.length',
               fixed = TRUE)
  expect_match(cf, '"Chart brands: same as table"', fixed = TRUE)
})


# --- the Excel export is coherent by construction, not by a new rule ---------

test_that("the Excel exporters walk tables, so a chart cannot reach them", {
  # _brExportPanel and the panel-local .xls writers all iterate table rows.
  # The table never deviates, so an exported sheet always matches the header
  # set and needs no note of its own. This test is here so the claim breaks
  # loudly if an exporter ever starts reading chart DOM.
  js <- read_cf(REPORT_CF, "js", "brand_report.js")
  export_fn <- sub(".*window._brExportPanel = function\\(panelId\\) \\{", "", js)
  export_fn <- sub("\\n  \\};.*", "", export_fn)
  expect_match(export_fn, 'panel.querySelectorAll("table")', fixed = TRUE)
  expect_false(grepl("chart", export_fn, fixed = TRUE))
})
