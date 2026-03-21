# Report Hub -- Page Assembler Tests (07_page_assembler.R)
# Tests for merge_pinned_data(), assemble_hub_html(), build_pinned_panel(),
# build_init_js(), edge cases, wrap_js_in_iife(), build_namespace_api(),
# build_pin_bridge()

# ==============================================================================
# 5. PAGE ASSEMBLER: merge_pinned_data()
# ==============================================================================

test_that("merge_pinned_data returns empty JSON array when no pins", {
  parsed_reports <- list(
    list(
      report_key = "tracker",
      pinned_data = "[]"
    ),
    list(
      report_key = "tabs",
      pinned_data = "[]"
    )
  )

  result <- merge_pinned_data(parsed_reports)

  expect_equal(result, "[]")
})

test_that("merge_pinned_data returns empty JSON for NULL pinned_data", {
  parsed_reports <- list(
    list(
      report_key = "tracker",
      pinned_data = NULL
    )
  )

  result <- merge_pinned_data(parsed_reports)

  expect_equal(result, "[]")
})

test_that("merge_pinned_data merges pins from single report", {
  skip_if_not_installed("jsonlite")

  pins_json <- jsonlite::toJSON(
    list(list(id = "pin-1", title = "Test Pin")),
    auto_unbox = TRUE
  )
  parsed_reports <- list(
    list(
      report_key = "tracker",
      pinned_data = as.character(pins_json)
    )
  )

  result <- merge_pinned_data(parsed_reports)
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_length(parsed, 1)
  expect_equal(parsed[[1]]$id, "pin-1")
  expect_equal(parsed[[1]]$title, "Test Pin")
  expect_equal(parsed[[1]]$source, "tracker")
  expect_equal(parsed[[1]]$type, "pin")
})

test_that("merge_pinned_data merges pins from multiple reports", {
  skip_if_not_installed("jsonlite")

  tracker_pins <- jsonlite::toJSON(
    list(
      list(id = "pin-t1", title = "Tracker Pin 1"),
      list(id = "pin-t2", title = "Tracker Pin 2")
    ),
    auto_unbox = TRUE
  )
  tabs_pins <- jsonlite::toJSON(
    list(
      list(id = "pin-x1", title = "Tabs Pin 1")
    ),
    auto_unbox = TRUE
  )

  parsed_reports <- list(
    list(report_key = "tracker", pinned_data = as.character(tracker_pins)),
    list(report_key = "tabs", pinned_data = as.character(tabs_pins))
  )

  result <- merge_pinned_data(parsed_reports)
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_length(parsed, 3)
  sources <- sapply(parsed, function(p) p$source)
  expect_equal(sum(sources == "tracker"), 2)
  expect_equal(sum(sources == "tabs"), 1)
})

test_that("merge_pinned_data handles malformed JSON gracefully", {
  parsed_reports <- list(
    list(
      report_key = "bad",
      pinned_data = "this is not valid json"
    )
  )

  # Should not error, just treat as empty
  result <- merge_pinned_data(parsed_reports)

  expect_equal(result, "[]")
})

test_that("merge_pinned_data skips reports with empty pins among valid ones", {
  skip_if_not_installed("jsonlite")

  pins_json <- jsonlite::toJSON(
    list(list(id = "pin-1", title = "Only Pin")),
    auto_unbox = TRUE
  )

  parsed_reports <- list(
    list(report_key = "tracker", pinned_data = "[]"),
    list(report_key = "tabs", pinned_data = as.character(pins_json))
  )

  result <- merge_pinned_data(parsed_reports)
  parsed <- jsonlite::fromJSON(result, simplifyVector = FALSE)

  expect_length(parsed, 1)
  expect_equal(parsed[[1]]$source, "tabs")
})


# ==============================================================================
# 5. PAGE ASSEMBLER: assemble_hub_html() (integration)
# ==============================================================================

test_that("assemble_hub_html produces a complete HTML document", {
  config <- list(
    settings = list(
      project_title = "Test Hub Project",
      company_name = "TestCo",
      brand_colour = "#323367",
      accent_colour = "#CC9900",
      client_name = "Client Inc",
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "tracker",
      report_type = "tracker",
      content_panels = list(
        overview = '<div id="tracker--tab-overview" class="tab-panel">Overview content</div>'
      ),
      footer = '<footer class="tk-footer">Tracker Footer</footer>',
      css_blocks = list(
        list(content = '#tracker--tab-overview { display: block; }')
      ),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = 'console.log("tracker init");',
      metadata = list(report_type = "tracker"),
      pinned_data = "[]"
    )
  )

  overview_html <- '<div class="hub-overview">overview content</div>'
  navigation_html <- '<nav class="hub-nav">navigation</nav>'

  html <- assemble_hub_html(config, parsed_reports, overview_html, navigation_html)

  # Basic structure checks
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl("<html lang=\"en\">", html, fixed = TRUE))
  expect_true(grepl("</html>", html, fixed = TRUE))
  expect_true(grepl("<head>", html, fixed = TRUE))
  expect_true(grepl("</head>", html, fixed = TRUE))
  expect_true(grepl("<body", html, fixed = TRUE))
  expect_true(grepl("</body>", html, fixed = TRUE))

  # Title
  expect_true(grepl("Test Hub Project", html))

  # Meta tag for hub type
  expect_true(grepl('content="hub"', html))

  # Navigation included
  expect_true(grepl("hub-nav", html))

  # Overview panel
  expect_true(grepl('data-hub-panel="overview"', html))
  expect_true(grepl("hub-overview", html))

  # Report panel
  expect_true(grepl('data-hub-panel="tracker"', html))
  expect_true(grepl("tracker--tab-overview", html))

  # Footer
  expect_true(grepl("Tracker Footer", html))

  # Pinned panel
  expect_true(grepl('data-hub-panel="pinned"', html))
  expect_true(grepl("hub-pinned-cards", html))

  # Pinned data store
  expect_true(grepl('id="hub-pinned-data"', html))

  # CSS included
  expect_true(grepl("tracker styles", html))

  # JS included
  expect_true(grepl("tracker JS", html))
  expect_true(grepl("tracker init", html))

  # DOMContentLoaded init script
  expect_true(grepl("DOMContentLoaded", html))
})

