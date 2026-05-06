# ==============================================================================
# Tests for the modern DBA panel: data shaper + HTML renderers
# ==============================================================================
# Covers:
#   build_dba_panel_data()     — engine result -> JSON payload
#     - placeholder pass-through
#     - REFUSED handling
#     - Wilson 95% CI calculation (known-answer)
#     - insight callouts (count + content)
#   build_dba_panel_html()     — orchestrator
#   build_dba_quadrant_html()  — quadrant scatter
#   build_dba_detail_html()    — asset detail cards
#   build_dba_panel_styles()   — CSS bundle
#   build_shared_placeholder_card() / build_shared_placeholder_styles()
#
# Tests are deterministic and inline-fixture (no external file deps).
# ==============================================================================
library(testthat)

.find_root_dbap <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_dbap()

# Engine constants + placeholder result helpers
source(file.path(ROOT, "modules", "brand", "R", "07_dba.R"))
# Panel data shaper
source(file.path(ROOT, "modules", "brand", "R", "07a_dba_panel_data.R"))
# Panel HTML renderers
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "panels", "00_shared_placeholder.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "panels", "07_dba_panel.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "panels", "07_dba_panel_quadrant.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "panels", "07_dba_panel_detail.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "panels", "07_dba_panel_styling.R"))


# ------------------------------------------------------------------------------
# build_dba_panel_data() — placeholder, REFUSED, full path
# ------------------------------------------------------------------------------

test_that("placeholder engine result passes through to placeholder panel data", {
  ph <- list(
    status = "PASS", placeholder = TRUE,
    dba_metrics = data.frame(
      AssetCode = character(0), AssetLabel = character(0),
      Fame_Pct = numeric(0), Uniqueness_Pct = numeric(0),
      Fame_n = integer(0), Uniqueness_n = integer(0),
      Quadrant = character(0), stringsAsFactors = FALSE),
    metrics_summary = list(focal_brand = "IPK", n_assets = 0L),
    n_respondents = 0L, n_assets = 0L,
    note = DBA_PLACEHOLDER_NOTE
  )
  pd <- build_dba_panel_data(ph, focal_brand = "IPK")
  expect_true(isTRUE(pd$meta$placeholder))
  expect_equal(pd$meta$status, "PASS")
  expect_equal(pd$meta$note, DBA_PLACEHOLDER_NOTE)
  expect_length(pd$assets, 0L)
})


test_that("REFUSED engine result yields refused panel data", {
  refused <- list(status = "REFUSED",
                   message = "No data for DBA analysis")
  pd <- build_dba_panel_data(refused, focal_brand = "IPK")
  expect_equal(pd$meta$status, "REFUSED")
  expect_match(pd$meta$message, "No data for DBA")
})


test_that("full engine result builds assets + insights with Wilson CIs", {
  metrics_df <- data.frame(
    AssetCode  = c("LOGO", "TAGLINE"),
    AssetLabel = c("Primary Logo", "Brand Tagline"),
    Fame_Pct       = c(70, 30),
    Uniqueness_Pct = c(70, 65),
    Fame_n         = c(210L, 90L),
    Uniqueness_n   = c(147L, 59L),
    Quadrant       = c("Use or Lose", "Invest to Build"),
    stringsAsFactors = FALSE
  )
  full <- list(
    status = "PASS", placeholder = FALSE,
    dba_metrics = metrics_df,
    metrics_summary = list(focal_brand = "IPK", n_assets = 2L,
                            n_use_or_lose = 1, n_invest = 1,
                            fame_threshold = 0.50,
                            uniqueness_threshold = 0.50),
    n_respondents = 300L, n_assets = 2L
  )
  pd <- build_dba_panel_data(full, focal_brand = "IPK", focal_colour = "#1A5276")
  expect_false(isTRUE(pd$meta$placeholder))
  expect_length(pd$assets, 2L)
  # Wilson CI for k=210 of n=300 → ~64.6 to 74.9 (computed in R3.6+)
  expect_equal(pd$assets[[1]]$fame_lo, 64.6, tolerance = 0.1)
  expect_equal(pd$assets[[1]]$fame_hi, 74.9, tolerance = 0.1)
  # Insights present
  expect_true(length(pd$insights) >= 2L)
  verbs <- vapply(pd$insights, function(x) x$verb, character(1))
  expect_true("Anchor" %in% verbs)   # 1 Use-or-Lose
  expect_true("Invest" %in% verbs)   # 1 Invest-to-Build
})


# ------------------------------------------------------------------------------
# Wilson CI helper — known-answer values
# ------------------------------------------------------------------------------

test_that("Wilson CI returns NA when n is zero", {
  ci <- .dba_wilson_ci(k = 0L, n = 0L)
  expect_true(is.na(ci$lo) && is.na(ci$hi))
})


test_that("Wilson CI for 50/100 produces a 95% CI around 50%", {
  ci <- .dba_wilson_ci(k = 50L, n = 100L)
  # Wilson 95% CI for 50% of 100 ≈ 40.4% to 59.6%
  expect_equal(ci$lo, 40.4, tolerance = 0.5)
  expect_equal(ci$hi, 59.6, tolerance = 0.5)
})


