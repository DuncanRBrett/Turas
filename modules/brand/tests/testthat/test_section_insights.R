# ==============================================================================
# Tests for the Section_Insights loader and the prefill wiring into
# build_br_section_toolbar().
#
# What's covered:
#   - Loader returns NULL when sheet is absent
#   - Loader parses Category + Section + Insight, resolves friendly labels
#     and reserved codes to anchor IDs
#   - section_insight_for() safe-accessor
#   - build_br_section_toolbar() pre-fills the textarea + rendered view when
#     given non-empty text, and falls back to the empty editor when not
#   - About panel renders _BACKGROUND when present in config
# ==============================================================================
library(testthat)

.find_root_si <- function() {
  dir <- getwd()
  for (i in 1:10) {
    if (file.exists(file.path(dir, "CLAUDE.md"))) return(dir)
    dir <- dirname(dir)
  }
  getwd()
}
ROOT <- .find_root_si()

source(file.path(ROOT, "modules", "brand", "R", "01b_section_insights.R"))
source(file.path(ROOT, "modules", "brand", "lib", "html_report",
                 "03_page_builder.R"))


# ------------------------------------------------------------------------------
# Anchor resolver
# ------------------------------------------------------------------------------

test_that(".brand_section_anchor maps reserved labels to anchor IDs", {
  expect_equal(.brand_section_anchor("_REPORT", "Executive Summary"),
               "_EXECUTIVE_SUMMARY")
  expect_equal(.brand_section_anchor("_REPORT", "Background"),
               "_BACKGROUND")
  expect_equal(.brand_section_anchor("_REPORT", "Portfolio Overview"),
               "pf-overview")
  expect_equal(.brand_section_anchor("_REPORT", "Portfolio Category Context"),
               "pf-clutter")
  expect_equal(.brand_section_anchor("_REPORT", "Portfolio Competitive Set"),
               "pf-constellation")
  expect_equal(.brand_section_anchor("_REPORT", "Portfolio Footprint"),
               "pf-footprint")
})

test_that(".brand_section_anchor maps per-category labels to element-cat IDs", {
  # Funnel-panel sub-tabs (v1.1: distinct anchors per internal sub-tab)
  expect_equal(.brand_section_anchor("POS", "Brand Funnel"), "funnel-pos")
  expect_equal(.brand_section_anchor("POS", "Brand Attitude"), "attitude-pos")
  expect_equal(.brand_section_anchor("POS", "Attitude"), "attitude-pos")
  # MA-panel sub-tabs (v1.1: 4 distinct anchors)
  expect_equal(.brand_section_anchor("PAS", "Brand Attributes"), "attributes-pas")
  expect_equal(.brand_section_anchor("PAS", "Attributes"), "attributes-pas")
  expect_equal(.brand_section_anchor("PAS", "Category Entry Points"), "ceps-pas")
  expect_equal(.brand_section_anchor("PAS", "CEPs"), "ceps-pas")
  expect_equal(.brand_section_anchor("PAS", "Mental Advantage"), "advantage-pas")
  expect_equal(.brand_section_anchor("PAS", "Advantage"), "advantage-pas")
  expect_equal(.brand_section_anchor("PAS", "MA Metrics"), "metrics-pas")
  expect_equal(.brand_section_anchor("PAS", "Headline Metrics"), "metrics-pas")
  expect_equal(.brand_section_anchor("PAS", "Metrics"), "metrics-pas")
  # Other elements
  expect_equal(.brand_section_anchor("DSS", "Category Buying"), "repertoire-dss")
  expect_equal(.brand_section_anchor("BAK", "Word of Mouth"), "wom-bak")
  expect_equal(.brand_section_anchor("BAK", "Demographics"), "demographics-bak")
  expect_equal(.brand_section_anchor("BAK", "Ad Hoc"), "adhoc-bak")
})

