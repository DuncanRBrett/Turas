# Report Hub -- HTML Parser Tests (01_html_parser.R, iframe approach)
# Tests for detect_report_type(), extract_meta_tags(), parse_html_report()

# ==============================================================================
# detect_report_type()
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
  html <- '<html><head><meta name="turas-report-type" content="tracker"></head>
    <body><div id="tab-crosstabs" class="tab-panel">content</div></body></html>'
  expect_equal(detect_report_type(html), "tracker")
})


# ==============================================================================
# extract_meta_tags()
# ==============================================================================

test_that("extract_meta_tags extracts tracker metadata", {
  html <- '<!DOCTYPE html>
<html><head>
<title>Brand Tracker 2025</title>
<meta name="turas-report-type" content="tracker">
<meta name="turas-project-title" content="Brand Tracker">
<meta name="turas-n-metrics" content="42">
<meta name="turas-n-waves" content="5">
<meta name="turas-n-segments" content="3">
<meta name="turas-baseline-label" content="Q1 2023">
<meta name="turas-latest-label" content="Q4 2025">
</head><body></body></html>'

  meta <- extract_meta_tags(html)

  expect_equal(meta$report_type, "tracker")
  expect_equal(meta$project_title, "Brand Tracker")
  expect_equal(meta$n_metrics, "42")
  expect_equal(meta$n_waves, "5")
  expect_equal(meta$n_segments, "3")
  expect_equal(meta$baseline_label, "Q1 2023")
  expect_equal(meta$latest_label, "Q4 2025")
})

test_that("extract_meta_tags extracts tabs metadata", {
  html <- '<!DOCTYPE html>
<html><head>
<title>Survey Crosstabs</title>
<meta name="turas-report-type" content="tabs">
<meta name="turas-project-title" content="Survey Crosstabs">
<meta name="turas-total-n" content="1500">
<meta name="turas-n-questions" content="35">
<meta name="turas-n-banner-groups" content="4">
<meta name="turas-weighted" content="true">
<meta name="turas-fieldwork" content="Jan-Mar 2025">
</head><body></body></html>'

  meta <- extract_meta_tags(html)

  expect_equal(meta$report_type, "tabs")
  expect_equal(meta$project_title, "Survey Crosstabs")
  expect_equal(meta$total_n, "1500")
  expect_equal(meta$n_questions, "35")
  expect_equal(meta$n_banner_groups, "4")
  expect_equal(meta$weighted, "true")
  expect_equal(meta$fieldwork, "Jan-Mar 2025")
})

test_that("extract_meta_tags falls back to title tag", {
  html <- '<html><head><title>Fallback Title</title></head><body></body></html>'
  meta <- extract_meta_tags(html)

  expect_equal(meta$project_title, "Fallback Title")
})

test_that("extract_meta_tags handles HTML with no metadata gracefully", {
  html <- "<html><head></head><body></body></html>"
  meta <- extract_meta_tags(html)

  expect_null(meta$report_type)
  expect_null(meta$project_title)
  expect_null(meta$n_metrics)
})


# ==============================================================================
# parse_html_report() (integration)
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

test_that("parse_html_report returns raw_html and metadata for tracker", {
  html <- '<!DOCTYPE html>
<html><head>
<meta name="turas-report-type" content="tracker">
<meta name="turas-project-title" content="Test Tracker">
<meta name="turas-n-metrics" content="12">
<title>Test Tracker</title>
<style>.tk-header { color: #333; }</style>
</head>
<body>
<header class="tk-header"><span class="tk-header-project">Test</span></header>
<div id="tab-overview" class="tab-panel active"><p>Overview</p></div>
<script>var x = 1;</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tracker")

  expect_equal(result$status, "PASS")
  expect_equal(result$result$report_key, "tracker")
  expect_equal(result$result$report_type, "tracker")
  expect_equal(result$result$metadata$project_title, "Test Tracker")
  expect_equal(result$result$metadata$n_metrics, "12")
  # raw_html contains the complete original HTML
  expect_true(grepl("tk-header", result$result$raw_html))
  expect_true(grepl("var x = 1", result$result$raw_html))
  expect_true(result$result$file_size > 0)
})

test_that("parse_html_report returns raw_html for tabs report", {
  html <- '<!DOCTYPE html>
<html><head>
<meta name="turas-report-type" content="tabs">
<meta name="turas-project-title" content="Test Crosstabs">
</head>
<body>
<div id="tab-crosstabs" class="tab-panel">crosstab content</div>
<script type="application/json" id="pinned-views-data">[{"qCode":"Q1"}]</script>
</body></html>'

  tmp <- tempfile(fileext = ".html")
  writeLines(html, tmp)
  on.exit(unlink(tmp))

  result <- parse_html_report(tmp, "tabs")

  expect_equal(result$status, "PASS")
  expect_equal(result$result$report_type, "tabs")
  # raw_html includes everything — pinned data, scripts, all content
  expect_true(grepl("crosstab content", result$result$raw_html))
  expect_true(grepl("pinned-views-data", result$result$raw_html))
})


# ==============================================================================
# format_file_size()
# ==============================================================================

test_that("format_file_size formats bytes correctly", {
  expect_equal(format_file_size(500), "500 B")
  expect_equal(format_file_size(1024), "1.0 KB")
  expect_equal(format_file_size(1536), "1.5 KB")
  expect_equal(format_file_size(1048576), "1.0 MB")
  expect_equal(format_file_size(2621440), "2.5 MB")
})
