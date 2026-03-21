# Report Hub -- Help Overlay Tests
# Tests for extract_help_overlay(), extract_balanced_div(),
# help overlay namespace rewriting, navigation builder help button,
# and page assembler help overlay integration

# ==============================================================================
# 6. HELP OVERLAY: extract_help_overlay()
# ==============================================================================

test_that("extract_help_overlay captures tabs help overlay", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">
  <div class="help-card" onclick="event.stopPropagation()">
    <h2>Quick Guide</h2>
    <p>Help content here</p>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tabs")

  expect_true(nzchar(result))
  expect_true(grepl('class="help-overlay"', result))
  expect_true(grepl('id="help-overlay"', result))
  expect_true(grepl("Quick Guide", result))
  expect_true(grepl("toggleHelpOverlay", result))
})

test_that("extract_help_overlay captures tracker help overlay", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tracker"></head>
<body>
<div id="tab-overview" class="tab-panel">content</div>
<div id="tk-help-overlay" class="tk-help-overlay" onclick="toggleHelpOverlay()">
  <div class="tk-help-card">
    <h2>Tracker Help</h2>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tracker")

  expect_true(nzchar(result))
  expect_true(grepl('id="tk-help-overlay"', result))
  expect_true(grepl("Tracker Help", result))
})

test_that("extract_help_overlay returns empty string for catdriver", {
  html <- '<html><body><div id="cd-section-overview">content</div></body></html>'
  result <- extract_help_overlay(html, "catdriver")
  expect_equal(result, "")
})

test_that("extract_help_overlay returns empty string for keydriver", {
  result <- extract_help_overlay("<html><body></body></html>", "keydriver")
  expect_equal(result, "")
})

test_that("extract_help_overlay returns empty string for confidence", {
  result <- extract_help_overlay("<html><body></body></html>", "confidence")
  expect_equal(result, "")
})

test_that("extract_help_overlay returns empty string when no overlay present", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tabs")
  expect_equal(result, "")
})

test_that("extract_help_overlay handles deeply nested divs correctly", {
  # Realistic overlay with inner divs (help-subtitle, help-tip, help-dismiss)
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">
  <div class="help-card" onclick="event.stopPropagation()">
    <h2>Quick Guide</h2>
    <div class="help-subtitle">Everything you need to know</div>
    <h3>Section</h3>
    <ul><li>Item</li></ul>
    <div class="help-tip"><strong>Tip:</strong> Some advice here.</div>
    <div class="help-dismiss">Click anywhere to close</div>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tabs")
  opens <- length(gregexpr("<div", result)[[1]])
  closes <- length(gregexpr("</div>", result)[[1]])
  expect_equal(opens, closes, info = "Help overlay divs must be balanced")
  expect_equal(opens, 5)  # overlay, card, subtitle, tip, dismiss
  expect_true(grepl("help-dismiss", result))
  expect_true(grepl("</div>$", trimws(result)))
})

test_that("extract_help_overlay handles tracker with 3-level nesting", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tracker"></head>
<body>
<div id="tab-overview" class="tab-panel">content</div>
<div id="tk-help-overlay" class="tk-help-overlay" style="display:none">
  <div class="tk-help-content">
    <h2>Tracking Report Help</h2>
    <button class="tk-help-close" onclick="toggleHelpOverlay()">&times;</button>
    <div class="tk-help-body">
      <h3>Report Tabs</h3>
      <ul><li>Summary</li></ul>
    </div>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  result <- extract_help_overlay(html, "tracker")
  opens <- length(gregexpr("<div", result)[[1]])
  closes <- length(gregexpr("</div>", result)[[1]])
  expect_equal(opens, closes, info = "Tracker overlay divs must be balanced")
  expect_equal(opens, 3)  # overlay, content, body
  expect_true(grepl("tk-help-body", result))
})

test_that("extract_balanced_div extracts correctly balanced HTML", {
  html <- '<div class="outer"><div class="inner"><div class="deep">x</div></div></div>rest'
  start <- regexpr('<div class="outer"', html, fixed = TRUE)
  result <- extract_balanced_div(html, start)
  expect_equal(result, '<div class="outer"><div class="inner"><div class="deep">x</div></div></div>')
})

