# ==============================================================================
# TEST: the Dirichlet renderers reach the Category Buying panel
# ==============================================================================
# b70ba905 (2026-04-21) split the monolithic cat-buying panel into panel /
# chart / table / styling files. Four finished renderers kept their
# definitions and lost their call sites in the move, so the Dirichlet norms
# table, the Double Jeopardy scatter, the SCR bars and the focal KPI strip
# reached no visible surface in the HTML report between then and now.
#
# These tests pin the call sites. Unlike test_cat_buying_panel.R they source
# the chart, table and styling files as well, so an "exists()" guard in the
# panel can no longer make a missing surface look like a pass.
# ==============================================================================

library(testthat)

local({
  find_root <- function() {
    d <- getwd()
    for (i in 1:10) {
      if (file.exists(file.path(d, "launch_turas.R")) ||
          file.exists(file.path(d, "CLAUDE.md"))) return(d)
      d <- dirname(d)
    }
    getwd()
  }
  root <- find_root()
  pdir <- file.path(root, "modules", "brand", "lib", "html_report", "panels")
  for (f in c("00_json_island.R",
              "00_brand_selector_widget.R",
              "00_brand_selector_styling.R",
              "08_cat_buying_panel_styling.R",
              "08_cat_buying_panel_chart.R",
              "08_cat_buying_panel_table.R",
              "08_cat_buying_panel.R")) {
    source(file.path(pdir, f), local = FALSE)
  }
})


.cbds_panel_data <- function(dj_flags = c("over", "on_line", "under"),
                              dirichlet_status = "PASS") {
  norms_tbl <- data.frame(
    BrandCode           = c("A", "B", "C"),
    Penetration_Obs_Pct = c(65, 45, 30),
    Penetration_Exp_Pct = c(60, 48, 32),
    Penetration_Dev_Pct = c(8, -6, -6),
    BuyRate_Obs         = c(4.2, 3.1, 2.8),
    BuyRate_Exp         = c(4.0, 3.3, 2.9),
    BuyRate_Dev_Pct     = c(5, -6, -3),
    SCR_Obs_Pct         = c(42, 30, 25),
    SCR_Exp_Pct         = c(40, 32, 27),
    SCR_Dev_Pct         = c(5, -6, -7),
    Pct100Loyal_Obs     = c(18, 10, 8),
    Pct100Loyal_Exp     = c(15, 12, 9),
    Pct100Loyal_Dev_Pct = c(20, -17, -11),
    DJ_Flag             = dj_flags,
    stringsAsFactors    = FALSE
  )

  dirichlet <- if (identical(dirichlet_status, "REFUSED")) {
    list(status = "REFUSED", code = "CALC_DIRICHLET_FAILED",
         message = "test refusal")
  } else {
    list(
      status           = "PASS",
      target_months    = 3L,
      longer_months    = 12L,
      category_metrics = list(penetration = 0.55, mean_purchases = 4.2,
                              n_buyers = 165L, n_respondents = 300L),
      norms_table      = norms_tbl,
      dj_curve         = list(x_grid = seq(0.2, 0.8, length.out = 20),
                              y_fit_scr = seq(25, 45, length.out = 20),
                              y_fit_w   = seq(2.5, 4.5, length.out = 20),
                              method = "NBDdirichlet"),
      metrics_summary  = list(focal_brand = "A", focal_scr_obs = 42,
                              focal_scr_exp = 40, focal_pen_obs = 65,
                              focal_pen_exp = 60, focal_loyal_obs = 18,
                              focal_loyal_exp = 15, n_brands = 3L),
      warnings         = character(0)
    )
  }

  list(
    cat_name        = "Test Category",
    category_code   = "TST",
    focal_brand     = "A",
    focal_colour    = "#1A5276",
    target_months   = 3L,
    longer_months   = 12L,
    dirichlet_norms = dirichlet,
    buyer_heaviness = list(
      status = "PASS",
      brand_heaviness = data.frame(
        BrandCode = c("A", "B", "C"), Heavy_Pct = c(40, 35, 30),
        Medium_Pct = c(35, 35, 35), Light_Pct = c(25, 30, 35),
        WBar_Brand = c(4.5, 3.2, 2.8), WBar_Category = 3.5,
        WBar_Gap = c(1.0, -0.3, -0.7),
        NaturalMonopolyIndex = c(71, 86, 100),
        Brand_Buyers_n = c(165L, 115L, 75L),
        stringsAsFactors = FALSE),
      category_buyer_mix = data.frame(
        Tier = c("Light", "Medium", "Heavy"), Pct = c(33, 34, 33),
        n = c(55L, 56L, 54L), stringsAsFactors = FALSE),
      metrics_summary = list(focal_brand = "A", focal_nmi = 71,
                             focal_wbar = 4.5, focal_wbar_gap = 1.0)
    ),
    cat_buying_frequency = list(status = "PASS", pct_buyers = 55.0,
                                mean_freq = 2.4, n_respondents = 300L),
    repertoire = list(status = "PASS", dop_deviation_matrix = NULL,
                      dop_D_coefficient = 1.8),
    brand_labels = c(A = "Alpha", B = "Bravo", C = "Charlie")
  )
}


