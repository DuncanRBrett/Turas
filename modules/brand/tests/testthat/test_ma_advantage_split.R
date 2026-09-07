# ==============================================================================
# Mental Advantage renders in two parts, one host each.
#
# The impact map's destination summary puts the MA Metrics headline, Category
# Entry Points and the Mental Advantage quadrant and action list in Mental
# Availability's main view, and the full Mental Advantage matrix, the
# buyer-gap diagnostic and the MA methodology in its Advanced drawer. A
# sub-panel cannot be in two tiers at once, so the panel emits the two parts
# separately and the page builder gives each its own leaf.
#
# What is covered here, at the fragment level, because the browser drives are
# one level above it:
#   - each part holds its own views and none of the other's;
#   - each part carries only the controls that govern what it holds;
#   - build_ma_panel_html() routes "advantage_detail" to the detail part,
#     leaves the sub-tab visible, and gives the host its own id;
#   - the marker 01_data_transformer.R tests on tells the two apart.
# ==============================================================================
library(testthat)

.find_root_mas <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT_MAS <- .find_root_mas()

PANELS_MAS <- file.path(ROOT_MAS, "modules", "brand", "lib", "html_report",
                        "panels")
source(file.path(PANELS_MAS, "00_json_island.R"))
source(file.path(PANELS_MAS, "00_brand_selector_widget.R"))
source(file.path(PANELS_MAS, "00_chart_focus_widget.R"))
source(file.path(PANELS_MAS, "02_ma_panel_advantage.R"))
source(file.path(PANELS_MAS, "02_ma_panel_chart.R"))
source(file.path(PANELS_MAS, "02_ma_panel_table.R"))
source(file.path(PANELS_MAS, "02_ma_panel.R"))

has_mas <- function(html, needle) grepl(needle, html, fixed = TRUE)

# The smallest panel data the advantage builders read: the available stimuli
# and the threshold for the legend, a focal view on one stimulus so the
# buyer-gap section renders, and enough config for the focal label.
mk_adv_pd <- function(stims = c("ceps", "attributes"), focal_view = TRUE) {
  fv <- if (focal_view)
    list(by_brand = list(IPK = list(rows = list())), rows = list()) else NULL
  block <- function() list(focal_view = fv, cells = list(),
                           brand_codes = c("IPK", "ROB"))
  pd <- list(
    meta = list(focal_brand_code = "IPK", n_respondents = 200L),
    config = list(focal_brand_code = "IPK",
                  focal_brand_name = "Ina Paarman's Kitchen",
                  brand_codes = c("IPK", "ROB"),
                  brand_names = c("Ina Paarman's Kitchen", "Robertsons"),
                  category_label = "Dry Seasonings"),
    advantage = list(available_stims = stims, default_stim = stims[1],
                     threshold_pp = 5))
  for (st in stims) pd$advantage[[st]] <- block()
  pd
}


test_that("the main part holds the quadrant and the action list, and no matrix", {
  html <- build_ma_advantage_section(mk_adv_pd(), part = "main")
  expect_true(has_mas(html, 'data-ma-adv-part="main"'))
  expect_true(has_mas(html, 'data-ma-adv-view="quadrant"'))
  expect_true(has_mas(html, 'data-ma-adv-view="actions"'))
  expect_false(has_mas(html, 'data-ma-adv-view="matrix"'))
  expect_false(has_mas(html, 'class="ma-section ma-adv-focal-view"'))
  # The intro sits with the first thing a reader meets, not with the drawer.
  expect_true(has_mas(html, 'class="ma-adv-intro"'))
})

test_that("the detail part holds the matrix and the buyer-gap view, and no quadrant", {
  html <- build_ma_advantage_section(mk_adv_pd(), part = "detail")
  expect_true(has_mas(html, 'data-ma-adv-part="detail"'))
  expect_true(has_mas(html, 'data-ma-adv-view="matrix"'))
  expect_true(has_mas(html, 'data-ma-focal-view="root"'))
  expect_false(has_mas(html, 'data-ma-adv-view="quadrant"'))
  expect_false(has_mas(html, 'data-ma-adv-view="actions"'))
  expect_false(has_mas(html, 'class="ma-adv-intro"'))
})