test_that("parse_html_report includes help_overlay in result for tabs", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">Crosstabs</div>
<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">
  <div class="help-card" onclick="event.stopPropagation()">
    <h2>Quick Guide</h2>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  expect_true(!is.null(result$result$help_overlay))
  expect_true(nzchar(result$result$help_overlay))
  expect_true(grepl("Quick Guide", result$result$help_overlay))
})

test_that("parse_html_report returns empty help_overlay for report without overlay", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  expect_equal(result$result$help_overlay, "")
})


# ==============================================================================
# 6. HELP OVERLAY: namespace rewriting
# ==============================================================================

test_that("rewrite_for_hub namespaces help overlay IDs", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = '<div id="tab-crosstabs" class="tab-panel">content</div>'
    ),
    report_tabs = list(html = "", tab_names = c("crosstabs")),
    header = "",
    footer = "",
    help_overlay = paste0(
      '<div class="help-overlay" id="help-overlay" onclick="toggleHelpOverlay()">',
      '<div class="help-card" onclick="event.stopPropagation()">',
      '<h2>Quick Guide</h2></div></div>'
    ),
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "tabs"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)

  # Help overlay IDs should be prefixed
  expect_true(grepl('id="tabs--help-overlay"', result$help_overlay))
  # onclick should be namespaced
  expect_true(grepl('tabs_toggleHelpOverlay', result$help_overlay))
  # Original unprefixed ID should NOT be present
  expect_false(grepl('id="help-overlay"[^-]', result$help_overlay))
})

test_that("rewrite_for_hub handles NULL help overlay gracefully", {
  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = '<div id="tab-crosstabs" class="tab-panel">content</div>'
    ),
    report_tabs = list(html = "", tab_names = c("crosstabs")),
    header = "",
    footer = "",
    help_overlay = NULL,
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "tabs"),
    pinned_data = "[]"
  )

  # Should not error
  result <- rewrite_for_hub(parsed)
  expect_null(result$help_overlay)
})

test_that("rewrite_for_hub handles empty help overlay gracefully", {
  parsed <- list(
    report_key = "catdriver",
    report_type = "catdriver",
    content_panels = list(
      overview = '<div id="cd-section-overview">content</div>'
    ),
    report_tabs = list(html = "", tab_names = c("overview")),
    header = "",
    footer = "",
    help_overlay = "",
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "catdriver"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)
  expect_equal(result$help_overlay, "")
})


# ==============================================================================
# 6. HELP OVERLAY: navigation builder
# ==============================================================================

test_that("build_level2_nav adds help button when has_help_overlay is TRUE", {
  html <- build_level2_nav(
    report_key = "tabs",
    tab_names = c("summary", "crosstabs"),
    report_type = "tabs",
    has_help_overlay = TRUE
  )

  expect_true(grepl('class="hub-help-btn"', html))
  expect_true(grepl('tabs_toggleHelpOverlay', html))
  expect_true(grepl('\\?', html))
})

test_that("build_level2_nav omits help button when has_help_overlay is FALSE", {
  html <- build_level2_nav(
    report_key = "catdriver",
    tab_names = c("overview", "drivers"),
    report_type = "catdriver",
    has_help_overlay = FALSE
  )

  expect_false(grepl('hub-help-btn', html))
  expect_false(grepl('toggleHelpOverlay', html))
})

test_that("build_level2_nav omits help button by default", {
  html <- build_level2_nav(
    report_key = "keydriver",
    tab_names = c("overview"),
    report_type = "keydriver"
  )

  expect_false(grepl('hub-help-btn', html))
})