test_that("build_br_section_toolbar accepts internal_tab + initial_visible", {
  # Hidden by default when not the first wrapper in a stack
  html_hidden <- build_br_section_toolbar(
    "attitude-bak", prefill_text = NULL,
    internal_tab = "relationship", initial_visible = FALSE)
  expect_match(html_hidden, 'data-insight-internal-tab="relationship"')
  expect_match(html_hidden, 'display:none;')
  # Visible when first
  html_visible <- build_br_section_toolbar(
    "funnel-bak", prefill_text = NULL,
    internal_tab = "funnel", initial_visible = TRUE)
  expect_match(html_visible, 'data-insight-internal-tab="funnel"')
  expect_match(html_visible, 'display:block;')
})

test_that("build_br_section_toolbar without internal_tab emits no wrapper", {
  html <- build_br_section_toolbar("wom-bak")
  expect_false(grepl("data-insight-internal-tab", html))
})

test_that("multiple toolbars per sub-panel each have a unique anchor + visible state", {
  # When build_br_category_panel emits the per-sub-tab toolbars for the
  # Funnel and MA panels, the FIRST toolbar must render visible
  # (initial_visible=TRUE → display:block) and the rest hidden
  # (initial_visible=FALSE → display:none). The JS sub-tab switcher
  # (brand_report.js::switchCategorySubtab) flips these on click.
  html_first <- build_br_section_toolbar(
    "funnel-bak", internal_tab = "funnel", initial_visible = TRUE)
  html_other <- build_br_section_toolbar(
    "attitude-bak", internal_tab = "relationship", initial_visible = FALSE)

  expect_match(html_first, 'data-insight-internal-tab="funnel"[^>]*style="display:block;"')
  expect_match(html_other, 'data-insight-internal-tab="relationship"[^>]*style="display:none;"')
  expect_match(html_first, 'data-section="funnel-bak"')
  expect_match(html_other, 'data-section="attitude-bak"')
})

test_that("emitted CSS has single %% (not %%%% leftover from sprintf escaping)", {
  # Regression guard for the v1.1 narrow-textarea bug: style strings
  # built with paste0() then substituted into sprintf via %s do NOT get
  # %% reduced to %. A leftover %% in the rendered CSS is invalid and
  # the browser silently drops the rule.
  html_empty   <- build_br_section_toolbar("test-section")
  html_filled  <- build_br_section_toolbar("test-section",
                                            prefill_text = "hello")
  html_wrap    <- build_br_section_toolbar("test-section",
                                            internal_tab    = "funnel",
                                            initial_visible = TRUE)
  for (h in list(html_empty, html_filled, html_wrap)) {
    expect_false(grepl("%%", h),
                 info = "Toolbar HTML must not contain literal %% in CSS")
    # Width must end up as single % so the browser honours it
    expect_match(h, "width:100%;")
  }
})

test_that(".brand_section_anchor is case-insensitive on Section", {
  expect_equal(.brand_section_anchor("POS", "brand funnel"), "funnel-pos")
  expect_equal(.brand_section_anchor("POS", "BRAND FUNNEL"), "funnel-pos")
  expect_equal(.brand_section_anchor("POS", "  Brand Funnel  "), "funnel-pos")
})

test_that(".brand_section_anchor passes raw anchor IDs through unchanged", {
  # Underscore-prefixed reserved codes
  expect_equal(.brand_section_anchor("_REPORT", "_EXECUTIVE_SUMMARY"),
               "_EXECUTIVE_SUMMARY")
  # Raw element-cat anchors
  expect_equal(.brand_section_anchor("POS", "funnel-pos"), "funnel-pos")
  expect_equal(.brand_section_anchor("_REPORT", "pf-overview"), "pf-overview")
  # Unknown labels under _REPORT are passed through (escape hatch)
  expect_equal(.brand_section_anchor("_REPORT", "some-new-anchor"),
               "some-new-anchor")
})

