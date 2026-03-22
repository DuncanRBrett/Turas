# Report Hub -- Page Assembler Tests (07_page_assembler.R, iframe approach)
# Tests for assemble_hub_html(), build_pinned_panel(), build_init_js()

# ==============================================================================
# assemble_hub_html() (integration)
# ==============================================================================

test_that("assemble_hub_html produces a complete HTML document with iframes", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("htmltools")

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

  report_html <- '<!DOCTYPE html><html><head><meta name="turas-report-type" content="tracker"><title>Test</title></head><body><p>Report content</p></body></html>'

  parsed_reports <- list(
    list(
      report_key = "tracker",
      report_type = "tracker",
      metadata = list(report_type = "tracker", project_title = "Test Tracker"),
      raw_html = report_html
    )
  )

  overview_html <- '<div class="hub-overview">overview content</div>'
  navigation_html <- '<nav class="hub-nav">navigation</nav>'

  html <- assemble_hub_html(config, parsed_reports, overview_html, navigation_html)

  # Basic structure checks
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl("<html lang=\"en\">", html, fixed = TRUE))
  expect_true(grepl("</html>", html, fixed = TRUE))

  # Title
  expect_true(grepl("Test Hub Project", html))

  # Meta tag for hub type
  expect_true(grepl('content="hub"', html))

  # Navigation included
  expect_true(grepl("hub-nav", html))

  # Overview panel
  expect_true(grepl('data-hub-panel="overview"', html))

  # Report panel with iframe
  expect_true(grepl('data-hub-panel="tracker"', html))
  expect_true(grepl('id="hub-iframe-tracker"', html))
  expect_true(grepl("hub-report-iframe", html))

  # Loading indicator
  expect_true(grepl('id="hub-loading-tracker"', html))

  # JSON-encoded report HTML stored for iframe injection
  expect_true(grepl('id="hub-report-tracker"', html))
  expect_true(grepl("application/json", html))

  # Pinned panel
  expect_true(grepl('data-hub-panel="pinned"', html))

  # Pinned data store
  expect_true(grepl('id="hub-pinned-data"', html))

  # DOMContentLoaded init script
  expect_true(grepl("DOMContentLoaded", html))
  expect_true(grepl("ReportHub.initNavigation", html))
})

test_that("assemble_hub_html base64-encodes report HTML safely", {
  skip_if_not_installed("htmltools")
  skip_if_not_installed("base64enc")

  config <- list(
    settings = list(
      project_title = "Script Test",
      brand_colour = NULL,
      accent_colour = NULL,
      company_name = NULL,
      client_name = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  # Report HTML containing </script> tags (the exact pattern that broke things)
  report_html <- '<html><head><meta name="turas-report-type" content="tabs"></head><body><script>var x = 1;</script></body></html>'

  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      metadata = list(report_type = "tabs"),
      raw_html = report_html
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "", "")

  # Data element uses base64 encoding
  expect_true(grepl('data-encoding="base64"', html))

  # Extract the base64 content between the data script tags
  b64_match <- regmatches(html, regexpr('id="hub-report-tabs">[^<]+<', html))
  b64_content <- sub('id="hub-report-tabs">', '', sub('<$', '', b64_match))

  # Base64 content must NOT contain < or > (the whole point)
  expect_false(grepl("[<>]", b64_content))

  # Decoding the base64 should give back the original HTML
  decoded <- rawToChar(base64enc::base64decode(b64_content))
  expect_equal(decoded, report_html)
})


# ==============================================================================
# build_pinned_panel()
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
# build_init_js()
# ==============================================================================

test_that("build_init_js generates DOMContentLoaded wrapper", {
  init_js <- build_init_js(c("tracker", "tabs"))

  expect_true(grepl("DOMContentLoaded", init_js))
  expect_true(grepl("ReportHub.initNavigation", init_js))
  expect_true(grepl("ReportHub.hydratePinnedViews", init_js))
  # Report keys should be in the JS
  expect_true(grepl('"tracker"', init_js))
  expect_true(grepl('"tabs"', init_js))
})

test_that("build_init_js handles single report", {
  init_js <- build_init_js("tracker")

  expect_true(grepl("DOMContentLoaded", init_js))
  expect_true(grepl('"tracker"', init_js))
})