test_that("Wilson CI bounds are clipped to [0, 100]", {
  ci <- .dba_wilson_ci(k = 0L, n = 50L)
  expect_gte(ci$lo, 0)
  ci2 <- .dba_wilson_ci(k = 50L, n = 50L)
  expect_lte(ci2$hi, 100)
})


# ------------------------------------------------------------------------------
# Insight builder — quadrant counts + lead/watch chips
# ------------------------------------------------------------------------------

test_that("insights include quadrant-specific verbs only when count > 0", {
  metrics_df <- data.frame(
    AssetCode  = c("A", "B", "C", "D"),
    AssetLabel = c("A", "B", "C", "D"),
    Fame_Pct       = c(80, 70, 25, 20),
    Uniqueness_Pct = c(80, 20, 70, 15),
    Fame_n         = c(240L, 210L, 75L, 60L),
    Uniqueness_n   = c(192L, 42L, 53L, 9L),
    Quadrant       = c("Use or Lose", "Avoid Alone",
                       "Invest to Build", "Ignore or Test"),
    stringsAsFactors = FALSE
  )
  summary <- list(fame_threshold = 0.5, uniqueness_threshold = 0.5)
  insights <- .dba_build_insights(metrics_df, summary, 0.5, 0.5)
  verbs <- vapply(insights, function(x) x$verb, character(1))
  expect_true(all(c("Anchor", "Pair", "Invest", "Test") %in% verbs))
  # Lead + Watch present because n_total > 1
  expect_true("Lead" %in% verbs)
  expect_true("Watch" %in% verbs)
})


# ------------------------------------------------------------------------------
# build_dba_panel_html() — orchestrator behaviour
# ------------------------------------------------------------------------------

test_that("placeholder HTML uses shared-placeholder-card class", {
  ph_pd <- build_dba_panel_data(
    list(status = "PASS", placeholder = TRUE,
          metrics_summary = list(focal_brand = "IPK"),
          n_respondents = 0L, n_assets = 0L,
          note = DBA_PLACEHOLDER_NOTE,
          dba_metrics = data.frame(
            AssetCode=character(0), AssetLabel=character(0),
            Fame_Pct=numeric(0), Uniqueness_Pct=numeric(0),
            Fame_n=integer(0), Uniqueness_n=integer(0),
            Quadrant=character(0), stringsAsFactors = FALSE)),
    focal_brand = "IPK", wave_label = "Wave 1")
  html <- build_dba_panel_html(ph_pd, scope_id = "section-dba",
                                wave_label = "Wave 1")
  expect_true(grepl("brand-placeholder-card", html, fixed = TRUE))
  expect_true(grepl("Data not yet collected for DBA", html, fixed = TRUE))
  expect_true(grepl("Wave 1", html, fixed = TRUE))
  expect_true(grepl('id="section-dba"', html, fixed = TRUE))
})


