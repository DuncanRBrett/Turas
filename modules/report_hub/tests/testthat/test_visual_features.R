# Report Hub -- Visual Feature Preservation and Remaining Tests
# Tests for SVG/image/heatmap/CSS variable/gauge/qualitative slide preservation,
# write_hub_html(), build_hub_header(), build_hub_css(), build_hub_js(),
# build_init_js(), build_level1_nav(), build_hub_about_panel(),
# build_front_page() extras, build_pinned_panel() extras,
# full integration pipeline, column chips, hub slides, about panel export,
# and namespace rewriter image functions

# ==============================================================================
# 7. VISUAL FEATURE PRESERVATION
# ==============================================================================

test_that("SVG charts with rounded corners survive the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs">
<style>.chart-container { width: 100%; }</style>
</head><body>
<div id="tab-crosstabs" class="tab-panel">
  <svg viewBox="0 0 400 200"><rect x="10" y="10" width="80" height="30" rx="4" fill="#4a7c6f"/></svg>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  expect_equal(result$status, "PASS")

  # Chart SVG should be in the content panel
  panel <- result$result$content_panels$crosstabs
  expect_true(grepl('rx="4"', panel))
  expect_true(grepl('fill="#4a7c6f"', panel))
  expect_true(grepl("<svg", panel))
})

test_that("base64 images survive namespace rewriting", {
  img_data <- "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=="

  parsed <- list(
    report_key = "tabs",
    report_type = "tabs",
    content_panels = list(
      crosstabs = sprintf(
        '<div id="tab-crosstabs" class="tab-panel"><img src="%s" alt="Logo" id="logo-img"></div>',
        img_data
      )
    ),
    report_tabs = list(html = "", tab_names = c("crosstabs")),
    header = "",
    footer = "",
    help_overlay = "",
    css_blocks = list(),
    js_blocks = list(),
    data_scripts = list(),
    metadata = list(report_type = "tabs"),
    pinned_data = "[]"
  )

  result <- rewrite_for_hub(parsed)

  # base64 image data must be preserved intact
  expect_true(grepl(img_data, result$content_panels$crosstabs, fixed = TRUE))
  # ID should be namespaced
  expect_true(grepl('id="tabs--logo-img"', result$content_panels$crosstabs))
})

test_that("heatmap data attributes survive the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<div id="tab-crosstabs" class="tab-panel">
  <table><tr><td data-heatmap-value="0.75" data-stat-type="pct" data-row-type="category">75%</td></tr></table>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  panel <- result$result$content_panels$crosstabs

  expect_true(grepl('data-heatmap-value="0.75"', panel))
  expect_true(grepl('data-stat-type="pct"', panel))
  expect_true(grepl('data-row-type="category"', panel))
})

test_that("colour palette CSS variables survive the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs">
<style>:root { --ct-brand: #323367; --ct-accent: #CC9900; --ct-text-primary: #1e293b; }</style>
</head><body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  css <- result$result$css_blocks[[1]]$content

  expect_true(grepl("--ct-brand", css))
  expect_true(grepl("--ct-accent", css))
  expect_true(grepl("--ct-text-primary", css))
})

test_that("dashboard gauge HTML survives the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<div id="tab-summary" class="tab-panel active">
  <div class="dash-gauge-container">
    <svg class="dash-gauge" viewBox="0 0 120 80"><path d="M10 70 A50 50 0 0 1 110 70" fill="none" stroke="#059669" stroke-width="8"/></svg>
    <div class="dash-gauge-value" style="color:#059669;">85%</div>
  </div>
</div>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  panel <- result$result$content_panels$summary

  expect_true(grepl("dash-gauge-container", panel))
  expect_true(grepl('stroke="#059669"', panel))
  expect_true(grepl("85%", panel))
})