test_that(".brand_section_anchor normalises CategoryCode for anchor", {
  # Hyphenisable codes
  expect_equal(.brand_section_anchor("Pour Over Sauce", "Brand Funnel"),
               "funnel-pour-over-sauce")
  # v1.1: "Mental Advantage" resolves to the MA Advantage sub-tab, not the
  # legacy panel-wide ma-{cat} anchor
  expect_equal(.brand_section_anchor("BAKING_MIXES", "Mental Advantage"),
               "advantage-baking-mixes")
})

test_that(".brand_section_anchor returns NA on unusable input", {
  expect_true(is.na(.brand_section_anchor("POS", NA)))
  expect_true(is.na(.brand_section_anchor("POS", "")))
  expect_true(is.na(.brand_section_anchor("POS", "   ")))
  expect_true(is.na(.brand_section_anchor("POS", NULL)))
})


# ------------------------------------------------------------------------------
# Safe accessor
# ------------------------------------------------------------------------------

test_that("section_insight_for returns '' for NULL / missing / NA", {
  expect_equal(section_insight_for(NULL, "anything"), "")
  expect_equal(section_insight_for(character(0), "anything"), "")
  expect_equal(section_insight_for(c(`funnel-pos` = "ok"), "missing-anchor"), "")
  expect_equal(section_insight_for(c(`funnel-pos` = NA_character_),
                                    "funnel-pos"), "")
})

test_that("section_insight_for returns the stored text on hit", {
  m <- c(`funnel-pos` = "hello", `ma-bak` = "world")
  expect_equal(section_insight_for(m, "funnel-pos"), "hello")
  expect_equal(section_insight_for(m, "ma-bak"), "world")
})


# ------------------------------------------------------------------------------
# Loader — round-trip via a temp xlsx
# ------------------------------------------------------------------------------

.make_si_sheet <- function(rows) {
  tf <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = c("focal_brand", "wave"),
    Value   = c("IPK", "1")
  ), colNames = FALSE)
  openxlsx::addWorksheet(wb, "Section_Insights")
  openxlsx::writeData(wb, "Section_Insights", rows)
  openxlsx::saveWorkbook(wb, tf, overwrite = TRUE)
  tf
}

test_that("load_section_insights_sheet returns NULL when sheet absent", {
  tf <- tempfile(fileext = ".xlsx")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Settings")
  openxlsx::writeData(wb, "Settings", data.frame(
    Setting = "focal_brand", Value = "IPK"
  ), colNames = FALSE)
  openxlsx::saveWorkbook(wb, tf, overwrite = TRUE)
  expect_null(load_section_insights_sheet(tf))
  unlink(tf)
})

test_that("load_section_insights_sheet resolves friendly labels to anchors", {
  rows <- data.frame(
    Category = c("_REPORT", "_REPORT", "POS", "BAK"),
    Section  = c("Executive Summary", "Portfolio Overview",
                 "Brand Funnel", "Mental Advantage"),
    Insight  = c("Topline story", "Cross-cat reach",
                 "POS funnel notes", "BAK gap to leader"),
    stringsAsFactors = FALSE
  )
  tf <- .make_si_sheet(rows)
  res <- load_section_insights_sheet(tf)
  unlink(tf)

  expect_type(res, "character")
  expect_setequal(names(res),
                  c("_EXECUTIVE_SUMMARY", "pf-overview",
                    "funnel-pos", "advantage-bak"))
  expect_equal(unname(res["_EXECUTIVE_SUMMARY"]), "Topline story")
  expect_equal(unname(res["funnel-pos"]), "POS funnel notes")
  expect_equal(unname(res["advantage-bak"]), "BAK gap to leader")
})

test_that("load_section_insights_sheet honours Order column", {
  rows <- data.frame(
    Category = c("_REPORT", "_REPORT"),
    Section  = c("Executive Summary", "Portfolio Overview"),
    Insight  = c("first", "zeroth"),
    Order    = c(2, 1),
    stringsAsFactors = FALSE
  )
  tf <- .make_si_sheet(rows)
  res <- load_section_insights_sheet(tf)
  unlink(tf)
  # Order 1 first, then order 2
  expect_equal(names(res), c("pf-overview", "_EXECUTIVE_SUMMARY"))
})

