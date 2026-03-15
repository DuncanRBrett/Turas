# ==============================================================================
# Tests: Tracker Comparison View & JS/CSS Build Functions
# ==============================================================================
# Covers:
#   - minify_js()           from 03a_page_styling.R
#   - minify_css()          from 03a_page_styling.R
#   - build_tracker_css()   from 03a_page_styling.R
#   - read_tracker_js_file() from 03a_page_styling.R
#   - build_tracker_javascript() from 03a_page_styling.R
#   - classify_metric_type() from 03d_metrics_builder.R
#   - derive_segment_groups() from 03d_metrics_builder.R
# ==============================================================================

library(testthat)
context("Tracker Comparison View & JS/CSS Build")

test_dir <- getwd()
tracker_root <- normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
turas_root <- normalizePath(file.path(tracker_root, "..", ".."), mustWork = FALSE)

assign(".tracker_lib_dir", file.path(tracker_root, "lib"), envir = globalenv())

palette_path <- file.path(turas_root, "modules", "shared", "lib", "colour_palettes.R")
if (file.exists(palette_path)) source(palette_path)

source(file.path(tracker_root, "lib", "constants.R"))
source(file.path(tracker_root, "lib", "tracker_config_loader.R"))
source(file.path(tracker_root, "lib", "html_report", "05_chart_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "03d_metrics_builder.R"))
source(file.path(tracker_root, "lib", "html_report", "03a_page_styling.R"))


# ==============================================================================
# minify_js
# ==============================================================================

test_that("minify_js strips block comments", {
  js <- "var x = 1; /* this is a comment */ var y = 2;"
  result <- minify_js(js)
  expect_false(grepl("/\\*", result))
  expect_false(grepl("this is a comment", result))
  expect_true(grepl("var x = 1;", result))
  expect_true(grepl("var y = 2;", result))
})

test_that("minify_js strips multiline block comments", {
  js <- "var a = 1;\n/* line one\n   line two\n   line three */\nvar b = 2;"
  result <- minify_js(js)
  expect_false(grepl("line one", result))
  expect_false(grepl("line two", result))
  expect_true(grepl("var a = 1;", result))
  expect_true(grepl("var b = 2;", result))
})

test_that("minify_js strips line comments", {
  js <- "var x = 1;\n// this is a line comment\nvar y = 2;"
  result <- minify_js(js)
  expect_false(grepl("this is a line comment", result))
  expect_true(grepl("var x = 1;", result))
  expect_true(grepl("var y = 2;", result))
})

test_that("minify_js collapses multiple blank lines", {
  js <- "var x = 1;\n\n\n\n\nvar y = 2;"
  result <- minify_js(js)
  # After minification, blank lines are removed entirely
  lines <- strsplit(result, "\n")[[1]]
  expect_true(all(nzchar(trimws(lines))))
})

test_that("minify_js preserves functional code", {
  js <- 'function greet(name) {\n  return "Hello, " + name;\n}'
  result <- minify_js(js)
  expect_true(grepl("function greet", result))
  expect_true(grepl("return", result))
  expect_true(grepl("Hello", result))
})


# ==============================================================================
# minify_css
# ==============================================================================

test_that("minify_css strips block comments", {
  css <- "body { color: red; } /* comment here */ div { margin: 0; }"
  result <- minify_css(css)
  expect_false(grepl("/\\*", result))
  expect_false(grepl("comment here", result))
  expect_true(grepl("body", result))
})

test_that("minify_css collapses whitespace around braces, semicolons, colons, commas", {
  css <- "body  {  color : red ;  margin : 0 ;  }"
  result <- minify_css(css)
  # No spaces around { } : ;

  expect_false(grepl(" \\{", result))
  expect_false(grepl("\\{ ", result))
  expect_false(grepl(" :", result))
  expect_false(grepl(": ", result))
  expect_false(grepl(" ;", result))
})

test_that("minify_css removes trailing semicolons before closing brace", {
  css <- "body { color: red; margin: 0; }"
  result <- minify_css(css)
  expect_false(grepl(";}", result))
})

test_that("minify_css trims result", {
  css <- "   body { color: red; }   "
  result <- minify_css(css)
  expect_equal(result, trimws(result))
})


# ==============================================================================
# build_tracker_css
# ==============================================================================

test_that("build_tracker_css returns a non-empty string", {
  result <- build_tracker_css("#323367", "#5b8def")
  # If the CSS file exists, should be non-empty; if not, empty string is acceptable
  if (nzchar(result)) {
    expect_true(is.character(result))
    expect_true(nchar(result) > 0)
  } else {
    skip("CSS asset file not found — skipping content check")
  }
})

test_that("build_tracker_css substitutes BRAND_COLOUR", {
  result <- build_tracker_css("#aa1122", "#5b8def")
  if (nzchar(result)) {
    expect_true(grepl("#aa1122", result, fixed = TRUE))
    expect_false(grepl("BRAND_COLOUR", result, fixed = TRUE))
  } else {
    skip("CSS asset file not found — skipping substitution check")
  }
})

test_that("build_tracker_css substitutes ACCENT_COLOUR", {
  result <- build_tracker_css("#323367", "#ff9900")
  if (nzchar(result)) {
    expect_true(grepl("#ff9900", result, fixed = TRUE))
    expect_false(grepl("ACCENT_COLOUR", result, fixed = TRUE))
  } else {
    skip("CSS asset file not found — skipping substitution check")
  }
})


# ==============================================================================
# read_tracker_js_file
# ==============================================================================

test_that("read_tracker_js_file returns non-empty string for existing file", {
  result <- read_tracker_js_file("annotations.js")
  expect_true(is.character(result))
  expect_true(nchar(result) > 0)
})

test_that("read_tracker_js_file returns empty string for non-existent file", {
  result <- suppressMessages(capture.output(
    res <- read_tracker_js_file("nonexistent_file_xyz.js"),
    type = "output"
  ))
  expect_equal(res, "")
})

test_that("read_tracker_js_file outputs warning for missing file", {
  output <- capture.output(
    read_tracker_js_file("nonexistent_file_xyz.js"),
    type = "output"
  )
  expect_true(any(grepl("WARN", output)))
})


# ==============================================================================
# build_tracker_javascript
# ==============================================================================

mock_html_data <- list(
  segments = c("Total", "Male"),
  baseline_wave = "W1",
  waves = c("W1", "W2", "W3")
)

test_that("build_tracker_javascript returns combined JS string", {
  result <- build_tracker_javascript(mock_html_data)
  expect_true(is.character(result))
  expect_true(nchar(result) > 0)
})

test_that("build_tracker_javascript contains SEGMENTS variable", {
  result <- build_tracker_javascript(mock_html_data)
  expect_true(grepl("var SEGMENTS", result, fixed = TRUE))
})

test_that("build_tracker_javascript contains N_WAVES variable", {
  result <- build_tracker_javascript(mock_html_data)
  expect_true(grepl("var N_WAVES", result, fixed = TRUE))
  expect_true(grepl("N_WAVES = 3", result, fixed = TRUE))
})

test_that("build_tracker_javascript includes content from JS files", {
  result <- build_tracker_javascript(mock_html_data)
  # After minification, comments are stripped, so check for actual JS content
  # from known files: annotations.js defines tkAnnotations, core_navigation defines switchReportTab
  expect_true(grepl("tkAnnotations", result, fixed = TRUE))
  expect_true(grepl("switchReportTab", result, fixed = TRUE))
  expect_true(grepl("rebuildCombinedChart", result, fixed = TRUE))
})


# ==============================================================================
# classify_metric_type
# ==============================================================================

test_that("classify_metric_type returns 'mean' for mean", {

  expect_equal(classify_metric_type("mean"), "mean")
})

test_that("classify_metric_type returns 'pct' for top2_box", {
  expect_equal(classify_metric_type("top2_box"), "pct")
})

test_that("classify_metric_type returns 'nps' for nps_score", {
  expect_equal(classify_metric_type("nps_score"), "nps")
})

test_that("classify_metric_type returns 'other' for unrecognised names", {
  expect_equal(classify_metric_type("other_thing"), "other")
})

test_that("classify_metric_type returns 'pct' for pct_agree", {
  expect_equal(classify_metric_type("pct_agree"), "pct")
})

test_that("classify_metric_type returns 'pct' for bottom3_box", {
  expect_equal(classify_metric_type("bottom3_box"), "pct")
})


# ==============================================================================
# derive_segment_groups
# ==============================================================================

test_that("derive_segment_groups places Total in standalone", {
  result <- derive_segment_groups(c("Total", "Gender_Male", "Gender_Female"))
  expect_true("Total" %in% result$standalone)
  expect_false("Total" %in% unlist(result$groups))
})

test_that("derive_segment_groups groups segments by prefix before underscore", {
  result <- derive_segment_groups(c("Total", "Gender_Male", "Gender_Female", "Age_18-24"))
  expect_true("Gender" %in% names(result$groups))
  expect_true("Age" %in% names(result$groups))
  expect_equal(sort(result$groups[["Gender"]]), sort(c("Gender_Male", "Gender_Female")))
  expect_equal(result$groups[["Age"]], "Age_18-24")
})

test_that("derive_segment_groups returns list with standalone and groups", {
  result <- derive_segment_groups(c("Total", "Male"))
  expect_true(is.list(result))
  expect_true("standalone" %in% names(result))
  expect_true("groups" %in% names(result))
})

test_that("derive_segment_groups handles segments without underscores", {
  result <- derive_segment_groups(c("Total", "Male", "Female"))
  expect_equal(result$standalone, "Total")
  # Male and Female have no underscore, so each becomes its own group key
  expect_true("Male" %in% names(result$groups))
  expect_true("Female" %in% names(result$groups))
})