test_that("qualitative slide HTML with images survives the pipeline", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<div id="tab-summary" class="tab-panel active">Summary</div>
<div id="tab-crosstabs" class="tab-panel">Crosstabs</div>
<div id="tab-qualitative" class="tab-panel">
  <div class="qual-slide" data-slide-idx="0">
    <div class="qual-slide-image"><img src="data:image/jpeg;base64,/9j/4AAQSkZJRg==" alt="Slide image"></div>
    <div class="qual-slide-text" contenteditable="true">Key finding about brand perception</div>
  </div>
</div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  panel <- result$result$content_panels$qualitative

  expect_true(grepl("qual-slide", panel))
  expect_true(grepl("data:image/jpeg;base64", panel))
  expect_true(grepl("Key finding about brand perception", panel))
  expect_true(grepl('contenteditable="true"', panel))
})


# ==============================================================================
# 10. WRITE HUB HTML: write_hub_html()
# ==============================================================================

test_that("write_hub_html writes file and returns PASS", {
  tmp_dir <- tempdir()
  out_file <- file.path(tmp_dir, "test_hub_output.html")
  on.exit(unlink(out_file), add = TRUE)

  html <- "<html><body><h1>Test</h1></body></html>"
  result <- write_hub_html(html, out_file)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(out_file))
  expect_true(result$result$file_size > 0)
  expect_true(nzchar(result$result$size_label))
  expect_true(grepl("test_hub_output.html", result$message))
})

test_that("write_hub_html creates output directory if missing", {
  tmp_base <- tempdir()
  nested <- file.path(tmp_base, "hub_test_nested_dir", "sub")
  out_file <- file.path(nested, "output.html")
  on.exit(unlink(file.path(tmp_base, "hub_test_nested_dir"), recursive = TRUE), add = TRUE)

  result <- write_hub_html("<html></html>", out_file)

  expect_equal(result$status, "PASS")
  expect_true(file.exists(out_file))
})

test_that("write_hub_html returns size in MB for large files", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  # 1.5 MB of content
  big_html <- paste(rep("x", 1500000), collapse = "")
  result <- write_hub_html(big_html, tmp)

  expect_equal(result$status, "PASS")
  expect_true(grepl("MB", result$result$size_label))
})

test_that("write_hub_html returns size in KB for small files", {
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  result <- write_hub_html("<html>small</html>", tmp)

  expect_equal(result$status, "PASS")
  expect_true(grepl("KB", result$result$size_label))
})


# ==============================================================================
# 11. HUB HEADER: build_hub_header()
# ==============================================================================

test_that("build_hub_header includes project title", {
  config <- list(settings = list(
    project_title = "My Survey Project",
    brand_colour = "#323367"
  ))
  html <- build_hub_header(config)

  expect_true(grepl("My Survey Project", html))
  expect_true(grepl("hub-header", html))
  expect_true(grepl("Powered by Turas Analytics", html))
})

test_that("build_hub_header includes prepared by/for line", {
  config <- list(settings = list(
    project_title = "Test",
    company_name = "Research Co",
    client_name = "Brand Inc"
  ))
  html <- build_hub_header(config)

  expect_true(grepl("Prepared by.*Research Co", html))
  expect_true(grepl("for.*Brand Inc", html))
})

test_that("build_hub_header includes Save and Print buttons", {
  config <- list(settings = list(project_title = "Test"))
  html <- build_hub_header(config)

  expect_true(grepl("Save Report", html))
  expect_true(grepl("Print", html))
  expect_true(grepl("ReportHub.saveReportHTML", html))
  expect_true(grepl("ReportHub.printReport", html))
})

test_that("build_hub_header handles missing optional fields gracefully", {
  config <- list(settings = list(project_title = "Minimal"))
  html <- build_hub_header(config)

  expect_true(grepl("Minimal", html))
  # No errors, no logo, still valid HTML
  expect_false(grepl("hub-logo", html))
})

test_that("build_hub_header encodes logo as base64 when file exists", {
  # Create a minimal valid PNG file (1x1 pixel, red)
  tmp_logo <- tempfile(fileext = ".png")
  on.exit(unlink(tmp_logo), add = TRUE)
  # Minimal valid 1x1 PNG binary
  png_bytes <- as.raw(c(
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,  # PNG signature
    0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  # 1x1
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,  # IDAT chunk
    0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00,
    0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc,
    0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,  # IEND chunk
    0x44, 0xae, 0x42, 0x60, 0x82
  ))
  writeBin(png_bytes, tmp_logo)

  config <- list(settings = list(
    project_title = "Logo Test",
    logo_path = tmp_logo
  ))
  html <- build_hub_header(config)

  expect_true(grepl("data:image/png;base64", html))
  expect_true(grepl("hub-logo", html))
})

