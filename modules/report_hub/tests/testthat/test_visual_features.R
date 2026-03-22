# Report Hub -- Visual Feature Preservation Tests (iframe approach)
#
# With the iframe approach, visual features are automatically preserved
# because the report HTML is embedded as-is. These tests verify that
# the parser correctly reads reports and the assembler correctly embeds them.

# ==============================================================================
# Visual features preserved in raw_html
# ==============================================================================

test_that("SVG charts are preserved in raw_html", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<div id="tab-crosstabs" class="tab-panel">
  <svg viewBox="0 0 400 200"><rect x="10" y="10" width="80" height="30" rx="4" fill="#4a7c6f"/></svg>
</div>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  expect_equal(result$status, "PASS")

  # SVG preserved exactly in raw_html
  expect_true(grepl('rx="4"', result$result$raw_html))
  expect_true(grepl('fill="#4a7c6f"', result$result$raw_html))
  expect_true(grepl("<svg", result$result$raw_html))
})

test_that("base64 images are preserved in raw_html", {
  img_data <- "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=="

  html <- sprintf('<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<img src="%s" alt="Logo" id="logo-img">
</body></html>', img_data)

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  expect_true(grepl(img_data, result$result$raw_html, fixed = TRUE))
})

test_that("heatmap data attributes are preserved in raw_html", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<table><tr><td data-heatmap-value="0.75" data-stat-type="pct">75%</td></tr></table>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  expect_true(grepl('data-heatmap-value="0.75"', result$result$raw_html))
  expect_true(grepl('data-stat-type="pct"', result$result$raw_html))
})

test_that("CSS variables are preserved in raw_html", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs">
<style>:root { --ct-brand: #323367; --ct-accent: #CC9900; }</style>
</head><body></body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  expect_true(grepl("--ct-brand", result$result$raw_html))
  expect_true(grepl("--ct-accent", result$result$raw_html))
})

test_that("JavaScript is preserved in raw_html", {
  html <- '<!DOCTYPE html>
<html><head><meta name="turas-report-type" content="tabs"></head><body>
<script>function togglePin(qCode) { console.log(qCode); }</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")
  expect_true(grepl("togglePin", result$result$raw_html))
})


# ==============================================================================
# Hub assembler: build_hub_header(), build_hub_css()
# ==============================================================================

test_that("build_hub_header includes project title and company", {
  skip_if_not_installed("htmltools")

  config <- list(
    settings = list(
      project_title = "Test Project",
      company_name = "Acme Corp",
      client_name = "Client Co",
      logo_path = NULL
    )
  )

  header <- build_hub_header(config)

  expect_true(grepl("Test Project", header))
  expect_true(grepl("Acme Corp", header))
  expect_true(grepl("Client Co", header))
  expect_true(grepl("hub-header", header))
  expect_true(grepl("ReportHub.saveReportHTML", header))
})

test_that("build_hub_css substitutes colour tokens", {
  config <- list(
    settings = list(
      brand_colour = "#FF0000",
      accent_colour = "#00FF00"
    )
  )

  css <- build_hub_css(config)

  # Tokens should be replaced (if the CSS file is found)
  if (grepl("--hub-brand", css)) {
    expect_false(grepl("BRAND_COLOUR", css))
    expect_false(grepl("ACCENT_COLOUR", css))
  }
})


# ==============================================================================
# Hub navigation: build_navigation()
# ==============================================================================

test_that("build_navigation creates Level 1 tabs", {
  skip_if_not_installed("htmltools")

  report_configs <- list(
    list(key = "tracker", label = "Brand Tracker"),
    list(key = "tabs", label = "Crosstabs")
  )

  nav <- build_navigation(report_configs, has_about = TRUE)

  expect_true(grepl("Overview", nav))
  expect_true(grepl("Brand Tracker", nav))
  expect_true(grepl("Crosstabs", nav))
  expect_true(grepl("Pinned Views", nav))
  expect_true(grepl("About", nav))
  expect_true(grepl("hub-tab", nav))
})

test_that("build_navigation omits About tab when not configured", {
  skip_if_not_installed("htmltools")

  report_configs <- list(
    list(key = "tabs", label = "Crosstabs")
  )

  nav <- build_navigation(report_configs, has_about = FALSE)

  expect_false(grepl("About", nav))
})
