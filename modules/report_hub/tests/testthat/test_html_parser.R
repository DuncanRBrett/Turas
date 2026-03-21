# Report Hub -- HTML Parser Tests (01_html_parser.R)
# Tests for detect_report_type(), extract_blocks(), extract_metadata(), parse_html_report()

# ==============================================================================
# 2. HTML PARSER: detect_report_type()
# ==============================================================================

test_that("detect_report_type identifies tracker via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="tracker"></head><body></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("detect_report_type identifies tabs via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="tabs"></head><body></body></html>'
  expect_equal(detect_report_type(html), "tabs")
})

test_that("detect_report_type identifies catdriver via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="catdriver"></head><body></body></html>'
  expect_equal(detect_report_type(html), "catdriver")
})

test_that("detect_report_type identifies keydriver via meta tag", {
  html <- '<html><head><meta name="turas-report-type" content="keydriver"></head><body></body></html>'
  expect_equal(detect_report_type(html), "keydriver")
})

test_that("detect_report_type identifies tabs via structural marker", {
  html <- '<html><body><div id="tab-crosstabs" class="tab-panel">content</div></body></html>'
  expect_equal(detect_report_type(html), "tabs")
})

test_that("detect_report_type identifies tracker via structural markers", {
  html <- '<html><body><div id="tab-metrics" class="tab-panel"></div><div id="tab-overview" class="tab-panel"></div></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("detect_report_type identifies tracker via tk-header class", {
  html <- '<html><body><header class="tk-header">content</header></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})

test_that("detect_report_type returns NULL for unknown HTML", {
  html <- '<html><body><p>Just a paragraph</p></body></html>'
  expect_null(detect_report_type(html))
})

test_that("detect_report_type meta tag takes precedence over structural markers", {
  # Even if both meta and structural markers are present, meta tag should win
  html <- '<html><head><meta name="turas-report-type" content="tracker"></head>
    <body><div id="tab-crosstabs" class="tab-panel">content</div></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})


# ==============================================================================
# 2. HTML PARSER: extract_blocks()
# ==============================================================================

test_that("extract_blocks extracts style blocks", {
  html <- '<html><head><style>.foo { color: red; }</style></head><body></body></html>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 1)
  expect_equal(blocks[[1]]$content, ".foo { color: red; }")
  expect_equal(blocks[[1]]$open_tag, "<style>")
})

test_that("extract_blocks extracts multiple blocks", {
  html <- '<style>a{}</style><p>gap</p><style type="text/css">b{}</style>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 2)
  expect_equal(blocks[[1]]$content, "a{}")
  expect_equal(blocks[[2]]$content, "b{}")
  expect_equal(blocks[[2]]$open_tag, '<style type="text/css">')
})

test_that("extract_blocks returns empty list when no matches", {
  html <- '<html><body><p>No styles here</p></body></html>'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 0)
})

test_that("extract_blocks extracts script blocks", {
  html <- '<script>var x = 1;</script><script type="text/javascript">var y = 2;</script>'
  blocks <- extract_blocks(html, "<script[^>]*>", "</script>")

  expect_length(blocks, 2)
  expect_equal(blocks[[1]]$content, "var x = 1;")
  expect_equal(blocks[[2]]$content, "var y = 2;")
})

test_that("extract_blocks captures start_pos and end_pos", {
  html <- 'before<style>content</style>after'
  blocks <- extract_blocks(html, "<style[^>]*>", "</style>")

  expect_length(blocks, 1)
  expect_equal(blocks[[1]]$start_pos, 7)    # position of '<' in <style>
  expect_true(blocks[[1]]$end_pos > blocks[[1]]$start_pos)
  expect_equal(blocks[[1]]$full_block, "<style>content</style>")
})

test_that("extract_blocks separates data scripts from regular scripts", {
  html <- paste0(
    '<script type="application/json" id="pinned-views-data">[{"a":1}]</script>',
    '<script>var x = 1;</script>'
  )
  all_scripts <- extract_blocks(html, "<script[^>]*>", "</script>")

  expect_length(all_scripts, 2)
  # Check that the first one is identifiable as a data script
  expect_true(grepl('application/json', all_scripts[[1]]$open_tag))
  # Check the second is a regular script
  expect_false(grepl('application/json', all_scripts[[2]]$open_tag))
})


# ==============================================================================
# 2. HTML PARSER: extract_metadata()
# ==============================================================================

test_that("extract_metadata extracts tracker metadata from meta tags", {
  html <- '<!DOCTYPE html>
<html><head>
<title>Brand Tracker 2025</title>
<meta name="turas-report-type" content="tracker">
<meta name="turas-generated" content="2025-03-15">
<meta name="turas-metrics" content="42">
<meta name="turas-waves" content="5">
<meta name="turas-segments" content="3">
<meta name="turas-baseline-label" content="Q1 2023">
<meta name="turas-latest-label" content="Q4 2025">
</head>
<body>
<header class="tk-header">
<span class="tk-header-project">Brand Tracker</span>
<span class="tk-brand-name">Acme</span>
</header>
</body></html>'

  meta <- extract_metadata(html, "tracker")

  expect_equal(meta$report_type, "tracker")
  expect_equal(meta$title, "Brand Tracker 2025")
  expect_equal(meta$generated, "2025-03-15")
  expect_equal(meta$n_metrics, "42")
  expect_equal(meta$n_waves, "5")
  expect_equal(meta$n_segments, "3")
  expect_equal(meta$baseline_label, "Q1 2023")
  expect_equal(meta$latest_label, "Q4 2025")
  expect_equal(meta$project_title, "Brand Tracker")
  expect_equal(meta$brand_name, "Acme")
})

test_that("extract_metadata extracts tabs metadata from meta tags", {
  html <- '<!DOCTYPE html>
<html><head>
<title>Survey Crosstabs</title>
<meta name="turas-report-type" content="tabs">
<meta name="turas-total-n" content="1500">
<meta name="turas-questions" content="35">
<meta name="turas-banner-groups" content="4">
<meta name="turas-weighted" content="true">
<meta name="turas-fieldwork" content="Jan-Mar 2025">
</head>
<body></body></html>'

  meta <- extract_metadata(html, "tabs")

  expect_equal(meta$report_type, "tabs")
  expect_equal(meta$title, "Survey Crosstabs")
  expect_equal(meta$total_n, "1500")
  expect_equal(meta$n_questions, "35")
  expect_equal(meta$n_banner_groups, "4")
  expect_equal(meta$weighted, "true")
  expect_equal(meta$fieldwork, "Jan-Mar 2025")
})

test_that("extract_metadata extracts tabs metadata from data attributes (legacy)", {
  html <- '<!DOCTYPE html>
<html><head><title>Legacy Tabs</title></head>
<body>
<div id="tab-summary" data-project-title="Legacy Project" data-fieldwork="2024" data-company="OldCo" data-brand-colour="#FF0000">
</div>
</body></html>'

  meta <- extract_metadata(html, "tabs")

  expect_equal(meta$project_title, "Legacy Project")
  expect_equal(meta$fieldwork, "2024")
  expect_equal(meta$company, "OldCo")
  expect_equal(meta$brand_colour, "#FF0000")
})

test_that("extract_metadata uses title as project_title fallback for tabs", {
  html <- '<html><head><title>Fallback Title</title></head><body></body></html>'
  meta <- extract_metadata(html, "tabs")

  expect_equal(meta$title, "Fallback Title")
  expect_equal(meta$project_title, "Fallback Title")
})

test_that("extract_metadata handles tracker badge bar fallback", {
  html <- '<!DOCTYPE html>
<html><head><title>Old Tracker</title></head>
<body>
<header class="tk-header">
<span class="tk-header-project">Badge Tracker</span>
</header>
<div class="tk-badge-bar"><strong>25</strong> Metrics <strong>4</strong> Waves <strong>2</strong> Segments</div>
</body></html>'

  meta <- extract_metadata(html, "tracker")

  expect_equal(meta$project_title, "Badge Tracker")
  expect_true(!is.null(meta$badge_bar))
  # The fallback should parse the badge bar for counts
  expect_equal(meta$n_metrics, "25")
  expect_equal(meta$n_waves, "4")
  expect_equal(meta$n_segments, "2")
})

test_that("extract_metadata returns minimal metadata for empty HTML", {
  html <- "<html><head></head><body></body></html>"
  meta <- extract_metadata(html, "tracker")

  expect_equal(meta$report_type, "tracker")
  expect_null(meta$title)
  expect_null(meta$generated)
})


# ==============================================================================
# 2. HTML PARSER: parse_html_report() (integration)
# ==============================================================================

test_that("parse_html_report refuses non-existent file", {
  result <- parse_html_report("/tmp/no_such_file_99999.html", "test")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "IO_FILE_NOT_FOUND")
})