test_that("build_hub_header escapes HTML in title", {
  config <- list(settings = list(project_title = "<script>alert('xss')</script>"))
  html <- build_hub_header(config)

  expect_false(grepl("<script>alert", html))
  expect_true(grepl("&lt;script&gt;", html))
})

test_that("build_hub_header includes creation date", {
  config <- list(settings = list(project_title = "Test"))
  html <- build_hub_header(config)

  expect_true(grepl("Created", html))
  expect_true(grepl(format(Sys.Date(), "%Y"), html))
})


# ==============================================================================
# 12. HUB CSS: build_hub_css()
# ==============================================================================

test_that("build_hub_css returns CSS string", {
  # Ensure CSS file is findable (set working dir if needed)
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))

  config <- list(settings = list(
    brand_colour = "#0d8a8a",
    accent_colour = "#CC9900"
  ))
  css <- build_hub_css(config)

  expect_true(is.character(css))
  expect_true(nchar(css) > 100)  # Non-trivial CSS
})

test_that("build_hub_css substitutes brand colour token", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))

  config <- list(settings = list(
    brand_colour = "#ff0000",
    accent_colour = "#00ff00"
  ))
  css <- build_hub_css(config)

  # Should not contain raw tokens
  expect_false(grepl("BRAND_COLOUR", css))
  expect_false(grepl("ACCENT_COLOUR", css))
})

test_that("build_hub_css uses defaults when colours not provided", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))

  config <- list(settings = list())
  css <- build_hub_css(config)

  # Should still produce valid CSS (uses fallback colours)
  expect_true(is.character(css))
  expect_true(nchar(css) > 0)
})


# ==============================================================================
# 13. HUB JS: build_hub_js()
# ==============================================================================

test_that("build_hub_js returns JavaScript string", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))
  js <- build_hub_js()

  expect_true(is.character(js))
  expect_true(nchar(js) > 100)
})

test_that("build_hub_js contains ReportHub namespace", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))
  js <- build_hub_js()

  expect_true(grepl("ReportHub", js))
})

test_that("build_hub_js includes navigation functions", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))
  js <- build_hub_js()

  expect_true(grepl("switchReport", js))
  expect_true(grepl("initNavigation", js))
})


# ==============================================================================
# 14. BUILD INIT JS: build_init_js()
# ==============================================================================

test_that("build_init_js generates DOMContentLoaded handler", {
  reports <- list(
    list(report_key = "tracker", report_type = "tracker"),
    list(report_key = "tabs", report_type = "tabs")
  )
  js <- build_init_js(reports)

  expect_true(grepl("DOMContentLoaded", js))
  expect_true(grepl("ReportHub.initNavigation", js))
  expect_true(grepl("TrackerReport", js))
  expect_true(grepl("TabsReport", js))
  expect_true(grepl("hydratePinnedViews", js))
})

test_that("build_init_js handles single report", {
  reports <- list(list(report_key = "tabs", report_type = "tabs"))
  js <- build_init_js(reports)

  expect_true(grepl("TabsReport", js))
  expect_false(grepl("TrackerReport", js))
})

test_that("build_init_js includes text section and slide rendering", {
  reports <- list(list(report_key = "tabs", report_type = "tabs"))
  js <- build_init_js(reports)

  expect_true(grepl("renderHubTextSections", js))
  expect_true(grepl("renderHubSlides", js))
})


# ==============================================================================
# 15. LEVEL 1 NAVIGATION: build_level1_nav()
# ==============================================================================

test_that("build_level1_nav includes Overview and Pinned tabs", {
  reports <- list(
    list(key = "tracker", label = "Tracker", type = "tracker")
  )
  html <- build_level1_nav(reports)

  expect_true(grepl("Overview", html))
  expect_true(grepl("Pinned Views", html))
  expect_true(grepl("hub-pin-badge", html))
})