test_that("load_section_insights_sheet drops junk rows", {
  rows <- data.frame(
    Category = c("_REPORT", "_REPORT", "_REPORT", "_REPORT"),
    Section  = c("[example anchor]", "Executive Summary", NA, ""),
    Insight  = c("ignored",          "kept",              "drop", "drop"),
    stringsAsFactors = FALSE
  )
  tf <- .make_si_sheet(rows)
  res <- load_section_insights_sheet(tf)
  unlink(tf)
  expect_equal(names(res), "_EXECUTIVE_SUMMARY")
  expect_equal(unname(res["_EXECUTIVE_SUMMARY"]), "kept")
})

test_that("load_section_insights_sheet de-dupes anchors (last wins)", {
  rows <- data.frame(
    Category = c("_REPORT", "_REPORT"),
    Section  = c("Executive Summary", "Executive Summary"),
    Insight  = c("old",                "new"),
    stringsAsFactors = FALSE
  )
  tf <- .make_si_sheet(rows)
  res <- load_section_insights_sheet(tf)
  unlink(tf)
  expect_equal(length(res), 1L)
  expect_equal(unname(res["_EXECUTIVE_SUMMARY"]), "new")
})


# ------------------------------------------------------------------------------
# build_br_section_toolbar prefill
# ------------------------------------------------------------------------------

test_that("build_br_section_toolbar without prefill renders empty editor", {
  html <- build_br_section_toolbar("test-section")
  expect_match(html, 'data-section="test-section"')
  expect_match(html, 'class="br-insight-editor" data-section="test-section"')
  # Container hidden, no prefilled flag
  expect_match(html, 'data-prefilled="false"')
  expect_match(html, "display:none;margin-bottom:16px")
  # Default add-insight label
  expect_match(html, "\\+ Add Insight")
  # Empty textarea body
  expect_match(html, '<textarea class="br-insight-editor"[^>]*></textarea>')
})

test_that("build_br_section_toolbar with prefill pre-populates editor", {
  html <- build_br_section_toolbar("test-section",
                                   prefill_text = "Hello **world**")
  # Container is visible
  expect_match(html, 'data-prefilled="true"')
  expect_match(html, "display:block;margin-bottom:16px")
  # Textarea carries the raw text
  expect_match(html, "Hello \\*\\*world\\*\\*")
  # Rendered div carries the server-rendered HTML
  expect_match(html, "<strong>world</strong>")
  # Edit label
  expect_match(html, "Edit Insight")
  # Toggle handler is the edit-mode one, not the show/hide one
  expect_match(html, '_brToggleInsightEdit\\(')
})

test_that(".br_render_insight_md handles bold, italic, bullets safely", {
  expect_equal(.br_render_insight_md("**bold**"), "<strong>bold</strong>")
  expect_equal(.br_render_insight_md("*italic*"), "<em>italic</em>")
  expect_equal(.br_render_insight_md("- a\n- b"),
               "<ul><li>a</li><li>b</li></ul>")
  # HTML injection escaped
  expect_equal(.br_render_insight_md("<script>x</script>"),
               "&lt;script&gt;x&lt;/script&gt;")
})


# ------------------------------------------------------------------------------
# About panel renders _BACKGROUND
# ------------------------------------------------------------------------------

test_that("build_br_about_panel injects _BACKGROUND prose when present", {
  cfg <- list(
    colour_focal = "#1A5276",
    section_insights = c(`_BACKGROUND` = "This is a test project background.")
  )
  html <- build_br_about_panel(cfg)
  expect_match(html, "br-about-background")
  expect_match(html, 'data-section="_BACKGROUND"')
  expect_match(html, "This is a test project background\\.")
})

test_that("build_br_about_panel omits background block when not set", {
  cfg <- list(colour_focal = "#1A5276", section_insights = NULL)
  html <- build_br_about_panel(cfg)
  expect_false(grepl("br-about-background", html))
})