test_that("parse_html_report refuses unrecognised report type", {
  tmp <- tempfile(fileext = ".html")
  writeLines("<html><body><p>Not a Turas report</p></body></html>", tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "unknown")

  expect_equal(result$status, "REFUSED")
  expect_equal(result$code, "DATA_INVALID")
  expect_true(grepl("Cannot detect report type", result$message))
})

test_that("parse_html_report parses a minimal tracker report", {
  html <- '<!DOCTYPE html>
<html><head>
<meta name="turas-report-type" content="tracker">
<title>Test Tracker</title>
<style>.tk-header { color: #333; }</style>
</head>
<body>
<header class="tk-header"><span class="tk-header-project">Test</span></header>
<div class="report-tabs">
  <button data-tab="overview">Overview</button>
  <button data-tab="metrics">Metrics</button>
</div>
<div id="tab-overview" class="tab-panel active">
  <p>Overview content</p>
</div>
<div id="tab-metrics" class="tab-panel">
  <p>Metrics content</p>
</div>
<script type="application/json" id="pinned-views-data">[]</script>
<script>var x = 1;</script>
<footer class="tk-footer">Footer</footer>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tracker")

  expect_equal(result$status, "PASS")
  expect_equal(result$result$report_key, "tracker")
  expect_equal(result$result$report_type, "tracker")
  expect_length(result$result$css_blocks, 1)
  expect_true(length(result$result$js_blocks) >= 1)
  expect_true(nzchar(result$result$header))
  expect_true(grepl("tk-header", result$result$header))
  expect_true(grepl("tk-footer", result$result$footer))
  expect_equal(result$result$pinned_data, "[]")
  expect_true(length(result$result$report_tabs$tab_names) >= 1)
  # Pinned tab should be filtered out
  expect_false("pinned" %in% result$result$report_tabs$tab_names)
})

test_that("parse_html_report extracts pinned-views-data JSON", {
  html <- '<!DOCTYPE html>
<html><head>
<meta name="turas-report-type" content="tabs">
</head>
<body>
<div id="tab-crosstabs" class="tab-panel">content</div>
<script type="application/json" id="pinned-views-data">[{"qCode":"Q1","title":"Test"}]</script>
<script>var y = 2;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  expect_true(grepl("Q1", result$result$pinned_data))
})
