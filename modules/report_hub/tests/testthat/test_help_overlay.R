# Report Hub -- Help Overlay Tests
# UPDATED for iframe approach: help overlays live inside each report's iframe,
# so they don't need extraction or namespace rewriting at the hub level.

test_that("help overlay is preserved in raw_html (iframe approach)", {
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

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  # Help overlay is preserved in raw_html — no extraction needed
  expect_true(grepl('class="help-overlay"', result$result$raw_html))
  expect_true(grepl("Quick Guide", result$result$raw_html))
  expect_true(grepl("toggleHelpOverlay", result$result$raw_html))
})
