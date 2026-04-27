# ==============================================================================
# Tests for cb_shopper_tab_html() and cb_shopper_context_chips()
# ==============================================================================
# These do not run a full HTML report build. They exercise the panel
# renderer directly with engine-shaped inputs to confirm:
#   1. absent / refused inputs are skipped silently;
#   2. the rendered fragment contains the expected section headings,
#      KPIs, and option codes;
#   3. the slim Context chips collapse to "" when both engines absent.
#
# Whitespace / class-name probes only — no DOM diffing.
# ==============================================================================

# Source the panel + its helpers. Test-time chdir = FALSE keeps the working
# directory at modules/brand/tests/testthat, so paths must be explicit.
.panel_dir <- "../../lib/html_report/panels"
for (f in c("08_cat_buying_panel_styling.R",
            "08_cat_buying_panel_chart.R",
            "08_cat_buying_panel_table.R",
            "08_cat_buying_panel_shopper.R",
            "08_cat_buying_panel.R")) {
  source(file.path(.panel_dir, f), local = FALSE)
}


build_loc_result <- function() {
  list(
    status = "PASS",
    kind   = "location",
    category_distribution = data.frame(
      Code  = c("S", "O"),
      Label = c("Supermarket", "Online"),
      Order = 1:2,
      n     = c(120L, 60L),
      Pct   = c(80.0, 40.0),
      stringsAsFactors = FALSE
    ),
    brand_matrix = data.frame(
      BrandCode = c("__cat__", "A", "B"),
      Base_n    = c(NA_integer_, 100L, 75L),
      Pct_S     = c(82.5, 90.0, 75.0),
      Pct_O     = c(45.0, 50.0, 40.0),
      stringsAsFactors = FALSE
    ),
    top = list(code = "S", label = "Supermarket", pct = 80.0),
    hhi = 0.80,
    n_cat_buyers  = 150L,
    n_respondents = 200L
  )
}


build_pak_result <- function() {
  list(
    status = "PASS",
    kind   = "packsize",
    category_distribution = data.frame(
      Code  = c("SMALL", "LARGE"),
      Label = c("Small", "Large"),
      Order = 1:2,
      n     = c(80L, 90L),
      Pct   = c(53.3, 60.0),
      stringsAsFactors = FALSE
    ),
    brand_matrix = data.frame(
      BrandCode = c("__cat__", "A", "B"),
      Base_n    = c(NA_integer_, 100L, 75L),
      Pct_SMALL = c(55.0, 60.0, 50.0),
      Pct_LARGE = c(58.0, 50.0, 66.0),
      stringsAsFactors = FALSE
    ),
    top = list(code = "LARGE", label = "Large", pct = 60.0),
    hhi = 0.64,
    n_cat_buyers  = 150L,
    n_respondents = 200L
  )
}


build_panel_data <- function(loc = NULL, pak = NULL) {
  list(
    cat_name        = "Dry Seasonings",
    category_code   = "dss",
    focal_brand     = "A",
    focal_colour    = "#1A5276",
    target_months   = 3L,
    longer_months   = 12L,
    dirichlet_norms = NULL,
    buyer_heaviness = NULL,
    cat_buying_frequency = NULL,
    repertoire      = NULL,
    shopper_location = loc,
    shopper_packsize = pak,
    brand_labels    = c(A = "Brand Alpha", B = "Brand Beta"),
    brand_colours   = list()
  )
}


# ------------------------------------------------------------------------------

test_that("cb_shopper_tab_html returns empty when both sections absent", {
  pd <- build_panel_data(loc = NULL, pak = NULL)
  expect_identical(cb_shopper_tab_html(pd), "")
})

test_that("cb_shopper_tab_html renders location-only when packsize absent", {
  pd <- build_panel_data(loc = build_loc_result(), pak = NULL)
  html <- cb_shopper_tab_html(pd)
  expect_true(nzchar(html))
  expect_match(html, "Purchase Location")
  expect_false(grepl("Pack Sizes", html))
  expect_match(html, "Top channel")     # KPI chip from .cb_shop_kpi_chips
  expect_false(grepl("Top pack size", html))
  expect_match(html, "Supermarket")
})

test_that("cb_shopper_tab_html renders both sections when both present", {
  pd <- build_panel_data(loc = build_loc_result(), pak = build_pak_result())
  html <- cb_shopper_tab_html(pd)
  expect_match(html, "Purchase Location")
  expect_match(html, "Pack Sizes")
  expect_match(html, "Top channel")
  expect_match(html, "Top pack size")
  # Both option codes should appear as table column scopes
  expect_match(html, "data-cb-seg=\"S\"")
  expect_match(html, "data-cb-seg=\"SMALL\"")
})

test_that("cb_shopper_tab_html skips a section that is REFUSED", {
  loc_refused <- list(status = "REFUSED",
                       code = "DATA_NO_CAT_BUYERS",
                       message = "no cat buyers")
  pd <- build_panel_data(loc = loc_refused, pak = build_pak_result())
  html <- cb_shopper_tab_html(pd)
  expect_false(grepl("Purchase Location", html))
  expect_match(html, "Pack Sizes")
})

test_that("cb_shopper_context_chips returns empty when both engines absent", {
  pd <- build_panel_data(NULL, NULL)
  expect_identical(cb_shopper_context_chips(pd), "")
})

test_that("cb_shopper_context_chips emits one chip per available engine", {
  pd <- build_panel_data(loc = build_loc_result(), pak = build_pak_result())
  chips <- cb_shopper_context_chips(pd)
  expect_match(chips, "Most-used purchase channel")
  expect_match(chips, "Most-bought pack size")
  expect_match(chips, "Supermarket")
  expect_match(chips, "Large")
})

test_that("cb_shopper_tab_html drops the cat avg row from the brand matrix", {
  # The renderer must hand .cb_rel_table_html only real brand rows;
  # otherwise the cross-brand mean would be biased by the precomputed
  # __cat__ row appearing as a "brand".
  pd <- build_panel_data(loc = build_loc_result(), pak = NULL)
  html <- cb_shopper_tab_html(pd)
  expect_false(grepl('data-cb-brand="__cat__"', html))
})