test_that("each part carries only the controls that govern what it holds", {
  main   <- build_ma_advantage_section(mk_adv_pd(), part = "main")
  detail <- build_ma_advantage_section(mk_adv_pd(), part = "detail")
  # Show chart governs the quadrant.
  expect_true(has_mas(main, 'data-ma-action="adv-show-chart"'))
  expect_false(has_mas(detail, 'data-ma-action="adv-show-chart"'))
  # Show counts and the Excel export govern the matrix.
  expect_true(has_mas(detail, 'data-ma-action="adv-show-counts"'))
  expect_false(has_mas(main, 'data-ma-action="adv-show-counts"'))
  expect_true(has_mas(detail, 'class="export-btn ma-export-btn"'))
  expect_false(has_mas(main, 'class="export-btn ma-export-btn"'))
  # The stimulus toggle governs both, so both carry one. The two are kept in
  # step by turas:brand-ma-stim-change; drive_chrome.py drives that.
  for (h in list(main, detail)) {
    expect_true(has_mas(h, 'data-ma-action="adv-stim"'))
    expect_true(has_mas(h, 'data-ma-adv-stim="ceps"'))
    expect_true(has_mas(h, 'data-ma-adv-stim="attributes"'))
    # A pin and a PNG each, and a tooltip and a legend each, because both
    # have hover targets and both colour by the diverging palette.
    expect_true(has_mas(h, "ma-pin-dropdown-btn"))
    expect_true(has_mas(h, "ma-png-btn"))
    expect_true(has_mas(h, "ma-adv-tooltip"))
    expect_true(has_mas(h, "ma-adv-legend"))
  }
})

test_that("the methodology follows the matrix into the detail part", {
  main   <- build_ma_advantage_section(mk_adv_pd(), part = "main")
  detail <- build_ma_advantage_section(mk_adv_pd(), part = "detail")
  # .ma_adv_about() renders the mental_advantage_methodology callout when the
  # registry helper is loaded, and an empty string when it is not. Either way
  # the main part must not carry it, and whatever it produces belongs to the
  # tier that holds the matrix it explains.
  meth <- .ma_adv_about(mk_adv_pd()$advantage)
  if (nzchar(meth)) {
    expect_true(has_mas(detail, meth))
    expect_false(has_mas(main, meth))
  } else {
    succeed("no callout registry loaded in this test process")
  }
})

test_that("the buyer-gap view is withheld when there is no focal view to show", {
  html <- build_ma_advantage_section(mk_adv_pd(focal_view = FALSE),
                                     part = "detail")
  expect_false(has_mas(html, 'data-ma-focal-view="root"'))
  # The matrix is still there, so the detail leaf is not empty.
  expect_true(has_mas(html, 'data-ma-adv-view="matrix"'))
})

test_that("one stimulus means no toggle, in either part", {
  for (p in c("main", "detail")) {
    html <- build_ma_advantage_section(mk_adv_pd(stims = "ceps"), part = p)
    expect_false(has_mas(html, 'data-ma-action="adv-stim"'), info = p)
  }
})


# --- what build_ma_panel_html() does with the new only_tab value ------------

mk_panel_pd <- function() {
  pd <- mk_adv_pd()
  pd$ceps <- list(codes = c("CEP01"), labels = c("First"))
  pd$attributes <- list(codes = c("ATT01"), labels = c("First"))
  pd
}

test_that("advantage_detail is the advantage sub-tab, visible, on its own host", {
  pd <- mk_panel_pd()
  detail <- build_ma_panel_html(pd, category_code = "dss",
                                only_tab = "advantage_detail",
                                island = FALSE, island_host = "ma-dss")
  main <- build_ma_panel_html(pd, category_code = "dss",
                              only_tab = "advantage",
                              island = FALSE, island_host = "ma-dss")
  # The sub-tab keeps its own name, because activateHost() in brand_report.js
  # routes by clicking .ma-subtab-btn[data-ma-subtab-target="advantage"].
  expect_true(has_mas(detail, '<div class="ma-subtab" data-ma-subtab="advantage">'))
  expect_true(has_mas(main, '<div class="ma-subtab" data-ma-subtab="advantage">'))
  # Neither ships hidden: each is the only sub-tab its host renders.
  expect_false(has_mas(detail, 'data-ma-subtab="advantage" hidden'))
  # Distinct host ids, so the two never collide in one category panel.
  expect_true(has_mas(detail, 'id="ma-dss-advantage_detail"'))
  expect_true(has_mas(main, 'id="ma-dss-advantage"'))
  # And the part marker, which is what 01_data_transformer.R tests on: the
  # sub-tab name is shared, so it cannot be the presence test.
  expect_true(has_mas(detail, 'data-ma-adv-part="detail"'))
  expect_true(has_mas(main, 'data-ma-adv-part="main"'))
  expect_false(has_mas(main, 'data-ma-adv-part="detail"'))
})

test_that("no advantage data means neither part registers", {
  pd <- mk_panel_pd()
  pd$advantage <- NULL
  for (tab in c("advantage", "advantage_detail")) {
    html <- build_ma_panel_html(pd, category_code = "dss", only_tab = tab,
                                island = FALSE, island_host = "ma-dss")
    # 01_data_transformer.R keys the panel on these two markers, so a host
    # that emits neither is never registered and the leaf never renders.
    # That is what keeps Mental Availability's Advanced drawer hidden on a
    # study with no advantage block.
    expect_false(has_mas(html, 'data-ma-adv-part="detail"'), info = tab)
    expect_false(has_mas(html, 'data-ma-subtab="advantage"'), info = tab)
  }
})