test_that("build_level1_nav includes report tabs", {
  reports <- list(
    list(key = "tracker", label = "My Tracker", type = "tracker"),
    list(key = "tabs", label = "Crosstabs", type = "tabs")
  )
  html <- build_level1_nav(reports)

  expect_true(grepl("My Tracker", html))
  expect_true(grepl("Crosstabs", html))
  expect_true(grepl('data-hub-tab="tracker"', html))
  expect_true(grepl('data-hub-tab="tabs"', html))
})

test_that("build_level1_nav shows About tab when has_about=TRUE", {
  reports <- list(list(key = "tabs", label = "Tabs", type = "tabs"))
  html_with <- build_level1_nav(reports, has_about = TRUE)
  html_without <- build_level1_nav(reports, has_about = FALSE)

  expect_true(grepl("About", html_with))
  expect_false(grepl('data-hub-tab="about"', html_without))
})

test_that("build_level1_nav escapes HTML in labels", {
  reports <- list(list(key = "r1", label = "Test <b>Bold</b>", type = "tabs"))
  html <- build_level1_nav(reports)

  expect_false(grepl("<b>Bold</b>", html))
  expect_true(grepl("&lt;b&gt;Bold&lt;/b&gt;", html))
})

test_that("build_level1_nav marks Overview as active", {
  reports <- list(list(key = "tabs", label = "Tabs", type = "tabs"))
  html <- build_level1_nav(reports)

  # Overview should be the active tab
  expect_true(grepl('class="hub-tab active".*Overview', html))
})


# ==============================================================================
# 16. HUB ABOUT PANEL: build_hub_about_panel()
# ==============================================================================

test_that("build_hub_about_panel returns empty string when no fields set", {
  config <- list(settings = list(project_title = "Test"))
  html <- build_hub_about_panel(config)

  expect_equal(html, "")
})

test_that("build_hub_about_panel includes analyst name", {
  config <- list(settings = list(
    analyst_name = "Jane Doe"
  ))
  html <- build_hub_about_panel(config)

  expect_true(nzchar(html))
  expect_true(grepl("Jane Doe", html))
  expect_true(grepl("Analyst", html))
  expect_true(grepl('data-hub-panel="about"', html))
})

test_that("build_hub_about_panel creates email mailto links", {
  config <- list(settings = list(
    analyst_email = "jane@test.com; bob@test.com"
  ))
  html <- build_hub_about_panel(config)

  expect_true(grepl("mailto:jane@test.com", html))
  expect_true(grepl("mailto:bob@test.com", html))
})

test_that("build_hub_about_panel includes phone", {
  config <- list(settings = list(analyst_phone = "+27 11 123 4567"))
  html <- build_hub_about_panel(config)

  expect_true(grepl("\\+27 11 123 4567", html))
  expect_true(grepl("Phone", html))
})

test_that("build_hub_about_panel includes appendices", {
  config <- list(settings = list(appendices = "See Appendix A"))
  html <- build_hub_about_panel(config)

  expect_true(grepl("Appendix A", html))
})

test_that("build_hub_about_panel includes editable notes section", {
  config <- list(settings = list(notes = "Some **bold** notes"))
  html <- build_hub_about_panel(config)

  expect_true(grepl("hub-about-notes", html))
  expect_true(grepl("Some \\*\\*bold\\*\\* notes", html))
  expect_true(grepl("textarea", html))
})

test_that("build_hub_about_panel has balanced divs", {
  config <- list(settings = list(
    analyst_name = "Test",
    analyst_email = "test@test.com",
    analyst_phone = "123",
    appendices = "App A",
    notes = "Some notes"
  ))
  html <- build_hub_about_panel(config)

  opens <- length(gregexpr("<div", html)[[1]])
  closes <- length(gregexpr("</div>", html)[[1]])
  expect_equal(opens, closes, info = "About panel divs must be balanced")
})


# ==============================================================================
# 17. FRONT PAGE BUILDER: build_front_page(), build_summary_area(), etc.
# ==============================================================================