test_that("full HTML contains both sub-tabs and the panel root", {
  metrics_df <- data.frame(
    AssetCode = "LOGO", AssetLabel = "Primary Logo",
    Fame_Pct = 60, Uniqueness_Pct = 70,
    Fame_n = 180L, Uniqueness_n = 126L,
    Quadrant = "Use or Lose", stringsAsFactors = FALSE)
  full <- list(
    status = "PASS", placeholder = FALSE,
    dba_metrics = metrics_df,
    metrics_summary = list(focal_brand = "IPK", n_assets = 1L,
                            fame_threshold = 0.5, uniqueness_threshold = 0.5),
    n_respondents = 300L, n_assets = 1L)
  pd <- build_dba_panel_data(full, focal_brand = "IPK",
                              focal_colour = "#1A5276")
  html <- build_dba_panel_html(pd, scope_id = "section-dba")
  expect_true(grepl('class="dba-panel"', html, fixed = TRUE))
  expect_true(grepl('data-dba-tab="quadrant"', html, fixed = TRUE))
  expect_true(grepl('data-dba-tab="detail"', html, fixed = TRUE))
  expect_true(grepl("dba-quadrant-svg", html, fixed = TRUE))
  expect_true(grepl("dba-detail-card", html, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# Quadrant SVG — defensive empty-state + axis labels
# ------------------------------------------------------------------------------

test_that("quadrant view emits an empty-state when no assets present", {
  pd <- list(assets = list(),
              meta = list(fame_threshold = 0.5,
                          uniqueness_threshold = 0.5))
  html <- build_dba_quadrant_html(pd, focal_colour = "#1A5276")
  expect_true(grepl("dba-quadrant-empty", html, fixed = TRUE))
})


test_that("quadrant view labels all four quadrants", {
  pd <- list(
    assets = list(list(asset_code = "X", asset_label = "X",
                        fame_pct = 60, unique_pct = 60,
                        quadrant = "Use or Lose")),
    meta = list(fame_threshold = 0.5, uniqueness_threshold = 0.5))
  html <- build_dba_quadrant_html(pd, focal_colour = "#1A5276")
  for (label in c("USE OR LOSE", "AVOID ALONE",
                  "INVEST TO BUILD", "IGNORE OR TEST")) {
    expect_true(grepl(label, html, fixed = TRUE),
                 info = sprintf("Missing quadrant label: %s", label))
  }
})


# ------------------------------------------------------------------------------
# Asset Detail — card per asset, image fallback, CI band
# ------------------------------------------------------------------------------

test_that("asset detail emits one card per asset with safe DOM ids", {
  pd <- list(assets = list(
    list(asset_code = "LOGO", asset_label = "Primary Logo",
          image_path = NA, fame_pct = 60, fame_lo = 55, fame_hi = 65, fame_n = 180L,
          unique_pct = 50, unique_lo = 45, unique_hi = 55, unique_n = 90L,
          n_respondents = 300L, quadrant = "Use or Lose",
          action = "Maintain consistent use across all touchpoints."),
    list(asset_code = "ICON / V2", asset_label = "Secondary Icon",
          image_path = "", fame_pct = 30, fame_lo = 25, fame_hi = 35, fame_n = 90L,
          unique_pct = 60, unique_lo = 50, unique_hi = 70, unique_n = 54L,
          n_respondents = 300L, quadrant = "Invest to Build",
          action = "Increase exposure; the asset earns when seen.")
  ))
  html <- build_dba_detail_html(pd, focal_colour = "#1A5276")
  expect_true(grepl("dba-detail-card", html, fixed = TRUE))
  expect_true(grepl('id="section-dba-asset-LOGO"', html, fixed = TRUE))
  # Special chars escape into a safe id
  expect_true(grepl('id="section-dba-asset-ICON---V2"', html, fixed = TRUE))
  # Both have image placeholders (no image_path)
  expect_true(grepl("dba-detail-image-placeholder", html, fixed = TRUE))
})


test_that("asset detail includes Wilson CI band markup", {
  pd <- list(assets = list(
    list(asset_code = "LOGO", asset_label = "Logo",
          image_path = NA, fame_pct = 60, fame_lo = 55, fame_hi = 65,
          fame_n = 180L, unique_pct = 50, unique_lo = 45, unique_hi = 55,
          unique_n = 90L, n_respondents = 300L,
          quadrant = "Use or Lose", action = "Maintain.")
  ))
  html <- build_dba_detail_html(pd, focal_colour = "#1A5276")
  expect_true(grepl("dba-detail-metric-bar-band", html, fixed = TRUE))
  expect_true(grepl("dba-detail-metric-bar-point", html, fixed = TRUE))
  expect_true(grepl("Wilson 95", html, fixed = TRUE))
})


test_that("missing pct in asset detail surfaces 'No responses'", {
  pd <- list(assets = list(
    list(asset_code = "LOGO", asset_label = "Logo",
          image_path = NA, fame_pct = NA_real_,
          unique_pct = NA_real_, fame_n = 0L, unique_n = 0L,
          n_respondents = 0L, quadrant = "Ignore or Test", action = "")
  ))
  html <- build_dba_detail_html(pd, focal_colour = "#1A5276")
  expect_true(grepl("No responses", html, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# Panel CSS bundle
# ------------------------------------------------------------------------------

test_that("panel styles return non-empty CSS containing the brand var", {
  css <- build_dba_panel_styles(list(focal_colour = "#1A5276"))
  expect_true(nchar(css) > 1000)
  expect_true(grepl("--dba-brand", css, fixed = TRUE))
  expect_true(grepl(".dba-panel", css, fixed = TRUE))
  expect_true(grepl("[data-quadrant=\"Use or Lose\"]", css, fixed = TRUE))
})


# ------------------------------------------------------------------------------
# Shared placeholder
# ------------------------------------------------------------------------------

test_that("shared placeholder card includes title, badge, note, next-step", {
  html <- build_shared_placeholder_card(
    scope_id = "section-test",
    title    = "Test Element",
    note     = "Data not yet collected",
    badge    = "Wave 1",
    next_step = "Add the data in the next wave."
  )
  expect_true(grepl("brand-placeholder-card", html, fixed = TRUE))
  expect_true(grepl('id="section-test"', html, fixed = TRUE))
  expect_true(grepl("Test Element", html, fixed = TRUE))
  expect_true(grepl("Wave 1", html, fixed = TRUE))
  expect_true(grepl("Data not yet collected", html, fixed = TRUE))
  expect_true(grepl("Add the data in the next wave", html, fixed = TRUE))
})


test_that("shared placeholder styles include the card class + dark theme", {
  css <- build_shared_placeholder_styles()
  expect_true(grepl(".brand-placeholder-card", css, fixed = TRUE))
  expect_true(grepl(".theme-dark", css, fixed = TRUE))
})


test_that("shared placeholder escapes HTML in inputs", {
  html <- build_shared_placeholder_card(
    scope_id = "ok",
    title    = "<script>alert(1)</script>",
    note     = "<b>bold</b>"
  )
  expect_false(grepl("<script>", html, fixed = TRUE))
  expect_true(grepl("&lt;script&gt;", html, fixed = TRUE))
  expect_true(grepl("&lt;b&gt;bold", html, fixed = TRUE))
})