#' Brand codes carrying a label in the SCR view of the Double Jeopardy scatter
.cbds_scatter_labels <- function(html) {
  scr <- regmatches(html, regexpr(
    '(?s)<div data-dj-yaxis="scr">.*?<div data-dj-yaxis="w"', html, perl = TRUE))
  if (!length(scr) || !nzchar(scr)) return(character(0))
  groups <- regmatches(scr, gregexpr('(?s)<g data-brand="[^"]*">.*?</g>', scr,
                                     perl = TRUE))[[1]]
  keep <- grepl("cb-brand-label", groups, fixed = TRUE)
  sub('(?s)^<g data-brand="([^"]*)">.*', "\\1", groups[keep], perl = TRUE)
}


# ------------------------------------------------------------------------------
# The four renderers reach the HTML
# ------------------------------------------------------------------------------

test_that("the norms table renders as element markup, not only as CSS", {
  html <- render_cat_buying_panel(.cbds_panel_data())
  expect_true(grepl('<table class="cb-norms-table">', html, fixed = TRUE))
  # The class also appears inside the <style> block; strip it and the element
  # markup must still be there.
  body <- gsub("<style>.*?</style>", "", html)
  expect_true(grepl('class="cb-norms-table"', body, fixed = TRUE))
  expect_true(grepl("100% Loyals", body, fixed = TRUE))
})


test_that("the Double Jeopardy scatter renders with both y-axis views", {
  html <- render_cat_buying_panel(.cbds_panel_data())
  expect_equal(length(gregexpr('class="cb-dj-svg"', html, fixed = TRUE)[[1]]), 2L)
  expect_true(grepl('data-dj-yaxis="scr"', html, fixed = TRUE))
  expect_true(grepl('data-dj-yaxis="w"', html, fixed = TRUE))
  expect_true(grepl("_cbDJToggle('cb-dj-TST','scr'", html, fixed = TRUE))
})


test_that("the scatter labels every brand off the Double Jeopardy line", {
  html <- render_cat_buying_panel(.cbds_panel_data(
    dj_flags = c("on_line", "over", "under")))
  codes <- .cbds_scatter_labels(html)
  # A is focal (always labelled), B is over, C is under. None on line.
  expect_setequal(codes, c("A", "B", "C"))
})


test_that("an on-line non-focal brand carries no scatter label", {
  html <- render_cat_buying_panel(.cbds_panel_data(
    dj_flags = c("over", "on_line", "on_line")))
  codes <- .cbds_scatter_labels(html)
  expect_setequal(codes, "A")
})


test_that("the SCR bar chart renders", {
  html <- render_cat_buying_panel(.cbds_panel_data())
  expect_true(grepl('class="cb-scr-svg"', html, fixed = TRUE))
})