test_that("build_front_page generates overview HTML", {
  config <- list(settings = list(
    project_title = "Test Project"
  ))
  parsed_reports <- list(
    list(
      report_key = "tracker",
      report_type = "tracker",
      metadata = list(project_title = "Brand Tracker", n_metrics = "15"),
      content_panels = list(summary = '<div id="tab-summary" class="tab-panel">Summary</div>')
    )
  )
  html <- build_front_page(config, parsed_reports)

  expect_true(grepl("hub-overview", html))
  expect_true(grepl("hub-report-card", html))
  expect_true(grepl("Brand Tracker", html))
  expect_true(grepl("hub-slides-section", html))
})

test_that("build_front_page includes executive summary from config", {
  config <- list(settings = list(
    project_title = "Test",
    executive_summary = "Key findings here"
  ))
  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      metadata = list(project_title = "Tabs"),
      content_panels = list()
    )
  )
  html <- build_front_page(config, parsed_reports)

  expect_true(grepl("Executive Summary", html))
  expect_true(grepl("Key findings here", html))
})

test_that("build_front_page includes background text from config", {
  config <- list(settings = list(
    project_title = "Test",
    background_text = "Study methodology details"
  ))
  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      metadata = list(project_title = "Tabs"),
      content_panels = list()
    )
  )
  html <- build_front_page(config, parsed_reports)

  expect_true(grepl("Background", html))
  expect_true(grepl("Study methodology details", html))
})

test_that("build_hub_text_section generates editable markdown section", {
  html <- build_hub_text_section("exec-summary", "Executive Summary", "This is the **summary**")

  expect_true(grepl('id="hub-text-exec-summary"', html))
  expect_true(grepl("Executive Summary", html))
  expect_true(grepl("hub-text-rendered", html))
  expect_true(grepl("hub-text-editor", html))
  expect_true(grepl("This is the \\*\\*summary\\*\\*", html))
})

test_that("build_hub_text_section escapes HTML in content", {
  html <- build_hub_text_section("test", "Test", "<script>alert('xss')</script>")

  expect_false(grepl("<script>alert", html))
  expect_true(grepl("&lt;script&gt;", html))
})

test_that("build_hub_slides_section generates slides grid", {
  slides <- list(
    list(id = "s1", title = "Slide One", content = "Content one"),
    list(id = "s2", title = "Slide Two", content = "Content two")
  )
  html <- build_hub_slides_section(slides)

  expect_true(grepl("hub-slides-grid", html))
  expect_true(grepl("Slide One", html))
  expect_true(grepl("Slide Two", html))
  expect_true(grepl('data-slide-id="s1"', html))
  expect_true(grepl('data-slide-id="s2"', html))
  expect_true(grepl("\\+ Add Insight", html))
})

test_that("build_hub_slides_section handles empty slides list", {
  html <- build_hub_slides_section(list())

  expect_true(grepl("hub-slides-grid", html))
  expect_true(grepl("\\+ Add Insight", html))
  # No slide cards
  expect_false(grepl("hub-slide-card", html))
})

test_that("extract_summary_sections extracts from textarea-based panels", {
  parsed <- list(
    content_panels = list(
      summary = '<div id="tab-summary" class="tab-panel">
        <div id="dash-text-background">
          <textarea class="dash-md-store" style="display:none">Background info here</textarea>
        </div>
        <div id="dash-text-execsummary">
          <textarea class="dash-md-store" style="display:none">Executive findings</textarea>
        </div>
      </div>'
    )
  )
  sections <- extract_summary_sections(parsed)

  expect_true("background" %in% names(sections))
  expect_true("execsummary" %in% names(sections))
  expect_equal(sections$background, "Background info here")
  expect_equal(sections$execsummary, "Executive findings")
})

test_that("extract_summary_sections returns empty list when no summary panel", {
  parsed <- list(content_panels = list(crosstabs = "<div>data</div>"))
  sections <- extract_summary_sections(parsed)

  expect_equal(sections, list())
})

