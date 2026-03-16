# ==============================================================================
# Tests: Tracker Page Components & Qualitative Panel
# ==============================================================================
# Covers: build_qualitative_panel, build_pinned_tab, build_help_overlay,
#         build_tracker_header, build_tracker_footer, build_tracker_about_panel,
#         build_report_tab_nav, build_annotations_json
# ==============================================================================

library(testthat)
context("Tracker Page Components & Qualitative Panel")

# --- Setup -------------------------------------------------------------------

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

assign(".tracker_lib_dir", file.path(tracker_root, "lib"), envir = globalenv())

palette_path <- file.path(turas_root, "modules", "shared", "lib", "colour_palettes.R")
if (file.exists(palette_path)) source(palette_path)

source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "html_report", "05_chart_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "03b_page_components.R"))
source(file.path(tracker_root, "lib", "html_report", "03_page_builder.R"))

# --- Mock data helpers -------------------------------------------------------

mock_html_data <- list(
  metadata = list(
    project_name = "Test Project",
    generated_at = Sys.time(),
    confidence_level = 0.95
  ),
  n_metrics = 5,
  waves = c("W1", "W2", "W3"),
  wave_labels = c("Wave 1", "Wave 2", "Wave 3"),
  wave_lookup = c(W1 = "Wave 1", W2 = "Wave 2", W3 = "Wave 3"),
  baseline_wave = "W1",
  segments = c("Total", "Male", "Female"),
  metric_rows = list()
)

mock_config <- list(
  settings = list(
    brand_colour = "#323367",
    company_name = "TestCo",
    client_name = "ClientCo"
  )
)

mock_config_with_about <- list(
  settings = list(
    brand_colour = "#323367",
    analyst_name = "Jane Doe",
    analyst_email = "jane@test.com",
    analyst_phone = "+1234567890",
    company_name = "TestCo"
  )
)

# ==============================================================================
# build_qualitative_panel
# ==============================================================================

test_that("build_qualitative_panel contains qual-tab-content class", {
  html <- as.character(build_qualitative_panel())
  expect_true(grepl("qual-tab-content", html, fixed = TRUE))
})

test_that("build_qualitative_panel has add slide button", {
  html <- as.character(build_qualitative_panel())
  expect_true(grepl("Add Slide", html, fixed = TRUE))
  expect_true(grepl("addQualSlide", html, fixed = TRUE))
})

test_that("build_qualitative_panel has pin all button", {
  html <- as.character(build_qualitative_panel())
  expect_true(grepl("Pin All", html, fixed = TRUE))
  expect_true(grepl("pinAllQualSlides", html, fixed = TRUE))
})

test_that("build_qualitative_panel has qual-slides-container div", {
  html <- as.character(build_qualitative_panel())
  expect_true(grepl("qual-slides-container", html, fixed = TRUE))
})

test_that("build_qualitative_panel has qual-empty-state", {
  html <- as.character(build_qualitative_panel())
  expect_true(grepl("qual-empty-state", html, fixed = TRUE))
})

test_that("build_qualitative_panel has hidden qual-slides-data JSON store", {
  html <- as.character(build_qualitative_panel())
  expect_true(grepl("qual-slides-data", html, fixed = TRUE))
  expect_true(grepl("application/json", html, fixed = TRUE))
})

# ==============================================================================
# build_pinned_tab
# ==============================================================================

test_that("build_pinned_tab contains pinned-toolbar", {
  html <- as.character(build_pinned_tab())
  expect_true(grepl("pinned-toolbar", html, fixed = TRUE))
})

test_that("build_pinned_tab contains pinned-cards-container", {
  html <- as.character(build_pinned_tab())
  expect_true(grepl("pinned-cards-container", html, fixed = TRUE))
})

test_that("build_pinned_tab contains pinned-empty-state", {
  html <- as.character(build_pinned_tab())
  expect_true(grepl("pinned-empty-state", html, fixed = TRUE))
})

test_that("build_pinned_tab has Save Report HTML button", {
  html <- as.character(build_pinned_tab())
  expect_true(grepl("Save Report HTML", html, fixed = TRUE))
  expect_true(grepl("saveReportHTML", html, fixed = TRUE))
})

# ==============================================================================
# build_help_overlay
# ==============================================================================

test_that("build_help_overlay contains tk-help-overlay", {
  html <- as.character(build_help_overlay())
  expect_true(grepl("tk-help-overlay", html, fixed = TRUE))
})

test_that("build_help_overlay is hidden by default", {
  html <- as.character(build_help_overlay())
  expect_true(grepl("display:none", html, fixed = TRUE))
})

test_that("build_help_overlay contains sections for all tabs", {
  html <- as.character(build_help_overlay())
  expect_true(grepl("Summary", html, fixed = TRUE))
  expect_true(grepl("Explorer", html, fixed = TRUE))
  expect_true(grepl("Added Slides", html, fixed = TRUE))
  expect_true(grepl("Pinned Views", html, fixed = TRUE))
})

test_that("build_help_overlay mentions annotations and comparison mode", {
  html <- as.character(build_help_overlay())
  expect_true(grepl("annotation", html, ignore.case = TRUE))
})