test_that("the KPI strip renders the focal expected values as sub-labels", {
  html <- render_cat_buying_panel(.cbds_panel_data())
  expect_true(grepl('data-kpi="scr"', html, fixed = TRUE))
  expect_true(grepl('data-kpi="loyal"', html, fixed = TRUE))
  expect_true(grepl("exp 40%", html, fixed = TRUE))
  expect_true(grepl("exp 15%", html, fixed = TRUE))
})


test_that("the KPI strip sub-label matches the JSON payload the JS swaps in", {
  # The focal switcher writes kd.scr_exp straight into [data-kpi-sub]. If the
  # server-rendered sub-label is punctuated differently the chip changes shape
  # the first time a reader picks another brand.
  pd <- .cbds_panel_data()
  html <- render_cat_buying_panel(pd)
  sub_txt <- regmatches(
    html, regexpr('data-kpi="scr">.*?<span data-kpi-sub>[^<]*</span>', html))
  rendered <- sub('.*<span data-kpi-sub>([^<]*)</span>', "\\1", sub_txt)
  json <- .cb_kpi_json_script(pd$dirichlet_norms, pd$buyer_heaviness, "TST")
  expect_true(grepl(sprintf('"scr_exp":"%s"', rendered), json, fixed = TRUE))
})


test_that("the KPI strip is outside every sub-tab so it stays readable", {
  html <- render_cat_buying_panel(.cbds_panel_data())
  before_first_tab <- sub('<div class="cb-subtab".*', "", html)
  expect_true(grepl('class="cb-kpi-strip"', before_first_tab, fixed = TRUE))
})


test_that("the category-buyer chip is dropped when the share is unavailable", {
  pd <- .cbds_panel_data()
  pd$cat_buying_frequency$pct_buyers <- NA_real_
  html <- render_cat_buying_panel(pd)
  expect_false(grepl("% Category buyers", html, fixed = TRUE))
  # The rest of the strip still renders.
  expect_true(grepl('data-kpi="scr"', html, fixed = TRUE))
})


test_that("the Dirichlet Norms sub-tab is in the nav and holds the surfaces", {
  html <- render_cat_buying_panel(.cbds_panel_data())
  expect_true(grepl('data-cb-tab="norms">Dirichlet Norms</button>', html,
                    fixed = TRUE))
  tab <- regmatches(html, regexpr('<div class="cb-subtab" data-cb-tab="norms" hidden>.*?<div class="cb-subtab" data-cb-tab="loyalty"',
                                  html))
  expect_true(nzchar(tab))
  expect_true(grepl('class="cb-norms-table"', tab, fixed = TRUE))
  expect_true(grepl('class="cb-dj-svg"', tab, fixed = TRUE))
  expect_true(grepl('class="cb-scr-svg"', tab, fixed = TRUE))
})


test_that("a REFUSED Dirichlet result gives the tab a refusal block, not an error", {
  html <- expect_no_error(
    render_cat_buying_panel(.cbds_panel_data(dirichlet_status = "REFUSED")))
  expect_true(grepl('data-cb-tab="norms"', html, fixed = TRUE))
  expect_false(grepl('class="cb-norms-table"', gsub("<style>.*?</style>", "", html),
                     fixed = TRUE))
  expect_true(grepl("not available|refused|unavailable|REFUSED", html,
                    ignore.case = TRUE))
})


test_that("the norms table footer carries no em dash", {
  html <- render_cat_buying_panel(.cbds_panel_data())
  foot <- regmatches(html, regexpr("<tfoot>.*?</tfoot>", html))
  expect_true(nzchar(foot))
  expect_false(grepl(intToUtf8(8212L), foot, fixed = TRUE))
})


test_that("a norms table with no DJ_Flag column still renders the scatter", {
  pd <- .cbds_panel_data()
  pd$dirichlet_norms$norms_table$DJ_Flag <- NULL
  html <- expect_no_error(render_cat_buying_panel(pd))
  expect_true(grepl('class="cb-dj-svg"', html, fixed = TRUE))
})