test_that("extract_dash_textarea extracts from dash-md-store", {
  html <- '<div id="dash-text-background">
    <textarea class="dash-md-store" style="display:none">Study background</textarea>
    <textarea class="dash-md-editor">Study background</textarea>
  </div>'

  result <- extract_dash_textarea(html, "background")
  expect_equal(result, "Study background")
})

test_that("extract_dash_textarea handles namespaced IDs", {
  html <- '<div id="tabs1--dash-text-execsummary">
    <textarea class="dash-md-store" style="display:none">Exec summary</textarea>
  </div>'

  result <- extract_dash_textarea(html, "execsummary")
  expect_equal(result, "Exec summary")
})

test_that("extract_dash_textarea returns empty string when not found", {
  html <- '<div id="other-section">no match</div>'
  result <- extract_dash_textarea(html, "background")
  expect_equal(result, "")
})


# ==============================================================================
# 18. PINNED PANEL: build_pinned_panel()
# ==============================================================================

test_that("build_pinned_panel generates valid HTML", {
  html <- build_pinned_panel()

  expect_true(grepl('data-hub-panel="pinned"', html))
  expect_true(grepl("hub-pinned-cards", html))
  expect_true(grepl("hub-pinned-empty", html))
  expect_true(grepl("Export All as PNGs", html))
})

test_that("build_pinned_panel has balanced divs", {
  html <- build_pinned_panel()
  opens <- length(gregexpr("<div", html)[[1]])
  closes <- length(gregexpr("</div>", html)[[1]])
  expect_equal(opens, closes)
})


# ==============================================================================
# 19. INTEGRATION: Full Assembly Pipeline
# ==============================================================================

test_that("assemble_hub_html produces balanced HTML document", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))
  config <- list(
    settings = list(
      project_title = "Integration Test",
      brand_colour = "#323367",
      accent_colour = "#CC9900"
    ),
    reports = list(
      list(key = "tabs", label = "Crosstabs", type = "tabs")
    )
  )
  parsed_reports <- list(
    list(
      report_key = "tabs",
      report_type = "tabs",
      css_blocks = list(list(content = ".test { color: red; }")),
      js_blocks = list(),
      data_scripts = list(),
      header = '<div class="header">Header</div>',
      report_tabs = list(html = "", tab_names = c("summary", "crosstabs")),
      content_panels = list(
        summary = '<div id="tabs--tab-summary" class="tab-panel">Summary</div>',
        crosstabs = '<div id="tabs--tab-crosstabs" class="tab-panel">Data</div>'
      ),
      footer = "",
      help_overlay = '<div class="help-overlay" id="tabs--help-overlay"><div class="help-card"><h2>Guide</h2></div></div>',
      metadata = list(project_title = "Tabs Report"),
      pinned_data = "[]",
      wrapped_js = "// tabs js"
    )
  )

  nav_html <- build_navigation(parsed_reports, config$reports)
  overview_html <- build_front_page(config, parsed_reports)
  html <- assemble_hub_html(config, parsed_reports, overview_html, nav_html)

  # Check basic structure
  expect_true(grepl("<!DOCTYPE html>", html))
  expect_true(grepl("</html>", html))
  expect_true(grepl("Integration Test", html))

  # Check div balance
  opens <- length(gregexpr("<div", html)[[1]])
  closes <- length(gregexpr("</div>", html)[[1]])
  expect_equal(opens, closes, info = "Full assembly must have balanced divs")

  # Check help overlay is present
  expect_true(grepl('id="tabs--help-overlay"', html))
})

test_that("assemble_hub_html includes About panel when configured", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))
  config <- list(
    settings = list(
      project_title = "Test",
      brand_colour = "#323367",
      accent_colour = "#CC9900",
      analyst_name = "Test Analyst"
    ),
    reports = list()
  )

  nav_html <- build_navigation(list(), config$reports, has_about = TRUE)
  overview_html <- "<div>Overview</div>"
  html <- assemble_hub_html(config, list(), overview_html, nav_html)

  expect_true(grepl('data-hub-panel="about"', html))
  expect_true(grepl("Test Analyst", html))
})