# ==============================================================================
# build_tracker_header
# ==============================================================================

test_that("build_tracker_header contains tk-header class", {
  html <- as.character(build_tracker_header(mock_html_data, mock_config, "#323367"))
  expect_true(grepl("tk-header", html, fixed = TRUE))
})

test_that("build_tracker_header shows project name", {
  html <- as.character(build_tracker_header(mock_html_data, mock_config, "#323367"))
  expect_true(grepl("Test Project", html, fixed = TRUE))
})

test_that("build_tracker_header shows badge bar", {
  html <- as.character(build_tracker_header(mock_html_data, mock_config, "#323367"))
  expect_true(grepl("tk-badge-bar", html, fixed = TRUE))
  expect_true(grepl("5.*Metrics", html))
  expect_true(grepl("3.*Waves", html))
  expect_true(grepl("3.*Segments", html))
})

test_that("build_tracker_header shows company and client name", {
  html <- as.character(build_tracker_header(mock_html_data, mock_config, "#323367"))
  expect_true(grepl("TestCo", html, fixed = TRUE))
  expect_true(grepl("ClientCo", html, fixed = TRUE))
})

# ==============================================================================
# build_tracker_footer
# ==============================================================================

test_that("build_tracker_footer contains tk-footer class", {
  html <- as.character(build_tracker_footer(mock_html_data, mock_config))
  expect_true(grepl("tk-footer", html, fixed = TRUE))
})

test_that("build_tracker_footer shows sig test info", {
  html <- as.character(build_tracker_footer(mock_html_data, mock_config))
  expect_true(grepl("Significance testing", html, fixed = TRUE))
  expect_true(grepl("p&lt;0.05", html, fixed = TRUE) || grepl("p<0.05", html, fixed = TRUE))
})

test_that("build_tracker_footer shows baseline info", {
  html <- as.character(build_tracker_footer(mock_html_data, mock_config))
  expect_true(grepl("Baseline", html, fixed = TRUE))
  expect_true(grepl("W1", html, fixed = TRUE))
})

# ==============================================================================
# build_tracker_about_panel
# ==============================================================================

test_that("build_tracker_about_panel returns NULL when no config fields", {
  empty_config <- list(settings = list(brand_colour = "#323367"))
  result <- build_tracker_about_panel(empty_config)
  expect_null(result)
})

test_that("build_tracker_about_panel returns panel when analyst_name set", {
  result <- build_tracker_about_panel(mock_config_with_about)
  expect_false(is.null(result))
  html <- as.character(result)
  expect_true(grepl("tab-about", html, fixed = TRUE))
  expect_true(grepl("Jane Doe", html, fixed = TRUE))
})

test_that("build_tracker_about_panel contains email link", {
  result <- build_tracker_about_panel(mock_config_with_about)
  html <- as.character(result)
  expect_true(grepl("mailto:jane@test.com", html, fixed = TRUE))
})

# ==============================================================================
# build_report_tab_nav
# ==============================================================================

test_that("build_report_tab_nav has 5 tabs when has_about is FALSE", {
  html <- as.character(build_report_tab_nav("#323367", has_about = FALSE))
  # Count tab buttons (class="report-tab" or class="report-tab active"), not the wrapper div
  tab_count <- length(gregexpr('class="report-tab[ "]', html, perl = TRUE)[[1]])
  expect_equal(tab_count, 5)
})

test_that("build_report_tab_nav has 6 tabs when has_about is TRUE", {
  html <- as.character(build_report_tab_nav("#323367", has_about = TRUE))
  tab_count <- length(gregexpr('class="report-tab[ "]', html, perl = TRUE)[[1]])
  expect_equal(tab_count, 6)
})

test_that("build_report_tab_nav includes Added Slides tab", {
  html <- as.character(build_report_tab_nav("#323367", has_about = FALSE))
  expect_true(grepl("Added Slides", html, fixed = TRUE))
})

test_that("build_report_tab_nav includes Save and Print buttons", {
  html <- as.character(build_report_tab_nav("#323367", has_about = FALSE))
  expect_true(grepl("Save Report", html, fixed = TRUE))
  expect_true(grepl("Print", html, fixed = TRUE))
})

# ==============================================================================
# build_annotations_json
# ==============================================================================

test_that("build_annotations_json returns empty array when no config", {
  empty_config <- list(settings = list())
  result <- build_annotations_json(empty_config)
  expect_equal(result, "[]")
})

test_that("build_annotations_json returns valid JSON when annotations provided", {
  ann_config <- list(settings = list(
    annotations = data.frame(
      metric_id = c("m1", "m2"),
      wave_id = c("W1", "W2"),
      text = c("Campaign launched", "Price change"),
      stringsAsFactors = FALSE
    )
  ))
  result <- build_annotations_json(ann_config)
  expect_false(result == "[]")
  parsed <- jsonlite::fromJSON(result)
  expect_equal(nrow(parsed), 2)
  expect_true("metricId" %in% names(parsed))
  expect_true("text" %in% names(parsed))
})
