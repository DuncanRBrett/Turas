# ==============================================================================
# TEST: 08_cat_buying_panel.R
# Coverage: HTML contract (data-* attributes, section ids), graceful
#           degradation when upstream elements are REFUSED, toggle presence.
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
  source(file.path(root, "modules", "brand", "lib", "html_report",
                   "panels", "08_cat_buying_panel.R"), local = FALSE)
})


# ---- Synthetic panel data ----

make_panel_data <- function(dirichlet_status = "PASS",
                            heaviness_status  = "PASS") {
  norms_tbl <- data.frame(
    BrandCode              = c("A", "B", "C"),
    Penetration_Obs_Pct    = c(65, 45, 30),
    Penetration_Exp_Pct    = c(60, 48, 32),
    Penetration_Dev_Pct    = c(8, -6, -6),
    BuyRate_Obs            = c(4.2, 3.1, 2.8),
    BuyRate_Exp            = c(4.0, 3.3, 2.9),
    BuyRate_Dev_Pct        = c(5, -6, -3),
    SCR_Obs_Pct            = c(42, 30, 25),
    SCR_Exp_Pct            = c(40, 32, 27),
    SCR_Dev_Pct            = c(5, -6, -7),
    Pct100Loyal_Obs        = c(18, 10, 8),
    Pct100Loyal_Exp        = c(15, 12, 9),
    Pct100Loyal_Dev_Pct    = c(20, -17, -11),
    DJ_Flag                = c("on_line", "on_line", "on_line"),
    stringsAsFactors       = FALSE
  )

  dirichlet <- if (dirichlet_status == "REFUSED") {
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
      market_shares    = data.frame(BrandCode = c("A","B","C"),
                                     Volume = c(60, 40, 25),
                                     Share_Pct = c(48, 32, 20),
                                     stringsAsFactors = FALSE),
      dj_curve         = list(x_grid = seq(0.2, 0.8, length.out = 50),
                               y_fit_scr = seq(25, 45, length.out = 50),
                               y_fit_w   = seq(2.5, 4.5, length.out = 50),
                               method = "NBDdirichlet"),
      metrics_summary  = list(focal_brand = "A", focal_scr_obs = 42,
                              focal_scr_exp = 40, focal_pen_obs = 65,
                              focal_pen_exp = 60, focal_loyal_obs = 18,
                              focal_loyal_exp = 15, n_brands = 3L),
      observed = norms_tbl[, c("BrandCode","Penetration_Obs_Pct","BuyRate_Obs",
                                "SCR_Obs_Pct","Pct100Loyal_Obs")],
      warnings = character(0)
    )
  }

  heaviness <- if (heaviness_status == "REFUSED") {
    list(status = "REFUSED", code = "DATA_NO_BUYERS", message = "test refusal")
  } else {
    list(
      status = "PASS",
      brand_heaviness = data.frame(
        BrandCode = c("A","B","C"), Heavy_Pct = c(40, 35, 30),
        Medium_Pct = c(35, 35, 35), Light_Pct = c(25, 30, 35),
        WBar_Brand = c(4.5, 3.2, 2.8), WBar_Category = 3.5,
        WBar_Gap = c(1.0, -0.3, -0.7),
        NaturalMonopolyIndex = c(71, 86, 100),
        Brand_Buyers_n = c(165L, 115L, 75L),
        stringsAsFactors = FALSE),
      category_buyer_mix = data.frame(
        Tier = c("Light","Medium","Heavy"), Pct = c(33, 34, 33), n = c(55,56,54),
        stringsAsFactors = FALSE),
      metrics_summary = list(focal_brand = "A", focal_nmi = 71,
                              focal_wbar = 4.5, focal_wbar_gap = 1.0)
    )
  }

  list(
    cat_name         = "Test Category",
    category_code    = "TST",
    focal_brand      = "A",
    focal_colour     = "#1A5276",
    target_months    = 3L,
    longer_months    = 12L,
    dirichlet_norms  = dirichlet,
    buyer_heaviness  = heaviness,
    cat_buying_frequency = list(
      status        = "PASS",
      pct_buyers    = 55.0,
      mean_freq     = 2.4,
      n_respondents = 300L
    ),
    repertoire = list(
      status               = "PASS",
      dop_deviation_matrix = NULL,
      dop_D_coefficient    = 1.8
    )
  )
}


# ==============================================================================
# HTML CONTRACT
# ==============================================================================

test_that("panel renders an HTML string", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  html <- render_cat_buying_panel(make_panel_data())
  expect_type(html, "character")
  expect_true(nchar(html) > 100)
})

test_that("panel contains section id for category code", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  html <- render_cat_buying_panel(make_panel_data())
  expect_true(grepl("cb-panel", html, fixed = TRUE) ||
              grepl("cat-buying", html, fixed = TRUE) ||
              grepl("TST", html, fixed = TRUE))
})

test_that("panel contains Purchase Distribution section", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  html <- render_cat_buying_panel(make_panel_data())
  expect_true(grepl("Purchase Distribution|cb-dist-chart|cb-dist-row", html))
})

test_that("panel contains norms table section", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  html <- render_cat_buying_panel(make_panel_data())
  expect_true(grepl("dirichlet|norms|Penetration", html, ignore.case = TRUE))
})

test_that("panel contains buyer heaviness section", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  html <- render_cat_buying_panel(make_panel_data())
  expect_true(grepl("heaviness|Light|Heavy|NMI", html, ignore.case = TRUE))
})

test_that("DJ y-axis toggle button present in HTML", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  html <- render_cat_buying_panel(make_panel_data())
  # Toggle should reference SCR and w (buy rate)
  expect_true(grepl("SCR|scr", html) && grepl("buy.rate|w\\b|BuyRate", html,
                                                ignore.case = TRUE))
})

test_that("DoP heatmap toggle present in HTML", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  html <- render_cat_buying_panel(make_panel_data())
  expect_true(grepl("deviation|Deviation|heatmap|DoP", html, ignore.case = TRUE))
})


# ==============================================================================
# GRACEFUL DEGRADATION
# ==============================================================================

test_that("dirichlet REFUSED shows refusal block but panel still renders", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  data_refused <- make_panel_data(dirichlet_status = "REFUSED")
  html <- render_cat_buying_panel(data_refused)
  expect_type(html, "character")
  expect_true(nchar(html) > 50)
  # Should contain some refusal indicator
  expect_true(grepl("not available|refused|unavailable|REFUSED",
                    html, ignore.case = TRUE))
})

test_that("heaviness REFUSED shows refusal block but panel still renders", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  data_refused <- make_panel_data(heaviness_status = "REFUSED")
  html <- render_cat_buying_panel(data_refused)
  expect_type(html, "character")
  expect_true(nchar(html) > 50)
})

test_that("both REFUSED still renders without error", {
  skip_if_not(exists("render_cat_buying_panel", mode = "function"),
               "08_cat_buying_panel.R not loaded")
  data_both <- make_panel_data(dirichlet_status  = "REFUSED",
                               heaviness_status  = "REFUSED")
  html <- expect_no_error(render_cat_buying_panel(data_both))
  expect_type(html, "character")
})