test_that("full pipeline write_hub_html writes valid file", {
  withr::local_dir(normalizePath(file.path(hub_root, "..", ".."), mustWork = FALSE))
  config <- list(
    settings = list(
      project_title = "Write Test",
      brand_colour = "#323367",
      accent_colour = "#CC9900"
    ),
    reports = list()
  )

  nav_html <- build_navigation(list(), list())
  overview_html <- "<div>Overview</div>"
  html <- assemble_hub_html(config, list(), overview_html, nav_html)

  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp), add = TRUE)

  result <- write_hub_html(html, tmp)
  expect_equal(result$status, "PASS")
  expect_true(file.exists(tmp))

  # Read back and verify
  content <- paste(readLines(tmp, warn = FALSE), collapse = "\n")
  expect_true(grepl("Write Test", content))
  expect_true(grepl("<!DOCTYPE html>", content))
})


# ==============================================================================
# 20. COLUMN CHIPS: Total chip in buildColumnChips (table_export_init.js)
# ==============================================================================

# These tests verify the JS source for buildColumnChips() includes Total column
# handling. The function lives in the tabs module JS but is exercised by the hub
# via namespace-prefixed calls.

test_that("buildColumnChips JS queries bg-total headers first", {
  js_path <- file.path(hub_root, "..", "tabs", "lib", "html_report", "js", "table_export_init.js")
  skip_if(!file.exists(js_path), "table_export_init.js not found")

  js_content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")

  # The function must query Total columns with the bg-total class

  expect_true(
    grepl('th.ct-data-col.bg-total\\[data-col-key\\]', js_content),
    info = "buildColumnChips must query th.ct-data-col.bg-total[data-col-key] for Total columns"
  )
})

test_that("buildColumnChips JS adds Total columns before banner group columns", {
  js_path <- file.path(hub_root, "..", "tabs", "lib", "html_report", "js", "table_export_init.js")
  skip_if(!file.exists(js_path), "table_export_init.js not found")

  js_content <- paste(readLines(js_path, warn = FALSE), collapse = "\n")

  # Find the positions of the Total query and the banner group query
  total_pos <- regexpr("bg-total\\[data-col-key\\]", js_content)
  group_pos <- regexpr('bg-"\\s*\\+\\s*groupCode', js_content)

  expect_true(total_pos[1] != -1, info = "Total column query must be present")
  expect_true(group_pos[1] != -1, info = "Banner group column query must be present")
  expect_true(
    total_pos[1] < group_pos[1],
    info = "Total columns must be queried before banner group columns"
  )
})


# ==============================================================================
# 21. HUB SLIDES: Image support in build_hub_slides_section()
# ==============================================================================

test_that("hub slide card includes image preview div, file input, and image store", {
  slides <- list(
    list(id = "s1", title = "Slide One", content = "Some content")
  )
  html <- build_hub_slides_section(slides)

  expect_true(grepl("hub-slide-img-preview", html))
  expect_true(grepl('type="file"', html))
  expect_true(grepl('class="hub-slide-img-input"', html))
  expect_true(grepl("hub-slide-img-store", html))
})

test_that("hub slide card includes image button in title row", {
  slides <- list(
    list(id = "s1", title = "Test", content = "Body")
  )
  html <- build_hub_slides_section(slides)

  # The image button has the frame/picture emoji &#x1F5BC;
  expect_true(grepl("hub-slide-img-btn", html))
  expect_true(grepl("&#x1F5BC;", html, fixed = TRUE))
})

test_that("hub slide image preview is hidden when no image_data provided", {
  slides <- list(
    list(id = "s1", title = "No Image", content = "Text")
  )
  html <- build_hub_slides_section(slides)

  # When no image_data, the preview div should have display:none
  expect_true(grepl('hub-slide-img-preview.*display:none;', html))
})

test_that("hub slide image preview is visible when image_data is provided", {
  slides <- list(
    list(id = "s1", title = "With Image", content = "Text",
         image_data = "data:image/png;base64,iVBORw0KGgo=")
  )
  html <- build_hub_slides_section(slides)

  # When image_data is set, the preview div style should be empty (visible)
  # Check that hub-slide-img-preview is present WITHOUT display:none
  # Extract the style attribute from the preview div
  m <- regexpr('hub-slide-img-preview"\\s+style="([^"]*)"', html, perl = TRUE)
  expect_true(m != -1, info = "Image preview div must be present")
  match_str <- regmatches(html, m)
  # The style should NOT contain display:none
  expect_false(grepl("display:none", match_str))
})

