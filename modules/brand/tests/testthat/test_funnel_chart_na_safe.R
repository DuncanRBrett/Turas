# ==============================================================================
# Tests for build_funnel_chart() NA safety
# ==============================================================================
# The legacy wide adapter (03e_funnel_legacy_adapter.R) writes NA_real_ for any
# stage or attitude position the survey did not measure. A questionnaire on the
# 5-level attitude scale leaves Price_Pct NA for every brand, which is what the
# IPK fixture does.
#
# build_funnel_chart() used to read those NAs straight into a segment width and
# then branch on it, so "if (seg_w > 1)" raised "missing value where TRUE/FALSE
# needed". transform_brand_charts() caught it one level up, dropped the whole
# chart layer and left the report generator reporting a warning on every
# IPK-shaped run. These tests pin the NA handling at the renderer.
# ==============================================================================
library(testthat)

.find_root_fcns <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT_FCNS <- .find_root_fcns()

source(file.path(ROOT_FCNS, "modules", "brand", "lib", "html_report",
                 "04_chart_builder.R"))


.fcns_row <- function(...) {
  base <- data.frame(
    BrandCode      = "IPK",
    Aware_Pct      = 92.5,
    Positive_Pct   = 66.9,
    Bought_Pct     = 62.3,
    Primary_Pct    = 45.0,
    Love_Pct       = 30.1,
    Prefer_Pct     = 36.8,
    Ambivalent_Pct = 20.5,
    Price_Pct      = NA_real_,
    Avoid_Pct      = 5.0,
    NoOpinion_Pct  = 7.5,
    stringsAsFactors = FALSE
  )
  over <- list(...)
  for (nm in names(over)) base[[nm]] <- over[[nm]]
  base
}


test_that("build_funnel_chart: an all-NA attitude column renders instead of erroring", {
  svg <- build_funnel_chart(.fcns_row(), focal_brand = "IPK")
  expect_type(svg, "character")
  expect_length(svg, 1L)
  expect_true(nzchar(svg))
  expect_true(grepl("<svg", svg, fixed = TRUE))
})


test_that("build_funnel_chart: an unmeasured position draws no segment", {
  # Price_Pct is NA, so the Price colour (#E67E22) must appear only as the
  # legend swatch, never as a decomposition segment. Segment rects carry the
  # bar height (24); legend swatches are 10 by 10.
  svg <- build_funnel_chart(.fcns_row(), focal_brand = "IPK")
  expect_false(grepl('height="24" fill="#E67E22"', svg, fixed = TRUE))
})


test_that("build_funnel_chart: a measured Price position does draw a segment", {
  svg <- build_funnel_chart(.fcns_row(Price_Pct = 12.0), focal_brand = "IPK")
  expect_true(grepl('height="24" fill="#E67E22"', svg, fixed = TRUE))
})


test_that("build_funnel_chart: an NA stage percentage writes no NA into the SVG", {
  svg <- build_funnel_chart(
    .fcns_row(Aware_Pct = NA_real_, Bought_Pct = NA_real_),
    focal_brand = "IPK")
  expect_true(nzchar(svg))
  expect_false(grepl('width="NA"', svg, fixed = TRUE))
  expect_false(grepl('x="NA"', svg, fixed = TRUE))
  expect_false(grepl('y="NA"', svg, fixed = TRUE))
})


test_that("build_funnel_chart: an NA brand code does not error on the focal test", {
  svg <- build_funnel_chart(.fcns_row(BrandCode = NA_character_),
                            focal_brand = "IPK")
  expect_type(svg, "character")
  expect_true(nzchar(svg))
})


test_that("build_funnel_chart: a missing attitude column keeps the colour mapping", {
  # Dropping Price_Pct entirely must not shift Avoid into the Price colour.
  df <- .fcns_row()
  df$Price_Pct <- NULL
  svg <- build_funnel_chart(df, focal_brand = "IPK")
  expect_true(nzchar(svg))
  expect_false(grepl('height="24" fill="#E67E22"', svg, fixed = TRUE))
  # Love, Prefer, Ambivalent, Avoid and No Opinion must all still be drawn
  # in their own colours, not shifted one position by the dropped column.
  for (col in c("#1A5276", "#2E86C1", "#85C1E9", "#C0392B", "#D5D8DC")) {
    expect_true(grepl(sprintf('height="24" fill="%s"', col), svg, fixed = TRUE),
                info = paste("expected a segment in", col))
  }
})


test_that("transform_brand_charts: the IPK-shaped funnel frame survives the loop", {
  # Two brands, one of them with every attitude position missing, is the
  # shape that took the chart layer down.
  df <- rbind(
    .fcns_row(),
    .fcns_row(BrandCode = "ROB", Love_Pct = NA_real_, Prefer_Pct = NA_real_,
              Ambivalent_Pct = NA_real_, Avoid_Pct = NA_real_,
              NoOpinion_Pct = NA_real_))
  svg <- build_funnel_chart(df, focal_brand = "IPK")
  expect_true(nzchar(svg))
  expect_false(grepl("NA", svg, fixed = TRUE))
})