test_that("assemble_hub_html skips pinned-views-data from individual reports", {
  config <- list(
    settings = list(
      project_title = "Test",
      company_name = "Co",
      brand_colour = NULL,
      accent_colour = NULL,
      client_name = NULL,
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      content_panels = list(),
      footer = "",
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(
        list(
          id = "tabs--pinned-views-data",
          open_tag = '<script type="application/json" id="tabs--pinned-views-data">',
          content = '[{"id":"old"}]'
        ),
        list(
          id = "tabs--banner-data",
          open_tag = '<script type="application/json" id="tabs--banner-data">',
          content = '{"banners":[]}'
        )
      ),
      wrapped_js = "",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "", "")

  # The per-report pinned-views-data should be skipped
  expect_false(grepl('id="tabs--pinned-views-data"', html))

  # But other data scripts should be included
  expect_true(grepl('id="tabs--banner-data"', html))

  # The unified hub-pinned-data should be present
  expect_true(grepl('id="hub-pinned-data"', html))
})


# ==============================================================================
# 5. PAGE ASSEMBLER: build_pinned_panel()
# ==============================================================================

test_that("build_pinned_panel generates expected HTML structure", {
  panel_html <- build_pinned_panel()

  expect_true(grepl('data-hub-panel="pinned"', panel_html))
  expect_true(grepl('id="hub-pinned-toolbar"', panel_html))
  expect_true(grepl('id="hub-pinned-cards"', panel_html))
  expect_true(grepl('id="hub-pinned-empty"', panel_html))
  expect_true(grepl('ReportHub.addSection', panel_html))
  expect_true(grepl('ReportHub.exportAllPins', panel_html))
})


# ==============================================================================
# 5. PAGE ASSEMBLER: build_init_js()
# ==============================================================================

test_that("build_init_js generates DOMContentLoaded wrapper", {
  parsed_reports <- list(
    list(report_key = "tracker", report_type = "tracker"),
    list(report_key = "tabs", report_type = "tabs")
  )

  init_js <- build_init_js(parsed_reports)

  expect_true(grepl("DOMContentLoaded", init_js))
  expect_true(grepl("ReportHub.initNavigation", init_js))
  expect_true(grepl("ReportHub.hydratePinnedViews", init_js))
  expect_true(grepl("TrackerReport", init_js))
  expect_true(grepl("TabsReport", init_js))
})


# ==============================================================================
# EDGE CASES AND ROBUSTNESS
# ==============================================================================

test_that("extract_blocks handles nested-looking tags correctly", {
  # Only the outermost matching pair should be captured
  html <- '<style>a { content: "<style>"; }</style>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  # Should find at least one block
  expect_true(length(blocks) >= 1)
})

test_that("detect_report_type handles whitespace in meta tags", {
  html <- '<meta  name="turas-report-type"  content="tracker">'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("rewrite_css_ids handles empty CSS string", {
  result <- rewrite_css_ids("", "tk--")
  expect_equal(result, "")
})

test_that("rewrite_html_ids handles empty HTML string", {
  result <- rewrite_html_ids("", "tk--")
  expect_equal(result, "")
})

test_that("merge_pinned_data handles empty parsed_reports list", {
  result <- merge_pinned_data(list())
  expect_equal(result, "[]")
})

test_that("parse_settings_sheet handles key-value format with extra columns", {
  df <- data.frame(
    Field = c("project_title", "company_name"),
    Value = c("Title", "Company"),
    Notes = c("Note 1", "Note 2"),
    stringsAsFactors = FALSE
  )
  result <- parse_settings_sheet(df)

  expect_equal(result$project_title, "Title")
  expect_equal(result$company_name, "Company")
})

test_that("rewrite_html_onclick_conflicts prefixes conflict functions in onclick", {
  html <- '<button onclick="togglePin(\'Q1\')">Pin</button>'
  result <- rewrite_html_onclick_conflicts(html, "tracker")

  expect_true(grepl("tracker_togglePin", result))
})

test_that("rewrite_html_onclick_conflicts handles multiple conflict functions", {
  html <- paste0(
    '<button onclick="exportCSV()">CSV</button>',
    '<button onclick="exportExcel()">Excel</button>'
  )
  result <- rewrite_html_onclick_conflicts(html, "tabs")

  expect_true(grepl("tabs_exportCSV", result))
  expect_true(grepl("tabs_exportExcel", result))
})

test_that("wrap_js_in_iife prefixes conflicting function definitions", {
  js_blocks <- list(
    list(content = 'function togglePin(qCode) { /* impl */ }
function escapeHtml(str) { return str; }
var someNonConflict = true;')
  )

  result <- wrap_js_in_iife(js_blocks, "tabs", "tabs")

  expect_true(grepl("function tabs_togglePin", result))
  expect_true(grepl("function tabs_escapeHtml", result))
  # Non-conflicting vars should NOT be prefixed
  expect_true(grepl("var someNonConflict", result))
})

test_that("wrap_js_in_iife adds scoped DOM helper functions", {
  js_blocks <- list(
    list(content = 'var el = document.getElementById("test");')
  )

  result <- wrap_js_in_iife(js_blocks, "tracker", "tracker")

  # Should define helper functions
  expect_true(grepl("_tracker_id", result))
  expect_true(grepl("_tracker_qs", result))
  expect_true(grepl("_tracker_qsa", result))

  # The user code 'document.getElementById("test")' should be rewritten to the helper.
  # Note: The helper *definitions* themselves still reference document.getElementById,
  # so we check that the original user-code call was replaced by the helper.
  expect_true(grepl('_tracker_id("test")', result, fixed = TRUE))
  # The original user-code call should NOT appear verbatim
  expect_false(grepl('var el = document.getElementById("test")', result, fixed = TRUE))
})

test_that("wrap_js_in_iife replaces querySelectorAll before querySelector", {
  js_blocks <- list(
    list(content = 'var els = document.querySelectorAll(".items"); var el = document.querySelector(".item");')
  )

  result <- wrap_js_in_iife(js_blocks, "tabs", "tabs")

  expect_true(grepl("_tabs_qsa(", result, fixed = TRUE))
  expect_true(grepl("_tabs_qs(", result, fixed = TRUE))
  # The original user-code calls should be rewritten to helpers
  expect_false(grepl('var els = document.querySelectorAll(".items")', result, fixed = TRUE))
  expect_false(grepl('var el = document.querySelector(".item")', result, fixed = TRUE))
  # Verify the helpers are used in user code
  expect_true(grepl('_tabs_qsa(".items")', result, fixed = TRUE))
  expect_true(grepl('_tabs_qs(".item")', result, fixed = TRUE))
})

test_that("build_namespace_api creates TrackerReport for tracker type", {
  api_js <- build_namespace_api("TrackerReport", "tracker", "tracker")

  expect_true(grepl("var TrackerReport", api_js))
  expect_true(grepl("tracker_togglePin", api_js))
  expect_true(grepl("tracker_updatePinButton", api_js))
  expect_true(grepl("tracker_toggleHelpOverlay", api_js))
})

test_that("build_namespace_api creates TabsReport for tabs type", {
  api_js <- build_namespace_api("TabsReport", "tabs", "tabs")

  expect_true(grepl("var TabsReport", api_js))
  expect_true(grepl("tabs_togglePin", api_js))
  expect_true(grepl("tabs_updatePinButton", api_js))
  expect_true(grepl("tabs_toggleHelpOverlay", api_js))
})

test_that("build_pin_bridge generates tracker bridge with correct prefixes", {
  bridge_js <- build_pin_bridge("tracker", "tracker")

  expect_true(grepl("Hub Pin Bridge", bridge_js))
  expect_true(grepl("ReportHub.addPin", bridge_js))
  expect_true(grepl("_tracker_id", bridge_js))
  expect_true(grepl("tracker_pinSigCard", bridge_js))
  expect_true(grepl("tracker_pinVisibleSigFindings", bridge_js))
  expect_true(grepl("tracker_hydratePinnedViews", bridge_js))
  expect_true(grepl("tracker_renderPinnedCards", bridge_js))
})

test_that("build_pin_bridge generates tabs bridge with correct prefixes", {
  bridge_js <- build_pin_bridge("tabs", "tabs")

  expect_true(grepl("Hub Pin Bridge", bridge_js))
  expect_true(grepl("ReportHub.addPin", bridge_js))
  expect_true(grepl("_tabs_id", bridge_js))
  expect_true(grepl("tabs_togglePin", bridge_js))
  expect_true(grepl("tabs_pinSigCard", bridge_js))
  expect_true(grepl("tabs_pinVisibleSigFindings", bridge_js))
  expect_true(grepl("tabs_hydratePinnedViews", bridge_js))
  expect_true(grepl("tabs_renderPinnedCards", bridge_js))
  expect_true(grepl("tabs_pinQualSlide", bridge_js))
})