test_that("hub slide image store contains image data", {
  img_data <- "data:image/png;base64,iVBORw0KGgo="
  slides <- list(
    list(id = "s1", title = "Img Slide", content = "Body", image_data = img_data)
  )
  html <- build_hub_slides_section(slides)

  # The image store textarea should contain the image data
  expect_true(grepl("hub-slide-img-store", html))
  # The image data (HTML-escaped) should be inside the textarea
  escaped_data <- htmltools::htmlEscape(img_data)
  expect_true(grepl(escaped_data, html, fixed = TRUE))
})


# ==============================================================================
# 22. ABOUT PANEL: Export section with Save and Print buttons
# ==============================================================================

test_that("about panel includes Export section", {
  config <- list(settings = list(analyst_name = "Test User"))
  html <- build_hub_about_panel(config)

  expect_true(grepl("Export", html))
  expect_true(grepl("hub-about-export", html))
})

test_that("about panel includes Save Report and Print Report buttons", {
  config <- list(settings = list(analyst_name = "Test User"))
  html <- build_hub_about_panel(config)

  expect_true(grepl("Save Report", html))
  expect_true(grepl("Print Report", html))
})

test_that("about panel export buttons call correct ReportHub functions", {
  config <- list(settings = list(analyst_name = "Test User"))
  html <- build_hub_about_panel(config)

  expect_true(grepl("ReportHub.saveReportHTML()", html, fixed = TRUE))
  expect_true(grepl("ReportHub.printReport()", html, fixed = TRUE))
})

test_that("about panel export section includes helper text", {
  config <- list(settings = list(analyst_name = "Test User"))
  html <- build_hub_about_panel(config)

  # Helper text mentions saving and printing
  expect_true(grepl("Save embeds all edits", html))
  expect_true(grepl("Print outputs", html))
})


# ==============================================================================
# 23. NAMESPACE REWRITER: Image functions in conflict lists
# ==============================================================================

test_that("rewrite_html_onclick_conflicts prefixes triggerQualImage", {
  html <- '<button onclick="triggerQualImage(\'s1\')">Image</button>'
  result <- rewrite_html_onclick_conflicts(html, "tabs")

  expect_true(grepl("tabs_triggerQualImage", result))
})

test_that("rewrite_html_onclick_conflicts prefixes handleQualImage", {
  html <- '<input onchange="handleQualImage(\'s1\', this)">'
  result <- rewrite_html_onclick_conflicts(html, "tabs")

  expect_true(grepl("tabs_handleQualImage", result))
})

test_that("rewrite_html_onclick_conflicts prefixes removeQualImage", {
  html <- '<button onclick="removeQualImage(\'s1\')">Remove</button>'
  result <- rewrite_html_onclick_conflicts(html, "tracker")

  expect_true(grepl("tracker_removeQualImage", result))
})

test_that("wrap_js_in_iife prefixes triggerQualImage function definition", {
  js_blocks <- list(
    list(content = 'function triggerQualImage(slideId) { /* impl */ }')
  )
  result <- wrap_js_in_iife(js_blocks, "tabs", "tabs")

  expect_true(grepl("function tabs_triggerQualImage", result))
})

test_that("wrap_js_in_iife prefixes handleQualImage function definition", {
  js_blocks <- list(
    list(content = 'function handleQualImage(slideId, input) { /* impl */ }')
  )
  result <- wrap_js_in_iife(js_blocks, "tabs", "tabs")

  expect_true(grepl("function tabs_handleQualImage", result))
})

test_that("wrap_js_in_iife prefixes removeQualImage function definition", {
  js_blocks <- list(
    list(content = 'function removeQualImage(slideId) { /* impl */ }')
  )
  result <- wrap_js_in_iife(js_blocks, "tracker", "tracker")

  expect_true(grepl("function tracker_removeQualImage", result))
})