test_that("build_navigation passes help_overlay flag to level 2 nav", {
  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      report_tabs = list(tab_names = c("summary", "crosstabs")),
      help_overlay = '<div class="help-overlay" id="tabs--help-overlay">help</div>'
    ),
    list(
      report_key = "catdriver",
      report_type = "catdriver",
      report_tabs = list(tab_names = c("overview")),
      help_overlay = ""
    )
  )

  report_configs <- list(
    list(key = "tabs", label = "Crosstabs", type = "tabs"),
    list(key = "catdriver", label = "Drivers", type = "catdriver")
  )

  html <- build_navigation(parsed_reports, report_configs)

  # tabs should have help button
  expect_true(grepl('tabs_toggleHelpOverlay', html))
  # catdriver should NOT have help button
  expect_false(grepl('catdriver_toggleHelpOverlay', html))
})


# ==============================================================================
# 6. HELP OVERLAY: page assembler integration
# ==============================================================================

test_that("assemble_hub_html includes help overlay in report panel", {
  config <- list(
    settings = list(
      project_title = "Help Test",
      company_name = "Co",
      brand_colour = "#323367",
      accent_colour = "#CC9900",
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
      content_panels = list(
        crosstabs = '<div id="tabs--tab-crosstabs" class="tab-panel">Crosstab content</div>'
      ),
      footer = "",
      help_overlay = '<div class="help-overlay" id="tabs--help-overlay" onclick="tabs_toggleHelpOverlay()"><div class="help-card"><h2>Quick Guide</h2></div></div>',
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// tabs js",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "<div>overview</div>", "<nav>nav</nav>")

  # Help overlay should be inside the report panel
  expect_true(grepl('id="tabs--help-overlay"', html))
  expect_true(grepl("Quick Guide", html))
  expect_true(grepl("tabs_toggleHelpOverlay", html))
})

test_that("assemble_hub_html does not inject empty help overlay", {
  config <- list(
    settings = list(
      project_title = "No Help Test",
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
      report_key = "catdriver",
      report_type = "catdriver",
      content_panels = list(
        overview = '<div id="catdriver--cd-section-overview">content</div>'
      ),
      footer = "",
      help_overlay = "",
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// catdriver js",
      metadata = list(report_type = "catdriver"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "", "")

  # Should NOT contain any help overlay div
  expect_false(grepl("help-overlay", html))
})

test_that("two tabs reports have independent namespaced help overlays", {
  config <- list(
    settings = list(
      project_title = "Dual Tabs Test",
      company_name = "Co",
      brand_colour = "#323367",
      accent_colour = "#CC9900",
      client_name = NULL,
      subtitle = NULL,
      logo_path = NULL,
      output_dir = NULL,
      output_file = NULL
    )
  )

  parsed_reports <- list(
    list(
      report_key = "tabs1",
      report_type = "tabs",
      content_panels = list(
        crosstabs = '<div id="tabs1--tab-crosstabs" class="tab-panel">Report 1</div>'
      ),
      footer = "",
      help_overlay = '<div class="help-overlay" id="tabs1--help-overlay" onclick="tabs1_toggleHelpOverlay()"><div class="help-card"><h2>Help 1</h2></div></div>',
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// tabs1 js",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    ),
    list(
      report_key = "tabs2",
      report_type = "tabs",
      content_panels = list(
        crosstabs = '<div id="tabs2--tab-crosstabs" class="tab-panel">Report 2</div>'
      ),
      footer = "",
      help_overlay = '<div class="help-overlay" id="tabs2--help-overlay" onclick="tabs2_toggleHelpOverlay()"><div class="help-card"><h2>Help 2</h2></div></div>',
      css_blocks = list(),
      js_blocks = list(),
      data_scripts = list(),
      wrapped_js = "// tabs2 js",
      metadata = list(report_type = "tabs"),
      pinned_data = "[]"
    )
  )

  html <- assemble_hub_html(config, parsed_reports, "", "")

  # Both overlays should be present with their own namespaced IDs
  expect_true(grepl('id="tabs1--help-overlay"', html))
  expect_true(grepl('id="tabs2--help-overlay"', html))
  expect_true(grepl("tabs1_toggleHelpOverlay", html))
  expect_true(grepl("tabs2_toggleHelpOverlay", html))
  expect_true(grepl("Help 1", html))
  expect_true(grepl("Help 2", html))
})
